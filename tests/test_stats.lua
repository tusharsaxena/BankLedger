local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- Database:Stats is the single aggregation pass every Insights widget and the Insights CSV read, so
-- it is worth pinning precisely: a wrong total here is wrong in three places at once.

local NOW = 1770000000
local FIXTURE = {
  -- 10 Linen Cloth deposited to the bank, vendor 20 → value 200
  { ts = NOW, char = "Mock-Realm", classFile = "MAGE", kind = "ITEM", direction = "DEPOSIT",
    store = "BANK", itemID = 2589, itemName = "Linen Cloth", quality = 1,
    itemType = "Tradegoods", vendorPrice = 20, quantity = 10 },
  -- 3 Silk Cloth withdrawn from the bank, vendor 60 → value 180
  { ts = NOW - 86400, char = "Mock-Realm", classFile = "MAGE", kind = "ITEM",
    direction = "WITHDRAW", store = "BANK", itemID = 4306, itemName = "Silk Cloth", quality = 1,
    itemType = "Tradegoods", vendorPrice = 60, quantity = 3 },
  -- 2 more Linen Cloth deposited by an alt → value 40
  { ts = NOW - 86400, char = "Alt-Realm", classFile = "ROGUE", kind = "ITEM",
    direction = "DEPOSIT", store = "WARBAND_BANK", itemID = 2589, itemName = "Linen Cloth",
    quality = 1, itemType = "Tradegoods", vendorPrice = 20, quantity = 2 },
  -- 50000 copper into the guild bank
  { ts = NOW - 2 * 86400, char = "Mock-Realm", classFile = "MAGE", kind = "MONEY",
    direction = "DEPOSIT", store = "GUILD_BANK", itemName = "Gold", quantity = 50000 },
  -- 20000 copper back out of the guild bank
  { ts = NOW - 2 * 86400, char = "Mock-Realm", classFile = "MAGE", kind = "MONEY",
    direction = "WITHDRAW", store = "GUILD_BANK", itemName = "Gold", quantity = 20000 },
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

test("Stats: total value sums item vendor value and gold amounts alike", function()
  -- 200 + 180 + 40 + 50000 + 20000
  assertEqual(stats().totals.totalValue, 70420)
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

test("Stats: netByStore applies the direction sign", function()
  local s = stats()
  assertEqual(s.netByStore.BANK, 200 - 180)          -- deposited 200, withdrew 180
  assertEqual(s.netByStore.GUILD_BANK, 50000 - 20000)
  assertEqual(s.netByStore.WARBAND_BANK, 40)
end)

test("Stats: valueByStore is unsigned — it totals what passed through", function()
  assertEqual(stats().valueByStore.BANK, 380)
end)

test("Stats: byChar carries a per-character count and value", function()
  local s = stats()
  assertEqual(s.byChar["Mock-Realm"].count, 4)
  assertEqual(s.byChar["Alt-Realm"].count, 1)
  assertEqual(s.byChar["Alt-Realm"].value, 40)
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

test("Stats: the biggest single movement is the largest by value", function()
  assertEqual(stats().totals.biggestMove.value, 50000)
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
  assertEqual(s.totals.totalValue, 420)
end)

test("Stats: an empty result set produces zeroed totals rather than nil", function()
  local s = stats({ store = "REAGENT_BANK" })
  assertEqual(s.totals.entries, 0)
  assertEqual(s.totals.totalValue, 0)
  assertEqual(s.totals.netMoney, 0)
  assertEqual(s.totals.firstTs, nil)
end)

-- ── Insights ranking helpers ───────────────────────────────────────────────────

test("Insights.RankRows sorts by count descending", function()
  local rows = NS.Insights.RankRows({ a = 1, b = 5, c = 3 })
  assertEqual(rows[1].label, "b")
  assertEqual(rows[2].label, "c")
  assertEqual(rows[3].label, "a")
end)

test("Insights.RankRows breaks count ties on the label, so the order is stable", function()
  local rows = NS.Insights.RankRows({ zebra = 2, apple = 2 })
  assertEqual(rows[1].label, "apple")
  assertEqual(rows[2].label, "zebra")
end)

test("Insights.RankRows applies the label mapper and the value map", function()
  local rows = NS.Insights.RankRows({ BANK = 2 },
    function(k) return NS.Constants.StoreLabel[k] end, { BANK = 500 })
  assertEqual(rows[1].label, "Character Bank")
  assertEqual(rows[1].value, 500)
end)

test("Insights.RankRows honours the row limit", function()
  local rows = NS.Insights.RankRows({ a = 1, b = 2, c = 3, d = 4 }, nil, nil, 2)
  assertEqual(#rows, 2)
end)

test("Insights.RankRows returns an empty array for an empty map", function()
  assertEqual(#NS.Insights.RankRows({}), 0)
  assertEqual(#NS.Insights.RankRows(nil), 0)
end)

test("Insights.BarFraction scales each bar against the largest count", function()
  local rows = NS.Insights.RankRows({ a = 10, b = 5 })
  assertEqual(NS.Insights.BarFraction(rows, 1), 1)
  assertEqual(NS.Insights.BarFraction(rows, 2), 0.5)
end)

test("Insights.BarFraction is zero for an empty list or a missing row", function()
  assertEqual(NS.Insights.BarFraction({}, 1), 0)
  assertEqual(NS.Insights.BarFraction(nil, 1), 0)
end)

test("Insights.FormatNet colours a gain green and a loss red", function()
  assertTrue(NS.Insights.FormatNet(100):find("40ff40", 1, true) ~= nil, "green for a gain")
  assertTrue(NS.Insights.FormatNet(-100):find("ff4040", 1, true) ~= nil, "red for a loss")
end)

test("Insights.FormatNet renders zero as a neutral dash", function()
  assertTrue(NS.Insights.FormatNet(0):find("808080", 1, true) ~= nil)
end)
