# Ka0s Bank Ledger

![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
[![Standard](https://img.shields.io/badge/Ka0s-WoW%20Addon%20Standard-yellow)](https://github.com/tusharsaxena/WowAddonStandards)
![Tests](https://img.shields.io/badge/Tests-335%2F335_passing-green)

![Logo](media/logos/bankledger.logo.jpg)

Ka0s Bank Ledger is a passbook for your banks. Every time you put something in or take something
out — your own bank, the warband bank, the guild bank — it writes a
line: what moved, which way, how much, and when. Gold is tracked the same way at the two banks that
hold gold.

It records **movements**, not contents. It never tries to tell you what is sitting in your bank
right now; it tells you the story of how it got that way, which is the thing the game itself
forgets the moment you close the window. The ledger is account-wide, so every character writes to
and reads from the same book.

Open it with `/bl`, browse and filter the History tab, switch to Insights for the totals, and use
Export whenever you want the numbers in a spreadsheet. Configure it in the Blizzard settings panel
or with `/bl config`.

## What's new in 0.1.0

- First release: a full passbook of item and gold movements between your bags and your banks.
- Covers the character bank, the warband bank and the guild bank.
- History tab with search, per-column filters, grouping and sorting over a fast pooled table.
- Insights tab with deposit/withdrawal totals, gold in and out, and per-store and per-character
  breakdowns.
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
| `/bl preview` | Toggle a sample ledger |
| `/bl purge` | Delete ALL ledger history (asks first) |
| `/bl debug` | Toggle the console; `on`/`off` set logging |
| `/bl help` | Show this help |

### Settings panel

| Tab | Covers |
| --- | ------ |
| General | What gets recorded, how long it is kept, and the window's scale |
| Filters | The item blacklist and whitelist |

**General** has two sections. *Capture* is where you turn recording on or off, choose whether items
and gold are tracked, set a minimum item quality, pick how long history is kept, and tick which
banks you care about. *Window* holds the window scale and a switch for the debug console. Below
them, *Storage* shows how much you have recorded and how big it is, with a button to wipe it.

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
| Does it slow the game down? | It only does anything while a bank window is open, and the window builds rows only for what fits on screen. |
| Where is my data kept? | In the addon's SavedVariables file, on your own machine. Nothing is sent anywhere. |

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| Nothing is recorded | Check `Enable capture` is on in Settings ▸ General, and that the bank you are using is ticked in "Record movements to and from". |
| An item is missing from the list | It may be below your minimum quality, or on the blacklist. Check Settings ▸ Filters. |
| Gold deposits are not showing | Gold is only tracked at the guild bank and the warband bank. The character bank has no gold slot. |
| Settings won't open in combat | That is deliberate. Blizzard protects the settings panel in combat, so the addon refuses rather than risk breaking it. Run `/bl config` again after the fight. |
| The window vanished off-screen | Settings ▸ General ▸ **Reset all** recentres it (it also clears your history, so export first if you want to keep it). |
| Something looks wrong and you want to report it | `/bl debug on`, reproduce it, then `/bl debug`, hit **Copy**, and paste the log into an issue. |

## Issues and feature requests

Bugs and feature requests are tracked at
[github.com/tusharsaxena/BankLedger/issues](https://github.com/tusharsaxena/BankLedger/issues).
Please file them there rather than in comments — it is the single place the project's to-do list
lives.

## Version History

| Version | Date | Highlights |
| ------- | ---- | ---------- |
| 0.1.0 | 2026-07-26 | First release. Item and gold movements across the character bank, the warband bank and the guild bank; History and Insights tabs; CSV export; item blacklist and whitelist. |
