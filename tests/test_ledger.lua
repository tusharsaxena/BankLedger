local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue =
  T.test, T.assertEqual, T.assertTrue

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

local S = dofile("tests/ledger_support.lua")
local withContainers = S.withContainers
local BAG_ID, BANK_ID, WARBAND_ID = S.BAG_ID, S.BANK_ID, S.WARBAND_ID


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

-- An upgraded drop: base item 171276 is Rare (3), and THIS one's bonus IDs make it Epic (4). The
-- id is the same either way, so an enrichment that asks the client about the id gets Rare and
-- writes Rare — permanently, because nothing re-resolves quality at display time (F-00x).
local UPGRADED_LINK = "|cffa335ee|Hitem:171276::::::::80:250::11:1:6652|h[Spectral Flask]|h|r"
local function withUpgradedVariant(fn)
  mocks.__itemVariants[UPGRADED_LINK] = { "Spectral Flask", 4, "Consumable", "Flask", 5000 }
  local ok, err = pcall(fn)
  mocks.__itemVariants[UPGRADED_LINK] = nil
  if not ok then error(err, 0) end
end

test("Ledger:BuildEntry takes the quality from the moved link, not the base item", function()
  withUpgradedVariant(function()
    local move = itemMove(171276, 1)
    move.link = UPGRADED_LINK
    local e = NS.Ledger:BuildEntry(move)
    assertEqual(e.quality, 4, "the deposited item was Epic; its base id is only Rare")
    assertEqual(e.itemLink, UPGRADED_LINK, "and the row still carries the link it was judged from")
  end)
end)

test("Ledger:BuildEntry still enriches from the id when the move carries no link", function()
  withUpgradedVariant(function()
    assertEqual(NS.Ledger:BuildEntry(itemMove(171276, 1)).quality, 3,
      "no observation to read, so the base item is the honest answer")
  end)
end)

test("Ledger:GateReason judges the quality gate on the moved link", function()
  withUpgradedVariant(function()
    withSettings({ qualityThreshold = 4 }, function()
      local move = itemMove(171276, 1)
      move.link = UPGRADED_LINK
      assertEqual(NS.Ledger:GateReason(move), nil,
        "an Epic-upgraded drop clears an Epic threshold its base id would fail")
      assertEqual(NS.Ledger:GateReason(itemMove(171276, 1)), "quality",
        "and an unobserved move of the same id is still judged as the base item")
    end)
  end)
end)

-- ── Characterization: the whole /bl debug scan dump (GI-BL-02) ───────────────────────────────
-- Pinned line for line before L:Diagnose was split below CCN 15. The event record and the hook
-- latch are swapped for fixed values so the golden does not depend on suite order.

local DIAG_MONEY = { __money = 1000000, __guildBankMoney = 65537936844, __warbandMoney = 16348260386,
  __characterBankMoney = 0 }

local function diagnoseWith(over, fn)
  local savedRec, savedHook = NS.EventRecord, NS.Ledger._guildHooked
  local saved = {}
  for k, v in pairs(DIAG_MONEY) do if over[k] == nil then over[k] = v end end
  for k, v in pairs(over) do saved[k] = mocks[k]; mocks[k] = (v ~= false) and v or nil end
  NS.EventRecord = { registered = { "A_EVENT", "B_EVENT" }, unavailable = { "GONE" } }
  NS.Ledger._guildHooked = true
  mocks.__containers[0] = { slots = 2, [1] = { itemID = 2589, count = 20 } }
  local ok, out = pcall(function() return NS.Ledger:Diagnose() end)
  mocks.__containers[0] = nil
  NS.EventRecord, NS.Ledger._guildHooked = savedRec, savedHook
  for k in pairs(over) do mocks[k] = saved[k] end
  if not ok then error(out, 0) end
  return fn(out)
end

local DIAG_GOLDEN = {
  "openContext=nil snapshot=no",
  "Enum.BagIndex has 20 members",
  "  BagIndex.Accountbanktab = -3", "  BagIndex.Characterbanktab = -2", "  BagIndex.Keyring = -1",
  "  BagIndex.Backpack = 0", "  BagIndex.Bag_1 = 1", "  BagIndex.Bag_2 = 2", "  BagIndex.Bag_3 = 3",
  "  BagIndex.Bag_4 = 4", "  BagIndex.ReagentBag = 5",
  "  BagIndex.CharacterBankTab_1 = 6", "  BagIndex.CharacterBankTab_2 = 7",
  "  BagIndex.CharacterBankTab_3 = 8", "  BagIndex.CharacterBankTab_4 = 9",
  "  BagIndex.CharacterBankTab_5 = 10", "  BagIndex.CharacterBankTab_6 = 11",
  "  BagIndex.AccountBankTab_1 = 12", "  BagIndex.AccountBankTab_2 = 13",
  "  BagIndex.AccountBankTab_3 = 14", "  BagIndex.AccountBankTab_4 = 15",
  "  BagIndex.AccountBankTab_5 = 16",
  "group BAGS = [0, 1, 2, 3, 4, 5]", "group BANK = [6, 7, 8, 9, 10, 11]",
  "group WARBAND_BANK = [12, 13, 14, 15, 16]",
  "container probe (id: slots / filled / distinct ids)",
  "  0: 2 / 1 / 1",
  "money=1000000",
  "money API: purse=function guildBank=function bankFetch=function bankTypes=true",
  "  Enum.BankType: Account=2, Character=0, Guild=1",
  "  GetGuildBankMoney(): 65537936844",
  "  C_Bank.FetchDepositedMoney(Account): 16348260386",
  "  C_Bank.FetchDepositedMoney(Character): 0",
  "guild bank API: link=function info=function query=function numTabs=function current=1 visible=true",
  "guild bank frame hooks: installed (frame=table)",
  "guild bank tabs=8 (tab: filled / distinct ids)",
  "  tab 1: 0 / 0", "  tab 2: 0 / 0", "  tab 3: 0 / 0", "  tab 4: 0 / 0",
  "  tab 5: 0 / 0", "  tab 6: 0 / 0", "  tab 7: 0 / 0", "  tab 8: 0 / 0",
  "events registered (2): A_EVENT, B_EVENT",
  "events UNAVAILABLE (1): GONE",
}

