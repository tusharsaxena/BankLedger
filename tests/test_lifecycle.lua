-- The addon object's own enable/disable cycle (core/BankLedger.lua).
--
-- AceAddon can disable and re-enable an addon at any point in a session, and every one of this
-- addon's four bus-driven modules gates its Enable behind a `_enabled` latch that nothing ever
-- cleared. A disable therefore stopped nothing and the enable that followed did nothing, so the
-- modules came back inert with no error anywhere. These cases pin both halves of the cycle: the
-- latch is released, and the re-enable does not leave the PREVIOUS run's bus subscriptions behind
-- it. The second half matters more than it looks — the modules subscribe on private AceEvent
-- targets that AceAddon has never seen and cannot tear down for them, and SessionWindow's
-- EntryAdded handler appends unconditionally (modules/SessionWindow.lua:149-154), so a stale
-- second subscription records every moved stack twice.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- The four OnEnable arms: three directly, Insights through the Browser (modules/Browser.lua:1186).
local MODULES = { "Ledger", "Browser", "SessionWindow", "Insights" }

local function entry()
  return {
    ts = 1770000000, char = "Mock-Realm", classFile = "MAGE",
    kind = "ITEM", direction = "DEPOSIT", store = "BANK",
    itemID = 2589, itemName = "Linen Cloth", quality = 1,
    itemType = "Tradegoods", itemSubType = "Cloth", quantity = 10,
  }
end

test("addon:OnDisable releases the _enabled latch on every module OnEnable arms", function()
  NS.addon:OnEnable()
  NS.addon:OnDisable()
  for _, name in ipairs(MODULES) do
    assertTrue(not NS[name]._enabled,
      name .. " is still latched enabled after OnDisable, so its Enable will early-return")
  end
end)

test("a disable then enable cycle leaves all four modules live again", function()
  NS.addon:OnEnable()
  NS.addon:OnDisable()
  NS.addon:OnEnable()
  for _, name in ipairs(MODULES) do
    assertTrue(NS[name]._enabled == true,
      name .. " stayed inert through a disable/enable cycle")
  end
end)

test("addon:OnDisable leaves _guildHooked alone — the hook it records is still installed", function()
  NS.addon:OnEnable()
  NS.Ledger._guildHooked = true
  NS.addon:OnDisable()
  assertTrue(NS.Ledger._guildHooked == true,
    "clearing _guildHooked would let the next Enable hook GuildBankFrame a second time")
  NS.addon:OnEnable()
end)

test("a disable then enable cycle does not subscribe the session window twice", function()
  NS.addon:OnEnable()
  NS.addon:OnDisable()
  NS.addon:OnEnable()
  NS.State.sessionActive = true
  NS.State.sessionEntries = {}
  NS.bus:SendMessage(NS.MSG.ENTRY_ADDED, entry())
  assertEqual(#NS.State.sessionEntries, 1,
    "one moved stack must be recorded once, not once per surviving subscription")
  NS.State.sessionActive = false
  NS.State.sessionEntries = {}
end)

-- The geometry belt's event half (#18). Browser and SessionWindow each register PLAYER_LOGOUT on
-- their own NS.NewBusTarget(), guarded by `if __ev.RegisterEvent`, and addon:OnDisable tears the
-- target down with UnregisterAllEvents. Under a harness whose Embed stamped no-op event methods
-- none of that was observable: the registration recorded nothing and the teardown cleared nothing,
-- so a misspelled handler or a registration that never happened still passed. The kit's Embed
-- records `__events`, so both halves are asserted here: the registration took, and it is gone
-- after OnDisable, along with the target's message subscriptions.
test("addon:OnDisable clears the PLAYER_LOGOUT the Browser and SessionWindow targets registered", function()
  NS.addon:OnEnable()
  local targets = { Browser = NS.Browser.__ev, SessionWindow = NS.SessionWindow.__ev }
  for name, ev in pairs(targets) do
    assertTrue(ev ~= nil, name .. " stood up no bus target")
    assertEqual(type(ev.__events and ev.__events.PLAYER_LOGOUT), "function",
      name .. "'s target did not record PLAYER_LOGOUT")
  end
  assertTrue(mocks.__msgRegistry[NS.MSG.LEDGER_CHANGED][targets.SessionWindow] ~= nil,
    "the session window's target is subscribed before the disable")

  NS.addon:OnDisable()
  for name, ev in pairs(targets) do
    assertTrue(ev.__events.PLAYER_LOGOUT == nil, name .. "'s PLAYER_LOGOUT survived OnDisable")
    assertTrue(mocks.__msgRegistry[NS.MSG.LEDGER_CHANGED][ev] == nil,
      name .. "'s LedgerChanged subscription survived OnDisable")
  end
  NS.addon:OnEnable()
end)

-- The addon object is the kit's (#19). The harness used to build it with a NewAddon of its own that
-- stamped only Print and no-op event methods, so the real embed's Printf never reached a suite and
-- the addon's own registrations recorded nothing. Production defines no Printf and calls none, so
-- the one the embed stamps is AceConsole's in the client too; what matters is that it is THERE, and
-- that the Print reclaim beside it still holds.
test("NS.addon carries the kit's Printf and records its own events", function()
  local AceConsole = mocks.LibStub("AceConsole-3.0")
  assertEqual(type(NS.addon.Printf), "function", "the AceConsole embed stamped no Printf")
  assertTrue(NS.addon.Printf == AceConsole.Printf, "the addon's Printf is not the kit's AceConsole mixin")
  assertTrue(NS.Print == NS.Util.print, "the Print reclaim no longer holds beside the embed")

  NS.addon:OnEnable()
  assertEqual(NS.addon.__events.PLAYER_ENTERING_WORLD, "OnEnterWorld")
  assertEqual(NS.addon.__events.PLAYER_REGEN_DISABLED, "OnCombatChanged")
  assertEqual(NS.addon.__events.PLAYER_REGEN_ENABLED, "OnCombatChanged")

  assertEqual(tostring(NS.addon), "BankLedger", "the kit's NewAddon names the object")
  assertTrue(mocks.LibStub("AceAddon-3.0"):GetAddon("BankLedger") == NS.addon,
    "and registers it for GetAddon")
end)

