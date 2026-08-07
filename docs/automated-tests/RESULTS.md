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
| [`20260807-110442`](20260807-110442/) | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260807-023005`](20260807-023005/) | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
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
[`20260807-023005`](20260807-023005/) — not that run's diff, which is its
[`ANALYSIS.md`](20260807-023005/ANALYSIS.md).

## Test suite

727 cases, all passing, none skipped — the largest suite in the collection. The net +1 on
`20260804-233144` hides real churn: nine cases were added and eight removed. The nine pin the
link-versus-id fix in `Ledger:BuildEntry`/`Ledger:GateReason`, the `Database:PruneOld` broadcast
condition, each degraded LibKa0s seam's stub surface as a set, and the vendored-payload gate now
reading the provenance line from `CLAUDE.md` rather than `README.md`. The eight are the seven
`Insights.RankRows`/`Insights.BarFraction` cases and the superseded README-sourced wording of that
same vendor-sync case. The count is still climbing with the code, so there is no stalled-coverage
signal to flag. The generated inventory `test-cases.md` in each bundle is the authority on what
exists at that point; the README badge tracks the same number. Note what the suite cannot cover: it
is headless, so every in-client behavior — frame creation, taint, real bank events — is covered by
`docs/smoke-tests.md` and by nothing here.

## Lint

Clean over 24 files: 0 warnings, 0 errors. **What is in scope matters more than the `0/0`**, and the
scope is narrower than it looks: `.luacheckrc`'s `exclude_files` is
`{ "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }`, so `luacheck .` lints the addon's
own shipped source — `core/`, `defaults/`, `locales/`, `modules/`, `settings/` — and **not** the
`tests/` tree. The 24 files in the row are exactly those shipped files, one per TOC entry; the ~20
suites under `tests/` are never linted. That is a deliberate exclusion rather than an oversight — the
harness files are checked by running them — but a reader comparing this `0/0` against another addon's
should know it covers roughly half the repo's Lua. `libs/` and `tests/_kit/` are out of scope because
neither is this repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a
transient tooling gap — and that absence is a **ratified state, not a gap**. BankLedger holds a
recorded `performance-§12` no-combat-path exemption: the register row is in
[`../ARCHITECTURE.md`](../ARCHITECTURE.md) and the whole-repo sweep that earns it is
[`../performance.md`](../performance.md), which is why there is no `tests/perf.lua`, no `perf` verb
registration and no `docs/perf-runs/` store. Two things still follow, and both are standing facts
rather than any run's news: the record says **nothing** about the addon's in-combat runtime cost, and
`performance-§9`'s zero-overhead evidence — that bracketed instrumentation is free when capture is
off — does not exist for it. (The older framing of these as gaps, `BL-15` and `BL-16` in
`docs/audits/2026-08-04/02_DEVIATIONS.md`, is superseded by the exemption; that bundle stands as
frozen evidence of what was true when it was written.) The reason to name for this column is the
exemption, not the bare absence of the file. A `skip` is never a pass — this column records that the
suite did not run, not that it ran clean, and at the release gate it is NOT EVALUATED.

## Complexity watch list

Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC on-notice
threshold, each with a one-line disposition — current state as of
[`20260807-023005`](20260807-023005/).

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| — | — | — | **None.** |

That is the result, not an empty section. `lizard` warned on fifteen functions at `20260804-182039`
and on none since `20260804-214843` — three consecutive runs now clean. `feat/fix-ccn` peeled every
one of them below the cap, and the whole watch list from `20260804-182039` is gone with it. Their old
dispositions are not carried forward: an "Accepted" with no warning attached to it is noise on a
future reader's desk. The frozen `20260804-182039` bundle keeps them if the reasoning is ever wanted.

The highest CCN measured anywhere in the tree is **15** — at the cap, not under it by a comfortable
margin — and **five** functions sit there, up from four at `20260804-233144`: `ensureFrame`
(`modules/SessionWindow.lua:441`), `I:Layout` (`modules/Insights.lua:505`), `accumulateItemTaxonomy`
(`core/Database.lua:234`), `LT:UpdateHeaderArrows` (`modules/LedgerTable.lua:827`) and — new this run,
at 14 → 15 — `L:GateReason` (`modules/Ledger.lua:402`). `L:GateReason` grew three lines when the
quality gate learned to judge the **moved link** rather than the base item. All five are dense
**guarding** rather than tangled control flow: `lizard` scores every `and`/`or` short-circuit as a
decision, and a run of Lua guard clauses reads high with no visible branching. None is a warning and
none is over the cap, but at 15 there is no headroom, so the next edit to any of the five is the one
that would trip the release gate.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1402 | **Accepted.** A suite grows with the cases it pins, and this one covers the addon's core mechanic. Up 41 lines at `20260807-023005` for the three link-versus-id cases. Split by concern if it passes 1500. |
| 1000–1500 (on notice) | `modules/Browser.lua` | 1358 | **Already tracked as `BL-24`** (`docs/audits/2026-08-04/02_DEVIATIONS.md`), with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. Down 10 lines at `20260807-023005`, when the window edge began delegating to `Core.ApplySkin`. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1052 | **Accepted for now.** Entered the band at `20260804-214843` and unmoved since. The test-data generator (`makeTestEntry`/`seedCoverage`/`bulkMovements`/`goldMovements`) is a self-contained block and is the peel seam if it grows. |

Nothing newly crossed a band at `20260807-023005`, and nothing is over the 1500-LOC cap.
**`modules/Insights.lua` left the band**, 1023 → 992 LOC, which is the whole of the 4 → 3 move in the
manifest's `bandFiles`; its disposition is retired rather than carried, since there is no entry left
to hold one.

**On the shelf life of these dispositions** (`automated-tests-§4`, anti-pattern #53): the clock runs
in **release** runs, and `RESULTS.md`'s git history shows this record has never carried one — every
manifest under `docs/automated-tests/` has `"release": null`. So no "Accepted" here has yet spent a
release, let alone three. `tests/test_ledger.lua` and `modules/LedgerTable.lua` are the two to watch
when the first release run lands; `modules/Browser.lua` already points at a tracked ID and is not
subject to the clock.
