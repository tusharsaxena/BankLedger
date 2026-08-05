local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- Database:Stats is the single aggregation pass every Insights widget and the Insights CSV read, so
-- it is worth pinning precisely: a wrong total here is wrong in three places at once.

local NOW = 1770000000
local FIXTURE = {
  -- 10 Linen Cloth deposited to the bank
  { ts = NOW, char = "Mock-Realm", classFile = "MAGE", kind = "ITEM", direction = "DEPOSIT",
    store = "BANK", itemID = 2589, itemName = "Linen Cloth", quality = 1,
    itemType = "Tradegoods", itemSubType = "Cloth", quantity = 10,
    zone = "Valdrakken" },
  -- 3 Silk Cloth withdrawn from the bank
  { ts = NOW - 86400, char = "Mock-Realm", classFile = "MAGE", kind = "ITEM",
    direction = "WITHDRAW", store = "BANK", itemID = 4306, itemName = "Silk Cloth", quality = 2,
    itemType = "Tradegoods", itemSubType = "Cloth", quantity = 3,
    zone = "Valdrakken" },
  -- 2 more Linen Cloth deposited by an alt
  { ts = NOW - 86400, char = "Alt-Realm", classFile = "ROGUE", kind = "ITEM",
    direction = "DEPOSIT", store = "WARBAND_BANK", itemID = 2589, itemName = "Linen Cloth",
    quality = 1, itemType = "Tradegoods", itemSubType = "Cloth", quantity = 2,
    zone = "Dornogal" },
  -- 50000 copper into the guild bank
  { ts = NOW - 2 * 86400, char = "Mock-Realm", classFile = "MAGE", kind = "MONEY",
    direction = "DEPOSIT", store = "GUILD_BANK", itemName = "Gold", quantity = 50000,
    zone = "Valdrakken" },
  -- 20000 copper back out of the guild bank
  { ts = NOW - 2 * 86400, char = "Mock-Realm", classFile = "MAGE", kind = "MONEY",
    direction = "WITHDRAW", store = "GUILD_BANK", itemName = "Gold", quantity = 20000,
    zone = "Valdrakken" },
}

local function stats(filter)
  local saved = NS.db.global.ledger
  NS.db.global.ledger = FIXTURE
  local s = NS.Database:Stats(filter)
  NS.db.global.ledger = saved
  return s
end

test("Stats: the entry total counts every movement in scope", function()
  assertEqual(stats().totals.entries, 5)
end)

test("Stats: item quantities split by direction", function()
  local t = stats().totals
  assertEqual(t.itemsDeposited, 12)   -- 10 + 2
  assertEqual(t.itemsWithdrawn, 3)
end)

test("Stats: gold in, gold out and the net between them", function()
  local t = stats().totals
  assertEqual(t.moneyIn, 50000)
  assertEqual(t.moneyOut, 20000)
  assertEqual(t.netMoney, 30000)
end)

test("Stats: distinct items counts item ids, not movements", function()
  -- Linen Cloth moves twice but is one item.
  assertEqual(stats().totals.distinctItems, 2)
end)

test("Stats: distinct characters counts the players involved", function()
  assertEqual(stats().totals.distinctChars, 2)
end)

test("Stats: the first and last timestamps bracket the data", function()
  local t = stats().totals
  assertEqual(t.lastTs, NOW)
  assertEqual(t.firstTs, NOW - 2 * 86400)
end)

test("Stats: active days counts distinct calendar days", function()
  assertEqual(stats().totals.activeDays, 3)
end)

test("Stats: byStore counts movements per store", function()
  local s = stats()
  assertEqual(s.byStore.BANK, 2)
  assertEqual(s.byStore.GUILD_BANK, 2)
  assertEqual(s.byStore.WARBAND_BANK, 1)
end)

test("Stats: byDirection counts deposits and withdrawals", function()
  local s = stats()
  assertEqual(s.byDirection.DEPOSIT, 3)
  assertEqual(s.byDirection.WITHDRAW, 2)
end)

