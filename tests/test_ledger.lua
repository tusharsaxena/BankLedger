local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The capture engine. Diff is the pure heart of the addon: two inventory snapshots in, ledger
-- movements out. Everything below it (event wiring, item enrichment) is a thin shell around it.

-- `storeMoney` is the store's OWN coin balance — the corroborating side of a money movement. Left
-- nil it models a store whose balance this build cannot read, which must produce no money row.
local function snap(bags, store, money, storeMoney)
  return { bags = bags or {}, store = store or {}, money = money or 0, storeMoney = storeMoney }
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

-- Money obeys the same "both sides must change, in opposite directions" rule as items. The purse
-- alone proves nothing: at the bank window a purse drop is just as likely to be a bank-tab purchase
-- or a repair as a deposit, and only the store's own balance can tell those apart.

test("Ledger.Diff: money leaving the player and arriving at the store is a DEPOSIT", function()
  local moves = NS.Ledger.Diff(
    snap({}, {}, 500000, 1000000), snap({}, {}, 300000, 1200000), "GUILD_BANK")
  local m = moneyMove(moves)
  assertTrue(m ~= nil, "a money movement")
  assertEqual(m.direction, "DEPOSIT")
  assertEqual(m.quantity, 200000)
end)

test("Ledger.Diff: money leaving the store and arriving at the player is a WITHDRAW", function()
  local moves = NS.Ledger.Diff(
    snap({}, {}, 300000, 1200000), snap({}, {}, 500000, 1000000), "WARBAND_BANK")
  local m = moneyMove(moves)
  assertTrue(m ~= nil)
  assertEqual(m.direction, "WITHDRAW")
  assertEqual(m.quantity, 200000)
end)

test("Ledger.Diff: a purse drop the store's balance does not mirror is NOT a deposit", function()
  -- F-001: buying a bank tab, repairing, or a mail COD landing while the bank window is open. The
  -- purse falls; the store gained nothing. This produced a phantom warband deposit before C-001.
  local moves = NS.Ledger.Diff(
    snap({}, {}, 10000000, 1000000), snap({}, {}, 0, 1000000), "WARBAND_BANK")
  assertEqual(moneyMove(moves), nil, "no store balance change means nothing moved to the store")
end)

test("Ledger.Diff: a store balance change the purse does not mirror is not a movement", function()
  -- Someone else deposited into the guild bank during your session. Real, but not YOUR movement,
  -- and the addon has no business writing it to your history.
  local moves = NS.Ledger.Diff(
    snap({}, {}, 500000, 1000000), snap({}, {}, 500000, 1200000), "GUILD_BANK")
  assertEqual(moneyMove(moves), nil)
end)

test("Ledger.Diff: both balances falling together is not a movement", function()
  -- Same direction on both sides cannot be a transfer between them.
  local moves = NS.Ledger.Diff(
    snap({}, {}, 500000, 1000000), snap({}, {}, 300000, 900000), "GUILD_BANK")
  assertEqual(moneyMove(moves), nil)
end)

test("Ledger.Diff: the recorded amount is the smaller of the two deltas", function()
  -- A repair AND a deposit in the same pass: the purse fell 300000 but only 200000 reached the
  -- store. Only what the store actually received is provable, so only that is recorded.
  local moves = NS.Ledger.Diff(
    snap({}, {}, 500000, 1000000), snap({}, {}, 200000, 1200000), "GUILD_BANK")
  local m = moneyMove(moves)
  assertTrue(m ~= nil)
  assertEqual(m.direction, "DEPOSIT")
  assertEqual(m.quantity, 200000)
end)

test("Ledger.Diff: an unreadable store balance produces no money movement", function()
  -- storeMoney nil = this build exposes no reader for that store. Declining is the only honest
  -- answer; guessing from the purse alone is exactly the bug C-001 removes.
  local moves = NS.Ledger.Diff(snap({}, {}, 500000, nil), snap({}, {}, 300000, nil), "GUILD_BANK")
  assertEqual(moneyMove(moves), nil)
end)

test("Ledger.Diff: a balance readable on only one side produces no money movement", function()
  -- The guild bank frame closed mid-session, so the second read came back nil. Half an observation
  -- is not an observation.
  local moves = NS.Ledger.Diff(snap({}, {}, 500000, 1000000), snap({}, {}, 300000, nil), "GUILD_BANK")
  assertEqual(moneyMove(moves), nil)
end)

test("Ledger.Diff: money is ignored at a store that holds no gold", function()
  -- The character bank has no gold slot, so a money change there came from something else entirely
  -- (a vendor sale, a quest turn-in) and must never be logged as a deposit.
  local moves = NS.Ledger.Diff(
    snap({}, {}, 500000, 1000000), snap({}, {}, 300000, 1200000), "BANK")
  assertEqual(moneyMove(moves), nil)
end)

test("Ledger.Diff: an unchanged balance produces no money movement", function()
  local moves = NS.Ledger.Diff(
    snap({}, {}, 500000, 1000000), snap({}, {}, 500000, 1000000), "GUILD_BANK")
  assertEqual(moneyMove(moves), nil)
end)

