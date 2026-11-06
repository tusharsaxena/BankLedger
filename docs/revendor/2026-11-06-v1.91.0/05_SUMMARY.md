# Summary (BankLedger), LibKa0s v1.90.0 -> v1.91.0

- **Tag moved** v1.90.0 -> v1.91.0 (local tag `55bfbb4`, not pushed; a new re-vendor, not a refresh).
  Base from the provenance line (`CLAUDE.md:48`), cross-checked against the last payload commit
  `36a7940`. Step 0 skipped (the installed skill's roster regex matches nothing; fixed upstream by
  FU-DC1); the newest bundle's base was checked by hand and is right, so no base correction.
- **Minors:** Core 16 -> 17, Widgets 25 -> 26, SkinPaintExtras 18 -> 19, WidgetsLineChart 6 -> 7;
  new files CorePixel 1, WidgetsDropdown 1, SkinPaintHud 1, SkinAceConfirm 1. Kit 51 -> 51 (copied in
  the same commit, pairing rule). No skew, no `NEEDS_*` floor rose, no file removed upstream.
- **Span bundle:** none (3h printed nothing).
- **Delivered free (class A):** the four peels, behaviour-neutral; the line chart's physical-pixel
  lines, which no BankLedger screen draws.
- **Contract blockers (3g):** one, fixed in the re-vendor commit. `tests/test_marks.lua:159` read the
  dropdown tick's Blizzard rung from `libs/LibKa0s/Widgets.lua`, which moved to
  `WidgetsDropdown.lua` (Widgets document `:23`); it now reads the new file, and two comments
  (`tests/test_browser.lua:227`, `tests/test_export.lua:269`) name it. The load list is derived from
  `LibKa0s.xml`, so it took the new files in XML order with no edit. No test pins a moved minor. The
  degraded `S.HudFont` stub (`core/SkinSetup.lua`) now names `SkinPaintHud.lua` in its comment.
- **Icons:** `LibKa0s icons:` line kept as is (17 names). The tag's `tools/prune-icons.lua` printed
  `17 icon(s) declared; kept 18 file(s), removed 5822`; `media/icons/` is byte-identical to what
  v1.90.0 left. No provenance split.
- **README credits:** unchanged (Open Iconic only). No dead stub mirror.
- **Adopted:** nothing (00_PLAN.md: nothing to adopt).
- **Declined / filed:** nothing filed. IconBrowser and Perf settled.
- **Unreached:** none.
- **Gate** (both through `~/.claude/dev-copilot/bin/ka0s-bounded`): `luacheck .` 0 warnings / 0 errors
  in 121 files (`.luacheckrc` excludes `libs/` and `tests/_kit/`; the seams in `core/`, `modules/`,
  `settings/` are checked). `lua tests/run.lua` 1657 passed, 0 failed, 1 skipped, 1658 total (the skip
  is the diagnostics opt-out case this addon does not take); `test_vendor_sync` passes. Own-code
  edits are comment lines and one test path, so the 1500-line cap and CCN 15 stand.
