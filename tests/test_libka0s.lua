-- The LibKa0s seams: that they are actually wired, that they render the same bytes as the code they
-- replaced, and that they degrade rather than error when the vendored library is absent.
--
-- Three of these deserve saying out loud, because none of them is the obvious test:
--
-- * The DEGRADED cases load the addon WITHOUT libs/LibKa0s at all, in a second isolated environment,
--   rather than hand-stubbing the absence. A hand-stubbed absence tests the stub; this tests the
--   branch that actually runs in the install the branch exists for.
-- * The BYTE cases compare rendered strings, not "did it run". A test that passed before and after
--   proves nothing about a formatter that changed hands.
-- * The L-TRAP cases. `LibKa0s-Core-1.0` ships no `STRINGS` and reads no descriptor `L`, so a
--   "the rendered label is prose, not its own key" assertion here is a case that CANNOT fail — worse
--   than no case, because it reads as coverage. What stands in for it is a TRIPWIRE on the library:
--   the day Core grows a user-visible string, these go red and whoever bumps that minor writes the
--   real assertion. The source guard below is the other half, and it is deliberately not anchored to
--   one spelling — see its own comment.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Loader = T.Loader

local lib = T.mocks.LibStub("LibKa0s-Core-1.0", true)

local function captureChat(fn, m)
  m = m or T.mocks
  local out = {}
  local saved = m.DEFAULT_CHAT_FRAME.AddMessage
  m.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  m.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

-- ── the seam is actually live ────────────────────────────────────────────────────────────────
--
-- Every byte-parity case below would also pass against the OLD hand-written printer, because that
-- is the whole point of the swap. These three are what make the rest mean something.

test("LibKa0s-Core: the vendored major registered and the addon is running on it", function()
  assertTrue(lib ~= nil, "LibKa0s-Core-1.0 did not register — the seam is untested")
  assertTrue(NS.SafeToString == lib.SafeToString,
    "NS.SafeToString is not the library's — core/CoreSetup.lua took its fallback branch")
  assertTrue(NS.IsConcatSafe == lib.IsConcatSafe, "NS.IsConcatSafe is not the library's")
end)

test("LibKa0s-Core: the sentinel is the library's, not a hand-copied literal", function()
  assertEqual(lib.SECRET, "<secret>")
  assertEqual(NS.SafeToString({}), lib.SECRET)
end)

-- Load a fresh, isolated environment containing the TOC's files up to and INCLUDING `stop`.
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

test("LibKa0s-Core: the seam publishes ONE object to NS.Print and NS.Util.print", function()
  -- Asserted at the seam, before core/BankLedger.lua runs — and that is the whole point. The
  -- AceConsole embed there stamps :Print over NS.Print and the reclaim repoints NS.Print AT
  -- NS.Util.print, which makes the two equal from then on no matter what the seam published. So
  -- the same assertion taken on the fully-loaded namespace is VACUOUS: it passes just as happily
  -- when the seam publishes a distinct wrapper, which is exactly what a mutation proved.
  --
  -- Identity, not equivalence, is what matters: the five files that do `local print = NS.Print`
  -- capture whatever the reclaim left behind, and a wrapper would leave them holding a copy that a
  -- later repoint no longer reaches.
  local ns = loadUpTo("core/CoreSetup.lua", true)
  assertTrue(ns.Print ~= nil, "the seam published no printer")
  assertTrue(ns.Print == ns.Util.print,
    "core/CoreSetup.lua must publish the SAME function object under both names, not a wrapper")
end)

test("LibKa0s-Core: the reclaim in core/BankLedger.lua survives the AceConsole embed", function()
  -- The other half: after the whole TOC has loaded, NS.Print is the tagged printer again rather
  -- than AceConsole's green untagged :Print.
  assertTrue(NS.Print == NS.Util.print)
  local out = captureChat(function() NS.Print("reclaimed") end)
  assertEqual(out[1], "|cff00ffff[BL]|r reclaimed")
end)

