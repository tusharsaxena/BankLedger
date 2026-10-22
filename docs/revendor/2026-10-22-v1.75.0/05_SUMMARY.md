# Summary: LibKa0s v1.71.0 -> v1.75.0 (BankLedger)

Run 2026-10-22, item BL-RV of the "LibKa0s issues #45-#58" run, on branch
`feat/2026-10-22-libka0s-issues-45-58`. The addon version was not bumped and nothing was pushed.

- **Re-vendored**: `libs/LibKa0s/` and `tests/_kit/` were replaced whole from the local tag v1.75.0
  (`265a89e`). The base is v1.71.0, read from the provenance line. Kit revision 38 -> 41. Every
  moved file is level with the tag (`01_DELTA.md`, *Per-file minors*), and the new majors Glow-1.0
  and Sim-1.0 arrived unconsumed. Both content diffs were empty before the prune. No file was
  deleted against the diffs. No span bundle and no base correction were needed.
- **Icon declaration** (new, directly under `CLAUDE.md:46`):
  `chevron-down, chevron-right, clear, close, confirm, copy, export, info, search, sort-down, sort-up`.
  Eleven names, all Open Iconic. The provenance line needed no split.
- **Prune**: `kept 12 file(s), removed 5828`. That is 213 Open Iconic, 1,435 Phosphor and 4,180
  Game-icons files, with the Phosphor and Game-icons folders gone. `libs/LibKa0s/media/icons/` now
  holds the eleven TGAs and `LICENSE-open-iconic.txt`.
- **Credits**: README `## Credits` now credits Open Iconic by set (Waybury, MIT, the link, and what
  draws it). There is no Phosphor or Game-icons line, because neither ships. The JetBrains Mono
  sentence stays. No README provenance line existed to remove.
- **Blockers fixed in the copy commit** (`01_DELTA.md`, *Blockers*):
  - 4a: the dead `__releaseChrome` stub mirror was removed from `settings/OptionsSetup.lua`.
  - 4b: `Drawer` joined the Options parity case's ignore list.
  - 4c: the stand-down CONTROL case now plants its survivor on the handler the registration names.
    This is a kit 39 harness interaction, and the addon code is unchanged.
  - 4d: the whole-catalog icon test was rewritten to the declaration.
  - 4e: the `info` file case now pins TestStrip-only use.
  - 4f: stale mentions were updated in `CLAUDE.md`, `docs/testing.md`, `docs/media.md` and
    `core/MediaSetup.lua`.
- **Adopted in this commit**: nothing. SearchBox (BL-02), TestStrip (BL-03), `Item.BonusIDsFromLink`
  (BL-01) and Sim-1.0 (BL-05..BL-13) are pre-decided by the run's owner scope and land as their own
  commits. **Declined**: nothing. **Issues filed**: none.
- **Class A, delivered on the copy**: Options 29's kept scroll offset, the corrected icon-fallback
  comments, the DebugLogDiagnostics header naming Glow and Sim, and kit 39-41.

## Gates on the copy commit

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 88 files |
| `lua tests/run.lua` | 1266 passed, 0 failed, 1 skipped (the declared diagnostics opt-out) |
| `tests/test_vendor_sync.lua` | passes: library (declared icon subset) and kit at v1.75.0 |
| `docs/test-cases.md` | regenerated; Total 1266, equal to the README badge (1266/1266) |

In-game smoke is the owner's (SM-BL-1..4 in the run's `06_SMOKE_TESTS.md`). Every declared mark
must still draw: the debug console's close, copy and clear; the title-bar close, the sort arrows,
the group chevrons, the dropdown chevron and tick, and the search magnifier; the export mark and the
CSV copy window's close; and the session window's close.
