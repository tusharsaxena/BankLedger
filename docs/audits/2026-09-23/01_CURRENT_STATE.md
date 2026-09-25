# 01 · Current state — Ka0s Bank Ledger — 2026-09-23

## Run facts

| | |
|---|---|
| Standard | **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**, resolved from `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` with `curl -fsSL`: `AUDIT.md`, `standards/STANDARDS.md`, all 27 section files its Sections list links, and `standards/ADDONS.md`. Every fetch succeeded. |
| Repo kind | **Addon.** Discriminator (`documentation-§8`): the repo has a `.toc` (`BankLedger.toc`), and `standards/ADDONS.md` lists it in the in-scope addons table with **Launcher left-click (a) the ledger browser**. The addon rule set applies: every section plus `anti-patterns`. |
| Checkout | `/mnt/d/Profile/Users/Tushar/Documents/GIT/BankLedger`, branch `feat/2026-09-23-review-audit-remediation`, HEAD `3256d8c4dbe47fa4daa3ee3fbfeecbf463ee530d` (2026-09-23), working tree clean at the start of the run. |
| Tags | `1.0.0-release` (2026-07-28), `1.1.0-release` (2026-09-11, commit `243dfab`). |
| Bounded runner | `~/.claude/wow-addon/bin/ka0s-bounded` is **not on PATH** in this shell but exists at its absolute path (`/home/tushar/.claude/wow-addon/bin/ka0s-bounded`, a symlink into the wow-addon 2.3.0 plugin cache). Every `luacheck`, `lua tests/run.lua` and `lizard` run below went through it by absolute path, so the `timeout 900` fallback was not needed. |
| Prefix | `BL-` (reused from the 2026-07-26 … 2026-09-08 bundles). `BL-01`…`BL-40` exist; this run adds `BL-41`…`BL-51`. |
| Prior bundle | `docs/audits/2026-09-08/`, audited against v2.39.0. This run re-measures from the fetched v2.64.0 sections and inherits no verdict. |

## Layout (`layout`)

