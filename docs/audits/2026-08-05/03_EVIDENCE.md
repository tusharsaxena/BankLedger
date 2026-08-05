# 03 · Evidence — Ka0s Bank Ledger — 2026-08-05

Audited against the **Ka0s WoW Addon Standard v2.21.0 (2026-08-04)**.

Every claim in `01_CURRENT_STATE.md` and `02_DEVIATIONS.md` is sourced here. Mechanical checks were
**executed**, not reasoned about; each records the real command and its real output, and a check that
could not be run is recorded as **not run** rather than inferred.

Environment: WSL2 Ubuntu, repo root `/mnt/d/Profile/Users/Tushar/Documents/GIT/BankLedger`,
branch `master`, HEAD `93abd23`.

---

## 1 · Mechanical checks

### 1.1 Lint — RUN, clean

```
$ luacheck .
...
Total: 0 warnings / 0 errors in 24 files
```

`.luacheckrc` excludes `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/`, so the 24 files
are the addon's own source. Supports `lint` compliance and BL-14's "consistent with there being no
brackets today".

### 1.2 Headless suite — RUN, green

```
$ lua5.1 tests/run.lua
...
726 passed, 0 failed, 726 total
```

Exit 0. Matches the README `[tests]` badge (`README.md:7` — `Tests-726%2F726_passing-green`) and the
newest bundle's manifest (`docs/automated-tests/20260804-233144/manifest.json` —
`"tests": { "passed": 726, "total": 726 }`). Supports `testing-§5` compliance.

### 1.3 Complexity — RUN, verbatim invocation, **zero drift**

Run from the repo root, exactly as `performance-§10` and `AUDIT.md` specify — no added flags, no
narrowed path, no re-tuned threshold:

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
...
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
     12788       6.0     2.1       48.0     1946            0      0.00    0.00

