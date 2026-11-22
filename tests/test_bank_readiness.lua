-- tests/test_bank_readiness.lua — the bank readiness guard (WoW Forever port design, ruling R8;
-- SYNTHESIS critic §2c). A bank that is still loading must never become the baseline a diff runs
-- against, because rows are append-only history and a phantom row cannot be taken back.
--
--   * PER CONTAINER. A bank container that reported slots on the last ready read and now reports 0
--     is not ready. "Every bank id reads 0" is too weak: a partly loaded bank (tab 1 ready, the
--     socketed tabs still 0 on WoW Forever) slips through it. The live memory is stored
--     (db.global.bankShape), so the first open after a login or /reload is guarded too.
--   * CanViewBank(Character). At a warband-only banker the character bank cannot be viewed, so it
--     is not read at all (BagSync v20.41's fix; a latent Retail bug).
--   * Not ready: no baseline at the open, the old baseline held mid-visit, and a re-read on the cue
--     events (BAG_CONTAINER_UPDATE and BANK_TABS_CHANGED join the existing ones). A read that stays
--     not ready past L.READY_TIMEOUT_SECONDS is accepted as the bank's new shape (re-anchored, never
--     diffed), so a bag taken out of a bank tab cannot silence the ledger.
--
-- Both clients, one behavior: every case runs on both kit profiles.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local L = NS.Ledger
local S = dofile("tests/ledger_support.lua")
local withContainers = S.withContainers
local BAG_ID, BANK_ID, WARBAND_ID = S.BAG_ID, S.BANK_ID, S.WARBAND_ID
local BANK_TAB_2 = mocks.Enum.BagIndex.CharacterBankTab_2
local CHARACTER = mocks.Enum.BankType.Character

local FLASK, CLOTH = 171276, 2589

local function contains(list, value)
  for _, v in ipairs(list or {}) do if v == value then return true end end
  return false
end

-- A visit: open the bank frame, run `fn`, close it. The timer queue is emptied first so a case can
-- count what the visit armed.
local function visit(fn)
  mocks.__timers = {}
  L:OpenContext("BANK_FRAME")
  if fn then fn() end
  L:CloseContext()
end

local function rowsOf(itemID)
  local n = 0
  for _, e in ipairs(NS.Database:Ledger()) do if e.itemID == itemID then n = n + 1 end end
  return n
end

local function dropRows()
  NS.Database:Delete(function(e) return e.itemID == FLASK or e.itemID == CLOTH end)
end

-- Runs `fn` with CanViewBank(Character) answering `answer`, then puts the mock back.
local function withCharacterView(answer, fn)
  local saved = mocks.__canViewBank[CHARACTER]
  mocks.__canViewBank[CHARACTER] = answer
  local ok, err = pcall(fn)
  mocks.__canViewBank[CHARACTER] = saved
  if not ok then error(err, 0) end
end

-- ── Compat ──────────────────────────────────────────────────────────────────────

test("readiness: Compat.CanViewCharacterBank answers C_Bank.CanViewBank(Enum.BankType.Character)", function()
  assertEqual(NS.Compat.CanViewCharacterBank(), true)
  withCharacterView(false, function()
    assertEqual(NS.Compat.CanViewCharacterBank(), false, "a warband-only banker")
  end)
  local saved = mocks.C_Bank.CanViewBank
  mocks.C_Bank.CanViewBank = nil
  local ok, answer = pcall(NS.Compat.CanViewCharacterBank)
  mocks.C_Bank.CanViewBank = saved
  assertTrue(ok, answer)
  assertNil(answer, "nil when this build cannot tell")
end)

test("readiness: Compat.CanViewCharacterBank is nil without Enum.BankType, false for a nil answer", function()
  local savedType = mocks.Enum.BankType
  mocks.Enum.BankType = nil
  local ok, answer = pcall(NS.Compat.CanViewCharacterBank)
  mocks.Enum.BankType = savedType
  assertTrue(ok, answer)
  assertNil(answer, "nil when the bank type cannot be named")
  local savedFn = mocks.C_Bank.CanViewBank
  mocks.C_Bank.CanViewBank = function() return nil end
  ok, answer = pcall(NS.Compat.CanViewCharacterBank)
  mocks.C_Bank.CanViewBank = savedFn
  assertTrue(ok, answer)
  assertEqual(answer, false, "a present API's nil answer reads false")
end)

