-- tests/test_surface_parity.lua — every degradation stub carries the whole live surface.
--
-- The addon adopts eight LibKa0s seams, and four of them carry a hand-written degradation stub for
-- the install where libs/LibKa0s is missing: core/CoreSetup.lua, core/DebugLogSetup.lua,
-- settings/Slash.lua and settings/OptionsSetup.lua. A stub is a second implementation of somebody
-- else's surface, so it drifts the moment the library grows a member the host starts calling: the
-- live path stays green and the degraded path raises in exactly the install the stub exists for.
--
-- These four cases lived in tests/test_libka0s.lua until M4-09, mixed in among that file's byte,
-- wiring and load-order cases for the same seams. Collecting them here is what the collection does
-- — nine addons, one file name, one grep — and it makes the set visible as a set: a fifth seam
-- growing a stub with no case beside it is now an obvious hole rather than four scattered
-- precedents nobody counted.
--
-- Two rules all four follow, both from testing-§8:
--
--   * The degraded arm comes from a REAL load with a partial file list (tests/degraded_env.lua
--     loads the TOC with libs/LibKa0s/*.lua left out), never from a hand-written table. A hand-stub
--     asserts the test author's typing, not the shipped file.
--   * Where a member is live-only on purpose, it is named in `ignore` WITH THE REASON, because
--     otherwise a deliberate omission and a bug read identically.
--
-- TWO OF THE FOUR USE THE KIT'S BY-NAME FORM — assertSurfaceParity(stub, major, ignore), new at kit
-- 15 and vendored by M4-01 — and two deliberately do not. The split is not stylistic:
--
--   * DebugLog and Options stub a LIBRARY MAJOR'S INSTANCE. `NS.DebugLog` and `NS.Helpers` are what
--     `lib:New(descriptor)` returned, so there is a major name to look up, and the by-name form
--     compares only Kit.publicMembers — which drops LibStub's MAJOR/MINOR/MODULES bookkeeping and
--     every `__`-prefixed key. Those are the library talking to itself across its own file boundary
--     and a stub is obliged to carry none of them. libs/LibKa0s/Options.lua's own comment at
--     O.__print says so and cites this filter by name; under the four-argument form that member had
--     to be exempted here BY HAND, and so would every internal the next re-vendor adds.
--   * Core and Slash stub NOTHING THAT HAS A MAJOR NAME. The Core seam publishes onto NS rather
--     than returning an object, so its two arms are two blocks of core/CoreSetup.lua compared at
--     the namespace. The Slash seam keeps the library instance as a file-scope local `cli` in
--     settings/Slash.lua and publishes host methods on NS.Slash that forward to it, so both arms
--     are this addon's own table and the library's surface is not the thing under test. There is no
--     name to resolve in either case, and the four-argument form is the right one. This is where
--     BankLedger differs from AbsorbTracker, whose Slash stub mirrors the instance directly and
--     publishes it as Sl.__cli for exactly this lookup; publishing one here to suit a test would be
--     changing shipped code to fit the gate.
--
-- WHERE THE LIVE HALF OF THE BY-NAME PAIR COMES FROM, and why it is not the obvious place.
-- tests/run.lua registers it with Kit.setSurfaceSource. It has to: Kit.expose's auto-wiring reaches
-- for the mock's LibStub, which answers the LIBRARY TABLE for a major, and both stubs here mirror an
-- INSTANCE. Left to the auto-wiring, "LibKa0s-Options-1.0" resolves a handful of module-level
-- members and this file goes red for reasons that have nothing to do with the stub.

local T = _G.BL_TEST
local NS = T.NS
local test, assertTrue = T.test, T.assertTrue

local Env = dofile("tests/degraded_env.lua")
local loadDegraded, loadUpTo = Env.loadDegraded, Env.loadUpTo

-- ── LibKa0s-Core-1.0 ─────────────────────────────────────────────────────────────────────────

test("LibKa0s-Core degraded: the fallback carries the whole live seam surface", function()
  -- The stub-surface parity case for the Core seam (testing-§8). BOTH arms come out of the loader
  -- from a PARTIAL FILE LIST — the TOC's files up to and including core/CoreSetup.lua, once with
  -- libs/LibKa0s/*.lua in front of them and once without — so neither side is hand-stubbed and the
  -- comparison is against the branch that actually runs in a degraded install.
  --
  -- Compared at the NAMESPACE, because that is this seam's surface: core/CoreSetup.lua publishes
  -- onto NS rather than returning an object. That is also why this one keeps the four-argument
  -- form: there is no major whose instance to look up, and a namespace's owner decides for itself
  -- what belongs in it.
  --   Members from: grep -nE "^ *function NS\.|^ *NS\.[A-Za-z_]+ *=|^ *Util\.[a-z]" core/CoreSetup.lua
  -- Nothing is ignored: every member the live branch publishes, the fallback branch owes the caller,
  -- because six files capture NS.Print at load and a nil member there takes the UI down.
  local live = loadUpTo("core/CoreSetup.lua", true)
  local degraded, dm = loadUpTo("core/CoreSetup.lua", false)
  assertTrue(dm.LibStub("LibKa0s-Core-1.0", true) == nil,
    "the degraded arm still has the library — this case would prove nothing")
  T.assertSurfaceParity(live, degraded, "the Core seam's namespace")
end)

-- ── LibKa0s-DebugLog-1.0 ─────────────────────────────────────────────────────────────────────

test("LibKa0s-DebugLog degraded: the stub carries the live surface the addon reaches", function()
  -- The stub-surface parity case for the DebugLog seam (testing-§8). The degraded arm is the real
  -- fallback branch of core/DebugLogSetup.lua, loaded from the TOC with the library left out, never
  -- a hand-written table.
  --
  -- The LIVE arm is looked up BY NAME, through the source tests/run.lua registers — the same
  -- `lib:New(...)` instance every call site in this addon holds. It used to be a second partial
  -- load stopping at core/DebugLogSetup.lua; that arm was equal to this one only because nothing
  -- decorates NS.DebugLog after its setup file, which is a fact this case had no way to state and
  -- would have gone on assuming after it stopped being true.
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
  -- directly. NS.Debug therefore exists on both paths — tests/test_libka0s.lua's "degrades to an
  -- honest stub" case asserts exactly that — and only the instance member is live-only.
  --
  -- The four `_...ForTest` seams are the one thing the by-name form ADDED to this list, and they are
  -- a fact about the live arm rather than about the stub. The library stamps them on the instance
  -- when it BUILDS the console and the copy window (libs/LibKa0s/DebugLog.lua:477, :482, :712,
  -- :713); two of them are on the instance by the time this case runs because tests/test_debuglog.lua
  -- showed the console. A library-less build has no window to build, so their absence from the stub
  -- is the condition under test, not a gap in it. Single underscore, so Kit.publicMembers does not
  -- filter them — that exclusion is the `__` prefix. All four are named, not the two set today: they
  -- are one class, and a suite that later shows the copy window should not have to rediscover this.
  local IGNORE = {
    "BufferSize", "ConsoleCheckbox", "CopyText", "Debug", "FindLine",
    "FormatColored", "FormatPlain", "LastLine", "MakeCloseButton", "Text",
    "_frameForTest", "_toggleClickForTest", "_copyWindowForTest", "_copyFrameForTest",
  }
  local degraded, dm = loadDegraded()
  assertTrue(dm.LibStub("LibKa0s-DebugLog-1.0", true) == nil, "the degraded arm still has the library")
  T.assertSurfaceParity(degraded.DebugLog, "LibKa0s-DebugLog-1.0", IGNORE)
end)

-- ── LibKa0s-Slash-1.0 ────────────────────────────────────────────────────────────────────────

test("LibKa0s-Slash degraded: the stub carries the whole live surface", function()
  -- The stub-surface parity case for the Slash seam (testing-§8). The degraded arm is the whole
  -- addon loaded from the TOC with libs/LibKa0s/*.lua left OUT of the file list, so `Slash` there
  -- is the table the `if not lib` branch actually built.
  --   Members from: grep -nE "^function Sl[.:][A-Za-z_]+" settings/Slash.lua
  --
  -- Four-argument, and the header above says why: this addon does not stub the library's dispatcher,
  -- it WRAPS it. settings/Slash.lua keeps the instance as the file-scope local `cli` and publishes
  -- Sl:OnSlash, Sl:CliList and the rest as host methods that forward to it, so both arms of this
  -- comparison are NS.Slash — the addon's own table on both paths — and the major's own surface
  -- (HelpHeader, HelpRows, Text) is never something this addon's stub owed anybody.
  --
  -- Nothing is ignored, and nothing may be: `/bl` is how a user reaches anything without the
  -- settings panel, so every verb the live seam answers the degraded one must answer too — with
  -- work where it can (CliResetAll) and with one honest line where it cannot.
  local degraded, dm = loadDegraded()
  assertTrue(dm.LibStub("LibKa0s-Slash-1.0", true) == nil, "the degraded arm still has the library")
  T.assertSurfaceParity(NS.Slash, degraded.Slash, "the Slash stub")
end)

-- ── LibKa0s-Options-1.0 ──────────────────────────────────────────────────────────────────────
--
-- The settings panel. tests/test_panel.lua asserts what the panel renders; what lives HERE is the
-- one thing it cannot see — that the degraded stub in settings/OptionsSetup.lua still answers every
-- member the live instance offers this addon, so a page file that grows a call does not meet a nil.

test("LibKa0s-Options degraded: the stub carries the live surface the addon reaches", function()
  -- The stub-surface parity case for the Options seam (testing-§8). The degraded arm is the whole
  -- addon loaded from the TOC with libs/LibKa0s/*.lua left out of the file list, so `NS.Helpers`
  -- there is the table the `if not lib` branch actually built. The live arm is the instance
  -- `lib:New(descriptor)` returned, looked up by name through tests/run.lua's registration.
  --
  -- `ignore` is the live-only surface, as DATA. Checked against this addon's call sites:
  --   grep -rnE "O[.:]|Helpers[.:]" settings core modules
  -- reaches O.AceGUI and the page/panel/render members the stub already carries; PADDING_X,
  -- LSMValues, BuildLandingPage and PatchAlwaysShowScrollbar have NO call site here, and
  -- carrying the library's constants into a stub is anti-pattern #47.
  --
  -- TextRow LEFT this list with the tabbed-panel pass: the History tab's storage read-out is drawn
  -- with it now, so it is a reachable name and the stub answers it. The tab strip's own surface
  -- (TabStrip, RenderTabbedSchema, SetChromeHeight, PageBanner, the chrome constants and the six
  -- __-prefixed internals) is reachable for the same reason and is in the stub, not in here.
  --
  -- AceGUI is the deliberate one, and the stub names it: `AceGUI = nil`. Every O.AceGUI:Create in
  -- settings/Panel.lua sits inside a body that only runs once a panel has been built, and on this
  -- path CreateOptionsPanel refuses with one honest line instead. A stub handing back a fake AceGUI
  -- would be a widget factory this addon then has to keep working.
  --
  -- The six added with LibKa0s v1.24.0's composers are library DATA, not behavior: the font-flag
  -- map, the visibility map, their two sortings, the canonical group name and the class-color
  -- tooltip note. Carrying any of them into a stub is anti-pattern #47 — the host copy is the copy
  -- that goes stale — and none has a call site here: the composer emits the values itself, and
  -- settings/Panel.lua keys its afterGroup table on the "Master controls" LITERAL, which is what the
  -- library documents the host doing.
  --
  -- The composer FUNCTIONS are a different question and are in the stub, not in here: MasterControls
  -- is reached (settings/OptionsSetup.lua calls it), and the other four are stubbed beside it.
  --
  -- `__print` IS NO LONGER ON THIS LIST, and that is the whole reason this case moved to the by-name
  -- form. It joined the live surface at LibKa0s v1.27.0 (Options minor 8): the ONE instance print
  -- sink the shell publishes so OptionsWidgets stops building a second one from the same descriptor
  -- (libs/LibKa0s/Options.lua:392, read at OptionsWidgets.lua:763). Its own comment there calls it
  -- internal rather than surface and says a degradation stub does not mirror it, BECAUSE
  -- Kit.assertSurfaceParity skips the `__` prefix — which was true of the by-name form and not of
  -- the four-argument form this case used, so the exemption had to be typed here by hand and the
  -- next internal the library publishes would have needed another line. It is the kit's rule now.
  local IGNORE = {
    "AceGUI", "BuildLandingPage", "LSMValues", "PADDING_X", "PatchAlwaysShowScrollbar",
    "CLASS_COLOR_NOTE", "FONT_FLAGS", "FONT_FLAGS_SORT", "MASTER_GROUP",
    "VISIBILITY_SORT", "VISIBILITY_VALUES",
  }
  local degraded, dm = loadDegraded()
  assertTrue(dm.LibStub("LibKa0s-Options-1.0", true) == nil, "the degraded arm still has the library")
  assertTrue(degraded.Helpers.__degraded == true, "the degraded arm is not the fallback branch")
  T.assertSurfaceParity(degraded.Helpers, "LibKa0s-Options-1.0", IGNORE)
end)
