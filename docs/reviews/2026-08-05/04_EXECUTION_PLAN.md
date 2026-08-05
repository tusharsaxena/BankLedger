# Execution plan — 2026-08-05

Implements `02_PROPOSED_CHANGES.md`. Five milestones. M0 is upstream and lands in **another repo**;
M1–M3 land here; M4 is the verification gate.

Standing rules for every task:

- **Nothing under `libs/` or `tests/_kit/` is edited.** Any task that appears to need it is wrong and
  belongs in M0.
- **Never hand-edit `docs/test-cases.md`.** It is emitted by `lua tests/run.lua --list`.
- **Never edit or delete a test to make a suite green.** C-003 deletes cases because their *subject*
  is being deleted, which is the opposite situation.
- Every commit runs `luacheck . && lua tests/run.lua` before it is made (`testing-§4`'s commit gate).

---

## M0 — Upstream: a real skip status in the shared test kit

**Lands in:** the LibKa0s repository. **Nothing in this milestone edits BankLedger source.**

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-0.1 | lib-maintainer (LibKa0s repo) | U-001 | `testkit/framework.lua` — add `Kit.skip(reason)`; count and print `SKIP` separately; render conditional cases in `--list` |
| T-0.2 | lib-maintainer (LibKa0s repo) | U-001 | Bump `Kit.VERSION` 6 → 7; add the kit-sync case coverage; cut a release tag |
| T-0.3 | vendor-sync (this repo) | U-001 | **Re-vendor the whole `testkit/` folder** into `tests/_kit/`, and update the README provenance line, **as its own commit** |

**Done when:** `tests/_kit/framework.lua` in this repo is byte-identical to the new tag's
`testkit/framework.lua`, `README.md`'s `Bundles [LibKa0s](...) vX.Y.Z` line names that tag, and
`tests/test_vendor_sync.lua` passes **having actually compared** (run with `../LibKa0s` present).

**Cross-repo handoff:** T-0.1/T-0.2 are done and released in the LibKa0s repo **before** T-0.3 is
attempted. T-0.3 is a **whole-folder copy in a commit of its own** — no other change rides with it.
Every other LibKa0s consumer needs the same re-vendor commit; that coordination is outside this plan.

**Explicitly decoupled:** M1–M3 do **not** wait on M0. C-002 is written to be correct with or without
it. If M0 slips, ship M1–M3 and revisit C-002's case names when the new kit arrives.

---

## M1 — Diagnostics tell the truth

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-1.1 | lua-refactorer | C-001, C-005a | `settings/Panel.lua` (the `"AceGUI-3.0"` key at `:405`, and the five prose comments at `:11,13,21,23,402`) |
| T-1.2 | test-author | C-001 | `tests/test_panel.lua` — add the falsifiable minor case, with its `-- red under:` comment |
| T-1.3 | test-author | C-002 | `tests/test_vendor_sync.lua` — case names carry the condition; fix the false comment at `:105-108`; print the looked-for path on the quiet branch |
| T-1.4 | docs | C-001, C-002 | Regenerate `docs/test-cases.md`; update the `[Tests]` badge at `README.md:7` |

**Done when:** `/bl debug panel` reports a real minor (verified by `03_SMOKE_TESTS.md` C-001), the new
case reddens when the `"O."` prefix is restored and greens when it is removed (prove this by actually
mutating and reverting — `testing-§12`), and the two vendor-sync case names in `docs/test-cases.md`
carry their condition.

**Concurrency:** T-1.1 and T-1.3 touch disjoint files → **parallelizable**. T-1.2 depends on T-1.1
(it asserts the corrected behavior). T-1.4 is last in the milestone and must be in the same commit as
whichever task last moved the count or a name.

---

## M2 — Retire the dead surface

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-2.1 | lua-refactorer | C-003 | `core/Compat.lua` (delete `QualityFromLink` + `qualityByHex`/`buildQualityByHex`), `docs/ARCHITECTURE.md:139` |
| T-2.2 | lua-refactorer | C-003 | `core/Database.lua` (delete `DeleteAt`), `tests/test_database.lua`, `tests/test_ledger.lua` |
| T-2.3 | lua-refactorer | C-003 | `modules/Filters.lua` (delete `IsBlacklisted`/`IsWhitelisted`), `tests/test_filters.lua` |
| T-2.4 | lua-refactorer | C-003 | `modules/Insights.lua` (delete `RankRows`/`BarFraction`, drop the stale section heading), `tests/test_stats.lua` |
| T-2.5 | lua-refactorer | C-003 | `modules/LedgerTable.lua:97` — **comment only**; `LT:CellText` stays |
| T-2.6 | lua-refactorer | C-003 | **Re-run the dead-code sweep** after T-2.1–T-2.4; a deletion can orphan a helper that was only reachable through it |
| T-2.7 | docs | C-003 | Regenerate `docs/test-cases.md`; update the badge |

**Done when:** the sweep in T-2.6 finds no new orphans, `luacheck` is clean, the suite is green at its
**new, lower** count, and `docs/test-cases.md` + the badge both show that number.

**Do not** add cases to hold the count at 726. The count going down is the point.

**Concurrency:** T-2.1 through T-2.5 touch disjoint file sets → **parallelizable**. T-2.6 **must
serialize after** all of them. T-2.7 is last.

**File-collision callout:** T-2.4 touches `modules/Insights.lua`, which no other task in any milestone
touches — safe. T-2.2 touches `core/Database.lua`, which **T-3.2 also touches** → see the critical-path
map.

---

## M3 — Stop paying for work that changes nothing

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-3.1 | lua-refactorer | C-004a | `modules/SessionWindow.lua:158` — early return on an empty session list |
| T-3.2 | lua-refactorer | C-004b | `core/Database.lua:620-636` — fire `LedgerChanged` only when `removed > 0`; correct the header comment at `:619` |
| T-3.3 | test-author | C-004 | `tests/test_database.lua` — the negative `PruneOld` case, **with** its `-- red under:` comment |
| T-3.4 | lua-refactorer | C-005b–f | `modules/Ledger.lua:713,743`; `settings/Panel.lua:39-42,62-67,78-80,119-120,172-173,469-477,547-549`; `settings/Schema.lua:124-125` |
| T-3.5 | docs | C-004 | Regenerate `docs/test-cases.md`; update the badge |

**Done when:** the C-004 smoke tests (`03_SMOKE_TESTS.md` C-004-1 through C-004-3) pass — in
particular **C-004-2**, which is the one that proves a real prune still reaches all four consumers.

**Concurrency:** T-3.1 and T-3.4 touch disjoint files → **parallelizable** with each other. T-3.2 and
T-3.3 both touch the `Database` surface and its suite → **serialize T-3.3 after T-3.2**.

---

## M4 — Verification

| Task | Owner role | Implements | Files touched |
|---|---|---|---|
| T-4.1 | qa | all | Run the full headless gate: `luacheck .` and `lua tests/run.lua`; confirm the inventory and badge agree with the run |
| T-4.2 | qa | all | Re-run `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` to a scratch path and confirm nothing crossed CCN 15. **Do not write it into the repo** — regeneration in place belongs to release |
| T-4.3 | qa (in-client) | all | Execute `03_SMOKE_TESTS.md` end to end and fill in the sign-off table |
| T-4.4 | docs | all | Complete `05_FINAL_SUMMARY.md` with the actual counts and the sign-off pointer |

**Done when:** the sign-off table in `03_SMOKE_TESTS.md` has a Pass in every row and `05_FINAL_SUMMARY.md`
records the real before/after pass counts.

---

## Critical path / concurrency map

```
M0 (upstream, LibKa0s repo)  ──── independent, does not block anything below ────┐
                                                                                 │
M1 ──► M2 ──► M3 ──► M4                                                          │
                                                                        T-0.3 re-vendor
                                                                        (own commit, any
                                                                         time after M0)
```

**Must serialize — shared files:**

| File | Tasks | Order |
|---|---|---|
| `core/Database.lua` | T-2.2 (delete `DeleteAt`), T-3.2 (`PruneOld` guard) | T-2.2 → T-3.2 |
| `tests/test_database.lua` | T-2.2 (drop `DeleteAt` cases), T-3.3 (add the `PruneOld` case) | T-2.2 → T-3.3 |
| `settings/Panel.lua` | T-1.1 (major + prose), T-3.4 (whitespace, dup comment, tooltip) | T-1.1 → T-3.4 |
| `docs/test-cases.md`, `README.md` | T-1.4, T-2.7, T-3.5 | one per milestone, in milestone order |

**Parallelizable (disjoint file sets):**

- T-1.1 ‖ T-1.3
- T-2.1 ‖ T-2.3 ‖ T-2.4 ‖ T-2.5 (T-2.2 is in this set too, but see the serialization table)
- T-3.1 ‖ T-3.4

---

## Checkpoints

| # | After | The human/coordinator verifies |
|---|---|---|
| CP-1 | T-1.2 | The new minor case was **actually mutated and watched go red**, then reverted from a `cp` backup — not `git checkout` (`testing-§12`). A green case nobody falsified is what this whole review flagged in the first place |
| CP-2 | End of M1 | The pass count moved by exactly +1, `docs/test-cases.md` and the badge agree, and the two vendor-sync names read correctly in the inventory |
| CP-3 | T-2.6 | The re-run dead-code sweep is clean **and** nothing user-facing was removed — hold M2 here until `03_SMOKE_TESTS.md` C-003 has been walked in-client |
| CP-4 | T-3.2, **before** committing | Re-grep every `Ka0s_BankLedger_LedgerChanged` registration (`modules/Browser.lua:1361`, `modules/Insights.lua:1021`, `modules/SessionWindow.lua:658`, `settings/Panel.lua:165,311`) and confirm each handler is a pure repaint of current state. This is C-004b's one real risk: a consumer relying on the message as a generic "recheck yourself" nudge would silently go stale |
| CP-5 | End of M3 | `03_SMOKE_TESTS.md` **C-004-2** passes — a real prune still reaches the table, the footer, Insights and the Storage section |
| CP-6 | Before T-0.3 | The LibKa0s tag exists, is released, and the README provenance line is bumped **in the same commit** as the folder copy |

---

## Incremental commit strategy

One commit per task, except where the table above forces a pairing. Suggested messages:

```
fix(panel): report the AceGUI-3.0 minor, not a field name          [F-001, F-005 / C-001, C-005a]
test(panel): assert the reported AceGUI minor, not just its shape  [F-001 / C-001]
test(vendor-sync): say in the case name when the sibling is absent [F-002 / C-002]
docs: regenerate test-cases.md and the tests badge                 [C-001, C-002]

refactor(compat): drop QualityFromLink, which has no callers       [F-003 / C-003]
refactor(database): drop DeleteAt; the row menu deletes by identity[F-003 / C-003]
refactor(filters): drop IsBlacklisted/IsWhitelisted                [F-003 / C-003]
refactor(insights): drop RankRows/BarFraction                      [F-003 / C-003]
docs: regenerate test-cases.md and the tests badge                 [C-003]

perf(session-window): do not walk the ledger with nothing to prune [F-004 / C-004a]
perf(database): PruneOld notifies only when it removed something   [F-004 / C-004b]
test(database): a no-op prune emits no LedgerChanged               [F-004 / C-004]
docs: correct the carve-out note, the Defaults tooltip and the
      GUILD_BANK context constant                                  [F-006..F-009 / C-005b-f]
docs: regenerate test-cases.md and the tests badge                 [C-004]
```

And, separately and alone, after M0:

```
chore(vendor): re-vendor tests/_kit from LibKa0s vX.Y.Z            [U-001]
```
