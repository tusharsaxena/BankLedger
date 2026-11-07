Delta: LibKa0s v1.92.0 -> v1.93.0

Recorded before anything was committed. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.93.0 LibKa0s testkit tools` (tag commit 60c2f41, local annotated tag, not yet pushed). Run under the WoW Forever port, item WFP-RV2-BL.

## 3a Base
- `grep -ioE 'Bundles \[LibKa0s\]\(...\) v...' CLAUDE.md` named v1.92.0 before the roll.
- Last payload commit before this run, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 01008dc; its CLAUDE.md names v1.92.0. They agree.
- Payload before the copy equalled the library at v1.92.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.92.0 extract printed nothing (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.92.0..v1.93.0` is 6 commits (WFP-LK-06, WFP-LK-08, WFP-FIX-02, WFP-LK-09).

## 3b/3c Per-file minors that moved (old = this addon, new = v1.93.0)
```
OptionsTabs.lua  old: 16  new: 17
OptionsHeader.lua  old: none  new: 1
```
Every file not listed matched v1.92.0 before the copy, so there is no cross-major skew.

## 3d Diffs
Post-copy, `diff -r --strip-trailing-cr` of both payloads against the v1.93.0 extract is empty apart from the icons the addon did not declare; `tests/test_vendor_sync.lua` is green.

## 3e Consumption map
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
Majors in the payload with no lookup in this addon: LibKa0s-Charts-1.0 LibKa0s-Compat-1.0 LibKa0s-Glow-1.0 LibKa0s-IconBrowser-1.0 LibKa0s-Perf-1.0 LibKa0s-Toast-1.0 

## 3f Kit revision
```
old: 20:Kit.VERSION = 52
251:  t.KIT_VERSION = Kit.VERSION
new: 20:Kit.VERSION = 53
251:  t.KIT_VERSION = Kit.VERSION
```
Kit revision 53 pairs with v1.93.0 and both payloads are copied whole in one commit.

## 3g Contract delta and Blockers
`git diff -U0 v1.92.0 v1.93.0 -- LibKa0s/` is the OptionsTabs minor 17 peel (O.PageHeader and O.SubTabStrip moved unchanged into the new OptionsHeader.lua) and the LibKa0s.xml line that loads it. No member changed its name, arguments or behavior. Host-supplied members, `__Attach*` sites in this addon:
```
none
```
**Blockers: none.** One addition in the kit is not a contract change but is a new gate every consumer inherits: `test_client_globals` (kit revision 53), wired in this commit.

## 3h Unrecorded vendored tags
```
(empty)
```

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: 49:LibKa0s icons: chevron-down, chevron-right, chevron-up, clear, close, confirm, copy, export, eye, info, move, reset, search, settings, sort-down, sort-up, volume-high.
- Kept as written; no icon name changes in this run.

## 3j Tests that assume the whole icon folder
```
tests/test_libka0s.lua:692:  -- help-mark art (libs/LibKa0s/media/icons/info.tga). Leave it out and every help mark silently
tests/test_libka0s.lua:733:  local f = io.open("libs/LibKa0s/media/icons/info.tga", "rb")
tests/test_libka0s.lua:734:  assertTrue(f ~= nil, "libs/LibKa0s/media/icons/info.tga is missing")
tests/test_mediasetup.lua:127:  -- declares (a re-vendor prunes media/icons to it), so a whole-catalog loop here is red by design.
tests/test_mediasetup.lua:154:    local f = io.open("libs/LibKa0s/media/icons/" .. name .. ".tga", "rb")
tests/test_mediasetup.lua:165:  for _, name in ipairs(Media.ICONS) do known[name] = true end
```

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: ./settings/OptionsSetup.lua:190:    -- so it is that, not the case, which keeps them here. __releaseChrome is gone: the library