local function indexOf(lines, text)
  for i, l in ipairs(lines) do if l == text then return i end end
  return nil
end

test("Ledger:Diagnose characterization: the whole dump, line for line", function()
  diagnoseWith({}, function(out)
    assertEqual(table.concat(out, "\n"), table.concat(DIAG_GOLDEN, "\n"))
  end)
end)

test("Ledger:Diagnose characterization: a raising money reader reads ERROR, an absent one absent", function()
  diagnoseWith({ GetGuildBankMoney = function() error("boom", 0) end }, function(out)
    assertTrue(indexOf(out, "  GetGuildBankMoney(): ERROR boom") ~= nil, table.concat(out, " | "))
  end)
  diagnoseWith({ GetGuildBankMoney = false }, function(out)
    assertTrue(indexOf(out, "  GetGuildBankMoney(): absent") ~= nil)
    assertTrue(indexOf(out,
      "money API: purse=function guildBank=nil bankFetch=function bankTypes=true") ~= nil)
  end)
end)

test("Ledger:Diagnose characterization: no C_Bank, no BankType, no Account member", function()
  diagnoseWith({ C_Bank = false }, function(out)
    assertTrue(indexOf(out, "money API: purse=function guildBank=function bankFetch=nil bankTypes=true") ~= nil)
    assertEqual(indexOf(out, "  C_Bank.FetchDepositedMoney(Account): 16348260386"), nil)
    assertTrue(indexOf(out, "  Enum.BankType: Account=2, Character=0, Guild=1") ~= nil)
  end)
  local enum = {}
  for k, v in pairs(mocks.Enum) do enum[k] = v end
  enum.BankType = nil
  diagnoseWith({ Enum = enum }, function(out)
    assertTrue(indexOf(out, "money API: purse=function guildBank=function bankFetch=function bankTypes=false") ~= nil)
    for _, l in ipairs(out) do
      assertEqual(l:find("Enum.BankType", 1, true), nil, "a BankType line with no BankType")
      assertEqual(l:find("FetchDepositedMoney", 1, true), nil, "a fetch probe with no BankType")
    end
  end)
  local charOnly = {}
  for k, v in pairs(mocks.Enum) do charOnly[k] = v end
  charOnly.BankType = { Character = 0, Label = "x" }
  diagnoseWith({ Enum = charOnly }, function(out)
    assertTrue(indexOf(out, "  Enum.BankType: Character=0") ~= nil, "a non-number member was listed")
    assertEqual(indexOf(out, "  C_Bank.FetchDepositedMoney(Account): 16348260386"), nil)
    assertTrue(indexOf(out, "  C_Bank.FetchDepositedMoney(Character): 0") ~= nil)
  end)
end)

test("Ledger:Diagnose characterization: no BagIndex, ties sorted by name, unhooked, nothing refused", function()
  local enum = {}
  for k, v in pairs(mocks.Enum) do enum[k] = v end
  enum.BagIndex = { Zeta = 1, Alpha = 1, Skip = "x" }
  diagnoseWith({ Enum = enum }, function(out)
    assertEqual(out[2], "Enum.BagIndex has 2 members")
    assertEqual(out[3], "  BagIndex.Alpha = 1")
    assertEqual(out[4], "  BagIndex.Zeta = 1")
  end)
  enum.BagIndex = nil
  diagnoseWith({ Enum = enum }, function(out)
    assertEqual(out[2], "Enum.BagIndex has 0 members")
  end)
  local savedRec, savedHook = NS.EventRecord, NS.Ledger._guildHooked
  NS.EventRecord = { registered = {}, unavailable = {} }
  NS.Ledger._guildHooked = nil
  local ok, out = pcall(function() return NS.Ledger:Diagnose() end)
  NS.EventRecord, NS.Ledger._guildHooked = savedRec, savedHook
  assertTrue(ok, out)
  assertTrue(indexOf(out, "guild bank frame hooks: NOT INSTALLED (frame=table)") ~= nil)
  assertEqual(out[#out - 1], "events registered (0): ")
  assertEqual(out[#out], "events UNAVAILABLE (0): none")
end)
