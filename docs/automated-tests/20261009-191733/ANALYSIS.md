# Analysis — 20261009-191733

- **Addon:** BankLedger 1.2.0 (release run for **1.3.0**; `manifest.json` `release: "1.3.0"`)
- **Verdict:** green
- **Commit:** `6aedd398cb9c14952265d74c0fb85530193c2702` (master), clean
- **Previous run:** `20260927-031851`

## Headline

This is the release run for 1.3.0, and the release gate passes on all six conditions. `luacheck` is
clean over 88 files, the harness runs 1266 cases with 1265 passed, 0 failed and 1 skipped (a kit
contract case that does not apply to this addon), and `lizard` reports max CCN 15 with zero warnings
and zero blind files. It is the first **sighted** run in this addon's record, and it lists no function
above 15. `perf` is a skip under the ratified `performance-§12` no-combat-path exemption, with no
`tests/perf.lua`; the release gate's narrow exception covers it and the 1.3.0 release notes say so.
Two test files newly entered the 1000–1500 band; both are ruled in the watch list below.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260927-031851` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 88 files | [`lint.txt`](lint.txt) | files 78 → 88 |
| tests | pass | 1265 passed, 1 skipped, 0 failed, 1266 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1104 → 1266 cases; skipped 0 → 1 |
| perf | skip | `performance-§12` no-combat-path exemption (ratified); 0 scenarios | none; nothing ran by design | unchanged: same skip, same reason |
| complexity | pass | 0 warnings, max CCN 15, blindFiles 0; see below | [`complexity.txt`](complexity.txt) | NLOC 19210 → 22780; first sighted run |

**Complexity is reported in full**, totals and averages both. Every value below is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt) plus the runner's band and parity counts.

| Metric | Value |
|---|---|
| Total NLOC | 22780 |
| Functions | 3657 |
| Avg NLOC / function | 6.2 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 50.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 4 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

**`tests`: a pass with one case-level skip.** [`tests.txt`](tests.txt) line 1255 is the kit's
diagnostics-contract case for an addon that opts out of turning logging on. BankLedger keeps the
default (`Kit.diagnostics.enablesLogging` is not false), so the case does not apply, and the case
beside it holds the behavior the addon actually has. The skip is counted in the total and in neither
passed nor failed. It is not a coverage gap in this addon, and `suites.tests.failed` is 0, which is
what the release gate reads.

**`perf`: a skip, and at this release a sanctioned one.** [`manifest.json`](manifest.json) records
`skipReason: "performance-§12 no-combat-path exemption (ratified; docs/ARCHITECTURE.md -> Documented
deviations)"`, and the addon ships no `tests/perf.lua`. The release gate's narrow exception covers it,
so the perf gate passes with nothing measured. The sweep behind the exemption is
`docs/performance.md`, and the one-sentence note the standard requires is in the 1.3.0 row of the
README's `## Version History`.

**`complexity`: a pass, and sighted.** [`complexity.txt`](complexity.txt) reads `No thresholds
exceeded`, and `blindFiles` is 0, so `lizard` measured every function. The previous record predates
kit revision 35 and carries no `blindFiles`, so it was unsighted. The sighted suite showed four
functions above 15 when kit 35 arrived (GI-BL-RV), and GI-BL-02 brought all four under 15 before this
run, so nothing is newly measured here. Five functions sit exactly at CCN 15: `I.Layout`
(`modules/Insights.lua:507`), `accumulateItemTaxonomy` (`core/Database.lua:563`), `LT.GroupEntries`
(`modules/LedgerTable.lua:343`), `LT.UpdateHeaderArrows` (`modules/LedgerTable.lua:690`) and
`L.GateReason` (`modules/Ledger.lua:298`). Growth in any of them trips the next release gate.

## Release gate (1.3.0)

