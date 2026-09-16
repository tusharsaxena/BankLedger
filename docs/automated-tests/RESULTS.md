# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

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

The **Tests** cell reads `passed/skipped/total`.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260916-184426`](20260916-184426/) | 1.1.0 | 0/0 | 67 | 943/0/943 | skip | 16380 | 2498 | 5.9 | 2.0 | 15 | 0 | **green** |
| [`20260916-094506`](20260916-094506/) | 1.1.0 | 0/0 | 61 | 913/0/913 | skip | 15821 | 2401 | 5.9 | 2.0 | 17 | 1 | **green** |
| [`20260910-234511`](20260910-234511/) | 1.0.0 → 1.1.0 | 0/0 | 61 | 849/0/849 | skip | 14669 | 2188 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260908-181253`](20260908-181253/) | 1.0.0 | 0/0 | 59 | 844/0/844 | skip | 14455 | 2181 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260825-103400`](20260825-103400/) | 1.0.0 | 0/0 | 28 | 791/791 | skip | 13409 | 2043 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260807-115101`](20260807-115101/) | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260807-110442`](20260807-110442/) | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260807-023005`](20260807-023005/) | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260804-233144`](20260804-233144/) | 1.0.0 | 0/0 | 24 | 726/726 | skip | 12788 | 1946 | 6.0 | 2.1 | 15 | 0 | **green** |
| [`20260804-214843`](20260804-214843/) | 1.0.0 | 0/0 | 24 | 726/726 | skip | 12788 | 1946 | 6.0 | 2.1 | 0 | 0 | **green** |
| [`20260804-182039`](20260804-182039/) | 1.0.0 | 0/0 | 24 | 689/689 | skip | 12085 | 1773 | 6.2 | 2.2 | 33 | 15 | **green** |

## Test suite

**943 cases** — 943 passed, 0 failed, 0 skipped. The generated inventory
[`20260916-184426/test-cases.md`](20260916-184426/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **913 → 943** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 67 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` sets `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`, so those paths
are not in it. A `0/0` that never moves is partly a statement about what was never looked at, which
is why the exclusion is restated on every run.

## Perf

**This repo ships no `tests/perf.lua`, so `perf` is a permanent `skip`** — the first of
`automated-tests-§3`'s two sanctioned reasons, *nothing to run*, rather than a ratified
`performance-§12` no-combat-path exemption. The record is therefore **silent about runtime
cost**: nothing in this file says this addon is fast or cheap, only that the question was
never asked.

## Complexity watch list

Current as of [`20260916-184426`](20260916-184426/) — **this run's measurement, not its diff.** Max CCN **15** across 2498
functions, **0** of them warned on; 3 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1208 | **Already tracked as `BL-24`** (`docs/audits/2026-08-04/02_DEVIATIONS.md`), with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. Carried forward; −44 this run, moving the right way under its own ID. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1132 | **Accepted** — carried forward unchanged, and the entry itself did not move a line this run. The test-data generator (`makeTestEntry`/`seedCoverage`/`bulkMovements`/`goldMovements`) is a self-contained block and is still the peel seam if it grows. Shelf life: this record holds exactly **one** release run (`20260910-234511`), so the three-consecutive-releases rule has not been reached. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1028 | **Accepted — arriving, not drifting.** New in this table, but it entered the band from **above**: 1539 and over the cap at the previous run, split in `684107c` into `tests/test_ledger_settling.lua`. Case count, not tangle — avg CCN 1.1 over 135 functions ([`20260916-184426/complexity.txt`](20260916-184426/complexity.txt)). Re-check trigger: 1200 LOC, at which the settling/marks boundary is the next seam. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

