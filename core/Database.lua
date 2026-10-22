local addonName, NS = ...

-- AceDB init. Two scopes (docs/profiles.md): the recorded ledger, the retention window that governs
-- it (owner decision D6) and LibDBIcon's table are account-wide in NS.db.global; every other
-- setting, both filter lists and the saved views (one per tab) live in the active profile,
-- NS.db.profile. `true` is AceDB's defaultProfile: every character starts on the one shared profile,
-- "Default", which is where schema v3 lifted the old account-wide settings.
function NS:InitDB()
  NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)
  -- The runner goes FIRST, before anything reads db.profile (savedvariables-§1): the v3 step lifts
  -- the pre-profile settings into the Default profile, and a read of db.profile before it would
  -- have AceDB fill the profile with defaults the lift then has to tell apart from player choices.
  NS:RunMigrations()
  -- THE PROFILE CALLBACKS SURVIVE THE DISABLED STATE (slash-commands-§7), and this is why they
  -- have to: `enabled` is a stored setting like any other and a profile switch can flip it with no
  -- verb and no checkbox being touched, so the addon re-reads the path and re-runs the latch's
  -- decision. All three reach the one adopt path, NS.OnProfileEvent below.
  if NS.db.RegisterCallback then
    local function onProfile(event, _, key) NS.OnProfileEvent(event, key) end
    NS.db.RegisterCallback(NS, "OnProfileChanged", onProfile)
    NS.db.RegisterCallback(NS, "OnProfileCopied",  onProfile)
    NS.db.RegisterCallback(NS, "OnProfileReset",   onProfile)
  end
end

-- The profile keys schema v3 lifted out of db.global, in the order they are moved. `settings` is
-- every schema row's root; the other three are the architecture-§5 structural registry (the two
-- filter lists) and the named non-setting state (the saved view) a profile carries beside it.
-- `savedView` is the v2 store's key and stays here for that store: v5 below then splits what v3
-- lifted into the per-tab `savedViews`.
NS.PROFILE_LIFT_KEYS = { "settings", "blacklist", "whitelist", "savedView" }

-- The `settings` keys that are NOT lifted, and stay account-wide under db.global.settings: the ones
-- that govern the recorded data rather than how the addon behaves (owner decision D6, 2026-09-29).
-- The retention window prunes the SHARED ledger, so a per-profile window would let a profile switch,
-- copy or reset delete history the other profiles still show. Its schema row reads and writes
-- db.global itself (settings/Schema.lua, S.GLOBAL_ROWS).
NS.GLOBAL_SETTINGS = { retentionDays = true }

-- What an NS.GLOBAL_SETTINGS key read as in a profile that did not store it, in the pre-D6 build of
-- v3: its defaults/Profile.lua declared `settings.retentionDays = 30`. Frozen here rather than read
-- from the live defaults, because v4 interprets a store THAT build wrote: a later change to the
-- declared window must not change what an absent key in one of its profiles meant.
local V3_PROFILE_DEFAULTS = { retentionDays = 30 }

-- The ledger window's tabs as the v5 step writes them: the `savedViews` slot names. Frozen here,
-- like V3_PROFILE_DEFAULTS, rather than read from modules/Browser.lua's TABS: the step produces the
-- shape the v5 build reads, and a tab added later must not change what the step wrote.
local V5_VIEW_TABS = { "History", "Insights" }

--- A deep copy of a stored view (its sets are tables), for the v5 step's one copy per slot.
local function copyView(v)
  local out = {}
  for k, val in pairs(v) do out[k] = (type(val) == "table") and copyView(val) or val end
  return out
end

--- A stored profile's raw `settings` table, or nil. Raw, so no AceDB default is read as stored.
local function rawProfileSettings(p)
  local ps = type(p) == "table" and rawget(p, "settings")
  return type(ps) == "table" and ps or nil
end

