# Final summary: Ka0s Bank Ledger, 2026-09-23 review-and-fix cycle

*This summary is written as though every item in `03_SMOKE_TESTS.md` has passed. Until the sign-off table is filled in, it describes the intended outcome.*

## Headline

This cycle closes two gaps in how Bank Ledger turns itself off and back on.

The first gap: switching the addon off while standing at a bank used to leave its "a bank is open" state behind. Turning it back on then recorded, as if they had happened while it was running, the deposits and withdrawals the player had just made with it off. It could also leave the addon rescanning the bank on every bag update for the rest of the session.

The second gap: pressing **Reset all settings** while the addon was off left it off in practice, even though every surface said it was on.

The cycle also makes that reset refresh every open view of the (now empty) ledger, discloses the 30-day default history window in the README, and tidies four smaller items: an allocation, a brand-name spelling, a prune that could skip a session, and rotted line citations. Nothing changed in the vendored library.

## Counts

- **Critical fixed:** 0 (none found)
- **High fixed:** 2 (F-001, F-002)
- **Medium fixed:** 2 (F-003, F-004)
- **Low fixed:** 5 (F-005, F-006, F-007, F-009, F-010)
- **Deferred by design:** F-008, the watch-list movement. It is confirmed by the next release's `RESULTS.md` regeneration, not fixed here.

## Changes by theme

### T1: The stand-down owns the capture context

- **What changed:** Turning Bank Ledger off now also forgets the open bank visit: its baseline snapshot, its settle deadline and the live session window's list. Turning it back on never compares against a snapshot taken before it was off.
- **Why it mattered:** The history could gain rows for movements made while the addon was disabled. The addon could also keep scanning the bank on every bag update, in combat included, for the rest of the session. That is the exact condition the addon's no-combat-path performance exemption rests on not happening.
- **Findings / changes:** F-001 / C-01.
- **Files:**
  - `modules/Ledger.lua`
  - `core/BankLedger.lua`
  - `tests/test_disabled.lua`
  - `docs/ARCHITECTURE.md`
  - `docs/test-cases.md`
  - `README.md` (badge)

### T2: The global reset is a fresh install

- **What changed:** **Reset all settings** now brings a disabled addon back up, because a fresh install is enabled. It also announces the emptied ledger, so the History table, the Insights charts, the session window and the storage read-out all refresh at once.
- **Why it mattered:** The checkbox said "enabled" while capture was off until `/reload`, and open windows kept showing rows that no longer existed.
- **Findings / changes:** F-002, F-003 / C-02.
- **Files:**
  - `settings/Slash.lua`
  - `tests/test_panel.lua`
  - `docs/test-cases.md`
  - `README.md` (badge)

### T3: Documentation matches the code

- **What changed:**
  - The README says how long history is kept by default and where to change it.
  - The visibility pass no longer allocates, so the performance page's "no allocation" is now true.
  - Architecture citations name symbols instead of line numbers.
  - The brand name has one spelling.
- **Why it mattered:** Players were losing month-old history without being told. The exemption's evidence page asserted something false about the code, and six citations pointed at the wrong lines.
- **Findings / changes:** F-004, F-006, F-007, F-010 / C-03, C-04, C-05, C-06.
- **Files:**
  - `README.md`
  - `core/Util.lua`
  - `docs/ARCHITECTURE.md`
  - `core/Database.lua` (comment)
  - `core/LauncherSetup.lua`
  - `settings/OptionsSetup.lua`
  - *(if the owner chose it)* `defaults/Global.lua` and `settings/Schema.lua`

### T4: Small correctness items

- **What changed:**
  - The once-per-session retention prune now postpones across a stand-down instead of skipping the session.
  - The guild-bank open/close registrations match what the 12.1 client actually fires. The result is recorded in `03_SMOKE_TESTS.md` C-08.
- **Findings / changes:** F-005, F-009 / C-07, C-08.
- **Files:**
  - `core/BankLedger.lua`
  - `core/State.lua`
  - `modules/Ledger.lua`
  - `docs/performance.md` (sweep row)
  - `docs/ARCHITECTURE.md` (registration count)
  - a test file

