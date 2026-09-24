# Ka0s Bank Ledger

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1629058)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-1034%2F1034_passing-green)

Ka0s Bank Ledger is a passbook for your banks. Put something in or take something out, at your own
bank, the warband bank or the guild bank, and it writes a line: what moved, which way, how much, and
when. Gold is tracked the same way at the two banks that hold gold.

It records movements, not contents. What is sitting in your bank right now is something the game
already shows you. How it got that way is the part the client forgets the moment the bank window
closes, and that is the part kept here. One book, account-wide, so every character writes to it and
reads from it.

## Screenshots

**_History browser_**

![History browser](https://media.forgecdn.net/attachments/1936/483/bankledger-screenshot-01-png.png)

![History browser](https://media.forgecdn.net/attachments/1936/484/bankledger-screenshot-02-png.png)

**_Insights panel_**

![Insights panel](https://media.forgecdn.net/attachments/1936/485/bankledger-screenshot-03-png.png)

![Insights panel](https://media.forgecdn.net/attachments/1936/486/bankledger-screenshot-04-png.png)

**_Current Banking Session (opens automatically at a bank)_**

![Current Banking Session](https://media.forgecdn.net/attachments/1936/487/bankledger-screenshot-05-png.png)

## Usage

`/bl show` opens the ledger and `/bl hide` closes it; `/bl toggle`, or a left-click on the minimap
button, does whichever the window is not already doing, and Escape and the X in the top corner close
it. A right-click on the minimap button, or `/bl config`, lands you in the settings instead. The
window opens on History, one line per movement, newest first, already scoped to whoever you are
logged in as. The bar above the table is how you narrow that: a search box for item names, dropdowns
for date, direction, store, quality, type, sub-type and character, and a Group dropdown that folds
the rows into blocks whose headers collapse when you click them. Any column header sorts on its
column, and clicking it again flips the direction. Once the view is the way you like it, **Save**
makes it the one every session opens on, **Clear** brings you back to it after you have wandered
off, and **Reset** returns the default to stock. Character scope is the one thing never saved, so
the window always opens on you, one click away from All.

Hover a row for the item's own tooltip. A gold row has no link to show, so it gets a small tooltip
built by hand with the amount spelled out in full, because the Qty cell can truncate it.
Shift-left-click drops the item into chat, and right-click opens the row menu: link it, blacklist
it, whitelist it, or delete that single line out of the book. The two lists are point-in-time, so
they decide what gets recorded from now on and leave everything already stored alone. If you want a
look around before you have any history of your own, `/bl test` puts a sample ledger on screen, and
so does the **Test mode** box on the Master controls tab. It stays on until you turn it off, or until
you enter combat. Only **Link to chat** works on those rows. The others would be writing fake item
ids into your real settings.

The Insights tab swaps the table out for charts drawn through the same filter, so the two always
describe the same slice. Fourteen headline figures come first, then seventeen charts, each of the
main breakdowns followed by its deposits-against-withdrawals companion, with the ranked "Top Of The
List" panels below. Gold charts appear only when the slice you are looking at contains a coin
movement. **Export** takes whichever tab you are on, asks for All Data or Current View, and hands
you the CSV in a copy box (Ctrl+C, then Esc). History rows carry a Wowhead link for the exact item
that moved, bonus IDs and all.

Then there is the window you never have to open. Walk up to a bank and **Current Banking Session**
opens with it, listing what you have moved during this visit as you move it; close the bank and it
closes too. It stores nothing of its own, and everything in it is in your history as well. Placing
it while a bank frame is in the way is a nuisance, so `/bl session` opens it on sample movements
away from one. Both windows drag by the title bar and size from the grip in the bottom-right corner,
and both come back where you left them — until you tick **Lock frame** on the settings' Master
controls tab, which pins every window the addon owns.

The minimap button wears the addon's own logo — the same picture the AddOns list shows beside the
name — and if you run Titan Panel, ElvUI's data texts or Bazooka, Bank Ledger turns up there too,
clicking exactly the same way. The **Minimap button** box on the Master controls tab hides it and
brings it back, and so does the button's own right-click menu; the two always agree, because they
are one switch. Neither **Defaults** nor **Reset all settings** touches it: whether the button is
there, and the spot around the minimap you dragged it to, is part of how your screen is arranged
rather than part of what the addon was told to do.

Everything else is configuration, and it lives in two places: the addon's own page under
Settings → AddOns in game, which `/bl` (or `/bankledger`) opens on its own, and `/bl help`, which
prints the full command list.

If you'd rather read your settings than click through them, `/bl list` prints every one with its
current value and `/bl get setting` answers for a single one; `/bl set setting value` changes
one from chat. Going the other way, `/bl reset setting` puts one back to its default. Every
*reset everything* control is one and the same act: `/bl resetall`, the **Defaults** button at the
top of Settings ▸ General (and Blizzard's own Defaults at the foot of the Settings window), and
**Reset all settings** on the Master controls tab all ask first, and saying Yes returns the addon
to a fresh install — your settings, both filter lists, your saved view **and your recorded
history** are discarded. Export first if you want to keep it. To delete history alone, use
`/bl purge`, which asks for confirmation too and leaves your settings be. `/bl version` prints the version to quote in
a bug report. And if you want the addon out of the way without unticking it in the AddOns list,
`/bl disable` stands it down and `/bl enable` brings it back — the same switch as the **Enable Bank
Ledger** box on the Master controls tab, so whichever you use, the other agrees.

**Off means off.** Nothing is watched, nothing is timed, nothing is drawn and nothing is recorded:
every event the capture engine listens for is unregistered rather than ignored, so the game stops
handing this addon work altogether. It is the same result as unticking it in Blizzard's own AddOns
list, without the reload.

What stays up is the way back in. Every command keeps working — you can read and change settings,
open the panel, print the version, run the debug console — and a bare `/bl` still opens the
settings window. What a stood-down addon will not do is **act**: ask it to show the ledger, toggle
the sample or purge your history, or left-click the minimap button, and it says it is disabled and
points you at `/bl enable` rather than quietly doing nothing. Right-click on the minimap button
still opens the settings.

## How the ledger works

The game never announces "you deposited this", so the addon works it out by watching.

1. When you open a bank, it takes a private snapshot of your bags and of that bank's contents.
2. Every time something changes, it takes a fresh snapshot and compares the two.
3. If an item's count went **down in your bags** and **up in the bank**, that is a deposit. The
   other way round is a withdrawal.
4. If something changed on only one side — you looted an item into your bags while the bank happened
   to be open — nothing is recorded, because nothing crossed between the two.
5. Gold works the same way, but only at the guild bank and the warband bank. Those are the only two
   with a gold slot, so a change in your money anywhere else came from something that was not a
   deposit.

Nothing is watched while every bank window is closed. Ordinary play, looting and vendoring and
questing, never ends up in the book.

## FAQ

| Question | Answer |
| -------- | ------ |
| Does it track what's in my bank right now? | No, and that is what a bag addon is for. This one keeps the record of what crossed in and out. |
| Is my history shared between characters? | Yes. One account-wide ledger, so an alt's deposits and your withdrawals sit in the same list. |
| Does it record currencies like Valorstones? | No. The book covers items and gold; currencies are deliberately out of scope. |
| Will it see what other people put in the guild bank? | No. It only sees what your own character does. |
| What is the small window that opens with my bank? | Current Banking Session, a live list of what you have moved during this visit. It keeps nothing of its own; everything in it is also in your history. Turn it off in Settings ▸ General if you would rather it did not appear. |
| Why does the session window forget everything when I reopen the bank? | Because it covers the visit you are on and nothing else. Anything older is in the main window. |
| Does it slow the game down? | It only does anything while a bank window is open, and both windows build rows only for what fits on screen. |
| Where is my data kept? | In the addon's SavedVariables file, on your own machine. Nothing is sent anywhere. |

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| Nothing is recorded | Check `Enable Bank Ledger` is on in Settings ▸ General ▸ Master controls, and that the bank you are using is ticked in "Record movements to and from" on the Capture tab. |
| An item is missing from the list | It may be below your minimum quality, or on the blacklist. Check Settings ▸ General ▸ Filters ▸ Blacklist. |
| Gold deposits are not showing | Gold is only tracked at the guild bank and the warband bank. The character bank has no gold slot. |
| Settings won't open in combat | That is deliberate. Blizzard protects the settings panel in combat, so the addon refuses rather than risk breaking it. Run `/bl config` again after the fight. |
| The window vanished off-screen | The **Reset position** button on Settings ▸ General ▸ Master controls recenters both windows and changes nothing else. Every reset control — **Defaults**, **Reset all settings** and `/bl resetall` — recenters them too, but it asks first and then discards your settings, filter lists and recorded history as well; export first if you want to keep it. `/bl purge` deletes history only. |
| The session window is in the way at the bank | Drag it by its title bar and resize it from the bottom-right corner; it remembers where you put it. `/bl session` opens it away from a bank so you can place it in peace, and Settings ▸ General turns it off for good. |
| The addon switched itself back on after Reset all settings | That is deliberate. **Reset all settings** returns everything to a fresh install, and a fresh install is enabled, so a reset made while the addon is disabled turns it back on. Untick `Enable Bank Ledger` again if you want it off. |
| Something looks wrong and you want to report it | `/bl debug on`, reproduce it, then `/bl debug`, hit **Copy**, and paste the log into an issue. Add the output of `/bl debug scan`, which writes to the console whether logging is on or not and reports which container ids and money readers your client actually exposes. |

## Issues and feature requests

Bugs and feature requests are tracked at
[github.com/tusharsaxena/BankLedger/issues](https://github.com/tusharsaxena/BankLedger/issues).
Please file them there rather than in comments. It is the single place the project's to-do list
lives.

## Version History

| Version | Date | Highlights |
| ------- | ---- | ---------- |
| 1.1.0 | 2026-09-10 | - The two id-lists are now one **Filters** tab, and the settings pages gained **Master controls**<br>- Fixed the guild bank arming on data arriving rather than on its frame showing, which could miss the first deposit of a session<br>- A disabled addon can now be re-enabled without a reload, and `/bl test` no longer confirms a toggle that never happened<br>- **Reset Everything** now clears the capture gate's stored settings instead of leaving dead ones behind<br>- Updated for game patch 12.1.0 |
| 1.0.0 | 2026-07-28 | - First release: a complete passbook of item and gold movements across the character, warband and guild banks<br>- History tab with search, per-column filters, grouping, sorting and a saved view<br>- Insights tab with fourteen headline figures and seventeen charts<br>- A live Current Banking Session window<br>- CSV export for either tab, with a Wowhead link per row |
