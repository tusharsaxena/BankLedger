# Architecture — Ka0s Bank Ledger

Engineer context for the addon. Player-facing docs live in the root `README.md`; the full standards
brief is `docs/agent-context.md`.

## Overview

Bank Ledger records **movements**, not inventory. It never stores "what is in your bank"; it stores
"what crossed the line between your bags and a bank, when, and which way".

WoW fires no "you deposited this" event, so a movement has to be derived. The addon keeps a snapshot
of the bags plus the contents of every store the open frame can reach. Each time the client reports
a change it takes a fresh snapshot and diffs the two, **per store**:

1. An item whose count **fell in the bags** and **rose in the store** is a **deposit**.
2. The reverse is a **withdrawal**.
3. A change on only one side (loot landing in the bags, a stack destroyed) is deliberately **not** a
   movement, so ordinary play never pollutes the ledger.
4. Gold is diffed the same way, but only at the two stores that hold gold — the guild bank and the
   warband bank. A character-bank money change came from somewhere else entirely.

Capture is completely inert outside an open storage frame. That single gate is what keeps a vendor
sale or a quest turn-in out of the ledger.

### Frames, not stores

The unit the addon tracks is the open **frame**, not the open store, and the distinction is
load-bearing. The retail bank window hosts the character bank **and** the warband
tabs behind a single `BANKFRAME_OPENED`, and switching between those tabs fires no event at all — so
an addon simply cannot know which tab you are looking at.

It does not need to. `L.CONTEXT_STORES` maps each frame to every store it can reach, a snapshot
measures all of them together, and each pass diffs the bags against each one in turn. The
"both sides must change" rule then decides which store you actually used: the ones you didn't touch
show no change on their side and produce no row. Tab switching becomes a non-event, because every
tab was already measured.

An earlier model picked one store from the open *event* and diffed only that. It could never see a
warband movement, because no event announces one.

## Module map

| File | Role |
|---|---|
| `core/Compat.lua` | The only caller of deprecated or patch-varying APIs. Container/guild-bank/void-storage readers, item lookups, money, guild name, TOC metadata. |
| `core/Constants.lua` | The `Store` / `Direction` / `Kind` enums, their labels and display order, the container-id groups per store, settings option lists, media paths. |
| `core/Namespace.lua` | Bootstrap: `NS.name`, `NS.version`, the cyan `NS.PREFIX` chat tag. |
| `core/State.lua` | Runtime-only state: the open frame, the last snapshot, the session debug flag, the preview dataset. Never persisted. |
| `core/Util.lua` | Player key, path splitting, date/money/byte formatting, entry valuation, and the shared secret-safe chat printer. |
| `core/BankLedger.lua` | AceAddon registration, the message bus, `NS.NewBusTarget`, `OnInitialize` / `OnEnable`. |
| `core/Database.lua` | AceDB init, the migration runner, ledger CRUD, `QueryList`, `Export`, `Stats`, retention prune, storage estimate. |
| `defaults/Global.lua` | The account-wide defaults table — the only place a default value is hardcoded. |
| `locales/enUS.lua` | The `NS.L` metatable-fallback locale seam. |
| `locales/PostLoad.lua` | Derived-key aliases (empty in v0.1.0). |
| `modules/Filters.lua` | The item blacklist / whitelist id-sets and their copy-on-write mutations. |
| `modules/Ledger.lua` | The capture engine: snapshot, diff, gate, build, record, plus the event shell. |
| `modules/Browser.lua` | The standalone window: skin, tabs, the shared filter bar, footer, minimap launcher. |
| `modules/LedgerTable.lua` | The virtualized pooled-row History table, its grouping/sorting, and the preview dataset. |
| `modules/Insights.lua` | The Insights tab: summary cards and ranked bars over `Database:Stats`. |
| `modules/Export.lua` | Ledger CSV, Insights CSV, and the export modal. |
| `modules/DebugLog.lua` | The on-screen debug console and the `NS.Debug` sink. |
| `settings/Schema.lua` | The schema table (the single source for panel, slash and defaults) and `NS.COMMANDS`. |
| `settings/Slash.lua` | AceConsole registration, dispatch, and the `list`/`get`/`set`/`reset` CLI. |
| `settings/Panel.lua` | The Blizzard Settings landing page plus the General and Filters subcategories. |

