# Saved view — Save / Reset / Clear for the History + Insights filter bar

**Date:** 2026-07-28
**Status:** implemented — shipped in `91c9c1c` (`NS.db.global.savedView`, `modules/Browser.lua`
`savedViewOrStock` / `ApplyView`). Kept as the design record; there is no outstanding work here.

## Problem

The ledger window's filter bar has one **Clear** button, which returns every filter to a fixed stock
state. There is no way to make a different starting state stick.

The reported symptom — "filters are saved and persisted across sessions" — is a misdiagnosis worth
recording so nobody hunts for storage that does not exist. BankLedger persists **nothing** about the
filter bar today: there is no `savedView` key, and `B:ClearFilters()` (`modules/Browser.lua:733`)
runs once at frame build (`:1014`) with exactly the stock defaults. What the user observes is that
`EnsureFrame` builds the frame **once per session** and caches it, so filters survive closing and
reopening the window. A `/reload` or a relog already discards them.

So the real gap is: no Save, no Reset, and Clear resets to stock rather than to a user-chosen
baseline.

The reference implementation is the sibling addon **LootHistory**, whose History window already has
this exact Save · Reset · Clear cluster (`modules/Browser.lua:456-520, 741-839, 1160`). Parity is
the goal: two Ka0s addons whose windows behave identically should read identically.

## Behaviour

1. **Stock defaults** — Group = None, Character = Current, every other filter = All, sort = date
   descending, search empty.
2. **Save** — captures the view currently on screen as the saved view.
3. **Clear** — returns to the saved view, or to stock when nothing is saved.
4. **Reset** — discards the saved view, returning the baseline to stock, and applies stock now.
5. **Each session** (login, `/reload`) — the window opens on the saved view, or stock when nothing
   is saved.

### Decisions

| Question | Decision |
|---|---|
| Is Character scope part of the saved view? | **No.** Excluded from capture; always resolves to Current (LootHistory parity). Opening the ledger answers "what did *I* move?" far more often than the alternative, and it is one click to widen. |
| Where does the saved view live? | **Account-wide**, `NS.db.global.savedView`. Consistent with the ledger itself being cross-character by design. |
| Do the "Reset All" paths drop it? | **Yes** — `Slash:CliResetAll` and therefore the Panel Defaults button and the confirm-gated `Sl:ResetEverything`. The saved view is a user setting, exactly like the blacklist/whitelist those paths already clear. |
| Test mode? | Entering applies **stock + Character:All**; leaving applies **saved view + Current**. Test data is synthetic alts, so scoping to the real player would open on an empty table — `defaultCharSelection()` already special-cases this. |
| Close/reopen mid-session? | **Keeps working filters.** The view is applied once, at frame build. Only login and `/reload` revert. This is today's observed behaviour, preserved deliberately: losing filters every time the window is closed to check something would be a regression. |
| Feedback? | Both Save and Reset print a confirmation line. A Save leaves the bar looking identical, so the chat line is the only evidence the click landed. |

## Design

### Storage

`NS.db.global.savedView` — absent by default, so `savedViewOrStock()` falls through to stock on a
fresh install. Documented in `defaults/Global.lua` as an **architecture-§5 carve-out** alongside
`window` and `blacklist`/`whitelist`: it is mutated directly rather than through `Schema:Set`,
because a captured view has no Schema widget to drive it. No `defaults.global` entry is added — an
absent key is the "nothing saved" signal, and seeding `savedView = {}` would make an empty table
indistinguishable from a deliberate all-filters-cleared save.

No schema-version bump: adding an optional key that reads as absent on every existing profile needs
no migration.

### `modules/Browser.lua`

**`STOCK_VIEW`** — a module-local table, the single definition of "stock":

```lua
groupBy = "none", sortKey = "date", sortAsc = false,
direction = {}, store = {}, quality = {}, itemType = {}, itemSubType = {},
date = "all", search = "",
```

Field names match the `activeFilter` / `Database:QueryList` keys already in use, so no translation
layer is introduced. An empty set means "All". `date` stores the **range option**, not an absolute
timestamp, so it recomputes correctly against each load's clock. Character is absent by design.

**`savedViewOrStock()`** — returns `NS.db.global.savedView` when it is a table, else `STOCK_VIEW`.
Type-checked, so a corrupt SavedVariables value degrades to stock instead of erroring.

**`B:CaptureView()`** — reads the `_dd` dropdown selections, `LedgerTable.groupBy/sortKey/sortAsc`
and the search box into a fresh view table. Every set is **copied** via the existing `setToFilter`
idiom, never aliased to a live dropdown set, so a later toggle cannot mutate the saved view behind
its back (the same F-013 hazard `ApplyFilter` already guards). The Character dropdown is not read.

