# 01 · Current state — Ka0s Bank Ledger — 2026-10-07

## Run facts

| | |
|---|---|
| Standard | **Ka0s WoW Addon Standard v2.76.1 (2026-10-07)**, resolved from `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` with `curl -fsSL`: `AUDIT.md` (1156 lines), `standards/STANDARDS.md`, all **27** section files its Sections list links (6,576 lines together), and `standards/ADDONS.md`. Every fetch succeeded. Each fetched section file and `AUDIT.md` is byte-identical to the sibling `../WowAddonStandards` checkout at `f472389` (`diff -q`, no output). |
| Repo kind | **Addon.** `dev-copilot-profile` reports `kind=addon` (`reason=toc:## Interface`); the repo has a `.toc` (`BankLedger.toc`), and `standards/ADDONS.md:21` lists it in the in-scope addons table with launcher menu entries *Enabled · Locked · Test mode · Show window (the ledger browser)*. The detector and the table agree. The addon rule set applies: every section plus `anti-patterns`. |
| Checkout | `/mnt/d/Profile/Users/Tushar/Documents/GIT/BankLedger`, branch `feat/2026-10-07-review-audit-remediation`, HEAD `662221b02af2984e54c122cf82da23609bee95e1` (merge of `feat/2026-10-07-autocomplete-typesubtype`), tree clean at the start of the run. 593 tracked files. |
| Tags | `1.0.0-release`, `1.1.0-release`, `1.2.0-release` (2026-09-27, `5cc9c87`). TOC `## Version: 1.2.0`. |
| Bounded runner | `~/.claude/dev-copilot/bin/ka0s-bounded` (symlink into the dev-copilot 2.0.1 plugin cache). Every `lua tests/run.lua`, `luacheck`, complexity-suite and `lizard` run below went through it. |
| Prefix | `BL-` (reused). `BL-01`…`BL-51` exist in earlier bundles; this run reuses `BL-41`, `BL-45`, `BL-51` and adds **`BL-52`**, **`BL-53`**. |
| Prior bundle | `docs/audits/2026-09-23/`, audited against v2.64.0. This run re-measures from the fetched v2.76.1 sections and inherits no verdict. 132 commits have landed since that bundle. |

## Layout (`layout`)

