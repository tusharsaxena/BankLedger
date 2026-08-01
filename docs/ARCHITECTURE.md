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
4. Gold is diffed the same way, and under the **same corroboration rule**, at the two stores that
   hold gold — the guild bank and the warband bank. A character-bank money change came from
   somewhere else entirely.

The corroboration in rule 4 is the whole of it: a gold row requires the player's purse **and the
store's own coin balance** to move by the same amount in opposite directions. The purse alone proves
nothing, because `BANK_FRAME` reaches the warband bank — so buying a bank tab, repairing, or a mail
COD landing mid-visit would otherwise each be recorded as a warband deposit. A store whose balance
cannot be read on both snapshots contributes no money movement at all.

`Compat.GetStoreMoney(store)` is the reader, and it returns `nil` rather than a number whenever it
cannot answer honestly. That matters more than it looks: `GetGuildBankMoney()` returns **0**, not
`nil`, when the guild bank frame is closed, so the guild read is gated on
`Compat.IsGuildBankVisible()`. The warband balance comes from
`C_Bank.FetchDepositedMoney(Enum.BankType.Account)`, which is not frame-bound.

### Bonus IDs survive the scan

A snapshot's counts are keyed by `itemID` — that is all the diff needs, and all it sees. But an id is
not an item variant: item level, tertiaries and sockets live in a link's **bonus IDs**, and
`GetItemInfo(itemID)` can only ever answer with the base item. So the scan keeps a side table,
`snapshot.links = { [itemID] = hyperlink }` (the first link seen for an id), the diff passes it
through onto the movement as `move.link`, and `BuildEntry` prefers it over the derived link.

Two consequences worth knowing: the counts map keeps its plain `{ [itemID] = count }` shape, so the
diff and the settle check are untouched; and one id resolves to one link per snapshot, which is
exact for gear (it does not stack) and irrelevant for stackables (they carry no bonuses).

This is what lets the ledger CSV's `wowhead` column point at the variant that actually moved rather
than at the base item.

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
| `core/Compat.lua` | The only caller of deprecated or patch-varying APIs. Container and guild-bank readers, item lookups, the player's purse **and each store's own coin balance** (`GetStoreMoney`), guild name, TOC metadata. |
| `core/Constants.lua` | The `Store` / `Context` / `Direction` / `Kind` enums, their labels and display order, the container-id groups per store, settings option lists, media paths. |
| `core/Namespace.lua` | Bootstrap: `NS.name`, `NS.version`, `NS.SCHEMA_VERSION` (the one source for the shipped default and the migration target), the cyan `NS.PREFIX` chat tag. |
| `core/CoreSetup.lua` | The **LibKa0s-Core-1.0 seam**: builds the prefixed chat printer and republishes it as `NS.Print` / `NS.Util.print`, plus `NS.SafeToString` and `NS.IsConcatSafe`. Also publishes **`NS.LIBKA0S_MISSING`**, the one cause clause every other LibKa0s seam appends its own consequence to — a cross-file contract, not an implementation detail of this file, and set on both the present and absent paths because the later seams read it either way. Degrades to equivalent built-in fallbacks, announcing the absence once. |
| `core/DebugLogSetup.lua` | The **LibKa0s-DebugLog-1.0 seam**: the on-screen console and the `NS.Debug` sink, published under the names `modules/DebugLog.lua` used before it was deleted. Supplies the descriptor's `applySkin` and `makeCloseButton` so the console keeps **this addon's** chrome rather than Core's — both resolved through `NS.Browser` at call time, which is what lets a `core/` file reach a `modules/` member without inverting the load order. Degrades to a stub answering every member `/bl debug` reaches. |
| `core/State.lua` | Runtime-only state: the open frame, the last snapshot, the session debug flag, the test dataset. Never persisted. |
| `core/Util.lua` | Player key, path splitting, date/money/byte formatting, the wowhead URL builder. The secret-safe chat printer moved to `core/CoreSetup.lua` when LibKa0s was adopted; every name it published is unchanged. |
| `core/BankLedger.lua` | AceAddon registration, the message bus, `NS.NewBusTarget`, `OnInitialize` / `OnEnable`. |
| `core/Database.lua` | AceDB init, the migration runner, ledger CRUD, `QueryList`, `Export`, `Stats`, retention prune, storage estimate. |
| `defaults/Global.lua` | The account-wide defaults table — the only place a default value is hardcoded. |
| `locales/enUS.lua` | The `NS.L` metatable-fallback locale seam. |
| `locales/PostLoad.lua` | Derived-key aliases (empty in v1.0.0). |
| `modules/Filters.lua` | The item blacklist / whitelist id-sets and their copy-on-write mutations. |
| `modules/Ledger.lua` | The capture engine: snapshot, diff, gate, build, record, plus the event shell. |
| `modules/Browser.lua` | The standalone window: skin, tabs, the shared filter bar, footer, minimap launcher. |
| `modules/LedgerTable.lua` | The virtualized pooled-row History table, its grouping/sorting, the test dataset (`/bl test`), and the shared `Column` / `PaintCell` column seams. |
| `modules/SessionWindow.lua` | The live "Current Banking Session" window: its own slim pooled table over the movements of one bank visit. |
| `modules/InsightsWidgets.lua` | The Insights visual vocabulary — pooled cards, bars, back-to-back/ratio/stacked bars, strips, list panels, legends, dividers — plus the categorical palette and label maths. Knows nothing about ledger entries. |
| `modules/Insights.lua` | The Insights tab: which breakdown is drawn, out of which `Database:Stats` key, in which colour and order. |
| `modules/Export.lua` | Ledger CSV, Insights CSV, and the export modal. |
| `settings/Schema.lua` | The schema table (the single source for panel, slash and defaults) and `NS.COMMANDS`. `S:Set` is the **single write seam**: it validates, writes, emits the one debug trace, runs the row's `onChange`, and repaints an open settings panel (options-ui-§41) — so a slash write and a panel widget take exactly the same path. |
| `settings/Slash.lua` | The **LibKa0s-Slash-1.0 seam**, plus what stays the host's: AceConsole registration, the five confirm dialogs, `Sl:Version`, and the full reset. The dispatcher, the help renderer and the `list`/`get`/`set`/`reset`/`resetall` CLI are the library's. Supplies `groupKey` (this schema groups by `group`, not `page`), a `format` hook for the set-typed `excludedStores` row, and a `parse` override that refuses a chat edit of that row by name. Wraps `CliResetAll` so the two carve-outs with no Schema widget — the filter lists and the saved ledger view — are still reset. |
| `settings/OptionsSetup.lua` | The **LibKa0s-Options-1.0 seam**. `NS.Helpers` IS the library instance (options-ui-§1), not a wrapper — `settings/Panel.lua` decorates it in place. Supplies the schema seams through `NS.Schema:Set`, so a panel widget takes exactly the path `/bl set` takes. Degrades LOAD-COMPLETING rather than member-answering, with a measured load-time member set of zero. |
| `settings/Panel.lua` | What did **not** generalise: the inverted store grid, the Storage section, the whole Filters page, the landing-page body, `P:Diagnose` and the `P:Batch` refresh coalescer. Registers three pages with the library and lets it own the shell, the makers, the flow engine and the render timing. |

