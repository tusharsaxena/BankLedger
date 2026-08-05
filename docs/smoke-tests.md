# Smoke tests — Ka0s Bank Ledger

In-game checks for the behavior the headless suites cannot reach: real frames, real bank UIs, real
taint. Run these before a release, on a character with a bank, a warband bank and a guild bank.

Each test lists what to do and what must happen. Anything that does not match is a bug, not a
tolerance.

## S-1 · Load

1. Enable the addon and log in.
2. `/bl version` prints one cyan-tagged line, `[BL] v1.0.0`.
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
6. Open the bank again and **spend** gold with it open — buy a bank slot, or repair. **No** gold row
   appears. A purse change alone is not a movement: the store's own balance has to mirror it, which
   is what stops a purchase at the bank being filed as a warband deposit.
7. `/bl debug scan` at the bank and read the `money API:` block. `bankFetch=function` and a non-zero
   `C_Bank.FetchDepositedMoney(Account)` mean the warband balance is readable on this build; if it
   is not, gold movements to the warband bank are declined rather than guessed.

## S-6 · Guild bank

1. Open the guild bank and deposit an item.
2. A **Guild Bank** row appears; the exported CSV's `guild` column carries your guild name.
3. Deposit gold → a Gold row against the guild bank.
   Then, from a fresh `/reload`, spend gold at a **character bank** and only afterwards open the
   guild bank. **No** guild-bank gold row appears. This is worth doing deliberately: with the guild
   frame closed the client reports the guild balance as `0` rather than "unknown", so a naive read
   would see the true balance arrive as an enormous gain the moment you open it.
4. `/bl debug scan` while it is open reports `openContext=GUILD_BANK`. The guild bank has no
   working open event, so it arms itself when tab data arrives — if this reads `nil`, no data has
   reached the addon and nothing will be recorded.
5. Close the window, then move something in your bags. No further guild-bank scanning should
   happen — it disarms once the window is gone.

## S-7 · Window behavior

1. `/bl toggle` opens and closes the window; **Esc** closes it.
2. Drag the title bar, then resize from the bottom-right grip. `/reload` — the position and size
   come back. Repeat resizing *only* (never dragging), releasing the grip well outside the button,
   and again with the window still open when you `/reload`: both must survive.
3. The window will not shrink below the width that shows every column.
4. `/bl set settings.windowScale 1.3` rescales the open window immediately. With the Current
   Banking Session window also open (`/bl session`), **both** windows rescale together, from the
   slash path and from the Settings slider alike, with no `/reload`.

## S-8 · Filtering, grouping and sorting

1. Type in the search box — the row count in the footer falls as you type.
2. Pick two stores in the Store dropdown — both are ticked and the button reads "Store: 2 selected".
3. Click a column header to sort; click it again to reverse. Date starts newest-first.
4. Group by Store — collapsible headers appear with per-group counts. Click one to collapse it.
5. The **Sub-type** and **Quality** dropdowns list only values your data contains; Quality is
   ordered Poor→Legendary (not alphabetically) and each option carries its quality color.
6. **Type ▸ Gold** and **Sub-type ▸ Gold** appear once a gold movement is recorded, and filter to
   gold rows. Both mix freely with real item types in one multi-select.
7. The **Direction** menu shows a red ▲ Withdraw and a green ▼ Deposit; the **Store** menu shows each
   store in its column color. Both match the table exactly.
8. The window opens with **Character: Current** already applied — a fresh install, a `/reload` and
   **Clear** all land there, not on "All". `/bl test` is the exception: synthetic data opens
   unscoped.
9. Every character row and dropdown option shows its class icon and class color; "Character:
   Current" carries no icon.
10. Group by **Type**, **Sub-type** and **Quality**. Quality groups run Poor→Legendary and gold sits
    in its own "None" group.
11. **Clear** returns every filter, the grouping and the sort to their defaults.
12. **Save · Reset · Clear** sit in one cluster above **Export**, their right edges flush with it,
    and stay put as the window is widened.
13. Set a grouping, a couple of column filters and a search term, then press **Save** — a
    "view saved as your default" line appears in chat. Change the filters, press **Clear**: you land
    back on the saved view, not on stock. `/reload` and the window opens on it too.
