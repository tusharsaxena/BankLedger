# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260804-233144`](20260804-233144/) | 1.0.0 | 0/0 | 24 | 726/726 | skip | 12788 | 1946 | 6.0 | 2.1 | 15 | 0 | **green** |
| [`20260804-214843`](20260804-214843/) | 1.0.0 | 0/0 | 24 | 726/726 | skip | 12788 | 1946 | 6.0 | 2.1 | 0 | 0 | **green** |
| [`20260804-182039`](20260804-182039/) | 1.0.0 | 0/0 | 24 | 689/689 | skip | 12085 | 1773 | 6.2 | 2.2 | 33 | 15 | **green** |

**Reading the `Max CCN` column: the `0` is an instrument fault, not a measurement.** Every run
recorded before the testkit rev-6 re-vendor — here that is `20260804-182039` and `20260804-214843` —
took that number from `lizard`'s warnings block, which lists only functions *over* the threshold. So
it reported the worst **warned** function, and it printed `0` the moment an addon reached zero
warnings, which is exactly what happened at `20260804-214843`. The true maximum for an affected run
is in that same bundle's own `complexity.txt` — for `20260804-214843` it is **15**, over a tree
byte-identical to the next run's. Rev 6 measures over every function, so `20260804-233144` onward
reads as "the worst function". The rows themselves stand as recorded: a bundle is frozen evidence,
and a hand-corrected number reads as measured (`performance-§10`).

The four sections below describe the **current** state, as of the newest run
[`20260804-233144`](20260804-233144/) — not that run's diff, which is its
[`ANALYSIS.md`](20260804-233144/ANALYSIS.md).

## Test suite

726 cases — the largest suite in the collection. Unchanged since `20260804-214843`, and up 37 on the adoption run `20260804-182039`. Those 37 are the cover the CCN work bought itself: every function peeled apart on `feat/fix-ccn` had its behavior pinned before it was touched, plus a new `tests/test_mock.lua` that pins the frame stub the UI suites all stand on. `tests/test_ledger.lua` alone pins the reconcile mechanic, whose branches the module header records as each having been a bug once. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 24 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a transient tooling gap — and that absence is now a **ratified state, not a gap**. BankLedger holds a recorded `performance-§12` no-combat-path exemption: the register row is in [`../ARCHITECTURE.md`](../ARCHITECTURE.md#documented-deviations) and the whole-repo sweep that earns it is [`../performance.md`](../performance.md), which is why there is no `tests/perf.lua`, no `perf` verb registration and no `docs/perf-runs/` store. Two things still follow, and both are standing facts rather than this run's news: the record says **nothing** about the addon's in-combat runtime cost, and `performance-§9`'s zero-overhead evidence — that bracketed instrumentation is free when capture is off — does not exist for it. (The older framing of these as gaps, `BL-15` and `BL-16` in `docs/audits/2026-08-04/02_DEVIATIONS.md`, is superseded by the exemption; that bundle stands as frozen evidence of what was true when it was written.) The reason to name for this column is now the exemption, not the bare absence of the file. A `skip` is never a pass — this column records that the suite did not run, not that it ran clean.

## Complexity watch list

Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition — current state as of
[`20260804-233144`](20260804-233144/).

### Functions `lizard` warned on

**None.**

That is the result, not an empty section. `lizard` warned on fifteen functions at `20260804-182039`
and on none since `20260804-214843`: `feat/fix-ccn` peeled every one of them below the cap, and the whole
watch list from `20260804-182039` — `Database:QueryList`, `P:Diagnose`, `I:RenderDirectionSplit`,
`menu:Populate`, `groupOf`, `L:Reconcile`, `L.Diff`, `I.CardValues`, `wow_mock`'s `__index`,
`B:CaptureView`, `W.BuildStackRows`, `LT:OrderedFilteredEntries`, `LT:PaintCell`, `B:ApplyView` and
`I:RenderStrip` — is gone with it. Their old dispositions are not carried forward: an "Accepted"
that no longer has a warning attached to it is just noise on a future reader's desk. The frozen
`20260804-182039` bundle keeps them if the reasoning is ever wanted.

The highest CCN measured anywhere in the tree is now **15** — at the cap, not under it by a
comfortable margin — and **four** functions sit there, so all four are the ones to watch:
`ensureFrame` (`modules/SessionWindow.lua:437`), `I:Layout` (`modules/Insights.lua:536`),
`accumulateItemTaxonomy` (`core/Database.lua:234`) and `LT:UpdateHeaderArrows`
(`modules/LedgerTable.lua:827`).

Those four are the whole list at 15 — `20260804-233144`'s `complexity.txt` records no other function
there — and they are what closes the CCN work: `20260804-214843` measured the same tree with an
instrument that could not report the maximum, and `20260804-233144` is the first run able to say
plainly that nothing is over 15 and the peak is 15. See the `Max CCN` note under the table for why
the column reads `33 → 0 → 15`.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1368 | **Already tracked as `BL-24`**, with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. Unmoved since `20260804-214843`, which is where it gained 62 lines — the CCN work traded height for width here, extracting `menu:Populate`'s widget factory into named file-locals in the same file rather than a new one. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1361 | **Accepted.** A suite grows with the cases it pins, and this one covers the addon's core mechanic. Unmoved since `20260804-182039`. Split by concern if it passes 1500. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1052 | **Entered the band at `20260804-214843`.** Crossed 1000 when `groupOf`, `PaintCell` and `BuildTestData` were peeled into file-local helpers. Accepted for now; the test-data generator (`makeTestEntry`/`seedCoverage`/`bulkMovements`/`goldMovements`) is a self-contained block and is the peel seam if it grows. |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1023 | **Entered the band at `20260804-214843`.** Crossed 1000 when `LayoutSections` was split into one `section*` helper per chart. Accepted: the file is seventeen chart sections and their layout, and the split is what made each one readable. Watch it — the ranked-panel grid is the natural sibling file. |
