# 04 Execution plan

Nothing adopted from the tag. The re-vendor is one commit, SD-RV-BL:

1. Copy both payloads whole from the v1.108.0 extract; both diffs empty before the prune.
2. Roll the provenance line to v1.108.0 and the kit sentence to revision 58; keep the `LibKa0s icons:` line.
3. Prune icons and sounds with the tag's `tools/prune-icons.lua`.
4. Fix what kit revision 58 turns red: `tests/skin_facts.lua` gains `Kit.skinValues.rows` for the new scanner hits, and the two Insights face surfaces are drawn through the pane's own renderers, which set their colors.
5. Refresh the standard reference to v2.116.0: the vendored quirks block in `docs/midnight-quirks.md` restamped (its content is unchanged at v2.116.0).
6. `docs/test-cases.md` regenerated; the README Tests badge rolled to its total.
7. Gate: `ka0s-bounded lua tests/run.lua` and `ka0s-bounded luacheck .` (0/0), every authored file under 1500 lines.
