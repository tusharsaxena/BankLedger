# 01 — Delta: LibKa0s v1.30.0 → v1.31.0

Taken **from the tag**, not from the sibling working tree:
`git -C ../LibKa0s archive v1.31.0 LibKa0s testkit | tar -x -C <scratch>/`. The tag is `30db4ed`
(the first cut; the tag was re-cut to `e7e1962`, see **Addendum** at the end of this file) on the
library's `feat/2026-09-12-v1.31.0` branch, which is not merged to the library's `master`. That
does not matter here, because `tests/test_vendor_sync.lua` compares against the tag the provenance
line names.

This bundle sits beside `docs/revendor/2026-09-12/`, which recorded the v1.30.0 re-vendor on the same
date. Both are frozen.

```
git -C ../LibKa0s tag --sort=-v:refname | head -1      # v1.31.0
git -C ../LibKa0s status --short                       # (empty: clean tree)
git -C ../LibKa0s log --oneline v1.30.0..v1.31.0
  30db4ed The v1.31.0 release record
  2b312db v1.31.0: release pointers, standards v2.44.0, the case list
  f355fdc Kit 17: the Ace surfaces six consumer harnesses migrate onto
  3162e53 Options 15.15.4.3: a record-backed bind arm for the composers (PanelMaster#48)
  09099b1 docs(releasing): v1.30.0 is merged in all ten consumers
  853c62e Merge branch 'fix/kit-27-30'
  5193ebe Post-tag v1.30.0: consumers table sweep; AuraMaster is the tenth consumer
```

> **Superseded:** this log is the tag's first cut. The re-cut tag `e7e1962` carries the review fixes
> and moves `Perf.lua` to minor 11; see **Addendum** at the end of this file.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
```

> 46: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.30.0** (MIT).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR|COMPOSE_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, `COMPOSE_MINOR` 3, `SCROLL_MINOR` 3,
`WIDGETS_MINOR` 14, Perf 10, `PANEL_MINOR` 5, Pool 3, Slash 7, Widgets 9. These are the minors the
v1.30.0 changelog block names, so the line and the bytes **agreed** before the copy.

## 3c — Per-file minor delta

Read from the tag's `LibKa0s/LibKa0s.xml` (14 files).

| File | Constant | v1.30.0 | v1.31.0 |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | 7 |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | 1 |
| `Media.lua` | `MINOR` | 3 | 3 |
| `Widgets.lua` | `MINOR` | 9 | 9 |
| `DebugLog.lua` | `MINOR` | 12 | 12 |
| `Slash.lua` | `MINOR` | 7 | 7 |
| `Options.lua` | `MINOR` | 15 | 15 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 14 | **15** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 3 | **4** |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | 3 |
| `Perf.lua` | `MINOR` | 10 | 10 at the first cut; **11** at the re-cut (see **Addendum**) |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

Two files moved at the first cut, both in the Options major (the re-cut moves `Perf.lua` as well;
see **Addendum**). **No cross-major skew.** After the copy the payload
carries exactly the minors the v1.31.0 changelog block names.

## 3d — Both diffs, both directions

Before the copy:

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # OptionsCompose.lua, OptionsWidgets.lua differ
diff -rq                     <tag>/LibKa0s libs/LibKa0s   # the same two
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua differ
diff -rq                     <tag>/testkit tests/_kit     # the same three
```

Content is dirty in both payloads, so this is a real update, not line-ending drift. Neither diff has
an `Only in libs/LibKa0s` or `Only in tests/_kit` line, so nothing was removed upstream and nothing was
deleted here.

After the copy (`cp -r <tag>/LibKa0s/. libs/LibKa0s/`, `cp -r <tag>/testkit/. tests/_kit/`) all four
diffs are **empty**. `tests/_kit/run-automated-tests.sh` keeps its `100755` mode.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
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
| Slash | `settings/Slash.lua:133` |
| Perf | **none**. This is the settled decline: the `performance-§12` row in `docs/ARCHITECTURE.md` → Documented deviations. |

The map is unchanged from the v1.30.0 bundle.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
  <tag>/testkit/framework.lua:20:Kit.VERSION = 17
  tests/_kit/framework.lua:20:Kit.VERSION = 16
```

Kit revision **16 → 17**. The pairing rule (any LibKa0s at v1.9.0 or later takes kit revision 11 or
later in the same commit) holds by construction, because both payloads are copied whole in one
commit.

The tag's `CHANGELOG.md` measured this on a fresh clone at `5f42f5c`: 848 passed, 2 skipped, 850 total
with revision 16, then the same with revision 17, then the same with the whole v1.31.0 payload.
Revision 17 adds no consumer-side case. This branch had grown to 852 before the copy (the #16 and #17
commits), so the expectation here is 852 unchanged.

## Addendum, 2026-09-12: the v1.31.0 tag was re-cut before release

This bundle was written against the first cut of the `v1.31.0` tag (commit `30db4ed`). Before anything
was pushed, a review of that release found defects in the kit-17 fakes, and LibKa0s re-cut the tag on the
fixed tree: **`v1.31.0` now points at `e7e1962`**. The re-vendor commit **`2519b9d`**, which follows this
bundle, copied both payloads whole from the re-cut tag, and the vendor-sync cases pass against it.

What the re-cut changed, relative to the tables above:

| File | First cut | Re-cut |
|---|---|---|
| `Perf.lua` | minor 10 (unchanged) | **minor 11**: `P.Save` traces the ring trim once past its cap (debug-logging-§8) |
| `OptionsWidgets.lua` | minor 15 | minor 15 (review fixes land inside the unreleased minor: `pairWith` keyed by `row.path or row.field`; a bound row's `disabledIf` reads through `row.get`) |
| `OptionsCompose.lua` | minor 4 | minor 4 (unchanged surface) |
| kit (`tests/_kit/`) | revision 17 | revision 17 (review fixes: repeating-timer delay no longer drifts; the nameless `NewAddon` path is exactly one table argument; the timer handle field is AceTimer's own `cancelled`, and `NewTimer` handles answer `IsCancelled()`; dispatch survives a handler error; `ADDON_LOADED` after login enables a load-on-demand addon; the AceEvent library object carries the message API) |

So three files in `LibKa0s/` move in this release, not two, and the upstream "the ring trim is not
traced" finding is resolved by Perf minor 11. This bundle recorded no such finding of its own.

**Perf is not wired here, so the `performance-§12` decline still holds.** No file outside `libs/` and
`tests/` looks up `LibKa0s-Perf-1.0` (the consumption map in `01_DELTA.md` §3e is unchanged at the
re-cut), so Perf minor 11 arrives as vendored bytes this addon loads and never calls: `P.Save` never
runs here, and neither does its new trace. The decline's premise, that this addon's capture engine never
runs in combat so every bucket would read `0.000`, is about this addon's own code, and the re-cut does not
touch it. The row in `docs/ARCHITECTURE.md` → Documented deviations stands, and Perf is not re-offered.

The gate was re-run on the re-cut payload at `2519b9d`:

| Point | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Re-vendor of the re-cut (`2519b9d`) | 857/857, vendor-sync cases passing against `v1.31.0` at `e7e1962` | 0/0 |

The re-vendor added and moved no case: its parent carries the same 857. The step from 854 (after B2) to
857 is later commits on this branch, outside this bundle.
