-- tests/panel_support.lua — the panel suites' shared render helpers.
--
-- Extracted when tests/test_panel.lua crossed layout-§1's 1500-line cap and the Filters-tab cases
-- peeled off into tests/test_panel_filters.lua. Unlike Ka0s Loot History's equivalent module there
-- is no cache to share here — `renderPage` marks the page `_dirty` and re-renders every call — so
-- copying these into both files would have WORKED. It would also have left `GENERAL_TABS` declared
-- twice, and that table exists precisely so the strip's order is stated once; a second copy is the
-- drift it was written to prevent. The singleton guard is kept for the same reason the sibling repo
-- needs one: `dofile` re-runs the file, and one registration of these helpers is easier to reason
-- about than two that happen to agree.
if rawget(_G, "__BL_PANEL_SUPPORT") then return rawget(_G, "__BL_PANEL_SUPPORT") end

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local assertTrue = T.assertTrue

local P = NS.Panel

local function panel(name)
  local p = mocks.__settingsPanels[name]
  assertTrue(p ~= nil, "panel '" .. name .. "' was registered")
  return p
end

local AceGUI = mocks.__libs["AceGUI-3.0"]

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


--- Widen the canvas every list drawn inside `fn` is laid out against.
---
--- The kit's AceGUI fake gives a ScrollFrame's content a flat `original_width = 400`
--- (tests/_kit/mock_base.lua) and LibKa0s's always-shown-scrollbar patch then takes its 20px
--- gutter off it, so every list in this suite measures 380px of content. Nothing in the kit
--- claims that is what Blizzard's settings canvas hands a page; it is a number a fake made up.
---
--- It matters from LibKa0s v1.50.0, which made `columns` a MAXIMUM: O.IdList measures the content
--- width at draw time and drops toward one column when the count cannot be paid for -- 520px for
--- two entries in the icon style. At 380 every multi-column list collapses to one, which is the
--- library being right about a number the harness invented. So a case asserting how a list PACKS
--- has to say what canvas it packs into, or it is asserting the fixture.
---
--- Both the scrolls already handed out and any handed out inside `fn` are widened, and every one
--- is restored afterwards -- this module is a singleton shared with every other panel suite, so a
--- case that left them wide would hand the next suite a canvas it never asked for. `fn`'s error is
--- re-raised after the restore.
local function withCanvas(px, fn)
  local saved = {}
  local function widen(w)
    if w.type == "ScrollFrame" and type(w.content) == "table" then
      saved[#saved + 1] = { content = w.content, original = w.content.original_width, width = w.content.width }
      w.content.original_width = px
      w.content.width = px
    end
  end
  for _, w in ipairs(AceGUI.__created) do widen(w) end
  local create = AceGUI.Create
  AceGUI.Create = function(self, wtype, ...)
    local w = create(self, wtype, ...)
    widen(w)
    return w
  end
  local ok, err = pcall(fn)
  AceGUI.Create = create
  for _, s in ipairs(saved) do
    s.content.original_width = s.original
    s.content.width = s.width
  end
  if not ok then error(err, 0) end
end

local M = {
  AceGUI          = AceGUI,
  withCanvas      = withCanvas,
  panel           = panel,
  ctxFor          = ctxFor,
  renderPage      = renderPage,
  renderTab       = renderTab,
  GENERAL_TABS    = GENERAL_TABS,
  FILTER_SUB_TABS = FILTER_SUB_TABS,
  widgetLabeled   = widgetLabeled,
}

rawset(_G, "__BL_PANEL_SUPPORT", M)
return M
