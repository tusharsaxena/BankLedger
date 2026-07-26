# Design — Banking-session window + expanded Insights

Date: 2026-07-26 · Branch: `feature/session-window-and-insights`

Two independent features, delivered together on one branch. They share no code path; the only files
both touch are the TOC, `tests/run.lua`, `.luacheckrc` and the docs.

---

## Feature 1 — Current Banking Session window

### Intent

While a bank is open, show a small live window listing exactly what moved **during this visit**.
The main History window answers "what have I ever moved"; this answers "what did I just do".

### Session definition

A session is the span between a storage frame opening and closing — precisely the span
`modules/Ledger.lua` already tracks as `NS.State.openContext`. `Ledger:OpenContext` starts one and
`Ledger:CloseContext` ends one, which also covers the guild bank (armed by tab data rather than by an
open event) with no special case.

### Data

Session rows are **not persisted and not a second copy of the ledger**. `NS.State.sessionEntries` is
a runtime array of references to the entries `Database:Add` appended while the session was open. It
is cleared at session start and dropped at `/reload` like every other `State` field. Nothing new is
written to SavedVariables.

Capture already only records the logged-in character's own movements, so "no character column" is
correct by construction.

### Module — `modules/SessionWindow.lua`

A second standalone window (standalone-windows): non-secure `CreateFrame`, `UISpecialFrames` for
ESC, geometry persisted, window scale honoured, built on the Browser's existing `SKIN` /
`ApplySkin` / `MakeCloseButton` seams so it is visually the same object as the main window.

It has its own slim pooled-row table rather than a second instance of `NS.LedgerTable`.
`LedgerTable` is a stateful singleton (one `rowPool`, one `displayList`, one sort/group/filter/
collapse state) and generalising it into a class is a larger, riskier change than the ~180 lines a
table with no sorting, no grouping, no filtering and no collapse actually needs. What is **not**
duplicated is the definition of a column: `LedgerTable` gains two public seams the session table
consumes, so a column's text and its colour have exactly one definition addon-wide.

| New `LedgerTable` seam | Purpose |
|---|---|
| `LT:Column(key)` | The column spec (label, width, align, desc, `valueFn`) for a key. |
| `LT:PaintCell(fs, colKey, entry, glyphFS)` | Set a cell's text + colour (quality / direction / store / money), optionally driving the direction glyph. |

### Deviations from the History window

| # | Requirement | How |
|---|---|---|
| 0 | Title `Ka0s Bank Ledger - Current Banking Session` | Title-bar `FontString`. |
| 1 | No Insights tab | No tab strip at all — one pane. |
| 2 | No filters / search / Clear / Export | No filter bar; the pane starts under the title bar. |
| 3 | No Character column | Column set omits `char`. |
| 4 | Headers inert | Header cells are `FontString`s on a plain frame, not `Button`s. Tooltips (the column `desc`) are kept — they explain, they don't act. |
| 5 | No Date / Time columns | Column set omits `date` and `time`. |
| 6 | No footer | Pane runs to the bottom inset. |

Columns, left → right: **In/Out · Store · Item (flex) · Qty · Quality · Type · Sub-type**.

### Geometry

Fixed widths 74 + 112 + 92 + 64 + 86 + 92 = 520, plus the 150px Item minimum, 7 × 8px gaps, a 24px
scrollbar gutter and 12px of pane margin → **min/default width 762**. Default height 320
(≈ 13 rows), minimum 200. Resizable from the bottom-right grip; position and size persist to
`db.global.settings.sessionWindow` — a storage carve-out written by this module, the same shape and
for the same reason as `settings.window` (architecture-§5; geometry is view state with no place in
the settings panel).

Default position: `CENTER` of `UIParent` offset `+420, 0`, i.e. clear of the bank frame, and moved
once by the player thereafter.

### Live updates

`SessionWindow` registers on its own `NS.NewBusTarget()` (never the shared bus-as-self) for
`Ka0s_BankLedger_EntryAdded` and appends + repaints while a session is active. `LedgerChanged`
(a delete or a purge) prunes rows that no longer exist in the ledger, so the session view cannot
outlive its data.

