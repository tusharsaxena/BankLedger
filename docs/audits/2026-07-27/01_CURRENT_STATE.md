# 01 · Current state — 2026-07-27

**Addon:** Ka0s Bank Ledger (`BankLedger`), version `0.1.0` (`BankLedger.toc:5`), unreleased (no git tags).
**Audited against:** **Ka0s WoW Addon Standard v2.11.0 (2026-07-26)** — `standards/STANDARDS.md` plus
every section file linked from its Sections list, fetched from
<https://github.com/tusharsaxena/WowAddonStandards> at run time.
**Playbook:** `AUDIT.md` (repo root of the standards repo).
**Deviation-ID prefix:** `BL-` (assigned on the 2026-07-26 run; reused here).
**Prior run:** `docs/audits/2026-07-26/` — frozen, untouched.

This run is **read-only**. No addon source, TOC, config or media was modified.

---

## Snapshot, section by section

### layout

Single modular tree, exactly the shape `layout-§1` prescribes: `core/`, `defaults/`, `settings/`,
`locales/`, `modules/`, plus `libs/`, `media/`, `tests/`, `docs/`. Nothing loose at the root beyond
`README.md`, `CLAUDE.md`, `LICENSE`, `.luacheckrc`, `.pkgmeta`, `BankLedger.toc`.

- `core/`: `Compat.lua`, `Constants.lua`, `Namespace.lua`, `State.lua`, `Util.lua`,
  `BankLedger.lua`, `Database.lua`.
- `defaults/`: **`Global.lua` only** — there is no `defaults/Profile.lua`; the addon is account-wide
  by design (`defaults/Global.lua:3-5`).
- `settings/`: `Schema.lua`, `Slash.lua`, `Panel.lua`.
- `locales/`: `enUS.lua`, `PostLoad.lua`.
- `modules/`: nine feature modules (`Filters`, `Ledger`, `Browser`, `LedgerTable`, `SessionWindow`,
  `InsightsWidgets`, `Insights`, `Export`, `DebugLog`).

Casing is compliant (`layout-§2`): PascalCase root and `.lua` files, all-lowercase subfolders,
`libs/` lowercase. LOC cap (`layout-§1`, 1500) is respected — the largest source file is
`modules/Browser.lua` at 1170 lines; `modules/LedgerTable.lua` (972), `modules/Insights.lua` (913),
`settings/Panel.lua` (817), `modules/InsightsWidgets.lua` (813) are the next band. None exceeds 1500;
`Browser.lua` sits in the 1000–1500 "on notice" band.

Media lives in typed subfolders (`layout-§3`): `media/fonts/` (JetBrains Mono + `OFL.txt`),
`media/logos/` (`.tga` runtime asset plus `.jpg`/`.png`/`256.jpg` sources), `media/screenshots/`
(present but empty).

### toc-file

`BankLedger.toc:1-12` carries the metadata block in the exact required field order — `Interface`,
`Title`, `Notes`, `Author`, `Version`, `IconTexture`, `SavedVariables`, `OptionalDeps`,
`DefaultState`, `Category-enUS`, `X-License`, `X-Standard`. Single Retail `## Interface: 120007`; no
multi-flavour list, no per-flavour TOCs. `X-Curse-Project-ID` / `X-Wago-ID` / `X-WoWI-ID` are absent
because the addon is not published anywhere yet.

File listing (`BankLedger.toc:14-57`) uses the `#` section comments in the mandated order —
Libraries → Locales → Core → Defaults → Modules → Settings. Every vendored library is listed
directly; there is no `embeds.xml`. The file ends with a single trailing newline.

### library-stack

Eleven vendored, committed libraries under `libs/`: LibStub, CallbackHandler-1.0, AceAddon-3.0,
AceEvent-3.0, AceTimer-3.0, AceConsole-3.0, AceDB-3.0, AceGUI-3.0, LibSharedMedia-3.0,
LibDataBroker-1.1, LibDBIcon-1.0. All eight mandatory libs are present; the three optional ones are
genuinely used (LSM registers the mono font at `core/BankLedger.lua:30`; LDB/LibDBIcon drive the
minimap launcher in `modules/Browser.lua`). AceConfig/AceDBOptions are **not** vendored — correct,
since there is no Profiles sub-page. No lib forks. `LibStub` is called once per lib at load, never
per frame.

### architecture

