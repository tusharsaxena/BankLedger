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

-- A FONTSTRING IS ITS OWN WIDGET, and it has the client's font rule. Both halves of this were
-- missing, and both hid the same class of defect: answering CreateFontString with the FRAME meant a
-- row's label and its glyph were one object carrying one font, so a glyph that never had a face of
-- its own looked exactly like one that did; and a SetText that only recorded meant a bare
-- FontString never raised `FontString:SetText(): Font not set`, which is the crash LibKa0s v1.11.0
-- and v1.11.1 shipped and which 553 green library cases sailed over. CreateTexture was given its
-- own stub for the same class of reason (see the note above it in tests/wow_mock.lua).
--
-- ../LibKa0s/tests/test_widgets.lua's geomFrame is the reference implementation; these cases pin
-- the same rule here.

test("Mock frame: CreateFontString answers with its OWN object, not the frame", function()
  local f = frame()
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  assertFalse(fs == f, "a label is not its parent under another name")
  local other = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  assertFalse(fs == other, "a row's label and its glyph are two objects, not one")
end)

test("Mock frame: sizing a FontString does not resize its parent", function()
  -- The same failure the texture stub was written for: a widget sizes a button, then sizes the
  -- text inside it, and the button ends up measuring the text.
  local f = frame()
  f:SetSize(120, 20)
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetWidth(12)
  assertEqual(f:GetWidth(), 120, "the parent keeps its own width")
  assertEqual(fs:GetWidth(), 12)
end)

test("Mock frame: CreateFontString still records the templates it was asked for, in order",
  function()
    local f = frame()
    f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    assertEqual(f.__fontTemplates[1], "GameFontNormalLarge")
    assertEqual(f.__fontTemplates[2], "GameFontHighlightSmall")
    assertEqual(#f.__fontTemplates, 2)
  end)

test("Mock frame: a FontString with NO font raises on SetText, exactly as the client does",
  function()
    local f = frame()
    local fs = f:CreateFontString()      -- bare: no template, and nobody called SetFont
    local err = T.assertError(function() fs:SetText("x") end,
      "a bare FontString must refuse SetText")
    assertTrue(err:find("Font not set", 1, true) ~= nil,
      "and it must refuse it with the client's own words: " .. err)
  end)

test("Mock frame: a FontString built FROM A TEMPLATE has a font and accepts SetText", function()
  local f = frame()
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetText("ok")
  assertEqual(fs:GetText(), "ok")
end)

test("Mock frame: SetFont is what rescues a bare FontString, and it is recorded", function()
  local f = frame()
  local fs = f:CreateFontString()
  fs:SetFont("Interface\\AddOns\\X\\mono.ttf", 11, "")
  fs:SetText("^")
  assertEqual(fs.__font[1], "Interface\\AddOns\\X\\mono.ttf")
  assertEqual(fs.__font[2], 11)
end)

test("Mock frame: the FONT rule is a FontString rule, not a frame rule", function()
  -- A plain frame or a button has no such restriction; only a FontString does.
  local f = frame()
  f:SetText("button words")
  assertEqual(f:GetText(), "button words")
end)

test("Mock frame: a FontString measures its text rather than answering with a frame", function()
  -- LibKa0s-Widgets-1.0's menuWidth does `(measure:GetStringWidth() or 0) + pad`. The catch-all
  -- answered that with the frame itself, so the arithmetic raised -- which is why
  -- tests/test_browser.lua had to force GetStringWidth sane around its real-click case.
  local f = frame()
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetText("abcde")
  assertEqual(fs:GetStringWidth(), 30, "6px a character, the same rule geomFrame uses")
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
