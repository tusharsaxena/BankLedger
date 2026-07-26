# Smoke tests — Ka0s Bank Ledger

In-game checks for the behaviour the headless suites cannot reach: real frames, real bank UIs, real
taint. Run these before a release, on a character with a bank, a warband bank and a guild bank.

Void storage is not covered: it was retired in 12.0.7 and the addon does not track it.

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

## S-4 · Warband bank

1. With the bank open, click the **Warband Bank** tab and move an item in → a **Warband Bank** row.
2. Move it back out → a Withdraw row. Both must appear even though switching tabs fires no event.
3. The row can take a second or two: the warband tab updates on a server round-trip, and the addon
   deliberately waits for both halves of the movement before writing anything.
4. Both stores appear in the Store filter dropdown, which only lists stores your data contains.

## S-5 · Gold

1. Open the warband bank and deposit gold.
2. A **Gold** row appears: Qty shows the amount as money, Type and Sub-type both read Gold,
   Quality shows a dash, direction Deposit (green ▼). The item name is a pale gold.
3. Hovering the row shows a **Gold** tooltip with the amount (a gold row has no item link, so the
   tooltip is built by hand).
4. Withdraw gold → a Withdraw row with the same shape.
5. Open your **character** bank and sell something to a vendor with the bank open. **No** gold row
   appears — the character bank holds no gold, so its money changes are never attributed.

## S-6 · Guild bank

1. Open the guild bank and deposit an item.
2. A **Guild Bank** row appears; the exported CSV's `guild` column carries your guild name.
3. Deposit gold → a Gold row against the guild bank.
4. `/bl debug scan` while it is open reports `openContext=GUILD_BANK`. The guild bank has no
   working open event, so it arms itself when tab data arrives — if this reads `nil`, no data has
   reached the addon and nothing will be recorded.
5. Close the window, then move something in your bags. No further guild-bank scanning should
   happen — it disarms once the window is gone.

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
5. The **Sub-type** and **Quality** dropdowns list only values your data contains; Quality is
   ordered Poor→Legendary (not alphabetically) and each option carries its quality colour.
6. **Type ▸ Gold** and **Sub-type ▸ Gold** appear once a gold movement is recorded, and filter to
   gold rows. Both mix freely with real item types in one multi-select.
7. The **In/Out** menu shows a red ▲ Withdraw and a green ▼ Deposit; the **Store** menu shows each
   store in its column colour. Both match the table exactly.
8. The window opens with **Character: Current** already applied — a fresh install, a `/reload` and
   **Clear** all land there, not on "All". `/bl preview` is the exception: synthetic data opens
   unscoped.
9. Every character row and dropdown option shows its class icon and class colour; "Character:
   Current" carries no icon.
10. Group by **Type**, **Sub-type** and **Quality**. Quality groups run Poor→Legendary and gold sits
    in its own "None" group.
11. **Clear** returns every filter, the grouping and the sort to their defaults.

## S-9 · Insights

1. Switch to the **Insights** tab. Fourteen stat cards populate across the top; hovering each one
   explains what it counts.
2. A long money value (Value moved, Biggest move) shrinks to stay on one line inside its card —
   it never clips or wraps.
3. Net items and Net gold read green with a `+` when positive, red with a `-` when negative, and a
   grey dash at exactly zero.
4. **Deposits vs Withdrawals** is one bar split into two coloured shares whose counts and
   percentages add up to the movement total. Hovering either half names it.
5. **Net Flow By Store** grows right and green for a store you are filling, left and red for one you
   are draining, from a centre baseline. A store with twice another's net has visibly twice the bar.
6. **Movements By Character** is class-coloured and carries each class icon. The two `×` companions
   below it stack one segment per store / per direction, each segment hover-tipped with its own
   value, and a legend under each names the colours.
7. **Movements By Quality** runs Poor → Legendary (not by count) in the game's own quality colours.
8. **Item Type** and **Sub-type** bars are all visibly different colours — no two adjacent bars look
   alike — and each has a legend.
9. The per-day strips (movements, value, and gold if any) share one x-axis. Quiet days show a faint
   ghost bar rather than a gap; the rotated date labels thin out as the bars tighten and never
   overlap. Hovering a bar names the day and its figure.
10. **By Hour Of Day** shows all 24 buckets, including the empty ones.
11. Under **TOP OF THE LIST**, four panels: top items by value, by movements, by quantity, and top
    banking spots. Item names carry their quality colour; a truncated name shows in full on hover.
12. Move some gold, refresh — the **GOLD** divider and its two charts appear. With a filter that
    excludes every gold movement, that whole block disappears rather than rendering empty.
13. Apply a filter on the History tab, then switch back to Insights — every number and every bar
    reflects the same filter. The two tabs never disagree.
14. Resize the window: the cards re-flow to the new width, the bars and strips re-stretch, and the
    two list columns stay side by side.
15. With the tab open, move something at a bank — the panel updates live.
16. Purge the ledger: the cards read 0 and one centred "no movements" line replaces every section.

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
3. General and Filters both render a breadcrumb header, a gold divider and a Defaults button. The
   Defaults button looks like every other button on the page — if it renders as Blizzard's red
   stone button, it was built before a UI skin hooked AceGUI (`/bl debug panel` shows the region
   list; the bare 5-region `130828` form is the unskinned one).
   General's sections read **Master Controls** (enable, minimap, session window, debug console,
   window scale + Reset all), then **Capture** (quality, retention, item/gold toggles, per-store
   grid), then **Storage**.
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
3. Settings ▸ General ▸ **Reset all** asks to confirm and restores everything, recentring both
   windows.

## S-17 · Current Banking Session window

1. Open your character bank. A second window titled **Ka0s Bank Ledger - Current Banking Session**
   appears alongside it, empty, reading "Nothing has moved yet this session."
2. It has no tabs, no filter bar, no search, no Clear, no Export and no footer. Its columns are
   In/Out, Store, Item, Qty, Quality, Type and Sub-type — no Date, no Time, no Character.
3. Clicking a column header does nothing. Hovering one still shows that column's explanation.
4. Deposit something. A row appears **immediately**, coloured exactly as the same movement reads in
   the History window, newest at the top.
5. Withdraw something. A second row appears above the first, with the red ▲ glyph.
6. Move gold at the warband bank — the row shows "Gold" and the amount as coins.
7. Drag the window somewhere else and resize it from the bottom-right grip.
8. Close the bank. The window closes.
9. Reopen the bank: it comes back **empty** (it is this visit's movements, not a running log) and in
   the position and size you left it.
10. Open the main ledger window — every movement from that session is still there. The session view
    never stored anything of its own.
11. Delete one of those rows from the History table while the bank is still open — it disappears from
    the session window too.
12. Repeat steps 1–5 at the **warband** tabs and at a **guild bank**. Both drive the same window; the
    guild bank has no close event, so confirm the window also disappears when the guild bank frame
    goes away.
13. `/reload` while a bank is open: the window reappears empty when you next open a bank, because the
    session data was never persisted.
14. Settings ▸ General ▸ untick **Session window**. Open a bank — no window appears, but the
    movements you make are still recorded (check the History window). Tick it again while a bank is
    open and it appears on the next movement; untick it while it is open and it closes at once.
15. Away from any bank, `/bl session` opens it on a sample visit so it can be positioned. Run it
    again to dismiss it. While a real bank session is open, `/bl session` refuses and says so rather
    than replacing your actual data with placeholders.
