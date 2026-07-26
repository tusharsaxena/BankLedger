std = "lua51"
max_line_length = false
codes = true
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }
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
  "MAX_GUILDBANK_SLOTS_PER_TAB",
  -- UI globals used by the window, console and panel
  "UIParent", "UISpecialFrames", "DEFAULT_CHAT_FRAME", "GameTooltip",
  "ITEM_QUALITY_COLORS", "RAID_CLASS_COLORS", "STANDARD_TEXT_FONT",
  "FauxScrollFrame_Update", "FauxScrollFrame_GetOffset", "FauxScrollFrame_OnVerticalScroll",
  "ChatEdit_InsertLink", "IsShiftKeyDown", "BreakUpLargeNumbers",
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
