# Summary (BankLedger)

This re-vendor moves LibKa0s from v1.66.0 to v1.67.0, copied from the local tag. Three payload files
moved: Core 9 -> 10, Options 27 -> 28 and OptionsIdList 2 -> 3 (table in `01_DELTA.md`). The kit
stays at revision 35, because `testkit/` did not change. Both diffs are empty after the copy, in
content and in bytes. There was no blocker, no deletion and no unrecorded tag.

Gate after the copy:

- tests: 1214 passed, 0 failed, 1 skipped, 1215 total (unchanged; the case inventory did not move)
- luacheck: 0 warnings / 0 errors in 86 files
- sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`):
  0 warnings, max CCN 15
- vendor parity: `diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s` is empty

Adoption: none in this commit. `addonName` goes to CA-BL-NM, and `MakeResizable` with
`onResizeStop` goes to CA-BL-01 (BankLedger#21). See `02_CANDIDATES.md`.
