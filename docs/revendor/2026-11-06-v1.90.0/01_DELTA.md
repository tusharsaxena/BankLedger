Delta: LibKa0s v1.89.0 -> v1.90.0

Run 2026-11-06, item SF1-RV-BL of the collection re-vendor (Ka0sAddonsCommonTasks
`docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`, `SF1_SMOKE_FEEDBACK.md`), on branch
`feat/2026-11-06-revendor-libka0s-v1-89`. Tag v1.90.0 (`b2fce60`) is a **local** tag in `../LibKa0s`,
not pushed, so `git ls-remote --tags origin v1.90.0` prints nothing. That is expected: the provenance
line named v1.89.0, so this is a new re-vendor and not a refresh. Extracted with
`git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/sf1-rv-bl/new`.

## Pre-flight (Step 0, this addon's row)

    BankLedger  2026-11-06-v1.89.0  base v1.85.0  vendored-before v1.85.0@da7b75a  ok

No base correction is owed.

## 3a. Claimed version

    grep -n '[Bb]undles' CLAUDE.md
    48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0 (MIT).

    c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)      -> da7b75a
    git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]...'  -> v1.89.0
    git log --format='%h %s' "$c..HEAD" -- CLAUDE.md             -> (none)

The two agree. Against the v1.89.0 payload (`git -C ../LibKa0s archive v1.89.0 LibKa0s testkit`),
`diff -rq` on `tests/_kit` is empty and on `libs/LibKa0s` prints only `Only in <v1.89.0>/LibKa0s/media/icons`
lines (the undeclared icons). The base is **v1.89.0**.

    git -C ../LibKa0s log --oneline v1.89.0..v1.90.0                          -> 7 commits
    git -C ../LibKa0s diff --stat v1.89.0 v1.90.0 -- LibKa0s testkit tools    -> 7 files, +209 -57

## 3b. Actual version

    grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua

Every constant is v1.89.0's (3c's old column). The line and the bytes agree.

## 3c. Per-file minor delta

The loop over `git -C ../LibKa0s show v1.90.0:LibKa0s/LibKa0s.xml`; files that did not move are left out.

| File | Old | New |
|---|---|---|
| `Core.lua` | 15 | 16 |
| `Skin.lua` | 16 | 17 |
| `SkinPaint.lua` (`PAINT_MINOR`) | 18 | 19 |
| `SkinPaintExtras.lua` (`EXTRAS_MINOR`) | 17 | 18 |
| `Widgets.lua` | 23 | 24 |
| `WidgetsAutocomplete.lua` (`AUTOCOMPLETE_MINOR`) | 7 | 8 |
| `OptionsAppearance.lua` (`APPEARANCE_MINOR`) | 6 | 7 |

No new file. No file is behind the tag after the copy: no cross-major skew. No `NEEDS_*` floor rose
(CHANGELOG v1.90.0: Widgets and Skin resolve Core's new members at call time).

## 3d. Diffs before the copy

    diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   (media/icons "Only in <tag>" lines dropped)
    Files .../Core.lua, OptionsAppearance.lua, Skin.lua, SkinPaint.lua, SkinPaintExtras.lua,
          Widgets.lua, WidgetsAutocomplete.lua differ
    diff -rq <tag>/LibKa0s libs/LibKa0s                      (same seven; no line-ending-only drift)
    diff -rq <tag>/testkit tests/_kit                        (empty)

Every difference is the range's own change. No `Only in libs/LibKa0s` line: nothing removed upstream.

## 3e. Consumption map

    grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'

Unchanged from the v1.89.0 bundle. Of the majors that moved, BankLedger looks up Core
(`core/CoreSetup.lua:58`), Skin (`core/SkinSetup.lua:105`), Widgets (`modules/Browser.lua:5`,
`modules/Export.lua:14`, `modules/SessionWindow.lua:482`) and Options (`settings/OptionsSetup.lua:26`).

## 3f. Kit revision

    grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
    -> 51 and 51

The kit did not move in this range; both payloads still travel together in the one commit (pairing rule).

## 3g. Contract delta

Read for Core 16, Widgets 24.5.12.6.8.5, Skin 17.1.27.8.19.18.17.4.9 and Options
37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4 against their v1.89.0 documents. The changes:

- Core's `__PixelSize`, `__WatchPixels`, `__OnPixelScale`, `__PixelBackdrop` are new and internal
  (`docs/api/Core/version-16-docs.md`). BankLedger calls none of them
  (`grep -rn '__Pixel\|__WatchPixels\|__OnPixelScale' --include='*.lua' --exclude-dir=libs --exclude-dir=_kit .` is empty).
- Widgets 24: `W.Dropdown`, `W.SearchBox`, the shared menu and the autocomplete list take a pixel-exact
  backdrop; "No member or option moves" (CHANGELOG v1.90.0). BankLedger's `W.Dropdown`
  (`modules/Browser.lua:179`) and `W.SearchBox` (`modules/Browser.lua:200`) pass the same opts.
  BankLedger's own `edgeSize = 1` backdrops (`core/CoreSetup.lua:114,124`, `core/SkinSetup.lua:689,738`)
  are host frames the library never marks with `__PixelBackdrop`, so they draw as before.
- Skin 17: `RegisterOwner(owner, { keepScope = true })` is an additive opt-out; "No member moves, so a
  host's Skin facade owes nothing". BankLedger's `RegisterOwner` (`core/SkinSetup.lua:830`) does not
  pass it and keeps the old behaviour.
- OptionsAppearance 7: `lib.__copySkinTo` skips the Scope only for a `keepScope` target. BankLedger is
  not one, so a copy carries Scope to it as before.

    grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
    -> (empty)

### Blockers

None. No stub needs a new member, no test pins an old minor or an edge size (the gate is green after
the copy with no host change).

## 3h. Unrecorded vendored tags

The walk prints nothing: every tag BankLedger vendored since the store's horizon has a bundle. No span
bundle.

## 3i. Icon declaration

    grep -n 'LibKa0s icons:' CLAUDE.md
    49:LibKa0s icons: chevron-down, chevron-right, chevron-up, clear, close, confirm, copy, export, eye, info, move, reset, search, settings, sort-down, sort-up, volume-high.

Kept as is (17 names), directly under the provenance line. No provenance split is owed. Decided by
the run (SF1 adds no icon); the owner's in-client smoke stays the backstop for a forgotten name.

## 3j. Tests that assume the whole icon folder

    grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'

`tests/test_libka0s.lua:733` opens `info.tga` (declared); `tests/test_mediasetup.lua:154,165` read
declared names only. No blocker.
