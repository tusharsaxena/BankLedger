# 04 Execution plan

Nothing adopted from the tag. The re-vendor is one commit, AF-RV-BL:

1. Copy both payloads whole from the v1.107.0 extract; both diffs empty before the prune.
2. Roll the provenance line to v1.107.0; keep the `LibKa0s icons:` line and the kit-revision sentence (57).
3. Prune icons and sounds with the tag's `tools/prune-icons.lua`.
4. Refresh the standard reference to v2.115.0 in the same item: the vendored quirks block in `docs/midnight-quirks.md` replaced whole, and the one live DPS Race mention in `docs/ARCHITECTURE.md` renamed to Combat Trail's race window.
5. `docs/test-cases.md` regenerated (unchanged, Total 1695); the README Tests badge, which read 1681, rolled to 1695.
6. Gate: `ka0s-bounded lua tests/run.lua` and `ka0s-bounded luacheck .` (0/0), every authored file under 1500 lines.
