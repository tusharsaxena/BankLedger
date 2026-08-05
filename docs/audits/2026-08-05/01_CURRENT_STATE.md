# 01 · Current state — Ka0s Bank Ledger — 2026-08-05

**Audited against the Ka0s WoW Addon Standard v2.21.0 (2026-08-04).**

**Provenance.** `AUDIT.md` and `standards/STANDARDS.md` were fetched with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, and **all 25 section
files** were discovered by following the index's Sections list and fetched from
`$RAW/standards/standards/<file>.md`. No rule below is reconstructed from memory. The 25 sections
resolved: `layout`, `toc-file`, `library-stack`, `architecture`, `savedvariables`, `options-ui`,
`standalone-windows`, `preview-mode`, `slash-commands`, `localization`, `events-frames-taint`,
`public-api`, `compat`, `debug-logging`, `packaging`, `lint`, `testing`, `performance`,
`automated-tests`, `documentation`, `audit-review-history`, `versioning-git`, `naming-cheatsheet`,
`anti-patterns`, `open-evolutions`.

**Repo.** `/mnt/d/Profile/Users/Tushar/Documents/GIT/BankLedger`, branch `master`, HEAD `93abd23`.
Working tree carried only the untracked `docs/reviews/2026-08-05/` at the start of this run. This
audit is **read-only**: its only writes are the five files in this folder.

**Deviation prefix.** `BL-` (assigned on the 2026-07-26 run; reused).

---

## 1. Layout (`layout`)

`core/ defaults/ locales/ modules/ settings/` plus `libs/`, `media/`, `tests/`, `docs/`. No loose
source at root. Subfolders lowercase; Lua files PascalCase; suites `test_<module>.lua`.

- `core/` — `Compat.lua`, `Constants.lua`, `Namespace.lua`, `CoreSetup.lua`, `DebugLogSetup.lua`,
  `State.lua`, `Util.lua`, `BankLedger.lua`, `Database.lua`.
- `defaults/` — **`Global.lua` only**; no `Profile.lua` (BL-07, accepted and documented at
  `docs/ARCHITECTURE.md:568-581`).
- `locales/` — `enUS.lua`, `PostLoad.lua`.
- `modules/` — `Filters`, `Ledger`, `Browser`, `LedgerTable`, `SessionWindow`, `InsightsWidgets`,
  `Insights`, `Export`.
- `settings/` — `Schema.lua`, `Slash.lua`, `OptionsSetup.lua`, `Panel.lua`.
- `media/` — typed subfolders only: `fonts/` (JetBrainsMono + `OFL.txt`), `logos/` (`.tga` runtime
  plus `.png`/`.jpg` sources), `screenshots/`.
- **No file exceeds the 1500 LOC cap.** Four sit in the 1000–1500 on-notice band:
  `modules/Browser.lua` 1368, `tests/test_ledger.lua` 1361, `modules/LedgerTable.lua` 1052,
  `modules/Insights.lua` 1023 (BL-24).

## 2. TOC (`toc-file`)

`BankLedger.toc` metadata block is in the exact required field order — `Interface`, `Title`, `Notes`,
`Author`, `Version`, `IconTexture`, `SavedVariables`, `OptionalDeps`, `DefaultState`,
`Category-enUS`, `X-License`, `X-Standard`, `X-Curse-Project-ID` — with no blank lines inside it.
Single Retail `## Interface: 120007`; `X-License: MIT`; `X-Standard:` present; Curse project id
present; `X-Wago-ID`/`X-WoWI-ID` correctly omitted.

File listing uses `#` section headers in the required order **Libraries → Locales → Core → Defaults →
Modules → Settings**. Libraries are listed **directly** — no addon-authored `embeds.xml` — and
`libs\LibKa0s\LibKa0s.xml` appears **once**, last in the block, after Ace3.

**Gap:** `## SavedVariables: BankLedgerDB` declares **one** global; `BankLedgerPerfDB` is absent
(BL-12).

## 3. Library stack (`library-stack`)

Vendored and committed under `libs/`: LibStub, CallbackHandler-1.0, AceAddon/AceEvent/AceTimer/
AceConsole/AceDB/AceGUI-3.0, LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0, and `LibKa0s`.
No `externals:`. No Ace fork. No addon-suite dependency.

