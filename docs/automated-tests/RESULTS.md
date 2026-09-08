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
| [`20260908-181253`](20260908-181253/) | 1.0.0 | 0/0 | 59 | 844/0/844 | skip | 14455 | 2181 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260825-103400`](20260825-103400/) | 1.0.0 | 0/0 | 28 | 791/791 | skip | 13409 | 2043 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260807-115101`](20260807-115101/) | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260807-110442`](20260807-110442/) | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260807-023005`](20260807-023005/) | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260804-233144`](20260804-233144/) | 1.0.0 | 0/0 | 24 | 726/726 | skip | 12788 | 1946 | 6.0 | 2.1 | 15 | 0 | **green** |
| [`20260804-214843`](20260804-214843/) | 1.0.0 | 0/0 | 24 | 726/726 | skip | 12788 | 1946 | 6.0 | 2.1 | 0 | 0 | **green** |
| [`20260804-182039`](20260804-182039/) | 1.0.0 | 0/0 | 24 | 689/689 | skip | 12085 | 1773 | 6.2 | 2.2 | 33 | 15 | **green** |

## Test suite

**844 cases** — 844 passed, 0 failed, 0 skipped. The generated inventory
[`20260908-181253/test-cases.md`](20260908-181253/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **791 → 844** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 59 files** (`luacheck .`).

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

Current as of [`20260908-181253`](20260908-181253/) — **this run's measurement, not its diff.** Max CCN **15** across 2181
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
| 1000–1500 (on notice) | `modules/Browser.lua` | 1251 | **Already tracked as `BL-24`** (`docs/audits/2026-08-04/02_DEVIATIONS.md`), with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. 1245 at the previous run's commit, +6 when the Filters page folded into the master controls. The cell this replaces read 1358 — a figure last true three runs ago. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1096 | **Accepted.** Entered the band at `20260804-214843` and has moved 45 lines in the month since — 1091 at the previous run's commit, +5 when both settings pages became tab strips. The test-data generator (`makeTestEntry`/`seedCoverage`/`bulkMovements`/`goldMovements`) is a self-contained block and is still the peel seam if it grows. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1478 | **Accepted, and the closest thing here to a trigger.** A suite grows with the cases it pins, and this one covers the addon's core mechanic — 1402 at the previous run's commit, +76 for the cases pinning the guild bank arming on its frame showing. That leaves 22 lines of headroom before `layout-§1`'s 1500 cap, and over the cap is a bug rather than a band entry. Split by concern at the next case, not at 1500. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

