-- tests/test_tooltip_place.lua — where every tooltip this addon places itself opens (AD-92-BL,
-- LibKa0s#92; WowAddonStandards standalone-windows, *Tooltip placement*).
--
-- Each surface is classified once, here and in docs/ARCHITECTURE.md (## Tooltip placement):
--   * BODY (PlaceBeside, the window group as the group): the History table's rows and column
--     headers, the session window's rows and column headers, and every Insights card, bar, bar
--     side, stacked segment, strip column, list row and legend swatch;
--   * CHROME (PlaceAttached on the control): the filter bar's four buttons and both windows' mode
--     strips.
-- The title-bar controls are the library's (AttachTitleTip), pinned in tests/test_title_bar.lua.
--
-- Per surface the case hovers the element through its real OnEnter and asserts: the tooltip is
-- owned at ANCHOR_NONE (never the cursor, never a corner), the right placer ran with the hovered
-- element and, for a body element, the element's window as the group, the content is still there,
-- and leaving hides it. The fake-screen cases drive the real placers through NS.Util's two helpers
-- (right fits, right does not fit, and the fallback when nothing can be read), and a source guard
-- holds the addon's own files to no cursor anchor, no corner anchor and no cursor read.

local T = _G.BL_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local NOW = 1770000000

local function fresh()
  local m = T.makeMocks()
  local ns = {}
  T.Loader.loadAll(T.libka0sFiles, ns, m)
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  ns:InitDB()
  ns.Schema:Register()
  ns.Ledger:Enable()
  return ns, m
end

-- A GameTooltip that records what a hover told it, and the two placers swapped for recorders that
-- answer as the real ones do when they place (so no fallback runs).
local function spy(m)
  local seen = { lines = {}, places = {}, shown = false, hidden = false }
  m.GameTooltip = {
    SetOwner = function(_, owner, anchor) seen.owner, seen.anchor = owner, anchor end,
    AddLine = function(_, text) seen.lines[#seen.lines + 1] = text end,
    AddDoubleLine = function(_, l, r) seen.lines[#seen.lines + 1] = tostring(l) .. "=" .. tostring(r) end,
    SetHyperlink = function(_, link) seen.link = link end,
    SetText = function(_, text) seen.lines[#seen.lines + 1] = text end,
    ClearLines = function() end,
    Show = function() seen.shown = true end,
    Hide = function() seen.hidden = true end,
    IsOwned = function(_, f) return f == seen.owner end,
    ClearAllPoints = function() end,
    SetPoint = function(_, point, rel, relPoint) seen.point, seen.rel, seen.relPoint = point, rel, relPoint end,
  }
  local Tip = m.LibStub("LibKa0s-Tooltip-1.0")
  local realB, realA = Tip.PlaceBeside, Tip.PlaceAttached
  Tip.PlaceBeside = function(tip, el, group)
    seen.places[#seen.places + 1] = { how = "beside", tip = tip, el = el, group = group, shown = seen.shown }
    return "right"
  end
  Tip.PlaceAttached = function(tip, el)
    seen.places[#seen.places + 1] = { how = "attached", tip = tip, el = el, shown = seen.shown }
    return "above"
  end
  seen.restore = function() Tip.PlaceBeside, Tip.PlaceAttached = realB, realA; m.GameTooltip = nil end
  return seen
end

-- Hover `el`, run the assertions, always restore the spies.
local function hover(m, el, check)
  local seen = spy(m)
  local ok, err = pcall(function()
    el:__fire("OnEnter")
    check(seen)
    el:__fire("OnLeave")
    assertTrue(seen.hidden, "leaving did not hide the tooltip")
  end)
  seen.restore()
  if not ok then error(err, 0) end
end

local function assertPlaced(seen, how, el, group, what)
  assertEqual(seen.anchor, "ANCHOR_NONE", what .. ": the tooltip is not owned at ANCHOR_NONE")
  assertTrue(seen.owner == el, what .. ": the tooltip is not owned by the hovered element")
  assertEqual(#seen.places, 1, what .. ": the tooltip was not placed exactly once")
  local p = seen.places[1]
  assertEqual(p.how, how, what .. ": the wrong placer")
  assertTrue(p.el == el, what .. ": placed against something other than the hovered element")
  assertTrue(p.shown, what .. ": placed before Show, so its size was not known")
  if group then assertTrue(p.group == group, what .. ": the group is not the element's window") end
end

local function entry(over)
  local x = { ts = NOW, char = "Mock-Realm", classFile = "MAGE", kind = "ITEM", direction = "DEPOSIT",
    store = "BANK", itemID = 2589, itemName = "Linen Cloth", quality = 1, quantity = 10,
    itemLink = "|cffffffff|Hitem:2589::::::::70:::::|h[Linen Cloth]|h|r" }
  for k, v in pairs(over or {}) do x[k] = v end
  return x
end

-- ── Body: the History table ─────────────────────────────────────────────────────

test("tooltips: a History row's item tooltip opens beside the ledger window, not off its corner", function()
  -- red under: GameTooltip:SetOwner(row, "ANCHOR_RIGHT") in LT:BuildRow's OnEnter.
  local ns, m = fresh()
  ns.Browser:Show()
  local win = ns.Browser:GetWindow()
  local row = ns.LedgerTable:BuildRow()
  row.item = { kind = "row", entry = entry() }
  hover(m, row, function(seen)
    assertPlaced(seen, "beside", row, win, "History item row")
    assertTrue(seen.link ~= nil, "the item tooltip lost its hyperlink")
    assertTrue(seen.lines[1]:find("Shift-click to link", 1, true) ~= nil, "the hint line is gone")
  end)
  row.item = { kind = "row", entry = entry({ kind = "MONEY", itemLink = false, quantity = 12345 }) }
  hover(m, row, function(seen)
    assertPlaced(seen, "beside", row, win, "History money row")
    assertTrue(#seen.lines >= 2, "the money tooltip lost its lines")
  end)
end)

test("tooltips: a History column header is a body element, placed beside the ledger window", function()
  -- red under: GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM") in LT:MakeHeaderButton.
  local ns, m = fresh()
  ns.Browser:Show()
  local btn = ns.LedgerTable:MakeHeaderButton(ns.LedgerTable:Column("item"))
  hover(m, btn, function(seen)
    assertPlaced(seen, "beside", btn, ns.Browser:GetWindow(), "History column header")
    assertTrue(#seen.lines >= 1, "the column tooltip lost its label")
  end)
end)

-- ── Body: the session window ────────────────────────────────────────────────────

test("tooltips: a session row and a session column header open beside the session window", function()
  -- red under: ANCHOR_RIGHT in SW:BuildRow's OnEnter, ANCHOR_BOTTOM in SW:BuildHeaderCells.
  local ns, m = fresh()
  ns.SessionWindow:Show()
  local win = ns.SessionWindow:GetWindow()
  local row = ns.SessionWindow:BuildRow()
  row.entry = entry()
  hover(m, row, function(seen)
    assertPlaced(seen, "beside", row, win, "session item row")
    assertTrue(seen.link ~= nil, "the item tooltip lost its hyperlink")
  end)
  row.entry = entry({ kind = "MONEY", itemLink = false, quantity = 500 })
  hover(m, row, function(seen) assertPlaced(seen, "beside", row, win, "session money row") end)
  local _, cell = next(ns.SessionWindow.headerFrame.cells)
  assertTrue(cell ~= nil, "the session window built no header cell")
  hover(m, cell, function(seen)
    assertPlaced(seen, "beside", cell, win, "session column header")
    assertTrue(#seen.lines >= 1, "the column tooltip lost its label")
  end)
end)

-- ── Body: Insights ──────────────────────────────────────────────────────────────

test("tooltips: every Insights widget's tip opens beside the ledger window, never at the cursor", function()
  -- red under: W.CursorTooltip's GetCursorPosition point, ANCHOR_BOTTOM on the card, ANCHOR_TOP on
  -- the strip column.
  local ns, m = fresh()
  ns.Browser:Show()
  local win = ns.Browser:GetWindow()
  local W = ns.InsightsWidgets
  local parent = m.CreateFrame("Frame", nil, win)
  local card = W.MakeCard(parent); card._tip, card._caption = "card body", "Card"
  local bar = W.MakeBar(parent); bar._tip = "bar tip"
  local split = W.MakeSplitBar(parent); split.left._tip = "left tip"
  local stack = W.MakeStackedBar(parent)
  local strip = W.MakeStripBar(parent); strip._tip = "strip tip"
  local list = W.MakeListRow(parent); list._tip = "list tip"
  local swatch = W.MakeSwatch(parent); swatch._tip = "swatch tip"
  local b2b = W.MakeBackToBackBar(parent); b2b._tip = "b2b tip"; b2b.leftSide._tip = "b2b side tip"
  stack._tip = "stack tip"; stack.segs[1]._tip = "seg tip"
  local els = { card = card, bar = bar, ["split side"] = split.left, strip = strip, list = list, swatch = swatch,
    ["stacked bar"] = stack, ["stacked segment"] = stack.segs[1], ["back-to-back bar"] = b2b,
    ["back-to-back side"] = b2b.leftSide }
  for name, el in pairs(els) do
    hover(m, el, function(seen)
      assertPlaced(seen, "beside", el, win, "Insights " .. name)
      assertTrue(#seen.lines >= 1, "Insights " .. name .. ": the tip lost its text")
    end)
  end
end)

-- ── Chrome: the filter bar and the mode strips ──────────────────────────────────

test("tooltips: a filter-bar button's tip is attached above the button", function()
  -- red under: GameTooltip:SetOwner(b, "ANCHOR_BOTTOM") in makeBarButton.
  local ns, m = fresh()
  ns.Browser:Show()
  local btn = ns.Browser._exportBtn
  hover(m, btn, function(seen)
    assertPlaced(seen, "attached", btn, nil, "filter-bar Export")
    assertTrue((seen.lines[1] or ""):find("Export", 1, true) ~= nil, "the button's words are gone")
  end)
end)

test("tooltips: both windows' mode strips attach their tip above the strip", function()
  -- red under: ANCHOR_BOTTOM in Browser's buildModeStrip and SessionWindow's buildStrip.
  local ns, m = fresh()
  ns.Browser:Show()
  ns.SessionWindow:Show()
  local strips = { ledger = ns.Browser:GetWindow().testStrip, session = ns.SessionWindow:GetWindow().simStrip }
  for name, strip in pairs(strips) do
    assertTrue(strip ~= nil, name .. ": no mode strip was built")
    hover(m, strip, function(seen)
      assertPlaced(seen, "attached", strip, nil, name .. " mode strip")
      assertTrue(#seen.lines >= 2, name .. ": the strip tooltip lost its lines")
    end)
  end
end)

-- ── The helpers on the fake screen ──────────────────────────────────────────────

test("tooltips: Util.TipBeside opens right of the window when it fits, left when it does not, top level with the row",
  function()
    local ns, m = fresh()
    local scr = dofile("tests/_kit/mock_screen.lua")(m, { width = 1920, height = 1080 })
    local ok, err = pcall(function()
      local win = scr.frame{ left = 400, bottom = 300, width = 300, height = 400 }
      local row = scr.frame{ left = 400, bottom = 580, width = 300, height = 20, parent = win }
      local tip = scr.tooltip{ width = 250, height = 90 }
      ns.Util.TipOwn(row, tip)
      assertEqual(ns.Util.TipBeside(tip, row, win), "right")
      local l, _, _, t = scr.rectOf(tip)
      assertEqual(l, 702, "the tooltip's left is not the window's right edge + 2")
      assertEqual(t, 600, "the tooltip's top is not level with the row's top")
      win:__place(1500, 300, 300, 400)
      row:__place(1500, 580, 300, 20)
      assertEqual(ns.Util.TipBeside(tip, row, win), "left")
      local _, _, r, t2 = scr.rectOf(tip)
      assertEqual(r, 1498, "the tooltip's right is not the window's left edge - 2")
      assertEqual(t2, 600, "the tooltip's top is not level with the row's top")
      assertTrue(not scr.ops(tip):find("SetOwner", 1, true) or tip.__log[1].anchor == "ANCHOR_NONE",
        "the tooltip was owned at a client anchor")
    end)
    scr.restore()
    if not ok then error(err, 0) end
  end)

test("tooltips: Util.TipAttached centers the tip 2 px above its control", function()
  local ns, m = fresh()
  local scr = dofile("tests/_kit/mock_screen.lua")(m, { width = 1920, height = 1080 })
  local ok, err = pcall(function()
    local btn = scr.frame{ left = 800, bottom = 500, width = 60, height = 20 }
    local tip = scr.tooltip{ width = 200, height = 40 }
    ns.Util.TipOwn(btn, tip)
    assertEqual(ns.Util.TipAttached(tip, btn), "above")
    local l, b, r = scr.rectOf(tip)
    assertEqual(b, 522, "the tooltip's bottom is not the control's top + 2")
    assertEqual((l + r) / 2, 830, "the tooltip is not centered on the control")
  end)
  scr.restore()
  if not ok then error(err, 0) end
end)

test("tooltips: with geometry it cannot read, a helper attaches above the element, never at the cursor",
  function()
    local ns, m = fresh()
    local seen = spy(m)
    local Tip = m.LibStub("LibKa0s-Tooltip-1.0")
    Tip.PlaceBeside = function() return nil end
    Tip.PlaceAttached = function() return nil end
    local el = m.CreateFrame("Frame", nil, m.UIParent)
    local ok, err = pcall(function()
      local tip = ns.Util.TipOwn(el)
      assertTrue(tip == m.GameTooltip, "TipOwn did not answer GameTooltip")
      assertEqual(seen.anchor, "ANCHOR_NONE")
      for _, place in ipairs({ ns.Util.TipBeside, ns.Util.TipAttached }) do
        seen.point = nil
        assertEqual(place(tip, el), nil, "an unreadable placement answered a side")
        assertTrue(seen.point == "BOTTOM" and seen.rel == el and seen.relPoint == "TOP",
          "the fallback is not above the element")
      end
    end)
    seen.restore()
    if not ok then error(err, 0) end
  end)

-- ── Source guard ────────────────────────────────────────────────────────────────

test("tooltips: the addon's own code anchors no tooltip at the cursor or a corner, and reads no cursor", function()
  -- red under: any ANCHOR_* literal other than ANCHOR_NONE, a GetCursorPosition call, or a
  -- GameTooltip:SetOwner outside core/Util.lua's TipOwn. Comments are stripped first.
  local files = {}
  for _, f in ipairs(T.Loader.tocFiles("BankLedger.toc")) do
    if f:match("%.lua$") then files[#files + 1] = f end
  end
  assertTrue(#files > 20, "the guard found too few addon files to be reading the TOC")
  for _, path in ipairs(files) do
    local fh = assert(io.open(path, "rb"))
    local src = fh:read("*a"); fh:close()
    src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    for anchor in src:gmatch("ANCHOR_[%u_]+") do
      assertEqual(anchor, "ANCHOR_NONE", path .. " anchors a tooltip at " .. anchor)
    end
    assertTrue(not src:find("GetCursorPosition", 1, true), path .. " places by the cursor")
    if path ~= "core/Util.lua" then
      assertTrue(not src:find("GameTooltip:SetOwner", 1, true), path .. " owns GameTooltip itself, past Util.TipOwn")
    end
  end
end)
