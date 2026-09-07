# 01 · Current state — Ka0s Bank Ledger — 2026-09-07

**Audited against the Ka0s WoW Addon Standard v2.38.0 (2026-09-02)** — index
`standards/STANDARDS.md` plus all **26** section files it links, fetched verbatim with
`curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, and the
playbook `AUDIT.md` from the same ref.

Repo `HEAD` at audit time: `0aec078` *Merge branch 'feat/settings-revamp-v2'* (2026-09-03).
Working tree clean. **This audit is read-only**: the five files in this folder are its only writes.

Rule set used: the **addon** sections. `BankLedger.toc` exists, so `AUDIT.md` step 1's
library-repo switch does not apply.

---

## Layout (`layout`)

`core/ defaults/ locales/ modules/ settings/ libs/ media/ tests/ docs/` — the modular tree, folder
casing correct. `defaults/` holds `Global.lua` only; the absent `defaults/Profile.lua` is a
**ratified** deviation (`docs/ARCHITECTURE.md:231`). `media/` holds `logos/` and `screenshots/`
only — no private copy of anything in `libs/LibKa0s/media/`.

Non-vendored Lua: 28 files, 10 228 lines. Three files sit in `layout-§1`'s 1000–1500 on-notice
band today — `tests/test_ledger.lua` 1478, `modules/Browser.lua` 1251,
`modules/LedgerTable.lua` 1096. Nothing is over the 1500 cap.

## TOC (`toc-file`)

`BankLedger.toc:1-14` carries every required field in `toc-file-§1`'s exact order, including
`X-License: MIT`, `X-Standard:` and a real `X-Curse-Project-ID: 1629058` (the addon is published;
the README carries the CurseForge version badge). `## SavedVariables: BankLedgerDB` alone
(`BankLedger.toc:7`) — correct under `savedvariables-§4`, which forbids declaring `<Addon>PerfDB`
for an addon holding a recorded `performance-§12` exemption.

The `# Libraries` block lists the single aggregate `libs\LibKa0s\LibKa0s.xml` once, last in the
block, after Ace3 (`BankLedger.toc:29`) — never individual module `.lua` files. The `# Core` block
annotates its load-bearing positions by name: `ItemSetup` before `Constants` for
`NS.Item.QualityLabel`, `MediaSetup` before `Constants` for `C.FONT_MONO`, `CoreSetup` after
`Namespace` for `NS.PREFIX`, `OptionsSetup` before `Panel.lua`; the conventional positions
(`EnvSetup`, `PoolSetup`) say so in as many words.

## Libraries and the shared subsystems (`library-stack`)

Ace3 + LibStub + LibSharedMedia + LDB/LDBIcon, all vendored. `libs/LibKa0s/` is the **whole**
v1.25.0 ship folder; `tests/_kit/` is that release's test kit. The provenance line is in root
`CLAUDE.md:46` and **not** in `README.md` — the shape `testing-§11`'s gate requires since kit
revision 9.

The addon owns a **descriptor plus a degradation stub** per module and no implementation:

| Module | Seam file | Descriptor |
|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua:141` | printer with `prefix` closure; `NS.ApplySkin = lib.ApplySkin` at `:112` |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua:60` | `name`/`addonName` = the first vararg (`:61`, `:74`) |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` | page registry, `RenderTabbedSchema`, `MasterControls` composer |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua:197` | `commands = NS.COMMANDS` (`:200`) |
| `LibKa0s-Env/Item/Media/Pool` | `core/EnvSetup.lua`, `ItemSetup.lua`, `MediaSetup.lua`, `PoolSetup.lua` | one `LibStub` lookup each |
| test harness | `tests/_kit/` | vendored, `100755`, unedited |
| `LibKa0s-Perf-1.0` | — | **deliberately unwired**, ratified at `docs/ARCHITECTURE.md:230` |

`core/MediaSetup.lua` passes the addon's **own first vararg** as the folder name and makes one
registration. Every seam has a library-absent branch, and `tests/test_libka0s.lua` proves stub
surface parity mechanically (`T.assertSurfaceParity`) for Core, DebugLog, Slash and Options rather
than by hand-stubbing.

## Settings (`options-ui`)

One landing page (host-drawn `buildMain`, `settings/Panel.lua:435`) and one **General** page
rendered through `O.RenderTabbedSchema` (`settings/Panel.lua:695`). Six primary tabs in `group`
declaration order: **Master controls** (composed by the library from `S.MASTER_SPEC`,
`settings/Schema.lua:150-256`), Capture, Interface, History, Filters. The Filters tab carries a
**secondary** strip over blacklist/whitelist, drawn as ordinary scroll content with its selection
kept per primary tab in `ctx.activeSubTab` and never persisted (`settings/Panel.lua:360-400`). No
third level.