$ lizard --version
1.23.0
```

Compared against the latest run bundle, CR-normalized on the committed side only (the repo pins CRLF
via `.gitattributes`; the fresh capture is LF):

```
$ sed 's/\r$//' docs/automated-tests/20260804-233144/complexity.txt > /tmp/cx_committed.txt
$ diff /tmp/cx_committed.txt /tmp/lizard_now.txt && echo COMPLEXITY-IDENTICAL
COMPLEXITY-IDENTICAL
```

**Drift: none.** The full 1946-row function table reproduces byte-for-byte. No function crossed a
`lizard` threshold since that run; no file newly entered `layout-§1`'s 1000–1500 band. The record is
**not** stale (anti-pattern #51 does not apply) and shows no sign of hand-editing — it reproduces
from the command in its own header.

**Staleness of the run's own stamp.** `20260804-233144` was taken at `2026-08-04T23:31:44+05:30`;
this audit ran at `2026-08-05 01:57 IST`, i.e. **~2.5 hours** later, over the same tree. The bundle
is current by any reading.

**Cross-check against `docs/automated-tests/RESULTS.md`.** The newest row reads
`12788 | 1946 | 6.0 | 2.1 | 15 | 0`, agreeing with the fresh capture on every field. The watch list
below the table names four functions at the CCN cap of 15 — `ensureFrame`
(`modules/SessionWindow.lua:437`), `I:Layout` (`modules/Insights.lua:536`),
`accumulateItemTaxonomy` (`core/Database.lua:234`), `LT:UpdateHeaderArrows`
(`modules/LedgerTable.lua:827`) — and the fresh `complexity.txt` records no other function there.

**Reading the numbers (performance-§10's `and`/`or` tax).** With zero warned functions there is
nothing to characterize as guarding-vs-control-flow this run. The four at the cap are dense
**defaulting and guarding** rather than tangled control flow — `ensureFrame` and
`LT:UpdateHeaderArrows` are widget-state ladders, `accumulateItemTaxonomy` is a field-classification
pass — which is the lower-risk of the two shapes.

### 1.4 The automated-test artifact itself — audited against `automated-tests`

| Requirement | Result | Evidence |
|---|---|---|
| Runner vendored at `tests/_kit/run-automated-tests.sh` | ✔ present | `ls tests/_kit/` |
| Runner **executable** | ✘ **`100644` in git** | `git ls-files -s tests/_kit/run-automated-tests.sh` → `100644 30da7c07…` — **BL-26** |
| `.gitattributes` carries `*.sh text eol=lf` | ✔ | `.gitattributes:38`, with the `bash\r` rationale at `:33-37` |
| `docs/automated-tests/README.md` | ✔ present | 43 lines, describes running, gating and layout |
| `docs/automated-tests/RESULTS.md` | ✔ present, one path, generated | header comment: *"This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line."* |
| Watch list as **two tables with header rows**, band as a **column** | ✔ | `RESULTS.md:56-...` — "Functions `lizard` warned on" (**None.**) and "Files by `layout-§1` band" with a `Band` column |
| Bundles frozen, not pruned | ✔ | three bundles retained: `20260804-182039`, `-214843`, `-233144` |
| `ANALYSIS.md` per bundle | ✔ | present in all three |
| Skip distinguished from pass | ✔ | `manifest.json` — `"perf": { "status": "skip", "skipReason": "no tests/perf.lua — this addon ships no offline scenarios" }` |
| Retired `docs/complexity.md` still present? | ✘ **absent — correct** | no such file; `docs/testing.md:104-106` records the retirement. **BL-21 closes.** |
| Release gate documented | ✘ **absent** | grep for `release gate` / `CCN > 15` / `all four` over `README.md`, `CLAUDE.md`, `DEPENDENCIES.md`, `docs/**.md` (excluding frozen bundles) returns nothing on the rule — **BL-25** |

### 1.5 Vendored Ka0s-owned library drift — **NOT RUN**

`AUDIT.md` requires two diffs over the whole folders, both of which MUST be empty:

```
diff -r <LibKa0sRepo>/LibKa0s  ./libs/LibKa0s
diff -r <LibKa0sRepo>/testkit  ./tests/_kit
```

**Neither was executed.** This audit ran under an explicit single-repo constraint that forbids
reading, writing or running anything inside any sibling repository under
`/mnt/d/Profile/Users/Tushar/Documents/GIT/` other than `WowAddonStandards`. The sibling library
checkout would be `../LibKa0s`, and it was not looked at. **Recorded as unverified, never as a pass.**

Two things are nonetheless verifiable from inside this repo, and both are recorded as what they are:

- **Whole-folder shape.** `libs/LibKa0s/` holds `Core.lua`, `DebugLog.lua`, `Slash.lua`,
  `Options.lua`, `OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`, `PerfPanel.lua`,
  `LibKa0s.xml`, `LICENSE` — eight `.lua` files across five majors, which is the ship payload
  `library-stack-§7` describes, including the two `Perf` files the addon does not wire. The TOC lists
  `libs\LibKa0s\LibKa0s.xml` **once** (`BankLedger.toc:29`) and no module file individually. This
  rules out the *shape* half of anti-pattern #48 but says nothing about content.
- **The in-suite substitute is not usable as evidence here.** `tests/test_vendor_sync.lua` is the
  mechanical stand-in for those diffs, and it **passes vacuously** when the sibling is absent — see
  §1.9. Its two `PASS` lines in §1.2's run therefore prove nothing about drift, which is exactly why
  this section reads *not run* rather than *clean*.

**A non-empty diff would be anti-pattern #45; a file missing on the addon side would be #48.**
Neither is asserted, in either direction. Re-run both diffs on a machine holding `../LibKa0s`.

### 1.6 Degradation-stub coverage — RUN (call-site sweep per setup file)

For each setup file, every member production code reaches on the library instance, checked against
the library-absent branch.

**`LibKa0s-DebugLog-1.0` — `core/DebugLogSetup.lua`.** Members reached across `core/`, `modules/`,
`settings/`:

```
$ grep -rhoE "DebugLog[:.][A-Za-z_]+" core modules settings --include='*.lua' | sort -u
DebugLog.Debug   DebugLog:Add     DebugLog:Clear   DebugLog:Hide
DebugLog:IsEnabled  DebugLog:IsShown  DebugLog:SetEnabled  DebugLog:Show
DebugLog:Toggle  DebugLog:UpdateScrollBar
```

Stub (`core/DebugLogSetup.lua:29-55`) answers **all ten**, plus `UpdateStatus`, `RefreshHeader`,
`ShowCopy` and the raw `buffer`; `NS.Debug` is a no-op function. `SetEnabled` still flips
`NS.State.debug` and still prints the honest line (`:48-52`) — the flag gates more than the console
(`settings/Schema.lua`), so refusing to set it would be a second, invisible behavior change.
**No gap.**

Four members the stub omits — `FormatPlain`, `FormatColored`, `CopyText`, `ConsoleCheckbox` — are
reached **only from tests**, and omitted **on purpose**:

```
tests/test_libka0s.lua:363  -- The degradation stub carries none of these. Naming members only the
tests/test_libka0s.lua:364  -- real instance has is what distinguishes "the seam is live" from "the
tests/test_libka0s.lua:365  -- seam fell back and everything still ran".
tests/test_libka0s.lua:366  assertEqual(D.FormatPlain, debuglog.FormatPlain)
tests/test_libka0s.lua:369  assertEqual(type(D.ConsoleCheckbox), "function", "the stub has no ConsoleCheckbox")
```

That is a decision with its reason written down, not a gap — `AUDIT.md` step 4(b). The settings
panel's console checkbox is the schema row `state.debugConsole` (`settings/Schema.lua:44`), not the
library's `ConsoleCheckbox()`, so no production path reaches it.

**`LibKa0s-Slash-1.0` — `settings/Slash.lua:109-154`.** Stub answers `PrintHelp`, `BuildListLines`,
`CliList`, `CliGet`, `CliSet`, `CliReset`, `CliVersion`, `LandingRows`, `CliResetAll` and `OnSlash`.
`CliResetAll` deliberately still **works** rather than explaining itself (`:127-140`) — it is the
body the panel's Defaults button and `/bl resetall` share. `OnSlash` reproduces the dispatch loop at
its smallest without copying the library's row formatter or parser (`:142-153`), which is what
`slash-commands-§1`'s "the stub MUST NOT re-implement the library's rendering" asks for. **No gap.**

**`LibKa0s-Options-1.0` — `settings/OptionsSetup.lua:115-163`.** **Load-completing, not
member-answering** — the one documented `options-ui-§1` exception, and flagging it would be a false
positive. The member set a page file needs at load is recorded as **measured**, not read, and
measured to **zero** for this addon:

```
settings/OptionsSetup.lua:105  -- The set of members a page file needs AT LOAD is determined by
settings/OptionsSetup.lua:106  -- MEASUREMENT, not by reading, and for this addon it measures out to
settings/OptionsSetup.lua:107  -- ZERO: settings/Panel.lua captures the instance at file scope but
settings/OptionsSetup.lua:108  -- calls nothing on it until a panel is registered or rendered, and no
settings/OptionsSetup.lua:109  -- schema row literal in settings/Schema.lua calls a helper.
```

The stub carries no widget maker, no flow engine and no copied layout constant — the three constants
it exposes are `0`/`0`/`0.5` with the reason at `:156-158` (anti-pattern #47 forbids carrying the
library's values). The global-reset entry point stays real via `Sl:CliResetAll`. **No gap.**

**`LibKa0s-Core-1.0` — `core/CoreSetup.lua:36-73`.** The one place the standard sanctions a working
second copy (events-frames-taint-§8: *"that branch is the **only** sanctioned place a second copy may
exist"*), because a printer that answered "not installed" would silence every line. Announced once,
not per call (`:55,65-69`). **No gap.**

### 1.7 The global `print()` — RUN (BL-18)

```
$ grep -rn "local print" core modules settings --include='*.lua'
modules/LedgerTable.lua:5:local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)
settings/Slash.lua:4:local print = NS.Print   -- …
settings/OptionsSetup.lua:20:local print = NS.Print
settings/Panel.lua:4:local print = NS.Print   -- …
settings/Schema.lua:5:local print = NS.Print   -- …
```

`modules/Browser.lua` is absent from that list, and its only two uses of the identifier are:

```
modules/Browser.lua:917:  print("view saved as your default.")
modules/Browser.lua:926:  if not silent then print("view reset to stock defaults.") end
```

Both therefore bind the Lua/WoW **global**. `luacheck` cannot see it (§1.1 is clean; `print` is a
legitimate `lua51` global). `tests/test_libka0s.lua:340-349` asserts *"at least five load-time
printer captures"* — a floor, not a per-file requirement, so it passes with Browser excluded.

### 1.8 Standard-reference sweep — RUN (BL-20)

```
$ grep -rn -E "§[0-9]+\.[0-9]+|-§[0-9]{2,}" --include='*.lua' --include='*.md' . \
    | grep -v "^./libs/" | grep -v "^./docs/audits/" | grep -v "^./docs/reviews/" \
    | grep -v "^./docs/automated-tests/"
```

Nine live hits in this repo's own files:

```
settings/OptionsSetup.lua:43:  … NS.Schema:Set is this addon's SINGLE write seam (options-ui-§41) …
settings/OptionsSetup.lua:65:  -- Ka0s standard §3.4: AceGUI is resolved once, by the library …
settings/OptionsSetup.lua:74:  -- AceTimer through the addon object (Ka0s standard §3.1) …
settings/Panel.lua:11:-- O.AceGUI is reached through `O.AceGUI` … (Ka0s standard §3.4). It
settings/Panel.lua:58:-- … which is also what options-ui-§190
settings/Schema.lua:184:  -- … this is "the same function /bl set calls" (options-ui-§41) …
docs/ARCHITECTURE.md:106: … repaints an open settings panel (options-ui-§41) …
docs/pending/LEDGER.md:63: … `standards/options-ui.md` §11 and §41 (WowAddonStandards v2.15.0) …
tests/test_panel.lua:175:  -- … (options-ui-§189 makes the same point about a re-entrancy guard).
```

Two further hits are inside `libs/LibKa0s/Options.lua:129,173,233` — the **library's** text, excluded
from this finding and fixable only upstream (library-stack-§7).

### 1.9 Vendor-sync cases pass vacuously — RUN (BL-27)

```
tests/test_vendor_sync.lua:110  local function siblingTag()
tests/test_vendor_sync.lua:111      if not gitShow("HEAD:LibKa0s/Core.lua") then return nil end
tests/test_vendor_sync.lua:138  test("libs/LibKa0s is the LibKa0s release the README says this addon bundles", …
tests/test_vendor_sync.lua:140      if not tag then return end
tests/test_vendor_sync.lua:144  test("tests/_kit is the test kit that shipped with that release", …
tests/test_vendor_sync.lua:146      if not tag then return end
```

`gitShow` returns `nil` when the sibling repo, or `git`, or `io.popen` is unavailable
(`:51-59`) — every one of which is "the gate could not look". Both cases then `return` and are
counted as **passes** (they appear as `PASS` in §1.2's tail). The file's header claims the opposite:

```
tests/test_vendor_sync.lua:107  -- A missing sibling is the ONE case where this pair may go quiet, and it is said
tests/test_vendor_sync.lua:108  -- in the case name rather than hidden.
```

Neither case name — `"libs/LibKa0s is the LibKa0s release the README says this addon bundles"`,
`"tests/_kit is the test kit that shipped with that release"` — mentions the sibling, a tag or a
skip. The comment is false.

### 1.10 US-English sweep — RUN, clean (localization-§5, anti-pattern #46)

```
$ grep -rniE "colour|grey|behaviour|centre[sd]?\b|cancelled|cancelling|[a-z]{3,}ise\b|\
[a-z]{3,}isation|analyse|catalogue|dialogue|defence|licence|favour|labelled|travelled|fulfil\b" \
    core modules settings defaults locales tests docs/*.md docs/automated-tests/*.md \
    README.md CLAUDE.md DEPENDENCIES.md
```

Every hit is the word **`otherwise`** matching `[a-z]{3,}ise\b`. **No British spelling in any
authored string, comment, identifier or doc.**

### 1.11 Test falsifiability (`testing-§12`) — **UNVERIFIED**, by design

Mutation leaves no artifact in the repo, so this rule is not mechanically auditable and `testing-§12`
explicitly forbids recording its absence as a deviation. Recorded here as **unverified**. The suite
does carry `-- red under:` comments in places (e.g. `docs/reviews/2026-08-05/02_PROPOSED_CHANGES.md`
records adding one), which is the cheapest form of checkability. The one case where the
*unfalsifiability is visible from the source itself* is §1.9 / BL-27, and that is raised as a
deviation on its own evidence, not on a mutation.

---

## 2 · Evidence per deviation

### BL-07 — `savedvariables-§2`

| Claim | Source |
|---|---|
| `defaults/` holds only `Global.lua` | `ls defaults` |
| `NS.defaults` has `global` only | `defaults/Global.lua:6-49` |
| `schemaVersion` from one constant | `defaults/Global.lua:14` (`NS.SCHEMA_VERSION`) |
| Departure recorded with rationale | `docs/ARCHITECTURE.md:568-581` |
| The recording is what `CLAUDE.md` asks for | `CLAUDE.md:18-19` |

### BL-11 … BL-17 — the Perf decline

| Claim | Source |
|---|---|
| No `core/PerfSetup.lua`, no `NS.Perf`, no descriptor, no bucket, no bracket | `ls core`; grep for `NS.Perf` / `debugprofilestop` over `core modules settings` returns nothing |
| The ship payload is still whole (so this is adoption, not #48) | `ls libs/LibKa0s` → `Perf.lua`, `PerfPanel.lua` present; `BankLedger.toc:29`; `tests/run.lua:31-40` loads all eight |
| No `BankLedgerPerfDB` | `BankLedger.toc:7`; grep returns nothing |
| No `perf` verb | `settings/Schema.lua:226-286` — 15 verbs, `perf` absent; `README.md:80-98` agrees |
| `.luacheckrc` gaps | `.luacheckrc:9-30` (no `debugprofilestop`), `:31-36` (no `BankLedgerPerfDB`) |
| Two of five required topic-detail docs absent | `ls docs` — no `performance.md`, no `perf-runs/` |
| No `tests/perf.lua` | `ls tests` — 20 suites, `run.lua`, `wow_mock.lua`, `_kit/` |
| The `perf` skip is honestly recorded rather than passed off | `docs/automated-tests/20260804-233144/manifest.json` `"status": "skip"` + `skipReason`; `RESULTS.md` "Perf" section |
| No suspend seam | `core/State.lua` declares no flag; `modules/Ledger.lua` `Enable()` is the only arming path |
| Rationale recorded but unratified | `docs/pending/LEDGER.md:65` (LIBKA0S-17, 🔵 wont-do); `docs/ARCHITECTURE.md:568-581` carries BL-07 alone |

### BL-18 — `events-frames-taint-§8`

See §1.7. Sites: `modules/Browser.lua:917`, `:926`. Counter-examples:
`modules/LedgerTable.lua:5`, `settings/Slash.lua:4`, `settings/OptionsSetup.lua:20`,
`settings/Panel.lua:4`, `settings/Schema.lua:5`. Prior sightings: `docs/reviews/2026-08-03` F-001,
`docs/audits/2026-08-04/02_DEVIATIONS.md` BL-18 (at the then-current lines 855/864).

### BL-19 — `standalone-windows-§2`

| Claim | Source |
|---|---|
| Private `SKIN` table | `modules/Browser.lua:19-36` |
| Private `B:ApplySkin` building the backdrop by hand | `modules/Browser.lua:67-89` |
| Values are exactly the normative edge | bg `0.06,0.06,0.08,0.92` (`:20`), border `0,0,0,1` (`:21`), inner `0.24,0.24,0.27,0.85` (`:22`), divider `:23`, title `1.0,0.82,0.0` (`:24`); `WHITE8X8` at `edgeSize = 1` inset 1 (`:69-72`); 1px child inset one pixel both axes (`:76-82`) |
| `Core.SKIN` / `Core.ApplySkin` never reached | no `LibKa0s-Core-1.0` lookup anywhere in `modules/Browser.lua` |
| Close-control split handled correctly | `modules/Browser.lua:93-107` (host glyph); `core/DebugLogSetup.lua:111-116` (no `makeCloseButton` passed, with the reason) |

### BL-20 — `documentation-§5`

See §1.8 for the nine sites and the two library-owned exclusions.

### BL-25 — `automated-tests-§3` (*The release gate*)

| Claim | Source |
|---|---|
| Only the never-gates half is stated | `docs/testing.md:88-91`; `docs/automated-tests/README.md:26-32` |
| "At release, not at commit" says only that a **bundle** is produced | `docs/testing.md:97-99` |
| The Release checklist has no four-suite / zero-CCN gate | `docs/testing.md:41-53` |
| Nothing anywhere states the gate | `grep -n -i "release gate\|CCN > 15\|CCN>15\|all four" docs/*.md docs/automated-tests/*.md README.md CLAUDE.md DEPENDENCIES.md` → four hits, all "all four **suites go through one runner**" / "all four **are the ones to watch**"; **zero** on the rule |
| This addon's `perf` is a permanent skip, so the narrow exception is load-bearing here | `manifest.json` `skipReason`; `RESULTS.md` "Perf" section; BL-16 |
| `RESULTS.md` is generated and must not be hand-edited (hence the fix targets `testing.md` / `README.md` only) | `docs/automated-tests/RESULTS.md:3-4` header comment |

### BL-26 — `automated-tests-§2`

```
$ ls -l tests/_kit/run-automated-tests.sh
-rwxrwxrwx 1 tushar tushar 23340 Aug  5 00:10 tests/_kit/run-automated-tests.sh   # drvfs: every file reads 777

$ git ls-files -s tests/_kit/run-automated-tests.sh
100644 30da7c0713a07740c7d91828f07fe0adb04205d4 0	tests/_kit/run-automated-tests.sh
```

The **index** is what a clone gets, and it is `100644`. The CRLF half of the same rule is satisfied:
`.gitattributes:38` — `*.sh   text eol=lf`, with the `bash\r` rationale at `:33-37`.

### BL-27 — `testing-§12` / `testing-§11`

See §1.9. Also relevant: `docs/reviews/2026-08-05/01_FINDINGS.md:108` reaches the same conclusion
(as F-002) from the review side, and its change-set has not landed. The upstream cause — the kit
carries no skip status — is `tests/_kit/framework.lua` (`Kit.VERSION = 6`); **no edit under
`tests/_kit/` is proposed** (testing-§1).

### BL-23 — `documentation-§4` (adjacent)

| Claim | Source |
|---|---|
| No `TODO.md` anywhere | `ls`, `ls docs` |
| `DOC-01` still 🟡 with no issue link | `docs/pending/LEDGER.md:32` |
| `DOC-03` / `DOC-04` do carry issue links | `docs/pending/LEDGER.md:35-36` (#1, #2) |
| The `ARCHITECTURE.md` record `DOC-01` waits on has not landed | `docs/ARCHITECTURE.md:568-581` carries BL-07 alone |

### BL-24 — `layout-§1`

```
$ find core defaults locales modules settings tests -name '*.lua' | xargs wc -l | sort -n | tail -6
   830 modules/Ledger.lua
   863 modules/InsightsWidgets.lua
  1023 modules/Insights.lua
  1052 modules/LedgerTable.lua
  1361 tests/test_ledger.lua
  1368 modules/Browser.lua
```

No file over 1500. Band membership and dispositions already recorded in
`docs/automated-tests/RESULTS.md`'s band table. No bundle carries a non-null `release` field
(`manifest.json` — `"release": null`), so no "Accepted" disposition has yet been renewed across three
consecutive **release** runs (anti-pattern #53 not yet breached).

---

## 3 · Compliance evidence (claims that are *not* deviations)

| Claim | Source |
|---|---|
| TOC field order exact, no blank lines in the block | `BankLedger.toc:1-13` |
| Single Retail Interface; badge in lockstep | `BankLedger.toc:1` (`120007`) vs `README.md:3` (`Midnight_12.0.7`) |
| `#`-sectioned file listing in the required order | `BankLedger.toc:15,31,34,50,53,63` |
| `libs\LibKa0s\LibKa0s.xml` listed **once**, after Ace3; no `embeds.xml` | `BankLedger.toc:26-29` |
| Three-place standards reference | `BankLedger.toc:12`; `README.md:6`; `CLAUDE.md:6-24` |
| Root doc set is exactly three docs + LICENSE | `ls -a` → `README.md`, `CLAUDE.md`, `DEPENDENCIES.md`, `LICENSE` |
| `CLAUDE.md` is a stub with the verbatim-in-substance compliance section | `CLAUDE.md:1-33` |
| No `docs/agent-context.md`, and the ban is recorded | `CLAUDE.md:53-66` |
| `docs/` canonical trio present | `ls docs` |
| `ARCHITECTURE.md` carries every required section | headings at `:19,82,226,269,290,316,543,641` |
| README canonical order; `What's new` above Screenshots and matching the top Version History row | `README.md:36,49,73,127,144,157,169,176` |
| No angle-bracket placeholders in the README | `README.md:83-85` — `/bl set setting value` |
| Standard badge uses `_`, not `%20` | `README.md:6` |
| Namespace bootstrap; no `_G[addonName]` | `local addonName, NS = ...` heads every source file |
| AceConsole `:Print` clobber reclaimed | `core/BankLedger.lua:4,13`; `core/CoreSetup.lua:92-98` |
| Bus messages prefixed `Ka0s_BankLedger_`, documented | grep → four messages; `docs/ARCHITECTURE.md:269-289` |
| Single write seam shared by panel and CLI | `settings/OptionsSetup.lua:46-49`; `settings/Slash.lua:184-188` |
| Migration runner ships | `core/Database.lua:14-33` |
| `NS.L` metatable fallback; scope decision written down | `locales/enUS.lua:6-16` |
| Load list derived from the TOC; all eight LibKa0s files spelled out | `tests/run.lua:31-46` |
| Kit vendored under `tests/`, never `libs/` | `ls tests/_kit` |
| `.pkgmeta` has no `externals:` and ignores `docs`/`tests`/`_dev` | `.pkgmeta:1-22` |
| Media in typed subfolders; logo `.tga` + sources; mono font with `OFL.txt` | `ls -R media` |
| Audit/review histories retained and unedited | `ls docs/audits docs/reviews` |
