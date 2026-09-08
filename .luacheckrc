std = "lua51"
max_line_length = false
codes = true
-- libs/ holds vendored code, including libs/LibKa0s/ whose upstream is the LibKa0s repo, so it is
-- linted there and not here. tests/_kit/ is the same fact one level down: it is a byte copy of the
-- library's testkit/, linted in LibKa0s as source, and linting the copy too would report every
-- finding twice while letting the copy drift green as the original went red -- the one state the
-- re-vendor diff gate exists to make impossible. Everything else under tests/ is ours and is
-- linted (lint-§1).
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }

-- NO TOP-LEVEL `ignore`, and none is coming back (lint-§1, `M4-11`). This file carried
-- `ignore = { "212/self", "212/event" }` until `M4c-06`. Both entries were already spelled in the
-- `<code>/<variable>` form, which made the blanket look narrow -- but the scope is the problem, not
-- the spelling: a top-level ignore reaches all 60 files, so it silenced those two names in every
-- file that has no business producing them too. That is the state `M4-11` calls "reads as coverage
-- and provides none", and it was literally true here. `212/event` matched NOTHING in this tree --
-- removing the blanket produced not one unused `event` -- so the addon carried a live suppression
-- for a warning it never had, and the day a handler did drop its event argument it would have
-- landed green under a 0/0 badge.
--
-- Removing the two lines reported 119 findings, every one of them `212/self`, across 12 of the 60
-- files. What replaced the blanket is the 12 `files[...]` stanzas at the foot of this file, each
-- naming one file and the one variable that earns it.
--
-- Fixed at source rather than re-silenced, in the same commit: 18 files opened
-- `local addonName, NS = ...   -- luacheck: ignore addonName` over a folder name they never read.
-- An inline pragma standing in for a variable nothing reads is the blanket again at file scope, so
-- 17 of them now open `local _, NS = ...` -- which is what core/CoreSetup.lua, core/ItemSetup.lua
-- and core/PoolSetup.lua already did, and why they never needed a pragma. The 18th,
-- locales/PostLoad.lua, read NEITHER name: it is a documented empty seam whose body is entirely
-- comment, so its header was dead outright and is gone. There is now no `luacheck:` pragma
-- anywhere in this addon's own Lua.
read_globals = {
  -- Core Lua/WoW globals
  "_G", "LibStub", "CreateFrame", "GetTime", "time", "date", "unpack",
  "UnitName", "UnitClass", "UnitGUID", "GetRealmName", "GetNormalizedRealmName",
  "GetZoneText", "GetSubZoneText", "GetGuildInfo", "GetMoney",
  "InCombatLockdown", "PlaySound", "GetLocale", "C_Timer", "hooksecurefunc",
  "Settings", "CreateColor", "Enum",
  -- Item / container / bank APIs the Compat layer wraps
  "C_Item", "C_Container", "C_Map", "C_AddOns", "GetAddOnMetadata",
  "GetGuildBankItemLink", "GetGuildBankItemInfo", "GetNumGuildBankTabs",
  "MAX_GUILDBANK_SLOTS_PER_TAB", "QueryGuildBankTab", "GetCurrentGuildBankTab", "GuildBankFrame",
  -- Store-held coin balances: the corroboration side of a money movement
  "GetGuildBankMoney", "C_Bank",
  -- UI globals used by the window, console and panel
  "UIParent", "UISpecialFrames", "DEFAULT_CHAT_FRAME", "GameTooltip",
  "ITEM_QUALITY_COLORS", "RAID_CLASS_COLORS", "CLASS_ICON_TCOORDS", "STANDARD_TEXT_FONT",
  "FauxScrollFrame_Update", "FauxScrollFrame_GetOffset", "FauxScrollFrame_OnVerticalScroll",
  "ChatEdit_InsertLink", "IsShiftKeyDown", "BreakUpLargeNumbers", "GetCursorPosition",
  "StaticPopup_Show", "YES", "NO",
  "GetCoinTextureString",
  "strtrim",
}
globals = {
  "BankLedgerDB",      -- the SavedVariables write target, declared in the TOC
  -- Registering a confirm dialog means writing a new key into Blizzard's table; that is the only
  -- API FrameXML offers for it, and every addon that ships a StaticPopup does the same.
  "StaticPopupDialogs",
}

-- The harness publishes its exposed table under a per-repo global, written at tests/run.lua:74 and
-- read by every suite file through _G. It is declared HERE rather than in the top-level
-- `read_globals` on purpose: a name granted at the top level is granted to core/, modules/ and
-- settings/ as much as to a suite, and no shipped file may ever reach for the test harness.
-- `globals` rather than `read_globals` because tests/run.lua is the writer, and because the suites
-- reach through it to stage fixtures -- BL_TEST.NS.db, BL_TEST.mocks -- which a read-only field
-- would refuse.
files["tests/"] = {
  globals = { "_G.BL_TEST" },
}

