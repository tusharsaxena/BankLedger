-- tests/test_reset_routes.lua — the ONE global reset (options-ui-§12), reached from every control.
--
-- options-ui-§12 puts the Master controls tab's *Reset all settings* button, the page's header
-- **Defaults** button, Blizzard's own Settings-window footer control and `/bl resetall` behind ONE
-- implementation, "so a player MUST NOT have to discover which of the two does more". Until
-- BankLedger-A-02 this addon had those four routes over TWO implementations: the button raised the
-- confirm-gated wholesale wipe, and the other three ran a schema walk that kept recorded history.
--
-- The owner took Option A (unify up). Every route now goes through `NS.Slash:RequestResetAll`, which
-- raises the confirm popup `KA0S_BANKLEDGER_RESETALL`; its OnAccept is `Sl:ResetEverything`. Since
-- schema v3 that one act is a PROFILE reset (options-ui-§12, "an addon with both"): it takes the
-- settings, both filter lists and the saved view, and keeps the account-wide recorded history,
-- which only `/bl purge` deletes.
--
-- A sibling of tests/test_panel.lua rather than more of it: that file sits at ~835 lines, and this
-- is one question (which act does each control reach, and what does the act do) asked across the
-- panel, the slash surface and the degraded install.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local P = NS.Panel
P:Register()

local S = dofile("tests/panel_support.lua")
local panel     = S.panel
local renderTab = S.renderTab

local Env = dofile("tests/degraded_env.lua")

local POPUP = "KA0S_BANKLEDGER_RESETALL"

