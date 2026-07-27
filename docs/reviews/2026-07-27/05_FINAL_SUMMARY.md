# Ka0s Bank Ledger — Review Cycle Final Summary (2026-07-27)

> **Status: implemented, pending in-client verification.** All 19 findings are closed in code on
> branch `review/2026-07-27`, and the headless gate is green. The in-client smoke tests in
> `03_SMOKE_TESTS.md` have **not** been run yet — see *Verification evidence* for exactly what is
> and is not proven.

---

## Headline

This cycle hardened Bank Ledger's capture engine and closed the gaps where the addon's *write* paths
had drifted away from its (very careful) *read* paths. The headline fix is that gold movements are
now corroborated against the bank's own balance instead of the player's purse, so buying a bank tab
at the bank window no longer writes a phantom "10,000g deposited to the Warband Bank" row into your
permanent history. Alongside it, the `/bl test` sample dataset became a genuine read-only sandbox
(it could previously write synthetic item ids into your real capture filters), the Window scale
slider now resizes both windows instead of one, and the search box no longer recomputes the entire
Insights aggregation on every keystroke. The rest is cleanup: a stale defaults version, a duplicated
version string, a comment describing a backfill that never existed, and a dead function.

---

## Counts

* **Critical fixed:** 0 *(none were found)*
* **High fixed:** 3 — F-001, F-002, F-003
* **Medium fixed:** 10 — F-004, F-005, F-006, F-007, F-008, F-009, F-010, F-011, F-012, F-013
* **Low fixed:** 6 — F-014, F-015, F-016, F-017, F-018, F-019

**Deferred:** none. Every finding in `01_FINDINGS.md` is closed in code.

**C-001b was not needed.** The probe found a working warband balance reader, so the full
balance-diff (C-001) was taken and warband gold capture is **fixed, not withdrawn**.

---

## What the M0 probe actually found

The plan opened on an investigation milestone because no one knew whether this client exposed a
warband balance reader. A live `/bl debug scan` at a bank **and** at a guild bank on 12.0.7 returned:

```
money API: purse=function guildBank=function bankFetch=function bankTypes=true
  Enum.BankType: Account=2, Character=0, Guild=1
  GetGuildBankMoney():                     0            (at the bank)  /  65537936844 (at the guild bank)
  C_Bank.FetchDepositedMoney(Account):     16348260386  (identical in both sessions)
  C_Bank.FetchDepositedMoney(Character):   0
```

Two things follow, and only the first was anticipated:

1. **`C_Bank.FetchDepositedMoney(Enum.BankType.Account)` exists and is not frame-bound.** It read
   the same figure at the bank and at the guild bank, so the warband balance is available whenever
   capture needs it. C-001 proper was taken.
2. **`GetGuildBankMoney()` returns `0`, not `nil`, when the guild bank frame is closed.** This was
   not in the design. Had the shim passed that `0` through as a balance, the first pass after
   opening the guild bank would have seen the balance "rise" from 0 to 65537936844 and — given a
   purse movement in the same pass — could have recorded a fabricated withdrawal. The guild read is
   therefore gated on `Compat.IsGuildBankVisible()` and returns `nil` when the frame is down. The
   test mock reproduces the `0` deliberately, so a future refactor that drops the gate fails.

---

## Changes by theme

### T1 — Money capture is evidence-driven

**What changed.** A gold movement is now only recorded when the **store's own** coin balance moves in
the opposite direction to your purse. The amount recorded is the smaller of the two deltas, so a
repair and a deposit in the same pass records only what the store provably received. A purchase, a
repair or a mail COD that happens to land while the bank window is open produces no ledger row, and
a store whose balance cannot be read contributes nothing at all.

**Why it mattered.** The purse-only diff had no corroboration: `BANK_FRAME` reaches the warband
bank, so *any* gold you spent at a bank was persisted as a warband deposit. Those rows were
indistinguishable from real ones afterwards, and they skewed `Gold deposited`, `Net gold`,
`Gold By Store` and the CSV export.

**Cost check.** Corroboration can only *remove* rows, so the risk it introduces is losing a real
one when the store's balance lands a pass later than the purse. The existing settle machinery
already covers that — it holds the baseline until both sides balance — and a reconcile-level test
now pins it.

**Findings covered:** F-001 · **Changes:** C-001
**Files touched:** `core/Compat.lua`, `modules/Ledger.lua`, `.luacheckrc`, `docs/ARCHITECTURE.md`,
`tests/test_ledger.lua`, `tests/test_compat.lua`, `tests/wow_mock.lua`

### T2 — Test mode is a read-only sandbox

