# Analysis — 20260926-193102

- **Addon:** BankLedger 1.1.0
- **Verdict:** green
- **Commit:** `d67564c84e1686ed8eac00bc7f1270ff4c415b2d` (feat/2026-09-26-automated-tests-sweep), clean
- **Previous run:** `20260926-160240`

## Headline

Both gating suites pass: `luacheck` is clean over 76 files and the harness runs the same 1104 cases
as the previous run, all passing, none skipped. The one planned move landed: `tests/test_libka0s.lua`
left the `layout-§1` on-notice band after its LibKa0s-Slash cases were split out (`BL-ATS-01`), so the
band holds **4** files, down from 5. Max CCN is still 15, with zero warnings and zero files over the
cap. `perf` is a skip under the addon's ratified `performance-§12` exemption. Nothing here needs action.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260926-160240` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 76 files | [`lint.txt`](lint.txt) | 0/0 unchanged; scope 75 → 76 files (`tests/test_libka0s_slash.lua`) |
| tests | pass | 1104 passed, 0 skipped, 0 failed, 1104 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged at 1104; 22 cases moved between files |
| perf | skip | `performance-§12` no-combat-path exemption (ratified) | none; nothing ran by design | unchanged: same skip, same reason |
| complexity | pass | 0 warnings, max CCN 15; see below | [`complexity.txt`](complexity.txt) | 0 → 0 warnings; band files 5 → 4 |

**Complexity is reported in full**, totals and averages both. Every value below is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 19199 |
| Functions | 2921 |
| Avg NLOC / function | 6.0 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 47.1 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 4 |
| Files over the 1500 cap | 0 |

**`perf`: a skip, not a pass.** [`manifest.json`](manifest.json) records `skipReason:
"performance-§12 no-combat-path exemption (ratified; docs/ARCHITECTURE.md -> Documented
deviations)"`, the second of `automated-tests-§3`'s two sanctioned reasons. The sweep behind the
exemption is `docs/performance.md`. At a release this suite is **NOT EVALUATED**, not passed.

**`complexity`: a pass.** [`complexity.txt`](complexity.txt) reads `No thresholds exceeded`. The
same five functions sit exactly at CCN 15, at the same locations as the previous run:
`accumulateItemTaxonomy` (`core/Database.lua:275`), `I` (`modules/Insights.lua:505`), `L`
(`modules/Ledger.lua:428`) and two `LT` closures (`modules/LedgerTable.lua:599` and `:905`). None is
above the threshold, but growth in any of them would trip the release gate.

## What moved

Three commits separate this run from the previous one (`0851298` → `d67564c`): the run record itself
(`BL-ATS-00`), the LibKa0s v1.62.0 re-vendor at kit revision 31 (`BL-ATS-RV`, which touches only
`libs/` and `tests/_kit/`, both outside lint and `lizard` scope), and the split of
`tests/test_libka0s.lua` (`BL-ATS-01`). No addon source under `core/`, `modules/` or `settings/`
changed.

- **lint:** 0 warnings / 0 errors at both runs, over **75 → 76** files. The new file is
  `tests/test_libka0s_slash.lua` ([`lint.txt`](lint.txt)).
- **tests:** **1104 → 1104**, all passing, none skipped ([`tests.txt`](tests.txt)). Per
  [`test-cases.md`](test-cases.md), `test_libka0s.lua` went 66 → 44 and the new
  `test_libka0s_slash.lua` holds 22. The set of case names is identical to the previous
  inventory's, so this is a move and adds no coverage.
- **perf:** still a skip, same reason. There is no figure to move.
- **complexity totals:** NLOC 19172 → **19199** (+27), functions 2918 → **2921** (+3). All of it is
  the split: `test_libka0s.lua` 653 NLOC / 121 functions became 422 / 63 plus
  `test_libka0s_slash.lua` at 258 / 61. The new file carries its own copies of the small helpers.
- **complexity averages:** avg NLOC/function **6.0 → 6.0**, avg CCN **2.0 → 2.0**, avg tokens
  **47.1 → 47.1**. No density signal.
- **max CCN:** **15 → 15**, warnings **0 → 0**. Unchanged.
- **file bands:** band files **5 → 4**, over-cap files **0 → 0**.
  - `tests/test_libka0s.lua` **1020 → 676** left the band. `tests/test_libka0s_slash.lua` is 391
    lines, well clear of it.
  - `modules/Browser.lua` 1221, `modules/Insights.lua` 1002, `modules/LedgerTable.lua` 1139 and
    `tests/test_ledger.lua` 1028 did not move.
- **Bundles without an analysis:** noted per `automated-tests-§5` and not backfilled: **2 of the 13**
  earlier bundles (`20260807-110442`, `20260825-103400`).

## Complexity watch list

These tables come from this run's own `lizard` output. The dispositions are the cells in
[`../RESULTS.md`](../RESULTS.md), refreshed at this run to today's figures. No ruling changed.

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|
| — | — | — | None. |

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1221 | Accepted — already tracked as `BL-24`; did not move. Avg CCN 3.1 over 101 functions. |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1002 | Accepted; did not move. Avg CCN 3.6 over 65 functions. Re-check trigger 1300 LOC. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1139 | Accepted; did not move. Avg CCN 3.0 over 101 functions. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1028 | Accepted — arriving, not drifting; did not move. Avg CCN 1.1 over 135 functions. Re-check trigger 1200 LOC. |

`tests/test_libka0s.lua` is gone from the table. `BL-ATS-01` resolved it, as the previous run's
Resolved row said it would be.

Shelf life: the record holds one release run (`20260910-234511`, `release: "1.1.0"`), so no
Accepted entry has crossed three consecutive release runs.

## Actions

None. No version bump or tag comes from this run (`release: null` in [`manifest.json`](manifest.json)).
