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
--- It takes no store argument any more: it reads through S:Get, which is where the minimap row's
--- inversion lives, and S:Get reads db.global — the very table the caller was handing in.
--- Worded apart from the [Data] line's "reset-all" on purpose: that line is the ledger purge, this
--- one is the settings.
local function traceSettingsReset()
  if not (NS.State and NS.State.debug and NS.Debug) then return end
  local S, n = NS.Schema, 0
  for _, row in ipairs(S and S.Schema or {}) do
    -- S:Get, not S:ReadPath: the minimap row's stored boolean is the INVERSE of the row's own
    -- (launcher-§3), and comparing the raw key against the row default would count it as changed
    -- on every reset. S:Get answers in the sense `row.default` is written in. `g` IS db.global,
    -- which is what S:Get reads, so this still reports the pre-wipe store.
    -- An EXEMPT row is not reset, so it is not counted (launcher-§3). Without this the count is
    -- wrong by one for every player who has hidden their minimap button: the row differs from its
    -- default and the wipe below deliberately leaves it that way.
    if not row.sessionOnly and not S.RESET_EXEMPT[row.path]
      and not S.SameValue(S:Get(row.path), row.default) then
      n = n + 1
    end
  end
  NS.Debug("Set", "reset account-wide settings to defaults (%d rows)", n)
end

--- The post-wipe repaint, lifted out of `Sl:ResetEverything` so that function stays under the
--- complexity ceiling the release gate enforces (`performance-§10`). It is a fan-out of guarded
--- calls and nothing else. Each target is optional because a reset can land before a module has
--- built its frame, and none of them touch stored data: they re-anchor live frames from what is now
--- an empty store.
local function refreshAfterReset()
  -- The minimap button follows the store the wipe just replaced. NOT through the write seam: the
  -- act has already logged its one [Set] summary line and a per-row line beside it would
  -- contradict it (debug-logging-§10). The store already says what it should be — this only moves
  -- the button to match, which is the half LibDBIcon cannot work out for itself.
  if NS.Launcher and NS.Launcher.SetShown then
    local t = NS.db and NS.db.global and NS.db.global.minimap
    NS.Launcher:SetShown(not (type(t) == "table" and t.hide))
  end
  if NS.Browser and NS.Browser.ResetWindow then NS.Browser:ResetWindow() end
  if NS.SessionWindow and NS.SessionWindow.ResetWindow then NS.SessionWindow:ResetWindow() end
  if NS.Panel and NS.Panel.Refresh then NS.Panel:Refresh() end
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
--- The window resets live in `refreshAfterReset` above. They are not stored data: they re-anchor
--- live frames from what is now an empty store.
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
    traceSettingsReset()
    -- LIBDBICON'S OWN TABLE SURVIVES THE WIPE, WHOLE (launcher-§3, standard v2.54.0). Both keys in
    -- it are per-installation display preferences rather than settings: `hide` is whether the player
    -- wants the button at all, `minimapPos` is the angle they dragged it to, and no reset in the
    -- collection has ever been meant to put a button back on a minimap at the default angle.
    --
    -- THIS ADDON IS ONE OF THE TWO SHAPES THAT RULE NAMES, and the reason the rule stopped being an
    -- argument and became a property. The old reasoning -- Reset all settings is a PROFILE reset and
    -- this table is GLOBAL, so it cannot be reached -- has no premise here: there is no profile at
    -- all, so the reset is this wholesale wipe of the account-wide store, and `minimap = { hide =
    -- false }` is a declared default that the merge below put straight back. A player who had hidden
    -- their button got it back, at the default angle, from a button labeled *Reset all settings*.
    --
    -- Carved out by holding the TABLE and putting it back, rather than by reading `hide` and
    -- re-writing it: `minimapPos` is in there too and is nobody's schema row, so a key-by-key
    -- carve-out would be a list to keep current -- the exact failure the wholesale wipe exists to
    -- avoid. The write seam's own sweep is exempted separately, through S.RESET_EXEMPT.
    local minimap = g.minimap
    for k in pairs(g) do g[k] = nil end
    for k, v in pairs(deepcopyGlobal(NS.defaults and NS.defaults.global or {})) do g[k] = v end
    if type(minimap) == "table" then g.minimap = minimap end
  end
  -- Test mode is session state (options-ui-§15). It lives in NS.State, never in db.global, so the
  -- wipe above cannot reach it, and that rule says Reset all settings ends it. So it is ended by
  -- name, and NOT through the write seam, which would log a per-row [Set] line beside this act's one
  -- summary (debug-logging-§10). LT:SetTestMode repaints the panel itself.
  local LT = NS.LedgerTable
  if LT and LT.IsTestMode and LT:IsTestMode() then LT:SetTestMode(false) end
  print("this addon reset to defaults.")
  if NS.bus then NS.bus:SendMessage(NS.MSG.SETTINGS_CHANGED, "reset") end
  refreshAfterReset()