test("Ledger.Diff: the money movement sorts after the item movements", function()
  local moves = NS.Ledger.Diff(
    snap({ [2589] = 1 }, {}, 500000, 1000000),
    snap({}, { [2589] = 1 }, 400000, 1100000),
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

test("Ledger:Snapshot captures bags, every reachable store and the money balance", function()
  mocks.__containers[0] = { slots = 1, [1] = { itemID = 2589, count = 7 } }
  mocks.__money = 4242
  local s = NS.Ledger:Snapshot("BANK_FRAME")
  assertEqual(s.bags[2589], 7)
  assertEqual(s.money, 4242)
  assertTrue(s.stores.BANK ~= nil, "the character bank was scanned")
  assertTrue(s.stores.WARBAND_BANK ~= nil, "the warband tab was scanned in the same pass")
  assertEqual(s.stores.GUILD_BANK, nil, "a store this frame cannot reach is not scanned")
  mocks.__containers[0] = nil
end)

test("Ledger:Snapshot carries each money-holding store's own balance", function()
  local s = NS.Ledger:Snapshot("BANK_FRAME")
  assertEqual(s.storeMoney.WARBAND_BANK, 16348260386, "read via C_Bank, not from the purse")
  assertEqual(s.storeMoney.BANK, nil, "the character bank holds no coin of its own")
end)

test("Ledger:Snapshot omits a store balance this build cannot read", function()
  local saved = mocks.C_Bank
  mocks.C_Bank = nil
  local s = NS.Ledger:Snapshot("BANK_FRAME")
  assertEqual((s.storeMoney or {}).WARBAND_BANK, nil)
  mocks.C_Bank = saved
end)

-- ── Frame-to-store mapping ─────────────────────────────────────────────────────
-- The retail bank frame hosts the character bank and the warband tabs behind ONE BANKFRAME_OPENED,
-- and switching between them fires no event whatsoever. These pin the model that replaced "one open
-- store, chosen by which event fired" — which could never see a warband move.

test("Ledger:StoresFor: the bank frame reaches the character bank and the warband tabs", function()
  local stores = {}
  for _, s in ipairs(NS.Ledger:StoresFor("BANK_FRAME")) do stores[s] = true end
  assertTrue(stores.BANK, "character bank")
  assertTrue(stores.WARBAND_BANK, "warband tab \226\128\148 no event ever announces it")
end)

test("Ledger:StoresFor drops a store this build has no container for", function()
  -- Every declared store resolves on the current client, so drive the guard directly: a store whose
  -- id group comes back empty is not on this build and must be dropped, not scanned every pass as a
  -- permanently empty store cluttering every debug line. Blizzard retires containers between
  -- expansions — the reagent bank was the last one — so this path stays live.
  local containers = NS.Constants.STORE_CONTAINERS
  local saved = containers.WARBAND_BANK
  containers.WARBAND_BANK = {}
  local ok, err = pcall(function()
    for _, s in ipairs(NS.Ledger:StoresFor("BANK_FRAME")) do
      assertTrue(s ~= "WARBAND_BANK", "a store with no containers must be dropped")
    end
  end)
  containers.WARBAND_BANK = saved
  if not ok then error(err, 0) end
  -- ...and comes back once its containers do.
  local back = false
  for _, s in ipairs(NS.Ledger:StoresFor("BANK_FRAME")) do
    if s == "WARBAND_BANK" then back = true end
  end
  assertTrue(back, "restored containers make the store reachable again")
end)

test("Ledger:StoresFor: the guild bank frame reaches only itself", function()
  assertEqual(#NS.Ledger:StoresFor("GUILD_BANK"), 1)
  assertEqual(NS.Ledger:StoresFor("GUILD_BANK")[1], "GUILD_BANK")
end)

test("Ledger:StoresFor: an unknown context reaches nothing", function()
  assertEqual(#NS.Ledger:StoresFor("NONESUCH"), 0)
  assertEqual(#NS.Ledger:StoresFor(nil), 0)
end)

-- ── Reconcile over a whole frame ───────────────────────────────────────────────

-- Drive a real capture: open the frame, move stock between two container ids, reconcile.
local BAG_ID, BANK_ID, WARBAND_ID = 0, 6, 12   -- the real 12.0.7 ids the mock reproduces

local function withContainers(setup, fn)
  local saved = {}
  for id in pairs(setup) do saved[id] = mocks.__containers[id] end
  for id, contents in pairs(setup) do mocks.__containers[id] = contents end
  local ok, err = pcall(fn)
  for id in pairs(setup) do mocks.__containers[id] = saved[id] end
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
  if not ok then error(err, 0) end
end

test("Ledger:Reconcile records a bags-to-character-bank deposit", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 171276, count = 5 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = 171276, count = 5 }
    assertEqual(NS.Ledger:Reconcile(), 1)
    local e = NS.Database:Ledger()[NS.Database:Count()]
    assertEqual(e.store, "BANK")
    assertEqual(e.direction, "DEPOSIT")
    assertEqual(e.quantity, 5)
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger:Reconcile records a warband move with no warband open event at all", function()
  -- The regression this whole change exists for: the warband tab is reached through BANK_FRAME.
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = 171276, count = 3 } },
    [WARBAND_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[WARBAND_ID][1] = { itemID = 171276, count = 3 }
    assertEqual(NS.Ledger:Reconcile(), 1)
    assertEqual(NS.Database:Ledger()[NS.Database:Count()].store, "WARBAND_BANK")
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger:Reconcile writes ONE row, not one per store the frame reaches", function()
  -- Three stores are diffed every pass; only the one whose side actually changed may produce a row.
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 171276, count = 2 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = 171276, count = 2 }
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before + 1, "exactly one row")
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
end)

test("Ledger:Reconcile records a withdrawal back out of the bank", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 1, [1] = { itemID = 171276, count = 4 } },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BANK_ID][1] = nil
    mocks.__containers[BAG_ID][1] = { itemID = 171276, count = 4 }
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Ledger()[NS.Database:Count()].direction, "WITHDRAW")
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger:Reconcile writes nothing when no frame is open", function()
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
  assertEqual(NS.Ledger:Reconcile(), 0)
end)

test("Ledger:CloseContext reconciles once more, then disarms", function()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 171276, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = 171276, count = 1 }
    NS.Ledger:CloseContext()
    assertEqual(NS.State.openContext, nil, "disarmed")
    assertEqual(NS.State.lastSnapshot, nil, "baseline dropped")
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
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

