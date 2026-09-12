local _, NS = ...
NS.Slash = NS.Slash or {}
local Sl = NS.Slash
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

--- A deep copy of the declared defaults, so the restored store never aliases the defaults table --
--- a later write into `db.global` would otherwise reach back into `NS.defaults.global` and change
--- what the NEXT reset restores.
local function deepcopyGlobal(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do out[k] = deepcopyGlobal(val) end
  return out
end

-- Confirm dialogs for the destructive actions. Registered once; in-game only.
if type(StaticPopupDialogs) == "table" then
  StaticPopupDialogs["KA0S_BANKLEDGER_PURGE"] = {
    text = "Delete ALL Ka0s Bank Ledger history? This cannot be undone.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
      if NS.Database and NS.Database.Purge then NS.Database:Purge() end
      print("ledger purged.")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
  StaticPopupDialogs["KA0S_BANKLEDGER_RESETALL"] = {
    -- THE COLLECTION'S SECOND CANONICAL WORDING (options-ui-§12), verbatim: the one for an addon
    -- with no profile. The first closes with "your other profiles are not affected", which is a
    -- promise this addon cannot keep -- it has none.
    text = "Reset this addon to its defaults? Everything you have configured or recorded is "
      .. "discarded, for every character on this account — this cannot be undone.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function() Sl:ResetEverything() end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
  -- Bulk-clear confirms for the two item-id filter lists. Non-destructive: clearing a list only
  -- empties its id-set — stored history is never touched (filtering is point-in-time, so there are
  -- no hidden rows to reconcile).
  StaticPopupDialogs["KA0S_BANKLEDGER_CLEAR_BLACKLIST"] = {
    text = "Clear ALL item ids from the blacklist? Future movements of them will be recorded "
      .. "again; your existing history is unaffected.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
      local n = (NS.Filters and NS.Filters:ClearList("blacklist")) or 0
      print(("blacklist cleared (%d %s)."):format(n, n == 1 and "id" or "ids"))
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
  StaticPopupDialogs["KA0S_BANKLEDGER_CLEAR_WHITELIST"] = {
    text = "Clear ALL item ids from the whitelist?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
      local n = (NS.Filters and NS.Filters:ClearList("whitelist")) or 0
      print(("whitelist cleared (%d %s)."):format(n, n == 1 and "id" or "ids"))
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
  -- NO "clear both filters" popup any more. It existed for the Filters subcategory's own top-right
  -- Defaults button, and that page is gone (R3) — the two lists are tabs of the General page now,
  -- whose Defaults button is P:RestoreDefaults and already clears both through CliResetAll. A
  -- confirm dialog with no caller is one nobody can reach, so it was deleted rather than parked.
end

--- debug-logging-§8: the wholesale reset below takes the recorded ledger with the rest of the store,
--- which is a purge of recorded data, so it is traced exactly as Database:Purge traces `/bl purge`:
--- one [Data] line carrying the count. Called just BEFORE the wipe, while the count is still there to
--- read; the wipe that follows is plain table work that cannot fail part-way. Nothing is counted or
--- formatted while logging is off.
local function traceLedgerWipe(g)
  if not (NS.State and NS.State.debug and NS.Debug) then return end
  local n = type(g.ledger) == "table" and #g.ledger or 0
  NS.Debug("Data", "reset-all wiped %s ledger entries", tostring(n))
end

--- debug-logging-§10: the same wipe replaces every stored setting, and that is logged ONCE, as a
--- [Set] line worded by the act. It is the no-profile form of the profile handler's
--- `reset profile '<name>' to defaults (N rows)`: a wholesale replacement, not a walk through the
--- helper, so the write seam never runs and there is no per-row line to mute. N is the stored rows
--- the wipe actually changes: a row already at its default is not counted, and neither is the
--- session-only console row, which lives outside db.global where the wipe cannot reach it. So it is
--- read BEFORE the wipe, beside the [Data] trace, while the old values are still there to compare.
--- Worded apart from the [Data] line's "reset-all" on purpose: that line is the ledger purge, this
--- one is the settings.
local function traceSettingsReset(g)
  if not (NS.State and NS.State.debug and NS.Debug) then return end
  local S, n = NS.Schema, 0
  for _, row in ipairs(S and S.Schema or {}) do
    if not row.sessionOnly and not S.SameValue(S:ReadPath(g, row.path), row.default) then
      n = n + 1
    end
  end
  NS.Debug("Set", "reset account-wide settings to defaults (%d rows)", n)
end

--- The confirm-gated full reset (options-ui-§12), in the shape that rule takes for an addon with
--- NO PROFILE.
---
--- Everything this addon stores is account-wide: `NS.defaults.global` carries the ledger, the filter
--- lists AND the settings, and there is no `profile` section at all. `db:ResetProfile()` -- what the
--- rule asks of an addon that has one -- would be a no-op here, so the rule translates: empty the
--- account-wide store wholesale and merge the declared defaults back, so what comes back is
--- indistinguishable from a fresh install.
---
--- WIPED IN PLACE, and NOT key by key. `NS.db.global` is held by modules from load, so replacing the
--- table would leave every holder on a stale one. And a hand-written list of things to clear fails
--- exactly the way a row-by-row schema sweep fails -- one release later, when something new is
--- stored beside the ones the list names -- which is what this function used to be: a purge, a
--- schema walk, a filter-list clear and two window-geometry carve-outs, five enumerations that
--- between them happened to cover the whole table. AceDB ships no `ResetGlobal`, so it is written
--- here.
---
--- The window resets that follow are not stored data: they re-anchor live frames from what is now an
--- empty store.
---
--- The broadcast is what tells the rest of the addon the store underneath it changed
--- (`architecture-§4`). Every Schema row already sends one on a single-key edit; this rewrites
--- every key there is and used to send nothing, so `modules/Ledger.lua`'s capture gate went on
--- judging bank movements by the cached settings the reset had just destroyed, until a /reload.
--- Once, at the end, with `"reset"` as the reason -- one act, one message. Sending per restored key
--- would make every subscriber rebuild several times over for a single button press, and no
--- subscriber wants finer grain than "all of it changed". The consumers are NOT enumerated here:
--- they subscribe, which is the whole point of the bus.
function Sl:ResetEverything()
  local db = NS.db
  if db and db.global then
    local g = db.global
    traceLedgerWipe(g)
    traceSettingsReset(g)
    for k in pairs(g) do g[k] = nil end
    for k, v in pairs(deepcopyGlobal(NS.defaults and NS.defaults.global or {})) do g[k] = v end
  end
  print("this addon reset to defaults.")
  if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "reset") end
  if NS.Browser and NS.Browser.ResetWindow then NS.Browser:ResetWindow() end
  if NS.SessionWindow and NS.SessionWindow.ResetWindow then NS.SessionWindow:ResetWindow() end
  if NS.Panel and NS.Panel.Refresh then NS.Panel:Refresh() end
end

function Sl:Register()
  NS.addon:RegisterChatCommand("bl", function(input) Sl:OnSlash(input) end)
  NS.addon:RegisterChatCommand("bankledger", function(input) Sl:OnSlash(input) end)
end


-- ── The dispatcher and the schema CLI ──────────────────────────────────────────────────────────
--
-- Everything from `Sl:OnSlash` down used to live here: the dispatch loop, the help renderer, a value
-- formatter, a `key = value` renderer, the list builder, and get/set/reset/resetall. All of it is
-- now LibKa0s-Slash-1.0 (slash-commands), and what is left above this line is the part that is
-- genuinely ours — the confirm dialogs, the chat-command registration, and the full reset.
--
-- WHAT STAYS THE HOST'S BY DESIGN, not by omission: `NS.COMMANDS`. The library takes the table in
-- rather than owning it, so the settings panel can render the same verbs on its landing page without
-- the options library having to resolve the slash library — which would be a real dependency cycle
-- between two majors at load time.

local lib = LibStub and LibStub("LibKa0s-Slash-1.0", true)

-- The addon's version. The TOC's ## Version is the truth and NS.version is the fallback, but that
-- ladder is core/EnvSetup.lua's now — this stays a method so that `/bl version` and the help
-- header keep resolving through ONE place and cannot report different numbers (F-017).
function Sl:Version()
  return NS.Version()
end

if not lib then
  -- Degrade, do not error. Unlike the console, the slash surface is how a user reaches ANYTHING
  -- without the settings panel, so every verb in NS.COMMANDS has to keep working: `show`, `hide`,
  -- `toggle`, `config`, `session`, `test`, `purge` and `debug` are all host handlers that never
  -- touched this library. What is lost is the schema CLI and the generated help index, and those say
  -- so through the shared cause clause.
  local UNAVAILABLE = NS.LIBKA0S_MISSING .. ", so the slash help index and the settings CLI "
    .. "(list/get/set/reset) are unavailable."

  function Sl:PrintHelp() print(UNAVAILABLE) end
  function Sl:BuildListLines() return { UNAVAILABLE } end
  function Sl:CliList() print(UNAVAILABLE) end
  function Sl:CliGet() print(UNAVAILABLE) end
  function Sl:CliSet() print(UNAVAILABLE) end
  function Sl:CliReset() print(UNAVAILABLE) end
  function Sl:CliVersion() print("v" .. tostring(Sl:Version())) end
  function Sl:LandingRows() return { UNAVAILABLE } end

  -- The one verb that must keep WORKING rather than merely explaining itself: it is the body the
  -- settings panel's Defaults button and the confirm-gated `/bl resetall` both share, and a reset
  -- that silently did nothing is worse than a missing help index.
  --
  -- Bracketed like the library's walk (debug-logging-§10): the seam mutes its per-row [Set] line,
  -- tallies the rows whose value changed, and S.BulkEnd logs the one `[Set] reset all: N rows`.
  -- BulkEnd runs on the raising path too, so the mute cannot stick, and the error is re-raised
  -- unchanged. Every caught error marks the line ` (stopped by an error)`. This walk has its own
  -- pcall, so unlike the library it can mark a raise of nil or false too: BulkEnd gets a stand-in
  -- `err`, and the re-raise still carries the original value.
  function Sl:CliResetAll()
    local S = NS.Schema
    local function walk()
      S.BulkBegin("reset", "all")
      local ok, err = pcall(function()
        for _, row in ipairs(S.Schema) do S:Set(row.path, S:Default(row.path)) end
      end)
      local failure = nil
      if not ok then failure = (err ~= nil and err ~= false) and err or "raised without a value" end
      S.BulkEnd("reset", "all", nil, failure, { profileReset = false })
      if not ok then error(err, 0) end
    end
    if NS.Panel and NS.Panel.Batch then NS.Panel:Batch(walk) else walk() end
    if NS.Filters and NS.Filters.ClearAll then NS.Filters:ClearAll() end
    if NS.Browser and NS.Browser.ResetView then NS.Browser:ResetView(true) end
    print("All settings reset to defaults")
  end

  -- Dispatch still has to work, so this is the library's loop reproduced at its smallest.
  function Sl:OnSlash(input)
    local raw = (input or ""):match("^%s*(.-)%s*$") or ""
    if raw == "" then return Sl:PrintHelp() end
    local verb, rest = raw:match("^(%S+)%s*(.*)$")
    verb = (verb or ""):lower()
    for _, cmd in ipairs(NS.COMMANDS) do
      if cmd[1] == verb then return cmd[3](rest or "") end
    end
    print(("unknown command '%s'"):format(verb))
    Sl:PrintHelp()
  end
  return
end

-- Render a stored value the library has no type for. `settings.excludedStores` is a SET of muted
-- stores, and lib.FormatValue ends at Core's SafeToString — which probes table.concat, refuses a
-- table, and answers "<secret>". A user being told a plain settings value is combat-protected is
-- worse than an ugly one, so this is the reason LibKa0s grew a `format` hook at Slash minor 5.
-- Byte-identical to what the deleted Sl.FormatSchemaValue rendered.
local function formatValue(row, v)
  if row and row.type == "table" then
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k, on in pairs(v) do if on then keys[#keys + 1] = tostring(k) end end
    table.sort(keys)
    if #keys == 0 then return "(none)" end
    return "{" .. table.concat(keys, ", ") .. "}"
  end
  return nil   -- nil means "not mine" — the caller falls through to the library's own renderer
end

local cli = lib:New({
  slash        = "/bl",
  slashAliases = { "/bankledger" },
  commands     = NS.COMMANDS,
  print        = function(line) print(line) end,
  version      = function() return Sl:Version() end,

  -- The schema seam. Every one of these is the SINGLE write/read path the settings panel already
  -- uses, so a slash change and a panel change take the same route: same validation, same debug
  -- trace, same onChange reaction.
  get          = function(path) return NS.Schema:Get(path) end,
  set          = function(path, v) NS.Schema:Set(path, v) end,
  findRow      = function(path) return NS.Schema:FindRow(path) end,
  allRows      = function() return NS.Schema.Schema end,
  applyDefault = function(row) NS.Schema:Set(row.path, NS.Schema:Default(row.path)) end,

  -- The bulk bracket (Slash minor 8, debug-logging-§10). CliResetAll, which is `/bl resetall` and
  -- both Defaults controls, calls these around its row walk: the seam mutes its per-row [Set] line
  -- and S.BulkEnd emits the one `[Set] reset all: N rows`, N the rows whose value changed. Always
  -- the pair, never one without the other. The Options descriptor gets no pair: this
  -- addon never calls O.RestoreDefaults or O.RestoreAllDefaults (settings/OptionsSetup.lua).
  -- Direct references are safe because the TOC loads settings/Schema.lua first.
  bulkBegin    = NS.Schema.BulkBegin,
  bulkEnd      = NS.Schema.BulkEnd,

  -- This addon's schema groups its rows under `group`, which names the TAB it draws on; the
  -- library defaults to `row.page`. Without this every row collapses under one "[settings]" heading
  -- and `/bl list` silently loses both its section headings.
  groupKey = function(row) return row.group or "?" end,

  -- Added upstream at Slash minor 5 for exactly this row. Returning nil for everything else lets the
  -- library's own type-aware renderer answer, so numbers keep their `fmt` and booleans keep reading
  -- true/false.
  format = function(row, v)
    local mine = formatValue(row, v)
    if mine ~= nil then return mine end
    return lib.FormatValue(row, v)
  end,

  -- Same shape, for reading. The library parses bool/number/string/color; `table` is ours and there
  -- is no sensible chat grammar for editing a set, so it refuses with a line that points at the
  -- place that CAN edit it rather than at the library's "unknown setting type 'table'".
  parse = function(row, text)
    if row and row.type == "table" then
      return nil, "edit this one in the settings panel (/bl config)"
    end
    return lib.ParseValue(row, text)
  end,
})

function Sl:OnSlash(input) return cli:OnSlash(input) end
function Sl:PrintHelp() return cli:PrintHelp() end
function Sl:BuildListLines() return cli:BuildListLines() end
function Sl:CliList() return cli:CliList() end
function Sl:CliGet(rest) return cli:CliGet(rest) end
function Sl:CliSet(rest) return cli:CliSet(rest) end
function Sl:CliReset(rest) return cli:CliReset(rest) end
function Sl:CliVersion() return cli:CliVersion() end

-- The settings landing page renders the same verbs, through the same one row formatter, in the help
-- colors — un-indented, because there each row is its own label. This is the convergence: the panel
-- used to carry a SECOND formatter for the same data, with doubled spaces around a white-wrapped em
-- dash and a bare description, and the two drifted apart the moment either was touched.
function Sl:LandingRows() return cli:LandingRows() end

-- Reset every user setting to its default. The library's CliResetAll walks the schema rows and
-- acknowledges; it cannot know about this addon's two pieces of state with no Schema widget: the
-- filter id-sets, an architecture-§5 registry cleared through its one writer NS.Filters, and the
-- saved ledger view, named non-setting state its owner Browser clears. So they are wrapped around the
-- library's call rather than forked from it. ResetView is called SILENTLY so this path still emits
-- exactly ONE confirmation line.
--
-- Order matters: those two run BEFORE the library's call, because that call is what prints the
-- acknowledgment and a line claiming everything was reset must not precede half the reset.
-- Non-destructive: the ledger and the window geometry are left alone (the confirm-gated
-- Sl:ResetEverything handles those).
function Sl:CliResetAll()
  if NS.Filters and NS.Filters.ClearAll then NS.Filters:ClearAll() end
  if NS.Browser and NS.Browser.ResetView then NS.Browser:ResetView(true) end
  -- Batched: the library's CliResetAll walks every schema row and each one goes through the write
  -- seam, which now repaints. Ten rows would otherwise be ten refreshes, and one of General's
  -- refreshers walks the whole ledger.
  if NS.Panel and NS.Panel.Batch then
    return NS.Panel:Batch(function() cli:CliResetAll() end)
  end
  return cli:CliResetAll()
end
