# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

| Run | Version | Lint w/e | Tests | Perf | CCN warn | Max CCN | Verdict |
|---|---|---|---|---|---|---|---|
| [`20260804-122506`](20260804-122506/) | 1.0.0 | 0/0 | 689/689 | skip | 15 | 33 | **green** |

## Complexity watch list

Current state as of [`20260804-122506`](20260804-122506/) — not that run's diff.
Every function `lizard` warned on and every file in `layout-§1`'s 1000–1500 on-notice band,
each with a one-line disposition.

Fifteen functions over CCN 15. Five are **parser over-spans** — lizard's Lua front end does not always close a colon-method body, so those ranges swallow their siblings and read high; they are marked as such in `complexity.txt` and their real cost is lower. The genuine entries are `L:Reconcile` (24), `L.Diff` (22), `groupOf` (25) and `P:Diagnose` (31), all **accepted** with reasons recorded at 2026-08-04.

**Files in the 1000–1500 band:** `tests/test_ledger.lua` (1361) — accepted, case count not tangle; `modules/Browser.lua` (1306) — **already tracked as BL-24**.
