# Analysis — 20260807-023005

- **Addon:** BankLedger 1.0.0
- **Verdict:** green
- **Commit:** 70c2e5484afa53b92afe6d01bce6f39008b139f5 (master), dirty
- **Previous run:** [`20260804-233144`](../20260804-233144/)

## Headline

Both gating suites passed: lint clean over 24 files, 727 of 727 cases green with nothing skipped.
Nothing is over CCN 15 and nothing is over the 1500-LOC cap, so the release gate would be satisfied
on these numbers. The only movement worth reading is downward — the tree lost 53 NLOC and four
functions since `20260804-233144`, `modules/Insights.lua` dropped out of the on-notice size band, and
average CCN ticked 2.1 to 2.0. There is nothing to act on.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since `20260804-233144` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 24 files | [`lint.txt`](lint.txt) | Unchanged — same figures, same file count |
| tests | pass | 727 passed, 0 skipped, 0 failed, 727 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +1 net (9 cases added, 8 removed) |
| perf | skip | 0 scenarios — `skipReason`: *no tests/perf.lua — this addon ships no offline scenarios* | none — nothing ran | Unchanged; a standing state, not a tooling gap |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC −53, functions −4, avg CCN 2.1 to 2.0 |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is `manifest.json`'s `suites.complexity`, which records all eight of
`lizard`'s footer fields plus the two derived band counts.

| Metric | Value |
|---|---|
| Total NLOC | 12735 |
| Functions | 1942 |
| Avg NLOC / function | 6.0 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 48.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

**On the one suite that is not a pass:** `perf` is a **skip**, and it is the standing kind rather than
a tooling gap. The manifest's `skipReason` is *"no tests/perf.lua — this addon ships no offline
scenarios"*, which is `automated-tests-§3`'s first sanctioned reason. The second reason is the one
that actually explains it here: BankLedger holds a ratified `performance-§12` no-combat-path
exemption, registered in [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md) with the whole-repo sweep
behind it in [`../../performance.md`](../../performance.md). Either way the consequence for this
bundle is the same and must not be softened: **this run says nothing about the addon's runtime cost**,
and `performance-§9`'s zero-overhead evidence does not exist for it. A skip is not a pass, and at the
release gate it is NOT EVALUATED rather than passed.

## What moved

- **lint** — did not move. 0 warnings / 0 errors over 24 files, identical to `20260804-233144`.
  Worth saying explicitly, because silence on a gating suite reads as "not checked".
- **tests** — 726 to **727**, net +1, and the churn under that net is larger than the net: **nine
  cases added, eight removed**, per a diff of this bundle's [`test-cases.md`](test-cases.md) against
  the previous one. Added: three pinning `Ledger:BuildEntry` / `Ledger:GateReason` against the moved
  *link* rather than the base item, one pinning that `Database:PruneOld` broadcasts `LedgerChanged`
  only when a row actually went, four asserting each degraded LibKa0s seam's stub surface as a set,
  and the re-worded vendored-payload case that now reads the provenance line from `CLAUDE.md`.
  Removed: seven `Insights.RankRows` / `Insights.BarFraction` cases, and the old README-sourced
  wording of the vendor-sync case the `CLAUDE.md` one replaces.
- **perf** — did not move. Skipped on the previous run for the same reason and by the same rule.
- **complexity** — every figure and its direction: NLOC **12788 to 12735** (−53), functions
  **1946 to 1942** (−4), avg NLOC/function **6.0 to 6.0** (flat), avg CCN **2.1 to 2.0**, avg tokens
  **48.0 to 48.0** (flat), max CCN **15 to 15** (flat), warnings **0 to 0** (flat), files in the
  1000–1500 band **4 to 3**, files over the 1500 cap **0 to 0** (flat).

  The averages are the reading that matters. The total fell and the average per function did not,
  which means the tree got *smaller*, not *denser* — four functions' worth of code left and what
  remains is shaped the way it was. Avg CCN moving 2.1 to 2.0 is the same story at one decimal place
  and is not a refactor signal on its own.

## Complexity watch list

### Functions `lizard` warned on

**None.**

That is the result, not an empty section: `complexity.txt`'s footer records `Warning cnt` 0 and
`No thresholds exceeded`. Zero warnings has now held for three consecutive runs.

The peak remains **15** — at the cap rather than under it — and **five** functions sit there, one
more than the four at `20260804-233144`:

| Function | CCN | Location |
|---|---|---|
| `ensureFrame` | 15 | `modules/SessionWindow.lua:441` |
| `I:Layout` | 15 | `modules/Insights.lua:505` |
| `accumulateItemTaxonomy` | 15 | `core/Database.lua:234` |
| `LT:UpdateHeaderArrows` | 15 | `modules/LedgerTable.lua:827` |
| `L:GateReason` | 15 | `modules/Ledger.lua:402` |

`L:GateReason` is the new one, at **14 to 15**. It is the quality gate deciding whether a movement is
recorded, and the previous run's tree measured it at 14 over `402-431`; it is now `402-434`. The
three lines are the change that made the gate judge the **moved link** rather than the base item, and
the three test cases added this run pin exactly that. This is `lizard` counting `and`/`or`
short-circuits as decisions over a run of guard clauses — dense **guarding**, not tangled control
flow — so the fix if it ever needs one is to lift the link/id resolution out, not to restructure the
gate. None of the five is over the cap and none is a warning; they are named because at 15 the next
edit to any of them is the one that trips the release gate.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1402 | **Accepted.** A suite grows with the cases it pins, and this one covers the addon's core mechanic. Up 41 lines this run for the three link-vs-id cases. Split by concern if it passes 1500. |
| 1000–1500 (on notice) | `modules/Browser.lua` | 1358 | **Already tracked as `BL-24`** (`docs/audits/2026-08-04/02_DEVIATIONS.md`), with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. Down 10 lines this run — the window edge now delegates to `Core.ApplySkin`. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1052 | **Accepted for now.** Unmoved since `20260804-214843`. The test-data generator (`makeTestEntry`/`seedCoverage`/`bulkMovements`/`goldMovements`) is a self-contained block and is the peel seam if it grows. |

**`modules/Insights.lua` left the band this run**, 1023 to 992 LOC, which is the whole of the
4 to 3 move in `bandFiles`. Its disposition is retired rather than carried: there is no band entry to
hold one.

Nothing newly crossed into a band, and nothing is over the 1500-LOC cap.

## Actions

**None.** Both gating suites are clean, no function is over CCN 15, no file is over the LOC cap, and
every band disposition is either newly retired or still true as written. The two standing facts that
are not actions and should not be filed as ones: `perf` records nothing about runtime cost by ratified
exemption, and five functions sit exactly at the CCN 15 cap with no headroom.
