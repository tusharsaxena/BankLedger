Delta: LibKa0s v1.85.0 -> v1.89.0

Run 2026-11-06, item V89-BL of the collection re-vendor (Ka0sAddonsCommonTasks
`docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`), on branch `feat/2026-11-06-revendor-libka0s-v1-89`.
Tag v1.89.0 (`0bd4839`, pushed), extracted with
`git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/v89-bl/new`.

## Pre-flight (Step 0, this addon's row)

From the run's `inputs/step0-preflight.txt` (the skill's roster regex is stale; the run used the
backticked-path form the plan records):

    BankLedger  2026-11-01-v1.85.0  base v1.84.0  vendored-before v1.84.0@7579910  ok

No base correction is owed.

## 3a. Claimed version

    grep -n '[Bb]undles' CLAUDE.md
    48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).

    c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)      -> 572205b
    git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]...'  -> v1.85.0
    git log --format='%h %s' "$c..HEAD" -- CLAUDE.md             -> (none)

The two agree. Cross-check against the payload at the claimed tag
(`git -C ../LibKa0s archive v1.85.0 LibKa0s testkit`): `diff -rq` on `tests/_kit` is empty, and on
`libs/LibKa0s` prints only `Only in <v1.85.0>/LibKa0s/media/icons: ...` lines (the icons this addon
does not declare). The base is **v1.85.0**.

    git -C ../LibKa0s log --oneline v1.85.0..v1.89.0                -> 27 commits
    git -C ../LibKa0s diff --stat v1.85.0 v1.89.0 -- LibKa0s testkit -> 10 files, +2576 -234

## 3b. Actual version

    grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua

64 constants, all v1.85.0's (3c's old column). The line and the bytes agree.

## 3c. Per-file minor delta

The loop over `git -C ../LibKa0s show v1.89.0:LibKa0s/LibKa0s.xml`; files that did not move are left out.

| File | Old | New |
|---|---|---|
| `Toast.lua` | 3 | 4 |
| `Widgets.lua` | 22 | 23 |
| `DebugLogDiagnostics.lua` (`DIAG_MINOR`) | 6 | 7 |
| `IconBrowserSources.lua` (`LibKa0s-IconBrowser-1.0`) | (new) | 1 |
| `IconBrowserWindow.lua` (`WINDOW_MINOR`) | (new) | 1 |
| `IconBrowser.lua` (`BROWSER_MINOR`) | (new) | 1 |

No file is behind the tag after the copy: no cross-major skew. No `NEEDS_*` floor rose.

## 3d. Diffs before the copy

    diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   (media/icons "Only in <tag>" lines dropped)
    Files .../DebugLogDiagnostics.lua differ
    Only in <tag>/LibKa0s: IconBrowser.lua, IconBrowserSources.lua, IconBrowserWindow.lua
    Files .../LibKa0s.xml differ
    Files .../Toast.lua differ
    Files .../Widgets.lua differ
    diff -rq --strip-trailing-cr <tag>/testkit tests/_kit
    Files .../README.md, framework.lua, mock_ace.lua differ

Every difference is the range's own change. No `Only in libs/LibKa0s` line: nothing removed upstream.

## 3e. Consumption map

    grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'

Core (`core/CoreSetup.lua:58`), Env (`core/EnvSetup.lua:39`), Lifecycle (`core/LifecycleSetup.lua:41`),
Bus (`core/Constants.lua:322`), Pool (`core/PoolSetup.lua:20`), Item (`core/ItemSetup.lua:28`),
Media (`core/MediaSetup.lua:45`), Skin (`core/SkinSetup.lua:105`), DebugLog (`core/DebugLogSetup.lua:23`),
Launcher (`core/LauncherSetup.lua:70`), Sim (`core/SimSetup.lua:32`, `modules/Sim.lua:442`),
Widgets (`modules/Browser.lua:5`, `modules/Export.lua:14`, `modules/SessionWindow.lua:482`),
Schema (`settings/Schema.lua:668`), Options (`settings/OptionsSetup.lua:26`), Slash (`settings/Slash.lua:228`).

Not looked up: Toast, IconBrowser (new), Glow, Charts, Compat (library-internal), Perf (settled decline,
capture engine never runs in combat).

## 3f. Kit revision

    grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
    <tag>/testkit/framework.lua:20:Kit.VERSION = 51
    tests/_kit/framework.lua:20:Kit.VERSION = 50

Kit 50 -> 51 (`367a9f1`, the CallbackHandler unregister guard in `mock_ace.lua`). The pairing rule
(LibKa0s v1.9.0+ needs kit revision 11+ in the same commit) holds by construction: both payloads are
copied whole in one commit.

## 3g. Contract delta

Majors that moved a minor and that this addon looks up: **Widgets** and **DebugLog**.

- Widgets 22 -> 23: `diff` of `docs/api/Widgets/version-22.5.12.6.7.5-docs.md` (v1.85.0) against
  `version-23.5.12.6.7.5-docs.md` (v1.89.0). Every change is additive: `submenu`, `radio`, `selected`
  and `opts.check` on `W.ContextMenu` rows, all **Since 23**; "Every single-level menu, a dropdown's
  and a host's, is unchanged"; "What a consumer owes: nothing for a flat menu; a re-vendor". BankLedger
  opens no `W.ContextMenu` (`grep -rn ContextMenu core modules settings` is empty); its one menu is
  `W.Dropdown` (`modules/Browser.lua:179`), whose rows the new fields do not touch.
- DebugLog 22.6.1.4 -> 22.7.1.4: "No member change". The diagnostics report's `LibKa0s running:` line
  now names `IconBrowser` when present.

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty:
the addon hands the library no host members through an attach seam.

Toast 3 -> 4 adds `SetStack`, `Visible`, `FrameFor` to the surface a host's Toast stub mirrors;
BankLedger has no Toast lookup and no Toast stub (`grep -rn Toast core modules settings tests` outside
`libs/` and `_kit/` is empty), so nothing is owed.

### Blockers

None.

## 3h. Tags vendored and never recorded

The skill's listing (audit walk plus provenance rolls since the store's horizon `2026-08-25`, against
every bundle's tags): 64 vendored, 64 recorded, `grep -vxF -f recorded.txt vendored.txt` prints
nothing. No span bundle.

## 3i. The icon declaration

    grep -n 'LibKa0s icons:' CLAUDE.md
    49:LibKa0s icons: chevron-down, chevron-right, chevron-up, clear, close, confirm, copy, export, eye, info, move, reset, search, settings, sort-down, sort-up, volume-high.

It is the next non-blank line under the provenance line. **Kept as is**: the range adds no
library-drawn icon a BankLedger surface wires (IconBrowser is not consumed; the cascade's submenu arrow
is client art, `Interface\ChatFrame\ChatFrameExpandArrow`, and BankLedger opens no `W.ContextMenu`).
Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop for a name the host forgot.

## 3j. Tests that assume the whole icon folder

    grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'

`tests/test_mediasetup.lua:154` opens only declared names; `:165` reads `Media.ICONS` as the catalog's
name list, not as files; `tests/test_libka0s.lua:733` opens `info.tga`, which is declared. No blocker.
