# 03 · Evidence — Ka0s Bank Ledger — 2026-10-07

Every command below was run from `/mnt/d/Profile/Users/Tushar/Documents/GIT/BankLedger` at HEAD
`662221b` with a clean tree, unless another directory is named. Every `file:line` cited in this bundle was
re-read before it was written, and the quoted text beside it is what is on that line. Scope is stated
for every count.

---

## E-00 · Standard resolution

```sh
RAW=https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master
curl -fsSL $RAW/AUDIT.md; curl -fsSL $RAW/standards/STANDARDS.md; curl -fsSL $RAW/standards/ADDONS.md
# then every (standards/<file>.md) link in STANDARDS.md's Sections list, from $RAW/standards/standards/
```

Output: `AUDIT.md` 1156 lines, `STANDARDS.md` 255 lines (H1 `# Ka0s WoW Addon Standard (v2.76.1, 2026-10-07)`),
`ADDONS.md` 82 lines, **27** section files, 6,576 lines together, no `FAIL`. `diff -q` of each fetched
section and of `AUDIT.md` against `../WowAddonStandards` at `f472389`: no output.

## E-01 · Mechanical runs

**Tests.** `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`

```
1258 passed, 0 failed, 1 skipped, 1259 total
exit=0
```

The skip: `SKIP  diagnostics contract: an addon that opts out lands the report and leaves logging off —
this addon keeps the default (Kit.diagnostics.enablesLogging is not false), so its report turns logging
on; the case above holds it`.

**Lint.** `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .`

```
Total: 0 warnings / 0 errors in 87 files
exit=0
```

Scope: `.luacheckrc:10` — `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`.
No top-level `ignore`. 87 = the authored census in E-03.

