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
