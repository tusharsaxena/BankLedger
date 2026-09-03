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

1. Right-click a ledger row → **Blacklist item**. The chat line reads
   `[BL] blacklisted <name>. Manage in Settings ▸ General ▸ Filters ▸ Blacklist.` — it must name the
   **tab and its sub-tab**, not the deregistered *Filters* page and not the retired top-level
   *Blacklist* tab. Whitelisting names **General ▸ Filters ▸ Whitelist**.
2. Move that item to your bank again — **no** new row is recorded, and the row you clicked is still
   there (blacklisting is point-in-time, it never rewrites history).
3. Open Settings ▸ General ▸ **Filters** ▸ **Blacklist** — the id is listed with its item name.
   Remove it.
4. Add an id by shift-clicking an item link into the Add box.
5. Whitelist an item, set the minimum quality to Epic, and move the whitelisted item — it is still
   recorded.
6. **Defaults** on the General page clears both lists (along with every setting) after a confirm.
   There is **no Filters page** in the sidebar any more — an entry still listed there would be one
   opening onto nothing.

## S-12 · Settings panel

1. `/bl config` opens the panel with the addon's entry already present in the list.
2. The landing page shows the **logo**, the tagline and every slash command. The logo must actually
   be there and be crisp — a missing texture draws nothing and raises no error, so blank is a real
   failure mode, and a soft or jagged one means the `.tga` was regenerated at the wrong size (it
   must be a power of two; see ARCHITECTURE ▸ Logo art).
