# Summary: LibKa0s v1.83.0 -> v1.84.0 (BankLedger)

Run 2026-10-31, item BL-RV of the findings remediation, on branch
`feat/2026-10-31-findings-remediation`. The addon version was not bumped and nothing was pushed.

- **Re-vendored**: `libs/LibKa0s/` and `tests/_kit/` were replaced whole from the local tag v1.84.0
  (`e917ccd`). Base v1.83.0, from the provenance line, confirmed against the payload. The minors are
  in `01_DELTA.md`; kit revision 46 -> 47. Both content diffs were empty before the prune; no file
  was deleted against the diffs.
- **Span bundle**: none needed. **Base correction**: none.
- **Delivered for free**: see `02_CANDIDATES.md`, class A.
- **Blocker, fixed in this commit**: the Options stub in `settings/OptionsSetup.lua` gains
  `PositionBlock`. The surface parity case was red on the copy alone (1 failed), green with it.
- **Icon declaration**: unchanged, thirteen Open Iconic names. Prune: `13 icon(s) declared; kept 14
  file(s), removed 5826`. README credits unchanged. No dead stub mirror, no provenance split.
- **Pins moved with the bytes**: `tests/test_libka0s.lua`'s descriptor tripwire now reads
  `OptionsFlow.lua`, the flow engine's new home. Line citations fixed in
  `tests/test_envsetup.lua` (`mock_base.lua:335`) and `tests/test_surface_parity.lua`
  (`Options.lua:524`, `OptionsWidgets.lua:307`). `docs/testing.md` lists `mock_ace.lua`.
- **Adopted**: nothing, by the brief. **Declined**: all of `02_CANDIDATES.md`; no issue filed.
- **LibKa0s#67**: none. **LibKa0s#68**: not applicable, no mover.
- **Smoke**: DIAG-32 added, Result empty.
- **Gate**: `lua tests/run.lua` 1534 passed, 0 failed, 1 skipped (1535). The count did not move, so
  the README badge and `docs/test-cases.md` are unchanged. `ka0s-bounded luacheck .` 0 / 0 in 117 files.
