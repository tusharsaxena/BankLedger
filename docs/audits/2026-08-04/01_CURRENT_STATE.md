# 01 · Current state — Ka0s Bank Ledger — 2026-08-04

Audited against the **Ka0s WoW Addon Standard v2.17.1 (2026-08-03)**.

## Provenance of the standard text

The playbook and the whole standard were fetched over the network and then verified byte-for-byte
against the canonical local checkout. Both routes agree, so nothing in this run is reconstructed
from memory.

| What | How it was obtained | Verification |
|---|---|---|
| `AUDIT.md` | `curl -fsSL --max-time 15 https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/AUDIT.md` | `diff` vs local checkout — **identical** |
| `standards/STANDARDS.md` | same raw base | `diff` vs local checkout — **identical** |
| All **24** section files under `standards/standards/` | fetched one-by-one from the raw base with `--max-time 10`, discovered by following the index's **Sections** list (never hard-coded) | `diff -r` of the fetched set vs `WowAddonStandards/standards/standards` — **identical**, 0 differences, 24/24 files |

Local checkout used for the identity check:
`/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards` — clean tree, HEAD
`214122996c6c2db2e1c4a88a1f5d152dce2de928` *("v2.17.1 — finish the v2.17.0 rollout: no fourth slot,
no drop-in imperative")*. That checkout was read only; nothing under it was written.

**Every section was assessed.** No section is marked unassessed.

Addon HEAD at audit time: `95b7ae4b0f9cefcfe17577c80583b31866755eaf` *("docs+i18n: complete the
v2.17.1 dialect sweep")*.

---

## layout

The modular tree is in place and nothing is loose at the root.

```
core/    Compat, Constants, Namespace, CoreSetup, DebugLogSetup, State, Util, BankLedger, Database
defaults/ Global.lua                (no Profile.lua — see 02_DEVIATIONS BL-07)
locales/ enUS.lua, PostLoad.lua
modules/ Filters, Ledger, Browser, LedgerTable, SessionWindow, InsightsWidgets, Insights, Export
settings/ Schema, Slash, OptionsSetup, Panel
media/   fonts/ logos/ screenshots/     (typed subfolders only — layout-§3 ✓)
libs/    Ace3 set + LibDataBroker-1.1 + LibDBIcon-1.0 + LibSharedMedia-3.0 + LibKa0s
tests/   _kit/ + run.lua + wow_mock.lua + 18 test_*.lua
docs/    ARCHITECTURE.md, testing.md, smoke-tests.md, test-cases.md, pending/, superpowers/, audits/, reviews/
```

- Casing is compliant: root `BankLedger` PascalCase, all subfolders lowercase, all Lua files
  PascalCase (`core/Database.lua`, `modules/LedgerTable.lua`).
- **File sizes.** No file exceeds 1500 LOC. The largest is `modules/Browser.lua` at **1306** lines,
  which sits inside layout-§1's 1000–1500 "on notice" band (advisory — BL-24). Next largest:
  `modules/LedgerTable.lua` 972, `modules/Insights.lua` 916, `modules/InsightsWidgets.lua` 832.
- Load order in the TOC follows layout-§1 (`Compat` → `Constants` → `Namespace` → other `core/*` →
  `defaults/*` → `modules/*` → `settings/*`); locales are hoisted above `core/`, which the TOC's own
  required section order (toc-file-§5: Libraries → Locales → Core → …) mandates.

## toc-file

`BankLedger.toc:1-13` carries the metadata block in the **exact required field order** — Interface,
Title, Notes, Author, Version, IconTexture, SavedVariables, OptionalDeps, DefaultState,
Category-enUS, X-License, X-Standard, X-Curse-Project-ID — with no blank lines inside the block.

- `## Interface: 120007` — single latest-Retail number (`:1`), matched by the README `[wow]` badge
  `Midnight_12.0.7` (`README.md:3`).
- `## X-License: MIT` (`:11`), `## X-Standard:` pointing at the standards repo (`:12`),
  `## X-Curse-Project-ID: 1629058` (`:13`) — the addon is published, so this is now required and
  present (closes BL-03).
- No hard `## Dependencies:`; everything soft via `## OptionalDeps:` (`:8`).
- **`## SavedVariables: BankLedgerDB` declares only ONE global** (`:7`). toc-file-§2 requires exactly
  two, in order, the second being `BankLedgerPerfDB` — see BL-12.
- File listing: `#`-sectioned in the mandated order (Libraries `:15`, Locales `:31`, Core `:35`,
  Defaults `:51`, Modules `:54`, Settings `:64`), dependency-ordered, no addon-authored `embeds.xml`.
- Every vendored library is listed **directly**; `libs\LibKa0s\LibKa0s.xml` is listed **once**, last
  in the `# Libraries` block after Ace3 (`:29`) — never individual module `.lua` files.
- File ends in a single trailing newline (CRLF, pinned by `.gitattributes`).

## library-stack

All mandatory Ace3 libs are vendored and committed under `libs/` (LibStub, CallbackHandler-1.0,
AceAddon/AceDB/AceEvent/AceTimer/AceConsole/AceGUI-3.0), plus LibSharedMedia-3.0,
LibDataBroker-1.1 and LibDBIcon-1.0 — each of which the addon actually `LibStub()`s. No Ace fork, no
suite dependency, no `externals:`.

`libs/LibKa0s/` holds the **whole ship folder** — `Core.lua`, `DebugLog.lua`, `Slash.lua`,
`Options.lua`, `OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`, `PerfPanel.lua`, `LibKa0s.xml`,
`LICENSE` — including the two Perf files the addon does not wire, which is exactly what
library-stack-§7 requires ("ship payload is the whole folder, always"). `tests/_kit/` holds the
vendored `testkit/`, under `tests/` and never under `libs/`.

**Both vendor-sync diffs are empty** (`03_EVIDENCE.md` §Mechanical checks) — no anti-pattern #45
drift and no anti-pattern #48 partial vendoring.

## architecture

- Every file opens `local addonName, NS = ...`; no `_G[addonName]` table anywhere.
- AceAddon promotion at `core/BankLedger.lua:3-6` passes `NS` as the first arg to `:NewAddon`.
- **The AceConsole clobber is handled.** `core/BankLedger.lua:13` reclaims
  `NS.Print = NS.Util.print` immediately after `NewAddon`, and `core/CoreSetup.lua:97-98` makes the
  two the *same function object* rather than two wrappers — which is what makes the reclaim reach the
  five files that captured the printer as a load-time upvalue.
- Modules publish idempotently (`NS.X = NS.X or {}`).
- Closed message bus: five messages, all `Ka0s_BankLedger_*` prefixed — `EntryAdded`,
  `LedgerChanged`, `SessionChanged`, `SettingsChanged` — each with a single producer module. Every
  **receiver** owns a private AceEvent target from `NS.NewBusTarget()` (`core/BankLedger.lua:20-26`),
  never the shared bus as `self` (`modules/Browser.lua:1298-1300`,
  `modules/SessionWindow.lua:652-659`, `modules/Insights.lua:914-915`, `modules/Ledger.lua:787`,
  `settings/Panel.lua:165-166`, `:311`). Anti-pattern #32 clear.
- Schema-as-single-source: `settings/Schema.lua` drives defaults, the panel, and the slash CLI, with
  `S:Set` (`:165-192`) the single write seam that validates → writes → traces once → runs `onChange`
  → repaints the panel. Boot validation walks every row and warns loudly (`:203-219`).

## savedvariables

`AceDB:New("BankLedgerDB", NS.defaults, true)` in `core/Database.lua`; `schemaVersion` is declared in
`defaults/Global.lua:14` from the one source `NS.SCHEMA_VERSION = 2` (`core/Namespace.lua:13`), and
`NS:RunMigrations` ships as the migration runner. `NS.State.debug` is session-only and never
persisted (`core/State.lua:25-26`).

Defaults live entirely in `defaults/Global.lua` — the addon is account-wide by design and carries no
`profile` tree. That departure from savedvariables-§2 is now **recorded as an accepted deviation** in
`docs/ARCHITECTURE.md:567-580` (BL-07). The diagnostics global `BankLedgerPerfDB` (savedvariables-§4)
does not exist (BL-12).

## options-ui

Fully on `LibKa0s-Options-1.0`. `settings/OptionsSetup.lua:26` resolves the major silently
(`LibStub(..., true)`), `:36-94` is the descriptor, `:166` makes `NS.Helpers` **be** the library
instance (not a copy-across), and `settings/Panel.lua` decorates it in place.

- Degradation (`settings/OptionsSetup.lua:115-163`) is the **load-completing** stub options-ui-§1
  documents as the one exception to member-answering. The measured load-time member set for this
  addon is **zero** — no schema-row literal calls a helper — and the comment says so, with
  `tests/test_libka0s.lua` pinning both the member set and the resulting row count.
- `OnCommit` / `OnDefault` / `OnRefresh` come from the library's `CreatePanel`
  (`libs/LibKa0s/Options.lua:219-231`, Options **minor 5**), and the host correctly does **not** set
  them itself — it parks `defaultsOnClick` (`settings/Panel.lua:52`) which the library's `OnDefault`
  forwards to. This closes BL-06 from the 2026-07-27 run.
- Category registration is **eager** at `OnInitialize` (`core/BankLedger.lua:36` →
  `settings/Panel.lua:511`, `:600`); bodies are lazy on first `OnShow`.
- Combat gate lives inside the library's `OpenOptionsPanel`; the host's `P:Open`
  (`settings/Panel.lua:603-607`) routes through it and wires no second un-gated open path.
- Landing page renders logo → tagline → "Slash Commands" heading → one Label per `NS.COMMANDS`, and
  the rows come from `NS.Slash:LandingRows()` — the library's single row formatter, shared with
  `/bl help` (`settings/Panel.lua:317-361`).
- No AceConfig; no hand-rolled widget makers, flow engine, header or layout constants; the stub reads
  `ROW_VSPACER/SECTION_HEADING_H` as zeros rather than copying library values
  (`settings/OptionsSetup.lua:157-161`).

## standalone-windows

Four non-secure windows: the ledger browser (`BankLedgerWindow`), the session window
(`BankLedgerSessionWindow`), and the two export popups (`BankLedgerExportWindow`,
`BankLedgerExportCopyWindow`). All are plain `CreateFrame("Frame")`, all register in
`UISpecialFrames` (`modules/Browser.lua:1186-1187`, `modules/SessionWindow.lua:554-555`,
`modules/Export.lua:262-263`, `:352-353`), position/size persist to
`db.global.settings.window` / `.sessionWindow`, and `settings.windowScale` is a schema row applied
via `SetScale`.

The window edge comes from the host helper `B:ApplySkin` (`modules/Browser.lua:67-89`), whose values
are **exactly** the normative Ka0s edge — bg `0.06,0.06,0.08,0.92`, black `edgeSize = 1` outer border
inset 1, a 1px `BackdropTemplate` child at `0.24,0.24,0.27,0.85`, gold title `1.0,0.82,0.0`, divider
`0.24,0.24,0.27,0.85`. It restates them rather than delegating to `Core.ApplySkin`, which is the
SHOULD in standalone-windows-§2 (BL-19). The debug console correctly routes through the same host
seam via the descriptor's `applySkin` hook and correctly does **not** pass `makeCloseButton`
(`core/DebugLogSetup.lua:107-116`), so the library's window keeps the library's close glyph.

Row pooling is present for the high-churn history table (`modules/LedgerTable.lua:533-535`,
`:673-679`, `:712`).

## preview-mode

`/bl session` toggles a placeholder-data preview of the session window, and `/bl test` publishes a
synthetic ledger into the browser (`settings/Schema.lua:242-256`, `:257-261`). Both feed the real
render path and both clear on toggle-off. The addon's main surface is a data browser rather than a
positionable HUD, so this section is largely satisfied by those two verbs.

## slash-commands

Fully on `LibKa0s-Slash-1.0`. `settings/Slash.lua:99` resolves the major silently, `:174-213` builds
one dispatcher from a descriptor over the host's own `NS.COMMANDS`, and `:215-228` republishes the
verbs. Registration stays AceConsole (`:82-83`) for both `/bl` and `/bankledger`; no `SLASH_*`
globals.

- `NS.COMMANDS` (`settings/Schema.lua:226-286`) is the host's, positional triples, 15 verbs.
- Reserved verbs present: `help`, `get`, `set`, `list`, `reset`, `resetall`, `config`, `version`,
  `debug`. **`perf` is absent** (BL-13).
- `reset` takes a path, not a page. Unknown verb prints `unknown command '<verb>'` then help.
- The tagged printer is the host's: `NS.PREFIX = "|cff00ffff[BL]|r"` (`core/Namespace.lua:18`),
  built from `LibKa0s-Core-1.0`'s printer factory (`core/CoreSetup.lua:88-98`) and passed as the
  descriptor's `print`. **Two call sites in `modules/Browser.lua` bypass it** (`:855`, `:864`) —
  BL-18.
- Host-side `format`/`parse` hooks handle this addon's one `type = "table"` row and defer everything
  else to the library (`settings/Slash.lua:198-212`) — an override at the sanctioned seam, not a fork.

## localization

`locales/enUS.lua:6` ships the metatable-fallback `NS.L`; `locales/PostLoad.lua` ships the alias
seam. v1.0.0 is English-only and no string routes through `NS.L` yet — an accepted scope decision
with its reason written in the file itself (`locales/enUS.lua:8-16`), which is what a SHOULD-level
departure requires. `localization-§3`'s MUST (ship `enUS.lua`) is satisfied.

Game data is matched on stable tokens throughout: `select(2, UnitClass("player"))` for the class file
(`modules/Ledger.lua:422`, `modules/SessionWindow.lua:194`, `modules/Browser.lua:101`), itemIDs for
items, `C_Map.GetBestMapForUnit` for the map. `GetZoneText`/`GetSubZoneText`
(`core/Compat.lua:32-36`) are captured as a **display stamp** on a record and are never compared
against a literal — no anti-pattern #37.

**US English sweep is clean.** A grep for `colour|grey|behaviour|centre|cancelled|analyse|catalogue|
dialogue|defence|licence|favour|labelled|-ise|-isation` across every authored file returns nothing.
The single hit in the repo is `tests/_kit/README.md:119` ("behaviour"), which is **vendored library
text** that testing-§1 forbids editing here — a LibKa0s finding, not a Bank Ledger deviation.

## events-frames-taint

AceEvent everywhere (`core/BankLedger.lua:40`, plus private targets for `PLAYER_LOGOUT`). No CLEU
path, no per-frame `OnUpdate` anywhere in the addon. No secure/protected frames, so no
`InCombatLockdown()` gate is required for the addon's own windows (standalone-windows explicitly
exempts non-secure windows); the only combat-gated surface is the options panel open, and that gate
is the library's.

Secret-safety: `NS.IsConcatSafe` / `NS.SafeToString` are published straight off
`LibKa0s-Core-1.0` (`core/CoreSetup.lua:76-77`), the degraded branch (`:43-53`) is the one sanctioned
second copy, and every chat line goes through `NS.Print` — except the two `modules/Browser.lua` call
sites in BL-18.

Row pooling is implemented for the history table (see standalone-windows above).

## public-api

The addon exposes no public surface and creates no `_G[addonName]` table. Section is N/A and
correctly so.

## compat

`core/Compat.lua` (230 lines) is the single home for container, item, bank, money, map and metadata
API access. A grep for direct deprecated calls outside it returns only `NS.Compat.*` call sites
(`modules/Ledger.lua:175`, `:294`). No `WOW_PROJECT_ID` branching anywhere.

## debug-logging

Fully on `LibKa0s-DebugLog-1.0`. `core/DebugLogSetup.lua:20` resolves silently and guards; `:59-121`
is the descriptor with the five required fields (`name`, `title`, `font`, `isEnabled`, `setEnabled`)
plus `print`, `initSummary`, `slash`, `onVisibilityChanged` and `applySkin`; `:125` binds the sink
bare as `NS.Debug`.

- `print` and `initSummary` are **thin call-time forwarders**, not captured references (`:78-79`).
- The flag is the host's, session-only, on `NS.State.debug`, never in SavedVariables.
- The degradation stub (`:22-57`) answers every member the addon calls — `IsShown`, `Show`, `Hide`,
  `Toggle`, `Add`, `Clear`, `UpdateScrollBar`, `UpdateStatus`, `RefreshHeader`, `ShowCopy`,
  `IsEnabled`, `SetEnabled`, plus the raw `buffer` — still flips the flag, still says once why the
  window is missing, and copies neither formatter nor color code.
- The monospace font ships at `media/fonts/JetBrainsMono-Regular.ttf` with `OFL.txt` beside it and is
  registered with LSM at `core/BankLedger.lua:30`.
- Coverage: **23** gated `NS.Debug` call sites across lifecycle (`Migrate`, `Prune`), the core
  capture flow including the not-recorded decisions (`Store`, `Skip`, `Diff`, `Move`), data mutations
  (`Data`), view opens/recomputes (`UI`, `Table`, `Session`, `Insights`, `Filters`), and the single
  `[Set]` line at the write seam (`settings/Schema.lua:177-179`).
- Two structured dump verbs — `/bl debug scan` and `/bl debug panel` — both use the **ungated raw
  append**, so an explicit diagnostic run is never gated on the debug flag.

## packaging

`.pkgmeta` declares `package-as: BankLedger`, no `externals:`, and ignores `.luacheckrc`,
`.gitignore`, `.gitattributes`, `docs`, `tests`, `_dev`, `*.bak`, plus `media/screenshots` and the
non-runtime logo sources. No `enable-toc-creation`.

## lint

`.luacheckrc` is present, based on the house config, excludes `libs/`, `docs/audits/`,
`docs/reviews/`, `_dev/`, `tests/`. Every `globals` entry carries a justifying comment. **Missing:**
`debugprofilestop` in `read_globals` and `BankLedgerPerfDB` in `globals` (BL-14).

`luacheck .` → **0 warnings / 0 errors in 24 files**.

## testing

The kit is vendored whole at `tests/_kit/` (`framework.lua`, `loader.lua`, `mock_base.lua`,
`README.md`) and byte-identical to `LibKa0s/testkit/`. `tests/run.lua` keeps only what is this
addon's: the LibKa0s file list in XML order (`:31-40` — **all eight files**, including the two Perf
ones the addon does not wire), the TOC-derived list of the addon's own files
(`Loader.tocFiles("BankLedger.toc")`, `:46`), the lifecycle kick (`:53-61`), and the suite list.
`tests/wow_mock.lua` is a thin extender over `mock_base`.

