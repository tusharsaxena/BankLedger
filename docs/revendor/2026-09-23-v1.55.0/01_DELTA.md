# 01 — Delta: LibKa0s v1.54.2 → v1.55.0

Run: 2026-09-23, Steps 2–4 of `/wow-addon:revendor-libka0s` taken non-interactively by the
orchestrating session (Phase 5 of the 2026-09-22 suite sweep). Steps 5–8 — candidates, interview,
adoption, summary — belong to a later run and are **not** in this bundle. No filing and no push.
Target: this repo, branch `suite/2026-09-22-standards-sweep` @ `33630c2`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.55.0` (tag object `bb161b7` → commit `6f9c5e0`)**,
extracted with `git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/`, never the
working tree. The tag is local to `../LibKa0s` and not yet pushed; `tests/test_vendor_sync.lua`
compares against the tag the provenance line names, so the local tag is enough.

```
git -C ../LibKa0s tag --sort=-v:refname | head -1      -> v1.55.0
git -C ../LibKa0s log --oneline v1.54.2..v1.55.0
  6f9c5e0 Record the v1.55.0 release run
  ae48f3f Make the v1.55.0 record true after the complexity split
  244c752 Bring collectKitHoles and repoKind under the CCN 15 ceiling
  be91249 Split Schema's Set and Validate under the CCN 15 gate
  18ca82a Release v1.55.0
  c051bef Re-vendor the standards reference, and make the v1.55.0 docs true
  06b4051 Add three majors: Compat, Bus, and the Schema runtime's portable half
  2a5e06f Test-kit revision 25: the four gates standard v2.63.0 already cites
```

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` → `CLAUDE.md:46`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.54.2** (MIT).

## 3b — Actual version, before this run

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/<file>` over every
file `LibKa0s.xml` lists: Core 7, Env 1, Lifecycle 1, Pool 3, Item 1, Media 3, Widgets 9,
WidgetsDragHandle 2, DebugLog 12, Slash 14, Launcher 1, Options 23, OptionsWidgets 30, OptionsTabs 3,
OptionsCompose 7, OptionsScroll 3, Perf 12, PerfPanel 5; kit revision 24
(`grep -n 'Kit.VERSION' tests/_kit/framework.lua`). That is v1.54.2's version block, so the line and
the bytes agreed before the copy.

## 3c — Per-file minor delta

File list read from each tag's `LibKa0s/LibKa0s.xml`, in XML order; minors by the same grep as 3b.

| File | Constant | v1.54.2 | v1.55.0 |
|---|---|---|---|
| Core.lua | `MINOR` | 7 | 7 |
| Env.lua | `MINOR` | 1 | 1 |
| **Compat.lua** | `MINOR` | — | **1 (new major `LibKa0s-Compat-1.0`)** |
| Lifecycle.lua | `MINOR` | 1 | 1 |
| **Bus.lua** | `MINOR` | — | **1 (new major `LibKa0s-Bus-1.0`)** |
| **Schema.lua** | `MINOR` | — | **1 (new major `LibKa0s-Schema-1.0`)** |
| Pool.lua | `MINOR` | 3 | 3 |
| Item.lua | `MINOR` | 1 | 1 |
| Media.lua | `MINOR` | 3 | 3 |
| Widgets.lua | `MINOR` | 9 | 9 |
| WidgetsDragHandle.lua | `DRAG_MINOR` | 2 | 2 |
| DebugLog.lua | `MINOR` | 12 | 12 |
| Slash.lua | `MINOR` | 14 | 14 |
| Launcher.lua | `MINOR` | 1 | 1 |
| Options.lua | `MINOR` | 23 | 23 |
| OptionsWidgets.lua | `WIDGETS_MINOR` | 30 | 30 |
| OptionsTabs.lua | `TABS_MINOR` | 3 | 3 |
| OptionsCompose.lua | `COMPOSE_MINOR` | 7 | 7 |
| OptionsScroll.lua | `SCROLL_MINOR` | 3 | 3 |
| Perf.lua | `MINOR` | 12 | 12 |
| PerfPanel.lua | `PANEL_MINOR` | 5 | 5 |
| **kit revision** | `Kit.VERSION` | **24** | **25** |

No existing file's minor moves, so there is no cross-major skew to report. `LibKa0s.xml` gains three
`<Script>` rows (`Compat.lua` after `Env.lua`; `Bus.lua` and `Schema.lua` after `Lifecycle.lua`).
`tests/run.lua` derives its library load list from that XML (`Loader.xmlFiles`), so the three new
files load headless with no edit here, and `tests/test_libka0s.lua:341`'s XML-order check follows
the XML rather than a re-typed list.

## 3d — Both diffs, before the copy

```
diff -r --strip-trailing-cr <scratch>/old/LibKa0s libs/LibKa0s   -> empty (content, vs v1.54.2)
diff -rq                    <scratch>/old/LibKa0s libs/LibKa0s   -> empty (bytes,   vs v1.54.2)
diff -r --strip-trailing-cr <scratch>/old/testkit tests/_kit     -> empty
diff -rq                    <scratch>/old/testkit tests/_kit     -> empty
```

Old tag versus new tag (`diff -rq <scratch>/old/<payload> <scratch>/new/<payload>`):

- `libs/LibKa0s/`: only in the new tag: `Bus.lua`, `Compat.lua`, `Schema.lua`; `LibKa0s.xml` differs.
  Nothing else.
- `tests/_kit/`: only in the new tag: `test_layout_cap.lua`; differs: `README.md`, `framework.lua`,
  the automated-test runner script, `test_eol.lua`, `test_prose.lua`. `vendor_sync.lua`, `loader.lua`
  and the three mock files are unchanged.

No `Only in libs/LibKa0s` or `Only in tests/_kit` line: nothing was removed upstream, so the copy
deletes nothing.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`
(addon source only):

