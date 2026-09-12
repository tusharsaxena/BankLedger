# 05 — Summary: LibKa0s v1.30.0 → v1.31.0

**Tag moved:** v1.30.0 → **v1.31.0** (`30db4ed`), taken from the tag, in commit `843c6d8` with the
CLAUDE.md provenance line and `docs/testing.md`'s live tag note.

| File | Constant | Before | After |
|---|---|---|---|
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 14 | **15** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 3 | **4** |
| every other file | — | unchanged | unchanged |
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

None. Perf stays a settled decline (`performance-§12` row), and this release does not touch it.

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
