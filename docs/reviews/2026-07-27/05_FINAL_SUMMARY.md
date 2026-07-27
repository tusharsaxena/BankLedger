# Ka0s Bank Ledger — Review Cycle Final Summary (2026-07-27)

> **Status: template, pending implementation.** This document is written on the assumption that
> every change in `02_PROPOSED_CHANGES.md` has been applied and every test in `03_SMOKE_TESTS.md`
> has passed. Fill in the bracketed placeholders (`[…]`) as the work lands; the structure and the
> claims below are what the plan commits to delivering.

---

## Headline

This cycle hardened Bank Ledger's capture engine and closed the gaps where the addon's *write* paths
had drifted away from its (very careful) *read* paths. The headline fix is that gold movements are
now corroborated against the bank's own balance instead of the player's purse, so buying a bank tab
at the bank window no longer writes a phantom "10,000g deposited to the Warband Bank" row into your
permanent history. Alongside it, the `/bl test` sample dataset became a genuine read-only sandbox
(it could previously write synthetic item ids into your real capture filters), the Window scale
slider now resizes both windows instead of one, and the search box no longer recomputes the entire
Insights aggregation on every keystroke. The rest is cleanup: a stale defaults version, a stale CLI
constant, a comment describing a backfill that never existed, and a dead function.

---

## Counts

* **Critical fixed:** 0 *(none were found)*
* **High fixed:** 3 — F-001, F-002, F-003
* **Medium fixed:** 10 — F-004, F-005, F-006, F-007, F-008, F-009, F-010, F-011, F-012, F-013
* **Low fixed:** 6 — F-014, F-015, F-016, F-017, F-018, F-019

**Deferred:** [none / list finding IDs and the reason]. If C-001b (narrow to guild-bank coin only)
was taken instead of C-001, record here that warband gold capture is **withdrawn**, not fixed, and
why the client offered no reliable balance reader.

---

## Changes by theme

### T1 — Money capture is evidence-driven

**What changed.** A gold movement is now only recorded when the **store's own** coin balance moves in
the opposite direction to your purse, by the same amount — the same "both sides must change" rule
that has always governed item movements. A purchase, a repair or a mail COD that happens to land
while the bank window is open produces no ledger row.

**Why it mattered.** The purse-only diff had no corroboration at all: `BANK_FRAME` reaches the
warband bank, so *any* gold you spent at a bank was persisted as a warband deposit. Those rows were
indistinguishable from real ones afterwards, and they skewed `Gold deposited`, `Net gold`,
`Gold By Store` and the CSV export.

**Findings covered:** F-001 · **Changes:** C-001 [or C-001b]
**Files touched:** `core/Compat.lua`, `modules/Ledger.lua`, `docs/ARCHITECTURE.md`,
`tests/test_ledger.lua`, `tests/test_compat.lua`

### T2 — Test mode is a read-only sandbox

**What changed.** `/bl test` now derives its state from one stored fact, and the History table's
right-click menu greys out **Delete**, **Blacklist item** and **Whitelist item** while the sample
dataset is on screen. "Link to chat" stays available.

**Why it mattered.** The sample rows carry synthetic item ids (190001–190030). Blacklisting one
wrote that id into the real, persisted capture filter; Delete matched nothing in real storage, did
nothing visible, and still fired a ledger-changed broadcast. A user exploring the demo could
silently corrupt their own configuration.

**Findings covered:** F-002, F-009 · **Changes:** C-002
**Files touched:** `modules/LedgerTable.lua`, `modules/Browser.lua`, `tests/test_ledgertable.lua`

### T3 — Settings propagate to everything that consumes them

**What changed.** The Window scale row now broadcasts `Ka0s_BankLedger_SettingsChanged` like every
other row, so the session window rescales live. `/bl list` prints its groups in the schema's declared
order (Master Controls, then Capture) instead of an order derived from a constant naming a group
that no longer exists. The per-store capture grid gained the tooltip every other row already had.

**Why it mattered.** One setting applying to one of two windows reads as a bug, and a "declared page
order" that isn't the order in force is the kind of drift that only gets worse.

**Findings covered:** F-003, F-007, F-019 · **Changes:** C-003, C-004
**Files touched:** `settings/Schema.lua`, `settings/Slash.lua`, `tests/test_schema.lua`,
`tests/test_slash.lua`

### T4 — Refreshes are coalesced

**What changed.** Search-box input is debounced (dropdown selections stay instant); the per-entry
`EntryAdded` refresh is collapsed to one repaint per frame, so a 20-stack deposit costs one repaint
instead of twenty; and the settings panel no longer walks the whole ledger to estimate storage size
while it is hidden.

**Why it mattered.** All three paths did O(n) work far more often than the data changed — worst at
exactly the moments the user is interacting (typing a search, emptying bags at the bank).

**Findings covered:** F-004, F-005, F-018 · **Changes:** C-005, C-006, C-007
**Files touched:** `modules/Browser.lua`, `modules/Insights.lua`, `settings/Panel.lua`

### T5 — The code and its comments agree again

**What changed.** The quality gate no longer lets an uncached item through a threshold the user set,
and the comment promising a name backfill that never existed was corrected. The shipped
`schemaVersion` default matches the migration runner's target. The open-frame token got its own
`C.Context` enum instead of borrowing `C.Store` values. The version string has one resolution path
for both `/bl version` and `/bl help`. A dead exported function and a printer-alias inconsistency
were removed, and the README's command table matches `NS.COMMANDS`.

