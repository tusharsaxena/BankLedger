Delta: LibKa0s v1.90.0 -> v1.91.0

Run 2026-11-06, item FU-RV-BL of the follow-ups run (Ka0sAddonsCommonTasks
`docs/2026-11-06-FOLLOWUPS_V1_91/00_PLAN.md`), on branch `feat/2026-11-06-followups-v1-91`. Tag
v1.91.0 (`55bfbb4`) is a **local** tag in `../LibKa0s`, not pushed, so
`git ls-remote --tags origin v1.91.0` prints nothing. That is expected: the provenance line named
v1.90.0, so this is a new re-vendor and not a refresh. Extracted with
`git -C ../LibKa0s archive v1.91.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/fu-rv-bl/x`.

## Pre-flight (Step 0)

Skipped, and stated as skipped. The installed skill's roster regex expects markdown links where
`ADDONS.md` writes `` `../../<Folder>/` ``, so it matches nothing; this run fixes that upstream
(FU-DC1). The newest single-tag bundle, `2026-11-06-v1.90.0`, states base v1.89.0, which is what
`CLAUDE.md` named before its re-vendor commit `4405fc4` (checked by hand below). No base correction is
owed.

    tag_at() { rev=$1; git show "$rev:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]...' | ... ; }
    tag_at 4405fc4^  -> v1.89.0

## 3a. Claimed version

    grep -n '[Bb]undles' CLAUDE.md
    48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0 (MIT).

    c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)      -> 36a7940 (the SF2 refresh)
    git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]...'  -> v1.90.0
    git log --format='%h %s' "$c..HEAD" -- CLAUDE.md             -> (none)

The two agree. The base is **v1.90.0**.

    git -C ../LibKa0s log --oneline v1.90.0..v1.91.0                          -> 9 commits (FU-L1, four FU-L2, two FU-L3, and the v1.90.0 merge and doc sync)
    git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 -- LibKa0s testkit tools    -> 9 files, +1414 -1203

## 3b. Actual version

    grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua

Every constant was v1.90.0's (3c's old column, including the SF2 refresh's Widgets 25). The line and
the bytes agree.

## 3c. Per-file minor delta

The loop over `git -C ../LibKa0s show v1.91.0:LibKa0s/LibKa0s.xml`; files that did not move are left out.

| File | Old | New |
|---|---|---|
| `Core.lua` | 16 | 17 |
| `CorePixel.lua` (`PIXEL_MINOR`) | (new) | 1 |
| `SkinPaintExtras.lua` (`EXTRAS_MINOR`) | 18 | 19 |
| `SkinPaintHud.lua` (`HUD_MINOR`) | (new) | 1 |
| `SkinAceConfirm.lua` (`CONFIRM_MINOR`) | (new) | 1 |
| `Widgets.lua` | 25 | 26 |
| `WidgetsDropdown.lua` (`DROPDOWN_MINOR`) | (new) | 1 |
| `WidgetsLineChart.lua` (`CHART_MINOR`) | 6 | 7 |

Four new files, from the peels (FU-L2). No file is behind the tag after the copy: no cross-major
skew. No `NEEDS_*` floor rose (CHANGELOG v1.91.0).

## 3d. Diffs before the copy

    diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   (media/icons "Only in <tag>" lines dropped)
    Files Core.lua, LibKa0s.xml, SkinPaintExtras.lua, Widgets.lua, WidgetsLineChart.lua differ
    Only in <tag>/LibKa0s: CorePixel.lua, SkinAceConfirm.lua, SkinPaintHud.lua, WidgetsDropdown.lua
    diff -rq <tag>/LibKa0s libs/LibKa0s                      (same; no line-ending-only drift)
    diff -rq <tag>/testkit tests/_kit                        (empty)

Every difference is the range's own change. No `Only in libs/LibKa0s` line: nothing removed upstream.

## 3e. Consumption map

    grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'

