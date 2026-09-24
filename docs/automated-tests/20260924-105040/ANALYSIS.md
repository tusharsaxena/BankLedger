# Analysis — 20260924-105040

- **Addon:** BankLedger 1.1.0
- **Verdict:** green
- **Commit:** `fff9780b1f51b6604bd9a39298f4ccb3e9a6d3eb` (feat/2026-09-23-review-audit-remediation), clean
- **Previous run:** `20260916-184426`

## Headline

Both gating suites pass: `luacheck` is clean over 72 files and the harness runs 1061 cases with no
failure and no skip, up 118 from the previous run. The complexity suite still reads **max CCN 15,
zero warnings, zero files over the `layout-§1` cap**, but the on-notice band grew from three files
to four: `modules/Insights.lua` crossed 1000 (992 → 1002) and is owed its first disposition. `perf`
is still a skip, and for a different reason: this runner reads the addon's ratified
`performance-§12` no-combat-path exemption out of `docs/ARCHITECTURE.md`, which the previous
runner could not do. The record stopped misdescribing the addon. The addon itself did not change.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260916-184426` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 72 files | [`lint.txt`](lint.txt) | 0/0 unchanged; scope widened 67 → 72 files |
| tests | pass | 1061 passed, 0 skipped, 0 failed, 1061 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +118 cases (943 → 1061) |
| perf | skip | `performance-§12` no-combat-path exemption (ratified) | none; nothing ran by design | still a skip, now under sanctioned reason (2) instead of (1) |
| complexity | pass | 0 warnings, max CCN 15; see below | [`complexity.txt`](complexity.txt) | 0 → 0 warnings; band files 3 → 4 |

**Complexity is reported in full**, totals and averages both. Every value below is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 18306 |
| Functions | 2765 |
| Avg NLOC / function | 6.0 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 47.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 4 |
| Files over the 1500 cap | 0 |

**`perf`: a skip, not a pass, and now the right skip.** [`manifest.json`](manifest.json) records
`skipReason: "performance-§12 no-combat-path exemption (ratified; docs/ARCHITECTURE.md -> Documented
deviations)"`. That is the second of `automated-tests-§3`'s two sanctioned reasons. The runner
found it in the `performance-§12` row of `docs/ARCHITECTURE.md` → `## Documented deviations`,
ratified 2026-08-05, with the sweep behind it in `docs/performance.md`. Every earlier bundle in this
record carries reason (1), *no `tests/perf.lua`*, which was false for this addon from the day the
exemption was ratified. The vendored runner knew only reason (1) through kit revision 25 (finding
`BankLedger-A-04`). Kit revision 26, re-vendored in `2195126`, reads the register. The bundles that
record reason (1) are frozen and stay that way. This run is the correction. At a release this
suite is still **NOT EVALUATED** rather than passed. The exemption says there is no combat path to
bracket. It does not say the addon was measured.

**`complexity`: a pass.** `lizard`'s threshold banner in [`complexity.txt`](complexity.txt) reads
`No thresholds exceeded`. The one item that needs a ruling is the fourth band file, below.

## What moved

Sixty-nine commits separate this run from the previous one (`076f674` → `fff9780`). They include
the LibKa0s re-vendors up to v1.56.0 and the 2026-09-23 remediation items `BL-00` to `BL-24`.

- **lint:** the figure did not move, the **scope did**: 0 warnings / 0 errors at both runs, over
  **67 → 72** files. The five new authored files are `core/LifecycleSetup.lua`,
  `tests/test_bus.lua`, `tests/test_disabled.lua`, `tests/test_reset_routes.lua` and
  `tests/test_schema_runtime.lua` ([`lint.txt`](lint.txt)).
- **tests:** **943 → 1061**, +118, all passing, none skipped ([`tests.txt`](tests.txt)). The largest
  single growths per [`test-cases.md`](test-cases.md) against the previous bundle's inventory:
  `test_schema_runtime.lua` +18 (new), `test_disabled.lua` +15 (new), `test_surface_parity.lua`
  4 → 19, `test_prose.lua` +15 and `test_layout_cap.lua` +13 (the kit's gates, wired from its
  directory), `test_bus.lua` +10 (new), `test_launcher.lua` 23 → 31, `test_reset_routes.lua` +6
  (new). One file went down: `test_libka0s.lua` 65 → 64.