-- One NS.GLOBAL_SETTINGS key back from every stored profile into db.global.settings (the v4 step,
-- below). Returns the number of profile values removed; 0, touching nothing, when no profile holds
-- the key.
--
-- WHICH VALUE WINS: a player choice already in db.global (a value off the declared default) is
-- kept; otherwise the Default profile's, which is where v3 put the player's own pre-profile value.
-- No other profile's value is ever promoted. Every profile's copy is cleared either way, so no
-- profile is left holding a window nothing reads.
--
-- A DEFAULT PROFILE WITHOUT THE KEY STILL HOLDS A VALUE (savedvariables-§1: a step tells a player's
-- value from a default by comparing against the default, never by testing for the key). AceDB's
-- logout strip removes a value equal to its default, so in a store the pre-D6 build wrote an absent
-- key IS V3_PROFILE_DEFAULTS'. Reading the absence as "Default holds nothing" would promote another
-- profile's shorter window over it, and the next login prune would delete shared history the
-- Default profile's characters kept: the loss D6 exists to prevent. A store with no Default profile
-- at all resolves the same way, to the pre-D6 default.
local function returnGlobalKey(g, profiles, key, declared)
  local holders = {}
  for _, p in pairs(profiles) do
    local ps = rawProfileSettings(p)
    if ps and rawget(ps, key) ~= nil then holders[#holders + 1] = ps end
  end
  if #holders == 0 then return 0 end
  local gs = rawget(g, "settings")
  local current = type(gs) == "table" and rawget(gs, key) or nil
  if current == nil or current == declared then
    local ds = rawProfileSettings(profiles.Default)
    local v = ds and rawget(ds, key)
    if v == nil then v = V3_PROFILE_DEFAULTS[key] end
    if type(gs) ~= "table" then gs = {}; rawset(g, "settings", gs) end
    rawset(gs, key, v)
  end
  for _, ps in ipairs(holders) do rawset(ps, key, nil) end
  return #holders
end

-- The migration steps, keyed by the version each one PRODUCES: NS.MIGRATIONS[n] takes a v(n-1)
-- store to vn and returns the number of rows it touched (for the [Migrate] line). Every step MUST be
-- idempotent -- a re-run over an already-migrated store is a no-op -- because a step that raises
-- leaves the stamp at the last completed version and the next login runs it again. Adding one:
-- bump NS.SCHEMA_VERSION (core/Namespace.lua) and add NS.MIGRATIONS[<new version>]. Each step is
-- handed db.global and the whole AceDB handle, for a step that has to reach the raw profiles.
NS.MIGRATIONS = {
  -- v1 -> v2: the addon no longer derives, captures or persists vendor value, so the field leaves
  -- the SavedVariables file rather than merely going unread. Clearing an absent field is a no-op.
  [2] = function(g)
    local n = 0
    for _, e in ipairs(g.ledger or {}) do
      if e.vendorPrice ~= nil then e.vendorPrice = nil; n = n + 1 end
    end
    return n
  end,

  -- v2 -> v3: settings become per profile (docs/profiles.md). Every stored value under a lifted key
  -- moves from db.global into the `Default` profile's raw table -- the profile every character was
  -- already on, since this addon has always created its db with defaultProfile = true -- and leaves
  -- db.global. The ledger stays where it is, and so does every NS.GLOBAL_SETTINGS key: it is left in
  -- db.global.settings, where v2 stored it and where its row reads it (D6).
  --
  -- WHAT IS STORED IS WHAT MOVES. AceDB's logout strip left only the values that differ from their
  -- defaults in db.global, and the new global defaults no longer declare any of these keys, so
  -- nothing here is a default AceDB filled in: a key present under db.global IS a player's choice.
  -- A `settings` value overwrites the profile's own (which can only be a default, since nothing
  -- wrote the profile before this step); a list or the saved view replaces the profile's whole.
  --
  -- IDEMPOTENT by construction: the global key is cleared the moment it is copied, so a second run
  -- finds nothing to move and touches nothing. Counts one row per value moved. The settings table is
  -- cleared key by key rather than whole, so the account-wide keys it still holds stay put.
  [3] = function(g, db)
    local sv = db and db.sv
    if type(sv) ~= "table" then return 0 end
    sv.profiles = sv.profiles or {}
    local n = 0
    local function defaultProfile()
      local p = sv.profiles.Default
      if type(p) ~= "table" then p = {}; sv.profiles.Default = p end
      return p
    end
    for _, key in ipairs(NS.PROFILE_LIFT_KEYS) do
      local v = rawget(g, key)
      if key == "settings" and type(v) == "table" then
        for k, val in pairs(v) do
          if not NS.GLOBAL_SETTINGS[k] then
            local p = defaultProfile()
            if type(rawget(p, "settings")) ~= "table" then rawset(p, "settings", {}) end
            p.settings[k] = val
            v[k] = nil
            n = n + 1
          end
        end
      elseif v ~= nil then
        rawset(defaultProfile(), key, v); n = n + 1
        g[key] = nil
      end
    end
    return n
  end,

  -- v3 -> v4: the retention window goes back to db.global (owner decision D6, 2026-09-29). The first
  -- build of v3 lifted it into the Default profile with every other setting; a profile could then
  -- carry its own window, and switching to it pruned the history every profile shares. This step
  -- walks every STORED profile raw (sv.profiles, before anything reads db.profile) and takes each
  -- NS.GLOBAL_SETTINGS key out of it (returnGlobalKey, above).
  --
  -- IDEMPOTENT: a second run finds no key in any profile and touches nothing. A store that took the
  -- v3 above never had the key lifted, so this step is a no-op for every v2 upgrade. Counts one row
  -- per profile value removed.
  [4] = function(g, db)
    local sv = db and db.sv
    local profiles = type(sv) == "table" and sv.profiles
    if type(profiles) ~= "table" then return 0 end
    local declared = (NS.defaults and NS.defaults.global and NS.defaults.global.settings) or {}
    local n = 0
    for key in pairs(NS.GLOBAL_SETTINGS) do
      n = n + returnGlobalKey(g, profiles, key, declared[key])
    end
    return n
  end,

  -- v4 -> v5: one saved view per ledger-window tab (owner request 2026-10-07). The profile's single
  -- `savedView` becomes `savedViews = { History = view, Insights = view }`: every STORED profile
  -- is walked raw, as v4 does, and a table under the old key is copied into each tab slot that is
  -- still empty -- a COPY per slot, so a later in-place edit of one tab's view cannot reach the
  -- other's -- and the old key leaves. A value corrupted to a scalar is not a view: it is dropped,
  -- and no slot is made for it. A profile that never saved a view gains nothing: "no key" is what
  -- "nothing saved" means (defaults/Profile.lua).
  --
  -- IDEMPOTENT: the old key is cleared the moment it is read, so a second run finds nothing and
  -- touches nothing; a slot that already holds a view is never overwritten. Counts one row per
  -- profile that held the old key.
  [5] = function(_, db)
    local sv = db and db.sv
    local profiles = type(sv) == "table" and sv.profiles
    if type(profiles) ~= "table" then return 0 end
    local n = 0
    for _, p in pairs(profiles) do
      local old = type(p) == "table" and rawget(p, "savedView") or nil
      if old ~= nil then
        if type(old) == "table" then
          local slots = rawget(p, "savedViews")
          if type(slots) ~= "table" then slots = {}; rawset(p, "savedViews", slots) end
          for _, tab in ipairs(V5_VIEW_TABS) do
            if slots[tab] == nil then slots[tab] = copyView(old) end
          end
        end
        rawset(p, "savedView", nil)
        n = n + 1
      end
    end
    return n
  end,
}