## Data model

One ledger entry per movement, appended to `db.global.ledger` (oldest first):

| Field | Notes |
|---|---|
| `ts` | Epoch seconds. |
| `char`, `classFile` | `Name-Realm` and the class token, for the per-character views. |
| `kind` | `ITEM` or `MONEY`. Those two are the whole enum; currencies are not recorded. |
| `direction` | `DEPOSIT` (bags → store) or `WITHDRAW` (store → bags). |
| `store` | `BANK`, `WARBAND_BANK`, `GUILD_BANK`. |
| `guild` | Set on guild-bank rows only. |
| `itemID`, `itemLink`, `itemName`, `quality`, `itemType`, `itemSubType` | Item rows. An item the client has not cached yet stores its id alone. `itemLink` is the link the **scan** saw, so it carries the item's bonus IDs (see [Bonus IDs survive the scan](#bonus-ids-survive-the-scan)). |
| `quantity` | Stack size for an item row; copper for a `MONEY` row. |
| `zone`, `subzone`, `mapID` | Where the movement happened. |

Every stored enum **value** equals its key and is part of the CSV export contract — extend the
enums freely, never rename a member.

### Retired stores

`REAGENT_BANK` and `VOID_STORAGE` were removed from `C.Store` outright rather than kept as dead
members, and the removal deliberately sits outside the rule above.

The rule protects rows that already exist: renaming a member orphans stored data that still carries
the old string. Neither of these could ever have produced one. The addon is Retail-only at Interface
120007, where Midnight has already removed both — void storage exposes no container or events at
all, and `REAGENT_BANK`'s container group resolved empty, so `StoresFor` dropped it from every scan
before a movement could be attributed to it. There is no installed base either: both were removed
before v1.0.0, the first published release, so no shipped build ever wrote a row against them. Zero
reachable rows, so nothing to orphan.

`StoresFor`'s empty-group guard stays regardless — it is what makes a retired container degrade to
"not on this build" instead of a permanently empty store in every debug line, and Blizzard will
retire another one. `tests/test_ledger.lua` drives it directly by emptying a live store's group.

If a store is ever retired *after* rows exist, the answer is the opposite one: keep the member,
drop it from `CONTEXT_STORES`, and let the history keep rendering.

### Schema v2 — the value dimension is gone

