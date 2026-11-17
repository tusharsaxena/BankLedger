Delta: LibKa0s v1.93.0 -> v1.105.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools` (tag commit 43ea2bd, a local tag, not on origin yet). Run under Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/`, item RV-BL, copy-and-bundle half only: no adoption interview and no GitHub issue filing (the run's design section 5).

## Step 0 pre-flight
Newest single-tag bundle `2026-11-07-v1.93.0`, line 1 `Delta: LibKa0s v1.92.0 -> v1.93.0`; the provenance line before that re-vendor named v1.92.0. ok, no correction owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` named v1.93.0 before the roll (CLAUDE.md:48).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit`, is the v1.93.0 re-copy (c125edf, WFP-RV2-BL); its CLAUDE.md names v1.93.0. They agree.
- Payload before the copy equalled the library at v1.93.0: `diff -rq` of `libs/LibKa0s` (outside the pruned `media/icons`) and of `tests/_kit` against a v1.93.0 extract printed nothing (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.93.0..v1.105.0` is 117 commits, across the tags v1.94.0 to v1.105.0, none of which this addon vendored. `git diff --stat v1.93.0 v1.105.0 -- LibKa0s testkit`: 419 files changed, 10325 insertions, 721 deletions.

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.105.0)
The constants this addon carried matched v1.93.0's, so the line and the bytes agreed.
```
Core.lua  old: 17  new: 18
Tooltip.lua  old: none  new: 1
Compat.lua  old: 3  new: 4
Role.lua  old: none  new: 1
Callout.lua  old: none  new: 4
CalloutSettings.lua  old: none  new: 5
WaypointArrow.lua  old: none  new: 2
WaypointArrowSettings.lua  old: none  new: 2
Charts.lua  old: 1  new: 2
Media.lua  old: 12  new: 13
Skin.lua  old: 17  new: 18
SkinDefs.lua  old: 27  new: 28
SkinDefsOthers.lua  old: 8  new: 10
Widgets.lua  old: 26  new: 27
WidgetsDropdown.lua  old: 1  new: 2
WidgetsReorder.lua  old: 6  new: 7
WidgetsDragHandle.lua  old: 13  new: 14
WidgetsDragHandleTip.lua  old: none  new: 1
WidgetsCopyWindow.lua  old: 5  new: 6
WidgetsHeader.lua  old: none  new: 1
WidgetsBar.lua  old: none  new: 1
DebugLog.lua  old: 22  new: 23
DebugLogDiagnostics.lua  old: 7  new: 11
DebugLogWindow.lua  old: 4  new: 5
Launcher.lua  old: 9  new: 11
OptionsWidgets.lua  old: 45  new: 46
OptionsNav.lua  old: 6  new: 7
OptionsSkinPicker.lua  old: 11  new: 12
OptionsSkinPickerQueue.lua  old: none  new: 1
IconBrowserWindow.lua  old: 1  new: 2
IconBrowser.lua  old: 1  new: 2
PerfPanel.lua  old: 13  new: 14
Sim.lua  old: 2  new: 3
SimPanel.lua  old: 10  new: 11
SimPanelRender.lua  old: 3  new: 4
```
Every other file in the tag's `LibKa0s.xml` (47) kept its minor. `none` is a file new in the range: Role (v1.95.0), Callout and CalloutSettings (v1.96.0), WaypointArrow and WaypointArrowSettings (v1.99.0), and this release's five, Tooltip, WidgetsDragHandleTip, WidgetsHeader, WidgetsBar and OptionsSkinPickerQueue. No cross-major skew: the copy is whole.

## 3d Diffs
Before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the v1.105.0 extract were both empty. After the prune the only lines are `Only in <extract>/LibKa0s/media/icons...` (icons not declared) and `Only in <extract>/LibKa0s/media/sounds: callout` (no sounds declared). `cp -r` deletes nothing, and no `Only in libs/LibKa0s` line appeared: nothing was removed upstream in the range. New untracked payload files: the ten Lua files above, `media/fonts/BebasNeue-*`, `media/fonts/RussoOne-*`, `media/waypoint/` and `tests/_kit/mock_screen.lua`.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings defaults locales`
```
core/Constants.lua:322:LibStub("LibKa0s-Bus-1.0", true)
core/CoreSetup.lua:58:LibStub("LibKa0s-Core-1.0", true)
core/DebugLogSetup.lua:23:LibStub("LibKa0s-DebugLog-1.0", true)
core/EnvSetup.lua:39:LibStub("LibKa0s-Env-1.0", true)
core/ItemSetup.lua:28:LibStub("LibKa0s-Item-1.0", true)
core/LauncherSetup.lua:70:LibStub("LibKa0s-Launcher-1.0", true)
core/LifecycleSetup.lua:41:LibStub("LibKa0s-Lifecycle-1.0", true)
core/MediaSetup.lua:45:LibStub("LibKa0s-Media-1.0", true)
core/PoolSetup.lua:20:LibStub("LibKa0s-Pool-1.0", true)
core/SimSetup.lua:32:LibStub("LibKa0s-Sim-1.0", true)
core/SkinSetup.lua:105:LibStub("LibKa0s-Skin-1.0", true)
modules/Browser.lua:5:LibStub("LibKa0s-Widgets-1.0", true)
modules/Export.lua:14:LibStub("LibKa0s-Widgets-1.0", true)
modules/SessionWindow.lua:482:LibStub("LibKa0s-Widgets-1.0", true)
modules/Sim.lua:442:LibStub("LibKa0s-Sim-1.0", true)
settings/OptionsSetup.lua:26:LibStub("LibKa0s-Options-1.0", true)
settings/Schema.lua:668:LibStub("LibKa0s-Schema-1.0", true)
settings/Slash.lua:228:LibStub("LibKa0s-Slash-1.0", true)
```
Majors in the payload with no lookup in this addon: LibKa0s-Callout-1.0 LibKa0s-Charts-1.0 LibKa0s-Compat-1.0 LibKa0s-Glow-1.0 LibKa0s-IconBrowser-1.0 LibKa0s-Perf-1.0 LibKa0s-Role-1.0 LibKa0s-Toast-1.0 LibKa0s-Tooltip-1.0 LibKa0s-WaypointArrow-1.0. Perf is the settled structural decline (`performance-§12` exemption, docs/performance.md); the rest have no use here today.

## 3f Kit revision
```
old: tests/_kit/framework.lua:20:Kit.VERSION = 53
new: testkit/framework.lua:20:Kit.VERSION = 57
```
Kit revision 57 pairs with v1.105.0, and both payloads are copied whole in one commit. Revision 57's frame hold (#75: a frame with a raw event registration is held until it unregisters) turned nothing red here. Its `VendorSync.LIBRARY_MARKS` gains `settings`, which this addon already declares. The CLAUDE.md line "That tag carries test-kit revision 51" was stale (the payload was at 53) and now reads 57.

## 3g Contract delta and Blockers
Host-supplied members, `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`:
```
none
```
Changes under surfaces this addon consumes whose shape did not move, each fixed in the re-vendor commit:
- **DebugLog instance gains `Report` and `Serialize`** (DebugLog minor 23, DebugLogDiagnostics minor 11, LibKa0s#79; `docs/api/DebugLog/version-23.11.1.5-docs.md`). `Kit.assertSurfaceParity` reads the instance by name, so the library-absent stub in `core/DebugLogSetup.lua` gains both: `Report` streams the body to chat with no pointer and answers the lines written, `Serialize` answers one line (design R3 §2.4). Red before: `LibKa0s-DebugLog degraded: the stub carries the live surface the addon reaches`.
- **Options instance gains `SideTabs`** (OptionsNav minor 7, from v1.100.0). The stub in `settings/OptionsSetup.lua` gains a nil-answering no-op. Red before: `LibKa0s-Options degraded: the stub carries the live surface the addon reaches`.
- **Ka0s Default's `list.stripe` and `list.hover` moved** (SkinDefs minor 28, LibKa0s#84: stripe white .03 to .08, hover gold .10 to .16). `core/SkinSetup.lua`'s library-absent fallback copies Ka0s Default's values, so it re-copies the two. Red before: `parity: each host-copy skin token is the live library's Ka0s Default value` (`list.hover[4]: host copy 0.1, library 0.16`).
- **The debug console's title bar gains a settings mark** (DebugLogWindow minor 5, WidgetsHeader minor 1, LibKa0s#86): the marks read Copy | Clear | settings | Close, so settings sits at -30, Clear at -54 and Copy at -78 where Clear sat at -30 and Copy at -54. `tests/test_libka0s.lua`'s title-bar case re-pins the offsets the library records and now also pins `settings` at -30. The launcher's `name` is `addonName` (core/LauncherSetup.lua:196), the console's descriptor passes `addonName` (core/DebugLogSetup.lua:110), so the mark finds this addon's settings opener (R9 C8 checked).

**Blockers: none.** No fix needed a decision.

## 3h Unrecorded vendored tags
The re-vendor-bundle walk (provenance tags at every payload commit and every CLAUDE.md roll since the store's horizon, against the tags named by the bundles in `docs/revendor/`):
```
(empty)
```
No span bundle is owed.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: `49:LibKa0s icons: chevron-down, chevron-right, chevron-up, clear, close, confirm, copy, export, eye, info, move, reset, search, settings, sort-down, sort-up, volume-high.`
- Kept as written. This release adds `settings` to the library-drawn set (`docs/releasing.md` at the tag, *Library-drawn icons are the host's to declare*), and the line already carries it. No `LibKa0s sounds:` line: sounds `none`.
- `lua <extract>/tools/prune-icons.lua .`: the icons prune kept 18 files (17 declared plus `LICENSE-open-iconic.txt`) and removed 207 Open Iconic, 1435 Phosphor and 4180 Game-icons files; the sounds prune removed 362 files (eight voice packs). A second run reported `kept 18 file(s), removed 0` and `kept 0 file(s), removed 0`.

## 3j Tests that assume the whole icon folder
```
tests/test_libka0s.lua:692:  -- help-mark art (libs/LibKa0s/media/icons/info.tga). Leave it out and every help mark silently
tests/test_libka0s.lua:733:  local f = io.open("libs/LibKa0s/media/icons/info.tga", "rb")
tests/test_libka0s.lua:734:  assertTrue(f ~= nil, "libs/LibKa0s/media/icons/info.tga is missing")
tests/test_mediasetup.lua:127:  -- declares (a re-vendor prunes media/icons to it), so a whole-catalog loop here is red by design.
tests/test_mediasetup.lua:154:    local f = io.open("libs/LibKa0s/media/icons/" .. name .. ".tga", "rb")
tests/test_mediasetup.lua:165:  for _, name in ipairs(Media.ICONS) do known[name] = true end
```
All already narrowed to declared names; nothing to fix.

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit finds only the history comment at settings/OptionsSetup.lua:190. Nothing to remove.