14. Set **Character: All**, press **Save**, then `/reload` — the window still opens on **Current**.
    Character scope is never part of a saved view.
15. Press **Reset** — chat confirms, the bar returns to stock, and **Clear** now lands on stock.
    `/bl resetall` and the Settings **Defaults** button discard the saved view the same way.
16. With a view saved, `/bl test` opens the synthetic data **unscoped and unfiltered**; leaving test
    mode restores the saved view scoped back to Current.

## S-9 · Insights

1. Switch to the **Insights** tab. Fourteen stat cards populate across the top — three rows of four
   single-width cards, then a fourth row of two double-width cards (date range, busiest day) —
   hovering each one explains what it counts. There is no value or biggest-move card.
2. Every card shares one headline font size; the long date-range and busiest-day strings shrink to
   stay on one line inside their card rather than clipping or wrapping.
3. Net items and Net gold read green with a `+` when positive, red with a `-` when negative, and a
   gray dash at exactly zero.
4. **Deposits vs Withdrawals** is one back-to-back bar about a center axis, drawn the same way as
   every `× Deposits/Withdrawals` companion below it: **withdrawals grow left** in red,
   **deposits grow right** in green, and the two are scaled against the larger — the bigger
   direction fills its half exactly and the smaller is a visible proportion of it. The center line
   sits on the same vertical as the companions' axis. The counts and percentages sit in a
   **caption row below the bar** — `Withdrawals <n> · <pct>%` left-aligned in withdraw red,
   `Deposits <n> · <pct>%` right-aligned in deposit green — and stay readable even at a lopsided
   split (try filtering to a slice that is almost all one direction; the label never vanishes the
   way in-bar text used to, and the near-empty side still shows a sliver). Hovering either half
   names it and gives its exact count.
5. **Movements By Character** is class-colored and carries each class icon rendered as an actual
   icon — never a raw `|TInterface\...|t` texture path as literal text. **Movements By Character ×
   Store** below it stacks one segment per store, left-aligned, each segment hover-tipped with its
   own value and a legend beneath.
6. **Every `× Deposits/Withdrawals` companion is drawn back to back**: withdraw-red grows LEFT of a center line,
   deposit-green grows RIGHT. Check the center line falls in the **same horizontal position on every
   row** of a chart — that is the whole point of the form. A row that is mostly withdrawals visibly
   leans left; mostly deposits leans right. Hovering either half names the direction and its exact
   count. The legend reads **Withdraw then Deposit**, matching the chart left to right.
7. **Companion titles mirror their parent in full** — the companion under *Movements By Item Type*
   reads **Movements By Item Type × Deposits/Withdrawals**, not *Item Type × Deposits/Withdrawals*. Same for Store, Quality,
   Sub-type and Character.
8. **Movements By Quality** runs Poor → Legendary (not by count) in the game's own quality colors,
   immediately followed by its back-to-back companion.
9. **Item Type** and **Sub-type** bars are all visibly different colors — no two adjacent bars look
    alike — each with a legend, and each immediately followed by its own back-to-back `× Deposits/Withdrawals`
    companion whose row labels keep the parent chart's colors. A parent capped at 12 bars has a
    companion capped at 12 too.
10. The per-day strip (movements, and gold if any) shares its x-axis with the hour and weekday charts.
    Quiet days show a faint ghost bar rather than a gap; the rotated date labels thin out as the bars
    tighten and never overlap. Hovering a bar names the day and its figure. There is no value-moved
    strip.
11. **By Hour Of Day** shows all 24 buckets, including the empty ones.
12. With an enriched slice (see the Test mode scenario below), every store shows a bar, both
    directions are visible on every split chart, and the character/zone/type/quality spreads look
    visibly uneven rather than a flat comb of equal-height bars.
