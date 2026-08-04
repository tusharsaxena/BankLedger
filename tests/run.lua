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
local SUITES = {
  "test_util", "test_compat", "test_constants", "test_filters",
  "test_ledger", "test_database", "test_stats", "test_ledgertable",
  "test_browser", "test_sessionwindow", "test_insights",
  "test_export", "test_debuglog", "test_schema", "test_slash",
  "test_panel", "test_harness", "test_mock", "test_libka0s", "test_vendor_sync",
}

-- The vendored library, every file of libs/LibKa0s/LibKa0s.xml in XML order. Spelled out because
-- Loader.tocFiles deliberately skips `libs\` lines — the TOC pulls these in through an XML it
-- cannot see inside. All eight load, not just the adopted majors, because that is what the client
-- does: a load-time error in a module this addon does not yet use is still a broken install.
-- tests/test_libka0s.lua asserts this list against LibKa0s.xml so the two cannot drift.
local LIBKA0S_FILES = {
  "libs/LibKa0s/Core.lua",
  "libs/LibKa0s/DebugLog.lua",
  "libs/LibKa0s/Slash.lua",
  "libs/LibKa0s/Options.lua",
  "libs/LibKa0s/OptionsWidgets.lua",
  "libs/LibKa0s/OptionsScroll.lua",
  "libs/LibKa0s/Perf.lua",
  "libs/LibKa0s/PerfPanel.lua",
}
Loader.loadAll(LIBKA0S_FILES, NS, mocks)

-- The addon's own files come from the SHIPPED TOC rather than from a list maintained here. Two load
-- lists that have to agree by hand are one list that rots: this one had already drifted from the TOC
-- once.
Loader.loadAll(Loader.tocFiles("BankLedger.toc"), NS, mocks)

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