Every source file opens `local addonName, NS = ...`; no `_G[addonName]` table anywhere.
`core/BankLedger.lua:3-5` promotes `NS` to an AceAddon with AceEvent/AceTimer/AceConsole, and
**line 13 reclaims `NS.Print` from the AceConsole embed** (`if NS.Util and NS.Util.print then
NS.Print = NS.Util.print end`) — the `architecture-§2` fix, with the real printer named
`NS.Util.print` (`core/Util.lua:159`).

Closed bus: `NS.bus = addon` (`core/BankLedger.lua:6`), four `Ka0s_BankLedger_*` messages, each with
one sender. **Every consumer registers on its own AceEvent target** produced by the
`NS.NewBusTarget()` factory (`core/BankLedger.lua:20-26`) — `Browser.__ev`, `Ledger.__ev`,
`Insights.__ev`, `SessionWindow.__ev`, `Panel.__ev`, `Panel.__evFilters`. Nothing registers on
`NS.bus` as self. All four messages are documented in `docs/ARCHITECTURE.md:158-169` with sender,
payload and consumer list.

Schema-as-single-source: `settings/Schema.lua` holds eight rows driving AceDB defaults, panel
widgets and the slash CLI. `S:Set` (`settings/Schema.lua:157-174`) is the single write seam —
validate → write → `[Set]` debug line → `onChange`. `S:Register` (`settings/Schema.lua:190-202`)
walks every row at boot and returns the unresolved-path count for the harness.

### savedvariables

`NS:InitDB` (`core/Database.lua:5-8`) creates `BankLedgerDB` through AceDB and immediately runs
`NS:RunMigrations` (`core/Database.lua:14-33`), which reads and writes `db.global.schemaVersion`
against the single `NS.SCHEMA_VERSION = 2` constant (`core/Namespace.lua:13`). Defaults live in
`defaults/Global.lua` — **`global` only, no `profile` table**, a deliberate account-wide decision
recorded in the file header. There is no `defaults/Profile.lua`.

### options-ui

`settings/Panel.lua` implements the full canonical shape: parent canvas category = landing page
(logo at `LOGO_SIZE` 300, tagline in `GameFontHighlight`, "Slash Commands" `Heading`, one row per
`NS.COMMANDS` entry), plus two canvas subcategories, `General` and `Filters`. Registration is eager
in `OnInitialize` (`core/BankLedger.lua:36`); every body builds lazily on first `OnShow`.

The v2.11.0 rule is met: `ensureDefaultsButton` (`settings/Panel.lua:97-111`) builds the Defaults
button as an **AceGUI `Button`** and is called from the **top of each panel's `OnShow`**
(`settings/Panel.lua:755`, `791`), with the intent parked at registration
(`panel.wantsDefaultsButton`, line 78) and the callback parked as `panel.defaultsOnClick`
(lines 752, 782). `/bl debug panel` exposes the live region-list dump that diagnoses the skinning
race (`settings/Panel.lua:628-704`).

Layout constants are named and exact (`settings/Panel.lua:24-34`): `PADDING_X` 16, `HEADER_TOP` 20,
`HEADER_HEIGHT` 54, `DEFAULTS_W` 110, `LOGO_SIZE` 300, `ROW_VSPACER` 8, section spacers 10/6/26,
`BUTTON_PAIR_REL` 0.492. Two-column pairing is schema-driven. The scroll container rebinds
`FixScroll` to keep the bar always shown and inert (`settings/Panel.lua:139-199`). Refresh is
in-place via a `refreshers` list, with structural rebuilds scoped to the on-screen panel and a
`dirty` flag for hidden ones (`settings/Panel.lua:439-443`, `572-580`, `710-719`). Combat: `P:Open`
refuses with the canonical grey notice (`settings/Panel.lua:809-813`).

**Gap:** the canvas frames created by `createPanel` (`settings/Panel.lua:114-131`) define no
`OnCommit` / `OnDefault` / `OnRefresh` callbacks.

### standalone-windows

`modules/Browser.lua:924` creates `BankLedgerWindow` as a plain non-secure `Frame`, movable,
resizable with bounds, `SetClampedToScreen(true)`, scale applied from `settings.windowScale`, and
registered in `UISpecialFrames` (`modules/Browser.lua:1050-1051`). Geometry persists to
`db.global.settings.window` (`modules/Browser.lua:107-160`). One `SKIN` table and one `ApplySkin`
seam (`modules/Browser.lua:21-85`), reused by the debug console, the session window and the export
windows. Rows are pooled (`modules/LedgerTable.lua:533-679`, `814-843`). Tabs build lazily. Window
verbs `show`/`hide`/`toggle` and a LibDBIcon launcher both exist. The session, export and debug
windows all register in `UISpecialFrames` too.