| Gate | Result | Detail |
|---|---|---|
| Lint | PASS | 0 warnings / 0 errors in 88 files |
| Tests | PASS | 1265 passed, 0 failed, 1 skipped of 1266 |
| Perf | PASS (exception) | skipped, not measured: ratified `performance-§12` no-combat-path exemption, no `tests/perf.lua` |
| Complexity | PASS | ran; lizard 1.24.0 |
| CCN <= 15 | PASS | 0 functions over 15; max CCN 15 |
| Sighted | PASS | blindFiles 0 |

## What moved

Eighty commits separate this run from the previous one (`b97fd24` → `6aedd39`): profile support and
the `/bl profile` verb, the login backfill of uncached item rows, the sighted-complexity re-vendor and
its CCN fixes, debug-log coverage, resizable windows, search autocomplete, Group by Type & SubType,
per-tab filter views, LibKa0s re-vendors through v1.71.0 (kit 38), and the 2026-10-07 review
remediation and doc syncs.

- **lint:** 0 warnings / 0 errors over **78 → 88** files ([`lint.txt`](lint.txt)). The ten new
  files are `defaults/Profile.lua`, `settings/Profiles.lua`, `modules/Backfill.lua`,
  `modules/Browser_Views.lua`, `modules/Ledger_Diagnose.lua` and five suites
  (`test_autocomplete`, `test_backfill`, `test_debug_coverage`, `test_debug_library`,
  `test_profiles`).
- **tests:** **1104 → 1266** cases, 0 failed ([`tests.txt`](tests.txt)); skipped **0 → 1**, the
  kit contract case above. The count had been flat at 1104 across four runs while the work was
  docs; this release's features each brought their own cases.
- **perf:** still a skip, same reason. There is no figure to move.
- **complexity totals:** NLOC **19210 → 22780**, functions **2920 → 3657**.
- **complexity averages:** avg NLOC/function **5.9 → 6.2**, avg CCN **2.0 → 2.0**, avg tokens
  **46.9 → 50.2**. Functions are slightly longer on average; branching density did not move.
- **max CCN:** **15 → 15**, warnings **0 → 0**, now measured sighted (blindFiles 0).
- **file bands:** band files **2 → 4**, over-cap files **0 → 0**. `modules/Browser.lua`
  1221 → 1179 (the BL-03 Browser_Views peel), `modules/Insights.lua` 1002 → 1004, and two files
  newly crossed: `tests/test_browser.lua` (1103) and `tests/test_profiles.lua` (1010).
- **Against the last release run** (`20260927-030326`, 1.2.0): tests 1104 → 1266, lint scope
  76 → 88 files, NLOC 19199 → 22780, functions 2921 → 3657, avg NLOC 6.0 → 6.2, avg CCN 2.0 flat,
  max CCN 15 in both, zero warnings in both, band files 4 → 4 (`modules/LedgerTable.lua` and
  `tests/test_ledger.lua` left the band in their splits; two test suites took their places).

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. This is a release run whose gate passed, so the table is empty by construction.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1179 | Accepted, already tracked as `BL-24`; down from 1221 after the BL-03 peel |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1004 | Accepted; second consecutive release run in the band, so the next release owes the peel or a tracked ID |
| 1000–1500 (on notice) | `tests/test_browser.lua` | 1103 | **Newly crossed**; accepted, case count for this release's features; peel seam is the saved-view and per-tab block |
| 1000–1500 (on notice) | `tests/test_profiles.lua` | 1010 | **Newly crossed**; accepted, case count; peel seam is the v3/v4/v5 migration steps |

The full dispositions are in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band).

## Actions

1. Before the next release, `modules/Insights.lua` needs its named peel (`I:Layout` /
   `I:LayoutSections` and the `I:Render*` renderers into a sibling file) or a tracked deviation ID,
   because a third release run carried as Accepted trips anti-pattern #53. New here; no issue filed.
2. `tests/test_browser.lua`: lift the saved-view and per-tab view cases into
   `tests/test_browser_views.lua` if it grows again (re-check at 1300 LOC). New here; no issue filed.
3. `tests/test_profiles.lua`: lift the migration-step cases into `tests/test_profiles_migrations.lua`
   at the next migration step or 1200 LOC. New here; no issue filed.
