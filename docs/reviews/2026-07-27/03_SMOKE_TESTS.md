# Ka0s Bank Ledger — Manual Smoke Tests (2026-07-27)

Execute **after** the changes in `02_PROPOSED_CHANGES.md` are applied. Derived from that document;
one section per change ID. Fill in the sign-off table at the bottom.

> **Revised 2026-07-27 after implementation.** C-001 was implemented in full (not the C-001b
> fallback), so its pass criteria are now unconditional. C-001 also gained a section — **C-001-B** —
> for a failure mode the live probe exposed that the design had not anticipated. C-005, C-008 and
> C-012 have been corrected to match what shipped.

## Priority order

If you cannot run everything in one sitting, run it in this order — each tier is self-contained.

| Tier | Sections | Why |
|---|---|---|
| **1 — must pass before merge** | C-001, C-001-B, C-008, R-2 | The capture engine. These are the only changes that can silently *lose or invent* permanent history. C-001 is the one place this cycle could cost you a real row rather than remove a false one. |
| **2 — user-visible behaviour** | C-002, C-003, C-004, C-005, C-012 | Each is a defect a user would have reported. Fast to run, no special setup. |
| **3 — regression / no-change-expected** | C-006, C-007, C-009, C-010, C-011, R-1, R-5…R-14 | Changes that should be invisible. Failures here are refactor slips. |
| **4 — measurement** | Perf spot-checks 1–3, R-3, R-4 | Numbers for the record, not gates. |

---

## Pre-flight

1. **Headless gate first.** From the repo root:
   `lua tests/run.lua` → must print `N passed, 0 failed`.
   `luacheck .` → must print `0 warnings / 0 errors`.
   Do not proceed to in-client testing on red.
2. **Install.** Copy the addon folder to `World of Warcraft/_retail_/Interface/AddOns/BankLedger/`.
   TOC `## Interface: 120007` — retail only; the addon has no Classic support by design.
3. **Character.** Any max-level character with: a character bank, a **warband bank** tab purchased,
   and membership of a guild with a **guild bank** tab you can deposit to and withdraw from. A
   second character on the same account is useful for the account-wide checks but not required.
4. **Make failures visible.**
   * `/console scriptErrors 1` then `/reload` — Lua errors surface as a popup instead of silently.
   * `/etrace` and add `PLAYER_MONEY`, `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`,
     `GUILDBANKBAGSLOTS_CHANGED` for the capture sections.
   * `/bl debug on` — turns on the tagged console log for the whole session. Leave it on except
     where a test says otherwise; `/bl debug` opens the window, **Copy** exports the log.
5. **Baseline SavedVariables.** Before the first run, back up
   `WTF/Account/<ACCT>/SavedVariables/BankLedger.lua`. Several tests below need a *fresh* DB — get
   one by logging out, deleting that file, and logging back in.

---

## C-001 — Money movements corroborated against the store's own balance

**Change covered:** C-001 — a purse change alone no longer creates a gold row.

**Setup:** live ledger (not test mode), `/bl debug on`, ledger window open on **History** with the
Character filter on *Current*, `settings.trackMoney` = true.

**Steps**
1. Run `/bl debug scan` at a **character bank**. In the console, find the `money API:` block.
2. Walk to a bank, open it, and **purchase a bank slot / bank tab** (any purchase that spends gold
   with the bank frame open). Close the bank.
3. `/bl toggle` → History tab. Set the Store filter to *Warband Bank* and the Type filter to *Gold*.
4. Now open the bank again and **deposit 10g into the warband bank** (Warband tab → deposit money).
   Close the bank.
5. Open a **guild bank**, deposit 5g, withdraw 1g, close.
6. Clear the filters (**Clear** button) and read the Gold rows.

**Expected**
* Step 1: `bankFetch=function`, `bankTypes=true`, and a non-zero
  `C_Bank.FetchDepositedMoney(Account)` figure matching your warband bank's gold. If `bankFetch` is
  **not** `function` on this build, stop — the implementation's premise does not hold here and the
  C-001b narrowing must be reconsidered.
* After step 2–3: **no** gold row for the purchase. Console shows a `[Diff]` line for the pass and
  **no** `[Move]` line attributing money to `WARBAND_BANK`.