**Complexity (the standard's invocation, verbatim).**
`~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`

```
BankLedger 1.2.0 — automated tests — 20261007-155038
  complexity  pass  — 1 warnings (fun rate 0.00), 22650 NLOC / 3628 funcs, avg NLOC 6.2, avg CCN 2.0 (max 16), avg tokens 50.3 (recorded, non-gating)
  verdict: green
  record:  newest bundle 20260927-031851 measured b97fd24, 67 commit(s) behind HEAD — its figures describe a tree this one is no longer
exit=0
```

Scope: the runner's own file list — `find . -name '*.lua' -not -path './libs/*' -not -path './tests/_kit/*'`
(`tests/_kit/run-automated-tests.sh:505-506`) — sanitized into a shadow tree, then
`lizard -l lua -L 1500 -x "./libs/*" -x "./tests/_kit/*" .` (`:508`). It wrote nothing (`--no-bundle`;
`git status --short` afterwards clean apart from a parallel run's `docs/reviews/2026-10-07/`).

**Naming the warned function.** `--no-bundle` prints totals only, so the shadow was rebuilt in scratch with
the runner's own two steps (same file list, `lua tests/_kit/lizard_sighted.lua shadow <dir>`, same
`lizard` command, through `ka0s-bounded`). Totals match the runner exactly (22650 / 6.2 / 2.0 / 50.3 /
3628 / 1):

```
!!!! Warnings (cyclomatic_complexity > 15 or length > 1500 or nloc > 1000000 or parameter_count > 100) !!!!
      35     16    310      2      45 LT.GroupEntries@320-364@./modules/LedgerTable.lua
```

The same two steps over `git show 5a78432^:modules/LedgerTable.lua` alone:

```
      35     15    306      2      45 LT.GroupEntries@302-346@./modules/LedgerTable.lua
```

**Kit revision.** `tests/_kit/framework.lua:20` — `Kit.VERSION = 37`. `tests/run.lua:43` —
`{ name = "test_lizard_sighted", dir = "tests/_kit/" },`.

## E-02 · Vendored payload drift (`library-stack-§7`, anti-patterns #45/#48)

`CLAUDE.md:46` — `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).`
`grep -n 'Bundles \[LibKa0s\]' README.md` → no output.

```sh
cd ../LibKa0s && git rev-parse v1.70.0          # 26f441a25ad7a808ca612eecec512808b9fa4c38
git archive v1.70.0 LibKa0s testkit | tar -x -C <scratch>
diff -r <scratch>/LibKa0s ../BankLedger/libs/LibKa0s ; echo $?   # 0, no output
diff -r <scratch>/testkit ../BankLedger/tests/_kit   ; echo $?   # 0, no output
```

File counts: 159 / 159 (ship folder), 22 / 22 (kit). No `--strip-trailing-cr` needed. The TOC lists
`libs\LibKa0s\LibKa0s.xml` once (`BankLedger.toc:31`).

## E-03 · Layout census (`layout-§1`)

Scope: the default denominator — tracked authored Lua, `libs/` and `tests/_kit/` excluded, `tests/` in.

```sh
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | wc -l                       # 87
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | sort -n | tail -6
    990 core/Database.lua
   1004 modules/Insights.lua
   1010 tests/test_profiles.lua
   1059 tests/test_browser.lua
   1427 modules/Browser.lua
  34166 total
```

0 over 1500; four in 1000–1500. No declared generated-data exemption exists, so nothing is subtracted.
`docs/ARCHITECTURE.md:460` — *"The largest authored file is `modules/Browser.lua` at 1328 lines,"* (BL-45).
History of that file's size: `e5cd620^` 1223, `e5cd620` 1328, `5a78432` 1329, `12d7ba7` 1336, `e8d264a`
1427 (`git show <c>:modules/Browser.lua | wc -l`).

`git ls-files '*.py' '*.sh'` → `tests/_kit/run-automated-tests.sh` only (vendored; not a generator).

## E-04 · Re-vendor bundles (`audit-review-history`) — BL-41

The playbook's loop, run as written (horizon `2026-08-25`, `--since="$horizon 00:00"`, walking
`libs/LibKa0s` and `tests/_kit`, tag read from `CLAUDE.md` at each commit; recorded side read from folder
names and `01_DELTA.md` line 1):

```
horizon=2026-08-25
vendored 52 recorded 50
UNRECORDED:
v1.69.0
v1.70.0
```

`git log --format='%h %ad %s' --date=short -- libs/LibKa0s tests/_kit | head -2`:

```
2c87997 2026-10-07 chore: re-vendor LibKa0s v1.70.0
b5e638b 2026-10-06 chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)
```

Newest bundle: `docs/revendor/2026-10-04-v1.68.1/01_DELTA.md:1` — `Delta: LibKa0s v1.68.0 -> v1.68.1`.
Span format already in the store: `docs/revendor/2026-10-01-v1.64.0-v1.65.0/01_DELTA.md:1` —
`Delta: LibKa0s v1.64.0 -> v1.65.0 (span: v1.64.0 v1.65.0)`. No register row mentions either tag.

## E-05 · BL-52 — `LT.GroupEntries`

- `modules/LedgerTable.lua:320` — `function LT:GroupEntries(entries)`.
- `modules/LedgerTable.lua:339` — `            sortKey = sortFn and sortFn(e) or groupOrder or valueLabel }`.
- `modules/LedgerTable.lua:347` — `  table.sort(order, function(a, b)` (a closure built per call).
- `git show 5a78432 -- modules/LedgerTable.lua`, the two changed lines inside the function:
  `-    local key, valueLabel = groupOf(groupBy, e)` / `+    local key, valueLabel, groupOrder = groupOf(groupBy, e)`
  and `-            sortKey = sortFn and sortFn(e) or valueLabel }` / `+            sortKey = sortFn and sortFn(e) or groupOrder or valueLabel }`.
- Coverage: `tests/test_ledgertable.lua:180` — `test("LedgerTable:GroupEntries with no grouping emits one row item each", function()`;
  seven `GroupEntries` cases listed at `docs/test-cases.md:392-398`, under `### test_ledgertable.lua (60)`.
- Record: `docs/automated-tests/20260927-031851/manifest.json` → `suites.complexity` =
  `{'status': 'pass', … 'maxCcn': 15, … 'bandFiles': 2, 'overCapFiles': 0, 'gating': False, 'gates': {'commit': False, 'release': True}}` — **no `blindFiles` key** (pre-kit-35).
- Rule: `automated-tests` section file, `#### The release gate: all four, and it is not the commit gate (MUST)`
  — *"`complexity` pass with **no function above CCN 15** and **`blindFiles` at 0**"*.

## E-06 · BL-53 — inventory total vs badge

- `README.md:7` — `![Tests](https://img.shields.io/badge/Tests-1258%2F1258_passing-green)`.
- `docs/test-cases.md:4-5` — *"The `## Totals` table below is the **authoritative pass count** — the README test / badge and any count quoted in the docs must agree with it."*
- `docs/test-cases.md:1402` — `- diagnostics contract: an addon that opts out lands the report and leaves logging off (skipped: this addon keeps the de…`.
- `docs/test-cases.md:1472` — `| **Total** | **1259** |`.
- `tests/_kit/framework.lua:569` — `  out(string.format("| **Total** | **%d** |", #tests))`.
- `tests/_kit/framework.lua:204-205` — `--   * a skip is NEVER folded into \`passed\` — the README [tests] badge and docs/test-cases.md` / `--     count passes, and a skip counted as one is the original lie in a new place;`.
- `../LibKa0s` at `353f286` (`HEAD`): `grep -n '| \*\*Total\*\*' testkit/framework.lua` → `569:  out(string.format("| **Total** | **%d** |", #tests))`. `gh issue list --state open` in `../LibKa0s`, filtered for skip/total/inventory: no match.
- Rule: `testing` section file line 89 — *"… **MUST NOT** be folded into either the passed count or the total."*

## E-07 · BL-45 — stale prose

- `docs/ARCHITECTURE.md:460` — quoted in E-03.
- `core/Constants.lua:235` — `-- .tga as required rather than optional. See docs/ARCHITECTURE.md ▸ Logo art.`
- `docs/smoke-tests.md:113` — `  two (ARCHITECTURE ▸ Logo art). Result:`
- `docs/media.md:104` — `## Logo art`. `grep -n 'Logo art' docs/ARCHITECTURE.md` → no output.
  `git log -S'Logo art' -- docs/ARCHITECTURE.md` newest hit: `a6b4c39 2026-08-06 docs: adopt the documentation tier model (standard v2.23.0)`.
- `modules/LedgerTable.lua:28` — `-- to a box) only where the library is missing. That is an accepted, documented deviation: the mono`;
  `:30` — `-- extends it to one glyph. See docs/ARCHITECTURE.md ▸ Documented deviations.`
- The register (`docs/ARCHITECTURE.md:434-451`) holds three rows: `performance-§12`, `localization-§1`, `standalone-windows`.
- `debug-logging` section file line 49 — *"**Second sanctioned use — a glyph the default font does not have.** The vendored monospace font **MAY** also be used for an individual glyph …"*.

## E-08 · BL-51 — pre-formatted printer calls (Info)

Scope: shipped Lua (`git ls-files '*.lua' ':!libs' ':!tests'`).
`… | xargs grep -nE '(^|[^.:A-Za-z_])(print|NS\.Print)\(' | grep -E ':format\(|\.\.|string\.format'`, minus the
printer's own definition:

```
core/DebugLogSetup.lua:51:    NS.Print(NS.L["%s is unavailable: the LibKa0s library did not load."]:format("/bl diagnostics"))
modules/Browser.lua:901:  print(("%s view saved as your default."):format(lastTab))
modules/Browser.lua:915:  if not silent then print(("%s view reset to stock defaults."):format(lastTab)) end
modules/LedgerTable.lua:852:          print("blacklisted", rowLabel(entry), MANAGE_ROUTE .. "Blacklist.")
modules/LedgerTable.lua:857:          print("whitelisted", rowLabel(entry), MANAGE_ROUTE .. "Whitelist.")
settings/Slash.lua:111:  print("profile '" .. tostring(db and db.GetCurrentProfile and db:GetCurrentProfile() or "?")
settings/Slash.lua:253:  function Sl:CliVersion() print("v" .. tostring(Sl:Version())) end
settings/Slash.lua:339:    print("unknown command", "'" .. verb .. "'")
```

`LedgerTable.lua:852,857` join two constants (`MANAGE_ROUTE .. "Blacklist."`) and pass the row label as its
own argument, so they are not pre-formatting a value; six sites remain. `git show e8d264a -- modules/Browser.lua`:
`-  print("view saved as your default.")` → `+  print(("%s view saved as your default."):format(lastTab))`.

## E-09 · Line endings (`line-endings`)

```sh
test -f .gitattributes && echo present                 # present
grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes  # 26:* text=auto eol=crlf
grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes       # 36:*.sh text eol=lf / 37:*.py text eol=lf
grep -c ' binary$' .gitattributes                         # 20
head -84 .gitattributes | tr -d '\r' | diff - <canonical client-bound body, line-endings §5> && echo BODY-CLEAN   # BODY-CLEAN
tail -n +85 .gitattributes | wc -l                        # 0
```

(e), the playbook's one-liner verbatim over the whole tracked set (`git ls-files | wc -l` = 593): **0**.

## E-10 · Packaging (`packaging`)

Run under `bash` (zsh does not word-split the `$entries` string): (a) prints nothing; (b) prints only
`UNACCOUNTED — .git`; (c) prints nothing. `.superpowers/` holds `sdd/.gitignore` and is ignored at
`.pkgmeta:22`. No `tools/`, no `.claude/`.

## E-11 · Registration census and stand-down (`slash-commands-§7`)

Scope: shipped Lua (`git ls-files '*.lua' ':!libs' ':!tests'`).

- Registrations: `core/BankLedger.lua:132,136,137` (`NS.RegisterEventSafely(self, …)`), `modules/Ledger.lua:839-865` (capture set via `register = NS.RegisterEventSafely`, plus `L.__ev:RegisterMessage`), `modules/Backfill.lua:182` (`NS.RegisterEventSafely(ad, EVENT, onItemInfo)`), `modules/Browser.lua:1419-1425`, `modules/Insights.lua:1002-1003`, `modules/SessionWindow.lua:686-697`, `settings/Panel.lua:169-170,492` (panel refresh, setup), `core/Database.lua:21-23` (AceDB profile callbacks, setup).
- Undone: `core/BankLedger.lua:179` `ad:CancelAllTimers()`, `:194` `ad:UnregisterAllEvents()`, `:220` `ev:UnregisterAllEvents()` with `UnregisterAllMessages` beside it in `dropBusTarget`; each module's `CancelPending` (`:182-184`); `modules/Backfill.lua:108-109`.
- Sanctioned survivor: `modules/Ledger.lua:667` — `-- THE ONE SANCTIONED GATE (slash-commands-§7). \`HookScript\` has no un-hook, so these two bodies`, bodies gated at `:672`.
- Timers: every one an AceTimer handle (`core/BankLedger.lua:329`, `modules/Backfill.lua:183`, `modules/Browser.lua:559,575`, `modules/Insights.lua:975`, `modules/Ledger.lua:622`); the one `C_Timer.After` is `core/ItemSetup.lua:67`, inside the library-absent `LoadItem`.
- Suite: `tests/run.lua:30` lists `"test_disabled"`; `tests/test_disabled.lua:18-19` — *"Every case reads the kit's recording registry — `mocks.__registrations()`, / `mocks.__timers()`, `mocks.__shownFrames()`, `mocks.__svWrites()`, `mocks.__printed()`"*; `tests/wow_mock.lua:636` — `-- C_Timer.After is the kit's too, and it RECORDS (testing-§1: record, never no-op). This file`.

## E-12 · Slash, diagnostics, launcher

- `settings/Schema.lua:795` `NS.COMMANDS = {` … `:896` `}` — `awk '/^NS.COMMANDS = \{/,/^\}/' settings/Schema.lua | grep -cE '^  \{ "'` → **19**.
- `settings/Schema.lua:808-809` — `{ "enable", … NS.Slash:CliEnabled(true) end }` / `{ "disable", … NS.Slash:CliEnabled(false) end }`.
- `settings/Slash.lua:365` — `for i, verb in ipairs(lib.LIVE_VERBS) do liveVerbs[i] = verb end`; `:380` — `  liveVerbs    = liveVerbs,`.
- `settings/Schema.lua:869` — `      if arg == "diagnostics" then NS.DebugLog:RunDiagnostics()`; `:892` — `  { "diagnostics", NS.L["Write a diagnostic report to the debug console"], function()`.
- `grep -rniE '"(diag|dump|dx)"' settings core modules` → no output.
- `core/LauncherSetup.lua:95` — `NS.BRAND_NAME = "Ka0s Bank Ledger"`; `:135` — `NS.Launcher = Launcher:New({`; `:232` — `  debug = NS.DebugSink,`; `:239` — `  debugAtEnable = function(tag, message) NS.DebugAtEnable(tag, "%s", tostring(message)) end,`.
- `standards/ADDONS.md:21` — `| Ka0s Bank Ledger | … | Enabled · Locked · Test mode · Show window (the ledger browser) |`.

## E-13 · Close-button grep (`standalone-windows`)

`grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'`:

```
modules/Browser.lua:103:function B:MakeCloseButton(parent, onClick)
modules/Browser.lua:1253:  local close = B:MakeCloseButton(titleBar, function() B:Hide() end)
modules/Export.lua:392:    local close = NS.Browser:MakeCloseButton(tbar, function() frame:Hide() end)
modules/SessionWindow.lua:511:    local close = NS.Browser:MakeCloseButton(titleBar, function() SW:Hide() end)
```

(The unfiltered grep's first four lines are `./libs/…` and drop out under `grep -v '/libs/'`.)
`modules/Browser.lua:109` — `  local path = NS.Icon and NS.Icon("close")`. One host factory, three callers,
the catalog mark — the ratified decline's four conditions hold.

## E-14 · Bus literals, settings-window grep, media

- `git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -nE '(Send|Register)Message\("Ka0s_'` → no output.
- Wire strings: `core/Constants.lua:287,289,292,295` — `"Ka0s_BankLedger_EntryAdded"`, `"…_LedgerChanged"`, `"…_SessionChanged"`, `"…_SettingsChanged"`.
- `… | xargs grep -nE 'SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory' | grep -v '^tests/'` → no output.
- `grep -rn 'ScrollUp-Up\|ScrollDown-Up' --include='*.lua' settings/` → no output; `grep -rn 'disabledIf\|LSM30_\|classColorSource' settings/` → no output.
- `od -An -tu1 -N18 media/logos/bankledger.logo.128.tga` → `0 0 2 0 0 0 0 0 0 0 0 0 128 0 128 0 / 32 8`.

## E-15 · Register and issue store

- `docs/ARCHITECTURE.md:434` `## Documented deviations`, three rows, `:453` `### Files over the 1500-line cap`.
- `gh issue list --state all --limit 200 --json number,title,state,labels` → 21 issues; open: `1 OPEN enhancement,state:triaged,severity:medium Capture store-to-store transfers (bank → warband tab)`; `3 CLOSED state:done,severity:low Record the BL-04 deviation …`; `5`, `9` `state:will-not-do` (cited by rows).
- `docs/audits/2026-09-07/02_DEVIATIONS.md` — `grep -c 'BL-04'` → 5, `grep -c 'BL-28'` → 5 (both ids resolve).
- `ls docs/pending` → *No such file or directory*.

## E-16 · Docs map (`documentation-§3`)

Scope: tracked `.md` under `docs/` outside `audits/`, `reviews/`, `automated-tests/<run>/`, `revendor/`,
`superpowers/` — 21 files: `ARCHITECTURE.md`, `automated-tests/README.md`, `automated-tests/RESULTS.md`,
`common-tasks.md`, `compat-layer.md`, `data-flow.md`, `debug.md`, `insights.md`, `media.md`,
`midnight-quirks.md`, `module-map.md`, `performance.md`, `profiles.md`, `schema.md`, `scope.md`,
`settings-panel.md`, `slash-dispatch.md`, `smoke-tests.md`, `test-cases.md`, `testing.md`, `windows.md`.
Map rows (`docs/ARCHITECTURE.md:391-432`): Required 7, Conditional 5 present + 2 N/A, Verification 6,
Addon-specific 3 — 21 files, each once; no dangling row.
`grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` → 13.
