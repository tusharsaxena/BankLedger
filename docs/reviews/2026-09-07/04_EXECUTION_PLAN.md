# Execution plan — Ka0s Bank Ledger — 2026-09-07

Implements `02_PROPOSED_CHANGES.md`. Five milestones, ordered so the highest-value correctness fix
lands first and the evidence-only work never blocks it.

**Standing rule for every task:** no task may edit a path under `libs/` or `tests/_kit/`. M4 is the
only milestone that touches another repo, and it does so *in* that repo.

---

## Milestone M1 — the global reset announces itself

**Done when:** the Master controls ▸ Reset all settings button leaves the capture engine reading the
post-reset settings with no `/reload`, proved by two new headless cases that go red when the
broadcast is deleted, and `lua5.1 tests/run.lua` is green at the new total with
`docs/test-cases.md` and the README badge moved in the same commit.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M1-T1 | lua-refactorer | C-1 / `BANKLEDGER-R-01` | `settings/Slash.lua` |
| M1-T2 | test-author | C-1 regression pressure | `tests/test_panel.lua` (beside the existing reset block at `:709-747`) |
| M1-T3 | docs-sync | C-1 inventory movement | `docs/test-cases.md`, `README.md` |

**Sequencing inside M1:** M1-T2 **before** M1-T1 if you want the cases to be seen failing first —
which is the point of a `red under:` comment and is strongly preferred here, because the whole
finding is "a green suite over an unchecked path". M1-T3 strictly last: it is the generator's
output (`lua5.1 tests/run.lua --list > docs/test-cases.md`), never hand-typed.

---

## Milestone M2 — the migration seam becomes un-skippable

**Done when:** `schemaVersion` is absent from `NS.defaults.global`; `NS:RunMigrations` seeds it
itself and distinguishes a fresh store from a pre-stamp one; the test harness uses the kit's AceDB
fake so the stamp-less case can actually go red; suite green at the new total.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M2-T1 | test-harness | C-3 / `BANKLEDGER-R-03` | `tests/wow_mock.lua` |
| M2-T2 | — (triage) | fallout from M2-T1 | whichever `tests/test_*.lua` break under the faithful fake |
| M2-T3 | savedvariables-migrator | C-2 / `BANKLEDGER-R-02` | `defaults/Global.lua`, `core/Database.lua` |
| M2-T4 | test-author | C-2 regression pressure | `tests/test_database.lua` |
| M2-T5 | docs-sync | C-2/C-3 inventory movement | `docs/test-cases.md`, `README.md` |

**M2-T1 must precede M2-T3.** Swapping the mock first is what makes
`tests/test_database.lua:330` fail, and that failure is the proof the finding is real. Landing the
production fix first would turn a demonstrable bug into an unverifiable one.

