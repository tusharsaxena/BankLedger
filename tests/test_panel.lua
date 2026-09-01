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

local function panel(name)
  local p = mocks.__settingsPanels[name]
  assertTrue(p ~= nil, "panel '" .. name .. "' was registered")
  return p
end

-- ── The Settings framework contract (options-ui-§1) ────────────────────────────

test("Panel: every registered canvas frame is handed to the Settings framework", function()
  assertTrue(mocks.__settingsPanels["Ka0s Bank Ledger"] ~= nil, "landing page")
  assertTrue(mocks.__settingsPanels["General"] ~= nil, "General subcategory")
  assertTrue(mocks.__settingsPanels["Filters"] ~= nil, "Filters subcategory")
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
  for _, name in ipairs({ "Ka0s Bank Ledger", "General", "Filters" }) do
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
  for _, name in ipairs({ "General", "Filters" }) do
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
  for _, name in ipairs({ "Ka0s Bank Ledger", "General", "Filters" }) do
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

local AceGUI = mocks.__libs["AceGUI-3.0"]

--- The live ctx for a registered page, out of the library's own registry.
local function ctxFor(name)
  local frame = panel(name)
  for _, c in ipairs(P.__pagesForTest()) do
    if c.panel == frame then return c end
  end
  return nil
end

--- Fire a page's OnShow and hand back every widget it created, plus anything it printed.
---
--- Marked dirty first, because the library renders a page ONCE and then only again when a refresh
--- flagged it while hidden — which is the whole point of the registry and not something to work
--- around. This is the same door: `_dirty` is what RefreshAllPanels sets on an off-screen page.
local function renderPage(name)
  local c = ctxFor(name)
  if c then c._dirty = true end
  local before = #AceGUI.__created
  local chat = {}
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, m) chat[#chat + 1] = m end
  local ok, err = pcall(function() panel(name):__fire("OnShow") end)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  local made = {}
  for i = before + 1, #AceGUI.__created do made[#made + 1] = AceGUI.__created[i] end
  return made, chat
end

--- Render one TAB of a tabbed page and hand back the widgets it created.
---
--- The strip re-renders the SCHEMA on a click (options-ui-§13), and `ctx.activeTab` is the only
--- state that says which group is on screen — so a case about a row now has to say which tab it
--- expects to find it on. Setting it directly is exactly what a click does.
local function renderTab(name, tab)
  local c = ctxFor(name)
  assertTrue(c ~= nil, name .. " has no ctx in the library's registry")
  c.activeTab = tab
  return renderPage(name)
end

--- Every widget the page draws across ALL of its tabs, concatenated in tab order.
local function renderAllTabs(name, tabs)
  local all = {}
  for _, tab in ipairs(tabs) do
    for _, w in ipairs(renderTab(name, tab)) do all[#all + 1] = w end
  end
  return all
end

-- The General page's strip, in tab order. Kept here rather than derived from the schema on purpose:
-- a case that reads the tab list out of the thing it is testing agrees with itself no matter what
-- the thing says. tests/test_schema.lua owns the partition; this is the panel's copy of the answer.
local GENERAL_TABS = { "Capture", "Interface", "History" }

local function widgetLabeled(made, label)
  for _, w in ipairs(made) do
    if w.labelText == label then return w end
  end
  return nil
end

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
  -- against it would be asserting "three tabs" with the number four.
  local c = ctxFor("General")
  renderTab("General", "Capture")
  local layout = c.__tabLayout
  assertTrue(layout ~= nil, "no tab strip was laid out")
  assertEqual(#layout.buttons, #GENERAL_TABS, "one tab button per group")
  assertEqual(c.activeTab, "Capture")

  -- And a click on another tab moves the strip rather than redrawing the same page.
  layout.buttons[2]:__fire("OnClick")
  assertEqual(c.activeTab, GENERAL_TABS[2], "clicking a tab must select it")
  c.activeTab = GENERAL_TABS[1]
end)

test("Panel: every renderable schema row reaches the page on ITS OWN tab", function()
  -- A row drifting into the wrong group renders under the wrong tab, which the partition case in
  -- tests/test_schema.lua catches in the data. This is the same claim about the drawn page: the row
  -- must be on the tab its group names, and must NOT be on the others.
  for _, tab in ipairs(GENERAL_TABS) do
    local made = renderTab("General", tab)
    for _, row in ipairs(NS.Schema.Schema) do
      if not row.skipRender then
        local drawn = widgetLabeled(made, row.label) ~= nil
        if row.group == tab then
          assertTrue(drawn, row.path .. " (" .. tostring(row.label) .. ") never reached its tab")
        else
          assertFalse(drawn, row.path .. " leaked onto the '" .. tab .. "' tab")
        end
      end
    end
  end
end)

test("Panel: a boolean row is a CheckBox and a range row is a Slider", function()
  assertEqual(widgetLabeled(renderTab("General", "Capture"), "Enable capture").type, "CheckBox")
  local iface = renderTab("General", "Interface")
  assertEqual(widgetLabeled(iface, "Window scale").type, "Slider")
  assertEqual(widgetLabeled(iface, "Row stripe opacity").type, "Slider")
  assertEqual(widgetLabeled(iface, "Row hover opacity").type, "Slider")
end)

test("Panel: a numeric ENUM row is a Dropdown, not a slider over its indices", function()
  -- The whole reason LibKa0s-Options-1.0 went to OptionsWidgets minor 5. Neither of these rows
  -- declares min/max/step, so under minor 4 they rendered as 0-to-1 sliders — a control that could
  -- not express any of their values, with nothing raising. The two now live on different tabs.
  local q = widgetLabeled(renderTab("General", "Capture"), "Minimum quality")
  local r = widgetLabeled(renderTab("General", "History"), "Keep history for")
  assertEqual(q.type, "Dropdown")
  assertEqual(r.type, "Dropdown")
  assertEqual(r.list[30], "30 days", "the entries carry their own labels, not stringified values")
  assertEqual(r.value, NS.Schema:Get("settings.retentionDays"), "seeded from the store")
end)

test("Panel: a checkbox write goes through the single write seam", function()
  local made = renderTab("General", "Capture")
  local cb = widgetLabeled(made, "Track gold")
  local saved = NS.Schema:Get("settings.trackMoney")
  cb:__fire("OnValueChanged", false)
  assertEqual(NS.Schema:Get("settings.trackMoney"), false, "the widget wrote through NS.Schema:Set")
  cb:__fire("OnValueChanged", true)
  assertEqual(NS.Schema:Get("settings.trackMoney"), true)
  NS.Schema:Set("settings.trackMoney", saved)
end)

test("Panel: Reset all sits on History beside Purge, and NOT beside the window-scale slider", function()
  -- It used to be the descriptor's `pairWith` on settings.windowScale, one pixel from the slider a
  -- player drags to size the window. It is now the right half of the History tab's InlineButtonPair,
  -- next to Purge and under the read-out that says how much there is to lose.
  --
  -- BOTH halves are asserted. A case that only checked the new home would stay green if the old
  -- pairing were reinstated as well, and two buttons that wipe the ledger is worse than one in the
  -- wrong place.
  local history = renderTab("General", "History")
  local seenPurge, paired = false, false
  for _, w in ipairs(history) do
    if w.type == "Button" and w.text == "Purge ledger\226\128\166" then seenPurge = true
    elseif seenPurge and w.type == "Button" and w.text == "Reset all\226\128\166" then
      paired = true; break
    end
  end
  assertTrue(paired, "Reset all must follow Purge ledger inside the same row")

  local iface = renderTab("General", "Interface")
  for _, w in ipairs(iface) do
    assertFalse(w.type == "Button" and (w.text or ""):find("Reset all", 1, true) ~= nil,
      "Reset all is back beside the window-scale slider")
  end
end)

test("Panel: the store grid renders as an inverted checkbox set, host-drawn", function()
  -- `skipRender = true` keeps the row out of the flow engine; the page emits this grid itself. The
  -- inversion is the part worth pinning: the row STORES the muted set, so a TICKED box means
  -- "record this store".
  local made = renderTab("General", "Capture")
  local group
  for _, w in ipairs(made) do
    if w.type == "InlineGroup" then group = w end
  end
  assertTrue(group ~= nil, "no InlineGroup for the store grid")
  assertEqual(group.titleText, NS.Schema:FindRow("settings.excludedStores").label)
  local row = NS.Schema:FindRow("settings.excludedStores")
  assertEqual(#group.children, #row.values, "one checkbox per store option")

  local saved = NS.Schema:Get("settings.excludedStores")
  NS.Schema:Set("settings.excludedStores", {})
  renderTab("General", "Capture")   -- re-render so the boxes seed from the empty muted set
  local made2 = renderTab("General", "Capture")
  local grid
  for _, w in ipairs(made2) do if w.type == "InlineGroup" then grid = w end end
  for _, cb in ipairs(grid.children) do
    assertTrue(cb.value == true, cb.labelText .. " should be TICKED when nothing is muted")
  end
  -- Unticking one must MUTE it, i.e. write it INTO the stored set.
  local first = row.values[1].value
  grid.children[1]:__fire("OnValueChanged", false)
  assertTrue((NS.Schema:Get("settings.excludedStores") or {})[first] == true,
    "unticking a store must add it to the muted set")
  NS.Schema:Set("settings.excludedStores", saved or {})
end)

test("Panel: a tabbed page draws NO section headings — the strip is the heading", function()
  -- RenderTabbedSchema renders the active group with `noHeadings`, because a tab labelled Capture
  -- over a section headed Capture says the same word twice. This used to assert the opposite (a
  -- heading per group plus one for Storage), which is exactly the drift the adoption removes.
  for _, tab in ipairs(GENERAL_TABS) do
    for _, w in ipairs(renderTab("General", tab)) do
      assertFalse(w.type == "Heading", tab .. " drew a section heading: " .. tostring(w.text))
    end
  end
end)

test("Panel: the storage read-out lands on the History tab and nowhere else", function()
  -- It was the casualty the first time the store grid raised: the library's per-page pcall stopped
  -- the renderer, and everything after the raise silently never drew. It is now drawn from the
  -- History tab's afterGroup hook, which is what keeps it on the page through a tab click — the
  -- page renderer's own trailing calls would have survived exactly one render.
  local function readoutIn(made)
    for _, w in ipairs(made) do
      if w.type == "Label" and (w.text or ""):find("Database size", 1, true) then return true end
    end
    return false
  end
  assertTrue(readoutIn(renderTab("General", "History")), "no storage read-out on History")
  assertFalse(readoutIn(renderTab("General", "Capture")), "the read-out leaked onto Capture")
  assertFalse(readoutIn(renderTab("General", "Interface")), "the read-out leaked onto Interface")

  -- And it survives a second visit to the tab, which is the whole point of the afterGroup hook.
  assertTrue(readoutIn(renderTab("General", "History")), "the read-out vanished on a re-render")
end)

test("Panel: the Filters page is a two-tab strip, one list per tab", function()
  -- It used to stack both lists down one scroll, and the case that covered it only counted widgets
  -- — which stayed true whichever list was on screen, and would have stayed true with one of them
  -- missing. It now asserts WHICH list is drawn, because that is the thing the tab strip decides.
  local c = ctxFor("Filters")
  assertTrue(c ~= nil, "the Filters ctx is in the library's registry")

  local function bodyText(made)
    local out = {}
    for _, w in ipairs(made) do
      if w.type == "Label" and w.text then out[#out + 1] = w.text end
    end
    return table.concat(out, "\n")
  end

  c.activeTab = "blacklist"
  local made, chat = renderPage("Filters")
  assertFalse(joined(chat):find("failed to render", 1, true) ~= nil, joined(chat))
  local layout = c.__tabLayout
  assertTrue(layout ~= nil and #layout.buttons == 2, "expected a two-tab strip")
  local black = bodyText(made)
  assertTrue(black:find("never recorded", 1, true) ~= nil, "the blacklist blurb is missing")
  assertFalse(black:find("always recorded", 1, true) ~= nil, "the whitelist leaked onto Blacklist")

  c.activeTab = "whitelist"
  local white = bodyText(renderPage("Filters"))
  assertTrue(white:find("always recorded", 1, true) ~= nil, "the whitelist blurb is missing")
  assertFalse(white:find("never recorded", 1, true) ~= nil, "the blacklist leaked onto Whitelist")

  c.activeTab = "blacklist"
end)

test("Panel: a Filters tab whose key no longer exists heals to the first tab", function()
  -- A stale ctx.activeTab would otherwise draw a strip over an empty page, with nothing to say so.
  local c = ctxFor("Filters")
  c.activeTab = "greylist"
  renderPage("Filters")
  assertEqual(c.activeTab, "blacklist")
end)

test("Panel: re-rendering a page releases the previous widgets and their refreshers", function()
  -- Every render appends refresher closures that capture the widgets it made. Keeping them across a
  -- re-render leaves every later write pcall'ing an ever-growing pile of dead closures
  -- (options-ui-§11) — which is what O.ClearScroll at the top of each renderer prevents.
  local ctx = ctxFor("General")
  assertTrue(ctx ~= nil, "the General ctx is in the library's registry")
  renderPage("General")
  local first = #ctx.refreshers
  renderPage("General")
  assertEqual(#ctx.refreshers, first, "the refresher list must be replaced, not appended to")
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
