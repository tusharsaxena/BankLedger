# 03 · Evidence — Ka0s Bank Ledger — 2026-09-23

Every `file:line` below was re-read in this run and is quoted beside the citation. Every count names
the command that produced it and what that command covered. Working directory for every command is
the repo root, HEAD `3256d8c`, branch `feat/2026-09-23-review-audit-remediation`, tree clean.
`B` below abbreviates `/home/tushar/.claude/wow-addon/bin/ka0s-bounded` (not on PATH in this shell;
used by absolute path, so no `timeout 900` fallback was needed).

Line endings in this repo are CRLF on disk, so quoted lines were read through `tr -d '\r'`.

---

## E-00 · Standard resolution

```
RAW=https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master
curl -fsSL $RAW/AUDIT.md; curl -fsSL $RAW/standards/STANDARDS.md; curl -fsSL $RAW/standards/ADDONS.md
for f in <every standards/<file>.md the Sections list links>; do curl -fsSL $RAW/standards/standards/$f; done
```

27 section files fetched, none failed. `STANDARDS.md:1` → `# Ka0s WoW Addon Standard (v2.64.0, 2026-09-23)`.
`ADDONS.md` row: `| Ka0s Bank Ledger | … | **(a)** the ledger browser |`.

---

## E-01 · Re-vendor bundles (`BL-41`)

Commands, verbatim from `AUDIT.md`, run under `bash` (the tag is read from the `CLAUDE.md`
provenance line at each commit; bare-dated bundles from their `01_DELTA.md` first line):

```
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)        # → 2026-08-25
git log --since="$horizon" --format=%H -- libs/LibKa0s | …            # 36 commits
… | sort -uV > vendored.txt                                            # 31 tags
for b in docs/revendor/*/; do …; done | sort -uV > recorded.txt        # 8 tags
grep -vxF -f recorded.txt vendored.txt
```

Scope: every commit touching `libs/LibKa0s/` since the store's first bundle; the whole
`docs/revendor/` store.

- `git log --since=2026-08-25 --format=%H -- libs/LibKa0s | wc -l` → **36**
- vendored: `v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.25.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.55.0` (31)
- recorded: `v1.15.0 v1.25.0 v1.30.0 v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.55.0` (8)
- **unrecorded (25):** `v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0`

Bundle first lines: `2026-08-25/` → `# 01 — Delta: BankLedger vs LibKa0s v1.15.0`;
`2026-09-03/` → `… v1.24.0 → v1.25.0`; `2026-09-12/` → `… v1.29.0 → v1.30.0`;
`2026-09-12-v1.31.0/`, `-v1.32.0/`, `-v1.33.0/`, `2026-09-13-v1.34.0/`, `2026-09-23-v1.55.0/`
(`# 01 — Delta: LibKa0s v1.54.2 → v1.55.0`). None names a span. No register row mentions
`audit-review-history` (`docs/ARCHITECTURE.md:499-505`).

Sample of the vendoring commits (`git log --since=2026-08-25 --format='%h %cd %s' -- libs/LibKa0s`):
`cb79c2c 2026-09-22 Re-vendor LibKa0s v1.53.0` … `4077fb1 2026-08-26 Adopt options-ui-§12: Reset
Everything is wholesale…` (tag v1.18.0 at that commit).

---

## E-02 · The global reset and its expired row (`BL-34`, `BL-34a`)

- `git tag -l --format='%(refname:short) %(creatordate:short)'` → `1.0.0-release 2026-07-28`,
  `1.1.0-release 2026-09-11`; `git show -s 72606d8` → tag `1.1.0-release` on `243dfab 2026-09-11`.
- `docs/ARCHITECTURE.md:505` — the row: *"| `options-ui-§12` | The global reset is **three routes over
  two implementations**, not one act. …| 2026-09-02 | **The decision itself — this row is a placeholder
  for a resolution, not an exemption.** Re-check at the next release, or the moment a player reports
  losing history to *Reset all settings*, whichever comes first. …"*
- `settings/Schema.lua:336` — `StaticPopup_Show("KA0S_BANKLEDGER_RESETALL")` (the Master-controls
  *Reset all settings*).