`libs/LibKa0s/` carries the whole ship folder: `Core.lua`, `DebugLog.lua`, `Slash.lua`,
`Options.lua`, `OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`, `PerfPanel.lua`, plus
`LibKa0s.xml` and `LICENSE` — **eight files across five majors**, which is the whole payload
(library-stack-§7). `Perf.lua`/`PerfPanel.lua` ship although the addon wires no Perf instance, which
is the correct *ship-payload-vs-adoption* split. `tests/_kit/` holds the harness — under `tests/`,
never `libs/`. **No anti-pattern #48 here.**

Byte-identity against the source repo is **not verified this run** — see `03_EVIDENCE.md` §1.5.

## 4. Shared subsystems — the addon owns descriptors and stubs, not implementations

There is **no** `modules/DebugLog.lua`, no addon widget-maker file, no addon dispatcher, no
hand-written test framework. Each adopted module is one setup file: a `LibStub(major, true)` lookup,
a descriptor, and a degradation stub.

| Module | Setup file | Lookup | Stub shape |
|---|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua:34` | `LibStub("LibKa0s-Core-1.0", true)` | working pre-library fallbacks for `IsConcatSafe`/`SafeToString`/`Print`, announced **once** (`:36-73`) |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua:20` | `LibStub("LibKa0s-DebugLog-1.0", true)` | member-answering (`:29-55`) |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua:99` | `LibStub("LibKa0s-Slash-1.0", true)` | member-answering; `CliResetAll` deliberately still **works** (`:109-154`) |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua:26` | `LibStub("LibKa0s-Options-1.0", true)` | **load-completing**, the documented options-ui-§1 exception, with the measured member set recorded at `:105-110` (`:115-163`) |
| `LibKa0s-Perf-1.0` | **absent** | — | — (BL-11) |

**Stub coverage checked call-site by call-site** (`03_EVIDENCE.md` §1.6): every member production
code reaches on `NS.DebugLog`, `NS.Slash` and `NS.Helpers` is answered by the corresponding
library-absent branch. The four members the DebugLog stub omits — `FormatPlain`, `FormatColored`,
`CopyText`, `ConsoleCheckbox` — are reached only from `tests/test_libka0s.lua:366-369`, which omits
them **on purpose** and says so in the case body: they are the fingerprints that distinguish "running
on the library" from "silently fell back". That is a decision with its reason written down, not a
gap.

`NS.Debug` is bound bare off the instance (`core/DebugLogSetup.lua:125`). `NS.Print` is reclaimed
from AceConsole's `:Print` embed immediately after `NewAddon` (`core/BankLedger.lua:4,13`), and
`NS.Print` and `NS.Util.print` are the **same function object**.

## 5. Architecture (`architecture`)

`local addonName, NS = ...` everywhere; no `_G[addonName]` table; no public API surface (so
`public-api` is N/A). AceAddon registration passes `NS` as the first arg. Four bus messages, all
`Ka0s_BankLedger_`-prefixed: `EntryAdded`, `LedgerChanged`, `SessionChanged`, `SettingsChanged`,
documented at `docs/ARCHITECTURE.md:269-289`. Schema-as-single-source is present and real:
`NS.Schema:Set` is the one write seam, and both the slash descriptor
(`settings/Slash.lua:184-188`) and the options descriptor (`settings/OptionsSetup.lua:46-49`) route
through it.

## 6. SavedVariables (`savedvariables`)

One AceDB tree, `BankLedgerDB`, account-wide `global` only. `schemaVersion` is stamped from one
constant (`defaults/Global.lua:14` ← `NS.SCHEMA_VERSION`) and a real migration runner ships at
`core/Database.lua:14-33`. No unsanctioned third global. The `Profile.lua` departure is BL-07.
No `<Addon>PerfDB` (BL-12).

## 7. Options UI (`options-ui`), standalone windows, preview mode

