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
ignore = {
  "212/self",   -- unused argument self
  "212/event",  -- unused argument event
}
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