test("Stats: byKind separates item movements from gold movements", function()
  local s = stats()
  assertEqual(s.byKind.ITEM, 3)
  assertEqual(s.byKind.MONEY, 2)
end)

test("Stats: byChar carries a per-character count", function()
  local s = stats()
  assertEqual(s.byChar["Mock-Realm"].count, 4)
  assertEqual(s.byChar["Alt-Realm"].count, 1)
  assertEqual(s.byChar["Alt-Realm"].classFile, "ROGUE")
end)

test("Stats: charByStore is a per-character by-store matrix", function()
  local s = stats()
  assertEqual(s.charByStore["Mock-Realm"].BANK, 2)
  assertEqual(s.charByStore["Alt-Realm"].WARBAND_BANK, 1)
end)

test("Stats: byItemType counts item movements only", function()
  assertEqual(stats().byItemType.Tradegoods, 3)
end)

test("Stats: topItems ranks by number of moves, most first", function()
  local top = stats().topItems
  assertEqual(top[1].itemID, 2589, "Linen Cloth moved twice")
  assertEqual(top[1].moves, 2)
  assertEqual(top[1].quantity, 12)
  assertEqual(top[2].itemID, 4306)
end)

test("Stats: the busiest day is the one with the most movements", function()
  local b = stats().totals.busiestDay
  assertTrue(b ~= nil)
  assertEqual(b.count, 2)
end)

test("Stats: a filter narrows every total, not just the count", function()
  local s = stats({ kind = "ITEM" })
  assertEqual(s.totals.entries, 3)
  assertEqual(s.totals.moneyIn, 0)
  assertEqual(s.totals.itemsMoved, 15)
end)

test("Stats: an empty result set produces zeroed totals rather than nil", function()
  -- BAGS is the counterparty of every movement, never a target, so it matches no entry.
  local s = stats({ store = "BAGS" })
  assertEqual(s.totals.entries, 0)
  assertEqual(s.totals.itemsMoved, 0)
  assertEqual(s.totals.netMoney, 0)
  assertEqual(s.totals.firstTs, nil)
end)

-- ── The expanded breakdowns ────────────────────────────────────────────────────
-- Added for the expanded Insights panel. Every one rides the SAME single pass, so these assertions
-- are also the guarantee that enriching the panel did not fork the aggregation.

test("Stats: byItemSubType counts item rows by sub-type", function()
  local s = stats()
  assertEqual(s.byItemSubType.Cloth, 3)
  assertEqual(s.byItemSubType.Gold, nil, "a gold movement has no sub-type to count")
end)

test("Stats: byQuality counts item rows by quality id", function()
  local s = stats()
  assertEqual(s.byQuality[1], 2)
  assertEqual(s.byQuality[2], 1)
end)

test("Stats: byQuality ignores gold, which has no quality", function()
  -- Bucketing a coin movement under Poor would invent a fact about it.
  local s = stats()
  local counted = 0
  for _, n in pairs(s.byQuality) do counted = counted + n end
  assertEqual(counted, 3, "only the three item rows are counted")
end)

test("Stats: byZone counts movements by where they happened", function()
  local s = stats()
  assertEqual(s.byZone.Valdrakken, 4)
  assertEqual(s.byZone.Dornogal, 1)
end)

test("Stats: topZones ranks the banking spots, count-desc", function()
  local s = stats()
  assertEqual(s.topZones[1].zone, "Valdrakken")
  assertEqual(s.topZones[1].count, 4)
  assertEqual(s.topZones[2].zone, "Dornogal")
end)

test("Stats: byHour and byWeekday bucket every movement exactly once", function()
  local s = stats()
  local hours, days = 0, 0
  for _, n in pairs(s.byHour) do hours = hours + n end
  for _, n in pairs(s.byWeekday) do days = days + n end
  assertEqual(hours, 5)
  assertEqual(days, 5)
end)