### New bus message

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_BankLedger_SessionChanged` | `modules/Ledger.lua` | `active` (boolean), `context` (string or nil) | `SessionWindow` |

One sender, as architecture-§4 requires. `Ledger` fires it from `OpenContext` (true) and
`CloseContext` (false); `SessionWindow` shows on true, hides on false.

### Setting

| Path | Type | Default | Group | Widget |
|---|---|---|---|---|
| `settings.showSessionWindow` | boolean | `true` | Master Controls | CheckBox |

Turning it off while a session window is open hides it immediately (via the row's `onChange` →
`SettingsChanged`). It never suppresses capture — only the window.

### Positioning without a bank (preview-mode)

The standard asks that a positionable display be placeable without waiting for real data
(preview-mode). `/bl session` toggles the window with a small synthetic session when no bank is
open, so it can be dragged and sized on demand. It reuses the real render path; the synthetic rows
are never recorded.

---

## Feature 2 — Expanded Insights

### Intent

The current tab is four flat blue bar lists and eight bare numbers. The sibling addon
LootHistory's `modules/Analytics.lua` is the reference implementation for a Ka0s insights panel:
backdrop KPI cards with shrink-to-fit headlines, section dividers, horizontal bar sections that
colour-code by category and carry legends, per-character stacked companions, per-bucket vertical
strips with rotated axis labels, and ranked list panels in two columns. This feature brings the same
vocabulary to Bank Ledger, applied to what a bank ledger actually measures: **flow** — direction,
store, and net.

Everything stays driven by the Browser's single shared filter, so the charts and the History table
can never describe different slices.

### Files

`modules/Insights.lua` grows past a comfortable single-file size, so the visual vocabulary is peeled
into its own module (hard rule 15's spirit — peel before it hurts):

| File | Role |
|---|---|
| `modules/InsightsWidgets.lua` | Pooled visual primitives + the categorical palette, label truncation, class/quality colour helpers, cursor tooltips. No knowledge of the ledger. |
| `modules/Insights.lua` | The section list, the `Stats` → rows mapping, layout, refresh, and the bus subscription. |

`InsightsWidgets` loads before `Insights` in the TOC.

### Primitives (`InsightsWidgets`)

* **KPI card** — backdrop panel, gold headline (shrink-to-fit for long money strings), grey caption,
  optional tooltip; `wide` cards span two columns.
* **Horizontal bar** — fixed label column, track + coloured fill, fixed value column; hover shows the
  untruncated label.
* **Stacked bar** — one row split into up to 9 coloured segments, each with its own hover tip.
* **Diverging bar** — a centre baseline with the fill growing right (green, net in) or left (red, net
  out). New here, and the honest form for net flow.
* **Ratio bar** — one full-width bar split into two labelled shares, for deposits vs withdrawals.
* **Vertical strip** — per-bucket columns with a baseline axis and rotated x-axis labels, thinned out
  when the bars get narrow.
* **Ranked list panel** — a bordered panel of `name … value` rows, capped at 10.
* **Legend** — wrapped colour-swatch chips.
* **Section divider** — centred gold title flanked by rules.

All pooled (acquire/release, created once, repainted in place) — the existing frame-light discipline.

### Sections

Cards (4 across, `wide` spans 2):

`Movements` · `Items in` · `Items out` · `Net items` · `Distinct items` · `Characters` ·
`Active days` · `Value moved` · `Gold in` · `Gold out` · `Net gold` · `Biggest move` ·
`Date range` (wide) · `Busiest day` (wide)

Then, under an **ITEMS & FLOW** divider:

1. Deposits vs withdrawals — ratio bar, counts + percentages.
2. Movements by store — bars in store colours.
3. Net flow by store — diverging bars, signed copper.
4. Value moved by store — bars in store colours.
5. Movements by character — bars in class colours, class icon on the label.
6. Character × Store — stacked companion + legend.
7. Character × In/Out — stacked companion + legend.
8. Movements by quality — bars in quality colours, ascending quality.
9. Movements by item type — bars from the categorical palette.
10. Movements by sub-type — bars from the same palette.
11. Movements over time — per-day strip.
12. Value moved over time — per-day strip.
13. Movements by hour of day — 24-bucket strip.
14. Movements by weekday — 7 bars.

Then, under a **GOLD** divider (shown only when the filtered slice holds a gold movement):

15. Gold moved over time — per-day strip.
16. Gold by store — bars.

Then two columns of ranked lists:

| Left | Right |
|---|---|
| Top items by value | Top items by moves |
| Top banking spots (zone) | Top items by quantity |

Empty slice → every section hides and one centred "No movements match your filters." line shows.

### `Database:Stats` additions

Purely **additive** — every existing key keeps its name and meaning, so `Export:InsightsCSV`,
`tests/test_stats.lua` and the current widgets are unaffected.

| New key | Shape |
|---|---|
| `byQuality` | `[qualityID] = count` (item rows only) |
| `byItemSubType` | `[subType] = count` |
| `byHour` | `[0..23] = count` |
| `byWeekday` | `[0..6] = count` |
| `byZone` | `[zone] = count` |
| `moneyByDay` | `[YYYY-MM-DD] = copper moved` |
| `moneyByStore` | `[store] = copper moved` |
| `charByDirection` | `[char][direction] = count` |
| `storeByDirection` | `[store][direction] = count` |
| `topItemsByValue` | array sorted value-desc |
| `topItemsByQuantity` | array sorted quantity-desc |
| `topZones` | array sorted count-desc |
| `totals.netItems` | `itemsDeposited - itemsWithdrawn` |
| `totals.moneyMoved` | `moneyIn + moneyOut` |

`topItems` (by moves) already exists and keeps its ordering contract.

### `Export:InsightsCSV` additions

New sections mirroring the new charts, appended after the existing ones so column order and every
existing section header are unchanged: `By Quality`, `By Sub-type`, `By Hour`, `By Weekday`,
`By Zone`, `Top Items By Value`, `Top Items By Quantity`, `Money By Store`, plus
`Summary,Net items` and `Summary,Gold moved`.

---

## Testing

Headless, TDD, and the green gate (`lua tests/run.lua` + `luacheck .`) before every commit.

New suites:

* `tests/test_sessionwindow.lua` — session start clears and arms; `EntryAdded` appends only while
  active; the disable setting suppresses the window without suppressing capture; the column set
  excludes `date`/`time`/`char` and includes the seven kept keys; a deleted entry is pruned; the
  computed minimum width matches the column model.
* `tests/test_insights.lua` — palette cycling, label truncation, the diverging-bar fraction/side
  maths, ratio-bar shares, day-key list generation (gaps included, capped), card value formatting,
  shrink-to-fit font sizing, and each section's rows-from-stats mapping.

Extended suites:

* `tests/test_stats.lua` — one case per new `Stats` key.
* `tests/test_export.lua` — the new `InsightsCSV` sections.
* `tests/test_ledgertable.lua` — the new `Column` / `PaintCell` seams.
* `tests/test_schema.lua` — the new schema row resolves against defaults.

`docs/test-cases.md` is regenerated (`lua tests/run.lua --list`) and the README `[tests]` badge moves
in the same change (testing-§5).

## Docs

`docs/ARCHITECTURE.md` (module map, settings schema, storage carve-outs, bus table, slash surface),
`docs/smoke-tests.md` (a new S-17 session-window case; S-9 Insights rewritten), and the README
(Usage → slash commands + settings table, What's new, FAQ). No version bump — that is a separate,
explicitly-instructed step.

## Standards notes

* The feature branch is an explicit user instruction, so hard rule 23 (trunk-based) is satisfied by
  request rather than deviated from.
* The session window is a second standalone window and follows standalone-windows in full
  (non-secure frame, ESC via `UISpecialFrames`, persisted geometry, scale setting, the shared
  `SKIN`/`ApplySkin` seam, pooled rows).
* `settings.sessionWindow` joins `settings.window` as a documented storage carve-out.
* `Ka0s_BankLedger_SessionChanged` has exactly one sender (`Ledger`).
* No new deviation from the Ka0s WoW Addon Standard is introduced or required.