-- 999999 is the id the item mock deliberately has no entry for: the client has not cached it.
test("Ledger:GateReason skips an uncached item when a minimum quality is set", function()
  -- F-006: nil quality skipped the comparison entirely, so an unjudgeable item was recorded no
  -- matter what threshold the user asked for. It cannot be judged, so it cannot be admitted.
  withSettings({ qualityThreshold = 3 }, function()
    assertEqual(NS.Ledger:GateReason(itemMove(999999)), "uncached")
  end)
end)

test("Ledger:GateReason records an uncached item at the default threshold", function()
  -- The asymmetry that keeps this safe: at qualityThreshold 0 every quality passes anyway, so
  -- nothing changes for the users who never set a threshold — which is all of them by default.
  withSettings({ qualityThreshold = 0 }, function()
    assertEqual(NS.Ledger:GateReason(itemMove(999999)), nil)
  end)
end)

test("Ledger:GateReason lets a whitelisted uncached item through", function()
  -- The whitelist is an explicit "record this id whatever the rules say", and it is checked before
  -- the quality gate, so it must outrank the uncached skip too.
  withSettings({ qualityThreshold = 5 }, function()
    NS.Filters:AddWhitelist(999999)
    assertEqual(NS.Ledger:GateReason(itemMove(999999)), nil)
    NS.Filters:RemoveWhitelist(999999)
  end)
end)