test("Stats: byWeekday is keyed 0..6 with Sunday as 0", function()
  local s = stats()
  for key in pairs(s.byWeekday) do
    assertTrue(key >= 0 and key <= 6, "weekday keys must be 0-based, got " .. tostring(key))
  end
  -- The mock clock is fixed, so the bucket for its own weekday must be the populated one.
  local wd = tonumber(os.date("%w", NOW))
  assertTrue((s.byWeekday[wd] or 0) > 0, "the fixture's own weekday must be populated")
end)

test("Stats: moneyByStore totals gross coin per store", function()
  local s = stats()
  assertEqual(s.moneyByStore.GUILD_BANK, 70000, "50000 in + 20000 out is 70000 moved")
  assertEqual(s.moneyByStore.BANK, nil, "the character bank has no coin slot")
end)

test("Stats: moneyByDay totals coin per calendar day, items excluded", function()
  local s = stats()
  local goldDay = os.date("%Y-%m-%d", NOW - 2 * 86400)
  assertEqual(s.moneyByDay[goldDay], 70000)
  assertEqual(s.moneyByDay[os.date("%Y-%m-%d", NOW)], nil, "an item-only day has no coin total")
end)

test("Stats: totals.moneyMoved is gross coin, not net", function()
  assertEqual(stats().totals.moneyMoved, 70000)
end)

test("Stats: totals.netItems signs the item flow like netMoney signs gold", function()
  assertEqual(stats().totals.netItems, 9)   -- 12 in - 3 out
end)

test("Stats: charByDirection splits each character's movements in and out", function()
  local s = stats()
  assertEqual(s.charByDirection["Mock-Realm"].DEPOSIT, 2)
  assertEqual(s.charByDirection["Mock-Realm"].WITHDRAW, 2)
  assertEqual(s.charByDirection["Alt-Realm"].DEPOSIT, 1)
  assertEqual(s.charByDirection["Alt-Realm"].WITHDRAW, nil)
end)

test("Stats: storeByDirection splits each store's movements in and out", function()
  local s = stats()
  assertEqual(s.storeByDirection.BANK.DEPOSIT, 1)
  assertEqual(s.storeByDirection.BANK.WITHDRAW, 1)
  assertEqual(s.storeByDirection.WARBAND_BANK.DEPOSIT, 1)
end)

test("Stats: topItemsByQuantity ranks the item index by stack count", function()
  local s = stats()
  assertEqual(s.topItemsByQuantity[1].itemName, "Linen Cloth")
  assertEqual(s.topItemsByQuantity[1].quantity, 12)
end)