- **perf:** still a skip, **reason changed** from (1) to (2), as above. No figure exists to move.
- **complexity totals:** NLOC 16380 → **18306** (+1926), functions 2498 → **2765** (+267). The addon
  and its suite grew. `libs/` and `tests/_kit/` are out of `lizard`'s scope, so none of the
  re-vendors contribute to these figures.
- **complexity averages:** avg NLOC/function 5.9 → **6.0**, avg CCN **2.0 → 2.0** (unchanged), avg
  tokens 46.6 → **47.5**. The branchiness of the average function did not move. Functions got
  slightly longer and slightly wordier, which is a small drift but not a complexity signal.
- **max CCN:** **15 → 15**, warnings **0 → 0**. Unchanged.
- **file bands:** band files **3 → 4**, over-cap files **0 → 0**.
  - `modules/Insights.lua` **992 → 1002** entered the band. It grew by 10 lines in `a769125`
    (the stand-down latch) and 2 changed lines in `f14c9df` (the bus catalog). Neither is a new
    renderer. Avg CCN 3.6 over 65 functions.
  - `modules/Browser.lua` **1208 → 1221**, +13 (+12 in `a769125`, +1 in the `BL-20` edit;
    `BL-05`, `BL-06` and `BL-18` changed lines without adding any). The previous disposition's
    *moving the right way* note described the −44 at that run. It is no longer true.
  - `modules/LedgerTable.lua` **1132 → 1139**, +7, from `17568e2` (`BL-17`, printer arguments).
  - `tests/test_ledger.lua` **1028 → 1028**. It did not move.
- **Bundles without an analysis:** as `automated-tests-§5` asks, noted again without
  backfilling. **2 of the 11** earlier bundles in this repo have no `ANALYSIS.md`
  (`20260807-110442`, `20260825-103400`). Both are frozen and stay that way.
- **The record's shape widened:** this is the first row with `Commit` and `Tree` cells (kit
  revision 25+). The eleven earlier rows read `unknown` in both, which is what the record holds
  about them.

## Complexity watch list

Generated from this run's own `lizard` output. The dispositions below are **proposals for the
owner**, authored into the same cells of [`../RESULTS.md`](../RESULTS.md).

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|
| — | — | — | None. |

None. `lizard`'s footer records **0 warnings over 2765 functions**. On the complexity half of the
release gate, this commit would pass.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1221 | **Accepted — already tracked as `BL-24`** (`docs/audits/2026-08-04/02_DEVIATIONS.md`), with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. 1208 → 1221 since `20260916-184426` (+12 of it the stand-down latch in `a769125`), so the earlier *moving the right way* note no longer holds and is withdrawn. |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1002 | **Accepted.** New in this table: 992 → 1002, crossed by the stand-down latch in `a769125` (+10), not by a new renderer. Avg CCN 3.6 over 65 functions ([`complexity.txt`](complexity.txt)): section renderers, not tangle. Peel seam: `I:Layout` / `I:LayoutSections` and the `I:Render*` section renderers they drive lift into a sibling file. Re-check trigger: 1300 LOC, or a new section renderer. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1139 | **Accepted**, carried forward; 1132 → 1139 since `20260916-184426` (+7, the printer-argument change in `17568e2`). The test-data generator (`makeTestEntry`/`seedCoverage`/`bulkMovements`/`goldMovements`) is a self-contained block and is still the peel seam if it grows. Shelf life: this record holds exactly **one** release run (`20260910-234511`), so the three-consecutive-releases rule has not been reached. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1028 | **Accepted**, carried forward verbatim in `../RESULTS.md` (the entry did not move). Case count, not tangle: avg CCN 1.1 over 135 functions ([`complexity.txt`](complexity.txt)). Re-check trigger: 1200 LOC, at which the settling/marks boundary is the next seam. |

The generated functions table in [`../RESULTS.md`](../RESULTS.md) is a header with no rows rather
than `None.`, which is how this kit revision renders an empty list. It is generated text, and any
fix belongs in the kit, not here.

## Actions

1. **Owner:** rule on the four proposed dispositions above, in `../RESULTS.md`'s Disposition
   cells. `modules/Insights.lua` is new here. Its peel seam is the `I:Layout` section-renderer
   block. `modules/Browser.lua` stays under the audit's `BL-24`, which has no GitHub issue in this
   repo's store. Filing one is the owner's call.
2. None beyond that. No version bump and no tag come from this run. This is a gate record on the
   remediation branch, not a release run (`release: null` in [`manifest.json`](manifest.json)).