test("Ledger:GateReason asks the client to cache an item it had to skip", function()
  -- Without the request the id would stay uncached forever and every future move of it would be
  -- skipped for the same reason.
  local saved = mocks.__loadRequests
  mocks.__loadRequests = {}
  withSettings({ qualityThreshold = 3 }, function()
    NS.Ledger:GateReason(itemMove(999999))
  end)
  local requested = mocks.__loadRequests[999999]
  mocks.__loadRequests = saved
  assertTrue(requested, "the skipped id was queued for loading")
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
  assertEqual(e.vendorPrice, nil, "schema v2 never persists vendor value")
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

-- ── Diagnostics ────────────────────────────────────────────────────────────────
-- The instrumentation is itself covered: a diagnostic that errors in the field is worse than none.

test("Ledger.DiffSummary reports both sides and the move count", function()
  local line = NS.Ledger.DiffSummary("BANK", 12, 0, 0)
  assertTrue(line:find("BANK", 1, true) ~= nil, "names the store")
  assertTrue(line:find("bags 12 kinds", 1, true) ~= nil, "carries the bag side")
  assertTrue(line:find("store 0 kinds", 1, true) ~= nil, "carries the store side")
  assertTrue(line:find("0 moves", 1, true) ~= nil, "carries the move count")
end)

test("Ledger.CountKinds counts distinct ids, not stack sizes", function()
  assertEqual(NS.Ledger.CountKinds({ [2589] = 40, [4306] = 5 }), 2)
  assertEqual(NS.Ledger.CountKinds({}), 0)
  assertEqual(NS.Ledger.CountKinds(nil), 0)
end)

test("Ledger:Diagnose reports the open store and the resolved id groups", function()
  local lines = NS.Ledger:Diagnose()
  local text = table.concat(lines, "\n")
  assertTrue(text:find("openContext=", 1, true) ~= nil)
  assertTrue(text:find("group BANK = [", 1, true) ~= nil, "shows what BANK resolved to")
  assertTrue(text:find("group WARBAND_BANK = [", 1, true) ~= nil)
end)

test("Ledger:Diagnose lists the BagIndex members the client exposes", function()
  local text = table.concat(NS.Ledger:Diagnose(), "\n")
  assertTrue(text:find("Enum.BagIndex has", 1, true) ~= nil)
  assertTrue(text:find("BagIndex.Backpack = 0", 1, true) ~= nil)
end)

test("Ledger:Diagnose probes containers and reports only the ones with slots", function()
  mocks.__containers[0] = { slots = 2, [1] = { itemID = 2589, count = 20 } }
  local text = table.concat(NS.Ledger:Diagnose(), "\n")
  assertTrue(text:find("  0: 2 / 1 / 1", 1, true) ~= nil, "id 0 reported with its counts")
  assertTrue(text:find("  7:", 1, true) == nil, "an id with no slots is not listed")
  mocks.__containers[0] = nil
end)

test("Ledger:Diagnose never raises when no container is reachable", function()
  local ok = pcall(function() return NS.Ledger:Diagnose() end)
  assertTrue(ok)
end)

-- ── Event registration resilience ──────────────────────────────────────────────
-- The second fault behind "nothing is tracked": on modern retail RegisterEvent RAISES on a retired
-- event name, so a bare registration loop aborts and leaves every later event unbound. The addon
-- then hears one event and goes deaf, with no error unless script errors are switched on.

local function reEnable(badEvents)
  mocks.__badEvents = badEvents or {}
  NS.Ledger._enabled = nil
  NS.Ledger:Enable()
  mocks.__badEvents = {}
end

local function listHas(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

test("Ledger:Enable registers every event on a build that has them all", function()
  reEnable(nil)
  assertEqual(#NS.Ledger.unavailableEvents, 0, "nothing rejected")
  assertTrue(listHas(NS.Ledger.registeredEvents, "BAG_UPDATE_DELAYED"))
  assertTrue(listHas(NS.Ledger.registeredEvents, "BANKFRAME_OPENED"))
end)

test("Ledger:Enable survives a retired event and still binds the rest", function()
  -- The regression, in its general form: Blizzard retires an event name the addon still asks for,
  -- and modern retail RAISES on the unknown name instead of ignoring it. Before this fix that abort
  -- took the rest of the loop with it — BAG_UPDATE_DELAYED never bound, so no bag change ever
  -- reached Reconcile and not one movement was recorded. (The original offender was the reagent
  -- bank's own event, retired with the reagent bank itself; any name can be next.)
  reEnable({ PLAYERBANKSLOTS_CHANGED = true })
  assertTrue(listHas(NS.Ledger.unavailableEvents, "PLAYERBANKSLOTS_CHANGED"),
    "the retired event is recorded, not fatal")
  assertTrue(listHas(NS.Ledger.registeredEvents, "BAG_UPDATE_DELAYED"),
    "the event capture actually depends on still bound")
end)

test("Ledger:Enable binds the capture events even when several are retired", function()
  reEnable({
    PLAYERBANKSLOTS_CHANGED = true,
    GUILDBANKBAGSLOTS_CHANGED = true,
    GUILDBANKFRAME_CLOSED = true,
  })
  assertEqual(#NS.Ledger.unavailableEvents, 3)
  assertTrue(listHas(NS.Ledger.registeredEvents, "BAG_UPDATE_DELAYED"))
  assertTrue(listHas(NS.Ledger.registeredEvents, "PLAYER_MONEY"))
  assertTrue(listHas(NS.Ledger.registeredEvents, "BANKFRAME_OPENED"))
end)

test("Ledger:Enable never lets a rejected open event silence the others", function()
  reEnable({ GUILDBANKFRAME_OPENED = true })
  assertTrue(listHas(NS.Ledger.registeredEvents, "BANKFRAME_OPENED"))
  assertTrue(listHas(NS.Ledger.unavailableEvents, "GUILDBANKFRAME_OPENED"))
end)

test("Ledger:RegisterEventSafely reports whether the binding took", function()
  mocks.__badEvents = { NONESUCH_EVENT = true }
  NS.Ledger.registeredEvents, NS.Ledger.unavailableEvents = {}, {}
  assertTrue(NS.Ledger:RegisterEventSafely(NS.addon, "BAG_UPDATE_DELAYED", function() end))
  assertFalse(NS.Ledger:RegisterEventSafely(NS.addon, "NONESUCH_EVENT", function() end))
  mocks.__badEvents = {}
  reEnable(nil)
end)

test("Ledger:Diagnose names the events this build rejected", function()
  reEnable({ PLAYERBANKSLOTS_CHANGED = true })
  local text = table.concat(NS.Ledger:Diagnose(), "\n")
  assertTrue(text:find("events UNAVAILABLE (1)", 1, true) ~= nil)
  assertTrue(text:find("PLAYERBANKSLOTS_CHANGED", 1, true) ~= nil)
  reEnable(nil)
end)

-- ── Debounced reconcile ────────────────────────────────────────────────────────
-- The third fault behind "warband movements are never recorded": one deposit reports itself through
-- several events that do NOT arrive together. Reconciling per event split a single movement across
-- two passes — the first saw bags -1 with the store unchanged, the second saw store +1 with the bags
-- unchanged — and the "both sides must change" rule correctly rejected both halves.

test("Ledger:ScheduleReconcile coalesces a burst of events into ONE pass", function()
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = 171276, count = 1 } },
    [WARBAND_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    NS.Ledger:ScheduleReconcile()
    NS.Ledger:ScheduleReconcile()
    NS.Ledger:ScheduleReconcile()
    assertEqual(mocks.__fireTimers(), 1, "three events, one reconcile pass")
  end)
end)

test("Ledger: a movement whose halves arrive in separate events is still recorded", function()
  -- The exact live repro: BAG_UPDATE_DELAYED lands with the bags already changed while the warband
  -- tabs are still stale, and the warband update follows on its own beat. Both must land in one pass.
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = 171276, count = 6 } },
    [WARBAND_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}

    -- Event 1: the bags have dropped the stack; the warband tab has not caught up yet.
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:ScheduleReconcile()

    -- Event 2, moments later: the warband tab now shows it.
    mocks.__containers[WARBAND_ID][1] = { itemID = 171276, count = 6 }
    NS.Ledger:ScheduleReconcile()

    mocks.__fireTimers()
    assertEqual(NS.Database:Count(), before + 1, "one warband row, not zero")
    local e = NS.Database:Ledger()[NS.Database:Count()]
    assertEqual(e.store, "WARBAND_BANK")
    assertEqual(e.direction, "DEPOSIT")
    assertEqual(e.quantity, 6)
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger: a withdrawal whose halves arrive separately is also recorded", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]     = { slots = 1 },
    [WARBAND_ID] = { slots = 1, [1] = { itemID = 171276, count = 2 } },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[WARBAND_ID][1] = nil
    NS.Ledger:ScheduleReconcile()
    mocks.__containers[BAG_ID][1] = { itemID = 171276, count = 2 }
    NS.Ledger:ScheduleReconcile()
    mocks.__fireTimers()
    assertEqual(NS.Database:Ledger()[NS.Database:Count()].direction, "WITHDRAW")
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger: two separate actions stay two separate rows", function()
  -- Debouncing must group by user action, not merge everything: a second deposit after the first
  -- pass has settled is its own movement.
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 2, [1] = { itemID = 171276, count = 1 },
                             [2] = { itemID = 2589, count = 1 } },
    [BANK_ID] = { slots = 2 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = 171276, count = 1 }
    NS.Ledger:ScheduleReconcile()
    mocks.__fireTimers()

    mocks.__containers[BAG_ID][2] = nil
    mocks.__containers[BANK_ID][2] = { itemID = 2589, count = 1 }
    NS.Ledger:ScheduleReconcile()
    mocks.__fireTimers()
    assertEqual(NS.Database:Count(), before + 2)
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 or e.itemID == 2589 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger:ScheduleReconcile does nothing when no frame is open", function()
  NS.Ledger:CancelPendingReconcile()
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
  mocks.__timers = {}
  NS.Ledger:ScheduleReconcile()
  assertEqual(#mocks.__timers, 0, "no timer armed outside a bank")
end)

test("Ledger:CloseContext runs the pending pass instead of waiting out the debounce", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 171276, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = 171276, count = 1 }
    NS.Ledger:ScheduleReconcile()
    NS.Ledger:CloseContext()   -- the frame closes before the timer would have fired
    assertEqual(NS.Database:Count(), before + 1, "the in-flight movement was not lost")
    assertEqual(mocks.__fireTimers(), 0, "and the pending timer was cancelled, not left to double-fire")
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
end)

