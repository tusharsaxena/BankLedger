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

-- The four OnEnable arms: three directly, Insights through the Browser (modules/Browser.lua:1229).
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
  NS.bus:SendMessage("Ka0s_BankLedger_EntryAdded", entry())
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
  assertTrue(mocks.__msgRegistry["Ka0s_BankLedger_LedgerChanged"][targets.SessionWindow] ~= nil,
    "the session window's target is subscribed before the disable")

  NS.addon:OnDisable()
  for name, ev in pairs(targets) do
    assertTrue(ev.__events.PLAYER_LOGOUT == nil, name .. "'s PLAYER_LOGOUT survived OnDisable")
    assertTrue(mocks.__msgRegistry["Ka0s_BankLedger_LedgerChanged"][ev] == nil,
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
