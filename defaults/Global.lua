local addonName, NS = ...   -- luacheck: ignore addonName

-- Account-wide defaults. The ledger and the settings both live under `global`: a bank ledger is
-- inherently cross-character (you deposit on one alt and withdraw on another), so a per-character
-- profile would split the very history the addon exists to join up.
NS.defaults = NS.defaults or {}
NS.defaults.global = {
  -- Version stamp for the persisted DB. 0.1.0 ships the initial shape (1). NS:RunMigrations
  -- (core/Database.lua) reads/writes this field once at init — the idempotent seam future schema
  -- changes hook into (savedvariables-§1).
  schemaVersion = 1,

  ledger = {},   -- array of movement entries, oldest first

  -- Item-id filter lists. Blacklisted ids are never recorded; whitelisted ids are always recorded,
  -- bypassing the quality gate. Managed via a custom UI (Settings ▸ Filters) and the ledger table's
  -- right-click menu — NOT Schema rows, so they are an architecture-§5 carve-out like `window`
  -- (mutated directly through NS.Filters, not via Schema:Set).
  blacklist = {},
  whitelist = {},

  settings = {
    enabled          = true,
    trackItems       = true,
    trackMoney       = true,
    qualityThreshold = 0,      -- Poor and above: a bank ledger cares about junk too
    excludedStores   = {},     -- set of muted Store keys
    retentionDays    = 30,     -- 0 == keep Always
    windowScale      = 1.0,
    window           = {},     -- persisted position/size (standalone-windows carve-out)
  },

  minimap = { hide = false },  -- LibDBIcon state
  -- debug is session-only (NS.State.debug), never persisted here (debug-logging-§5).
}
