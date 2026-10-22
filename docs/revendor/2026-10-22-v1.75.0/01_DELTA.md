Delta: LibKa0s v1.71.0 -> v1.75.0

# 01 — Delta (BankLedger)

Run: 2026-10-22, item BL-RV of the cross-repo run "LibKa0s issues #45-#58", on branch
`feat/2026-10-22-libka0s-issues-45-58` (cut from `master` at `b0f9493`). Non-interactive: the run's
owner scope pre-decides the icon declaration and every adoption, so nothing is re-asked and no issue
is filed.

Source: the sibling checkout `../LibKa0s`, **local annotated tag `v1.75.0` (tag object `eae0ee5` ->
commit `265a89e`)**, which is not pushed yet. The payloads were extracted with
`git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools | tar -x -C <scratch>`, never from the
library's working tree. `tools/` was extracted only for `prune-icons.lua` and was not copied in.

## Base

`grep -n '[Bb]undles' CLAUDE.md` named **v1.71.0** at `CLAUDE.md:46`, and `CLAUDE.md:48` named kit
revision 38. The last payload commit, `git log -1 --format=%H -- libs/LibKa0s tests/_kit` =
`8d22a58`, left them so. `diff -rq` of both payloads against `git archive v1.71.0` printed nothing
(`payload-matches`), so claim and bytes agreed. **Base: v1.71.0** (commit `cb274a4`).

The newest single-tag bundle, `docs/revendor/2026-10-07-v1.71.0/`, states base v1.70.0, which is
what the provenance line named before its re-vendor. No base correction is needed. No tag was
vendored and left unrecorded (3h), so no span bundle is written.

The range `git -C ../LibKa0s log --oneline v1.71.0..v1.75.0` is 56 commits over four releases:
v1.72.0 (Perf 15, kit 39), v1.73.0 (Options 29, the new `OptionsDrawer`), v1.74.0 (Media 5, the new
`MediaIcons`, 5,836 icons) and v1.75.0 (kit 41, OptionsTabs 9, Core 11, DebugLog 20, OptionsIdList
5, Widgets 13, Item 3, DebugLogDiagnostics 3, PerfPanel 7, and the new majors Glow-1.0 and Sim-1.0).
`git -C ../LibKa0s diff --stat v1.71.0 v1.75.0 -- LibKa0s testkit` reports 5,752 files, almost all
of them v1.74.0's icon TGAs; outside `LibKa0s/media` it is 18 library files (3,903 insertions, 69
deletions), and the kit is 8 files (633 insertions, 52 deletions).

## Per-file minors