-- ── Settling: halves that arrive SECONDS apart ─────────────────────────────────
-- Debouncing groups events that arrive together. It cannot help when the two sides of one movement
-- are a server round-trip apart — the live warband bank took over a second. So the baseline is held
-- whenever a pass sees a one-sided change, instead of advancing past a transaction still in flight.

test("Ledger.SnapshotsDiffer spots a change on any side", function()
  local base = { bags = { [1] = 1 }, stores = { BANK = { [2] = 1 } }, money = 5 }
  assertFalse(NS.Ledger.SnapshotsDiffer(base, base), "identical")
  assertTrue(NS.Ledger.SnapshotsDiffer(base,
    { bags = {}, stores = { BANK = { [2] = 1 } }, money = 5 }), "bags changed")
  assertTrue(NS.Ledger.SnapshotsDiffer(base,
    { bags = { [1] = 1 }, stores = { BANK = {} }, money = 5 }), "a store changed")
  assertTrue(NS.Ledger.SnapshotsDiffer(base,
    { bags = { [1] = 1 }, stores = { BANK = { [2] = 1 } }, money = 9 }), "money changed")
end)

test("Ledger: a movement whose halves are SECONDS apart is still recorded", function()
  -- The live repro that debouncing alone could not reach: the bags update, a whole second passes
  -- with several reconcile passes in between, and only then does the warband tab catch up.
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = 171276, count = 9 } },
    [WARBAND_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")

    -- The bags drop the stack. Several passes fire while the warband tab is still stale.
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:Reconcile()
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "nothing recorded yet — only one side has moved")

    -- A second later the warband tab reflects it.
    mocks.__now = mocks.__now + 1
    mocks.__containers[WARBAND_ID][1] = { itemID = 171276, count = 9 }
    NS.Ledger:Reconcile()

    assertEqual(NS.Database:Count(), before + 1, "the held baseline still saw the bags half")
    local e = NS.Database:Ledger()[NS.Database:Count()]
    assertEqual(e.store, "WARBAND_BANK")
    assertEqual(e.direction, "DEPOSIT")
    assertEqual(e.quantity, 9)
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
  assertEqual(NS.Database:Count(), before)
end)

-- Money end-to-end, through the real reconcile path. The Diff tests prove the rule; these two prove
-- the rule survives the settle machinery, which is where a corroborated movement could still be
-- lost (the store's balance lands a pass later than the purse).

test("Ledger: gold spent at the bank window is not recorded as a warband deposit", function()
  -- F-001, end to end: buying a bank tab. The purse falls by 1000g and the warband bank receives
  -- nothing. Before C-001 this wrote a permanent "1000g deposited to the Warband Bank" row.
  local before = NS.Database:Count()
  local savedMoney, savedWarband = mocks.__money, mocks.__warbandMoney
  withContainers({ [BAG_ID] = { slots = 1 }, [WARBAND_ID] = { slots = 1 } }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__money = mocks.__money - 10000000
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "the purse moved alone — nothing is provable")

    -- And it must not sit in the held baseline waiting to pair with something later either.
    mocks.__now = mocks.__now + NS.Ledger.SETTLE_TIMEOUT_SECONDS + 1
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "still no phantom row after the baseline re-anchors")
  end)
  mocks.__money, mocks.__warbandMoney = savedMoney, savedWarband
end)

test("Ledger: a real gold deposit still records when the store balance lands a pass later", function()
  -- The corroboration must not cost real rows. The purse updates on PLAYER_MONEY; the store's own
  -- balance can lag. The held baseline is what carries the purse half across to the pass that sees
  -- the other half — the same mechanism the item path already relies on.
  local before = NS.Database:Count()
  local savedMoney, savedWarband = mocks.__money, mocks.__warbandMoney
  withContainers({ [BAG_ID] = { slots = 1 }, [WARBAND_ID] = { slots = 1 } }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__money = mocks.__money - 500000
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "nothing recorded yet — the balance has not landed")

    mocks.__now = mocks.__now + 1
    mocks.__warbandMoney = mocks.__warbandMoney + 500000
    NS.Ledger:Reconcile()

    assertEqual(NS.Database:Count(), before + 1, "the held baseline still saw the purse half")
    local e = NS.Database:Ledger()[NS.Database:Count()]
    assertEqual(e.kind, "MONEY")
    assertEqual(e.store, "WARBAND_BANK")
    assertEqual(e.direction, "DEPOSIT")
    assertEqual(e.quantity, 500000)
  end)
  mocks.__money, mocks.__warbandMoney = savedMoney, savedWarband
  NS.Database:Delete(function(e) return e.kind == "MONEY" and e.quantity == 500000 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger: a one-sided change that never completes re-anchors after the timeout", function()
  -- Loot landing in the bags while the bank is open never balances. The baseline must not stay
  -- pinned for the rest of the session, or a stale delta would eventually pair with something
  -- unrelated and invent a movement.
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = { itemID = 19019, count = 1 }   -- looted, not withdrawn
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "not a movement")

    mocks.__now = mocks.__now + NS.Ledger.SETTLE_TIMEOUT_SECONDS + 1
    NS.Ledger:Reconcile()

    -- The baseline has re-anchored, so the loot is now part of the accepted state.
    assertFalse(NS.Ledger.SnapshotsDiffer(NS.State.lastSnapshot,
      NS.Ledger:Snapshot("BANK_FRAME")), "baseline caught up")
    assertEqual(NS.Database:Count(), before, "and still no phantom row")
  end)
end)

