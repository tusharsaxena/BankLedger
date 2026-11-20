# 05 Summary

- Tag moved v1.107.0 -> v1.108.0, base taken from the CLAUDE.md provenance line (payload matched v1.107.0). Kit revision 57 -> 58. Seventeen files moved a minor (01_DELTA.md 3c).
- Span bundle: none. Base correction: none.
- Delivered for free (class A): nothing visible. The footer's shown-marks layout, the menu's secret-label measure and submenu-arrow tint, and the owner-warning walk reach this addon's code but change nothing it draws.
- Contract changes: none under anything this addon supplies. Blockers: none.
- What kit revision 58 turned red, fixed in this commit (`tests/skin_facts.lua`):
  - `test_skin_values`: the scanner now reads three-number tables and multi-assignments. New hits: the four `C.StoreRGB` entries (`core/Constants.lua:93-96`), rows with cause `MC` (skinning-§9 meaning colors, the audit's OVERRIDE row); the palette guard `series = { { 1, 1, 1 } }` (`modules/InsightsWidgets.lua:81`), category `unreachable default`; the diagnostic dump's `local r, g, b, a = 1, 1, 1, 1` (`settings/Panel.lua:580`), category `not a color`.
  - `test_skin_switch`: "a bar's face" and "a list row's face" answered a bare label whose face followed while no color was set on it (the colorless-face check). In the pane every label's color is set by the renderer on each refresh, so both surfaces are now drawn through `I:RenderBars` and `I:RenderList` over a stand-in pane, and lose `scope = "fonts"` (they draw a color in both passes).
- LibKa0s icons: line kept (19 names). The prune cut the re-copied icon folder back to those 19 plus the Open Iconic license, and removed 362 sound files. No provenance split.
- Standard v2.116.0: the quirks block's stamp rolled v2.115.0 -> v2.116.0 (the catalog's text is unchanged); the three-place reference carries no version and was already correct.
- README: the Tests badge rolled 1700 -> 1703 to match `docs/test-cases.md`; credits unchanged (Open Iconic only). Dead stub mirrors: none.
- Adopted: nothing. Declined: nothing (no issue filed; the run skips filing).
- Gate (Retail-only addon, one client): before the copy, `ka0s-bounded lua tests/run.lua` 1700 passed, 0 failed, 1 skipped; after the copy and before the fixes, 1698 passed, 3 failed; after, 1703 passed, 0 failed, 1 skipped, 1704 total. `ka0s-bounded luacheck .` 0 warnings / 0 errors in 125 files.
