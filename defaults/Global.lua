local _, NS = ...

-- Account-wide defaults: the RECORDED DATA, the one setting that governs it, and the
-- per-installation launcher state. A bank ledger is inherently cross-character (you deposit on one
-- alt and withdraw on another), so the history stays here, one ledger for the whole account,
-- whatever profile a character is on. Everything else a player CONFIGURES -- the settings, the two
-- filter lists, the saved view -- lives in the profile (defaults/Profile.lua) since schema v3, which
-- lifted it there from this table (core/Database.lua, NS.MIGRATIONS[3]). docs/profiles.md says what
-- a profile holds and what stays here.
--
-- `settings.retentionDays` STAYS HERE (owner decision D6, 2026-09-29). It decides how much of the
-- SHARED history is kept, so it is one value for the whole account: a per-profile window would let
-- a profile switch, copy or reset prune history every other profile still shows. It never left
-- this table for a player upgrading from v2, and NS.MIGRATIONS[4] brings it back from any profile a
-- pre-D6 build of v3 had lifted it into.
NS.defaults = NS.defaults or {}
NS.defaults.global = {
  -- The migration stamp, declared as 0 (savedvariables-§1, standard v2.65.0). 0 is never a real
  -- version, which is the whole point. AceDB's logoutHandler strips every stored value still equal
  -- to its default, so a default equal to NS.SCHEMA_VERSION (what this key once read) left the file
  -- at every logout and came back as the runner's own target, disarming it. A real stamp (1, 2, ...)
  -- never equals 0, so it is never stripped; and the 0 AceDB backfills onto a legacy unstamped store
  -- reads as "unstamped" rather than masking it. NS:RunMigrations (core/Database.lua) walks 0 from
  -- v1 and writes the real stamp; tests/test_database.lua pins the 0.
  schemaVersion = 0,

  ledger = {},   -- array of movement entries, oldest first

  -- The retention window, account-wide (D6, above). The same `settings.` path the schema row and
  -- `/bl set settings.retentionDays` name, and the key v2 always stored it under.
  settings = {
    retentionDays = 30,     -- 0 == keep Always
  },

  -- LibDBIcon's own table: whether the button is shown and the angle it was dragged to. A
  -- per-installation display preference rather than a setting (launcher-§3), so it stays account-wide
  -- and no profile reset reaches it.
  minimap = { hide = false },  -- LibDBIcon state
  -- debug is session-only (NS.State.debug), never persisted here (debug-logging-§5).
}
