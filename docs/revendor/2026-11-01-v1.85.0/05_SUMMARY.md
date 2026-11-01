# Summary: LibKa0s v1.84.0 -> v1.85.0 (BankLedger)

Run 2026-11-01, item FS-BL-RV of the full skinning run, on branch `feat/2026-11-01-full-skinning`. The
addon version was not bumped and nothing was pushed.

- **Re-vendored**: `libs/LibKa0s/` and `tests/_kit/` replaced whole from the local tag v1.85.0
  (`9776130`). Base v1.84.0, from the provenance line. Kit 47 -> 49. Both content diffs were empty
  before the prune; no file was deleted against the diffs.
- **Span bundle**: none needed. **Base correction**: none. **Refresh**: none.
- **Delivered for free**: class A in `02_CANDIDATES.md`.
- **Blockers, fixed in this commit**: the facade members and the Options stub's `LabelFont`, in
  `01_DELTA.md`.
- **Icon declaration**: gains `chevron-up, move, reset, volume-high`, all Open Iconic. Prune: `17
  icon(s) declared; kept 18 file(s), removed 5822`. README credits name the new marks. No dead stub
  mirror, no provenance split.
- **Pin moved with the bytes**: `tests/test_browser.lua`, whose art-less dropdown now draws the Ka0s
  chevron (Widgets minor 18), not the client's arrow.
- **Look on this addon's Sim and strips (Step 5)**: the Steps title band is 30 high, an owned tooltip
  title takes `gtip.title`, and an owned strip's icon wears `icon.tint`.
- **Adopted**: by the plan's FS-BL-FIX commit. **Declined**: nothing.
- **Gate**: `lua tests/run.lua` 1534 passed, 0 failed, 1 skipped (1535); `ka0s-bounded luacheck .` 0 / 0
  in 117 files.