## API / behavior changes

- **Reset all settings, confirmed while the addon is disabled, now re-enables it.** This is a behavior change. It matches the confirm text ("Reset this addon to its defaults").
- **Disabling while at a bank ends the banking session** (the session window closes and its list clears). Re-enabling at the same visit does not re-arm capture until the next bank open.
- **Reset all settings now broadcasts `Ka0s_BankLedger_LedgerChanged` once**, in addition to `Ka0s_BankLedger_SettingsChanged "reset"`.
- **No slash verbs were added, renamed or removed.** No locale keys changed; the addon is English-only by its registered deviation.
- *(Owner-dependent)* The default retention window changes from 30 days to Always, if chosen at CP2.

## SavedVariables / migration notes

**No schema bump.** `NS.SCHEMA_VERSION` stays 2.

If the retention default changes to 0, no migration is needed. AceDB stores nothing for a value equal to its default, so players who never touched the dropdown move to the new default, which keeps more data. Players who set a value keep it.

`NS.State.cleanupPending` is session-only and never persisted.

## Deprecated-API migrations

| Old | New | Files |
|---|---|---|
| `GUILDBANKFRAME_OPENED` / `GUILDBANKFRAME_CLOSED` (registered, never fire) | `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` / `_HIDE` filtered on `Enum.PlayerInteractionType.GuildBanker`, **or** removal, depending on the C-08 client result | `modules/Ledger.lua` |

## Performance impact

This section is left empty on purpose. The addon holds a `performance-§12` exemption and ships no `tests/perf.lua` and no in-game captures, so no before/after numbers exist to report. C-04 removes one small table allocation per combat edge, which is a correctness-of-evidence fix and not a measured gain. C-01 removes a *potential* unbounded rescan-per-bag-event state rather than a measured cost.

## Test and complexity movement

- **Pass count:** 1017 → **1022** (+2 from C-01, +2 from C-02, +1 from C-07). `docs/test-cases.md` and the README `[tests]` badge moved in each commit that moved the count.
- **Watch list (confirm at the next release regeneration, do not regenerate now):**
  - `modules/Insights.lua` (1002 LOC) appears as a new 1000–1500 band row needing a disposition.
  - `modules/Browser.lua` (1220) stays under `BL-24`.
  - C-01 adds about 10 lines to `modules/Ledger.lua` (890 today), and C-07 adds a few to `core/BankLedger.lua`. Neither crosses a band.
  - No function is expected to cross CCN 15.

## Known follow-ups

- **Re-arm capture on a re-enable at an open bank.** This is deliberately left out. It needs a reliable per-context "frame is shown" probe, and the conservative behavior (unarmed until the next open) is safe.
- **The `modules/Insights.lua` band disposition.** The owner rules on it at the next release. The natural peel seam is the section renderers inside `I:Layout`.
- **F-008.** It is recorded evidence only and is resolved by the release run.

## Verification evidence

- Completed `docs/reviews/2026-09-23/03_SMOKE_TESTS.md` sign-off table.
- Commit range on `feat/2026-09-23-review-audit-remediation`, commits 1–8 per `04_EXECUTION_PLAN.md`.
- Headless gate: `lua5.1 tests/run.lua` → 1022/1022, and `luacheck .` → 0/0.

## Suggested commit / PR description

```
BankLedger: stand-down and reset correctness, plus doc/hygiene fixes (review 2026-09-23)

- Disabling at a bank now drops the capture context, so re-enabling never records
  movements made while the addon was off, and never leaves a bank scan armed on bag
  events (F-001).
- Reset all settings re-runs the enable latch and announces the emptied ledger, so a
  reset made while disabled comes back running and every open view refreshes (F-002, F-003).
- README discloses the default 30-day history window (F-004).
- Visibility pass no longer allocates per combat edge; brand name spelled once; retention
  prune postpones across a stand-down; guild-bank open/close events verified in client;
  architecture citations name symbols instead of line numbers (F-005, F-006, F-007, F-009, F-010).

Tests 1017 -> 1022; docs/test-cases.md and the README badge move with the count.
No SavedVariables schema change. No change under libs/ or tests/_kit/.
```
