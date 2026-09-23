# 04 — Execution plan

Step 7 of `/wow-addon:revendor-libka0s`. One commit per adopted candidate, in the order
`03_DECISIONS.md` settled. For each: the characterization written and green **before** the code
moved, the assertions that prove the change, and the commit boundary. Every gate ran through
`~/.claude/wow-addon/bin/ka0s-bounded`. The fences held throughout: nothing under `libs/` or
`tests/_kit/` was written, no version was bumped, and nothing was pushed.

Baseline, at `4310368` before either candidate: `lua tests/run.lua` 987 passed, 0 failed, 0 skipped;
`luacheck .` 0 warnings / 0 errors in 69 files.

## C1 — `LibKa0s-Bus-1.0` `Catalog` -> `f14c9df`

**Files.** `core/Constants.lua` (the `Bus` resolution, the one-member stub, `NS.__busLib`, `NS.MSG`);
the 25 literal lines in `core/Database.lua`, `core/Util.lua`, `modules/Browser.lua`,
`modules/Insights.lua`, `modules/Ledger.lua`, `modules/SessionWindow.lua`, `settings/Panel.lua`,
`settings/Schema.lua`, `settings/Slash.lua`; `tests/run.lua` (the suite and the surface source);
`tests/test_bus.lua` (new); `tests/test_surface_parity.lua`; `docs/ARCHITECTURE.md` `## Message bus`,
`docs/module-map.md`, `docs/testing.md`, `docs/test-cases.md`, the README badge.

**Characterization first** (`tests/test_bus.lua`, 6 cases, green against the literal call sites:
993 passed, 0 failed):

- every module's receiver is subscribed to exactly the wire names it had (Ledger, Browser,
  SessionWindow, Insights, each as one sorted set);
- no live registration names an addon message outside the four;
- each sender's name, payload **arity** and payload values: `Database:Add` (entry, index),
  `FireLedgerChanged` (none), a settings write and the row-tint refresh (the reason string), and the
  bank frame's open and close (`true` then `false`, with the context).

**Assertions that prove the change** (added with it): `NS.MSG` holds exactly the four names; it is
strict live (an undeclared read raises `no bus message named <KEY>`, an added key raises); on a
library-less load it is the same four as a plain table with no metatable; no TOC-loaded file but
`core/Constants.lua` carries a quoted `Ka0s_BankLedger_` literal, and that file carries four; and the
stub is held to the live major by name, with `New` named as live-only.

**Gate at the commit:** 998 passed, 0 failed, 0 skipped; lint 0/0 in 70 files.

## C2 — `LibKa0s-Schema-1.0`, full adopter -> `0d9d1e6`

**Files.** `settings/Schema.lua` (the host seam replaced by the instance, the stub, the Minimap row's
`set`, the `AddRows` head splice, `S:Register` on `Validate`); `settings/OptionsSetup.lua` and
`settings/Slash.lua` (descriptors bound to the instance's members); `core/Util.lua` (the orphaned
`SplitPath` removed); `tests/test_schema_runtime.lua` (new), `tests/test_surface_parity.lua`,
`tests/test_libka0s.lua` (three degraded re-pins), `tests/test_util.lua`, `tests/run.lua`;
`docs/ARCHITECTURE.md` `## Settings Schema`, `docs/module-map.md`, `docs/slash-dispatch.md`,
`docs/testing.md`, `docs/test-cases.md`, the README badge.

**Characterization first** (`tests/test_schema_runtime.lua`, 13 cases, green against the host's own
seam: 1011 passed, 0 failed). The assertion standard is "behaves the same", so each pins an output,
an order or an arity, not "still runs":

- the write's four effects in order, as one string: the `[Set] <path> = <value>` line, then
  `onChange` (which already reads the stored value), then the panel repaint, once each; the same for a
  session-only row, which stores nothing under `db.global`;
- the answers with their arity: `true` (one value), `false, "unknown path: <path>"` (two),
  `false, "invalid value"` (two) under a validate refusal, which also leaves no line, no reaction,
  no repaint and no stored value;
- an unknown path stores nothing at either depth;
- the Minimap row writes `hide` inverted **into the table LibDBIcon holds** (identity checked) and
  reads back in the row's own sense;
- `ApplyDefault`: one-value `true`, `false` for a pathless row or nil, the sweep veto binding inside
  a bracket only;
- `Default` a fresh copy; `SameValue` by content, `false` distinct from absent;
- degraded: a write lands, reads back, reacts and answers the same two values; a table is stored as a
  copy and the default stays whole; the resetall sweep writes every row back and closes its bracket.

**Assertions that prove the change** (added with it): the seam is the library's instance and every
host name is bound to it; `S:Register` reports a path missing from the defaults even when the row
carries a default, and reports a duplicate path while `FindRow` keeps the first; `O.RestoreDefaults`
skips the Minimap row and logs exactly `[Set] reset general: 1 rows` (shown red under the old
descriptor before the new one went in); the stub instance matches the live instance two-table, with
the seven trimmed members named; the stub library matches the major by name, `STRINGS` excepted.

**The one planned re-pin.** Three degraded cases in `tests/test_libka0s.lua` pinned a `[Set]` line
the library-less build writes. Under the log-silent stub they went red on the attempt, as the Schema
spec predicts (`schema.md:480-482`), and were re-pinned to what a player can observe: the rows written
back, the error re-raised unchanged (a nil raise included), and the bracket closed after a raise.

**Gate at the commit:** 1015 passed, 0 failed, 0 skipped; lint 0/0 in 71 files. Complexity over the
touched source and suites: `ka0s-bounded lizard -C 15 -w` reported no function above CCN 15.

## C3 — `LibKa0s-Compat-1.0` — no code

Declined "never", filed as issue #20. Nothing to implement.

## The bundle -> its own commit

`02_CANDIDATES.md` through `05_SUMMARY.md`, committed after the two adoption commits, on a green gate.
