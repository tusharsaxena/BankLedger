# Analysis — 20261101-143115

- **Addon:** BankLedger 1.3.0
- **Verdict:** green
- **Commit:** `71d50d9ce64f051b39cc0083d4fdb85325fa7f09` (feat/2026-11-01-full-skinning), clean
- **Previous run:** `20261101-025240`

## Headline

The full skinning run's record is green. `luacheck` is clean over 118 files, the harness runs 1544
cases with 1543 passed, 0 failed and 1 skipped, and `lizard` reports max CCN 15, zero warnings, zero
blind files and zero crashed files. `perf` is a skip under the ratified `performance-§12` no-combat-path
exemption. The growth is nine new cases in `tests/test_skin_chrome.lua`, and nothing needs acting on.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-025240` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 118 files | [`lint.txt`](lint.txt) | 117 → 118 files, the new suite |
| tests | pass | 1543 passed, 1 skipped, 0 failed, 1544 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1535 → 1544, nine new cases |
| perf | skip | `performance-§12` no-combat-path exemption (ratified); 0 scenarios | none; nothing ran by design | unchanged: same skip, same reason |
| complexity | pass | 0 warnings, max CCN 15, blindFiles 0, crashedFiles 0; see below | [`complexity.txt`](complexity.txt) | NLOC and functions up; max CCN flat |

**Complexity is reported in full**, totals and averages both. Every value below is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt) plus the runner's band and parity counts.

| Metric | Value |
|---|---|
| Total NLOC | 29675 |
| Functions | 4721 |
| Avg NLOC / function | 6.2 |
| Avg CCN | 2.1 |
| Max CCN | 15 |
| Avg tokens / function | 51.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**`tests`: a pass with one case-level skip.** The same kit diagnostics-contract case as the previous
run. BankLedger keeps the default (`Kit.diagnostics.enablesLogging` is not false), so the case does not
apply, and the case beside it holds the behavior the addon has. It is pre-existing.

**`perf`: a skip, pre-existing and sanctioned.** [`manifest.json`](manifest.json) records the
`performance-§12` exemption. Nothing was measured, by design. Runtime cost is not evidenced by this run,
and it is a **NOT EVALUATED** at the release gate rather than a pass.

**`complexity`: a pass, and sighted.** [`complexity.txt`](complexity.txt) reads `No thresholds
exceeded`, with `blindFiles` 0 and `crashedFiles` 0. The same eight functions sit exactly at CCN 15:
`accumulateItemTaxonomy` (`core/DatabaseStats.lua:64`), `LT.GroupEntries`
(`modules/LedgerTable.lua:375`), `LT.UpdateHeaderArrows` (`modules/LedgerTable.lua:764`),
`L.GateReason` (`modules/Ledger.lua:298`), `I.Layout` (`modules/Insights.lua:282`), `warbandMove`
(`modules/SimDrivers.lua:155`), `splitArgs` (`tests/test_skin_literals.lua:55`) and `M.advance`
(`tests/sim_support.lua:70`). Growth in any of them trips the next release gate.

## What moved

The commits since `20261101-025240` are the v1.84.0 merge, the v1.85.0 re-vendor (kit revision 47 →
49, `FS-BL-RV`), the window chrome on the skin's primitives (`FS-BL-FIX`) and the docs sync.

- **lint:** **117 → 118** files ([`lint.txt`](lint.txt)).
- **tests:** **1535 → 1544** cases, 1543 passed, 0 failed, 1 skipped ([`tests.txt`](tests.txt)).
- **perf:** still a skip, same reason. There is no figure to move.
- **complexity totals:** NLOC **29490 → 29675**, functions **4700 → 4721**, mostly the new suite and its
  closures.
- **complexity averages:** avg NLOC/function flat at **6.2**, avg CCN flat at **2.1**, avg tokens
  **50.8 → 51.0**.
- **max CCN:** **15 → 15**, warnings **0 → 0**, blind files **0 → 0**, crashed files **0 → 0**.
- **file bands:** band files **7 → 7**, over-cap files **0 → 0**.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

The band's rows are in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). No row is new and no
Disposition cell is blank, so nothing was owed a ruling.

## Actions

None.