`db.global.schemaVersion` is now **2**. Vendor price was a poor proxy for worth, so the addon stopped
deriving, capturing and persisting it entirely: `Util.EntryValue`/`Util.SignedValue` are deleted,
`Compat.GetItemDetails` returns 5 values (`name, quality, itemType, itemSubType, link`, no vendor
price), and a ledger entry never carries `vendorPrice`. Gold is unaffected — a `MONEY` row's amount
lives in `quantity` and was never vendor-priced.

`NS:RunMigrations` is no longer a bare seam: the v1 → v2 step walks `db.global.ledger` once, sets
`e.vendorPrice = nil` on every entry, bumps `schemaVersion` to 2, and emits the standard `[Migrate]`
debug line via `NS.MigrationSummary`. It is idempotent — a v2 database is skipped entirely, and
clearing an already-absent field on a partially-migrated one is a no-op.

### Accepted deviation — the CSV export contract broke

`core/Database.lua` and `modules/Export.lua` document the CSV column set as stable, and the schema-v2
bump breaks it — recorded here as an **accepted, deliberate deviation**, versioned by the schema
bump rather than left open-ended:

- The **ledger CSV** loses the `vendorPrice`, `value`, `valueRaw` and `net` columns.
- The **Insights CSV** loses the `Summary / Value moved` row and the whole `Top Items By Value`
  section; `Net by Store` now writes its movement count into the **Count** column instead of a
  value.

Keeping the columns and emitting blanks was considered and rejected: a `value` column with no value
behind it is a promise the data no longer keeps, and it would outlive everyone's memory of why the
column went empty. The break is one-time and tied to `schemaVersion`, not an open-ended contract
violation.

The later `wowhead` column is **not** part of that break: it is appended after `zone`, so every
existing column keeps its index and a sheet keyed on position is unaffected. Growth at the end is
what the stable-column-set promise allows.

## Settings schema

`settings/Schema.lua` is the single source: it drives the panel widgets, the slash `get`/`set`/
`list`/`reset` dispatch, and the defaults reset. Every write goes through `NS.Schema:Set`.

Rows render in schema order, so this table is also the panel's layout, top to bottom.

| Path | Type | Default | Group |
|---|---|---|---|
| `settings.enabled` | boolean | `true` | Master Controls |
| `minimap.hide` | boolean | `false` | Master Controls |
| `settings.showSessionWindow` | boolean | `true` | Master Controls |
| `state.debugConsole` | boolean (session-only) | `false` | Master Controls |
| `settings.windowScale` | number | `1.0` | Master Controls |
| `settings.qualityThreshold` | number | `0` | Capture |
| `settings.retentionDays` | number | `30` | Capture |
| `settings.trackItems` | boolean | `true` | Capture |
| `settings.trackMoney` | boolean | `true` | Capture |
| `settings.excludedStores` | table (muted set) | `{}` | Capture |