test("readiness: ReadableStores drops the character bank only on an explicit false", function()
  local function hasBank()
    return contains(L:ReadableStores("BANK_FRAME"), "BANK")
  end
  assertTrue(hasBank(), "a character banker")
  withCharacterView(false, function() assertFalse(hasBank(), "a warband-only banker") end)
  local saved = mocks.C_Bank.CanViewBank
  mocks.C_Bank.CanViewBank = nil
  local ok, has = pcall(hasBank)
  mocks.C_Bank.CanViewBank = saved
  assertTrue(ok, has)
  assertTrue(has, "a build that cannot tell")
end)

-- ── The pure judgment, pinned (K101-BL-02 characterization) ────────────────────
-- The ids the readiness judgment answers for a shape against a memory, pinned before the ledger
-- read it from LibKa0s-Compat-1.0's UnreadyBankContainers (LibKa0s#101) and kept green after.
-- `unready` is the one call L:CheckReady makes: no purchased-tab count.
local function unready(shape, memory)
  return NS.Compat.UnreadyBankContainers(shape, memory)
end

local function idList(list) return list and table.concat(list, ",") or "nil" end

local JUDGED = {
  { "visit 2 with a partly loaded bank", { [6] = 2, [7] = 0, [8] = 0 }, { [6] = 2, [7] = 2, [8] = 3 }, "7,8" },
  { "visit 2 with every tab ready", { [6] = 2, [7] = 2 }, { [6] = 2, [7] = 2 }, "nil" },
  { "a first visit (no memory)", { [6] = 0, [7] = 0 }, {}, "nil" },
  { "an unbought tab (remembered at 0)", { [6] = 2, [7] = 0 }, { [6] = 2, [7] = 0 }, "nil" },
  { "a tab the memory never saw", { [6] = 2, [9] = 0 }, { [6] = 2 }, "nil" },
  { "a remembered tab the shape does not carry", { [6] = 2 }, { [6] = 2, [7] = 2 }, "nil" },
  { "a tab that grew", { [6] = 4 }, { [6] = 2 }, "nil" },
  { "every tab still loading", { [14] = 0, [6] = 0, [9] = 0 }, { [6] = 1, [9] = 1, [14] = 1 }, "6,9,14" },
}

for _, case in ipairs(JUDGED) do
  test("readiness: the judgment of " .. case[1] .. " is " .. case[4], function()
    assertEqual(idList(unready(case[2], case[3])), case[4])
  end)
end

test("readiness: without LibKa0s the container reads degrade (bags 0..5, no bank, nothing unready)", function()
  -- A partial install: core/Compat.lua's degraded stubs, never a second copy of the library's bodies.
  local ns = dofile("tests/degraded_env.lua").loadUpTo("core/Compat.lua", false)
  local groups = ns.Compat.ContainerGroups()
  assertEqual(table.concat(groups.bags, ","), "0,1,2,3,4,5")
  assertEqual(#groups.bank, 0)
  assertEqual(#groups.accountBank, 0)
  assertNil(ns.Compat.CanViewCharacterBank(), "cannot tell, so readable")
  assertNil(ns.Compat.UnreadyBankContainers({ [6] = 0 }, { [6] = 2 }), "no bank group to judge")
  assertEqual(next(ns.Compat.CONTAINER_PATTERNS_BY_CLIENT), nil)
end)

-- ── The cue events ──────────────────────────────────────────────────────────────

test("readiness: BAG_CONTAINER_UPDATE and BANK_TABS_CHANGED are capture cues on both clients", function()
  for _, event in ipairs({ "BAG_CONTAINER_UPDATE", "BANK_TABS_CHANGED" }) do
    assertTrue(contains(L.CLIENT_EVENTS, event), event .. " is registered with the client")
    assertTrue(type(L.HANDLERS[event]) == "function", event .. " has a handler")
    assertTrue(contains(NS.EventRecord.registered, event), event .. " bound at Enable")
  end
end)

test("readiness: a cue event with the bank open schedules one debounced re-read", function()
  withContainers({
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 1 },
  }, function()
    L:OpenContext("BANK_FRAME")
    for _, event in ipairs({ "BAG_CONTAINER_UPDATE", "BANK_TABS_CHANGED" }) do
      mocks.__timers = {}
      assertEqual(L:Dispatch(event, 0), 1, event .. " delivered")
      assertEqual(mocks.__fireTimers(), 1, event .. " armed one reconcile pass")
    end
    L:CloseContext()
  end)
end)

-- ── Per-container readiness ─────────────────────────────────────────────────────

test("readiness: a first visit takes its baseline even with tabs at 0 slots (no memory yet)", function()
  withContainers({
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 2 },
  }, function()
    L:OpenContext("BANK_FRAME")
    assertTrue(NS.State.lastSnapshot ~= nil, "genesis: the baseline is taken")
    L:CloseContext()
  end)
end)