- Source under `core/` (15 files), `defaults/` (1), `locales/` (2), `modules/` (8), `settings/` (4): 30 source files. No loose root Lua, no `tools/` directory, no authored generator (`git ls-files '*.py' '*.sh'` returns only the vendored `tests/_kit/run-automated-tests.sh`).
- `media/logos/` (logo art, including `bankledger.logo.128.tga`) and `media/screenshots/`; no private fonts, icons or textures.
- **Authored-Lua census** (`layout-§1`'s scope): `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'` = **71** files, 26,810 lines by `wc -l`. **0 over the 1500 cap.** Four in the 1000–1500 band: `modules/Browser.lua` 1220, `modules/LedgerTable.lua` 1132, `tests/test_ledger.lua` 1028, `modules/Insights.lua` 1002.
- The census heading `### Files over the 1500-line cap` sits under `## Documented deviations` (`docs/ARCHITECTURE.md:511`) and reads "Nothing is over the cap today" — correct against the tree. The kit gate `tests/_kit/test_layout_cap.lua` is wired as `{ name = "test_layout_cap", dir = "tests/_kit/" }` (`tests/run.lua:37`) and is green.

## TOC (`toc-file`)

- Field order matches `toc-file-§1` exactly (`BankLedger.toc:1-13`). `## Interface: 120100` (single value) in lockstep with the README `[wow]` badge `Midnight_12.1.0`. `## IconTexture` names `media\logos\bankledger.logo.128.tga`; its header reads type **2**, **128×128**, **32 bpp** (`od -An -tu1 -N18`). `X-Curse-Project-ID: 1629058` (published; the README's CurseForge badge uses the same id).
- One SavedVariables global, `BankLedgerDB` — correct under the ratified `performance-§12` exemption (`toc-file-§2`).
- `# Libraries` lists each vendored library directly and `libs\LibKa0s\LibKa0s.xml` once, last (`:15-29`). Section headers in the mandated order.
- **Load-bearing annotations** (`toc-file-§5`), measured against the positions that actually resolve at file load: `core\ItemSetup.lua`, `core\MediaSetup.lua`, `core\CoreSetup.lua`, `core\DebugLogSetup.lua` and `settings\OptionsSetup.lua` are annotated. **Two are not**: `modules\Insights.lua` (`:85`, takes `NS.InsightsWidgets` at file scope) and `settings\Slash.lua` (`:90`, reads `NS.SchemaRuntime.*` at file load) — `BL-36`, `BL-42`.

## Libraries (`library-stack`)

- Ace3 (LibStub, CallbackHandler, AceAddon, AceEvent, AceTimer, AceConsole, AceDB, AceGUI), LibSharedMedia, LibDataBroker-1.1, LibDBIcon-1.0, and `libs/LibKa0s/` — vendored and committed.
- **Provenance line** in root `CLAUDE.md:46`: `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).` Exactly one hit in `CLAUDE.md`, none in `README.md`.
- **Vendored payloads are byte-identical to `v1.55.0`**: `diff -r --strip-trailing-cr` of the tag's `LibKa0s/` and `testkit/` against `libs/LibKa0s/` (146 files) and `tests/_kit/` (11 files) is empty, and a `git hash-object` comparison of every worktree file against the tag's blob sha reports no mismatch. `tests/_kit/run-automated-tests.sh` is recorded `100755`.
- **LibKa0s seams** (one setup file per wired module): `core/EnvSetup.lua`, `core/ItemSetup.lua`, `core/MediaSetup.lua`, `core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `core/LifecycleSetup.lua`, `core/PoolSetup.lua`, `core/LauncherSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua`. The three v1.55.0 majors: **Schema** adopted (`settings/Schema.lua:441`, with a runtime-completing stub citing the API document, `:443-458`); **Bus** — only `Catalog` adopted (`core/Constants.lua:259`), the untracked factory `NS.NewBusTarget` kept (`core/BankLedger.lua:20-26`); **Compat** declined in closed issue #20 (no member overlaps; v2.64.0 requires none of the three). `LibKa0s-Widgets-1.0` is resolved directly in `modules/Browser.lua:5` and `modules/Export.lua:14`.
- Shared media: `core/MediaSetup.lua` passes its own first vararg to `Media.Icon`/`Media.Font` and makes the single `Media.RegisterLSM(addonName)` call at file load (`:109`).

## Patterns (`architecture`, `savedvariables`, `compat`)

- `local addonName, NS = ...` bootstrap; `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")` with `NS.Print` reclaimed from `NS.Util.print` (`core/BankLedger.lua:4-13`).
- **Bus:** four messages declared once in `core/Constants.lua` (`:281-289`) through `LibKa0s-Bus-1.0`'s strict `Catalog`, PascalCase tails, one sender each, documented in `docs/ARCHITECTURE.md:264-296`. Receivers register on private `NS.NewBusTarget()` targets. Literal wire names appear at call sites only in test files — `BL-49`.
- **Schema-as-single-source:** 8 host rows in `settings/Schema.lua:31-124` plus 8 composed Master-controls rows spliced at the head (`:315-350`); one write seam (`NS.SchemaRuntime.Set`). One structural registry (`blacklist`/`whitelist`, writer `NS.Filters`), recorded data (`db.global.ledger`, owner `NS.Database`) and four pieces of named non-setting state are named in `docs/ARCHITECTURE.md:140-210`. A write-path grep over `core/ modules/ settings/ defaults/` finds no unnamed writer.
- **SavedVariables:** account-wide `global` only, `NS.SCHEMA_VERSION = 2` (`core/Namespace.lua:13`), migration runner `NS:RunMigrations` in `core/Database.lua`. `defaults/Profile.lua` absent under the ratified `savedvariables-§2` row.
- **Compat:** `core/Compat.lua` publishes **13** shims (`grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` → 13); `docs/compat-layer.md` present.

## Settings (`options-ui`)

- `NS.Helpers` **is** the `LibKa0s-Options-1.0` instance (`settings/OptionsSetup.lua`), with a load-completing stub whose five composers answer empty lists (`:203-207`).
- Two pages: the landing page (host `buildMain`, exempt from the strip) and **General**, tabbed: **Master controls · Capture · Interface · History · Filters**, rows 8 · 4 · 3 · 1 · 1 (`Filters` is one renderer-only row with a secondary Blacklist/Whitelist strip, session-only selection). Master controls is composed with `minimapPath` and `testModePath`; not frameless (`SetMovable(true)` at `modules/Browser.lua:1016`, `modules/SessionWindow.lua:449`, `modules/Export.lua:347`).
- No color rows, no LSM media rows, no reorder arrows, no `disabledIf`. The grep for `SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory` outside `libs/` and `tests/_kit/` hits only test files; the open and the combat lock are the library's.
- **Global reset:** *Reset all settings* (Master controls) raises `KA0S_BANKLEDGER_RESETALL`, whose text is `options-ui-§12`'s second canonical wording verbatim (`settings/Slash.lua:33-34`), and runs `Sl:ResetEverything` — `db.global` wiped wholesale, ledger included, `minimap` held across. The page's **Defaults** button (and Blizzard's footer control through `OnDefault`) and `/bl resetall` run `Sl:CliResetAll` instead — a schema walk plus filter and saved-view clears that leaves the ledger alone. Recorded in the register as the `options-ui-§12` row, whose re-check trigger has fired — `BL-34`.

## Slash (`slash-commands`)

- `/bl`, alias `/bankledger`, registered through AceConsole (`settings/Slash.lua:274-277`); `LibKa0s-Slash-1.0` dispatcher from a descriptor (`:418-479`); `NS.COMMANDS` in `settings/Schema.lua:641-722` holds **17** verbs, positional triples; `enable`/`disable` are aliases onto `settings.enabled` through `CliSet` (`settings/Slash.lua:202-215`).
- **Disabled state (`slash-commands-§7`):** `LibKa0s-Lifecycle-1.0` latch in `core/LifecycleSetup.lua`; one teardown body `NS.StandDown` (`core/BankLedger.lua:146-191`) cancelling every AceTimer and module handle, `UnregisterAllEvents` on the addon object, unregistering and dropping the four private bus targets, hiding both windows with the show ladder refusing at the source. The slash surface keeps every reserved verb live (no `liveVerbs` passed, `:423-429`); feature verbs refuse on the library's one line; the launcher's left click refuses and right click opens the panel (`core/LauncherSetup.lua:156`). The survivors are the panel's own refresh subscriptions (recorded, not ruled, `open-evolutions`), the `HookScript` on the guild-bank frame (one-way API, gated), and **one `C_Timer.After(5)`** that is gated rather than cancelled — `BL-46`.
- Conformance suite `tests/test_disabled.lua` (569 lines) is listed in `tests/run.lua:30`, asserts on the kit's recording registry, and carries falsification comments at every negative step.

## Debug (`debug-logging`)

- `core/DebugLogSetup.lua` builds `NS.DebugLog` from a descriptor passing both `name` and `addonName` (`:61`, `:74`) and `FONT_MONO` from the media seam (`:76`); stub on the absent branch. Two structured dump verbs, `/bl debug scan` and `/bl debug panel` (`settings/Schema.lua:708-721`).

## Tests (`testing`)

- Kit revision 25 (LibKa0s v1.55.0) at `tests/_kit/`, byte-identical to the tag. `tests/run.lua` declares 36 addon suites plus three kit suites by `(name, dir)` (`:24-37`); no raised budgets.
- **Run:** `ka0s-bounded lua tests/run.lua` → **1017 passed, 0 failed, 0 skipped, 1017 total**, exit 0. The vendor-sync gate ran (the sibling LibKa0s checkout is present). `docs/test-cases.md` total and the README badge both read **1017**.
- **Lint:** `ka0s-bounded luacheck .` → **0 warnings / 0 errors in 71 files** — the same 71 the authored census counts. `exclude_files` narrows to `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/` (`.luacheckrc:10`); the harness global `_G.BL_TEST` is in a `files["tests/"]` stanza (`:70-71`); no top-level `ignore`; no `debugprofilestop` or `BankLedgerPerfDB` (correct under the exemption).

## Performance (`performance`)

- **Exempt** under a ratified `performance-§12` row (`docs/ARCHITECTURE.md:501`, decided 2026-08-05); the committed sweep lives in `docs/performance.md:37-60` and now names the combat-edge pair. No `PerfSetup.lua`, no `perf` verb, no `tests/perf.lua`, no `docs/perf-analysis/`.
- **Complexity (measured):** `ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` → **17,397 NLOC, 2,640 functions, avg NLOC 5.9, avg CCN 2.0, max CCN 15, 0 warnings.**
- **Record:** newest bundle `docs/automated-tests/20260916-184426/` (manifest sha `076f674`, clean), **37 commits** behind HEAD (`git rev-list --count 076f674..HEAD`) and dated seven days ago. Drift since it: tests 943 → 1017, lint files 67 → 71, NLOC 16,380 → 17,397, functions 2,498 → 2,640, band files 3 → 4 (`modules/Insights.lua` entered at 1002), warnings 0 → 0. The checkpoint is release (`automated-tests-§6`); the last release run was `20260910-234511` (`"release": "1.1.0"`). No row carries the commit cells yet: every row predates kit revision 25, which arrived today, so they carry forward as *unknown* — a fact about the record, not a finding.
- **Watch list:** 0 warned functions; band table dispositions: 1 tracked (`BL-24`), 2 *Accepted*, each carried across one release run — below `anti-patterns` #53's three. The one refactor since the last audit that the watch list drove (`6592b51`, `Sl:ResetEverything` → `refreshAfterReset`) is a named file-local helper for a nameable block (`performance-§11` shape 2), built at file scope.
- The generated Perf standing section and the manifest record the perf skip as *"no tests/perf.lua"* and say it is *not* a `performance-§12` exemption — `BL-48`.

## Packaging (`packaging`)

- `.pkgmeta` has no `externals:`; ignores `.luacheckrc`, `.gitignore`, `.gitattributes`, `.pkgmeta`, `docs`, `tests`, `_dev`, `*.bak`, `.superpowers` (present, untracked), `CLAUDE.md`, `DEPENDENCIES.md`, `media/screenshots`, `media/logos/*.png|*.jpg`. Checks (a) and (c) print nothing; (b) prints only `.git`. `.pkgmeta:17` and `:22` cite the standard as `packaging.md:28` — `BL-50`.

## `.gitattributes` (`line-endings`)

- Present at root; the pin `* text=auto eol=crlf` (`:26`); `*.sh text eol=lf` and `*.py text eol=lf` (`:36-37`); 23 `binary` marks. The first 84 lines diff **clean** against `line-endings-§5`'s client-bound body (extracted from the fetched section, 84 lines) and nothing follows the body. Working tree: the `line-endings-§7` (e) one-liner over the whole tracked set (458 files) reports **0** strays; the kit's `tests/_kit/test_eol.lua` (both cases) is green.

## Root docs (`documentation-§1/§2/§7`)

- `README.md` (164 lines): H1, the five badges in order with the standard badge **bare** (`:6`), description, Screenshots, Usage (prose, no command or settings table), How the ledger works, FAQ, Troubleshooting, Issues and feature requests, Version History (highlights prefixed `- `). No logo image, no library inventory, no provenance line, no `## Credits`.
- `CLAUDE.md`: stub with H1, adherence line, `## Standards compliance (read first)`, doc pointers, green gate, provenance line (`:46`).
- `DEPENDENCIES.md`: runtime / development / release groups, WSL2 commands, `pipx` for `lizard`, a verification line per tool.

## `docs/` (`documentation-§3`)

- **Tier 1:** all six present under the canonical names.
- **Tier 2:** `slash-dispatch.md` present (17 verbs), `midnight-quirks.md` present, `compat-layer.md` present (13 shims); `message-bus.md` N/A (4 messages), `profiles.md` N/A (no profile control), `perf-analysis/README.md` N/A (exemption). `debug.md` is recorded N/A although the addon ships two structured dump verbs beyond the default console — `BL-44`.
- **Documentation map** (`docs/ARCHITECTURE.md:440-487`): four tables in the mandated order (Required with the optional hub self-row, Conditional, Verification and record with exactly the six, Addon-specific: `windows.md`, `insights.md`, `media.md`); the frozen stores `audits/`, `reviews/`, `automated-tests/`, `revendor/`, `superpowers/` named once. Every `.md` under `docs/` outside those stores has exactly one row and every row resolves. No non-canonical Tier 1/2 filenames, no `file-index.md`, `conventions.md`, `complexity.md`, `docs/perf-runs/`, `docs/pending/` or `agent-context.md`.
- **Hub shape:** `docs/ARCHITECTURE.md` is **522** lines; its `## Settings Schema` section runs 167 lines (`:45-211`) — `BL-43`.

## Deviation register (`docs/ARCHITECTURE.md:489-522`)

Read first, as `audit-review-history` requires. Five rows:

| Rule | Decided | Evidence ids | Trigger evaluated against this tree |
|---|---|---|---|
| `performance-§12` | 2026-08-05 | issue #9 (`LIBKA0S-17` in its body) | Not fired: no `OnUpdate`, no repeating ticker; the combat-edge pair is bounded and named in the sweep. The row's own *Why* sentence is stale (`BL-45`). |
| `savedvariables-§2` | 2026-07-27 | — | Not fired: no per-profile setting. |
| `localization-§1` | 2026-07-31 | issue #3, `BL-04` in `docs/audits/2026-09-07/` (both resolve) | Not fired: `locales/` holds `enUS.lua` and `PostLoad.lua` only. |
| `standalone-windows` | 2026-08-06 | `BL-28` in `docs/audits/2026-09-07/`, issue #5 (both resolve) | Not fired: the close-button grep returns one host factory (`modules/Browser.lua:95`) and its three callers; all four conditions hold. The row's line numbers have drifted (`BL-45`). |
| `options-ui-§12` | 2026-09-02 | — | **Fired**: *"Re-check at the next release"* — `1.1.0-release` was tagged 2026-09-11. `BL-34`. |

No row's cited rule has changed in a way that makes the recorded behavior mandated or permitted outright.

## Issue store (`audit-review-history`)

`gh issue list --state all --limit 200 --json …` → 20 issues, every one carrying one `state:` and one `severity:` label, no `[status]` title prefix. Open: #1, #2 (`state:triaged`, enhancements) and **#3** (`state:triaged`, asks for the `localization-§1` row that has existed since `M5-02`) — `BL-39`. The `state:will-not-do` issues (#4–#10, #15, #20) decline library adoptions or scope, not a rule, except #5 and #9, whose decisions carry register rows.

## Re-vendor store (`audit-review-history`)

`docs/revendor/` holds eight bundles, the oldest `2026-08-25`. Since that horizon `git log -- libs/LibKa0s` finds 36 vendoring commits carrying 31 distinct tags; the bundles record 8 tags. **25 vendored tags have no bundle and no register row** — `BL-41`.
