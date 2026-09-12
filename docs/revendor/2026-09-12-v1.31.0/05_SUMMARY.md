# 05 — Summary: LibKa0s v1.30.0 → v1.31.0

**Tag moved:** v1.30.0 → **v1.31.0** (`30db4ed`, the first cut; re-cut to `e7e1962` and re-vendored
in `2519b9d`, see **Addendum**), taken from the tag, in commit `843c6d8` with the
CLAUDE.md provenance line and `docs/testing.md`'s live tag note.

| File | Constant | Before | After |
|---|---|---|---|
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 14 | **15** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 3 | **4** |
| every other file | — | unchanged | unchanged at the first cut (the re-cut moves `Perf.lua` 10 → **11**; see **Addendum**) |
| `tests/_kit/framework.lua` | `Kit.VERSION` | 16 | **17** |

No cross-major skew and no upstream deletion.

## Reached the addon for free (class A)

- The Options flow engine's path-less `get`/`set` arm, and the composers' `spec.bind` arm. Every row
  here is path-keyed, so both are inert and byte-identical for this addon.
- Kit revision 17's Ace surfaces. They were inert until the harness stopped replacing them, which is
  the adoption below.

## Adopted

| Candidate | Commit | New case |
|---|---|---|
| Harness onto the kit's AceEvent Embed and message bus (#18) | `b2df58c` | Browser/SessionWindow `PLAYER_LOGOUT` recorded, and cleared by `OnDisable` |
| Harness onto the kit's NewAddon, AceTimer and AceConsole (#19) | `aef3e6a` | `NS.addon` carries the kit's `Printf` and records its own events |

## Declined

None. No issue was filed.

## Skipped or unreached

None. Perf stays a settled decline (`performance-§12` row), and this release's first cut does not
touch it. The re-cut does (Perf minor 11), and the decline still holds; see **Addendum**.

## Gates

| Point | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Before the copy | 852/852 | 0/0 |
| After the copy (`843c6d8`) | 852/852, vendor-sync cases passing against v1.31.0 | 0/0 |
| After B1 (`b2df58c`) | 853/853 | 0/0 |
| After B2 (`aef3e6a`) | 854/854 | 0/0 |

luacheck's scope excludes `libs/` and `tests/_kit/`, but it checks `tests/`, so
`tests/wow_mock.lua`, the file carrying the seam, is inside the checked set. Lizard was not needed
for a harness-only change. Later commits on this branch (the debug-logging-§8 traces) are outside
this bundle.

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