-- The memory outlives the session (BL-REV). The documented WoW Forever case is the FIRST open after
-- a login or a /reload (BagSync: the bank is not always loaded when it first opens), so a memory
-- that died with the Lua state left exactly that visit unguarded. The live world's shape is kept in
-- db.global.bankShape under the record key; a simulated world's stays runtime-only.
local function storedShape()
  local all = NS.db.global.bankShape
  return all and all[NS.Util.PlayerKey()]
end

test("readiness: a visit writes the live bank's shape to SavedVariables under the record key", function()
  withContainers({
    [BAG_ID]     = { slots = 1 },
    [BANK_ID]    = { slots = 2 },
    [BANK_TAB_2] = { slots = 3 },
  }, function()
    visit()
    local shape = storedShape()
    assertTrue(type(shape) == "table", "db.global.bankShape holds this character's shape")
    assertEqual(shape[BANK_ID], 2)
    assertEqual(shape[BANK_TAB_2], 3)
  end)
  assertNil(storedShape(), "ForgetBankShape forgets the stored shape too")
end)

test("readiness: the first visit after a reload is guarded by the shape the last session stored", function()
  local before = rowsOf(FLASK)
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = FLASK, count = 3 } },
    [BANK_ID] = { slots = 2 },
  }, function()
    -- What the last session left: tab 2 had slots. This session has no runtime memory at all.
    NS.db.global.bankShape = { [NS.Util.PlayerKey()] = { [BANK_ID] = 2, [BANK_TAB_2] = 2 } }
    L:OpenContext("BANK_FRAME")                    -- tab 2 still loading (0 slots)
    assertNil(NS.State.lastSnapshot, "no baseline from a bank still loading on the first open")
    mocks.__containers[BAG_ID][1] = nil            -- the flasks are sold
    mocks.__containers[BANK_TAB_2] = { slots = 2, [1] = { itemID = FLASK, count = 3 } }   -- loaded
    L:Reconcile()
    assertTrue(NS.State.lastSnapshot ~= nil, "the first ready read is the baseline")
    L:CloseContext()
    mocks.__containers[BANK_TAB_2] = nil
  end)
  assertEqual(rowsOf(FLASK), before, "no phantom deposit on the first visit of a session")
  dropRows()
end)

test("readiness: visit 2 with a partly loaded bank takes no baseline", function()
  withContainers({
    [BAG_ID]     = { slots = 1 },
    [BANK_ID]    = { slots = 2 },
    [BANK_TAB_2] = { slots = 2, [1] = { itemID = FLASK, count = 3 } },
  }, function()
    visit()                                        -- visit 1: every tab ready
    local tab2 = mocks.__containers[BANK_TAB_2]
    mocks.__containers[BANK_TAB_2] = nil           -- visit 2: tab 2 still loading (0 slots)
    L:OpenContext("BANK_FRAME")
    assertNil(NS.State.lastSnapshot, "no baseline from a partly loaded bank")
    mocks.__containers[BANK_TAB_2] = tab2          -- the tab arrives
    L:Reconcile()
    assertTrue(NS.State.lastSnapshot ~= nil, "the first ready read is the baseline")
    assertEqual(NS.State.lastSnapshot.stores.BANK[FLASK], 3)
    L:CloseContext()
  end)
end)

test("readiness: a tab loading while the bags lose the same item writes no phantom deposit", function()
  -- The defect: the baseline was taken with tab 2 at 0 slots. Tab 2 then loads (its flasks appear)
  -- in the same pass as the bags lose the same flasks to a vendor, and the diff reads the pair as a
  -- deposit nobody made.
  local before = rowsOf(FLASK)
  withContainers({
    [BAG_ID]     = { slots = 1 },
    [BANK_ID]    = { slots = 2 },
    [BANK_TAB_2] = { slots = 2, [1] = { itemID = FLASK, count = 3 } },
  }, function()
    visit()
    local tab2 = mocks.__containers[BANK_TAB_2]
    mocks.__containers[BANK_TAB_2] = nil
    mocks.__containers[BAG_ID][1] = { itemID = FLASK, count = 3 }
    L:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = nil            -- sold
    mocks.__containers[BANK_TAB_2] = tab2          -- loaded
    L:Reconcile()
    L:CloseContext()
  end)
  assertEqual(rowsOf(FLASK), before, "no row")
  dropRows()
end)

