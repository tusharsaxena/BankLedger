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

local function joinLines(t) return table.concat(t, "\n") end

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

test("LibKa0s-Core: this addon does NOT republish the library's close factory", function()
    -- A DELIBERATE ABSENCE, pinned so it cannot drift back. `lib.MakeCloseButton` takes a third
    -- argument — the addon FOLDER the library builds its texture path from — and a wrapper that
    -- forwarded only two would draw a multiplication sign, green in every suite and visible only in
    -- a screenshot (anti-pattern #64). This addon avoids that class entirely by not consuming the
    -- factory: all four of its title bars go through modules/Browser.lua's own B:MakeCloseButton,
    -- which resolves the same shared `close` mark through NS.Icon. A wrapper published here would
    -- have had exactly one caller — a spy test — and would read as coverage of those four bars while
    -- covering nothing on screen.
    --
    -- The "tell the library which folder is asking" argument still ships, on the windows that ARE
    -- the library's: core/DebugLogSetup.lua's descriptor passes `addonName`, and the case further
    -- down this file asserts it there.
    assertTrue(NS.MakeCloseButton == nil,
      "core/CoreSetup.lua publishes a close-button seam again; nothing in this addon calls one")
    assertTrue(type(NS.Browser.MakeCloseButton) == "function",
      "this addon's own close factory is gone, and the library's is not republished")
    local f = assert(io.open("core/CoreSetup.lua", "r"))
    local src = f:read("*a"); f:close()
    assertTrue(src:match("[^%-]NS%.MakeCloseButton%s*=") == nil,
      "core/CoreSetup.lua assigns NS.MakeCloseButton")
  end)

test("LibKa0s-Media: the folder name the seam passes is the FIRST VARARG, not a hand-typed literal",
  function()
    -- Three strings in this repo read almost alike and only one of them is the addon FOLDER:
    -- "BankLedger" (the folder, and the first vararg every TOC-loaded file gets), the frame-name
    -- prefix that happens to match it, and the TOC's `## Title`, "Ka0s Bank Ledger". A texture path
    -- built from the wrong one draws nothing and raises nothing, so this pins the seam to the one
    -- the loader supplies rather than to any spelling written down in the source.
    --
    -- core/MediaSetup.lua is where that answer lives for this addon's own marks: NS.Icon and
    -- NS.MediaFont both hand it straight to the library.
    assertEqual(NS.name, Loader.addonName)
    local f = assert(io.open("core/MediaSetup.lua", "r"))
    local src = f:read("*a"); f:close()
    assertTrue(src:match("^local addonName, NS = %.%.%.") ~= nil,
      "core/MediaSetup.lua does not take the addon name as its first vararg")
    assertTrue(src:match('Media%.Icon%(%s*"') == nil and src:match('Media%.Font%(%s*"') == nil,
      "core/MediaSetup.lua hands the library a hand-typed folder literal")
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

test("LibKa0s-Core degraded: the fallback carries the whole live seam surface", function()
  -- The stub-surface parity case for the Core seam (testing-§8). BOTH arms come out of the loader
  -- from a PARTIAL FILE LIST — the TOC's files up to and including core/CoreSetup.lua, once with
  -- libs/LibKa0s/*.lua in front of them and once without — so neither side is hand-stubbed and the
  -- comparison is against the branch that actually runs in a degraded install.
  --
  -- Compared at the NAMESPACE, because that is this seam's surface: core/CoreSetup.lua publishes
  -- onto NS rather than returning an object.
  --   Members from: grep -nE "^ *function NS\.|^ *NS\.[A-Za-z_]+ *=|^ *Util\.[a-z]" core/CoreSetup.lua
  -- Nothing is ignored: every member the live branch publishes, the fallback branch owes the caller,
  -- because six files capture NS.Print at load and a nil member there takes the UI down.
  local live = loadUpTo("core/CoreSetup.lua", true)
  local degraded, dm = loadUpTo("core/CoreSetup.lua", false)
  assertTrue(dm.LibStub("LibKa0s-Core-1.0", true) == nil,
    "the degraded arm still has the library — this case would prove nothing")
  T.assertSurfaceParity(live, degraded, "the Core seam's namespace")
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

test("LibKa0s-Options tripwire: Options reads no descriptor L", function()
  -- The second major this addon adopts that cannot express the trap, and it needs a DIFFERENT
  -- tripwire from Core's rather than a copy of it. Options.lua ships a STRINGS table of its own, so
  -- `rawget(lib, "STRINGS") == nil` would fail against a module behaving exactly as designed. What
  -- transfers is the source half: Options resolves its user-visible strings from `lib.STRINGS` with
  -- no descriptor override path at all, so there is nothing a host can hand it to break — until
  -- there is, and then this reddens on the day it becomes possible rather than on the day someone
  -- thinks to look.
  --
  -- `local L = lib.LAYOUT` at the top of that file is GEOMETRY, not a locale table. Asserting the
  -- layout table exists keeps that distinction pinned, so this case cannot be quietly satisfied by
  -- renaming the wrong thing.
  local opts = T.mocks.LibStub("LibKa0s-Options-1.0", true)
  assertTrue(opts ~= nil, "the vendored Options major must be registered")
  assertTrue(type(rawget(opts, "STRINGS")) == "table",
    "Options is expected to own its strings — if that went away, so did the reason for this shape")
  assertTrue(type(rawget(opts, "LAYOUT")) == "table", "and `L` inside that file is this table")

  for _, rel in ipairs({ "Options.lua", "OptionsWidgets.lua", "OptionsScroll.lua" }) do
    local osrc = Loader.readFile("libs/LibKa0s/" .. rel)
    assertTrue(osrc:find("d.L", 1, true) == nil,
      rel .. " now reads a descriptor L — every host descriptor for this major needs a rendered "
      .. "assertion now, and this tripwire needs replacing")
  end
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

local SEAM_FILES = { "core/CoreSetup.lua", "core/DebugLogSetup.lua", "settings/Slash.lua" }

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

-- ── LibKa0s-Widgets-1.0 ──────────────────────────────────────────────────────────────────────
--
-- Widgets has no core/*Setup.lua seam of its own — it is a plain filter-bar concern, so
-- modules/Browser.lua resolves it directly, the same way it resolves LibDataBroker and LibDBIcon.
-- What still belongs HERE is the one thing every other major gets: proof the vendored payload
-- actually registers this major, so a copy that silently dropped Widgets.lua (or shipped it under
-- the wrong major/minor) is caught before it reaches modules/Browser.lua's forwarder at all.

test("LibKa0s-Widgets: the vendored major registered", function()
  local widgets = T.mocks.LibStub("LibKa0s-Widgets-1.0", true)
  assertTrue(widgets ~= nil,
    "LibKa0s-Widgets-1.0 did not register — modules/Browser.lua's dropdown forwarder is untested")
  assertTrue(type(widgets.Dropdown) == "function", "the registered major has no Dropdown constructor")
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

test("LibKa0s: the vendored folder carries the license it ships under", function()
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
-- The console. tests/test_debuglog.lua already asserts the behavior — its 18 cases were written
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
test("LibKa0s-DebugLog: the console's title bar is the library's, at the pitch the ART gives it",
  function()
    -- The console and the copy window are the library's windows, so they wear Core's thin 18x18
    -- close. This addon's own 24x24 class-colored glyph stays on the windows it belongs to; passing
    -- it through the `makeCloseButton` hook is what made these two windows look unlike every other
    -- Ka0s addon's (LIBKA0S-19, issue #11). That half has not moved.
    --
    -- WHAT MOVED IS COPY. The descriptor now passes `addonName`, so the library can build a texture
    -- path and Clear becomes an 18-wide MARK where it used to be the 42-wide word "Clear" — icons
    -- are narrower than words, and the library derives the pitch from what it actually built rather
    -- than from a constant. So Copy lands at -54 rather than -78, and -78 coming back would mean
    -- the folder name never arrived and the library fell back to two words.
    --
    -- This addon's mock models SetSize/GetWidth as real state, textures included
    -- (tests/wow_mock.lua, override 1), so Core's `SetSize(18, 18)` is genuinely MEASURED here and
    -- the real arithmetic runs. That is the one thing LibKa0s's own suite cannot do — its mock
    -- answers 0 from GetWidth, so every path gives it the same number.
    D:Show()
    local off = D._frameForTest.titleBarOffsets
    assertTrue(off ~= nil, "the library records the computed offsets")
    assertEqual(off.close, -6)
    assertEqual(off.clear, -30, "-6 - 18 - 6 — a 24-wide close button would give -36")
    assertEqual(off.copy, -54, "-30 - 18 - 6 — the 42-wide word would give -78")
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

test("LibKa0s-DebugLog degraded: the stub carries the live surface the addon reaches", function()
  -- The stub-surface parity case for the DebugLog seam (testing-§8). Both arms are loaded from a
  -- partial file list — the TOC up to and including core/DebugLogSetup.lua, with and without the
  -- vendored library — so the degraded arm is the real fallback branch, never a hand-written table.
  --
  -- `ignore` is the live-only surface, as DATA rather than as a shortened comparison. Every name in
  -- it was checked against the addon's own call sites:
  --   grep -rnE "DebugLog[.:][A-Za-z_]+|NS\.Debug\b" core modules settings
  -- returns IsShown/Show/Hide/Toggle/Add/Clear/SetEnabled/IsEnabled and the `NS.Debug` publication —
  -- and nothing else. The ten below are the library's own console internals and its widget makers,
  -- which no BankLedger file calls; a stub re-implementing them would be anti-pattern #47.
  --
  -- `Debug` is the one that needs saying out loud: the live seam publishes NS.Debug FROM the
  -- instance (core/DebugLogSetup.lua), while the degraded branch publishes its own no-op onto NS
  -- directly. NS.Debug therefore exists on both paths — the case above asserts exactly that — and
  -- only the instance member is live-only.
  local IGNORE = {
    "BufferSize", "ConsoleCheckbox", "CopyText", "Debug", "FindLine",
    "FormatColored", "FormatPlain", "LastLine", "MakeCloseButton", "Text",
  }
  local live = loadUpTo("core/DebugLogSetup.lua", true)
  local degraded, dm = loadUpTo("core/DebugLogSetup.lua", false)
  assertTrue(dm.LibStub("LibKa0s-DebugLog-1.0", true) == nil, "the degraded arm still has the library")
  T.assertSurfaceParity(live.DebugLog, degraded.DebugLog, "the DebugLog stub", IGNORE)
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

test("LibKa0s-DebugLog: the library is told the FOLDER name, not just the frame name", function()
  -- `name` and `addonName` are TWO DIFFERENT QUESTIONS that this addon answers with the same
  -- string, which is exactly why the second one is easy to leave out and impossible to notice:
  -- `name` seeds BankLedgerDebugWindow and friends, `addonName` is what the library builds its
  -- texture paths from. Without it the console's own copy and clear controls fall back to two
  -- words, silently, on a window that otherwise works perfectly.
  --
  -- Source-level, and non-comment lines only: the descriptor field cannot be read back off the
  -- instance, and the surrounding note names the field while explaining it.
  local found, n = false, 0
  for line in io.lines("core/DebugLogSetup.lua") do
    n = n + 1
    if not line:match("^%s*%-%-") and line:match("^%s*addonName%s*=%s*addonName%s*,") then
      found = true
    end
  end
  assertTrue(n > 0, "core/DebugLogSetup.lua could not be read")
  assertTrue(found, "the descriptor never passes `addonName = addonName`")
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

test("LibKa0s-DebugLog: the chat acknowledgment still carries the [BL] tag", function()
  -- The descriptor's `print` is what keeps it. Omit it and the library's own default sink writes
  -- straight to DEFAULT_CHAT_FRAME UNTAGGED — the color-coded state word survives, so a case that
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

-- ── LibKa0s-Slash-1.0 ────────────────────────────────────────────────────────────────────────

local slashlib = T.mocks.LibStub("LibKa0s-Slash-1.0", true)
local Sl = NS.Slash

local function chat(fn) return captureChat(fn) end

test("LibKa0s-Slash: the vendored major registered and the CLI is running on it", function()
  assertTrue(slashlib ~= nil, "LibKa0s-Slash-1.0 did not register")
  -- The host's own formatters are GONE, not shadowed. Their absence is what proves the dispatcher
  -- and the schema verbs are the library's rather than the deleted 264-line implementation.
  assertTrue(Sl.FormatSchemaValue == nil, "the host's value formatter should be deleted")
  assertTrue(Sl.FormatKV == nil, "the host's key=value formatter should be deleted")
  assertTrue(Sl.LIST_GROUP_ORDER == nil, "the hand-maintained group order should be deleted")
end)

test("LibKa0s-Slash: the module needs the minor that carries the format hook", function()
  -- `format` landed at Slash minor 5. Against minor 4 it is ignored SILENTLY and
  -- settings.excludedStores renders as "<secret>" — the CLI telling a user a plain settings value
  -- is combat-protected.
  local _, minor = T.mocks.LibStub:GetLibrary("LibKa0s-Slash-1.0", true)
  assertTrue((minor or 0) >= 5,
    "vendored Slash is minor " .. tostring(minor) .. "; the format hook needs 5 — re-vendor")
end)

test("LibKa0s-Slash: every printed line still carries the [BL] tag", function()
  -- The descriptor's `print`. Omit it and the library's default sink writes straight to the chat
  -- frame untagged — every line of /bl help, /bl list and every echo loses its prefix at once.
  local out = chat(function() Sl:CliList() end)
  assertTrue(#out > 3)
  for _, line in ipairs(out) do
    assertTrue(line:sub(1, #NS.PREFIX) == NS.PREFIX, "untagged line: " .. line)
  end
end)

test("LibKa0s-Slash: /bl list keeps its section headings", function()
  -- The descriptor's `groupKey`. The library defaults to `row.page`; this schema declares `group`.
  -- Without it every row collapses under a single "[settings]" heading — a silent, total loss of
  -- structure that no error reports.
  local lines = Sl:BuildListLines()
  assertEqual(lines[1], "|cff33ff99Available settings|r", "the green header is unchanged")
  local headings = {}
  for _, line in ipairs(lines) do
    local g = line:match("^  |cff3399ff%[(.-)%]")
    if g then headings[#headings + 1] = g end
  end
  assertEqual(headings[1], "Master Controls")
  assertEqual(headings[2], "Capture")
  assertEqual(#headings, 2)
end)

test("LibKa0s-Slash: a set-typed row renders as a set, never as the secret sentinel", function()
  -- The whole reason Slash minor 5 exists. lib.FormatValue ends at Core's SafeToString, which
  -- probes table.concat and refuses a table — so without the `format` hook this row reads
  -- "<secret>" in /bl list, /bl get and /bl reset alike.
  local saved = NS.Schema:Get("settings.excludedStores")
  NS.Schema:Set("settings.excludedStores", { GUILD_BANK = true, BANK = true })
  local got = chat(function() Sl:CliGet("settings.excludedStores") end)[1]
  assertEqual(got, NS.PREFIX .. " " ..
    slashlib.FormatKV("settings.excludedStores", "{BANK, GUILD_BANK}"))
  NS.Schema:Set("settings.excludedStores", {})
  local empty = chat(function() Sl:CliGet("settings.excludedStores") end)[1]
  assertEqual(empty, NS.PREFIX .. " " ..
    slashlib.FormatKV("settings.excludedStores", "(none)"))
  NS.Schema:Set("settings.excludedStores", saved or {})
end)

test("LibKa0s-Slash: the format hook defers to the library for every OTHER row type", function()
  -- Returning nil for a row it does not own is what keeps numbers formatted by their `fmt` and
  -- booleans reading true/false. A hook that answered for everything would quietly become a second
  -- renderer — the exact duplication this adoption exists to remove.
  local n = chat(function() Sl:CliGet("settings.windowScale") end)[1]
  assertEqual(n, NS.PREFIX .. " " .. slashlib.FormatKV("settings.windowScale", "1.00x"))
  local b = chat(function() Sl:CliGet("settings.enabled") end)[1]
  assertEqual(b, NS.PREFIX .. " " .. slashlib.FormatKV("settings.enabled", "true"))
end)

test("LibKa0s-Slash: booleans are settable, because the schema says 'bool'", function()
  -- The library dispatches on "bool"; this schema said "boolean" until the adoption renamed it.
  -- Against the old spelling all six boolean rows answer "unknown setting type 'boolean'" and
  -- become un-settable from chat — over half the settings surface, silently.
  local saved = NS.Schema:Get("settings.trackMoney")
  chat(function() Sl:CliSet("settings.trackMoney off") end)
  assertEqual(NS.Schema:Get("settings.trackMoney"), false)
  chat(function() Sl:CliSet("settings.trackMoney yes") end)
  assertEqual(NS.Schema:Get("settings.trackMoney"), true)
  NS.Schema:Set("settings.trackMoney", saved)
end)

test("LibKa0s-Slash: a numeric dropdown now REFUSES a value outside its list", function()
  -- Gained with the row.options -> row.values rename: the library reads `values`, so enumList can
  -- finally see the list. Before the rename `/bl set settings.retentionDays 99` stored 99 and the
  -- panel had no label for it.
  local saved = NS.Schema:Get("settings.retentionDays")
  local out = joinLines(chat(function() Sl:CliSet("settings.retentionDays 99") end))
  assertTrue(out:find("allowed values:", 1, true) ~= nil, out)
  assertEqual(NS.Schema:Get("settings.retentionDays"), saved, "nothing was written")
end)

test("LibKa0s-Slash: a slider value out of range CLAMPS rather than storing what was typed",
  function()
    -- A behavior change, and an improvement: NS.Schema:Set validates nothing, so the old CLI wrote
    -- 9 into a 0.6-1.6 row and the panel drew a slider pinned to its end with a value it could not
    -- represent.
    chat(function() Sl:CliSet("settings.windowScale 9") end)
    assertEqual(NS.Schema:Get("settings.windowScale"), 1.6)
    chat(function() Sl:CliReset("settings.windowScale") end)
  end)

test("LibKa0s-Slash: a set-typed row refuses a chat edit, and says where it CAN be edited",
  function()
    -- The host's `parse` override. Left to the library it answers "unknown setting type 'table'",
    -- which names an implementation detail rather than an action. Before the adoption this wrote a
    -- raw STRING into a table-typed setting the capture gate reads as a set — a live bug the
    -- refusal fixes.
    local saved = NS.Schema:Get("settings.excludedStores")
    local out = joinLines(chat(function() Sl:CliSet("settings.excludedStores BANK") end))
    assertTrue(out:find("settings panel", 1, true) ~= nil, out)
    assertEqual(type(NS.Schema:Get("settings.excludedStores")), "table", "nothing was written")
    NS.Schema:Set("settings.excludedStores", saved or {})
  end)

test("LibKa0s-Slash: CliResetAll keeps this addon's two carve-outs", function()
  -- The library's CliResetAll walks the schema and acknowledges; it cannot know about state that
  -- has no Schema row. Both are user-configured settings despite having no widget, so the host
  -- wraps the library call rather than forking it — and the wrap runs BEFORE it, because that call
  -- is what prints the single acknowledgment.
  NS.Filters:AddBlacklist(2589)
  NS.db.global.savedView = { tab = "insights" }
  local out = chat(function() Sl:CliResetAll() end)
  assertEqual(NS.Filters:Count(NS.Filters:Blacklist()), 0, "the filter lists are cleared")
  assertTrue(NS.db.global.savedView == nil, "the saved ledger view is cleared")
  assertEqual(#out, 1, "still exactly one confirmation line")
  assertEqual(out[1], NS.PREFIX .. " All settings reset to defaults")
end)

test("LibKa0s-Slash: the landing page and the chat help render the SAME rows", function()
  -- Convergence #2, adopted. The panel used to carry a second formatter for this data — doubled
  -- spaces around a white-wrapped em dash, description bare — and the two drifted. Now the only
  -- difference between them is the indent, which is the library's whole reason for having both.
  local landing = Sl:LandingRows()
  local helpRows = chat(function() Sl:PrintHelp() end)
  assertEqual(#landing, #NS.COMMANDS, "one landing row per verb")
  for i, row in ipairs(landing) do
    assertTrue(row:sub(1, 2) ~= "  ", "a landing row must not be indented: " .. row)
    -- helpRows[1] is the header, so the rows line up at i + 1, each behind the [BL] tag.
    assertEqual(helpRows[i + 1], NS.PREFIX .. " " .. "  " .. row,
      "the chat row is the landing row plus a two-space indent")
  end
  assertEqual(landing[1], slashlib.FormatRow("/bl show", "Open the ledger window"))
end)

test("LibKa0s-Slash: reset takes a PATH and resetall takes none — already converged", function()
  -- Convergence #1 needed no change: `/bl reset <path>` was already path-scoped and `/bl resetall`
  -- already existed, so there was no page-shaped form to remove and no confirmation to re-anchor.
  -- Asserted rather than assumed, because "not applicable" and "declined" are different states and
  -- only one of them is a finding.
  -- The library takes the first token, so a two-word page name arrives as "Master" — and the point
  -- stands either way: it resolves as a PATH lookup and misses, rather than resetting a page.
  local out = joinLines(chat(function() Sl:CliReset("Master Controls") end))
  assertTrue(out:find("Setting not found: Master", 1, true) ~= nil,
    "a page name must not resolve as a reset target: " .. out)
  local usage = joinLines(chat(function() Sl:CliReset("") end))
  assertTrue(usage:find("Usage: /bl reset <path>", 1, true) ~= nil, usage)
end)

test("LibKa0s-Slash: every user-visible string resolves to prose, not to its own key", function()
  -- The L trap. Slash is the second of the three majors that can express it, and it has by far the
  -- largest string surface — the help header, the list header, every usage line and seven error
  -- messages. All reached through real output rather than through a guard that could pass vacuously.
  --
  -- Color escapes and the [BL] tag are stripped first: `|cFFFFFF00` and `BL` are both
  -- SCREAMING_SNAKE-shaped and neither is prose the user reads as a word.
  --
  -- Two shapes are flagged, because the library's keys come in two. A WHOLE rendered value equal to
  -- its key catches the short ones (VERSION, NONE, INVALID); a single word carrying an underscore
  -- catches the rest (HELP_HEADER, USAGE_GET, ERR_BOOL) wherever it sits inside a longer line.
  local function assertProse(value, what)
    assertEqual(type(value), "string", what .. " is not a string")
    assertTrue(value ~= "", what .. " is empty")
    local bare = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      :gsub("%[BL%]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    assertTrue(bare:match("^[A-Z][A-Z0-9_]+$") == nil,
      what .. " rendered as a raw locale key: " .. value)
    for word in bare:gmatch("[%w_]+") do
      assertTrue(word:match("^[A-Z][A-Z0-9]*_[A-Z0-9_]*$") == nil,
        what .. " contains a raw locale key (" .. word .. "): " .. value)
    end
  end
  local help = chat(function() Sl:PrintHelp() end)
  assertProse(help[1], "the help header")
  assertProse(Sl:BuildListLines()[1], "the list header")
  assertProse(joinLines(chat(function() Sl:CliGet("") end)), "the get usage line")
  assertProse(joinLines(chat(function() Sl:CliSet("") end)), "the set usage line")
  assertProse(joinLines(chat(function() Sl:CliReset("") end)), "the reset usage line")
  assertProse(joinLines(chat(function() Sl:CliGet("nope.nope") end)), "the not-found line")
  assertProse(joinLines(chat(function() Sl:OnSlash("wibble") end)), "the unknown-command line")
end)

test("LibKa0s-Slash degraded: the verbs that never needed the library still work", function()
  local ns, m = loadDegraded()
  assertTrue(m.LibStub("LibKa0s-Slash-1.0", true) == nil, "the library is present after all")
  -- Dispatch survives: `show`, `hide`, `toggle`, `config`, `session`, `test`, `purge` and `debug`
  -- are host handlers that never touched this library, and losing them would break the addon rather
  -- than degrade it.
  local reached = false
  ns.COMMANDS[#ns.COMMANDS + 1] = { "probe", "probe", function() reached = true end }
  ns.Slash:OnSlash("probe")
  assertTrue(reached, "the fallback dispatcher must still reach a host verb")
  ns.COMMANDS[#ns.COMMANDS] = nil
end)

test("LibKa0s-Slash degraded: the stub carries the whole live surface", function()
  -- The stub-surface parity case for the Slash seam (testing-§8). The degraded arm is the whole
  -- addon loaded from the TOC with libs/LibKa0s/*.lua left OUT of the file list, so `Sl` there is
  -- the table the `if not lib` branch actually built.
  --   Members from: grep -nE "^function Sl[.:][A-Za-z_]+" settings/Slash.lua
  -- Nothing is ignored, and nothing may be: `/bl` is how a user reaches anything without the
  -- settings panel, so every verb the live seam answers the degraded one must answer too — with
  -- work where it can (CliResetAll) and with one honest line where it cannot.
  local degraded, dm = loadDegraded()
  assertTrue(dm.LibStub("LibKa0s-Slash-1.0", true) == nil, "the degraded arm still has the library")
  T.assertSurfaceParity(Sl, degraded.Slash, "the Slash stub")
end)

test("LibKa0s-Slash degraded: the CLI explains itself through the SHARED cause clause", function()
  local ns, m = loadDegraded()
  local out = captureChat(function() ns.Slash:CliList() end, m)
  assertEqual(out[#out], "|cff00ffff[BL]|r The LibKa0s library is missing from this installation "
    .. "of Ka0s Bank Ledger (expected in libs/LibKa0s), so the slash help index and the settings "
    .. "CLI (list/get/set/reset) are unavailable.")
end)

test("LibKa0s-Slash degraded: resetall still WORKS rather than merely explaining itself", function()
  -- It is the body the panel's Defaults button and the confirm-gated /bl resetall share. A reset
  -- that silently did nothing is worse than a missing help index.
  local ns, m = loadDegraded()
  ns:InitDB()
  ns.Schema:Set("settings.qualityThreshold", 4)
  local out = captureChat(function() ns.Slash:CliResetAll() end, m)
  assertEqual(ns.Schema:Get("settings.qualityThreshold"), 0)
  assertEqual(out[#out], "|cff00ffff[BL]|r All settings reset to defaults")
end)

test("LibKa0s-Slash: the seam loads after the schema it reads", function()
  loadsBefore("settings/Schema.lua", "settings/Slash.lua")
end)

-- ── LibKa0s-Options-1.0 ──────────────────────────────────────────────────────────────────────
--
-- The settings panel. tests/test_panel.lua asserts what the panel renders; what lives HERE is the
-- one thing it cannot see — that the degraded stub in settings/OptionsSetup.lua still answers every
-- member the live instance offers this addon, so a page file that grows a call does not meet a nil.

test("LibKa0s-Options degraded: the stub carries the live surface the addon reaches", function()
  -- The stub-surface parity case for the Options seam (testing-§8). The degraded arm is the whole
  -- addon loaded from the TOC with libs/LibKa0s/*.lua left out of the file list, so `NS.Helpers`
  -- there is the table the `if not lib` branch actually built.
  --
  -- `ignore` is the live-only surface, as DATA. Checked against this addon's call sites:
  --   grep -rnE "O[.:]|Helpers[.:]" settings core modules
  -- reaches O.AceGUI and the page/panel/render members the stub already carries; PADDING_X,
  -- LSMValues, TextRow, BuildLandingPage and PatchAlwaysShowScrollbar have NO call site here, and
  -- carrying the library's constants into a stub is anti-pattern #47.
  --
  -- AceGUI is the deliberate one, and the stub names it: `AceGUI = nil`. Every O.AceGUI:Create in
  -- settings/Panel.lua sits inside a body that only runs once a panel has been built, and on this
  -- path CreateOptionsPanel refuses with one honest line instead. A stub handing back a fake AceGUI
  -- would be a widget factory this addon then has to keep working.
  local IGNORE = {
    "AceGUI", "BuildLandingPage", "LSMValues", "PADDING_X", "PatchAlwaysShowScrollbar", "TextRow",
  }
  local degraded, dm = loadDegraded()
  assertTrue(dm.LibStub("LibKa0s-Options-1.0", true) == nil, "the degraded arm still has the library")
  assertTrue(degraded.Helpers.__degraded == true, "the degraded arm is not the fallback branch")
  T.assertSurfaceParity(NS.Helpers, degraded.Helpers, "the Options stub", IGNORE)
end)
