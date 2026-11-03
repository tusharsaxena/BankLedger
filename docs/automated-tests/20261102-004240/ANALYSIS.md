# Analysis — 20261102-004240

- **Addon:** BankLedger 1.3.0
- **Verdict:** green
- **Commit:** `65cd70a` (feat/2026-11-01-full-skinning), clean
- **Previous run:** `20261101-202157`

## Headline

Item SF-REC's record, taken after SF-BL-1 (the Insights section headings no longer grow on a skin switch).
`luacheck` is clean over 118 files, the harness runs 1631 cases with 1630 passed, 0 failed and 1 skipped,
and `lizard` reports max CCN 15, zero warnings, zero blind and zero crashed files. `perf` is a skip under
the ratified `performance-§12` no-combat-path exemption. Nothing needs acting on.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-202157` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 118 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1630 passed, 1 skipped, 0 failed, 1631 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1630 → 1631, the divider guard case |
| perf | skip | `performance-§12` exemption (ratified); 0 scenarios | none; nothing ran by design | unchanged |
| complexity | pass | 0 warnings, max CCN 15, blindFiles 0, crashedFiles 0 | [`complexity.txt`](complexity.txt) | NLOC and functions up slightly |

| Complexity metric | Value (from [`manifest.json`](manifest.json)) |
|---|---|
| Total NLOC | 29880 |
| Functions | 4793 |
| Avg NLOC / function | 6.2 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 50.6 |
| Warnings (CCN > 15) | 0 |
| Files in the 1000–1500 band / over cap | 7 / 0 |
| Blind / crashed files | 0 / 0 |

The one case-level skip is the kit's diagnostics-contract case, pre-existing. `perf` measured nothing by
design and is NOT EVALUATED at the release gate. The new guard test models the client keeping the font
object after `SetFont`; it passed on the old code in the mock too, so it guards the shape and does not
prove the in-client cause, which SKIN-38 (not run) covers.

## What moved

- **tests:** 1630 → 1631. **NLOC:** 29858 → 29880. **Functions:** 4789 → 4793.
- **averages, max CCN, warnings, bands:** flat.

## Complexity watch list

No function is warned on and no band row is new, so no disposition is owed. The rows are in
[`RESULTS.md`](../RESULTS.md).

## Actions

None.
