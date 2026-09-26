# Analysis — 20260927-031851

- **Addon:** BankLedger 1.2.0
- **Verdict:** green
- **Commit:** `b97fd24d4818e4111c8c0d43495836cfae421824` (master), clean
- **Previous run:** `20260927-030326` (the 1.2.0 release run)

## Headline

Green, and the two splits did what they were for. `modules/LedgerTable.lua` (1139 → 888) and
`tests/test_ledger.lua` (1028 → 723) have both left `layout-§1`'s 1000–1500 band, so the band holds
2 files instead of 4, and nothing is over the cap. Lint is clean over 78 files (two more, the two new
ones), all 1104 cases pass with the same inventory spread across one more file, and complexity is
flat: max CCN 15, zero warnings, averages unchanged within rounding. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260927-030326` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 78 files | [`lint.txt`](lint.txt) | files 76 → 78; still 0/0 |
| tests | pass | 1104 passed, 0 skipped, 0 failed, 1104 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total unchanged; `test_ledger.lua` 98 → 72 cases, new `test_ledger_guildbank.lua` 26 |
| perf | skip | `performance-§12` no-combat-path exemption (ratified); 0 scenarios | none; nothing ran by design | unchanged: same skip, same reason |
| complexity | pass | 0 warnings, max CCN 15; see below | [`complexity.txt`](complexity.txt) | band files 4 → 2; see below |

**Complexity is reported in full**, totals and averages both. Every value below is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 19210 |
| Functions | 2920 |
| Avg NLOC / function | 5.9 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 46.9 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |

**`perf`: a skip, and a sanctioned one.** [`manifest.json`](manifest.json) records
`skipReason: "performance-§12 no-combat-path exemption (ratified; docs/ARCHITECTURE.md -> Documented
deviations)"`, the second of `automated-tests-§3`'s two sanctioned reasons. The addon ships no
`tests/perf.lua` and brackets no combat path by design, so this run says nothing about runtime cost
and is not meant to. That is a standing fact about the addon, not a tooling gap.

**`complexity`: a pass.** [`complexity.txt`](complexity.txt) reads `No thresholds exceeded`. The
same five functions sit exactly at CCN 15 as at the release run, two of them in new places because
they moved with the split: `accumulateItemTaxonomy` (`core/Database.lua:275`), `I`
(`modules/Insights.lua:505`), `L` (`modules/Ledger.lua:428`), and the two `LT` closures, formerly
`modules/LedgerTable.lua:599` (24 NLOC) and `:905` (17 NLOC), now
`modules/LedgerTable_TestMode.lua:237` (24 NLOC) and `modules/LedgerTable.lua:654` (17 NLOC). Same
NLOC, tokens and CCN: a move, not a change.

## What moved

Three commits separate this run from the previous one (`e9c5cae` → `b97fd24`): the 1.2.0 release
commit (`5cc9c87`, version stamps and the release bundle) and the two splits, `9dd1c2a`
(`modules/LedgerTable.lua` → `+ modules/LedgerTable_TestMode.lua`) and `b97fd24`
(`tests/test_ledger.lua` → `+ tests/test_ledger_guildbank.lua`).

- **lint:** 0 warnings / 0 errors over **76 → 78** files ([`lint.txt`](lint.txt)). The two added
  files are the new split halves; `.luacheckrc`'s excludes did not change.
- **tests:** **1104 → 1104**, all passing, none skipped ([`tests.txt`](tests.txt)). Sorted against
  the previous bundle's inventory, [`test-cases.md`](test-cases.md) differs only in the per-file
  headings and counts: `test_ledger.lua` **98 → 72**, `test_ledger_guildbank.lua` **new, 26**. No case
  was added, dropped or renamed. This bundle's `test-cases.md` is byte-identical to
  `docs/test-cases.md` at HEAD. The count is now flat at 1104 across four runs; every change in that
  span was docs, a release stamp or a verbatim split, so that is expected rather than a coverage gap.
- **perf:** still a skip, same reason. There is no figure to move.
- **complexity totals:** NLOC **19199 → 19210** (+11, the new files' headers and locals), functions
  **2921 → 2920**. Diffed by name and file against the previous `complexity.txt`, with each split
  half folded back into its parent, the only difference is one fewer `LT`-named entry in the
  `modules/LedgerTable.lua` lineage: `lizard` attributes one closure differently now that the code
  sits in its own file. No function was written or removed.
- **complexity averages:** avg NLOC/function **6.0 → 5.9**, avg CCN **2.0 → 2.0**, avg tokens
  **47.1 → 46.9**. Rounding-level movement from the redistribution; no density signal.
- **max CCN:** **15 → 15**, warnings **0 → 0**.
- **file bands:** band files **4 → 2**, over-cap files **0 → 0**. Out of the band:
  `modules/LedgerTable.lua` **1139 → 888** (new `modules/LedgerTable_TestMode.lua`, 265) and
  `tests/test_ledger.lua` **1028 → 723** (new `tests/test_ledger_guildbank.lua`, 322). Still in:
  `modules/Browser.lua` 1221 and `modules/Insights.lua` 1002, neither moved. Per-file `lizard` rows:
  `modules/LedgerTable.lua` 634 NLOC / 85 functions / avg CCN 3.0,
  `modules/LedgerTable_TestMode.lua` 187 / 15 / 3.5, `tests/test_ledger.lua` 567 / 105 / 1.2,
  `tests/test_ledger_guildbank.lua` 241 / 30 / 1.0.

This discharges the one action the release run's analysis raised: both files had been carried as
Accepted at two consecutive release runs, and neither now needs a third disposition or a tracked
deviation ID.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1221 | Accepted, already tracked as `BL-24`; unchanged |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1002 | Accepted; one release run in the band so far (1.2.0) |

The full dispositions are in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). Nothing newly
crossed; two files left the band.

## Actions

None.