## Data model

One ledger entry per movement, appended to `db.global.ledger` (oldest first):

| Field | Notes |
|---|---|
| `ts` | Epoch seconds. |
| `char`, `classFile` | `Name-Realm` and the class token, for the per-character views. |
| `kind` | `ITEM` or `MONEY`. `CURRENCY` is reserved for a later iteration. |
| `direction` | `DEPOSIT` (bags → store) or `WITHDRAW` (store → bags). |
| `store` | `BANK`, `WARBAND_BANK`, `GUILD_BANK`. (`REAGENT_BANK` remains in the enum for older builds.) |
| `guild` | Set on guild-bank rows only. |
| `itemID`, `itemLink`, `itemName`, `quality`, `itemType`, `itemSubType`, `vendorPrice` | Item rows. An item the client has not cached yet stores its id alone. |
| `quantity` | Stack size for an item row; copper for a `MONEY` row. |
| `zone`, `subzone`, `mapID` | Where the movement happened. |

Every stored enum **value** equals its key and is part of the CSV export contract — extend the
enums freely, never rename a member.

## Settings schema

`settings/Schema.lua` is the single source: it drives the panel widgets, the slash `get`/`set`/
`list`/`reset` dispatch, and the defaults reset. Every write goes through `NS.Schema:Set`.

| Path | Type | Default | Group |
|---|---|---|---|
| `settings.enabled` | boolean | `true` | Capture |
| `minimap.hide` | boolean | `false` | Capture |
| `settings.trackItems` | boolean | `true` | Capture |
| `settings.trackMoney` | boolean | `true` | Capture |
| `settings.qualityThreshold` | number | `0` | Capture |
| `settings.retentionDays` | number | `90` | Capture |
| `settings.excludedStores` | table (muted set) | `{}` | Capture |
| `settings.windowScale` | number | `1.0` | Window |
| `state.debugConsole` | boolean (session-only) | `false` | Window |

**Storage carve-outs** — mutated by their owning module rather than through `Schema:Set`, because
neither has a schema widget to drive: `settings.window` (geometry, `modules/Browser.lua`) and
`db.global.blacklist` / `db.global.whitelist` (`modules/Filters.lua`).

**Not settings:** the debug *logging* flag is `NS.State.debug` — session-only, off at login, never
written to SavedVariables.

## Message bus