**What changed.** `/bl test` now derives its state from one stored fact, and the History table's
right-click menu greys out **Delete**, **Blacklist item** and **Whitelist item** while the sample
dataset is on screen. "Link to chat" stays available. The menu entries were extracted to
`LT:RowMenuItems` as plain data, so the enable rules are unit-testable without frames.

**Why it mattered.** The sample rows carry synthetic item ids (190001–190030). Blacklisting one
wrote that id into the real, persisted capture filter; Delete matched nothing in real storage, did
nothing visible, and still fired a ledger-changed broadcast. A user exploring the demo could
silently corrupt their own configuration.

**Findings covered:** F-002, F-009, F-015 · **Changes:** C-002
**Files touched:** `modules/LedgerTable.lua`, `modules/Browser.lua`, `tests/test_ledgertable.lua`,
`tests/test_browser.lua`

### T3 — Settings propagate to everything that consumes them

**What changed.** The Window scale row now broadcasts `Ka0s_BankLedger_SettingsChanged` like every
other row, so the session window rescales live. `/bl list` prints its groups in the schema's declared
order (Master Controls, then Capture) instead of an order derived from a constant naming a group
that no longer exists. The per-store capture grid gained the tooltip every other row already had.

**Why it mattered.** One setting applying to one of two windows reads as a bug, and a "declared page
order" that isn't the order in force is the kind of drift that only gets worse.

**Note on the test that agreed with the bug.** `LIST_GROUP_ORDER` was covered by a test that
asserted "Capture" comes first — the same literal the buggy constant named. It passed while the
ordering mechanism matched nothing and the listing silently fell through to first-seen order. It now
asserts against `NS.Schema.Schema[1].group`, and a second test asserts every name in the constant
resolves to a real group.

**Findings covered:** F-003, F-007, F-019 · **Changes:** C-003, C-004
**Files touched:** `settings/Schema.lua`, `settings/Slash.lua`, `tests/test_schema.lua`,
`tests/test_slash.lua`

### T4 — Refreshes are coalesced

**What changed.** Search-box input is debounced at 0.20s (dropdown selections stay instant); the
per-entry `EntryAdded` refresh is collapsed to one repaint per burst in both Browser and Insights,
so a 20-stack deposit costs one repaint instead of twenty; and the settings panel no longer walks
the whole ledger to estimate storage size while it is hidden. Both schedulers fall back to running
inline when no timer library is present, so nothing is silently dropped headlessly.

**Why it mattered.** All three paths did O(n) work far more often than the data changed — worst at
exactly the moments the user is interacting (typing a search, emptying bags at the bank).

**Findings covered:** F-004, F-005, F-018 · **Changes:** C-005, C-006, C-007
**Files touched:** `modules/Browser.lua`, `modules/Insights.lua`, `settings/Panel.lua`,
`tests/test_browser.lua`

### T5 — The code and its comments agree again

**What changed.** The quality gate no longer lets an uncached item through a threshold the user set,
and the comment promising a name backfill that never existed was corrected. The shipped
`schemaVersion` default and the migration runner's target now both read one `NS.SCHEMA_VERSION`
constant. The open-frame token got its own `C.Context` enum instead of borrowing `C.Store` values,
whose own comment promises they are the stored export keys. The version string has one resolution
path for both `/bl version` and `/bl help`. A dead exported function was removed, `LedgerTable`
picked up the file-local print alias the other emitting files use, and the README's command table
matches `NS.COMMANDS`.

**Why it mattered.** This addon's comments are unusually load-bearing — they encode hard-won
knowledge about the client's container model. Every comment that turns out to be false costs the
next reader their trust in all of them.

**Findings covered:** F-006, F-008, F-012, F-014, F-016, F-017 · **Changes:** C-008, C-009, C-012
**Files touched:** `modules/Ledger.lua`, `defaults/Global.lua`, `core/Constants.lua`,
`core/State.lua`, `core/Namespace.lua`, `core/Database.lua`, `modules/Browser.lua`,
`settings/Slash.lua`, `README.md`, `tests/test_constants.lua`, `tests/test_database.lua`

### T6 — The settings panel is debuggable

**What changed.** The three `pcall` sites that swallowed widget errors now route through one
`safeRun` helper that keeps the isolation and reports the failure to the on-screen debug console
under a `[Panel]` tag, naming which refresher or rebuilder failed. The Browser's bus-target fallback
— which was unreachable and would have registered on the shared bus if it ever ran — was removed in
favour of the early return its sibling modules already use, with the window, tabs and minimap set up
before it so only live refresh goes inert.

**Why it mattered.** A refresher that starts failing used to stop updating forever, silently, with
nothing in chat, the console or a test. And the "safety" fallback would have caused precisely the
receiver-clobber it was written to avoid.

