# Analysis — 20260804-182039

- **Addon:** BankLedger 1.0.0
- **Verdict:** green
- **Commit:** d5b372649a11 (master), dirty
- **Started:** 2026-08-04T18:20:39+05:30
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

## Actions

None arising from this run. The dispositions above are carried forward from the complexity reports
written against the same measurements earlier today; each was recorded with its evidence at the
time, and none is new here.