**M2-T2 is expected work, not a surprise.** The naive fake has been in place for the whole life of
the suite; other cases may lean on its flat-table behaviour. Each break is information. **Fix the
case, never the assertion, and never re-fork the fake to make a case pass.** If the kit's fake is
genuinely missing something (e.g. it does not model AceDB's `PLAYER_LOGOUT` default strip), that is
a LibKa0s testkit item for M4 — express the strip inside the case for now.

---

## Milestone M3 — lifecycle and precision

**Done when:** a disable/enable round trip re-arms capture, proved headlessly and in-client (T-5);
the two misleading comments/guards are corrected; suite green.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M3-T1 | lua-refactorer | C-4 / `BANKLEDGER-R-04` | `core/BankLedger.lua` |
| M3-T2 | test-author | C-4 regression pressure | `tests/test_ledger.lua` |
| M3-T3 | comment-precision | C-6 / `BANKLEDGER-R-10` | `settings/OptionsSetup.lua` |
| M3-T4 | ux-cleanup | C-6 / `BANKLEDGER-R-07` | `settings/Schema.lua`, `tests/test_slash.lua` |
| M3-T5 | docs-sync | M3 inventory movement | `docs/test-cases.md`, `README.md` |

**M3-T1 carries one investigation** before it edits: `modules/Ledger.lua`'s `L._guildHooked` latch.
If the guild-bank hook survives an AceAddon disable, `_guildHooked` must **not** be cleared — a
double hook is worse than the deaf-on-re-enable bug. Establish this by reading
`L:HookGuildBankFrame` and record the answer in the commit message either way.

---

## Milestone M4 — upstream (lands in LibKa0s, not here)

**Done when:** the two LF working-tree files in the LibKa0s repo are renormalised and committed
*there*, and `diff -rq libs/LibKa0s/ ../LibKa0s/LibKa0s/` from this repo is clean. **Exit criterion
in this repo is either nothing at all** (expected — the stored blobs do not move, because the file
contents are byte-identical after CR stripping) **or, if the payload's stored bytes do move, a
re-vendor commit of the whole `libs/LibKa0s/` folder, on its own, touching no other path.**

| Task | Owner-agent | Implements | Repo / files touched |
|---|---|---|---|
| M4-T1 | cross-repo-handoff | U-1 / `BANKLEDGER-R-09` | **LibKa0s repo**: `git add --renormalize .` |
| M4-T2 | vendor-sync | U-1 exit criterion | this repo: re-run the two `diff -rq` commands; re-vendor **only if** blobs moved |
| M4-T3 | cross-repo-handoff | any testkit gap surfaced by M2-T2 | **LibKa0s repo**: `testkit/mock_base.lua` |

**No LibStub minor bump for M4-T1** — no file content changes. M4-T3, if it happens, does need one,
plus a re-vendor of `tests/_kit/` into every consumer as its own commit.

**M4 is independent of M1–M3** and can run at any time by a different person. It is listed fourth
only because it is the lowest-value item.

---

## Milestone M5 — the evidence catches up

**Done when:** `docs/performance.md`'s sweep table points at the file that actually holds the call
site, the line-ending stragglers are renormalised in an isolated commit, and no committed
measurement artifact has been hand-edited.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M5-T1 | docs-sync | C-5 / `BANKLEDGER-R-06` | `docs/performance.md` |
| M5-T2 | repo-hygiene | C-7 / `BANKLEDGER-R-08` | `tests/test_marks.lua`, `docs/media.md`, `docs/revendor/2026-08-25/{01_DELTA,05_SUMMARY}.md` |

**Explicitly NOT in M5:** regenerating or editing `docs/automated-tests/RESULTS.md`
(`BANKLEDGER-R-05`). Its checkpoint is release. M1–M3 will move the pass count and the NLOC; the
next `/wow-addon:bump-version` run regenerates the record and the narrative sections together. A
hand-corrected number in that file reads as measured and is worse than the stale one.

**Explicitly NOT in M5:** splitting `tests/test_ledger.lua` or `modules/Insights.lua`
(`BANKLEDGER-R-11`). Neither is over a threshold.

---

## Critical-path and concurrency map

```
M2-T1 ──► M2-T2 ──► M2-T3 ──► M2-T4 ──► M2-T5
M1-T2 ──► M1-T1 ──► M1-T3
M3-T1 ──► M3-T2 ─┐
M3-T3 ───────────┼─► M3-T5
M3-T4 ───────────┘
M4-T1 ──► M4-T2            (fully independent)
M5-T1, M5-T2               (fully independent)
```

**Must serialize — shared files:**

- `docs/test-cases.md` and `README.md` are touched by **M1-T3, M2-T5 and M3-T5**. These three cannot
  run concurrently, and each must be the *last* task of its milestone. The cleanest discipline is to
  regenerate the inventory once at the end of each milestone rather than per task.
- `tests/wow_mock.lua` (M2-T1) can invalidate results in **any** suite. Nothing in M1 or M3 that
  touches a `tests/test_*.lua` should be in flight while M2-T1 is landing. Practical ordering:
  finish M1 entirely, then M2, then M3.
- `settings/Slash.lua` (M1-T1) and `settings/Schema.lua` (M3-T4) are different files, but both are
  in the settings load chain. No conflict; no serialization needed.

**Parallelizable — disjoint file sets:**

- **M4** touches only the sibling LibKa0s repo (plus a read-only `diff` here). Run any time, by
  anyone.
- **M5-T1** (`docs/performance.md`) is disjoint from every other task.
- **M5-T2** must be its **own commit** and should be run when nothing else is in the working tree —
  a renormalisation mixed into a content diff is unreviewable.
- **M3-T3** (comment only, `settings/OptionsSetup.lua`) is disjoint from everything and can be done
  at any point.

---

## Checkpoints

| # | After | The human verifies |
|---|---|---|
| CP-1 | M1-T2, **before** M1-T1 | The two new cases are **red**. If they are green before the fix, they do not test the finding — stop and rewrite them. |
| CP-2 | M1 complete | Smoke tests **T-1** and **T-2** pass in-client. This is the milestone's real gate; the headless cases prove the broadcast fires, only the client proves the gate re-reads. |
| CP-3 | M2-T1 + M2-T2, **before** M2-T3 | `tests/test_database.lua:330` is **red** under the faithful AceDB fake, and every other break in M2-T2 was fixed in the *case*, not by weakening an assertion or re-forking the mock. |
| CP-4 | M2 complete | Smoke tests **T-3** and **T-4** pass. T-3 is the only check anywhere that exercises AceDB's real logout strip — do not skip it, and do not substitute a `/reload` for the full client exit. |
| CP-5 | M3 complete | Smoke test **T-5**, plus the `L._guildHooked` decision recorded in M3-T1's commit message. |
| CP-6 | Before any release tag | Full `03_SMOKE_TESTS.md` regression suite (R-1 … R-12) and the taint pair (X-1, X-2). Then `/wow-addon:bump-version`, which regenerates `docs/automated-tests/` and closes out `BANKLEDGER-R-05` as a side effect of measuring, not of editing. |

---

## Incremental commit strategy

One commit per task, except where a task's whole purpose is to move a generated file with its
change. Suggested boundaries and messages:

| Commit | Tasks | Message |
|---|---|---|
| 1 | M1-T2 | `test(reset): two cases that go red when the global reset stays silent` |
| 2 | M1-T1 + M1-T3 | `fix(reset): the wholesale reset announces itself on the bus` |
| 3 | M2-T1 + M2-T2 | `test(mock): wrap the kit's AceDB fake instead of replacing it` |
| 4 | M2-T4 | `test(migrate): pin the stamp-less store, empty and populated` |
| 5 | M2-T3 + M2-T5 | `fix(savedvariables): the schema stamp leaves the AceDB defaults` |
| 6 | M3-T1 + M3-T2 | `fix(lifecycle): OnDisable clears the enable latches` |
| 7 | M3-T3 + M3-T4 + M3-T5 | `docs(comments): two guards and one stub note stop overstating themselves` |
| 8 | M5-T1 | `docs(performance): the exemption sweep follows LoadItem to ItemSetup` |
| 9 | M5-T2 | `chore: renormalise four line-ending stragglers` |
| — | M4-T2 | only if blobs moved: `Re-vendor LibKa0s <tag>` — whole folder, nothing else |

Commits 2, 5 and 6 each move the test total; each therefore carries `docs/test-cases.md` and the
README `[Tests]` badge in the **same** commit (`testing-§7`). Commit 9 must contain nothing but
line-ending changes.
