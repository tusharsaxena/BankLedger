local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- The capture engine. Diff is the pure heart of the addon: two inventory snapshots in, ledger
-- movements out. Everything below it (event wiring, item enrichment) is a thin shell around it.

local function snap(bags, store, money)
  return { bags = bags or {}, store = store or {}, money = money or 0 }
end

-- Find the single move for an itemID (nil when absent), so a test reads by intent not by index.
local function moveFor(moves, itemID)
  for _, m in ipairs(moves) do
    if m.itemID == itemID then return m end
  end
  return nil
end

local function moneyMove(moves)
  for _, m in ipairs(moves) do
    if m.kind == "MONEY" then return m end
  end
  return nil
end

-- ── Diff: items ────────────────────────────────────────────────────────────────

test("Ledger.Diff: stack leaving bags and arriving in the store is a DEPOSIT", function()
  local moves = NS.Ledger.Diff(
    snap({ [2589] = 20 }, {}),
    snap({ [2589] = 0 }, { [2589] = 20 }),
    "BANK")
  assertEqual(#moves, 1, "one movement")
  local m = moves[1]
  assertEqual(m.kind, "ITEM")
  assertEqual(m.direction, "DEPOSIT")
  assertEqual(m.itemID, 2589)
  assertEqual(m.quantity, 20)
end)

test("Ledger.Diff: stack leaving the store and arriving in bags is a WITHDRAW", function()
  local moves = NS.Ledger.Diff(
    snap({}, { [2589] = 20 }),
    snap({ [2589] = 20 }, {}),
    "BANK")
  assertEqual(#moves, 1)
  assertEqual(moves[1].direction, "WITHDRAW")
  assertEqual(moves[1].quantity, 20)
end)

test("Ledger.Diff: a partial stack move records only the quantity that actually moved", function()
  local moves = NS.Ledger.Diff(
    snap({ [4306] = 50 }, { [4306] = 10 }),
    snap({ [4306] = 30 }, { [4306] = 30 }),
    "BANK")
  assertEqual(#moves, 1)
  assertEqual(moves[1].direction, "DEPOSIT")
  assertEqual(moves[1].quantity, 20)
end)

test("Ledger.Diff: quantity is the smaller of the two sides when they disagree", function()
  -- 5 left the bags but 3 arrived (2 were destroyed/consumed): only the 3 that landed are a move.
  local moves = NS.Ledger.Diff(
    snap({ [4306] = 10 }, {}),
    snap({ [4306] = 5 }, { [4306] = 3 }),
    "BANK")
  assertEqual(#moves, 1)
  assertEqual(moves[1].quantity, 3)
end)

test("Ledger.Diff: an item that only appears in bags is not a bank movement", function()
  -- Looting into the bags while the bank window is open must not read as a withdrawal.
  local moves = NS.Ledger.Diff(snap({}, {}), snap({ [19019] = 1 }, {}), "BANK")
  assertEqual(#moves, 0)
end)

test("Ledger.Diff: an item that only appears in the store is not a movement", function()
  local moves = NS.Ledger.Diff(snap({}, {}), snap({}, { [19019] = 1 }), "BANK")
  assertEqual(#moves, 0)
end)

test("Ledger.Diff: identical snapshots produce nothing", function()
  local before = snap({ [2589] = 20 }, { [4306] = 5 }, 100)
  local after  = snap({ [2589] = 20 }, { [4306] = 5 }, 100)
  assertEqual(#NS.Ledger.Diff(before, after, "BANK"), 0)
end)

test("Ledger.Diff: several items in one pass each get their own movement", function()
  local moves = NS.Ledger.Diff(
    snap({ [2589] = 20, [4306] = 5 }, {}),
    snap({ [2589] = 0, [4306] = 0 }, { [2589] = 20, [4306] = 5 }),
    "BANK")
  assertEqual(#moves, 2)
  assertEqual(moveFor(moves, 2589).quantity, 20)
  assertEqual(moveFor(moves, 4306).quantity, 5)
end)

test("Ledger.Diff: movements come back in ascending itemID order (deterministic)", function()
  local moves = NS.Ledger.Diff(
    snap({ [19019] = 1, [2589] = 3, [4306] = 2 }, {}),
    snap({}, { [19019] = 1, [2589] = 3, [4306] = 2 }),
    "BANK")
  assertEqual(#moves, 3)
  assertEqual(moves[1].itemID, 2589)
  assertEqual(moves[2].itemID, 4306)
  assertEqual(moves[3].itemID, 19019)
end)

test("Ledger.Diff: the store name is carried on every movement", function()
  local moves = NS.Ledger.Diff(snap({ [2589] = 1 }, {}), snap({}, { [2589] = 1 }), "WARBAND_BANK")
  assertEqual(moves[1].store, "WARBAND_BANK")
end)

-- ── Diff: money ────────────────────────────────────────────────────────────────

test("Ledger.Diff: money leaving the player at a money-holding store is a DEPOSIT", function()
  local moves = NS.Ledger.Diff(snap({}, {}, 500000), snap({}, {}, 300000), "GUILD_BANK")
  local m = moneyMove(moves)
  assertTrue(m ~= nil, "a money movement")
  assertEqual(m.direction, "DEPOSIT")
  assertEqual(m.quantity, 200000)
end)

test("Ledger.Diff: money arriving at a money-holding store is a WITHDRAW", function()
  local moves = NS.Ledger.Diff(snap({}, {}, 300000), snap({}, {}, 500000), "WARBAND_BANK")
  local m = moneyMove(moves)
  assertTrue(m ~= nil)
  assertEqual(m.direction, "WITHDRAW")
  assertEqual(m.quantity, 200000)
end)

test("Ledger.Diff: money is ignored at a store that holds no gold", function()
  -- The character bank has no gold slot, so a money change there came from something else entirely
  -- (a vendor sale, a quest turn-in) and must never be logged as a deposit.
  local moves = NS.Ledger.Diff(snap({}, {}, 500000), snap({}, {}, 300000), "BANK")
  assertEqual(moneyMove(moves), nil)
end)

test("Ledger.Diff: an unchanged balance produces no money movement", function()
  local moves = NS.Ledger.Diff(snap({}, {}, 500000), snap({}, {}, 500000), "GUILD_BANK")
  assertEqual(moneyMove(moves), nil)
end)

test("Ledger.Diff: the money movement sorts after the item movements", function()
  local moves = NS.Ledger.Diff(
    snap({ [2589] = 1 }, {}, 500000),
    snap({}, { [2589] = 1 }, 400000),
    "GUILD_BANK")
  assertEqual(#moves, 2)
  assertEqual(moves[1].kind, "ITEM")
  assertEqual(moves[2].kind, "MONEY")
end)

-- ── Snapshot scanning ──────────────────────────────────────────────────────────

test("Ledger:ScanStore sums stacks across every container id of a store", function()
  mocks.__containers[0] = { slots = 2, [1] = { itemID = 2589, count = 20 },
                                       [2] = { itemID = 4306, count = 5 } }
  mocks.__containers[1] = { slots = 1, [1] = { itemID = 2589, count = 12 } }
  local counts = NS.Ledger:ScanStore("BAGS")
  assertEqual(counts[2589], 32, "stacks of the same item add up across bags")
  assertEqual(counts[4306], 5)
  mocks.__containers[0], mocks.__containers[1] = nil, nil
end)

test("Ledger:ScanStore returns an empty map for a store with no reachable containers", function()
  local counts = NS.Ledger:ScanStore("BANK")
  assertEqual(next(counts), nil, "nothing to count")
end)

test("Ledger:Snapshot captures bags, the open store and the money balance together", function()
  mocks.__containers[0] = { slots = 1, [1] = { itemID = 2589, count = 7 } }
  mocks.__money = 4242
  local s = NS.Ledger:Snapshot("BANK")
  assertEqual(s.bags[2589], 7)
  assertEqual(next(s.store), nil)
  assertEqual(s.money, 4242)
  mocks.__containers[0] = nil
end)

-- ── Capture gate ───────────────────────────────────────────────────────────────

local function itemMove(itemID, qty)
  return { kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = itemID, quantity = qty or 1 }
end

-- Settings changes go through NS.Schema:Set, never a direct db write. That is not incidental: the
-- gate reads cached upvalues for speed (it runs once per moved item), and the cache is re-filled by
-- the SettingsChanged message the write seam publishes. Poking db.global behind the seam would
-- leave the gate reading stale values — which is exactly the bug this route proves cannot happen.
local function withSettings(overrides, fn)
  local saved = {}
  for k, v in pairs(overrides) do
    saved[k] = NS.Schema:Get("settings." .. k)
    NS.Schema:Set("settings." .. k, v)
  end
  local ok, err = pcall(fn)
  for k, v in pairs(saved) do NS.Schema:Set("settings." .. k, v) end
  if not ok then error(err, 0) end
end

test("Ledger:GateReason allows an ordinary item move", function()
  assertEqual(NS.Ledger:GateReason(itemMove(171276)), nil)
end)

test("Ledger:GateReason blocks everything while capture is disabled", function()
  withSettings({ enabled = false }, function()
    assertEqual(NS.Ledger:GateReason(itemMove(171276)), "disabled")
  end)
end)

test("Ledger:GateReason blocks an item below the minimum quality", function()
  withSettings({ qualityThreshold = 3 }, function()
    assertEqual(NS.Ledger:GateReason(itemMove(2589)), "quality")   -- Linen Cloth is Common (1)
  end)
end)

test("Ledger:GateReason lets a whitelisted item through the quality gate", function()
  withSettings({ qualityThreshold = 5 }, function()
    NS.Filters:AddWhitelist(2589)
    assertEqual(NS.Ledger:GateReason(itemMove(2589)), nil)
    NS.Filters:RemoveWhitelist(2589)
  end)
end)

test("Ledger:GateReason blocks a blacklisted item even when it would otherwise pass", function()
  NS.Filters:AddBlacklist(171276)
  assertEqual(NS.Ledger:GateReason(itemMove(171276)), "blacklist")
  NS.Filters:RemoveBlacklist(171276)
end)

test("Ledger:GateReason blocks a muted store", function()
  withSettings({ excludedStores = { BANK = true } }, function()
    assertEqual(NS.Ledger:GateReason(itemMove(171276)), "store")
  end)
end)

test("Ledger:GateReason blocks item moves when item tracking is off", function()
  withSettings({ trackItems = false }, function()
    assertEqual(NS.Ledger:GateReason(itemMove(171276)), "kind")
  end)
end)

test("Ledger:GateReason blocks money moves when gold tracking is off", function()
  withSettings({ trackMoney = false }, function()
    local m = { kind = "MONEY", direction = "DEPOSIT", store = "GUILD_BANK", quantity = 100 }
    assertEqual(NS.Ledger:GateReason(m), "kind")
  end)
end)

test("Ledger:GateReason ignores the quality gate for a money move", function()
  withSettings({ qualityThreshold = 5 }, function()
    local m = { kind = "MONEY", direction = "DEPOSIT", store = "GUILD_BANK", quantity = 100 }
    assertEqual(NS.Ledger:GateReason(m), nil)
  end)
end)

-- ── Entry construction ─────────────────────────────────────────────────────────

test("Ledger:BuildEntry stamps who, where and when onto an item movement", function()
  local e = NS.Ledger:BuildEntry(itemMove(171276, 4))
  assertEqual(e.kind, "ITEM")
  assertEqual(e.direction, "DEPOSIT")
  assertEqual(e.store, "BANK")
  assertEqual(e.itemID, 171276)
  assertEqual(e.quantity, 4)
  assertEqual(e.char, "Mock-Realm")
  assertEqual(e.classFile, "MAGE")
  assertEqual(e.zone, "Testville")
  assertEqual(e.subzone, "The Vault")
  assertEqual(e.mapID, 2657)
  assertTrue(type(e.ts) == "number", "a timestamp")
end)

test("Ledger:BuildEntry enriches an item movement from the item cache", function()
  local e = NS.Ledger:BuildEntry(itemMove(171276, 2))
  assertEqual(e.itemName, "Spectral Flask")
  assertEqual(e.quality, 3)
  assertEqual(e.itemType, "Consumable")
  assertEqual(e.itemSubType, "Flask")
  assertEqual(e.vendorPrice, 5000)
end)

test("Ledger:BuildEntry names a money movement and leaves the item fields empty", function()
  local e = NS.Ledger:BuildEntry(
    { kind = "MONEY", direction = "WITHDRAW", store = "GUILD_BANK", quantity = 12345 })
  assertEqual(e.kind, "MONEY")
  assertEqual(e.itemID, nil)
  assertEqual(e.quantity, 12345)
  assertEqual(e.itemName, "Gold")
end)

test("Ledger:BuildEntry stamps the guild name on a guild-bank movement only", function()
  local guildMove = { kind = "ITEM", direction = "DEPOSIT", store = "GUILD_BANK",
                      itemID = 2589, quantity = 1 }
  assertEqual(NS.Ledger:BuildEntry(guildMove).guild, "Ka0s")
  assertEqual(NS.Ledger:BuildEntry(itemMove(2589)).guild, nil)
end)

-- ── Record ─────────────────────────────────────────────────────────────────────

test("Ledger:Record appends a gated-in movement to the ledger", function()
  local before = NS.Database:Count()
  local index = NS.Ledger:Record(itemMove(171276, 3))
  assertEqual(NS.Database:Count(), before + 1)
  assertEqual(NS.Database:Ledger()[index].quantity, 3)
  NS.Database:DeleteAt(index)
end)

test("Ledger:Record drops a gated-out movement and writes nothing", function()
  local before = NS.Database:Count()
  NS.Filters:AddBlacklist(171276)
  assertEqual(NS.Ledger:Record(itemMove(171276, 3)), nil)
  assertEqual(NS.Database:Count(), before, "nothing was written")
  NS.Filters:RemoveBlacklist(171276)
end)

test("Ledger.MoveSummary renders one line per pass, not one per item (debug-logging-§9)", function()
  local line = NS.Ledger.MoveSummary("BANK", 3, 1)
  assertTrue(line:find("BANK", 1, true) ~= nil, "names the store")
  assertTrue(line:find("3", 1, true) ~= nil, "carries the recorded count")
  assertTrue(line:find("1", 1, true) ~= nil, "carries the skipped count")
end)
