-- tests/test_title_bar.lua — every title-bar control this addon draws itself (smoke round 1's
-- rulings 3 and 4, SR-BL of Ka0sAddonsCommonTasks docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/).
--
-- This addon draws three windows of its own, the ledger window, the session window and the export
-- modal, and each title bar carries one control, its close (modules/Browser_Chrome.lua
-- B:MakeCloseButton). The library's windows (the console, the copy window, the sim panel) are the
-- library's to pin. Per window, every control built on the title bar:
--   * shows a non-empty tooltip on hover, above the control (PlaceAttached's chrome rule, or its
--     relative fallback when the geometry cannot be read), in the owner's gtip.title, and hides it
--     on leave;
--   * paints icon.tint at rest and close.hot under the pointer (close.rest follows icon.tint in
--     every skin since SR-L3), under Ka0s Default and Obsidian.
--
-- The controls are found by watching CreateFrame while the windows build, so a control added to a
-- title bar later is held to the same two rules without a new case.

local T = _G.BL_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "BankLedger"
local SKINS = { "ka0s", "obsidian" }

local function rgb(c) return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3]) end

-- A fresh addon whose CreateFrame records every frame built with a parent, so a title bar's
-- controls can be listed after the window is built.
local function fresh()
  local m = T.makeMocks()
  local built = {}
  local create = m.CreateFrame
  m.CreateFrame = function(kind, name, parent, ...)
    local f = create(kind, name, parent, ...)
    if parent then built[#built + 1] = { frame = f, parent = parent, kind = kind } end
    return f
  end
  local ns = {}
  T.Loader.loadAll(T.libka0sFiles, ns, m)
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  ns:InitDB()
  ns.Schema:Register()
  ns.Ledger:Enable()
  return ns, m, m.LibStub("LibKa0s-Skin-1.0"), built
end

local function windows(ns)
  ns.Browser:Show()
  ns.SessionWindow:Show()
  local export = ns.Export:Open({})
  local ledger, session = ns.Browser:GetWindow(), ns.SessionWindow:GetWindow()
  return {
    { name = "ledger", bar = ledger.titleBar, close = ledger.closeButton },
    { name = "session", bar = session.titleBar, close = session.closeButton },
    { name = "export", bar = export.titleBar, close = export.closeBtn },
  }
end

local function controlsOn(built, bar)
  local out = {}
  for _, b in ipairs(built) do
    if b.parent == bar and b.kind == "Button" then out[#out + 1] = b.frame end
  end
  return out
end

-- A GameTooltip that records what a hover told it.
local function spyTip(m)
  local seen = { shown = false, hidden = false }
  m.GameTooltip = {
    SetOwner = function(_, owner, anchor) seen.owner, seen.anchor = owner, anchor end,
    SetText = function(_, text, r, g, b) seen.text, seen.color = text, r and { r, g, b } end,
    Show = function() seen.shown = true end,
    Hide = function() seen.hidden = true end,
    IsOwned = function(_, f) return f == seen.owner end,
    ClearAllPoints = function() end,
    SetPoint = function(_, point, rel, relPoint) seen.point, seen.rel, seen.relPoint = point, rel, relPoint end,
  }
  return seen
end

test("title bar: every control on each of this addon's windows shows its tooltip above it, in gtip.title",
  function()
    local ns, m, _, built = fresh()
    local list = windows(ns)
    local title = rgb({ ns.Skin.Color("gtip.title") })
    local ok, err = pcall(function()
      for _, w in ipairs(list) do
        local controls = controlsOn(built, w.bar)
        assertTrue(#controls >= 1, w.name .. ": no control on the title bar")
        assertTrue(w.close ~= nil, w.name .. ": no close control")
        for i, c in ipairs(controls) do
          local what = ("%s title-bar control %d"):format(w.name, i)
          local seen = spyTip(m)
          c:__fire("OnEnter")
          assertTrue(type(seen.text) == "string" and seen.text ~= "", what .. ": no tooltip on hover")
          assertTrue(seen.shown and seen.owner == c, what .. ": the tooltip is not shown for the control")
          assertEqual(seen.anchor, "ANCHOR_NONE", what .. ": the tooltip is placed, never at the cursor")
          assertTrue(seen.point == "BOTTOM" and seen.rel == c and seen.relPoint == "TOP",
            what .. ": the tooltip is not above the control")
          assertTrue(seen.color ~= nil and rgb(seen.color) == title, what .. ": not in the owner's gtip.title")
          c:__fire("OnLeave")
          assertTrue(seen.hidden, what .. ": the tooltip is not hidden on leave")
        end
        local seen = spyTip(m)
        w.close:__fire("OnEnter")
        assertEqual(seen.text, "Close", w.name .. ": the close's words")
        w.close:__fire("OnLeave")
      end
    end)
    m.GameTooltip = nil
    if not ok then error(err, 0) end
  end)

-- The art says what it is (the primitive reaches it only as a Texture / FontString) and remembers
-- its last tint itself: the mock's regions store no color (tests/test_skin_windows.lua's watchArt).
local function watchArt(close)
  local art = close.icon or close.glyph
  local kind = close.icon and "Texture" or "FontString"
  rawset(art, "GetObjectType", function() return kind end)
  local box = {}
  local function remember(_, r, g, b) box.last = { r, g, b } end
  rawset(art, "SetVertexColor", remember)
  rawset(art, "SetTextColor", remember)
  return function()
    assertTrue(box.last ~= nil, "nothing tinted the close control's art")
    return rgb(box.last)
  end
end

test("title bar: every window's close rests in icon.tint and lights close.hot, under Ka0s Default and Obsidian",
  function()
    local ns, m, Skin = fresh()
    local list = windows(ns)
    local painted = {}
    for _, w in ipairs(list) do painted[w.name] = watchArt(w.close) end
    local ok, err = pcall(function()
      for _, key in ipairs(SKINS) do
        Skin:SetChoice(OWNER, "ka0s", key)
        if m.__fireTimers then m.__fireTimers() end
        local t = Skin:ResolveSkin(key)
        local rest, hot = rgb(t["icon.tint"]), rgb(t["close.hot"])
        assertEqual(rgb({ ns.Skin.Color("icon.tint") }), rest, key .. ": the owner does not resolve icon.tint")
        for _, w in ipairs(list) do
          local what = w.name .. " under " .. key
          w.close:__fire("OnLeave")
          assertEqual(painted[w.name](), rest, what .. ": the close does not rest in icon.tint")
          w.close:__fire("OnEnter")
          assertEqual(painted[w.name](), hot, what .. ": the close does not light close.hot")
          w.close:__fire("OnLeave")
          assertEqual(painted[w.name](), rest, what .. ": the close does not return to icon.tint")
        end
      end
    end)
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    if m.__fireTimers then m.__fireTimers() end
    if not ok then error(err, 0) end
  end)