-- Schema-migration runner (toc-file-§2 / savedvariables-§1, standard v2.65.0). Invoked once at init,
-- before any read of db.profile or db.global.ledger, and again from every profile event, where it is
-- a no-op once the stamp is current. Safe no-op when the DB isn't ready yet.
--
-- THE STAMP. defaults/Global.lua declares `schemaVersion = 0`, which is never a real version: AceDB's
-- logout strip can never remove a real stamp, and the 0 it backfills onto an unstamped store reads
-- as "unstamped". 0 and nil are both walked from v1. That covers a legacy pre-stamp store (which IS
-- v1) and a fresh install alike: a step over an empty ledger touches nothing, so a fresh install
-- costs one loop and is stamped current. A future version (> NS.SCHEMA_VERSION) is left alone.
--
-- STAMPED AFTER EACH STEP, never up front and never once at the end. A step that raises propagates,
-- and the stamp stays at the last version that completed, so the next run retries that step rather
-- than skipping it.
--
-- ONE ACCOUNT-WIDE STAMP, and no per-profile one. v3 is a lift OUT of db.global into the one profile
-- every character was on; v4 walks every stored profile once, raw, and takes the account-wide keys
-- back out. A profile created after either passes through untouched -- the profile defaults declare
-- no account-wide key, so it has nothing to move -- which is savedvariables-§1's idempotence against
-- a fresh default profile. A step that reshapes data INSIDE a profile walks sv.profiles, as v4 does.
function NS:RunMigrations()
  local g = NS.db and NS.db.global
  if not g then return end
  local from = tonumber(g.schemaVersion) or 0
  if from >= NS.SCHEMA_VERSION then return end
  local v = math.max(from, 1)
  local rows = 0
  for target = v + 1, NS.SCHEMA_VERSION do
    rows = rows + NS.MIGRATIONS[target](g, NS.db)
    g.schemaVersion = target   -- reached only when the step returned
  end
  if NS.State.debug and NS.Debug then
    NS.Debug("Migrate", "%s", NS.MigrationSummary(v, NS.SCHEMA_VERSION, rows))
  end