`lua tests/run.lua` → **689 passed, 0 failed, 689 total**, exit 0.
`docs/test-cases.md` is generated by `--list` and totals **689**; the README `[tests]` badge reads
`689/689` (`README.md:7`). All three agree.

Degraded-path suites exist for all three adopted modules and load the addon with the module genuinely
absent rather than hand-stubbing (`tests/test_libka0s.lua`). `tests/test_vendor_sync.lua` pins the
vendored payload against the release the README names.

**Not present:** `tests/perf.lua` (BL-16).

## performance

**Unadopted.** `libs/LibKa0s/Perf.lua` and `PerfPanel.lua` are correctly vendored as part of the
whole folder and are loaded by `LibKa0s.xml`, but nothing wires them: there is no
`core/PerfSetup.lua`, no `NS.Perf`, no declared buckets, no bracket, no `perf` verb, no
`BankLedgerPerfDB`, no suspend/resume contract, no `tests/perf.lua`, and no `docs/performance.md` /
`docs/perf-runs/`.

The decision is **recorded, reasoned and deliberate** — `docs/pending/LEDGER.md:65` (LIBKA0S-17,
🔵 wont-do, 2026-08-01) argues that the harness measures inside combat-gated windows while this
addon's entire capture engine is gated on a bank frame being open, so every declared bucket would
read `0.000` by construction. Yesterday's review (`docs/reviews/2026-08-03/01_FINDINGS.md:20-28`,
`05_FINAL_SUMMARY.md:37-40`) noticed the same gap and routed it here rather than acting on it.

