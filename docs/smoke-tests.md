# Smoke tests — Ka0s Bank Ledger

These are the in-client checks the headless suite cannot make: real frames, real bank UIs, real taint,
real SavedVariables files. Run them before a release, from a clean `/reload`, on a character with a
character bank, a warband bank and a guild bank. Turn logging on (`/bl debug on`) only where a step
says so. Each check says what to do and what must happen; anything that does not match is a bug, not a
tolerance. Record the outcome on the check's `Result:` line (pass, or what you saw instead). IDs are
`<THEME>-<n>` and stay stable: a new check takes the next free number in its theme, and a retired one
leaves its number unused.

## Index

| ID range | Theme | What it covers |
|---|---|---|
| INSTALL-1 – 10 | Install and load | Clean login, version, the minimap launcher and its menu, the migration ladder on a real store |
| SLASH-1 – 4 | Slash commands | Bare `/bl`, help, the panel/CLI round trip, verbs while disabled |
| PANEL-1 – 31 | Settings panel | Landing page, General's tabs, Master controls, row tints, slash repaint, the full reset |
| PROFILE-1 – 14 | Profiles | The Profiles page, the schema v3 lift, retention staying account-wide, the `/bl profile` verb |
| STATE-1 – 9 | Enable, stand-down, lock | Disabled means not running, re-enable, Lock frame, General visibility |
| COMBAT-1 – 8 | Combat | The panel in combat, test mode and visibility on combat edges, diagnostics in combat |
| CAPT-1 – 17 | Capture and retention | What becomes a ledger row at each store, gold, guild arming, the uncached refusal, retention, purge |
| LEDG-1 – 50 | History window | Window, filter bar, saved views, row menu, test mode, export and copy window, marks, dropdown menus, the resize grip, search suggestions, per-tab views |
| INS-1 – 18 | Insights | Cards, charts, companions, Top Of The List, the GOLD block, live updates |
| FILT-1 – 15 | Filter lists | Blacklist and whitelist, the add box and its dropdown, the two-column grid |
| SESS-1 – 13 | Session window | The Current Banking Session window at every store, its resize grip |
| DIAG-1 – 31 | Debug and diagnostics | The console, its chrome, the addon's dumps, the diagnostics report, resizing the console and its copy windows, debug coverage, the Diagnostics link, diagnostics turning logging on, the library's own lines (slash refusals, Lifecycle edges) |
| DEGRADED-1 – 12 | Library-absent install | `libs/LibKa0s` renamed aside: fallbacks, refusals, restore, the fallback resize grip |
| LOC-1 – 5 | Non-English client | Localized type strings, the CSV contract, sort and search, quality names |

## Before you start

- Error display on: `/console scriptErrors 1`. Every check assumes it.
- A character with a character bank, the warband bank and a guild bank it can deposit to, some gold,
  and a few movements already recorded (so History, Insights and the session window have rows).
- A training dummy nearby for the COMBAT checks and the combat halves of others.
- A second Ka0s addon installed, for DIAG-11, DIAG-24 and PANEL-4 (Ka0s Loot History for PANEL-4).
- Back up `WTF/` before INSTALL-8 and PROFILE-14: both edit or replace a real SavedVariables file.
- For DEGRADED, first run `/bl list` on the healthy install and keep the output for DEGRADED-11. Then
  quit the game and rename `Interface/AddOns/BankLedger/libs/LibKa0s` to `libs/LibKa0s.off`;
  DEGRADED-11 renames it back. A repo left in that state passes its own gate and ships broken.

## INSTALL

- **INSTALL-1. Clean login.** Enable the addon and log in → zero Lua errors. A nil-index in
  `core/Constants.lua` means `core\ItemSetup.lua` slipped below `core\Constants.lua` in the TOC. Result:
- **INSTALL-2. Version.** `/bl version` → one line, `[BL] v<version>` with the tag in cyan, the
  version the TOC's `## Version` line carries. Result:
- **INSTALL-3. The minimap button.** Look at the minimap and at the AddOns list → the button wears the
  addon's own logo, not a Blizzard bag icon (`launcher-§4`), and the same art sits beside Ka0s Bank
  Ledger in the AddOns list. Hover it → `Ka0s Bank Ledger  v<version>`, `Enabled: Yes`, `Locked: No`,
  `Test mode: Off`, the movement count, then `Left-click: Open settings` and
  `Right-click: Options menu`. Result:
- **INSTALL-4. Left-click.** Left-click the button → the settings panel opens on its landing page
  (`launcher-§2`); the ledger window does not toggle. Result:
- **INSTALL-5. The options menu.** Right-click the button → a menu titled Ka0s Bank Ledger with four
  checkboxes in this order: Enabled (ticked), Locked, Test mode, Show window. Click Show window → the
  ledger opens exactly as `/bl toggle` opens it, and on the next right-click Show window is ticked.
  Click Show window again → the ledger closes. The menu closes after every click. Result:
- **INSTALL-6. Menu entries echo their verbs.** In the menu click Test mode → chat prints
  `test mode on` and the ledger shows the sample. Click Locked → chat prints `settings.locked = true`,
  the ledger can no longer be dragged and Master controls' *Lock frame* is ticked. Click each again →
  both undo. Result:
- **INSTALL-7. Broker displays.** With Titan Panel, ElvUI data texts or Bazooka installed → Ka0s Bank
  Ledger is in its plugin list with the same icon, and its clicks do the same two things (one object
  registered twice). Result:
- **INSTALL-8. The migration ladder runs on a real store.** Copy
  `WTF/Account/<ACCOUNT>/SavedVariables/BankLedger.lua` somewhere safe. Edit the file: delete the
  `["schemaVersion"] = 5,` line under `["global"]` and add `["vendorPrice"] = 20,` to one ledger entry
  (note which). Log in → zero Lua errors, and `/bl debug diagnostics` → its `[State]` section reads
  `schema stored=5 code=5`. **Fail:** `stored=0`, the default showing through because the ladder did
  not run. Do not look for a `[Migrate]` line: the ladder runs in `addon:OnInitialize`, before any
  slash command can turn logging on, and logging is off at every login, so the line never reaches a
  client's console. The stamp alone cannot tell a walked store from one left alone; INSTALL-9 reads
  what the walk did from the file. Result:
- **INSTALL-9. The walk shows in the file, and the stamp survives a logout.** After INSTALL-8, exit to
  desktop (the strip runs on `PLAYER_LOGOUT`) and reopen the file → `["schemaVersion"] = 5,` is under
  `["global"]`, the planted `vendorPrice` key is gone from the entry you noted, and the settings still
  sit under `["profiles"]` (on a store already at v5 no profile holds a retention window or a
  single `savedView`, so the v3, v4 and v5 steps find nothing to move). **Fail:** `vendorPrice` still there (the v2 step did not run),
  or the stamp missing again, meaning something declared a default equal to a real version
  (`savedvariables-§1`). Result:
- **INSTALL-10. A stamped store is left alone.** After INSTALL-9, log back in. `/bl debug on`, open the
  console. On the Profiles page create a profile (any name), then choose `Default` again → two
  `[Profile] switched to profile '…'` lines and no `[Migrate]` line. Every profile event re-runs the
  ladder (`NS.OnProfileEvent`), so this is the one place a client can watch it run with logging on,
  and on a stamped store it does nothing. Delete the extra profile, `/bl debug off`. Result:

## SLASH

- **SLASH-1. Bare `/bl`, config and help.** `/bl config` → the panel opens with the addon's entry
  already in the list. Close it, type `/bl` alone → the same landing page, not General, and nothing in
  chat. `/bl help` → the command list prints instead. Result:
- **SLASH-2. Panel and CLI read one value.** Toggle a checkbox on General, then `/bl list` → the value
  matches. `/bl set settings.trackMoney false`, reopen the panel → *Track gold* is unticked. Set it
  back. Result:
- **SLASH-3. Live verbs answer while disabled.** Disable the addon (`/bl disable`). `/bl` alone opens
  the panel. `/bl version`, `/bl list`, `/bl get settings.qualityThreshold`,
  `/bl set settings.qualityThreshold 3`, `/bl reset settings.qualityThreshold` all answer normally.
  `/bl help` prints the whole index with the refusal line under its header. `/bl wibble` answers
  `unknown command 'wibble'`, then that same index, refusal line included; never the refusal line
  alone. `/bl perf` answers the same way (reserved, but this addon registers no `perf` verb).
  Re-enable. Result:
- **SLASH-4. Feature verbs are refused once.** Disabled, run `/bl show`, `/bl toggle`, `/bl test`,
  `/bl purge` → each prints exactly one line, `Ka0s Bank Ledger is disabled — enable it with
  /bl enable` with the command in gold, and does nothing else; `/bl purge` raises no confirm dialog.
  Re-enable. Result:

## PANEL

- **PANEL-1. Landing page.** `/bl config` → the logo, the tagline and every slash command, `profile`
  included. The logo is present and crisp: blank is a real failure (a missing texture draws nothing
  and raises nothing), soft or jagged means the `.tga` was regenerated at a size that is not a power of
  two (media.md ▸ Logo art). Result:
- **PANEL-2. The settings tree.** Settings ▸ AddOns ▸ Ka0s Bank Ledger → General, then Profiles, and no
  Filters page (an entry there would open onto nothing). Result:
- **PANEL-3. General's header.** Open General → a breadcrumb header, a gold divider and a Defaults
  button that looks like every other button on the page. Blizzard's red stone button means it was built
  before a UI skin hooked AceGUI (`/bl debug panel` shows the region list; the bare 5-region `130828`
  form is the unskinned one). Result:
- **PANEL-4. The tab strip.** On General → a strip pinned under the header, above the scroll, reading
  Master controls · Capture · Interface · History · Filters, with Master controls selected on first
  open and no section heading repeating a tab's name (`options-ui-§13`). Open Ka0s Loot History's
  panel beside it → the same five, plus AH Price after Capture. Result:
- **PANEL-5. Master controls rows.** Master controls → *Enable Bank Ledger · General visibility*, then
  *Master scale · Master alpha*, then *Lock frame · Debug console*, then *Minimap button · Test mode*,
  then Reset position and Reset all settings side by side. Nothing renamed, reordered or missing.
  Result:
- **PANEL-6. Capture tab.** Capture → *Track items · Track gold*, then *Minimum quality*, then the
  full-width per-store grid. Open *Minimum quality* → six rows, each the quality's own name in its own
  color followed by " and above": Poor, Common, Uncommon, Rare, Epic, Legendary. A bare number or an
  uncolored row is the Item seam failing. Result:
