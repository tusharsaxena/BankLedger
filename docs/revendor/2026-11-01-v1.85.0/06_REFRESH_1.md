# Refresh 1 of v1.85.0

The tag is still local-only and was re-cut for the owner's rulings of 2026-11-01 and the gate (`FS-FIX`, `FS-GATE`), so this is a refresh and not a new re-vendor. It lands in `FS-BL-GATE`.

- **Old:** `9776130`. `libs/LibKa0s/` and `tests/_kit/` matched it before this copy.
- **New:** `2ad1a5080112cc1323fe79f7e134b00768a7ebca`.
- **Kit:** revision 49 -> 50. `test_skin_values` and `test_skin_switch` are declared by the pair and adopted.

**Copy:** both folders removed and copied from `git archive v1.85.0`, so a file the tag dropped goes too. **Prune:** the 17 declared icons stay; the declaration did not move.

**Blockers, fixed in this commit:** the degraded Skin facade gains `BarBorder`, which answers its three, and `HoverArt`. This addon has no Widgets stub, so `ContextMenu` is owed nowhere.

**Adopted:** `tests/test_skin_literals.lua` is retired. Its three allow rows are all kit categories now, so `tests/skin_facts.lua` carries no rows, and it declares `NS.SkinBar` as a paint call. The switch test declares this addon's surfaces there. `LT:ShowRowMenu` now answers its frame, for the menu's surface.

**Title height:** `title.height` is 30 in every registered skin, the value `B.SKIN.titleBarH` holds. `tests/test_skin_chrome.lua` pins that, and each bar's drawn height, for every skin.

**Not owed:** a repair step, since this addon has no `Skin.FollowOnce` call and no numeric path. No `S.Mark` or `S.HoverArt` call, and no recorded primitive on a pooled AceGUI widget, so nothing to untrack on release. No `bar.*`, `icon.border`, `glow` or `cover` read, so no expected smoke result moved.

**Gate:** see the `FS-BL-REC` bundle.