- Source under `core/` (15 files), `defaults/` (2), `locales/` (2), `modules/` (12), `settings/` (5) — 36 shipped Lua files. No loose root Lua, no `tools/`, no authored generator: `git ls-files '*.py' '*.sh'` returns only the vendored `tests/_kit/run-automated-tests.sh`.
- `media/` holds `logos/` and `screenshots/` only — no private `fonts/`, `icons/` or `textures/` (`layout-§3`, anti-pattern #63).
- **Authored-Lua census** (`layout-§1`'s scope): `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'` = **87** files, 34,166 lines. **0 over the 1500 cap.** In the 1000–1500 band: `modules/Browser.lua` **1427**, `tests/test_browser.lua` 1059, `tests/test_profiles.lua` 1010, `modules/Insights.lua` 1004.
- The census heading `### Files over the 1500-line cap` sits under `## Documented deviations` (`docs/ARCHITECTURE.md:453`) and reads "Nothing is over the cap today" — correct against the tree. Its supporting prose figure is stale (`:460` says Browser is 1328; it is 1427) — `BL-45`. The kit gate is wired as `{ name = "test_layout_cap", dir = "tests/_kit/" }` (`tests/run.lua:37`) and green.

## TOC (`toc-file`)

- Field order matches `toc-file-§1` (`BankLedger.toc:1-13`). `## Interface: 120100`, in step with the README `[wow]` badge `Midnight_12.1.0` (`README.md:3`). `X-Curse-Project-ID: 1629058`, matching the CurseForge badge (`README.md:4`).
- `## IconTexture: Interface\AddOns\BankLedger\media\logos\bankledger.logo.128.tga` (`:6`). Header (`od -An -tu1 -N18`): type **2**, **128×128**, **32** bpp — compliant (`toc-file-§1`, `layout-§4`, anti-pattern #82 not applicable).
- One SavedVariables global, `BankLedgerDB` (`:7`) — correct under the ratified `performance-§12` exemption (`toc-file-§2`).
- `# Libraries` lists Ace3, LibSharedMedia, LibDataBroker, LibDBIcon and `libs\LibKa0s\LibKa0s.xml` **once**, last (`:15-31`), never an individual LibKa0s `.lua` (anti-pattern #48 not present).
- **Load-bearing annotations** (`toc-file-§5`): `core\ItemSetup.lua`, `core\MediaSetup.lua`, `core\CoreSetup.lua`, `core\DebugLogSetup.lua`, `modules\Insights.lua` (comment `:98` above the line at `:99`, "LOAD-BEARING: modules/Insights.lua takes NS.InsightsWidgets …"), `settings\Slash.lua` (comment `:107` above `:108`, "LOAD-BEARING: hands NS.SchemaRuntime's members to LibKa0s-Slash …"), `settings\OptionsSetup.lua`; every conventional seam since added (`Ledger_Diagnose`, `Backfill`, `LedgerTable_TestMode`, `Diagnostics`, `Profiles`) carries a "conventional" comment. The 2026-09-23 findings `BL-36` and `BL-42` are closed.

## Libraries (`library-stack`)

- **Provenance line**: `CLAUDE.md:46` — `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).` Exactly one hit in `CLAUDE.md`, none in `README.md`.
- **Vendored payloads are byte-identical to `v1.70.0`** (`26f441a`): `git archive v1.70.0 LibKa0s testkit` from `../LibKa0s`, then `diff -r` against `libs/LibKa0s/` (159 files each side) and `tests/_kit/` (22 files each side) — both exit 0, no output, without `--strip-trailing-cr`. Kit revision **37** (`tests/_kit/framework.lua:20`).
- **LibKa0s seams** (one setup file per wired major, each a `LibStub(…, true)` lookup plus a library-absent branch): Env (`core/EnvSetup.lua:39`), Item (`core/ItemSetup.lua:26`), Media (`core/MediaSetup.lua:45`), Core (`core/CoreSetup.lua:58`), DebugLog (`core/DebugLogSetup.lua:21`), Lifecycle (`core/LifecycleSetup.lua:41`), Pool (`core/PoolSetup.lua:20`), Launcher (`core/LauncherSetup.lua:70`), Bus `Catalog` (`core/Constants.lua:265`), Schema (`settings/Schema.lua:516`), Slash (`settings/Slash.lua:226`), Options (`settings/OptionsSetup.lua:26`); Widgets resolved directly at `modules/Browser.lua:5` and `modules/Export.lua:14` (the dropdown, the copy window and, since today, `Autocomplete`). `LibKa0s-Compat-1.0` declined in closed issue #20 — not required at v2.76.1 (`library-stack-§7`).
- No host console, widget-maker, dispatcher or test framework (anti-pattern #47 not present). Shared media: `core/MediaSetup.lua` passes its own first vararg; the Options descriptor passes `addonName = addonName` (`settings/OptionsSetup.lua:41`, `options-ui-§1` v2.75.0).

## Patterns (`architecture`, `savedvariables`, `compat`)

- `local addonName, NS = ...` bootstrap; `NS.bus = addon` (`core/BankLedger.lua:6`).
- **Bus:** four messages declared once (`core/Constants.lua:287-295`), PascalCase tails. `AUDIT.md`'s call-site literal grep over shipped and test Lua (vendored trees excluded) returns **nothing** — `BL-49` closed. The two remaining `"Ka0s_…"` strings in tests are a deliberate unknown name (`tests/test_bus.lua:157`) and the mock's scratch message (`tests/test_mock.lua:309`), neither at a call site.
- **SavedVariables:** settings moved into **AceDB profiles** (`SP-BL-01`, `d72e356`); `defaults/Profile.lua` now ships; the ledger and the retention window stay account-wide (`defaults/Global.lua`). `NS.SCHEMA_VERSION = 5` (`core/Namespace.lua:13`), runner walks `NS.MIGRATIONS` (`core/Database.lua:241-249`); v5 split `savedView` into per-tab `savedViews` today (`core/Database.lua:185-210`).
- **Write paths (`architecture-§5`):** every non-helper write is classified and named — the id-list registry (`modules/Filters.lua:89-132`, writer `NS.Filters`), recorded data (`core/Database.lua:903,916,981`, owner `NS.Database`), window geometry (`modules/Browser.lua:192`, `modules/SessionWindow.lua:323`) and per-tab saved views (`modules/Browser.lua:749,912`) are named in `docs/schema.md:299-350` with their owners and writers. No unnamed writer.
- **Compat:** `core/Compat.lua` publishes **13** shims (`grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` → 13); `docs/compat-layer.md` present.
- **Events (`events-frames-taint-§1`):** every registration goes through `NS.RegisterEventSafely` (`core/CoreSetup.lua:193-194`), which calls `lib.SafeRegisterEvent` — the `C_EventUtils.IsEventValid` front gate plus `pcall` — and writes `NS.EventRecord`, printed by `/bl debug scan`. `BL-47` closed.

## Settings (`options-ui`)

- `NS.Helpers` is the `LibKa0s-Options-1.0` instance (`settings/OptionsSetup.lua`), descriptor passing `addonName` (`:41`) and `debug = NS.DebugSink` (`:46`); load-completing stub on the absent arm.
- Pages: the landing page (host `buildMain`, exempt from the strip), **General** — **Master controls · Capture · Interface · History · Filters** — and the AceConfig-drawn **Profiles** sub-page (`settings/Profiles.lua`, exempt). Master controls is composed from `S.MASTER_SPEC` (`settings/Schema.lua:254-288`) with `minimapPath` and `testModePath`; not frameless (`SetMovable(true)` in each window builder).
- No color rows, no LSM media rows, no reorder arrows, no `disabledIf` (grep over `settings/` empty). `SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory` over shipped Lua: **no hits**.
- **Global reset (`options-ui-§12`):** one act — *Reset all settings*, both Defaults controls, the Profiles page's Reset Profile and `/bl resetall` all raise `KA0S_BANKLEDGER_RESETALL` and reset the active profile (`settings/Schema.lua:815-820`). The expired `options-ui-§12` register row is gone. `BL-34`/`BL-34a` closed.

## Slash (`slash-commands`)

- `/bl`, alias `/bankledger`; `LibKa0s-Slash-1.0` dispatcher from a descriptor (`settings/Slash.lua:368-449`); `NS.COMMANDS` (`settings/Schema.lua:795-896`) holds **19** verbs. `enable`/`disable` are aliases onto `settings.enabled` through `Sl:CliEnabled` (`:808-809`).
- `liveVerbs` = `lib.LIVE_VERBS` plus `profile` (`settings/Slash.lua:364-366`, `:380`); the library-absent gate reproduces the same thirteen reserved verbs plus `profile` (`:304-309`). Every reserved verb answers while disabled — `slash-commands-§2` (v2.57.0 surface).
- **Diagnostics (`debug-logging-§14`):** exactly one `"diagnostics"` row (`settings/Schema.lua:892`); `debug` tests `diagnostics` first (`:869`); no `diag`/`dump`/`dx` (grep empty); no host `SetEnabled` around `RunDiagnostics`; `modules/Diagnostics.lua` calls no `Clear()`. README `## Reporting a bug` is verbatim (`README.md:132-138`), between Troubleshooting and Issues.

## The disabled state (`slash-commands-§7`)

- **Teardown:** one body, `NS.StandDown` (`core/BankLedger.lua:255`), reached from the `LibKa0s-Lifecycle-1.0` latch (`core/LifecycleSetup.lua:54-64`, hold `disabled`) and AceAddon's `OnDisable` (`:272`). No second, parallel teardown; the addon takes no `perf` hold under its exemption (`core/LifecycleSetup.lua:29-31`).
- **Registration census** (`git ls-files '*.lua' ':!libs' ':!tests'`): the addon object's events (`NS.StandUp`, `:132-137`; the Ledger's capture set; Backfill's transient `GET_ITEM_INFO_RECEIVED`) are undone by `UnregisterAllEvents` (`:194`); the four private bus targets by `dropBusTarget` (`:216-224`); every AceTimer by `CancelAllTimers` plus each module's `CancelPending` (`:178-185`). Survivors: the two gated `HookScript` bodies on `GuildBankFrame` (`modules/Ledger.lua:667-682`, no un-hook — the sanctioned carve-out), the window frames' own `HookScript`s (frames hidden), AceDB's profile callbacks (setup), and the panel's own refresh subscriptions (`settings/Panel.lua:169-170,492`, recorded as open in `open-evolutions`). The one `C_Timer.After` (`core/ItemSetup.lua:67`) is on the library-absent arm and is armed only when a caller passes a callback — none does (`docs/performance.md:49`).
- **Writes from game events while disabled:** none found; the combat-entry handler is unregistered with the rest.
- **Conformance suite:** `tests/test_disabled.lua` (857 lines), listed in `tests/run.lua:30`, asserts on the kit's recording registry (`mocks.__registrations()`, `__timers()`, `__shownFrames()`, `__svWrites()`), and `tests/wow_mock.lua:636` now lets the kit record `C_Timer.After` — `BL-46`/`BL-46a` closed.

## Launcher (`launcher`)

- One object, built by `LibKa0s-Launcher-1.0` (`core/LauncherSetup.lua:135-240`): `label = NS.BRAND_NAME` = `"Ka0s Bank Ledger"` (`:95`); `minimap` resolved from `db.global.minimap` at Register time; `openSettings` for left-click; `isEnabled`/`setEnabled`, `isLocked`/`toggleLock`, `isTestMode`/`toggleTestMode`, `isWindowShown`/`toggleWindow` — exactly the four entries `ADDONS.md:21` lists, each toggle calling a `NS.COMMANDS` handler. `onTooltipShow` adds only the movement count; `debug` and `debugAtEnable` are passed (`:232`, `:239`). The stub answers all five members the addon calls.

## Debug (`debug-logging`)

- `core/DebugLogSetup.lua` builds `NS.DebugLog` from a descriptor passing `addonName` (`:95`) and the monospace face from the media seam; the stub answers `RunDiagnostics`, `BuildDiagnostics`, `DebugOnce`, `DebugChanged`, `DebugForget` and `DebugAtEnable` (`:50-63`). Library debug lines adopted (`DG-BL-01`): every descriptor that takes `debug` is given `NS.DebugSink`; change gates use `D.DebugChanged` (`modules/Ledger.lua:501`).

## Tests and lint (`testing`, `lint`)

- `ka0s-bounded lua tests/run.lua` → **1258 passed, 0 failed, 1 skipped, 1259 total**, exit 0. The skip is the kit's declared opt-out case in `test_diagnostics_contract` (this addon keeps the default). The vendor-sync gate ran.
- `README.md:7` badge reads **1258/1258**; `docs/test-cases.md:1472` Totals reads **1259**, counting the declared skip — `BL-53`.
- `ka0s-bounded luacheck .` → **0 warnings / 0 errors in 87 files** — the same 87 the authored census counts. `exclude_files` narrows to `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/` (`.luacheckrc:10`); harness global in `files["tests/"]` (`:71`); no top-level `ignore`; fourteen `212/self` per-file stanzas, each named in `docs/testing.md:43`.

## Performance and complexity (`performance`, `automated-tests`)

- **Exempt** under the ratified `performance-§12` row (`docs/ARCHITECTURE.md`, `## Documented deviations`, decided 2026-08-05). The sweep (`docs/performance.md:37-54`) names every registration and timer, the new transient backfill event included. No `OnUpdate`, no repeating ticker. Trigger not fired.
- **Complexity, measured** (`ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`): **22,650 NLOC, 3,628 functions, avg CCN 2.0, max CCN 16, 1 warning** — `LT.GroupEntries` (`modules/LedgerTable.lua:320-364`), CCN **16** — `BL-52`.
- **Record:** newest bundle `docs/automated-tests/20260927-031851/` (commit `b97fd24`, clean), **67 commits** behind HEAD, ten days old. Its manifest carries **no** `blindFiles` — it predates kit revision 35 (vendored 2026-10-01), so **no sighted run has been recorded yet**. Drift since it: NLOC 19,210 → 22,650, functions 2,920 → 3,628, max CCN 15 → 16, warnings 0 → 1, band files 2 → 4 (`tests/test_browser.lua` and `tests/test_profiles.lua` entered; `modules/Browser.lua` 1221 → 1427, `modules/Insights.lua` 1002 → 1004). The checkpoint is release; no release has been cut since `1.2.0`.
- **Watch list:** two *Accepted* band entries — `modules/Browser.lua` (tracked as `BL-24`, so `anti-patterns` #53 is discharged) and `modules/Insights.lua` (one release run). Neither has run three releases untracked.

## Packaging (`packaging`)

- `.pkgmeta`: no `externals:`; ignores `.luacheckrc`, `.gitignore`, `.gitattributes`, `.pkgmeta`, `docs`, `tests`, `_dev`, `*.bak`, `.superpowers`, `CLAUDE.md`, `DEPENDENCIES.md`, `media/screenshots`, `media/logos/*.png|*.jpg`. Check (a) prints nothing, (b) prints only `.git`, (c) prints nothing. `.pkgmeta:17,22` now cite `packaging` bare — `BL-50` closed.

## `.gitattributes` (`line-endings`)

- Present; pin `* text=auto eol=crlf` (`:26`); `*.sh text eol=lf` (`:36`) and `*.py text eol=lf` (`:37`); 20 `binary` lines. The 84-line body diffs **clean** against `line-endings-§5`'s client-bound canonical body (extracted from the fetched section, 84 lines); nothing follows it.
- Working tree: the (e) one-liner over the whole tracked set (593 files) prints **0**. The kit's `tests/_kit/test_eol.lua` is green.

## Root docs (`documentation-§1/§2/§7`)

- `README.md`: H1, the five badges in order, standard badge **bare** (`:6`), no logo image, no library inventory, no numbered list (`grep -nE '^[[:space:]]*[0-9]+[.)][[:space:]]' README.md` empty), `## Reporting a bug` verbatim, `## Credits` last with external credit only (JetBrains Mono, Open Iconic).
- `CLAUDE.md`: stub with `## Standards compliance (read first)`, doc pointers, green gate (no raw `lizard` command), provenance line (`:46`).

## `docs/` (`documentation-§3`)

- **Tier 1:** all six present under the canonical names.
- **Tier 2:** `slash-dispatch.md` Present (19 verbs ≥ 8); `midnight-quirks.md` Present; `compat-layer.md` Present (13 shims); `message-bus.md` N/A (4 messages); `profiles.md` **Present** (the Profiles page ships a profile control); `debug.md` Present (`BL-44` closed); `perf-analysis/README.md` N/A (exemption).
- **Documentation map** (`docs/ARCHITECTURE.md:385-432`): four tables in order (Required with the optional hub self-row, Conditional, Verification and record with exactly the six, Addon-specific `windows.md`, `insights.md`, `media.md`); frozen stores named once (`audits/`, `reviews/`, `automated-tests/`, `revendor/`, `superpowers/`). The 21 live `.md` files outside those stores each have exactly one row and every row resolves.
- No non-canonical Tier 1/2 filenames, no `file-index.md`, `conventions.md`, `complexity.md`, `docs/perf-runs/`, `docs/pending/` or `agent-context.md`.
- **Hub shape:** 464 lines. Every mandated section is under ~60 (*Settings Schema* `:46-88`, 43 lines — `BL-43` closed). Two non-mandated sections run longer (*Launcher* `:112-172`, *The stand-down* `:218-291`); the file is over the ~400 SHOULD — recorded as an observation, not filed.

## Deviation register (`docs/ARCHITECTURE.md:434-464`)

Read first. Three rows (the `savedvariables-§2` row retired with the profiles adoption, the `options-ui-§12` row with the single reset):

| Rule | Decided | Evidence ids | Trigger, against this tree |
|---|---|---|---|
| `performance-§12` | 2026-08-05 | issue #9 (resolves, `state:will-not-do`) | Not fired: no `OnUpdate`, no repeating ticker; the backfill event is registered only while its one-shot pass waits. |
| `localization-§1` | 2026-07-31 | issue #3 (closed `state:done`), `BL-04` in `docs/audits/2026-09-07/` (resolves) | Not fired: `locales/` holds `enUS.lua`, `PostLoad.lua`. |
| `standalone-windows` | 2026-08-06 | `BL-28` in `docs/audits/2026-09-07/` (resolves), issue #5 (resolves) | Not fired. All four conditions re-checked: host windows only; `NS.Icon("close")` inside `B:MakeCloseButton` (`modules/Browser.lua:109`); one factory (`:103`) and three callers (`:1253`, `modules/Export.lua:392`, `modules/SessionWindow.lua:511`); the row. |

No row's cited rule has changed so that the recorded behavior is now mandated or permitted outright. **One register claim exists outside the register**: `modules/LedgerTable.lua:28-30` calls the ▲/▼ mono glyph "an accepted, documented deviation … See docs/ARCHITECTURE.md ▸ Documented deviations", and no such row exists. It is not a missing row — `debug-logging-§2` now sanctions that use outright — so it is filed as stale prose under `BL-45`.

## Issue store (`audit-review-history`)

`gh issue list --state all --limit 200 --json number,title,state,labels` → **21** issues, every one with one `state:` and one `severity:` label, no `[status]` title prefix. Open: **#1** only (`state:triaged`, enhancement). `#3` is closed `state:done` (`BL-39` closed). The `state:will-not-do` issues (#4, #6, #7, #8, #10, #15, #20) decline library adoptions or scope, not a rule; #5 and #9 carry rows.

## Re-vendor store (`audit-review-history`)

`docs/revendor/` holds 21 bundles, the oldest `2026-08-25`. Since that horizon the payload walk resolves **52** distinct tags; the bundles record **50**. **Unrecorded: `v1.69.0`, `v1.70.0`** (commits `b5e638b` 2026-10-06 and `2c87997` 2026-10-07) — `BL-41`, recurring and narrowed from 25 tags.
