# Summary (BankLedger)

LibKa0s v1.65.0 -> v1.66.0 from the local tag; ten payload files moved or arrived (table in
`01_DELTA.md`), kit revision 34 -> 35. Both diffs are empty after the copy, in content and in bytes.
No blocker, no deletion. A span bundle for the two unrecorded tags v1.64.0 and v1.65.0 is written
beside this one (`docs/revendor/2026-10-01-v1.64.0-v1.65.0/`).

Gate after the copy:

- tests: 1186 passed, 0 failed, 1 skipped, 1187 total (1178 / 0 / 1 of 1179 before; +8 kit cases)
- luacheck: 0 warnings / 0 errors in 83 files
- sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`):
  first run blindFiles 1 (`tests/test_panel.lua`, 114 of 115 listed) -> 0 after the hoist;
  warnings 4, maxCcn 44. Over CCN 15: `E.InsightsCSV` (Export.lua, 44), `L.Diagnose` (Ledger.lua, 37),
  `NS.StandDown` (BankLedger.lua, 23), `W.BuildBackToBackRows` (InsightsWidgets.lua, 19). They go to
  GI-BL-02.

Adoption: none (deferred to GI-LK-13; see `02_CANDIDATES.md`).
