-- core/MediaSetup.lua — the LibKa0s-Media-1.0 seam.
--
-- THE CASE THAT EARNS THIS FILE is the catalog cross-check. Every mark this addon asks for is a
-- plain string resolved against a catalog that now lives in ANOTHER REPO, and every path it answers
-- points into a VENDORED copy of that repo. If the library renames a mark, or a re-vendor drops a
-- file, or this addon asks for one it never shipped, the answer is nil or a path to nothing — and a
-- texture that does not load draws nothing and raises nothing, so every other suite stays green
-- while the control quietly stops being what it was. That is the failure this file exists to catch
-- out of game.
--
-- The FONT half matters for the same reason and one more: `C.FONT_MONO` used to be a string literal
-- naming this addon's own media/fonts/. It is resolved through the seam now, so the literal that
-- would have gone stale is gone — and this suite is what stops the resolution silently answering
-- STANDARD_TEXT_FONT in a working install.

local T = _G.BL_TEST
local NS = T.NS
local test = T.test
local assertEqual, assertTrue, assertNil = T.assertEqual, T.assertTrue, T.assertNil
local Loader = T.Loader

local VENDORED = "Interface\\AddOns\\BankLedger\\libs\\LibKa0s\\media\\"

local Media = T.mocks.LibStub("LibKa0s-Media-1.0", true)

-- Load a fresh, isolated environment containing the TOC's files up to and INCLUDING `stop`, with or
-- without the vendored library. The degraded arm loads the REAL fallback branch rather than a
-- hand-written stub, which is the same shape tests/test_libka0s.lua uses and for the same reason.
local function loadUpTo(stop, withLibrary)
  local m = T.makeMocks()
  local ns = {}
  if withLibrary then Loader.loadAll(T.libka0sFiles, ns, m) end
  for _, path in ipairs(Loader.tocFiles("BankLedger.toc")) do
    Loader.load(path, ns, m)
    if path == stop then break end
  end
  return ns, m
end

-- ── the seam is actually live ────────────────────────────────────────────────────────────────

test("LibKa0s-Media: the vendored major registered and the seam is published", function()
  assertTrue(Media ~= nil, "LibKa0s-Media-1.0 did not register — this whole suite proves nothing")
  assertTrue(type(NS.Icon) == "function", "core/MediaSetup.lua published no NS.Icon")
  assertTrue(type(NS.MediaFont) == "function", "core/MediaSetup.lua published no NS.MediaFont")
end)

test("LibKa0s-Media: NS.Icon answers the vendored path, EXTENSIONLESS", function()
  -- Extensionless is not a preference. The client appends the extension itself, and a path carrying
  -- `.tga` is one of the two spellings that draws nothing and raises nothing.
  assertEqual(NS.Icon("close"), VENDORED .. "icons\\close")
  assertTrue(NS.Icon("close"):match("%.tga$") == nil, "the path carries an extension")
end)

test("LibKa0s-Media: an icon the library does not ship answers nil", function()
  -- nil is a value a caller can branch on: it is what sends an art ladder down to its next rung. A
  -- plausible path to a texture that is not there is a control that is simply absent, forever,
  -- silently — which is why nothing in this addon may build a path by concatenation.
  assertNil(NS.Icon("nosuchicon"))
  assertNil(NS.Icon(""))
end)

test("LibKa0s-Media: NS.MediaFont answers the vendored face, and an unknown face answers nil",
  function()
    -- The font path KEEPS its extension where an icon path does not: SetFont wants the real file.
    assertEqual(NS.MediaFont("JetBrains Mono"), VENDORED .. "fonts\\JetBrainsMono-Regular.ttf")
    assertNil(NS.MediaFont("Comic Sans"))
  end)

-- ── the font this addon names ────────────────────────────────────────────────────────────────

test("LibKa0s-Media: C.FONT_MONO resolves through the seam, not to a literal under media/fonts/",
  function()
    -- The old value was "Interface\\AddOns\\BankLedger\\media\\fonts\\JetBrainsMono-Regular.ttf",
    -- and that directory is gone. A working install must resolve to the PAYLOAD, and must not have
    -- fallen through to the client default — which is what a MediaSetup that loaded after Constants
    -- would silently produce.
    assertEqual(NS.Constants.FONT_MONO, NS.MediaFont("JetBrains Mono"))
    assertTrue(NS.Constants.FONT_MONO:find("libs\\LibKa0s\\media", 1, true) ~= nil,
      "FONT_MONO is '" .. tostring(NS.Constants.FONT_MONO) .. "', which is not the vendored payload")
    assertTrue(NS.Constants.FONT_MONO:find("AddOns\\BankLedger\\media\\fonts", 1, true) == nil,
      "FONT_MONO still names this addon's own media/fonts/, which no longer exists")
  end)

test("LibKa0s-Media: the addon's own media/fonts/ is gone from disk", function()
  -- The bytes are the library's now. A second copy left behind is a second license to track and the
  -- other half of the LibSharedMedia collision the seam exists to end.
  local f = io.open("media/fonts/JetBrainsMono-Regular.ttf", "rb")
  assertTrue(f == nil, "media/fonts/JetBrainsMono-Regular.ttf is still on disk")
  if f then f:close() end
end)