An audit measures against the standard as written, and performance's adoption strength is **MUST for
the wiring**. The gap is therefore catalogued as MUST-level deviations BL-11 … BL-17, with the
recorded rationale reproduced beside each so the user can classify it as an accepted deviation or as
a change to the standard.

## documentation

Root ships exactly `README.md`, `CLAUDE.md`, `LICENSE`.

- **README** follows the canonical order: H1 → five-badge row in the exact template order
  (`:3-7`, standard badge using `_` not `%20`) → logo → description → `## What's new in 1.0.0`
  (`:36`) → `## Screenshots` (`:49`, seven captioned images — closes BL-02) → `## Usage` with
  `### Slash commands` (a table generated from `NS.COMMANDS`) and `### Settings panel` (a Tab/Covers
  table) → `## How the ledger works` (`:127`) → `## FAQ` → `## Troubleshooting` →
  `## Issues and feature requests` → `## Version History`. `## What's new` and the top Version
  History row agree. A sweep for angle-bracket placeholders finds none in shipped prose.
- **`CLAUDE.md`** is a stub with the H1, the adherence line, the verbatim-in-substance
  `## Standards compliance (read first)` section (`:6-23`), the read-the-docs pointer list, and the
  green-gate line. It also carries an explicit "there is no `agent-context.md`" section.
