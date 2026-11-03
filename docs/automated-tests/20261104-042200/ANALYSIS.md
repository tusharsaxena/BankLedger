# Analysis — 20261104-042200

- **Addon:** BankLedger 1.3.0
- **Verdict:** green
- **Commit:** `43d690d` (feat/2026-11-01-full-skinning), clean
- **Previous run:** `20261102-004240`

## Headline

Item R6-AT's record, taken at the end of round 6 of the full skinning run (the skin picker's preview as
test mode, the Sim mode box in Master controls, the README rename, the LibKa0s v1.85.0 re-cuts).
`luacheck` is clean over 121 files, the harness runs 1654 cases with 1653 passed, 0 failed and 1 skipped,
and `lizard` reports max CCN 15, zero warnings, zero blind and zero crashed files. `perf` is a skip under
the ratified `performance-§12` no-combat-path exemption. Nothing needs acting on.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261102-004240` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 121 files | [`lint.txt`](lint.txt) | 118 → 121 files: three new suites |
| tests | pass | 1653 passed, 1 skipped, 0 failed, 1654 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1631 → 1654 total |
| perf | skip | `performance-§12` exemption (ratified); 0 scenarios | none; nothing ran by design | unchanged |
| complexity | pass | 0 warnings, max CCN 15, blindFiles 0, crashedFiles 0 | [`complexity.txt`](complexity.txt) | NLOC and functions up; averages flat or down |

| Complexity metric | Value (from [`manifest.json`](manifest.json)) |
|---|---|
| Total NLOC | 30413 |
| Functions | 4894 |
| Avg NLOC / function | 6.1 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 50.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

`perf` is not a clean pass: it measured nothing, by design, under the ratified exemption recorded in
`docs/ARCHITECTURE.md`'s `## Documented deviations` (the manifest's `skipReason`). It is NOT EVALUATED at
the release gate. The one case-level skip in [`tests.txt`](tests.txt) is the kit's diagnostics-contract
opt-out case, which does not apply because this addon keeps the default; it is pre-existing and
unchanged since `20261009-191733`.

## What moved

- **lint:** 0/0 both runs; files 118 → 121. The three new files are `tests/test_launcher_skin_entry.lua`,
  `tests/test_sim_checkbox.lua` and `tests/test_skin_picker_preview.lua`.
- **tests:** 1631 → 1654 (+23), 1630 → 1653 passed, skip count flat at 1, failures flat at 0.
- **perf:** skip both runs, same reason.
- **complexity:** NLOC 29880 → 30413, functions 4793 → 4894. Avg NLOC 6.2 → 6.1, avg tokens 50.6 → 50.4,
  avg CCN 2.0 flat, max CCN 15 flat, warnings 0 flat. The addon grew without getting denser.
- **bands:** still 7 files in the 1000–1500 band and 0 over the cap. Within the band, `modules/Browser.lua`
  1189 → 1199 (its re-check trigger is 1300), `settings/Schema.lua` 1046 → 1059 and
  `tests/test_profiles.lua` 1010 → 1036 (its re-check trigger is 1200). No file entered or left the band.

## Complexity watch list

No function is warned on and no band row is new, so no disposition is owed: the runner carried all seven
forward and none crossed its stated re-check trigger. The rows are in [`RESULTS.md`](../RESULTS.md).
Functions at exactly CCN 15 (for example `NS.RunMigrations`, `Database.QueryList`, `NS.WriteSkinChoice`,
`NS.MaybeShowSkinNotice`, `LT.MakeHeaderButton`) sit at the line, not over it, per
[`complexity.txt`](complexity.txt).

## Actions

None.
