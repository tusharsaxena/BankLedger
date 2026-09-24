local _, NS = ...

-- Canonical locale. The metatable fallback returns the key itself, so English strings work
-- untranslated and a missing key never errors (localization-§1). Non-enUS files gate with
-- `if GetLocale() ~= "<locale>" then return end` at the top of the file.
NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })

-- English-only and all but UNWRAPPED: every label, tooltip and message is hardcoded English (an
-- accepted scope decision for the first release, not an oversight), save the launcher's left-click
-- label (core/LauncherSetup.lua), which reads NS.L["Toggle ledger window"] and needs no override
-- here. The NS.L seam is what a later localization pass wraps the rest through, dropping its enUS
-- overrides here without touching a call site. There is deliberately no `local L` alias while no
-- override is listed, so this file stays luacheck-clean.
--
-- Keys are the English source strings (localization-§2); only overrides need listing, e.g.:
-- NS.L["Enable capture"] = "Enable capture"
--
-- THE ONE ENTRY THAT USED TO BE HERE WAS THE DISABLED-VERB REFUSAL, and it is gone rather than
-- translated. slash-commands-§7 fixes that line's wording collection-wide and LibKa0s-Slash-1.0
-- builds it from lib.DISABLED_LINE_FORMAT: it is the COLLECTION'S sentence, not this addon's, and
-- the standard says in as many words that the `L` override does not reach it. A locale entry for it
-- was an invitation to give one addon its own spelling of a line eleven addons share.
