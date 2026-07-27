# Design — Insights panel overhaul: value removal, chart fixes, In/Out views, test mode

Date: 2026-07-27 · Branch: `feature/session-window-and-insights`

Seven changes to the Insights tab, delivered together because five of them fall out of the first.
Removing the value dimension rewrites `Database:Stats`, and every other item in this spec either
edits a chart that pass feeds or adds a new one to it.

---

## 1 — Remove the value dimension

### Intent

Vendor price is a poor proxy for worth and the panel leaned on it in six places. Rather than caveat
those figures, the addon stops deriving, capturing and persisting value at all. Gold is unaffected:
a MONEY row's amount lives in `quantity` and was never vendor-priced.

### Capture and storage

| Site | Change |
|---|---|
| `modules/Ledger.lua:368` | Stop writing `entry.vendorPrice`. |
| `core/Compat.lua` `GetItemDetails` | Stop returning `vendorPrice` (5 returns, not 6). |
| `core/Database.lua` `Database:Export` | Drop `vendorPrice` from the copied field list. |
| `core/Util.lua` | Delete `Util.EntryValue` and `Util.SignedValue`. |
| `modules/LedgerTable.lua`, `modules/SessionWindow.lua` | Drop `vendorPrice` from the synthetic datasets. |

### Migration — schema v1 → v2

The seam documented in `Database:RunMigrations` gets its first real body. It walks
`db.global.ledger` once, sets `e.vendorPrice = nil` on every entry, sets `schemaVersion = 2`, and
emits the standard `[Migrate]` line via `NS.MigrationSummary`. Idempotent: a v2 database is skipped
entirely, and re-running the strip on an already-clean entry is a no-op.

Stripping rather than ignoring is deliberate. "Stop persisting value" means the bytes leave the
SavedVariables file, not that the reader averts its eyes.

### Stats

Removed from `Database:Stats`: `totalValue`, `valueByStore`, `valueByDay`, `topItemsByValue`,
`biggestMove`, `rec.value` on every `byItem` record, and `ce.value` on every `byChar` record.

`netByStore` is **re-based on movement count**: `+1` per deposit, `-1` per withdrawal. The Net Flow
By Store diverging chart keeps its meaning — which stores am I filling, which am I draining — with
no value input. It is the only surviving signed non-gold quantity.

Untouched: `moneyIn`, `moneyOut`, `netMoney`, `moneyMoved`, `moneyByDay`, `moneyByStore`. The GOLD
section of the panel is unaffected by this change.

### UI removals

- Cards: `value` ("value moved") and `biggest` ("biggest move").
- Section: `valueStore` — *Value Moved By Store* bars.
- Strip: `valueDay` — *Value Moved Over Time (Per Day)*.
- List panel: `itemValue` — *Top Items By Value*.
- `MONEY_COL_W` in `modules/Insights.lua` becomes unused and is deleted with its last consumer.

### Accepted deviation — the CSV export contract

`core/Database.lua:7` and `modules/Export.lua:21` document the CSV column set as stable, and this
change breaks it. It is recorded here as an **accepted deviation**, tied to the schema-v2 bump:

- Ledger CSV loses `vendorPrice`, `value`, `valueRaw` and `net`.
- Stats CSV loses the `Value` column's contents, the `Summary / Value moved` row, and the whole
  `Top Items By Value` section.

Keeping the columns and emitting blanks was considered and rejected: a `value` column that is always
empty is a promise the data no longer keeps, and it would outlive everyone's memory of why. The
break is one-time, versioned by `schemaVersion`, and must be noted in `docs/ARCHITECTURE.md` and the
next audit bundle.

---

## 2 — Character bar labels render as raw texture paths

### Diagnosis

`modules/Insights.lua:587` builds a character bar's label as
`ClassIconMarkup(classFile) .. ShortChar(char)`, and `I:RenderBars` then passes the whole string
through `W.Truncate`, which cuts at 17 **bytes**. `ClassIconMarkup` returns a
`|TInterface\TargetingFrame\UI-Classes-Circles:12:12:...|t` escape far longer than that, so the cut
lands inside the escape, the `|T` never closes, and WoW renders the texture path as literal text —
`ITInterface\Targ…`. The tooltip is correct because it reads `fullLabel = ce.char`, which never
passes through `Truncate`.

### Fix

Bar rows gain an optional `icon` field, kept out of the truncated string. `RenderBars` sets
`bar.label:SetText((row.icon or "") .. W.Truncate(row.label, row.labelMax))`. The character section
passes `icon = ClassIconMarkup(ce.classFile)`, `label = W.ShortChar(ce.char)` and a reduced
`labelMax` (14) so icon plus name still fit the 118px label column.

No other `Truncate` caller concatenates markup — `LedgerTable.lua:89` and `Browser.lua:584` build
iconned strings but never truncate them — so this is the only site.

---

## 3 — Deposits vs Withdrawals labels move outside the bar