* After step 4: exactly **one** row — Deposit / Warband Bank / Gold / `10g`.
* After step 5: exactly **two** rows — Deposit `5g` and Withdraw `1g`, both Guild Bank.
* No Lua error popup at any point.

**Pass / Fail:** PASS when the purchase produces no row **and** all three genuine movements produce
exactly one correctly-signed row each. C-001 was implemented in full, so step 4 producing no row is
a **FAIL**, not the documented fallback — it means corroboration is costing real rows.

**If step 4 produces no row:** the likely cause is timing, not logic — `PLAYER_MONEY` arriving before
`C_Bank.FetchDepositedMoney` reflects the deposit. Check the console for a `[Diff]` line followed by
`one-sided change never settled; baseline re-anchored`. That would mean the store balance took longer
than `SETTLE_TIMEOUT_SECONDS` to land, and the fix is to extend the settle window for money, not to
weaken the rule.

---

## C-001-B — The guild bank's closed-frame balance lie

**Change covered:** C-001 — `Compat.GetStoreMoney` returns `nil`, not the API's `0`, when the guild
bank frame is down.

**Why this exists:** the live probe found `GetGuildBankMoney()` answers **0** with the guild bank
closed and its true balance (billions of copper) with it open. If that `0` ever reached the diff as
a balance, opening the guild bank would look like the store gaining its entire holdings at once —
and paired with any purse movement in the same pass, that fabricates a gold row. This is the single
highest-risk edge in the change, and it cannot be reproduced headlessly at the client's real timing.

**Setup:** `/bl debug on`, live ledger, guild bank tab you can deposit to.

**Steps**
1. Fresh `/reload`. Do **not** open a guild bank yet.
2. Run `/bl debug scan` and read `GetGuildBankMoney()` — it should report `0` (the lie).
3. Go to a **character bank**, open it, and spend some gold (repair, or buy a bank slot). Close it.
4. Walk to a **guild bank** and open it.
5. `/bl debug scan` again — `GetGuildBankMoney()` now reports the true balance.
6. Close the guild bank, then `/bl toggle` → History → Type filter *Gold*.

**Expected**
* Step 3 produces **no** gold row (that is C-001 doing its job at the bank).
* Steps 4–6 produce **no** gold row at all. In particular there must be **no** Guild Bank row for
  the difference between `0` and the true balance, in either direction.
* Console shows no `[Move]` line attributing money to `GUILD_BANK` across the whole sequence.

**Pass / Fail:** PASS when opening a guild bank after spending gold elsewhere writes nothing. A row
here of any size — especially a very large one — means the closed-frame `0` is reaching the diff and
`Compat.IsGuildBankVisible()` is not gating the read.

---

## C-002 — Test mode is read-only

**Change covered:** C-002 — mutating row actions are disabled while `/bl test` is on.

**Setup:** fresh SavedVariables. Confirm both filter lists are empty: `/bl config` → **Filters** →
both sections read `(none)`.

**Steps**
1. `/bl test` → chat prints `test mode on`; the ledger window opens with a red **TEST MODE** badge
   beside the title and a populated table.
2. Right-click any item row.
3. Read the menu: **Link to chat** must be enabled (white); **Blacklist item**, **Whitelist item**
   and **Delete** must all be greyed out and unclickable.
4. Click each greyed entry once. Nothing should happen and the menu should stay open (disabled rows
   are click-inert).
5. Press Escape / click away, then `/bl config` → **Filters**. Both lists must still read `(none)`.
6. `/bl test` again → `test mode off`, badge gone.
7. Right-click a **real** ledger row (record something at a bank first if the ledger is empty).
   All four entries must now be enabled. Click **Delete** — the row must disappear immediately and
   the footer's "Showing X of Y" must decrement.

**Pass / Fail:** PASS when no synthetic item id ever reaches the Filters page, Delete is inert in
test mode and works on a real row, and no Lua error appears.

---

## C-003 — Window scale reaches both windows

**Change covered:** C-003 — `windowScale` now broadcasts on the bus.

**Setup:** `/bl session` to open the session window on sample data, and `/bl toggle` to open the
ledger window. Position them so both are fully visible at once.

