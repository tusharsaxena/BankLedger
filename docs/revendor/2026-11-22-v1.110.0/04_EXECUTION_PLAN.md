# 04 Execution plan

Nothing adopted in this commit; the adoption is K101-BL-02's own commit. The re-vendor is one commit, K101-BL-01:

1. Copy both payloads whole from the v1.110.0 extract; both diffs (content and bytes) empty before the prune.
2. Roll the provenance line to v1.110.0 and the kit sentence to revision 60; keep the `LibKa0s icons:` line.
3. Prune icons and sounds with the tag's `tools/prune-icons.lua`.
4. Back-fill the unrecorded v1.109.0 as the span bundle `../2026-11-22-v1.109.0-v1.109.0/`.
5. Gate: `ka0s-bounded lua tests/run.lua` on both kit profiles (default and `KA0S_KIT_CLIENT=forever`) and `ka0s-bounded luacheck .` (0/0).