test("LibKa0s-Media: the font name this addon stores is a key of the library's FONTS", function()
  -- Two names for one thing, in two repos: C.FONT_MONO_NAME is what anything naming the face by key
  -- would store, and the library's FONTS is what actually gets registered with LibSharedMedia. A key
  -- nobody registered renders silently in Blizzard's fallback face, which is the exact outcome
  -- shipping a monospace font was meant to prevent.
  assertTrue(Media.FONTS[NS.Constants.FONT_MONO_NAME] ~= nil,
    "FONT_MONO_NAME is '" .. tostring(NS.Constants.FONT_MONO_NAME)
    .. "', which the library's FONTS does not carry")
  assertEqual(NS.Constants.FONT_MONO, NS.MediaFont(NS.Constants.FONT_MONO_NAME))
end)

test("LibKa0s-Media: this addon no longer registers the face with LibSharedMedia itself", function()
  -- core/BankLedger.lua's OnInitialize used to call LSM:Register("font", "JetBrains Mono", …)
  -- against its own copy. Two registrations of one name against two paths is the collision; the
  -- library's own idempotent call from core/MediaSetup.lua is the single owner now. Source-level,
  -- because the duplicate would be invisible at runtime — the second write simply wins.
  -- COMMENT LINES ARE SKIPPED: the file still NAMES the call it used to make, in the note
  -- explaining why it no longer makes it, and a grep that could not tell the two apart is a test
  -- nobody could write that comment past.
  local offenders, n = {}, 0
  for line in io.lines("core/BankLedger.lua") do
    n = n + 1
    if not line:match("^%s*%-%-") and line:match('Register%s*%(%s*"font"') then
      offenders[#offenders + 1] = "core/BankLedger.lua:" .. n
    end
  end
  assertEqual(table.concat(offenders, ", "), "",
    "the addon still registers the font itself; LibKa0s-Media owns that registration")
end)

-- ── the catalog, against the vendored copy ───────────────────────────────────────────────────

test("LibKa0s-Media: every name the library ships has a file in the vendored copy", function()
  -- The library's own suite checks its catalog against its own directory. This checks the COPY: a
  -- re-vendor that dropped a file, or a packaging step that filtered one out, leaves a catalog
  -- naming art this build does not carry — and every path it answers still looks perfectly correct.
  local missing = {}
  for _, name in ipairs(Media.ICONS) do
    local fh = io.open("libs/LibKa0s/media/icons/" .. name .. ".tga", "rb")
    if fh then fh:close() else missing[#missing + 1] = name end
  end
  assertEqual(table.concat(missing, ", "), "")
end)

test("LibKa0s-Media: every icon name this addon asks for is one the library ships", function()
  -- The names are plain strings in this addon's source and the catalog is in another repo, so a
  -- rename on either side answers nil and nil draws nothing. This suite is the tripwire; the list
  -- grows as surfaces adopt marks. Empty is honest today — the seam is wired, the marks are not.
  local known = {}
  for _, name in ipairs(Media.ICONS) do known[name] = true end
  for _, name in ipairs(NS.ICON_NAMES or {}) do
    assertTrue(known[name] == true,
      "this addon draws '" .. name .. "', which LibKa0s-Media does not ship")
    assertTrue(NS.Icon(name) ~= nil, "NS.Icon answered nil for " .. name)
  end
end)

-- ── load order ───────────────────────────────────────────────────────────────────────────────

test("LibKa0s-Media: the seam loads BEFORE core/Constants.lua, which resolves the font from it",
  function()
    -- The position is load-bearing, not conventional. Reversed, C.FONT_MONO resolves to
    -- STANDARD_TEXT_FONT in a fully working install and every column loses its grid — with no error
    -- and no missing file to find.
    local toc = Loader.tocFiles("BankLedger.toc")
    local ia, ib
    for i, p in ipairs(toc) do
      if p == "core/MediaSetup.lua" then ia = i end
      if p == "core/Constants.lua" then ib = i end
    end
    assertTrue(ia ~= nil, "core/MediaSetup.lua is not in BankLedger.toc")
    assertTrue(ib ~= nil, "core/Constants.lua is not in BankLedger.toc")
    assertTrue(ia < ib, "core/MediaSetup.lua must load before core/Constants.lua (TOC positions "
      .. tostring(ia) .. " and " .. tostring(ib) .. ")")
  end)

-- ── degraded ─────────────────────────────────────────────────────────────────────────────────

test("LibKa0s-Media degraded: with no library there is no art, and that is not an error", function()
  -- The art and the face are INSIDE the payload that is missing, so a degraded install has neither.
  -- NS.Icon answering nil is what sends a caller down its ladder.
  local ns, m = loadUpTo("core/MediaSetup.lua", false)
  assertTrue(m.LibStub("LibKa0s-Media-1.0", true) == nil,
    "the degraded arm still has the library — this case would prove nothing")
  assertNil(ns.Icon("close"))
  assertNil(ns.MediaFont("JetBrains Mono"))
end)

test("LibKa0s-Media degraded: FONT_MONO falls back to a REAL CLIENT FONT, never nil and never a path",
  function()
    -- SetFont accepts a path to a file that is not there, fails to load it, and then does not draw
    -- the text at all. So the degraded rung has to be a font the CLIENT owns: the console loses its
    -- monospace grid and keeps every line on screen.
    local ns, m = loadUpTo("core/Constants.lua", false)
    assertTrue(m.LibStub("LibKa0s-Media-1.0", true) == nil, "the degraded arm still has the library")
    assertEqual(ns.Constants.FONT_MONO, m.STANDARD_TEXT_FONT)
    assertTrue(ns.Constants.FONT_MONO ~= nil, "a nil font is not a fallback")
    assertTrue(ns.Constants.FONT_MONO:find("LibKa0s", 1, true) == nil,
      "the degraded fallback still names the payload that is missing")
  end)