**Steps**
1. `/bl config` → **General**. Drag **Window scale** to its maximum (1.60) and release the mouse.
2. Observe **both** windows without reloading.
3. Drag it back to 1.00 and release.
4. `/bl set settings.windowScale 1.3` from chat and observe both windows again.

**Expected:** both the ledger window and the "Current Banking Session" window resize together, on
mouse-up, with no `/reload`. The chat echo after step 4 reads
`settings.windowScale = 1.30x` (gold key, white value, cyan `[BL]` tag, no trailing colon).

**Pass / Fail:** PASS when the session window tracks the slider live in both the panel and the slash
paths.

---

## C-004 — `/bl list` group order and the store tooltip

**Change covered:** C-004.

**Steps**
1. `/bl list`.
2. `/bl config` → **General**, hover the "Record movements to and from" grid's title.

**Expected**
* Step 1 prints, in order: the green `Available settings` header; `  [Master Controls]` (azure, two
  spaces) with its five rows at four spaces; then `  [Capture]` with its five rows. Every value row
  is gold-key / white-value. **No line ends in a colon.**
* Step 2 shows a tooltip explaining that a **ticked** box means *record* that store.

**Pass / Fail:** PASS when Master Controls precedes Capture and the tooltip appears.

---

## C-005 — Filter debounce

**Change covered:** C-005 — search keystrokes coalesce into one recompute.

**Setup:** a ledger with at least ~2000 entries. Fastest route: `/bl test` (≈256 synthetic rows) is
enough to see behaviour but not load; for the perf half, use a real large ledger if you have one.

**Steps**
1. `/bl toggle` → **Insights** tab.
2. Type `linen` into the search box at normal typing speed.
3. Watch for frame hitching per keystroke.
4. Wait ~0.3s after the last character.
5. Switch to **History** and repeat.
6. Change the **Store** dropdown to a single store.

**Expected:** typing is smooth; the charts/table update once, **0.20s** after the last keystroke
(`FILTER_DEBOUNCE` in `modules/Browser.lua`). The dropdown change (step 6) applies **immediately** —
only the search box is debounced.

**Pass / Fail:** PASS when typing does not hitch, the result is correct after the pause, and
dropdown selections still feel instant. This is checkpoint **C3**: if the dropdowns feel laggy the
debounce has been applied too broadly, which is a worse experience than the cost it saves — report
it rather than accepting it.

---

## C-006 — Bulk-deposit refresh coalescing

**Change covered:** C-006.

**Setup:** at least 20 distinct item stacks in your bags. `/bl debug on`, ledger window **open** on
the Insights tab, bank open.

**Steps**
1. Use the bank's "Deposit All Reagents" (or shift-click 20 stacks in quick succession) to move
   many stacks in one action.
2. Watch the client during the deposit.
3. Open `/bl debug` and read the log.
4. Switch to History and confirm every deposited stack has a row.

**Expected:** no visible stall during the deposit; the console shows **one** `[Move]` summary line
for the pass (never one line per item, per debug-logging-§9); every stack is present in History.

**Pass / Fail:** PASS when the row count is complete **and** the client does not stall. A complete
row count with a stall is a partial fail — re-check that the consumers, not the sender, were changed.

---

## C-007 — Hidden panel does no work

**Change covered:** C-007.

**Steps**
1. `/bl config`, then press Escape to close the Settings window entirely.
2. `/bl debug` several times in a row (show/hide the console).
3. `/bl config` again → **General** → scroll to **Storage**.

