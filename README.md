# Ka0s Bank Ledger

![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
[![Standard](https://img.shields.io/badge/Ka0s-WoW%20Addon%20Standard-yellow)](https://github.com/tusharsaxena/WowAddonStandards)
![Tests](https://img.shields.io/badge/Tests-521%2F521_passing-green)

![Logo](media/logos/bankledger.logo.jpg)

Ka0s Bank Ledger is a passbook for your banks. Every time you put something in or take something
out — your own bank, the warband bank, the guild bank — it writes a
line: what moved, which way, how much, and when. Gold is tracked the same way at the two banks that
hold gold.

It records **movements**, not contents. It never tries to tell you what is sitting in your bank
right now; it tells you the story of how it got that way, which is the thing the game itself
forgets the moment you close the window. The ledger is account-wide, so every character writes to
and reads from the same book.

Open it with `/bl`, browse and filter the History tab, switch to Insights for the charts, and use
Export whenever you want the numbers in a spreadsheet. Configure it in the Blizzard settings panel
or with `/bl config`.

There is also a second, smaller window you never have to open yourself: whenever you are standing at
a bank, **Current Banking Session** lists what you have moved during that visit, as you move it.
Close the bank and it closes with it.

## What's new in 0.1.0

- First release: a full passbook of item and gold movements between your bags and your banks.
- Covers the character bank, the warband bank and the guild bank.
- History tab with search, per-column filters, grouping and sorting over a fast pooled table.
- A live **Current Banking Session** window that opens with any bank and shows exactly what you moved
  during that visit.
- Insights tab with fourteen headline figures and eighteen charts: the deposit/withdrawal split, net
  flow per store, per-character/per-store/per-quality/per-type breakdowns (each with an In/Out
  companion), activity by day, hour and weekday, and ranked lists — by item, category and location,
  each split into All / Deposits / Withdrawals — of your most-moved and most-numerous items.
- Export either tab to CSV, for all your data or just the view you are looking at.
- Blacklist and whitelist by item, so the ledger records exactly what you care about.

## Usage

### Slash commands

`/bl` is the short form and `/bankledger` the long one; both do the same thing. Everything the
addon prints to chat carries the cyan `[BL]` tag.

| Command | What it does |
| ------- | ------------ |
| `/bl show` | Open the ledger window |
| `/bl hide` | Close the ledger window |
| `/bl toggle` | Toggle the ledger window |
| `/bl config` | Open settings |
| `/bl version` | Print addon version |
| `/bl get <setting>` | Get a setting value |
| `/bl set <setting> <value>` | Set a setting value |
| `/bl list` | List all settings |
| `/bl reset <setting>` | Reset one setting |
| `/bl resetall` | Reset all settings |
| `/bl test` | Toggle a sample ledger |
| `/bl session` | Toggle the banking-session window (sample data outside a bank) |
| `/bl purge` | Delete ALL ledger history (asks first) |
| `/bl debug` | Toggle the console; `on`/`off` set logging |
| `/bl help` | Show this help |

### Settings panel

| Tab | Covers |
| --- | ------ |
| General | What gets recorded, how long it is kept, and how the windows behave |
| Filters | The item blacklist and whitelist |

**General** has three sections. *Master Controls* is the top-level stuff: the switch that turns
recording on or off, the minimap button, whether the Current Banking Session window appears at a
bank, the debug console, and the window scale. *Capture* is what actually gets recorded — a minimum
item quality, how long history is kept (30 days by default), whether items and gold are tracked, and
which banks you care about. *Storage* shows how much you have recorded and how big it is, with a
button to wipe it.

**Filters** manages two lists of items by id. Blacklisted items are never recorded; whitelisted
items are always recorded, even below your minimum quality. Add an item by typing its id or by
shift-clicking its link into the box. Both lists only affect what happens from now on — nothing
already in your ledger is ever hidden or removed by them.

## How the ledger works

The game never announces "you deposited this", so the addon works it out by watching.

1. When you open a bank, it takes a private snapshot of your bags and of that bank's contents.
2. Every time something changes, it takes a fresh snapshot and compares the two.
3. If an item's count went **down in your bags** and **up in the bank**, that is a deposit. The
   other way round is a withdrawal.
4. If something changed on only one side — you looted an item into your bags while the bank happened
   to be open — nothing is recorded, because nothing crossed between the two.
5. Gold works the same way, but only at the guild bank and the warband bank. Those are the only two
   that have a gold slot, so a change in your money anywhere else came from something other than a
   deposit.

Nothing is watched while every bank window is closed, so ordinary play — looting, vendoring,
questing — never ends up in the book.

## FAQ

| Question | Answer |
| -------- | ------ |
| Does it track what's in my bank right now? | No. It tracks what moved in and out. Plenty of addons show you bank contents; this one shows you the history. |
| Is my history shared between characters? | Yes. One account-wide ledger, so an alt's deposits and your withdrawals sit in the same list. |
| Does it record currencies like Valorstones? | Not yet. Items and gold in this release; currencies are planned. |
| Will it see what other people put in the guild bank? | No. It only sees what your own character does. |
| What is the small window that opens with my bank? | Current Banking Session — a live list of what you have moved during this visit. It keeps nothing of its own; everything in it is also in your history. Turn it off in Settings ▸ General if you would rather it did not appear. |
| Why does the session window forget everything when I reopen the bank? | Because it answers "what did I just do", not "what have I ever done". The full record is in the main window. |
| Does it slow the game down? | It only does anything while a bank window is open, and both windows build rows only for what fits on screen. |
| Where is my data kept? | In the addon's SavedVariables file, on your own machine. Nothing is sent anywhere. |

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| Nothing is recorded | Check `Enable capture` is on in Settings ▸ General, and that the bank you are using is ticked in "Record movements to and from". |
| An item is missing from the list | It may be below your minimum quality, or on the blacklist. Check Settings ▸ Filters. |
| Gold deposits are not showing | Gold is only tracked at the guild bank and the warband bank. The character bank has no gold slot. |
| Settings won't open in combat | That is deliberate. Blizzard protects the settings panel in combat, so the addon refuses rather than risk breaking it. Run `/bl config` again after the fight. |
| The window vanished off-screen | Settings ▸ General ▸ **Reset all** recentres both windows (it also clears your history, so export first if you want to keep it). |
| The session window is in the way at the bank | Drag it by its title bar and resize it from the bottom-right corner; it remembers where you put it. `/bl session` opens it away from a bank so you can place it in peace, and Settings ▸ General turns it off for good. |
| Something looks wrong and you want to report it | `/bl debug on`, reproduce it, then `/bl debug`, hit **Copy**, and paste the log into an issue. |

## Issues and feature requests

Bugs and feature requests are tracked at
[github.com/tusharsaxena/BankLedger/issues](https://github.com/tusharsaxena/BankLedger/issues).
Please file them there rather than in comments — it is the single place the project's to-do list
lives.

## Version History

| Version | Date | Highlights |
| ------- | ---- | ---------- |
| 0.1.0 | 2026-07-26 | First release. Item and gold movements across the character bank, the warband bank and the guild bank; History and Insights tabs; a live Current Banking Session window; CSV export; item blacklist and whitelist. |
