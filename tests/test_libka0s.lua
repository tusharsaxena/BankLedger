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

local SEAM_FILES = { "core/CoreSetup.lua" }

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