**Expected:** step 2 is instant with no hitch. Step 3 shows a **current** movement count and
database-size estimate (matching the ledger window's bottom-right `Database ≈ …` figure).

**Pass / Fail:** PASS when the storage figures are correct on open despite not being refreshed while
hidden.

---

## C-008 — Uncached items and the quality gate

**Change covered:** C-008.

**Setup:** `/bl debug on`. `/bl config` → **General** → **Minimum quality** = *Rare and above*.
You need an item the client has **not** cached — most reliable: log in fresh (no `/reload`), go
straight to a **guild bank** tab you have not opened this session containing a green/grey item.

**Steps**
1. Log in fresh, open the guild bank, withdraw one low-quality item you have not previously seen.
2. Open `/bl debug` and read the log.
3. Set **Minimum quality** back to *Poor and above*, then repeat the withdrawal with another item.

**Expected**
* Step 2: a `[Skip]` line — **not** a silently recorded row, and the item must not appear in
  History. The reason distinguishes the two cases: `uncached` when the client had no data for the id
  (the F-006 case), `quality` when it did and the item was genuinely below the threshold. Either is
  a pass; `uncached` is the one that proves the fix.
* Step 3: at threshold 0 the item **is** recorded, as before. This is checkpoint **C2**, the
  no-behaviour-change case that governs every user who never set a threshold — it must not regress.

**Pass / Fail:** PASS when a sub-threshold item is never recorded regardless of cache state, the
console names the reason, and threshold 0 behaves exactly as it did before the change.

**Note:** a skipped id is queued for caching, so the *second* movement of the same item may report
`quality` where the first reported `uncached`. That is the intended progression, not a flap.

---

## C-009 — `C.Context` rename (regression only)

**Change covered:** C-009 — a pure rename; nothing user-visible must change.

**Steps**
1. `/bl debug on`, open the character bank, deposit an item, close.
2. Open a guild bank, deposit an item, close the guild bank window.
3. `/bl debug scan` and read the `openContext=` and `guild bank close hook:` lines.

**Expected:** the console reports `BANK_FRAME` / `GUILD_BANK` exactly as before; the guild session
window closes when the guild bank window closes; both deposits are recorded.

**Pass / Fail:** PASS when capture and the session window behave identically to pre-change, with no
`nil` context in any console line.

---

## C-010 — Filter copy (regression only)

**Steps**
1. Open the ledger, apply a Store filter, a Direction filter and a search term.
2. Press **Clear**.
3. Re-apply a different combination, then switch tabs History ↔ Insights twice.

**Expected:** the footer "Showing X of Y" always matches the visible rows; Clear returns Character to
*Current* (not All) and empties every other filter; the Insights numbers match the History row count
after each change.

**Pass / Fail:** PASS when the two views never disagree about the slice.

---

## C-011 — Panel error visibility and bus target

**Steps**
1. `/reload`, then `/bl config` and visit both **General** and **Filters**.
2. `/bl debug on`, then `/bl config` → **Filters** → add item id `6948` to the blacklist, and remove
   it again.
3. Close Settings, then from the ledger table right-click a real row → **Blacklist item**.
4. Re-open `/bl config` → **Filters**.

**Expected:** no Lua errors; the Filters list repaints correctly in step 2; in step 4 the id added
while the page was **hidden** is present (the dirty-flag lazy rebuild). The console shows no
`[Panel] … failed` lines — if it does, that is the change working, and the underlying error must be
fixed before sign-off.

**Pass / Fail:** PASS when both subcategories render, off-screen edits appear on next open, and no
`[Panel] … failed` line is emitted.

---

## C-012 — Defaults, version, README, printer

**Steps**
1. Delete `SavedVariables/BankLedger.lua`, log in, then `/bl debug on` (this emits the `[Init]`
   summary line).
2. Read the `[Init]` line in the console.
3. `/bl version`, then `/bl help` — compare the version in both.
4. With test mode **off**, right-click a real ledger row → **Blacklist item**, and read the chat
   line. (This is the `LedgerTable` printer alias, changed in this cycle.)
5. Compare `README.md`'s command table with `/bl help` output line by line.
6. `/bl show`, `/bl hide`, `/bl toggle` — each must work normally.

**Expected**
* Step 2: `[Init]` reads `BankLedger v0.1.0, schema v2, profile 'Default', 0 entries` — **schema v2**
  on a brand-new database (not v1), and **no** `[Migrate]` line, because a fresh DB is already
  current and has nothing to migrate.
* Step 3: both print the same version, both carry the cyan `[BL]` tag.
* Step 4: the blacklist confirmation reads
  `[BL] blacklisted <item>. Manage in Settings ▸ Filters.` — cyan tag present. A **green** line with
  a trailing colon means the alias fell through to AceConsole's `:Print` mixin.
* Step 5: same verbs in the same order — `show, hide, toggle, config, version, get, set, list,
  reset, resetall, session, test, purge, debug, help` — plus README-only rows for `debug scan` and
  `debug panel`.
* Step 6: the window opens and closes. `B:Unavailable()` was deleted this cycle; these three verbs
  were the only plausible callers, so this confirms nothing depended on it.

**Pass / Fail:** PASS when a fresh DB starts at schema v2 with no migration line, both version paths
agree, every chat line is `[BL]`-tagged, and the window verbs work.

---

## Regression suite (not tied to one change)

| # | Check | Expected |
|---|---|---|
| R-1 | `/reload` with both windows open | No errors; both windows reopen at their saved position and size |
| R-2 | Fresh login (delete SavedVariables) | Defaults populate; `/bl list` shows every row at its default; no errors |
| R-3 | `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` | No Lua error popup; retention prune runs ~5s after entering world |
| R-4 | Enter and leave combat with both windows open | Windows stay visible and interactive (they are non-secure — no combat gate by design) |
| R-5 | `/bl config` **during combat** | Grey chat notice "cannot open settings during combat…"; the panel does **not** open, and does **not** pop open when combat ends |
| R-6 | Toggle **every** option in Settings ▸ General once, then `/reload` | Every value persists; no errors |
| R-7 | Settings ▸ Filters: add by id, add by shift-clicked link, remove, Clear all (confirm) | Each works; the confirm dialogs appear; ledger history is untouched |
| R-8 | `/bl purge` → confirm | Ledger empties; both windows and the Insights tab show the empty-state message; storage stats read 0 |
| R-9 | Defaults button on **General**, then on **Filters** | General resets settings + recentres both windows; Filters prompts, then clears both id lists |
| R-10 | Escape closes each window | Ledger, session, debug console, both copy windows and the export modal all close on Escape |
| R-11 | Resize the ledger window by its grip, then `/reload` | Size persists; columns and header stay aligned; no column overflows |
| R-12 | Minimap button: left-click, right-click; then tick "Hide minimap button" | Left opens the ledger, right opens Settings; the button hides and stays hidden across `/reload` |
| R-13 | Export → All Data → Export to CSV on both tabs | A copy window opens with a CSV header row and data; Ctrl+C works; Escape closes |
| R-14 | Sort by every column header, group by every option | No errors; the sort/group arrow moves; grouped headers collapse and expand |

*Profile switching is not applicable — the addon is deliberately account-wide (`global`), with no
AceDB profile surface.*

---

## Localization sanity

Not applicable to this pass: no finding in `01_FINDINGS.md` is tagged `[locale]`, and no proposed
change touches a tooltip **pattern-match** or a localized-string comparison. Note for a future pass:
`Compat.QualityLabel` correctly keys on the numeric quality id and reads the localized
`ITEM_QUALITY<n>_DESC` global rather than an English literal (anti-pattern #37 avoided), and the
CSV export ships both `quality` (localized label) and `qualityRaw` (id).

---

## Performance spot-checks

Run these for the perf-tagged changes (C-005, C-006, C-007). Use a ledger of at least a few thousand
entries.

1. **Search-box cost (C-005).**
   `/run collectgarbage("collect"); print(collectgarbage("count"))` → note the number.
   Open Insights, type `linen`, wait 1s, run the same line again. Note the delta.
   Expected: markedly smaller than the pre-change delta (one `Database:Stats` allocation, not five).
2. **Bulk deposit (C-006).**
   `/console scriptProfile 1` → `/reload` → do a 20-stack deposit with the window open →
   `/run UpdateAddOnCPUUsage(); print(GetAddOnCPUUsage("BankLedger"))`.
   Expected: substantially below the pre-change figure. Remember `/console scriptProfile 0` and
   `/reload` afterwards — profiling is a permanent overhead otherwise.
3. **Debug-console toggle (C-007).**
   Spam `/bl debug` ten times with a large ledger. Expected: no perceptible hitch (previously each
   toggle walked the whole ledger via `refreshStats`).

*No `OnUpdate` handler exists anywhere in the addon, so no frame-time handler check is required.*

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-001 | | | |
| C-001-B | | | |
| C-002 | | | |
| C-003 | | | |
| C-004 | | | |
| C-005 | | | |
| C-006 | | | |
| C-007 | | | |
| C-008 | | | |
| C-009 | | | |
| C-010 | | | |
| C-011 | | | |
| C-012 | | | |
| Regression R-1…R-14 | | | |
| Perf spot-checks 1–3 | | | |