From the tag's `LibKa0s/LibKa0s.xml` and each file's `[A-Z_]*MINOR` constant (Step 3c's loop).
Only the files whose minor moved or that are new:

| File | Before (v1.71.0) | After (v1.75.0) |
|---|---|---|
| `Core.lua` | 10 | **11** (comment-only) |
| `Item.lua` | 2 | **3** (`Item.BonusIDsFromLink`) |
| `Glow.lua` | (new) | **1** (new major `LibKa0s-Glow-1.0`) |
| `Media.lua` | 4 | **5** |
| `MediaIcons.lua` | (new) | **1** (`ICONS_MINOR`, the 5,836-name catalog) |
| `Widgets.lua` | 12 | **13** (`W.SearchBox`, `W.TestStrip`) |
| `DebugLog.lua` | 19 | **20** (comment-only) |
| `DebugLogDiagnostics.lua` | 2 | **3** (the header names Glow and Sim) |
| `Options.lua` | 28 | **29** (scroll kept across a structural refresh) |
| `OptionsIdList.lua` | 4 | **5** (comment-only) |
| `OptionsTabs.lua` | 8 | **9** (`O.__releaseChrome` no longer exported) |
| `OptionsDrawer.lua` | (new) | **1** (`O.Drawer`) |
| `Perf.lua` | 14 | **15** |
| `PerfPanel.lua` | 6 | **7** (comment-only) |
| `Sim.lua` | (new) | **1** (new major `LibKa0s-Sim-1.0`) |
| `SimTimeline.lua` | (new) | **1** |
| `SimPanel.lua` | (new) | **1** (the Sim-private step-panel renderer) |

Every other file keeps its v1.71.0 minor. No `NEEDS_*` floor rises. The library is seventeen majors
across forty files. There is no `WidgetsStepPanel.lua` at the tag: `W.StepPanel` was withdrawn
before any release carried it (LK-11 outcome B), and the renderer is private to Sim-1.0. The consumer
was behind on every moved file and is level on all of them after the copy, so there is no
cross-major skew.

## Both diffs

After `cp -r <scratch>/LibKa0s/. libs/LibKa0s/` and `cp -r <scratch>/testkit/. tests/_kit/`, and
**before the prune**:

```
diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # empty
diff -r                     <scratch>/LibKa0s libs/LibKa0s   # empty
diff -r --strip-trailing-cr <scratch>/testkit tests/_kit     # empty
diff -r                     <scratch>/testkit tests/_kit     # empty
```

No `Only in libs/LibKa0s` or `Only in tests/_kit` line appeared, so no file was deleted against the
diffs. After the prune, the only difference is `Only in <scratch>/LibKa0s/media/icons` for the
icons this addon does not declare, which is the declaration working.

## Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and `tests/`: this addon
looks up thirteen majors, unchanged from v1.71.0. They are Bus (`core/Constants.lua`), Core
(`core/CoreSetup.lua`), DebugLog (`core/DebugLogSetup.lua`), Env (`core/EnvSetup.lua`), Item
(`core/ItemSetup.lua`), Launcher (`core/LauncherSetup.lua`), Lifecycle (`core/LifecycleSetup.lua`),
Media (`core/MediaSetup.lua`), Options (`settings/OptionsSetup.lua`), Pool (`core/PoolSetup.lua`),
Schema (`settings/Schema.lua`), Slash (`settings/Slash.lua`) and Widgets (`modules/Browser.lua`,
`modules/Export.lua`). Perf, Compat, Glow and Sim are not looked up.

Moved and consumed: Core, Item, Media, Widgets, DebugLog and Options.

## Kit revision, and the pairing rule

`Kit.VERSION` **38 -> 41** (`grep -n 'Kit.VERSION' tests/_kit/framework.lua`). Revision 39 adds
`latch.lua` (`Kit.assertLatchHoldOrder`) and makes `M.__fireUnconditional` reach the handler of the
last registration (`__kitEver`). Revision 40, which shipped only inside 41, makes `vendor_sync.lua`
hold `media/icons/` to the `LibKa0s icons:` declaration. Revision 41 stops exporting
`Kit.__deviationRows` and `Kit.__declineFor` and makes a lizard raise its own `crashed` complexity
bucket. Both payloads were copied whole in one commit, so the pairing rule is met by construction.
`tests/_kit/run-automated-tests.sh` keeps mode `100755`.

## The icon declaration (3i)

Decided by the run's item spec, recorded here as decided and not re-asked:

```
LibKa0s icons: chevron-down, chevron-right, clear, close, confirm, copy, export, info, search, sort-down, sort-up.
```

It is the next line after the provenance line at `CLAUDE.md:46`. Every name is unprefixed Open
Iconic, and each was checked present in `../LibKa0s/LibKa0s/media/icons/` before the prune.

- Host draw sites, eight names (`core/MediaSetup.lua` `NS.ICON_NAMES`): `close` through
  `B:MakeCloseButton` (`modules/Browser.lua`), on the ledger title bar, the export modal and the
  session window; `chevron-down` (the dropdown affordance in `modules/Browser.lua`, and
  `GROUP_OPEN` in `modules/LedgerTable.lua`); `confirm` (the multi-select tick in
  `modules/Browser.lua`); `search` (the search box in `modules/Browser.lua`); `export`
  (`modules/Export.lua`); `sort-up`, `sort-down` and `chevron-right` (`modules/LedgerTable.lua`,
  through its `markup()`).
- Library-drawn, three names: `close` from `Core.MakeCloseButton` given the folder name, for the
  DebugLog console (`core/DebugLogSetup.lua`) and the `W.CopyWindow` (`modules/Export.lua`); `copy`
  and `clear`, the DebugLog console's title-bar buttons.
- `info` is declared now for `W.TestStrip`'s host-passed mark (item BL-03).
- Not declared: `info` as library art (the one `O.IdList`, in `settings/Panel.lua`, passes no
  `help`, and its `removeStyle = "icon"` draws an atlas); no `PerfPanel` (no perf harness, the
  ratified `performance-§12` exemption); nothing for the Sim panel (item BL-12), whose close is
  `close` and whose step tick is the host-passed `confirm`; no `ph:` or `gi:` icon.

Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`). The owner's in-client smoke is the backstop: a pruned icon still
resolves to a path and draws blank, and no gate sees a name the host forgot to declare.

The prune: `lua <scratch>/tools/prune-icons.lua <BankLedger>` printed
`11 icon(s) declared; kept 12 file(s), removed 5828`. By set: 213 Open Iconic files, 1,435 Phosphor
files (with `phosphor/LICENSE-phosphor.txt`) and 4,180 Game-icons files (with
`game-icons/LICENSE-game-icons.txt` and `game-icons/AUTHORS.txt`). Kept: the eleven TGAs and
`LICENSE-open-iconic.txt`.

## Blockers

Each one is fixed in the re-vendor commit, beside the payload and the provenance line.

- **4a. A dead `__releaseChrome` mirror.** OptionsTabs minor 9 stops exporting
  `O.__releaseChrome` (LibKa0s#45). `settings/OptionsSetup.lua` mirrored it in the library-absent
  stub as `__releaseChrome = function() end`. That line is removed, and the comment above the
  tabbed-page stubs is rewritten to say why the other `__` mirrors stay (the live instance still
  publishes them) and why this one went. The Options parity case uses the by-name form, which
  skips `__` names, so the parity case does not depend on them.
- **4b. `O.Drawer` parity (v1.73.0).** The Options degraded-stub parity case went red with
  `Drawer is missing (live: function)`. The library's own *What a consumer owes* suggests a no-op
  stub. The item spec rules otherwise: `grep -rn Drawer core modules settings` is empty, and the
  case's rule for a live-only name with no call site is the ignore list. So `"Drawer"` joins
  `IGNORE` in `tests/test_surface_parity.lua`, with a one-line reason, and is not stubbed.
- **4c. Kit 39 `__fireUnconditional`.** Step 6 of `tests/test_disabled.lua` now reaches every
  registered handler after unregister, including the anonymous closures in `modules/Ledger.lua`,
  and stays green: those handlers write nothing while the addon is down. `modules/Ledger.lua` is
  unchanged. The CONTROL case went red for a different reason, which is a harness interaction
  rather than an addon defect. It planted its survivor as `NS.addon.PLAYER_REGEN_DISABLED`, but
  that event is registered under the method name `OnCombatChanged`, and from revision 39 the kit
  calls the last registration's handler (`__kitEver`) before the method named for the event, so
  the planted survivor never ran. The case now plants the survivor on `OnCombatChanged` and
  restores it afterwards. Its three assertions are unchanged.
- **4d. The whole-catalog loop in `tests/test_mediasetup.lua`** ("every name the library ships has
  a file in the vendored copy") went red after the prune, listing every undeclared name. It is
  rewritten to the declaration: it loads `tests/_kit/vendor_sync.lua`, reads
  `VendorSync.iconDeclaration(<CLAUDE.md>)`, and asserts mode `list`, that every `NS.ICON_NAMES`
  name plus `close`, `copy` and `clear` is declared, and that each declared name's `.tga` opens. It
  uses no second parser.
- **4e. The help-mark file case in `tests/test_libka0s.lua`** ("the help-mark art ... is
  vendored"). The `addonName`-on-descriptor case is kept. The file case becomes: `info` is declared
  and vendored for the TestStrip, and no `O.IdList` spec in `settings/Panel.lua` passes `help`, so
  the library itself draws no `info`.
- **4f. Stale mentions.** `CLAUDE.md:48`'s kit line moves below the declaration and rolls to the
  tag's real `Kit.VERSION`, 41. The `tests/_kit` tree in `docs/testing.md` gains `latch.lua`, the
  `vendor_sync.lua` declaration gate and the crashed complexity bucket. Its stale v1.71.0
  "diffs are empty" paragraph is replaced by the declaration's effect on those diffs, plus the
  re-vendor recipe with its declaration and prune steps. `docs/media.md` gains *Which icons
  ship*. The `NS.ICON_NAMES` comment in `core/MediaSetup.lua` says a new mark also goes on the
  declaration, and that a pruned name needs a re-copy.

Step 3j's grep (`media/icons\|lib.ICONS\|\.ICONS)` under `tests/`, outside `_kit`) found the two
cases in 4d and 4e. The remaining `Media.ICONS` reader in `tests/test_mediasetup.lua` checks that the
names this addon asks for are in the catalog. That is a catalog check, not a file check, and it
stays green.

No contract changed under a consumed surface whose signature did not move, apart from 4a's removed
`__` member. There are no `__Attach*` sites outside `libs/` and `_kit/`.

## Test inventory

`docs/test-cases.md` is regenerated in the same commit (CRLF). Two case titles change (4d and 4e),
and no case is added or removed. `| **Total** |` stays **1266** with `| Skipped | 1 |`, so the README
badge (1266/1266) does not move.