13. Under **TOP OF THE LIST**, a three-column grid grouped under four sub-headings:
    - **ITEMS** — Top Items By Movements, then Top Items By Quantity, each one row of three panels
      (All / Deposits / Withdrawals).
    - **CATEGORIES** — Top Type · Sub-type, one row of three panels.
    - **WHERE** — Top Banking Spots, one row of three panels.
    - **BY STORE** — a sub-section per store that has movements (Character Bank, Warband Bank,
      Guild Bank), each with its OWN row of three panels (All / Deposits /
      Withdrawals), not a single combined panel. A coin-only store has no item list and does not
      appear at all.
    A slice with no withdrawals simply has no Withdrawals column in a row — the row is not padded
    with an empty panel. Item names carry their quality color; a truncated name shows in full on
    hover. There is no Top Items By Value panel.
14. Move some gold, refresh — the **GOLD** divider and its two charts appear. With a filter that
    excludes every gold movement, that whole block disappears rather than rendering empty.
15. Apply a filter on the History tab, then switch back to Insights — every number and every bar
    reflects the same filter. The two tabs never disagree.
16. Resize the window: the cards re-flow to the new width, the bars and strips re-stretch, and the
    Top Of The List columns stay side by side.
17. With the tab open, move something at a bank — the panel updates live.
18. Purge the ledger: the cards read 0 and one centered "no movements" line replaces every section.

## S-10 · Export

1. On History, click **Export** → choose **Current View** → **Export to CSV**.
2. The copy window opens with the text pre-selected in a monospace font. Ctrl+C copies it; Esc
   closes it.
3. The row count matches what the table showed.
4. The last column is `wowhead`. Open the URL from a **gear** row: the page must show the item at the
   item level and with the sockets/tertiaries the piece you moved actually has — that is the
   `?bonus=…` list doing its job. A stackable trade good has no bonuses, so it is a plain
   `item=<id>` URL, and a gold row's cell is empty. Use a row recorded **after** this build: rows
   captured earlier stored the base link, so their URL resolves to the base item.
5. Repeat on the **Insights** tab — the CSV is the sectioned summary, not raw rows.

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
2. The landing page shows the **logo**, the tagline and every slash command. The logo must actually
   be there and be crisp — a missing texture draws nothing and raises no error, so blank is a real
   failure mode, and a soft or jagged one means the `.tga` was regenerated at the wrong size (it
   must be a power of two; see ARCHITECTURE ▸ Logo art).
3. General and Filters both render a breadcrumb header, a gold divider and a Defaults button. The
   Defaults button looks like every other button on the page — if it renders as Blizzard's red
   stone button, it was built before a UI skin hooked AceGUI (`/bl debug panel` shows the region
   list; the bare 5-region `130828` form is the unskinned one).
   General's sections read **Master Controls** (enable, minimap, session window, debug console,
   window scale + Reset all), then **Capture** (quality, retention, item/gold toggles, per-store
   grid), then **Storage**. Master Controls' four checkboxes pair two to a line — *Enable capture ·
   Hide minimap button* on the first, *Session window · Debug console* on the second — with no
   ragged single-column gap between them.
4. Toggle a checkbox, then run `/bl list` — the value matches.
5. `/bl set settings.trackMoney false`, then reopen the panel — the checkbox reflects the change.
6. The scrollbar is visible on both pages and grayed out on the one that fits, so the body width
   does not jump between them.
7. **Blizzard's own defaults control** (the Settings window's footer, not the addon's header button)
   reaches the addon: on General, change a setting, then use it — the settings return to stock and
   the ledger is untouched (`/bl` reports the same entry count as before). Headless coverage stops at
   the callback contract; only the live client proves the framework actually invokes it. On Filters
   the same control raises the clear-both-lists confirmation, exactly as the header button does.

## S-13 · Combat

1. Pull a training dummy.
2. `/bl config` prints a gray "cannot open settings during combat" notice and does **not** open.
3. Leave combat. The panel does **not** pop itself open — you re-run `/bl config` when you choose.
4. The ledger window still opens, refreshes and filters in combat (it is a non-secure frame).

## S-14 · Debug console

1. `/bl debug` opens the console. The header reads **Debug: OFF** in red.
2. `/bl debug on` → a green ON ack in chat, a `[Debug] logging enabled` line and an `[Init]` summary
   naming the build, schema and profile.