Panel is `LibKa0s-Options-1.0`'s shell driven by a descriptor; `NS.Helpers` **is** the instance,
decorated in place (`settings/OptionsSetup.lua:11-15,163`). Windows are non-secure `CreateFrame`
frames registered in `UISpecialFrames`, geometry persisted, pooled rows. `modules/Browser.lua:67-89`
carries a host `B:ApplySkin` that produces exactly the normative Ka0s edge values but does **not**
delegate to `Core.ApplySkin` (BL-19). The close-control split is handled correctly: the host's 24×24
glyph on host windows, and `core/DebugLogSetup.lua:111-116` deliberately passes **no**
`makeCloseButton` so the library's windows keep Core's. Preview mode is present as `/bl session` and
`/bl test`.

## 8. Slash (`slash-commands`) and debug logging (`debug-logging`)

`/bl` + `/bankledger` through AceConsole; `NS.COMMANDS` is a host-owned ordered table of positional
triples (`settings/Schema.lua:226-286`), passed into the dispatcher descriptor. Cyan `[BL]` tag as
one shared constant. Reserved verbs `help get set list reset resetall config version debug` all
present; **`perf` is absent** (BL-13). Debug flag is session-only on `NS.State.debug`, never in
SavedVariables. Structured dump verbs `/bl debug scan` and `/bl debug panel` route through the
ungated raw append, correctly.

**Gap:** `modules/Browser.lua:917` and `:926` call the **global** `print()` — the file declares no
`local print = NS.Print` (BL-18).

## 9. Localization, Compat, events/taint

`NS.L` is a metatable-fallback table (`locales/enUS.lua:6`); non-enUS files would gate. v1.0.0 ships
English-only with the scope decision written in place (`locales/enUS.lua:8-16`). `core/Compat.lua`
is the single home for deprecated/cross-patch API calls. No `WOW_PROJECT_ID` branching. A US-English
sweep over every authored `.lua` and `.md` returned **no** British spellings.

## 10. Lint, packaging, tests

- `.luacheckrc` present, `std = "lua51"`, excludes `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`,
  `tests/`; every `globals` entry carries a justifying comment. Missing `debugprofilestop` and
  `BankLedgerPerfDB` (BL-14).
- `.pkgmeta` present, no `externals:`, ignores `docs`, `tests`, `_dev`, `.luacheckrc`,
  `.gitattributes`, `*.bak`, plus the non-loadable logo sources and the screenshots.
- `tests/_kit/` is the vendored kit (`framework.lua`, `loader.lua`, `mock_base.lua`, `README.md`,
  `run-automated-tests.sh`). `tests/run.lua` derives the addon's load list from the shipped TOC via
  `Loader.tocFiles` and spells out **all eight** LibKa0s files explicitly (testing-§9). Twenty suites,
  **726 cases, all green**.
- `.gitattributes` carries `*.sh text eol=lf` with the reason (automated-tests-§2).

## 11. Performance (`performance`)

**Not adopted.** No `core/PerfSetup.lua`, no `NS.Perf`, no descriptor, no declared buckets, no
`Perf.on and debugprofilestop()` bracket, no `perf` verb, no `BankLedgerPerfDB`, no `tests/perf.lua`,
no suspend/resume contract, no `docs/performance.md`, no `docs/perf-runs/`. Recorded as a decline at
`docs/pending/LEDGER.md:65` (LIBKA0S-17, 🔵 wont-do) on the grounds that the harness's combat-gated
windows and this addon's `openContext` gate never overlap, so every declared bucket would read
`0.000`. That rationale has **still not been ratified** either as an accepted deviation in
`docs/ARCHITECTURE.md` ▸ *Documented deviations* (which carries only BL-07) or as a change to the
standard. BL-11 … BL-17 therefore stand, unchanged from the 2026-08-04 run.

The **complexity** half of `performance-§10` is, by contrast, in good order — see §12.

## 12. Automated tests (`automated-tests`)

Three frozen bundles under `docs/automated-tests/` (`20260804-182039`, `20260804-214843`,
`20260804-233144`), each with `manifest.json`, `ANALYSIS.md`, `lint.txt`, `tests.txt`,
`test-cases.md`, `complexity.txt`. `RESULTS.md` is one file, one row per run, with the watch list
below the table as **two tables with header rows** — warned functions (currently **None.**, written
out as a result rather than dropped) and files by `layout-§1` band, with a **Band column**, not a
heading. The `Max CCN` column's `33 → 0 → 15` discontinuity is explained in place as an instrument
fault rather than silently corrected.