end

-- ── The profile events: one adopt path (savedvariables-§1, options-ui-§12, debug-logging-§10) ──
--
-- AceDB replaces the whole profile on a switch, a copy and a reset, and none of it goes through the
-- write seam, so no row's onChange runs. This is where the addon catches up, in one place for all
-- three events: re-run the migrations (a no-op once stamped), re-sync the enable latch, re-apply
-- every setting's effect from the new profile, refresh an open panel, and log exactly one line.
--
-- NEVER A PRUNE (owner decision D6). The retention window is account-wide (NS.GLOBAL_SETTINGS), so
-- no profile event changes it, and nothing here deletes recorded history: the ledger a profile
-- switch, copy or reset leaves behind is exactly the one it found.

-- The reset's row count, handed over by Sl:ResetEverything, which counts the rows off their
-- defaults BEFORE it resets (after, they are all back on them). Taken once, so a reset that arrives
-- from AceDBOptions' own Reset Profile button, which counts nothing, logs its line without one.
local pendingResetRows

function NS.SetPendingResetRows(n) pendingResetRows = n end

local function profileName()
  return (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?"
end

--- The one line debug-logging-§10 asks for, worded by the event. The reset and the copy rewrite rows
--- and carry `[Set]`; a switch rewrites none and is traced under `[Profile]`.
local function traceProfileEvent(event, key)
  local rows = pendingResetRows
  pendingResetRows = nil
  if not (NS.State and NS.State.debug and NS.Debug) then return end
  if event == "OnProfileReset" then
    if rows then
      NS.Debug("Set", "reset profile '%s' to defaults (%d rows)", profileName(), rows)
    else
      NS.Debug("Set", "reset profile '%s' to defaults", profileName())
    end
  elseif event == "OnProfileCopied" then
    NS.Debug("Set", "copied profile '%s' -> '%s'", tostring(key), profileName())
  else
    NS.Debug("Profile", "switched to profile '%s'", profileName())
  end
end

--- Re-apply what a profile's settings DO. Each call is the one its row's onChange (or its owner's
--- frame builder) already makes, so nothing here is a second implementation; every target is
--- optional because a profile can change before a module has built its frame.
local function applyProfileEffects()
  local U, B, SW = NS.Util, NS.Browser, NS.SessionWindow
  -- Stored geometry and the saved views belong to the profile: re-anchor both windows from it, and
  -- put every ledger-window tab back on the new profile's view for that tab (or stock), silently.
  if B and B.ApplyGeometry then B:ApplyGeometry() end
  if SW and SW.ApplyGeometry then SW:ApplyGeometry() end
  if B and B.ClearAllTabs then B:ClearAllTabs() end
  if U then
    U.ApplyMasterChrome()
    U.ApplyVisibility()
  end
  -- The row tint, repainted directly (Util.RefreshRowTint would send a second bus message).
  if NS.LedgerTable and NS.LedgerTable.Bind then NS.LedgerTable:Bind() end
  if SW and SW.Bind then SW:Bind() end
  -- No retention prune: the window is account-wide and no profile holds one (D6). The prune runs
  -- at login and when the retention row itself is changed, never on a profile event.
end

--- The session-only rows a profile reset cannot reach, ended BY NAME (options-ui-§12, §15). Neither
--- lives in the profile: test mode is NS.State, and the debug console row reads the window itself.
--- NOT through the write seam, which would log a per-row [Set] line beside the act's one line
--- (debug-logging-§10). Each lands on its row's declared default, which S.MASTER_SPEC gives as false
--- for both. LT:SetTestMode repaints the panel itself. A reset only: a switch or a copy is not a
--- reset, and ending the player's test mode on one would be a surprise.
local function endSessionState()
  local LT = NS.LedgerTable
  if LT and LT.IsTestMode and LT:IsTestMode() then LT:SetTestMode(false) end
  local D = NS.DebugLog
  if D and D.IsShown and D:IsShown() then D:Hide() end
end

--- The adopt path. `event` is AceDB's callback name; `key` is its third argument (the profile
--- switched to, or the source of a copy; nothing on a reset).
function NS.OnProfileEvent(event, key)
  if event == "OnProfileReset" then endSessionState() end
  NS:RunMigrations()
  NS.ReevaluateEnabled()
  -- The capture gate caches the settings and both lists: SettingsChanged re-caches it (and every
  -- other subscriber re-reads), LedgerChanged repaints what the filter lists decide -- the tables,
  -- Insights and the Filters tab. One message each, for the whole act.
  if NS.bus then NS.bus:SendMessage(NS.MSG.SETTINGS_CHANGED, "profile") end
  if NS.Database and NS.Database.FireLedgerChanged then NS.Database:FireLedgerChanged() end
  applyProfileEffects()
  if NS.Panel and NS.Panel.Refresh then NS.Panel:Refresh() end
  traceProfileEvent(event, key)