test("Ledger: a re-anchored loot does not pair with a later unrelated deposit", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 2, [1] = { itemID = 2589, count = 1 } },
    [BANK_ID] = { slots = 2 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    -- Loot arrives in the bags and never balances; let it time out.
    mocks.__containers[BAG_ID][2] = { itemID = 19019, count = 1 }
    NS.Ledger:Reconcile()
    mocks.__now = mocks.__now + NS.Ledger.SETTLE_TIMEOUT_SECONDS + 1
    NS.Ledger:Reconcile()

    -- Now genuinely deposit the OTHER item.
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = 2589, count = 1 }
    NS.Ledger:Reconcile()

    assertEqual(NS.Database:Count(), before + 1, "exactly one row, for the real deposit")
    assertEqual(NS.Database:Ledger()[NS.Database:Count()].itemID, 2589)
  end)
  NS.Database:Delete(function(e) return e.itemID == 2589 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger: an unchanged world advances the baseline without waiting", function()
  withContainers({ [BAG_ID] = { slots = 1 }, [BANK_ID] = { slots = 1 } }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    NS.Ledger:Reconcile()
    assertEqual(NS.Ledger._settleSince, nil, "nothing in flight, nothing to wait for")
  end)
end)

test("Ledger: a completed movement clears the settle wait", function()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 171276, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:Reconcile()                       -- one-sided: starts waiting
    assertTrue(NS.Ledger._settleSince ~= nil, "waiting for the other half")
    mocks.__containers[BANK_ID][1] = { itemID = 171276, count = 1 }
    NS.Ledger:Reconcile()                       -- completes
    assertEqual(NS.Ledger._settleSince, nil, "wait cleared")
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
end)

-- ── The settle wait must not poll ──────────────────────────────────────────────
-- Deleting an item with the bank open is a one-sided change that will never balance. Waiting it out
-- is correct; rescanning every half-second for the whole window is not — each pass walks the bags,
-- six bank tabs and five warband tabs. The other half of a real movement always arrives with an
-- event, so the timer is a give-up deadline rather than a poll.

test("Ledger: a deletion writes no row and arms ONE deadline, not a poll", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 19019, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[BAG_ID][1] = nil          -- deleted, not deposited
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "a deletion is not a movement")
    assertEqual(#mocks.__timers, 1, "one deadline armed")
  end)
end)

test("Ledger: the deadline is armed for the REMAINING window, not a fixed retry", function()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 19019, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:Reconcile()
    assertEqual(mocks.__timers[1].delay, NS.Ledger.SETTLE_TIMEOUT_SECONDS,
      "the first wait covers the whole window")

    -- An event arrives partway through and re-checks; the deadline must survive, shortened.
    mocks.__now = mocks.__now + 4
    mocks.__timers = {}
    NS.Ledger:Reconcile()
    assertEqual(mocks.__timers[1].delay, NS.Ledger.SETTLE_TIMEOUT_SECONDS - 4,
      "re-armed on what is left, so the deadline cannot be pushed out forever")
  end)
end)

test("Ledger: the deadline never schedules a near-zero timer", function()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 19019, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:Reconcile()
    mocks.__now = mocks.__now + NS.Ledger.SETTLE_TIMEOUT_SECONDS - 0.1
    mocks.__timers = {}
    NS.Ledger:Reconcile()
    assertTrue(mocks.__timers[1].delay >= NS.Ledger.SETTLE_MIN_RECHECK_SECONDS,
      "floored, got " .. tostring(mocks.__timers[1].delay))
  end)
end)

test("Ledger: firing the deadline re-anchors and stops waiting", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 19019, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:Reconcile()

    mocks.__now = mocks.__now + NS.Ledger.SETTLE_TIMEOUT_SECONDS
    mocks.__fireTimers()

    assertEqual(NS.Ledger._settleSince, nil, "no longer waiting")
    assertEqual(NS.Database:Count(), before, "and still no phantom row")
    assertEqual(#mocks.__timers, 0, "nothing left armed")
  end)
end)

-- ── Guild bank ─────────────────────────────────────────────────────────────────
-- The guild bank has its own API family AND a prerequisite the container stores do not have: a tab
-- returns nothing until it has been QUERIED. Only the tab you are looking at is populated for free,
-- so without the query the scan sees an almost-empty guild bank whatever is really in it.

test("Ledger:ScanGuildBank sees nothing from a tab that was never queried", function()
  mocks.__guildQueried = {}
  assertEqual(next(NS.Ledger:ScanGuildBank()), nil, "unqueried tabs report nothing")
end)

test("Ledger:QueryGuildBankTabs asks for every tab", function()
  mocks.__guildQueried, mocks.__guildQueryCount = {}, 0
  assertEqual(NS.Ledger:QueryGuildBankTabs(), 8)
  assertEqual(mocks.__guildQueryCount, 8, "one query per tab")
end)

test("Ledger:ScanGuildBank reads a tab once it has been queried", function()
  mocks.__guildQueried = {}
  NS.Ledger:QueryGuildBankTabs()
  assertEqual(NS.Ledger:ScanGuildBank()[2589], 5)
end)

test("Ledger:OpenContext queries the guild bank tabs on open", function()
  mocks.__guildQueried, mocks.__guildQueryCount = {}, 0
  NS.Ledger:OpenContext("GUILD_BANK")
  assertEqual(mocks.__guildQueryCount, 8, "opening the frame populates every tab")
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
end)

test("Ledger:OpenContext does NOT query guild tabs for the bank frame", function()
  mocks.__guildQueried, mocks.__guildQueryCount = {}, 0
  NS.Ledger:OpenContext("BANK_FRAME")
  assertEqual(mocks.__guildQueryCount, 0)
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
end)

