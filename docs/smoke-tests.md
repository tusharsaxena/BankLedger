# Smoke tests — Ka0s Bank Ledger

In-game checks for the behaviour the headless suites cannot reach: real frames, real bank UIs, real
taint. Run these before a release, on a character with a bank, a warband bank and a guild bank.

Each test lists what to do and what must happen. Anything that does not match is a bug, not a
tolerance.

## S-1 · Load

1. Enable the addon and log in.
2. `/bl version` prints one cyan-tagged line, `[BL] v0.1.0`.
3. No Lua errors on login (turn error display on first: `/console scriptErrors 1`).
4. The minimap button is present and its tooltip shows the movement count.

## S-2 · Character bank deposit and withdrawal

1. Open your bank.
2. Deposit a stack of something into a bank bag.
3. `/bl show` — the top row is a **Deposit** to **Character Bank** with the right item and count.
4. Withdraw part of that stack.
5. A new **Withdraw** row appears with the partial count, not the whole stack.

## S-3 · Loot does not become a movement

1. Open your bank and leave it open.
2. Take an item from your mailbox, or loot something, so it lands in your bags.
3. **No** ledger row appears — the item changed on one side only, so it is not a bank movement.

## S-4 · Reagent bank and warband bank

1. Deposit a reagent into the reagent bank → a **Reagent Bank** row.
2. Move an item into a warband bank tab → a **Warband Bank** row.
3. Both stores appear in the Store filter dropdown, which only lists stores your data contains.

## S-5 · Gold

1. Open the warband bank and deposit gold.
2. A **Gold** row appears: quantity shows a dash, Value shows the amount, direction Deposit.
3. Withdraw gold → a Withdraw row with the same shape.
4. Open your **character** bank and sell something to a vendor with the bank open. **No** gold row
   appears — the character bank holds no gold, so its money changes are never attributed.

## S-6 · Guild bank

1. Open the guild bank and deposit an item.
2. A **Guild Bank** row appears; the exported CSV's `guild` column carries your guild name.
3. Deposit gold → a Gold row against the guild bank.

## S-7 · Window behaviour

1. `/bl toggle` opens and closes the window; **Esc** closes it.
2. Drag the title bar, then resize from the bottom-right grip. `/reload` — the position and size
   come back.
3. The window will not shrink below the width that shows every column.
4. `/bl set settings.windowScale 1.3` rescales the open window immediately.

## S-8 · Filtering, grouping and sorting

1. Type in the search box — the row count in the footer falls as you type.
2. Pick two stores in the Store dropdown — both are ticked and the button reads "Store: 2 selected".
3. Click a column header to sort; click it again to reverse. Date starts newest-first.
4. Group by Store — collapsible headers appear with per-group counts. Click one to collapse it.
5. **Clear** returns every filter, the grouping and the sort to their defaults.

## S-9 · Insights

1. Switch to the **Insights** tab. The summary cards and bars populate.
2. Apply a filter on the History tab, then switch back to Insights — the numbers reflect the same
   filter. The two tabs never disagree.
3. Net gold shows green when positive, red when negative.

## S-10 · Export

1. On History, click **Export** → choose **Current View** → **Export to CSV**.
2. The copy window opens with the text pre-selected in a monospace font. Ctrl+C copies it; Esc
   closes it.
3. The row count matches what the table showed.
4. Repeat on the **Insights** tab — the CSV is the sectioned summary, not raw rows.

## S-11 · Filters (blacklist / whitelist)

1. Right-click a ledger row → **Blacklist item**. A chat line confirms it.
2. Move that item to your bank again — **no** new row is recorded, and the row you clicked is still
   there (blacklisting is point-in-time, it never rewrites history).
3. Open Settings ▸ Filters — the id is listed with its item name. Remove it.
4. Add an id by shift-clicking an item link into the Add box.
5. Whitelist an item, set the minimum quality to Epic, and move the whitelisted item — it is still
   recorded.
6. **Defaults** on the Filters page clears both lists after a confirm.

## S-12 · Settings panel

1. `/bl config` opens the panel with the addon's entry already present in the list.
2. The landing page shows the tagline and every slash command.
3. General and Filters both render a breadcrumb header, a gold divider and a Defaults button.
4. Toggle a checkbox, then run `/bl list` — the value matches.
5. `/bl set settings.trackMoney false`, then reopen the panel — the checkbox reflects the change.
6. The scrollbar is visible on both pages and greyed out on the one that fits, so the body width
   does not jump between them.

## S-13 · Combat

1. Pull a training dummy.
2. `/bl config` prints a grey "cannot open settings during combat" notice and does **not** open.
3. Leave combat. The panel does **not** pop itself open — you re-run `/bl config` when you choose.
4. The ledger window still opens, refreshes and filters in combat (it is a non-secure frame).

## S-14 · Debug console

1. `/bl debug` opens the console. The header reads **Debug: OFF** in red.
2. `/bl debug on` → a green ON ack in chat, a `[Debug] logging enabled` line and an `[Init]` summary
   naming the build, schema and profile.
3. Move something to your bank → one `[Move]` summary line per pass, not one per item.
4. The scrollbar tracks the wheel both ways, and the counter reads `N / 500 lines`.
5. **Copy** opens a monospace box with the plain, colour-code-free log. **Clear** empties both and
   resets the counter to `0 / 500`.
6. `/bl debug off` → a red OFF ack and a `[Debug] logging disabled` line.
7. `/reload` → logging is off again, because the flag is session-only.

## S-15 · Preview mode

1. `/bl preview` opens the window on a sample ledger with a red **PREVIEW** badge by the title.
2. The filters, grouping, Insights and export all work against it.
3. `/bl preview` again returns to the real data and the badge disappears.

## S-16 · Retention and purge

1. `/bl set settings.retentionDays 7`, then `/reload`. Entries older than 7 days are gone.
2. `/bl purge` asks to confirm; accepting empties the ledger and the window shows its empty state.
3. Settings ▸ General ▸ **Reset all** asks to confirm and restores everything, recentring the window.