test("readiness: a tab dropping to 0 mid-visit holds the baseline and writes no phantom withdrawal", function()
  local before = rowsOf(FLASK)
  withContainers({
    [BAG_ID]     = { slots = 1 },
    [BANK_ID]    = { slots = 2 },
    [BANK_TAB_2] = { slots = 2, [1] = { itemID = FLASK, count = 3 } },
  }, function()
    L:OpenContext("BANK_FRAME")
    local baseline = NS.State.lastSnapshot
    mocks.__timers = {}
    mocks.__containers[BANK_TAB_2] = nil           -- the tab reads 0 for a moment
    mocks.__containers[BAG_ID][1] = { itemID = FLASK, count = 3 }   -- and the same flasks are looted
    L:Reconcile()
    assertTrue(rawequal(NS.State.lastSnapshot, baseline), "the baseline is held")
    assertEqual(rowsOf(FLASK), before, "no withdrawal from a tab that only failed to answer")
    assertTrue(#mocks.__timers >= 1, "a re-read is armed for the deadline")
    L:CloseContext()
  end)
  dropRows()
end)

test("readiness: once the loading bank is ready, a real deposit is recorded", function()
  local before = rowsOf(CLOTH)
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = CLOTH, count = 5 } },
    [BANK_ID]    = { slots = 2 },
    [BANK_TAB_2] = { slots = 2, [1] = { itemID = FLASK, count = 3 } },
  }, function()
    visit()
    local tab2 = mocks.__containers[BANK_TAB_2]
    mocks.__containers[BANK_TAB_2] = nil
    L:OpenContext("BANK_FRAME")
    mocks.__containers[BANK_TAB_2] = tab2
    L:Dispatch("BANK_TABS_CHANGED")                -- the cue; the mock queue holds the pass
    mocks.__fireTimers()
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = CLOTH, count = 5 }
    L:Reconcile()
    L:CloseContext()
  end)
  assertEqual(rowsOf(CLOTH), before + 1, "the deposit")
  local e = NS.Database:Ledger()[NS.Database:Count()]
  assertEqual(e.store, "BANK")
  assertEqual(e.direction, "DEPOSIT")
  assertEqual(e.quantity, 5)
  dropRows()
end)

test("readiness: a movement made while the bank was loading mid-visit is recorded once it is ready", function()
  local before = rowsOf(CLOTH)
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = CLOTH, count = 5 } },
    [BANK_ID]    = { slots = 2 },
    [BANK_TAB_2] = { slots = 2, [1] = { itemID = FLASK, count = 3 } },
  }, function()
    L:OpenContext("BANK_FRAME")
    local tab2 = mocks.__containers[BANK_TAB_2]
    mocks.__containers[BANK_TAB_2] = nil
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = CLOTH, count = 5 }
    L:Reconcile()                                  -- not ready: held
    assertEqual(rowsOf(CLOTH), before)
    mocks.__containers[BANK_TAB_2] = tab2
    L:Reconcile()                                  -- ready: diffed against the held baseline
    L:CloseContext()
  end)
  assertEqual(rowsOf(CLOTH), before + 1, "the deposit made during the wait")
  dropRows()
end)