| Major | Lookup site |
|---|---|
| Core | `core/CoreSetup.lua:37` |
| Env | `core/EnvSetup.lua:39` |
| Lifecycle | `core/LifecycleSetup.lua:41` |
| Pool | `core/PoolSetup.lua:20` |
| Item | `core/ItemSetup.lua:26` |
| Media | `core/MediaSetup.lua:45` |
| Widgets | `modules/Browser.lua:5`, `modules/Export.lua:14` |
| DebugLog | `core/DebugLogSetup.lua:21` |
| Slash | `settings/Slash.lua:292` |
| Launcher | `core/LauncherSetup.lua:67` |
| Options | `settings/OptionsSetup.lua:26` |

Unconsumed: **Perf** (settled decline — the `performance-§12` row in `docs/ARCHITECTURE.md`), and
the three new majors **Compat**, **Bus** and **Schema**. Those three are Step 5's class-C candidates
and are left to that run. This addon keeps its own `core/Compat.lua` (`NS.Compat`), its own message
catalog and stand-down record, and its own `settings/Schema.lua` (`NS.Schema`); none of those names
touches the new LibStub majors, so the copy is additive and nothing in the addon resolves them.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua` → 25 (tag)
vs 24 (vendored). Both payloads are copied whole in one commit, which satisfies the revision-11
pairing rule by construction and is the reason they move together.

## 3g — Contract delta

**Library.** The majors whose minor moved, intersected with the majors this addon consumes, is the
empty set: no existing file's minor moved. No `docs/api/<Major>/` document for a consumed major
changes version between the two tags, so there is no old/new pair to diff, and
`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit`
returns nothing — this addon hands no member to a library attach seam. **No library contract
blocker.**

**Kit — one blocker, resolved in the vendor commit.** Kit revision 25 changes the contract of
`Kit.assertSuiteInventory` (`testkit/framework.lua`, `collectKitHoles`) without changing its
signature: a declaration is now keyed by the pair (basename, directory), not the basename. This repo's
`tests/run.lua` declared a bare `"test_prose"` beside its own `tests/test_prose.lua`, while
`tests/_kit/test_prose.lua` (arrived with kit 24) was declared nowhere. Under revision 24 the bare name
was accepted as covering the kit's copy, which therefore ran zero cases; the v1.55.0 CHANGELOG names
BankLedger among the six repos in exactly that state. Under revision 25 it is a **collision** and the
run aborts before any case. The same revision ships `tests/_kit/test_layout_cap.lua`, undeclared here,
which is a **hole** and aborts the run the same way.

Resolution, in Step 4's commit beside the payload and the provenance line:

- `tests/run.lua` declares `{ name = "test_prose", dir = "tests/_kit/" }` and
  `{ name = "test_layout_cap", dir = "tests/_kit/" }`, the form `testing-§9` prescribes, and the bare
  `"test_prose"` is removed.
- `tests/test_prose.lua` — the hand-written gate the 2026-09-22 commit meant to retire — is deleted.
  `localization-§5` permits the kit's gate or the repo's own, never both; the kit's reads the whole
  tracked set with the same named exclusions this copy carried, so coverage does not narrow.
- Prep that is green on revision 24 landed first, in its own commits:
  - `tests/test_harness.lua` learned the `{ name, dir }` entry shape (`bb2e120`). Before that it
    crashed on the kit's own remedy ("attempt to concatenate local 'suite' (a table value)").
  - `docs/ARCHITECTURE.md` gained the `### Files over the 1500-line cap` census under
    `## Documented deviations`, empty ("Nothing is over the cap today"), which the new
    `test_layout_cap` gate reads (`33630c2`).

**Blockers:** one, kit-side (the pair-keyed suite inventory), fixed in the vendor commit. None
library-side.
