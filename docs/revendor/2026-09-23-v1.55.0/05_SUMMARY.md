# 05 — Summary: LibKa0s v1.54.2 -> v1.55.0

Run 2026-09-23. Steps 2-4 were Phase 5 of the 2026-09-22 suite sweep (`01_DELTA.md`). Steps 5-8 are
Phase 6 (this bundle), with the interview delegated by the owner (CP-6). Branch
`suite/2026-09-22-standards-sweep`. Nothing was pushed.

## The tag, and the per-file minors

`v1.54.2` -> `v1.55.0` (tag object `bb161b7`, commit `6f9c5e0`). No existing file's minor moved; the
payload gained three majors, each at minor 1; the kit went from revision 24 to 25.

| File | v1.54.2 | v1.55.0 |
|---|---|---|
| Core, Env, Lifecycle, Pool, Item, Media, Widgets, WidgetsDragHandle, DebugLog, Slash, Launcher, Options, OptionsWidgets, OptionsTabs, OptionsCompose, OptionsScroll, Perf, PerfPanel | unchanged (7, 1, 1, 3, 1, 3, 9, 2, 12, 14, 1, 23, 30, 3, 7, 3, 12, 5) | unchanged |
| `Compat.lua` (`LibKa0s-Compat-1.0`) | — | **1** |
| `Bus.lua` (`LibKa0s-Bus-1.0`) | — | **1** |
| `Schema.lua` (`LibKa0s-Schema-1.0`) | — | **1** |
| kit (`Kit.VERSION`) | 24 | **25** |

The full per-file table is `01_DELTA.md` 3c.

## Delivered for free (class A)

Kit revision 25's gates: the suite inventory keyed by (basename, directory), the `layout-§1` cap
census, the `.gitattributes` body case in `test_eol`, and the commit and tree cells in the
automated-test record. All were wired in Phase 5's vendor commit `4310368`. No consumed major moved,
so no library fix arrived for free.

## Contract blockers

Library: none. Kit: one, the bare `"test_prose"` entry shadowing the kit's gate, resolved in
`4310368` (`01_DELTA.md` 3g).

## Adopted

| Candidate | Commit | Tests added |
|---|---|---|
| C1 `LibKa0s-Bus-1.0` `Catalog`: `NS.MSG` declared once in `core/Constants.lua`, 25 literals replaced | `f14c9df` | `tests/test_bus.lua` (10 cases: 6 characterization, 4 for the catalog), 3 Bus cases in `tests/test_surface_parity.lua`: the surface-parity case (`f14c9df`, its ignore list dropped in `f4e8fd9`), the untracked-target shape case with AceEvent present (`f4e8fd9`), and its AceEvent-absent arm, where `NewTarget` answers nil (the follow-up after `f4e8fd9`) |
| C2 `LibKa0s-Schema-1.0` full adopter: `NS.SchemaRuntime`, host names bound, runtime-completing stub | `0d9d1e6` | `tests/test_schema_runtime.lua` (17 cases: 13 characterization, 4 for the intended changes), 2 parity cases; 3 degraded cases in `tests/test_libka0s.lua` re-pinned; 2 `Util.SplitPath` cases removed with the function |

`docs/ARCHITECTURE.md` names each major in its section (`## Message bus`, `## Settings Schema`).
Neither adoption retires a Documented-deviations row, and neither adds one.

## Declined

| Candidate | Outcome | Issue |
|---|---|---|
| C3 `LibKa0s-Compat-1.0` | never: no member of the major matches anything `core/Compat.lua` carries, and no call site would reach one (`3b-specs/compat.md:544`) | [#20](https://github.com/tusharsaxena/BankLedger/issues/20), `state:will-not-do`, `severity:low`, closed as not planned |

## Skipped or unreached

None. Every candidate was decided. The class-C Perf major stays on its settled decline (the
`performance-§12` row, closed issue #9); v1.55.0 changes no premise of it.

## Suite results at each gate

| Gate | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline (`4310368`) | 987 passed, 0 failed, 0 skipped | 0 / 0 in 69 files |
| C1 characterization, before the swap | 993 passed, 0 failed | — |
| C1 commit `f14c9df` | 998 passed, 0 failed, 0 skipped | 0 / 0 in 70 files |
| C2 characterization, before the swap | 1011 passed, 0 failed | — |
| C2 first attempt | 1008 passed, 3 failed (the degraded `[Set]`-line pins) | — |
| C2 commit `0d9d1e6` | 1015 passed, 0 failed, 0 skipped | 0 / 0 in 71 files |
| Bundle commit | 1015 passed, 0 failed, 0 skipped | 0 / 0 in 71 files |
| Review fix `f4e8fd9` (Bus stub to the untracked-target shape) | 1016 passed, 0 failed, 0 skipped | 0 / 0 in 71 files |
| Follow-up (the stub's AceEvent-absent arm pinned) | 1017 passed, 0 failed, 0 skipped | 0 / 0 in 71 files |

Complexity: `ka0s-bounded lizard -C 15 -w` over the touched source files and the two new suites
reported nothing above CCN 15. Not run: the full automated-test battery (`tests/_kit/run-automated-tests.sh`) and the
in-game checks. Nothing in this run needed either to decide a candidate.

## Owed in-game

- The Minimap button checkbox, `/bl set minimap.hide false|true` and `/bl reset minimap.hide` still move
  the button and survive `/bl resetall` (the inversion moved onto the row's own `set`).
- A panel widget write and a `/bl set` still repaint an open settings page (the repaint is now the
  descriptor's `announce`).
