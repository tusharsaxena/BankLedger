# Ka0s Bank Ledger — Execution Plan (2026-07-27)

Implements `02_PROPOSED_CHANGES.md`. Every task is **test-first** (testing-§4: write the failing
test, then implement) and every milestone exits on the green gate — `lua tests/run.lua` all green
**and** `luacheck .` at 0/0 (anti-pattern #23).

---

## Milestone M0 — Ground truth for the money bug

**Done when:** `/bl debug scan` reports which money-balance readers this client exposes, and the
decision between C-001 (balance diff) and C-001b (narrow to guild bank) is recorded in the ticket.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M0-T1 | wow-api-migrator | C-001a (probe only) | `modules/Ledger.lua` (`L:Diagnose`) |
| M0-T2 | *human* | decision | — (records the outcome) |

**Parallelizable:** no — everything in M1 depends on the outcome.
**Checkpoint C0:** human runs `/bl debug scan` at a bank *and* a guild bank, pastes the `money API:`
line into the ticket, and picks C-001 or C-001b. **Do not start M1-T1 before this.**

---

## Milestone M1 — High-severity fixes

**Done when:** F-001, F-002, F-003 are fixed, their new tests pass, and the C-001/C-002/C-003
sections of `03_SMOKE_TESTS.md` pass in-client.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M1-T1 | lua-refactorer | C-001 (or C-001b) | `core/Compat.lua`, `modules/Ledger.lua`, `tests/test_ledger.lua`, `tests/test_compat.lua`, `docs/ARCHITECTURE.md` |
| M1-T2 | lua-refactorer | C-002 | `modules/LedgerTable.lua`, `modules/Browser.lua`, `tests/test_ledgertable.lua`, `tests/test_browser.lua` |
| M1-T3 | ux-cleanup | C-003 | `settings/Schema.lua`, `tests/test_schema.lua` |

**Concurrency map**
* M1-T1 ↔ M1-T2: disjoint (`Ledger`/`Compat` vs `LedgerTable`/`Browser`) → **parallelizable**.
* M1-T2 ↔ M1-T3: disjoint → **parallelizable**.
* M1-T2 touches `modules/Browser.lua`, which **M3-T1 (C-005), M3-T2 (C-006) and M4-T3 (C-010, C-011,
  C-012)** also touch → those must **serialize** behind M1-T2. This is the plan's main contention
  point; `Browser.lua` is touched by four tasks in total.

**Checkpoint C1:** human runs the C-001, C-002 and C-003 smoke sections plus regression R-1, R-2 and
R-5 before M2 starts. C-001 changes the capture invariant — do not stack further work on an
unverified capture engine.

---

## Milestone M2 — Capture-gate correctness

**Done when:** F-006 is fixed with a covering test, and the C-008 smoke section passes at both
`qualityThreshold = 0` (behaviour unchanged) and `= 3` (sub-threshold uncached item skipped).

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M2-T1 | lua-refactorer | C-008 | `modules/Ledger.lua`, `tests/test_ledger.lua` |

**Concurrency map:** M2-T1 touches `modules/Ledger.lua`, shared with M1-T1 and M5-T1 (C-009) →
**must serialize** after M1-T1 and before/after M5-T1, never concurrent.

**Checkpoint C2:** verify the threshold-0 default path is byte-for-byte unchanged in behaviour —
this is the case that governs every existing user, and it must not regress.

---

## Milestone M3 — Performance

**Done when:** the three perf spot-checks in `03_SMOKE_TESTS.md` show improvement and no functional
regression in R-10…R-14.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M3-T1 | perf-tuning | C-005 | `modules/Browser.lua`, `tests/test_browser.lua` |
| M3-T2 | perf-tuning | C-006 | `modules/Browser.lua`, `modules/Insights.lua`, `tests/test_browser.lua` |
| M3-T3 | perf-tuning | C-007 | `settings/Panel.lua` |

**Concurrency map**
* M3-T1 ↔ M3-T2: **both touch `modules/Browser.lua` → must serialize** (T1 then T2; T2's scheduler
  can reuse T1's timer idiom).
* M3-T3 is disjoint (`settings/Panel.lua`) → **parallelizable** with either, but note M4-T2 (C-011)
  also touches `Panel.lua` → serialize those two.

**Checkpoint C3:** human confirms dropdown selections still feel **instant** after the debounce
lands. A debounce applied too broadly is a worse UX than the perf problem it solves.

---

## Milestone M4 — Design and correctness cleanup

**Done when:** F-010, F-011, F-013 fixed; no behaviour change observable except the new `[Panel]`
debug lines.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M4-T1 | lua-refactorer | C-010 | `modules/Browser.lua`, `tests/test_browser.lua` |
| M4-T2 | lua-refactorer | C-011 (Panel half) | `settings/Panel.lua` |
| M4-T3 | lua-refactorer | C-011 (Browser half) | `modules/Browser.lua` |

**Concurrency map:** M4-T1 and M4-T3 both touch `modules/Browser.lua` → **serialize**, and both
behind M3-T2. M4-T2 is disjoint from both but shares `Panel.lua` with M3-T3 → **serialize** those.
Practical simplification: fold M4-T1 and M4-T3 into a single `Browser.lua` commit.

---

## Milestone M5 — Naming, conventions, docs

**Done when:** F-007, F-008, F-012, F-014, F-015, F-016, F-017, F-019 are closed and the full
regression suite passes.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M5-T1 | lua-refactorer | C-009 | `core/Constants.lua`, `core/State.lua`, `modules/Ledger.lua`, `tests/test_constants.lua` |
| M5-T2 | ux-cleanup | C-004 | `settings/Slash.lua`, `settings/Schema.lua`, `tests/test_slash.lua`, `tests/test_schema.lua` |
| M5-T3 | lua-refactorer | C-012 (code half) | `defaults/Global.lua`, `core/Namespace.lua`, `settings/Slash.lua`, `modules/Browser.lua`, `modules/LedgerTable.lua`, `tests/test_database.lua` |
| M5-T4 | docs | C-012 (README half) | `README.md` |

**Concurrency map**
* M5-T1 touches `modules/Ledger.lua` → **serialize** behind M2-T1.
* M5-T2 and M5-T3 both touch `settings/Slash.lua` → **serialize**.
* M5-T3 touches `modules/Browser.lua` and `modules/LedgerTable.lua` → **serialize** behind M4-T3 and
  M1-T2.
* M5-T4 (`README.md`) is disjoint from everything → **fully parallelizable**, may run any time after
  M5-T2 fixes the command order in code.

**Checkpoint C5:** full regression suite R-1…R-14 plus a fresh-SavedVariables login, since M5-T3
changes the shipped `schemaVersion` default.

---

## Milestone M6 — Documentation reconciliation

**Done when:** `docs/ARCHITECTURE.md` reflects the shipped behaviour and `05_FINAL_SUMMARY.md` is
completed from the filled-in smoke-test sign-off.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M6-T1 | docs | C-001 / C-008 doc ripple | `docs/ARCHITECTURE.md` (message table, Known limitations, capture-gate description) |
| M6-T2 | docs | final summary | `docs/reviews/2026-07-27/05_FINAL_SUMMARY.md` |

**Checkpoint C6:** confirm the `Ka0s_BankLedger_SettingsChanged` consumer list in
`docs/ARCHITECTURE.md:155` now includes the `windowScale` reason string (C-003), and that any money
narrowing from C-001b appears under Known limitations.

---

## Critical path

```
M0-T1 → [C0 human decision] → M1-T1 ─┐
                              M1-T2 ─┼→ [C1] → M2-T1 → [C2] → M3-T1 → M3-T2 → [C3]
                              M1-T3 ─┘                                          │
                                                                                ▼
                                                     M4-T1+T3 → M4-T2 → M5-T1 → M5-T2 → M5-T3 → [C5]
                                                                                              │
                                                                                              ▼
                                                                                   M6-T1 → M6-T2 → [C6]
```

**File contention summary (must serialize):**

| File | Tasks |
|---|---|
| `modules/Browser.lua` | M1-T2, M3-T1, M3-T2, M4-T1, M4-T3, M5-T3 |
| `modules/Ledger.lua` | M0-T1, M1-T1, M2-T1, M5-T1 |
| `settings/Panel.lua` | M3-T3, M4-T2 |
| `settings/Slash.lua` | M5-T2, M5-T3 |
| `settings/Schema.lua` | M1-T3, M5-T2 |

**Fully parallelizable at any point:** M5-T4 (`README.md`).

---

## Incremental commit strategy

One commit per task (or per fused task where the plan folds them), each landing on green
(versioning-git, anti-pattern #23). Suggested messages:

```
fix(ledger): corroborate money movements against the store's own balance   # M1-T1, F-001
fix(table): make test mode read-only for delete and filter actions          # M1-T2, F-002 F-009
fix(settings): broadcast windowScale on the bus so both windows rescale     # M1-T3, F-003
fix(ledger): don't let an uncached item bypass the quality gate             # M2-T1, F-006
perf(browser): debounce filter application and coalesce entry refreshes     # M3-T1+T2, F-004 F-005
perf(options): skip the storage recompute while the panel is hidden         # M3-T3, F-018
refactor(browser): copy the filter to the table; drop the shared-bus fallback # M4-T1+T3, F-013 F-010
fix(options): surface refresher/rebuilder failures on the debug console     # M4-T2, F-011
refactor(core): name the open-frame token C.Context                         # M5-T1, F-012
fix(slash): correct the /bl list group order; add the missing tooltip       # M5-T2, F-007 F-019
chore: schema default v2, single version source, drop dead code             # M5-T3, F-008 F-014 F-015 F-017
docs: sync README commands and ARCHITECTURE for the capture changes         # M5-T4 + M6-T1, F-016
```

**Do not** bump `## Version` or `NS.version` as part of this work — versioning-git requires an
explicit instruction to bump, and the README's `## What's new` section must be rolled forward in the
same change as any bump (anti-pattern #40). Raise the bump as a separate, explicitly-requested step.
