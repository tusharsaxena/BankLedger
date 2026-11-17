# 04 Execution plan

Nothing adopted, so no characterization tests and no adoption commits. The run is one commit, RV-BL:

1. Copy both payloads whole from the v1.105.0 extract; both diffs empty before the prune.
2. Roll the provenance line to v1.105.0 and the kit-revision sentence to 57; keep the `LibKa0s icons:` line.
3. Prune icons and sounds with the tag's `tools/prune-icons.lua`.
4. Fix what the new payload turned red (01_DELTA.md 3g): the DebugLog stub's `Report` and `Serialize`, the Options stub's `SideTabs`, the Ka0s Default fallback's `list.stripe` and `list.hover`, and the console title-bar offsets re-pinned in `tests/test_libka0s.lua`.
5. Regenerate `docs/test-cases.md` (`lua tests/run.lua --list`) and roll the README Tests badge.
6. Gate: `ka0s-bounded lua tests/run.lua` and `ka0s-bounded luacheck .` (0/0), every file under 1500 lines.