- **`docs/`** carries the canonical trio — `ARCHITECTURE.md` (with Overview, Module map, Data model,
  Settings schema, Message bus, Slash surface, Event subscriptions, Windows, Taint notes, Documented
  deviations, Known limitations), `testing.md`, `smoke-tests.md` — plus the required generated
  `test-cases.md`. **`docs/performance.md` and `docs/perf-runs/README.md` are absent** (BL-15), and
  the SHOULD-level `docs/complexity.md` is absent (BL-21).
- **`docs/agent-context.md` does not exist** — anti-pattern #49 clear (closes BL-08).
- No `TODO.md` anywhere. `docs/pending/LEDGER.md` is a decision ledger rather than a backlog, though
  its 🟡 rows do function as one — advisory BL-23.
- The standards reference appears in all **three** required places: TOC `## X-Standard:` (`:12`),
  README standard badge (`:6`), and `CLAUDE.md` `## Standards compliance (read first)` (`:6`).

Code and doc comments carry five **malformed** standard references (`options-ui-§41`,
`options-ui-§189`, `options-ui-§190`) and three uses of the **retired global `§N.M`** form
(`Ka0s standard §3.4`, `§3.1`) — BL-20.

## audit-review-history

`docs/audits/2026-07-26/`, `docs/audits/2026-07-27/`, `docs/reviews/2026-07-27/` and
`docs/reviews/2026-08-03/` are all retained and untouched. This run writes a new dated folder beside
them.

