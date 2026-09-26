# Analysis — 20260927-030326

- **Addon:** BankLedger 1.1.0 (release run for **1.2.0**; `manifest.json` `release: "1.2.0"`)
- **Verdict:** green
- **Commit:** `e9c5caeda763ac6ccda2dd770fb47076101adf6d` (master), clean
- **Previous run:** `20260926-193102`

## Headline

This is the release run for 1.2.0, and the release gate passes. `luacheck` is clean over 76 files,
the harness runs 1104 cases with none failed or skipped, and `lizard` reports max CCN 15 with zero
warnings. `perf` is a skip under the addon's ratified `performance-§12` no-combat-path exemption,
which `automated-tests-§3` counts as a pass at the release gate, and which the 1.2.0 release notes
state. Every figure is identical to the previous run, since only README and docs changed between
the two. Nothing here needs action before the tag.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260926-193102` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 76 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1104 passed, 0 skipped, 0 failed, 1104 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged; identical inventory |
| perf | skip | `performance-§12` no-combat-path exemption (ratified); 0 scenarios | none; nothing ran by design | unchanged: same skip, same reason |
| complexity | pass | 0 warnings, max CCN 15; see below | [`complexity.txt`](complexity.txt) | unchanged, function for function |

**Complexity is reported in full**, totals and averages both. Every value below is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 19199 |
| Functions | 2921 |
| Avg NLOC / function | 6.0 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 47.1 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 4 |
| Files over the 1500 cap | 0 |

**`perf`: a skip, and at this release a sanctioned one.** [`manifest.json`](manifest.json) records
`skipReason: "performance-§12 no-combat-path exemption (ratified; docs/ARCHITECTURE.md -> Documented
deviations)"`, the second of `automated-tests-§3`'s two sanctioned reasons, and the addon ships no
`tests/perf.lua`. The release gate's one narrow exception covers both sanctioned reasons, including
this exemption, so the perf gate passes here with nothing measured. The previous run's analysis
said this suite would be NOT EVALUATED at a release; that reading was wrong, and this run corrects
it rather than editing the frozen bundle. The sweep behind the exemption is `docs/performance.md`.
The one-sentence note the standard requires is in the 1.2.0 row of the README's `## Version History`.

**`complexity`: a pass.** [`complexity.txt`](complexity.txt) reads `No thresholds exceeded`. The
same five functions sit exactly at CCN 15, at the same locations as the previous run:
`accumulateItemTaxonomy` (`core/Database.lua:275`), `I` (`modules/Insights.lua:505`), `L`
(`modules/Ledger.lua:428`) and two `LT` closures (`modules/LedgerTable.lua:599` and `:905`). Growth in
any of them would trip the next release gate.

## Release gate (1.2.0)

| Gate | Result | Detail |
|---|---|---|
| Lint | PASS | 0 warnings / 0 errors in 76 files |
| Tests | PASS | 1104 passed, 0 failed, 0 skipped of 1104 |
| Perf | PASS (exception) | skipped, not measured: ratified `performance-§12` no-combat-path exemption, no `tests/perf.lua` |
| Complexity | PASS | ran; lizard 1.24.0 |
| CCN <= 15 | PASS | 0 functions over 15; max CCN 15 |

## What moved

Seven commits separate this run from the previous one (`d67564c` → `e9c5cae`): the sweep's final
run record, its sync-docs and comment-citation follow-ups, the merge to master, and three README
passes (plain-language, third-party credits, and the first-bank-visit Usage flow with sync-docs).
Lua changed only in `.luacheckrc`, `tests/test_envsetup.lua` and `tests/test_surface_parity.lua`,
and none of those moved a figure.

- **lint:** 0 warnings / 0 errors over **76 → 76** files ([`lint.txt`](lint.txt)).
- **tests:** **1104 → 1104**, all passing, none skipped ([`tests.txt`](tests.txt)). This bundle's
  [`test-cases.md`](test-cases.md) is byte-identical to `docs/test-cases.md` at HEAD. The count has
  been flat at 1104 across three runs; the work since then was docs, not features, so that is
  expected rather than a coverage gap.
- **perf:** still a skip, same reason. There is no figure to move.
- **complexity totals:** NLOC **19199 → 19199**, functions **2921 → 2921**.
- **complexity averages:** avg NLOC/function **6.0 → 6.0**, avg CCN **2.0 → 2.0**, avg tokens
  **47.1 → 47.1**. No density signal.
- **max CCN:** **15 → 15**, warnings **0 → 0**.
- **file bands:** band files **4 → 4**, over-cap files **0 → 0**. `modules/Browser.lua` 1221,
  `modules/Insights.lua` 1002, `modules/LedgerTable.lua` 1139 and `tests/test_ledger.lua` 1028 did
  not move.
- **Against the last release run** (`20260910-234511`, 1.1.0): tests 849 → 1104, lint scope 61 → 76
  files, NLOC 14669 → 19199, functions 2188 → 2921, avg NLOC 6.0 and avg CCN 2.0 flat, max CCN 15
  in both, zero warnings in both, band files 3 → 4. The addon grew by about a third with no rise in
  density.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. This is a release run whose gate passed, so the table is empty by construction.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1221 | Accepted, already tracked as `BL-24`; unchanged |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1002 | Accepted; first release run in the band |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1139 | Accepted; second consecutive release run, so the next release owes the peel or a tracked ID |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1028 | Accepted, case count not tangle; second consecutive release run, same shelf life |

The full dispositions are in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). Nothing newly
crossed.

## Actions

1. Before the next release, `modules/LedgerTable.lua` and `tests/test_ledger.lua` each need either
   their named peel (the test-data generator block; the settling/marks split) or a tracked deviation
   ID, because a third release run carried as Accepted trips anti-pattern #53. New here; no issue
   filed yet.