test("Ledger: a guild-bank deposit is recorded", function()
  local before = NS.Database:Count()
  local savedTabs = mocks.__guildTabs
  mocks.__guildTabs = { [1] = {} }
  mocks.__guildQueried = {}
  local savedBag = mocks.__containers[BAG_ID]
  mocks.__containers[BAG_ID] = { slots = 1, [1] = { itemID = 171276, count = 4 } }

  NS.Ledger:OpenContext("GUILD_BANK")
  mocks.__containers[BAG_ID][1] = nil
  mocks.__guildTabs[1][1] = { itemID = 171276, count = 4 }
  NS.Ledger:Reconcile()

  assertEqual(NS.Database:Count(), before + 1)
  local e = NS.Database:Ledger()[NS.Database:Count()]
  assertEqual(e.store, "GUILD_BANK")
  assertEqual(e.direction, "DEPOSIT")
  assertEqual(e.quantity, 4)
  assertEqual(e.guild, "Ka0s", "guild-bank rows carry the guild name")

  NS.Database:Delete(function(x) return x.itemID == 171276 end)
  mocks.__guildTabs, mocks.__containers[BAG_ID] = savedTabs, savedBag
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
end)

test("Ledger:Diagnose reports the guild-bank API and per-tab contents", function()
  mocks.__guildQueried = {}
  NS.Ledger:QueryGuildBankTabs()
  local text = table.concat(NS.Ledger:Diagnose(), "\n")
  assertTrue(text:find("guild bank API:", 1, true) ~= nil, "which globals exist")
  assertTrue(text:find("guild bank tabs=8", 1, true) ~= nil)
  assertTrue(text:find("  tab 1: 1 / 1", 1, true) ~= nil, "per-tab filled/distinct counts")
end)

test("Compat.GetGuildBankSlot survives a build with no guild-bank API", function()
  -- Both getters are guarded independently: a build that keeps one and retires the other must
  -- degrade to "no data" rather than raise part-way through a scan.
  local savedLink = mocks.GetGuildBankItemLink
  mocks.GetGuildBankItemLink = nil
  local ok, result = pcall(function() return NS.Compat.GetGuildBankSlot(1, 1) end)
  mocks.GetGuildBankItemLink = savedLink
  assertTrue(ok, "no error")
  assertEqual(result, nil)
end)

-- ── The guild bank arms itself on data, not on an open event ───────────────────
-- GUILDBANKFRAME_OPENED is a valid event name that registers without complaint and then never
-- fires on 12.0.7, so waiting for it left the addon permanently unarmed and every guild deposit
-- unrecorded. Tab contents arriving is the signal that actually happens.

local function clearContext()
  NS.State.openContext, NS.State.lastSnapshot, NS.Ledger._settleSince = nil, nil, nil
end

test("Ledger:OnGuildBankData arms the guild bank when nothing else is open", function()
  clearContext()
  mocks.__guildQueried = {}
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "GUILD_BANK", "data arriving is what arms it")
  assertTrue(NS.State.lastSnapshot ~= nil, "and takes a baseline")
  clearContext()
end)

test("Ledger:OnGuildBankData queries the tabs when it arms", function()
  clearContext()
  mocks.__guildQueried, mocks.__guildQueryCount = {}, 0
  NS.Ledger:OnGuildBankData()
  assertEqual(mocks.__guildQueryCount, 8)
  clearContext()
end)

test("Ledger:OnGuildBankData never steals the context from an open bank frame", function()
  clearContext()
  NS.Ledger:OpenContext("BANK_FRAME")
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "BANK_FRAME", "the bank frame has its own events")
  clearContext()
end)

test("Ledger:OnGuildBankData re-arms without churning the baseline once armed", function()
  clearContext()
  NS.Ledger:OnGuildBankData()
  local first = NS.State.lastSnapshot
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "GUILD_BANK")
  assertTrue(NS.State.lastSnapshot == first, "a second data event does not re-baseline")
  clearContext()
end)

test("Ledger: a guild-bank deposit is recorded with no open event at all", function()
  local before = NS.Database:Count()
  local savedTabs, savedBag = mocks.__guildTabs, mocks.__containers[BAG_ID]
  mocks.__guildTabs, mocks.__guildQueried = { [1] = {} }, {}
  mocks.__containers[BAG_ID] = { slots = 1, [1] = { itemID = 171276, count = 7 } }
  clearContext()

  NS.Ledger:OnGuildBankData()                       -- window opened; contents arrive
  mocks.__containers[BAG_ID][1] = nil               -- deposited
  mocks.__guildTabs[1][1] = { itemID = 171276, count = 7 }
  NS.Ledger:OnGuildBankData()                       -- the tab update arrives
  NS.Ledger:Reconcile()

  assertEqual(NS.Database:Count(), before + 1)
  local e = NS.Database:Ledger()[NS.Database:Count()]
  assertEqual(e.store, "GUILD_BANK")
  assertEqual(e.direction, "DEPOSIT")
  assertEqual(e.quantity, 7)

  NS.Database:Delete(function(x) return x.itemID == 171276 end)
  mocks.__guildTabs, mocks.__containers[BAG_ID] = savedTabs, savedBag
  clearContext()
end)

test("Ledger: the guild bank disarms once its window has gone", function()
  clearContext()
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "GUILD_BANK")
  mocks.__guildVisible = false
  NS.Ledger:Reconcile()
  assertEqual(NS.State.openContext, nil, "stops rescanning six tabs on every bag update")
  mocks.__guildVisible = true
  clearContext()
end)

-- Disarming on the next Reconcile is not enough on its own. Closing the guild bank changes nothing,
-- so NO event fires afterwards and no reconcile pass runs — the context (and anything watching it)
-- would sit armed until some unrelated bag update happened along, possibly minutes later. The frame's
-- own OnHide is the only notice the client actually gives.

test("Ledger: hiding the guild-bank frame disarms it there and then, with no event", function()
  clearContext()
  NS.Ledger:OnGuildBankData()
  assertEqual(NS.State.openContext, "GUILD_BANK")
  mocks.__closeGuildBank()          -- no event, no bag change: just the window going away
  assertEqual(NS.State.openContext, nil, "the close is noticed immediately, not on the next event")
  mocks.__guildVisible = true
  clearContext()
end)

