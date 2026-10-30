-- tests/test_skin_outline.lua — the Font outline (LibKa0s v1.82.0, Skin minor 9; BL-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-06): stored as
-- settings.appearance.outline ("all", the default, "hud", "off"), written only through the skin
-- write seam (NS.WriteSkinChoice's `media.outline`), and applied with Skin:SetOutline at load, on
-- every profile event and on the row's own write. LibKa0sSkinTester's tests/test_skin_outline.lua is
-- the pattern; this suite runs on the shared addon, so every case puts the mode back on All text.

local T = _G.BL_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "BankLedger"
local PATH = "settings.appearance.outline"

local function stored() return NS.db.profile.settings.appearance.outline end

--- Run `fn` with chat silenced (a `/bl set` echoes its value) and the mode back on All text,
--- stored and applied, whatever `fn` raised.
local function clean(fn)
  return function()
    local cf = mocks.DEFAULT_CHAT_FRAME
    local add = cf.AddMessage
    cf.AddMessage = function() end
    local ok, err = pcall(fn)
    NS.db.profile.settings.appearance.outline = "all"
    Skin:SetOutline(OWNER, "all")
    cf.AddMessage = add
    if not ok then error(err, 0) end
  end
end

test("outline: a fresh profile stores All text, the library's default, and applies it", function()
  assertEqual(NS.defaults.profile.settings.appearance.outline, "all")
  assertEqual(NS.defaults.profile.settings.appearance.outline, Skin.OUTLINE_DEFAULT)
  assertEqual(stored(), "all")
  assertEqual(Skin:GetOutline(OWNER), "all")
end)

test("outline: the schema row offers the library's three modes, in its order, drawn by the tab", function()
  local row = NS.Schema:FindRow(PATH)
  assertTrue(row ~= nil, "a settings.appearance.outline row")
  assertTrue(row.skipRender == true, "the Skin tab draws it")
  assertEqual(row.group, "Appearance")
  local got = {}
  for _, opt in ipairs(row.values) do got[#got + 1] = opt.value end
  assertEqual(table.concat(got, ","), table.concat(Skin.OUTLINE_MODES, ","))
end)

test("outline: the write seam stores media.outline, and leaves it alone when it is nil", clean(function()
  -- red under: WriteSkinChoice dropping media.outline (the Skin tab's Font outline and another
  -- addon's copy would move the look and never store it).
  NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "hud" })
  assertEqual(stored(), "hud")
  NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false })
  assertEqual(stored(), "hud", "a media without outline leaves it")
  NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "off" })
  assertEqual(stored(), "off")
end))

test("outline: another addon's copy reaches the store through WriteChoice", clean(function()
  Skin:WriteChoice(OWNER, "ka0s", "ka0s", nil, { font = false, texture = false, outline = "off" })
  assertEqual(stored(), "off")
end))

test("outline: /bl set applies the mode live, and only the outline", clean(function()
  NS.Slash:CliSet(PATH .. " hud")
  assertEqual(stored(), "hud")
  assertEqual(Skin:GetOutline(OWNER), "hud", "the row's onChange applied it")
  assertEqual(NS.Skin.Token("font.outline"), "", "window text loses its outline")
  assertEqual(NS.Skin.Token("hud.outline"), "OUTLINE", "the HUD keeps it")
  NS.Slash:CliSet(PATH .. " off")
  assertEqual(NS.Skin.Token("hud.outline"), "", "Off takes both")
  NS.Slash:CliSet(PATH .. " all")
  assertEqual(NS.Skin.Token("font.outline"), "OUTLINE")
  assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "the skin did not move")
end))

test("outline: /bl set refuses a mode the library does not know", clean(function()
  NS.Slash:CliSet(PATH .. " thick")
  assertEqual(stored(), "all")
end))

test("outline: the whole-choice apply (load, profile events) applies the stored mode", clean(function()
  -- red under: ApplySkinChoice's whole-pair path not applying the stored outline.
  NS.db.profile.settings.appearance.outline = "off"
  assertEqual(Skin:GetOutline(OWNER), "all", "nothing applied yet")
  NS.ApplySkinChoice()
  assertEqual(Skin:GetOutline(OWNER), "off")
end))

test("outline: a profile switch applies the incoming profile's mode, and back", clean(function()
  local db = NS.db
  local ok, err = pcall(function()
    NS.Slash:CliSet(PATH .. " hud")
    db:SetProfile("OutlineProbe")
    assertEqual(Skin:GetOutline(OWNER), "all", "the new profile keeps the default")
    db:SetProfile("Default")
    assertEqual(Skin:GetOutline(OWNER), "hud", "Default's is back")
  end)
  if db:GetCurrentProfile() ~= "Default" then db:SetProfile("Default") end
  if db.DeleteProfile then pcall(db.DeleteProfile, db, "OutlineProbe", true) end
  if not ok then error(err, 0) end
end))

test("outline: without the skin engine the apply is a quiet no-op", function()
  local Env = dofile("tests/degraded_env.lua")
  local ns = Env.loadDegraded()
  assertEqual(type(ns.ApplySkinOutline), "function", "the degraded arm publishes it")
  assertEqual(ns.ApplySkinOutline("off"), false)
end)

test("outline: the degraded facade's FontFlags and HudFontSize answer a value, never nil", function()
  local ns = dofile("tests/degraded_env.lua").loadDegraded()
  local S = ns.Skin
  assertEqual(S.FontFlags("@skin", "window"), "", "From skin on window text: the stock flags")
  assertEqual(S.FontFlags(nil, "window"), "", "nothing on window text: the stock flags")
  assertEqual(S.FontFlags("@skin"), "OUTLINE", "From skin elsewhere: outlined")
  assertEqual(S.FontFlags("THICKOUTLINE"), "THICKOUTLINE", "a picked flag as it is")
  assertEqual(S.FontFlags("THICKOUTLINE", "window"), "THICKOUTLINE", "a picked flag wins on a window too")
  assertEqual(S.HudFontSize(14), 14, "a positive size as it is")
  assertEqual(S.HudFontSize(0), 12, "zero falls back to Ka0s Default's 12")
  assertEqual(S.HudFontSize(nil), 12, "nil falls back to Ka0s Default's 12")
end)
