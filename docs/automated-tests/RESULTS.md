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
| [`20260804-182039`](20260804-182039/) | 1.0.0 | 0/0 | 24 | 689/689 | skip | 12085 | 1773 | 6.2 | 2.2 | 33 | 15 | **green** |

## Test suite

689 cases — the largest suite in the collection. `tests/test_ledger.lua` alone pins the reconcile mechanic, whose branches the module header records as each having been a bug once. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 24 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a transient tooling gap. Two things follow, and both are standing facts rather than this run's news: the record says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence — that bracketed instrumentation is free when capture is off — does not exist for it. Adding scenarios is the only thing that changes either.

## Complexity watch list

Current state as of [`20260804-182039`](20260804-182039/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `Database:QueryList` | 33 | `core/Database.lua` | **Accepted** — *parser over-span*: the range swallows `matches`, `Query` and `Export`, so the real cost is lower. One filter predicate per supported facet. |
| `P:Diagnose` | 31 | `settings/Panel.lua` | **Accepted — diagnostic, not a hot path.** Counts frame regions to tell stock art from skinned; never called except by the user. |
| `I:RenderDirectionSplit` | 28 | `modules/Insights.lua` | **Peel next, if it grows** — *over-spans* into `I:LayoutSections`, which is the real seam to watch. |
| `menu:Populate` | 26 | `modules/Browser.lua` | **Already tracked as `BL-24`**, whose named peel seam is exactly this widget-factory block. |
| `groupOf` | 25 | `modules/LedgerTable.lua` | **Accepted and deliberate.** One branch per group mode, producing the collision-proof key and its label in one pass. |
| `L:Reconcile` | 24 | `modules/Ledger.lua` | **Accepted, with a warning attached.** The core mechanic; its header records each branch as having been a bug once. Refactor test-first only. |
| `L.Diff` | 22 | `modules/Ledger.lua` | **Accepted.** Pure, deterministic, the most-tested function in the addon; its ordering guarantee is what lets suites assert by index. |
| `I.CardValues` | 21 | `modules/Insights.lua` | **Accepted.** Split out of layout so the formatting rules are testable; one branch per card. |
| `__index` | 21 | `tests/wow_mock.lua` | **Accepted — mock fidelity.** One branch per frame method the suites exercise. Test-only, never shipped. |
| `B:CaptureView` | 20 | `modules/Browser.lua` | **Already tracked as `BL-24`.** Fifteen lines; the CCN is `and`/`or` fallbacks, not control flow. |
| `W.BuildStackRows` | 19 | `modules/InsightsWidgets.lua` | **Accepted.** Pure row builder with a documented options contract; every branch is an `opts` default. |
| `LT:OrderedFilteredEntries` | 18 | `modules/LedgerTable.lua` | **Accepted** — *over-spans* into the test-data generator that follows it. The named function is six lines. |
| `LT:PaintCell` | 17 | `modules/LedgerTable.lua` | **Accepted.** The single definition of "what colour is this cell", so two views can never disagree. |
| `B:ApplyView` | 16 | `modules/Browser.lua` | **Already tracked as `BL-24`.** The branch count is a documented ordered write sequence — order is load-bearing. |
| `I:RenderStrip` | 16 | `modules/Insights.lua` | **Not a real finding** — *over-spans badly*; `RenderStrip` itself ends at :432. Ignore until the parser range is trustworthy. |

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1361 | **Accepted.** A suite grows with the cases it pins, and this one covers the addon's core mechanic. Split by concern if it passes 1500. |
| 1000–1500 (on notice) | `modules/Browser.lua` | 1306 | **Already tracked as `BL-24`**, with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. |
