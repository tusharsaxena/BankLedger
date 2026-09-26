# Analysis — 20260926-160240

- **Addon:** BankLedger 1.1.0
- **Verdict:** green
- **Commit:** `08512989b673d5ef9402187bd0c5e94f838facc1` (master), clean
- **Previous run:** `20260924-105040`

## Headline

Both gating suites pass: `luacheck` is clean over 75 files and the harness runs 1104 cases with no
failure and no skip, up 43 from the previous run. Complexity still reads **max CCN 15, zero
warnings, zero files over the `layout-§1` cap**, but the on-notice band grew from four files to
five: `tests/test_libka0s.lua` crossed 1000 (964 → 1020). `perf` is a skip under the addon's
ratified `performance-§12` exemption. Nothing here needs action beyond the new band entry's
disposition.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260924-105040` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 75 files | [`lint.txt`](lint.txt) | 0/0 unchanged; scope widened 72 → 75 files |
| tests | pass | 1104 passed, 0 skipped, 0 failed, 1104 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +43 cases (1061 → 1104) |
| perf | skip | `performance-§12` no-combat-path exemption (ratified) | none; nothing ran by design | unchanged: same skip, same reason |
| complexity | pass | 0 warnings, max CCN 15; see below | [`complexity.txt`](complexity.txt) | 0 → 0 warnings; band files 4 → 5 |

**Complexity is reported in full**, totals and averages both. Every value below is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 19172 |
| Functions | 2918 |
| Avg NLOC / function | 6.0 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 47.1 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 5 |
| Files over the 1500 cap | 0 |

**`perf`: a skip, not a pass.** [`manifest.json`](manifest.json) records `skipReason:
"performance-§12 no-combat-path exemption (ratified; docs/ARCHITECTURE.md -> Documented
deviations)"`, the second of `automated-tests-§3`'s two sanctioned reasons. The sweep behind the
exemption is `docs/performance.md`. At a release this suite is **NOT EVALUATED**, not passed.

**`complexity`: a pass.** [`complexity.txt`](complexity.txt) reads `No thresholds exceeded
(cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)`. Five
functions sit exactly at CCN 15, the same five as the previous run: `accumulateItemTaxonomy`
(`core/Database.lua:275`), `I` (`modules/Insights.lua:505`), `L` (`modules/Ledger.lua:428`, at
`:405` last run, shifted 23 lines by the diagnostics additions) and two `LT` closures
(`modules/LedgerTable.lua:599` and `:905`). None is above the threshold; any growth in one of them
trips the release gate.

## What moved

Sixteen commits separate this run from the previous one (`fff9780` → `0851298`): the merge of the
2026-09-23 remediation branch, the LibKa0s v1.60.0 re-vendor and the `/bl diagnostics` verb
(`DR-BL-01`..`DR-BL-07`), and the LibKa0s v1.61.0 re-vendor with its NavRail stub (`NR-BL-01`).

- **lint:** 0 warnings / 0 errors at both runs, over **72 → 75** files. The three new files are
  `modules/Diagnostics.lua`, `tests/menu_mock.lua` and `tests/test_diagnostics.lua`
  ([`lint.txt`](lint.txt)).
- **tests:** **1061 → 1104**, +43, all passing, none skipped ([`tests.txt`](tests.txt)). Per
  [`test-cases.md`](test-cases.md) against the previous bundle's inventory:
  `test_diagnostics.lua` +26 (new), `test_diagnostics_contract.lua` +7 (new),
  `test_launcher.lua` 31 → 37, `test_disabled.lua` 15 → 17, `test_libka0s.lua` 64 → 66. No file
  went down.
- **perf:** still a skip, same reason. No figure exists to move.
- **complexity totals:** NLOC 18306 → **19172** (+866), functions 2765 → **2918** (+153). The addon
  and its suite grew; `libs/` and `tests/_kit/` are outside `lizard`'s scope.
- **complexity averages:** avg NLOC/function **6.0 → 6.0**, avg CCN **2.0 → 2.0**, avg tokens
  47.5 → **47.1**. No density signal: the new code is no branchier than the old.
- **max CCN:** **15 → 15**, warnings **0 → 0**. Unchanged.
- **file bands:** band files **4 → 5**, over-cap files **0 → 0**.
  - `tests/test_libka0s.lua` **964 → 1020** entered the band, all from `08ccdee` (DR-BL-01). Avg
    CCN 1.4 over 121 functions ([`complexity.txt`](complexity.txt)): test cases, not tangle.
  - `modules/Browser.lua` 1221, `modules/Insights.lua` 1002, `modules/LedgerTable.lua` 1139 and
    `tests/test_ledger.lua` 1028 did not move.
- **Bundles without an analysis:** noted per `automated-tests-§5`, not backfilled: **2 of the 12**
  earlier bundles (`20260807-110442`, `20260825-103400`).

## Complexity watch list

Generated from this run's own `lizard` output; the dispositions are the cells in
[`../RESULTS.md`](../RESULTS.md).

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|
| — | — | — | None. |

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1221 | Accepted — already tracked as `BL-24`; carried forward, did not move. |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1002 | Accepted; carried forward, did not move. Re-check trigger 1300 LOC. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1139 | Accepted; carried forward, did not move. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1028 | Accepted — arriving, not drifting; carried forward, did not move. |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1020 | **New.** Accepted — case count, not tangle (avg CCN 1.4). Re-check trigger 1200 LOC. |

Shelf life: the record holds one release run (`20260910-234511`, `release: "1.1.0"`), so no
Accepted entry has crossed three consecutive release runs.

## Actions

1. **Owner:** confirm the new disposition on `tests/test_libka0s.lua` in `../RESULTS.md`. It is new
   here and has no tracking ID.
2. None beyond that. No version bump or tag comes from this run (`release: null` in
   [`manifest.json`](manifest.json)).
