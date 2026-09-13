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

-- The General page's strip, in tab order. Kept here rather than derived from the schema on purpose:
-- a case that reads the tab list out of the thing it is testing agrees with itself no matter what
-- the thing says. tests/test_schema.lua owns the partition; this is the panel's copy of the answer.
--
-- Five: Master controls leads (options-ui-§15), and Filters is the retired Filters page (R3), now
-- one tab whose afterGroup hook draws a SECONDARY strip over the two id lists (options-ui-§13).
-- The names and their order are shared with Ka0s Loot History, which draws the same strip plus an
-- AH Price tab after Capture -- two addons a player compares should not name one subject twice.
local GENERAL_TABS = {
  "Master controls", "Capture", "Interface", "History", "Filters",
}

-- The Filters tab's sub-strip, in order. The KEY is the stored list name and the LABEL is what the
-- sub-tab reads, which are deliberately not the same string: the tab above them is already called
-- Filters.
local FILTER_SUB_TABS = { "blacklist", "whitelist" }

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

-- ── the Filters tab's secondary strip (options-ui-§13) ─────────────────────────
--
-- Two id-lists are a list of like subjects inside one category, which is what a secondary strip is
-- for -- drawn inside the scroll as ordinary content, with its selection in ctx.activeSubTab keyed
-- by the PRIMARY tab's name. Session state, never persisted.
--
-- Dies under: promoting the lists back to two primary tabs, or keying the sub-selection off
-- ctx.activeTab (which a click on another primary tab would then overwrite).
test("Panel: the Filters tab draws a SECONDARY strip and renders only the selected list", function()
  local c = ctxFor("General")
  c.activeSubTab = nil
  local made = renderTab("General", "Filters")
  assertTrue(c.__subTabKids ~= nil and #c.__subTabKids == #FILTER_SUB_TABS,
    "one sub-tab per list")
  assertEqual(c.activeSubTab["Filters"], FILTER_SUB_TABS[1],
    "the sub-strip opens on the first list")

  -- One add-row, not two: the tab draws the selected list and nothing else.
  local boxes = 0
  for _, w in ipairs(made) do if w.type == "EditBox" then boxes = boxes + 1 end end
  assertEqual(boxes, 1, "exactly one add-row is on screen")

  c.__subTabKids[2]:__fire("OnClick")
  assertEqual(c.activeSubTab["Filters"], FILTER_SUB_TABS[2], "sub-tab 2 is the whitelist")
  c.activeSubTab = nil
  c.activeTab = GENERAL_TABS[1]
end)

-- ── the Filters tab's id list (LibKa0s-Options IdList, v1.35.0) ──────────────────────────────
--
-- Each list is ONE O.IdList with kind = "item" now: the box resolves a number, a shift-clicked link
-- or an item's NAME through O.ResolveId, and the entry lines are the library's. The host keeps the
-- storage. Every add and remove goes through NS.Filters' own writers, so F:_move still keeps the two
-- lists exclusive and db.global.{blacklist,whitelist} keep their [itemID] = true shape. The names
-- come from the kit's opt-in id lookups, which tests/wow_mock.lua installs (override 13).

-- The ledger a Filters case replaced, boxed so a nil one comes back as nil; leaveFilters restores it.
local savedLedger

--- Open Filters on `listKey` with the two lists seeded as given, and the ledger holding `ledgerRows`
--- (empty when omitted); hand back what the tab drew. The ledger is set every time because the
--- lists' add box takes its name candidates from it: rows left behind by another suite would be
--- unnamed ids, and a typed name waits on a lookup while any candidate is unnamed.
local function filtersTab(listKey, black, white, ledgerRows)
  NS.db.global.blacklist = black or {}
  NS.db.global.whitelist = white or {}
  if savedLedger == nil then savedLedger = { NS.db.global.ledger } end
  NS.db.global.ledger = ledgerRows or {}
  local c = ctxFor("General")
  c.activeSubTab = { Filters = listKey }
  return renderTab("General", "Filters"), c
end