-- The retention prune is deferred off the login spike and runs once per session. Every PEW (a
-- zone, a /reload's loading screen) reaches OnEnterWorld, so the pending handle is what keeps a
-- second PEW inside the window from queuing a second prune, and the latch keeps every PEW after
-- the prune from queuing any.
test("OnEnterWorld arms the retention prune once per session", function()
  -- red under: dropping the cleanupPending check from addon:OnEnterWorld (core/BankLedger.lua).
  local st, db = NS.State, NS.Database
  local savedDone, savedPending, savedPrune = st.cleanupDone, st.cleanupPending, db.PruneOld
  local pruned = 0
  db.PruneOld = function() pruned = pruned + 1 end
  st.cleanupDone, st.cleanupPending = false, nil
  mocks.__timers = setmetatable({}, getmetatable(mocks.__timers))
  local ok, err = pcall(function()
    NS.addon:OnEnterWorld()
    NS.addon:OnEnterWorld()
    assertEqual(#mocks.__timers, 1, "two PEWs inside the window queued more than one prune")
    assertEqual(mocks.__timers[1].delay, 5, "the prune is deferred five seconds off the login spike")
    mocks.__fireTimers()
    assertEqual(pruned, 1, "the queued prune did not run")
    NS.addon:OnEnterWorld()
    assertEqual(#mocks.__timers, 0, "a PEW after the prune ran queued another")
  end)
  if st.cleanupPending and NS.addon.CancelTimer then NS.addon:CancelTimer(st.cleanupPending) end
  db.PruneOld = savedPrune
  st.cleanupDone, st.cleanupPending = savedDone, savedPending
  mocks.__timers = setmetatable({}, getmetatable(mocks.__timers))
  if not ok then error(err, 0) end
end)

-- ── One registration helper, one record (BL-06, events-frames-taint-§1) ─────────────────────
--
-- NS.StandUp used to register its three names with a bare self:RegisterEvent, BEFORE the three
-- module Enables. A raise on any of them aborted the stand-up there, so one refused name took the
-- whole capture engine and both windows down with it. Every registration now goes through
-- NS.RegisterEventSafely (core/CoreSetup.lua), which front-gates on C_EventUtils.IsEventValid and
-- pcalls what gets past it, and writes one record /bl debug scan reads.

local function has(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

test("a rejected event name in the stand-up does not stop Ledger:Enable", function()
  -- red under: a bare self:RegisterEvent in NS.StandUp (core/BankLedger.lua).
  NS.addon:OnDisable()
  mocks.__badEvents = { PLAYER_REGEN_DISABLED = true }
  local ok, err = pcall(NS.addon.OnEnable, NS.addon)
  mocks.__badEvents = {}
  local ledgerUp = NS.Ledger._enabled == true
  local bankBound = NS.addon.__events.BANKFRAME_OPENED ~= nil
  local recorded = has(NS.EventRecord.unavailable, "PLAYER_REGEN_DISABLED")
  -- Hand the build back whole: the refused name bound normally again.
  NS.addon:OnDisable()
  NS.addon:OnEnable()
  assertTrue(ok, err)
  assertTrue(ledgerUp, "the refused stand-up name aborted Ledger:Enable")
  assertTrue(bankBound, "BANKFRAME_OPENED is not registered after the refused name")
  assertTrue(recorded, "PLAYER_REGEN_DISABLED is not in NS.EventRecord.unavailable")
end)

test("C_EventUtils.IsEventValid rejects a name before any RegisterEvent call", function()
  local utils = mocks.C_EventUtils
  local saved = utils.IsEventValid
  utils.IsEventValid = function(name) return name ~= "RETIRED_EVENT" end
  local calls = 0
  local target = { RegisterEvent = function() calls = calls + 1 end }
  local ok, took = pcall(NS.RegisterEventSafely, target, "RETIRED_EVENT", function() end)
  utils.IsEventValid = saved
  local recorded = has(NS.EventRecord.unavailable, "RETIRED_EVENT")
  NS.addon:OnDisable()
  NS.addon:OnEnable()
  assertTrue(ok, took)
  assertTrue(took == false, "a name IsEventValid refuses was reported as bound")
  assertEqual(calls, 0, "RegisterEvent was reached for a name IsEventValid refuses")
  assertTrue(recorded, "the refused name is not in NS.EventRecord.unavailable")
end)

test("the stand-down clears the event record", function()
  NS.addon:OnEnable()
  assertTrue(#NS.EventRecord.registered > 0, "the stand-up recorded nothing — this case proves nothing")
  NS.addon:OnDisable()
  local registered, unavailable = #NS.EventRecord.registered, #NS.EventRecord.unavailable
  NS.addon:OnEnable()
  assertEqual(registered, 0, "the stand-down left names in NS.EventRecord.registered")
  assertEqual(unavailable, 0, "the stand-down left names in NS.EventRecord.unavailable")
end)
