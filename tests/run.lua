-- Headless test runner for Ka0s Bank Ledger.
-- Run from the repo root:  lua tests/run.lua        (add --list to emit docs/test-cases.md)
--
-- The registry, the assertions, the `--list` renderer and the source loader all live in the shared
-- kit under tests/_kit (vendored from LibKa0s, never edited here — see docs/testing.md). What stays
-- in this file is what is genuinely per-addon: the load list, the lifecycle kick, and the suite list.

local Kit    = dofile("tests/_kit/framework.lua")
local Loader = dofile("tests/_kit/loader.lua")
local mocks  = dofile("tests/wow_mock.lua")()   -- the addon's own extender over the kit's mock base

Loader.addonName = "BankLedger"
local NS = {}

-- The kit takes suite BASENAMES and appends the extension itself, and it SKIPS a name with no file
-- on disk rather than raising. A typo is therefore a silently green run with fewer cases — so
-- tests/test_harness.lua asserts this list against `tests/test_*.lua` on disk, in both directions.
--
-- A bare name is a suite in tests/. A suite the vendored kit ships is declared by the pair
-- (basename, directory) -- `{ name = ..., dir = "tests/_kit/" }`, the form testing-§9 prescribes --
-- because the kit's inventory keys on that pair and reads a bare name as a claim on tests/. One list
-- carries both shapes, so the list the harness walks is the list that runs.
local SUITES = {
  "test_util", "test_compat", "test_constants", "test_filters",
  "test_ledger", "test_ledger_settling", "test_database", "test_stats", "test_ledgertable",
  "test_browser", "test_launcher", "test_sessionwindow", "test_insights",
  "test_export", "test_debuglog", "test_schema", "test_schema_runtime", "test_slash", "test_bus",
  "test_panel", "test_panel_filters", "test_reset_routes", "test_harness", "test_mock", "test_mediasetup", "test_envsetup",
  "test_marks", "test_libka0s", "test_vendor_sync", "test_poolsetup", "test_itemsetup",
  "test_lifecycle", "test_disabled", "test_surface_parity", "test_register", "test_docs",
  "test_lintconfig",
  -- The kit's own gates. The prose gate is the kit's, not a copy of this repo's: localization-§5
  -- wires one or the other, never both, and the hand-written tests/test_prose.lua was retired when
  -- kit revision 25 began reporting it as shadowing tests/_kit/test_prose.lua.
  { name = "test_eol",        dir = "tests/_kit/" },
  { name = "test_prose",      dir = "tests/_kit/" },
  { name = "test_layout_cap", dir = "tests/_kit/" },
  -- Kit revision 27's diagnostics contract (debug-logging-§14). Until this addon sets
  -- Kit.diagnostics it registers one declared skip naming the rule; the report and its dispatcher
  -- wiring arrive together (DR-BL-03 of the 2026-09-25 diagnostics rollout).
  { name = "test_diagnostics_contract", dir = "tests/_kit/" },
}

-- The vendored library, every file of libs/LibKa0s/LibKa0s.xml in XML order. DERIVED FROM THE XML
-- rather than re-typed: Loader.tocFiles deliberately skips `libs\` lines, because the TOC pulls
-- these in through an XML it cannot see inside, and a hand-kept copy of that XML is a second list
-- that has to agree with the first by hand. It stopped agreeing at LibKa0s v1.48.0, which added
-- WidgetsDragHandle.lua: the list was short by one and tests/_kit's drift check is what caught it.
-- All of them load, not just the adopted majors, because that is what the client does -- a
-- load-time error in a module this addon does not yet use is still a broken install.
-- Loader.xmlFiles returns XML order, directory-prefixed, and raises on a missing XML.
local LIBKA0S_FILES = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")
Loader.loadAll(LIBKA0S_FILES, NS, mocks)

-- The addon's own files come from the SHIPPED TOC rather than from a list maintained here. Two load
-- lists that have to agree by hand are one list that rots: this one had already drifted from the TOC
-- once.
Loader.loadAll(Loader.tocFiles("BankLedger.toc"), NS, mocks)

-- Where Kit.assertSurfaceParity's by-name form looks the LIVE half up (kit 15, vendored by M4-01).
-- Registered explicitly, and the explicitness is the point. Kit.expose auto-wires the mock's
-- LibStub for a repo whose degradation stubs mirror LIBRARY TABLES; this addon's two by-name stubs
-- mirror an INSTANCE instead -- what `lib:New(descriptor)` returned. Left to the auto-wiring,
-- "LibKa0s-Options-1.0" resolves the module table (LAYOUT, New, STRINGS) and
-- "LibKa0s-DebugLog-1.0" resolves its own (MAX_BUFFER, New, STRINGS), so
-- tests/test_surface_parity.lua goes red naming six members no stub was ever meant to carry.
--
-- Set BEFORE Kit.expose, which is what makes it stick: expose registers a source only when none is
-- registered yet, precisely so a runner like this one keeps its own.
--
-- The Core and Slash stubs are deliberately absent from this table -- neither mirrors a major's
-- instance, so neither has a name to resolve; tests/test_surface_parity.lua's header says why.
--
-- The Bus and Schema stubs mirror a LIBRARY TABLE (core/Constants.lua calls Bus.Catalog on the
-- library itself; settings/Schema.lua resolves the Schema library or its stub library and builds its
-- instance from that), so their live half is the mock LibStub's answer for the major. The Schema
-- INSTANCE has no member manifest to resolve by name, and tests/test_surface_parity.lua compares it
-- two-table. A table map is all-or-nothing, which is why those answers are written into it here
-- rather than left to the auto-wiring.
Kit.setSurfaceSource{
  ["LibKa0s-Options-1.0"]  = NS.Helpers,
  ["LibKa0s-DebugLog-1.0"] = NS.DebugLog,
  ["LibKa0s-Bus-1.0"]      = mocks.LibStub("LibKa0s-Bus-1.0", true),
  ["LibKa0s-Schema-1.0"]   = mocks.LibStub("LibKa0s-Schema-1.0", true),
}

_G.BL_TEST = Kit.expose{
  NS = NS, mocks = mocks, Loader = Loader, suites = SUITES, libka0sFiles = LIBKA0S_FILES,
  makeMocks = function() return dofile("tests/wow_mock.lua")() end,
}

NS:InitDB()
-- Mirror the in-game lifecycle: OnInitialize registers the schema, OnEnable arms the capture
-- engine. Enabling the Ledger here is what wires its SettingsChanged subscription, so the tests
-- exercise the real "settings change → re-cache the gate's upvalues" path rather than a fiction.
NS.Schema:Register()
NS.Ledger:Enable()
-- The session window subscribes to the SessionChanged / EntryAdded / LedgerChanged messages here, so
-- its suite exercises the real bus wiring rather than calling its handlers by hand.
NS.SessionWindow:Enable()

Kit.run{ dir = "tests/", suites = SUITES }
