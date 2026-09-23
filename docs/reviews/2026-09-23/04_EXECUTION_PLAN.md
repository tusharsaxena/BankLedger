# Execution plan: Ka0s Bank Ledger, 2026-09-23 review

**Scope:** 10 findings (F-001 to F-010) → 9 change IDs (C-01 to C-09). There are **no upstream findings**, so there is no cross-repo milestone and no re-vendor commit is required *by this review*. If the collection-wide plan re-vendors LibKa0s for other reasons, that commit lands **before M1** as its own commit, with `CLAUDE.md`'s provenance line and `docs/test-cases.md` moving in the same commit, and the green gate re-run before M1 starts.

**Green gate before every commit:** `ka0s-bounded lua5.1 tests/run.lua` (all pass) and `ka0s-bounded luacheck .` (0/0). Whenever the pass count moves, regenerate `docs/test-cases.md` with `lua5.1 tests/run.lua --list > docs/test-cases.md` and update the README `[tests]` badge **in the same commit**.

## Milestones

### M1: Stand-down and reset correctness (High)

**Done when:** C-01 and C-02 are merged on the branch, the four new cases are green (1017 → 1021), `docs/test-cases.md` and the badge read 1021, and the gate is green.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| M1-T1 | lua-refactorer | C-01 (F-001) | `modules/Ledger.lua`, `core/BankLedger.lua`, `tests/test_disabled.lua`, `docs/ARCHITECTURE.md` (*The stand-down* section gains the context step), `docs/test-cases.md`, `README.md` (badge) |
| M1-T2 | lua-refactorer | C-02 (F-002, F-003) | `settings/Slash.lua`, `tests/test_panel.lua`, `docs/test-cases.md`, `README.md` (badge) |

**Concurrency:** T1 and T2 both touch `docs/test-cases.md` and `README.md`, so **they must be serialized**: T1, then T2. Their code files are disjoint, so the code can be drafted in parallel, but the inventory and badge commits are sequential.

**Checkpoint CP1 (human):** run `03_SMOKE_TESTS.md` C-01 (both cases) and C-02 in the client before M2. These are the two behavior changes a player can see.

### M2: Hygiene and small correctness (Low/Medium, code)

**Done when:** C-04, C-06 and C-07 are merged, the pass count is 1022, and the gate is green.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| M2-T1 | lua-refactorer | C-04 (F-006) | `core/Util.lua` |
| M2-T2 | ux-cleanup | C-06 (F-010) | `core/LauncherSetup.lua`, `settings/OptionsSetup.lua` |
| M2-T3 | lua-refactorer | C-07 (F-009) | `core/BankLedger.lua`, `core/State.lua`, `tests/test_disabled.lua` (or `tests/test_database.lua`), `docs/test-cases.md`, `README.md` (badge) |

**Concurrency:**

- T1 and T2 have disjoint file sets and are **parallelizable**.
- T3 touches `core/BankLedger.lua` and `tests/test_disabled.lua`, which M1-T1 also touched. It must come **after M1**.
- T3 also shares the inventory and badge with nothing else in M2.

### M3: Documentation (F-004, F-007)

**Done when:** C-03 and C-05 are merged, and `tests/test_docs.lua` plus the kit's prose gate are green.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| M3-T1 | ux-cleanup | C-03 (F-004); owner decision on the default | `README.md`; optionally `defaults/Global.lua` and `settings/Schema.lua` |
| M3-T2 | doc-maintainer | C-05 (F-007) | `docs/ARCHITECTURE.md`, `core/Database.lua` (comment only) |

**Concurrency:**

- M3-T1 touches `README.md`, which M1 and M2-T3 also touch (the badge), so it runs **after M2**.
- M3-T2 touches `docs/ARCHITECTURE.md`, which M1-T1 also touches, so it runs **after M1**.
- M3-T1 and M3-T2 are parallelizable with each other.

**Checkpoint CP2 (owner):** the owner rules on the retention default (keep 30, or change to 0) before M3-T1 is committed.

### M4: Client-verified event change (F-005)

**Done when:** `03_SMOKE_TESTS.md` C-08 has been run and recorded, and the outcome-dependent edit has landed with `docs/ARCHITECTURE.md` (registration count) and `docs/performance.md` (sweep row) moved in the same commit.

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| M4-T1 | human (in-client) | C-08 step 1 | none; results recorded in the sign-off table |
| M4-T2 | wow-api-migrator | C-08 step 2 | `modules/Ledger.lua`, `docs/ARCHITECTURE.md`, `docs/performance.md`, and a test in `tests/test_ledger.lua` if a PIM path is added |

**Concurrency:**

- M4-T2 touches `modules/Ledger.lua`, which M1-T1 also touches, so it runs **after M1**.
- It touches `docs/ARCHITECTURE.md`, which M3-T2 also touches, so it runs **after M3**.

**Checkpoint CP3 (human):** the full `03_SMOKE_TESTS.md` regression suite, with the sign-off table filled in.

### M5: Release record (F-008). This milestone is release, not a task now.

**Done when:** at the next `/wow-addon:bump-version`, the regenerated `docs/automated-tests/RESULTS.md` carries:

- a `modules/Insights.lua` band row with an owner disposition;
- `modules/Browser.lua`'s corrected note;
- the new pass count.

**Nothing in this plan regenerates it early.**

## Critical path

`M1-T1 → M1-T2 → CP1 → M2-T3 → M3-T1 (after CP2)`, with `M3-T2 → M4-T2 (after M4-T1)` branching off M1.

M2-T1 and M2-T2 can run any time after M1 starts; they touch no shared files.

## File-overlap map (serialize where listed)

| File | Tasks |
|---|---|
| `docs/test-cases.md`, `README.md` (badge) | M1-T1, M1-T2, M2-T3, M3-T1 (README text) |
| `core/BankLedger.lua` | M1-T1, M2-T3 |
| `tests/test_disabled.lua` | M1-T1, M2-T3 |
| `modules/Ledger.lua` | M1-T1, M4-T2 |
| `docs/ARCHITECTURE.md` | M1-T1, M3-T2, M4-T2 |
| `core/Util.lua` | M2-T1 only |
| `core/LauncherSetup.lua`, `settings/OptionsSetup.lua` | M2-T2 only |
| `settings/Slash.lua`, `tests/test_panel.lua` | M1-T2 only |

## Commit strategy (one commit per task)

1. `Drop the capture context on stand-down, so a re-enable never records the disabled period` (M1-T1; F-001)
2. `Reset all settings re-runs the latch and announces the emptied ledger` (M1-T2; F-002, F-003)
3. `Walk the visibility owners by name instead of allocating a table per combat edge` (M2-T1; F-006)
4. `Spell the brand name once` (M2-T2; F-010)
5. `Postpone the retention prune across a stand-down instead of skipping the session` (M2-T3; F-009)
6. `README: say how long history is kept by default` (M3-T1; F-004)
7. `Cite symbols, not line numbers, in ARCHITECTURE and the DeleteAt comment` (M3-T2; F-007)
8. `Guild bank open/close: <adopt PIM events | drop dead registrations>` (M4-T2; F-005)

Every commit message ends with the session's attribution lines. Do not push or merge without the owner's go-ahead.
