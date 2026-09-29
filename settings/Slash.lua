local _, NS = ...
NS.Slash = NS.Slash or {}
local Sl = NS.Slash
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

-- Confirm dialogs for the destructive actions. Registered once; in-game only.
if type(StaticPopupDialogs) == "table" then
  StaticPopupDialogs["KA0S_BANKLEDGER_PURGE"] = {
    text = "Delete ALL " .. NS.BRAND_NAME .. " history? This cannot be undone.",
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
    -- THE COLLECTION'S FIRST CANONICAL WORDING (options-ui-§12), verbatim: the one for an addon with a
    -- profile section. This addon has had one since schema v3, and it keeps its account-wide ledger
    -- beside it -- the "addon with both" case, which resets the profile and never folds the recorded
    -- history into it. Deleting history is `/bl purge`, confirmed separately (KA0S_BANKLEDGER_PURGE).
    text = "Reset this profile to the addon's defaults? Everything you have configured or added in "
      .. "it is discarded — your other profiles are not affected.",
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
      print("blacklist cleared:", n, n == 1 and "id." or "ids.")
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
      print("whitelist cleared:", n, n == 1 and "id." or "ids.")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
  -- NO "clear both filters" popup any more. It existed for the Filters subcategory's own top-right
  -- Defaults button, and that page is gone (R3) — the two lists are tabs of the General page now,
  -- whose Defaults button raises KA0S_BANKLEDGER_RESETALL above, and the profile reset behind it
  -- empties both lists with the rest of the profile. A confirm dialog with no caller is one nobody can
  -- reach, so it was deleted rather than parked.
end

--- debug-logging-§10: a profile reset is logged ONCE, by the profile-event handler
--- (NS.OnProfileEvent in core/Database.lua), as `[Set] reset profile '<name>' to defaults (N rows)`.
--- N is the stored rows the reset actually changes, so it is counted HERE, before the reset, while the
--- old values are still there to compare, and handed over through NS.SetPendingResetRows. A row
--- already at its default is not counted, and neither is a session-only row (its storage is not the
--- profile) or an account-wide one (S.GLOBAL_ROWS: the minimap row, launcher-§3, and the retention
--- window, owner decision D6; a profile reset cannot reach either). Read through S:Get, which is
--- where the minimap row's inversion lives. Nothing is counted while logging is off.
local function countResetRows()
  if not (NS.State and NS.State.debug and NS.Debug) then return nil end
  local S, n = NS.Schema, 0
  for _, row in ipairs(S and S.Schema or {}) do
    if not row.sessionOnly and not S.GLOBAL_ROWS[row.path]
      and not S.SameValue(S:Get(row.path), row.default) then
      n = n + 1
    end
  end
  return n
end

--- The confirm-gated global reset (options-ui-§12), in the shape that rule takes for an addon with
--- BOTH a profile and an account-wide store: `db:ResetProfile()`, the active profile only. It is the
--- ONE reset: the popup's OnAccept runs it, and every control -- Reset all settings, the page and
--- footer Defaults, `/bl resetall` -- reaches the popup through Sl:RequestResetAll below. AceDBOptions'
--- own Reset Profile on the Profiles page is the same act by construction.
---
--- WHAT IT TAKES is everything the profile holds: every setting, both filter lists, the saved view
--- and both windows' stored geometry. WHAT IT KEEPS is everything account-wide: the recorded ledger
--- (deleting history is `/bl purge`, a separate, separately confirmed act, never folded into a
--- settings reset), the retention window that governs it (owner decision D6, so the reset cannot
--- prune), LibDBIcon's table (launcher-§3), the profile list and every other profile.
---
--- NOT a schema walk and NOT a hand-written list of keys. AceDB empties the profile in place and
--- merges its defaults back, then fires OnProfileReset, and NS.OnProfileEvent does the rest: it ends
--- the session-only rows a profile reset cannot reach (test mode, the debug console), then takes the
--- order every profile event takes -- the migration runner, the enable latch (a reset made while
--- disabled re-enables the addon, as a fresh profile is), one SettingsChanged and one LedgerChanged
--- broadcast, the windows re-anchored from the now-empty geometry (centered), the ledger window's
--- view back to stock, the panel repaint, and the one [Set] line. Doing that in the handler rather
--- than here is what makes the Profiles page's own Reset Profile the same act.
function Sl:ResetEverything()
  local db = NS.db
  if db and db.ResetProfile then
    NS.SetPendingResetRows(countResetRows())
    db:ResetProfile()
  end
  print("profile '" .. tostring(db and db.GetCurrentProfile and db:GetCurrentProfile() or "?")
    .. "' reset to defaults.")
end

--- THE SINGLE ENTRY POINT to the global reset (options-ui-§12). Reset all settings, the General
--- page's Defaults button, Blizzard's footer control (which forwards to it) and `/bl resetall` all
--- call this, and it only ASKS: the confirm popup's OnAccept is Sl:ResetEverything. With no popup
--- API it runs the reset directly, the arm the headless harness takes.
---
--- Defined ABOVE the library branch on purpose, so both arms' CliResetAll resolve the same one.
--- Recorded history is never part of it; `/bl purge` deletes history alone.
function Sl:RequestResetAll()
  if type(StaticPopup_Show) == "function" then
    return StaticPopup_Show("KA0S_BANKLEDGER_RESETALL")
  end
  return Sl:ResetEverything()
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
--- definition serves the live arm. The degraded arm overrides it below, because its CliSet can
--- only print the CLI-unavailable line.
---
--- THEN THE LATCH IS RE-RUN. On a full load the write went through the composed row, whose
--- onChange already drove it, and NS.ReevaluateEnabled fires only on a real edge, so this is a
--- no-op there. On a partial load (Schema present, Options absent) the path has no row and the
--- seam stores it through S.WRITE_THROUGH, which runs no onChange -- this call is what stands the
--- addon down or back up in that case.
function Sl:CliEnabled(on)
  local r = Sl:CliSet(ENABLED_PATH .. " " .. (on and "true" or "false"))
  if NS.ReevaluateEnabled then NS.ReevaluateEnabled() end
  return r
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
-- lib.LIVE_VERBS (the standard's reserved verbs, thirteen since Slash minor 16), refuses what is
-- left, and renders the line from lib.DISABLED_LINE_FORMAT so eleven addons cannot each word it
-- differently.
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
  -- The live library's VERSION is "v%s": the prefix abuts the value with no separator, so the one
  -- join stays a concat of addon-owned, secret-free text (the TOC version) rather than a printer
  -- argument, which would put a space between them (events-frames-taint-§8).
  function Sl:CliVersion() print("v" .. tostring(Sl:Version())) end
  function Sl:LandingRows() return { UNAVAILABLE } end

  -- The one verb that must keep WORKING rather than merely explaining itself, because a reset that
  -- silently did nothing is worse than a missing help index. It needs no library: it is the same
  -- confirm-gated request as the live arm (options-ui-§12), whose OnAccept is the host's own
  -- Sl:ResetEverything. The member name is kept for NS.Slash parity with the live arm.
  function Sl:CliResetAll() return Sl:RequestResetAll() end

  -- `/bl enable` and `/bl disable` keep WORKING on this arm too (slash-commands-§2: the reserved
  -- pair is never one-way), which is why this arm carries its own body instead of the shared one
  -- above: that one routes through Sl:CliSet, which here prints the CLI-unavailable line and writes
  -- nothing. The seam stores `settings.enabled` through S.WRITE_THROUGH even though the composer
  -- that declares its row is absent (WS-02 route a); a write-through row runs no onChange, so the
  -- latch is re-run here. A refusal (no store yet) prints the seam's own words, never raises and
  -- never acknowledges. The echo is the `path = value` line the live CliSet prints.
  function Sl:CliEnabled(on)
    local ok, err = NS.Schema:Set(ENABLED_PATH, on)
    if not ok then return print(err) end
    NS.ReevaluateEnabled()
    print(ENABLED_PATH, "=", tostring(on))   -- the same bytes, as printer arguments
  end

  -- The refusal line with no library to build it. The FORMAT is the collection's, copied from
  -- lib.DISABLED_LINE_FORMAT rather than re-worded: on this arm there is no library to ask, and a
  -- second wording invented for the degraded case is still a second wording a player can meet.
  -- Published as Sl.__DISABLED_LINE_FORMAT so tests/test_surface_parity.lua can hold the copy to
  -- the library's bytes; the `__` prefix keeps it out of the public surface parity compares.
  local DISABLED_LINE_FORMAT = "%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r"
  Sl.__DISABLED_LINE_FORMAT = DISABLED_LINE_FORMAT
  function Sl:DisabledLine()
    return DISABLED_LINE_FORMAT:format(tostring(NS.BRAND_NAME or "/bl"), "/bl enable")
  end

  -- The gate, reproduced for this arm alone. The live set is the standard's thirteen reserved verbs,
  -- which is lib.LIVE_VERBS written out: every one of them answers while the addon is off, because
  -- a player must be able to read and repair settings and to reach the panel -- which is precisely
  -- when they are most likely to need to -- and `enable` above all, or the pair is one-way.
  -- `perf` is on the list although this addon registers no such verb (it holds the
  -- performance-§12 no-combat-path exemption), because the verb is RESERVED everywhere and arming
  -- the harness later must be a registration rather than a second edit here.
  local LIVE_VERBS = {
    help = true, config = true, version = true, enable = true, disable = true,
    debug = true, perf = true, diagnostics = true,
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
    -- The live library's UNKNOWN_COMMAND wording, `unknown command '<verb>'`. The verb is a
    -- separate printer argument (events-frames-taint-§8); only its quotes abut it, and the verb is
    -- the player's own slash text, already lower-cased above, so that join is secret-free.
    print("unknown command", "'" .. verb .. "'")
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
  -- `set` is the instance's THREE-value member, not NS.Schema:Set (which trims to two): on a refusal
  -- it answers `false, err, why` with nothing stored, and the library (Slash minor 15) prints
  -- INVALID for the path, then the reason and the why on indented lines, in place of an echo of the
  -- unchanged value. Every row carries a default, so `/bl reset` never meets NO_DEFAULT here.
  get          = NS.SchemaRuntime.Get,
  set          = NS.SchemaRuntime.Set,
  findRow      = NS.SchemaRuntime.FindRow,
  allRows      = NS.SchemaRuntime.AllRows,
  -- ApplyDefault honors S.RESET_EXEMPT, so the sweep this feeds cannot walk the Minimap button row
  -- back to shown (launcher-§3) or the retention window back to 30 days, which would prune history
  -- (owner decision D6). The library reaches this from CliReset (one named path) too, and
  -- the veto there is inert by construction: it binds only inside the bracket below.
  applyDefault = NS.SchemaRuntime.ApplyDefault,

  -- The bulk bracket (Slash minor 8, debug-logging-§10). The library's own CliResetAll calls these
  -- around its row walk: the seam mutes its per-row [Set] line and the outermost BulkEnd emits the
  -- one `[Set] reset all: N rows`, N the rows whose value changed. NOTHING HERE CALLS THAT WALK any
  -- more -- `/bl resetall` and both Defaults controls are the confirm-gated Sl:RequestResetAll
  -- (options-ui-§12) -- but the descriptor keeps the pair so the library's seam stays whole. The
  -- Options descriptor carries the same pair (settings/OptionsSetup.lua), though this addon never
  -- calls O.RestoreDefaults or O.RestoreAllDefaults. Direct references are safe because the TOC
  -- loads settings/Schema.lua first.
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

-- The collection's one refusal wording, built by the library from lib.DISABLED_LINE_FORMAT. MUST NOT
-- be re-spelled host-side. The launcher's descriptor read it as `disabledLine` until Launcher minor 4
-- retired the field along with the left-click refusal it fed.
function Sl:DisabledLine() return cli:DisabledLine() end

-- The settings landing page renders the same verbs, through the same one row formatter, in the help
-- colors — un-indented, because there each row is its own label. This is the convergence: the panel
-- used to carry a SECOND formatter for the same data, with doubled spaces around a white-wrapped em
-- dash and a bare description, and the two drifted apart the moment either was touched.
function Sl:LandingRows() return cli:LandingRows() end

-- `/bl resetall` is the ONE global reset (options-ui-§12), not the library's schema walk: it asks
-- through the same confirm popup as Reset all settings and both Defaults controls, and Yes resets the
-- active profile -- the settings, the filter lists and the saved view. Recorded history is kept.
-- The member name stays CliResetAll for NS.Slash parity with the degraded arm.
function Sl:CliResetAll() return Sl:RequestResetAll() end
