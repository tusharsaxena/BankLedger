<!--
  THE FULL AGENT BRIEF for Ka0s Bank Ledger.

  This began as the Ka0s WoW Addon Standard's context pack (standards/NEW_ADDON_CONTEXT.md,
  v2.7.0) and has since been SPECIALIZED to this addon: the generic placeholders are filled in with
  Bank Ledger's real TOC, tree, modules, messages, commands and test seams, and the
  new-addon scaffolding steps are reframed as the shipped state.

  THIS IS A DELIBERATE, RECORDED DEVIATION from the standard's re-drop contract — see
  docs/ARCHITECTURE.md ▸ "Documented deviations". Do NOT re-drop this file verbatim from upstream:
  that would erase the specialization. When the standard moves on, diff the new pack against this
  file and port the CHANGED RULES by hand, leaving the Bank Ledger specifics in place.

  The root CLAUDE.md is a short stub that points here. The "Conform to the Ka0s WoW Addon Standard"
  bullet that opens the Hard rules cheat sheet is one of the four mandated standards-reference
  sites (documentation-§6 item 4) and must survive every edit.
-->

# Ka0s Bank Ledger — Agent Context Pack

**The full agent brief for this addon.** Self-contained — no external lookups required for an LLM or
new contributor to work on Bank Ledger and stay standards-compliant. The root `CLAUDE.md` is a stub
pointing here; `docs/ARCHITECTURE.md` carries the design detail this file summarizes.

Authoritative reference: `WowAddonStandards/standards/STANDARDS.md`. This document is its
operational distillation, specialized to Bank Ledger. Every Ka0s addon is built to the standard and
references it: <https://github.com/tusharsaxena/WowAddonStandards>.

**Scope:** Retail (Mainline) only.

**This addon at a glance:** `BankLedger` v1.0.0, Interface 120007, SavedVariables `BankLedgerDB`
(account-wide `global` only), slash `/bl` aliased `/bankledger`, 24 source files across
`core/ defaults/ locales/ modules/ settings/`, 685 headless test cases.

---

## Where things stand

Bank Ledger is **already scaffolded, shipped and compliant** — v1.0.0 is published on CurseForge
(project `1629058`) and the addon's row is in `WowAddonStandards/standards/ADDONS.md`, so it is in
scope for every standards refresh. The scaffolding steps a new addon works through are done; what
remains is keeping it that way.

The working loop for a change here:

1. **Read the design first.** `docs/ARCHITECTURE.md` is the module map, data model, message bus,
   slash surface, event wiring, taint notes and known limitations. This file is the *rules*;
   ARCHITECTURE is the *system*.
2. **Test-first.** Write or extend a failing case under `tests/`, then implement. See
   `docs/testing.md` for the harness and `docs/test-cases.md` for the generated inventory.
3. **Green gate before every commit.** `lua tests/run.lua` (685 cases, 0 failed) and `luacheck .`
   (0 warnings / 0 errors). Regenerate `docs/test-cases.md` and update the README `[tests]` badge in
   the *same* change whenever the count moves.
4. **Flag deviations, never absorb them.** If a change would depart from the standard, stop and
   surface it — the user decides whether it is an accepted deviation (recorded in ARCHITECTURE ▸
   *Documented deviations*) or a change the standard itself should adopt upstream.
5. **In-client behaviour goes in `docs/smoke-tests.md`.** Frame rendering, taint, drag/resize and
   real capture cannot be proven headlessly.

Keep it compliant over time with the `wow-addon:` skills listed at the end of this file
(`review`, `standards-audit`, `sync-docs`, `bump-version`, …).

---

## Identity

- **Author:** add1kted2ka0s (Ka0s)
- **License:** MIT (always; no exceptions)
- **Substrate:** Ace3
- **Scope:** Retail only — single latest-Retail `## Interface:` line, currently `120007`
- **TOC `Title`:** `Ka0s Bank Ledger`
- **SavedVariables:** `BankLedgerDB` — **account-wide `global` only**; the `profile` namespace AceDB
  creates is deliberately unused (see *Documented deviations*)
- **Slash:** `/bl`, aliased `/bankledger`
- **Chat tag:** `NS.PREFIX` = `|cff00ffff[BL]|r`
- **Folder name:** `BankLedger`
- **Standard:** built to & references <https://github.com/tusharsaxena/WowAddonStandards>

## Layout

Every Ka0s addon uses one **modular** layout — `core/ defaults/ settings/ locales/ modules/` — no matter how small (layout). There is no flat variant: a three-file utility and a multi-feature suite share the same skeleton, so every repo reads identically and each file has one obvious home. A small addon simply has thin folders (a single `modules/` file, a one-row `settings/Schema.lua`), not a different structure.

---

## The tree

```
BankLedger/
  BankLedger.toc         -- single Interface line (120007)
  core/
    Compat.lua           -- LOAD FIRST: every deprecated/patch-varying API call
    Constants.lua        -- Store/Context/Direction/Kind enums, palettes, container-id groups
    Namespace.lua        -- NS.name, NS.version, NS.SCHEMA_VERSION, NS.PREFIX
    CoreSetup.lua        -- LibKa0s-Core seam: NS.Print/NS.SafeToString + NS.LIBKA0S_MISSING (the shared cause clause)
    DebugLogSetup.lua    -- LibKa0s-DebugLog seam: the console and NS.Debug, on the shared Ka0s edge, Core's close x
    State.lua            -- runtime-only state; never persisted
    Util.lua             -- player key, path split, date/money/byte format, wowhead URL
    BankLedger.lua       -- AceAddon registration; NS.bus; NS.NewBusTarget
    Database.lua         -- AceDB + migrations, ledger CRUD, Query/Export/Stats, prune
  defaults/
    Global.lua           -- the ONLY hardcoded defaults; no Profile.lua (documented deviation)
  locales/
    enUS.lua             -- canonical; NS.L metatable fallback
    PostLoad.lua         -- derived-key aliases (empty in v1.0.0)
  modules/
    Filters.lua          -- blacklist/whitelist id-sets  (loads BEFORE Ledger: the gate reads them)
    Ledger.lua           -- the capture engine: snapshot, diff, gate, build, record, event shell
    Browser.lua          -- the standalone window: skin, tabs, filter bar, footer, minimap launcher
    LedgerTable.lua      -- virtualized pooled History table; Column/PaintCell seams; /bl test data
    SessionWindow.lua    -- the live "Current Banking Session" window
    InsightsWidgets.lua  -- HOW charts are drawn: pooled primitives, palette, label maths
    Insights.lua         -- WHAT is drawn: 14 stat cards, 17 chart sections, Top Of The List
    Export.lua           -- ledger CSV, insights CSV, the export modal
  settings/
    Schema.lua           -- the schema table (single source) + NS.COMMANDS
    Slash.lua            -- LibKa0s-Slash seam: AceConsole registration, confirm dialogs, full reset
    OptionsSetup.lua     -- LibKa0s-Options seam: NS.Helpers IS the instance; the schema seams
    Panel.lua            -- what did not generalise: store grid, Storage, Filters page, landing body, Diagnose
  media/                 -- logos/, screenshots/, fonts/
  libs/                  -- vendored, committed (Ace3, LibStub, LibDBIcon, LibSharedMedia, LibKa0s)
  tests/                 -- run.lua, wow_mock.lua, test_*.lua (18 suites), _kit/ (vendored from LibKa0s)
  docs/                  -- agent-context.md, ARCHITECTURE.md, testing.md, smoke-tests.md,
    audits/<YYYY-MM-DD>/ --   test-cases.md (generated), pending/LEDGER.md
    reviews/<YYYY-MM-DD>/--   retained audit + code-review history (audit-review-history)
    superpowers/         --   specs/ and plans/ for feature work
  README.md  (root, full)   CLAUDE.md (root, stub)   LICENSE (root)
  .luacheckrc  .pkgmeta
```

