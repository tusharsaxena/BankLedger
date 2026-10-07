# Execution plan: Ka0s Bank Ledger, 2026-10-07

All work is on `feat/2026-10-07-review-audit-remediation`. Green gate after every task: `lua tests/run.lua`, plus `luacheck .` at 0/0.

## M1: release-gate and behavior fixes (done when: the suite and luacheck are green, and the sighted complexity run in scratch shows 0 warnings)

| Task | Role | Implements | Files |
|---|---|---|---|
| BL-R1 | lua-refactorer | C-01 / F-001 | `modules/LedgerTable.lua`, `tests/test_ledgertable.lua`, `docs/test-cases.md`, `README.md` (badge) |
| BL-R2 | lua-refactorer | C-03 / F-003 | `modules/Browser.lua`, `tests/test_browser.lua`, `docs/test-cases.md`, `README.md` |
| BL-R3 | ux-cleanup | C-04 / F-004 | `modules/Browser.lua`, `tests/test_browser.lua`, `docs/test-cases.md`, `README.md` |

BL-R1 is parallelizable with BL-R2 and BL-R3 in code. All three touch `docs/test-cases.md` and the badge, so they must **serialize the inventory regeneration**. BL-R2 and BL-R3 both touch `modules/Browser.lua` and `tests/test_browser.lua`, so they **serialize** (R2 then R3).

**Checkpoint A:** the suite is green at 1262 passing, and the scratch complexity run shows max CCN ≤ 15.

## M2: the peel (done when: Browser.lua is under 1300 LOC, there is no behavior change, the suite is green with an unchanged count, and the docs are synced)

| Task | Role | Implements | Files |
|---|---|---|---|
| BL-R4 | lua-refactorer | C-02 / F-002 | `modules/Browser.lua`, new `modules/Browser_Views.lua`, `BankLedger.toc`, `docs/module-map.md`, `docs/ARCHITECTURE.md` |

It **must follow M1**, because it moves code that BL-R2 and BL-R3 edit. Run it as a pure move: the test count must not change.

**Checkpoint B:** green suite, luacheck at 0/0, and a re-run of the LOC census command.

## M3: docs (done when: no live doc says "the saved view" in the singular)

| Task | Role | Implements | Files |
|---|---|---|---|
| BL-R5 | doc-sync | C-05 / F-005 | `docs/ARCHITECTURE.md`, `docs/debug.md`, `docs/settings-panel.md`, `docs/slash-dispatch.md`, `docs/smoke-tests.md` |

`docs/ARCHITECTURE.md` is shared with BL-R4, so it **serializes after M2**.

## Not executed

F-006 (record only) and F-007 (regenerated at release).

## Commits

1. `fix(table): GroupEntries sort-key helper brings it back under CCN 15 (F-001)`
2. `fix(browser): one debounce owner for programmatic SetText; no double repaint on tab switch (F-003)`
3. `fix(search): trim the search clause the filter applies (F-004)`
4. `refactor(browser): peel per-tab view machinery into Browser_Views.lua (F-002)`
5. `docs: saved views are per tab (F-005)`

Each message ends with the session's attribution trailers. If this review runs inside a cross-repo plan, use that plan's `<ID>: ` subject prefixes instead.
