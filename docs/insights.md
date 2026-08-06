# Insights

One `Database:Stats(filter)` pass per refresh, against the Browser's shared filter, feeds the whole
panel — so the charts and the History table always describe the same slice. The panel is split in two:

* `modules/InsightsWidgets.lua` — **how** things are drawn. Pooled primitives (KPI card, horizontal
  bar, back-to-back bar, split bar, stacked bar, vertical strip, ranked list panel, legend, section
  divider) plus the categorical palette, label truncation, color helpers and the geometry math.
  It never touches a ledger entry, which is what makes that math unit-testable headlessly.
* `modules/Insights.lua` — **what** is drawn: fourteen stat cards and seventeen chart sections, each
  mapping one `Stats` key to rows, plus the reorganized "Top Of The List" ranked-panel grid below them.

#### `Database:Stats` keys

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

#### Section order

In render order: Deposits vs Withdrawals (one back-to-back bar about a center axis — withdrawals
left, deposits right, `W.PeakShares` → `W.PlaceSplitBar`, both sides scaled against the larger so
the bigger direction fills its half; caption labels **below** the bar, not inside it), Movements
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
fixed center axis, deposits grow RIGHT. Both sides share **one** scale — the largest single-direction
magnitude in the list — so the split sits on the same vertical line in every row and the lean of the
whole chart reads straight down that line. A left-aligned stacked bar puts that boundary somewhere
different on every row and answers the question only after arithmetic, which is why the form changed.
Each row keeps its parent chart's label color (store color, quality color, class color, palette
color by rank) so a category stays recognizable across the pair, and each half carries its own
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

* **Every deposit/withdrawal chart is back to back, not stacked** — the headline `Deposits vs
  Withdrawals` included. Withdrawals grow left of a fixed center axis and deposits grow right, on
  one shared scale: the largest single-direction magnitude in the list for a companion, the larger
  of the two for the headline pair. A left-aligned stacked bar puts the in/out boundary in a
  different place on every row, so "which way does this lean" takes arithmetic; pinning the split
  to one vertical line makes it readable straight down the column. The headline chart was a
  100%-stacked ratio bar until it was converted to this form — it answered the same question in a
  second visual language, directly above the five companions speaking the first one, and the shares
  it showed in its lengths are carried by its captions instead.
* **Color is never decorative.** Store, direction, quality and class bars take their color from the
  shared palettes in `core/Constants.lua`, so a bar matches the table column it summarizes. Only the
  breakdowns with no palette of their own (item type, sub-type, weekday) fall back to
  `InsightsWidgets.PaletteColor`, assigned by *rank* so adjacent bars are never lookalikes.
* **Empty is drawn, missing is not.** A quiet day keeps a ghost bar in a strip (a gap cannot be told
  apart from a day outside the range) and the cards paint "0" rather than vanishing; but the whole
  GOLD block hides when the slice holds no coin movement, because two blank charts under a banner
  read as a broken addon.

Every widget is pooled and repainted in place. The Blizzard UI runs a super-linear pass over a frame
tree on some transitions, so re-allocating widgets per refresh is what turns a smooth panel into a
visible hitch.
