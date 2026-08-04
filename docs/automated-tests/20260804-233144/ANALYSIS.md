# Analysis — 20260804-233144

- **Addon:** BankLedger 1.0.0
- **Verdict:** green
- **Commit:** 405571eedba7 (feat/fix-ccn), dirty
- **Started:** 2026-08-04T23:31:44+05:30
- **Previous run:** [`20260804-214843`](../20260804-214843/) (green)

## Headline

This is the run that closes the CCN work, and it closes it by finally being able to state the
number. Both gating suites are clean — `luacheck` reports 0 warnings / 0 errors across 24 files, and
the headless harness passes 726 of 726 — and the complexity suite records what the previous run
could not: **zero functions over CCN 15, with the true maximum at 15**. The code is the same code
the previous run measured; what changed is the instrument. Testkit rev 6 computes `Max CCN` over
every function, where the older kit read it out of `lizard`'s warnings block and therefore printed
`0` the moment the warnings were gone.

Nothing else moved. `perf` is still a skip — this addon ships no `tests/perf.lua` — so this record
says nothing at all about runtime cost.

## Suites

| Suite | Status | Result | Artifact | Moved since [`20260804-214843`](../20260804-214843/) |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 24 files | [`lint.txt`](lint.txt) | unchanged — same 24 files, same 0/0 |
| tests | pass | 726 passed, 0 failed, 726 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged — 726/726, inventory byte-identical |
| perf | skip | not measured — no `tests/perf.lua` | — (no artifact) | unchanged — still skipped |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | `Max CCN` now reported: **15**, not `0` |

### Complexity in full

Every field of `lizard`'s footer as `manifest.json`'s `suites.complexity` records it, plus the two
derived file counts. Totals and averages both, because they answer different questions: a total that
rose because the addon grew is not the same fact as an average that rose because it got denser.
Here neither moved — this is the same tree the previous run measured.

| Metric | Value | Previous (`20260804-214843`) |
|---|---|---|
| Total NLOC | 12788 | 12788 |
| Functions | 1946 | 1946 |
| Avg NLOC / function | 6.0 | 6.0 |
| Avg CCN | 2.1 | 2.1 |
| Max CCN | **15** | `0` — instrument fault, see below |
| Avg tokens / function | 48.0 | 48.0 |
| Warnings (CCN > 15) | **0** | 0 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.00 / 0.00 | 0.00 / 0.00 |
| Files in the 1000–1500 band | 4 | 4 |
| Files over the 1500 cap | 0 | 0 |

[`complexity.txt`](complexity.txt) closes with *"No thresholds exceeded (cyclomatic_complexity > 15
or length > 1000 or nloc > 1000000 or parameter_count > 100)"* and a footer of
`12788 / 6.0 / 2.1 / 48.0 / 1946 / 0 / 0.00 / 0.00`. That is the whole complexity result: the cap is
met with nothing above it, and the peak sits exactly on the line.

**On the previous run's `Max CCN` of `0`.** It was never a measurement. The kit that produced
`20260804-214843` read `CCN_MAX` out of `lizard`'s warnings block, which lists only functions over
the threshold — so once `feat/fix-ccn` drove the warning count to zero, the block was empty and the
kit recorded `0`. The true figure was in that bundle all along, in its own
[`complexity.txt`](../20260804-214843/complexity.txt), which is byte-identical to this run's. Read a
`Max CCN` of `0` in any row before this one as "no function exceeded 15", never as "no complexity".

`tests/perf.lua` is absent, so the perf suite measured nothing. `manifest.json` records it as a
`skip` with the reason *"no tests/perf.lua — this addon ships no offline scenarios"*. That is a
skip, not a pass, and it is a standing property of the addon rather than a tooling gap on the day.

## What moved

- **`Max CCN`: `0` → 15 with no code change.** The commit under test moved from `fb54d6695091` to
  `405571eedba7`, which is a documentation commit; [`complexity.txt`](complexity.txt),
  [`lint.txt`](lint.txt), [`tests.txt`](tests.txt) and [`test-cases.md`](test-cases.md) are each
  byte-identical to the previous bundle's copy. The trend column's jump is the instrument, and the
  instrument is now right.
- **Complexity: 0 warned functions, held.** The previous run got the count to zero; this one shows
  it was zero for the right reason. Four functions sit exactly at 15 — named in the watch list below.
- **Tests: 726 → 726, still 0 failed.** No case was added or lost between the two runs.
- **Lint: 0/0 over 24 files, unchanged.**
- **Size: 12788 NLOC over 1946 functions, unchanged.** Both averages held, at 6.0 NLOC and 2.1 CCN
  per function.

## Complexity watch list

### Functions `lizard` warned on

**None.** No function is above CCN 15, so `lizard` warned on nothing —
[`complexity.txt`](complexity.txt)'s footer records `Warning cnt 0` over 1946 functions. That is the
result the branch was opened for, and this is the first run whose instrument can prove it rather
than merely fail to contradict it.

The functions that sit **at** the cap are the ones to watch, and there are exactly four of them —
[`complexity.txt`](complexity.txt) lists no others at 15:

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `ensureFrame` | 15 | `modules/SessionWindow.lua:437` | **Watch.** At the cap, and the largest of the four at 89 NLOC. Next peel if anything touches it. |
| `I:Layout` | 15 | `modules/Insights.lua:536` | **Watch.** At the cap. Section dispatch across seventeen chart sections; one more section puts it over. |
| `accumulateItemTaxonomy` | 15 | `core/Database.lua:234` | **Watch.** At the cap. One more taxonomy facet puts it over. |
| `LT:UpdateHeaderArrows` | 15 | `modules/LedgerTable.lua:827` | **Watch.** At the cap, and the smallest of the four at 17 NLOC — mostly `and`/`or` guards rather than tangle. |

The previous run's analysis named `accumulateItemTaxonomy` alone as the function at 15. That was a
spot check, not the full listing, and the listing has four. The frozen bundle stands as written and
this is the correction, per `automated-tests-§1`.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1368 | **Already tracked as `BL-24`.** Peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. Unmoved since the previous run. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1361 | **Accepted.** A suite grows with the cases it pins, and this one pins the reconcile mechanic. Split by concern if it passes 1500. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1052 | **Accepted.** Entered the band on the previous run, when `groupOf`, `PaintCell` and `BuildTestData` were peeled into file-locals. The test-data generator is the peel seam if it grows. |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1023 | **Accepted.** Entered the band on the previous run, when `LayoutSections` was split into one `section*` helper per chart. The ranked-panel grid is the natural sibling file. |

`manifest.json` records `bandFiles: 4` and `overCapFiles: 0`, so those four are the whole band and
nothing is over the 1500 cap.

## Actions

1. **Watch the four functions at CCN 15** — `ensureFrame` (`modules/SessionWindow.lua:437`),
   `I:Layout` (`modules/Insights.lua:536`), `accumulateItemTaxonomy` (`core/Database.lua:234`) and
   `LT:UpdateHeaderArrows` (`modules/LedgerTable.lua:827`). None is a finding today; each is one
   guard away from being one. New here — no deviation ID covers them.
2. **Keep the `Max CCN` annotation in `docs/automated-tests/RESULTS.md`** for as long as the
   `20260804-214843` and `20260804-182039` rows are in the table, so a reader crossing `33 → 0 → 15`
   reaches the explanation in one step. The rows themselves stay exactly as measured.
3. **The `perf` skip stands.** Nothing changes it until the addon ships `tests/perf.lua`; the absence
   is tracked as `BL-15` in `docs/audits/2026-08-04/02_DEVIATIONS.md`.