**The measured complexity report is current, not stale.** A fresh
`lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` run from the repo root at HEAD `93abd23`
reproduces `20260804-233144/complexity.txt` **exactly** (CR-normalized diff empty): nloc 12788,
1946 functions, avg CCN 2.1, **zero warnings**, no function above CCN 15. No drift, no new band
entry.

**Gap:** the addon's own docs state only the never-gates half of the rule. Neither `docs/testing.md`
nor `docs/automated-tests/README.md` states the **release gate** — all four suites at `pass` plus
`suites.complexity.warnings == 0` at the tag — or that a `skip` is a gate that did not pass, which
matters here because this addon's `perf` is a permanent skip (BL-25). The vendored runner is
committed **non-executable** (BL-26).

## 13. Documentation (`documentation`)

- **Root doc set:** exactly `README.md`, `CLAUDE.md`, `DEPENDENCIES.md` plus `LICENSE`. No fourth
  doc, no `TODO.md`, no `docs/agent-context.md` — and `CLAUDE.md:53-66` records why it must never
  come back.
- **README** follows the canonical order: H1 → five badges in the exact canonical templates (the
  standard badge uses `_`, not `%20`) → logo → description → `## What's new in 1.0.0` immediately
  above `## Screenshots` → `## Usage` with both subsections → `## How the ledger works` → `## FAQ` →
  `## Troubleshooting` → `## Issues and feature requests` → `## Version History`. `What's new` and
  the top Version History row agree. No angle-bracket placeholders (`/bl set setting value`). The
  `[wow]` badge reads `Midnight_12.0.7`, matching `## Interface: 120007`; the `[tests]` badge reads
  `726/726`, matching the suite and `docs/test-cases.md`.
- **`CLAUDE.md`** is a stub carrying the H1, the adherence line, the verbatim-in-substance
  `## Standards compliance (read first)` section, the docs pointer list and the green-gate line.
- **`docs/` canonical trio:** `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md` all present.
  `ARCHITECTURE.md` carries every required section including a *Documented deviations* section.
- **Five required topic-detail docs:** `test-cases.md` ✓, `automated-tests/README.md` ✓,
  `automated-tests/RESULTS.md` ✓, **`performance.md` ✗**, **`perf-runs/README.md` ✗** (BL-15).
- **Retired `docs/complexity.md`:** correctly **absent**, and `docs/testing.md` says so explicitly.
  The 2026-08-04 deviation BL-21 ("no `docs/complexity.md`") is therefore **closed as superseded** by
  the v2.19.0 retirement.
- **Three-place standards reference:** TOC `## X-Standard:` (`BankLedger.toc:12`), README badge #4
  (`README.md:6`), `CLAUDE.md` `## Standards compliance (read first)` (`CLAUDE.md:6-24`). All three
  present.
- **`DEPENDENCIES.md`** splits runtime / development / release, gives WSL2 commands with the `pipx`
  workaround and a verification line per tool.
- Nine standard references in the repo's own files do not resolve (BL-20).

## 14. Audit & review history (`audit-review-history`), versioning (`versioning-git`)

`docs/audits/` holds 2026-07-26, 2026-07-27, 2026-08-04; `docs/reviews/` holds 2026-07-27,
2026-08-03, 2026-08-05. All retained, none edited. Semver `1.0.0` in TOC and README Version History.
Trunk-based; the working tree at audit time was clean apart from the untracked review bundle.

## 15. Anti-patterns sweep

Clean on #1–#55 except: **#34 is met** (the standards reference is in all three places); **#47 and
#48 do not apply** — nothing is hand-rolled and nothing is partially vendored; **#49 does not apply**
— no scaffolding pack; **#51 does not apply** — the complexity record reproduces exactly; **#53 does
not apply to functions** (the warned-function list is genuinely empty) though three of four file-band
entries read "Accepted" and are worth watching; **#54** — no `or`-defaulting sweep found over stored
settings. The live findings are #34-adjacent documentation drift (BL-20), the untagged global
`print()` (BL-18, which is the seam #35/events-frames-taint-§8 exists to protect), and the
release-gate omission (BL-25).
