-- tests/test_surface_parity.lua — every degradation stub carries the whole live surface.
--
-- Seven of the addon's LibKa0s seams carry a hand-written degradation arm for the install where
-- libs/LibKa0s is missing: core/CoreSetup.lua, core/DebugLogSetup.lua, core/LifecycleSetup.lua,
-- settings/Slash.lua, settings/OptionsSetup.lua and, since LibKa0s v1.55.0, the Bus catalog in
-- core/Constants.lua and the schema runtime in settings/Schema.lua. A stub is a second implementation of somebody
-- else's surface, so it drifts the moment the library grows a member the host starts calling: the
-- live path stays green and the degraded path raises in exactly the install the stub exists for.
--
-- Four of these cases lived in tests/test_libka0s.lua until M4-09, mixed in among that file's byte,
-- wiring and load-order cases for the same seams. Collecting them here is what the collection does
-- — nine addons, one file name, one grep — and it makes the set visible as a set: the fifth, the
-- Lifecycle seam, arrived with its case beside it rather than as a scattered precedent nobody
-- counted.
--
-- Two rules all five follow, both from testing-§8:
--
--   * The degraded arm comes from a REAL load with a partial file list (tests/degraded_env.lua
--     loads the TOC with libs/LibKa0s/*.lua left out), never from a hand-written table. A hand-stub
--     asserts the test author's typing, not the shipped file.
--   * Where a member is live-only on purpose, it is named in `ignore` WITH THE REASON, because
--     otherwise a deliberate omission and a bug read identically.
--
-- TWO OF THE FIVE USE THE KIT'S BY-NAME FORM — assertSurfaceParity(stub, major, ignore), new at kit
-- 15 and vendored by M4-01 — and three deliberately do not. The split is not stylistic:
--
--   * DebugLog and Options stub a LIBRARY MAJOR'S INSTANCE. `NS.DebugLog` and `NS.Helpers` are what
--     `lib:New(descriptor)` returned, so there is a major name to look up, and the by-name form
--     compares only Kit.publicMembers — which drops LibStub's MAJOR/MINOR/MODULES bookkeeping and
--     every `__`-prefixed key. Those are the library talking to itself across its own file boundary
--     and a stub is obliged to carry none of them. libs/LibKa0s/Options.lua's own comment at
--     O.__print says so and cites this filter by name; under the four-argument form that member had
--     to be exempted here BY HAND, and so would every internal the next re-vendor adds.
--   * Core, Lifecycle and Slash stub NOTHING THAT HAS A MAJOR NAME. The Core and Lifecycle seams
--     publish onto NS rather than handing callers an object, so their two arms are two blocks of
--     one setup file compared at the namespace. The Slash seam keeps the library instance as a file-scope local `cli` in
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
local test, assertTrue, assertEqual = T.test, T.assertTrue, T.assertEqual

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

test("Core degraded: NS.RegisterEventSafely isolates a raising RegisterEvent", function()
  -- The degraded arm's one rung (BL-06): no library, so no IsEventValid gate, but the pcall still
  -- stands between a refused name and the caller, and the record still says which way it went.
  -- red under: a degraded NS.RegisterEventSafely that calls target:RegisterEvent bare.
  local degraded, dm = loadUpTo("core/CoreSetup.lua", false)
  assertTrue(dm.LibStub("LibKa0s-Core-1.0", true) == nil,
    "the degraded arm still has the library — this case would prove nothing")
  local target = {
    RegisterEvent = function(_, event)
      if event == "RETIRED_EVENT" then error("Attempt to register unknown event") end
    end,
  }
  local ok, took = pcall(degraded.RegisterEventSafely, target, "RETIRED_EVENT", function() end)
  assertTrue(ok, took)
  assertTrue(took == false, "a raising RegisterEvent was reported as bound")
  assertTrue(degraded.RegisterEventSafely(target, "BAG_UPDATE_DELAYED", function() end) == true)
  assertEqual(degraded.EventRecord.unavailable[1], "RETIRED_EVENT")
  assertEqual(degraded.EventRecord.registered[1], "BAG_UPDATE_DELAYED")
end)

-- ── LibKa0s-Lifecycle-1.0 ────────────────────────────────────────────────────────────────────

test("LibKa0s-Lifecycle degraded: the fallback carries the whole host latch surface", function()
  -- The fifth degradation arm, and the newest (slash-commands-§7). Like Core, it is compared at the
  -- NAMESPACE with the four-argument form, because that is where this seam's surface lives: every
  -- caller in the addon -- the schema's onChange, both verbs, the slash gate, the show ladder, the
  -- profile callbacks -- reaches the latch through NS.SetDisabledHold, NS.IsDisabled,
  -- NS.IsStoodDown, NS.EnabledStored and NS.ReevaluateEnabled, never through the instance.
  --   Members from: grep -nE "^function NS\.|^NS\.[A-Za-z_]+ *=" core/LifecycleSetup.lua
  --
  -- `Lifecycle` is the one live-only member, and it is live-only BY DESIGN rather than by omission:
  -- it is the library instance itself. The degraded arm does not mirror it with a hand-written hold
  -- set -- a second implementation of the edge logic is the parallel lifecycle mechanism the major
  -- exists to prevent -- it drives the same NS.StandDown / NS.StandUp bodies off the one reason to
  -- be down that exists without the library. So the case also proves that arm WORKS, not merely
  -- that its names exist.
  --
  -- Dies under: a new NS latch helper defined only inside the `if Lifecycle` branch.
  local live = loadUpTo("core/LifecycleSetup.lua", true)
  local degraded, dm = loadUpTo("core/LifecycleSetup.lua", false)
  assertTrue(dm.LibStub("LibKa0s-Lifecycle-1.0", true) == nil,
    "the degraded arm still has the library — this case would prove nothing")
  assertTrue(live.Lifecycle ~= nil, "the live arm did not build the latch instance")
  assertTrue(degraded.Lifecycle == nil, "the degraded arm published a latch it has no library for")
  T.assertSurfaceParity(live, degraded, "the Lifecycle seam's namespace", { "Lifecycle" })

  local downs, ups = 0, 0
  degraded.StandDown = function() downs = downs + 1 end
  degraded.StandUp = function() ups = ups + 1 end
  degraded.SetDisabledHold(true)
  degraded.SetDisabledHold(true)
  assertTrue(downs == 1 and degraded.IsDisabled() and degraded.IsStoodDown(),
    "the degraded arm did not stand down exactly once on the edge")
  degraded.SetDisabledHold(false)
  assertTrue(ups == 1 and not degraded.IsStoodDown(), "the degraded arm did not stand back up")
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
  -- when it BUILDS the console and the copy window (libs/LibKa0s/DebugLog.lua:527, :532, :809,
  -- :810); two of them are on the instance by the time this case runs because tests/test_debuglog.lua
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
  -- (libs/LibKa0s/Options.lua:499, read at OptionsWidgets.lua:404). Its own comment there calls it
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

-- ── LibKa0s-Bus-1.0 ──────────────────────────────────────────────────────────────────────────

test("LibKa0s-Bus degraded: the stub carries the whole live surface", function()
  -- The sixth degradation arm. core/Constants.lua adopts Bus.Catalog alone and publishes the
  -- resolved library, or its stub, as NS.__busLib. The degraded arm is that stub from a real load
  -- with libs/LibKa0s/*.lua left out; the live arm is the library table, by name, through the
  -- source tests/run.lua registers.
  --
  -- The stub is the untracked-target shape (options-ui-§1), verbatim from the Bus API document's
  -- Worked example, so it owes the whole live surface -- New and Catalog (members-1.json) -- and
  -- nothing is ignored. No BankLedger file calls Bus:New today; an ignore list here would be the
  -- stub drift anti-pattern #56 exists to catch.
  --   Callers from: grep -rn "__busLib\|Bus:New\|Bus.New" core modules settings
  local degraded, dm = loadDegraded()
  assertTrue(dm.LibStub("LibKa0s-Bus-1.0", true) == nil, "the degraded arm still has the library")
  assertTrue(degraded.__busLib ~= nil, "the degraded arm published no Bus stub")
  T.assertSurfaceParity(degraded.__busLib, "LibKa0s-Bus-1.0")
end)

test("LibKa0s-Bus degraded: the stub answers as the untracked-target shape names", function()
  -- options-ui-§1: New answers a record whose NewTarget hands each receiver a private AceEvent
  -- target, untracked, and answers nil only when AceEvent-3.0 itself is absent; StandDown and
  -- StandUp answer 0 and 0, {}; Catalog hands back the host's own table.
  local degraded, dm = loadDegraded()
  local Bus = degraded.__busLib
  assertTrue(dm.LibStub("AceEvent-3.0", true) ~= nil, "the degraded arm lost AceEvent-3.0")
  local rec = Bus:New{ name = "BankLedger" }
  assertEqual(rec.name, "BankLedger", "the record carries the descriptor's name")
  local a, b = rec:NewTarget(), rec:NewTarget()
  assertTrue(type(a) == "table" and type(a.RegisterMessage) == "function",
    "NewTarget answered no AceEvent target while AceEvent is present")
  assertTrue(a ~= b, "NewTarget handed two receivers the same target")
  assertEqual(rec:StandDown(), 0, "StandDown answers 0")
  local replayed, rejected = rec:StandUp()
  assertEqual(replayed, 0, "StandUp answers 0 replayed")
  assertTrue(type(rejected) == "table" and next(rejected) == nil, "StandUp answers an empty rejected list")
  local declared = { X = NS.MSG.ENTRY_ADDED }
  assertTrue(Bus.Catalog("BankLedger", declared) == declared, "Catalog hands back the host's own table")
  assertTrue(degraded.MSG.ENTRY_ADDED == NS.MSG.ENTRY_ADDED, "NS.MSG lost a name on the degraded load")
end)

test("LibKa0s-Bus degraded: with AceEvent-3.0 itself absent, NewTarget answers nil", function()
  -- The other arm of the same options-ui-§1 sentence: nil is the stub's answer ONLY when
  -- AceEvent-3.0 is missing too. The fixture is a real degraded load with AceEvent then taken out
  -- of the mock LibStub's registry (M.__libs, the seam tests/_kit/mock_base.lua exposes); the stub
  -- looks AceEvent up at call time, so it sees the removal. Its no-AceEvent answers for the rest of
  -- the record stay what they were, because none of them reaches AceEvent.
  local degraded, dm = loadDegraded()
  local Bus = degraded.__busLib
  assertTrue(dm.LibStub("AceEvent-3.0", true) ~= nil, "the fixture had no AceEvent to take out")
  dm.__libs["AceEvent-3.0"] = nil
  assertTrue(dm.LibStub("AceEvent-3.0", true) == nil, "the fixture failed to take AceEvent out")
  local rec = Bus:New{ name = "BankLedger" }
  assertTrue(rec ~= nil, "New answered no record with AceEvent absent")
  assertEqual(rec:NewTarget(), nil, "NewTarget answered a target with AceEvent-3.0 absent")
  assertEqual(rec:StandDown(), 0, "StandDown answers 0 with AceEvent absent")
  local replayed, rejected = rec:StandUp()
  assertEqual(replayed, 0, "StandUp answers 0 replayed with AceEvent absent")
  assertTrue(type(rejected) == "table" and next(rejected) == nil, "StandUp answers an empty rejected list")
end)

-- ── LibKa0s-Schema-1.0 ───────────────────────────────────────────────────────────────────────

-- The seventh arm, and the one a player's settings ride on: settings/Schema.lua resolves the major
-- or its runtime-completing stub (docs/api/Schema/version-1-docs.md, "The degradation stub"), builds
-- NS.SchemaRuntime from whichever it got, and publishes the resolved library as NS.__schemaLib. The
-- stub is TRIMMED to what this addon calls, and the trimmed members are named here as live-only,
-- each for the same reason: no BankLedger file calls it.
--   Callers from: grep -rnE "SchemaRuntime[.:][A-Za-z]+|S\.Bulk[A-Za-z]+|Schema[.:](Set|Get|Default|ApplyDefault|FindRow|ReadPath|WritePath|SameValue|Register)\b" core modules settings
--   * BulkRun, BulkAdd, InBulk -- the addon brackets with the BulkBegin/BulkEnd pair and nothing else.
--   * Reindex -- the one head splice goes through AddRows, which re-indexes on its own.
--   * CountOffDefault, ResetCounted, ConsumeResetCount -- the profile reset's count. This addon has
--     no profile (the savedvariables-§2 row), so nothing resets one.
local SCHEMA_LIVE_ONLY = {
  "BulkAdd", "BulkRun", "ConsumeResetCount", "CountOffDefault", "InBulk", "Reindex", "ResetCounted",
}

test("LibKa0s-Schema degraded: the stub instance carries every member the addon reaches", function()
  local degraded, dm = loadDegraded()
  assertTrue(dm.LibStub("LibKa0s-Schema-1.0", true) == nil, "the degraded arm still has the library")
  assertTrue(degraded.SchemaRuntime ~= nil, "the degraded arm built no schema runtime")
  T.assertSurfaceParity(NS.SchemaRuntime, degraded.SchemaRuntime, "schema instance vs host stub",
    SCHEMA_LIVE_ONLY)
end)

test("LibKa0s-Schema degraded: the stub library carries the whole lib-level surface but STRINGS", function()
  -- STRINGS is the one lib member the stub does not carry, as the document prescribes: its refusals
  -- are this addon's own words (the descriptor's `L`), not a copy of the library's constants.
  local degraded = loadDegraded()
  T.assertSurfaceParity(degraded.__schemaLib, "LibKa0s-Schema-1.0", { "STRINGS" })
end)

test("LibKa0s-Schema degraded: the stub SetMany is all-or-nothing", function()
  -- Schema minor 2 (LibKa0s v1.56.0) adds SetMany to the instance surface, and its version-2
  -- document puts it in the stub table: all-or-nothing, log-silent. The stub carries it ahead of
  -- the re-vendor so the parity case above stays green across it. BankLedger calls it nowhere; this
  -- case holds its semantics so a carried member is not an untested one. No row in S.Schema carries
  -- a `validate`, so the refusing row is spliced into the degraded arm's own rows through AddRows.
  local degraded = loadDegraded()
  local R = degraded.SchemaRuntime
  local ticks, repaints = 0, 0
  degraded.Util.RefreshRowTint = function() ticks = ticks + 1 end
  degraded.Panel = { Refresh = function() repaints = repaints + 1 end }
  R.AddRows({ { path = "settings.refused", default = 1, group = "Capture",
    validate = function(v) return v == 1, "only one" end } })

  degraded.db = { global = { settings = { rowStripeAlpha = 0.03, rowHoverAlpha = 0.10 } } }
  local store = degraded.db.global.settings
  local ok, err, why, index = R.SetMany({
    { path = "settings.rowStripeAlpha", value = 0.2 }, { path = "settings.nope", value = 1 } })
  assertEqual(ok, false, "an unknown path let the batch through")
  assertEqual(err, "unknown path: settings.nope", "the NOT_FOUND refusal is the host's words")
  assertEqual(why, nil, "a NOT_FOUND refusal carries no why")
  assertEqual(index, 2, "the refusal names the refused entry")

  ok, err, why, index = R.SetMany({
    { path = "settings.rowStripeAlpha", value = 0.2 }, { path = "settings.refused", value = 2 } })
  assertEqual(ok, false, "a refusing validate let the batch through")
  assertEqual(err, "invalid value", "the INVALID refusal is the host's words")
  assertEqual(why, "only one", "the validate's own why is handed on")
  assertEqual(index, 2, "the refusal names the refused entry")
  assertEqual(store.rowStripeAlpha, 0.03, "a refused batch stored its first entry")
  assertEqual(ticks + repaints, 0, "a refused batch ran a reaction or an announce")

  assertEqual(R.SetMany({ { path = "settings.rowStripeAlpha", value = 0.2 },
    { path = "settings.rowHoverAlpha", value = 0.3 } }, { act = "reset" }), true,
    "a valid batch was refused")
  assertEqual(store.rowStripeAlpha, 0.2, "the first entry was not stored")
  assertEqual(store.rowHoverAlpha, 0.3, "the second entry was not stored")
  assertEqual(ticks, 2, "each row's onChange runs once")
  assertEqual(repaints, 2, "with no announceBatch, announce runs once per write")
  assertEqual(R.SetMany({}), true, "the empty batch is a success")
  assertEqual(ticks + repaints, 4, "the empty batch reacted or announced")

  degraded.db = nil
  ok, err, why, index = R.SetMany({ { path = "settings.rowStripeAlpha", value = 0.5 } })
  assertEqual(ok, false, "a batch stored with no root")
  assertEqual(err, "no settings store yet: settings.rowStripeAlpha", "the NO_ROOT refusal")
  assertEqual(why, nil, "a NO_ROOT refusal carries no why")
  assertEqual(index, 1, "the NO_ROOT refusal names its entry")
end)

-- ── The master switch without the library (WS-02 route a) ────────────────────────────────────
--
-- `settings.enabled` is a COMPOSED row: LibKa0s-Options' MasterControls declares it, so a load with
-- no library has no row for it, and the reserved pair `/bl enable` / `/bl disable` used to meet the
-- CLI-unavailable line and leave the store where it was. settings/Schema.lua lists the path in
-- S.WRITE_THROUGH, the stub stores it raw through a synthetic row, and the degraded Sl:CliEnabled
-- writes it through the seam and re-runs the latch itself (a write-through row has no onChange).

--- A degraded load with a settings store, the addon enabled and the print survey emptied. The
--- degraded NS.Print leads its first line with the once-only missing-library notice (BL-00), so
--- one throwaway print spends it here and the cases below count only what the verb said.
local function degradedEnabled(store)
  local degraded, dm = loadDegraded()
  degraded.db = store
  degraded.Print("fixture")
  dm.__resetPrinted()
  return degraded, dm
end

test("degraded: /bl disable writes settings.enabled through and stands the addon down, without a Lua error", function()
  -- red under: a degraded Sl:CliEnabled that goes through Sl:CliSet (the CLI-unavailable line).
  local degraded, dm = degradedEnabled({ global = { settings = { enabled = true } } })
  local ok, err = pcall(degraded.Slash.OnSlash, degraded.Slash, "disable")
  assertTrue(ok, err)
  assertEqual(degraded.db.global.settings.enabled, false, "the store did not take the write")
  assertTrue(degraded.IsStoodDown() == true, "the addon did not stand down")
  local lines = dm.__printed()
  assertEqual(#lines, 1, "expected exactly one chat line, got: " .. table.concat(lines, " || "))
  assertTrue(lines[1]:find("settings.enabled = false", 1, true) ~= nil, lines[1])
end)

test("degraded: /bl enable reverses it", function()
  local degraded, dm = degradedEnabled({ global = { settings = { enabled = true } } })
  degraded.Slash.OnSlash(degraded.Slash, "disable")
  dm.__resetPrinted()
  local ok, err = pcall(degraded.Slash.OnSlash, degraded.Slash, "enable")
  assertTrue(ok, err)
  assertEqual(degraded.db.global.settings.enabled, true, "the store did not take the write")
  assertTrue(degraded.IsStoodDown() == false, "the addon did not stand back up")
  local lines = dm.__printed()
  assertEqual(#lines, 1, "expected exactly one chat line, got: " .. table.concat(lines, " || "))
  assertTrue(lines[1]:find("settings.enabled = true", 1, true) ~= nil, lines[1])
end)

test("degraded: /bl disable with no settings store prints the refusal and acknowledges nothing", function()
  local degraded, dm = degradedEnabled(nil)
  local ok, err = pcall(degraded.Slash.OnSlash, degraded.Slash, "disable")
  assertTrue(ok, err)
  assertTrue(degraded.IsStoodDown() == false, "a refused write stood the addon down")
  local lines = dm.__printed()
  assertEqual(#lines, 1, "expected exactly one chat line, got: " .. table.concat(lines, " || "))
  assertTrue(lines[1]:find("no settings store yet: settings.enabled", 1, true) ~= nil, lines[1])
end)

test("Schema stub: a writeThrough path with no row is stored raw and announced; a path outside the list still answers unknown path", function()
  local degraded = loadDegraded()
  local R = degraded.SchemaRuntime
  assertTrue(R.FindRow("settings.enabled") == nil, "the degraded arm has a settings.enabled row")
  local repaints = 0
  degraded.Panel = { Refresh = function() repaints = repaints + 1 end }
  degraded.db = { global = { settings = { enabled = true } } }
  assertEqual(R.Set("settings.enabled", false), true, "the writeThrough path was refused")
  assertEqual(degraded.db.global.settings.enabled, false, "the writeThrough path was not stored")
  assertEqual(repaints, 1, "the writeThrough write was not announced once")
  assertEqual(R.SetMany({ { path = "settings.enabled", value = true } }), true,
    "SetMany refused the writeThrough path")
  assertEqual(degraded.db.global.settings.enabled, true, "SetMany did not store the writeThrough path")
  local ok, err = R.Set("settings.locked", true)
  assertEqual(ok, false, "a row-less path outside the list was stored")
  assertEqual(err, "unknown path: settings.locked")
  degraded.db = nil
  ok, err = R.Set("settings.enabled", false)
  assertEqual(ok, false, "a writeThrough write with no root was stored")
  assertEqual(err, "no settings store yet: settings.enabled")
end)

test("Slash stub DisabledLine format is the library's bytes", function()
  local degraded = loadDegraded()
  T.assertLibraryConstant(degraded.Slash.__DISABLED_LINE_FORMAT, "LibKa0s-Slash-1.0", "DISABLED_LINE_FORMAT")
end)

-- ── The degraded Slash arm speaks the live arm's bytes (BL-17) ────────────────────────────────────
--
-- `/bl version` and the unknown-verb answer are two lines a player meets on either arm. The degraded
-- arm passes the value to the printer (events-frames-taint-§8) and must still print exactly what the
-- live library prints, or a degraded install reads differently from a working one.

--- The one line a degraded verb prints, the once-only missing-library notice spent beforehand.
local function degradedLines(fn)
  local degraded, dm = degradedEnabled({ global = { settings = { enabled = true } } })
  fn(degraded.Slash)
  return dm.__printed()
end

local function liveLines(fn)
  T.mocks.__resetPrinted()
  fn(NS.Slash)
  local out = T.mocks.__printed()
  T.mocks.__resetPrinted()
  return out
end

test("Slash stub: /bl version prints the live arm's bytes", function()
  local want = liveLines(function(Sl) Sl:CliVersion() end)
  local got = degradedLines(function(Sl) Sl:CliVersion() end)
  assertEqual(#want, 1, "the live arm printed " .. #want .. " lines")
  assertEqual(#got, 1, "the degraded arm printed " .. #got .. " lines")
  assertEqual(got[1], want[1])
end)

test("Slash stub: an unknown verb is answered in the live arm's words", function()
  -- Only the first line: the help index after it differs by design (the degraded arm has none).
  local want = liveLines(function(Sl) Sl:OnSlash("wibble") end)
  local got = degradedLines(function(Sl) Sl:OnSlash("wibble") end)
  assertEqual(got[1], want[1])
  assertEqual(got[1], "|cff00ffff[BL]|r unknown command 'wibble'")
end)
