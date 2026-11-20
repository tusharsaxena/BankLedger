Delta: LibKa0s v1.107.0 -> v1.108.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools` (tag commit 56c20b76, a local tag on the library's branch `feat/2026-11-20-libka0s-94-97-99-100`, not on origin yet: `git -C ../LibKa0s ls-remote --tags origin v1.108.0` prints nothing). Run under Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/`, item SD-RV-BL: copy and bundle only, no adoption interview and no issue filing (the run's items for this addon are pre-decided: SD-RV-BL and SD-SK-BL).

## Step 0 pre-flight
Newest single-tag bundle `2026-11-19-v1.107.0`, line 1 `Delta: LibKa0s v1.106.0 -> v1.107.0`; the provenance line before that re-vendor (36de18c^) named v1.106.0. ok, no correction owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` named v1.107.0 before the roll (CLAUDE.md:48).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit`, is 20320f7 ("AF-RV-BL: Re-vendor the re-cut LibKa0s v1.107.0"); its CLAUDE.md names v1.107.0. They agree.
- Payload before the copy equalled the library at v1.107.0: `diff -rq` of `libs/LibKa0s` (outside the pruned `media/icons` and `media/sounds`) and of `tests/_kit` against a v1.107.0 extract printed nothing (payload-matches).
- `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0`: 15 commits (SD-LK-94, SD-LK-99, SD-LK-100, SD-LK-97 Batches A to D, SD-LK-GUARD and SD-LK-REL, with their review fixes). `git -C ../LibKa0s diff --stat v1.107.0 v1.108.0 -- LibKa0s testkit`: 23 files changed, 1363 insertions, 306 deletions.

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.108.0)
The constants this addon carried matched v1.107.0's, so the line and the bytes agreed.
```
Core.lua                   old: 18  new: 19
Callout.lua                old: 4   new: 5
CalloutSettings.lua        old: 5   new: 6
WaypointArrow.lua          old: 2   new: 3
WaypointArrowSettings.lua  old: 2   new: 3
Charts.lua                 old: 2   new: 3
ChartsRender.lua           old: 1   new: 2
SkinPaint.lua              old: 19  new: 20
SkinPaintHud.lua           old: 1   new: 2
SkinPaintControls.lua      old: 18  new: 19
Widgets.lua                old: 29  new: 30
WidgetsDropdown.lua        old: 2   new: 3
WidgetsDragHandle.lua      old: 15  new: 16
WidgetsDragHandleTip.lua   old: 2   new: 3
WidgetsLineChart.lua       old: 7   new: 8
WidgetsBar.lua             old: 1   new: 2
OptionsCompose.lua         old: 19  new: 20
```
(The loop of the command's 3c over the tag's `LibKa0s.xml`; the full constant names are in each file.) Every other file kept its minor. No file is new and no `NEEDS_*` floor rose.

## 3d Diffs
Before the prune, `diff -r --strip-trailing-cr` and `diff -rq` of both payloads against the v1.108.0 extract were empty. After the prune the only lines are `Only in <extract>/LibKa0s/media/icons...` and `Only in <extract>/LibKa0s/media/sounds...` (names not declared).

## 3e Consumption map
Unchanged from `../2026-11-19-v1.107.0/01_DELTA.md` 3e. Of the majors that moved, this addon looks up Core, Skin (SkinPaint, SkinPaintHud, SkinPaintControls), Widgets (Footer, Dropdown) and Options. It calls no `O.FontGroup`, `O.BorderGroup`, `O.BarGroup` or `O.ColorPair` (`grep -rnE 'O\.(FontGroup|BorderGroup|BarGroup|ColorPair)' core modules settings` finds nothing), builds no `W.Bar`, no Charts context, no `S.ApplyBarFill` StatusBar, no `DragHandle`, no Callout and no WaypointArrow. Its footer (`modules/Browser.lua:1089`, `W.Footer` with `grip = true`) carries no marks. The Callout, Charts, Perf and WaypointArrow lookups `grep` finds are inside `libs/` only.

## 3f Kit revision
```
old: tests/_kit/framework.lua:20:Kit.VERSION = 57
new: testkit/framework.lua:20:Kit.VERSION = 58
```
Both payloads copied whole in one commit, as the pairing rule requires; CLAUDE.md's kit sentence rolls 57 -> 58 with the provenance line.

## 3g Contract delta and Blockers
`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: none.
The consumer-visible default changes (OptionsCompose's companions, `W.BarStyle` border and gloss, `S.ApplyBarFill`, Callout, WaypointArrow) reach no surface this addon calls (3e). The kit's revision 58 guards are the one change that reaches it, and it is the intended one (the release's *What a consumer owes*): three new typed-value hits and two switch failures, fixed in this commit (05_SUMMARY.md).

**Blockers: none.**

## 3h Unrecorded vendored tags
The re-vendor-bundle walk (provenance tags at every payload commit and every CLAUDE.md roll since the store's horizon, against the tags the bundles in `docs/revendor/` name): v1.107.0 (36de18c, 20320f7) is recorded by `../2026-11-19-v1.107.0/`. Nothing unrecorded; no span bundle.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: line 49, kept as written (19 names). The release draws no new library icon for a surface this addon wires.
- `lua <extract>/tools/prune-icons.lua .`: icons pruned back to the 19 declared names plus `LICENSE-open-iconic.txt` (kept 20 files); the sounds prune (no `LibKa0s sounds:` line) removed 362 files.

## 3j Tests that assume the whole icon folder
```
tests/test_libka0s.lua:738   io.open("libs/LibKa0s/media/icons/info.tga")   (a declared name)
tests/test_mediasetup.lua:154  io.open over the declared names only
```
No whole-catalog loop. Nothing to fix.
