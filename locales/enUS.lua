local _, NS = ...

-- Canonical locale. The metatable fallback returns the key itself, so English strings work
-- untranslated and a missing key never errors (localization-§1). Non-enUS files gate with
-- `if GetLocale() ~= "<locale>" then return end` at the top of the file.
NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })

-- English-only, and MOSTLY still unwrapped: every label, tooltip and message except the one below
-- is hardcoded English (an accepted scope decision for the first release, not an oversight). The
-- NS.L seam is what a later localization pass wraps the rest through, dropping its enUS overrides
-- here without touching a call site. There is deliberately no `local L` alias while a single
-- string is wrapped, so this file stays luacheck-clean.
--
-- Keys are the English source strings (localization-§2); only overrides need listing, e.g.:
-- NS.L["Enable capture"] = "Enable capture"

-- THE DISABLED-VERB REFUSAL (slash-commands-§2, standard v2.54.0). The one line a feature verb
-- answers with while `settings.enabled` is false, printed by settings/Slash.lua's dispatcher gate.
-- It NAMES THE VERB THAT UNDOES THE STATE, which is the whole point of the line: a player told only
-- that the addon is off has to go looking for the way back.
--
-- Listed although it reads the same as its key, because a translator finds a string by opening this
-- file and an identity entry is how a wrapped string announces itself. \226\128\148 is an em dash,
-- spelled in bytes so the file needs no encoding assumption of the client.
NS.L["this addon is disabled \226\128\148 /bl enable turns it back on."] =
  "this addon is disabled \226\128\148 /bl enable turns it back on."