**Findings covered:** F-010, F-011, F-013 · **Changes:** C-010, C-011
**Files touched:** `settings/Panel.lua`, `modules/Browser.lua`, `tests/test_browser.lua`

---

## API / behaviour changes

| Change | Detail |
|---|---|
| Slash commands | **No new, renamed or removed verbs.** `/bl list` group **order** changed (Master Controls now first). |
| Chat output | New `[Skip] … (uncached)` console reason; new `[Panel] … failed` console lines when a settings widget errors; new `money API:` lines in `/bl debug scan`. Format, colours and the cyan `[BL]` tag unchanged. |
| Capture behaviour | Gold rows now require store-balance corroboration (**fewer** rows recorded; the ones removed were false). Items below a **non-zero** minimum quality that the client has not cached are now skipped rather than recorded. At the default `qualityThreshold = 0` item capture is unchanged. |
| Settings | `settings.windowScale` now also broadcasts on the bus. New tooltip on `settings.excludedStores`. No new, renamed or removed settings. |
| Defaults | `schemaVersion` default `1` → `2`. No other default changed. |
| Locale keys | None added, renamed or removed — v0.1.0 still ships English-only through the `NS.L` fallback seam. |
| Export | CSV columns unchanged; the contract is untouched. |
| New API | `Compat.GetStoreMoney(store)`, `LT:IsTestMode()`, `LT:RowMenuItems(entry)`, `B:ApplyFilterNow()`, `B:ScheduleApplyFilter()`, `B:ScheduleLedgerRefresh()`, `I:ScheduleRefresh()`, `Sl:Version()`, `C.Context`, `NS.SCHEMA_VERSION`. |
| Removed API | `B:Unavailable()` (zero callers), `LT.testMode` (replaced by `LT:IsTestMode()`). |

---

## SavedVariables / migration notes

**No schema bump.** The entry shape is unchanged, so `NS:RunMigrations` keeps its existing v1 → v2
step and existing databases need nothing.

The only SavedVariables-facing edit is the **default** `schemaVersion`, raised from `1` to `2` to
match the migration runner's target — both now read `NS.SCHEMA_VERSION`:

* **Existing profiles** — unaffected. They already carry an explicit `schemaVersion`, and AceDB only
  applies a default where a key is absent.
* **Fresh installs** — start at `2` and no longer replay the v1→v2 pass over an empty ledger.
* **No `/bl reset` or `resetall` is required** by any change in this cycle, and no user data is
  discarded. Phantom gold rows already written before C-001 are **not** retroactively removed — the
  addon cannot distinguish them after the fact. Users who care can delete them from the History
  table's right-click menu, or filter to Gold + Warband Bank and review. This is now recorded under
  *Known limitations* in `docs/ARCHITECTURE.md`.

---

## Deprecated-API migrations

None. The addon was already clean: a grep for `GetItemInfo`, `GetContainerItemInfo`,
`GetContainerNumSlots`, `IsAddOnLoaded`, `UnitAura*`, `GetSpellInfo` and `InterfaceOptions_*` outside
`core/Compat.lua` returns nothing, and there is no `WOW_PROJECT_ID` branching.

This cycle **added** one Compat shim rather than migrating one:

| New shim | Wraps | Files |
|---|---|---|
| `Compat.GetStoreMoney(store)` | `GetGuildBankMoney` (gated on `IsGuildBankVisible`) / `C_Bank.FetchDepositedMoney(Enum.BankType.Account)` | `core/Compat.lua`, called from `modules/Ledger.lua` |

`GetGuildBankMoney` and `C_Bank` were added to `.luacheckrc` `read_globals`.

---

## Performance impact

**Not measured in-client.** The three spot-checks in `03_SMOKE_TESTS.md` require a running client
and have not been run. What is proven headlessly is the change in *call counts*, which is where the
saving comes from:

| Scenario | Before | After | Evidence |
|---|---|---|---|
| Five-character search on Insights | 5 × (`Database:Query` + `Database:Stats`) | 1 | `tests/test_browser.lua` — "a burst of search keystrokes costs ONE filter application" |
| 20-stack deposit with the window open | 20 × `OnLedgerChanged` | 1 | `tests/test_browser.lua` — "a 20-stack deposit repaints the window once" |
| Settings refresh while the panel is hidden | full ledger walk | none | `settings/Panel.lua` visibility guard (pure guard, no test required) |

The measured `collectgarbage("count")` and `GetAddOnCPUUsage` figures should be filled in here after
the smoke run.

---

## Known follow-ups

