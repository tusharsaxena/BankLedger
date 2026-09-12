# 05 — Summary: LibKa0s v1.31.0 → v1.32.0

**Tag moved:** v1.31.0 → **v1.32.0** (`e18dd12`, local), taken from the tag, in commit `f7ad75e`
with the CLAUDE.md provenance line and `docs/testing.md`'s live tag note.

| File | Constant | Before | After |
|---|---|---|---|
| `Slash.lua` | `MINOR` | 7 | **8** |
| `Options.lua` | `MINOR` | 15 | **16** |
| every other file | — | unchanged | unchanged |
| `tests/_kit/framework.lua` | `Kit.VERSION` | 17 | 17 |

No cross-major skew and no upstream deletion. `tests/_kit/` is byte-identical before and after.

## Reached the addon for free (class A)

- Options minor 16 in full. Nothing here calls `O.RestoreDefaults` or `O.RestoreAllDefaults`, so the
  new bracket is inert and the file is loaded but never runs that path.
- Slash minor 8 with no descriptor pair runs version 7's walk exactly, so the copy alone moved no case.

## Adopted

| Candidate | Commit | New cases |
|---|---|---|
| Slash bracket on `CliResetAll`, the fallback `CliResetAll`, and the `Sl:ResetEverything` settings line (C1) | `81588be` | 10 (see below) |

What each act now logs, with debug logging on:

| Act | Route | Lines |
|---|---|---|
| `/bl resetall` | `NS.COMMANDS` → `Sl:CliResetAll` → library `CliResetAll`, bracketed | `[Set] reset all: N rows` |
| General page **Defaults**, and Blizzard's footer **Defaults** | `P:RestoreDefaults` → `Sl:CliResetAll` | `[Set] reset all: N rows` |
| `/bl resetall` / Defaults, LibKa0s missing | fallback `Sl:CliResetAll`, self-bracketed | `[Set] reset all: N rows` |
| **Reset all settings** (confirm-gated popup) | `Sl:ResetEverything` | `[Data] reset-all wiped N ledger entries`, then `[Set] reset account-wide settings to defaults (N rows)` |
| `/bl set <path> <v>`, a panel widget, `/bl reset <path>` | `NS.Schema:Set` | `[Set] <path> = <value>`, unchanged |

N counts only the rows whose stored value changed, so a reset with everything already at its
default logs `0 rows`. Every row's `onChange` still fires. Nested brackets log one line.

New cases:

- `tests/test_slash.lua`:
  - resetall logs one line with the changed count (`2 rows`);
  - an already-at-default resetall logs `0 rows`;
  - every row's `onChange` still fires, and the seam logs again afterwards;
  - a raising row still closes the bracket;
  - a nested reset logs one line;
  - a `profileReset` bracket logs nothing.
- `tests/test_panel.lua`:
  - Defaults logs one line (`2 rows`);
  - Defaults at defaults logs `0 rows`;
  - `ResetEverything` logs one `[Set]` line beside its `[Data]` line.
- `tests/test_libka0s.lua`: the degraded fallback logs one line.

Red before the change (4 of the first 6 failed on per-row output or a missing line), and red under two
mutations. Logging the library's `count` fails 6 cases. Emitting at every nesting level fails 2.

## Declined

None. No issue was filed.

## Skipped or unreached

C2, the Options minor 16 bracket: no caller here. Perf stays a settled decline (`performance-§12` row);
this release does not touch `Perf.lua`.

## Gates

| Point | `lua tests/run.lua` | `luacheck .` | `lizard -C 15` |
|---|---|---|---|
| Before the copy | 858/858 | 0/0 | 0 over 15 |
| After the copy (`f7ad75e`) | 858/858, vendor-sync cases passing against v1.32.0 | 0/0 | — |
| After C1 (`81588be`) | 868/868 | 0/0 | 0 over 15 |

Every touched file carries CRLF with CR == LF. `docs/test-cases.md` and the README `[tests]` badge
read 868.