**Load order is load-bearing in two places:** `core/Compat.lua` is first so every later file can
shim through it, and `modules/Filters.lua` precedes `modules/Ledger.lua` because the capture gate
reads the id-lists. `settings/` loads last — it depends on everything else being initialized.

---

## Reference snippets

These are Bank Ledger's actual shapes, not templates. Match them when adding to the addon.

### TOC

Fixed field order (toc-file-§1), then a blank line, then the file listing in commented sections (toc-file-§5). `BankLedger.toc` in full:

```
## Interface: 120007
## Title: Ka0s Bank Ledger
## Notes: A passbook of every item and gold movement between your bags and your banks.
## Author: add1kted2ka0s
## Version: 1.0.0
## IconTexture: Interface\Icons\inv_misc_bag_15
## SavedVariables: BankLedgerDB
## OptionalDeps: Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0
## DefaultState: enabled
## Category-enUS: Misc
## X-License: MIT
## X-Standard: https://github.com/tusharsaxena/WowAddonStandards
## X-Curse-Project-ID: 1629058

# Libraries (vendored in libs/ — load first)
libs\LibStub\LibStub.lua
libs\CallbackHandler-1.0\CallbackHandler-1.0.xml
libs\AceAddon-3.0\AceAddon-3.0.xml
libs\AceEvent-3.0\AceEvent-3.0.xml
libs\AceTimer-3.0\AceTimer-3.0.xml
libs\AceConsole-3.0\AceConsole-3.0.xml
libs\AceDB-3.0\AceDB-3.0.xml
libs\AceGUI-3.0\AceGUI-3.0.xml
libs\LibSharedMedia-3.0\lib.xml
libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
libs\LibDBIcon-1.0\LibDBIcon-1.0.lua
# LibKa0s last in the block: every module but Core resolves LibKa0s-Core-1.0 through LibStub before
# it registers, and Options resolves AceGUI-3.0 at panel-build time rather than at load.
libs\LibKa0s\LibKa0s.xml

# Locales
locales\enUS.lua
locales\PostLoad.lua

# Core (Compat loads first)
core\Compat.lua
core\Constants.lua
core\Namespace.lua
# The LibKa0s-Core seam. After Namespace (NS.PREFIX), and before every file that takes NS.Print as a
# load-time upvalue or reclaims it from NS.Util.print — see the header of core/CoreSetup.lua.
core\CoreSetup.lua
# The LibKa0s-DebugLog seam. After Constants (FONT_MONO) and after CoreSetup
# (NS.LIBKA0S_MISSING). Everything else it touches is reached through a closure, so it no
# longer has to sit after modules/Browser.lua the way modules/DebugLog.lua did.
core\DebugLogSetup.lua
core\State.lua
core\Util.lua
core\BankLedger.lua
core\Database.lua

# Defaults
defaults\Global.lua

# Modules (Filters before Ledger — the capture gate reads the lists)
modules\Filters.lua
modules\Ledger.lua
modules\Browser.lua
modules\LedgerTable.lua
modules\SessionWindow.lua
modules\InsightsWidgets.lua
modules\Insights.lua
modules\Export.lua

# Settings (last — depend on everything else being initialized)
settings\Schema.lua
settings\Slash.lua
# The LibKa0s-Options seam. After the schema and the write seam it reads, and BEFORE
# settings/Panel.lua, which captures the instance at file scope (options-ui-§1).
settings\OptionsSetup.lua
settings\Panel.lua
```

`X-Wago-ID` / `X-WoWI-ID` are absent deliberately — the addon is not listed on those platforms, and the standard only requires the id of a platform it is actually published to.

The `## Interface:` is a **single** latest-Retail number (Retail only, toc-file-§3); bump it each patch with `wow-addon:bump-interface`, and keep the README `[wow]` badge in lockstep. Field order and section comments are fixed (toc-file-§1, toc-file-§5).

### `core/BankLedger.lua` (entry)

```lua
local addonName, NS = ...
local AceAddon = LibStub("AceAddon-3.0")
local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon
NS.bus = addon   -- closed message bus: SendMessage / RegisterMessage (architecture-§4)

function addon:OnInitialize()
  NS:InitDB()            -- Database.lua
  NS:RunMigrations()     -- Database.lua
  NS.Schema:Register()   -- EAGER settings-category registration (options-ui-§1)
end

function addon:OnEnable()
  NS.Ledger:Enable()     -- the capture engine binds its events here
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")   -- deferred one-shot retention prune
end
```

`NS.bus` is the addon table itself. Consumers **must** register on their own `NS.NewBusTarget()`
rather than on the shared bus-as-self — CallbackHandler keys callbacks by `(message, target)`, so
two consumers sharing a target silently clobber each other.

### `core/Compat.lua`

Retail only: shims cross-patch API differences, **not** game flavors. This is the single file
allowed to call a deprecated or patch-varying API — 20 exports in four groups:

