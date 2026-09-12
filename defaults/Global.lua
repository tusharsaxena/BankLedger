local _, NS = ...

-- Account-wide defaults. The ledger and the settings both live under `global`: a bank ledger is
-- inherently cross-character (you deposit on one alt and withdraw on another), so a per-character
-- profile would split the very history the addon exists to join up.
NS.defaults = NS.defaults or {}
NS.defaults.global = {
  -- schemaVersion is DELIBERATELY NOT DECLARED HERE, and this comment is the whole reason the key
  -- is missing rather than forgotten. It used to sit here reading NS.SCHEMA_VERSION, on the theory
  -- that a shipped default equal to the runner's target could not drift from it. It cannot — and
  -- that identity is exactly what disarmed the runner. AceDB's logoutHandler calls
  -- RegisterDefaults(nil) at PLAYER_LOGOUT, which runs removeDefaults and strips every stored key
  -- whose value still equals its default; the stamp therefore left the SavedVariables file on the
  -- way out and was re-supplied at the next login as whatever the CURRENT default said. The runner
  -- read its own target back, `< NS.SCHEMA_VERSION` was never true, and the upgrade pass it guards
  -- could not run against a real store. Every future migration would be pre-disarmed the same way.
  --
  -- NS:RunMigrations (core/Database.lua) seeds it instead, as an ordinary stored value that AceDB
  -- has no default to compare against and so cannot strip. The requirement this key was originally
  -- written for — a fresh install starts at the current shape rather than replaying v1->v2 over an
  -- empty ledger — is met there, off the ledger's own emptiness. Do not put it back
  -- (savedvariables-§1); tests/test_database.lua asserts its absence.

  ledger = {},   -- array of movement entries, oldest first

  -- Item-id filter lists. Blacklisted ids are never recorded; whitelisted ids are always recorded,
  -- bypassing the quality gate. Managed via a custom UI (Settings ▸ General ▸ Blacklist /
  -- Whitelist, the two tabs the retired Filters page became) and the ledger table's
  -- right-click menu — NOT Schema rows. They are an architecture-§5 structural registry: NS.Filters
  -- is their one writer (copy-on-write, never Schema:Set), and there is no load pass.
  blacklist = {},
  whitelist = {},

  -- savedView — the ledger window's saved filter/group/sort baseline, written by the filter bar's
  -- Save button (NS.Browser:SaveView). Deliberately ABSENT from these defaults: "no key" is what
  -- "nothing saved" means, and seeding it as {} would make an empty table indistinguishable from a
  -- deliberate save of an all-cleared view. A storage carve-out like `window`, not a registry like
  -- the id-lists above — a captured view has no Schema widget to drive it, so it is written directly
  -- rather than through Schema:Set. Character scope is never part of it (Browser's STOCK_VIEW).

  settings = {
    enabled          = true,
    trackItems       = true,
    trackMoney       = true,
    qualityThreshold = 0,      -- Poor and above: a bank ledger cares about junk too
    excludedStores   = {},     -- set of muted Store keys
    retentionDays    = 30,     -- 0 == keep Always

    -- The Master controls block (options-ui-§15). Each default is the composer's own, restated here
    -- because NS.Schema:Register resolves every schema path against this table — a composed row with
    -- no default here is a path that reads nil forever, and that check is what catches it.
    --
    -- `visibility` is a DROPDOWN, not a boolean, and it starts life as one: this addon never shipped
    -- a "show only in combat" checkbox, so there is no stored value to migrate and SCHEMA_VERSION is
    -- unmoved. Honored in NS.Util.VisibilityAllows.
    visibility       = "always",  -- always | inCombat | outOfCombat | never
    -- "Master scale". Already addon-wide before it was promoted onto that tab: modules/Browser.lua
    -- and modules/SessionWindow.lua both read this one key.
    windowScale      = 1.0,
    alpha            = 1.0,    -- "Master alpha" — NS.Util.ApplyMasterChrome
    locked           = false,  -- "Lock frame"   — NS.Util.ApplyMasterChrome
    window           = {},     -- persisted position/size (standalone-windows carve-out)

    -- The pooled-row tint, shared by the History table and the session window. Each value IS the
    -- literal it was promoted from (modules/LedgerTable.lua and modules/SessionWindow.lua both
    -- built every row with these two numbers), so an install that touches neither slider is drawn
    -- exactly as it was before they existed. Read through NS.Util.RowTintAlpha, which clamps:
    -- these arrive from SavedVariables, where a hand-edited 5 is not an error, it is a table
    -- drawn opaque white.
    rowStripeAlpha    = 0.03,  -- every second row's zebra band
    rowHoverAlpha     = 0.10,  -- the gold wash under the cursor

    -- The live "Current Banking Session" window: shown automatically whenever a bank frame is open.
    showSessionWindow = true,
    sessionWindow     = {},    -- its own persisted position/size (same carve-out as `window`)
  },

  minimap = { hide = false },  -- LibDBIcon state
  -- debug is session-only (NS.State.debug), never persisted here (debug-logging-§5).
}
