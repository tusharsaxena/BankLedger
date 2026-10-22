Refresh: LibKa0s v1.75.0 payload after the second tag move

# 07 — Refresh (BankLedger)

Run: 2026-10-22, item BL-RV3 of the cross-repo run "LibKa0s issues #45-#58", on branch
`feat/2026-10-22-libka0s-issues-45-58`. Files 01..05 of this bundle record the BL-RV copy of the tag
at `265a89e`, and 06 records the BL-RV2 refresh to `6bf5f3e`. This file records the second refresh
and does not edit them.

## Why

The local, unpushed annotated tag `v1.75.0` in `../LibKa0s` moved again, from commit **`6bf5f3e`** to
commit **`9e5c4e2`**. The range `6bf5f3e..9e5c4e2` is LK-27:

- `85e4f74` LK-27: SimPanel minor 2: the picker reads its scenario at use
- `9e5c4e2` LK-27: address review — pin late anchorTo, stepDelay and callbacks; 1.1.1 ripple

This is the additive fix for the SimPanel gap DropWatcher's DW-04 found (OWNER_SCOPE B). The vendored
payload had to follow the tag so that `tests/test_vendor_sync.lua` stays green and BL-08 builds its
simulator on the fixed contract.

## What was done

The same procedure as BL-RV and BL-RV2: `git -C ../LibKa0s archive v1.75.0 LibKa0s testkit
tools/prune-icons.lua` into scratch, `cp -r` of both payloads over `libs/LibKa0s/` and `tests/_kit/`,
then the tag's `tools/prune-icons.lua` against the unchanged `LibKa0s icons:` line in `CLAUDE.md`
(`11 icon(s) declared; kept 12 file(s), removed 5828`, the same result as before). After the prune,
`diff -rq` against the tag shows no difference beyond the pruned icons, so no file needed deleting.
The provenance line still reads v1.75.0 and was not edited.

## Files that changed

| File | Change |
|---|---|
| `libs/LibKa0s/SimPanel.lua` | `SIM_PANEL_MINOR` **1 -> 2**: the picker reads its scenario at use (`chosen(P)`: the picker's choice while its def resolves, else the first name `scenarios.names` lists now), so a host that fills its scenarios after `Sim:New` gets a working Start row and picker; with no scenario listed the Start row is locked |

`Sim.lua` (`LibKa0s-Sim-1.0` minor 2) and `SimTimeline.lua` (`TIMELINE_MINOR` 2) are unchanged since
BL-RV2. `tests/_kit/` is byte-identical to the moved tag (the kit revision stays 41). The Sim docs key
moves 2.2.1 -> **2.2.2** (`docs/api/Sim/version-2.2.2-docs.md` in LibKa0s). No public member was added
or removed.

## Addon pins

BankLedger's own tests and docs pin no Sim, SimTimeline or SimPanel minor, nor a Sim docs key
(searched outside `libs/`, `tests/_kit/` and the revendor bundles), so nothing else needed updating.
BankLedger does not consume Sim-1.0 yet; BL-08 adopts it.

## Gates

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 89 files |
| `lua tests/run.lua` | 1304 passed, 0 failed, 1 skipped (the declared diagnostics opt-out); `test_vendor_sync` green against `9e5c4e2` |
| 1500-line cap | largest authored file `tests/test_browser.lua`, 1371 lines |
