Delta: LibKa0s v1.67.0 -> v1.68.0

# LibKa0s v1.67.0 -> v1.68.0: the delta (BankLedger)

Copied from the tag `v1.68.0` (annotated, local, object `6d83731` on commit `cc9f5eb`), never from a
working tree: `git -C ../LibKa0s archive v1.68.0 LibKa0s testkit | tar -x -C <scratch>`. `../LibKa0s`
sat on `feat/2026-10-02-drag-attach` at that commit, and `git -C ../LibKa0s diff --quiet v1.68.0 --
LibKa0s testkit` exited 0. Plan item TP-BL-01 of
`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/`, on branch
`feat/2026-10-02-drag-attach`.

## Base

```
grep -n '[Bb]undles' CLAUDE.md
46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.67.0 (MIT).

git log -1 --format='%h %s' -- libs/LibKa0s tests/_kit
5e49c3a CA-BL-RV: re-vendor LibKa0s v1.67.0 (Core 10, Options 28, OptionsIdList 3; kit 35 unchanged)
```

That commit's line names v1.67.0, no `CLAUDE.md` commit since has rolled it, and the payload before
the copy matched the v1.67.0 archive (`diff -rq` of both payloads: empty, `payload-matches`). The base
is v1.67.0. Step 0 for this addon: the newest single-tag bundle, `2026-10-02-v1.67.0/`, states base
v1.66.0, and the provenance before `5e49c3a` was v1.66.0, so it is `ok` and no correction is owed.

3h: the vendored-versus-recorded listing printed nothing, so no tag went unrecorded and no span
bundle is written.

```
git -C ../LibKa0s log --oneline v1.67.0..v1.68.0
cc9f5eb DA-LK-07R: v1.68.0 release record re-cut (docs/automated-tests/20261002-232612/), its ANALYSIS.md, the release-gate line and DEPENDENCIES.md's verified-with pointer
6ffa4ca DA-LK-06R: CHANGELOG's v1.68.0 entry gives test_widgets_draghandle.lua as 813 lines; releasing.md's Widgets row gets its missing period
3fe6b43 DA-LK-05R: CLAUDE.md band note - test_widgets_draghandle.lua is 813 lines, test_widgets_draghandle_place.lua 241
ee9dcfe DA-LK-05: v1.68.0 release record (docs/automated-tests/20261002-231513/), its ANALYSIS.md, the release-gate line and DEPENDENCIES.md's verified-with pointer
3cd411d DA-LK-04: peel the placement-hook cases to tests/test_widgets_draghandle_place.lua, the bench to tests/fixture_draghandle.lua
da221a7 DA-LK-03: v1.68.0 release run superseded before the tag (docs/automated-tests/20261002-231003/), one suite entered the band
1382135 DA-LK-02: v1.68.0 built to standard v2.75.0; releasing.md steps 7 and 9 for v1.68.0
2cc8a03 DA-LK-01: WidgetsDragHandle minor 4 - tooltipPlace lets the host place the strip's tooltip (AuraMaster#22)
fce3003 Merge branch 'feat/2026-10-02-libka0s-census-adoption'
89164e4 CA-FIN-02: doc sync before merge
d178a2b CA-LK-04R: CONSUMERS.md split row - lib.LAYOUT left the host-duplicate split by deletion, not adoption
8f55167 CA-LK-04: consumer census at v1.67.0 - CONSUMERS.md restamped, nine verdicts moved, adoption-prompt and no-consumer lines restamped (#9)

git -C ../LibKa0s diff --stat v1.67.0 v1.68.0 -- LibKa0s testkit
 LibKa0s/WidgetsDragHandle.lua | 84 +++++++++++++++++++++++++++++++++++--------
 1 file changed, 69 insertions(+), 15 deletions(-)
```

## Per-file minors (old -> new; every file not listed is unchanged)

Walked over every file the tag's `LibKa0s/LibKa0s.xml` lists, by its own `[A-Z_]*MINOR` constant.

| File | Old | New |
|---|---|---|
| `WidgetsDragHandle.lua` | `DRAG_MINOR` 3 | 4 |

The minors before the copy agreed with the v1.67.0 claim, so the line and the bytes agreed. No file was
added or removed, so `LibKa0s.xml` did not move and neither the TOC nor `tests/run.lua` needs a line.
There is no cross-major skew.

## Diffs before the copy (both directions, content and bytes)

libs/LibKa0s: `WidgetsDragHandle.lua` differs, in content and in bytes. Nothing only in the tag,
nothing only in the addon.

tests/_kit: no difference, in content or bytes.

## Kit revision

`Kit.VERSION` 35 -> 35 (`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua
tests/_kit/framework.lua`). `testkit/` did not change between the tags. The two payloads still move
together in one commit (the kit-revision pairing rule), and the `CLAUDE.md` kit line (revision 35)
stands.

## Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' --include='*.lua' --exclude-dir=libs --exclude-dir=tests .
```

Host lookups: Bus, Core, DebugLog, Env, Item, Launcher, Lifecycle, Media, Options, Pool, Schema,
Slash, and Widgets at two sites (`modules/Browser.lua:5`, `modules/Export.lua:14`). This is the same
set as v1.67.0. Perf and Compat are not looked up by the host. Perf stays unconsumed under the ratified
`performance-§12` no-combat-path exemption. Within Widgets the host uses `W.Dropdown`, `W.CloseMenu` and `W.CopyWindow`,
all in `Widgets.lua`, and never `lib.DragHandle`.

## Contract delta: no blocker

The only major that moved is Widgets (12.1.3 -> 12.1.4), and this addon consumes Widgets, so it was
read. `../LibKa0s/docs/api/Widgets/version-12.1.4-docs.md:20-48` adds one optional spec field,
`tooltipPlace`, and one optional descriptor field, `place`, both Since 4, and states at `:44-45` that a
host setting neither gets minor 3's calls in minor 3's order, and at `:47` "What a host must change:
nothing." No member, `DRAG_HANDLE` field or handle method moved.

Bound to this addon: `grep -rnE 'DragHandle|tooltipPlace|tooltipAnchor|__Attach' --include='*.lua'
--exclude-dir=libs --exclude-dir=_kit .` finds only a comment at `tests/run.lua:50`. BankLedger builds
no drag handle and hands the library no `__Attach*` members, so no host-supplied member's call site
moved. Nothing to fix in the re-vendor commit.
