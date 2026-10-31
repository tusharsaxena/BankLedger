# Analysis — 20261031-202022

- **Addon:** BankLedger 1.3.0
- **Verdict:** green
- **Commit:** `ac7a3e856ff124030af658c189979d04208b9f82` (feat/2026-10-31-font-pickers-skin-faces), clean
- **Previous run:** `20261009-191733`

## Headline

The pre-merge run is green. `luacheck` is clean over 114 files, the harness runs 1535 cases with 1534
passed, 0 failed and 1 skipped, and `lizard` reports max CCN 15, zero warnings, zero blind files and
zero crashed files. `perf` is a skip under the ratified `performance-§12` no-combat-path exemption.
No function is above CCN 15 and no file is over the 1500 cap, so no code changed for this run. Four
files entered the 1000–1500 band, taking it from 4 to 8, and `tests/test_browser.lua` at 1442 LOC is
the one to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261009-191733` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 114 files | [`lint.txt`](lint.txt) | files 88 → 114 |
| tests | pass | 1534 passed, 1 skipped, 0 failed, 1535 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1266 → 1535 cases; skipped 1 → 1 |
| perf | skip | `performance-§12` no-combat-path exemption (ratified); 0 scenarios | none; nothing ran by design | unchanged: same skip, same reason |
| complexity | pass | 0 warnings, max CCN 15, blindFiles 0, crashedFiles 0; see below | [`complexity.txt`](complexity.txt) | NLOC 22780 → 29456; band files 4 → 8 |

**Complexity is reported in full**, totals and averages both. Every value below is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt) plus the runner's band and parity counts.

| Metric | Value |
|---|---|
| Total NLOC | 29456 |
| Functions | 4698 |
| Avg NLOC / function | 6.2 |
| Avg CCN | 2.1 |
| Max CCN | 15 |
| Avg tokens / function | 50.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**`tests`: a pass with one case-level skip.** [`tests.txt`](tests.txt) line 1524 is the same kit
diagnostics-contract case as the previous run. BankLedger keeps the default
(`Kit.diagnostics.enablesLogging` is not false), so the case does not apply, and the case beside it
holds the behavior the addon has. The skip is counted in the total and in neither passed nor failed.
It is pre-existing.

**`perf`: a skip, pre-existing and sanctioned.** [`manifest.json`](manifest.json) records
`skipReason: "performance-§12 no-combat-path exemption (ratified; docs/ARCHITECTURE.md -> Documented
deviations)"`. Nothing was measured, by design. Runtime cost is not evidenced by this run.

**`complexity`: a pass, and sighted.** [`complexity.txt`](complexity.txt) reads `No thresholds
exceeded`, with `blindFiles` 0 and `crashedFiles` 0, so `lizard` measured every function. This
manifest is the first in the record with `crashedFiles`. Eight functions sit exactly at CCN 15, and
growth in any of them trips the next release gate: `accumulateItemTaxonomy`
(`core/DatabaseStats.lua:64`), `LT.GroupEntries` (`modules/LedgerTable.lua:387`),
`LT.UpdateHeaderArrows` (`modules/LedgerTable.lua:776`), `L.GateReason` (`modules/Ledger.lua:298`),
`I.Layout` (`modules/Insights.lua:516`), `warbandMove` (`modules/SimDrivers.lua:155`), `splitArgs`
(`tests/test_skin_literals.lua:55`) and `M.advance` (`tests/sim_support.lua:70`). The previous run
listed the first five; the last three are in files added since then.

## What moved

Eighty-nine commits separate this run from the previous one (`6aedd39` → `ac7a3e8`), including the
simulator, keybinds, layers, the skin system and its fonts, and the re-vendors of LibKa0s.

- **lint:** 0 warnings / 0 errors over **88 → 114** files ([`lint.txt`](lint.txt)). The 26 new files
  are 7 addon files (`core/DatabaseStats.lua`, `core/SimSetup.lua`, `core/SkinSetup.lua` and
  `modules/Sim*.lua`) and 19 under `tests/`.
- **tests:** **1266 → 1535** cases, 0 failed ([`tests.txt`](tests.txt)); passed 1265 → 1534, skipped
  flat at 1.
- **perf:** still a skip, same reason. There is no figure to move.
- **complexity totals:** NLOC **22780 → 29456**, functions **3657 → 4698**.
- **complexity averages:** avg NLOC/function flat at **6.2**, avg CCN **2.0 → 2.1**, avg tokens
  **50.2 → 50.8**. The addon grew by size, with a small rise in density.
- **max CCN:** **15 → 15**, warnings **0 → 0**, blind files **0 → 0**.
- **file bands:** band files **4 → 8**, over-cap files **0 → 0**. Against the previous table,
  `modules/Browser.lua` 1179 → 1323, `modules/Insights.lua` 1004 → 1030, `tests/test_browser.lua`
  1103 → 1442 and `tests/test_profiles.lua` flat at 1010. Newly crossed: `modules/LedgerTable.lua`
  (1047), `settings/Schema.lua` (1046), `tests/test_ledger.lua` (1006) and
  `tests/test_panel_filters.lua` (1003).

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1323 | Accepted, already tracked as `BL-24`; carried forward, up from 1179 |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1030 | Accepted; carried forward, and the next release run would be the third |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1047 | **Newly crossed**; accepted, a cohesive pooled-row table, with the row menu as the peel seam |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1046 | **Newly crossed**; accepted, mostly declarative row tables |
| 1000–1500 (on notice) | `tests/test_browser.lua` | 1442 | Accepted when ruled at 1103; carried forward, and past its 1300 re-check trigger |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1006 | **Newly crossed**; accepted, case count, flat sections around the capture engine |
| 1000–1500 (on notice) | `tests/test_panel_filters.lua` | 1003 | **Newly crossed**; accepted, case count for one tab |
| 1000–1500 (on notice) | `tests/test_profiles.lua` | 1010 | Accepted; carried forward, unchanged |

The full dispositions are in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band).

## Actions

1. `tests/test_browser.lua`: lift the saved-view and per-tab view cases into
   `tests/test_browser_views.lua`. At 1442 LOC it has passed the 1300 re-check its disposition set and
   is 58 lines under the cap. New here; no issue filed.
2. `modules/Insights.lua`: before the next release, take the named peel (`I:Layout` /
   `I:LayoutSections` and the `I:Render*` renderers into a sibling file) or a tracked deviation ID, as
   a third release run carried as Accepted trips anti-pattern #53. Carried from `20261009-191733`; no
   issue filed.
