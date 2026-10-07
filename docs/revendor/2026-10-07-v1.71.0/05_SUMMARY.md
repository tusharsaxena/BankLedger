# Summary: LibKa0s v1.70.0 -> v1.71.0 (BankLedger)

Run 2026-10-07, item RV-BL, on branch `feat/2026-10-07-review-audit-remediation`. The addon version
was not bumped and nothing was pushed.

- **Re-vendored**: `libs/LibKa0s/` and `tests/_kit/` replaced whole from the local tag v1.71.0
  (`cb274a4`); kit revision 37 -> 38. The `CLAUDE.md` provenance line names v1.71.0 and kit 38 in
  the same commit.
- **Adopted**: nothing. **Declined**: nothing. **Issues filed**: none (owner scope ruling 5).
- **Contract**: the Autocomplete scripts-first precondition is already met (`01_DELTA.md`). No
  blockers.
- **Totals now equal the badge**: `docs/test-cases.md` Total is 1258 with `| Skipped | 1 |`, and the
  README badge reads 1258/1258 (`BL-A-03`).
- **Span bundle**: the unrecorded v1.69.0 and v1.70.0 re-vendors are recorded in
  `docs/revendor/2026-10-07-v1.69.0-v1.70.0/` (`BL-A-01`).

## Gates on the copy commit

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 87 files |
| `lua tests/run.lua` | 1258 passed, 0 failed, 1 skipped (the declared diagnostics opt-out) |
| `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | 0 warnings, 3467 functions |
| `tests/test_vendor_sync.lua` | passes: library and kit at the tag |

In-game smoke is the owner's: `/reload` with no Lua errors; `/bl` opens the browser and typing in the
search box still shows the suggestion list.
