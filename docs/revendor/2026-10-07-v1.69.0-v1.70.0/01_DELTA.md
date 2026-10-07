Delta: LibKa0s v1.69.0 -> v1.70.0 (span: v1.69.0 v1.70.0)

# 01 — Delta: the consolidated span bundle

Written 2026-10-07 by RV-BL (the 2026-10-07 review-and-standards-audit remediation), beside
`docs/revendor/2026-10-07-v1.71.0/`. Two tags this addon vendored were never recorded (the
2026-10-07 standards audit's `BL-A-01`):

- **v1.69.0**, re-vendored by `b5e638b` (2026-10-06, "chore: re-vendor LibKa0s v1.69.0 (kit 37; adds
  the line chart widget)").
- **v1.70.0**, re-vendored by `2c87997` (2026-10-07, "chore: re-vendor LibKa0s v1.70.0").

Each re-vendor was gated when it landed. Nothing is re-vendored here. The base before the span is
**v1.68.1** (`docs/revendor/2026-10-04-v1.68.1/`, and the `CLAUDE.md` provenance line at
`b5e638b~1`, which names v1.68.1 and kit revision 36).

## What arrived

- **v1.69.0** (`git -C ../LibKa0s diff --stat v1.68.1 v1.69.0 -- LibKa0s testkit`: six files):
  **WidgetsLineChart minor 1**, a new file (`LibKa0s-Widgets-1.0` key 12.1.4.1), listed in
  `LibKa0s.xml`; and **test kit revision 37** (36 -> 37), which adds `testkit/mock_lines.lua` (Line
  regions from `CreateLine`) and loads it from `mock_base.lua`. Every other file stayed at its
  v1.68.1 minor.
- **v1.70.0** (`git -C ../LibKa0s diff --stat v1.69.0 v1.70.0 -- LibKa0s testkit`: three files):
  **WidgetsAutocomplete minor 1**, a new file, listed in `LibKa0s.xml`; and **WidgetsLineChart
  minor 2** (`LibKa0s-Widgets-1.0` key 12.1.4.2.1). The kit stayed at revision 37.

No major was added and no `NEEDS_*` floor rose in either tag. This addon consumes the Widgets major
(`modules/Browser.lua:5`, `modules/Export.lua:14`). It draws no line chart. It adopted Autocomplete
under the search box in `e5cd620` (see `05_SUMMARY.md`).

## The listing

After this bundle and `docs/revendor/2026-10-07-v1.71.0/`, every tag named by a payload commit or a
`CLAUDE.md` provenance roll since the horizon (`2026-08-25`) has a `docs/revendor/` folder, so the
audit's `grep -vxF -f recorded.txt vendored.txt` is empty.