Unchanged. Of the majors that moved, BankLedger looks up Core (`core/CoreSetup.lua:58`), Skin
(`core/SkinSetup.lua:105`) and Widgets (`modules/Browser.lua:5`, `modules/Export.lua:14`,
`modules/SessionWindow.lua:482`). It draws no line chart
(`grep -rn 'LineChart' --include='*.lua' --exclude-dir=libs --exclude-dir=_kit .` is empty).

## 3f. Kit revision

    grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
    -> 51 and 51

The kit did not move; both payloads still travel together in the one commit (pairing rule).

## 3g. Contract delta

Read for Core 17.1, Widgets 26.1.6.13.7.8.5 and Skin 17.1.27.8.19.19.1.1.17.4.9 against their v1.90.0
documents:

- Core (`docs/api/Core/version-17.1-docs.md:27`): the pixel members move to `CorePixel.lua`,
  "unchanged". BankLedger calls none of them.
- Widgets (`docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md:23`): `lib.Dropdown`, `lib.ContextMenu`,
  `lib.CloseMenu` and the shared menu move to `WidgetsDropdown.lua`, "unchanged". BankLedger's
  `W.Dropdown` and `W.CloseMenu()` callers (`modules/Browser.lua`, `modules/Export.lua`) see the same
  members on the same major. The LineChart change (`:25-29`) reaches no BankLedger surface.
- Skin (`docs/api/Skin/version-17.1.27.8.19.19.1.1.17.4.9-docs.md:23`): `S.BarGloss`, `S.HudFont` move
  to `SkinPaintHud.lua`, the confirmation box to `SkinAceConfirm.lua`, unchanged. No facade member
  is added or removed (`docs/releasing.md` step 8 at the tag).

    grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
    -> (empty)

### Blockers

Fixed in the re-vendor commit:

- **A test reads the vendored source of a moved member by file name.** `tests/test_marks.lua:159`
  read `libs/LibKa0s/Widgets.lua` for the dropdown tick's Blizzard rung
  (`Interface\Buttons\UI-CheckBox-Check`), which moved to `WidgetsDropdown.lua`. Red after the copy
  (1656 passed, 1 failed); now reads `libs/LibKa0s/WidgetsDropdown.lua`. Two comments naming the
  shared menu's file (`tests/test_browser.lua:227`, `tests/test_export.lua:269`) follow it.
- **The library load list.** `tests/run.lua` derives it from `libs/LibKa0s/LibKa0s.xml`
  (`Loader.xmlFiles`), so the four new files load in the tag's XML order with no edit. The degraded
  "no Widgets" arms (`tests/test_browser.lua:660,707`, `tests/test_export.lua:278`) drop only
  `Widgets.lua`; `WidgetsDropdown.lua` then finds no shell and attaches nothing, which is the shape
  the arms model, and they stay green.
- **Minor pins.** None of the moved files' minors is pinned in a BankLedger test.
- **Stub mirrors.** `core/SkinSetup.lua`'s degraded `S.HudFont` and `S.BarGloss` mirror members
  that moved to `SkinPaintHud.lua` unchanged; the `S.HudFont` stub's comment now names the new file.
  No member is added or removed, so the stub list is otherwise unchanged.

## 3h. Unrecorded vendored tags

The walk (with `tag_at` written over a named `rev` variable) prints nothing: every tag BankLedger
vendored since the store's horizon (2026-08-25) has a bundle. No span bundle.

## 3i. Icon declaration

    grep -n 'LibKa0s icons:' CLAUDE.md
    49:LibKa0s icons: chevron-down, chevron-right, chevron-up, clear, close, confirm, copy, export, eye, info, move, reset, search, settings, sort-down, sort-up, volume-high.

Kept as is (17 names), directly under the provenance line. No provenance split. Decided by the run
(nothing adopted, so no new icon); the owner's in-client smoke stays the backstop for a forgotten name.

## 3j. Tests that assume the whole icon folder

    grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'

`tests/test_libka0s.lua:733` opens `info.tga` (declared); `tests/test_mediasetup.lua:154,165` read
declared names only. No blocker.
