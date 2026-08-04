-- The frame stub's own guard rail.
--
-- tests/wow_mock.lua's stubFrame underpins EVERY headless suite, so any drift in it breaks all of
-- them at once — and a stub with no self-test can only be debugged through whichever unrelated case
-- happened to notice. These cases pin the behaviors that are load-bearing somewhere else: the
-- shown->hidden OnHide transition the session-window cases read, the recorded scripts that make
-- LibKa0s-Options page bodies reachable at all, the geometry that makes SavedVariables position
-- round-trips assertable, the font templates behind "every card shares one headline template", and
-- the PascalCase catch-all every `if not f.someField then` in the addon depends on missing through.

local T = _G.BL_TEST
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function frame() return mocks.__stubFrame() end

-- ── Visibility ─────────────────────────────────────────────────────────────────

test("Mock frame: a stub starts SHOWN, as a real frame does", function()
  local f = frame()
  assertTrue(f:IsShown(), "real frames start shown, and nine session-window cases read that")
  assertTrue(f:IsVisible(), "IsVisible mirrors IsShown")
end)

test("Mock frame: Show, Hide and SetShown flip the one piece of state the stub models", function()
  local f = frame()
  f:Hide()
  assertFalse(f:IsShown())
  assertFalse(f:IsVisible())
  f:Show()
  assertTrue(f:IsShown())
  f:SetShown(false)
  assertFalse(f:IsShown())
  f:SetShown(true)
  assertTrue(f:IsShown())
end)

test("Mock frame: Show and Hide return the frame, so calls chain", function()
  local f = frame()
  assertEqual(f:Show(), f)
  assertEqual(f:Hide(), f)
  assertEqual(f:SetShown(true), f)
end)

test("Mock frame: OnHide fires only on a real shown->hidden transition", function()
  local f = frame()
  local fired = 0
  f:HookScript("OnHide", function() fired = fired + 1 end)
  f:Hide()
  assertEqual(fired, 1, "shown -> hidden fires it")
  f:Hide()
  assertEqual(fired, 1, "already hidden fires nothing")
  f:Show()
  f:Hide()
  assertEqual(fired, 2, "and it fires again after a re-show")
end)

