# Analysis — 20261101-025240

- **Addon:** BankLedger 1.3.0
- **Verdict:** green
- **Commit:** `cc21f2af561d006084f370c2a7f84d01593a2983` (feat/2026-10-31-findings-remediation), clean
- **Previous run:** `20261101-000956`

## Headline

The final pre-merge run is green. `luacheck` is clean over 117 files, the harness runs 1535 cases with
1534 passed, 0 failed and 1 skipped, and `lizard` reports max CCN 15, zero warnings, zero blind files
and zero crashed files. `perf` is a skip under the ratified `performance-§12` no-combat-path exemption.
No figure moved since the previous run, and nothing needs acting on.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-000956` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 117 files | [`lint.txt`](lint.txt) | unchanged; artifact identical |
| tests | pass | 1534 passed, 1 skipped, 0 failed, 1535 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged; both artifacts identical |
| perf | skip | `performance-§12` no-combat-path exemption (ratified); 0 scenarios | none; nothing ran by design | unchanged: same skip, same reason |
| complexity | pass | 0 warnings, max CCN 15, blindFiles 0, crashedFiles 0; see below | [`complexity.txt`](complexity.txt) | unchanged; artifact identical |

**Complexity is reported in full**, totals and averages both. Every value below is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt) plus the runner's band and parity counts.

| Metric | Value |
|---|---|
| Total NLOC | 29490 |
| Functions | 4700 |
| Avg NLOC / function | 6.2 |
| Avg CCN | 2.1 |
| Max CCN | 15 |
| Avg tokens / function | 50.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
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
deviations)"`. Nothing was measured, by design. Runtime cost is not evidenced by this run, and it is a
**NOT EVALUATED** at the release gate rather than a pass.

**`complexity`: a pass, and sighted.** [`complexity.txt`](complexity.txt) reads `No thresholds
exceeded`, with `blindFiles` 0 and `crashedFiles` 0, so `lizard` measured every function. The same
eight functions sit exactly at CCN 15 at the same locations, and growth in any of them trips the next
release gate: `accumulateItemTaxonomy` (`core/DatabaseStats.lua:64`), `LT.GroupEntries`
(`modules/LedgerTable.lua:387`), `LT.UpdateHeaderArrows` (`modules/LedgerTable.lua:776`),
`L.GateReason` (`modules/Ledger.lua:298`), `I.Layout` (`modules/Insights.lua:282`), `warbandMove`
(`modules/SimDrivers.lua:155`), `splitArgs` (`tests/test_skin_literals.lua:55`) and `M.advance`
(`tests/sim_support.lua:70`).

## What moved

Nothing measured moved. The four commits since `20261101-000956` are the run's own record, the re-cut
LibKa0s v1.84.0 under `libs/LibKa0s/` (six files), a comment-only line reference in
`tests/test_surface_parity.lua`, and two `docs/smoke-tests.md` edits, none of which adds an addon case
or authored code. [`lint.txt`](lint.txt), [`tests.txt`](tests.txt), [`test-cases.md`](test-cases.md)
and [`complexity.txt`](complexity.txt) are byte-for-byte the previous run's, line terminators aside.

- **lint:** 0 warnings / 0 errors, flat at **117** files ([`lint.txt`](lint.txt)).
- **tests:** flat at **1535** cases, 1534 passed, 0 failed, 1 skipped ([`tests.txt`](tests.txt)).
  `RESULTS.md` now flags the count as flat across the last 4 runs. Here that flatness has a stated
  cause: this run's changes are vendored, comment-only or documentation.
- **perf:** still a skip, same reason. There is no figure to move.
- **complexity totals:** NLOC flat at **29490**, functions flat at **4700**.
- **complexity averages:** avg NLOC/function flat at **6.2**, avg CCN flat at **2.1**, avg tokens flat
  at **50.8**.
- **max CCN:** **15 → 15**, warnings **0 → 0**, blind files **0 → 0**, crashed files **0 → 0**.
- **file bands:** band files **7 → 7**, over-cap files **0 → 0**. Nothing newly crossed.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1195 | Accepted, already tracked as `BL-24`; carried forward, unchanged |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1047 | Accepted; carried forward, unchanged |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1046 | Accepted; carried forward, unchanged |
| 1000–1500 (on notice) | `tests/test_browser.lua` | 1006 | Peeled, accepted at this size; carried forward, unchanged |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1006 | Accepted; carried forward, unchanged |
| 1000–1500 (on notice) | `tests/test_panel_filters.lua` | 1003 | Accepted; carried forward, unchanged |
| 1000–1500 (on notice) | `tests/test_profiles.lua` | 1010 | Accepted; carried forward, unchanged |

No row is new and no Disposition cell is blank, so nothing was owed a ruling. The full dispositions are
in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band).

## Actions

None.