test("Stats: the two top-item rankings share one record per item", function()
  -- Two orderings over the same byItem index, not two copies of it.
  local s = stats()
  assertEqual(#s.topItems, #s.topItemsByQuantity)
  assertEqual(s.topItems[1], s.byItem[s.topItems[1].itemID],
    "a ranked row IS the index record")
end)

test("Stats: topItems still ranks by movement count, unchanged", function()
  local s = stats()
  assertEqual(s.topItems[1].itemName, "Linen Cloth")
  assertEqual(s.topItems[1].moves, 2)
end)

test("Stats: every new breakdown is empty rather than nil on an empty ledger", function()
  local saved = NS.db.global.ledger
  NS.db.global.ledger = {}
  local s = NS.Database:Stats({})
  NS.db.global.ledger = saved
  for _, key in ipairs({ "byItemSubType", "byQuality", "byZone", "byHour", "byWeekday",
                         "moneyByDay", "moneyByStore", "charByDirection", "storeByDirection" }) do
    assertTrue(type(s[key]) == "table", key .. " must be a table, not nil")
    assertEqual(next(s[key]), nil, key .. " must be empty")
  end
  assertEqual(#s.topZones, 0)
  assertEqual(#s.topItemsByQuantity, 0)
  assertEqual(s.totals.netItems, 0)
  assertEqual(s.totals.moneyMoved, 0)
end)

test("Stats: the new breakdowns honor the filter like every other key", function()
  local s = stats({ store = "GUILD_BANK" })
  assertEqual(s.totals.entries, 2)
  assertEqual(next(s.byItemSubType), nil, "the guild-bank slice holds no item rows")
  assertEqual(s.moneyByStore.GUILD_BANK, 70000)
end)

-- ── Value is gone; net flow is counted in movements ─────────────────────────────

test("Stats no longer reports any value figure", function()
  local s = stats()
  assertEqual(s.totals.totalValue, nil)
  assertEqual(s.totals.biggestMove, nil)
  assertEqual(s.valueByStore, nil)
  assertEqual(s.valueByDay, nil)
  assertEqual(s.topItemsByValue, nil)
  assertEqual(s.topItems[1].value, nil, "item records carry no value")
end)

test("Stats: netByStore counts movements, deposits positive", function()
  local s = stats()
  -- BANK: 1 deposit + 1 withdrawal -> 0. WARBAND_BANK: 1 deposit -> +1.
  -- GUILD_BANK: 1 coin deposit + 1 coin withdrawal -> 0.
  assertEqual(s.netByStore.BANK, 0)
  assertEqual(s.netByStore.WARBAND_BANK, 1)
  assertEqual(s.netByStore.GUILD_BANK, 0)
end)

test("Stats: itemsMoved totals every stack unit that crossed the line", function()
  assertEqual(stats().totals.itemsMoved, 15)   -- 12 in + 3 out
end)

test("Stats: topStore names the store with the most movements", function()
  local top = stats().totals.topStore
  assertEqual(top.store, "BANK")   -- 2 movements, vs 1 warband and 2 guild; BANK wins the tie
  assertEqual(top.count, 2)
end)

test("Stats: topStore is nil on an empty slice", function()
  local saved = NS.db.global.ledger
  NS.db.global.ledger = {}
  assertEqual(NS.Database:Stats({}).totals.topStore, nil)
  NS.db.global.ledger = saved
end)

-- ── Direction-split companions ─────────────────────────────────────────────────

-- storeByDirection is covered above: Stats has computed it since before these companions
-- existed, and this task was simply its first consumer.

test("Stats: qualityByDirection is keyed on the numeric quality id", function()
  local m = stats().qualityByDirection
  assertEqual(m[1].DEPOSIT, 2)    -- both Linen Cloth deposits are quality 1
  assertEqual(m[2].WITHDRAW, 1)   -- the Silk Cloth withdrawal is quality 2
end)

test("Stats: itemTypeByDirection and itemSubTypeByDirection split by direction", function()
  local s = stats()
  assertEqual(s.itemTypeByDirection.Tradegoods.DEPOSIT, 2)
  assertEqual(s.itemTypeByDirection.Tradegoods.WITHDRAW, 1)
  assertEqual(s.itemSubTypeByDirection.Cloth.DEPOSIT, 2)
end)

test("Stats: the direction split always sums back to its parent breakdown", function()
  local s = stats()
  for ty, count in pairs(s.byItemType) do
    local m = s.itemTypeByDirection[ty] or {}
    assertEqual((m.DEPOSIT or 0) + (m.WITHDRAW or 0), count,
      "itemTypeByDirection must reconcile with byItemType for " .. ty)
  end
  for q, count in pairs(s.byQuality) do
    local m = s.qualityByDirection[q] or {}
    assertEqual((m.DEPOSIT or 0) + (m.WITHDRAW or 0), count,
      "qualityByDirection must reconcile with byQuality for quality " .. tostring(q))
  end
end)

-- ── Direction-split rankings for the Top Of The List section ────────────────────

test("Stats: item records split their moves and quantities by direction", function()
  local byItem = stats().byItem
  local linen = byItem[2589]      -- 2 deposits (10 + 2), no withdrawals
  assertEqual(linen.movesIn, 2)
  assertEqual(linen.movesOut, 0)
  assertEqual(linen.qtyIn, 12)
  assertEqual(linen.qtyOut, 0)
  local silk = byItem[4306]       -- 1 withdrawal of 3
  assertEqual(silk.movesOut, 1)
  assertEqual(silk.qtyOut, 3)
end)

test("Stats: the In and Out item rankings sum back to the combined ranking", function()
  local s = stats()
  for _, rec in ipairs(s.topItems) do
    assertEqual(rec.movesIn + rec.movesOut, rec.moves,
      "moves must reconcile for item " .. tostring(rec.itemID))
    assertEqual(rec.qtyIn + rec.qtyOut, rec.quantity,
      "quantity must reconcile for item " .. tostring(rec.itemID))
  end
  assertEqual(s.topItemsIn[1].itemID, 2589, "Linen Cloth leads the deposits")
  assertEqual(s.topItemsOut[1].itemID, 4306, "Silk Cloth leads the withdrawals")
end)

test("Stats: byZone keeps its plain count-map shape for the CSV", function()
  assertEqual(stats().byZone.Valdrakken, 4)
end)

test("Stats: topZones records carry the in/out split", function()
  local z = stats().topZones[1]
  assertEqual(z.zone, "Valdrakken")
  assertEqual(z.count, 4)
  assertEqual(z.inCount + z.outCount, z.count)
end)

test("Stats: topTypeSub ranks type and sub-type pairs with a display label", function()
  local t = stats().topTypeSub[1]
  assertEqual(t.type, "Tradegoods")
  assertEqual(t.subType, "Cloth")
  assertEqual(t.label, "Tradegoods \194\183 Cloth")
  assertEqual(t.count, 3)
  assertEqual(t.inCount, 2)
  assertEqual(t.outCount, 1)
end)

test("Stats: topItemsByStore ranks each store's items independently", function()
  local byStore = stats().topItemsByStore
  assertEqual(byStore.BANK[1].itemID, 2589, "Linen Cloth and Silk Cloth tie at 1; id breaks it")
  assertEqual(byStore.WARBAND_BANK[1].itemID, 2589)
  assertEqual(byStore.GUILD_BANK, nil, "a coin-only store has no item list")
end)

-- ── Per-store direction-split item lists ───────────────────────────────────────
-- Each store gets its own All / Deposits / Withdrawals triptych, so the three lists must
-- reconcile per store exactly as the global ones do.

test("Stats: per-store item records split moves by direction", function()
  local rec = stats().topItemsByStore.BANK[1]
  assertEqual(rec.movesIn + rec.movesOut, rec.moves,
    "a store record's directions must sum to its total")
end)

test("Stats: the per-store In and Out lists rank independently", function()
  local s = stats()
  -- BANK holds one Linen Cloth deposit and one Silk Cloth withdrawal.
  assertEqual(s.topItemsByStoreIn.BANK[1].itemID, 2589, "Linen Cloth leads BANK's deposits")
  assertEqual(#s.topItemsByStoreIn.BANK, 1, "only the deposited item appears in the In list")
  assertEqual(s.topItemsByStoreOut.BANK[1].itemID, 4306, "Silk Cloth leads BANK's withdrawals")
  assertEqual(#s.topItemsByStoreOut.BANK, 1, "only the withdrawn item appears in the Out list")
end)

test("Stats: a store with no withdrawals has an empty per-store Out list", function()
  local s = stats()
  -- WARBAND_BANK holds a single deposit and nothing outgoing.
  assertEqual(#s.topItemsByStoreIn.WARBAND_BANK, 1)
  assertEqual(#s.topItemsByStoreOut.WARBAND_BANK, 0,
    "an empty list, not a nil -- the panel decides whether to draw a column")
end)