**`B:ApplyView(view, scope)`** — the inverse. Resets `activeFilter` to empty, sets the table's
group/sort, paints each dropdown and the search box, rebuilds `activeFilter` from the view (running
`date` through `NS.Util.RangeFrom` and `search` into `.text`), and **sets the Character scope last**
— `scope == "all"` clears it, anything else applies `defaultCharSelection()`. That final char write
funnels through the existing apply path, making it the single repaint that paints every field set
above it. `view` defaults to `STOCK_VIEW` when nil.

Tolerating older/foreign shapes: each set field is normalised through a small `asSet` helper that
accepts a set, a bare scalar, or the `"all"` sentinel. Cheap insurance for a table that lives in
SavedVariables, and it keeps parity with LootHistory's loader.

**The three actions:**

- `B:ClearFilters()` → `ApplyView(savedViewOrStock(), "current")`. Same name, same call sites, new
  meaning — nothing else in the file needs to change to follow it.
- `B:SaveView()` → writes `CaptureView()` to `NS.db.global.savedView`, prints the confirmation.
- `B:ResetView(silent)` → nils `savedView`, applies `STOCK_VIEW` with `"current"` scope, prints
  unless `silent`. The `silent` flag exists so `CliResetAll` can fold it into its own single
  confirmation line instead of emitting a second one.

**Call sites:**

| Site | Change |
|---|---|
| `EnsureFrame` (`:1014`) | `B:ClearFilters()` now means "apply the saved view" — no edit needed. |
| `B:OnDatasetChanged` (`:758`) | Branch on `LedgerTable:IsTestMode()`: `ApplyView(STOCK_VIEW, "all")` entering, `ClearFilters()` leaving. |
| `Slash:CliResetAll` | Add `B:ResetView(true)` beside the existing `Filters:ClearAll()`. |

### Bar layout

Today's single `exportW`-wide Clear becomes three buttons spanning exactly `exportW`, so the
cluster's right edge stays flush above Export and both stay static as the window widens:

```
Save · Reset · Clear        ← two 6px gaps
Clear, Reset:  floor((exportW - 12) / 3)
Save:          exportW - 12 - 2 * that      (absorbs the rounding remainder)
```

Anchored right-to-left from Export exactly as Clear is now. Each gets its own tooltip through the
existing `makeBarButton` helper; no new widget code. Raw English strings, consistent with the
`Clear`/`Export` labels already in the bar.

## Rider: Master Controls row pairing

Unrelated to the saved view, folded in at the user's request. The *Master Controls* section
currently renders as:

```
Enable capture        Hide minimap button
Session window
Debug console
```

because the `state.debugConsole` row carries `soloRow = true`, which forces `renderRows`
(`settings/Panel.lua:371-383`) to flush the half-filled row holding *Session window* and then take a
line of its own. The wanted shape is the natural two-column pairing:

```
Enable capture        Hide minimap button
Session window        Debug console
```

Fix: drop `soloRow = true` from the `state.debugConsole` row in `settings/Schema.lua`. No panel-code
change — row order already pairs them correctly once nothing forces a break. `soloRow` remains a
supported flag; it simply has no user left in this schema.

`docs/ARCHITECTURE.md` records the schema rows but not their pairing, so no doc edit follows.

## Standards compliance

No deviation from the Ka0s WoW Addon Standard. `savedView` is the same documented storage carve-out
as `window` and the id-lists, and is recorded as such in `defaults/Global.lua`. No new bus sender,
no new event registration, no Schema row.

## Testing

`tests/test_browser.lua` gains:

- `CaptureView` → `SaveView` → `ApplyView` round-trip restores group, sort, date, search and every
  multi-select set.
- `CaptureView` output contains **no** char field, and `ApplyView` always resolves Character to the
  current player (`ResolveCharFilter` is already injectable via `playerKey`).
- `savedViewOrStock` falls back to stock when `savedView` is absent, and when it is a non-table.
- `ClearFilters` returns to a **saved** view, not stock, once one exists.
- `ResetView` nils the stored view, and the next `ClearFilters` lands on stock.
- Captured sets are copies: mutating a dropdown after a Save does not alter the stored view.

Docs to resync: `docs/ARCHITECTURE.md` (the `savedView` carve-out and the bar's button row) and
`docs/smoke-tests.md` (a manual pass over Save → `/reload` → Clear → Reset).

Green gate before commit: `lua tests/run.lua` and `luacheck .` at 0/0.
