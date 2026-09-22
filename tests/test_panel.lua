local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local P = NS.Panel

-- Registration is idempotent (`registered` guard), so one call at load time gives every case in this
-- suite the same three canvas frames the game would get. The bodies are NOT built here: each panel's
-- content is lazy on first OnShow (options-ui-§1), which never fires headless.
P:Register()

local S = dofile("tests/panel_support.lua")
local panel           = S.panel
local ctxFor          = S.ctxFor
local renderTab       = S.renderTab
local GENERAL_TABS    = S.GENERAL_TABS


-- ── The Settings framework contract (options-ui-§1) ────────────────────────────

test("Panel: every registered canvas frame is handed to the Settings framework", function()
  assertTrue(mocks.__settingsPanels["Ka0s Bank Ledger"] ~= nil, "landing page")
  assertTrue(mocks.__settingsPanels["General"] ~= nil, "General subcategory")
  -- And the Filters subcategory is GONE (R3), not registered-and-empty: its two lists are two of
  -- General's tabs now. A page left registered would be a second entry in the Blizzard sidebar
  -- opening onto nothing.
  assertTrue(mocks.__settingsPanels["Filters"] == nil, "the Filters subcategory must be gone")
end)

-- Blizzard's Settings window calls all three on the registered canvas — OnCommit on apply, OnDefault
-- from its own footer defaults control, OnRefresh on re-show. LibKa0s sets none of them, so this
-- stays the host's job (LIBKA0S-19, issue #11).
--
-- RAWGET, not `type(p.OnCommit)`, and that is the whole point of this case. The mock's frame stub
-- synthesizes a no-op function for ANY PascalCase key, so `type(p.OnCommit) == "function"` is true
-- whether or not a single line of this addon ever set it — which is what this test asserted from
-- the day it was written until a mutation proved it could not fail. rawget asks the only question
-- that matters: did the addon actually put something here?
test("Panel: each canvas frame defines OnCommit, OnDefault and OnRefresh", function()
  for _, name in ipairs({ "Ka0s Bank Ledger", "General" }) do
    local p = panel(name)
    assertEqual(type(rawget(p, "OnCommit")),  "function", name .. " OnCommit")
    assertEqual(type(rawget(p, "OnDefault")), "function", name .. " OnDefault")
    assertEqual(type(rawget(p, "OnRefresh")), "function", name .. " OnRefresh")
  end
end)

test("Panel: the landing page's OnDefault is inert — it manages no settings", function()
  local p = panel("Ka0s Bank Ledger")
  assertTrue(rawget(p, "defaultsOnClick") == nil, "no defaults action parked on the landing page")
  rawget(p, "OnDefault")()   -- must not raise
end)

-- The header Defaults button and Blizzard's own footer control must be ONE implementation, not two
-- that can drift.
--
-- Asserted as BEHAVIOR, not identity. It used to compare the two function objects, which worked
-- while the host set both from a single closure. LibKa0s-Options-1.0 minor 5 stamps an `OnDefault`
-- that FORWARDS to whatever the page parked as `defaultsOnClick` — so they are deliberately no
-- longer the same object, and identity was only ever a proxy for the thing that matters: calling
-- one runs the other.
test("Panel: OnDefault runs the same action as the header Defaults button", function()
  for _, name in ipairs({ "General" }) do
    local p = panel(name)
    local parked = rawget(p, "defaultsOnClick")
    assertTrue(parked ~= nil, name .. " parks a defaults action")
    local ran = 0
    p.defaultsOnClick = function() ran = ran + 1 end
    rawget(p, "OnDefault")()
    p.defaultsOnClick = parked
    assertEqual(ran, 1, name .. ": the footer control must reach the page's parked action")
  end
end)

-- Blizzard's footer control is NOT confirm-gated the way the body's "Reset all" button is, so the
-- General page's defaults action must stay non-destructive: settings and window geometry only, never
-- the ledger. The destructive path stays behind KA0S_BANKLEDGER_RESETALL.
test("Panel: the General defaults action resets settings but never the ledger", function()
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end

  NS.Schema:Set("settings.qualityThreshold", 4)
  local before = NS.Database:Count()

  local ok, err = pcall(function() panel("General").OnDefault() end)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end

  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0, "settings returned to stock")
  assertEqual(NS.Database:Count(), before, "the ledger is untouched")
end)

test("Panel: OnCommit and OnRefresh are inert — writes land immediately and OnShow refreshes", function()
  for _, name in ipairs({ "Ka0s Bank Ledger", "General" }) do
    local p = panel(name)
    p.OnCommit()
    p.OnRefresh()
  end
end)

