local addonName, NS = ...

-- Shared namespace bootstrap. Runs early so common metadata exists regardless of load order.
NS.name = addonName
-- Fallback only: `/bl version` and the help header both resolve through Sl:Version(), which prefers
-- the TOC's ## Version and degrades to this when the metadata API is unavailable (headlessly, say).
NS.version = "1.1.0"

-- The persisted-DB shape this build writes: the migration runner's target (NS:RunMigrations) and the
-- highest key in NS.MIGRATIONS. It is NOT the shipped default -- defaults/Global.lua declares
-- `schemaVersion = 0`, never a real version (savedvariables-§1), so AceDB's logout strip cannot take
-- a real stamp out of the file.
NS.SCHEMA_VERSION = 2

-- Shared chat tag. Cyan (00ffff) is the Ka0s Standard house color (slash-commands-§4) — every Ka0s
-- addon prints the same cyan bracketed tag so a user running several recognizes them at a glance.
-- MUST NOT be substituted with another color.
NS.PREFIX = "|cff00ffff[BL]|r"

-- Modules publish themselves idempotently (`NS.X = NS.X or {}`); nothing to wire here yet.