## versioning-git

Semver `1.0.0` in the TOC (`:5`), mirrored in `core/Namespace.lua:7` as the metadata fallback and in
the README Version History. One tag, `1.0.0-release`. Trunk-based on `master`. The commit gate is
documented in `docs/testing.md` and in `CLAUDE.md:33-34`, and both gates are green right now.
`docs/testing.md` additionally documents the LibKa0s re-vendor gate.

## naming-cheatsheet

Every convention in the table holds: folders, files, `NS`, `BankLedgerDB`, `/bl`,
`Ka0s_BankLedger_<Event>`, dotted settings paths, `NS.<PascalCase>` module tables,
`NS.Util.print` as the printer, `test_<module>.lua` suites, the `CLAUDE.md` stub, and the three
`docs/` homes. The only cheatsheet rows unmet are the perf ones (`<Addon>PerfDB`, `NS.Perf`, bucket
naming), which follow from the unadopted harness.

## anti-patterns

Swept #1–#49. Clear on all except:

- **#35 / the single-seam half of it** — two `modules/Browser.lua` call sites reach the *global*
  `print()` rather than the shared secret-safe, `[BL]`-tagged printer (BL-18).

Explicitly **not** flagged, because the addon is on the compliant side of each: #3, #5, #6 (library
dispatcher + `COMMANDS`), #7, #13, #22 (eager category registration), #26, #30/#31 (library-owned
scroll and button-pair widths), #32/#33 (private bus targets, target-keyed mock), #34, #36 (printer
reclaimed), #38, #39, #41, #42 (Defaults button built on first `OnShow`), #45 and #48 (both vendor
diffs empty), #47 (no hand-rolled console, toolkit, dispatcher or harness), #49.

## open-evolutions

Informational; nothing to assess.