3. Move something to your bank → one `[Move]` summary line per pass, not one per item.
4. The scrollbar tracks the wheel both ways, and the counter reads `N / 500 lines`.
5. **Copy** opens a monospace box with the plain, color-code-free log. **Clear** empties both and
   resets the counter to `0 / 500`.
6. `/bl debug off` → a red OFF ack and a `[Debug] logging disabled` line.
7. `/reload` → logging is off again, because the flag is session-only.
8. **Chrome.** The console and the **Copy** box wear the same edge as the ledger window — a flat 1px
   black border with a 1px light-gray line just inside it, a gold title, a gray divider — but they
   close with a **thin ×**, not the big class-colored one. That is correct, not drift: the edge is
   shared across every Ka0s window, the close control on a library-drawn window is the library's
   (standalone-windows). The ledger window's own 24×24 glyph is unchanged — check it too.
9. Open another Ka0s addon's debug console alongside this one. Apart from their titles the two must
   be **indistinguishable**: same border, same inner highlight, same gold title, same divider, same
   close ×. Any difference means the shared edge has drifted in one of them, and the fix belongs in
   `../LibKa0s`, never in `libs/`.

## S-15 · Test mode

1. `/bl test` opens the window on a sample ledger with a red **TEST MODE** badge by the title.
2. The filters, grouping, Insights and export all work against it.
3. The dataset reads as a real bank's history, not a uniform grid: character-bank rows dominate,
   warband is mid-weight and the guild bank lightest; roughly 60/40 deposit-leaning; about
   eight characters across distinct classes with two or three clear "mains"; six real bank-city
   zones; a hot-item head over a long tail in the Top Items lists; an evening-leaning hour-of-day
   curve; every store, both directions and every quality 0–5 appear at least once; the date range
   spans more than 14 days.
4. Right-click a sample row. **Link to chat** is available; **Blacklist item**, **Whitelist item**
   and **Delete** are grayed out and click-inert. The sample rows carry synthetic item ids, so those
   three would otherwise reach the real filter lists and the real ledger.
5. `/bl config` ▸ **Filters** — both lists are unchanged by anything done in step 4.
6. `/bl test` again returns to the real data and the badge disappears. Right-click a real row: all
   four entries are now available, and **Delete** removes the row and decrements the footer count.

## S-16 · Retention and purge

1. `/bl set settings.retentionDays 7`, then `/reload`. Entries older than 7 days are gone.
2. `/bl purge` asks to confirm; accepting empties the ledger and the window shows its empty state.
3. Settings ▸ General ▸ **Reset all** asks to confirm and restores everything, recentering both
   windows.

## S-17 · Current Banking Session window

1. Open your character bank. A second window titled **Ka0s Bank Ledger - Current Banking Session**
   appears alongside it, empty, reading "Nothing has moved yet this session."
2. It has no tabs, no filter bar, no search, no Clear, no Export and no footer. Its columns are
   Direction, Store, Item, Qty, Quality, Type and Sub-type — no Date, no Time, no Character.
3. Clicking a column header does nothing. Hovering one still shows that column's explanation.
4. Deposit something. A row appears **immediately**, colored exactly as the same movement reads in
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
12. Repeat steps 1–5 at the **warband** tabs and at a **guild bank**. Both drive the same window.
13. **Guild bank close, specifically.** The guild bank fires no close event, so its session ends on
    the frame's own `OnHide`. Open the guild bank, move something, then close it **without touching
    your bags afterwards** — the session window must disappear *immediately*, not on your next bag
    change. If it lingers, `/bl debug scan` will say `guild bank close hook: NOT INSTALLED`.
14. **Geometry across a game session.** Move and resize the window, close the bank, then `/reload`.
    Open a bank again: it comes back at the size and position you left it, with no rows. Repeat
    logging in on a **different character** — the geometry is account-wide, so it follows you.
    Do it once more resizing *only* (never dragging), and once more with the window still on screen
    when you `/reload`: both must survive. Session *data* is never persisted; only the geometry is.
15. Settings ▸ General ▸ untick **Session window**. Open a bank — no window appears, but the
    movements you make are still recorded (check the History window). Tick it again while a bank is
    open and it appears on the next movement; untick it while it is open and it closes at once.
