# Scope

What Bank Ledger is for, and — the load-bearing half — what it deliberately is not for.

## At a glance

| | |
|---|---|
| Folder / TOC `Title` | `BankLedger` / `Ka0s Bank Ledger` |
| Client | Retail (Mainline) only — a single `## Interface:` line, currently `120007` |
| SavedVariables | `BankLedgerDB`, **account-wide `global` only** |
| Slash | `/bl`, aliased `/bankledger` |
| Chat tag | `NS.PREFIX` — the cyan bracketed `[BL]` tag |
| Layout | `core/ defaults/ locales/ modules/ settings/`, 24 source files |
| Substrate | Ace3 + vendored `LibKa0s`, all committed under `libs/` |

## In scope

Bank Ledger is a **passbook**. It records **movements** — what crossed the line between your bags and
a bank, when, and which way — across three stores: the character bank, the warband bank and the guild
bank. Gold is recorded the same way at the two stores that hold gold.

- **Items and gold.** Both directions, per store, per character, account-wide.
- **The variant that moved, not the base item.** A snapshot keeps the first hyperlink seen for each
  id, so a row points at the actual item level, tertiaries and sockets.
- **Reading the history back** — a virtualized History table, an Insights tab computed from one
  `Database:Stats` pass over the same filter, and CSV export of both.
- **A live session view** for the movements of the bank visit currently open.

## Explicitly out of scope

These are decisions, not gaps. Each one has a reason that would still apply tomorrow.

- **Inventory.** The addon never stores "what is in your bank". That is a state the game already
  shows you; the story of how it got that way is the thing the client forgets the moment you close the
  window.
- **Currencies.** The book covers items and gold. `Kind` carries no member for currencies and the
  export contract reserves no column — adding them would be a new feature, not a fill-in.
- **The guild log.** The addon only ever sees your own client's view, so it records what *you* moved.
  Other players' guild-bank withdrawals are invisible to it and always will be.
- **The reagent bank and void storage.** Midnight removed both — reagents live in the character-bank
  tabs now, and the client exposes neither events nor a container for void storage. The addon does not
  advertise stores it cannot observe; neither has an enum member.
- **Store-to-store transfers.** Moving an item straight from the character bank to a warband tab
  changes no bag count, and the "both sides must change" rule requires the bags to be one of the two
  sides. Recording it would need a second rule pairing two stores against each other.
- **Backfilling.** A movement made while capture is off is lost, not reconstructed — the baseline
  snapshot is only taken while capture is on. Likewise there is no name backfill: a row stored before
  the client cached the item keeps only its id.
- **Retroactive cleanup of pre-corroboration gold rows.** Nothing in a stored row distinguishes a real
  warband deposit from a bank-tab purchase that was recorded as one, so the addon cannot find them
  after the fact. Filter to Gold + Warband Bank in the History tab and delete by hand.
- **Per-character settings.** Account-wide is the design, not a simplification — see
  [schema.md](schema.md).

## Boundaries with the collection

The chat printer, debug console, options toolkit, slash dispatcher and test harness are **consumed**
from the vendored `LibKa0s`, not built here (`library-stack`). Anything that looks like a missing
subsystem in this repo is most likely a seam file pointing at the library — see
[module-map.md](module-map.md).