test("Ledger: the guild-bank OnHide hook is installed once, not once per data event", function()
  clearContext()
  local before = #mocks.__guildHideHooks
  NS.Ledger:OnGuildBankData()
  NS.Ledger:OnGuildBankData()
  NS.Ledger:OnGuildBankData()
  assertTrue(#mocks.__guildHideHooks <= before + 1, "a hook must never be stacked per event")
  clearContext()
end)

test("Ledger:Diagnose reports whether the guild-bank close hook is installed", function()
  clearContext()
  NS.Ledger:OnGuildBankData()
  local text = table.concat(NS.Ledger:Diagnose(), "\n")
  assertTrue(text:find("guild bank close hook: installed", 1, true) ~= nil,
    "the one line that explains a guild session that will not end")
  clearContext()
end)

test("Ledger: hiding the guild-bank frame leaves an open BANK frame alone", function()
  -- The guild frame hides whenever it is not the window you are looking at. Closing the character
  -- bank's session on that basis would throw away a baseline that is still in use.
  clearContext()
  NS.Ledger:OpenContext("BANK_FRAME")
  mocks.__closeGuildBank()
  assertEqual(NS.State.openContext, "BANK_FRAME", "only the guild bank's own context is ended")
  mocks.__guildVisible = true
  clearContext()
end)

test("Ledger: an unknown window state does NOT disarm the guild bank", function()
  -- A build with no guild-bank frame to inspect reports nil, meaning "cannot tell". That must not
  -- be read as "hidden", or the guild bank would disarm itself instantly and permanently there.
  clearContext()
  NS.Ledger:OnGuildBankData()
  local savedFrame = mocks.GuildBankFrame
  mocks.GuildBankFrame = nil
  NS.Ledger:Reconcile()
  assertEqual(NS.State.openContext, "GUILD_BANK", "still armed when visibility is unknowable")
  mocks.GuildBankFrame = savedFrame
  clearContext()
end)

test("Compat.IsGuildBankVisible is three-valued", function()
  mocks.__guildVisible = true
  assertEqual(NS.Compat.IsGuildBankVisible(), true)
  mocks.__guildVisible = false
  assertEqual(NS.Compat.IsGuildBankVisible(), false)
  local savedFrame = mocks.GuildBankFrame
  mocks.GuildBankFrame = nil
  assertEqual(NS.Compat.IsGuildBankVisible(), nil, "no frame means unknown, not hidden")
  mocks.GuildBankFrame, mocks.__guildVisible = savedFrame, true
end)

-- ── Bonus-carrying links ───────────────────────────────────────────────────────
-- The scanned hyperlink is the only place an item's bonus IDs ever exist: GetItemInfo(itemID)
-- answers with the BASE item, so a link re-derived from the id has lost the variant that moved.
-- The export's wowhead URL is built from what these tests protect.

local SAMPLE_LINK = "|cffa335ee|Hitem:19019::::::::80:250::5:2:12801:13440|h[Thunderfury]|h|r"

test("Ledger:ScanStore hands back the first hyperlink seen for each item", function()
  mocks.__containers[0] = { slots = 2, [1] = { itemID = 19019, count = 1, link = SAMPLE_LINK },
                                       [2] = { itemID = 2589, count = 5 } }
  local links = {}
  local counts = NS.Ledger:ScanStore("BAGS", links)
  assertEqual(counts[19019], 1, "the counts map is unchanged by the link accumulator")
  assertEqual(links[19019], SAMPLE_LINK)
  assertEqual(links[2589], nil, "a slot with no link contributes none")
  mocks.__containers[0] = nil
end)

test("Ledger:Snapshot carries a links table beside the counts", function()
  mocks.__containers[0] = { slots = 1, [1] = { itemID = 19019, count = 1, link = SAMPLE_LINK } }
  local s = NS.Ledger:Snapshot("BANK_FRAME")
  assertEqual(s.links[19019], SAMPLE_LINK)
  assertEqual(s.bags[19019], 1, "counts stay a plain id -> count map")
  mocks.__containers[0] = nil
end)

test("Ledger.Diff attaches the observed link to a deposit", function()
  local before = snap({ [19019] = 1 }, {})
  before.links = { [19019] = SAMPLE_LINK }
  local moves = NS.Ledger.Diff(before, snap({}, { [19019] = 1 }), "BANK")
  assertEqual(moveFor(moves, 19019).link, SAMPLE_LINK,
    "the item has left the bags by the after-snapshot; the before-snapshot still knows it")
end)

test("Ledger.Diff attaches the observed link to a withdrawal", function()
  local before = snap({}, { [19019] = 1 })
  before.links = { [19019] = SAMPLE_LINK }
  local moves = NS.Ledger.Diff(before, snap({ [19019] = 1 }, {}), "BANK")
  assertEqual(moveFor(moves, 19019).link, SAMPLE_LINK)
end)

test("Ledger.Diff leaves the link nil when neither snapshot observed one", function()
  local moves = NS.Ledger.Diff(snap({ [2589] = 1 }, {}), snap({}, { [2589] = 1 }), "BANK")
  assertEqual(moveFor(moves, 2589).link, nil)
end)

test("Ledger:BuildEntry keeps the scanned link over the one derived from the id", function()
  local move = itemMove(19019, 1)
  move.link = SAMPLE_LINK
  assertEqual(NS.Ledger:BuildEntry(move).itemLink, SAMPLE_LINK)
end)

test("Ledger:BuildEntry falls back to the item cache's link when the move carries none", function()
  local e = NS.Ledger:BuildEntry(itemMove(19019, 1))
  assertTrue(type(e.itemLink) == "string" and e.itemLink:find("19019", 1, true) ~= nil,
    "still a usable link, just without bonuses")
end)