test("Mock frame: OnHide handlers are called with the frame, in hook order", function()
  local f = frame()
  local seen = {}
  f:HookScript("OnHide", function(self) seen[#seen + 1] = (self == f) and "a" or "?" end)
  f:HookScript("OnHide", function(self) seen[#seen + 1] = (self == f) and "b" or "?" end)
  f:Hide()
  assertEqual(table.concat(seen), "ab")
end)

-- ── Scripts ────────────────────────────────────────────────────────────────────

test("Mock frame: SetScript RECORDS the handler and GetScript hands it back", function()
  -- A discarding stub is what left every LibKa0s-Options page body unreachable from the suite.
  local f = frame()
  local handler = function() end
  assertEqual(f:SetScript("OnShow", handler), f)
  assertEqual(f:GetScript("OnShow"), handler)
  assertEqual(f:GetScript("OnEnter"), nil, "an unset script is nil, not a no-op")
end)

test("Mock frame: __fire replays a recorded script with the frame and the extra args", function()
  local f = frame()
  local got
  f:SetScript("OnSizeChanged", function(self, w, h) got = { self, w, h }; return "ret" end)
  assertEqual(f:__fire("OnSizeChanged", 100, 40), "ret", "the handler's return is passed through")
  assertEqual(got[1], f)
  assertEqual(got[2], 100)
  assertEqual(got[3], 40)
end)

test("Mock frame: __fire on a script nobody set is a silent no-op", function()
  assertEqual(frame():__fire("OnShow"), nil)
end)

test("Mock frame: HookScript chains the PREVIOUS handler before the new one", function()
  local f = frame()
  local order = {}
  f:SetScript("OnShow", function() order[#order + 1] = "first" end)
  f:HookScript("OnShow", function() order[#order + 1] = "hooked" end)
  f:__fire("OnShow")
  assertEqual(table.concat(order, ","), "first,hooked")
end)

test("Mock frame: HookScript on a bare frame still installs a callable script", function()
  local f = frame()
  local ran = false
  assertEqual(f:HookScript("OnShow", function() ran = true end), f)
  f:__fire("OnShow")
  assertTrue(ran, "no previous handler must not stop the new one running")
end)

-- ── Geometry ───────────────────────────────────────────────────────────────────

test("Mock frame: SetPoint records the (point, x, y) form", function()
  local f = frame()
  assertEqual(f:SetPoint("TOPLEFT", 12, -8), f)
  local point, relativeTo, relativePoint, x, y = f:GetPoint()
  assertEqual(point, "TOPLEFT")
  assertEqual(relativeTo, nil)
  assertEqual(relativePoint, "TOPLEFT", "the short form mirrors the point onto relativePoint")
  assertEqual(x, 12)
  assertEqual(y, -8)
end)

test("Mock frame: SetPoint records the (point, relativeTo, relativePoint, x, y) form", function()
  local f, anchor = frame(), frame()
  f:SetPoint("BOTTOM", anchor, "TOP", 3, 4)
  local point, relativeTo, relativePoint, x, y = f:GetPoint(1)
  assertEqual(point, "BOTTOM")
  assertEqual(relativeTo, anchor)
  assertEqual(relativePoint, "TOP")
  assertEqual(x, 3)
  assertEqual(y, 4)
end)

test("Mock frame: a bare SetPoint defaults its offsets to zero", function()
  local f = frame()
  f:SetPoint("CENTER")
  local point, _, _, x, y = f:GetPoint()
  assertEqual(point, "CENTER")
  assertEqual(x, 0)
  assertEqual(y, 0)
end)

test("Mock frame: points accumulate, ClearAllPoints drops them, GetPoint misses to nil", function()
  local f = frame()
  f:SetPoint("TOP", 0, 0)
  f:SetPoint("LEFT", 1, 1)
  assertEqual(select(1, f:GetPoint(2)), "LEFT")
  assertEqual(f:GetPoint(3), nil, "past the end is nil, not a garbage table")
  assertEqual(f:ClearAllPoints(), f)
  assertEqual(f:GetPoint(), nil)
end)

test("Mock frame: size is real state through SetSize, SetWidth and SetHeight", function()
  local f = frame()
  assertEqual(f:GetWidth(), 0, "an unsized stub measures zero")
  assertEqual(f:GetHeight(), 0)
  f:SetSize(300, 200)
  assertEqual(f:GetWidth(), 300)
  assertEqual(f:GetHeight(), 200)
  f:SetWidth(120)
  assertEqual(f:GetWidth(), 120)
  assertEqual(f:GetHeight(), 200, "SetWidth leaves the height alone")
  f:SetHeight(60)
  assertEqual(f:GetHeight(), 60)
end)

-- ── Font strings ───────────────────────────────────────────────────────────────

test("Mock frame: CreateFontString returns the frame and records templates in order", function()
  local f = frame()
  assertEqual(f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), f)
  f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  assertEqual(f.__fontTemplates[1], "GameFontNormalLarge")
  assertEqual(f.__fontTemplates[2], "GameFontHighlightSmall")
  assertEqual(#f.__fontTemplates, 2)
end)

-- ── The catch-all ──────────────────────────────────────────────────────────────

test("Mock frame: any other PascalCase key is a chainable no-op", function()
  local f = frame()
  assertEqual(type(f.SetBackdropColor), "function")
  assertEqual(f:SetBackdropColor(1, 1, 1), f, "the no-op returns the frame, so calls chain")
end)

test("Mock frame: a named method always beats the catch-all", function()
  -- The lookup has to come FIRST, or IsShown would resolve to the no-op and be permanently truthy.
  local f = frame()
  f:Hide()
  assertFalse(f:IsShown())
end)

test("Mock frame: lowercase and non-string keys miss through to nil", function()
  -- This is what lets addon code do `if not f.someCustomField then f.someCustomField = ... end`.
  local f = frame()
  assertEqual(f.someCustomField, nil)
  assertEqual(f.rowIndex, nil)
  assertEqual(f[1], nil)
  assertEqual(f[true], nil)
end)