The ratio bar keeps its two colour blocks and loses its in-bar text, along with the `w >= 56`
suppression rule that dropped a label when its share got narrow.

A caption line sits **below** the bar: `In 412 · 62%` left-aligned in deposit green at the bar's
left edge, `Out 253 · 38%` right-aligned in withdraw red at the right edge. Both are always legible,
including at a 97/3 split where the old in-bar text vanished. Costs 14px of section height. The
per-side hover tooltips stay.

---

## 4 — Date range and busiest day headline size

`span` and `busiest` are the only cards carrying `smallValue = true`, which drops them to
`GameFontNormal` while every other card uses `GameFontNormalHuge`. Both flags are removed, so all
cards share one base font and the existing `W.FitFontSize` shrink-to-fit handles the long strings.

The `smallValue` option on `W.MakeCard` has no remaining consumer and is deleted.

---

## 5 — Test mode

### Rename

The addon already has this feature under a different name. It is renamed to match the Ka0s house
vocabulary set by LootHistory's `/lh test`:

| Before | After |
|---|---|
| `/bl preview` | `/bl test` |
| `LT.previewMode` | `LT.testMode` |
| `LT:TogglePreview` | `LT:ToggleTestMode` |
| `LT:BuildPreviewData` | `LT:BuildTestData` |
| `PREVIEW_ITEMS`, `PREVIEW_STORES`, `PREVIEW_CHARS`, `PREVIEW_DAY`, `PREVIEW_SPAN_DAYS`, `previewRng` | `TEST_*`, `testRng` |
| `frame.previewBadge`, badge text `PREVIEW` | `frame.testBadge`, badge text `TEST MODE` |

`NS.State.testRecords` and `Database:ActiveLedger` already use the "test" name and do not move.

**Flagged, not done:** `SessionWindow.previewSession` (`/bl session`) is a separate synthetic-data
feature with no LootHistory counterpart. Its naming is left alone.

### Enriched dataset

The generator keeps its deterministic Park–Miller LCG and fixed seed, so the dataset stays
byte-identical between runs and the headless tests can keep asserting on it. What changes is the
distribution: the current data is near-uniform across 8 items, 3 stores, 3 characters and 1 zone,
which makes every chart a flat comb.

The new generator follows LootHistory's structure, shaped for banking:

- **Weighted stores** — character bank heavy, guild and warband mid, reagent bank light.
- **Weighted direction** — roughly 60/40 deposit-leaning, as a real bank is.
- **~8 characters** across distinct classes, weighted so two or three "mains" dominate.
- **Six bank-city zones** with real map ids.
- **Weighted item types** with representative sub-types per type.
- **A hot-item head over a ~30-item long tail**, so the top-items lists have real shape.
- **Weighted qualities 0–5.**
- **An evening-leaning hour-of-day curve** and recency-clustered day offsets.
- **Gold movements** at the two stores that hold coin.
- **No `vendorPrice`** — value is gone.

A coverage seed pass runs first and guarantees, regardless of the dice, that every store, both
directions, every quality 0–5 and every character in the pool appear at least once and that the
timestamp span exceeds 14 days. The headless tests assert exactly that.

---

## 6 — `<Segment> × In/Out` companion charts

Four stacked-bar companions, each placed **immediately after its parent chart**, segmented
deposit-green / withdraw-red with a legend:

| Parent chart | Companion | Source |
|---|---|---|
| Movements By Store | Store × In/Out | `storeByDirection` — already computed, currently unused |
| Movements By Quality | Quality × In/Out | new `qualityByDirection` |
| Movements By Item Type | Item Type × In/Out | new `itemTypeByDirection` |
| Movements By Sub-type | Sub-type × In/Out | new `subTypeByDirection` |

They render through the existing `I:RenderStacked` + `I:RenderLegend` path with
`catOrder = C.DirectionOrder`, exactly as *Character × In/Out* already does. Each row's label keeps
its parent chart's colour (store colour, quality colour, palette colour by rank) so a category is
recognisable across the pair.

The three new maps are plain extra accumulators in the same single `Stats` pass — the panel gets
richer without the aggregation getting slower, and no existing key changes name or meaning.

---

## 7 — Top of the list, reorganized

### Layout

Three columns instead of two, with grouped sub-headers. Each metric becomes one row of three
panels, so the All / Deposits / Withdrawals triptych *is* the visual organization:

```
════════════════════ TOP OF THE LIST ════════════════════

  ITEMS
  Top Items By Movements
  ┌─ All ─────────┐ ┌─ Deposits ────┐ ┌─ Withdrawals ─┐
  Top Items By Quantity
  ┌─ All ─────────┐ ┌─ Deposits ────┐ ┌─ Withdrawals ─┐

  CATEGORIES
  Top Type · Sub-type
  ┌─ All ─────────┐ ┌─ Deposits ────┐ ┌─ Withdrawals ─┐

  WHERE
  Top Banking Spots
  ┌─ All ─────────┐ ┌─ Deposits ────┐ ┌─ Withdrawals ─┐

  BY STORE
  ┌ Character Bank ┐ ┌ Warband Bank ┐ ┌ Guild Bank ──┐
  ┌ Reagent Bank ──┐ ┌ Bags ────────┐
```

