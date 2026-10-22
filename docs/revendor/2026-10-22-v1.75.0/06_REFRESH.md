Refresh: LibKa0s v1.75.0 payload after the local tag moved

# 06 — Refresh (BankLedger)

Run: 2026-10-22, item BL-RV2 of the cross-repo run "LibKa0s issues #45-#58", on branch
`feat/2026-10-22-libka0s-issues-45-58`. Files 01..05 of this bundle are frozen and describe the BL-RV
copy of the tag at `265a89e`. This file records the later refresh and does not edit them.

## Why

The local, unpushed annotated tag `v1.75.0` in `../LibKa0s` moved from commit **`265a89e`** to commit
**`6bf5f3e`** (`LK-26: Sim minor 2: Start reads scenarios live; prepare gets host opts`), the additive
fix for the two LibKa0s-Sim-1.0 contract gaps DropWatcher's DW-02 found (LibKa0s#54, OWNER_SCOPE B).
The range `265a89e..6bf5f3e` is that one commit. The vendored payload had to follow the tag so that
`tests/test_vendor_sync.lua` stays green and BL-08 builds its simulator on the fixed contract.

## What was done

The same procedure as BL-RV: `git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools/prune-icons.lua`
into scratch, `cp -r` of both payloads over `libs/LibKa0s/` and `tests/_kit/`, then the tag's
`tools/prune-icons.lua` against the unchanged `LibKa0s icons:` line in `CLAUDE.md`
(`11 icon(s) declared; kept 12 file(s), removed 5828`, the same result as BL-RV). No file needed
deleting against the diff. The provenance line still reads v1.75.0 and was not edited.

## Files that changed

| File | Change |
|---|---|
| `libs/LibKa0s/Sim.lua` | `LibKa0s-Sim-1.0` minor **1 -> 2**: `Start` reads `scenarios.names`/`defs` live; `prepare` receives a shallow copy of the caller's start options |
| `libs/LibKa0s/SimTimeline.lua` | `TIMELINE_MINOR` **1 -> 2**: `Restart` carries the host's extra start fields through |

`tests/_kit/` is byte-identical to the moved tag (the kit revision stays 41). `SimPanel.lua` is
unchanged. The Sim docs key moves 1.1.1 -> **2.2.1** (`docs/api/Sim/version-2.2.1-docs.md` in
LibKa0s). No public member was added or removed.

## Addon pins

BankLedger's own tests and docs pin no Sim minor or docs key (searched outside `libs/`, `tests/_kit/`
and the frozen revendor bundles), so nothing else needed updating. BankLedger does not consume
Sim-1.0 yet; BL-08 adopts it.

## Gates

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 89 files |
| `lua tests/run.lua` | 1304 passed, 0 failed, 1 skipped (the declared diagnostics opt-out); `test_vendor_sync` green against `6bf5f3e` |
| 1500-line cap | largest authored file `tests/test_browser.lua`, 1371 lines |