--- Run `fn` with chat muted and StaticPopup_Show replaced by a recorder, on mock table `m`. Returns
--- the names shown, in order. The mock leaves StaticPopup_Show nil by default (tests/wow_mock.lua,
--- override 9), which is the no-popup fallback arm; installing it is what puts a route on the arm a
--- player's client takes.
local function withPopupSpy(fn, m)
  m = m or mocks
  local shown = {}
  local savedShow, savedChat = m.StaticPopup_Show, m.DEFAULT_CHAT_FRAME.AddMessage
  m.StaticPopup_Show = function(name) shown[#shown + 1] = name end
  m.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local ok, err = pcall(fn)
  m.StaticPopup_Show, m.DEFAULT_CHAT_FRAME.AddMessage = savedShow, savedChat
  if not ok then error(err, 0) end
  return shown
end

local function muted(fn)
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
end

-- A store that is NOT the fresh install: a recorded row, one id on each list, a saved view and a
-- changed setting. Dated NOW, so no retention pass could take the row: a reset no longer prunes
-- (the window is account-wide, owner decision D6), and a row gone here must be the reset's doing.
local function seedStore()
  NS.db.global.ledger = {
    { ts = os.time(), kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 2589 },
  }
  NS.db.profile.blacklist = { [2589] = true }
  NS.db.profile.whitelist = { [4306] = true }
  NS.db.profile.savedView = { tab = "insights" }
  NS.db.profile.settings.qualityThreshold = 4
end

local function assertStoreUntouched(route)
  assertEqual(#NS.db.global.ledger, 1, route .. " changed the ledger before the confirm")
  assertEqual(NS.Filters:Count(NS.Filters:Blacklist()), 1, route .. " cleared the blacklist")
  assertEqual(NS.Filters:Count(NS.Filters:Whitelist()), 1, route .. " cleared the whitelist")
  assertTrue(NS.db.profile.savedView ~= nil, route .. " discarded the saved view")
  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 4, route .. " reset a setting")
end

--- The Master controls tab's rendered "Reset all settings" button, clicked the way AceGUI would.
local function clickResetAllButton()
  local button
  for _, w in ipairs(renderTab("General", "Master controls")) do
    if w.type == "Button" and w.text == "Reset all settings" then button = w end
  end
  assertTrue(button ~= nil, "the Master controls tab lost its Reset all settings button")
  assertTrue(button.callbacks and type(button.callbacks.OnClick) == "function",
    "the Reset all settings button has no OnClick")
  button.callbacks.OnClick(button)
end

-- ── every control raises the ONE popup, and nothing happens before Yes ───────────────────────────

test("Reset routes: every reset control raises the one confirm popup and changes nothing before accept", function()
  -- red under: P:RestoreDefaults or Sl:CliResetAll going back to the schema walk (the store changes
  -- and no popup shows), or the Master controls button calling ResetEverything on the click.
  local routes = {
    { "the page Defaults (P:RestoreDefaults)", function() P:RestoreDefaults() end },
    { "the header Defaults action (defaultsOnClick)",
      function() rawget(panel("General"), "defaultsOnClick")() end },
    { "Blizzard's footer (OnDefault)", function() rawget(panel("General"), "OnDefault")() end },
    { "/bl resetall", function() NS.Slash:OnSlash("resetall") end },
    { "Master controls' Reset all settings", clickResetAllButton },
  }
  local ok, err = pcall(function()
    for _, route in ipairs(routes) do
      seedStore()
      local shown = withPopupSpy(route[2])
      assertEqual(#shown, 1, route[1] .. " showed " .. #shown .. " popups")
      assertEqual(shown[1], POPUP, route[1] .. " raised the wrong popup")
      assertStoreUntouched(route[1])
    end
  end)
  muted(function() NS.Slash:ResetEverything() end)
  if not ok then error(err, 0) end
end)

test("Reset routes: RequestResetAll is the single entry point, and the popup's Yes is ResetEverything", function()
  -- The popup's OnAccept is the one body. With no popup API (headless, or a stripped client) the
  -- request runs that body directly, which is the arm every older fallback here already took.
  -- red under: a route calling StaticPopup_Show itself, or OnAccept pointing anywhere else.
  assertTrue(type(NS.Slash.RequestResetAll) == "function", "NS.Slash:RequestResetAll is missing")
  local dialog = mocks.StaticPopupDialogs[POPUP]
  assertTrue(dialog ~= nil and type(dialog.OnAccept) == "function", "the popup is not registered")

  local saved, ran = NS.Slash.ResetEverything, 0
  NS.Slash.ResetEverything = function() ran = ran + 1 end
  local ok, err = pcall(function()
    dialog.OnAccept()
    assertEqual(ran, 1, "the popup's Yes does not run ResetEverything")
    NS.Slash:RequestResetAll()   -- StaticPopup_Show is nil in the mock: the fallback arm
    assertEqual(ran, 2, "with no popup API the request must still reset")
    withPopupSpy(function() NS.Slash:RequestResetAll() end)
    assertEqual(ran, 2, "with a popup API the request must only ask")
  end)
  NS.Slash.ResetEverything = saved
  if not ok then error(err, 0) end
end)

-- ── what Yes does ──────────────────────────────────────────────────────────────────────────────

test("Reset routes: accepting the popup resets both filter lists, savedView and the settings, keeps the ledger, ends test mode, closes the debug console and keeps db.global.minimap whole", function()
  -- The session-only rows are swept BY NAME (options-ui-§12): a profile reset cannot reach them,
  -- since neither lives in the profile. The console row's declared default is false (S.MASTER_SPEC).
  -- red under: dropping the DebugLog:Hide line from Sl:ResetEverything (the console stays open), a
  -- reset reaching db.global (the ledger or the minimap table), or one that skips the profile.
  local savedHide, savedPos = NS.db.global.minimap.hide, NS.db.global.minimap.minimapPos
  local ok, err = pcall(function()
    muted(function()
      seedStore()
      NS.db.global.minimap.hide = true
      NS.db.global.minimap.minimapPos = 123.5
      NS.Schema:Set("state.testMode", true)
      NS.DebugLog:Show()
    end)
    assertTrue(NS.LedgerTable:IsTestMode(), "precondition: test mode is on")
    assertTrue(NS.DebugLog:IsShown(), "precondition: the debug console is open")

    muted(function() mocks.StaticPopupDialogs[POPUP].OnAccept() end)

    assertEqual(#NS.db.global.ledger, 1, "the reset took recorded history")
    assertEqual(NS.Filters:Count(NS.Filters:Blacklist()), 0, "the blacklist survived")
    assertEqual(NS.Filters:Count(NS.Filters:Whitelist()), 0, "the whitelist survived")
    assertEqual(NS.db.profile.savedView, nil, "the saved view survived")
    assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0, "a setting survived")
    assertFalse(NS.LedgerTable:IsTestMode(), "test mode is still on")
    assertFalse(NS.DebugLog:IsShown(), "the debug console is still open")
    assertEqual(NS.Schema:Get("state.debugConsole"), false, "the console row does not read off")
    assertEqual(NS.db.global.minimap.hide, true, "the hidden minimap button came back")
    assertEqual(NS.db.global.minimap.minimapPos, 123.5, "the minimap button moved")
  end)
  NS.State.testRecords = nil
  NS.Browser:Hide()
  NS.DebugLog:Hide()
  NS.db.global.minimap.hide, NS.db.global.minimap.minimapPos = savedHide, savedPos
  if not ok then error(err, 0) end
end)

test("Reset routes: accepting the popup puts the ledger window's live view back to stock", function()
  -- Characterization of an in-memory copy. The reset empties db.profile.savedView, but the Browser
  -- holds the view it last painted in B.activeFilter. The profile handler asks the same owner to
  -- repaint (B:ClearFilters, onto the reset profile's view: stock) rather than re-implementing it,
  -- so the window does not keep filtering by a view the reset discarded.
  -- red under: dropping NS.Browser:ClearFilters from NS.OnProfileEvent's re-apply.
  local B = NS.Browser
  local ok, err = pcall(function()
    muted(function() B:ApplyView({ store = "BANK" }, "current") end)
    assertEqual((B.activeFilter.store or {}).BANK, true, "precondition: the live view filters by store")
    muted(function() mocks.StaticPopupDialogs[POPUP].OnAccept() end)
    assertEqual((B.activeFilter.store or {}).BANK, nil, "the live view still filters by the old store")
  end)
  muted(function() B:ApplyView(nil, "current") end)
  if not ok then error(err, 0) end
end)

-- ── the words a player reads ────────────────────────────────────────────────────────────────────

test("Reset routes: the resetall verb, the Defaults tooltip and the popup say it is this profile, that history is kept, and that it asks first", function()
  -- Until schema v3 every control here said history went with the reset, because it did. It is a
  -- profile reset now, and a player about to press it needs to know the ledger is safe.
  -- red under: restoring "including recorded history", or the no-profile popup wording.
  local verb
  for _, cmd in ipairs(NS.COMMANDS) do
    if cmd[1] == "resetall" then verb = cmd[2] end
  end
  assertEqual(verb, "Reset this profile's settings to defaults; history is kept (asks first)")
  local tip = panel("General").defaultsTooltip or ""
  assertTrue(tip:find("current profile", 1, true) ~= nil,
    "the Defaults tooltip does not name the profile: " .. tip)
  assertTrue(tip:find("history", 1, true) ~= nil, "the Defaults tooltip does not name history: " .. tip)
  assertTrue(tip:find("kept", 1, true) ~= nil, "the Defaults tooltip does not say history is kept: " .. tip)
  -- options-ui-§12's FIRST canonical wording, byte for byte: the one for an addon with a profile.
  assertEqual(mocks.StaticPopupDialogs[POPUP].text,
    "Reset this profile to the addon's defaults? Everything you have configured or added in it is "
      .. "discarded \226\128\148 your other profiles are not affected.")
end)

-- ── the degraded install ────────────────────────────────────────────────────────────────────────

test("Reset routes degraded: library-absent /bl resetall raises the same popup", function()
  -- The degraded arm used to carry its own bracketed row walk plus a Filters/ResetView wrap -- a
  -- second implementation of a reset that was already a second implementation. It is one call now.
  -- red under: restoring the degraded CliResetAll walk.
  local ns, m = Env.loadDegraded()
  ns:InitDB()
  ns.Schema:Set("settings.qualityThreshold", 4)
  ns.db.global.ledger = {
    { ts = os.time(), kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 2589 },
  }
  local shown = withPopupSpy(function() ns.Slash:OnSlash("resetall") end, m)
  assertEqual(#shown, 1, "one popup")
  assertEqual(shown[1], POPUP)
  assertEqual(ns.Schema:Get("settings.qualityThreshold"), 4, "the reset ran before the confirm")
  assertEqual(#ns.db.global.ledger, 1, "the ledger went before the confirm")

  -- Yes, on the same arm, is the same profile reset.
  local saved = m.DEFAULT_CHAT_FRAME.AddMessage
  m.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local ok, err = pcall(function() m.StaticPopupDialogs[POPUP].OnAccept() end)
  m.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  assertEqual(ns.Schema:Get("settings.qualityThreshold"), 0, "Yes did not reset the settings")
  assertEqual(#ns.db.global.ledger, 1, "Yes took recorded history")
end)