### preview-mode

The Current Banking Session window is the positionable display; `/bl session`
(`settings/Schema.lua:220-229`) toggles a placeholder-data preview through
`NS.SessionWindow:TogglePreview()`, feeding the same render path and refusing to override a real
live session.

### slash-commands

AceConsole registration of `/bl` and `/bankledger` (`settings/Slash.lua:81-84`). Dispatch is a table
walk over `NS.COMMANDS` (`settings/Slash.lua:95-99`) — no `if/elseif` chain — lower-casing only the
verb. 16 verbs including `version`, `config`, `get`/`set`/`list`/`reset`/`resetall`, `debug`, and
the browser verbs. Unknown verb prints `unknown command '<verb>'` then the help index. Help is
generated from `NS.COMMANDS` (`settings/Slash.lua:104-110`) with the mandated header shape.

`NS.PREFIX = "|cff00ffff[BL]|r"` (`core/Namespace.lua:18`) is the single shared cyan tag. Every file
that prints does `local print = NS.Print`; there is no global `print()` call site, no hand-written
tag, no pre-concatenation before the printer. `list` output uses green header / azure `[group]` /
gold key / white value through the shared `FormatKV` and `FormatSchemaValue`
(`settings/Slash.lua:117-177`); `get`/`set` reuse the same two helpers, and `set` reads back the
stored value. No line carries a trailing colon.

### localization

`locales/enUS.lua:6` exports `NS.L` with the key-returning metatable; `locales/PostLoad.lua` is the
derived-alias seam. Both are stubs — v0.1.0 ships hardcoded English, recorded in the file itself as
an accepted scope decision. Game data is matched on stable identifiers throughout: container ids are
derived from `Enum.BagIndex` **member names** (`core/Constants.lua:109-142`), item identity comes
from `itemID` parsed out of the link (`core/Compat.lua:167-170`), quality from the link's colour hex
and quality **ids** (`core/Compat.lua:184-201`), bank type from `Enum.BankType.Account` read by name
(`core/Compat.lua:78`). No localized display string is used in a branch.

### events-frames-taint

AceEvent throughout; `modules/Ledger.lua:731-737` wraps `RegisterEvent` in a `pcall` so a retired
event name can't abort registration. No CLEU use. No secure writes; the only combat gate is the
options-panel refusal. Blizzard frames are hooked, never replaced. Hot-path upvalues are cached in
`L:RefreshUpvalues` (`modules/Ledger.lua:55`) and re-cached on the settings-changed message
(`modules/Ledger.lua:765`). Secret-safety: `NS.IsConcatSafe` probes **`table.concat`**
(`core/Util.lua:130-133`), `NS.SafeToString` substitutes `<secret>` (`core/Util.lua:139-144`), and
both the chat printer (`core/Util.lua:151-158`) and the debug sink
(`modules/DebugLog.lua:347-357`) build every line through it.

### public-api

None exposed. Section is N/A.

### compat

`core/Compat.lua` is the sole caller of every varying or deprecated API — addon metadata,
container/bank/guild-bank getters, item info, map/zone, money. Each is presence-guarded and degrades
to `nil`/`0`. No `WOW_PROJECT_ID` branch anywhere.

### debug-logging

`modules/DebugLog.lua` ships the console as a `BackdropTemplate` frame `BankLedgerDebugWindow` at
**700×344** on `DIALOG` strata, draggable, clamped, in `UISpecialFrames`, skinned through the
Browser's `ApplySkin`. Log is a `ScrollingMessageFrame` with `SetMaxLines(500)`, mono font at 10pt,
left-justified, fading off. Line format is the mandated `<HH:MM:SS> | [<Tag>] <msg>` with the two
pure formatters `FormatPlain`/`FormatColored` (`modules/DebugLog.lua:173-183`) in the mandated
colours. Copy/Clear both present; Copy uses the same mono font.

`debug-logging-§11` is met: a thin vertical `Slider` on the right edge with two-way sync guarded by a
`_syncing` flag (`modules/DebugLog.lua:114-138`, `201-212`), driven **only** through
`GetMaxScrollRange`/`GetScrollOffset`/`SetScrollOffset` with method-presence and type guards; a
bottom status bar showing `N / 500 lines`, updated on every append and reset by `Clear`
(`modules/DebugLog.lua:216-228`); and the initial sync runs **last** in the window build
(`modules/DebugLog.lua:164-167`).