3. General renders a breadcrumb header, a gold divider and a Defaults button. The
   Defaults button looks like every other button on the page — if it renders as Blizzard's red
   stone button, it was built before a UI skin hooked AceGUI (`/bl debug panel` shows the region
   list; the bare 5-region `130828` form is the unskinned one).
   The page is **tabbed** (`options-ui-§13`): a strip pinned under the header, above the scroll,
   with no section heading repeating a tab's own name — the tab is the heading. The strip reads
   **Master controls · Capture · Interface · History · Filters**, in that order, and
   **Master controls** is selected when General first opens. Those names and that order are shared
   with **Ka0s Loot History**, whose strip is the same five plus **AH Price** after Capture — open
   both panels side by side and check they agree, because that agreement is the point.
   - **Master controls** — *Enable Bank Ledger · General visibility*, then *Master scale · Master
     alpha*, then *Lock frame · Debug console*, then **Reset position** and **Reset all settings**
     side by side. Exactly that order, three full lines and the button pair; no row may be renamed,
     reordered or missing. Drag **Master alpha** to its far left: it bottoms out at **0.10**, not 0,
     and the windows visibly fade to that and no further — the row's declared minimum IS the floor
     `NS.Util.ApplyMasterFrame` draws at, so no stop on the slider is one the drawing code refuses.
     **Reset all settings** raises a confirm popup and, on Yes, discards **the recorded ledger too**;
     `/bl resetall` and the header **Defaults** button are a different, non-destructive act (see
     ARCHITECTURE ▸ Documented deviations, `options-ui-§12`).
   - **Capture** — *Track items · Track gold*, then *Minimum quality*, then the full-width per-store
     grid.
   - **Interface** — a **Windows** heading over *Hide minimap button · Session window*, then a
     **Table rows** heading over *Row stripe opacity · Row hover opacity*. Both headings must be
     there (this tab mixes two kinds of control, `options-ui-§7`), and neither may read
     "Interface". The two opacity sliders must be side by side on one line, not stacked.
   - **History** — *Keep history for*, then the storage read-out ("N movements recorded over N
     days" and the estimated database size), then **Purge ledger…** alone. There must be **no**
     *Reset all* button on History, Interface or Capture — there is exactly one in the panel and it
     is on Master controls.
   - **Filters** — a **secondary** strip inside the scroll (it scrolls with the content, and there
     is no second pinned chrome band), reading **Blacklist · Whitelist**, opening on Blacklist. The
     selected list shows its own blurb, its own add box and its own **Clear all**, and never both
     lists at once — one add box on screen, not two. Click Whitelist, leave for **Capture**, come
     back: Filters is still on **Whitelist** (the sub-selection is per-tab session state). Reload:
     it opens on Blacklist again, because none of it is persisted.
   Click each tab in turn and then click back: the store grid, the read-out, the reset pair and both
   id lists must still be there. They are drawn from the tab's `afterGroup` hook precisely so that a
   second visit redraws them; anything drawn by the page body instead would survive exactly one
   render.
4. Toggle a checkbox, then run `/bl list` — the value matches.
5. `/bl set settings.trackMoney false`, then reopen the panel — the checkbox reflects the change.
6. The scrollbar is visible on both pages and grayed out on the one that fits, so the body width
   does not jump between them.
7. **Blizzard's own defaults control** (the Settings window's footer, not the addon's header button)
   reaches the addon: on General, change a setting, then use it — the settings return to stock, both
   id lists are cleared and the ledger is untouched (`/bl` reports the same entry count as before).
   Headless coverage stops at the callback contract; only the live client proves the framework
   actually invokes it.

## S-12a · The row tint sliders

Two settings that were hardcoded numbers until the tabbed-panel pass: `settings.rowStripeAlpha`
(the zebra band behind every second row, `0.03`) and `settings.rowHoverAlpha` (the gold wash under
the cursor, `0.10`). Both live on **Settings ▸ General ▸ Interface** and both drive **two** tables —
the History window and the Current Banking Session window.

1. `/bl show` with a few movements recorded. Every second row carries a faint lighter band. Hover a
   row: it takes a faint gold wash. That is the shipped look, and it must be **identical** to what
   the addon drew before these sliders existed — the defaults are the literals they replaced, so an
   install that never touches them is not redrawn by the upgrade.
2. Open Settings ▸ General ▸ Interface with the ledger window still on screen. Drag **Row stripe
   opacity** to its maximum. The banding darkens **while you drag**, with no reload.
3. Drag it to `0`. The banding disappears entirely — every row reads the same.
4. Drag **Row hover opacity** to its maximum, then hover a row: the wash is strong and unmistakably
   gold. Set it to `0` and hover again: no highlight at all.
5. Open a bank so the **Current Banking Session** window appears, and move something. Its rows wear
   the same band and the same hover at the same strengths — one setting, both tables.
6. `/bl set settings.rowStripeAlpha 5`. The CLI clamps to the slider's maximum; the table is tinted
   at that value and never drawn as an opaque white block. Same for a negative value: it clamps to
   `0`. (These come out of SavedVariables, so a hand-edit is the real case.)
7. `/bl resetall`, then look again: `0.03` and `0.10`, and the tables read exactly as in step 1.

## S-12b · Master controls — the three rows the revamp added

`General visibility`, `Master alpha` and `Lock frame` are new settings, not relabelled old ones.
Nothing headless can prove a frame is actually dimmed, undraggable or gone, so this is the only place
these are observable. All three are on **Settings ▸ General ▸ Master controls**.

1. `/bl show`. Drag **Master alpha** down to about a quarter: the ledger window fades **while you
   drag**. Open a bank so the **Current Banking Session** window appears — it is faded to the same
   degree. Open **Export** from the filter bar: the modal matches too. All three read one setting.
2. Set **Master alpha** to its minimum. The windows are faint but still findable and still
   clickable — never fully invisible. (`0` is clamped to `0.1` at the read for exactly that reason.)
   Put it back to `1.00`.
3. Tick **Lock frame**. Try to drag the ledger window by its title bar: it does not move. The session
   window and the export modal are equally stuck. Untick it — all three drag again.
4. Move the ledger window well off centre, drag the session window somewhere odd, then click **Reset
   position**. Both snap back to centre at their default size. Nothing else changes — your settings,
   your filter lists and your recorded history are all untouched. (The page's **Defaults** button
   does this too, as part of a wider reset; this button does *only* this.)
5. Set **General visibility** to **Never**. Every window closes. `/bl show` does nothing — the addon
   refuses rather than deferring. Capture keeps running: move something into your bank, set
   visibility back to **Always**, and the movement is in the ledger.
6. Set **General visibility** to **Only out of combat** with the ledger window open, then pull a
   training dummy: the window hides on the pull and comes back when you leave combat.
7. Repeat step 6 with the ledger window **closed**. It must stay closed through both edges — the
   rule puts back only what it took, never a window you had closed yourself.
8. Set **General visibility** to **Only in combat** and confirm the mirror image: hidden out of
   combat, shown on the pull. Set it back to **Always** when you are done.

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
4. The scrollbar tracks the wheel both ways, and the counter reads `N / 1500 lines`.
5. **Copy** opens a monospace box with the plain, color-code-free log. **Clear** empties both and
   resets the counter to `0 / 1500`.
6. `/bl debug off` → a red OFF ack and a `[Debug] logging disabled` line.
7. `/reload` → logging is off again, because the flag is session-only.
8. **Chrome.** The console and the **Copy** box wear the same edge as the ledger window — a flat 1px
   black border with a 1px light-gray line just inside it, a gold title, a gray divider — but their
   close control is **smaller** (18×18 on a 26px title bar) than the ledger window's 24×24. That is
   correct, not drift: the edge is shared across every Ka0s window, the close control on a
   library-drawn window is the library's (standalone-windows). Both should now show the same
   **×-in-outline mark** rather than a font character — see S-21.
9. **The title bar draws three marks, right to left: close, clear, copy** — one size (18×18), one
   pitch, gray at rest and brighter under the pointer, and the same art every other Ka0s window
   uses. **Words there (`Copy`, `Clear`), or a thin multiplication sign where the close mark should
   be, mean `core/DebugLogSetup.lua` stopped passing `addonName`** — or the art is missing from the
   vendored payload. The library falls back to the words and the console keeps working, which is
   exactly why nothing errors to tell you. The measurement gives it away too: with the marks, clear
   is 18 wide and copy sits at `-54`; with the word, clear is 42 wide and copy slides out to `-78`.
10. **Hover copy and clear: each brightens, and NOTHING pops up.** They carried a tooltip for one
    release; anchored under the control, it covered the first line of the log, and it was removed
    rather than repositioned. A tooltip reappearing on either of them is a **regression**, not a
    nicety. The same goes for the close mark, here and on the **Copy** box.
11. **The log body is still monospace.** Timestamps and the `[Tag]` prefixes line up in a straight
    column down the left edge, and so do the numbers in a `[Move]` summary. **Proportional text
    there means the font seam fell through** — `NS.MediaFont("JetBrains Mono")` answered nil and
    `C.FONT_MONO` took `STANDARD_TEXT_FONT` instead. Either `LibKa0s-Media-1.0` is not loaded, or
    `core\\MediaSetup.lua` slipped after `core\\Constants.lua` in the TOC. It is readable, so
    nothing complains; the ragged left column is the only symptom. Check the **Copy** box too.
12. Open another Ka0s addon's debug console alongside this one. Apart from their titles the two must
    be **indistinguishable**: same border, same inner highlight, same gold title, same divider, and
    the same three marks in the same order. Any difference means the shared edge has drifted in one
    of them, and the fix belongs in `../LibKa0s`, never in `libs/`.

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
5. `/bl config` ▸ **General** ▸ **Filters** ▸ **Blacklist** / **Whitelist** — both lists are unchanged by
   anything done in step 4.
6. `/bl test` again returns to the real data and the badge disappears. Right-click a real row: all
   four entries are now available, and **Delete** removes the row and decrements the footer count.

## S-16 · Retention and purge

1. `/bl set settings.retentionDays 7`, then `/reload`. Entries older than 7 days are gone.
2. `/bl purge` asks to confirm; accepting empties the ledger and the window shows its empty state.
3. Settings ▸ General ▸ **Master controls** ▸ **Reset all settings** asks to confirm and restores
   everything, recentering both windows and discarding the recorded ledger with them. It sits beside
   **Reset position** in that tab's closing button pair, and nowhere else — History carries
   **Purge ledger…** alone (S-12).

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
13. **Guild bank open and close, specifically.** The guild bank fires neither event, so its session
    starts on the frame's own `OnShow` and ends on its `OnHide`. Open the guild bank — the session
    window must appear, and `/bl debug` must show `[Store] GUILD_BANK opened` with a **non-zero**
    baseline for the `GUILD_BANK` store once the tab queries land. Move something and confirm the
    row. Then close it **without touching your bags afterwards** — the window must disappear
    *immediately*, not on your next bag change. If either half misbehaves, `/bl debug scan` will say
    `guild bank frame hooks: NOT INSTALLED`.
14. **No session away from a bank** (issue #12). `/bl debug on`, then `/reload` while standing
    somewhere with no bank in sight, and leave the character parked for a few minutes — ideally
    while a guildmate moves something in the guild vault. No session window may appear, and the log
    must show **no** `[Store] GUILD_BANK opened` line. A `GUILD_BANK opened` with a baseline of
    `GUILD_BANK 0` is the exact signature of the regression.
15. **Geometry across a game session.** Move and resize the window, close the bank, then `/reload`.
    Open a bank again: it comes back at the size and position you left it, with no rows. Repeat
    logging in on a **different character** — the geometry is account-wide, so it follows you.
    Do it once more resizing *only* (never dragging), and once more with the window still on screen
    when you `/reload`: both must survive. Session *data* is never persisted; only the geometry is.
16. Settings ▸ General ▸ untick **Session window**. Open a bank — no window appears, but the
    movements you make are still recorded (check the History window). Tick it again while a bank is
    open and it appears on the next movement; untick it while it is open and it closes at once.
17. Away from any bank, `/bl session` opens it on a sample visit so it can be positioned. Run it
    again to dismiss it. While a real bank session is open, `/bl session` refuses and says so rather
    than replacing your actual data with placeholders.

## S-18 · LibKa0s — the degraded install

The eight LibKa0s seams (`core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `core/EnvSetup.lua`,
`core/ItemSetup.lua`, `core/MediaSetup.lua`, `core/PoolSetup.lua`, `settings/OptionsSetup.lua` and
`settings/Slash.lua`) each degrade rather than error when the
vendored library is absent. Nothing headless can prove what the client
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
5. `/bl list` prints a **complete** listing — every schema row under all three group headings
   (*Capture*, *Interface*, *History*, in that order), no gaps and no truncation. A degraded printer
   that drops lines is the failure this step exists to catch.
6. `/bl show`, `/bl config`, `/bl debug` — the ledger window, the settings panel and the console all
   open and behave. Nothing about the addon's own function depends on the library.
7. **The Media seam is the silent one.** With the library gone, `NS.Icon` and `NS.MediaFont` both
   answer `nil`, and nothing errors either way. Every mark falls back to the rung below it (S-21
   step 10 is the full list), and every monospace surface falls back to `STANDARD_TEXT_FONT`: the
   debug console, the **Copy** box, the direction ▲/▼ column in History and the same glyph in the
   session window. The console's log goes proportional and the ▲/▼ render as **boxes**. All of that
   is correct in this state and a **bug** in a healthy install — if you see a box or a
   proportional log with `libs/LibKa0s` in place, the seam is broken, not the client.
8. Quit, rename `libs/LibKa0s.off` back to `libs/LibKa0s`, log in. The notice is gone and `/bl list`
   is byte-for-byte what it was in step 5. Re-check the console: monospace again, and the three
   marks back on its title bar.

**Rename the folder back before you finish.** A repo left in the degraded state passes its own gate
and ships broken.

## S-19 · LibKa0s — no raw locale keys on screen

The library modules resolve their user-visible strings through the descriptor's `L` table first.
Handing one an addon-wide locale table makes every key resolve to *itself*, so the addon renders
`DEBUG_ON` and `LIST_HEADER` in place of English — for every string at once, and only in game. The
headless source guard cannot see what the client draws.

1. Walk **every** settings page and every tab of General: the landing page, then Master controls,
   Capture, Interface, History, and Filters (both of its sub-tabs).
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
2. `/bl set settings.enabled false` — the **Enable Bank Ledger** checkbox on **Master controls**
   unticks **immediately**, with the settings window still open. Set it back to `true`.
3. `/bl set settings.windowScale 1.25` — the **Master scale** slider moves at once, and both the
   ledger and session windows rescale.
4. `/bl set settings.windowScale 9` — the slider lands on its maximum (2.00), because the CLI
   clamps. The chat echo says `2.00x`, and the slider agrees with it.
5. `/bl reset settings.windowScale` — the slider returns to 1.00.
6. `/bl resetall` — every General widget repaints, and the **Database size** line on History
   updates. It should repaint **once**, not flicker per row.
7. Switch to **Filters ▸ Blacklist**, add an item id, then `/bl resetall` — the id list empties while
   you watch. (This path was already correct: the lists are structural and ride `LedgerChanged`.)
8. Close the settings window entirely and run `/bl resetall` again. No errors, and reopening shows
   the reset values.

## S-21 · The shared marks

The one failure mode nothing headless can see. A texture that does not load draws **nothing** and
raises **nothing** — no error, no log line, no red suite. Every assertion in `tests/test_marks.lua`
is about the path and the argument; this is where somebody actually looks at the window.

1. `/bl show`. The title bar's close control is an **outlined ×**, not a font character: thinner,
   evenly weighted, and the same shape you see on every other Ka0s window. Hover it — it takes your
   class color, exactly as the old glyph did. Click it; the window closes.
2. Reopen, then check the other three title bars the same way: `/bl session`, then **Export**, then
   **Export to CSV** on the modal. All four wear the same mark, because all four go through
   `B:MakeCloseButton`. A window whose × still looks like a font character means one of them stopped
   using that factory. The **debug console** and its **Copy** box are the two windows this factory
   does *not* draw — they are the library's, and S-14 steps 9–11 are where you check them.
3. **Every dropdown on the filter bar** ends in a **chevron**, not Blizzard's filled arrow — that is
   eight today: **Group by** on row 1, then Date, Direction, Store, Quality, Type, Sub-type and
   Character on row 2. Count them; Group by is the one a "seven filters" habit skips. The modal's
   **Data set** dropdown makes nine — it is the same factory.
   Open any MULTI-select one (Store, Type, Quality, Character) and pick two values. Each chosen row
   is prefixed by a **flat white tick**, the same weight as the chevron on the button above it — not
   Blizzard's beveled `UI-CheckBox-Check`. A beveled tick means the `confirm` path this addon hands
   `LibKa0s-Widgets-1.0` through `B:MakeDropdown` stopped resolving and fell to its rung, which is
   the same art the menu used before the marks landed.
   **The tick is FULL WHITE and that is correct** — it is the one inline mark left untinted, because
   the menu row beside it is plain white text with no colour for it to match. It reads a shade
   brighter than that label. Recorded in [media.md](media.md); not a regression to file.
4. Click a **column header** in History. The sort arrow beside the label is a chevron-weight
   **sort-up / sort-down** mark, and it flips when you click again. Group by **Day**: each group
   header now opens with a **chevron**, right when collapsed and down when expanded, where it used
   to be Blizzard's boxed `+` / `-`. Click one; the chevron turns.
   **All four are the SAME GOLD as the words they sit beside** — the arrows against the column
   label, the chevrons against the group label, both of which are drawn in 1/0.82/0. Hold your eye
   on each pair: a near-white mark against a gold word means the vertex-colour tail came off the
   inline escape, and it is the one failure in this section that still draws, still sizes and still
   points the right way. Check the group chevron as carefully as the arrow — it is drawn in a
   different function and is the half that gets forgotten. The gray `(count)` on the same line is
   *not* gold and is not part of this check. Every mark drawn on a *widget* — close, the dropdown
   chevron, the magnifier, the modal's export mark — is toned to 0.7–0.85 gray instead.
5. **The filter bar carries no marks at all** — **Export**, **Save**, **Reset** and **Clear** are
   four plain centred words. Export used to wear one and does not any more: one marked button in a
   row of four read as an odd one out. A mark that has come back on any of them is a regression.
   **Export to CSV** in the modal is the one action button that keeps its mark: a small mark on its
   LEFT with the words still **centred** — not shifted. If the words have moved off centre, the
   label was anchored to the art instead of to the button.
   **Measure the modal's button against the Data set dropdown directly above it.** It must be about
   *two-fifths* as wide and centred under it, with the mark and the words close enough to read as one
   control. If it spans the modal edge to edge like the dropdown does, its 150px width was overridden
   by a left-and-right anchor pair — the mark is then pinned at the far-left edge with the label
   floating ~150px away, which reads as an unrelated decoration rather than as a mark BESIDE a label.
6. The search box shows a **magnifier** on its left, with "Search items…" starting just past it. Type
   into it — your text starts in the same place, not under the magnifier.
7. **Hover every mark in turn.** None of them shows a tooltip of its own. The four filter-bar buttons
   still show *their* tooltips, which is not the same thing.
8. **The settings panel has no marks at all** — `/bl config`, every page. Its widgets belong to
   `LibKa0s-Options-1.0`; a mark that has appeared there came from the wrong side of the seam.
9. **The degraded pass.** Rename `libs/LibKa0s` aside and `/reload`. **The filter bar refuses to
   build entirely** — none of its eight dropdowns appear, and the chat line reads "Filters need
   LibKa0s. The ledger itself is unaffected." The History table underneath still works and is still
   usable with no filters. Every surface not on that bar must still draw *something*: the
   font-character ×, its `Arrow-Up-Up` sort arrows and its boxed `+`/`-` group expanders.
   **The four header marks are GOLD on this rung too** —
   the tint rides on the escape rather than on the art, so a gold `Arrow-Up-Up` and a gold boxed `+`
   are correct here; a near-white one means the fallback path lost the tail the resolved path keeps.
   Nothing blank, nothing off-centre, no error.

   **The export modal is NOT on this rung, and that is not a gap in the check.** This step used to
   ask for "**Export to CSV** with its words and no art", and it could not be performed: the
   **Export** button lives on the filter bar, the filter bar refuses to build, so nothing in the
   client can call `NS.Export:Open` and the modal never exists. Confirm the *absence* instead — no
   **Export** button anywhere, no way to reach the modal — and check the modal's own marks on the
   healthy rung, at steps 2 and 5. `tests/test_export.lua` covers what the modal does if it is ever
   opened on this rung anyway: it draws no **Data set** dropdown rather than a dead one, and it does
   not raise. Put the folder back.

## S-22 · LibKa0s-Widgets-1.0 — the shared dropdown menu

S-21 checks the *art* on the dropdowns. This section checks the *menu*, which is a different thing
and a shared one: `LibKa0s-Widgets-1.0` drops **one** popup frame for every dropdown in the client,
parented to `UIParent` at `FULLSCREEN_DIALOG` and outliving any window that opened it. Nothing
headless can reach it — the addon is handed no reference to it, only `W.CloseMenu()`.

1. **The first click opens the menu.** `/bl show`, then click **Store** as the very first dropdown
   you touch after logging in. The menu drops. This is the check for the crash v1.11.0 and v1.11.1
   of the library shipped: the *first* click built the row pool, and building a row raised
   `FontString:SetText(): Font not set` before anything appeared. A second click is not a substitute
   — by then the pool exists. If it drops, click **Direction** too: its rows carry the ▲/▼ glyph,
   which is the row field that was crashing, and it must be a **glyph and not a box**.
2. **Escape closes the window AND the menu.** Open **Store**'s menu and, with it still open, press
   Escape. The ledger window closes *and the menu goes with it*. A menu left floating over the game
   with no window behind it is the failure: `modules/Browser.lua`'s `OnHide` hook missed its
   `W.CloseMenu()`. Do the same on the **export modal**: **Export**, open the **Data set** menu,
   press Escape — modal and menu both go. Then reopen the modal, open the menu again and click the
   modal's **×**: same result. That close button and Escape are the two routes
   `modules/Export.lua`'s `OnHide` hook covers.
3. **A slash-command close closes the menu.** Open the ledger, open any filter menu, and type
   `/bl hide` in chat with the menu still open. The window closes *and the menu goes with it* —
   `/bl hide` lands on `B:Hide`, which calls `W.CloseMenu()` itself. Repeat with `/bl toggle` on an
   open window: it hides the frame, the `OnHide` hook fires, and the menu goes the same way.
   `/bl show` is **not** a toggle in this addon — it re-shows an already-open window and closes
   nothing, so it is not the verb to use here. No other slash verb closes the ledger, and no other
   window owns one of these menus: the session window (`/bl session`) has no `LibKa0s-Widgets-1.0`
   dropdown, so a filter menu left open while it closes stays open, correctly.
4. **Two dropdowns do not fight.** Open **Store**'s menu, then — without closing it — click
   **Character**. The Store menu closes and the Character menu opens in its place; exactly one menu
   is on screen, the way a native game menu behaves. Then open **Export** on top of the ledger
   window, open the modal's **Data set** menu, and click somewhere in the ledger window behind it:
   the menu closes **and the click lands** on whatever in the ledger window sits under the cursor,
   in that same press. Right-click there instead and the same holds: the menu goes, and the
   right-click reaches what is under it. *(Changed at LibKa0s v1.13.0, Widgets minor 5. The menu
   used to be dismissed by a full-screen `Button` shown alongside it, which intercepted the press —
   so closing the menu cost a click that did nothing else. That `Button` registered `LeftButtonUp`
   and nothing else, so a right-click anywhere while a menu was open landed on it, found no handler
   and went nowhere at all. The catcher is gone; two presses where one should do is now a
   regression.)*
5. **A collapsed multi-select names a filter it can no longer list.** *(New at LibKa0s v1.12.0,
   Widgets minor 4 — this is a deliberate change to what the button says.)* Filter History to a
   single item **Type** that only one character owns, press **Save**, then switch to a character
   with none of it (or `/bl test` and back) so today's dataset no longer contains that type. The
   **Type** button reads the **type's own name**. It used to read **"Type: All"** while the filter
   was still on — the old label walked the option list, and a selected value with no row in it was
   invisible. The filter itself has not changed and the row count is the same as before; only the
   words on the button. **"Type: All" on a bar that is visibly filtering is now the regression.**
   The same applies to **Store**, **Quality** and **Sub-type**. It cannot happen to **Character**:
   that list always carries its **All** and **Current** rows, whatever the data holds.

## S-23 · The Item seam, and the refusal it did not take with it

`core/ItemSetup.lua` moved four primitives to `LibKa0s-Item-1.0` and left the **resolver** in
`core/Compat.lua` on purpose. Two things need a client to see: the seam resolves before
`core/Constants.lua` builds its quality labels at file load, and the capture gate still **refuses**
an item it cannot classify. Neither is visible headlessly — the first is a load-order accident that
only a real login can produce, the second needs an item the client has genuinely not cached.

1. Log in with error display on (`/console scriptErrors 1`). **Zero Lua errors.** A nil-index in
   `core/Constants.lua` here means `core\ItemSetup.lua` has slipped below `core\Constants.lua` in
   the TOC.
2. `/bl config` → **General** ▸ **Capture**. The **Minimum quality** dropdown lists six rows, each the quality's
   own name in its own colour followed by " and above": *Poor*, *Common*, *Uncommon*, *Rare*,
   *Epic*, *Legendary*. A row reading a bare number, or a row with no colour, is the seam failing.
   On a non-English client the names are the client's own, never English.
3. `/bl show` — the **Quality** column and the Quality filter still read the same words they did
   before this change, and `/bl export` writes the same quality names into its rows.
4. **The refusal survives (F-006).** Set Minimum quality to *Rare*. Move an item the client has not
   cached this session — the reliable way is `/reload` and then immediately move something unusual
   from a bank tab you have not opened. `/bl debug` shows the movement recorded as skipped with
   cause `uncached`, **not** captured and **not** guessed at from the link's colour. The addon also
   asks the client to cache the id, so repeating the same movement a few seconds later judges it
   properly and either captures it or skips it on quality. A row that appears immediately at a
   quality nothing resolved is the regression this step exists to catch: that is LootHistory's
   policy, and it is wrong here.

## S-24 · The copy window is LibKa0s-Widgets-1.0's

`modules/Export.lua` no longer builds a frame for the export copy window; it passes a descriptor to
`Widgets.CopyWindow`. Focus, selection and the Esc binding are the three things a headless suite
cannot see, so they are checked here. **NOT YET RUN** — recorded when the adoption landed.

1. `/bl` → open the ledger → **Export** → with **All Data** selected, click **Export to CSV**.
2. The copy window opens **centred on the ledger window**, above the modal, with the CSV **already
   selected**.
3. Ctrl+C, paste into a text editor: the whole CSV, including the `\r\n` line breaks the exporter
   writes.
4. Switch the **Data Set** to **Current View** and export again: the **same** window, new text,
   selected again — not a second window stacked on the first.
5. Esc closes the copy window and leaves the modal open.
6. Drag the ledger window somewhere else and export again: the copy window follows it.
7. **The close glyph is the library's now** — 18x18 with a red hover, where this addon's own close
   is 24x24 with a class-coloured hover. Confirm it still reads as a close button in the title bar
   and is not clipped by the 26px bar. This is the one deliberate visual difference in the change.