**Storage carve-outs** — mutated by their owning module rather than through `Schema:Set`, because
none has a schema widget to drive: `settings.window` (main-window geometry, `modules/Browser.lua`),
`settings.sessionWindow` (session-window geometry, `modules/SessionWindow.lua`),
`db.global.blacklist` / `db.global.whitelist` (`modules/Filters.lua`) and `db.global.savedView`
(the filter bar's saved baseline, `modules/Browser.lua`).

**The saved view** — `db.global.savedView` holds the grouping, sort, date range, search text and the
five multi-select column filters, captured by the filter bar's **Save** button. It is *absent* until
the user saves: no key is what "nothing saved" means, so an empty table stays available to mean a
deliberately all-cleared save. **Clear** returns to it (or to `STOCK_VIEW` when absent); **Reset**
discards it, as does `Slash:CliResetAll` and therefore the Panel's Defaults button. The character
scope is deliberately *not* part of a view — it is a per-session default of Current that widens on
demand, so a stale save can never pin the window to one alt. Applied once, at frame build, so
closing and reopening the window mid-session keeps whatever you were working with.

**Not settings:** the debug *logging* flag is `NS.State.debug` — session-only, off at login, never
written to SavedVariables. The current banking session's movements are `NS.State.sessionEntries` —
references to already-stored entries, held only while a bank frame is open and never persisted.

## Message bus

Four messages, one sender each. Consumers **must** register on their own `NS.NewBusTarget()`
target, never on the shared bus-as-self: CallbackHandler keys callbacks by `(message, target)`, so
two consumers sharing a target silently clobber each other.

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_BankLedger_EntryAdded` | `Database:Add` | `entry, index` | Browser, Insights, SessionWindow, Panel (storage stats) |
| `Ka0s_BankLedger_LedgerChanged` | `Database` (delete / purge / prune / `FireLedgerChanged`) | — | Browser, Insights, SessionWindow (prunes deleted rows), Panel (storage stats + Filters page) |
| `Ka0s_BankLedger_SettingsChanged` | `Schema` row `onChange` handlers | a short reason string (`enabled`, `sessionWindow`, `windowScale`, `quality`, `trackItems`, `trackMoney`, `stores`) | Ledger (re-caches its gate upvalues), Browser, SessionWindow |
| `Ka0s_BankLedger_SessionChanged` | `Ledger` (`OpenContext` / `CloseContext` / the guild-bank self-disarm) | `active` (boolean), `context` | SessionWindow |

`SessionChanged` exists so the session window rides the span the capture engine already arms
`openContext` for, instead of re-deriving it from the open/close events — which would have missed the
guild bank entirely, since that is armed by the arrival of tab data rather than by an event, and gets
no close event at all.

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
| `/bl test` | Toggle a sample ledger for previewing the window |
| `/bl session` | Toggle the banking-session window (on sample data when no bank is open) |
| `/bl purge` | Delete all history (confirm-gated) |
| `/bl debug` | Toggle the console; `on`/`off` set logging |
| `/bl debug scan` | Dump the client's live container model **and its money-balance readers** into the console |
| `/bl debug panel` | Dump what the settings header's Defaults button actually is at runtime |
| `/bl help` | The help index |

`/bl test` is the renamed History-table sample data (`LT:IsTestMode`, `LT:ToggleTestMode`,
`LT:BuildTestData`, badge `TEST MODE`) — matching the Ka0s house vocabulary set by LootHistory's
`/lh test`. `/bl session`'s `previewSession` / `TogglePreview` on `NS.SessionWindow` **deliberately
keep the "preview" name**: it is a separate synthetic-data feature (placeholder movements for
positioning the Current Banking Session window away from a bank) with no LootHistory counterpart to
match, so it was left alone rather than folded into the rename.

## Event subscriptions

| Event | Handler |
|---|---|
| `PLAYER_ENTERING_WORLD` | Deferred one-shot retention prune |
| `BANKFRAME_OPENED`, `GUILDBANKFRAME_OPENED` | Arm the differ with a baseline snapshot of every store that frame reaches (the guild one never fires — see below) |
| `BANKFRAME_CLOSED`, `GUILDBANKFRAME_CLOSED` | Final reconcile, then disarm (the guild one never fires — see below) |
| `BAG_UPDATE_DELAYED`, `PLAYERBANKSLOTS_CHANGED`, `PLAYER_MONEY` | Schedule a debounced re-snapshot, then record what moved |
| `GUILDBANKBAGSLOTS_CHANGED` | Both at once: **arms** the guild-bank context if nothing else holds it, then schedules the same debounced pass. It is the guild bank's stand-in for an open event — see below |
| `PLAYER_LOGOUT` | Flush each window's geometry to SavedVariables (`modules/Browser.lua`, `modules/SessionWindow.lua`) |

The addon asks for no event Midnight has retired. That is not a standing guarantee — Blizzard
retires names between expansions, and modern retail **raises** on an unknown one rather than
ignoring it, so registration is isolated per event (below) and a name that goes away is recorded and
survived rather than fatal.

Change events are **debounced** into one reconcile pass per user action (`Ledger.DEBOUNCE_SECONDS`,
0.35s). A single deposit reports itself through several events that do not arrive together — the
bags update on `BAG_UPDATE_DELAYED`, the warband tabs on their own beat — so reconciling per event
split one movement across two passes and the "both sides must change" rule rejected both halves.
Debouncing lines passes up with user actions and collapses several full container scans per action
into one, but it cannot cover a gap of *seconds* — the live warband tab took over a second to catch
up after the bags. So the baseline is additionally **held whenever a pass sees a one-sided change**
(`SETTLE_TIMEOUT_SECONDS`): the pass keeps the old baseline so the half that already happened is
still visible when the other half lands. The wait is **event-driven, not polled** — a warband tab is
a container, so the client updating it fires `BAG_UPDATE_DELAYED` and drives the re-check by itself;
the timer is only a give-up deadline, re-armed on the remaining window so event traffic cannot push
it out. If it never balances — an item
looted into the bags while the bank happened to be open — the baseline re-anchors after the timeout,
so a stale delta cannot later pair with something unrelated. Closing a frame runs the pending pass
immediately rather than waiting out the window.

Event registration is **isolated per event** (`Ledger:RegisterEventSafely`). Modern retail raises
on an unknown event name rather than ignoring it, so a bare registration loop turns one retired
event into a silently deaf addon — every event after the throw goes unbound, with no visible error
unless the player has script errors switched on. Names this build rejected are recorded in
`Ledger.unavailableEvents` and reported by `/bl debug scan`.

The guild bank is the one store with **no usable open event, and no usable close event either**.
`GUILDBANKFRAME_OPENED` is a valid name that registers without complaint and never fires on 12.0.7,
so it is the arrival of tab **data** (`GUILDBANKBAGSLOTS_CHANGED`) that arms the context — the first
one lands as the window opens, before anything can be moved, which is exactly when the baseline wants
taking. It never steals the context from an already-open bank frame.

`GUILDBANKFRAME_CLOSED` is the same story, so closing it is caught two ways:

- **`GuildBankFrame`'s own `OnHide`** (`Ledger:HookGuildBankFrame`) is the close path. It is the one
  notice the client gives, and it has to be a hook rather than a check inside `Reconcile`, because
  closing the window changes no container and moves no money — so no event fires and no reconcile
  pass runs. The hook only ends the guild bank's *own* context (the frame also hides whenever it is
  simply not the panel on screen). `GuildBankFrame` lives in `Blizzard_GuildBankUI`, loaded on
  demand, so the hook is installed the first time the guild bank is in play, and once only.
- **`Compat.IsGuildBankVisible() == false`, checked in `Reconcile`**, is the backstop for a frame
  that went away without hiding, and stops the addon rescanning six 98-slot tabs on every bag update.
  That check is three-valued: `nil` means "this build cannot tell" and deliberately does not disarm.

`/bl debug scan` reports whether the close hook is installed — a `NOT INSTALLED` there is the
explanation for a guild session that will not end.

The guild bank also has a prerequisite the container stores do not: a tab holds **no data until it
has been queried** (`QueryGuildBankTab`), so only the tab the player is looking at is readable for
free. Arming queries every tab; the replies arrive asynchronously and reconcile like any other
change.

## Windows

Two standalone windows, both plain non-secure frames sharing one `SKIN` / `ApplySkin` seam and one
close-glyph factory (`modules/Browser.lua`), each with its own persisted geometry carve-out.

**When geometry is written matters as much as what is written**, and the obvious answer is wrong. The
natural call sites — the end of a drag, the end of a resize — fire at the end of an *interaction*,
and the resize one is easy to miss outright: releasing the grip a pixel outside a 16×16 button never
delivers its `OnMouseUp`. Miss it and the geometry lives only in the frame, which survives every
`Hide`/`Show` — so it looks perfectly persistent for a whole game session and is gone on the first
`/reload`. Worse, the in-memory frame masks the fault: the window keeps its place all session
*without SavedVariables ever being read back*, so the save path is never exercised and never seen to
be broken.

Both windows therefore anchor the save to moments that are **guaranteed**, through the same two
method names:

| Seam | Runs |
|---|---|
| `SaveGeometry()` | Every `OnHide`; `PLAYER_LOGOUT`; plus drag-stop and resize-stop, which keep the stored value current mid-session |
| `ApplyGeometry()` | Once, when the frame is built on first show |

`SaveGeometry()` refuses to write a point-less table — one would make `ApplyGeometry()` fall through
to the default and silently discard a real position — and `ApplyGeometry()` clamps a restored size to
the window's floor on the way *in* as well as out, so a size saved against an older column set (or a
hand-edited SavedVariables) cannot reopen a window too small to read.

| Window | Frame | Opened by | Contents |
|---|---|---|---|
| Ledger | `BankLedgerWindow` | `/bl show`, the minimap button | History table + Insights, over one shared filter bar |
| Current Banking Session | `BankLedgerSessionWindow` | a bank frame opening (`SessionChanged`), or `/bl session` | One slim table of this visit's movements |

The session window is **not** a second `NS.LedgerTable` instance. That module is a stateful singleton
— one row pool, one display list, one sort/group/filter/collapse state — and the session table has
none of those, so a slim renderer is smaller than the refactor generalising it would take. What the
two **do** share is the definition of a column: `LedgerTable:Column(key)` hands out the spec (label,
width, align, tooltip, `valueFn`) and `LedgerTable:PaintCell(fs, key, entry, glyph)` sets a cell's
text and colour, so a column cannot read one way in one window and another way in the other.

Its column set is the History table's minus `date`, `time` and `char`: every row happened moments
ago, and capture only ever records the logged-in character's own movements, so all three columns
would carry the same value on every row.

## Insights

One `Database:Stats(filter)` pass per refresh, against the Browser's shared filter, feeds the whole
panel — so the charts and the History table always describe the same slice. The panel is split in two:

* `modules/InsightsWidgets.lua` — **how** things are drawn. Pooled primitives (KPI card, horizontal
  bar, back-to-back bar, ratio bar, stacked bar, vertical strip, ranked list panel, legend, section
  divider) plus the categorical palette, label truncation, colour helpers and the geometry maths.
  It never touches a ledger entry, which is what makes that maths unit-testable headlessly.
* `modules/Insights.lua` — **what** is drawn: fourteen stat cards and seventeen chart sections, each
  mapping one `Stats` key to rows, plus the reorganized "Top Of The List" ranked-panel grid below them.

### `Database:Stats` keys

One `Stats(filter)` pass computes every breakdown the panel and the Insights CSV read. Schema v2
removed the value dimension from it entirely:

- **Removed:** `totalValue`, `valueByStore`, `valueByDay`, `topItemsByValue`, `biggestMove`, and the
  `.value` field that used to sit on every `byItem` / `byChar` record.
- **Changed:** `netByStore` is now a **signed movement count** (`+1` per deposit, `-1` per
  withdrawal), not a value — the only surviving signed non-gold quantity.
- **Added:** `storeByDirection`, `qualityByDirection`, `itemTypeByDirection`, `itemSubTypeByDirection`
  (the four `× Deposits/Withdrawals` companion accumulators), `itemsByStore`
  (`[store][itemID] = { moves, movesIn, movesOut }`, behind the per-store triptychs),
  `topItemsIn`/`topItemsOut`, `topItemsByQuantityIn`/`topItemsByQuantityOut`, `topZonesIn`/
  `topZonesOut`, `topTypeSub`/`topTypeSubIn`/`topTypeSubOut`, `topItemsByStore`, `totals.itemsMoved`
  (`itemsDeposited + itemsWithdrawn`) and `totals.topStore` (the busiest store, ties broken on the
  store key). `byItem` records gain `movesIn`/`movesOut`/`qtyIn`/`qtyOut`, and `topZones` records
  gain `inCount`/`outCount`. (`zoneByDirection` and `byTypeSub` are function-local working tables used
  to build `topZones*`/`topTypeSub*` — they are never in the returned `Stats` table themselves.)
- **Unchanged:** `stats.byZone` deliberately keeps its plain `{ [zone] = count }` map shape —
  `modules/Export.lua` feeds it straight to `rankedRows` for the stats CSV, and reshaping it would
  break that export for no gain.

Every new breakdown is a plain extra accumulator in the same single O(n) pass, so the panel got
richer without the aggregation getting slower, and every comparator still ends on `itemID`/the
label/the store key so a tie can never reorder run to run.

### Section order

In render order: Deposits vs Withdrawals (caption labels **below** the bar, not inside it), Movements
By Store + its companion, Movements By Character, Movements By
Character × Store, Movements By Character × Deposits/Withdrawals, Movements By Quality + its companion, Movements
By Item Type + its companion, Movements By Sub-type + its companion, Movements Over Time (per day),
Movements By Hour Of Day, Movements By Weekday, then — only when the slice holds a coin movement —
the GOLD block (Gold Moved Over Time, Gold By Store).

Every companion **mirrors its parent's full title** — `Movements By Item Type × Deposits/Withdrawals`, not
`Item Type × Deposits/Withdrawals` — so a companion scrolled past in isolation still says what it is a companion
to.

Each `× Deposits/Withdrawals` companion sits **immediately after its parent chart** and is drawn **back to back**
(`W.BuildBackToBackRows` → `I:RenderBackToBack` → `W.PlaceBackToBackBar`): withdrawals grow LEFT of a
fixed centre axis, deposits grow RIGHT. Both sides share **one** scale — the largest single-direction
magnitude in the list — so the split sits on the same vertical line in every row and the lean of the
whole chart reads straight down that line. A left-aligned stacked bar puts that boundary somewhere
different on every row and answers the question only after arithmetic, which is why the form changed.
Each row keeps its parent chart's label colour (store colour, quality colour, class colour, palette
colour by rank) so a category stays recognisable across the pair, and each half carries its own
hover tip with the exact count. The legend is ordered **withdraw, deposit** to match the chart's
left-to-right reading rather than `C.DirectionOrder`.

`Movements By Character × Store` is the one `×` chart that is *not* back to back — it splits by store,
not by direction, so it keeps the ordinary left-aligned `I:RenderStacked` path.

Last comes "TOP OF THE LIST", reorganized into a three-column grid grouped under **ITEMS**
(Top Items By Movements, Top Items By Quantity), **CATEGORIES** (Top Type · Sub-type), **WHERE**
(Top Banking Spots) and **BY STORE** (one panel per store with movements). Each metric renders as one
row of three panels — All / Deposits / Withdrawals — so the triptych *is* the visual organization; a
panel with no rows simply hides, so a slice with no withdrawals has no Withdrawals column, and each
row advances by the height of its tallest panel. *Top Items By Value* is gone with the rest of the
value dimension.

**Panel pooling.** List panels are pooled and carry a **per-pass title** (`W.MakeListPanel` gained a
settable title, set per pass through `W.SetPanelTitle`; the pool itself is the generic `W.NewPool`,
drained by `W.ReleasePanels` rather than the plain `W.ReleaseAll`, because a panel has to release its
own row pool too) because the store panels are variable in count — at most three, only those with
movements — instead of the fixed four the old two-column layout had baked in at `Attach`. A pooled panel carries **its own row pool**
on itself (`panel._rows`), because rows are parented to a specific panel at creation and cannot be
shared across panels.

Three choices worth stating, because they are the ones a future change is most likely to undo:

* **The direction companions are back to back, not stacked.** Withdrawals grow left of a fixed
  centre axis and deposits grow right, both sides on one shared scale. A left-aligned stacked bar
  puts the in/out boundary in a different place on every row, so "which way does this lean" takes
  arithmetic; pinning the split to one vertical line makes it readable straight down the column.
* **Colour is never decorative.** Store, direction, quality and class bars take their colour from the
  shared palettes in `core/Constants.lua`, so a bar matches the table column it summarises. Only the
  breakdowns with no palette of their own (item type, sub-type, weekday) fall back to
  `InsightsWidgets.PaletteColor`, assigned by *rank* so adjacent bars are never lookalikes.
* **Empty is drawn, missing is not.** A quiet day keeps a ghost bar in a strip (a gap cannot be told
  apart from a day outside the range) and the cards paint "0" rather than vanishing; but the whole
  GOLD block hides when the slice holds no coin movement, because two blank charts under a banner
  read as a broken addon.

Every widget is pooled and repainted in place. The Blizzard UI runs a super-linear pass over a frame
tree on some transitions, so re-allocating widgets per refresh is what turns a smooth panel into a
visible hitch.

## Taint notes

- The ledger window, the session window and the debug console are plain **non-secure** frames, so they
  touch nothing protected and need no combat gate. All three are registered in `UISpecialFrames` for
  ESC. That the session window opens off a game event is safe for the same reason: it shows a frame
  nobody protected, and it never calls a protected API.
- The settings **category** is registered eagerly at load — that never taints. Each panel **body**
  is built lazily on its first `OnShow`, as is the header's Defaults button.
- Every registered canvas frame carries `OnCommit`, `OnDefault` and `OnRefresh`, so Blizzard's
  Settings window never calls into a missing method — **stamped by `LibKa0s-Options-1.0`'s
  `CreatePanel`** (Options minor 5), not by this addon, which is what options-ui-§1 now requires.
  `OnCommit` and `OnRefresh` are inert by design — writes land immediately through `NS.Schema:Set`
  (nothing is staged), and the library's renderer already owns re-show. `OnDefault` **forwards** to
  whatever the page parked as `defaultsOnClick` (`setDefaultsAction`), so the framework's footer
  control and the addon's own header button are one implementation by construction rather than two
  that have to be kept in step. On General that action is `P:RestoreDefaults()`, which is
  non-destructive — settings and window geometry only; wiping the ledger stays behind the
  confirm-gated `KA0S_BANKLEDGER_RESETALL` popup, which Blizzard's un-gated control never reaches.
- Opening the settings panel **refuses** under combat lockdown with a grey notice and never defers:
  `Settings.OpenToCategory` is protected, and calling it under lockdown taints the panel for the
  rest of the session.
- Every chat and debug line funnels through one secret-safe printer, whose detector probes
  `table.concat` rather than `..` — the operator propagates secretness without raising, so a
  `..`-based probe would let a combat "secret" through to the real concat and crash.

## Documented deviations

Accepted, deliberate departures from the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards).

- **All defaults live in `defaults/Global.lua`; there is no `defaults/Profile.lua`.**
  `savedvariables-§2` names `defaults/Profile.lua` as the required home for defaults, and
  `layout-§1` lists it in the tree. Bank Ledger is **account-wide by design** — you deposit on one
  character and withdraw on another, so a per-character profile would split the very history the
  addon exists to join up. `NS.defaults` therefore carries a `global` table only, and every schema
  path resolves against `NS.db.global`. AceDB still creates the profile namespace (the addon calls
  `AceDB:New("BankLedgerDB", NS.defaults, true)`); it is simply unused.
  **Why not an empty `Profile.lua`:** a defaults file nothing reads would satisfy the filename while
  weakening `savedvariables-§2`'s real invariant — that there is exactly *one* place a default value
  is hardcoded — by standing up a second candidate home for it.

- **`docs/agent-context.md` is specialized to this addon, not a verbatim copy of the upstream pack.**
  `documentation-§3`/`§5` treat the file as the standard's context pack dropped in unchanged, so it
  can be re-dropped wholesale whenever the standard moves. Bank Ledger's copy has instead been filled
  in with the addon's real TOC, file tree, `Compat` surface, schema rows, `NS.COMMANDS` verbs, bus
  messages and test seams, and its new-addon scaffolding steps rewritten as the shipped state.
  **Rationale:** the brief loads into every agent session, and a generic pack made an agent read
  `<Addon>DB`, `Locale.lua`, `Settings.lua` and `_G.MYADDON_TEST` — none of which exist here — before
  finding the real names in `ARCHITECTURE.md`. Concrete beats canonical for a file whose whole job is
  orienting someone fast.
  **The cost, accepted knowingly:** the file can no longer be re-dropped. When the standard ships a
  new pack, its changes must be **diffed and ported by hand**, leaving the Bank Ledger specifics in
  place — recorded in the release checklist in `docs/testing.md` and in the file's own header
  comment. The rules content still tracks the standard; only the examples are local.

## Mono font outside the debug console

`media/fonts/JetBrainsMono-Regular.ttf` ships as a sanctioned styling exception. Its primary scope is
the debug console and its copy boxes, but the History table's Direction column and the Direction
filter dropdown also draw a ▲/▼ (U+25B2 / U+25BC) in it, because WoW's default font carries neither
glyph and renders a box for both.

This is **not a deviation**: `debug-logging-§2` sanctions the vendored mono font for an individual
glyph the default font lacks, naming ▲/▼ direction markers in a table cell as the example, and states
that an audit must not flag it.

The reason the standard settled there is the reason this addon needs it: the alternative is a
texture, and Blizzard's arrow art carries uneven padding — the up arrow sits low in its canvas, the
down arrow high — so a texture pair visibly misaligns against the row text. A text glyph sits on the
label's own baseline, so it is centred by construction and takes the direction's colour from the same
`SetTextColor` call as the label. The font is already shipped, so this costs no new asset. Scope is
two glyphs; no body text anywhere uses the mono font outside the console.

## Logo art

`media/logos/` holds one master and three derivatives. Only the `.tga` is loaded by the addon; WoW
cannot read `.png` or `.jpg` at runtime.

| File | Size | Role |
|---|---|---|
| `bankledger.logo.png` | 1254×1254 | The master. Never shipped to the client; every other file is derived from it. |
| `bankledger.logo.tga` | 512×512, 24-bit RLE | **The runtime asset** — `C.LOGO_PATH`, drawn on the settings landing page at 300px. |
| `bankledger.logo.jpg` | 1024×1024 | The README image. |
| `bankledger.logo.256.jpg` | 256×256 | The CurseForge project avatar. |

Three rules the derivatives have to follow, each of which has already gone wrong once:

- **The `.tga` must actually exist.** `C.LOGO_PATH` points at `media/logos/bankledger.logo.tga`, and
  a missing file draws nothing rather than erroring — so the settings landing page just renders
  blank and nobody notices. That silence is why the art was absent for a while without anything
  failing. The runtime asset ships now, so this is a fallback path rather than a live problem.
- **Power-of-two dimensions.** The master is 1254×1254, which is not one; a non-power-of-two texture
  is rescaled by the client and softens. 512 is the smallest power of two comfortably above the
  300px display size, and matches the sibling addons.
- **Downscale with Lanczos, and sharpen the 256.** This is dense artwork — a ledger page of tiny
  text, coin stacks, filigree borders — so it loses more than a flat logo would at small sizes. The
  256 avatar takes a light unsharp mask (radius 0.8, 60%, threshold 2) afterwards to hold the detail
  together; without it the fine work turns to mush.

Regenerate the derivatives from the master with:

```python
from PIL import Image, ImageFilter
src = Image.open("media/logos/bankledger.logo.png").convert("RGB")
src.resize((512, 512), Image.LANCZOS).save(
    "media/logos/bankledger.logo.tga", compression="tga_rle")
src.resize((1024, 1024), Image.LANCZOS).save(
    "media/logos/bankledger.logo.jpg", quality=95, subsampling=0, optimize=True)
src.resize((256, 256), Image.LANCZOS) \
   .filter(ImageFilter.UnsharpMask(radius=0.8, percent=60, threshold=2)) \
   .save("media/logos/bankledger.logo.256.jpg", quality=95, subsampling=0, optimize=True)
```

## Known limitations

- **Currency movements are not recorded, and are not planned.** The book covers items and gold.
  Currencies were considered and deliberately left out, so `Kind` carries no member for them and the
  export contract reserves no column — adding them later would be a new feature, not a fill-in.
- **Guild-bank withdrawals by other players are invisible.** The addon only sees your own client's
  view, so it records what *you* moved, not the guild log.
- **The reagent bank and void storage are not stores.** Midnight removed both — reagents live in the
  character-bank tabs now, and the client exposes neither events nor a container for void storage —
  so the addon does not advertise stores it cannot observe. Neither has an enum member; see
  [Retired stores](#retired-stores) for why removing them was safe.
- **A store-to-store transfer is not recorded.** Moving an item straight from the character bank to
  a warband tab changes neither bag count, and the "both sides must change" rule requires the bags
  to be one of the two sides. It would need a second rule that pairs two stores against each other.
- **A movement made while the addon is disabled is lost**, not backfilled — the baseline snapshot is
  only taken while capture is on.
- **Gold rows written before the balance-corroboration fix cannot be cleaned up retroactively.**
  Nothing in a stored row distinguishes a real warband deposit from a bank-tab purchase that was
  recorded as one, so the addon cannot find them after the fact. Filter to Gold + Warband Bank in
  the History tab to review them, and delete any that were not real from the row menu.
- **An item the client has not cached is skipped when a minimum quality is set**, because it has no
  quality to judge. The id is queued for loading so the next movement of it is judged properly. At
  the default threshold of 0 nothing is skipped. There is **no name backfill** — a row stored
  without a cached name keeps only its item id and stays out of the Type, Sub-type and Quality
  breakdowns for good.