16. Away from any bank, `/bl session` opens it on a sample visit so it can be positioned. Run it
    again to dismiss it. While a real bank session is open, `/bl session` refuses and says so rather
    than replacing your actual data with placeholders.

## S-18 · LibKa0s — the degraded install

The four LibKa0s seams (`core/CoreSetup.lua` today, more as modules are adopted) each degrade
rather than error when the vendored library is absent. Nothing headless can prove what the client
actually draws, and an install missing `libs/LibKa0s` is exactly the install those branches exist
for.

1. Quit the game. Rename `Interface/AddOns/BankLedger/libs/LibKa0s` to `libs/LibKa0s.off`.
2. Log in. **Zero Lua errors.** Not one — turn error display on (`/console scriptErrors 1`) first.
3. `/bl version` prints two lines: the notice, then `[BL] v1.0.0`. The notice reads, exactly:

   > `[BL] The LibKa0s library is missing from this installation of Ka0s Bank Ledger (expected in
   > libs/LibKa0s); running on reduced built-in fallbacks.`

   The cause clause — everything up to and including `(expected in libs/LibKa0s)` — is shared with
   every other Ka0s addon that bundles LibKa0s. If it does not match theirs word for word, that is
   the finding.
4. `/bl version` again. The notice is **not** repeated. It is said once per session, on the first
   line the addon prints, never stapled to every line.
5. `/bl list` prints a **complete** listing — every schema row, both group headings, no gaps and no
   truncation. A degraded printer that drops lines is the failure this step exists to catch.
6. `/bl show`, `/bl config`, `/bl debug` — the ledger window, the settings panel and the console all
   open and behave. Nothing about the addon's own function depends on the library.
7. Quit, rename `libs/LibKa0s.off` back to `libs/LibKa0s`, log in. The notice is gone and `/bl list`
   is byte-for-byte what it was in step 5.

**Rename the folder back before you finish.** A repo left in the degraded state passes its own gate
and ships broken.

## S-19 · LibKa0s — no raw locale keys on screen

The library modules resolve their user-visible strings through the descriptor's `L` table first.
Handing one an addon-wide locale table makes every key resolve to *itself*, so the addon renders
`DEBUG_ON` and `LIST_HEADER` in place of English — for every string at once, and only in game. The
headless source guard cannot see what the client draws.

1. Walk **every** settings page: the landing page, General, Filters.
2. Open the debug console (`/bl debug`) and toggle it on and off.
3. Run `/bl help`, `/bl list`, `/bl get settings.enabled`, `/bl reset settings.enabled`.
4. Nothing on screen or in chat is `SCREAMING_SNAKE_CASE`. Every label is prose. One raw key means
   a descriptor was handed `NS.L`, and it means all of them are wrong, not just the one you spotted.

## S-20 · A slash write repaints the open settings window

options-ui-§11: an open panel must reflect live state after a mutation, including a slash `set`. It
did not, from v1.0.0 until this was fixed — the value was written correctly and the widget kept
showing the old one until the window was closed and reopened. Nothing headless can see a widget
redraw, so this is the only place the fix is actually observable.

1. `/bl config`, then open **General**. Leave the window on screen for every step below.
2. `/bl set settings.enabled false` — the **Enable capture** checkbox unticks **immediately**, with
   the settings window still open and still on the General page. Set it back to `true`.
3. `/bl set settings.windowScale 1.25` — the **Window scale** slider moves at once.
4. `/bl set settings.windowScale 9` — the slider lands on its maximum (1.60), because the CLI now
   clamps. The chat echo says `1.60x`, and the slider agrees with it.
5. `/bl reset settings.windowScale` — the slider returns to 1.00.
6. `/bl resetall` — every General widget repaints, and the **Database size** line under it updates.
   It should repaint **once**, not flicker per row.
7. Switch to the **Filters** page, add an item id, then `/bl resetall` — the id list empties while
   you watch. (This path was already correct: the lists are structural and ride `LedgerChanged`.)
8. Move to the **Filters** page and run `/bl set settings.enabled false` there. Nothing on Filters
   should flicker — only the page you are looking at does work.
9. Close the settings window entirely and run `/bl resetall` again. No errors, and reopening shows
   the reset values.
