# Analysis — 20260804-114702

- **Addon:** BankLedger 1.0.0
- **Verdict:** green
- **Commit:** 6f5a8432c184 (master), dirty
- **Previous run:** none — this is the first recorded run

## Headline

The first automated-test record for this addon, produced while adopting `automated-tests`
(standard v2.19.0). Both gating suites are clean: `luacheck` reports 0 warnings / 0 errors across
24 files and the headless harness passes 689 of 689 cases. The offline perf runner is absent (see below). Every figure below is a **baseline** —
there is no previous run to diff against, so nothing here is a regression and nothing is an
improvement.

## Suites

| Suite | Status | Result | Moved since previous run |
|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 24 files (`lint.txt`) | — first run |
| tests | pass | 689 passed, 0 failed, 689 total (`tests.txt`) | — first run |
| perf | skip | skip | — first run |
| complexity | pass | 15 warnings, max CCN 33, 12085 NLOC / 1773 functions (`complexity.txt`) | — first run |

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured here. That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run says nothing about the addon's runtime cost.

## What moved

**First run — nothing to diff against; every figure above is a baseline reading.** The next run is
the first one that can say something moved, and this record is what it will be read against.

## Complexity watch list

Fifteen functions over CCN 15. Five are **parser over-spans** — lizard's Lua front end does not always close a colon-method body, so those ranges swallow their siblings and read high; they are marked as such in the run's `complexity.txt` and their real cost is lower. The genuine entries are `L:Reconcile` (24), `L.Diff` (22), `groupOf` (25) and `P:Diagnose` (31), all **accepted** with reasons recorded at 2026-08-04.

**Files in the 1000–1500 band:** `tests/test_ledger.lua` (1361) — accepted, case count not tangle; `modules/Browser.lua` (1306) — **already tracked as BL-24**.

## Actions

None arising from this run. The dispositions above are carried forward from the complexity reports
written against the same measurements earlier today; each was recorded with its evidence at the
time, and none is new here.
