# Ka0s Bank Ledger — Manual Smoke Tests (2026-07-27)

Execute **after** the changes in `02_PROPOSED_CHANGES.md` are applied. Derived from that document;
one section per change ID. Fill in the sign-off table at the bottom.

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
1. Run `/bl debug scan` at a **character bank**. In the console, find the new `money API:` line.
   Record which readers this build exposes.
2. Walk to a bank, open it, and **purchase a bank slot / bank tab** (any purchase that spends gold
   with the bank frame open). Close the bank.
3. `/bl toggle` → History tab. Set the Store filter to *Warband Bank* and the Type filter to *Gold*.
4. Now open the bank again and **deposit 10g into the warband bank** (Warband tab → deposit money).
   Close the bank.
5. Open a **guild bank**, deposit 5g, withdraw 1g, close.
6. Clear the filters (**Clear** button) and read the Gold rows.

**Expected**
* After step 2–3: **no** gold row for the purchase. Console shows a `[Diff]` line for the pass and
  **no** `[Move]` line attributing money to `WARBAND_BANK`.
* After step 4: exactly **one** row — Deposit / Warband Bank / Gold / `10g`.
* After step 5: exactly **two** rows — Deposit `5g` and Withdraw `1g`, both Guild Bank.
* No Lua error popup at any point.

**Pass / Fail:** PASS when the purchase produces no row **and** both genuine deposits/withdrawals
produce exactly one correctly-signed row each. If C-001b (the fallback) was implemented instead,
step 4 legitimately produces **no** row — in that case PASS requires steps 2 and 4 to produce
nothing and step 5 to produce two rows.

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

**Expected:** typing is smooth; the charts/table update once, shortly after you stop typing. The
dropdown change (step 6) applies **immediately**, with no perceptible delay.

**Pass / Fail:** PASS when typing does not hitch, the result is correct after the pause, and
dropdown selections still feel instant.

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
* Step 2: a `[Skip]` line whose reason is `quality` or `uncached` — **not** a silently recorded row.
  The item must not appear in History.
* Step 3: at threshold 0 the item **is** recorded, as before (this is the no-behaviour-change case).

**Pass / Fail:** PASS when a sub-threshold item is never recorded regardless of cache state, the
console names the reason, and threshold 0 behaves exactly as it did before the change.

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
4. `/bl test`, right-click a row → hover **Blacklist item** (it is disabled per C-002); instead turn
   test mode off and blacklist a real row, and read the chat line.
5. Compare `README.md`'s command table with `/bl help` output line by line.

**Expected**
* Step 2: `[Init]` reads `BankLedger v0.1.0, schema v2, profile 'Default', 0 entries` — **schema v2**
  on a brand-new database (not v1).
* Step 3: both print the same version, both carry the cyan `[BL]` tag.
* Step 4: the blacklist confirmation line carries the cyan `[BL]` tag (proving the printer alias
  change did not fall through to the global `print`).
* Step 5: same verbs in the same order; `/bl debug` documented with its `on` / `off` / `scan` /
  `panel` arguments.

**Pass / Fail:** PASS when a fresh DB starts at schema v2, both version paths agree, and every chat
line is `[BL]`-tagged.

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