end

-- Pure migration summary for the [Migrate] debug line.
function NS.MigrationSummary(from, to, rows)
  return ("v%s -> v%s, %s rows touched"):format(tostring(from), tostring(to), tostring(rows))
end

-- The dependency tail of the [Init] line (debug-logging-§8, dependencies: found or missing, once,
-- at enable). The flag is off at every login, so "at enable" is the moment logging is switched on,
-- which is when the library writes this line. One fact: the bank-replacing addons loaded (the
-- first suspect when a visit records nothing). Addon names and fixed words only, so the join is
-- secret-free.
--
-- NOT the launcher's state any more. This tail carried `launcher registered / unregistered /
-- degraded` while the Launcher's own Register lines were gated off at OnEnable and never landed.
-- From Launcher minor 5 they go to the console's at-enable queue (core/LauncherSetup.lua's
-- `debugAtEnable`) and land right after this line, so a launcher fact here would be the second line
-- for one state (debug-logging-§4). `degraded` needs no line: without LibKa0s there is no console.
local function dependencySummary()
  local X = NS.Diagnostics
  local loaded = X and X.LoadedBankAddons and X.LoadedBankAddons()
  local bank = loaded == nil and "unreadable" or (#loaded == 0 and "none" or table.concat(loaded, " "))
  return ("bank addons: %s"):format(bank)
end

-- Pure [Init] session summary for the SetEnabled seam (debug-logging-§5/§8): addon name + version,
-- schema version, active profile, entry count, then the dependency tail — e.g.
-- "BankLedger v1.3.0, schema v4, profile 'Default', 412 entries, bank addons: none".
-- Guarded so it can't error before the DB is ready. All values are plain constants/counts, so a raw
-- tostring is secret-safe here.
function NS.InitSummary()
  local g = NS.db and NS.db.global
  local schema = (g and g.schemaVersion) or 0
  local profile = (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?"
  local entries = (g and g.ledger and #g.ledger) or 0
  return ("%s v%s, schema v%s, profile '%s', %s entries, %s"):format(
    tostring(NS.name), tostring(NS.version), tostring(schema), tostring(profile), tostring(entries),
    dependencySummary())
end

NS.Database = NS.Database or {}
local Database = NS.Database

function Database:Ledger()
  return NS.db.global.ledger
end

-- The WRITE sink every capture-path write reaches (host contract H4, BankLedger#24): the session-only
-- simulator log while a simulator runs (NS.State.simLog, never saved), otherwise the saved ledger.
function Database:Sink()
  return (NS.State and NS.State.simLog) or NS.db.global.ledger
end

-- The dataset every read-path query (Query/Stats/Export, and therefore the table + Insights)
-- resolves against, in precedence sim, then test (`/bl test`), then the live account-wide ledger.
function Database:ActiveLedger()
  local st = NS.State
  return (st and (st.simLog or st.testRecords)) or NS.db.global.ledger
end

-- The one dataset predicate: "sim", "test" or "live", in ActiveLedger's precedence. Anything that
-- must refuse a synthetic dataset reads DatasetKind() ~= "live".
function Database:DatasetKind()
  local st = NS.State or {}
  return (st.simLog and "sim") or (st.testRecords and "test") or "live"
end

-- The REAL ledger, whatever the sink or the read path is.
function Database:Count()
  return #NS.db.global.ledger
end

-- Append an entry to the write sink, stamped `sim = true` under a simulator; fire EntryAdded;
-- return its index.
function Database:Add(entry)
  local ledger = self:Sink()
  if NS.State and NS.State.simLog then entry.sim = true end
  ledger[#ledger + 1] = entry
  local index = #ledger
  if NS.bus then
    NS.bus:SendMessage(NS.MSG.ENTRY_ADDED, entry, index)
  end
  return index
end

-- Scalar-or-set membership test shared by every set-capable filter field.
local function matchesSpec(spec, value)
  if spec == nil then return true end
  if type(spec) == "table" then return spec[value] == true end
  return spec == value
end

-- The set-capable filter fields and how to read each one off an entry, in the order they were tested
-- when this was one `and` chain. Module-level, so neither the table nor its readers is rebuilt per
-- query — and the `get` calls are pure, so stopping at the first miss only skips work.
-- itemType/itemSubType read the EFFECTIVE type (NS.Util.EntryType), so "Gold" filters gold
-- movements — the same value the Type column shows for them. Item rows are unaffected.
local SET_FIELDS = {
  { key = "kind",        get = function(e) return e.kind end },
  { key = "direction",   get = function(e) return e.direction end },
  { key = "store",       get = function(e) return e.store end },
  { key = "char",        get = function(e) return e.char end },
  { key = "itemType",    get = function(e) return NS.Util.EntryType(e) end },
  { key = "itemSubType", get = function(e) return NS.Util.EntrySubType(e) end },
}

local function matchesSetFields(filter, e)
  for _, f in ipairs(SET_FIELDS) do
    local spec = filter[f.key]
    if spec ~= nil and not matchesSpec(spec, f.get(e)) then return false end
  end
  return true
end

-- Quality is a set (membership) or a number (exact, against a missing quality read as 0); anything
-- else is no filter at all.
local function qualityOK(e, qSet, qExact)
  if qSet then return qSet[e.quality] and true or false end
  if qExact then return (e.quality or 0) == qExact end
  return true
end

-- Timestamp range, inclusive on both ends, against a missing timestamp read as 0.
local function rangeOK(e, from, to)
  local ts = e.ts or 0
  if from and ts < from then return false end
  if to and ts > to then return false end
  return true
end

-- Case-insensitive substring on the item name; `text` arrives already lowered.
local function textOK(e, text)
  if not text then return true end
  local name = e.itemName and e.itemName:lower() or ""
  return name:find(text, 1, true) ~= nil
end

-- Filter an arbitrary entry array by the filter spec. Every field is optional and AND-combined.
-- kind/direction/store/char/itemType/itemSubType each accept a scalar (equality) OR a set table
-- (membership, for the browser's multi-select filters); quality accepts a number (exact) or a set.
-- itemType/itemSubType match the entry's EFFECTIVE type — a gold movement's is "Gold".
--   kind · direction · store · char · itemType · itemSubType · quality · from/to (ts, inclusive) ·
--   text (case-insensitive substring on itemName)
-- An empty/nil filter returns everything. Kept generic (not tied to the live ledger) so the browser
-- can filter its test dataset through exactly the same code.
function Database:QueryList(entries, filter)
  filter = filter or {}
  local qSet = type(filter.quality) == "table" and filter.quality or nil
  local qExact = type(filter.quality) == "number" and filter.quality or nil
  local from, to = filter.from, filter.to
  local text = filter.text and filter.text:lower() or nil

  local out = {}
  for _, e in ipairs(entries) do
    if matchesSetFields(filter, e) and qualityOK(e, qSet, qExact)
      and rangeOK(e, from, to) and textOK(e, text) then
      out[#out + 1] = e
    end
  end
  return out
end

-- Query the active dataset (live ledger, or the test dataset while test mode is on).
function Database:Query(filter)
  return self:QueryList(self:ActiveLedger(), filter)
end

-- Plain, metatable-free copy of the (optionally filtered) ledger — the forward-compatible export
-- contract (see docs/schema.md). The field shape is stable except across schema bumps.
function Database:Export(filter)
  local out = {}
  for _, e in ipairs(self:Query(filter or {})) do
    out[#out + 1] = {
      ts = e.ts, char = e.char, classFile = e.classFile,
      kind = e.kind, direction = e.direction, store = e.store, guild = e.guild,
      itemID = e.itemID, itemLink = e.itemLink, itemName = e.itemName, quality = e.quality,
      itemType = e.itemType, itemSubType = e.itemSubType,
      quantity = e.quantity, zone = e.zone, mapID = e.mapID, subzone = e.subzone,
    }
  end
  return out
end

local function fireLedgerChanged()
  if NS.bus then NS.bus:SendMessage(NS.MSG.LEDGER_CHANGED) end
end

-- Public LedgerChanged emitter for non-Database owners of a visible-ledger change (NS.Filters calls
-- it after mutating db.global). Keeps Database the single sending module for this message
-- (architecture-§4's one-sender-per-message invariant).
function Database:FireLedgerChanged()
  fireLedgerChanged()
end

-- Delete a single entry by index. Compacts the array. No production caller: the table's row menu
-- deletes by identity through Database:Delete (LT:RowMenuItems' Delete entry, in
-- modules/LedgerTable.lua). Exported as the index-delete seam the tests use to undo a recorded row
-- (tests/test_ledger.lua, the case "Ledger:Record appends a gated-in movement to the ledger").
function Database:DeleteAt(index)   -- the REAL ledger, never the sim sink
  local ledger = NS.db.global.ledger
  if type(index) ~= "number" or index < 1 or index > #ledger then return false end
  local ts = ledger[index] and ledger[index].ts
  table.remove(ledger, index)
  fireLedgerChanged()
  if NS.State.debug and NS.Debug then
    NS.Debug("Data", "deleted entry @%s", tostring(ts))
  end
  return true
end

-- Delete every entry for which pred(entry) is true. Rebuild-and-swap (no array holes).
-- Returns the number removed; fires LedgerChanged.
function Database:Delete(pred)
  local ledger = NS.db.global.ledger
  local kept, removed = {}, 0
  for _, e in ipairs(ledger) do
    if pred(e) then removed = removed + 1 else kept[#kept + 1] = e end
  end
  NS.db.global.ledger = kept
  fireLedgerChanged()
  -- A user-initiated delete of recorded data (the History row menu), so debug-logging-§8 wants it
  -- traced: one line per act, carrying the count, the same [Data] tag DeleteAt and Purge use.
  if NS.State.debug and NS.Debug then
    NS.Debug("Data", "delete removed %s entries", tostring(removed))
  end
  return removed
end

--- True, after printing why, while a simulation runs (OWNER_SCOPE C.13, Sim-1.0 host contract H5).
--- `/bl purge` and the panel's Purge button ask it BEFORE opening the confirm, so the confirm never
--- opens; Purge asks it again, so no path past them wipes the ledger mid-simulation either.
function Database:PurgeRefused()
  local sim = NS.Sim
  if not (sim and sim:IsActive()) then return false end
  NS.Print(NS.L["Stop the simulation first."])
  if NS.State.debug and NS.Debug then NS.Debug("Sim", "purge refused: a simulation is running") end
  return true
end

-- Wipe the whole ledger (`/bl purge`). Returns the count removed, or false when a running simulation
-- refused it. The REAL ledger, never the sim sink.
function Database:Purge()
  if self:PurgeRefused() then return false end
  local removed = #NS.db.global.ledger
  NS.db.global.ledger = {}
  fireLedgerChanged()
  if NS.State.debug and NS.Debug then
    NS.Debug("Data", "purge-all removed %s entries", tostring(removed))
  end
  return removed
end

-- Rough per-entry byte cost as written to the SavedVariables .lua file. WoW gives addons no way to
-- read the real on-disk file size, so this estimates: a fixed overhead covering key names, table
-- syntax and numeric fields, plus the length of each string field.
local ENTRY_OVERHEAD = 192
local function estimateEntryBytes(e)
  local n = ENTRY_OVERHEAD
  local strFields = { e.itemLink, e.itemName, e.zone, e.subzone, e.char, e.itemType,
                      e.itemSubType, e.guild }
  for _, s in ipairs(strFields) do
    if type(s) == "string" then n = n + #s end
  end
  return n
end

-- Storage summary for the settings panel: entry count, span in days since the earliest entry, and
-- an ESTIMATED SavedVariables byte size. `now` is injectable for tests; it defaults to time().
function Database:StorageStats(now)
  local ledger = NS.db.global.ledger
  local firstTs, bytes = nil, 0
  for _, e in ipairs(ledger) do
    if e.ts and (not firstTs or e.ts < firstTs) then firstTs = e.ts end
    bytes = bytes + estimateEntryBytes(e)
  end
  local days = 0
  if firstTs then
    now = now or time()
    days = math.max(1, math.ceil((now - firstTs) / 86400))
  end
  return { count = #ledger, days = days, bytes = bytes }
end

-- The retention window in days (0 == Always), read from the ACCOUNT-WIDE store: it governs the
-- shared ledger, so it is one value whatever profile is active (owner decision D6).
function Database:RetentionDays()
  local s = NS.db and NS.db.global and NS.db.global.settings
  return s and s.retentionDays
end

-- Retention cleanup. Drops entries older than the account-wide retention window (0 == Always).
-- Rebuild-and-swap avoids O(n^2) shifting and array holes. Fires LedgerChanged when it actually runs.
-- Two callers only: the once-per-session login pass (core/BankLedger.lua) and the retention row's
-- own onChange. No profile event reaches it (D6). The REAL ledger, never the sim sink.
function Database:PruneOld()
  local days = Database:RetentionDays()
  if not days or days == 0 then
    -- Still one line: the login pass's "armed" line (core/BankLedger.lua) needs its flush, and a
    -- retention window of Always is the answer to "why was nothing pruned".
    if NS.State.debug and NS.Debug then NS.Debug("Prune", "retention always: nothing pruned") end
    return 0
  end
  local cutoff = time() - days * 86400
  local ledger = NS.db.global.ledger
  local kept = {}
  for _, e in ipairs(ledger) do
    if (e.ts or 0) >= cutoff then kept[#kept + 1] = e end
  end
  local removed = #ledger - #kept
  NS.db.global.ledger = kept
  -- Only when a row actually went. A retention pass runs on every login and on every retention
  -- change, and a LedgerChanged with nothing changed repaints both windows and the Insights
  -- charts for no reason. The `days == 0` early return above is the other half of the same rule.
  if removed > 0 then fireLedgerChanged() end
  if NS.State.debug and NS.Debug then
    NS.Debug("Prune", "retention %sd: removed %s entries", tostring(days), tostring(removed))
  end
  return removed
end