--- The first drawn widget of `wtype`, optionally one whose text contains `part`.
local function firstOf(made, wtype, part)
  for _, w in ipairs(made) do
    if w.type == wtype and (part == nil
        or (type(w.text) == "string" and w.text:find(part, 1, true) ~= nil)) then
      return w
    end
  end
  return nil
end

--- Spy on one NS.Filters writer for the length of `fn`, still calling through to the real one.
local function spyWriter(name, fn)
  local real, calls = NS.Filters[name], {}
  NS.Filters[name] = function(self, id) calls[#calls + 1] = id; return real(self, id) end
  local ok, err = pcall(fn)
  NS.Filters[name] = real
  if not ok then error(err, 0) end
  return calls
end

local function typeInto(made, text)
  local box = firstOf(made, "EditBox")
  assertTrue(box ~= nil, "the Filters tab has no add box")
  box:__fire("OnEnterPressed", text)
end

local function leaveFilters(c)
  NS.db.global.blacklist, NS.db.global.whitelist = {}, {}
  if savedLedger then NS.db.global.ledger = savedLedger[1] end
  savedLedger = nil
  c.activeSubTab = nil
  c.activeTab = GENERAL_TABS[1]
end

test("Filters tab: an item id typed into the box goes through Filters:AddBlacklist", function()
  -- red under: onAdd writing db.global.blacklist directly (the spy sees nothing), or not wired.
  local made, c = filtersTab("blacklist")
  local calls = spyWriter("AddBlacklist", function() typeInto(made, "2589") end)
  assertEqual(#calls, 1, "one add, one writer call")
  assertEqual(calls[1], 2589)
  -- The stored shape is unchanged: a number key, the value true, and nothing else in the set.
  local keys = 0
  for k, v in pairs(NS.db.global.blacklist) do
    keys = keys + 1
    assertEqual(type(k), "number", "keyed by the numeric item id")
    assertEqual(v, true, "stored as [itemID] = true")
  end
  assertEqual(keys, 1, "exactly the one id")
  leaveFilters(c)
end)

test("Filters tab: a shift-clicked item link adds the id inside it", function()
  -- red under: a kind other than "item" (a link of another type resolves to nothing).
  local made, c = filtersTab("blacklist")
  local link = "|cffffffff|Hitem:4306::::::::::|h[Silk Cloth]|h|r"
  local calls = spyWriter("AddBlacklist", function() typeInto(made, link) end)
  assertEqual(calls[1], 4306)
  leaveFilters(c)
end)

test("Filters tab: an item typed by NAME resolves to its id, whatever its case", function()
  -- The new capability: the old box took a number or a link and nothing else.
  -- red under: kind omitted (the id-only kind resolves no name), or the old ParseItemID submit.
  local made, c = filtersTab("blacklist")
  local calls = spyWriter("AddBlacklist", function() typeInto(made, "linen cloth") end)
  assertEqual(calls[1], 2589)
  leaveFilters(c)
end)

test("Filters tab: input that names no item adds nothing and says why on the tab", function()
  -- red under: kind omitted (the id-only kind's reason reads "No entry named"), or the old editor's
  -- submit, which reported a bad input only as a chat line.
  local made, c = filtersTab("blacklist")
  local calls = spyWriter("AddBlacklist", function() typeInto(made, "Nonesuch Blade") end)
  assertEqual(#calls, 0, "nothing reaches the writer")
  assertEqual(next(NS.db.global.blacklist), nil, "the list is untouched")
  assertTrue(firstOf(made, "Label", "No item named 'Nonesuch Blade'") ~= nil,
    "the reason is shown under the box")
  leaveFilters(c)
end)

test("Filters tab: an entry's Remove goes through Filters:RemoveBlacklist", function()
  -- red under: onRemove not wired, or pointed at the other list's writer.
  local made, c = filtersTab("blacklist", { [2589] = true })
  local rm = firstOf(made, "Button", "Remove")
  assertTrue(rm ~= nil, "the entry has a Remove button")
  local calls = spyWriter("RemoveBlacklist", function() rm:__fire("OnClick") end)
  assertEqual(calls[1], 2589)
  assertEqual(next(NS.db.global.blacklist), nil, "the id is gone from the store")
  leaveFilters(c)
end)

test("Filters tab: adding on Whitelist takes the id off Blacklist (Filters:_move, unchanged)", function()
  -- red under: the Whitelist tab's onAdd calling AddBlacklist, or writing the store directly.
  local made, c = filtersTab("whitelist", { [2589] = true })
  local calls = spyWriter("AddWhitelist", function() typeInto(made, "2589") end)
  assertEqual(calls[1], 2589)
  assertTrue(NS.db.global.whitelist[2589] == true, "now on the whitelist")
  assertTrue(NS.db.global.blacklist[2589] == nil, "and off the blacklist")
  leaveFilters(c)
end)

test("Filters tab: an entry reads its item name and id; an empty list reads (none)", function()
  -- red under: dropping kind = "item" (the line reads "Unknown entry 2589"), or dropping emptyText.
  local made, c = filtersTab("blacklist", { [2589] = true })
  local line = firstOf(made, "InteractiveLabel", "Linen Cloth")
  assertTrue(line ~= nil and line.text:find("(2589)", 1, true) ~= nil, "name and id on the line")
  made = filtersTab("blacklist")
  assertTrue(firstOf(made, "Label", "(none)") ~= nil, "the empty list says so")
  assertTrue(firstOf(made, "Button", "Clear all") ~= nil, "Clear all stays the host's button")
  leaveFilters(c)
end)

test("Filters tab: an uncached item is asked for, and the list redraws when it lands", function()
  -- red under: kind omitted (the id-only kind neither names an item nor loads one), or the old
  -- editor's label, which read "Item <id>" and redrew only its own group.
  mocks.addIdRecord("item", 99001, "Gilded Trinket", 134400, true)
  local landed
  local savedAfter, savedRefresh = mocks.C_Timer.After, NS.Helpers.RefreshAllPanels
  mocks.C_Timer.After = function(_, cb) landed = cb end
  local ok, made, c = pcall(filtersTab, "blacklist", { [99001] = true })
  mocks.C_Timer.After = savedAfter
  if not ok then error(made, 0) end
  assertTrue(firstOf(made, "InteractiveLabel", "Unknown item 99001") ~= nil, "unnamed until cached")
  assertTrue(mocks.__loadRequests[99001] == true, "the client was asked to load it")
  assertTrue(type(landed) == "function", "a load callback is waiting")

  -- The redraw is this page's own (ctx.rebuild -> O.RefreshPanel on this ctx), not a sweep.
  local redraws = 0
  NS.Helpers.RefreshPanel = function(ctx, structural)
    if ctx == c and structural then redraws = redraws + 1 end
  end
  mocks.addIdRecord("item", 99001, "Gilded Trinket", 134400)
  local ran, err = pcall(landed)
  NS.Helpers.RefreshPanel = savedRefresh
  if not ran then error(err, 0) end
  assertEqual(redraws, 1, "the load landing redraws the list")
  made = filtersTab("blacklist", { [99001] = true })
  assertTrue(firstOf(made, "InteractiveLabel", "Gilded Trinket") ~= nil, "named once cached")
  mocks.__idRecords.item[99001] = nil
  leaveFilters(c)
end)

test("Filters tab: several uncached items cost one load check and one redraw", function()
  -- LibKa0s v1.35.0 (re-cut) batches a render's asks: the first id carries the callback, the rest
  -- only ask, so a blacklist of uncached items repaints the page once, not once per item.
  -- red under: the pre-re-cut widget, which armed one callback per id and redrew on each.
  mocks.addIdRecord("item", 99003, "Gilded Trinket", 134400, true)
  mocks.addIdRecord("item", 99004, "Tarnished Locket", 134400, true)
  local pending = {}
  local savedAfter, savedRefresh = mocks.C_Timer.After, NS.Helpers.RefreshPanel
  mocks.C_Timer.After = function(_, cb) pending[#pending + 1] = cb end
  local ok, made, c = pcall(filtersTab, "blacklist", { [99003] = true, [99004] = true })
  mocks.C_Timer.After = savedAfter
  if not ok then error(made, 0) end
  assertTrue(mocks.__loadRequests[99003] == true and mocks.__loadRequests[99004] == true,
    "both items were asked for")
  assertEqual(#pending, 1, "one load check for the whole render")

  local redraws = 0
  NS.Helpers.RefreshPanel = function(ctx, structural)
    if ctx == c and structural then redraws = redraws + 1 end
  end
  mocks.addIdRecord("item", 99003, "Gilded Trinket", 134400)
  mocks.addIdRecord("item", 99004, "Tarnished Locket", 134400)
  local ran, err = pcall(function() for _, cb in ipairs(pending) do cb() end end)
  NS.Helpers.RefreshPanel = savedRefresh
  if not ran then error(err, 0) end
  assertEqual(redraws, 1, "both loads landing redraw the list once")
  mocks.__idRecords.item[99003], mocks.__idRecords.item[99004] = nil, nil
  leaveFilters(c)
end)

--- How many EditBoxes `fn` created with the General page ON SCREEN: one per repaint of the Filters
--- tab, which draws exactly one. Firing OnShow draws the page but never marks it shown, and a hidden
--- page is only flagged dirty by a refresh, so without the Show the repaints this counts never run.
local function editBoxesMadeBy(fn)
  local frame = panel("General")
  local wasShown = frame:IsShown()
  frame:Show()
  local before = #AceGUI.__created
  local ok, err = pcall(fn)
  if not wasShown then frame:Hide() end
  if not ok then error(err, 0) end
  local boxes = 0
  for i = before + 1, #AceGUI.__created do
    if AceGUI.__created[i].type == "EditBox" then boxes = boxes + 1 end
  end
  return boxes
end

test("Filters tab: one add redraws the page once, not twice", function()
  -- The writer fires LedgerChanged synchronously and the page's own listener repaints on it; the
  -- widget then asks for its own redraw. Two full repaints per click is the anti-pattern #39 cost.
  -- (Since the v1.35.0 re-cut the widget clears the box and the status line BEFORE onAdd, so an
  -- onAdd that repaints no longer races the pool; the double repaint is still the waste.)
  -- red under: dropping the write guard that holds the LedgerChanged repaint off during an add.
  local made, c = filtersTab("blacklist")
  local boxes = editBoxesMadeBy(function() typeInto(made, "2589") end)
  assertEqual(boxes, 1, "exactly one repaint follows one add")
  assertTrue(NS.db.global.blacklist[2589] == true, "the add landed")
  leaveFilters(c)
end)

test("Filters tab: one Remove redraws the page once, not twice", function()
  -- red under: the write guard wrapping onAdd but not onRemove.
  local made, c = filtersTab("blacklist", { [2589] = true })
  local rm = firstOf(made, "Button", "Remove")
  local boxes = editBoxesMadeBy(function() rm:__fire("OnClick") end)
  assertEqual(boxes, 1, "exactly one repaint follows one remove")
  assertEqual(next(NS.db.global.blacklist), nil, "the remove landed")
  leaveFilters(c)
end)

test("Filters tab: the list's own redraw repaints this page, never every rendered page", function()
  -- red under: no ctx.rebuild, where the widget falls back to O.RefreshAllPanels.
  local made, c = filtersTab("blacklist")
  local saved, sweeps = NS.Helpers.RefreshAllPanels, 0
  NS.Helpers.RefreshAllPanels = function() sweeps = sweeps + 1 end
  local ok, err = pcall(typeInto, made, "2589")
  NS.Helpers.RefreshAllPanels = saved
  if not ok then error(err, 0) end
  assertEqual(sweeps, 0, "an add sweeps no page but this one")
  leaveFilters(c)
end)

test("Filters tab: a list change from elsewhere still repaints the open tab", function()
  -- The guard holds the listener off only for the page's OWN write; the ledger table's right-click
  -- Blacklist goes through the same writer outside it and must still show up on an open tab.
  -- red under: the guard left set after a write, or the listener dropped.
  local _, c = filtersTab("blacklist")
  local boxes = editBoxesMadeBy(function() NS.Filters:AddBlacklist(4306) end)
  assertEqual(boxes, 1, "the open tab repaints for an outside change")
  leaveFilters(c)
end)

test("Filters tab: an entry's name is drawn in its item quality color", function()
  -- The client's ITEM_QUALITY_COLORS[q].hex is a whole color code, "|cff" prefix included, and
  -- IdList prepends it as-is. red under: a palette hex without the prefix (the line read
  -- "ff0070ddRuned Band|r"), which is what tests/wow_mock.lua answered before it matched the client.
  mocks.addIdRecord("item", 99104, "Runed Band", 134400, nil, 3)
  local ok, made, c = pcall(filtersTab, "blacklist", { [99104] = true })
  mocks.__idRecords.item[99104] = nil
  if not ok then error(made, 0) end
  local line = firstOf(made, "InteractiveLabel", "Runed Band")
  assertTrue(line ~= nil, "the entry is drawn")
  assertEqual(line.text:find("|cff0070ddRuned Band|r", 1, true), 1,
    "a rare item's name opens in the rare color code")
  leaveFilters(c)
end)

-- ── the Filters tab's suggestions (LibKa0s v1.35.0 re-cut, issue #31) ────────────────────────
--
-- The client has no item-name search: C_Item's name lookups answer only for an item the player
-- carries or carried this session. So the add box gets `candidates` -- every item id the ledger has
-- recorded, plus both lists' ids -- which the widget names itself, lists as the player types, and
-- resolves a typed name against. The dropdown is a library frame, not an AceGUI widget, so a case
-- records the frames CreateFrame hands out and finds the one carrying `rows`, and reads each row off
-- the library's own record on it (`row.entry`, `row.labelText`): the kit's frame stub keeps no
-- FontString text. This harness's C_Timer.After is a no-op, so each case queues the typing debounce
-- and runs it by hand.

local ZEPHYR = "Potion of the Hushed Zephyr"
local ZEPHYR_IDS = { 191395, 191396, 191397 }
-- The words the add box's refusal and tooltip end with. Spelled here, not read off settings/Panel.lua:
-- a case that reads its answer out of the thing it tests agrees with itself whatever that says.
local NAME_HINT = "Names work for items you carry (or carried this session), items on either list "
  .. "and items your ledger has recorded; otherwise use the id or shift-click a link."

-- The dropdown, once a case has seen it built: there is one per library instance, built the first
-- time it shows, so later cases find it here rather than among their own frames.
local seenDropdown

--- One suggestion case. `fn(s)` gets:
---   s.item(id, name, quality, tier) -- a cached item record, removed again when the case ends;
---   s.rows(ids)                     -- ledger rows recording `ids`, plus a gold row with no item;
---   s.notCarried()                  -- C_Item's name lookups answer nothing for a plain name, as
---                                      the client's do for an item not in the bags this session;
---   s.flush()                       -- run the queued timers (the typing debounce, a lookup);
---   s.dropdown(), s.c               -- the dropdown frame; set s.c to the ctx to leave Filters.
local function suggestCase(name, fn)
  test(name, function()
    local realFrame, realAfter = mocks.CreateFrame, mocks.C_Timer.After
    local realInstant, realInfo = mocks.C_Item.GetItemInfoInstant, mocks.C_Item.GetItemInfo
    local frames, queue, seeded = {}, {}, {}
    mocks.CreateFrame = function(...)
      local f = realFrame(...)
      frames[#frames + 1] = f
      return f
    end
    mocks.C_Timer.After = function(_, cb) queue[#queue + 1] = cb end
    local s = {}
    function s.item(id, itemName, quality, tier)
      mocks.addIdRecord("item", id, itemName, 134400, nil, quality)
      if tier then mocks.setCraftedQuality(id, tier) end
      seeded[#seeded + 1] = id
    end
    function s.rows(ids)
      local rows = {}
      for i, id in ipairs(ids) do rows[i] = { itemID = id, quantity = 1 } end
      rows[#rows + 1] = { quantity = 100 }
      return rows
    end
    function s.notCarried()
      local function byName(real)
        return function(key, ...)
          if type(key) == "string" and not tonumber(key) and not key:find("item:%d") then
            return nil
          end
          return real(key, ...)
        end
      end
      mocks.C_Item.GetItemInfoInstant = byName(realInstant)
      if realInfo then mocks.C_Item.GetItemInfo = byName(realInfo) end
    end
    function s.flush()
      for _ = 1, 50 do
        if #queue == 0 then return end
        local due = queue
        queue = {}
        for _, cb in ipairs(due) do cb() end
      end
    end
    function s.dropdown()
      for i = #frames, 1, -1 do
        if type(frames[i].rows) == "table" then seenDropdown = frames[i] end
      end
      return seenDropdown
    end
    local ok, err = pcall(fn, s)
    mocks.CreateFrame, mocks.C_Timer.After = realFrame, realAfter
    mocks.C_Item.GetItemInfoInstant, mocks.C_Item.GetItemInfo = realInstant, realInfo
    for _, id in ipairs(seeded) do
      mocks.__idRecords.item[id] = nil
      mocks.__craftedQuality[id] = nil
    end
    if s.c then leaveFilters(s.c) end
    if not ok then error(err, 0) end
  end)
end

--- Type into the add box as AceGUI's EditBox reports it, then let the debounce run.
local function typeText(made, text, s)
  local box = firstOf(made, "EditBox")
  assertTrue(box ~= nil, "the Filters tab has no add box")
  box:SetText(text)
  box:__fire("OnTextChanged", text)
  s.flush()
end

--- The ids the dropdown's visible rows carry, in order; "" while it is hidden.
local function shownIds(s)
  local dd = s.dropdown()
  if not (dd and dd:IsShown()) then return "" end
  local ids = {}
  for _, row in ipairs(dd.rows) do
    if row:IsShown() and row.entry then ids[#ids + 1] = row.entry.id end
  end
  return table.concat(ids, ",")
end

suggestCase("Filters tab: typing lists the items the ledger recorded and the other list holds", function(s)
  -- red under: no candidates. The bags are empty, so the dropdown would have nothing to list.
  s.item(99101, "Glimmering Opal")
  s.item(99102, "Glimmering Shard")
  local made
  made, s.c = filtersTab("blacklist", nil, { [99102] = true }, s.rows({ 99101, 99101 }))
  typeText(made, "glimmering", s)
  assertEqual(shownIds(s), "99101,99102", "the ledger's item and the whitelist's, each once")
end)

suggestCase("Filters tab: a name the client's lookup cannot find resolves through the ledger's ids", function(s)
  -- The owner's case: an item the player does not carry, so C_Item answers nothing for its name.
  -- red under: no candidates (the name resolves to nothing and the add is refused).
  s.item(99103, "Gossamer Thread")
  s.notCarried()
  local made
  made, s.c = filtersTab("blacklist", nil, nil, s.rows({ 99103 }))
  local calls = spyWriter("AddBlacklist", function() typeInto(made, "gossamer thread") end)
  assertEqual(table.concat(calls, ","), "99103")
end)

suggestCase("Filters tab: picking a suggestion adds it through the list's own writer, once", function(s)
  -- red under: no candidates (no row to pick), or a pick that reaches the writer twice.
  s.item(99101, "Glimmering Opal")
  local made
  made, s.c = filtersTab("whitelist", nil, nil, s.rows({ 99101 }))
  typeText(made, "glimm", s)
  local dd = s.dropdown()
  assertTrue(dd ~= nil and dd:IsShown(), "the dropdown is up")
  local black
  local white = spyWriter("AddWhitelist", function()
    black = spyWriter("AddBlacklist", function() dd.rows[1]:__fire("OnClick") end)
  end)
  assertEqual(table.concat(white, ","), "99101", "one call, with the picked id")
  assertEqual(#black, 0, "the other list's writer is not called")
  assertTrue(NS.db.global.whitelist[99101] == true, "the pick landed on the whitelist")
end)

suggestCase("Filters tab: a name three ranks share lists every rank; Enter without a pick adds none", function(s)
  for tier, id in ipairs(ZEPHYR_IDS) do s.item(id, ZEPHYR, 1, tier) end
  local made
  made, s.c = filtersTab("blacklist", nil, nil, s.rows(ZEPHYR_IDS))
  typeText(made, ZEPHYR, s)
  -- red under: no candidates (nothing listed, the player cannot pick a rank)
  assertEqual(shownIds(s), "191395,191396,191397", "every rank is its own row")
  for i = 1, 3 do
    assertTrue(s.dropdown().rows[i].labelText:find("Tier" .. i, 1, true) ~= nil,
      "row " .. i .. " is labeled with its rank")
  end
  local box = firstOf(made, "EditBox")
  local calls = spyWriter("AddBlacklist", function() box:__fire("OnEnterPressed", ZEPHYR) end)
  -- red under: no candidates, where the client's one answer for the name adds its first rank
  assertEqual(#calls, 0, "neither one rank nor all three")
  assertTrue(firstOf(made, "Label", "Several items are named '" .. ZEPHYR
    .. "' \226\128\148 pick one from the list, or use the id.") ~= nil, "the refusal says why")
  assertEqual(shownIds(s), "191395,191396,191397", "the ranks stay listed to pick from")
  calls = spyWriter("AddBlacklist", function() s.dropdown().rows[3]:__fire("OnClick") end)
  assertEqual(table.concat(calls, ","), "191397", "the picked rank, and only it")
end)

suggestCase("Filters tab: a name nothing knows is refused, saying where names come from", function(s)
  -- red under: the library's default hint, which says "ones this list knows" and never that the
  -- ledger's items count too.
  s.notCarried()
  local made
  made, s.c = filtersTab("blacklist")
  local calls = spyWriter("AddBlacklist", function() typeInto(made, "Unseen Relic") end)
  assertEqual(#calls, 0, "nothing reaches the writer")
  assertTrue(firstOf(made, "Label", "No item named 'Unseen Relic' that the game can find. "
    .. NAME_HINT) ~= nil, "the refusal ends with the tab's own hint")
  -- And the box's tooltip says it before anything is typed. GameTooltip is nil in this harness
  -- (tests/wow_mock.lua override 10), so the case lends it a recorder for one hover.
  local lines = {}
  mocks.GameTooltip = {
    SetOwner = function() end, SetText = function() end, Show = function() end,
    Hide = function() end, AddLine = function(_, text) lines[#lines + 1] = text end,
  }
  local ok, err = pcall(function() firstOf(made, "EditBox"):__fire("OnEnter") end)
  mocks.GameTooltip = nil
  if not ok then error(err, 0) end
  assertTrue(type(lines[1]) == "string" and lines[1]:find(NAME_HINT, 1, true) ~= nil,
    "the add box's tooltip carries the hint")
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
  -- The two canonical labels moved with their rows: "Enable capture" is "Enable Bank Ledger" and
  -- "Window scale" is "Master scale", both on Master controls (options-ui-§15).
  local master = renderTab("General", "Master controls")
  assertEqual(widgetLabeled(master, "Enable Bank Ledger").type, "CheckBox")
  assertEqual(widgetLabeled(master, "Master scale").type, "Slider")
  assertEqual(widgetLabeled(master, "Master alpha").type, "Slider")
  assertEqual(widgetLabeled(master, "General visibility").type, "Dropdown")
  local iface = renderTab("General", "Interface")
  assertEqual(widgetLabeled(iface, "Row stripe opacity").type, "Slider")
  assertEqual(widgetLabeled(iface, "Row hover opacity").type, "Slider")
end)

test("Panel: the Master controls tab closes with the two reset buttons", function()
  -- The composer's afterGroup hook, wired under the group's own name — rename the group and the
  -- pair silently detaches (options-ui-§15). "Reset all settings" is options-ui-§12's global reset,
  -- so this is also the case that proves it did not stay behind on History as a second control.
  --
  -- Dies under: dropping GENERAL_AFTER_TAB["Master controls"], or renaming the group.
  local master = renderTab("General", "Master controls")
  local seenPosition, paired = false, false
  for _, w in ipairs(master) do
    if w.type == "Button" and w.text == "Reset position" then seenPosition = true
    elseif seenPosition and w.type == "Button" and w.text == "Reset all settings" then
      paired = true; break
    end
  end
  assertTrue(paired, "Reset all settings must follow Reset position inside the same row")

  for _, tab in ipairs({ "Capture", "Interface", "History" }) do
    for _, w in ipairs(renderTab("General", tab)) do
      assertFalse(w.type == "Button" and (w.text or ""):find("Reset all", 1, true) ~= nil,
        "a second Reset all is drawn on the '" .. tab .. "' tab")
    end
  end
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

test("Panel: History draws Purge alone — Reset all left with the Master controls tab", function()
  -- "Reset all…" used to be the right half of this pair, and it raised the SAME popup the Master
  -- controls tab's "Reset all settings" raises now. Two controls over one act is what the revamp
  -- removes, so it moved rather than being copied, and Purge is alone in its pair.
  --
  -- Dies under: putting the second spec back into renderStorage's InlineButtonPair call.
  local history = renderTab("General", "History")
  local seenPurge = false
  for _, w in ipairs(history) do
    if w.type == "Button" and w.text == "Purge ledger\226\128\166" then seenPurge = true
    elseif seenPurge and w.type == "Button" then
      assertFalse(true, "History drew a second button beside Purge: " .. tostring(w.text))
    end
  end
  assertTrue(seenPurge, "the Purge button is missing from History")
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

test("Panel: a tab's only headings are the SUBSECTION ones its rows declare", function()
  -- RenderTabbedSchema renders the active group with `noHeadings`, because a tab labelled Capture
  -- over a section headed Capture says the same word twice. A SUBSECTION heading is the exception
  -- and is deliberately not suppressed (options-ui-§7): it names a kind of control the tab mixes,
  -- and it is declared by the row's `subgroup`, never drawn by a builder.
  --
  -- So the claim is not "no Heading" — it is "every Heading on this tab is one its rows asked for,
  -- and none of them repeats the tab's own name".
  --
  -- Dies under: dropping `subgroup` from the Interface rows (Windows/Table rows vanish), or drawing
  -- a heading by hand from an afterGroup hook.
  for _, tab in ipairs(GENERAL_TABS) do
    local declared = {}
    for _, row in ipairs(NS.Schema:PageRows()) do
      if row.group == tab and row.subgroup then declared[row.subgroup] = true end
    end
    local drawn = {}
    for _, w in ipairs(renderTab("General", tab)) do
      if w.type == "Heading" then
        assertTrue(declared[w.text] == true,
          tab .. " drew a heading no row declared: " .. tostring(w.text))
        assertFalse(w.text == tab, tab .. " drew a heading repeating its own tab name")
        drawn[w.text] = true
      end
    end
    for name in pairs(declared) do
      assertTrue(drawn[name] == true, tab .. " declared the subsection '" .. name
        .. "' and drew no heading for it")
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

-- The two Filters-page cases that used to live here are GONE with the page (R3). What they proved
-- — which list is drawn under which tab, and a stale tab pointer healing to the first — is now
-- General's, and both are covered above: "the strip's FIRST tab is Master controls, and it is not
-- the Filters page's" asserts the bodies, and the heal is RenderTabbedSchema's own (it repoints
-- ctx.activeTab at groups[1] when the pointer names a group the page no longer has), exercised by
-- every renderTab call in this file.

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
-- are at least labelled apart while the split stands.

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