**Why it mattered.** This addon's comments are unusually load-bearing — they encode hard-won
knowledge about the client's container model. Every comment that turns out to be false costs the
next reader their trust in all of them.

**Findings covered:** F-006, F-008, F-012, F-014, F-015, F-016, F-017 · **Changes:** C-008, C-009, C-012
**Files touched:** `modules/Ledger.lua`, `defaults/Global.lua`, `core/Constants.lua`,
`core/State.lua`, `core/Namespace.lua`, `modules/Browser.lua`, `modules/LedgerTable.lua`,
`settings/Slash.lua`, `README.md`

### T6 — The settings panel is debuggable

**What changed.** The three `pcall` sites that swallowed widget errors now report the failure to the
on-screen debug console under a `[Panel]` tag. The Browser's bus-target fallback — which was
unreachable and would have registered on the shared bus if it ever ran — was removed in favour of the
early return its sibling modules already use.

**Why it mattered.** A refresher that starts failing used to stop updating forever, silently, with
nothing in chat, the console or a test.

**Findings covered:** F-010, F-011 · **Changes:** C-011
**Files touched:** `settings/Panel.lua`, `modules/Browser.lua`

---

## API / behaviour changes

| Change | Detail |
|---|---|
| Slash commands | **No new, renamed or removed verbs.** `/bl list` group **order** changed (Master Controls now first). |
| Chat output | New `[Skip] … (uncached)` console reason; new `[Panel] … failed` console lines when a settings widget errors. Format, colours and the cyan `[BL]` tag unchanged. |
| Capture behaviour | Gold rows now require store-balance corroboration (**fewer** rows recorded; the ones removed were false). Items below a **non-zero** minimum quality that the client has not cached are now skipped rather than recorded. At the default `qualityThreshold = 0` item capture is unchanged. |
| Settings | `settings.windowScale` now also broadcasts on the bus. New tooltip on `settings.excludedStores`. No new, renamed or removed settings. |
| Defaults | `schemaVersion` default `1` → `2`. No other default changed. |
| Locale keys | None added, renamed or removed — v0.1.0 still ships English-only through the `NS.L` fallback seam. |
| Export | CSV columns unchanged; the contract is untouched. |

---

## SavedVariables / migration notes

**No schema bump.** The entry shape is unchanged, so `NS:RunMigrations` is untouched and existing
databases need nothing.

The only SavedVariables-facing edit is the **default** `schemaVersion`, raised from `1` to `2` to
match the migration runner's target:

* **Existing profiles** — unaffected. They already carry an explicit `schemaVersion` (set to `2` by
  the v1→v2 migration on first load after that migration shipped), and AceDB only applies a default
  where a key is absent.
* **Fresh installs** — start at `2` and no longer replay the v1→v2 pass over an empty ledger.
* **No `/bl reset` or `resetall` is required** by any change in this cycle, and no user data is
  discarded. Phantom gold rows already written before C-001 are **not** retroactively removed — the
  addon cannot distinguish them after the fact. Users who care can delete them from the History
  table's right-click menu, or filter to Gold + Warband Bank and review.

---

## Deprecated-API migrations

None. The addon was already clean: a grep for `GetItemInfo`, `GetContainerItemInfo`,
`GetContainerNumSlots`, `IsAddOnLoaded`, `UnitAura*`, `GetSpellInfo` and `InterfaceOptions_*` outside
`core/Compat.lua` returns nothing, and there is no `WOW_PROJECT_ID` branching.

This cycle **added** one Compat shim rather than migrating one:

| New shim | Wraps | Files |
|---|---|---|
| `Compat.GetStoreMoney(store)` | `GetGuildBankMoney` / `C_Bank.FetchDepositedMoney(Enum.BankType.Account)` [confirm the exact reader from the M0 probe] | `core/Compat.lua`, called from `modules/Ledger.lua` |

---

## Performance impact

From the spot-checks in `03_SMOKE_TESTS.md` (fill in with measured figures):

| Scenario | Before | After |
|---|---|---|
| Typing a 5-character search on Insights (`collectgarbage("count")` delta) | [ ] kB | [ ] kB |
| 20-stack deposit with the window open (`GetAddOnCPUUsage`) | [ ] ms | [ ] ms |
| Ten `/bl debug` toggles on a large ledger | [ ] | [ ] |

Expected shape: the search delta drops to roughly one aggregation pass; the deposit CPU figure drops
by close to the fan-out factor; the console toggle stops doing ledger work entirely.

---

## Known follow-ups

* **`modules/Browser.lua` is the next split candidate** (1120 LOC — under the 1500 ceiling, but it
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

---

## Verification evidence

* **Smoke tests:** `docs/reviews/2026-07-27/03_SMOKE_TESTS.md`, sign-off table completed — [link /
  confirm all rows PASS].
* **Headless gate:** `lua tests/run.lua` → [N] passed, 0 failed. `luacheck .` → 0 warnings /
  0 errors in [N] files.
* **Commit range:** [`<first>`..`<last>`] · **PR:** [#N]

---

## Suggested commit message / PR description

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
- F-007 /bl list group order named a group that no longer exists.
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

Tests: lua tests/run.lua green, luacheck . 0/0.
```
