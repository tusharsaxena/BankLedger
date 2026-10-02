# Summary (BankLedger)

This re-vendor moves LibKa0s from v1.67.0 to v1.68.0, copied from the local annotated tag (`cc9f5eb`).
The base came from the `CLAUDE.md` provenance line (v1.67.0), and it agreed with the last re-vendor
commit `5e49c3a` and the payload's bytes. One payload file moved: `WidgetsDragHandle.lua`,
`DRAG_MINOR` 3 -> 4 (Widgets key 12.1.3 -> 12.1.4). The kit stays at revision 35, because `testkit/`
did not change. After the copy, both diffs are empty in content and in bytes. There was no blocker, no
deletion, no unrecorded tag (no span bundle) and no base correction.

- **Free on the copy (class A):** nothing behavioral. With no hook set, minor 4 makes minor 3's calls,
  and this addon builds no drag handle.
- **Contract blockers:** none. `version-12.1.4-docs.md:47`: "What a host must change: nothing."
- **Adopted:** none.
- **Declined:** `tooltipPlace` / `place`, not applicable, because BankLedger has no drag strip. Not a
  gap, so no GitHub issue (`03_DECISIONS.md`).
- **Skipped or unreached:** none.

Gate after the copy (every Lua run through `ka0s-bounded`):

- tests: 1226 passed, 0 failed, 1 skipped, 1227 total. The vendor-sync cases pass ("libs/LibKa0s is
  the LibKa0s release CLAUDE.md says this addon bundles", "tests/_kit is the test kit that shipped with
  that release").
- inventory: `lua tests/run.lua --list` matches `docs/test-cases.md`, so neither the inventory nor the
  README `[tests]` badge (1226/1226) moves.
- luacheck: 0 warnings / 0 errors in 86 files.
- sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`):
  0 warnings, max CCN 15.
