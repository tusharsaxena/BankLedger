local _, NS = ...

-- Canonical locale. The metatable fallback returns the key itself, so English strings work
-- untranslated and a missing key never errors (localization-§1). Non-enUS files gate with
-- `if GetLocale() ~= "<locale>" then return end` at the top of the file.
NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })

-- English-only and almost entirely UNWRAPPED: nearly every label, tooltip and message is hardcoded
-- English (an accepted scope decision for the first release, not an oversight). The exceptions are
-- the slash help rows in settings/Schema.lua and the library-absent line in settings/Slash.lua and
-- core/DebugLogSetup.lua, which already read NS.L. The seam is what a later localization pass
-- wraps the rest through, dropping its enUS overrides here without touching a call site. There is
-- deliberately no `local L` alias while this file lists no override, so it stays luacheck-clean. (The launcher's left-click label read NS.L["Toggle ledger window"] from M5 until
-- LibKa0s-Launcher minor 4 retired `leftClickLabel`; the options menu's words are the library's.)
--
-- Keys are the English source strings (localization-§2); only overrides need listing, e.g.:
-- NS.L["Enable capture"] = "Enable capture"
--
-- THE ONE ENTRY THAT USED TO BE HERE WAS THE DISABLED-VERB REFUSAL, and it is gone rather than
-- translated. slash-commands-§7 fixes that line's wording collection-wide and LibKa0s-Slash-1.0
-- builds it from lib.DISABLED_LINE_FORMAT: it is the COLLECTION'S sentence, not this addon's, and
-- the standard says in as many words that the `L` override does not reach it. A locale entry for it
-- was an invitation to give one addon its own spelling of a line eleven addons share.