end

-- THE ONE STORED PATH `/bl enable`, `/bl disable` and the Master-controls "Enable Bank Ledger"
-- checkbox all write (slash-commands-§2). Named once, here, so the verbs cannot drift onto a key
-- of their own — which is the whole failure the reserved pair exists to prevent.
local ENABLED_PATH = "settings.enabled"

--- `/bl enable` and `/bl disable`, as ALIASES of one `set` and nothing more.
---
--- Routed through Sl:CliSet rather than through NS.Schema:Set directly, and the difference is the
--- ECHO: CliSet reads the value back AFTER writing and prints it in slash-commands-§5's single-line
--- `path = value` shape, from the same shared formatter every other verb prints through. Calling
--- the seam here and printing our own line would be a second confirmation wording for one act.
---
--- Defined ABOVE the library branch on purpose: `Sl:CliSet` is resolved at CALL time, so this one
--- definition serves both the live arm and the degraded one, and neither arm carries a copy.
function Sl:CliEnabled(on)
  return Sl:CliSet(ENABLED_PATH .. " " .. (on and "true" or "false"))
end

-- ── A DISABLED ADDON REFUSES ITS FEATURE VERBS (slash-commands-§2, §7) ────────────────────────
--
-- Acting is the wrong answer twice over: the player asked for something the addon is currently
-- standing down from doing, and a silent no-op leaves them with no clue why nothing happened. So a
-- verb that DRIVES THE ADDON'S FEATURES answers on ONE tagged line naming `/bl enable`, and does
-- nothing else -- no partial work, no side effect, no second line. One line is the whole courtesy.
--
-- THE GATE IS THE LIBRARY'S NOW, AND THE HOST'S COPY IS GONE. This file used to carry a twelve-name
-- ALWAYS_LIVE table, a stored-path read and a refusal printer of its own -- the collection's rule
-- re-implemented per addon, with the wording re-spelled per addon along with it. Against Slash minor
-- 14 (LibKa0s v1.42.0) the descriptor's `isEnabled` and `brandName` are the whole adoption: the library keeps its own
-- lib.LIVE_VERBS (the standard's twelve reserved verbs), refuses what is left, and renders the line
-- from lib.DISABLED_LINE_FORMAT so eleven addons cannot each word it differently.
--
-- NO `liveVerbs` IS PASSED, deliberately. That field NARROWS or WIDENS the live set, and this addon
-- wants neither: every reserved verb answers while disabled, and the bare `/bl` opens the settings
-- panel. An earlier pass against Slash minor 12 cut the disabled surface to `enable` and `help`;
-- standard v2.57.0 reversed that, minor 13 implemented the reversal and minor 14 stopped refusing a
-- reserved verb the host never registered, so the right host-side change is to pass nothing and let
-- the library's default set stand.
--
-- WHAT THE GATE DOES NOT REACH. A TYPO is not refused: the gate sits AFTER the COMMANDS lookup, so
-- a word this addon does not ship still gets `unknown command '<verb>'` and the index -- and from
-- minor 14 that includes a RESERVED verb it does not ship, which today is `perf`. The addon
-- understood perfectly well and is off is a true sentence about `show`; said about a misspelling it
-- tells a player their spelling was fine.

--- Has the PLAYER switched the addon off? Asked at DISPATCH time and never cached, so the command
--- after an `/bl enable` works. Resolved through NS.IsDisabled, which reads the latch's `disabled`
--- hold -- the same hold the Master-controls checkbox drives -- so the gate can never disagree with
--- what the panel shows, and a perf-suspended addon (a different hold) is not treated as disabled.
local function addonIsEnabled()
  return not (NS.IsDisabled and NS.IsDisabled())
end

--- THE ONE DOOR EVERY VERB COMES THROUGH, on both arms.
---
--- `Sl:Register` points both chat commands here, and `Sl:Dispatch` is what each arm defines for
--- itself -- the library's loop on the live arm, its smallest reproduction on the degraded one.
--- Defined ABOVE the library branch on purpose: `Sl:Dispatch` resolves at CALL time, so one
--- definition serves both arms and neither carries a copy.
function Sl:OnSlash(input)
  return Sl:Dispatch(input)
end

--- The refusal, for a caller that is not a slash command: the launcher's LEFT click
--- (launcher-§2, slash-commands-§7). Answers true when it refused and the click must not act.
---
--- The line itself comes from `Sl:DisabledLine`, which is the library's builder on the live arm.
--- launcher-§2 and slash-commands-§7 are one wording, so the button and the verb can never word the
--- same refusal two ways.
function Sl:RefuseIfDisabled()
  if addonIsEnabled() then return false end
  print(Sl:DisabledLine())
  return true
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
        -- S:ApplyDefault, not S:Set: the same seam the live arm's descriptor hands the library, so
        -- the Minimap button row is exempt from the sweep on BOTH arms (launcher-§3).
        for _, row in ipairs(S.Schema) do S:ApplyDefault(row) end
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

  -- The refusal line with no library to build it. The FORMAT is the collection's, copied from
  -- lib.DISABLED_LINE_FORMAT rather than re-worded: on this arm there is no library to ask, and a
  -- second wording invented for the degraded case is still a second wording a player can meet.
  function Sl:DisabledLine()
    return ("%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r")
      :format(tostring(NS.BRAND_NAME or "/bl"), "/bl enable")
  end

  -- The gate, reproduced for this arm alone. The live set is the standard's twelve reserved verbs,
  -- which is lib.LIVE_VERBS written out: every one of them answers while the addon is off, because
  -- a player must be able to read and repair settings and to reach the panel -- which is precisely
  -- when they are most likely to need to -- and `enable` above all, or the pair is one-way.
  -- `perf` is on the list although this addon registers no such verb (it holds the
  -- performance-§12 no-combat-path exemption), because the verb is RESERVED everywhere and arming
  -- the harness later must be a registration rather than a second edit here.
  local LIVE_VERBS = {
    help = true, config = true, version = true, enable = true, disable = true,
    debug = true, perf = true,
    get = true, set = true, list = true, reset = true, resetall = true,
  }

  -- Dispatch still has to work, so this is the library's loop reproduced at its smallest, gate and
  -- all. `Dispatch`, not `OnSlash`: Sl:OnSlash is the one door, defined once above the branch.
  function Sl:Dispatch(input)
    local raw = (input or ""):match("^%s*(.-)%s*$") or ""
    -- A bare /bl runs the `config` verb, as the library does from Slash minor 11
    -- (slash-commands-§4): the settings panel on its landing page. `help` is the index. With no
    -- `config` verb registered, bare input falls back to the index.
    if raw == "" then
      for _, cmd in ipairs(NS.COMMANDS) do
        if cmd[1] == "config" then return cmd[3]("") end
      end
      return Sl:PrintHelp()
    end
    local verb, rest = raw:match("^(%S+)%s*(.*)$")
    verb = (verb or ""):lower()
    for _, cmd in ipairs(NS.COMMANDS) do
      if cmd[1] == verb then
        -- THE GATE, AFTER THE LOOKUP, as the library places it: a verb this addon SHIPS and is
        -- standing down from is refused, and a typo falls through to the unknown-verb answer below.
        if not LIVE_VERBS[verb] and NS.IsDisabled and NS.IsDisabled() then
          return print(Sl:DisabledLine())
        end
        return cmd[3](rest or "")
      end
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

  -- THE DISABLED GATE (Slash minor 12, reversed to the twelve reserved verbs at minor 13, refusing
  -- only verbs the host ships from minor 14). Asked at
  -- dispatch time, never cached. `brandName` is required alongside it and is the plain-text brand
  -- the LDB object already wears, spelled once in core/LauncherSetup.lua. No `liveVerbs`: see the
  -- block above the dispatcher on why passing one would be the wrong half of the reversal.
  isEnabled    = addonIsEnabled,
  brandName    = NS.BRAND_NAME,
  print        = function(line) print(line) end,
  version      = function() return Sl:Version() end,

  -- The schema seam. Every one of these is the SINGLE write/read path the settings panel already
  -- uses, so a slash change and a panel change take the same route: same validation, same debug
  -- trace, same onChange reaction.
  -- The LibKa0s-Schema-1.0 instance's own members, handed over as values (settings/Schema.lua,
  -- which the TOC loads first). No gate stands in front of the seam, so nothing is bypassed.
  get          = NS.SchemaRuntime.Get,
  set          = NS.SchemaRuntime.Set,
  findRow      = NS.SchemaRuntime.FindRow,
  allRows      = NS.SchemaRuntime.AllRows,
  -- ApplyDefault honors S.RESET_EXEMPT, so the sweep this feeds cannot walk the Minimap button row
  -- back to shown (launcher-§3). The library reaches this from CliReset (one named path) too, and
  -- the veto there is inert by construction: it binds only inside the bracket below.
  applyDefault = NS.SchemaRuntime.ApplyDefault,

  -- The bulk bracket (Slash minor 8, debug-logging-§10). CliResetAll, which is `/bl resetall` and
  -- both Defaults controls, calls these around its row walk: the seam mutes its per-row [Set] line
  -- and the outermost BulkEnd emits the one `[Set] reset all: N rows`, N the rows whose value
  -- changed. Always the pair, never one without the other. The Options descriptor carries the same
  -- pair (settings/OptionsSetup.lua), though this addon never calls O.RestoreDefaults or
  -- O.RestoreAllDefaults. Direct references are safe because the TOC loads settings/Schema.lua first.
  bulkBegin    = NS.SchemaRuntime.BulkBegin,
  bulkEnd      = NS.SchemaRuntime.BulkEnd,

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

-- `Dispatch`, not `OnSlash`: Sl:OnSlash is defined once, above the library branch, and it is where
-- the disabled-verb gate lives (slash-commands-§2).
function Sl:Dispatch(input) return cli:OnSlash(input) end
function Sl:PrintHelp() return cli:PrintHelp() end
function Sl:BuildListLines() return cli:BuildListLines() end
function Sl:CliList() return cli:CliList() end
function Sl:CliGet(rest) return cli:CliGet(rest) end
function Sl:CliSet(rest) return cli:CliSet(rest) end
function Sl:CliReset(rest) return cli:CliReset(rest) end
function Sl:CliVersion() return cli:CliVersion() end

-- The collection's one refusal wording, built by the library from lib.DISABLED_LINE_FORMAT. Read by
-- the launcher's left click through Sl:RefuseIfDisabled; MUST NOT be re-spelled host-side.
function Sl:DisabledLine() return cli:DisabledLine() end

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
