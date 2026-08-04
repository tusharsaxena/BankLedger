# Analysis — 20260804-122506

- **Addon:** BankLedger 1.0.0
- **Verdict:** green
- **Commit:** 9854b89933c0 (master), dirty
- **Previous run:** none — this is the first recorded run

## Headline

The first automated-test record for this addon, produced while adopting `automated-tests`
(standard v2.19.0). Both gating suites are clean: `luacheck` reports 0 warnings / 0 errors across
24 files and the headless harness passes 689 of 689 cases. The offline perf runner is absent (see below). Every figure below is a **baseline** —
there is no previous run to diff against, so nothing here is a regression and nothing is an
improvement.

## Suites

| Suite | Status | Result | Artifact | Moved since previous run |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 24 files | [`lint.txt`](lint.txt) | — first run |
| tests | pass | 689 passed, 0 failed, 689 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | — first run |
| perf | skip | — | — (not run) | — first run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | — first run |

### Complexity in full

Every field of `lizard`'s footer, plus the two derived file counts. The **averages** are what make
this run comparable to the next one across a change in size: a total that rises because the addon
grew is a different fact from an average that rises because it got denser, and only the second is a
complexity signal.

| Metric | Value |
|---|---|
| Total NLOC | 12085 |
| Functions | 1773 |
| Avg NLOC / function | 6.2 |
| Avg CCN | 2.2 |
| Max CCN | 33 |
| Avg tokens / function | 50.2 |
| Warnings (CCN > 15) | 15 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.01 / 0.06 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured there. That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run says nothing about the addon's runtime cost.

## What moved

**First run — nothing to diff against; every figure above is a baseline reading.** The next run is
the first one that can say something moved, and this record is what it will be read against.

## Complexity watch list

Fifteen functions over CCN 15. Five are **parser over-spans** — lizard's Lua front end does not always close a colon-method body, so those ranges swallow their siblings and read high; they are marked as such in `complexity.txt` and their real cost is lower. The genuine entries are `L:Reconcile` (24), `L.Diff` (22), `groupOf` (25) and `P:Diagnose` (31), all **accepted** with reasons recorded at 2026-08-04.

**Files in the 1000–1500 band:** `tests/test_ledger.lua` (1361) — accepted, case count not tangle; `modules/Browser.lua` (1306) — **already tracked as BL-24**.

## Actions

None arising from this run. The dispositions above are carried forward from the complexity reports
written against the same measurements earlier today; each was recorded with its evidence at the
time, and none is new here.