* **`modules/Browser.lua` is the next split candidate** (~1150 LOC — under the 1500 ceiling, but it
  now owns the window chrome, the tabs, the whole filter bar, the dropdown widget factory, the
  minimap launcher and the export routing). Deferred: a split is a large mechanical change with no
  user-visible benefit, and it would have serialized against six tasks in this cycle.
* **Localization pass.** Every user-facing string is still hardcoded English behind an unused `NS.L`
  seam. Deferred as an accepted v0.1.0 scope decision, already documented in `locales/enUS.lua`.
* **Retroactive cleanup of pre-C-001 phantom gold rows.** Deferred: unresolvable — nothing in a
  stored row distinguishes a real warband deposit from a bank-tab purchase recorded as one.
* **Store-to-store transfers** remain uncaptured (already in `docs/ARCHITECTURE.md` ▸ Known
  limitations). Unchanged by this cycle.
* **Incremental `Database:Stats`.** The debounce (C-005) flattens the current problem; a streaming
  aggregate would be the real fix if ledgers routinely reach tens of thousands of rows. Deferred as
  premature — it would fork the aggregation into two implementations that must agree.
* **`minimap.hide` and `settings.retentionDays` still call their consumers directly** rather than
  broadcasting, the same shape as the F-003 defect. Not flagged in this review because each has
  exactly one consumer today, so nothing is currently missed — but the next consumer added to either
  reproduces F-003 exactly.

---

## Verification evidence

**Proven:**

* **Headless gate:** `lua tests/run.lua` → **567 passed, 0 failed**. `luacheck .` → **0 warnings /
  0 errors in 22 files**. Run green after every one of the eleven commits.
* **Test coverage added this cycle:** 36 new tests, including the F-001 regression end-to-end
  (gold spent at the bank window writes no row), the lag case it could have broken (a real deposit
  whose store balance lands a pass later is still recorded), and drift guards on `LIST_GROUP_ORDER`,
  schema-row tooltips, the schema-version default and the version resolution path.
* **The M0 probe** was run on a live 12.0.7 client at both a bank and a guild bank; its output is
  reproduced above and drove two implementation decisions.

**Not yet proven — requires a client:**

* Every section of `03_SMOKE_TESTS.md`, including checkpoints **C1** (the capture invariant after
  C-001), **C2** (threshold-0 behaviour unchanged), **C3** (dropdowns still feel instant after the
  debounce), and **C5** (a fresh-SavedVariables login on the new `schemaVersion` default).
* The three performance spot-checks above.
* That a real gold deposit into the warband bank is still captured in-client. The headless test
  proves the logic; only the client proves the timing of `C_Bank.FetchDepositedMoney` relative to
  `PLAYER_MONEY`. **This is the single highest-value smoke test in the set** — it is the case where
  C-001 could cost a real row rather than remove a false one.

**Commit range:** `8c8e18e`..`a6d566d` on branch `review/2026-07-27` (11 commits, one per plan
task). Not merged to `main`; no PR raised.

---

## Suggested PR description

```
fix: correct gold attribution, make test mode read-only, and coalesce view refreshes

Review cycle docs/reviews/2026-07-27 — 19 findings, 0 critical, 3 high.

High
- F-001 a money change during any bank visit was recorded as a Warband Bank
  deposit; gold movements are now corroborated against the store's own balance,
  the same "both sides must change" rule item capture has always used.
- F-002 the /bl test sample dataset's row menu wrote synthetic item ids into the
  real capture filters and offered a Delete that did nothing; mutating actions
  are now disabled in test mode.
- F-003 the Window scale setting never reached the session window; it now
  broadcasts on the bus like every other schema row.

Medium
- F-004/F-005/F-018 debounce search input, coalesce per-entry refreshes, and skip
  the storage recompute while the options panel is hidden.
- F-006 an uncached item no longer bypasses a non-zero minimum-quality threshold.
- F-007 /bl list group order named a group that no longer exists — and the test
  covering it named the same non-existent group, so it passed.
- F-008 the shipped schemaVersion default was one behind the migration target.
- F-009/F-012/F-013 single source of truth for test mode; C.Context enum for the
  open-frame token; the table gets a filter copy rather than a live reference.
- F-010/F-011 settings-panel failures now reach the debug console; the Browser's
  unreachable shared-bus fallback removed.

Low
- F-014 drop dead NS.Browser:Unavailable; F-015 use the file-local print alias;
  F-016 README command table resynced; F-017 one version resolution path;
  F-019 tooltip added to the per-store capture grid.

No schema bump; no user data discarded; no slash verb added, renamed or removed.
Conforms to the Ka0s WoW Addon Standard v2.11.0.

Tests: lua tests/run.lua 567 passed 0 failed, luacheck . 0/0.
In-client smoke tests (03_SMOKE_TESTS.md) not yet run.
```