State: `NS.State.debug` is session-only, never persisted (`core/State.lua:25`). `D:SetEnabled`
(`modules/DebugLog.lua:314-331`) is the single seam — flag, header refresh, colour-coded chat ack
(`ON` `40ff40` / `OFF` `ff4040`), console bracket at both transitions via the raw append, and the
`[Init]` session summary on enable. Coverage spans lifecycle, the capture/compute flow including
skip decisions, mutations, view recompute and the single `[Set]` settings line; per-pass summaries
are coalesced (`L.DiffSummary`, `L.MoveSummary`) with string-building behind the gate.

### packaging / lint / testing

`.pkgmeta` matches the template — `package-as: BankLedger`, no `externals:`, ignoring
`.luacheckrc`, `.gitignore`, `docs`, `tests`, `_dev`, `*.bak`. `.luacheckrc` is the WoW base config
with per-repo `read_globals`, `BankLedgerDB` and `StaticPopupDialogs` as commented write-globals,
and the mandated `exclude_files`.

The green gate passes at audit time: **`lua tests/run.lua` → 567 passed, 0 failed, 567 total**;
**`luacheck .` → 0 warnings / 0 errors in 22 files**. Fifteen suites under `tests/`, plus
`run.lua`/`loader.lua`/`wow_mock.lua`. `docs/test-cases.md` is generated and totals **567**, matching
the README `[tests]` badge exactly.

### documentation

Root ships `README.md`, `CLAUDE.md` (stub with the `## Standards compliance (read first)` section),
`LICENSE`. README order: H1 → badges → logo → description → `## What's new in 0.1.0` → `## Usage`
(slash-command table + settings-panel tab table) → `## How the ledger works` → `## FAQ` →
`## Troubleshooting` → `## Issues and feature requests` → `## Version History`. **`## Screenshots`
is absent.** The badge row is four badges — wow / license / standard / tests — with the
published-version badge correctly omitted pre-publish; `[wow]` shows `Midnight_12.0.7`, matching TOC
`120007`.

`docs/` carries the full quartet — `agent-context.md`, `ARCHITECTURE.md`, `testing.md`,
`smoke-tests.md` — plus the required generated `docs/test-cases.md` and topic detail under
`docs/superpowers/`. No `TODO.md`. The four-place standards reference is in place: TOC `X-Standard`
(`BankLedger.toc:12`), README badge (`README.md:5`), `CLAUDE.md` `## Standards compliance`
(`CLAUDE.md:6`), and the first bullet of `docs/agent-context.md:466-474`.

`docs/agent-context.md` is the standard's context pack dropped in verbatim, but at **pack v2.6.0
(2026-07-20)** — one pack release behind the current standard.

### audit-review-history

`docs/audits/2026-07-26/` (five artifacts) and `docs/reviews/2026-07-27/` (five artifacts) are both
retained and were not modified by this run. Today's bundle is a new dated folder beside them.

### versioning-git

Semver `0.1.0` in TOC and as the `NS.version` fallback; `/bl version` resolves through TOC metadata
with the constant as fallback, so the two cannot drift. `schemaVersion` is a single constant shared
by defaults and the migration runner. Work is trunk-based; the recent history is a linear run of
doc/fix commits on `main`.

### naming-cheatsheet

Conformant throughout — `NS` private namespace, `BankLedgerDB`, `/bl` two-char verb,
`Ka0s_BankLedger_<Event>` bus names, `NS.<PascalCase>` module tables, `NS.Util.print` printer,
`test_<module>.lua` suites, dotted settings paths.

### anti-patterns

Checked #1–#42. None of the forbidden patterns is present: no global namespace, no AceLocale strict
mode, no hand-rolled options framework, no AceConfig content, no `SLASH_*`, no `if/elseif` dispatch,
no `externals:`, no lib forks, no flavour branching, no un-routed deprecated calls, no
`:Hide()`-on-Blizzard-frames, no `AddMessage` replacement, no hard `Dependencies`, MIT licensed,
single Interface, no file over 1500 LOC, single sender per message, debug to the console not chat,
no cross-module direct access on the bus paths, no user Lua execution, trunk-based, eager category
registration, green gate, TDD harness, typed media folders, stub `CLAUDE.md`, no `TODO.md`,
canonical README/TOC shapes, self-contained, always-shown scrollbar, `BUTTON_PAIR_REL` 0.492,
per-receiver bus targets, target-keyed bus mock, four-place standards reference, secret-safe
printer, reclaimed `NS.Print`, ID-based game-data matching, no `embeds.xml`, in-place panel refresh,
`## What's new` present and current, scrollbar + line counter on the console, and the Defaults
button built lazily on `OnShow`.
