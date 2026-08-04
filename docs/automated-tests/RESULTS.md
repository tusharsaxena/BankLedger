# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate. `perf` and `complexity` are recorded and never fail a run** —
they are read and compared, not thresholded. A `skip` is a suite that did not run at all,
which is never the same as a pass.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260804-233144`](20260804-233144/) | 1.0.0 | 0/0 | 24 | 726/726 | skip | 12788 | 1946 | 6.0 | 2.1 | 15 | 0 | **green** |
| [`20260804-214843`](20260804-214843/) | 1.0.0 | 0/0 | 24 | 726/726 | skip | 12788 | 1946 | 6.0 | 2.1 | 0 | 0 | **green** |
| [`20260804-182039`](20260804-182039/) | 1.0.0 | 0/0 | 24 | 689/689 | skip | 12085 | 1773 | 6.2 | 2.2 | 33 | 15 | **green** |

## Test suite

726 cases — the largest suite in the collection, up 37 on the previous run. Those 37 are the cover the CCN work bought itself: every function peeled apart on `feat/fix-ccn` had its behavior pinned before it was touched, plus a new `tests/test_mock.lua` that pins the frame stub the UI suites all stand on. `tests/test_ledger.lua` alone pins the reconcile mechanic, whose branches the module header records as each having been a bug once. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 24 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a transient tooling gap. Two things follow, and both are standing facts rather than this run's news: the record says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence — that bracketed instrumentation is free when capture is off — does not exist for it. Adding scenarios is the only thing that changes either.

## Complexity watch list

Current state as of [`20260804-214843`](20260804-214843/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

**None.**

That is the result, not an empty section. `lizard` warned on fifteen functions in the previous run
and warns on none in this one: `feat/fix-ccn` peeled every one of them below the cap, and the whole
watch list from `20260804-182039` — `Database:QueryList`, `P:Diagnose`, `I:RenderDirectionSplit`,
`menu:Populate`, `groupOf`, `L:Reconcile`, `L.Diff`, `I.CardValues`, `wow_mock`'s `__index`,
`B:CaptureView`, `W.BuildStackRows`, `LT:OrderedFilteredEntries`, `LT:PaintCell`, `B:ApplyView` and
`I:RenderStrip` — is gone with it. Their old dispositions are not carried forward: an "Accepted"
that no longer has a warning attached to it is just noise on a future reader's desk. The frozen
`20260804-182039` bundle keeps them if the reasoning is ever wanted.

The highest CCN measured anywhere in the tree is now **15**, in `accumulateItemTaxonomy`
(`core/Database.lua:234`) — at the cap, not under it by a comfortable margin, so it is the function
to watch. `lizard`'s footer reports `Max CCN` only across *warned* functions, which is why the run
row above records `0`; that column means "no warnings", not "no branches".

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1368 | **Already tracked as `BL-24`**, with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. Up 62 on the previous run — the CCN work traded height for width here, extracting `menu:Populate`'s widget factory into named file-locals in the same file rather than a new one. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1361 | **Accepted.** A suite grows with the cases it pins, and this one covers the addon's core mechanic. Unmoved by this branch. Split by concern if it passes 1500. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1052 | **New to the band.** Crossed 1000 when `groupOf`, `PaintCell` and `BuildTestData` were peeled into file-local helpers. Accepted for now; the test-data generator (`makeTestEntry`/`seedCoverage`/`bulkMovements`/`goldMovements`) is a self-contained block and is the peel seam if it grows. |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1023 | **New to the band.** Crossed 1000 when `LayoutSections` was split into one `section*` helper per chart. Accepted: the file is seventeen chart sections and their layout, and the split is what made each one readable. Watch it — the ranked-panel grid is the natural sibling file. |