test("readiness: a tab that stays at 0 past the deadline is re-anchored, never diffed", function()
  -- A WoW Forever player can take an empty bag out of a bank tab: the tab really is gone. The guard
  -- must not silence the ledger for the rest of the session, so the read is accepted as the bank's
  -- new shape once L.READY_TIMEOUT_SECONDS have passed, as a fresh baseline with no diff.
  local before = rowsOf(CLOTH)
  local savedNow = mocks.__now
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = CLOTH, count = 5 } },
    [BANK_ID]    = { slots = 2 },
    [BANK_TAB_2] = { slots = 2 },
  }, function()
    visit()
    mocks.__containers[BANK_TAB_2] = nil           -- the bag was taken out
    L:OpenContext("BANK_FRAME")
    assertNil(NS.State.lastSnapshot)
    mocks.__now = savedNow + L.READY_TIMEOUT_SECONDS
    L:Reconcile()
    assertTrue(NS.State.lastSnapshot ~= nil, "re-anchored at the deadline")
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = CLOTH, count = 5 }
    L:Reconcile()
    L:CloseContext()
    -- The next visit remembers the new shape: 0 slots there is ready now.
    L:OpenContext("BANK_FRAME")
    assertTrue(NS.State.lastSnapshot ~= nil, "the new shape is remembered")
    L:CloseContext()
  end)
  mocks.__now = savedNow
  assertEqual(rowsOf(CLOTH), before + 1, "recording resumed after the re-anchor")
  dropRows()
end)

test("readiness: a tab that never had slots (an unbought tab) never blocks the baseline", function()
  withContainers({
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 2 },
  }, function()
    visit()
    L:OpenContext("BANK_FRAME")
    assertTrue(NS.State.lastSnapshot ~= nil)
    L:CloseContext()
  end)
end)

test("readiness: the bags have no guard (only bank containers are judged)", function()
  withContainers({
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 2 },
  }, function()
    visit()
    mocks.__containers[BAG_ID] = nil
    L:OpenContext("BANK_FRAME")
    assertTrue(NS.State.lastSnapshot ~= nil, "a 0-slot backpack is not a loading bank")
    L:CloseContext()
  end)
end)

test("readiness: the shape memory is the live world's, never a running simulation's", function()
  local live = L:ShapeMemory()
  local sim, host = NS.Sim, NS.SimHost
  local savedActive, savedWorld = sim.IsActive, host.world
  sim.IsActive, host.world = function() return true end, {}
  local ok, simMemory = pcall(L.ShapeMemory, L)
  sim.IsActive, host.world = savedActive, savedWorld
  assertTrue(ok, simMemory)
  assertFalse(rawequal(simMemory, live), "a simulated world has its own memory")
  assertTrue(rawequal(L:ShapeMemory(), live), "and the live one is untouched")
end)

-- ── CanViewBank(Character) ──────────────────────────────────────────────────────

test("readiness: at a warband-only banker the character bank is not read", function()
  local before = rowsOf(CLOTH)
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = CLOTH, count = 5 } },
    [BANK_ID] = { slots = 2 },
  }, function()
    withCharacterView(false, function()
      L:OpenContext("BANK_FRAME")
      local snap = NS.State.lastSnapshot
      assertTrue(snap ~= nil, "the baseline is taken")
      assertNil(snap.stores.BANK, "the character bank is not in the snapshot")
      mocks.__containers[BAG_ID][1] = nil
      mocks.__containers[BANK_ID][1] = { itemID = CLOTH, count = 5 }
      L:Reconcile()
      L:CloseContext()
    end)
  end)
  assertEqual(rowsOf(CLOTH), before, "no character-bank row from a bank that cannot be viewed")
  dropRows()
end)

test("readiness: at a warband-only banker the Warband Bank is still recorded", function()
  local before = rowsOf(CLOTH)
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = CLOTH, count = 5 } },
    [WARBAND_ID] = { slots = 2 },
  }, function()
    withCharacterView(false, function()
      L:OpenContext("BANK_FRAME")
      mocks.__containers[BAG_ID][1] = nil
      mocks.__containers[WARBAND_ID][1] = { itemID = CLOTH, count = 5 }
      L:Reconcile()
      L:CloseContext()
    end)
  end)
  assertEqual(rowsOf(CLOTH), before + 1)
  assertEqual(NS.Database:Ledger()[NS.Database:Count()].store, "WARBAND_BANK")
  dropRows()
end, T.WARBAND_ONLY)

test("readiness: a nil CanViewBank answer (cannot tell) still reads the character bank", function()
  local saved = mocks.C_Bank.CanViewBank
  mocks.C_Bank.CanViewBank = nil
  local ok, err = pcall(withContainers, {
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 2, [1] = { itemID = CLOTH, count = 1 } },
  }, function()
    L:OpenContext("BANK_FRAME")
    assertEqual(NS.State.lastSnapshot.stores.BANK[CLOTH], 1)
    L:CloseContext()
  end)
  mocks.C_Bank.CanViewBank = saved
  assertTrue(ok, err)
end)
