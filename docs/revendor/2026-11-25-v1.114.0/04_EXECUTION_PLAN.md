# 04 Execution plan

The re-vendor is one commit, SF-BL-01, carrying nothing adopted:

1. Copy both payloads whole from the v1.114.0 extract; both diffs (content and bytes) empty before the prune.
2. Roll the provenance line to v1.114.0 and the kit sentence to revision 62; keep the `LibKa0s icons:` line.
3. Prune icons and sounds with the tag's `tools/prune-icons.lua`.
4. Back-fill the unrecorded v1.112.0 and v1.113.0 as the span bundle `../2026-11-25-v1.112.0-v1.113.0/`.
5. Gate: `ka0s-bounded lua tests/run.lua` on both kit profiles (default and `KA0S_KIT_CLIENT=forever`) and `ka0s-bounded luacheck .` (0/0).

Then the adoption, in later SF-BL-01 commits: a characterization test of the row tooltip first, then the ForeverDB seam (`core/ForeverDBSetup.lua`), the Forever-only settings row (default on), the tooltip lines, the TOC `## OptionalDeps` and `.pkgmeta` `optional-dependencies`, the perf note and the smoke rows.
