local _, NS = ...

-- Profile defaults (savedvariables-§2): everything a player CONFIGURES. Recorded data does not live
-- here -- the ledger is account-wide, in defaults/Global.lua, so every character on every profile
-- reads and writes the one history. A profile holds how the addon behaves and looks, and the lists
-- that decide what it records; switching one never touches what was recorded (docs/profiles.md).
--
-- Every key below was account-wide until schema v3. NS.MIGRATIONS[3] (core/Database.lua) lifted
-- each stored value from db.global into the `Default` profile, which is the profile every character
-- was already on (AceDB:New's defaultProfile = true), so an upgrade changes nothing a player sees.
-- The retention window is the one setting that did not move (owner decision D6).
NS.defaults = NS.defaults or {}
NS.defaults.profile = {
  -- Item-id filter lists. Blacklisted ids are never recorded; whitelisted ids are always recorded,
  -- bypassing the quality gate. Managed via a custom UI (Settings ▸ General ▸ Filters) and the
  -- ledger table's right-click menu — NOT Schema rows. They are an architecture-§5 structural
  -- registry: NS.Filters is their one runtime writer (copy-on-write, never Schema:Set). The load
  -- pass that lifted them here is NS.MIGRATIONS[3]; a profile reset or copy replaces them wholesale.
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
    -- NOT retentionDays: it governs the shared ledger, so it is account-wide (defaults/Global.lua,
    -- owner decision D6).

    -- The Master controls block (options-ui-§15). Each default is the composer's own, restated here
    -- because NS.Schema:Register resolves every schema path against this table — a composed row with
    -- no default here is a path that reads nil forever, and that check is what catches it.
    --
    -- `visibility` is a DROPDOWN, not a boolean, and it starts life as one: this addon never shipped
    -- a "show only in combat" checkbox, so there was no stored value to migrate for it. Honored in
    -- NS.Util.VisibilityAllows.
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
}