-- ---------------------------------------------------------------------------
-- The narrowed 212s (lint-§1, `M4c-06`)
-- ---------------------------------------------------------------------------
--
-- Every stanza below names ONE file and ONE variable, in luacheck's `<code>/<variable>` form. That
-- is the whole difference from the blanket this replaced: an unused argument under any OTHER name
-- -- `event`, `entry`, `index`, `reason` -- still reports in these 12 files, and an unused `self`
-- still reports in the other 48. Measured, not assumed: a dead `unusedArg` parameter added to
-- `Database:Count` reports under this config and reported nothing under the old one.
--
-- All 119 are the SAME shape, and it is a shape the calling convention forces rather than one this
-- addon chose. Each file publishes a module table the same way -- `NS.X = NS.X or {}` then
-- `local X = NS.X` -- and defines its surface as `function X:Method(...)`. The bodies reach the
-- module through that file-local upvalue and through `NS`, never through the receiver, because the
-- upvalue is in scope and resolves at load time. The receiver is still load-bearing: every call
-- site is a colon call through the namespace (`NS.Browser:Show()`, `NS.Schema:Set(path, v)`,
-- `NS.Database:Add(entry)`), and roughly 900 of them across the addon and the suites. Redefining
-- these with `.` would shift every argument one place to the left at all of them. So the receiver
-- is not dead code that a stanza is hiding -- deleting it is what would break the addon.
--
-- Checked one method at a time before any of this was written, not asserted: every warned method
-- was matched against its call sites, and the only ones with no colon caller in the tree are the
-- framework and library callbacks named below, which are invoked by name from outside it.

-- The AceAddon lifecycle and the two AceEvent handlers. AceAddon calls `OnInitialize`/`OnDisable`
-- on the addon object, and AceEvent invokes a handler as `self[handler](self, event, ...)` -- so
-- `OnCombatChanged` and `OnEnterWorld`, both registered by NAME as strings at :45-:48, receive the
-- addon whether the body reads it or not. These four have no colon caller anywhere in the tree
-- precisely because the caller is the library. `OnEnable`, the fifth, does read `self` and is not
-- suppressed here.
files["core/BankLedger.lua"] = {
  ignore = { "212/self" },
}

-- Two receivers in one file, both forced. `NS:InitDB` and `NS:RunMigrations` are called as
-- `NS:InitDB()` from core/BankLedger.lua:36 and `NS:RunMigrations()` at :8; the rest are the
-- `Database` surface reached as `NS.Database:Ledger()`, `:Add()`, `:QueryList()` and so on from
-- the modules and from six suites. Both bodies read the store through `NS.db`, which is where it
-- lives -- the receiver would only be a second name for something already in scope.
files["core/Database.lua"] = {
  ignore = { "212/self" },
}

-- The degraded stub, and this one is a PARITY surface rather than an ordinary module. When
-- LibKa0s-DebugLog-1.0 is absent this file stands up a table carrying every member the live
-- instance publishes, so nothing that reaches the console raises. Four of them -- UpdateScrollBar,
-- UpdateStatus, RefreshHeader, ShowCopy -- have no caller in THIS repo because their callers are
-- inside the library (libs/LibKa0s/DebugLog.lua calls `D:UpdateStatus()` at :557, :625 and :680,
-- and the others likewise), which is exactly why the stub has to carry them. A no-op stub still has
-- to accept the receiver its live counterpart is called with. tests/test_libka0s.lua:537 pins all
-- twelve members by name.
files["core/DebugLogSetup.lua"] = {
  ignore = { "212/self" },
}

-- The window, table, session, filter and export modules. Every one of these keeps its frame in a
-- file-local `frame` upvalue and its state in `NS`, so the receiver is unread -- but the method
-- form is what the rest of the addon calls, and in several places what it PROBES: the lifecycle in
-- core/BankLedger.lua guards each call as `if NS.Browser and NS.Browser.Enable then` before the
-- colon call, which is how the addon survives one of these files failing to load. A plain local
-- would leave those probes nothing to find.
files["modules/Browser.lua"]       = { ignore = { "212/self" } }
files["modules/Export.lua"]        = { ignore = { "212/self" } }
files["modules/Filters.lua"]       = { ignore = { "212/self" } }
files["modules/Ledger.lua"]        = { ignore = { "212/self" } }
files["modules/LedgerTable.lua"]   = { ignore = { "212/self" } }
files["modules/SessionWindow.lua"] = { ignore = { "212/self" } }

-- The settings trio, same shape. `NS.Schema:Set`/`:Get` alone are called from 87 sites across the
-- panel, the slash CLI and the suites; settings/Slash.lua's 23 are the host handlers plus the
-- degraded branch's stubs, which mirror the LibKa0s-Slash-1.0 surface member for member for the
-- same reason the DebugLog stub does.
files["settings/Panel.lua"]  = { ignore = { "212/self" } }
files["settings/Schema.lua"] = { ignore = { "212/self" } }
files["settings/Slash.lua"]  = { ignore = { "212/self" } }
