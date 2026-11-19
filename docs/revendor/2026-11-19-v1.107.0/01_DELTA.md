Delta: LibKa0s v1.106.0 -> v1.107.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.107.0 LibKa0s testkit tools` (tag commit 5e96365, a local tag, not on origin yet: `git -C ../LibKa0s ls-remote --tags origin v1.107.0` prints nothing). Run under Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/`, item AF-RV-BL: copy and bundle only, no adoption interview (the run's adoption items are pre-decided in its `plan-data/items.tsv`).

## Step 0 pre-flight
Newest single-tag bundle `2026-11-16-v1.105.0`, line 1 `Delta: LibKa0s v1.93.0 -> v1.105.0`; the provenance line before that re-vendor named v1.93.0. ok, no correction owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` named v1.106.0 before the roll (CLAUDE.md:48).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit`, is f37cc1d ("Re-vendor LibKa0s v1.106.0"); its CLAUDE.md names v1.106.0. They agree.
- Payload before the copy equalled the library at v1.106.0: `diff -rq` of `libs/LibKa0s` (outside the pruned `media/icons` and `media/sounds`) and of `tests/_kit` against a v1.106.0 extract printed nothing (payload-matches).
- `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0`: six commits (cbf3577f AF-LK-01, efbed582 AF-LK-02, f468fe7c AF-DR-LK, 24b9cea1 / 72653ecc / 5e963659 AF-LK-03) plus the v1.106.0 merge 18d2f12a. `git -C ../LibKa0s diff --stat v1.106.0 v1.107.0 -- LibKa0s testkit`: 2 files changed, 195 insertions, 197 deletions.

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.107.0)
The constants this addon carried matched v1.106.0's, so the line and the bytes agreed.
```
WidgetsDragHandle.lua  old: local DRAG_MINOR = 14  new: local DRAG_MINOR = 15
WidgetsDragHandleTip.lua  old: local DRAGTIP_MINOR = 1  new: local DRAGTIP_MINOR = 2
```
Every other file in the tag's `LibKa0s.xml` kept its minor. No file is new and no `NEEDS_*` floor rose.

## 3d Diffs
Before the prune, `diff -r --strip-trailing-cr` and `diff -rq` of both payloads against the v1.107.0 extract were empty. After the prune the only lines are `Only in <extract>/LibKa0s/media/icons...` and `Only in <extract>/LibKa0s/media/sounds...` (names not declared).

## 3e Consumption map
Unchanged from `../2026-11-16-v1.105.0/01_DELTA.md` 3e. This addon looks up `LibKa0s-Widgets-1.0` (modules/Browser.lua:5, modules/Export.lua:14, modules/SessionWindow.lua:482) but builds no `DragHandle`: `grep -rn 'DragHandle' core modules settings` finds nothing. Its title bars are `W.HeaderButtons` (modules/Browser_Chrome.lua:105). The library's own DragHandle user, Callout, is not looked up here.

## 3f Kit revision
```
old: tests/_kit/framework.lua:20:Kit.VERSION = 57
new: testkit/framework.lua:20:Kit.VERSION = 57
```
The kit is unchanged at this tag; both payloads are still copied whole in one commit.

## 3g Contract delta and Blockers
`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: none.
The two moved files change the drag strip's mark order, default settings mark, close (only with `onClose`), tints and tooltip side, and retire `tooltipPlace`. This addon builds no strip, so nothing it supplies is read differently.

**Blockers: none.**

## 3h Unrecorded vendored tags
The re-vendor-bundle walk (provenance tags at every payload commit and every CLAUDE.md roll since the store's horizon 2026-08-25, against the tags the bundles in `docs/revendor/` name):
```
v1.106.0
```
v1.106.0 was vendored by f37cc1d without a bundle. The span bundle `../2026-11-19-v1.106.0-v1.106.0/` records it.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: line 49, kept as written. It already carries `settings`, which the release says a strip host declares.
- `lua <extract>/tools/prune-icons.lua .`: icons pruned back to the 17 declared names plus `LICENSE-open-iconic.txt`; the sounds prune (no `LibKa0s sounds:` line) removed 362 files.
- AF-HDR-BL, later in this run, adds `lock` and `unlock` to the line in its own commit (re-copy of `media/icons` from the extract, then the prune again).

## 3j Tests that assume the whole icon folder
```
tests/test_libka0s.lua:738   io.open("libs/LibKa0s/media/icons/info.tga")   (a declared name)
tests/test_mediasetup.lua:154  io.open over the declared names only
```
No whole-catalog loop. Nothing to fix.