Three messages, one sender each. Consumers **must** register on their own `NS.NewBusTarget()`
target, never on the shared bus-as-self: CallbackHandler keys callbacks by `(message, target)`, so
two consumers sharing a target silently clobber each other.

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_BankLedger_EntryAdded` | `Database:Add` | `entry, index` | Browser, Insights, Panel (storage stats) |
| `Ka0s_BankLedger_LedgerChanged` | `Database` (delete / purge / prune / `FireLedgerChanged`) | — | Browser, Insights, Panel (storage stats + Filters page) |
| `Ka0s_BankLedger_SettingsChanged` | `Schema` row `onChange` handlers | a short reason string | Ledger (re-caches its gate upvalues), Browser |

`NS.Filters` deliberately does **not** introduce a fourth sender: it calls
`Database:FireLedgerChanged()` so `Database` stays the sole emitter of that message.

## Slash surface

`/bl`, aliased `/bankledger`. The table is generated from `NS.COMMANDS`, so `/bl help`, the
settings landing page and the README all read from one place.

| Command | What it does |
|---|---|
| `/bl show` / `hide` / `toggle` | Open, close or toggle the ledger window |
| `/bl config` | Open the settings panel |
| `/bl version` | Print the addon version |
| `/bl get` / `set` / `list` / `reset` / `resetall` | Read and write settings |
| `/bl preview` | Toggle a sample ledger for previewing the window |
| `/bl purge` | Delete all history (confirm-gated) |
| `/bl debug` | Toggle the console; `on`/`off` set logging |
| `/bl help` | The help index |

## Event subscriptions

| Event | Handler |
|---|---|
| `PLAYER_ENTERING_WORLD` | Deferred one-shot retention prune |
| `BANKFRAME_OPENED`, `GUILDBANKFRAME_OPENED` | Arm the differ with a baseline snapshot of every store that frame reaches |
| `BANKFRAME_CLOSED`, `GUILDBANKFRAME_CLOSED` | Final reconcile, then disarm |
| `BAG_UPDATE_DELAYED`, `PLAYERBANKSLOTS_CHANGED`, `PLAYERREAGENTBANKSLOTS_CHANGED`, `GUILDBANKBAGSLOTS_CHANGED`, `PLAYER_MONEY` | Schedule a debounced re-snapshot, then record what moved |

On a live 12.0.7 client `PLAYERREAGENTBANKSLOTS_CHANGED` is **retired** and rejected at
registration; the addon records that and carries on.

Change events are **debounced** into one reconcile pass per user action (`Ledger.DEBOUNCE_SECONDS`,
0.35s). A single deposit reports itself through several events that do not arrive together — the
bags update on `BAG_UPDATE_DELAYED`, the warband tabs on their own beat — so reconciling per event
split one movement across two passes and the "both sides must change" rule rejected both halves.
Debouncing lines passes up with user actions and collapses several full container scans per action
into one, but it cannot cover a gap of *seconds* — the live warband tab took over a second to catch
up after the bags. So the baseline is additionally **held whenever a pass sees a one-sided change**
(`SETTLE_TIMEOUT_SECONDS`): the pass keeps the old baseline and looks again shortly, so the half
that already happened is still visible when the other half lands. If it never balances — an item
looted into the bags while the bank happened to be open — the baseline re-anchors after the timeout,
so a stale delta cannot later pair with something unrelated. Closing a frame runs the pending pass
immediately rather than waiting out the window.

Event registration is **isolated per event** (`Ledger:RegisterEventSafely`). Modern retail raises
on an unknown event name rather than ignoring it, so a bare registration loop turns one retired
event into a silently deaf addon — every event after the throw goes unbound, with no visible error
unless the player has script errors switched on. Names this build rejected are recorded in
`Ledger.unavailableEvents` and reported by `/bl debug scan`.

## Taint notes

- The ledger window and the debug console are plain **non-secure** frames, so they touch nothing
  protected and need no combat gate. Both are registered in `UISpecialFrames` for ESC.
- The settings **category** is registered eagerly at load — that never taints. Each panel **body**
  is built lazily on its first `OnShow`.
- Opening the settings panel **refuses** under combat lockdown with a grey notice and never defers:
  `Settings.OpenToCategory` is protected, and calling it under lockdown taints the panel for the
  rest of the session.
- Every chat and debug line funnels through one secret-safe printer, whose detector probes
  `table.concat` rather than `..` — the operator propagates secretness without raising, so a
  `..`-based probe would let a combat "secret" through to the real concat and crash.

## Known limitations

- **Currency movements are not captured yet.** The `Kind.CURRENCY` enum member and the export
  contract are in place so adding it is additive, but no capture path exists in v0.1.0.
- **Guild-bank withdrawals by other players are invisible.** The addon only sees your own client's
  view, so it records what *you* moved, not the guild log.
- **The reagent bank no longer exists on 12.0.7** — reagents live in the character-bank tabs, so
  the `REAGENT_BANK` store resolves to an empty container group and is dropped from the bank
  frame. The enum member stays for the export contract and for older builds.
- **Void storage is not tracked.** It was retired in 12.0.7 — the client exposes neither its events
  nor a container for it — so the addon does not advertise a store it cannot observe.
- **A store-to-store transfer is not recorded.** Moving an item straight from the character bank to
  a warband tab changes neither bag count, and the "both sides must change" rule requires the bags
  to be one of the two sides. It would need a second rule that pairs two stores against each other.
- **A movement made while the addon is disabled is lost**, not backfilled — the baseline snapshot is
  only taken while capture is on.
- **`media/logos/bankledger.logo.tga` is not shipped yet.** The settings landing page reserves its
  300×300 slot and renders nothing until the art lands.