- `settings/Slash.lua:37` — `OnAccept = function() Sl:ResetEverything() end,`
- `settings/Slash.lua:33-34` — `text = "Reset this addon to its defaults? Everything you have configured or recorded is " .. "discarded, for every character on this account — this cannot be undone.",`
- `settings/Slash.lua:184` — `for k in pairs(g) do g[k] = nil end` (the wholesale wipe; ledger included).
- `settings/Slash.lua:193` — `if LT and LT.IsTestMode and LT:IsTestMode() then LT:SetTestMode(false) end`
  (test mode ended by name; nothing touches `state.debugConsole` in `:161-197`).
- `settings/Panel.lua:697` — `if NS.Slash and NS.Slash.CliResetAll then NS.Slash:CliResetAll() end`
  (`P:RestoreDefaults`, the page Defaults and — through `setDefaultsAction`, `:761` — Blizzard's footer control).
- `settings/Slash.lua:514` — `if NS.Filters and NS.Filters.ClearAll then NS.Filters:ClearAll() end`
  (`Sl:CliResetAll`, reached by `/bl resetall`, `settings/Schema.lua` `NS.COMMANDS` `resetall` row).
- `settings/Schema.lua:326-330` — *"`/bl resetall` does NOT reach this, and neither does the
  header/footer Defaults button … options-ui-§12 wants all three behind ONE implementation; they are not."*

---

## E-03 · TOC annotations (`BL-36`, `BL-42`)

Denominator: positions where something resolves at file scope. Found with, for every TOC-listed
source file in order, `grep -oE '^local [A-Za-z_, ]+ *= *NS\.[A-Za-z_]+'` plus a read of each
`*Setup.lua` and `core/Constants.lua`. Annotated load-bearing lines: `BankLedger.toc:41-44`
(ItemSetup), `:45-48` (MediaSetup), `:51-53` (CoreSetup), `:54-57` (DebugLogSetup), `:91-93`
(OptionsSetup).

- `BankLedger.toc:84` — `modules\InsightsWidgets.lua`; `:85` — `modules\Insights.lua` (no comment on
  either; group header `:78` — `# Modules (Filters before Ledger — the capture gate reads the lists)`).
- `modules/InsightsWidgets.lua:2` — `NS.InsightsWidgets = NS.InsightsWidgets or {}`
- `modules/Insights.lua:5` — `local W = NS.InsightsWidgets`
- `BankLedger.toc:89` — `settings\Schema.lua`; `:90` — `settings\Slash.lua` (no comment on either;
  group header `:88` — `# Settings (last — depend on everything else being initialized)`).
- `settings/Schema.lua:580` — `NS.SchemaRuntime = inst`
- `settings/Slash.lua:438` — `get          = NS.SchemaRuntime.Get,` (through `:454`, `bulkEnd`), inside
  `local cli = lib:New({` at `:418`, which runs at file load.
- `settings/Slash.lua:452` — `-- O.RestoreAllDefaults. Direct references are safe because the TOC loads settings/Schema.lua first.`
- `BankLedger.toc:91` — `# The LibKa0s-Options seam. After the schema and the write seam it reads, and BEFORE`
  (the sibling that does carry the annotation).
- `git log --format='%h %ad %s' --date=short -1 0d9d1e6` → `0d9d1e6 2026-09-23 Run the settings schema on LibKa0s-Schema-1.0`.

---

## E-04 · Hollow composer counts (`BL-37`)

- `settings/OptionsSetup.lua:203` — `MasterControls = function() return {}, function() end end,` (and
  `ColorPair`, `FontGroup`, `BorderGroup`, `BarGroup` at `:204-207`).
- `settings/Schema.lua:31-124` — `S.Schema`: `settings.trackItems`, `settings.trackMoney`,
  `settings.qualityThreshold`, `settings.excludedStores`, `settings.showSessionWindow`,
  `settings.rowStripeAlpha`, `settings.rowHoverAlpha`, `settings.retentionDays` → **8** host rows.
- `tests/test_schema.lua:241` — `{ tab = "Master controls", rows = 8 },` and `:284-290` the eight
  composed paths (`settings.enabled` … `state.testMode`) → **16** fully loaded, **8** absent, delta **8**.
- `grep -rnE 'hollow' tests/*.lua` → nothing; `grep -nE 'MasterControls' tests/test_surface_parity.lua`
  → only the comment at `:216`. No case pins the absent count or the delta.

---

## E-05 · Close-factory census and the `standalone-windows` decline (`BL-28`, `BL-38`, `BL-45`)

```
git ls-files '*.lua' ':!libs' | grep -v '^tests/' | xargs grep -n 'MakeCloseButton('
```
Scope: authored Lua outside `libs/` and `tests/`.

```
modules/Browser.lua:95:function B:MakeCloseButton(parent, onClick)
modules/Browser.lua:1056:  local close = B:MakeCloseButton(titleBar, function() B:Hide() end)
modules/Export.lua:362:    local close = NS.Browser:MakeCloseButton(tbar, function() frame:Hide() end)
modules/SessionWindow.lua:485:    local close = NS.Browser:MakeCloseButton(titleBar, function() SW:Hide() end)
```

- `modules/Browser.lua:101` — `local path = NS.Icon and NS.Icon("close")`
- `core/CoreSetup.lua:117` — `` -- `lib.MakeCloseButton` IS DELIBERATELY NOT REPUBLISHED, … `` and
  `:119-120` — *"all three of its title bars (ledger, session, export modal) go through that one factory."*

`BL-38` census:
```
git ls-files | grep -vE '^(libs/|tests/_kit/|docs/(audits|reviews|automated-tests|revendor|superpowers)/)' \
  | xargs grep -nE 'four title bars|all four of its title bars|export-copy title bars|all four go through|one edit, four title bars'
```
Scope: the whole tracked set minus vendored trees and the frozen/generated stores; `docs/test-cases.md`
is generated but live and is included.
```
core/MediaSetup.lua:86:---   close          modules/Browser.lua  B:MakeCloseButton — all four title bars
docs/media.md:46:| `close` | `B:MakeCloseButton` — the ledger, session, export-modal and export-copy title bars | …
docs/smoke-tests.md:598:   **Export to CSV** on the modal. All four wear the same mark, because all four go through
docs/test-cases.md:941:- marks: the × is DRAWN in exactly one place, so one edit reached all four title bars
tests/test_libka0s.lua:63:    -- factory: all four of its title bars go through modules/Browser.lua's own B:MakeCloseButton,
tests/test_marks.lua:71:-- ── the close control: one edit, four title bars ───…
tests/test_marks.lua:98:test("marks: the × is DRAWN in exactly one place, so one edit reached all four title bars", function()
```
**7 lines in 6 files.**

---

## E-06 · Issue store (`BL-39`, register evidence ids)

`gh issue list --state all --limit 200 --json number,title,state,labels,url` → 20 issues; every one
carries exactly one `state:` and one `severity:` label; no title starts with `[`.
```
3  OPEN    state:triaged,severity:low   Record the BL-04 deviation in ARCHITECTURE's Documented deviations register
2  OPEN    enhancement,state:triaged,severity:medium   Backfill item names onto rows stored before the client cached the item
1  OPEN    enhancement,state:triaged,severity:medium   Capture store-to-store transfers (bank → warband tab)
20 CLOSED  state:will-not-do,severity:low   Adopt LibKa0s-Compat-1.0 in place of core/Compat.lua
…
```
- `docs/ARCHITECTURE.md:503` — the `localization-§1` row issue #3 asks for.
- Evidence ids resolve: `grep -c 'BL-04' docs/audits/2026-09-07/02_DEVIATIONS.md` → 5;
  `grep -c 'BL-28' …` → 5; `gh issue view 9 --json body` contains `LIBKA0S-17`; `gh issue view 5` → `CLOSED`.

---

## E-07 · Hub shape (`BL-43`)

- `tr -d '\r' < docs/ARCHITECTURE.md | wc -l` → **522**.
- `tr -d '\r' < docs/ARCHITECTURE.md | grep -n '^#'` → `45:## Settings Schema`, `212:## Launcher`, … so
  the section spans `:45-211` = **167** lines. Other mandated sections: Overview `:20-34`, Module Map
  `:35-44`, Message bus `:264-297`, Slash Commands `:298-305`, Event Subscriptions `:371-393`, Taint
  notes `:394-420`, Known Limitations `:421-439`, Documentation map `:440-488`, Documented deviations
  `:489-522` — each under ~60.
- `docs/ARCHITECTURE.md:208-210` — *"Row table and panel structure are in **[settings-panel.md](settings-panel.md)**; the stored shape and the carve-out rules are in **[schema.md](schema.md)**."* (two links).

---

## E-08 · The `debug.md` trigger (`BL-44`)

- `docs/ARCHITECTURE.md:467` — ``| `debug.md` | Not applicable | The console is `LibKa0s-DebugLog-1.0`'s, with no debug surface of the addon's own beyond `/bl debug scan` and `/bl debug panel` |``
- `settings/Schema.lua:708` — `elseif arg == "panel" then`; `:717` — `elseif arg == "scan" then`; the
  bodies call `NS.Panel:Diagnose()` and `NS.Ledger:Diagnose()` and append through the raw
  `NS.DebugLog:Add` (`:713`, `:721`).
- `modules/Ledger.lua:279` — `function L:Diagnose()`; `settings/Panel.lua:638` — `function P:Diagnose()`.
- `ls docs/debug.md` → no such file.

---

## E-09 · Stale citations (`BL-45`)

Each cited line re-read (`tr -d '\r' < <file> | sed -n '<n>p'`):

| Cited | Line actually holds | Symbol found at |
|---|---|---|
| `modules/Browser.lua:98` (register) | `local _, class = UnitClass("player")` | `function B:MakeCloseButton` at `:95` |
| `modules/Browser.lua:104` (register) | `art:SetPoint("CENTER")` | `NS.Icon("close")` at `:101` |
| `modules/Browser.lua:1047` (register) | `testBadge:Hide()` | ledger caller at `:1056` |
| `core/BankLedger.lua:45` (Event Subscriptions) | `--` | `RegisterEvent("PLAYER_ENTERING_WORLD"…)` at `:87` |
| `core/BankLedger.lua:49-50` | `-- they were trying not to open.` | the combat pair at `:91-92` |
| `modules/Browser.lua:1206` | `-- the "safety" fallback would have caused…` | `PLAYER_LOGOUT` at `:1218` |
| `modules/Browser.lua:147` (`settings/Schema.lua:396`) | `if not settings then return false end` | `function B:SaveGeometry()` at `:144` |
| `modules/Browser.lua:1099` (`:396`) | *(blank)* | grip `B:SaveGeometry()` at `:1108` |
| `modules/Browser.lua:185` (`:397`) | `end` | `function B:ResetWindow()` at `:182` |
| `modules/Browser.lua:748` (`:401`) | `-- current character. This is what the Clear button…` | `function B:SaveView()` at `:757` |
| `modules/Browser.lua:757` (`:401`) | `function B:SaveView()` | `function B:ResetView(silent)` at `:766` |
| `modules/Browser.lua:1007` (`settings/Schema.lua:178`, `tests/test_schema.lua:278`) | `frame = CreateFrame("Frame", "BankLedgerWindow", UIParent, "BackdropTemplate")` | `frame:SetMovable(true)` at `:1016` |
| `modules/Browser.lua:1123`, `:1165` (`settings/Schema.lua:139`) | a comment; a blank | `NS.Util.ApplyMasterFrame(frame)` at `:1132`, `:1179` |

- `settings/Schema.lua:402-403` — *"`minimap.minimapPos` — LibDBIcon writes it on a button drag, into the
  table B:SetupMinimap hands it."*; `core/LauncherSetup.lua:12` — *"This was `B:SetupMinimap` and
  `B:SetMinimapHidden` in modules/Browser.lua"*.
- `docs/performance.md:46` — ``| `core/BankLedger.lua` `OnEnable` | `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` -> `OnCombatChanged` …`` against `core/BankLedger.lua:91` inside `function NS.StandUp()` (`:85`).
- `docs/ARCHITECTURE.md:501` — *"the three events that *can* fire in combat do a single
  `NS.State.openContext` nil check and return"* against `core/BankLedger.lua:206-213`
  (`function addon:OnCombatChanged(event)` … `NS.Util.ApplyVisibility()`).
- `settings/Panel.lua:767` — *"`rowsForPage` (settings/OptionsSetup.lua) is what adds the two host-drawn filter tabs"*
  against `settings/Schema.lua:370-373` (`S.BespokeRows` — one `Filters` row).

---

## E-10 · The surviving timer and the mock that hides it (`BL-46`, `BL-46a`)

Registration census (`AUDIT.md`'s three greps, `tests/` also excluded for the first two because the
question is what the addon registers):

```
git ls-files '*.lua' ':!libs' ':!tests/_kit' ':!tests' | xargs grep -nE 'Register(Unit)?Event|RegisterMessage|RegisterBucketEvent'
git ls-files '*.lua' ':!libs' ':!tests/_kit' ':!tests' | xargs grep -nE 'Unregister(All)?Events?|UnregisterMessage|UnregisterAllMessages|UnregisterBucket|CancelTimer|CancelAllTimers|:Cancel\(|SetScript\("OnUpdate", *nil\)|CancelPending'
git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -nE 'C_Timer|ScheduleTimer|ScheduleRepeatingTimer|NewTicker|OnUpdate'
```

Registrations: `core/BankLedger.lua:87,91,92` (addon object), the capture set through
`L:RegisterEventSafely` (`modules/Ledger.lua:864-881`, addon object), bus targets in
`modules/Browser.lua:1212-1218`, `modules/Insights.lua:1000-1001`, `modules/Ledger.lua:888`,
`modules/SessionWindow.lua:662-673`, and the panel's own `settings/Panel.lua:170-171,493`
(recorded-not-ruled, not filed). Undone by `NS.StandDown`: `core/BankLedger.lua:151` —
`if ad and ad.CancelAllTimers then ad:CancelAllTimers() end`; `:161` —
`if ad and ad.UnregisterAllEvents then ad:UnregisterAllEvents() end`; `:176-177` — the four targets'
`UnregisterAllMessages` / `UnregisterAllEvents`. No `OnUpdate`, no ticker anywhere.

Timers: every one is AceTimer (`modules/Browser.lua:523,539`, `modules/Insights.lua:973`,
`modules/Ledger.lua:675`) except:
- `core/BankLedger.lua:220` — `C_Timer.After(5, function()`
- `core/BankLedger.lua:225` — `if NS.IsStoodDown and NS.IsStoodDown() then return end`
- `core/ItemSetup.lua:67` — `if cb and C_Timer and C_Timer.After then C_Timer.After(0.4, cb) end` (one
  caller passes no callback; the Filters panel path is the library's — `docs/performance.md:48`; not filed).

The mock:
- `tests/wow_mock.lua:617` — `M.C_Timer.After = function() end`
- `tests/wow_mock.lua:614-616` — *"C_Timer.After alone is a no-op … the retention-cleanup deferral
  (core/BankLedger.lua's OnEnterWorld) must NOT run inside the suites"*
- `tests/_kit/mock_base.lua:523` — *"the kit's C_Timer.After IS a push onto `M.__timers`"* (the recording
  the extender overwrites).
- `tests/test_disabled.lua:191-192` — `disable()` / `assertEqual(#mocks.__timers(), 0, "something is still going to wake up")`.

---

## E-11 · Event isolation (`BL-47`)

- `modules/Ledger.lua:850` — `local ok = pcall(addon.RegisterEvent, addon, event, handler)` (the helper, `:849-854`).
- Outside it: `core/BankLedger.lua:87` — `self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")`;
  `:91` — `self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatChanged")`; `:92` —
  `self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatChanged")`; `modules/Browser.lua:1218` —
  `B.__ev:RegisterEvent("PLAYER_LOGOUT", function() B:OnLogout() end)`; `modules/SessionWindow.lua:673`
  — `SW.__ev:RegisterEvent("PLAYER_LOGOUT", function() SW:OnLogout() end)`.
- `grep -rn 'IsEventValid' core modules settings` → nothing.
- `docs/ARCHITECTURE.md:376-377` — *"The other five sit outside the engine and outside that guard,
  because none of their names can go away under it"*.

---

## E-12 · The generated perf record (`BL-48`)

- `docs/automated-tests/20260916-184426/manifest.json` — `"perf": { "status": "skip", …, "skipReason": "no tests/perf.lua — this addon ships no offline scenarios", …`
- `docs/automated-tests/RESULTS.md:59-61` — *"**This repo ships no `tests/perf.lua`, so `perf` is a
  permanent `skip`** — the first of `automated-tests-§3`'s two sanctioned reasons, *nothing to run*,
  rather than a ratified `performance-§12` no-combat-path exemption."*
- `tests/_kit/run-automated-tests.sh:343-344` — `if [ ! -f tests/perf.lua ]; then` /
  `ST[perf]="skip"; NOTE[perf]="no tests/perf.lua — this addon ships no offline scenarios"`; `:838-843`
  — the fixed prose above. No other branch names `performance-§12`
  (`grep -n 'performance-§12' tests/_kit/run-automated-tests.sh` → `:841` only).
- `docs/ARCHITECTURE.md:501` — the ratified `performance-§12` row.

---

## E-13 · Bus literals and casing (`BL-49`)

```
git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -nE '(Send|Register)Message\("Ka0s_'
```
Scope: all authored Lua, `tests/` included (the playbook's scope).
```
tests/test_database.lua:40   tests/test_database.lua:53   tests/test_database.lua:54
tests/test_lifecycle.lua:64  tests/test_mock.lua:312       tests/test_mock.lua:313
tests/test_mock.lua:315      tests/test_mock.lua:320       tests/test_panel.lua:614
tests/test_schema.lua:36     tests/test_sessionwindow.lua:143  tests/test_sessionwindow.lua:145
```
**12 hits in 6 files; 0 in shipped code.** Casing grep (`'"Ka0s_[A-Za-z]+_[A-Za-z0-9_]+"'`): the four
declarations `core/Constants.lua:281,283,286,289` (e.g. `:281` —
`ENTRY_ADDED      = "Ka0s_BankLedger_EntryAdded",`), all PascalCase; `tests/test_bus.lua:19` —
`ENTRY_ADDED      = "Ka0s_BankLedger_EntryAdded",` (the oracle).

---

## E-14 · `.pkgmeta` (`BL-50`) and the packaging checks

- `.pkgmeta:17` — `# packaging.md:28 MUSTs every root dot-entry present in the repo be named or`
- `.pkgmeta:22` — `- .superpowers   # untracked; listed under packaging.md:28`
- `AUDIT.md`'s packaging checks, under `bash`: (a) prints nothing; (b) prints `UNACCOUNTED — .git`
  only; (c) prints nothing. Root entries: `.git .gitattributes .luacheckrc .pkgmeta .superpowers`
  (no `.gitignore`, no `.claude`, no `tools`).

---

## E-15 · Pre-formatted printer calls (`BL-51`, Info)

```
git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' | xargs grep -nE '\bprint\(\(|\bprint\([^)]*\.\.|NS\.Print\(\(|NS\.Print\([^)]*\.\.'
```
9 hits; one is the printer's definition (`core/CoreSetup.lua:59`), **8 call sites**:
`modules/LedgerTable.lua:1074,1080`, `settings/Schema.lua:677,691`, `settings/Slash.lua:51,62,316,395`.
E.g. `settings/Slash.lua:51` — `print(("blacklist cleared (%d %s)."):format(n, n == 1 and "id" or "ids"))`.

---

## E-16 · Lint

```
B luacheck .
```
→ `Total: 0 warnings / 0 errors in 71 files`. `.luacheckrc:10` —
`exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`; `:70-71` —
`files["tests/"] = {` / `globals = { "_G.BL_TEST" },`; no top-level `ignore`;
`grep -nE 'debugprofilestop|PerfDB' .luacheckrc BankLedger.toc` → nothing.

## E-17 · Tests

```
B lua tests/run.lua
```
→ last lines `PASS  layoutcap self-test: the exempt set takes folders as well as paths` /
`1017 passed, 0 failed, 0 skipped, 1017 total`; exit 0. `docs/test-cases.md` → `| **Total** | **1017** |`;
`README.md:7` → `![Tests](https://img.shields.io/badge/Tests-1017%2F1017_passing-green)`.

## E-18 · Complexity

```
B lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
```
→ `No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)`;
footer `17397  5.9  2.0  46.9  2640  0  0.00  0.00`. Top CCN 15 (e.g. `accumulateItemTaxonomy@263-294@./core/Database.lua`,
`I@505-551@./modules/Insights.lua`). Newest bundle `docs/automated-tests/20260916-184426/complexity.txt`
footer: `16380  5.9  2.0  46.6  2498  0`. `git rev-list --count 076f674..HEAD` → **37**. Previous
warning (`20260916-094506`): `Sl@132-152@./settings/Slash.lua` CCN 17, fixed in `6592b51 2026-09-16 Get
ResetEverything back under the complexity ceiling` by extracting `refreshAfterReset`
(`settings/Slash.lua:119-131`). Manifests: only `20260910-234511` has `"release": "1.1.0"`.
`docs/automated-tests/RESULTS.md:84-86` — the band table (Browser `BL-24`, LedgerTable *Accepted*, test_ledger *Accepted*).

## E-19 · Vendored payloads

```
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>
diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s     # empty, rc 0
diff -r --strip-trailing-cr <scratch>/testkit tests/_kit       # empty, rc 0
git -C ../LibKa0s ls-tree -r v1.55.0 LibKa0s testkit | while …; git hash-object <local> vs <blob sha>   # no MISMATCH
```
`git ls-tree -r v1.55.0 LibKa0s | wc -l` → 146 = `git ls-files libs/LibKa0s | wc -l` → 146;
testkit 11 = `tests/_kit` 11. `git ls-files -s tests/_kit/run-automated-tests.sh` → `100755`.
`CLAUDE.md:46` — `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).`;
`grep -n 'Bundles \[LibKa0s\]' README.md` → nothing; `README.md:6` —
`![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)` (bare).

## E-20 · Line endings

```
test -f .gitattributes; grep -n '^\* text=auto eol=\(crlf\|lf\)' .gitattributes; grep -nE '^\*\.(sh|py) text eol=lf' .gitattributes; grep -c ' binary' .gitattributes
n=84; diff <(head -n 84 .gitattributes | tr -d '\r') <canonical client body from line-endings-§5>; tail -n +85 .gitattributes | tr -d '\r' | grep -m1 .
git ls-files -z | xargs -0 -I{} sh -c '<the §7 (e) one-liner, verbatim>' | wc -l
```
→ present; `26:* text=auto eol=crlf`; `36:*.sh text eol=lf`, `37:*.py text eol=lf`; `23`; body diff
empty, no tail; **(e) = 0** strays over 458 tracked files.

## E-21 · Census and generators

```
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | wc -l            # 71
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | awk '$1>1500'   # none
git ls-files '*.py' '*.sh'                                                 # tests/_kit/run-automated-tests.sh only
```
Band: `modules/Browser.lua` 1220, `modules/LedgerTable.lua` 1132, `tests/test_ledger.lua` 1028,
`modules/Insights.lua` 1002. `docs/ARCHITECTURE.md:518` — *"Nothing is over the cap today."*

## E-22 · Compat and Tier 2 counts

- `grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` → **13**.
- `NS.COMMANDS` (`settings/Schema.lua:641-722`): 17 entries (`show hide toggle config enable disable
  version get set list reset resetall session test purge debug help`).
- Messages: 4 (`core/Constants.lua:281-289`).

## E-23 · Citation notation

```
git ls-files | grep -vE '^(libs/|tests/_kit/|docs/(audits|reviews|automated-tests|revendor|superpowers)/)' | xargs grep -nE '§[0-9]+\.[0-9]' | wc -l
```
→ **0** retired dotted citations. The same scope's `filename-§N` citations: 65 distinct references,
each range-checked against `grep -c '^### [0-9]' <fetched section>` → none out of range, none against a
bare-cited file.