-- ── Refresh on write (options-ui-§11 / §41) ────────────────────────────────────
--
-- An open panel MUST reflect live state after a mutation, and the write seam is where that
-- belongs. It was nowhere: NS.Schema:Set fired the row's onChange and stopped, so `/bl set` with
-- the settings window open left every widget showing the old value until the window was closed and
-- reopened. P:Refresh also walked P.general alone, so even once wired, every OTHER page stayed
-- stale — and the next page added would have inherited that silently.
--
-- The panel bodies are lazy and never build headless, so these drive the contract rather than the
-- widgets: a fake page is registered through the same registry the real ones use.

-- Register a throwaway page whose refresher just counts, and return { count, show, hide, remove }.
--
-- `_renderFn` and `_rendered` are set because the library treats a ctx WITHOUT a renderer as the
-- legacy shape and refreshes it ungated — deliberately, as the migration seam for a host adopting
-- the registry one page at a time. Every real page here declares a renderer, so a fake that did not
-- would be exercising a path this addon no longer has.
local function fakePage(shown)
  local ran = 0
  local ctx = {
    panel = mocks.__stubFrame(),
    refreshers = { function() ran = ran + 1 end },
    pageKey = "fake",
    _renderFn = function() end,
    _rendered = true,
  }
  ctx.panel.name = "Fake"
  if shown then ctx.panel:Show() else ctx.panel:Hide() end
  local reg = P.__pagesForTest()
  reg[#reg + 1] = ctx
  return {
    count  = function() return ran end,
    remove = function() reg[#reg] = nil end,
  }
end

test("Panel: a schema write refreshes an open page", function()
  local page = fakePage(true)
  local before = page.count()
  NS.Schema:Set("settings.enabled", not NS.Schema:Get("settings.enabled"))
  assertTrue(page.count() > before,
    "NS.Schema:Set must repaint an open panel — this is what `/bl set` was missing")
  page.remove()
end)

test("Panel: a schema write does NOT refresh a hidden page", function()
  -- One of General's refreshers walks the whole ledger to estimate the SavedVariables size, so an
  -- off-screen refresh is pure cost (F-018). The Blizzard window shows one subcategory at a time.
  local page = fakePage(false)
  local before = page.count()
  NS.Schema:Set("settings.enabled", not NS.Schema:Get("settings.enabled"))
  assertEqual(page.count(), before, "a hidden page must not be refreshed")
  page.remove()
end)

test("Panel: Refresh walks EVERY registered page, not just General", function()
  local a, b = fakePage(true), fakePage(true)
  local a0, b0 = a.count(), b.count()
  P:Refresh()
  assertTrue(a.count() > a0 and b.count() > b0, "both open pages refresh")
  b.remove(); a.remove()
end)

test("Panel: a bulk reset coalesces into exactly ONE refresh", function()
  -- Ten schema rows through the write seam would be ten refreshes, and ten ledger walks.
  local page = fakePage(true)
  local before = page.count()
  P:Batch(function()
    for _, row in ipairs(NS.Schema.Schema) do NS.Schema:Set(row.path, NS.Schema:Default(row.path)) end
  end)
  assertEqual(page.count() - before, 1, "one refresh for the whole batch")
  page.remove()
end)

test("Panel: Batch unwinds its depth on the error path", function()
  -- Latched above zero, the panel silently stops refreshing for the rest of the session and only
  -- /reload recovers it (options-ui-§11 makes the same point about a re-entrancy guard).
  local page = fakePage(true)
  local ok = pcall(function() P:Batch(function() error("boom") end) end)
  assertTrue(not ok, "Batch must re-raise")
  local before = page.count()
  NS.Schema:Set("settings.enabled", not NS.Schema:Get("settings.enabled"))
  assertTrue(page.count() > before, "refreshes must resume after a raising batch")
  page.remove()
end)

test("Panel: /bl resetall repaints, and only once", function()
  local page = fakePage(true)
  local before = page.count()
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  NS.Slash:CliResetAll()
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  assertEqual(page.count() - before, 1, "the whole reset is one repaint")
  page.remove()
end)

test("Panel: a refresher that raises does not stop the others", function()
  local reg = P.__pagesForTest()
  local ran = 0
  local ctx = { panel = mocks.__stubFrame(), pageKey = "fake",
    _renderFn = function() end, _rendered = true,
    refreshers = { function() error("bad widget") end, function() ran = ran + 1 end } }
  ctx.panel.name = "Fake"
  ctx.panel:Show()
  reg[#reg + 1] = ctx
  P:Refresh()
  assertEqual(ran, 1, "each refresher is pcall'd — one dead widget must not take the UI with it")
  reg[#reg] = nil
end)

-- ── The pages actually render (options-ui) ─────────────────────────────────────
--
-- New with the LibKa0s-Options-1.0 adoption, and it is the first coverage this panel has ever had.
-- Before it, the page bodies were built inside an OnShow closure the mock discarded, so nothing
-- from `AceGUI:Create` downwards was reachable: the whole schema → widget → write path could break
-- and the suite stayed green. Two things made it drivable — the mock now records and fires frame
-- scripts, and it takes the kit's real AceGUI widget factory instead of an inert `Create -> nil`.


--- The live ctx for a registered page, out of the library's own registry.
local function joined(t) return table.concat(t, "\n") end

test("Panel: every tab of the General page renders without the library reporting a failure", function()
  -- The library pcalls each page render and prints which page failed. That report is the only
  -- thing standing between a raise inside a bespoke widget and a settings page that silently stops
  -- half-way — which is exactly what a missing SetTitle did the first time this ran. Every tab is
  -- driven, because a raise inside one tab's afterGroup hook is invisible from any other tab.
  local total = 0
  for _, tab in ipairs(GENERAL_TABS) do
    local made, chat = renderTab("General", tab)
    assertFalse(joined(chat):find("failed to render", 1, true) ~= nil, tab .. ": " .. joined(chat))
    assertTrue(#made > 2, tab .. " drew almost nothing; got " .. #made)
    total = total + #made
  end
  assertTrue(total > 20, "expected a full page of widgets across the strip; got " .. total)
end)

test("Panel: the General page draws a tab strip, one button per schema group", function()
  -- The adoption itself (options-ui-§13). The strip's buttons are CreateFrame Buttons, not AceGUI
  -- widgets, so they never reach __created — they are recorded in the ctx's own tab layout, which
  -- is also what the strip re-places from when the canvas finally reports a real width.
  --
  -- Counted off __tabLayout.buttons and NOT off __tabKids: that ledger also holds the content panel
  -- the strip draws beneath itself, so it answers one more than the tab count and a case written
  -- against it would be asserting "six tabs" with the number seven.
  local c = ctxFor("General")
  renderTab("General", "Master controls")
  local layout = c.__tabLayout
  assertTrue(layout ~= nil, "no tab strip was laid out")
  assertEqual(#layout.buttons, #GENERAL_TABS, "one tab button per group")
  assertEqual(c.activeTab, "Master controls")

  -- And a click on another tab moves the strip rather than redrawing the same page.
  layout.buttons[2]:__fire("OnClick")
  assertEqual(c.activeTab, GENERAL_TABS[2], "clicking a tab must select it")
  c.activeTab = GENERAL_TABS[1]
end)

test("Panel: the strip's FIRST tab is Master controls, and it is not the Filters page's", function()
  -- options-ui-§15 in the drawn page rather than in the data, plus R3's merge: the strip's last
  -- button is the page that used to be a category of its own, and its body comes up under
  -- General's strip.
  --
  -- Dies under: splicing the composed rows anywhere but the head of S.Schema, or dropping the
  -- Filters entry from GENERAL_AFTER_TAB.
  local c = ctxFor("General")
  renderTab("General", "Master controls")
  local labels = {}
  for i, btn in ipairs(c.__tabLayout.buttons) do labels[i] = btn.__labelText or btn.text end
  assertEqual(labels[1] or GENERAL_TABS[1], GENERAL_TABS[1])

  local function bodyText(made)
    local out = {}
    for _, w in ipairs(made) do
      if w.type == "Label" and w.text then out[#out + 1] = w.text end
    end
    return table.concat(out, "\n")
  end
  c.activeSubTab = nil
  local black = bodyText(renderTab("General", "Filters"))
  assertTrue(black:find("never recorded", 1, true) ~= nil, "the blacklist blurb is missing")
  assertFalse(black:find("always recorded", 1, true) ~= nil, "the whitelist leaked onto Blacklist")
  c.activeSubTab["Filters"] = "whitelist"
  local white = bodyText(renderTab("General", "Filters"))
  assertTrue(white:find("always recorded", 1, true) ~= nil, "the whitelist blurb is missing")
  assertFalse(white:find("never recorded", 1, true) ~= nil, "the blacklist leaked onto Whitelist")
  c.activeSubTab = nil
  c.activeTab = GENERAL_TABS[1]
end)

-- ── Diagnostics (`/bl debug panel`) ────────────────────────────────────────────
-- P:Diagnose's OUTPUT LINES ARE THE PRODUCT: a human reads them while debugging the load-order
-- skinning race, so their order, wording and format specifiers are the contract. These cases pin
-- them against a hand-built button, because the real defaults button only exists once the library
-- has laid out a page against a live canvas.

local function withDefaultsBtn(btn, fn)
  local saved = P.general
  P.general = { panel = { defaultsBtn = btn } }
  local ok, err = pcall(fn)
  P.general = saved
  if not ok then error(err, 0) end
end

-- A texture stand-in. Passing nil for atlas/path exercises the tostring() the dump wraps them in.
local function fakeTexture(atlas, path, r, g, b, a, layer)
  return {
    GetAtlas = function() return atlas end,
    GetTexture = function() return path end,
    GetVertexColor = function() return r, g, b, a end,
    GetObjectType = function() return "Texture" end,
    GetDrawLayer = function() return layer end,
  }
end

test("Panel:Diagnose says so and stops when no defaults button was ever built", function()
  withDefaultsBtn(nil, function()
    local out = P:Diagnose()
    assertTrue(#out > 0, "the AceGUI preamble is always emitted")
    assertEqual(out[#out],
      "defaultsBtn=NIL \226\128\148 no button was built; anything on screen is not ours",
      "the NIL line is the LAST line — a missing button terminates the dump")
  end)
end)

test("Panel:Diagnose stops at a button with no frame", function()
  withDefaultsBtn({ type = "Button" }, function()
    local out = P:Diagnose()
    assertEqual(out[#out], "defaultsBtn.frame=NIL")
    assertEqual(out[#out - 1], "defaultsBtn type=table aceType=Button",
      "the type line is emitted before the frame is resolved")
  end)
end)

test("Panel:Diagnose dumps the frame, its parent chain and every scrap of its art", function()
  local nineSlice = {
    GetRegions = function()
      return fakeTexture("nineslice-border", nil, 0.2, 0.3, 0.4, 1, "BORDER")
    end,
  }
  local f = {
    NineSlice = nineSlice,
    GetObjectType = function() return "Button" end,
    IsShown = function() return true end,
    GetWidth = function() return 120 end,
    GetHeight = function() return 22.4 end,
    GetParent = function()
      return { GetName = function() return "BankLedgerGeneralPanel" end,
               GetParent = function()
                 return { GetObjectType = function() return "Frame" end }
               end }
    end,
    GetNormalTexture = function() return nil end,
    GetHighlightTexture = function()
      return fakeTexture(nil, "Interface\\Buttons\\UI-Panel-Button-Highlight", 1, 0.5, 0.25, 1)
    end,
    GetPushedTexture = function() return nil end,
    -- Region 2 is a FontString: the dump must skip it, because only textures carry the art.
    GetRegions = function()
      return fakeTexture(nil, "Interface\\Buttons\\UI-Panel-Button-Up", 1, 1, 1, 1, "BACKGROUND"),
             { GetObjectType = function() return "FontString" end }
    end,
    GetFontString = function()
      return { GetText = function() return "Defaults" end,
               GetTextColor = function() return 1, 0.82, 0 end }
    end,
  }

  withDefaultsBtn({ type = "Button", frame = f }, function()
    local out = P:Diagnose()
    -- The AceGUI preamble is asserted by VALUE, not by shape. Read as `LibStub.minors[<major>]`,
    -- it printed `minor=nil` for as long as the key was misspelled, and a `^AceGUI=` match was
    -- happy with that. The mock publishes the minor it registered (tests/wow_mock.lua,
    -- override 12), so the line has one correct rendering and this compares against it.
    local minor = mocks.LibStub.minors["AceGUI-3.0"]
    assertTrue(minor ~= nil, "the mock records no AceGUI minor — this case would assert nil")
    assertEqual(out[1], ("AceGUI=yes minor=%s"):format(tostring(minor)),
      "line 1 names the serving AceGUI and its minor")
    local tail = {}
    for i = 1, #out do
      if out[i]:find("^defaultsBtn ") then
        for j = i, #out do tail[#tail + 1] = out[j] end
        break
      end
    end
    local want = {
      "defaultsBtn type=table aceType=Button",
      "frame objectType=Button shown=true size=120x22",
      "parent chain: BankLedgerGeneralPanel < Frame(anon)",
      "normal: none",
      "highlight: atlas=nil texture=Interface\\Buttons\\UI-Panel-Button-Highlight "
        .. "vertex=1.00/0.50/0.25/1.00",
      "pushed: none",
      "btn: 2 regions",
      "  btn[1] BACKGROUND: atlas=nil texture=Interface\\Buttons\\UI-Panel-Button-Up "
        .. "vertex=1.00/1.00/1.00/1.00",
      "btn.NineSlice: 1 regions",
      "  btn.NineSlice[1] BORDER: atlas=nineslice-border texture=nil vertex=0.20/0.30/0.40/1.00",
      "label=\"Defaults\" color=1.00/0.82/0.00",
    }
    assertEqual(#tail, #want, "line count from the button down")
    for i = 1, #want do assertEqual(tail[i], want[i], "line " .. i) end
  end)
end)

-- ── the destructive reset (options-ui-§12) ──────────────────────────────────────────────────────

test("Slash: ResetEverything is WHOLESALE, not a list of things somebody kept current", function()
  -- This addon has NO PROFILE -- NS.defaults.global carries the ledger, the filter lists AND the
  -- settings -- so db:ResetProfile() would be a no-op and the rule translates: empty the
  -- account-wide store wholesale and merge the declared defaults back.
  --
  -- The old body was five enumerations (a purge, a schema walk, a filter-list clear and two window
  -- carve-outs) which between them happened to cover the whole table. That is the shape the rule
  -- forbids, for the reason it forbids a row-by-row sweep: it fails one release later, when
  -- something new is stored beside the ones the list names, and it fails silently.
  --
  -- The probe key is one no enumeration could have named, because it exists nowhere in this addon.
  -- red under: reinstating the purge + CliResetAll + ResetWindow composition.
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  NS.db.global.__probeNothingNames = { deep = { value = 1 } }

  NS.Slash:ResetEverything()

  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  assertEqual(NS.db.global.__probeNothingNames, nil,
    "a key no enumeration names survived the reset")
  -- And the declared defaults came back rather than the store being left empty.
  assertTrue(type(NS.db.global.settings) == "table", "the defaults did not come back")
end)

test("Slash: ResetEverything keeps db.global's IDENTITY, so nothing is left on a stale table", function()
  -- Modules capture NS.db.global at load. Replacing the table would leave every one of them
  -- pointing at the old one -- and a suite that re-reads NS.db.global on every access cannot see
  -- that. So the wipe is in place, which is what the real library does to a profile.
  -- red under: `db.global = deepcopyGlobal(NS.defaults.global)`.
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local before = NS.db.global

  NS.Slash:ResetEverything()

  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  assertEqual(NS.db.global, before, "the store was replaced rather than emptied")
end)

test("Slash: the restored store does not ALIAS the defaults table", function()
  -- A later write into db.global would otherwise reach back into NS.defaults.global and change what
  -- the NEXT reset restores -- a bug that only shows up on the second reset of a session.
  -- red under: copying the defaults by reference instead of deep.
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end

  NS.Slash:ResetEverything()
  NS.db.global.settings.__probeAlias = true

  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  assertEqual(NS.defaults.global.settings.__probeAlias, nil,
    "the store aliases the defaults table")
end)

test("Slash: both global resets end test mode, which no store wipe can reach", function()
  -- options-ui-§15 (standard v2.47.0): test mode is ended by Reset all settings, which is why the
  -- composed row declares `default = false`. `/bl resetall` and the Defaults button reach it through
  -- CliResetAll's row walk. The Master controls button's wholesale wipe empties db.global, and test
  -- mode was never in db.global, so ResetEverything ends it by name.
  --
  -- red under: dropping `testMode = false` from S.MASTER_SPEC's defaults, or the test-mode line in
  -- Sl:ResetEverything.
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local ok, err = pcall(function()
    NS.Schema:Set("state.testMode", true)
    assertTrue(NS.LedgerTable:IsTestMode(), "precondition: test mode is on")
    NS.Slash:CliResetAll()
    assertFalse(NS.LedgerTable:IsTestMode(), "/bl resetall left test mode on")
    NS.Schema:Set("state.testMode", true)
    assertTrue(NS.LedgerTable:IsTestMode(), "precondition: test mode is on again")
    NS.Slash:ResetEverything()
    assertFalse(NS.LedgerTable:IsTestMode(), "Reset all settings left test mode on")
  end)
  NS.State.testRecords = nil
  NS.Browser:Hide()
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
end)

-- ── the minimap button survives BOTH resets (launcher-§3, standard v2.54.0) ────────────────────
--
-- A player's minimap-button choice is a per-installation DISPLAY PREFERENCE, in the same class as
-- the angle they dragged the button to, and it survives a reset because of what kind of setting it
-- is -- not because of where it is stored. Until v2.54.0 the standard argued the second thing: that
-- *Reset all settings* is a profile reset and the table is global, so the reset cannot reach it.
--
-- BOTH HALVES OF THAT ARGUMENT FAIL IN THIS ADDON, which is one of the two shapes the amended rule
-- names. It has no profile, so its Reset all settings is a wholesale wipe of the account-wide store
-- that merged `minimap = { hide = false }` straight back. And the argument only ever spoke about
-- that one control, so the page-scoped Defaults button -- which walks every schema row carrying a
-- default -- reached the row from the other side. These two cases run the real acts and read the
-- STORED byte back, in both directions, because a case that only proved the row was declared
-- exempt would pass over a sweep that wrote it anyway.

local function withHiddenButton(fn)
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local savedHide, savedPos = NS.db.global.minimap.hide, NS.db.global.minimap.minimapPos
  local ok, err = pcall(fn)
  NS.db.global.minimap.hide, NS.db.global.minimap.minimapPos = savedHide, savedPos
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
end

test("Minimap row: the page Defaults button does not un-hide the button", function()
  -- The button is P:RestoreDefaults -> Sl:CliResetAll -> the library's walk over every schema row,
  -- and the Minimap button row IS a schema row (the Master controls composer emits it). So this
  -- sweep reached it, in an addon where the profile reasoning would otherwise have held.
  --
  -- red under: dropping minimap.hide from S.RESET_EXEMPT, or pointing the descriptor's
  -- applyDefault back at a bare S:Set.
  withHiddenButton(function()
    -- The player hid it, through the row's own sense: the checkbox says SHOWN, the key says hidden.
    NS.Schema:Set("minimap.hide", false)
    assertEqual(NS.db.global.minimap.hide, true, "precondition: the button is hidden")
    -- A control row on the same sweep, so a green result cannot mean the sweep did nothing at all.
    NS.Schema:Set("settings.qualityThreshold", 4)

    NS.Panel:RestoreDefaults()

    assertEqual(NS.db.global.minimap.hide, true,
      "the Defaults button walked the player's hidden button back to shown")
    assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0,
      "the sweep did not run at all, so this case proves nothing")

    -- And the other direction: a SHOWN button is not re-hidden either.
    NS.Schema:Set("minimap.hide", true)
    assertEqual(NS.db.global.minimap.hide, false, "precondition: the button is shown")
    NS.Panel:RestoreDefaults()
    assertEqual(NS.db.global.minimap.hide, false, "the Defaults button re-hid a shown button")
  end)
end)

test("Minimap row: Reset all settings does not un-hide the button, or move it", function()
  -- Sl:ResetEverything: the confirm-gated Master controls button, and the one options-ui-§12 calls
  -- for in an addon with no profile -- empty db.global wholesale, merge the declared defaults back.
  -- `minimap = { hide = false }` is one of those declared defaults.
  --
  -- LibDBIcon's `minimapPos` rides along in the same table and is asserted here for the same
  -- reason it is exempt: it is the angle the player dragged the button to, and the carve-out holds
  -- the TABLE rather than one key so a future key in it needs no second edit.
  --
  -- red under: removing the carve-out from Sl:ResetEverything, or narrowing it to `hide` alone.
  withHiddenButton(function()
    NS.Schema:Set("minimap.hide", false)
    NS.db.global.minimap.minimapPos = 217.5
    assertEqual(NS.db.global.minimap.hide, true, "precondition: the button is hidden")
    NS.db.global.settings.qualityThreshold = 4

    NS.Slash:ResetEverything()

    assertEqual(NS.db.global.minimap.hide, true,
      "the wholesale wipe put the button back on the player's minimap")
    assertEqual(NS.db.global.minimap.minimapPos, 217.5,
      "and back at the library's default angle")
    assertEqual(NS.db.global.settings.qualityThreshold, 0,
      "the wipe did not run at all, so this case proves nothing")
  end)
end)

test("Minimap row: a TARGETED /bl reset minimap.hide is not a sweep, and still works", function()
  -- launcher-§3 exempts the row from *Reset all settings* and from a page Defaults button. It says
  -- nothing about the player naming that one row, and refusing them would be a carve-out that ate a
  -- verb. The veto is bracket-scoped for exactly this reason.
  --
  -- red under: making S:ApplyDefault veto unconditionally.
  withHiddenButton(function()
    NS.Schema:Set("minimap.hide", false)
    assertEqual(NS.db.global.minimap.hide, true, "precondition: the button is hidden")
    local out = {}
    local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
    mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
    local ok, err = pcall(function() NS.Slash:OnSlash("reset minimap.hide") end)
    mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
    if not ok then error(err, 0) end
    assertEqual(NS.db.global.minimap.hide, false,
      "/bl reset minimap.hide must still put the row back to its default")
    assertTrue(table.concat(out, "\n"):find("minimap.hide", 1, true) ~= nil,
      "and echo what it wrote: " .. table.concat(out, "\n"))
  end)
end)

test("Slash: ResetEverything tells the bus ONCE, so the capture gate re-caches now", function()
  -- BANKLEDGER-R-01. The reset empties db.global and merges the declared defaults back, which
  -- changes every setting the Ledger caches on its hot path -- and it changed them silently. The
  -- Ledger re-caches on Ka0s_BankLedger_SettingsChanged and on nothing else, so until the next
  -- /reload the gate went on judging bank movements by the settings the player just destroyed.
  --
  -- ONCE, not once per key. The reset is one act; a broadcast per restored default would have
  -- every subscriber rebuild several times over for it, and the reason string would be a lie
  -- about what happened.
  -- red under: dropping the SendMessage, or moving it inside the merge loop.
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end

  local move = { kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 171276, quantity = 1 }
  NS.Filters:AddBlacklist(171276)
  assertEqual(NS.Ledger:GateReason(move), "blacklist", "precondition: the gate sees the list")

  local seen = {}
  local target = NS.NewBusTarget()
  target:RegisterMessage("Ka0s_BankLedger_SettingsChanged", function(_, reason)
    seen[#seen + 1] = reason
  end)
  NS.Slash:ResetEverything()
  target:UnregisterMessage("Ka0s_BankLedger_SettingsChanged")

  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  assertEqual(#seen, 1, "one reset, one broadcast")
  assertEqual(seen[1], "reset", "the reason names the act")
  assertEqual(NS.Ledger:GateReason(move), nil,
    "the gate is still judging movements by the settings the reset destroyed")
end)

test("Slash: ResetEverything traces the recorded entries it wiped, once", function()
  -- The wholesale reset empties db.global, and the recorded ledger goes with it. That is a purge of
  -- recorded data, which debug-logging-§8 requires traced (standard v2.44.0, debug-logging-§10),
  -- exactly as Database:Purge traces `/bl purge`. It traced nothing.
  -- red under: dropping the NS.Debug line from Sl:ResetEverything.
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local savedDebug = NS.State.debug
  NS.db.global.ledger = {
    { ts = os.time(), kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 2589 },
    { ts = os.time(), kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 4306 },
  }

  NS.State.debug = true
  NS.DebugLog:Clear()
  NS.Slash:ResetEverything()
  local lines = {}
  for _, line in ipairs(NS.DebugLog.buffer) do
    if line:find("reset-all", 1, true) then lines[#lines + 1] = line end
  end
  NS.DebugLog:Clear()
  NS.State.debug = savedDebug
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved

  assertEqual(#lines, 1, "one line for the one act")
  assertTrue(lines[1]:find("[Data]", 1, true) ~= nil, "under the [Data] tag the other purges use")
  assertTrue(lines[1]:find("wiped 2 ledger entries", 1, true) ~= nil,
    "the line names the count, got: " .. tostring(lines[1]))
end)

-- ── A bulk reset is ONE [Set] line (debug-logging-§10) ─────────────────────────────────────────

-- Every debug line one act writes, with logging on for the act alone and chat muted.
local function actLines(fn)
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local savedDebug = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  local ok, err = pcall(fn)
  local out = {}
  for _, line in ipairs(NS.DebugLog.buffer) do out[#out + 1] = line end
  NS.DebugLog:Clear()
  NS.State.debug = savedDebug
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

local function withTag(lines, tag)
  local out = {}
  for _, line in ipairs(lines) do
    if line:find(tag, 1, true) then out[#out + 1] = line end
  end
  return out
end

test("Panel: Defaults logs ONE [Set] reset all line, and no per-row [Set]", function()
  -- The header/footer Defaults button is P:RestoreDefaults, which runs the library's CliResetAll
  -- inside its bracket. The window re-anchoring after it writes geometry, a carve-out outside the
  -- seam, so it adds no [Set] line of its own.
  -- P:Batch wraps that walk, and it is not a bracket, so it adds no second line.
  -- red under: dropping bulkBegin/bulkEnd from the Slash descriptor.
  actLines(function() P:RestoreDefaults() end)   -- baseline: every row at its default
  NS.Schema:Set("settings.rowHoverAlpha", 0.3)
  NS.Schema:Set("settings.rowStripeAlpha", 0.2)
  local set = withTag(actLines(function() P:RestoreDefaults() end), "[Set]")
  assertEqual(#set, 1, "one line for the one act, got:\n" .. table.concat(set, "\n"))
  assertTrue(set[1]:find("[Set] reset all: 2 rows", 1, true) ~= nil, "got: " .. tostring(set[1]))
  assertEqual(NS.Schema:Get("settings.rowHoverAlpha"), 0.10, "the reset still happened")
end)

test("Panel: Defaults on a page already at its defaults logs 0 rows, and nothing per row", function()
  actLines(function() P:RestoreDefaults() end)
  local set = withTag(actLines(function() P:RestoreDefaults() end), "[Set]")
  assertEqual(#set, 1, "one line for the one act, got:\n" .. table.concat(set, "\n"))
  assertTrue(set[1]:find("[Set] reset all: 0 rows", 1, true) ~= nil, "got: " .. tostring(set[1]))
end)

test("Slash: ResetEverything logs its settings reset as ONE [Set] line, beside the [Data] line", function()
  -- The wholesale reset replaces every stored setting along with the ledger. It is not a walk through
  -- the helper, so the seam never runs, but debug-logging-§10 still wants the settings reset logged
  -- once, as a [Set] line worded by the act (the no-profile form of `reset profile '<name>' to
  -- defaults (N rows)`). N is the stored rows the wipe actually changes: a row already at its
  -- default is not counted, nor is the session-only console row, which lives outside db.global.
  -- The wording deliberately avoids "reset-all", so the [Data] case above still sees ONE such line.
  -- red under: dropping the [Set] line from Sl:ResetEverything, or counting every stored row (14).
  actLines(function() NS.Slash:ResetEverything() end)   -- baseline: every row at its default
  NS.Schema:Set("settings.qualityThreshold", 4)
  NS.Schema:Set("settings.trackMoney", false)
  NS.db.global.ledger = {
    { ts = os.time(), kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 2589 },
  }
  local lines = actLines(function() NS.Slash:ResetEverything() end)
  local set, data = withTag(lines, "[Set]"), withTag(lines, "[Data]")

  assertEqual(#data, 1, "the [Data] line for the ledger wipe is unchanged")
  assertEqual(#set, 1, "one [Set] line for the settings reset, got:\n" .. table.concat(set, "\n"))
  assertTrue(set[1]:find("[Set] reset account-wide settings to defaults (2 rows)", 1, true) ~= nil,
    "got: " .. tostring(set[1]))
  assertTrue(set[1]:find("reset-all", 1, true) == nil, "must not collide with the [Data] line's word")
end)

-- ── The two resets are two acts, and they must not wear one name ────────────────────────────────
--
-- options-ui-§12 requires the General page's Reset all settings control, the header/footer Defaults
-- button and `/bl resetall` to sit behind ONE implementation, "so a player MUST NOT have to
-- discover which of the two does more". This addon has three routes over TWO implementations, and
-- that divergence is a ratified row in docs/ARCHITECTURE.md ▸ Documented deviations.
--
-- These two cases exist so the divergence cannot drift: the first PINS the blast radii that are
-- actually shipping, so unifying them is a deliberate, visible change to this file rather than a
-- silent one; the second holds the mitigation the register row promises, which is that the two acts
-- are at least labeled apart while the split stands.

test("Slash: the two resets have DIFFERENT blast radii — the ledger survives exactly one", function()
  -- Dies under: pointing CliResetAll at ResetEverything (or the reverse) without also deleting the
  -- options-ui-§12 row from the deviation register and rewriting this case to match.
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  -- Dated NOW on purpose: resetting settings.retentionDays re-runs the retention cleanup, and a
  -- 1970-stamped row would be dropped as ancient rather than as part of a reset.
  local entry = { ts = os.time(), kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 2589 }

  NS.db.global.ledger = { entry }
  NS.Slash:CliResetAll()
  local afterCli = #NS.db.global.ledger

  NS.db.global.ledger = { entry }
  NS.Slash:ResetEverything()
  local afterEverything = #NS.db.global.ledger

  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  assertEqual(afterCli, 1, "/bl resetall and the Defaults button must leave recorded history alone")
  assertEqual(afterEverything, 0, "the confirm-gated button must empty the store wholesale")
end)

test("Slash: while the split stands, the button and the verb do NOT share a label", function()
  -- Two controls whose names are identical and whose blast radii are not is precisely what §12
  -- exists to prevent. The button keeps §12's canonical name because it is §12's act; the verb
  -- takes slash-commands-§3's own reference wording instead.
  --
  -- Dies under: restoring "Reset all settings" as the resetall verb's description.
  local button
  for _, w in ipairs(renderTab("General", "Master controls")) do
    if w.type == "Button" and w.text == "Reset all settings" then button = w.text end
  end
  assertTrue(button ~= nil, "the Master controls tab lost its Reset all settings button")

  local verb
  for _, cmd in ipairs(NS.COMMANDS) do
    if cmd[1] == "resetall" then verb = cmd[2] end
  end
  assertTrue(verb ~= nil, "the resetall verb is missing from NS.COMMANDS")
  assertTrue(verb ~= button,
    "two acts with two blast radii are advertised under one name: " .. tostring(verb))
end)
