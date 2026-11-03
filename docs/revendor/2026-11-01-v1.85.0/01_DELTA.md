Delta: LibKa0s v1.84.0 -> v1.85.0

Run 2026-11-01, item FS-BL-RV of the full skinning run (Ka0sAddonsCommonTasks
`docs/2026-11-01-FULL_SKINNING/`), on branch `feat/2026-11-01-full-skinning`. Tag v1.85.0 is local
(`9776130`; `git -C ../LibKa0s ls-remote --tags origin v1.85.0` prints nothing).

## Pre-flight (Step 0, this addon only)

The other addons belong to other agents in this run, so the roster table was not printed.

    newest single-tag bundle: 2026-10-31-v1.84.0, line 1 base v1.83.0
    provenance before the commit that rolled to v1.84.0: v1.83.0    ok

## 3a. Claimed version

    grep -n '[Bb]undles' CLAUDE.md   ->  Bundles [LibKa0s](...) v1.84.0 (MIT).
    c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   ->  its line names v1.84.0

The two agree. The base is v1.84.0. Range: `git -C ../LibKa0s log --oneline v1.84.0..v1.85.0` (24
commits); `git diff --stat` 168 files.

## 3b. Actual version

The minors in `libs/LibKa0s` are v1.84.0's, as 3c's old column shows. The line and the bytes agree.

## 3c. Per-file minor delta

Loop over `LibKa0s.xml` at v1.85.0, old and new constants; files that did not move are left out.

| File | Old | New |
|---|---|---|
| `Glow.lua` | 1 | 2 |
| `Toast.lua` | 1 | 2 |
| `Skin.lua` | 11 | 14 |
| `SkinDefs.lua` | 19 | 24 |
| `SkinDefsOthers.lua` | 1 | 6 |
| `SkinPaint.lua` | 13 | 16 |
| `SkinPaintExtras.lua` | 7 | 15 |
| `SkinPaintControls.lua` | 11 | 14 |
| `SkinEUI.lua` | 2 | 3 |
| `SkinAce.lua` | 6 | 9 |
| `Widgets.lua` | 17 | 20 |
| `WidgetsReorder.lua` | 3 | 5 |
| `WidgetsDragHandle.lua` | 10 | 12 |
| `WidgetsLineChart.lua` | 5 | 6 |
| `WidgetsAutocomplete.lua` | 5 | 6 |
| `WidgetsCopyWindow.lua` | 2 | 4 |
| `DebugLogWindow.lua` | 2 | 3 |
| `Launcher.lua` | 5 | 6 |
| `OptionsWidgets.lua` | 41 | 44 |
| `OptionsIds.lua` | 6 | 7 |
| `OptionsIdList.lua` | 7 | 8 |
| `OptionsTabs.lua` | 13 | 15 |
| `OptionsCompose.lua` | 16 | 17 |
| `OptionsScroll.lua` | 10 | 13 |
| `OptionsNav.lua` | 4 | 5 |
| `OptionsDrawer.lua` | 4 | 5 |
| `OptionsKeybinds.lua` | 6 | 7 |
| `OptionsAppearance.lua` | 5 | 6 |
| `OptionsSkinPicker.lua` | 5 | 7 |
| `OptionsMedia.lua` | 3 | 4 |
| `PerfPanel.lua` | 11 | 12 |
| `SimPanel.lua` | 9 | 10 |
| `SimPanelRender.lua` | 1 | 2 |

No file is behind another, so there is no cross-major skew. No file is new.

## 3d. Both diffs

`diff -rq --strip-trailing-cr` of the v1.84.0 extract against both payloads, less the undeclared
icons: empty. No fork.

## 3e. Consumption map

    grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/

166 lookup sites; no new major, and Perf stays declined (LIBKA0S-17).

## 3f. Kit revision

`Kit.VERSION` 47 -> 49. The two payloads move together, as the pairing rule asks.

## 3g. Contract delta

`CHANGELOG.md`'s v1.85.0 block and `docs/releasing.md`, *Step 8 for v1.85.0*. No host-supplied member
moved its call site. Blockers, all resolved in this commit:

- The degraded facade in `core/SkinSetup.lua` owes `Mark`, `MarkText`, `HudTextColor`,
  `HudLabelColor`, `BarFillColor`, `HudShadow`, `BarGloss` and `HudFont`. `docs/releasing.md` lists
  six; the changelog's *What a consumer owes* adds the last two, and the parity case reads the live
  facade.
- The Options stub in `settings/OptionsSetup.lua` owes `LabelFont`.
- The `LibKa0s icons:` line owes `chevron-up, move, reset, volume-high`, or the kit's vendor gate
  goes red on `VendorSync.LIBRARY_MARKS`.

## 3h. Tags vendored and unrecorded

None: the listing is empty. No span bundle.

## 3i. The icon declaration

Decided by the plan (`docs/releasing.md`, Step 8), so not re-asked:

    LibKa0s icons: chevron-down, chevron-right, chevron-up, clear, close, confirm, copy, export, eye, info, move, reset, search, settings, sort-down, sort-up, volume-high.

Hand lists have drifted before, and the owner's smoke is the backstop: a pruned icon draws blank.

## 3j. Tests that assume the whole icon folder

`tests/test_mediasetup.lua` and `tests/test_libka0s.lua` read declared names only. No change owed.
