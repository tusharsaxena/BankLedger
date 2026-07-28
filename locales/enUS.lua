local addonName, NS = ...   -- luacheck: ignore addonName

-- Canonical locale. The metatable fallback returns the key itself, so English strings work
-- untranslated and a missing key never errors (localization-§1). Non-enUS files gate with
-- `if GetLocale() ~= "<locale>" then return end` at the top of the file.
NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })

-- v1.0.0 ships English-only: no user-facing string routes through NS.L yet — every label, tooltip
-- and message is hardcoded English (an accepted scope decision for the first release, not an
-- oversight). The NS.L seam is kept so a later localization pass can wrap strings
-- (`NS.L["Enable capture"]`) and drop enUS overrides here without touching call sites. There is
-- deliberately no `local L` alias until the first string is wrapped, so this file stays
-- luacheck-clean.
--
-- Keys are the English source strings (localization-§2); only overrides need listing, e.g.:
-- NS.L["Enable capture"] = "Enable capture"
