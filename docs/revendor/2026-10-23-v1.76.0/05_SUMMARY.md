# Summary: LibKa0s v1.75.2 -> v1.76.0 (BankLedger)

Run 2026-10-23, item BL-RV of the "sim auto-run, QC preview selector, mode strips, MM/KCD
simulators" run, on branch `feat/2026-10-23-sim-preview-mode-strips`. The addon version was not
bumped and nothing was pushed.

- **Re-vendored**: `libs/LibKa0s/` and `tests/_kit/` were replaced whole from the local tag v1.76.0
  (`9949368`). The base is v1.75.2, read from the provenance line and confirmed against the
  payload. Widgets 13 -> 14, SimTimeline 2 -> 3, SimPanel 4 -> 5; kit revision 41 unchanged. Both
  content diffs were empty before the prune; no file was deleted against the diffs.
- **Span bundle**: v1.75.1 and v1.75.2 had been vendored without a bundle, so
  `docs/revendor/2026-10-23-v1.75.1-v1.75.2/` records them (both sweeps, nothing adopted).
- **Icon declaration**: unchanged (eleven Open Iconic names). Prune: `11 icon(s) declared; kept 12
  file(s), removed 5828`. README credits unchanged (Open Iconic still the only set that ships).
- **Blockers**: none. The Sim auto-run leaves "Run all" wording in the step-delay tooltip and three
  comments; BL-01 owns it on this branch.
- **Adopted in this commit**: nothing. BL-01 (auto-run wording and typed-start cases) and BL-10
  (the `kind = "sim"` strips) are pre-decided by the run's owner scope.
- **Gate**: `luacheck .` 0 warnings / 0 errors in 103 files; `lua tests/run.lua` 1418 passed,
  0 failed, 1 skipped (1419); `docs/test-cases.md` regenerated with no change.
