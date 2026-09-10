# Analysis — 20260910-234511

- **Addon:** BankLedger 1.0.0 → 1.1.0
- **Verdict:** green
- **Commit:** d4632ef81b15 (master), clean
- **Previous run:** [`20260908-181253`](../20260908-181253/)

## Headline

The release run for **1.1.0**. Lint, tests and complexity are green with zero functions above CCN 15; **perf did not run at all** — this addon ships no `tests/perf.lua`, so three suites were measured, not four. Against the previous run: five new test cases, two new lint files, 214 more NLOC, and no movement in any average.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260908-181253` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 61 files | [`lint.txt`](lint.txt) | see below |
| tests | pass | 849 passed, 0 skipped, 0 failed, 849 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | see below |
| perf | skip | not measured — no `tests/perf.lua` in this addon | — | not measured in either run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 14669 |
| Functions | 2188 |
| Avg NLOC / function | 6.0 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 47.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

**perf is the one suite that is not a clean pass, and it is a skip rather than a failure.** `manifest.json` records the reason verbatim: *"no tests/perf.lua — this addon ships no offline scenarios"*. Nothing ran, so nothing was measured — this is a pre-existing condition of the addon, not a regression in this run, and it is stated in the release notes as well as here. The release gate's perf condition is satisfied by the no-scenarios exception, which means this tag rests on three measured suites.

## What moved

- **lint** — 61 files, up two from 59. Still 0 warnings / 0 errors.
- **tests** — 849 passed, up 5 from 844. No skips, no failures.
- **perf** — skipped in both runs, for the same reason: there is no `tests/perf.lua` to run. Not a regression, and not a measurement.
- **complexity** — NLOC 14455 → 14669 (+214) over 2181 → 2188 functions (+7). Avg NLOC flat at 6.0, avg CCN flat at 2.0, avg tokens 47.4 → 47.5. Max CCN 15 in both, zero warnings in both. Three band files in both runs, none over the cap.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. Zero functions above CCN 15 is what the release gate required, and it is what this run measured — max CCN 15.

### Files by `layout-§1` band

3 file(s) in the 1000–1500 on-notice band, 0 over the 1500 cap. Each carries a disposition in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). The band is not part of the release gate.

## Actions

None. All three band entries carry current dispositions; `modules/Browser.lua` remains owned by `BL-24` with its peel seam named.
