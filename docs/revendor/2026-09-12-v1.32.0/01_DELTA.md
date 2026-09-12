# 01 — Delta: LibKa0s v1.31.0 → v1.32.0

Taken **from the tag**, not from the sibling working tree:
`git -C ../LibKa0s archive v1.32.0 LibKa0s testkit | tar -x -C <scratch>/`. The tag is local to
`../LibKa0s` and points at **`e18dd12`** ("The v1.32.0 release record, re-taken on the final tree").
`tests/test_vendor_sync.lua` compares against the tag the provenance line names, so which branch the
library has checked out does not matter.

This bundle sits beside `docs/revendor/2026-09-12-v1.31.0/`, which recorded the v1.31.0 re-vendor on
the same date. Both are frozen.

```
git -C ../LibKa0s tag --sort=-v:refname | head -1      # v1.32.0
git -C ../LibKa0s status --short                       # (empty: clean tree)
git -C ../LibKa0s log --oneline v1.31.0..v1.32.0
  e18dd12 The v1.32.0 release record, re-taken on the final tree
  c6314d6 CLAUDE.md: the luacheck scope is fifty-four files at v1.32.0
  4083889 v1.32.0 review: bulkEnd's info names a profile reset (debug-logging-§10 final ruling)
  4353908 The v1.32.0 release record
  f7d78cd v1.32.0: Options 16 and Slash 8 bracket their reset walks (debug-logging-§10)
  807925a v1.31.0 post-tag docs and test: the verifier's findings
```

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
```

> 46: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.31.0** (MIT).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR|COMPOSE_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, `COMPOSE_MINOR` 4, `SCROLL_MINOR` 3,
`WIDGETS_MINOR` 15, Perf 11, `PANEL_MINOR` 5, Pool 3, Slash 7, Widgets 9. These are the minors the
v1.31.0 (re-cut) changelog block names, so the line and the bytes **agreed** before the copy.

## 3c — Per-file minor delta

| File | Constant | v1.31.0 | v1.32.0 |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | 7 |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | 1 |
| `Media.lua` | `MINOR` | 3 | 3 |
| `Widgets.lua` | `MINOR` | 9 | 9 |
| `DebugLog.lua` | `MINOR` | 12 | 12 |
| `Slash.lua` | `MINOR` | 7 | **8** |
| `Options.lua` | `MINOR` | 15 | **16** |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 15 | 15 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 4 | 4 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | 3 |
| `Perf.lua` | `MINOR` | 11 | 11 |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

Two files move, one per major: the Options and Slash majors each gain the optional
`bulkBegin` / `bulkEnd` bracket around their reset walks (`debug-logging-§10`, standard v2.44.0).
**No cross-major skew.** After the copy the payload carries exactly the minors the v1.32.0
changelog block names.

## 3d — Both diffs, both directions

Before the copy:

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # Options.lua, Slash.lua differ
diff -rq                     <tag>/LibKa0s libs/LibKa0s   # the same two
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # (empty)
diff -rq                     <tag>/testkit tests/_kit     # (empty)
```

Content is dirty in `libs/LibKa0s/` only, so this is a real update, not line-ending drift. The kit
does not move: `Kit.VERSION` is **17** on both sides. Neither diff has an `Only in` line, so nothing
was removed upstream and nothing was deleted here.

After the copy (`cp -r <tag>/LibKa0s/. libs/LibKa0s/`, `cp -r <tag>/testkit/. tests/_kit/`) all four
diffs are **empty**. `tests/_kit/run-automated-tests.sh` keeps its `100755` mode. Both changed files
carry CRLF with CR == LF (1114/1114 and 652/652).

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings locales
```

| Major | Lookup sites |
|---|---|
| Core | `core/CoreSetup.lua:37` |
| Env | `core/EnvSetup.lua:39` |
| Pool | `core/PoolSetup.lua:20` |
| Item | `core/ItemSetup.lua:26` |
| Media | `core/MediaSetup.lua:45` |
| DebugLog | `core/DebugLogSetup.lua:21` |
| Widgets | `modules/Browser.lua:5`, `modules/Export.lua:14` |
| Options | `settings/OptionsSetup.lua:26` |
| Slash | `settings/Slash.lua:145` |
| Perf | **none**. The settled decline: the `performance-§12` row in `docs/ARCHITECTURE.md` → Documented deviations. |

The same set of majors as the v1.31.0 bundle. The Slash site moved from `:133` to `:145` through
later commits on this branch, not through this re-vendor.

**Both moving majors are consumed**, but only one of their new brackets is reachable here:

- **Slash 8, reachable.** Every non-destructive global reset this addon has goes through the
  library's `CliResetAll`: the General page's Defaults button and Blizzard's footer Defaults
  (`P:RestoreDefaults`, `settings/Panel.lua:625`), and `/bl resetall` (`NS.COMMANDS`,
  `settings/Schema.lua:434`). Unbracketed, the write seam (`S:Set`, `settings/Schema.lua:367`) logs one
  `[Set]` line per row.
- **Options 16, not reached.** `O.RestoreDefaults` and `O.RestoreAllDefaults` have no caller here. The
  General page's Defaults action is replaced by `setDefaultsAction` (`settings/Panel.lua:687`), and
  `settings/OptionsSetup.lua:93` records why the library's `RestoreAllDefaults` is not used (the reset
  stays one host-owned implementation shared with `/bl resetall`, LIBKA0S-22, closed issue #10).
  Options 16 therefore arrives as bytes this addon loads and never runs.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
  <tag>/testkit/framework.lua:20:Kit.VERSION = 17
  tests/_kit/framework.lua:20:Kit.VERSION = 17
```

Kit revision **17 → 17**, unchanged. The pairing rule (any LibKa0s at v1.9.0 or later takes kit
revision 11 or later in the same commit) holds.

The tag's `CHANGELOG.md` says that with the whole payload in, on all ten consumers'
`fix/2026-09-12-triage` branches, nothing moves on re-vendor. That holds here: the suite is 858/858
before and after the copy, and the vendor-sync cases pass against `v1.32.0`.
