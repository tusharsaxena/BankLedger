local addonName, NS = ...

-- core/EnvSetup.lua — wires the addon into LibKa0s-Env-1.0 (library-stack-§7).
--
-- The seam where this addon's own version, and the where-am-I stamp on every stored row, come from.
--
-- ── WHAT THIS REPLACED ───────────────────────────────────────────────────────────────────────
--
-- Three shims out of core/Compat.lua: the TOC-metadata reader, the map-id read and the zone read.
-- The metadata one had been written ELEVEN times across nine addons before the library had it — six
-- copies in a core/Compat.lua in four different spellings, and five more inlined at the call site
-- where no audit of the shim files would ever have found them. Not one of the eleven behaved
-- differently from any other, and the map/zone pair here was byte-identical to LootHistory's. That
-- sameness is the whole case: it is what makes these the library's business rather than this
-- addon's, and it is why Compat KEEPS its container, guild-bank and item readers, which are
-- genuinely BankLedger's and behave like nobody else's.
--
-- ── WHY THE LIBRARY HAS TO BE TOLD OUR NAME ──────────────────────────────────────────────────
--
-- Same reason core/MediaSetup.lua passes it: LibKa0s is VENDORED, so a copy cannot know which addon
-- folder it sits in. `addonName` is the FIRST VARARG every TOC-loaded file gets — not `NS.PREFIX`,
-- not the `## Title`, and not a hand-typed literal. Here those read "BankLedger", "[BL]" and
-- "Ka0s Bank Ledger", and only the first is the folder. A wrong name reads some other addon's
-- manifest, or none at all, and answers nil without raising a thing.
--
-- ── WHY THE FALLBACKS ARE WRITTEN OUT RATHER THAN LEFT TO ANSWER nil ─────────────────────────
--
-- Because this is a seam, not a feature. An install missing LibKa0s must get exactly what this
-- addon got before the library existed: every helper below repeats the ladder its deleted shim ran,
-- so such an install still reads its own TOC and still stamps its own zone. Nothing here is
-- resolved at load beyond the LibStub lookup, so this file's TOC position is conventional.
--
-- ── WHAT THE SEAM MUST NOT CHANGE ────────────────────────────────────────────────────────────
--
-- Any answer. All three shims already agreed with the library rung for rung, so a difference in
-- what comes back here is a defect in the adoption rather than an improvement — most sharply for
-- NS.Zone, whose "" is load-bearing (see its own note). tests/test_envsetup.lua pins all of it.

local Env = LibStub and LibStub("LibKa0s-Env-1.0", true)

--- One field of this addon's TOC manifest, or nil.
---
--- NIL IS A REAL ANSWER, twice over: the library may be absent AND the client may expose no reader
--- at all, which is exactly what a headless run looks like. A field the TOC does not carry also
--- answers nil on a perfectly healthy client. Callers that need a value supply their own.
---
--- @param field string  a TOC key: "Version", "Title", "Notes", "Author", …
--- @return string|nil
function NS.Meta(field)
  if Env then return Env.GetAddOnMetadata(addonName, field) end
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(addonName, field)
  end
  if type(GetAddOnMetadata) == "function" then
    return GetAddOnMetadata(addonName, field)
  end
  return nil
end

--- This addon's version string, preferring the TOC over the fallback constant. Never nil.
---
--- The fallback stays visible HERE rather than inside the library because which constant this addon
--- falls back to is genuinely its own business — and because a packaged addon whose TOC can be read
--- should never report the constant somebody forgot to edit.
---
--- `NS.version` is read at CALL time, not captured as an upvalue: core/Namespace.lua publishes it
--- and loads after this file.
---
--- @return string
function NS.Version()
  if Env then return Env.Version(addonName, NS.version) or "?" end
  return NS.Meta("Version") or NS.version or "?"
end

--- The player's current UI map id, or nil.
---
--- Best-effort by design: the id is a stamp on a stored row, and a row with no map id is worth more
--- than a raise during a zone transition. modules/Ledger.lua stores whatever this answers.
---
--- @return number|nil
function NS.PlayerMapID()
  if Env then return Env.GetPlayerMapID() end
  if C_Map and C_Map.GetBestMapForUnit then
    return C_Map.GetBestMapForUnit("player")
  end
  return nil
end

--- Zone and subzone. ALWAYS two strings; "" when the client has no text yet.
---
--- The empty string is load-bearing rather than tidy. modules/Ledger.lua:BuildEntry stores
--- `zone ~= "" and zone or nil`, so "" and nil deliberately land in the same bucket in storage and
--- in the Browser's zone filter. A nil from here would raise nothing and look fine, and would start
--- moving stored rows between buckets the moment a caller compared the two.
---
--- @return string zone, string subzone
function NS.Zone()
  if Env then return Env.GetZone() end
  local zone = (GetZoneText and GetZoneText()) or ""
  local subzone = (GetSubZoneText and GetSubZoneText()) or ""
  return zone, subzone
end
