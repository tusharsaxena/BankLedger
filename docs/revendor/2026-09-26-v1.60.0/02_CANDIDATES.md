Candidates: LibKa0s v1.58.0 -> v1.60.0

# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.58.0..v1.60.0`, the v1.59.0 and v1.60.0 blocks of the
tag's `CHANGELOG.md`, and the `Since` markers in `docs/api/DebugLog/version-14.1-docs.md`,
`docs/api/Slash/version-16-docs.md` and `docs/api/Widgets/` (DragHandle minor 3).

## A. Delivered on the re-vendor alone

- **The 3000-line debug buffer** (DebugLog 14: `MAX_BUFFER` 1500 -> 3000, `BUFFER_SLACK` 64 -> 128).
  The console, its message frame and the Copy window read the constant, so `/bl debug` holds twice
  the trace with no host change. Not an adoption (plan rule for M3).
- **`lib.TIME_COPY`**, the hand-set copy-timing switch (DebugLog 14). A maintainer aid; off by default.
- **`diagnostics` in `lib.LIVE_VERBS`** (Slash 16). This addon passes no `liveVerbs`, so the live
  dispatcher inherits it; it has no effect until the verb is registered.

## B. Host change required

| # | Candidate | Evidence | Would touch | Recommendation | Blast radius |
|---|---|---|---|---|---|
| B1 | **The diagnostics helper**: `D:RunDiagnostics(spec?)`, `D:BuildDiagnostics`, `D:DebugVerb`, the `brandName` and `diagnostics` descriptor fields, kit revision 27's `test_diagnostics_contract.lua` via `Kit.diagnostics` | `CHANGELOG.md` v1.60.0 *DebugLogDiagnostics minor 1*; `version-14.1-docs.md` *The diagnostics report* | `core/DebugLogSetup.lua`, a new `modules/Diagnostics.lua`, `settings/Schema.lua` (COMMANDS row, debug word), `tests/` | **Adopt, in DR-BL-03** (the plan fixes it; `Ledger:Diagnose` folds in as a section) | Additive |
| B2 | **Slash 16's reserved `diagnostics` verb** registered in `NS.COMMANDS` | `version-16-docs.md:39-61` | `settings/Schema.lua`, `tests/test_slash.lua` live list | **Adopt, in DR-BL-03**, with B1 | Additive |

## C. Whole-module adoption

- **WidgetsDragHandle minor 3's close mark** (`e8faa5d`, Widgets key 10.3). This addon has no
  DragHandle host (`grep -rn DragHandle core modules settings` -> nothing), so it is **not a
  candidate** here (plan: adopted only by ConsumableMaster and AbsorbTracker).
- **Perf**: settled decline (`performance-§12` no-combat-path exemption); nothing in this range moves
  its premise.

Contract blockers are in `01_DELTA.md` 3g and are not candidates.