No color rows anywhere, so `options-ui-§17` and the `disabledIf` check are inapplicable. No
`LSM30_*` control and no `ScrollUp-Up`/`ScrollDown-Up` reorder art in `settings/`. `settings.visibility`
is a four-value dropdown that **never shipped as a boolean** (`defaults/Global.lua:45-48`), so no
migration is owed and `NS.SCHEMA_VERSION` is correctly unmoved.

## Slash, debug, events (`slash-commands`, `debug-logging`, `events-frames-taint`)

`NS.COMMANDS` carries 15 verbs (`settings/Schema.lua:407`), handed to the library dispatcher. Six
files bind `local print = NS.Print` at file scope, so every chat line is the secret-safe `[BL]`
printer — the two `modules/Browser.lua` global-`print` sites the 2026-08-05 run raised are gone.
Debug logging is session-only (`NS.State.debug`), never persisted.

## SavedVariables (`savedvariables`)

One AceDB tree under `db.global`; `NS:RunMigrations` at `core/Database.lua:14-31` is an idempotent
runner keyed on `g.schemaVersion`. Four storage carve-outs (`window`, `sessionWindow`, the two id
lists, `savedView`) are documented at `defaults/Global.lua:17-30` and `settings/Schema.lua:99-105`.

## Line endings (`line-endings`)

`.gitattributes` present and **byte-identical to the standard's canonical client-bound body** (diff
against the block extracted from `line-endings-§5`: empty). Pin `* text=auto eol=crlf`
(`.gitattributes:26`), `*.sh text eol=lf` (`:34`), 20 `binary` rows. The working tree does not fully
agree: 4 tracked files — see `02_DEVIATIONS.md` BL-32.

## Packaging (`packaging`)

`.pkgmeta` ignores `.luacheckrc .gitignore .gitattributes docs tests _dev *.bak media/screenshots`
and the two unloadable logo formats. `.superpowers/` exists in the repo and is **not** accounted for.

## Documentation (`documentation`)

Root: `README.md` (bare `![Standard]` badge at `:6`, no bundled-library inventory, no `## Credits`,
`## What's new in 1.0.0` and `## Version History` present), `CLAUDE.md` (standards-compliance
section, provenance line, the no-`agent-context.md` rule), `DEPENDENCIES.md`, `LICENSE`.

`docs/`: all six Tier 1 files present under their canonical names; three Tier 2 present
(`slash-dispatch.md`, `midnight-quirks.md`, `compat-layer.md`) and four answered by a *Not
applicable* row carrying its trigger (`message-bus.md`, `profiles.md`, `debug.md`,
`perf-analysis/README.md`). Four of the five verification-and-record members ship
(`test-cases.md`, `performance.md`, `automated-tests/README.md`, `automated-tests/RESULTS.md`) —
the fifth is the conditional one the exemption removes. `## Documentation map`
(`docs/ARCHITECTURE.md:169`) covers every live `.md` under `docs/` exactly once with frozen
directories named once each; no orphan, no dangling row, no retired `file-index.md`,
`conventions.md`, `complexity.md` or `docs/perf-runs/`. Hub is 236 lines with all ten mandated
sections.

`## Documented deviations` (`docs/ARCHITECTURE.md:218-235`) carries three rows — `performance-§12`,
`savedvariables-§2`, `options-ui-§12` — each with a `filename-§N` Rule, a Decided date and a
re-check trigger.

## Issue store (`audit-review-history`)

12 issues, every one carrying a `state:` and a `severity:` label, no `[status]` title prefix, no
surviving `docs/pending/LEDGER.md`. Open: #1, #2 (`state:triaged`, enhancements), #3
(`state:triaged` — *Record the BL-04 deviation in ARCHITECTURE's Documented deviations register*).
Closed `state:will-not-do`: #4, #5, #6, #7, #8, #9, #10. Closed `state:done`: #11, #12.

## Suites, as observed today

`luacheck .` → **0 warnings / 0 errors in 28 files**. `lua tests/run.lua` → **831 passed, 0 failed,
0 skipped, 831 total**. `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` → **no thresholds
exceeded**, 14 174 NLOC over 2 153 functions. Full output in `03_EVIDENCE.md`.
