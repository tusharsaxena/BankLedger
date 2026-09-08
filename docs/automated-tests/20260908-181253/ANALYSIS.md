# Analysis — 20260908-181253

- **Addon:** BankLedger 1.0.0
- **Verdict:** green
- **Commit:** 14c86de (`feat/2026-09-07-audit-review-remediation`), clean
- **Previous run:** [`20260825-103400`](../20260825-103400/)

## Headline

Three suites pass and one is a permanent skip. Lint is 0/0 over 59 files, the harness runs 844 cases
with none failed and none skipped, `lizard` warns on nothing at max CCN 15 across 2181 functions,
and `perf` skips because this repository ships no `tests/perf.lua`. Nothing needs acting on.

The reason to read this bundle is the record rather than the result. It is the first written by
test-kit revision 15 and the first whose `RESULTS.md` came out of the runner end to end. The watch
list it replaces was hand-written and dated `20260807-115101` — **three runs behind** — and two of
its three line counts were wrong at the moment the previous run was taken, never mind today:
`modules/Browser.lua` was recorded at 1358 against an actual 1245, and `modules/LedgerTable.lua` at
1052 against 1091. That is `C08` in one repository, and it was not neglect: until today the runner
wrote one table row and a fixed paragraph, so the two tables `automated-tests-§4` mandates had no
producer and the only way to have them was to type them.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260825-103400` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 59 files | [`lint.txt`](lint.txt) | File count 28 → 59; the 0/0 is unchanged |
| tests | pass | 844 passed, 0 skipped, 0 failed, 844 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 791 → 844 |
| perf | skip | no `tests/perf.lua` | — | Unchanged, and permanent |
| complexity | pass | 0 warnings, max CCN 15 | [`complexity.txt`](complexity.txt) | Totals up with the addon; every average flat |

**On the `perf` skip.** This is the first of `automated-tests-§3`'s two sanctioned reasons — *nothing
to run* — and not a ratified `performance-§12` no-combat-path exemption. The record is therefore
**silent about runtime cost**: nothing in this bundle says BankLedger is cheap, only that the
question was never asked. A skip is not a pass, and at the release gate it is NOT EVALUATED.

**Complexity in full**, because one figure cannot be compared across a change in size.

| Metric | `20260825-103400` | This run |
|---|---|---|
| Total NLOC | 13409 | 14455 |
| Functions | 2043 | 2181 |
| Avg NLOC / function | 6.0 | 6.0 |
| Avg CCN | 2.0 | 2.0 |
| Max CCN | 15 | 15 |
| Avg tokens / function | 47.4 | 47.4 |
| Warnings (CCN > 15) | 0 | 0 |
| Files 1000–1500 | 3 | 3 |
| Files over 1500 | 0 | 0 |

Every average is identical to the previous run — NLOC per function, CCN, tokens per function, all
four to the decimal — while the totals rose 8% and 7%. The addon grew and did not get denser, which
is the only reading in which a rising total is not a signal.

## What moved

- **lint** — 28 → 59 files at 0/0. The scope more than doubled because this cycle put files into it,
  not because the exclusions changed.
- **tests** — 791 → 844, none failed and none skipped. `docs/test-cases.md` and the README badge
  already read 844, so no count claim moves in this commit, and the bundle's own
  [`test-cases.md`](test-cases.md) is byte-identical to `docs/test-cases.md` at HEAD.
- **complexity** — nothing warned. Four functions sit at exactly CCN 15 and none above it:
  `I@505-551` (`modules/Insights.lua`), `accumulateItemTaxonomy@247-278` (`core/Database.lua`),
  `L@403-435` (`modules/Ledger.lua`) and `LT@869-885` (`modules/LedgerTable.lua`). Zero headroom on
  four functions is worth stating plainly, because one more `or` on any of them is a warning, and a
  warning blocks a tag (`automated-tests-§3`).
- **Band** — the same three files, all three moved, none newly crossed:
  `modules/Browser.lua` 1245 → 1251, `modules/LedgerTable.lua` 1091 → 1096, and
  `tests/test_ledger.lua` 1402 → 1478. The last one is the one to watch: **22 lines of headroom**
  before `layout-§1`'s 1500 cap, and over the cap is a bug rather than a band entry. Its disposition
  now says to split at the next case rather than at 1500.

## The `ANALYSIS.md` gap, noted once

Three of this repository's eight bundles carry no `ANALYSIS.md` — `20260807-110442`,
`20260825-103400`, and until this file, this one. The first two are not getting one. Writing an
analysis today into a folder stamped in August would date a reading to a day nobody took it, which
is worse than a gap, because a gap is legible and a backdated record is not. Fixed forward: this
bundle has one, and every bundle from here gets one at the time of its run. Collection-wide the same
gap stands at 37 of 95 bundles and closes the same way.

## Actions

None. Three green suites, one permanent skip that the record states rather than hides, no warned
function, no file over cap, and no disposition due for conversion — the three-consecutive-release-
runs clock (`automated-tests-§4`) has not started, because every manifest here carries
`"release": null`.
