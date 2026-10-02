Delta: LibKa0s v1.66.0 -> v1.67.0

# LibKa0s v1.66.0 -> v1.67.0: the delta (BankLedger)

Copied from the tag `v1.67.0` (annotated, local, object `749c42e` on commit `0bccf4c`), never from a
working tree: `git -C ../LibKa0s archive v1.67.0 LibKa0s testkit | tar -x -C <scratch>`. `../LibKa0s`
was checked out at that commit with a clean tree, and its `LibKa0s/` matched the archive. Plan item
CA-BL-RV of `Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_CENSUS_ADOPTION/`, on branch
`feat/2026-10-02-libka0s-census-adoption`.

## Base

`CLAUDE.md` named v1.66.0, and the payload before the copy matched that tag in bytes (`diff -r` of
`v1.66.0`'s `LibKa0s/` and `testkit/` against `libs/LibKa0s` and `tests/_kit`: empty). The last
re-vendor commit is `968665a` (GI-BL-RV), whose line names v1.66.0, and its bundle is
`docs/revendor/2026-10-01-v1.66.0/`. No tag went unrecorded, so no span bundle is written.

```
git -C ../LibKa0s log --oneline v1.66.0..v1.67.0
0bccf4c CA-LK-03: v1.67.0 release record (docs/automated-tests/20261002-012529/), its ANALYSIS.md, the release-gate line and DEPENDENCIES.md's verified-with pointer
7e07c83 CA-LK-03: v1.67.0 built to standard v2.75.0; releasing.md steps 7 and 9 for v1.67.0
008a87a CA-LK-02: OptionsIdList minor 3 - the help art checks addonName against the loaded addons; Options minor 28 docblock (#42)
a4f1d17 CA-LK-01: Core minor 10 - MakeResizable gains canResize, onResizeStop and gripParent (#41)
e918c5c Merge branch 'feat/2026-10-01-github-issue-pass'
389a65b GI-LK-13: consumer census at v1.66.0 - docs/api/CONSUMERS.md, adoption-prompt counts, no-consumer lines (#9)
```

## Per-file minors (old -> new; every file not listed is unchanged)

| File | Old | New |
|---|---|---|
| `Core.lua` | 9 | 10 |
| `Options.lua` | 27 | 28 (docblock only) |
| `OptionsIdList.lua` | `IDLIST_MINOR` 2 | 3 |

No file was added or removed, so `LibKa0s.xml` did not move and neither the TOC nor `tests/run.lua`
needs a line.

## Diffs before the copy (`diff -rq` against the tag)

libs/LibKa0s: `Core.lua`, `Options.lua`, `OptionsIdList.lua` differ. Nothing only in the tag.

tests/_kit: no difference.

Nothing was only in the addon, so nothing was deleted. After the copy, `diff -r` (bytes, not just
content) of both payloads against the tag is empty, and the files keep the tag's CRLF bytes, as the
previous re-vendor's did.

## Kit revision

`Kit.VERSION` 35 -> 35. `testkit/` did not change between the two tags, so the kit is unchanged.
The `CLAUDE.md` kit line (revision 35) stands.

## Consumption map

Host lookups: Core, Env, Item, Media, DebugLog, Lifecycle, Pool, Launcher, Bus, Schema, Slash,
Options, Widgets. This is the same set as v1.66.0. Perf is not consumed, under the ratified
`performance-§12` no-combat-path exemption.

## Contract delta: no blocker

Read for the three files that moved. This addon consumes Core and Options, and through Options it
consumes the id list.

- **Core 10**: `MakeResizable(frame, opts)` gains three optional `opts` fields: `canResize`,
  `onResizeStop` and `gripParent`. A caller that passes none of them gets exactly the minor-9
  behavior, and no member was added, so no degradation stub owes anything. This addon does not call
  `MakeResizable` yet. Both of its windows hand-build their grips (`modules/Browser.lua:1102-1112`,
  `modules/SessionWindow.lua:558-568`). That makes this a candidate, not a contract change under a
  surface the addon uses.
- **Options 28**: docblock only. The descriptor's `addonName` is now RECOMMENDED for every host. It
  is read by `OptionsIdList.lua` and is the FOLDER name.
- **OptionsIdList 3**: the help mark takes `d.addonName` only when the client reports that addon as
  loaded. It is trusted headless. A fall past that rung writes one `Cfg` line through `d.debug`.
  This addon's descriptor (`settings/OptionsSetup.lua`) passes no `addonName`, and its two id lists
  (`settings/Panel.lua`) carry no `help`, so no mark is drawn. The change is latent here: the fall
  writes its line only when a mark is resolved, and nothing resolves one.

The headless suite stayed green on the copy alone: 1214 passed / 0 failed / 1 skipped, 1215 total.
That matches the 1214 the README badge recorded before, and `lua tests/run.lua --list` is
unchanged, so the re-vendor commit carries no host fix.