| Group | Exports |
|---|---|
| Metadata / player | `GetAddOnMetadata`, `GetPlayerMapID`, `GetZone`, `GetGuildName` |
| Money | `GetMoney` (the purse), `GetStoreMoney` (a store's **own** balance) |
| Containers | `GetContainerNumSlots`, `GetContainerSlot`, `GetGuildBankSlot`, `GetNumGuildBankTabs`, `QueryGuildBankTab`, `GetCurrentGuildBankTab`, `IsGuildBankVisible`, `GuildBankTabSize` |
| Items | `ItemIDFromLink`, `QualityFromLink`, `QualityLabel`, `GetItemDetails`, `ItemNameQuality`, `LoadItem` |

The shape every reader follows — probe the modern API, fall back, and **return `nil` rather than a
wrong answer**:

```lua
-- A store's own coin balance, or nil when it cannot be read honestly.
function Compat.GetStoreMoney(store)
  if store == C.Store.GUILD_BANK then
    -- GetGuildBankMoney() returns 0 (not nil) when the frame is closed, so gate on visibility:
    -- passing that 0 through would read as a balance falling to zero and fabricate a withdrawal.
    if not Compat.IsGuildBankVisible() then return nil end
    return GetGuildBankMoney and GetGuildBankMoney() or nil
  elseif store == C.Store.WARBAND_BANK then
    -- Not frame-bound — reads the same at a bank and at a guild bank.
    if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
      return C_Bank.FetchDepositedMoney(Enum.BankType.Account)
    end
  end
  return nil   -- the character bank has no coin slot
end
```

**`nil` is a real answer here.** A store whose balance cannot be read on both snapshots contributes
no money movement at all, which is what keeps a bank-tab purchase from being recorded as a warband
deposit. Never substitute `0` for "cannot read".

### `locales/enUS.lua`

```lua
local addonName, NS = ...   -- luacheck: ignore addonName

-- Canonical locale. The metatable fallback returns the key itself, so English strings work
-- untranslated and a missing key never errors (localization-§1).
NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })

-- v1.0.0 ships English-only: no user-facing string routes through NS.L yet — every label, tooltip
-- and message is hardcoded English (an accepted scope decision, not an oversight). The seam is kept
-- so a later localization pass can wrap strings without touching call sites. There is deliberately
-- no `local L` alias until the first string is wrapped, so this file stays luacheck-clean.
-- Non-enUS files gate with `if GetLocale() ~= "<locale>" then return end` at the top.
```

Input side (localization-§4): match game data on stable IDs/tokens — `itemID`, `classFile`
(`"PRIEST"`), `Enum.*` — **never** on a localized name string. Bank Ledger stores `classFile` on
every entry for exactly this reason.

### `defaults/Global.lua` + `core/Database.lua`

Bank Ledger is **account-wide by design** — you deposit on one character and withdraw on another —
so every default lives under `global` and there is no `defaults/Profile.lua`. That is a documented
deviation from `savedvariables-§2`; see ARCHITECTURE ▸ *Documented deviations*.

```lua
-- defaults/Global.lua — the ONLY place a default value is hardcoded.
NS.defaults.global = {
  schemaVersion = NS.SCHEMA_VERSION,   -- one source for the shipped default AND the migration target
  ledger        = {},                  -- array of movement entries, oldest first
  blacklist     = {},                  -- item-id filter lists: storage carve-outs, mutated via
  whitelist     = {},                  --   NS.Filters, never through Schema:Set
  -- savedView is deliberately ABSENT: "no key" is what "nothing saved" means, so an empty table
  -- stays available to mean a deliberate save of an all-cleared view.
  settings = {
    enabled = true, trackItems = true, trackMoney = true,
    qualityThreshold = 0, excludedStores = {}, retentionDays = 30,
    windowScale = 1.0, window = {},          -- geometry: a standalone-windows carve-out
    showSessionWindow = true, sessionWindow = {},
  },
  minimap = { hide = false },          -- LibDBIcon state
  -- The debug LOGGING flag is NOT here: session-only (NS.State.debug), off at login, never in SV
  -- (debug-logging-§5).
}
```

```lua
function NS:InitDB()
  NS.db = LibStub("AceDB-3.0"):New("BankLedgerDB", NS.defaults, true)
end
```

`NS:RunMigrations` is the idempotent seam (savedvariables-§1), and it is no longer a stub: the
v1 → v2 step walks `db.global.ledger` once, clears the retired `vendorPrice` field from every entry,
bumps `schemaVersion` to 2 and emits the standard `[Migrate]` debug line via `NS.MigrationSummary`.
A v2 database is skipped entirely. **`NS.SCHEMA_VERSION` (in `core/Namespace.lua`) is the single
source** for both the shipped default and the runner's target, so the two cannot drift apart.

### `settings/Schema.lua` + `settings/Slash.lua` + `settings/Panel.lua`

The schema is the **single source**: it drives the panel widgets, the slash `get`/`set`/`list`/
`reset` dispatch and the defaults reset. Rows render in schema order, so the table is also the
panel's top-to-bottom layout. Ten rows in two groups:

| Path | Type | Default | Group |
|---|---|---|---|
| `settings.enabled` | bool | `true` | Master Controls |
| `minimap.hide` | bool | `false` | Master Controls |
| `settings.showSessionWindow` | bool | `true` | Master Controls |
| `state.debugConsole` | bool (**session-only**) | `false` | Master Controls |
| `settings.windowScale` | number 0.6–1.6 | `1.0` | Master Controls |
| `settings.qualityThreshold` | number | `0` | Capture |
| `settings.retentionDays` | number | `30` | Capture |
| `settings.trackItems` | bool | `true` | Capture |
| `settings.trackMoney` | bool | `true` | Capture |
| `settings.excludedStores` | table (muted set) | `{}` | Capture |

```lua
-- settings/Schema.lua — a row. Every write goes through NS.Schema:Set, which is the single seam.
{ path = "settings.windowScale", default = 1.0, type = "number", min = 0.6, max = 1.6,
  -- `step` is declared, never defaulted: LibKa0s-Options-1.0's makeSlider assumes 1, which would
  -- snap a 0.6–1.6 slider to its two endpoints and nothing else.
  step = 0.05,
  group = "Master Controls", label = "Window scale", widget = "Slider",
  onChange = function()
    -- Announce on the bus rather than reaching into the windows: BOTH the ledger window and the
    -- session window rescale off this one message.
    if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "windowScale") end
  end },
```

`NS.COMMANDS` (also in `Schema.lua`) is the one place the slash surface is declared — `/bl help`,
the settings landing page and the README's command table are all generated from it, so they cannot
drift. Fifteen verbs: `show`, `hide`, `toggle`, `config`, `version`, `get`, `set`, `list`, `reset`,
`resetall`, `session`, `test`, `purge`, `debug`, `help`. `debug` additionally takes
`on` / `off` / `scan` / `panel`.

```lua
-- settings/Slash.lua — AceConsole registration stays the host's; the dispatch loop, the help
-- renderer and the list/get/set/reset CLI are all LibKa0s-Slash-1.0's.
function Sl:Register()
  NS.addon:RegisterChatCommand("bl", function(input) Sl:OnSlash(input) end)
  NS.addon:RegisterChatCommand("bankledger", function(input) Sl:OnSlash(input) end)
end

local cli = lib:New({ slash = "/bl", slashAliases = { "/bankledger" }, commands = NS.COMMANDS, … })
function Sl:OnSlash(input) return cli:OnSlash(input) end

-- The library's loop, reproduced at its smallest on the degraded path. NS.COMMANDS rows are
-- POSITIONAL — { name, description, handler } — never keyed.
for _, cmd in ipairs(NS.COMMANDS) do
  if cmd[1] == verb then return cmd[3](rest or "") end
end
```

Every schema read/write echo goes through **two shared formatters** — `lib.FormatValue(row, v)` for
the value and `lib.FormatKV(path, valueStr)` for the coloured `key = value` line — so `list`, `get`,
`set` and `reset` can never render differently. Both are **LibKa0s-Slash-1.0's**; the host's own
`Sl.FormatSchemaValue` and `Sl.FormatKV` are deleted. What stays here is the `format` hook for the
set-typed `excludedStores` row, which the library has no type for. All four read the **stored** value
back after a write, so the echo reflects clamping.

`settings/Panel.lua` registers the Blizzard settings **category eagerly** at load (options-ui-§1) and
builds each panel **body lazily** on first `OnShow`, as it does the header Defaults button. The
`setDefaultsAction(panel, fn)` helper parks `panel.defaultsOnClick`, and `LibKa0s-Options-1.0`'s
`CreatePanel` stamps an `OnDefault` that **forwards** to it (Options minor 5) — so the framework's
footer control and the addon's own header button run one implementation and cannot diverge.

**Chat tag & CLI output (slash-commands-§4–§5).** `NS.PREFIX` is the mandatory **cyan** bracketed tag — `|cff00ffff[XY]|r` (initials `XY`; the cyan `00ffff` is required, not just an example) — exposed once and prepended to every chat line. `list`/`get`/`set` follow the canonical output shape in slash-commands-§5: `list` prints `Available settings` then `  [page]` group headers then `    path = value` rows; `get`/`set` print the single-line `path = value` (echoing the *stored* value after a set). Output uses the **mandated colour scheme** — header green (`33ff99`), `[page]` group headers azure (`3399ff`), keys/paths gold (`ffff00`), values white (`ffffff`), the ` = ` separator default, and **no trailing colon** on any line. Values are **type-aware and unit-annotated** through one shared formatter — `<n> px`, `1.00x`, `true`/`false`, `{r, g, b, a}` — and the coloured `key = value` line comes from one shared helper, so `list` and `get`/`set` never diverge.

### Debug console (debug-logging)

Debug output routes to a **dedicated on-screen console styled like the main window**, not chat. Full reference: `STANDARDS.md debug-logging`. Minimal sink — note the **tag is the first argument**:

```lua
function NS.Debug(tag, fmt, ...)
  if not (NS.State and NS.State.debug) then return end   -- gated; zero-alloc when off
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
  NS.DebugLog:Add(tag, msg)   -- append to the console, NOT print() to chat
end
-- call site: NS.Debug("Loot", "%s x%d", name, qty)
```

**Secret-safe (events-frames-taint-§8) — mandatory if you ever log a combat value.** In combat, retail returns absorb/health/threat totals as opaque *secret* values that survive `tostring()` **and `..`** but raise in `table.concat`/`string.format`. An unguarded secret in a debug line crashes — and on a repeating ticker it freezes the feature until `/reload`. The `NS.PREFIX` printer (slash-commands-§4) and this sink MUST route args through one secret-safe stringifier whose detector probes `table.concat`, **not** `..`:

```lua
local function probeConcat(v) return table.concat({ v }) end
function NS.IsConcatSafe(v) return (pcall(probeConcat, v)) end     -- `..` would pass secrets through
function NS.SafeToString(v)
  if v == nil then return "nil" end
  if type(v) == "boolean" then return tostring(v) end
  if NS.IsConcatSafe(v) then return tostring(v) end
  return "<secret>"
end
-- For display, hand the raw secret to AbbreviateNumbers() / widget setters — never tonumber() or `<`.
```

The console: a `BackdropTemplate` frame (`BankLedgerDebugWindow`) on `DIALOG` strata, **default size `700×344`**, draggable title bar, a `ScrollingMessageFrame` (`SetMaxLines(500)`) rendered in a **shipped monospace font** (`media/fonts/`, the Ka0s reference font is JetBrains Mono Regular OFL, LSM-registered — a sanctioned styling exception, debug-logging-§2) at **10pt**. Lines follow `<HH:MM:SS> | [<Tag>] <content>` — timestamp coloured `6f8faf`, `[tag]` `c9a66b`, separator/content white; the plain **Copy buffer** mirrors the same line code-free (two pure formatters, `FormatPlain`/`FormatColored`). **Clear** + **Copy** (copy = read-through multiline `EditBox`, same font), registered in `UISpecialFrames`, drawn on the **shared Ka0s window edge** — `Core.SKIN` carries it and this addon's `SKIN` agrees with it value for value — and still tracking the addon's `ApplySkin` seam through the descriptor, while the close control on these two library-drawn windows is the **library's** thin 18×18 × rather than the ledger window's 24×24 class-coloured glyph (standalone-windows-§2). The log **MUST** also carry a **right-edge scrollbar** and a **bottom `N / MAX lines` counter** (debug-logging-§11): a thin vertical `Slider` synced both ways to the log via the Lua `ScrollingMessageFrameMixin` API — `GetMaxScrollRange()` / `GetScrollOffset()` / `SetScrollOffset()` (offset `0` = newest/bottom; the old C getters `GetNumLinesDisplayed()`/`GetCurrentScroll()` are **`nil`** and crash), always shown but inert when it fits (options-ui-§10) — and a status-bar counter updated on every append, reset on Clear.

**Enabled-state is session-only and window-independent** (debug-logging-§5): `NS.State.debug`, default off, **never in SV**, reset every `/reload`. `/bl debug` toggles the *window* only; `/bl debug on|off` set the flag via a single `DebugLog:SetEnabled(on)` seam; a left-aligned title-bar toggle shows **`Debug: ON`** (green) / **`Debug: OFF`** (red) and flips the same flag. Each state change prints a `NS.PREFIX`-tagged chat ack whose state word is **colour-coded** — `ON` green (`40ff40`) / `OFF` red (`ff4040`) — mirroring the toggle. The `SetEnabled` seam **also appends a console line at both transitions** — `[Debug] logging enabled` / `[Debug] logging disabled` — via the raw `DebugLog:Add` (the disable line must land after the flag flips off, so it can't go through the gated `NS.Debug` sink), and on **enable** additionally emits a one-line **`[Init]` session summary** (addon + version, schema version, active profile — e.g. `[Init] BankLedger v1.0.0, schema v2, account-wide`) right after the enable bracket; it rides the enable seam, **not** login, because the session-only flag is off at login and a load-time summary would never render. Addons with no window MAY fall back to `NS.PREFIX`-tagged chat.

### Tests (`tests/`, testing)

Headless plain-Lua-5.1 harness. Run `lua tests/run.lua` from the repo root.

```
tests/
  run.lua            -- the load list, the lifecycle kick and the suite list; the framework is _kit/framework.lua's
  _kit/              -- VENDORED from LibKa0s testkit/: framework.lua (registry+assertions+--list), loader.lua (setfenv, tocFiles), mock_base.lua
  wow_mock.lua       -- extender over _kit/mock_base.lua: geometry-modelling frame stub, container/guild-bank/item model, Ace fakes
  test_<module>.lua  -- 18 suites, 685 cases (test_harness.lua guards the suite list and TOC order)
```

`run.lua` builds the environment once by loading every source **in TOC order**, then calls
`NS:InitDB()`, `NS.Schema:Register()` and `NS.Ledger:Enable()` to mirror the in-game
`OnInitialize` / `OnEnable` lifecycle.

Suite shape:

```lua
local T = _G.BL_TEST           -- run.lua exposes { NS, mocks, test, assertEqual, assertTrue, assertFalse }
local NS = T.NS
local test, assertEqual = T.test, T.assertEqual
test("Schema: every path resolves against defaults", function()
  assertEqual(NS.Schema:Validate(), 0)   -- 0 unresolved paths
end)
```

Three pieces of mock **fidelity** are load-bearing and must not be simplified away: the AceAddon mock
stamps AceConsole's colliding `:Print` mixin (so the real printer-reclaim path is exercised); the
message bus keys callbacks by `(message, target)` and fans out to every target (so a test can catch
two receivers clobbering each other); and the `Settings.RegisterCanvasLayout(Sub)category` fakes keep
every frame handed to them in `mocks.__settingsPanels` (so `test_panel.lua` can assert the
`OnCommit`/`OnDefault`/`OnRefresh` contract on what the framework actually received).

Regenerate the inventory and update the README badge in the same change whenever the count moves:
`lua tests/run.lua --list > docs/test-cases.md`.

Local toolchain:

```sh
sudo apt-get update && sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck
```

### Message bus

Four messages, one sender each. Full payload/consumer table in `docs/ARCHITECTURE.md` ▸ *Message bus*.

| Message | Sender | Payload |
|---|---|---|
| `Ka0s_BankLedger_EntryAdded` | `Database:Add` | `entry, index` |
| `Ka0s_BankLedger_LedgerChanged` | `Database` (delete / purge / prune / `FireLedgerChanged`) | — |
| `Ka0s_BankLedger_SettingsChanged` | `Schema` row `onChange` handlers | a short reason string |
| `Ka0s_BankLedger_SessionChanged` | `Ledger` (open / close / guild self-disarm) | `active`, `context` |

```lua
-- Producer (pick exactly one; send on any embed — SendMessage fans out to all receivers)
NS.bus:SendMessage("Ka0s_BankLedger_EntryAdded", entry, index)

-- Consumer — MUST register on its OWN AceEvent target, never the shared bus-as-self:
-- CallbackHandler keys callbacks by (message, target), so two receivers sharing one object
-- clobber each other (last registrant wins, silently). See architecture-§4.
NS.Browser.__ev = NS.NewBusTarget()   -- AceEvent:Embed({}); or an AceAddon module `self`
NS.Browser.__ev:RegisterMessage("Ka0s_BankLedger_EntryAdded", function() B:ScheduleLedgerRefresh() end)
```

`NS.Filters` deliberately does **not** become a fifth sender: it calls
`Database:FireLedgerChanged()` so `Database` stays the sole emitter of that message.

### `.luacheckrc`

```lua
std = "lua51"
max_line_length = false
codes = true
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }
ignore = {
  "212/self",   -- unused argument self
  "212/event",  -- unused argument event
}
read_globals = {
  -- Core Lua/WoW globals, then the item/container/bank APIs Compat wraps, the store-held coin
  -- balances that corroborate a money movement, and the UI globals the window/console/panel use.
  "_G", "LibStub", "CreateFrame", "GetTime", "time", "date", "unpack",
  -- …see the file for the full list; add a name here rather than reaching for a luacheck inline.
  "C_Item", "C_Container", "C_Map", "C_AddOns", "Enum",
  "GetGuildBankMoney", "C_Bank",
}
globals = {
  "BankLedgerDB",      -- the SavedVariables write target, declared in the TOC
  -- Registering a confirm dialog means writing a new key into Blizzard's table; that is the only
  -- API FrameXML offers for it, and every addon that ships a StaticPopup does the same.
  "StaticPopupDialogs",
}
```

### `.pkgmeta`

```yaml
package-as: BankLedger

# Libraries are vendored in libs/ and committed to git — NOT fetched as externals.

ignore:
  - .luacheckrc
  - .gitignore
  - docs        # holds docs/audits/ and docs/reviews/ too — all dev-only
  - tests
  - _dev
  - "*.bak"
  - media/screenshots   # project-page art, served from the CurseForge CDN — never downloaded by a player
  # Only the .tga logo is loadable at runtime; WoW cannot read .png or .jpg at all. The master .png
  # and the .jpg render exist for the project page and for regenerating the .tga, so shipping them
  # would add ~3MB to every download for files the client physically cannot use.
  - media/logos/*.png
  - media/logos/*.jpg
```

Libraries are **vendored under `libs/` and committed** (`STANDARDS.md library-stack-§3`). Copy the folder-per-lib set you actually `LibStub()` from an existing Ka0s addon's `libs/` so versions stay consistent across the suite, and list them **first** in the TOC (`.xml` where the lib ships one, `.lua` otherwise). Pull libs the suite doesn't yet vendor (LibDataBroker-1.1, LibDBIcon-1.0, …) from a current retail install or the upstream release.

### Docs — root `CLAUDE.md` stub + `docs/agent-context.md`

Root ships a **full** `README.md`, a **stub** `CLAUDE.md`, and `LICENSE`; everything else lives under `docs/` (documentation). The stub is short and **MUST** carry a `## Standards compliance (read first)` section; the contents of *this* pack become `docs/agent-context.md`, whose `## Hard rules` **MUST** open with the conform-to-the-standard rule pointing back to the stub (documentation-§6).

```markdown
<!-- root CLAUDE.md (STUB — never the full brief) -->
# CLAUDE.md — Ka0s Bank Ledger

**Ka0s WoW addon.** Adheres to the **Ka0s WoW Addon Standard** —
https://github.com/tusharsaxena/WowAddonStandards

## Standards compliance (read first)

This repo is built to the **Ka0s WoW Addon Standard** (URL above). All development here — features,
refactors, doc changes — MUST conform to it. The standard is the source of truth for layout, TOC
shape, the Ace substrate, schema-driven settings, slash/prefix conventions, locales, Compat,
tests/lint, and doc structure.

**If a change would deviate from the standard, STOP and flag the deviation explicitly.** Do not
silently deviate and do not silently "fix" to match. Surface it and let the user decide which of
two things it is:

1. **An accepted deviation** — this addon intentionally differs; record it as a documented
   deviation (e.g. in the TOC/README/`docs/` and in the audit bundle), with the reason.
2. **A change to the standard itself** — the standard's definition should evolve; the update
   belongs upstream in the WowAddonStandards repo, after which this addon conforms to the new rule.

When in doubt, treat standard conformance as a hard requirement and ask.

Start here, then read the docs:

- **`docs/agent-context.md`** — the full agent brief (stack, layout, hard rules, invariants,
  the `NS` bus, working environment, response style).
- **`docs/ARCHITECTURE.md`** — module map, settings schema, message bus, slash surface, event
  wiring, taint notes, known limitations.
- Topic detail in `docs/` as needed (`schema.md`, `settings-panel.md`, `smoke-tests.md`, …).

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0). Never auto-stage/commit/
push and never bump the version without an explicit instruction.
```

```markdown
<!-- docs/agent-context.md — the FIRST bullet of ## Hard rules -->
- **Conform to the Ka0s WoW Addon Standard** (https://github.com/tusharsaxena/WowAddonStandards).
  It is the source of truth for layout, TOC, the Ace substrate, schema-driven settings, slash/prefix
  conventions, locales, Compat, tests/lint, and doc structure. **If a change would deviate, STOP and
  flag it** — never silently deviate or silently conform. The user decides whether it is (a) an
  accepted, documented deviation for this addon, or (b) a change to the standard itself (updated
  upstream in the standards repo, then this addon follows the new rule). See the root
  [CLAUDE.md](../CLAUDE.md) "Standards compliance" section.
```

---

## Hard rules cheat sheet (memorize)

- **Conform to the Ka0s WoW Addon Standard** (https://github.com/tusharsaxena/WowAddonStandards).
  It is the source of truth for layout, TOC, the Ace substrate, schema-driven settings,
  slash/prefix conventions, locales, Compat, tests/lint, and doc structure. **If a change would
  deviate, STOP and flag it** — never silently deviate or silently conform. The user decides
  whether it is (a) an accepted, documented deviation for this addon, or (b) a change to the
  standard itself (updated upstream in the standards repo, then this addon follows the new rule).
  See the root [CLAUDE.md](../CLAUDE.md) "Standards compliance" section.

1. Every file starts with `local addonName, NS = ...`. No `_G[addonName] = {}`.
2. SavedVariables: `BankLedgerDB`, single global, with `schemaVersion` (currently **2**).
3. License: MIT.
4. Folder casing: `BankLedger/` PascalCase, all subfolders lowercase (`libs/` not `Libs/`).
5. TOC: single latest-Retail `## Interface:` (Retail only), plus `X-Standard`, and `X-Curse-Project-ID` (mandatory once published on CurseForge). `X-Wago-ID` / `X-WoWI-ID` are optional — include each only if the addon is actually listed on that platform.
6. Slash: AceConsole `:RegisterChatCommand`. Never raw `SLASH_*`.
7. Locale: metatable fallback `__index = function(_,k) return k end`. Never AceLocale strict.
8. Options UI: Blizzard `Settings.RegisterCanvasLayoutCategory` + raw AceGUI body. Register the **category eagerly at load** (always visible); build the **body lazily** on first `OnShow` — and build the header's **Defaults button lazily too**, in that same first `OnShow`, never at registration time (options-ui-§5). AceGUI is shared and UI skins hook `RegisterAsWidget`, so a widget created during load keeps Blizzard's stock red `UI-Panel-Button-Up` art forever while later-created ones come out skinned — building it at registration makes the button's look a race against addon load order. Never AceConfigDialog for content; never defer registration to first `/config`.
9. Schema-as-single-source: one table drives panel widgets + slash + defaults reset. One write seam.
10. Closed message bus: modules talk via `Ka0s_BankLedger_<Event>` messages, one sender each (four of them). No cross-module table reach.
11. All deprecated-API calls live in `Compat.lua`. Modules call `NS.Compat.X`. No `WOW_PROJECT_ID` flavor branching (Retail only).
12. Combat lockdown: gate `InCombatLockdown()` (secure writes — settings setters, secure-frame attributes) and defer those with `PLAYER_REGEN_ENABLED`. **Exception — options-panel open (options-ui-§2): refuse under lockdown, do not defer.** Print a grey `NS.PREFIX` notice ("cannot open settings during combat — Blizzard's category-switch is protected") and return; **never** `Settings.OpenToCategory` under lockdown, and **never** auto-open on `PLAYER_REGEN_ENABLED`. For combat-reactive *display/logic* use `UnitAffectingCombat(unit)` — **not** `InCombatLockdown()` (which is player-only and can raise *action blocked* if it gates a secure call at the combat boundary).
13. Per-frame loops: cache db values into module locals, refresh via `M:RefreshUpvalues()` on settings change.
14. ≥10 dynamic frames: use object pool (Acquire/Release/HideAll).
15. File LOC cap: ~1500. Peel when exceeded.
16. Vendor everything: commit all libs in `libs/`, loaded first in the TOC. Never use `.pkgmeta` `externals:` for libraries.
17. Debug: on-screen **console** styled like the main window (debug-logging), not chat, if the addon has a window. Monospace font (10pt) + tagged colour-coded lines via `NS.Debug(tag, …)`; zero-alloc when off. Enabled-state is **session-only** (`NS.State.debug`, default off, reset every `/reload`; never in SV), decoupled from window visibility.
18. Preview/test mode (preview-mode): addons with a positionable display SHOULD show placeholder data while unlocked and/or via a test verb — here `/bl test` for the History table and `/bl session` for the session window.
19. Tests: ship a headless `tests/` harness. TDD. `lua tests/run.lua` green **and** `luacheck .` clean **before every commit**.
19a. Test-case inventory & badge (testing-§5): ship a **generated** `docs/test-cases.md` (full per-suite case enumeration + totals, produced by a `--list` mode of the runner — `lua tests/run.lua --list > docs/test-cases.md`, never hand-authored; it is the authoritative pass count) and a **static** X/Y `[tests]` README badge. Regenerate the doc and update the badge **in the same change** whenever the suite changes (a case added/removed/renamed or the count moved). No CI.
20. Docs: root = full `README.md` + **stub** `CLAUDE.md` + `LICENSE`; everything else under `docs/`. Canonical `docs/` quartet (all addons): **`agent-context.md`** (full agent brief), `ARCHITECTURE.md`, `testing.md` (verify-how-to), `smoke-tests.md`; plus the generated `test-cases.md` (testing-§5) and topic-detail docs as needed. Media in typed `media/` subfolders. No drift; sync before every release. (documentation-§3)
20a. `README.md` is a **player-facing** document — written for the person who installed the addon (what it does, how to use it, how to fix common problems), in plain language, free of internal jargon and machine-generated tells; contributor material (test harness, lint, build, internals) stays out of it, under `docs/`. It follows the **canonical section order** (documentation-§1): title → badges (`[wow]` → version → license → standard → `[tests]`, that exact order and these exact templates: `![WoW](https://img.shields.io/badge/WoW-<Expansion>_<X.Y.Z>-purple)`, `![CurseForge Version](https://img.shields.io/curseforge/v/<projectId>)`, `![License](https://img.shields.io/badge/License-MIT-orange)`, `[![Standard](https://img.shields.io/badge/Ka0s-WoW%20Addon%20Standard-yellow)](https://github.com/tusharsaxena/WowAddonStandards)`, `![Tests](https://img.shields.io/badge/Tests-<X>%2F<Y>_passing-green)`; the `[wow]` and `[tests]` badges MUST be updated in lockstep with the TOC `## Interface:` and the test inventory respectively) → logo → description → **What's new in `<X.Y.Z>`** (top user-facing highlights of the current release, mirroring the newest Version History row; rolled forward on every version bump) → Screenshots → Usage (Slash commands + Settings panel tables) → How it works → FAQ → Troubleshooting → **Issues and feature requests** (→ GitHub issues) → Version History (there is **no** `## Testing` section — verify-how-to lives in `docs/`; the README keeps only the `[tests]` badge). TOC follows the fixed field order + `#`-section file listing (toc-file-§1/toc-file-§5).
20b. **No `TODO.md`** in a released addon — backlog lives in **GitHub issues** (documentation-§4). Only an unreleased, in-development addon may keep a `docs/TODO.md`, deleted before first release.
20c. **Standards reference in project memory & context** (documentation-§6): the reference to the standard MUST appear in **four** places — TOC `X-Standard`, README standard badge, the root `CLAUDE.md` `## Standards compliance (read first)` section, and `docs/agent-context.md`'s first `## Hard rules` bullet (pointing back to the `CLAUDE.md` section). STOP and flag any change that would deviate; the user classifies it as an accepted deviation (recorded here) or a change to the standard itself (made upstream, then adopted).
21. Audits & reviews: archive every audit under `docs/audits/<YYYY-MM-DD>/` and every code review under `docs/reviews/<YYYY-MM-DD>/`, each a 5-artifact bundle (audit-review-history). Kept, not deleted.
22. Versioning: semver. Bump TOC, code constants, README. `wow-addon:bump-version` automates this. Bump `## Interface:` + README `[wow]` badge each patch.
23. Git: trunk-based. Commit to the default branch on a **green** unit of work; no feature branches unless the human asks. Never push unless asked.
24. Standalone main window (data browser/log/tracker): non-secure `CreateFrame` (no combat gate), `UISpecialFrames` (ESC), persist pos/size in SV, scale setting, lazy tabs, one `SKIN` + `ApplySkin` seam, pooled rows. See `STANDARDS.md standalone-windows`.

## Forbidden patterns

- `_G[addonName] = {}` (use private NS).
- AceLocale strict mode.
- Hand-rolled options framework (use Settings + AceGUI).
- AceConfigDialog for non-Profiles content.
- Raw `SLASH_*` registration.
- `if cmd == "x" then elseif ...` slash dispatchers.
- `.pkgmeta` `externals:` for libraries (Ka0s vendors and commits all libs).
- Forking Ace libs.
- Multi-flavor / Classic support: comma `Interface` lists, per-flavor TOCs, `_Classic` data splits, `enable-toc-creation` fan-out (Retail only, single Interface line).
- `if WOW_PROJECT_ID ==` game-flavor branching (Retail only; Retail-patch checks go in Compat).
- Direct calls to deprecated APIs (route through Compat).
- `:Hide()` on Blizzard frames you replace (reparent to hidden parent).
- Replacing `_G.AddMessage`.
- Hard `## Dependencies:` (use OptionalDeps + soft fallback).
- Hard-depending on an addon suite or standalone addon (ElvUI/EllesmereUI/DBM/WeakAuras/…), or reading its media/API/frames/SavedVariables — the addon is fully self-contained and works identically standalone; suite integration is optional, presence-guarded (`C_AddOns.IsAddOnLoaded`), `OptionalDeps`-listed, and degrades gracefully (library-stack-§6). Vendored **libraries** are unaffected — a library is not a suite.
- `X-License: All Rights Reserved`.
- Files >1500 LOC.
- Multiple senders per bus message.
- Debug output to the chat frame when the addon has a main window (use the on-screen console).
- Deferring settings-**category** registration until first `/config`/panel-open (register eagerly at load).
- Cross-module direct table access.
- User-supplied Lua execution.
- Committing with red `lua tests/run.lua` or non-clean `luacheck .`; a logic change with no covering test.
- Loose files directly in `media/` (use typed subfolders).
- Full agent brief in the root `CLAUDE.md` (root is a stub; brief lives in `docs/`).
- `TODO.md` in a **released** addon (track the backlog in GitHub issues; allowed only in an unreleased, in-development addon, deleted before first release).
- Non-canonical `README.md` section order, or a TOC departing from the required field order / file-listing structure (documentation-§1, toc-file-§1/toc-file-§5).
- Missing the standards reference in project memory & context: no `## Standards compliance (read first)` section in `CLAUDE.md`, or `docs/agent-context.md`'s `## Hard rules` not opening with the conform-to-the-standard rule pointing back to it (documentation-§6).
- Creating a feature branch without an explicit request (work trunk-based).

---

## Definition of done — the invariants to keep

Bank Ledger met all of these at v1.0.0. They are not a to-do list; they are what a change **must not
break**. Re-check any line a change touches.

- [x] TOC has all required fields incl. single latest-Retail `## Interface:` (`120007`), `X-Standard`, and `X-Curse-Project-ID` (`1629058`). `X-Wago-ID` / `X-WoWI-ID` are absent — the addon is not listed there.
- [x] `.pkgmeta` present with **no** `externals:` block; all libs vendored and committed under `libs/`.
- [x] `.luacheckrc` present; `luacheck .` reports **0 warnings / 0 errors**.
- [x] `tests/` harness present; `lua tests/run.lua` is **green** (685/685); behavior is covered test-first (testing).
- [x] Generated `docs/test-cases.md` inventory present and in sync (`lua tests/run.lua --list`); README carries a static X/Y `[tests]` badge (testing-§5).
- [x] `core/Compat.lua` owns every deprecated/patch-varying call; no `WOW_PROJECT_ID` flavor branching.
- [x] `locales/enUS.lua` exists with the metatable fallback.
- [x] `core/Database.lua` has `RunMigrations()` — a real v1 → v2 step, idempotent.
- [x] `settings/Schema.lua` exposes the Schema (10 rows), the single `Schema:Set` write seam, and slash dispatch from `NS.COMMANDS`.
- [x] AceConsole `:RegisterChatCommand` registered for `/bl` and `/bankledger`.
- [x] Options panel uses `Settings.RegisterCanvasLayoutCategory`, **category registered eagerly at load** (entry always visible), **body built lazily** on first `OnShow`.
- [x] The header **Defaults button** is an AceGUI `Button` **created in the first `OnShow`** (not at registration), with its callback parked on the panel (`panel.defaultsOnClick`) and wired by the builder (options-ui-§5, anti-pattern #42). `setDefaultsAction` parks that closure and `LibKa0s-Options-1.0`'s `CreatePanel` stamps an `OnDefault` that forwards to it, so the two can never diverge.
- [x] Combat-lockdown: options-panel open **refuses** under lockdown (grey notice, no defer — options-ui-§2). The addon has no secure writes to defer.
- [x] Debug **console** (debug-logging) — on-screen, styled like the main window; monospace font (10pt) + tagged colour-coded lines `<ts> | [<Tag>] <content>`; `/bl debug` toggles the window, `/bl debug on|off` set logging (colour-coded `ON` green / `OFF` red chat ack); enabled-state **session-only** (never in SV), decoupled from window visibility; title-bar `Debug: ON/OFF` toggle; on enable emits an `[Init]` session summary. Plus two structured dump verbs, `/bl debug scan` and `/bl debug panel`.
- [x] Test mode (preview-mode) — `/bl test` drives synthetic data through the real render path, read-only: Delete, Blacklist and Whitelist are inert while it is on.
- [x] Media in typed `media/` subfolders (`logos/`, `screenshots/`, `fonts/`).
- [x] Root = full `README.md` (with `[wow]` badge + standard link) + **stub** `CLAUDE.md` + `LICENSE`; canonical `docs/` quartet present (`agent-context.md`, `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`) plus generated `test-cases.md`.
- [x] **Standards reference in memory & context (documentation-§6)** — all four present: TOC `X-Standard`, README standard badge, `CLAUDE.md` `## Standards compliance (read first)` section, and this file's first `## Hard rules` bullet pointing back to it.
- [x] `README.md` is player-facing and plain-language (no contributor material, no `## Testing` section) and follows the canonical section order (documentation-§1), including `## What's new in 1.0.0` above the screenshots, **Usage** (Slash-commands + Settings-panel tables), **Issues and feature requests** (→ GitHub issues), and **Version History**.
- [x] TOC follows the fixed field order and `#`-section file-listing structure (toc-file-§1/toc-file-§5).
- [x] **No `TODO.md`** — the backlog is GitHub issues (documentation-§4). Deferred items are tracked in `docs/pending/LEDGER.md`.
- [x] LICENSE = MIT full text.
- [x] Audit and review history retained under `docs/audits/<DATE>/` and `docs/reviews/<DATE>/`.

**Two known departures, both deliberate and recorded** in ARCHITECTURE ▸ *Documented deviations*:
all defaults live in `defaults/Global.lua` with no `defaults/Profile.lua` (the addon is account-wide
by design), and this file is specialized to Bank Ledger rather than kept as a verbatim copy of the
upstream context pack.

---

## Patterns to reproduce (described, not named)

When stuck, reproduce these patterns — each already exists somewhere in the collection in the cited
dimension. (Per the standard's reading-guide convention, they are described by their role, not by addon name; the
named evidence is in `INDUSTRY_RESEARCH.md`.)

| Need | Reproduce this pattern |
|---|---|
| Schema structure | A single `Schema` table whose rows (`path/default/type/label/widget/validate/onChange`) drive AceDB defaults, AceGUI widgets, slash dispatch, and reset — with a boot-time validator that warns on any `path` not resolving against defaults. |
| Macro/protected-API firewall | A single `MacroManager`-style module that is the **only** caller of `CreateMacro`/`EditMacro`; no other file touches protected macro APIs. |
| Modular layout | `core/` + `modules/` + `defaults/` + `settings/` + `locales/` with strict TOC load order and idempotent `NS.<Module> = NS.<Module> or {}` publication. |
| Closed message bus | A handful of `Ka0s_BankLedger_*` messages, one sender each, documented in `docs/ARCHITECTURE.md`; consumers register by name, no cross-module table reach. |
| Compat module | One `Compat.lua` that owns every deprecated/cross-patch API call and exposes shimmed wrappers (`Compat.GetSpellInfo`, `Compat.GetSpecialization`). |
| Taint-free chat formatting | Override `_G[GLOBALSTRING]` values rather than hooking chat events or replacing `AddMessage`; order filter registration deterministically. |
| Combat-lockdown cascade | A layered `InCombatLockdown()` guard on secure writes (settings-setter → secure-frame-show), each deferring on `PLAYER_REGEN_ENABLED`. **Config-open is the exception: it refuses with a grey notice, never defers** (options-ui-§2). |
| Eager settings registration + lazy body | Register the Blizzard **category** at load (bootstrap on `ADDON_LOADED(Blizzard_Settings)`/`PLAYER_LOGIN`, or in `OnInitialize`); build the panel body only in the first `OnShow`. |
| On-screen debug console | A `DIALOG`-strata `700×344` `BackdropTemplate` window; a `ScrollingMessageFrame` in a shipped monospace font (10pt) with tagged, colour-coded lines (`<ts> \| [<Tag>] <content>`), a right-edge scrollbar + bottom `N / MAX lines` counter (debug-logging-§11), Clear/Copy, `UISpecialFrames`, on the shared Ka0s window edge and still tracking the main window's `ApplySkin`, but closing with the library's own thin 18×18 ×; a gated `NS.Debug(tag, …)` sink that appends there instead of chat; session-only window-independent enabled-state with a title-bar `Debug: ON/OFF` toggle. |
| Preview/test mode | Placeholder data fed through the real render path, read-only so it cannot reach real settings or history (`/bl test`, `/bl session`). |
| Headless test harness | LibKa0s test kit vendored at `tests/_kit/` (registry, assertions, `setfenv` loader, shared mock base) + `tests/run.lua` (TOC-derived load list, lifecycle kick, suite list) + `tests/wow_mock.lua` (the addon-specific extender); per-module `test_*.lua` suites. |
| Lazy first-OnShow panel build | Latch (`rendered` flag) so the AceGUI body builds once, on first `OnShow`, when the panel width is non-zero. |
| Lazy header Defaults button | `ensureDefaultsButton(panel)` at the top of every `OnShow` builds the AceGUI `Button` once, after every addon has loaded — so a UI skin's `RegisterAsWidget` hook is already in place and the button isn't left on stock red art (options-ui-§5). |
| Soft-fallback discipline | Load-safe shims for missing optional libs (AceDB-missing flat table, LSM-missing Blizzard constants) so the addon runs with `OptionalDeps` absent. |

---

## Skills you should use while building

(All under `wow-addon:` prefix in your local Claude Code plugin.)

- `wow-addon:new-addon` — scaffold a new addon (Ace3 stack, AceDB, modular folder layout, MIT license, slash command).
- `wow-addon:standards-audit` — audit the current addon against the standard. Produces the `docs/audits/<DATE>/` deviation + remediation bundle (audit-review-history).
- `wow-addon:review` — principal-engineer code review of the current addon. Produces a `docs/reviews/<DATE>/` findings bundle (audit-review-history).
- `wow-addon:sync-docs` — eliminate doc drift across README, CLAUDE.md, ARCHITECTURE.md.
- `wow-addon:bump-interface` — bump the single TOC Interface line to the latest Retail patch.
- `wow-addon:bump-version` — bump version everywhere (TOC, code constants, README badges + Version History, CLAUDE/ARCHITECTURE, CHANGELOG).
- `wow-addon:diff` — summarize uncommitted changes with risk assessment.
- `wow-addon:commit` — generated-message commit.