*Top Items By Value* is gone. A panel with no rows hides, so a slice with no withdrawals simply has
no Withdrawals column; each row advances by the height of its tallest panel.

### Panel pooling

`self.panels` is currently a fixed table of four panels with titles baked in at `Attach`. The store
panels are variable in count (up to five, only those with movements) and every panel now needs a
per-pass title, so panels become **pooled**:

- `W.MakeListPanel` gains a settable title; `W.NewPanelPool` / acquire-release join the existing
  pool vocabulary in `InsightsWidgets.lua`.
- A pooled panel carries **its own row pool** on itself (`panel._rows`), because rows are parented
  to a specific panel at creation and cannot be shared across panels.

This keeps the two-file split intact: pooling is HOW, so it lives in `InsightsWidgets.lua`; the list
definitions stay in `Insights.lua`, which lands around 880 lines.

### Stats

| Addition | Shape |
|---|---|
| `byItem[id]` gains `movesIn`, `movesOut`, `qtyIn`, `qtyOut` | Six item rankings become six sorts over the *same* record tables — no extra memory, matching the existing three-way pattern. |
| `topZones` records gain `inCount`, `outCount` | `{ zone, count, inCount, outCount }` → three zone rankings. `stats.byZone` **keeps its plain count-map shape**: `modules/Export.lua:153` feeds it straight to `rankedRows`, and reshaping it would break the stats CSV for no gain. |
| `byTypeSub` (new) | Keyed `Type .. "\t" .. SubType` so the pair is unambiguous; records are `{ type, subType, label, count, inCount, outCount }` where `label` is the display form `"Type · SubType"`. → three rankings. |
| `itemsByStore` (new) | `[store][itemID] = moves` → one ranked list per store. |

All accumulate in the single existing pass. Every comparator still ends on `itemID` or the label, so
a tie can never reorder between refreshes — the existing determinism invariant.

---

## Cards, after the removals

Dropping `value` and `biggest` leaves 14 column-units in a 4-wide grid, so the bottom row would be
half empty. Two derived cards are added — both from figures the pass already computes, so they cost
nothing — making four clean rows:

```
row 1   movements  │ items in   │ items out │ net items
row 2   distinct   │ characters │ active d  │ top store
row 3   items moved│ gold in    │ gold out  │ net gold
row 4  [      date range      ][     busiest day     ]
```

- **top store** — the store with the most movements, from `byStore`.
- **items moved** — `itemsDeposited + itemsWithdrawn`, total stack units that crossed the line.

Each carries a tooltip, like every other card.

---

## Invariants held

Nothing in this spec changes the panel's contracts:

- Insights computes off **one** `Database:Stats` pass against the **same** filter the ledger table
  uses, so the two views cannot disagree about which slice they describe.
- `Stats` remains a single O(n) pass; every new breakdown is an accumulator inside it.
- Every widget stays **pooled** — created once, released per layout, re-acquired in place.
- Live refresh stays on the module's own `NS.NewBusTarget()`, never the shared bus-as-self.
- Pure helpers (ranking, fractions, formatting, the test generator) stay separable from layout and
  unit-tested without a client.

## Testing

Green gate before commit: `lua tests/run.lua` and `luacheck .` at 0/0.

**Rewritten** — every value assertion across `test_util`, `test_export`, `test_database`,
`test_compat`, `test_ledger`, `test_insights` and `test_stats`.

**New coverage:**

| Area | Assertion |
|---|---|
| Migration | v1 database with `vendorPrice` → v2 with the field gone; idempotent on a second run. |
| `netByStore` | Signed by movement count, deposits positive. |
| Icon truncation | A long character name yields a label whose `\|T…\|t` escape is intact and whose name is cut, not the escape. |
| New direction maps | `qualityByDirection`, `itemTypeByDirection`, `subTypeByDirection` split correctly and sum to the parent chart's counts. |
| Direction-split rankings | Item / zone / type-sub In and Out lists rank independently and sum to the combined list. |
| `itemsByStore` | One list per store, ranked, deterministic on ties. |
| Test dataset | Coverage seed guarantees: every store, both directions, qualities 0–5, every character, span > 14 days. Byte-identical across two builds. |

## Documentation

`docs/ARCHITECTURE.md` (stats keys, schema v2, the accepted export deviation), `docs/agent-context.md`,
`docs/smoke-tests.md` (`/bl test`, the new sections), `docs/test-cases.md`, `docs/testing.md` and
`README.md`. No version bump — that is a separate, explicit instruction.