-- ── rendered bytes ───────────────────────────────────────────────────────────────────────────

test("LibKa0s-Core: a printed line is byte-identical to the pre-library printer", function()
  local out = captureChat(function() NS.Print("hello", 42) end)
  assertEqual(#out, 1)
  assertEqual(out[1], "|cff00ffff[BL]|r hello 42")
end)

test("LibKa0s-Core: a bare NS.Print() emits the tag and its separator", function()
  -- The one input on which the library and the pre-library printer disagree: the old single-concat
  -- form emitted a bare tag with no trailing space, Core emits `tag .. sep`. Nothing in this addon
  -- calls NS.Print with no arguments, so no user-visible line moves — but it is a rendered-output
  -- change and it is pinned here rather than left to be rediscovered.
  local out = captureChat(function() NS.Print() end)
  assertEqual(out[1], "|cff00ffff[BL]|r ")
end)

test("LibKa0s-Core: the degraded fallback renders the SAME bytes as the library on every input",
  function()
    -- A degraded install that rendered differently from a working one is a bug report nobody can
    -- reproduce. Drive both printers over the same inputs and compare byte for byte.
    local ns, m = loadUpTo("core/CoreSetup.lua", false)
    assertTrue(m.LibStub("LibKa0s-Core-1.0", true) == nil, "the fallback branch was not taken")
    local cases = {
      { "hello", 42 },
      { },
      { "value", {} },
      { nil, true, false, n = 3 },
      { "" },
    }
    for i, args in ipairs(cases) do
      local n = args.n or #args
      local viaLib = captureChat(function() NS.Print(unpack(args, 1, n)) end)
      local viaFallback = captureChat(function() ns.Print(unpack(args, 1, n)) end, m)
      -- The fallback says the once-only notice first; compare the payload line.
      assertEqual(viaFallback[#viaFallback], viaLib[#viaLib], "case " .. i .. " diverges")
    end
  end)

test("LibKa0s-Core: an unconcatenable argument renders as the sentinel, never raising", function()
  local out = captureChat(function() NS.Print("value", {}) end)
  assertEqual(out[1], "|cff00ffff[BL]|r value <secret>")
end)

test("LibKa0s-Core: nil and booleans are not masked by the secret guard", function()
  local out = captureChat(function() NS.Print(nil, true, false) end)
  assertEqual(out[1], "|cff00ffff[BL]|r nil true false")
end)

test("LibKa0s-Core: the prefix is re-read on every call, so a later change lands", function()
  -- The descriptor passes `prefix` as a FUNCTION. A captured string would freeze the tag at load.
  local saved = NS.PREFIX
  NS.PREFIX = "|cff00ffff[XX]|r"
  local out = captureChat(function() NS.Print("moved") end)
  NS.PREFIX = saved
  assertEqual(out[1], "|cff00ffff[XX]|r moved")
end)

-- ── the degraded install ─────────────────────────────────────────────────────────────────────
--
-- A second, fully isolated environment with NO libs/LibKa0s loaded. This is the install the
-- fallback branch of core/CoreSetup.lua exists for, and the only way to exercise it honestly.

local function loadDegraded()
  local m = T.makeMocks()
  local ns = {}
  Loader.loadAll(Loader.tocFiles("BankLedger.toc"), ns, m)
  return ns, m
end

test("LibKa0s-Core degraded: the addon loads with no library at all", function()
  local ns, m = loadDegraded()
  assertTrue(m.LibStub("LibKa0s-Core-1.0", true) == nil,
    "the degraded environment still has the library — this case proves nothing")
  assertEqual(type(ns.Print), "function")
  assertEqual(type(ns.SafeToString), "function")
  assertEqual(type(ns.IsConcatSafe), "function")
  assertTrue(ns.Print == ns.Util.print, "the fallback must publish under both names too")
end)

test("LibKa0s-Core degraded: the fallback printer renders the same bytes", function()
  local ns, m = loadDegraded()
  local out = captureChat(function() ns.Print("hello", 42) end, m)
  -- Line 1 is the once-only notice; the line the caller asked for follows it.
  assertEqual(out[#out], "|cff00ffff[BL]|r hello 42")
  assertEqual(ns.SafeToString({}), "<secret>")
end)

test("LibKa0s-Core degraded: the notice is said exactly ONCE, on the first line printed", function()
  local ns, m = loadDegraded()
  local out = captureChat(function()
    ns.Print("one")
    ns.Print("two")
    ns.Print("three")
  end, m)
  assertEqual(#out, 4, "expected one notice plus three lines")
  assertEqual(out[1], "|cff00ffff[BL]|r The LibKa0s library is missing from this installation of "
    .. "Ka0s Bank Ledger (expected in libs/LibKa0s); running on reduced built-in fallbacks.")
  assertEqual(out[2], "|cff00ffff[BL]|r one")
  assertEqual(out[3], "|cff00ffff[BL]|r two")
  assertEqual(out[4], "|cff00ffff[BL]|r three")
end)

test("LibKa0s: the shared cause clause is set on BOTH paths, word for word", function()
  -- The later seams append their own "so <what> is unavailable" to this one string, so a degraded
  -- install says the same thing about WHY at every site. The wording is shared across the whole Ka0s
  -- collection and is not this addon's to reword.
  local EXPECTED = "The LibKa0s library is missing from this installation of Ka0s Bank Ledger "
    .. "(expected in libs/LibKa0s)"
  assertEqual(NS.LIBKA0S_MISSING, EXPECTED, "the cause clause must be set outside the `if not lib` "
    .. "branch — the later seams read it whether or not the library is present")
  local ns = loadDegraded()
  assertEqual(ns.LIBKA0S_MISSING, EXPECTED)
end)

-- ── the L trap ───────────────────────────────────────────────────────────────────────────────

test("LibKa0s-Core tripwire: Core ships no STRINGS and reads no descriptor L", function()
  -- Core cannot express the L trap, so there is no rendered label here to assert on. This stands in
  -- for one: the day Core grows a user-visible string, this goes red and whoever bumps that minor
  -- writes the real assertion instead of shipping an unguarded surface.
  assertTrue(rawget(lib, "STRINGS") == nil,
    "LibKa0s-Core-1.0 has grown a STRINGS table — it can now express the L trap, so this tripwire "
    .. "must be replaced by a real rendered-string assertion")
  local src = Loader.readFile("libs/LibKa0s/Core.lua")
  assertTrue(src:find("STRINGS", 1, true) == nil, "Core.lua now names STRINGS")
  assertTrue(src:find("d.L", 1, true) == nil, "Core.lua now reads a descriptor L")
end)

-- The source guard for every seam file. A descriptor field is not observable after `lib:New`
-- returns, so the only way to pin "no descriptor was handed the addon-wide locale table" is to read
-- the source.
--
-- It matches on what the expression EVALUATES TO, not on one spelling. The obvious end-anchored
-- `L = NS.L` misses `L = NS.L or { ... }` completely — and NS.L is always truthy, so that spelling
-- evaluates to the locale table itself and is just as broken. `L = NS.L and { ... } or nil` is the
-- legitimate form and must pass.
local function offendingLocaleDescriptor(src)
  for line in src:gmatch("[^\r\n]+") do
    local rest = line:match("[%s,{]L%s*=%s*(.*)$") or line:match("^L%s*=%s*(.*)$")
    if rest then
      local head, next_ = rest:match("^(NS%.L)%s*([%w_]*)")
      if head and next_ ~= "and" then return line end
    end
  end
  return nil
end

local SEAM_FILES = { "core/CoreSetup.lua", "core/DebugLogSetup.lua" }

test("LibKa0s: no seam file hands a descriptor the addon-wide locale table", function()
  for _, path in ipairs(SEAM_FILES) do
    local bad = offendingLocaleDescriptor(Loader.readFile(path))
    assertTrue(bad == nil, path .. " passes NS.L (or a chain evaluating to it) as a descriptor L: "
      .. tostring(bad))
  end
end)

test("LibKa0s: the locale-descriptor matcher catches all three spellings", function()
  -- A matcher nothing tests can be narrowed back to a single anchored form while still reporting
  -- green, which is exactly how it got there in a sibling addon.
  assertTrue(offendingLocaleDescriptor("    L = NS.L,") ~= nil, "the bare table must be caught")
  assertTrue(offendingLocaleDescriptor("    L = NS.L or { A = 'x' },") ~= nil,
    "`or` still evaluates to the locale table — it must be caught")
  assertTrue(offendingLocaleDescriptor("    L = NS.L and { A = 'x' } or nil,") == nil,
    "the `and` form evaluates to the plain table and is legitimate")
  assertTrue(offendingLocaleDescriptor("    L = { A = 'x' },") == nil, "a plain table is fine")
  assertTrue(offendingLocaleDescriptor("local L = NS.L") ~= nil,
    "a file-scope capture handed on is still the locale table")
end)

-- ── vendoring and load order ─────────────────────────────────────────────────────────────────

test("LibKa0s: the harness loads every file LibKa0s.xml declares, in XML order", function()
  local xml = Loader.readFile("libs/LibKa0s/LibKa0s.xml")
  local declared = {}
  for f in xml:gmatch('<Script file="([^"]+)"') do declared[#declared + 1] = "libs/LibKa0s/" .. f end
  assertTrue(#declared > 0, "could not parse libs/LibKa0s/LibKa0s.xml")
  assertEqual(#T.libka0sFiles, #declared,
    "tests/run.lua's LIBKA0S_FILES has drifted from LibKa0s.xml")
  for i, path in ipairs(declared) do
    assertEqual(T.libka0sFiles[i], path, "LIBKA0S_FILES entry " .. i .. " is out of XML order")
  end
end)

test("LibKa0s: the vendored folder carries the licence it ships under", function()
  -- LICENSE lives INSIDE the payload as of v1.1.1, so a whole-folder copy carries it. Its absence
  -- means someone vendored file-by-file, which is the thing whole-folder vendoring exists to stop.
  local f = io.open("libs/LibKa0s/LICENSE", "r")
  assertTrue(f ~= nil, "libs/LibKa0s/LICENSE is missing — was this vendored a file at a time?")
  if f then f:close() end
end)

-- The Core seam's TOC position. Every one of these fails SILENTLY in the client: a seam that lands
-- after a `local print = NS.Print` upvalue swaps a printer nobody reads, and the whole change looks
-- like it worked.
local toc = Loader.tocFiles("BankLedger.toc")
local function at(path)
  for i, p in ipairs(toc) do if p == path then return i end end
  return nil
end
local function loadsBefore(a, b)
  local ia, ib = at(a), at(b)
  assertTrue(ia ~= nil, a .. " is not in BankLedger.toc")
  assertTrue(ib ~= nil, b .. " is not in BankLedger.toc")
  assertTrue(ia < ib, a .. " must load before " .. b .. " (TOC positions "
    .. tostring(ia) .. " and " .. tostring(ib) .. ")")
end

test("LibKa0s-Core: the seam loads after core/Namespace.lua, which defines NS.PREFIX", function()
  loadsBefore("core/Namespace.lua", "core/CoreSetup.lua")
end)

test("LibKa0s-Core: the seam loads before the AceConsole reclaim in core/BankLedger.lua", function()
  -- The reclaim reads NS.Util.print. A seam landing after it would leave AceConsole's green,
  -- untagged :Print in place on NS.Print for the rest of the session.
  loadsBefore("core/CoreSetup.lua", "core/BankLedger.lua")
end)

test("LibKa0s-Core: the seam loads before every file that captures NS.Print at load", function()
  -- Derived from the source rather than listed, so a new `local print = NS.Print` in a file that
  -- loads too early is caught the moment it is written.
  local captured = 0
  for _, path in ipairs(toc) do
    -- The seam file names the idiom in its own header; it cannot load before itself.
    if path ~= "core/CoreSetup.lua"
      and Loader.readFile(path):find("local print = NS.Print", 1, true) then
      captured = captured + 1
      loadsBefore("core/CoreSetup.lua", path)
    end
  end
  assertTrue(captured >= 5, "expected at least five load-time printer captures; found " .. captured)
end)

-- ── LibKa0s-DebugLog-1.0 ─────────────────────────────────────────────────────────────────────
--
-- The console. tests/test_debuglog.lua already asserts the behaviour — its 18 cases were written
-- against modules/DebugLog.lua and pass unchanged against the library instance, which is the
-- strongest single piece of evidence that this swap is byte-neutral. What lives HERE is what those
-- cases cannot see: that the seam is on the library at all rather than silently on its stub, that
-- the descriptor is wired the way this addon needs, and the L trap.

local debuglog = T.mocks.LibStub("LibKa0s-DebugLog-1.0", true)
local D = NS.DebugLog

test("LibKa0s-DebugLog: the vendored major registered and the console is running on it", function()
  assertTrue(debuglog ~= nil, "LibKa0s-DebugLog-1.0 did not register")
  -- The degradation stub carries none of these. Naming members only the real instance has is what
  -- distinguishes "the seam is live" from "the seam fell back and everything still ran".
  assertEqual(D.FormatPlain, debuglog.FormatPlain)
  assertEqual(D.FormatColored, debuglog.FormatColored)
  assertEqual(type(D.CopyText), "function", "the stub has no CopyText")
  assertEqual(type(D.ConsoleCheckbox), "function", "the stub has no ConsoleCheckbox")
end)

test("LibKa0s-DebugLog: the module needs the minor that carries the chrome hooks", function()
  -- applySkin and makeCloseButton landed at DebugLog minor 4. Against minor 3 they are ignored
  -- SILENTLY — the console would build, every case here would pass, and the window would simply
  -- wear Core's tooltip border and red x instead of this addon's. Only in game, only visually.
  local _, minor = T.mocks.LibStub:GetLibrary("LibKa0s-DebugLog-1.0", true)
  assertTrue((minor or 0) >= 4,
    "vendored DebugLog is minor " .. tostring(minor) .. "; the chrome hooks need 4 — re-vendor")
  assertEqual(debuglog.MODULES.DebugLog, minor, "lib.MODULES disagrees with the registered minor")
end)

test("LibKa0s-DebugLog: NS.Debug is bound and still gates on the session-only flag", function()
  assertEqual(NS.Debug, D.Debug, "the 29 call sites read NS.Debug; it must BE the instance's sink")
  local saved = NS.State.debug
  NS.State.debug = false
  D:Clear()
  NS.Debug("Move", "should not land")
  assertEqual(#D.buffer, 0, "gated off")
  NS.State.debug = true
  NS.Debug("Move", "should land")
  assertEqual(#D.buffer, 1, "gated on")
  NS.State.debug = saved
  D:Clear()
end)

test("LibKa0s-DebugLog: the enable seam reads and writes NS.State.debug, never SavedVariables",
  function()
    local saved = NS.State.debug
    D:SetEnabled(true)
    assertTrue(NS.State.debug, "setEnabled writes the host's flag")
    assertTrue(D:IsEnabled(), "and isEnabled reads it back")
    assertTrue(NS.db.global.debug == nil, "the flag is session-only")
    D:SetEnabled(false)
    NS.State.debug = saved
    D:Clear()
  end)

test("LibKa0s-DebugLog: the window title composes to exactly what the old console rendered",
  function()
    -- A font string is write-only through the frame API, so the composed title is recorded on the
    -- frame. The descriptor must pass "Bank Ledger" WITHOUT the suffix or the title doubles.
    D:Show()
    assertEqual(D._frameForTest.titleText, "Bank Ledger \226\128\148 Debug")
    D:Hide()
  end)

test("LibKa0s-DebugLog: the console wears THIS addon's chrome, not Core's", function()
  -- The whole reason DebugLog minor 4 exists, asserted on the REAL console rather than on a
  -- throwaway instance built with a descriptor of the test's own. An earlier version of this case
  -- did the latter, and it passed just as happily with `applySkin` deleted from the seam — it was
  -- testing the library, not the wiring.
  --
  -- Nothing headless can read a backdrop back. What IS observable is the thing Core's skin does not
  -- do: NS.Browser:ApplySkin builds an `innerBorder` child frame on whatever it skins
  -- (modules/Browser.lua), and Core's three backdrop calls never create a child of any kind. Its
  -- presence on the console frame is therefore proof that the HOST's skin ran on it.
  D:Show()
  assertTrue(D._frameForTest.innerBorder ~= nil,
    "the console frame has no innerBorder — it was skinned by Core, not by NS.Browser:ApplySkin")
  D:Hide()
end)
test("LibKa0s-DebugLog: a 24-wide host close button does not collide with Clear", function()
  -- The defect the derived offsets exist to prevent. Minor 3's hard-coded -30 is exactly the left
  -- edge of a 24-wide button anchored at -6, so Copy | Clear | Close would have lost their gap.
  --
  -- This addon's mock models SetSize/GetWidth as real state (tests/wow_mock.lua, override 1), so
  -- NS.Browser:MakeCloseButton's `SetSize(24, 24)` is genuinely measurable here and the REAL
  -- arithmetic is exercised rather than the library's 18-wide fallback. That is the one thing
  -- LibKa0s's own suite cannot do — its mock answers 0 from GetWidth.
  D:Show()
  local off = D._frameForTest.titleBarOffsets
  assertTrue(off ~= nil, "the library records the computed offsets")
  assertEqual(off.close, -6)
  assertEqual(off.clear, -36, "-6 - 24 - 6, clearing this addon's wider x")
  assertEqual(off.copy, -84, "-36 - 42 - 6")
  D:Hide()
end)

test("LibKa0s-DebugLog: every user-visible string resolves to prose, not to its own key", function()
  -- The L trap, and DebugLog is one of the three majors that can actually express it. A rendered
  -- label matching ^[A-Z][A-Z0-9_]+$ means the descriptor was handed a locale table whose metatable
  -- answers every key with the key — and it fails for EVERY string at once, only in game.
  --
  -- Reached through real accessors. A case guarding on `if label then` passes vacuously when the
  -- accessor does not exist, which is how the first attempt at this test proved nothing.
  local function assertProse(value, what)
    assertEqual(type(value), "string", what .. " is not a string")
    assertTrue(value ~= "", what .. " is empty")
    assertTrue(value:match("^[A-Z][A-Z0-9_]+$") == nil,
      what .. " rendered as a raw locale key: " .. value)
  end
  local box = D:ConsoleCheckbox()
  assertProse(box.label, "the console checkbox label")
  assertProse(box.tooltip, "the console checkbox tooltip")
  assertProse(D:Text("DEBUG_ON"), "the header toggle's ON label")
  assertProse(D:Text("DEBUG_OFF"), "the header toggle's OFF label")
  assertProse(D:Text("COPY_TITLE"), "the copy window title")
  D:Show()
  assertProse(D._frameForTest.titleText, "the console window title")
  D:Hide()
  -- And the composed tooltip really did pick up this addon's slash verb.
  assertTrue(box.tooltip:find("/bl debug", 1, true) ~= nil,
    "the checkbox tooltip must name /bl debug: " .. box.tooltip)
end)

test("LibKa0s-DebugLog degraded: the console degrades to an honest stub, not an error", function()
  local ns, m = loadDegraded()
  assertTrue(m.LibStub("LibKa0s-DebugLog-1.0", true) == nil, "the library is present after all")
  local d = ns.DebugLog
  assertTrue(d ~= nil, "NS.DebugLog must still exist")
  -- Every member settings/Schema.lua's `/bl debug` verb and its state.debugConsole row reach.
  for _, member in ipairs({ "IsShown", "Show", "Hide", "Toggle", "Add", "Clear", "SetEnabled",
    "UpdateScrollBar", "UpdateStatus", "RefreshHeader", "ShowCopy", "IsEnabled" }) do
    assertEqual(type(d[member]), "function", "the stub is missing " .. member)
  end
  assertEqual(type(ns.Debug), "function", "NS.Debug must still be callable")
  assertTrue(d:IsShown() == false)
  ns.Debug("Move", "swallowed")   -- must not raise
end)

test("LibKa0s-DebugLog degraded: the consequence is appended to the SHARED cause clause", function()
  local ns, m = loadDegraded()
  local out = captureChat(function() ns.DebugLog:Show() end, m)
  assertEqual(out[#out], "|cff00ffff[BL]|r The LibKa0s library is missing from this installation "
    .. "of Ka0s Bank Ledger (expected in libs/LibKa0s), so the debug console window is unavailable.")
end)

test("LibKa0s-DebugLog degraded: the session flag still flips, because it gates more than the window",
  function()
    local ns = loadDegraded()
    ns.State.debug = false
    ns.DebugLog:SetEnabled(true)
    assertTrue(ns.State.debug, "settings/Schema.lua's write-seam trace reads this flag too")
    assertTrue(ns.DebugLog:IsEnabled())
    ns.DebugLog:SetEnabled(false)
    assertTrue(ns.State.debug == false)
  end)

test("LibKa0s-DebugLog: the seam loads after Constants (FONT_MONO) and after the Core seam",
  function()
    loadsBefore("core/Constants.lua", "core/DebugLogSetup.lua")
    loadsBefore("core/CoreSetup.lua", "core/DebugLogSetup.lua")
  end)

test("LibKa0s-DebugLog: modules/DebugLog.lua is gone from the TOC and from disk", function()
  assertTrue(at("modules/DebugLog.lua") == nil, "the replaced file is still in the TOC")
  local f = io.open("modules/DebugLog.lua", "r")
  assertTrue(f == nil, "the replaced file is still on disk")
  if f then f:close() end
end)

test("LibKa0s-DebugLog: the chat acknowledgement still carries the [BL] tag", function()
  -- The descriptor's `print` is what keeps it. Omit it and the library's own default sink writes
  -- straight to DEFAULT_CHAT_FRAME UNTAGGED — the colour-coded state word survives, so a case that
  -- only looked for |cff40ff40ON|r would pass while every user watched the tag disappear from the
  -- two lines `/bl debug on|off` prints.
  local saved = NS.State.debug
  local on = captureChat(function() D:SetEnabled(true) end)
  local off = captureChat(function() D:SetEnabled(false) end)
  assertEqual(on[1], "|cff00ffff[BL]|r debug logging |cff40ff40ON|r")
  assertEqual(off[1], "|cff00ffff[BL]|r debug logging |cffff4040OFF|r")
  NS.State.debug = saved
  D:Clear()
end)

test("LibKa0s-DebugLog: hiding the console repaints the settings panel", function()
  -- The `onVisibilityChanged` wiring, and it is a real fix rather than a translation: the console is
  -- registered in UISpecialFrames, so Esc hides it WITHOUT going through D:Hide, and the panel's
  -- state.debugConsole checkbox went stale on every Esc close until the library moved this onto the
  -- frame's own OnHide. Driving the frame directly is the only way to see that.
  D:Show()
  local refreshed = 0
  local real = NS.Panel.Refresh
  NS.Panel.Refresh = function(self) refreshed = refreshed + 1; return real(self) end
  D._frameForTest:Hide()          -- what Esc and the close button both do
  NS.Panel.Refresh = real
  assertTrue(refreshed > 0, "hiding the console must reach NS.Panel:Refresh")
end)