- **PANEL-7. Interface tab.** Interface → a Windows heading over *Session window*, then a Table rows
  heading over *Row stripe opacity · Row hover opacity*, the two sliders side by side on one line.
  Neither heading reads "Interface" (`options-ui-§7`). Result:
- **PANEL-8. History tab.** History → *Keep history for*, the storage read-out ("N movements recorded
  over N days" and the estimated database size), then Purge ledger… alone. No Reset all button here or
  on Interface or Capture: the only one is on Master controls. Result:
- **PANEL-9. Filters tab.** Filters → a secondary strip inside the scroll (it scrolls with the content)
  reading Blacklist · Whitelist, opening on Blacklist. The selected list shows its own blurb, its own
  Clear all, its own add box and id list, and never both lists at once. Click Whitelist, go to Capture,
  come back → still on Whitelist. `/reload` → back on Blacklist (none of it is saved). Result:
- **PANEL-10. A second visit redraws.** Click each tab in turn, then back → the store grid, the storage
  read-out, the reset pair and both id lists are still there (they are drawn from the tab's
  `afterGroup` hook; anything drawn by the page body would survive one render). Result:
- **PANEL-11. The tab strip survives pooling.** On General, cycle every tab three times, ending on the
  first. Watch each pass → every label is that tab's own, the selected tab is the one you pressed, and
  the strip's band height never moves. **Fail:** a label carried over from the previous tab, a highlight
  on the wrong button, a body under the wrong tab, or a band that grows or shrinks (the pool handing
  back a frame it did not finish dressing). Result:
- **PANEL-12. Scrollbar.** Compare the landing page and General → the scrollbar is visible on both and
  grayed out on the one that fits, so the body width does not jump. Result:
- **PANEL-13. No marks in the panel.** Walk every page → no mark art anywhere; the panel's widgets are
  `LibKa0s-Options-1.0`'s. Result:
- **PANEL-14. No raw locale keys.** Walk the landing page and every tab of General (both Filters
  sub-tabs), toggle the debug console on and off, and run `/bl help`, `/bl list`,
  `/bl get settings.enabled`, `/bl reset settings.enabled` → nothing on screen or in chat is
  `SCREAMING_SNAKE_CASE`. One raw key means a library descriptor was handed `NS.L`, and then all of them
  are wrong. Result:
- **PANEL-15. Minimap button checkbox.** On Master controls untick *Minimap button* → the button leaves
  the minimap at once. Tick it → it returns at the angle you dragged it to. `/bl set minimap.shown
  false`, reopen the tab → the box is unticked; `/bl get minimap.shown` answers false;
  `/bl set minimap.shown true` brings it back; `/reload` keeps whichever state you left;
  `/bl get minimap.hide` answers `Setting not found` (`launcher-§3`). Result:
- **PANEL-16. Master scale reaches both windows.** With the ledger and the session window open
  (`/bl show`, `/bl session`) and General on screen, `/bl set settings.windowScale 1.25` → the Master
  scale slider moves at once and both windows rescale together. Drag the slider → both rescale again,
  no `/reload`. Result:
- **PANEL-17. Master scale clamps and resets.** `/bl set settings.windowScale 9` → the slider lands on
  its maximum, its box reading `2`, and chat echoes `settings.windowScale = 2.00x`.
  `/bl reset settings.windowScale` → the box reads `1` and chat echoes `settings.windowScale = 1.00x`.
  Result:
- **PANEL-18. Master alpha reaches every window.** `/bl show`, open a bank (the session window
  appears), open Export. Drag Master alpha to about a quarter → all three fade while you drag. Result:
- **PANEL-19. The alpha floor.** Drag Master alpha to its far left → its box stops at `10%` (0.10),
  and the windows fade to that and no further: faint, still findable and clickable. Put it back to
  `100%`. Result:
- **PANEL-20. Reset position.** Move the ledger and the session window well off center, then Reset
  position → both return to center at their default size; settings, filter lists and history are
  untouched. Result:
- **PANEL-21. Row tints at their defaults.** `/bl show` with rows → every second row carries a faint
  lighter band (0.03) and a hovered row a faint gold wash (0.10). Result:
- **PANEL-22. Row stripe slider.** With the ledger on screen, drag Row stripe opacity to its maximum →
  the banding darkens while you drag. Drag it to 0 → no banding at all. Result:
- **PANEL-23. Row hover slider.** Row hover opacity at maximum, hover a row → a strong gold wash. At 0
  → no highlight. Result:
- **PANEL-24. One tint, both tables.** Open a bank and move something → the session window's rows wear
  the same band and hover at the same strengths. Result:
- **PANEL-25. Tint values clamp.** `/bl set settings.rowStripeAlpha 5` → clamped to the slider's
  maximum, never an opaque white block. A negative value clamps to 0. Result:
- **PANEL-26. A slash write repaints the open panel.** With General on Master controls on screen,
  `/bl set settings.enabled false` → the Enable Bank Ledger box unticks at once (`options-ui-§11`).
  Set it back to `true`. Result:
- **PANEL-27. One reset, one popup.** Click Reset all settings on Master controls → a confirm popup
  saying it resets this profile and leaves your other profiles alone. `/bl resetall`, General's header
  Defaults and Blizzard's footer Defaults (the Settings window's own button, not the addon's) raise
  the same popup (`options-ui-§12`). No → nothing changes. On General change a setting, then footer
  Defaults ▸ Yes → the PANEL-28 reset runs (settings at stock, both lists empty, History keeps its
  row count), which proves the framework calls the addon. Result:
- **PANEL-28. What Yes resets.** Save a view on History AND a different one on Insights, blacklist
  and whitelist an item, change a few settings (row tints included), tick Test mode, open the
  console, hide the minimap button, move both windows. Reset all settings ▸ Yes → every setting at
  stock (tints back to 0.03 and 0.10), both lists empty, both saved views discarded (Clear on History
  and Clear on Insights each land on stock), test mode off, the console closed, both windows
  recentered, the minimap button still hidden. History keeps every row. Result:
- **PANEL-29. The open views keep the history.** `/bl show`, press Reset on the filter bar (the view
  back to stock) and note the footer's `Showing n of N`, then switch to Insights and leave it on
  screen. Open Settings ▸ AddOns ▸ Ka0s Bank Ledger ▸ General ▸ History beside it and note the
  read-out's movement count. `/bl resetall` ▸ Yes → the read-out keeps its count, every Insights card
  keeps its figure, and back on History the footer still reads `Showing n of N`. **Fail:** any
  history row goes. Result:
- **PANEL-30. Capture sees the reset without a reload.** Blacklist an item, Reset all settings ▸ Yes,
  then move that item at your bank → it is recorded, in History and the session window. **Fail:** the
  movement is dropped (or one that should drop is recorded) until you `/reload`. Result:
- **PANEL-31. The reset repaints once.** With General open, `/bl resetall` ▸ Yes → every widget
  repaints once, not per row. On Filters ▸ Blacklist add an id, then `/bl resetall` ▸ Yes → the list
  empties while you watch. Close the settings window, `/bl resetall` ▸ Yes → no errors, and reopening
  shows the reset values. Result:

## PROFILE

- **PROFILE-1. The Profiles page.** Settings ▸ AddOns ▸ Ka0s Bank Ledger ▸ Profiles → last under
  General, no Defaults button, `Default` shown as the current profile. Result:
- **PROFILE-2. A new profile is fresh settings over the same history.** On the page create `Alt` → at
  once, with no `/reload`: General reads every default, the Blacklist is empty, both windows sit at
  their default positions, History still has every row. **Fail:** a history row missing, or a window or
  setting still showing `Default`'s values. Result:
- **PROFILE-3. Switching back restores.** Choose `Default` → every setting, the blacklist, the saved
  view and both window positions come back. Result:
- **PROFILE-4. Enable is per profile.** On `Alt` untick Enable Bank Ledger → it stands down. Choose
  `Default` → running (deposit something, it records). Choose `Alt` → stood down. Tick it again. Result:
- **PROFILE-5. Reset Profile keeps history.** On `Alt` change a setting, press the page's Reset Profile
  → `Alt` returns to defaults with no confirm, History keeps every row, `Default` is untouched when you
  switch back. (The `/bl resetall` popup and its Yes are PANEL-27 and PANEL-28.) Result:
- **PROFILE-6. One debug line per profile event.** `/bl debug on`, open the console. Switch profile →
  exactly one `[Profile] switched to profile '<name>'` line. Copy `Alt` into the current profile →
  exactly one `[Set] copied profile 'Alt' -> '<current>'` line. `/bl debug off`. Result:
- **PROFILE-7. Retention is account-wide and nothing prunes.** On `Default` set Keep history for to
  Always, with at least one History row older than 30 days. Hover the dropdown → the tooltip ends
  *Account-wide: one value for every profile, because the history it trims is shared.* Switch to `Alt`
  → still Always. Switch back, copy `Alt` into `Default`, press Reset Profile, then `/bl resetall` ▸
  Yes → after each the dropdown still reads Always and the old row is still in History, and with
  `/bl debug on` none of those writes a `[Prune]` line. Keep `Alt` for PROFILE-8 to 13. Result:
- **PROFILE-8. `/bl profile` lists.** With `Default` and `Alt` present, `/bl profile` → a `Profiles`
  header, one row per profile sorted without regard to case with the current one suffixed
  `(current)`, then `/bl profile <name> switches profile`. No line ends in a colon. Result:
- **PROFILE-9. `/bl profile <name>` switches.** On the page choose `Alt`, set Master scale to 1.25,
  choose `Default`. Open General on Master controls with the ledger shown, then `/bl profile Alt` →
  `Switched to profile 'Alt'.`; the slider moves to 1.25 and the ledger rescales without a `/reload`,
  exactly as choosing it on the page does. `/bl profile Alt` again → `Already on profile 'Alt'.` and
  nothing changes. `/bl profile Default` to go back. Result:
- **PROFILE-10. An unknown name is refused, never created.** `/bl profile Nope` → `No profile named
  'Nope'.` then the list; the Profiles page's list has no `Nope`. `/bl profile alt` → refused the same
  way, with `Did you mean 'Alt'?` before the list (names are case-sensitive). Result:
- **PROFILE-11. Quotes and spaces.** Create `My Alt` on the page and switch back to `Default`.
  `/bl profile "My Alt"` → switched to `My Alt`. `/bl profile 'Default'` → switched back. Delete
  `My Alt`. Result:
- **PROFILE-12. The verb answers while disabled.** `/bl profile Alt`, untick Enable Bank Ledger.
  `/bl profile` → the list, not the disabled refusal. `/bl profile Default` → switched, and the addon
  is running again (deposit something, it records). Result:
- **PROFILE-13. No switch in combat.** Pull a training dummy. `/bl profile Alt` → `Can't switch
  profiles in combat.` and the profile does not change. `/bl profile` → the list still prints. Leave
  combat and delete `Alt`. Result:
- **PROFILE-14. The schema v3 lift keeps your settings.** On a build before schema v3, set a minimum
  quality, a muted store and a row tint, blacklist an item, save a view and move the ledger. Install
  this build and log in → all of it as you left it, History complete. Log out and open
  `BankLedger.lua` → settings and both lists under `["profiles"]["Default"]`, and the saved view as
  `savedViews` with the same view under both `History` and `Insights` (v5); `["global"]`
  holds only `ledger`, `minimap`, `schemaVersion = 5` and, if you changed Keep history for, a
  `settings` table holding `retentionDays` alone (D6). **Fail:** a setting back at its default, or any
  other key in a `settings` table under `["global"]`. Result:

## STATE

- **STATE-1. Disabling takes the windows down at once.** `/bl show` and `/bl session`, `/bl debug on`,
  `/bl debug` (leave the console open). Untick Enable Bank Ledger on Master controls (or `/bl
  disable`, the same write) → both windows go in the same turn as the click. Result:
- **STATE-2. Nothing is recorded while disabled.** Disabled, open your bank and move a stack in and out
  → nothing recorded (History's Database size line has not moved) and no session window. Result:
- **STATE-3. Silent on combat edges.** Disabled, pull a mob and drop combat → nothing in chat and no
  new console line. **Fail:** any line: the addon is still registered for that edge. Result:
- **STATE-4. The minimap button while disabled.** Disabled, left-click the button → the settings panel
  opens and nothing prints. Hover → `Enabled: No`. Right-click → Enabled unticked and live; Locked,
  Test mode and Show window grayed out, each reading `(enable the addon first)`, and clicking one does
  nothing. Result:
- **STATE-5. Disabled survives a reload.** `/reload` while disabled → still disabled, still silent,
  still answering every live verb. Result:
- **STATE-6. Re-enabling resumes without a reload.** Tick the box again (or right-click the button ▸
  Enabled, which runs `/bl enable`; the other three entries are live on the next open). Open the bank
  and move a stack → the session window appears with the row. Then `/bl disable`,
  `/bl set settings.trackMoney false`, `/bl enable`, move gold → not recorded (the rebuild reads the
  settings as they are now). Set it back. Result:
- **STATE-7. A reset while disabled re-enables.** Untick Enable Bank Ledger, then Reset all settings ▸
  Yes → the box reads ticked and the addon runs: a deposit records. **Fail:** ticked but nothing
  records until a `/reload` or a toggle. Result:
- **STATE-8. Lock frame.** Tick Lock frame → the ledger, the session window and the export modal cannot
  be dragged by their title bars. Untick → all three drag again. Result:
- **STATE-9. General visibility: Never.** Set General visibility to Never → every window closes and
  `/bl show` does nothing (it refuses, it does not defer). Move something into your bank, set it back
  to Always → the movement is in the ledger. Result:

## COMBAT

- **COMBAT-1. No panel in combat.** Pull a training dummy, `/bl config` → a gray "cannot open settings
  during combat" notice and no panel. Leave combat → the panel does not open by itself. Result:
- **COMBAT-2. The ledger works in combat.** In combat, open, refresh and filter the ledger window → all
  work (it is not a secure frame). Result:
- **COMBAT-3. An open panel locks in combat.** Open the panel on General, pull a training dummy → a gray
  *Settings are locked during combat.* cover over the page; a click on a checkbox or tab does nothing
  and chat prints one gray line for the combat; Blizzard's settings window stays usable (no
  `ADDON_ACTION_BLOCKED`). Leave combat → the cover lifts and the page shows current values. Result:
- **COMBAT-4. Combat ends test mode.** Tick Test mode, close the ledger and the settings window, pull
  a dummy → one chat line, `test mode off — combat started.`, and the ledger does not open. Still in
  combat, `/bl test` → one line, `cannot start test mode during combat.`, and no sample opens (the box
  itself cannot be clicked in combat: COMBAT-3's lock refuses it). Leave combat, `/bl config`, open
  General → Test mode is unticked. Result:
- **COMBAT-5. Only out of combat, window open.** Set General visibility to Only out of combat with the
  ledger open, pull a dummy → it hides on the pull and returns when combat ends. Result:
- **COMBAT-6. Only out of combat, window closed.** Repeat COMBAT-5 with the ledger closed → it stays
  closed through both edges. Result:
- **COMBAT-7. Only in combat.** Set Only in combat → hidden out of combat, shown on the pull. Set it
  back to Always. Result:
- **COMBAT-8. Diagnostics in combat.** In combat, `/bl diagnostics` → no Lua error, and the identity
  header's `combat:` line reads `InCombatLockdown=true`. Result:

## CAPT

- **CAPT-1. Character bank deposit.** Open your bank, deposit a stack into a bank bag, `/bl show` → the
  top row is a Deposit to Character Bank with the right item and count. Result:
- **CAPT-2. Partial withdrawal.** Withdraw part of that stack → a Withdraw row with the partial count,
  not the whole stack. Result:
- **CAPT-3. Loot is not a movement.** With the bank open, take an item from the mailbox or loot one →
  no row. Result:
- **CAPT-4. Warband bank items.** On the Warband Bank tab move an item in, then out → a Warband Bank
  deposit row and a withdraw row, even though switching tabs fires no event. Each can take a second or
  two (the addon waits for both halves of the server round trip). Result:
- **CAPT-5. Warband gold.** Deposit gold at the warband bank → a Gold row: Qty as money, Type and
  Sub-type Gold, Quality a dash, Deposit (green ▼), a pale gold name. Hover → a Gold tooltip with the
  amount. Withdraw gold → a Withdraw row of the same shape. Result:
- **CAPT-6. The character bank holds no gold.** At the character bank, sell something to a vendor with
  the bank open → no gold row. Result:
- **CAPT-7. Spending is not a deposit.** With the bank open, buy a bank slot or repair → no gold row
  (the store's own balance must mirror a purse change). Result:
- **CAPT-8. The money API is readable.** At the bank, `/bl debug scan`, read the `money API:` block →
  `bankFetch=function` and a non-zero `C_Bank.FetchDepositedMoney(Account)`. If not, warband gold is
  declined rather than guessed. Result:
- **CAPT-9. Guild bank items.** Deposit an item at the guild bank → a Guild Bank row, and the exported
  CSV's `guild` column carries your guild name. Result:
- **CAPT-10. Guild bank gold.** Deposit gold at the guild bank → a Gold row against the guild bank.
  Result:
- **CAPT-11. A closed guild frame is not a zero balance.** From a fresh `/reload`, spend gold at a
  character bank, then open the guild bank → no guild-bank gold row (with the frame closed the client
  reports the guild balance as `0`, so a naive read would see a huge gain on open). Result:
- **CAPT-12. The guild bank arms on open.** With the guild bank open, `/bl debug scan` →
  `openContext=GUILD_BANK`. With `/bl debug on`, reopen it → `[Store] GUILD_BANK opened` with a
  non-zero `GUILD_BANK` baseline once the tab queries land. `nil` means no data reached the addon.
  Result:
- **CAPT-13. The guild bank disarms on close.** Close it, then move something in your bags → no further
  guild-bank scanning. If either half misbehaves, `/bl debug scan` says
  `guild bank frame hooks: NOT INSTALLED`. Result:
- **CAPT-14. No guild session away from a bank.** `/reload` somewhere with no bank in sight, then
  `/bl debug on` at once (a reload turns logging off) and stay a few minutes, ideally while a
  guildmate uses the vault → no session window and no `[Store] GUILD_BANK opened` line in the
  console. One with a `GUILD_BANK 0` baseline is the regression (issue #12). Result:
- **CAPT-15. An uncached item is refused, not guessed.** Set Minimum quality to Rare. `/reload`,
  `/bl debug on` (a reload turns logging off) and `/bl debug` to open the console, then at once move
  something unusual from a bank tab you have not opened → a `[Skip]` line naming it with `(uncached)`,
  and no row. Repeat the movement a few seconds later → judged properly: a row, or a `[Skip]` line
  naming it with `(quality)`. **Fail:** a row appearing at once at a quality nothing resolved. Result:
- **CAPT-18. Unnamed rows fill in at login.** With Minimum quality at 0 and a History holding
  `Item <id>` rows (deposit something the client has not cached, then `/reload` at once), log in,
  `/bl debug on`, wait about 10 seconds, open History → those rows show their real names, and the
  console shows a `[Backfill] done: …` line. **Fail:** a row still reading `Item <id>` with no
  `unresolved` count to explain it. Result: pass (owner, 2026-10-02)
- **CAPT-19. Insights counts them, once.** Open Insights → the previously unnamed items appear under
  Type, Sub-type and Quality. `/reload` again → no duplicate rows, nothing changes, and no
  `[Backfill]` line (nothing left to fill). Result: pass (owner, 2026-10-02)
- **CAPT-16. Retention.** `/bl set settings.retentionDays 7`, `/reload` → entries older than 7 days are
  gone. Result:
- **CAPT-17. Purge.** `/bl purge` → a confirm; accept → the ledger empties and the window shows its
  empty state. Result:

## LEDG

- **LEDG-1. Open and close.** `/bl toggle` → opens, again → closes. Esc also closes it. Result:
- **LEDG-2. Geometry persists.** Drag the title bar and resize from the bottom-right grip, `/reload` →
  position and size return. Resize only (never drag), releasing the grip well outside the button,
  `/reload` → kept. Again with the window open at `/reload` → kept. Result:
- **LEDG-3. Minimum width.** Shrink the window → it stops at the width that shows every column. Result:
- **LEDG-4. Search.** Type in the search box → the footer's row count falls as you type. Result:
- **LEDG-5. Store filter.** Open Store → only stores your data contains, both bank stores listed once
  both have rows. Pick two → both ticked, the button reads "Store: 2 selected". Result:
- **LEDG-6. Sorting.** Click a column header → sorts; again → reversed. Date starts newest first.
  Result:
- **LEDG-7. Group by Store.** Group by Store → collapsible headers with per-group counts; click one →
  it collapses. Result:
- **LEDG-8. Sub-type and Quality options.** Open both → only values your data contains; Quality runs
  Poor→Legendary, each option in its quality color. Result:
- **LEDG-9. Gold as a type.** After a gold movement → Type ▸ Gold and Sub-type ▸ Gold appear, filter to
  gold rows, and mix with item types in one multi-select. Result:
- **LEDG-10. Direction and Store colors.** Open Direction → a red ▲ Withdraw and a green ▼ Deposit.
  Open Store → each store in its column color, matching the table. Result:
- **LEDG-11. Character: Current by default.** On a fresh install, after a `/reload` and after Clear →
  the window is on Character: Current, not All. Result:
- **LEDG-12. Class icons.** Every character row and option shows its class icon and color;
  "Character: Current" has no icon. Result:
- **LEDG-13. More groupings.** Group by Type, Sub-type and Quality → Quality groups run Poor→Legendary
  and gold sits in its own "None" group. Group: Type & SubType → one header per pair, read
  "Type: Armor · Cloth", in type then sub-type order; an item with no sub-type reads "Type: Armor"
  (no trailing dot) ahead of its siblings, gold reads plain "Type: Gold". With it picked, the closed
  Group dropdown reads the whole "Group: Type & SubType", not clipped or ellipsized, clear of the ▼.
  Save the view, `/reload` → it comes back grouped the same way. Result:
- **LEDG-14. Clear.** With no saved view on History, change filters, grouping and sort, press Clear →
  all back to their defaults. Result:
- **LEDG-15. The button cluster.** Save · Reset · Clear sit in one cluster above Export, right edges
  flush with it, and stay put as the window widens. Result:
- **LEDG-16. Save a view.** Set a grouping, two column filters and a search term, press Save → a
  "History view saved as your default" line in chat. Change filters, press Clear → back on the saved view. `/reload`
  → the window opens on it. Result:
- **LEDG-17. Character scope is not saved.** Set Character: All, Save, `/reload` → opens on Current.
  Result:
- **LEDG-18. Reset the view.** Press Reset → chat confirms ("History view reset to stock defaults"),
  the bar returns to stock, and Clear now lands on stock. Result:
- **LEDG-19. Quality words.** The Quality column and the Quality filter read the quality names, and an
  export writes the same names into its rows. Result:
- **LEDG-20. Test mode.** `/bl test` → the window opens on a sample ledger with a red TEST MODE badge
  by the title; filters, grouping, Insights and export all work on it. Result:
- **LEDG-21. Test mode ignores the saved view.** With a view saved, `/bl test` → the sample opens
  unscoped and unfiltered. Leave test mode → the saved view is back, scoped to Current. Result:
- **LEDG-22. The sample reads like a real bank.** In test mode → character-bank rows dominate, warband
  mid-weight, guild lightest; about 60/40 deposit-leaning; about eight characters across distinct
  classes with two or three clear mains; six real bank-city zones; a hot-item head over a long tail in
  Top Items; an evening-leaning hour curve; every store, both directions and qualities 0–5 at least
  once; a date range over 14 days. Result:
- **LEDG-23. Sample rows cannot touch real data.** Right-click a sample row → Link to chat available;
  Blacklist item, Whitelist item and Delete grayed out and click-inert. Then both filter lists on
  Filters are unchanged. Result:
- **LEDG-24. Back to real data.** `/bl test` again → real data, badge gone. Right-click a real row →
  all four entries live; Delete removes the row and the footer count drops. Result:
- **LEDG-25. The Master controls box is the same switch.** Close the ledger, tick Test mode on Master
  controls → the ledger opens on the sample with the badge. Untick → real data, the window stays.
  `/bl test` with the panel open → the box ticks; again → unticks. The session window never changes
  (its preview is `/bl session`'s). Result:
- **LEDG-26. A refused start leaves the box unticked.** General visibility Never, tick Test mode → one
  chat line saying General visibility keeps the window closed, and the box unticks. `/bl test` → the
  same answer, never `test mode on`. Set visibility back to Always. Result:
- **LEDG-27. Test mode is never saved.** Tick Test mode, `/reload` → off. (A reset ending it is
  PANEL-28.) Result:
- **LEDG-28. The copy window opens ready.** History ▸ Export ▸ Current View ▸ Export to CSV → the copy
  window opens centered on the ledger, above the modal, with the text already selected in a monospace
  font. Result:
- **LEDG-29. The copied CSV is whole.** Ctrl+C, paste into a text editor → the whole CSV with its
  `\r\n` line breaks, and a row count matching the table. Result:
- **LEDG-30. One copy window.** Switch the Data Set to All Data and export again → the same window, new
  text, selected again; no second window. Result:
- **LEDG-31. Esc closes only the copy window.** Esc → the copy window closes and the modal stays open.
  Result:
- **LEDG-32. The copy window follows the ledger.** Drag the ledger elsewhere and export again → the
  copy window opens centered on it. Result:
- **LEDG-33. Wowhead URLs carry bonuses.** In the CSV, the last column is `wowhead`. Open the URL from a
  gear row recorded by this build → the item at its item level with its sockets and tertiaries (the
  `?bonus=…` list). A stackable trade good is a plain `item=<id>` URL; a gold row's cell is empty.
  Result:
- **LEDG-34. The Insights export.** Export from the Insights tab → the sectioned summary, not raw rows.
  Result:
- **LEDG-35. Host close marks.** `/bl show` → the close control is an outlined ×, not a font
  character; hover → your class color; click → closes. Check `/bl session` and the Export modal → the
  same mark (all three use `B:MakeCloseButton`). Result:
- **LEDG-36. The copy window's close is the library's.** Export to CSV and look at the copy window's
  title bar → the library's outlined close mark, 18×18 with a red hover (the host's is 24×24 with a
  class-colored hover), reading as a close button and not clipped by the 26px bar. A font × there is a
  library regression. Result:
- **LEDG-37. Dropdown art.** Count the filter bar's dropdowns → eight chevrons, not Blizzard's filled
  arrow: Group by on row 1, then Date, Direction, Store, Quality, Type, Sub-type, Character on row 2;
  the modal's Data set makes nine. Open a multi-select (Store, Type, Quality, Character), pick two →
  each chosen row has a flat full-white tick, not Blizzard's beveled `UI-CheckBox-Check`. Full white
  is correct: it is the one untinted inline mark ([media.md](media.md)). Result:
- **LEDG-38. Header marks are gold.** Click a column header → a sort-up / sort-down mark that flips on
  the next click. Group by Day → each group header opens with a chevron, right when collapsed, down
  when expanded. All four are the same gold as the label beside them (the gray `(count)` is not part of
  this). **Fail:** a near-white mark against a gold word (the vertex-color tail came off). Widget marks
  (close, dropdown chevron, magnifier, the modal's export mark) are 0.7–0.85 gray instead. Result:
- **LEDG-39. Button marks.** Export, Save, Reset and Clear on the bar → four plain centered words, no
  mark. The modal's Export to CSV → a small mark on its left with the words still centered, about
  two-fifths the width of the Data set dropdown above it and centered under it. **Fail:** a button
  spanning the modal edge to edge with the mark pinned far left. Result:
- **LEDG-40. The search magnifier.** The search box shows a magnifier on its left with "Search items…"
  starting just past it; typed text starts in the same place. Result:
- **LEDG-41. Marks carry no tooltips.** Hover every mark → none shows a tooltip; the four filter-bar
  buttons still show theirs. Result:
- **LEDG-42. The first click opens the menu.** Right after logging in, `/bl show`, click Store as the
  first dropdown you touch → the menu drops. Click Direction → its ▲/▼ rows are glyphs, not boxes.
  Result:
- **LEDG-43. Escape takes the menu with the window.** Open Store's menu, press Escape → the ledger and
  the menu both close. Export ▸ open Data set's menu ▸ Escape → modal and menu both close. Reopen, open
  the menu, click the modal's × → the same. Result:
- **LEDG-44. A slash close takes the menu.** Open any filter menu, `/bl hide` → window and menu close.
  Again with `/bl toggle` on an open window → the same. (`/bl show` closes nothing; the session window
  owns no such menu, so a filter menu stays open when it closes.) Result:
- **LEDG-45. One menu at a time; clicks land.** Open Store's menu, then click Character → Store closes,
  Character opens. Open Export, open Data set's menu, left-click in the ledger behind → the menu closes
  and the click lands on what is under the cursor in the same press. Right-click there → the same.
  Two presses where one should do is the regression. Result:
- **LEDG-46. A filter it can no longer list keeps its name.** Filter History to one Type only one
  character owns, Save, switch to a character with none of it (or `/bl test` and back) → the Type
  button reads the type's name, not "Type: All", and the row count is unchanged. The same for Store,
  Quality and Sub-type (Character always has its All and Current rows). Result:
- **LEDG-47. The ledger grip is the library's.** `/bl show` → a size grip sits in the bottom-right
  corner, 1px inside the edge, and darkens while pressed. Drag it out and in on both axes → the table
  and its header cells re-flow live. It stops at the width that shows every column, and the DB-size
  text in the footer never sits under the grip. Right-click the grip and drag → nothing happens.
  Result:
- **LEDG-48. Resize-only geometry survives a reload.** Without dragging the title bar, resize the
  ledger, releasing on the grip, then `/reload` and `/bl show` → the size you chose returns. Repeat,
  releasing well outside the grip, and `/reload` with the window open → it is still kept. Then Master
  controls ▸ Reset position, `/reload` → the default size and center return, not the old size.
  Result:
- **LEDG-49. Search suggestions.** On History, type two letters of an item you have moved → a list
  drops directly under the search box, exactly as wide as it, its top edge one gray line with the
  box's bottom edge, rows in quality colors (a gold movement reads "Gold" in pale gold), names that
  start with the letters first, at most eight. Down/Up move a gold highlight; Enter picks it → the
  box reads that name, the list closes and the table filters to it at once. Type again, press Escape
  → the list closes and the typed text stays. Type again and click a table row or the window title →
  the list closes. Filter Store to one store → only that store's names are offered. Widen and
  narrow the window → the list stays the box's width. Repeat the pick on Insights → the charts
  follow it. `/bl test` → the suggestions are the sample's names. Result:
- **LEDG-50. Each tab keeps its own filters and its own saved view.** On History set Store to one
  store, Character: All and a search term; switch to Insights → the bar reads its own state (stock
  on a first visit, Character: Current), not History's. Set Quality to Epic there and switch back
  → History's store, All and search term are exactly as you left them; back on Insights → Epic is
  still set. Save on each tab with different filters → each chat line names its tab. Press Clear on
  Insights → Insights' saved view, never History's; History is untouched. Press Reset on Insights →
  Insights goes to stock, then switch to History and press Clear → History's saved view is still
  there. `/reload` → each tab opens on its own saved view. Result:

## INS

- **INS-1. Stat cards.** Open Insights → fourteen cards: three rows of four, then two double-width
  (date range, busiest day). Hover each → what it counts. No value or biggest-move card. Result:
- **INS-2. Card text fits.** Every card shares one headline size; the date-range and busiest-day
  strings shrink to one line rather than clip or wrap. Result:
- **INS-3. Net colors.** Net items and Net gold → green `+` when positive, red `-` when negative, a gray
  dash at zero. Result:
- **INS-4. Deposits vs Withdrawals.** One back-to-back bar: withdrawals grow left in red, deposits
  right in green, scaled against the larger; its center line on the companions' axis. A caption row
  below reads `Withdrawals <n> · <pct>%` left in red and `Deposits <n> · <pct>%` right in green, still
  readable on a slice that is almost all one direction (the small side keeps a sliver). Hover either
  half → its name and exact count. Result:
- **INS-5. By Character.** Movements By Character → class colors and real class icons, never a raw
  `|TInterface\...|t` path. Movements By Character × Store → one left-aligned segment per store, each
  hover-tipped, with a legend. Result:
- **INS-6. Back-to-back companions.** Every `× Deposits/Withdrawals` companion → red grows left of a
  center line in the same position on every row, green right; a mostly-withdraw row leans left. Hover
  → direction and count. Legend reads Withdraw then Deposit. Result:
- **INS-7. Companion titles.** Under Movements By Item Type → Movements By Item Type ×
  Deposits/Withdrawals, not Item Type × …; the same for Store, Quality, Sub-type and Character. Result:
- **INS-8. By Quality.** Movements By Quality → Poor→Legendary in the game's quality colors, followed
  by its companion. Result:
- **INS-9. Type and Sub-type bars.** Visibly different colors (no two adjacent alike), each with a
  legend and its own companion whose labels keep the parent's colors; a parent capped at 12 bars has
  a companion capped at 12. Result:
- **INS-10. The per-day strip.** Movements (and gold, if any) share an x-axis with the hour and weekday
  charts; quiet days show a faint ghost bar; the rotated date labels thin out and never overlap; hover
  names the day and figure. No value-moved strip. Result:
- **INS-11. By Hour Of Day.** All 24 buckets, empty ones included. Result:
- **INS-12. An enriched slice.** In test mode → every store has a bar, both directions show on every
  split chart, and the character, zone, type and quality spreads are visibly uneven. Result:
- **INS-13. Top Of The List.** A three-column grid under ITEMS (Top Items By Movements, then By
  Quantity, each All / Deposits / Withdrawals), CATEGORIES (Top Type · Sub-type), WHERE (Top Banking
  Spots) and BY STORE (a sub-section per store with movements, each its own row of three; a coin-only
  store absent). A slice with no withdrawals has no Withdrawals column rather than an empty panel. Names
  in quality color, a truncated one full on hover. No Top Items By Value. Result:
- **INS-14. The GOLD block.** Move gold, refresh → the GOLD divider and its two charts. Filter out every
  gold movement → the whole block disappears rather than rendering empty. Result:
- **INS-15. Insights keeps its own filter.** Filter on History, switch to Insights → the numbers and
  bars reflect Insights' own filter state (stock on a first visit), not History's. Filter Insights to
  one store → every number and bar reflects that store; switch to History and back → still that
  store. Result:
- **INS-16. Resize.** Resize the window → cards re-flow, bars and strips re-stretch, the Top Of The List
  columns stay side by side. Result:
- **INS-17. Live update.** With Insights open, move something at a bank → it updates. Result:
- **INS-18. Empty ledger.** After a purge (CAPT-17) → the cards read 0 and one centered line replaces
  every section: `No movements match your filters.` while any filter is set (Character: Current, the
  default, counts), or `No bank movements recorded yet. Open your bank and move something.` on
  Character: All with nothing else set. Result:

## FILT

- **FILT-1. Blacklist from a row.** Right-click a ledger row ▸ Blacklist item → `[BL] blacklisted
  <name> — manage it in Settings ▸ General ▸ Filters ▸ Blacklist.`, naming the tab and sub-tab.
  Whitelisting names General ▸ Filters ▸ Whitelist. Result:
- **FILT-2. Blacklisting is point in time.** Move that item to your bank again → no new row, and the
  row you clicked is still there. Result:
- **FILT-3. A list entry.** Filters ▸ Blacklist → the item with an X on the left, its icon, its name,
  its id in gray, no Remove button. Hover → the game's item tooltip. Click the X → removed. Result:
- **FILT-4. Three ways to add.** In the add box, shift-click an item link, type a bare item id, and type
  an item's name in lower case (one in your bags) → each lands on the list. An uncached id reads
  `Unknown item <id>` and fills in its name a moment later with no reopen. Result:
- **FILT-5. The whitelist beats the quality floor.** Whitelist an item, set Minimum quality to Epic,
  move the item → still recorded. Result:
- **FILT-6. The name dropdown.** Type two or more letters of a recorded item → a list under the box,
  above the panel and not clipped: icon, name in quality color, id in gray. A crafted-quality item
  shows one row per rank you carry, recorded or listed, each with its tier icon, and no other rank; a
  name with one known rank adds that rank on Enter. Over ten matches end in a gray `+N more`. Result:
- **FILT-7. Picking adds.** Click a row, or Up/Down and Enter → that id added once, the box clears, the
  dropdown closes. Escape or a click elsewhere closes it without adding. A name several ranks share,
  typed in full with Enter and no pick → nothing added, the orange line reads `Several items are named
  '<name>' — pick one from the list, or use the id.`, the ranks stay listed. Result:
- **FILT-8. A name not seen this session.** `/reload`, then with a recorded (or listed) item not in
  your bags, type its exact name, Enter → added, perhaps after a gray `Looking up items...`. On a large,
  uncached ledger the first name after a `/reload` can take up to about ten seconds; later ones answer
  at once. Result:
- **FILT-9. A name nothing knows is refused.** Type the exact name of a real item you have not carried
  this session, on neither list and never recorded, Enter → nothing added, the text stays, the orange
  line reads `No item named '<text>' that the game can find. Names work for items you carry (or carried
  this session), items on either list and items your ledger has recorded; otherwise use the id or
  shift-click a link.` The box's tooltip ends with the same sentence. Its id or link still adds it.
  Result:
- **FILT-10. Two to a row.** With at least five blacklisted items → entries two to a row, left to right
  then down, the X, icon and name aligned across both columns and down each. Whitelist → the same.
  Result:
- **FILT-11. An odd count.** With an odd count → the last row has one entry in the left column and
  empty space on the right, not one stretched entry. Result:
- **FILT-12. Long names truncate.** Blacklist an item with a long name → cut at the tail, not wrapped (a
  long one may lose its gray `(id)`); hovering still names the item. Result:
- **FILT-13. Remove and add repack.** Remove an entry with its X → the grid rebuilds and repacks left to
  right. Add one → the same. Result:
- **FILT-14. One column when narrow.** Narrow the settings canvas (windowed at a small width, or
  `/console uiScale 1`) → below about 580px of panel the lists draw one full-width column, correctly
  formed; never icons over wrapped names or an X on its own row. Widen and reopen → two columns. (If
  you cannot get narrow enough, FILT-10 passing is still the meaningful result.) Result:
- **FILT-15. The lists after the help-art descriptor.** With entries on both lists, open Settings ▸
  General ▸ Filters ▸ Blacklist, then Whitelist → each renders exactly as in FILT-3 and FILT-10, with
  no help mark on any entry (none carries help) and no Lua error on opening the panel or either tab.
  This build passes the addon's folder name to the settings library for its help-mark art
  (LibKa0s#42); nothing here draws one yet, so a pass means nothing broke. Result:

## SESS

- **SESS-1. It opens with the bank.** Open your character bank → a second window, Ka0s Bank Ledger -
  Current Banking Session, empty, reading "Nothing has moved yet this session." Result:
- **SESS-2. Its shape.** No tabs, filter bar, search, Clear, Export or footer. Columns: Direction,
  Store, Item, Qty, Quality, Type, Sub-type; no Date, Time or Character. Result:
- **SESS-3. Headers do not sort.** Click a header → nothing; hover → the column's explanation. Result:
- **SESS-4. Rows arrive at once.** Deposit something → a row at once, colored as History colors it,
  newest on top. Withdraw → a second row above it with the red ▲. Result:
- **SESS-5. Gold.** Move gold at the warband bank → the row reads Gold with the amount in coins.
  Result:
- **SESS-6. It is this visit only.** Drag and resize it, close the bank → it closes. Reopen → empty, at
  the position and size you left. Result:
- **SESS-7. History holds it.** Open the ledger → every movement from that visit is there. Delete one in
  History with the bank open → it leaves the session window too. Result:
- **SESS-8. Every store drives it.** Repeat SESS-1 and SESS-4 at the warband tabs and at a guild bank →
  the same window. Result:
- **SESS-9. The guild bank's open and close.** Open the guild bank → the window appears (on the frame's
  `OnShow`). Move something → the row. Close it without touching your bags → the window disappears at
  once, not on the next bag change. Result:
- **SESS-10. Geometry across a game session.** Move and resize it, close the bank, `/reload`, reopen →
  same size and place, no rows. Log in on another character on the same profile → the geometry
  follows (it belongs to the profile). Again resizing only, and again with it on screen at `/reload` →
  both kept. Result:
- **SESS-11. The Session window setting.** Untick Session window on Interface, open a bank → no window,
  but movements still record in History. Tick it with a bank open → it appears on the next movement.
  Untick it while shown → it closes at once. Result:
- **SESS-12. The preview.** Away from any bank, `/bl session` → it opens on a sample visit; again →
  dismissed. During a real session, `/bl session` → refuses and says so. Result:
- **SESS-13. The session window grip is the library's.** Open a bank → resize the session window
  from its grip → the rows re-bind live, and the scroll bar's down arrow stays clickable above the
  grip. Close the bank, `/reload`, reopen → same size. Reset position, `/reload`, reopen → the default
  size, right of center. With Lock frame ticked the window still resizes, which is today's behavior,
  but cannot be dragged; say if the lock should gate the grip too. Result:

## DIAG

- **DIAG-1. The console opens.** `/bl debug` → the console, header **Debug: OFF** in red. Result:
- **DIAG-2. Logging on.** `/bl debug on` → a green ON ack, `[Debug] logging enabled` and an `[Init]`
  summary naming the build, schema and profile, ending `bank addons: …` (no launcher fact), then
  `[Launcher] registered` and `[State] events at login: N registered, 0 unavailable`, each once.
  `/bl debug off`, `/bl debug on` → neither of those two lines comes back. Result:
- **DIAG-3. One summary per pass.** Move something at your bank → one `[Move]` summary line per pass,
  not one per item. Result:
- **DIAG-4. Scroll and counter.** The scrollbar follows the wheel both ways; the counter reads
  `N / 3000 lines`. Result:
- **DIAG-5. Copy and Clear.** Copy → a monospace box with the plain log, no color codes. Clear → both
  empty and the counter reads `0 / 3000`. Result:
- **DIAG-6. Logging off.** `/bl debug off` → a red OFF ack and `[Debug] logging disabled`. Turn it on
  and `/reload` → off again (the flag is session-only). Result:
- **DIAG-7. Chrome.** The console and its Copy box wear the ledger window's edge (a flat 1px black
  border with a 1px light-gray line inside, a gold title, a gray divider), with a smaller close
  control, 18×18 on a 26px title bar, drawn as the outlined × mark. That size is the library's, not
  drift. Result:
- **DIAG-8. Three title-bar marks.** Right to left: close, clear, copy, one size and pitch, gray at rest
  and brighter under the pointer, the art every Ka0s window uses. **Fail:** the words `Copy` and
  `Clear`, or a thin multiplication sign for close: `core/DebugLogSetup.lua` stopped passing
  `addonName`, or the art is missing from the payload (with the marks clear is 18 wide and copy sits
  at `-54`; with words, 42 and `-78`). Result:
- **DIAG-9. No tooltips on the marks.** Hover copy, clear and close, here and on the Copy box → each
  brightens and nothing pops up. A tooltip there is a regression. Result:
- **DIAG-10. A monospace log.** Timestamps, `[Tag]` prefixes and `[Move]` numbers line up in straight
  columns, in the console and the Copy box. **Fail:** proportional text: `NS.MediaFont("JetBrains
  Mono")` answered nil (`LibKa0s-Media-1.0` missing, or `core\MediaSetup.lua` after
  `core\Constants.lua` in the TOC). Result:
- **DIAG-11. One console look.** Open another Ka0s addon's console beside this one → apart from the
  titles, indistinguishable: border, inner line, gold title, divider, the same three marks in order. A
  difference is fixed in `../LibKa0s`, never in `libs/`. Result:
- **DIAG-12. The addon's own dumps.** With logging off, `/bl debug scan` at a bank, then `/bl debug
  panel` after opening `/bl config` once → both open the console and write their lines anyway, tagged
  `[Scan]` and `[Panel]`; the scan ends with the `events registered` / `events UNAVAILABLE` pair
  ([debug.md](debug.md)). An empty console means a dump went through the gated sink. Result:
- **DIAG-13. The report appends with logging off.** `/bl debug on`, move something, `/bl debug off`,
  then `/bl diagnostics` at the open bank → the `[Move]` lines sit above a `[Diag] ==== Ka0s Bank Ledger
  diagnostics begin ====` line and the report is complete, although logging was off when it ran (the
  run turns logging on first, DIAG-29). Chat prints one line, *Diagnostic report written to the debug
  console: N lines. Use Copy to share it.* `/bl debug off`. Result:
- **DIAG-14. The report's sections.** In order, each under its tag: `[State]`, `[Set]`, `[Filter]`,
  `[Ledger]`, `[Capture]`, `[Session]`, `[Scan]`, `[Window]`, `[Launcher]`, `[Env]`, ending
  `[Diag] ==== Ka0s Bank Ledger diagnostics end: N line(s) ====` with the chat line's N. A
  `section <name> failed:` line names a section that raised. Result:
- **DIAG-15. A second report and the copy.** `/bl debug diagnostics` → a second report of the same shape
  below the first. Copy, paste into an editor → the trace and both reports, no `|c`, `|T` or `|H`
  escapes; ledger entries show an item id and a plain name, never a link. Result:
- **DIAG-16. The guild cache caveat.** Run the report with the guild bank closed → `[Scan]` opens with
  `guild bank frame closed: the tab counts below are the client's cache, not fact`. Result:
- **DIAG-17. Diagnostics while disabled.** Untick Enable Bank Ledger, run `/bl diagnostics` and
  `/bl debug diagnostics` → both write a full report; `[State]` reads `disabled=true stood down=true`;
  `[Capture]` and `[Session]` each print one `stood down:` line. `/bl debug diag` toggles the console
  and `/bl diag` is an unknown command. Re-enable. Result:
- **DIAG-18. The buffer cap.** With logging on, keep logging (moves, or repeated `/bl diagnostics`) past
  3000 → the counter pins at `3000 / 3000 lines`, the oldest lines scroll away, and Copy still opens
  without a hitch. Result:
- **DIAG-19. A reset logs one line.** With logging off, `/bl resetall` ▸ Yes first: earlier checks
  leave settings off their defaults (Minimum quality, Session window), and the count takes in every
  one. `/bl debug on`, `/bl debug` to open the console. `/bl set settings.qualityThreshold 4`,
  `/bl set settings.rowHoverAlpha 0.3`, `/bl resetall` ▸ Yes → the console closes (a reset ends it,
  PANEL-28); `/bl debug` reopens it on exactly one
  `[Set] reset profile 'Default' to defaults (2 rows)` line and no `[Set] settings.… = …` line under
  it. `/bl resetall` ▸ Yes again, `/bl debug` → one `… (0 rows)` line. General's Defaults ▸ Yes,
  `/bl debug` → one more `… (0 rows)` line (`debug-logging-§10`). `/bl debug off`. Result:
- **DIAG-20. The console resizes.** `/bl debug` → the console opens at its usual 700 × 344, with a
  small size grip in the bottom-right corner. Drag the grip out and back in → the window follows on
  both axes; the log reflows to the new width, the scrollbar still reaches the first and the last
  line, the counter stays readable beside the grip, and copy, clear and close stay in the title bar.
  The lines and the scroll position are the ones you had. Result:
- **DIAG-21. The console's minimum holds.** Drag the grip as far up and left as it goes → it stops
  while the title and all three marks still fit in the title bar and a few log lines still show
  between the bars; nothing overlaps. Result:
- **DIAG-22. The size is kept for the session only.** Resize the console, close it, `/bl debug` → it
  reopens at the size you left. `/reload`, `/bl debug` → back at 700 × 344. Result:
- **DIAG-23. Each copy window resizes on its own.** Copy on the console → the Copy box has its own
  grip; resize it on both axes → the text box widens and narrows with it, the scroll bar's down button
  stays clickable above the grip, and it will not shrink below about 240 × 140. Close and Copy again →
  the size you left. Then History ▸ Export ▸ Export to CSV → the export's copy window opens at its own
  default, not the Copy box's size; resize it, export again → it keeps its own size. `/reload` → both
  back at their defaults. Result:
- **DIAG-24. Another addon's console is unaffected.** With a second Ka0s addon installed, resize this
  console, then open the other addon's console → it opens at its own size (700 × 344 on a fresh
  session). Resize that one → this console keeps the size you gave it. Result:
- **DIAG-25. An idle bank is quiet.** `/bl debug on`, `/bl debug`, open your bank and move nothing for
  a minute, opening and closing a bag or two → after the `[Store] BANK_FRAME opened` line and one
  `[Diff]` line per store, nothing more, however many passes ran. A pass that repeats an identical
  `[Diff]` line (or folds it into `(x2)`) is the regression ([debug.md](debug.md#coverage)). Result:
- **DIAG-26. The combat edges are in the log.** With logging on, set General visibility to Only out of combat with the ledger window open, pull a
  training dummy → `[Combat] entered: visibility outOfCombat, hid 1, re-showed 0`; leave combat → the
  window is back and a `[Combat] left: … re-showed 1` line. Put visibility back to Always. Result:
- **DIAG-27. A refusal names its guard.** With logging on and General visibility on Never,
  `/bl show` → the window stays shut and the console has `[UI] window show refused: visibility
  never`. In combat, `/bl test` → `[Table] test mode start refused: in combat`. Put visibility back.
  Result:
- **DIAG-28. The Diagnostics link.** `/bl debug` → in the title bar, top left, the word
  **Diagnostics** in orange sits just after the Debug: OFF label with a small gap: plain text like that
  label, no button art, brighter under the pointer. `/bl debug on` → the same gap after Debug: ON.
  Click it → a full report is written into the console exactly as `/bl diagnostics` writes it, with
  the same chat line. `/bl debug off`. Result:
- **DIAG-29. Diagnostics turns logging on for the session.** With logging off, click Diagnostics →
  the header flips to Debug: ON, and `[Debug] logging enabled` and an `[Init]` summary sit above the
  report's begin marker; move something at your bank → a `[Move]` line. Click it again → a second
  report and no second `[Debug] logging enabled` line. `/bl debug off`, then `/bl diagnostics` →
  logging is on again, the same way. `/reload`, `/bl debug` → Debug: OFF: the report turned logging
  on for that session only. Result:
- **DIAG-30. A slash refusal shows in the console.** `/bl debug on`, `/bl debug`, then `/bl
  frobnicate` → chat says `unknown command 'frobnicate'` as before, and the console has one `[Cmd]
  refused frobnicate: unknown verb` line. Untick Enable Bank Ledger, `/bl show` → chat has the
  disabled line, the console one `[Cmd] refused show: disabled` line and no second line repeating
  it. Re-tick Enable Bank Ledger. Result:
- **DIAG-31. A Lifecycle edge shows in the console, once.** With logging on, untick and re-tick
  Enable Bank Ledger → one `[Lifecycle] stood down: added disabled (holds: disabled)` line, then
  one `[Lifecycle] stood up: released disabled (holds: none)` line followed by `[State] events: N
  registered, 0 unavailable`; no `[State] stood down` or `[State] stood up` line beside them. Now
  untick Enable Bank Ledger, `/reload`, `/bl debug on` → after `[Init]`, one `[State] stood down at
  login (holds: disabled)` line. Re-tick Enable Bank Ledger. Result:

## DEGRADED

With `libs/LibKa0s` renamed aside (Before you start). Nothing about the addon's own function depends
on the library; the nine seams (`core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `core/EnvSetup.lua`,
`core/ItemSetup.lua`, `core/LifecycleSetup.lua`, `core/MediaSetup.lua`, `core/PoolSetup.lua`,
`settings/OptionsSetup.lua`, `settings/Slash.lua`) each degrade rather than error.

- **DEGRADED-1. Zero errors, two lines at login.** Log in → not one Lua error, and the addon prints
  exactly two lines: the notice (DEGRADED-2), then `[BL] The LibKa0s library is missing from this
  installation of Ka0s Bank Ledger (expected in libs/LibKa0s), so the settings panel is unavailable.`
  The second comes from the settings category registering at login (`NS.Panel:Register` in
  `addon:OnInitialize`), whose stub answers once per session; as the addon's first printed line it
  brings the notice with it. Result:
- **DEGRADED-2. The notice.** The first of the two login lines reads `[BL] The LibKa0s library is
  missing from this installation of Ka0s Bank Ledger (expected in libs/LibKa0s); running on reduced
  built-in fallbacks.` The clause up to `(expected in libs/LibKa0s)` matches every other Ka0s addon's
  word for word; a difference is the finding. Result:
- **DEGRADED-3. Said once.** `/bl version`, then `/bl version` again → one line each time,
  `[BL] v<version>`, and no notice above either. It prints once per session, on the first line the
  addon prints, and that line came at login. Result:
- **DEGRADED-4. The settings CLI explains itself.** `/bl list` and `/bl get settings.enabled` → each
  one line, `[BL] The LibKa0s library is missing from this installation of Ka0s Bank Ledger (expected
  in libs/LibKa0s), so the slash help index and the settings CLI (list/get/set/reset) are
  unavailable.`, and nothing else. Result:
- **DEGRADED-5. The addon still works.** `/bl show` → the ledger opens and behaves, and chat reads
  `[BL] Filters need LibKa0s. The ledger itself is unaffected.` This first `/bl show` of the session
  builds the window, and only the build prints that line (DEGRADED-8 checks the bar itself). A bank
  movement still records. `/bl config` and bare `/bl` → no panel and nothing in chat (the settings
  panel's one line printed at login, DEGRADED-1). `/bl debug` → one line ending
  `, so the debug console window is unavailable.` and no console. `/bl diagnostics` → one line, `/bl diagnostics is unavailable: the LibKa0s library did not
  load.`, and nothing else. Result:
- **DEGRADED-6. The profile verb explains itself.** `/bl profile` and `/bl profile Default` → each one
  line, `/bl profile is unavailable: the LibKa0s library did not load.`, and no switch. Result:
- **DEGRADED-7. The Media fallbacks.** The ▲/▼ column in History and in the session window →
  proportional text, and ▲/▼ drawn as boxes. Correct here; the same with `libs/LibKa0s` in place is a
  broken seam. (The console and the Copy box are unreachable in this state; DEGRADED-11 checks the
  console's font on restore.) Result:
- **DEGRADED-8. No filter bar.** In the ledger DEGRADED-5 opened → no filter bar (none of its eight
  dropdowns), and the History table below still works unfiltered. `/bl hide`, then `/bl show` → the
  same window comes back and chat stays quiet: the window is built once per session, and the
  filter-bar line came with that build (DEGRADED-5). Result:
- **DEGRADED-9. The fallback marks.** Every other surface still draws something: the font-character ×,
  `Arrow-Up-Up` sort arrows, boxed `+`/`-` group expanders, and the four header marks still gold (the
  tint rides on the escape). A near-white one means the fallback lost the tail. Nothing blank or off
  center. Result:
- **DEGRADED-10. The export modal is unreachable.** There is no Export button anywhere and no way to
  open the modal (it lives on the filter bar). `tests/test_export.lua` covers the modal on this rung.
  Result:
- **DEGRADED-11. Restore.** Quit, rename `libs/LibKa0s.off` back, log in → no notice, `/bl list`
  byte for byte the healthy listing kept before the rename (Before you start), the console monospace
  again with its three marks. Result:
- **DEGRADED-12. Windows still resize without the library.** Run it before DEGRADED-11's restore.
  `/bl show` → the grip is there at the old 2px inset with no pressed art, and dragging it resizes
  the window. Open a bank → the session window's grip does the same. `/reload` → both sizes are
  kept. Result:

## Non-English client

Run on a client set to **deDE or frFR**, the two the collection's other locale checks use
(ConsumableMaster LOC-1, KickCD LOC-1). Any character with a bank works. The headless suite is blind
here: `tests/wow_mock.lua` answers enUS for every localized global, so a path keyed on a display
string is green whether it is right or wrong.

What this addon reads in the player's language:

- **`entry.itemType` / `entry.itemSubType`** (`modules/Ledger.lua:502-507`, via
  `core/Compat.lua:153-159`): `C_Item.GetItemInfo`'s localized strings. `core/Database.lua:519-550`
  uses them as analytics keys (`byItemType`, `byItemSubType`, `byTypeSub`), they are persisted on every
  row, and the CSV emits them raw. `core/Compat.lua:156` discards the locale-independent `classID` /
  `subClassID`; unlike `quality` and `store`, these two have no `*Raw` column.
- **`NS.Item.QualityLabel`** (`core/ItemSetup.lua:59-62`): `_G["ITEM_QUALITY" .. q .. "_DESC"]`,
  localized by design, with the numeric `qualityRaw` beside it in the CSV.
- **`Util.FormatDate`** (`core/Util.lua:20-22`): `date("%d-%b-%Y")`, whose `%b` is the month in the
  client's language.
- **Case folding**: `modules/LedgerTable.lua:66`, `:85`, `:89`, `:94` sort on `:lower()`, and
  `core/Database.lua:415` and `:432` lowercase names and search text. Lua's `string.lower` folds ASCII
  only.

English by design, and not a failure: `C.StoreLabel`, `C.DirectionLabel`, `C.KindLabel` and every
label, tooltip and chat line the addon prints; the CSV header row stays byte-identical to enUS (a key
another tool parses).

- **LOC-1. Type facets in the client's language.** Deposit armor and a trade good, open Insights and
  read Movements By Item Type and the sub-type facets → labels in the client's words (`Rüstung`,
  `Handelswaren`), right counts, and the type × sub-type pivot paired correctly. **Fail:** a numeric or
  empty label, or one category counted twice. If this account has rows captured on an English client
  (or you capture some and switch language), look for both spellings in one facet list: one category
  under an English and a German label is the persisted-display-string defect. Record what you see
  either way; a split list is a finding to file. Result:
- **LOC-2. The export contract.** History ▸ Export ▸ Current View ▸ Export to CSV → the header row
  byte-identical to enUS (`ts,date,time,char,classFile,…`, all ASCII), `quality` localized with
  `qualityRaw` numeric beside it, `direction` / `store` / `kind` English. **Fail:** a translated header
  key, or a `storeRaw` / `qualityRaw` cell that is not the raw token. Write down the `date` cell's month
  token (`11-Jul-2026` on enUS) and one `itemType` / `itemSubType` pair: they decide whether the CSV
  is locale-independent in fact. Result:
- **LOC-3. Sort and search over non-ASCII text.** With item names starting with an accented or
  umlauted letter, sort the Item column both ways, then search the name in lower case with the accent
  (`änderung`, `épée`) → accented names sort among their unaccented neighbors and search finds the
  row in either case. **Fail:** accented names clumped at one end, or a search that needs the exact
  capital. This is the check most likely to fail. Result:
- **LOC-4. Nothing else moved.** Run INSTALL-1 to INSTALL-7, CAPT-1, CAPT-2, LEDG-4 to LEDG-18 and
  LEDG-21 on this client → they behave as on English. **Fail:** any Lua error (a localized string
  reached code that assumed English). Result:
- **LOC-5. Quality names are the client's.** Capture ▸ Minimum quality → the six names in the client's
  language, never English. Result:

No sign-off exists without a non-English client for LOC-1 to LOC-3 and LOC-5: the headless cases on
these paths (`test_database`'s analytics grouping, `test_export`'s column contract,
`test_ledgertable`'s sort keys) feed the mock's English in and read the same English back. Until the
pass runs, record this section as unrun, not as coverage.

## Pending sign-off

A check is listed here until a client run records a pass for it in its current form: every check new
in the 2026-09-29 rework, every check whose expectation was corrected against the code (by SP-BL-01
for profiles, and by SP-BL-03 and its review fixes, SP-BL-03R), and every check carried over from the
pre-rework document (the `S-n` sections and steps as of commit `16398dd`) with no recorded pass. That
document kept no `Result:` lines, and Session BL of the 2026-09-23 remediation's in-client checklist,
which ends by walking this whole document, is still owed, so most checks are here. Sign one off on
its own `Result:` line, then remove its ID from this table.

Not listed, because a recorded pass covers them and the rework did not change what they expect:
INSTALL-4 (S-1 step 5, passed in the owner's minimap re-check of 2026-09-25 on
the launcher-menu builds, step X1.4 of the 2026-09-23 remediation's checklist), and
DIAG-14 – 18 and COMBAT-8 (S-14 steps 14–17, passed in the owner's run of 2026-09-26 as rows
BL-S1 – BL-S5, BL-S7, BL-S8 and BL-X1 of the diagnostics rollout's report), and CAPT-18 and CAPT-19
(new with the login backfill, GI-BL-01, and passed in the owner's run of 2026-10-02 as rows BL-1 – BL-3
of the 2026-10-01 GitHub issue pass's smoke tests). The records are in the Ka0sAddonsCommonTasks
repository.

| ID | Origin | Why it is owed |
|---|---|---|
| INSTALL-1 | S-1 steps 1 and 3, S-23 step 1 | No recorded result |
| INSTALL-2 | S-1 step 2, corrected by SP-BL-03 | The old step expected a hardcoded `[BL] v1.2.0`; it now expects the version the TOC's `## Version` line carries |
| INSTALL-3 | S-1 step 4 | X1.4's pass recorded the status tooltip, not the button's own logo (`launcher-§4`) or the same art beside Ka0s Bank Ledger in the AddOns list; no recorded result for those |
| INSTALL-5 | S-1 step 6 (the menu's shape and the Show window entry) | X1.4's pass recorded that right-click opens the menu, not that Show window opens the ledger, shows ticked and closes it again; no recorded result |
| INSTALL-6 | S-1 step 6 (the Test mode and Locked entries) | X1.4's pass recorded the menu opening, not these entries' chat lines; no recorded result |
| INSTALL-7 | S-1 step 7 | No recorded result |
| INSTALL-8 – 10 | S-25 steps 1–7 | Marked NOT YET RUN since the 2026-09-07 remediation (session 2, `M2-05`). Its `[Migrate]` expectation could never pass in a client (logging is off when the ladder runs), so the evidence is now `[State]`, the file and a profile switch |
| SLASH-1 | S-12 step 1 | No recorded result |
| SLASH-2 | S-12 steps 4–5 | No recorded result |
| SLASH-3 | S-28 step 6, corrected by SP-BL-03R | While disabled, `/bl wibble` and `/bl perf` print the index with its refusal line under the header; the old wording ("not the refusal") read as no refusal line at all |
| SLASH-4 | S-28 step 7 | No recorded result |
| PANEL-1 | S-12 step 2 | No recorded result |
| PANEL-2 | S-11 step 6, S-30 step 2 | No recorded result; the Profiles entry came with S-30 (SP-BL-01), which has never run |
| PANEL-3 – 10, PANEL-15 | S-12 step 3 (PANEL-6 also S-23 step 2) | No recorded result |
| PANEL-11 | S-26 steps 1–4 | NOT YET RUN since the 2026-09-07 remediation (session 3, `M4-01`) |
| PANEL-12 | S-12 step 6 | No recorded result |
| PANEL-13 | S-21 step 8 | No recorded result |
| PANEL-14 | S-19 steps 1–4 | No recorded result |
| PANEL-16 | S-7 step 4, S-20 step 3 | No recorded result |
| PANEL-17 | S-20 steps 4–5, corrected by SP-BL-03R | The slider's box reads `2` and `1`; the old step expected `2.00` and `1.00` there |
| PANEL-18 | S-12b step 1 | No recorded result |
| PANEL-19 | S-12 step 3 and S-12b step 2, corrected by SP-BL-03R | Master alpha is a percent slider, so its box stops at `10%`; the old step expected `0.10` there |
| PANEL-20 | S-12b step 4 | No recorded result |
| PANEL-21 – 25 | S-12a steps 1–6 | No recorded result |
| PANEL-26 | S-20 steps 1–2 | No recorded result |
| PANEL-27 | S-12 step 3 and S-16 step 3 as rewritten by SP-BL-01 | The popup now says it resets this profile and leaves the others alone; master's doc expected the old wording |
| PANEL-28 | S-12 step 3 and S-16 step 3 as rewritten by SP-BL-01 | Yes now keeps every History row; master's doc expected Yes to empty History, the opposite |
| PANEL-29 | S-16 step 5 as rewritten by SP-BL-01, corrected by SP-BL-03R | History, Insights and the read-out now keep their rows (master's doc expected them to go empty, the opposite); the setup is now one a client can arrange, and the list-empties half is PANEL-31's alone |
| PANEL-30 | S-16 step 4 | No recorded result |
| PANEL-31 | S-20 steps 6–8, corrected by SP-BL-03R | Yes keeps the ledger, so the Database size line no longer changes; old step 6 expected it to update |
| PROFILE-1 – 7, PROFILE-14 | S-30 steps 1–8 | Added with profile support (SP-BL-01, 2026-09-29); never run |
| PROFILE-8 – 13 | New (the `/bl profile` verb, SP-BL-02) | Never run |
| STATE-1 – 3, STATE-5, STATE-6 | S-28 steps 1–4, 8 and 9 | No recorded result |
| STATE-4 | S-28 step 5 | X1.4's pass recorded the disabled left-click and right-click; the grayed menu entries have no recorded result |
| STATE-7 | S-16 step 6 | Step BL.13 of the 2026-09-23 checklist's Session BL, still owed; no recorded result |
| STATE-8, STATE-9 | S-12b steps 3 and 5 | No recorded result |
| COMBAT-1 – 3 | S-13 steps 1–5 | No recorded result |
| COMBAT-4 | S-15 step 8, corrected by SP-BL-03R | A click on the box in combat meets the settings combat lock (COMBAT-3), not the test-mode refusal, so the refusal is now read from `/bl test` and the box after combat |
| COMBAT-5, COMBAT-6 | S-12b steps 6–7 | Step BL.15 of the 2026-09-23 checklist's Session BL, still owed; no recorded result |
| COMBAT-7 | S-12b step 8 | No recorded result |
| CAPT-1 – 8 | S-2, S-3, S-4 steps 1–3, S-5 steps 1–7 | No recorded result |
| CAPT-9 | S-6 steps 1–2 | Step BL.17 of the 2026-09-23 checklist's Session BL, still owed; no recorded result |
| CAPT-10, CAPT-11 | S-6 step 3 | No recorded result |
| CAPT-12 | S-6 step 4 and S-17 step 13, corrected by SP-BL-03R | The `[Store] GUILD_BANK opened` line is logged only with logging on, and S-17 step 13 never turned it on (S-14 steps 6–7 had turned it off and reloaded), so the check now reopens the guild bank after `/bl debug on` |
| CAPT-13 | S-6 step 5, S-17 step 13 | No recorded result |
| CAPT-14 | S-17 step 14, corrected by SP-BL-03R | A `/reload` turns logging off, so the old order (`/bl debug on`, then `/reload`) could never show the `[Store]` line it watched for |
| CAPT-15 | S-23 step 4, corrected by SP-BL-03R | The same: the `uncached` skip is logged only with logging on, which the `/reload` had turned off |
| CAPT-16 | S-16 step 1 | Step BL.16 of the 2026-09-23 checklist's Session BL, still owed; no recorded result |
| CAPT-17 | S-16 step 2 | No recorded result |
| LEDG-1 – 3 | S-7 steps 1–3 | No recorded result |
| LEDG-4 – 18 | S-8 steps 1–15 (LEDG-5 also S-4 step 4) | No recorded result |
| LEDG-19 | S-23 step 3, corrected by SP-BL-03 | The old step exported with `/bl export`, which is not a verb; the export now goes through the Export button |
| LEDG-20 – 27 | S-15 steps 1–7, 9 and 10 (LEDG-21 also S-8 steps 8 and 16) | No recorded result |
| LEDG-28 – 32, LEDG-36 | S-24 steps 1–7 (merged with S-10 steps 1–3, S-21 step 2) | S-24 was NOT YET RUN since the `CopyWindow` adoption |
| LEDG-33, LEDG-34 | S-10 steps 4–5 | No recorded result |
| LEDG-35, LEDG-37 – 41 | S-21 steps 1–7 | No recorded result |
| LEDG-42 – 46 | S-22 steps 1–5 | No recorded result |
| LEDG-47, LEDG-48 | New (the library's resize grip, CA-BL-01, BankLedger#21, LibKa0s v1.67.0) | Never run |
| LEDG-49 | New (the search box's suggestion list, P9, LibKa0s v1.70.0) | Never run |
| LEDG-50 | New (per-tab filter views, owner request 2026-10-07, schema v5) | Never run |
| INS-1 – 14, INS-16, INS-17 | S-9 steps 1–14, 16 and 17 | No recorded result |
| INS-15 | S-9 step 15, rewritten for per-tab views (2026-10-07) | The old step asserted one filter shared by both tabs; each tab now keeps its own |
| INS-18 | S-9 step 18, corrected by SP-BL-03R | The empty state is one of two named lines, and Character: Current counts as a filter; the old "no movements" line matched neither |
| FILT-1 – 7 | S-11 steps 1–8 | No recorded result |
| FILT-8 | S-11 step 9, corrected by SP-BL-03R | The lookup line ends in three periods (`Looking up items...`); the old step had an ellipsis character |
| FILT-9 | S-11 step 10 | No recorded result |
| FILT-10 – 14 | S-29 steps 1–7 and its closing note | No recorded result |
| FILT-15 | New (the Options descriptor's `addonName`, CA-BL-NM, LibKa0s#42, LibKa0s v1.67.0) | Never run |
| SESS-1 – 8 | S-17 steps 1–12 | No recorded result |
| SESS-9 | S-17 step 13 | Step BL.17 of the 2026-09-23 checklist's Session BL, still owed; no recorded result |
| SESS-10 | S-17 step 15 as rewritten by SP-BL-01 | Geometry now belongs to the profile; master's doc expected it to be account-wide |
| SESS-11, SESS-12 | S-17 steps 16–17 | No recorded result |
| SESS-13 | New (the library's resize grip, CA-BL-01, BankLedger#21, LibKa0s v1.67.0) | Never run |
| DIAG-1 – 12 | S-14 steps 1–13 | No recorded result; the 2026-09-26 diagnostics run recorded only the report steps. DIAG-2 corrected by DG-BL-01: the `[Init]` tail no longer names the launcher; the Launcher's own line and the login's event record follow it (LibKa0s v1.65.0) |
| DIAG-19 | S-20 step 9 as rewritten by SP-BL-01, corrected by SP-BL-03R | The line is now `[Set] reset profile 'Default' to defaults (N rows)` (master's doc expected `[Set] reset all: N rows`); the check now starts from stock, since leftovers from earlier checks change the count, and reopens the console each reset closes |
| DIAG-20 – 24 | New (resizable console and copy windows, DL-BL-01, LibKa0s v1.64.0) | Never run |
| DIAG-25 – 27 | New (debug coverage, DL-BL-02); DIAG-26's stand-down/stand-up half moved to DIAG-31 by DG-BL-01 | Never run |
| DIAG-13 | S-14 steps 14–17, corrected by DL-BL-03 | The report now turns logging on for the session (`debug-logging-§14`), so the header no longer reads Debug: OFF after it and a later move logs; the 2026-09-26 pass recorded the old expectation |
| DIAG-28 – 29 | New (the Diagnostics link, and diagnostics turning logging on, DL-BL-03, LibKa0s v1.64.0) | Never run |
| DIAG-30 – 31 | New (the library's own `[Cmd]` and `[Lifecycle]` lines, DG-BL-01, LibKa0s v1.65.0) | Never run |
| DEGRADED-1 – 5, DEGRADED-7, DEGRADED-11 | S-18 steps 1–8 as rewritten by SP-BL-03R | Login now prints the notice and the settings-panel line; `/bl version` prints no notice; `/bl list` and `/bl get` print the CLI-unavailable line, not a listing; `/bl config` opens nothing; `/bl debug` opens no console; the first `/bl show` prints the filter-bar line; the Media check keeps to reachable surfaces; the restore compares against a healthy listing taken first. Several are the opposite of what S-18 asked |
| DEGRADED-6 | New (the `/bl profile` verb, SP-BL-02) | Never run |
| DEGRADED-8 | S-21 step 9, corrected by SP-BL-03R | No recorded result. The filter-bar line now belongs to DEGRADED-5's first `/bl show`, the one that builds the window; the old step saw it because it began with its own rename and `/reload` |
| DEGRADED-9 – 10 | S-21 step 9 | No recorded result |
| DEGRADED-12 | New (the fallback resize grip, CA-BL-01, BankLedger#21, LibKa0s v1.67.0) | Never run |
| LOC-1 – 4 | S-27 steps 1–4 | NOT YET RUN since the 2026-09-07 remediation (session 6, `M5-08`); needs a deDE or frFR client |
| LOC-5 | S-23 step 2 (last sentence) | No record of a run on a non-English client |
