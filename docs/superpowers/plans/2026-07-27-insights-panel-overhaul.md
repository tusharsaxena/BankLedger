# Insights Panel Overhaul Implementation Plan

> **Status: implemented.** Delivered in full across commits `1144bc1`…`377757f` (schema v2 and the
> vendor-value removal through to the back-to-back In/Out charts). The step checkboxes below were
> never ticked as the work landed — this document is history, not an open work list. Do not
> re-execute it.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the vendor-value dimension from Ka0s Bank Ledger entirely, fix three Insights rendering defects, add eight new direction-split breakdowns, reorganize the ranked-list section, and rename/enrich the synthetic test dataset.

**Architecture:** Everything the Insights tab draws comes from **one** `Database:Stats` pass over the **same** filter the ledger table uses. Value removal is therefore a `Stats` rewrite that ripples outward to the CSV exports and the panel; every new breakdown is an extra accumulator inside that same single O(n) loop. Rendering stays split across two files — `modules/Insights.lua` decides WHAT is shown, `modules/InsightsWidgets.lua` decides HOW — and every widget stays pooled.

**Tech Stack:** Lua 5.1 (WoW client dialect), Ace3 (AceDB/AceEvent/AceConfig), headless test harness at `tests/run.lua`, `luacheck` for lint.

**Spec:** `docs/superpowers/specs/2026-07-27-insights-panel-overhaul-design.md`

## Global Constraints

- **Standards.** This repo is built to the **Ka0s WoW Addon Standard** (https://github.com/tusharsaxena/WowAddonStandards). Any change that would deviate must be **stopped and flagged**, never silently absorbed. One deviation is already accepted and recorded in the spec: the CSV export-contract break (Task 3).
- **Green gate before every commit.** `lua tests/run.lua` must report `0 failed` and `luacheck .` must report `0 warnings / 0 errors`. Both run from the repo root.
- **Never** auto-stage/commit/push beyond the commits this plan specifies, and **never** bump the addon version — that requires an explicit separate instruction.
- **No new files.** No module is created or deleted, so `BankLedger.toc`, `tests/run.lua`'s `SUITE_FILES`, and `.luacheckrc` are untouched.
- **Single pass.** `Database:Stats` must remain one O(n) loop over `self:Query(filter)`. New breakdowns are accumulators inside it — never a second iteration over the entries.
- **Pooling.** Every Insights widget is created once, released on each layout, re-acquired in place. Never allocate a frame per row per refresh.
- **Determinism.** Every ranking comparator must end on a stable tiebreak (`itemID`, or the label) so ties cannot reorder between refreshes.
- **Encoding.** Source is ASCII with `\ddd` byte escapes for non-ASCII glyphs (e.g. `"\226\128\148"` is an em-dash, `"\195\151"` is `×`). Do not paste literal UTF-8 into `.lua` files.
- **Line length.** Keep source lines at or under 100 columns — `.luacheckrc` enforces it.
- **Existing debug idiom.** Trace lines go through `if NS.State.debug and NS.Debug then NS.Debug("Tag", "fmt", ...) end`.

## Test harness orientation (read before Task 1)

- Run everything: `lua tests/run.lua`. Run lint: `luacheck .`.
- There is **no per-test filter flag**. To verify a single new test fails, run the whole suite and grep: `lua tests/run.lua 2>&1 | grep -A2 "FAIL"`.
- Suites live in `tests/`, are `dofile`d by `tests/run.lua`, and share one pre-built addon environment. Each suite starts with:
  ```lua
  local T = _G.BL_TEST
  local NS = T.NS
  local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
  ```
  `T.mocks` holds the WoW API mocks (`T.mocks.CreateFrame()` returns a mock frame).
- `docs/test-cases.md` is **generated**. Regenerate it with `lua tests/run.lua --list > docs/test-cases.md` whenever the suite changes (Task 10).
- Most suites swap `NS.db.global.ledger` for a fixture and restore it. Follow that pattern; always restore.

---

## File Structure

| File | Responsibility | Tasks |
|---|---|---|
| `core/Util.lua` | Delete `EntryValue` / `SignedValue`. | 1 |
| `core/Compat.lua` | `GetItemDetails` drops its `vendorPrice` return. | 1 |
| `core/Database.lua` | Schema-v2 migration; `Export` field list; the whole `Stats` rewrite (value removal, count-based `netByStore`, 3 direction maps, direction-split item/zone/type-sub rankings, `itemsByStore`, `topStore`). | 1, 2, 7, 8 |
| `modules/Ledger.lua` | Stop writing `entry.vendorPrice`. | 1 |
| `modules/Export.lua` | Drop the 4 value columns and the value sections from both CSVs. | 3 |
| `modules/Insights.lua` | WHAT is shown: card defs, section order, the 4 new × In/Out charts, the reorganized 3-column list grid. | 4, 5, 6, 7, 8 |
| `modules/InsightsWidgets.lua` | HOW it is drawn: `icon` support on bars, ratio-bar caption, `smallValue` removal, list-panel pooling. | 5, 6, 8 |
| `modules/LedgerTable.lua` | `preview` → `test` rename; the enriched generator. | 1, 9 |
| `modules/Browser.lua` | Badge rename (`previewBadge` → `testBadge`, `PREVIEW` → `TEST MODE`). | 9 |
| `modules/SessionWindow.lua` | Drop `vendorPrice` from its synthetic rows. Its own `previewSession` naming is **deliberately left alone**. | 1 |
| `settings/Schema.lua` | `/bl preview` → `/bl test`. | 9 |
| `tests/*.lua` | Fixture and assertion updates plus new coverage. | all |
| `docs/*`, `README.md` | Documentation sync. | 10 |

---

## Task 1: Strip value from capture, storage and the schema

**Files:**
- Modify: `core/Util.lua:123-137` (delete two functions)
- Modify: `core/Compat.lua:172-181` (`GetItemDetails`)
- Modify: `core/Database.lua:13-25` (`RunMigrations`), `core/Database.lua:130-142` (`Export`)
- Modify: `modules/Ledger.lua:361-370`
- Modify: `modules/LedgerTable.lua:316-364`, `modules/SessionWindow.lua:185-206`
- Test: `tests/test_database.lua`, `tests/test_util.lua`, `tests/test_compat.lua`, `tests/test_ledger.lua`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `NS.Util.EntryValue` and `NS.Util.SignedValue` **no longer exist** — later tasks must not reference them. `NS.Compat.GetItemDetails(idOrLink)` returns exactly `name, quality, itemType, itemSubType, link` (5 values, `link` moves from 6th to 5th). Ledger entries never carry `vendorPrice`. `db.global.schemaVersion == 2`.

- [ ] **Step 1: Write the failing migration test**

Append to `tests/test_database.lua`:

```lua
-- ── Schema v1 → v2: vendorPrice leaves the SavedVariables file ──────────────────

test("RunMigrations strips vendorPrice from every stored entry and bumps to v2", function()
  local saved, savedVer = NS.db.global.ledger, NS.db.global.schemaVersion
  NS.db.global.schemaVersion = 1
  NS.db.global.ledger = {
    { ts = 1, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
      itemID = 2589, itemName = "Linen Cloth", quantity = 10, vendorPrice = 20 },
    { ts = 2, char = "A-R", kind = "MONEY", direction = "DEPOSIT", store = "GUILD_BANK",
      itemName = "Gold", quantity = 50000 },
  }
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
  assertEqual(NS.db.global.ledger[1].vendorPrice, nil)
  assertEqual(NS.db.global.ledger[1].quantity, 10, "the rest of the entry is untouched")
  NS.db.global.ledger, NS.db.global.schemaVersion = saved, savedVer
end)

test("RunMigrations is idempotent on an already-migrated database", function()
  local saved, savedVer = NS.db.global.ledger, NS.db.global.schemaVersion
  NS.db.global.schemaVersion = 2
  NS.db.global.ledger = { { ts = 1, kind = "ITEM", quantity = 3 } }
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
  assertEqual(NS.db.global.ledger[1].quantity, 3)
  NS.db.global.ledger, NS.db.global.schemaVersion = saved, savedVer
end)

test("Database:Export never emits a vendorPrice field", function()
  local saved = NS.db.global.ledger
  NS.db.global.ledger = {
    { ts = 1, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
      itemID = 2589, itemName = "Linen Cloth", quantity = 10, vendorPrice = 20 },
  }
  local out = NS.Database:Export()
  assertEqual(out[1].vendorPrice, nil)
  assertEqual(out[1].itemName, "Linen Cloth")
  NS.db.global.ledger = saved
end)
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: FAIL on all three — `RunMigrations` leaves `schemaVersion` at 1, and `Export` copies `vendorPrice`.

- [ ] **Step 3: Write the migration**

Replace the placeholder body of `NS:RunMigrations` in `core/Database.lua` (currently lines 13-25) with:

```lua
function NS:RunMigrations()
  local g = NS.db and NS.db.global
  if not g then return end
  g.schemaVersion = g.schemaVersion or 1
  -- v1 -> v2: the addon no longer derives, captures or persists vendor value, so the field leaves
  -- the SavedVariables file rather than merely going unread. Idempotent: clearing an absent field
  -- is a no-op, so a partially-migrated database converges on a second run.
  if g.schemaVersion < 2 then
    local n = 0
    for _, e in ipairs(g.ledger or {}) do
      if e.vendorPrice ~= nil then e.vendorPrice = nil; n = n + 1 end
    end
    g.schemaVersion = 2
    if NS.State.debug and NS.Debug then
      NS.Debug("Migrate", "%s", NS.MigrationSummary(1, 2, n))
    end
  end
end
```

- [ ] **Step 4: Delete the value helpers**

In `core/Util.lua`, delete `Util.EntryValue` and `Util.SignedValue` **together with their comment blocks** (currently lines 123-137). Nothing replaces them.

- [ ] **Step 5: Stop capturing vendor price**

In `core/Compat.lua`, `GetItemDetails` becomes:

```lua
-- Display info for an item id (or link). Returns name, quality, itemType, itemSubType, link --
-- each nil when the client hasn't cached the item yet. Vendor price is deliberately NOT read: the
-- addon does not derive or persist item value (schema v2).
function Compat.GetItemDetails(idOrLink)
  if not idOrLink then return nil end
  if not (C_Item and C_Item.GetItemInfo) then return nil end
  local name, link, quality, _, _, itemType, itemSubType = C_Item.GetItemInfo(idOrLink)
  if not name then return nil end
  return name, quality, itemType, itemSubType, link
end
```

In `modules/Ledger.lua` (currently lines 362-368), the call site becomes — note `link` moves to the 5th slot and the `entry.vendorPrice` assignment is deleted:

```lua
  entry.itemID = move.itemID
  local name, quality, itemType, itemSubType, link = NS.Compat.GetItemDetails(move.itemID)
  entry.itemName = name
  entry.quality = quality
  entry.itemType = itemType
  entry.itemSubType = itemSubType
  entry.itemLink = link
  return entry
```

In `core/Database.lua`, `Database:Export` drops `vendorPrice = e.vendorPrice,` from the copied field list (currently line 137).

- [ ] **Step 6: Drop vendorPrice from the two synthetic datasets**

In `modules/LedgerTable.lua`, `PREVIEW_ITEMS` rows lose their trailing 6th element (the vendor price), leaving `{ id, name, quality, type, subType }`:

```lua
local PREVIEW_ITEMS = {
  { 2589,  "Linen Cloth",           1, "Tradegoods", "Cloth" },
  { 4306,  "Silk Cloth",            1, "Tradegoods", "Cloth" },
  { 171276,"Spectral Flask",        3, "Consumable", "Flask" },
  { 19019, "Thunderfury",           5, "Weapon",     "Swords" },
  { 6948,  "Hearthstone",           1, "Miscellaneous", "Junk" },
  { 194863,"Serevite Ore",          1, "Tradegoods", "Metal" },
  { 190316,"Refreshing Healing Potion", 2, "Consumable", "Potion" },
  { 200071,"Dragon Isles Herb",     2, "Tradegoods", "Herb" },
}
```

and in `LT:BuildPreviewData`'s `push`, delete `vendorPrice = it[6],` from the emitted table (leave `itemType = it[4], itemSubType = it[5],` as they are).

In `modules/SessionWindow.lua`, `PREVIEW_ROWS` loses its 8th element (vendor price), so quantity moves from `r[9]` to `r[8]`:

```lua
local PREVIEW_ROWS = {
  { "WITHDRAW", "BANK",         2589,   "Linen Cloth",     1, "Tradegoods",    "Cloth",  40 },
  { "DEPOSIT",  "BANK",         194863, "Serevite Ore",    1, "Tradegoods",    "Metal",  200 },
  { "DEPOSIT",  "WARBAND_BANK", 171276, "Spectral Flask",  3, "Consumable",    "Flask",  4 },
  { "WITHDRAW", "WARBAND_BANK", 19019,  "Thunderfury",     5, "Weapon",        "Swords", 1 },
  { "DEPOSIT",  "GUILD_BANK",   6948,   "Hearthstone",     1, "Miscellaneous", "Junk",   1 },
}
```

and in `SW:BuildPreviewSession` the emitted row becomes `itemType = r[6], itemSubType = r[7], quantity = r[8],`.

- [ ] **Step 7: Update the existing tests that assert on value**

In `tests/test_util.lua`, delete every `Util.EntryValue` / `Util.SignedValue` test (around line 107) — the functions no longer exist, so the tests go with them.

In `tests/test_compat.lua` (around lines 31-36), remove `vendorPrice` from the destructuring and delete `assertEqual(vendorPrice, 5000)`:

```lua
  local name, quality, itemType, itemSubType = NS.Compat.GetItemDetails(171276)
```

In `tests/test_ledger.lua` (around line 425), the assertion inverts — capture must now leave the field absent:

```lua
  assertEqual(e.vendorPrice, nil, "schema v2 never persists vendor value")
```

- [ ] **Step 8: Do NOT run a green gate here — continue straight into Task 2**

**This task has no standalone green gate, by design.** `Database:Stats` calls `NS.Util.EntryValue` and `NS.Util.SignedValue` on every entry, and Step 4 just deleted both. The suite therefore **cannot** pass until `Stats` stops calling them, which is Task 2's job. There is no honest intermediate state: faking one (stubbing the helpers to return 0) would put a lie in the tree for one commit.

**Task 1 and Task 2 share one commit.** Do not commit anything yet. Proceed directly to Task 2, complete it, and commit both under Task 2's Step 6.

If you want a sanity check before moving on, confirm the *only* remaining references to the deleted helpers are the two inside `Stats`:

Run: `grep -rn "EntryValue\|SignedValue" --include="*.lua" core modules settings`
Expected: exactly two hits, both in `core/Database.lua` inside the `Stats` entry loop. Any other hit is a call site this task missed — fix it before continuing.

---

## Task 2: Remove value from `Database:Stats`; re-base `netByStore` on movement count

**Files:**
- Modify: `core/Database.lua:149-318` (`Database:Stats`)
- Test: `tests/test_stats.lua`

**Interfaces:**
- Consumes: Task 1 (`Util.EntryValue` / `Util.SignedValue` are gone).
- Produces: `Database:Stats(filter)` returns a table **without** `valueByStore`, `valueByDay`, `topItemsByValue`; `totals` without `totalValue` and `biggestMove`; `byItem` records without `.value`; `byChar` records without `.value`. `netByStore[store]` is now an **integer movement count**, positive when deposits outnumber withdrawals. New: `totals.itemsMoved` (number) and `totals.topStore` (`{ store = <key>, count = <n> }` or `nil`).

- [ ] **Step 1: Write the failing tests**

In `tests/test_stats.lua`, first **strip `vendorPrice` from every entry in `FIXTURE`** and fix the stale comments (the `-- ... vendor 20 -> value 200` notes). Then delete the existing `"Stats: total value ..."` test and any test asserting `valueByStore`, `valueByDay`, `topItemsByValue`, `biggestMove`, `ce.value` or `rec.value`. Append:

```lua
-- ── Value is gone; net flow is counted in movements ─────────────────────────────

test("Stats no longer reports any value figure", function()
  local s = stats()
  assertEqual(s.totals.totalValue, nil)
  assertEqual(s.totals.biggestMove, nil)
  assertEqual(s.valueByStore, nil)
  assertEqual(s.valueByDay, nil)
  assertEqual(s.topItemsByValue, nil)
  assertEqual(s.topItems[1].value, nil, "item records carry no value")
end)

test("Stats: netByStore counts movements, deposits positive", function()
  local s = stats()
  -- BANK: 1 deposit + 1 withdrawal -> 0. WARBAND_BANK: 1 deposit -> +1.
  -- GUILD_BANK: 1 coin deposit + 1 coin withdrawal -> 0.
  assertEqual(s.netByStore.BANK, 0)
  assertEqual(s.netByStore.WARBAND_BANK, 1)
  assertEqual(s.netByStore.GUILD_BANK, 0)
end)

test("Stats: itemsMoved totals every stack unit that crossed the line", function()
  assertEqual(stats().totals.itemsMoved, 15)   -- 12 in + 3 out
end)

test("Stats: topStore names the store with the most movements", function()
  local top = stats().totals.topStore
  assertEqual(top.store, "BANK")   -- 2 movements, vs 1 warband and 2 guild; BANK wins the tie
  assertEqual(top.count, 2)
end)

test("Stats: topStore is nil on an empty slice", function()
  local saved = NS.db.global.ledger
  NS.db.global.ledger = {}
  assertEqual(NS.Database:Stats({}).totals.topStore, nil)
  NS.db.global.ledger = saved
end)
```

> **Tie note:** `BANK` and `GUILD_BANK` both have 2 movements in `FIXTURE`. The comparator below breaks the tie on the store key ascending, so `"BANK" < "GUILD_BANK"` wins. Keep that comparator exactly as written or the test flips.

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: errors about `NS.Util.EntryValue` being nil (from Task 1) plus failures on the four new assertions.

- [ ] **Step 3: Rewrite the value-bearing parts of `Stats`**

In `core/Database.lua`:

Delete these locals from the declaration block (lines ~152-159): `valueByStore`, `valueByDay`, `totalValue`, `biggestMove`. Keep `netByStore`. Add `itemsMoved` is derived, not accumulated — no local needed.

Inside the entry loop, delete:

```lua
    local value = NS.Util.EntryValue(e)
    local signed = NS.Util.SignedValue(e)
    totalValue = totalValue + value
    valueByStore[store] = (valueByStore[store] or 0) + value
    netByStore[store] = (netByStore[store] or 0) + signed
```

and replace the `netByStore` line with the count form:

```lua
    -- Net flow per store, counted in MOVEMENTS: +1 for a deposit, -1 for a withdrawal. The only
    -- signed non-gold quantity the addon keeps now that vendor value is gone (schema v2).
    netByStore[store] = (netByStore[store] or 0) + (C.DirectionSign[dir] or 1)
```

`C` is not currently a local in `core/Database.lua`. Add near the top of the file, after `local addonName, NS = ...`:

```lua
local C = NS.Constants
```

> **Load-order check:** `core/Constants.lua` loads before `core/Database.lua` in both `BankLedger.toc` and `tests/run.lua`, so `NS.Constants` is populated at this point. Verify the TOC ordering before relying on it.

Also delete inside the loop: `valueByDay[day] = ...`, `rec.value = rec.value + value`, `value = value` from the new `byItem` record, `value = 0` from the new `byChar` record, `ce.value = ce.value + value`, and the whole `biggestMove` block (lines ~253-256).

- [ ] **Step 4: Drop the value rankings and add the two new totals**

Delete `topItemsByValue` from the three-way ranking block: remove its local, its `[#... + 1] = rec` line, and its `table.sort`. `topItems` and `topItemsByQuantity` stay.

After the `activeDays` / `busiestDay` loop, add:

```lua
  -- The store with the most movements, for the "top store" card. Ties break on the store key so
  -- the card cannot flicker between two equally-busy stores across refreshes.
  local topStore
  for store, count in pairs(byStore) do
    if not topStore or count > topStore.count
      or (count == topStore.count and store < topStore.store) then
      topStore = { store = store, count = count }
    end
  end
```

In the returned table, delete `valueByStore`, `valueByDay`, `topItemsByValue`, and inside `totals` delete `totalValue` and `biggestMove`, then add:

```lua
      itemsMoved = itemsDeposited + itemsWithdrawn,
      topStore = topStore,
```

- [ ] **Step 5: Run the green gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `0 failed`, luacheck clean. Failures in `test_export.lua` / `test_insights.lua` mean those files still read a removed key — fix only what is needed to make them run; Tasks 3 and 4 own their real rewrites. If `test_export` breaks because `Export.lua` calls `NS.Util.EntryValue`, jump to Task 3 Step 3 now and fold Task 3 into this commit as well.

- [ ] **Step 6: Commit Tasks 1 + 2 (+ 3 if folded)**

```bash
git add core/Util.lua core/Compat.lua core/Database.lua modules/Ledger.lua \
        modules/LedgerTable.lua modules/SessionWindow.lua tests/
git commit -m "feat(schema)!: drop the vendor-value dimension, bump to schema v2

Value is no longer derived, captured or persisted. Util.EntryValue and
Util.SignedValue are deleted, Compat.GetItemDetails stops reading vendor
price, and a v1->v2 migration strips vendorPrice from every stored entry
so the bytes actually leave the SavedVariables file.

Stats loses totalValue, valueByStore, valueByDay, topItemsByValue,
biggestMove and the per-item/per-character value fields. Net Flow By
Store re-bases on movement count, the only signed non-gold quantity
left. Two new totals replace the removed cards: itemsMoved and topStore.

Gold is untouched -- a MONEY row's amount lives in quantity and was
never vendor-priced."
```

---

## Task 3: Remove value from both CSV exports

**Files:**
- Modify: `modules/Export.lua:19-47` (ledger `COLUMNS`), `modules/Export.lua:91-190` (`InsightsCSV`)
- Test: `tests/test_export.lua`

**Interfaces:**
- Consumes: Task 1 (helpers gone), Task 2 (`netByStore` is a count).
- Produces: `E.COLUMNS` / `E.HEADER` without `vendorPrice`, `value`, `valueRaw`, `net`. `E:InsightsCSV(stats)` without the `Summary/Value moved` row, the `Top Items By Value` section, and with `Net by Store` written into the **Count** column rather than the Value column.

⚠️ **Accepted deviation.** This breaks the documented stable CSV contract (`core/Database.lua:7`, `modules/Export.lua:21`). It is deliberate, approved, and tied to the schema-v2 bump. It must be recorded in `docs/ARCHITECTURE.md` (Task 10) and in the next audit bundle.

- [ ] **Step 1: Write the failing tests**

In `tests/test_export.lua`, strip `vendorPrice` from the fixtures (lines ~13, ~86, ~111, ~113) and delete any assertion referencing the `value`, `valueRaw`, `net` or `vendorPrice` columns. Append:

```lua
test("Export: the ledger CSV carries no value columns", function()
  for _, name in ipairs({ "vendorPrice", "value", "valueRaw", "net" }) do
    for _, h in ipairs(NS.Export.HEADER) do
      assertTrue(h ~= name, "column '" .. name .. "' must be gone from the ledger CSV")
    end
  end
end)

test("Export: the insights CSV drops the value summary and the value ranking", function()
  local csv = NS.Export:InsightsCSV(NS.Database:Stats({}))
  assertEqual(csv:find("Value moved", 1, true), nil)
  assertEqual(csv:find("Top Items By Value", 1, true), nil)
end)

test("Export: net by store is written as a count, not a coin string", function()
  local saved = NS.db.global.ledger
  NS.db.global.ledger = {
    { ts = 1, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
      itemID = 2589, itemName = "Linen Cloth", quantity = 10 },
    { ts = 2, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
      itemID = 4306, itemName = "Silk Cloth", quantity = 1 },
  }
  local csv = NS.Export:InsightsCSV(NS.Database:Stats({}))
  assertTrue(csv:find("Net by Store,Character Bank,2,", 1, true) ~= nil,
    "the net lands in the Count column as a plain 2")
  NS.db.global.ledger = saved
end)
```

- [ ] **Step 2: Run the suite to verify they fail**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: FAIL — the columns are still present and `Export.lua` still calls the deleted `NS.Util.EntryValue`.

- [ ] **Step 3: Cut the ledger CSV columns**

In `modules/Export.lua`, delete these four `COLUMNS` entries (currently lines 43-46):

```lua
  { "vendorPrice",  function(e) return NS.Util.PlainMoney(e.vendorPrice) end },
  { "value",        function(e) return NS.Util.PlainMoney(NS.Util.EntryValue(e)) end },
  { "valueRaw",     function(e) return NS.Util.EntryValue(e) end },
  { "net",          function(e) return NS.Util.SignedValue(e) end },
```

and rewrite the block comment above `COLUMNS` (lines 19-24) to drop the sentences about `value`/`valueRaw`/`net`:

```lua
-- Ledger CSV columns: { header, value(entry) }. `ts` is followed by human `date` and `time`.
-- Renamed raw columns carry a *Raw suffix beside a human sibling -- human `quality` (label) before
-- `qualityRaw` (number) -- so a spreadsheet can sort on the raw number while a reader sees the
-- readable form. itemLink / mapID / subzone are intentionally not exported.
-- Schema v2 removed the vendorPrice / value / valueRaw / net columns: the addon no longer derives
-- item value at all (an accepted, documented break of the otherwise-stable column contract).
```

- [ ] **Step 4: Cut the insights CSV sections**

In `E:InsightsCSV`:

- Delete `row("Summary", "Value moved", nil, t.totalValue or 0)`.
- `section("By Store", rankedRows(stats.byStore, storeLabel, stats.valueByStore))` loses its third argument: `section("By Store", rankedRows(stats.byStore, storeLabel))`.
- The Net-by-Store loop moves its number from the Value column to the Count column:

```lua
  -- Net flow per store, signed and counted in MOVEMENTS (schema v2): a store you keep draining
  -- reads negative.
  for _, s in ipairs(C.StoreOrder) do
    local net = (stats.netByStore or {})[s]
    if net ~= nil then row("Net by Store", storeLabel(s), net) end
  end
```

- In the `charRows` loop, drop `value = ce.value`.
- Delete the whole `topItemsByValue` loop.
- `row("Top Items", itemName(it), it.moves, it.value)` → `row("Top Items", itemName(it), it.moves)`.
- `row("Top Items By Quantity", itemName(it), it.quantity, it.value)` → `row("Top Items By Quantity", itemName(it), it.quantity)`.
- The By Day loop drops its value column: `row("By Day", day, stats.byDay[day])`, and its comment loses the "`value` is the vendor value moved" sentence.
- In `rankedRows`, delete the `valueMap` parameter and the `value = valueMap and valueMap[key] or nil` field — no caller passes one any more.

- [ ] **Step 5: Run the green gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `0 failed`, luacheck clean.

- [ ] **Step 6: Commit**

```bash
git add modules/Export.lua tests/test_export.lua
git commit -m "feat(export)!: drop the value columns from both CSVs

Accepted deviation from the stable-column contract, tied to the schema
v2 bump: a value column with no value behind it is a promise the data
no longer keeps. The ledger CSV loses vendorPrice/value/valueRaw/net;
the insights CSV loses the Value moved summary row and the Top Items By
Value section, and writes Net by Store as a movement count."
```

---

## Task 4: Remove the value charts and cards; add the two derived cards

**Files:**
- Modify: `modules/Insights.lua:19-23` (constants), `:68-98` (`CARD_DEFS`), `:102-126` (titles/pools), `:167-172` (panels), `:211-236` (`CardValues`), `:556-576` (value sections), `:664-676` (strips), `:731-779` (lists)
- Test: `tests/test_insights.lua`

**Interfaces:**
- Consumes: Task 2 (`totals.itemsMoved`, `totals.topStore`, no value keys).
- Produces: `I.CardValues(totals)` returns a table keyed exactly `movements, itemsIn, itemsOut, netItems, distinctItems, chars, activeDays, topStore, itemsMoved, goldIn, goldOut, netGold, span, busiest` — 14 keys, no `value`, no `biggest`. `self.panels.itemValue` no longer exists.

- [ ] **Step 1: Write the failing tests**

In `tests/test_insights.lua`, strip `vendorPrice` from the fixtures (lines ~424, ~450) and delete any test asserting on the `value`/`biggest` cards. Append:

```lua
test("Insights.CardValues no longer produces value or biggest-move cards", function()
  local v = I.CardValues({ entries = 3, itemsDeposited = 10, itemsWithdrawn = 4 })
  assertEqual(v.value, nil)
  assertEqual(v.biggest, nil)
end)

test("Insights.CardValues reports items moved and the top store", function()
  local v = I.CardValues({
    entries = 3, itemsDeposited = 10, itemsWithdrawn = 4,
    topStore = { store = "GUILD_BANK", count = 7 },
  })
  assertEqual(v.itemsMoved, "14")
  assertEqual(v.topStore, "Guild Bank")
end)

test("Insights.CardValues em-dashes the top store on an empty slice", function()
  assertEqual(I.CardValues({}).topStore, "\226\128\148")
end)
```

- [ ] **Step 2: Run the suite to verify they fail**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: FAIL — `v.itemsMoved` and `v.topStore` are nil.

- [ ] **Step 3: Rewrite `CARD_DEFS`**

In `modules/Insights.lua`, replace `CARD_DEFS` (lines 68-98). Note the order below is the approved grid: three full rows of four singles, then one row of two double-wide cards.

```lua
local CARD_DEFS = {
  { key = "movements", caption = "movements",
    tooltip = "Rows in the current slice - one per item stack or coin amount that crossed the line." },
  { key = "itemsIn", caption = "items in",
    tooltip = "Total stack count deposited into a bank from your bags." },
  { key = "itemsOut", caption = "items out",
    tooltip = "Total stack count withdrawn from a bank back into your bags." },
  { key = "netItems", caption = "net items",
    tooltip = "Items in minus items out. Positive means you are stockpiling." },
  { key = "distinctItems", caption = "distinct items",
    tooltip = "How many different items appear, however often each one moved." },
  { key = "chars", caption = "characters",
    tooltip = "How many of your characters appear in this slice." },
  { key = "activeDays", caption = "active days",
    tooltip = "Calendar days on which at least one movement happened." },
  { key = "topStore", caption = "top store",
    tooltip = "The store with the most movements in this slice." },
  { key = "itemsMoved", caption = "items moved",
    tooltip = "Every stack unit that crossed the line, in either direction: items in plus items out." },
  { key = "goldIn", caption = "gold in",
    tooltip = "Coin deposited into the guild and warband banks. The character bank has no coin slot." },
  { key = "goldOut", caption = "gold out",
    tooltip = "Coin withdrawn from the guild and warband banks." },
  { key = "netGold", caption = "net gold",
    tooltip = "Gold in minus gold out. Green means the banks gained; red means you drew down." },
  { key = "span", caption = "date range", wide = true,
    tooltip = "Earliest and latest movement in this slice." },
  { key = "busiest", caption = "busiest day", wide = true,
    tooltip = "The calendar day with the most movements, and how many." },
}
```

> `smallValue` is gone from both wide cards — that is Task 6's item 4, delivered here because the table is being rewritten anyway. `W.MakeCard` still accepts the option until Task 6 deletes it.

- [ ] **Step 4: Rewrite `CardValues`**

Replace the return table in `I.CardValues` (lines 219-235):

```lua
  return {
    movements     = tostring(t.entries or 0),
    itemsIn       = tostring(t.itemsDeposited or 0),
    itemsOut      = tostring(t.itemsWithdrawn or 0),
    netItems      = W.SignedCount(t.netItems or 0),
    distinctItems = tostring(t.distinctItems or 0),
    chars         = tostring(t.distinctChars or 0),
    activeDays    = tostring(t.activeDays or 0),
    topStore      = t.topStore and (C.StoreLabel[t.topStore.store] or t.topStore.store) or EM_DASH,
    itemsMoved    = tostring((t.itemsDeposited or 0) + (t.itemsWithdrawn or 0)),
    goldIn        = W.Money(t.moneyIn or 0),
    goldOut       = W.Money(t.moneyOut or 0),
    netGold       = W.SignedMoney(t.netMoney or 0),
    span          = span,
    busiest       = t.busiestDay
      and (t.busiestDay.day .. "  (" .. t.busiestDay.count .. ")") or EM_DASH,
  }
```

Delete the now-unused `local biggest = t.biggestMove` line above it.

- [ ] **Step 5: Delete the value sections**

In `modules/Insights.lua`:

- `SECTION_TITLES`: delete the `valueStore` and `valueDay` entries.
- `POOL_KEYS`: delete `"valueStore"`, `"valueDay"`, `"itemValue"`.
- `self.strips`: delete the `valueDay = CreateFrame(...)` line.
- `self.panels`: delete the `itemValue = W.MakeListPanel(content, "Top Items By Value"),` line.
- In `I:LayoutSections`, delete the whole **section 4** block (`-- 4 ... Gross value moved per store`, lines ~560-572) including its `y = self:RenderBars("valueStore", ...)`.
- In the per-day block (lines ~664-676), delete `valueDay` from the locals, the `local value = (stats.valueByDay or {})[key] or 0` line, the `valueDay[#valueDay + 1] = ...` line, and the `y = self:RenderStrip("valueDay", ...)` call. Fix the comment: the two strips are now one strip.
- In the ranked-list block, delete `local valueList = itemRows(stats.topItemsByValue, ...)` and rewire the left column so `zone` takes the top slot:

```lua
  local leftTop = y
  local zoneH = self:RenderList("zone", self.panels.zone, zoneList, leftTop, leftX, listColW)
  local leftTotal = zoneH
```

- Delete the `MONEY_COL_W` constant (line 23) — its only consumer was the value list.
- Renumber the `-- N --` section comments in `LayoutSections` so they stay sequential.

- [ ] **Step 6: Run the green gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `0 failed`, luacheck clean (an unused-local warning for `MONEY_COL_W` or `valueDay` means one was missed).

- [ ] **Step 7: Commit**

```bash
git add modules/Insights.lua tests/test_insights.lua
git commit -m "feat(insights): retire the value charts, add top store and items moved

Removes the value moved and biggest move cards, the Value Moved By Store
bars, the Value Moved Over Time strip and the Top Items By Value panel.

Dropping two cards left 14 column-units in a 4-wide grid, so two derived
cards fill it back to four clean rows: top store (from byStore) and
items moved (items in + items out). Both come from figures the single
Stats pass already computes."
```

---

## Task 5: Fix the class-icon truncation bug

**Files:**
- Modify: `modules/InsightsWidgets.lua` (`W.Truncate` doc note only), `modules/Insights.lua:244-275` (`I:RenderBars`), `:583-592` (character rows)
- Test: `tests/test_insights.lua`

**Interfaces:**
- Consumes: Task 4.
- Produces: `I:RenderBars` rows accept two new optional fields — `icon` (a markup string prepended verbatim, never truncated) and `labelMax` (per-row truncation budget, defaults to `W.LABEL_MAXCHARS`). `I.BarLabel(row)` is a new pure helper returning the final label string.

**Diagnosis (for the implementer):** `modules/Insights.lua:587` builds the label as `ClassIconMarkup(classFile) .. ShortChar(char)`, and `RenderBars` passes it through `W.Truncate`, which cuts at 17 **bytes**. `ClassIconMarkup` returns `|TInterface\TargetingFrame\UI-Classes-Circles:12:12:0:0:256:256:...|t ` — far longer than 17 — so the cut lands inside the escape, the `|T` never closes, and WoW prints the texture path as literal text (`ITInterface\Targ...`). The tooltip is right because it reads `fullLabel = ce.char`, which never passes through `Truncate`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_insights.lua`:

```lua
-- ── Icon markup must survive truncation ────────────────────────────────────────
-- Regression: the class icon was concatenated into the label BEFORE W.Truncate cut it at 17
-- bytes, so the cut landed inside the |T...|t escape and WoW rendered the raw texture path.

test("Insights.BarLabel truncates the name and leaves the icon escape intact", function()
  local icon = "|TInterface\\TargetingFrame\\UI-Classes-Circles:12:12:0:0:256:256:0:64:0:64|t "
  local out = I.BarLabel({ icon = icon, label = "Verylongcharactername", labelMax = 14 })
  assertTrue(out:sub(1, #icon) == icon, "the icon escape is emitted whole and unmodified")
  assertTrue(out:find("|t", 1, true) ~= nil, "the escape is still closed")
  assertTrue(#out - #icon <= 14, "only the name is subject to the budget")
end)

test("Insights.BarLabel is a plain truncation when there is no icon", function()
  assertEqual(I.BarLabel({ label = "Bank" }), "Bank")
end)

test("Insights: character bars carry the icon out of band", function()
  local rows = {}
  for _, ce in pairs({ ["Verylongcharactername-Ravencrest"] = {
    char = "Verylongcharactername-Ravencrest", classFile = "MAGE", count = 3 } }) do
    rows[#rows + 1] = ce
  end
  -- The row the layout builds must keep icon and label separate.
  local row = { icon = NS.Util.ClassIconMarkup(rows[1].classFile),
                label = W.ShortChar(rows[1].char), fullLabel = rows[1].char, labelMax = 14 }
  local out = I.BarLabel(row)
  assertEqual(row.label:find("|T", 1, true), nil, "the label field holds no markup")
  assertTrue(#out >= #row.icon, "the rendered label leads with the icon")
end)
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: FAIL with `attempt to call field 'BarLabel' (a nil value)`.

- [ ] **Step 3: Add the pure helper and use it**

In `modules/Insights.lua`, add beside the other pure helpers (after `I.BarFraction`):

```lua
-- A bar's final label string. `icon` is markup (a |T...|t texture escape) and is emitted WHOLE:
-- W.Truncate cuts on BYTES, so a cut that lands inside the escape breaks it and WoW renders the
-- raw texture path as text. Only the name is subject to the budget.
function I.BarLabel(row)
  local name = (W.Truncate(row.label, row.labelMax))
  return (row.icon or "") .. name
end
```

In `I:RenderBars`, replace `bar.label:SetText((W.Truncate(row.label)))` with:

```lua
    bar.label:SetText(I.BarLabel(row))
```

In the character section (currently lines 583-591), split the icon out and shrink the name budget so icon plus name still fit the 118px label column:

```lua
  local barCharRows = {}
  for i, ce in ipairs(charRows) do
    if i > BAR_ROWS then break end
    barCharRows[#barCharRows + 1] = {
      icon = NS.Util.ClassIconMarkup(ce.classFile), label = W.ShortChar(ce.char),
      -- 14, not the default 17: the class icon eats ~14px of the 118px label column.
      labelMax = 14,
      fullLabel = ce.char, color = W.ClassColor(ce.classFile),
      frac = ce.count, value = tostring(ce.count),
    }
  end
```

- [ ] **Step 4: Run the green gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `0 failed`, luacheck clean.

- [ ] **Step 5: Commit**

```bash
git add modules/Insights.lua tests/test_insights.lua
git commit -m "fix(insights): stop truncating the class icon into a raw texture path

The character bars concatenated the |T...|t class-icon escape into the
label before W.Truncate cut it at 17 bytes, so the cut landed inside the
escape, the |T never closed, and WoW rendered the texture path as text.

Rows now carry the icon out of band and only the name is truncated, with
a 14-char budget so icon plus name still fit the 118px label column."
```

---

## Task 6: Ratio-bar labels below the bar; one headline font for every card

**Files:**
- Modify: `modules/InsightsWidgets.lua:337-391` (`MakeCard`/`SetCard`), `:510-549` (ratio bar)
- Modify: `modules/Insights.lua:146-149` (card construction), `:513-535` (the split section)
- Test: `tests/test_insights.lua`

**Interfaces:**
- Consumes: Task 4 (`smallValue` already removed from `CARD_DEFS`).
- Produces: `W.MakeCard(parent)` takes no options table. `W.PlaceRatioBar(bar, host, x, y, barW, left, right)` keeps its signature but renders the two texts in a caption row **below** the bar; `W.RATIO_H` (22) and `W.RATIO_CAPTION_H` (14) are new exported constants the layout advances by.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_insights.lua`:

```lua
test("InsightsWidgets exports the ratio bar's two-part height", function()
  assertEqual(W.RATIO_H, 22)
  assertEqual(W.RATIO_CAPTION_H, 14)
end)

test("InsightsWidgets.MakeCard takes no options and always builds one headline font", function()
  local a = W.MakeCard(T.mocks.CreateFrame())
  local b = W.MakeCard(T.mocks.CreateFrame())
  assertTrue(a.value ~= nil and b.value ~= nil, "both cards have a headline")
  assertEqual(a.baseSize, b.baseSize, "every card shares one base headline size")
end)
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: FAIL — `W.RATIO_H` is nil.

- [ ] **Step 3: One headline font for every card**

In `modules/InsightsWidgets.lua`, `W.MakeCard` drops its options parameter and always uses the large template:

```lua
function W.MakeCard(parent)
  local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  card:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
                     insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  card:SetBackdropColor(0.10, 0.10, 0.12, 0.85)
  card:SetBackdropBorderColor(0.24, 0.24, 0.27, 0.90)

  -- Every card shares ONE base headline font. A long string (a date range, a coin amount) is
  -- handled by the shrink-to-fit pass in SetCard, not by a second smaller template -- two nominal
  -- sizes made the wide cards read as a different kind of card.
  local value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
```

(the rest of the function body is unchanged from `value:SetPoint("TOP", 0, -9)` onward).

In `modules/Insights.lua:147-149`, drop the options argument:

```lua
  for _, def in ipairs(CARD_DEFS) do
    self.cards[def.key] = W.MakeCard(content)
  end
```

- [ ] **Step 4: Move the ratio-bar labels below the bar**

In `modules/InsightsWidgets.lua`, add the two constants beside the other metrics (near `W.BAR_H`):

```lua
W.RATIO_H, W.RATIO_CAPTION_H = 22, 14   -- the split bar, and the caption row beneath it
```

`W.MakeRatioBar` keeps its two mouse-enabled halves but its per-side `FontString`s move out of the halves and onto the bar itself, anchored below:

```lua
function W.MakeRatioBar(parent)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(W.RATIO_H)
  bar.left = CreateFrame("Frame", nil, bar)
  bar.right = CreateFrame("Frame", nil, bar)
  for _, side in ipairs({ bar.left, bar.right }) do
    side:EnableMouse(true)
    local tex = side:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(side)
    side.tex = tex
    side:SetScript("OnEnter", function(self) W.CursorTooltip(self, self._tip) end)
    side:SetScript("OnLeave", hideTooltip)
  end
  -- The captions sit BELOW the bar, pinned to its two ends. Inside the bar they were unreadable at
  -- a lopsided split -- the narrow share had no room for its own text and dropped it entirely.
  local lfs = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  lfs:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
  lfs:SetJustifyH("LEFT")
  lfs:SetWordWrap(false)
  bar.leftText = lfs
  local rfs = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rfs:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
  rfs:SetJustifyH("RIGHT")
  rfs:SetWordWrap(false)
  bar.rightText = rfs
  return bar
end
```

and `W.PlaceRatioBar` loses the `w >= 56` suppression rule, painting both captions unconditionally in their direction colour:

```lua
-- `left`/`right` are { frac, color, text, tip }. The two texts are painted in the caption row under
-- the bar, each in its own direction colour, so both stay readable at any split -- including 97/3,
-- where the old in-bar text vanished. The per-side hover tips are unchanged.
function W.PlaceRatioBar(bar, host, x, y, barW, left, right)
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
  bar:SetWidth(barW)
  local leftW = math.max(0, math.floor(barW * (left.frac or 0)))
  local rightW = math.max(0, barW - leftW)
  local function place(side, w, anchor, spec)
    side:ClearAllPoints()
    side:SetPoint(anchor, bar, anchor, 0, 0)
    side:SetSize(math.max(1, w), W.RATIO_H)
    side.tex:SetColorTexture(spec.color[1], spec.color[2], spec.color[3], 0.9)
    side._tip = spec.tip
    side:SetShown(w > 0)
  end
  place(bar.left, leftW, "LEFT", left)
  place(bar.right, rightW, "RIGHT", right)
  bar.leftText:SetText(left.text or "")
  bar.leftText:SetTextColor(left.color[1], left.color[2], left.color[3])
  bar.rightText:SetText(right.text or "")
  bar.rightText:SetTextColor(right.color[1], right.color[2], right.color[3])
end
```

- [ ] **Step 5: Advance the layout by the new height**

In `modules/Insights.lua`'s split section (currently line 531), the section now consumes the bar **and** its caption row. Replace `y = y - 22 - W.SECTION_GAP` with:

```lua
    y = y - W.RATIO_H - W.RATIO_CAPTION_H - W.SECTION_GAP
```

and change the two `text = ` fields to use the middot separator (`"\194\183"` is `·`):

```lua
      { frac = inFrac, color = directionColor(C.Direction.DEPOSIT),
        text = ("In %d \194\183 %d%%"):format(inCount, W.Percent(inCount, total)),
        tip = ("Deposits: %d of %d movements"):format(inCount, total) },
      { frac = outFrac, color = directionColor(C.Direction.WITHDRAW),
        text = ("Out %d \194\183 %d%%"):format(outCount, W.Percent(outCount, total)),
        tip = ("Withdrawals: %d of %d movements"):format(outCount, total) })
```

- [ ] **Step 6: Run the green gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `0 failed`, luacheck clean.

- [ ] **Step 7: Commit**

```bash
git add modules/Insights.lua modules/InsightsWidgets.lua tests/test_insights.lua
git commit -m "fix(insights): move the split labels below the bar, unify the card font

The Deposits vs Withdrawals captions were centred inside their own share
and dropped entirely when a share fell under 56px, so a lopsided split
lost its numbers. They now sit in a caption row beneath the bar, pinned
to its two ends and coloured by direction, readable at any split.

Cards lose the smallValue option: date range and busiest day were the
only two on a smaller template, which made them read as a different kind
of card. Every headline now shares one base font and relies on the
existing shrink-to-fit for the long strings."
```

---

## Task 7: The four `<Segment> × In/Out` companion charts

**Files:**
- Modify: `core/Database.lua` (`Stats`: three new maps)
- Modify: `modules/Insights.lua` (`SECTION_TITLES`, `POOL_KEYS`, `LayoutSections`)
- Test: `tests/test_stats.lua`, `tests/test_insights.lua`

**Interfaces:**
- Consumes: Task 2.
- Produces: `Database:Stats` gains `qualityByDirection`, `itemTypeByDirection`, `itemSubTypeByDirection` — each a `{ [key] = { DEPOSIT = n, WITHDRAW = n } }` matrix in the same shape as the existing `charByDirection` / `storeByDirection`. Quality keys are **numeric ids**, matching `byQuality`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_stats.lua`:

```lua
-- ── Direction-split companions ─────────────────────────────────────────────────

test("Stats: storeByDirection splits each store's movements in and out", function()
  local m = stats().storeByDirection
  assertEqual(m.BANK.DEPOSIT, 1)
  assertEqual(m.BANK.WITHDRAW, 1)
  assertEqual(m.WARBAND_BANK.DEPOSIT, 1)
end)

test("Stats: qualityByDirection is keyed on the numeric quality id", function()
  local m = stats().qualityByDirection
  assertEqual(m[1].DEPOSIT, 2)    -- both Linen Cloth deposits are quality 1
  assertEqual(m[2].WITHDRAW, 1)   -- the Silk Cloth withdrawal is quality 2
end)

test("Stats: itemTypeByDirection and itemSubTypeByDirection split by direction", function()
  local s = stats()
  assertEqual(s.itemTypeByDirection.Tradegoods.DEPOSIT, 2)
  assertEqual(s.itemTypeByDirection.Tradegoods.WITHDRAW, 1)
  assertEqual(s.itemSubTypeByDirection.Cloth.DEPOSIT, 2)
end)

test("Stats: the direction split always sums back to its parent breakdown", function()
  local s = stats()
  for ty, count in pairs(s.byItemType) do
    local m = s.itemTypeByDirection[ty] or {}
    assertEqual((m.DEPOSIT or 0) + (m.WITHDRAW or 0), count,
      "itemTypeByDirection must reconcile with byItemType for " .. ty)
  end
  for q, count in pairs(s.byQuality) do
    local m = s.qualityByDirection[q] or {}
    assertEqual((m.DEPOSIT or 0) + (m.WITHDRAW or 0), count,
      "qualityByDirection must reconcile with byQuality for quality " .. tostring(q))
  end
end)
```

- [ ] **Step 2: Run the suite to verify they fail**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: FAIL — `qualityByDirection` is nil.

- [ ] **Step 3: Add the three accumulators**

In `core/Database.lua`, add to the declaration block beside `charByDirection, storeByDirection`:

```lua
  local qualityByDirection, itemTypeByDirection, itemSubTypeByDirection = {}, {}, {}
```

Inside the entry loop's **item branch** (the `else` of `if e.kind == "MONEY"`), add a `bump` beside each existing count. The existing lines become:

```lua
      local ty = e.itemType
      if ty and ty ~= "" then
        byItemType[ty] = (byItemType[ty] or 0) + 1
        bump(itemTypeByDirection, ty, dir, 1)
      end
      local sty = e.itemSubType
      if sty and sty ~= "" then
        byItemSubType[sty] = (byItemSubType[sty] or 0) + 1
        bump(itemSubTypeByDirection, sty, dir, 1)
      end
      if type(e.quality) == "number" then
        byQuality[e.quality] = (byQuality[e.quality] or 0) + 1
        bump(qualityByDirection, e.quality, dir, 1)
      end
```

Add all three to the returned table beside `charByDirection = charByDirection, storeByDirection = storeByDirection,`.

- [ ] **Step 4: Render the four companions**

In `modules/Insights.lua`, add to `SECTION_TITLES` (`"\195\151"` is `×`):

```lua
  storeDir   = "Store \195\151 In/Out",
  qualityDir = "Quality \195\151 In/Out",
  itemTypeDir= "Item Type \195\151 In/Out",
  subTypeDir = "Sub-type \195\151 In/Out",
```

and to `POOL_KEYS`: `"storeDir", "qualityDir", "itemTypeDir", "subTypeDir",` plus their legend pools `"storeDirLeg", "qualityDirLeg", "itemTypeDirLeg", "subTypeDirLeg",`.

Add a helper beside the other render helpers in `LayoutSections`' file scope (after `directionLabel`), so the four call sites are one line each:

```lua
-- A "<segment> x In/Out" companion: the same stacked-bar form as Character x In/Out, in the
-- direction colours, with a legend. `labelOf`/`labelColorOf` keep each row recognisable against
-- the parent chart it sits under.
function I:RenderDirectionSplit(poolKey, headerKey, legendKey, matrix, opts, y, w)
  if not next(matrix or {}) then
    self.headers[headerKey]:Hide()
    return y
  end
  y = self:RenderStacked(poolKey, headerKey,
    W.BuildStackRows(matrix, C.DirectionOrder, {
      labelOf = opts.labelOf, colorOf = directionColor, catLabelOf = directionLabel,
      valueFmt = tostring, labelColorOf = opts.labelColorOf,
    }), y, w)
  local legend = {}
  for _, key in ipairs(C.DirectionOrder) do
    legend[#legend + 1] = { label = directionLabel(key), color = directionColor(key) }
  end
  return self:RenderLegend(legendKey, legend, y, w)
end
```

Then insert the four calls, each **immediately after its parent chart**:

After `y = self:RenderBars("store", "store", storeRows, y, w)`:

```lua
  y = self:RenderDirectionSplit("storeDir", "storeDir", "storeDirLeg", stats.storeByDirection,
    { labelOf = storeLabel, labelColorOf = storeColor }, y, w)
```

After `y = self:RenderBars("quality", "quality", qualityRows, y, w)`:

```lua
  y = self:RenderDirectionSplit("qualityDir", "qualityDir", "qualityDirLeg",
    stats.qualityByDirection,
    { labelOf = NS.Compat.QualityLabel, labelColorOf = W.QualityColor }, y, w)
```

The item-type and sub-type companions need the same rank-ordered palette their parent charts use, so capture the colour map. Change the `paletteRows` local function to return both the cursor and its colour map, and call the companion between the two:

```lua
  local function paletteRows(map, poolKey, headerKey, legendKey, yy)
    local ranked = W.SortedByCount(map)
    local keys = {}
    for _, e in ipairs(ranked) do keys[#keys + 1] = e.key end
    local colors = W.PaletteMap(keys)
    local rows = {}
    for i, e in ipairs(ranked) do
      if i > BAR_ROWS then break end
      rows[#rows + 1] = { label = tostring(e.key), color = colors[e.key],
        frac = e.count, value = ("%d  %d%%"):format(e.count, W.Percent(e.count, total)) }
    end
    return self:RenderBars(poolKey, headerKey, rows, yy, w, legendKey), colors
  end

  local typeColors, subColors
  y, typeColors = paletteRows(stats.byItemType, "itemType", "itemType", "itemTypeLeg", y)
  y = self:RenderDirectionSplit("itemTypeDir", "itemTypeDir", "itemTypeDirLeg",
    stats.itemTypeByDirection,
    { labelOf = tostring, labelColorOf = function(k) return typeColors[k] end }, y, w)
  y, subColors = paletteRows(stats.byItemSubType, "subType", "subType", "subTypeLeg", y)
  y = self:RenderDirectionSplit("subTypeDir", "subTypeDir", "subTypeDirLeg",
    stats.itemSubTypeByDirection,
    { labelOf = tostring, labelColorOf = function(k) return subColors[k] end }, y, w)
```

- [ ] **Step 5: Add a render smoke test**

Append to `tests/test_insights.lua`:

```lua
test("Insights: the four direction-split companions render without raising", function()
  unfiltered()
  NS.db.global.ledger = {
    { ts = NOW, char = "Mageling-Realm", classFile = "MAGE", kind = "ITEM", direction = "DEPOSIT",
      store = "BANK", itemID = 2589, itemName = "Linen Cloth", quality = 1,
      itemType = "Tradegoods", itemSubType = "Cloth", quantity = 5, zone = "Valdrakken" },
    { ts = NOW - DAY, char = "Mageling-Realm", classFile = "MAGE", kind = "ITEM",
      direction = "WITHDRAW", store = "GUILD_BANK", itemID = 4306, itemName = "Silk Cloth",
      quality = 2, itemType = "Tradegoods", itemSubType = "Cloth", quantity = 2,
      zone = "Valdrakken" },
  }
  I:Refresh()
  assertTrue(next(I.stats.qualityByDirection) ~= nil, "the quality split had data")
  assertTrue(next(I.stats.storeByDirection) ~= nil, "the store split had data")
  NS.db.global.ledger = {}
end)
```

- [ ] **Step 6: Run the green gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `0 failed`, luacheck clean.

- [ ] **Step 7: Commit**

```bash
git add core/Database.lua modules/Insights.lua tests/
git commit -m "feat(insights): add Store/Quality/Type/Sub-type x In/Out companions

Four stacked-bar companions, each sitting immediately under its parent
chart in the direction colours. Store x In/Out finally consumes
storeByDirection, which Stats has computed and nothing has read; the
other three matrices are new accumulators in the same single pass, so
the panel got richer without the aggregation getting slower.

Each row keeps its parent chart's colour -- store colour, quality
colour, palette colour by rank -- so a category stays recognisable
across the pair."
```

---

## Task 8: Reorganize Top Of The List into a pooled 3-column All/In/Out grid

**Files:**
- Modify: `core/Database.lua` (`Stats`: direction-split rankings, `byTypeSub`, `itemsByStore`)
- Modify: `modules/InsightsWidgets.lua` (list-panel pooling)
- Modify: `modules/Insights.lua` (`RenderList`, the whole ranked-list block)
- Test: `tests/test_stats.lua`, `tests/test_insights.lua`

**Interfaces:**
- Consumes: Tasks 2, 4.
- Produces:
  - `Stats.byItem[id]` records gain `movesIn`, `movesOut`, `qtyIn`, `qtyOut` (numbers, default 0).
  - New ranked arrays, all of the **same record tables** (never copies): `topItemsIn`, `topItemsOut` (by `movesIn`/`movesOut`), `topItemsByQuantityIn`, `topItemsByQuantityOut` (by `qtyIn`/`qtyOut`).
  - `topZones` records gain `inCount`, `outCount`; new `topZonesIn`, `topZonesOut`. `stats.byZone` **keeps its plain `{ [zone] = count }` map shape** — `modules/Export.lua` feeds it to `rankedRows`.
  - New `topTypeSub`, `topTypeSubIn`, `topTypeSubOut`: arrays of `{ type, subType, label, count, inCount, outCount }` where `label` is `"<Type> \194\183 <SubType>"`.
  - New `topItemsByStore`: `{ [storeKey] = { { itemID, itemName, quality, moves }, ... } }`, ranked moves-desc then itemID-asc.
  - `W.MakeListPanel(parent, title)` — `title` is now optional. New `W.SetPanelTitle(panel, text)`, `W.ReleasePanels(pool)`. A pooled panel carries its own row pool at `panel._rows`.
  - `I:RenderList(title, rows, y, x, colW, rightW)` — **signature changed**: takes a title string and acquires its own panel, instead of taking a pool key and a pre-made panel.

- [ ] **Step 1: Write the failing Stats tests**

Append to `tests/test_stats.lua`:

```lua
-- ── Direction-split rankings for the Top Of The List section ────────────────────

test("Stats: item records split their moves and quantities by direction", function()
  local byItem = stats().byItem
  local linen = byItem[2589]      -- 2 deposits (10 + 2), no withdrawals
  assertEqual(linen.movesIn, 2)
  assertEqual(linen.movesOut, 0)
  assertEqual(linen.qtyIn, 12)
  assertEqual(linen.qtyOut, 0)
  local silk = byItem[4306]       -- 1 withdrawal of 3
  assertEqual(silk.movesOut, 1)
  assertEqual(silk.qtyOut, 3)
end)

test("Stats: the In and Out item rankings sum back to the combined ranking", function()
  local s = stats()
  for _, rec in ipairs(s.topItems) do
    assertEqual(rec.movesIn + rec.movesOut, rec.moves,
      "moves must reconcile for item " .. tostring(rec.itemID))
    assertEqual(rec.qtyIn + rec.qtyOut, rec.quantity,
      "quantity must reconcile for item " .. tostring(rec.itemID))
  end
  assertEqual(s.topItemsIn[1].itemID, 2589, "Linen Cloth leads the deposits")
  assertEqual(s.topItemsOut[1].itemID, 4306, "Silk Cloth leads the withdrawals")
end)

test("Stats: byZone keeps its plain count-map shape for the CSV", function()
  assertEqual(stats().byZone.Valdrakken, 4)
end)

test("Stats: topZones records carry the in/out split", function()
  local z = stats().topZones[1]
  assertEqual(z.zone, "Valdrakken")
  assertEqual(z.count, 4)
  assertEqual(z.inCount + z.outCount, z.count)
end)

test("Stats: topTypeSub ranks type and sub-type pairs with a display label", function()
  local t = stats().topTypeSub[1]
  assertEqual(t.type, "Tradegoods")
  assertEqual(t.subType, "Cloth")
  assertEqual(t.label, "Tradegoods \194\183 Cloth")
  assertEqual(t.count, 3)
  assertEqual(t.inCount, 2)
  assertEqual(t.outCount, 1)
end)

test("Stats: topItemsByStore ranks each store's items independently", function()
  local byStore = stats().topItemsByStore
  assertEqual(byStore.BANK[1].itemID, 2589, "Linen Cloth and Silk Cloth tie at 1; id breaks it")
  assertEqual(byStore.WARBAND_BANK[1].itemID, 2589)
  assertEqual(byStore.GUILD_BANK, nil, "a coin-only store has no item list")
end)
```

- [ ] **Step 2: Run the suite to verify they fail**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: FAIL — `movesIn` is nil.

- [ ] **Step 3: Extend `Stats`**

In `core/Database.lua`, add to the declaration block:

```lua
  local byTypeSub, itemsByStore = {}, {}
```

Also declare `local zoneByDirection = {}` in the same block.

Inside the entry loop, the existing `byZone` line **keeps its plain count-map form** (`modules/Export.lua:153` feeds `stats.byZone` straight to `rankedRows`, so reshaping it would break the stats CSV). Add the direction split beside it — the one existing line becomes two:

```lua
    if e.zone and e.zone ~= "" then
      byZone[e.zone] = (byZone[e.zone] or 0) + 1
      bump(zoneByDirection, e.zone, dir, 1)
    end
```

Inside the **item branch**, extend the `byItem` record and add the two new matrices. The existing `byItem` block becomes:

```lua
      local id = e.itemID
      if id ~= nil then
        local isIn = (dir == "DEPOSIT")
        local rec = byItem[id]
        if rec then
          rec.moves = rec.moves + 1
          rec.quantity = rec.quantity + qty
        else
          rec = { itemID = id, itemName = e.itemName, quality = e.quality,
                  moves = 1, quantity = qty,
                  movesIn = 0, movesOut = 0, qtyIn = 0, qtyOut = 0 }
          byItem[id] = rec
          distinctItems = distinctItems + 1
        end
        if isIn then
          rec.movesIn = rec.movesIn + 1
          rec.qtyIn = rec.qtyIn + qty
        else
          rec.movesOut = rec.movesOut + 1
          rec.qtyOut = rec.qtyOut + qty
        end
        -- Per-store item index, for the "Top Items - <Store>" panels.
        local m = itemsByStore[store]
        if not m then m = {}; itemsByStore[store] = m end
        m[id] = (m[id] or 0) + 1
      end
```

and, still in the item branch, after the sub-type bump, add the type/sub-type pair index:

```lua
      -- Type + sub-type as one pivot. Keyed on a tab-joined pair so "Armor/Cloth" and
      -- "Tradegoods/Cloth" can never collide; `label` is the display form.
      if ty and ty ~= "" and sty and sty ~= "" then
        local key = ty .. "\t" .. sty
        local rec = byTypeSub[key]
        if not rec then
          rec = { type = ty, subType = sty, label = ty .. " \194\183 " .. sty,
                  count = 0, inCount = 0, outCount = 0 }
          byTypeSub[key] = rec
        end
        rec.count = rec.count + 1
        if dir == "DEPOSIT" then rec.inCount = rec.inCount + 1
        else rec.outCount = rec.outCount + 1 end
      end
```

- [ ] **Step 4: Build the new rankings**

Replace the three-way ranking block in `core/Database.lua` with the five-way form (still one array per ranking, all holding the **same** record tables):

```lua
  -- Top items, ranked five ways off the one byItem index. Each list is a fresh array of the SAME
  -- record tables (never a copy), so five rankings cost five sorts and no extra memory. Every
  -- comparator ends on the item id, so a tie can never reorder run to run.
  local topItems, topItemsByQuantity = {}, {}
  local topItemsIn, topItemsOut = {}, {}
  local topItemsByQuantityIn, topItemsByQuantityOut = {}, {}
  for _, rec in pairs(byItem) do
    topItems[#topItems + 1] = rec
    topItemsByQuantity[#topItemsByQuantity + 1] = rec
    if rec.movesIn > 0 then
      topItemsIn[#topItemsIn + 1] = rec
      topItemsByQuantityIn[#topItemsByQuantityIn + 1] = rec
    end
    if rec.movesOut > 0 then
      topItemsOut[#topItemsOut + 1] = rec
      topItemsByQuantityOut[#topItemsByQuantityOut + 1] = rec
    end
  end
  -- One comparator factory: rank on `field` desc, tiebreak on the item id asc.
  local function byField(field)
    return function(a, b)
      if a[field] ~= b[field] then return a[field] > b[field] end
      return (a.itemID or 0) < (b.itemID or 0)
    end
  end
  table.sort(topItems, function(a, b)
    if a.moves ~= b.moves then return a.moves > b.moves end
    if a.quantity ~= b.quantity then return a.quantity > b.quantity end
    return (a.itemID or 0) < (b.itemID or 0)
  end)
  table.sort(topItemsByQuantity, byField("quantity"))
  table.sort(topItemsIn, byField("movesIn"))
  table.sort(topItemsOut, byField("movesOut"))
  table.sort(topItemsByQuantityIn, byField("qtyIn"))
  table.sort(topItemsByQuantityOut, byField("qtyOut"))
```

Replace the `topZones` block:

```lua
  -- Where the banking actually happens, ranked three ways. Ties break on the zone name.
  local topZones, topZonesIn, topZonesOut = {}, {}, {}
  for zone, count in pairs(byZone) do
    local m = zoneByDirection[zone] or {}
    local rec = { zone = zone, count = count,
                  inCount = m.DEPOSIT or 0, outCount = m.WITHDRAW or 0 }
    topZones[#topZones + 1] = rec
    if rec.inCount > 0 then topZonesIn[#topZonesIn + 1] = rec end
    if rec.outCount > 0 then topZonesOut[#topZonesOut + 1] = rec end
  end
  local function byZoneField(field)
    return function(a, b)
      if a[field] ~= b[field] then return a[field] > b[field] end
      return a.zone < b.zone
    end
  end
  table.sort(topZones, byZoneField("count"))
  table.sort(topZonesIn, byZoneField("inCount"))
  table.sort(topZonesOut, byZoneField("outCount"))
```

Add the type/sub-type and per-store rankings after it:

```lua
  -- Type + sub-type pairs, ranked three ways. Ties break on the display label.
  local topTypeSub, topTypeSubIn, topTypeSubOut = {}, {}, {}
  for _, rec in pairs(byTypeSub) do
    topTypeSub[#topTypeSub + 1] = rec
    if rec.inCount > 0 then topTypeSubIn[#topTypeSubIn + 1] = rec end
    if rec.outCount > 0 then topTypeSubOut[#topTypeSubOut + 1] = rec end
  end
  local function byTSField(field)
    return function(a, b)
      if a[field] ~= b[field] then return a[field] > b[field] end
      return a.label < b.label
    end
  end
  table.sort(topTypeSub, byTSField("count"))
  table.sort(topTypeSubIn, byTSField("inCount"))
  table.sort(topTypeSubOut, byTSField("outCount"))

  -- One ranked item list per store, off the per-store index. Names and qualities come from the
  -- shared byItem records, so a store list can never disagree with the global one about an item.
  local topItemsByStore = {}
  for store, ids in pairs(itemsByStore) do
    local list = {}
    for id, moves in pairs(ids) do
      local rec = byItem[id]
      list[#list + 1] = { itemID = id, itemName = rec and rec.itemName,
                          quality = rec and rec.quality, moves = moves }
    end
    table.sort(list, function(a, b)
      if a.moves ~= b.moves then return a.moves > b.moves end
      return (a.itemID or 0) < (b.itemID or 0)
    end)
    topItemsByStore[store] = list
  end
```

Add every new key to the returned table: `topItemsIn`, `topItemsOut`, `topItemsByQuantityIn`, `topItemsByQuantityOut`, `topZonesIn`, `topZonesOut`, `topTypeSub`, `topTypeSubIn`, `topTypeSubOut`, `topItemsByStore`.

- [ ] **Step 5: Run the Stats tests**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: the Task 8 Step 1 tests now PASS. `test_insights` may still pass (the panel has not changed yet).

- [ ] **Step 6: Write the failing panel-pool test**

Append to `tests/test_insights.lua`:

```lua
test("InsightsWidgets pools list panels, each carrying its own row pool", function()
  local parent = T.mocks.CreateFrame()
  local pool = W.NewPool()
  local a = W.Acquire(pool, function() return W.MakeListPanel(parent) end)
  W.SetPanelTitle(a, "Top Items")
  assertTrue(a._rows ~= nil, "a pooled panel owns its row pool")
  W.ReleasePanels(pool)
  assertEqual(#pool.active, 0, "releasing empties the active list")
  local b = W.Acquire(pool, function() return W.MakeListPanel(parent) end)
  assertTrue(a == b, "the released panel is reused, never re-allocated")
end)
```

- [ ] **Step 7: Run to verify it fails**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: FAIL with `attempt to call field 'SetPanelTitle' (a nil value)`.

- [ ] **Step 8: Add panel pooling**

In `modules/InsightsWidgets.lua`, `W.MakeListPanel` takes an optional title and gains a row pool:

```lua
-- A bordered ranked-list panel. Pooled, so the title is set per pass rather than baked in, and
-- each panel carries its OWN row pool: rows are parented to a specific panel at creation and can
-- never be shared across panels.
function W.MakeListPanel(parent, title)
  local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  p:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
                  insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  p:SetBackdropColor(0.08, 0.08, 0.10, 0.60)
  p:SetBackdropBorderColor(0.24, 0.24, 0.27, 0.70)
  local t = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t:SetPoint("TOPLEFT", 6, -5)
  t:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
  t:SetText(title or "")
  p.title = t
  p._rows = W.NewPool()
  return p
end

function W.SetPanelTitle(panel, text)
  panel.title:SetText(text or "")
end

-- Release a panel pool AND every panel's rows, so a shrinking pass leaves no orphan row visible.
function W.ReleasePanels(pool)
  for _, p in ipairs(pool.active) do W.ReleaseAll(p._rows) end
  W.ReleaseAll(pool)
end
```

- [ ] **Step 9: Rewrite `I:RenderList` and the ranked-list block**

In `modules/Insights.lua`:

`POOL_KEYS` loses `"itemMoves"`, `"itemQty"`, `"zone"` (Task 4 already removed `"itemValue"`) and gains `"listHead"`. Delete the whole `self.panels = { ... }` block from `I:Attach` and add:

```lua
  -- Ranked-list panels are POOLED, not fixed: the per-store lists vary in count and every panel
  -- takes its title per pass.
  self.panelPool = W.NewPool()
```

`I:HideAllSections` loses its `for _, p in pairs(self.panels)` loop.

`I:Layout`'s release loop gains the panel pool — after the `for _, key in ipairs(POOL_KEYS)` loop add:

```lua
  W.ReleasePanels(self.panelPool)
```

`I:RenderList` becomes:

```lua
-- A ranked list panel, acquired from the pool and titled per pass. `rows` is
-- { name, fullName, nameColor, right }. Returns the panel's height (0 when there is nothing to
-- show, so the caller can collapse the slot) so columns of differing lengths can be stacked.
function I:RenderList(title, rows, y, x, colW, rightW)
  local n = math.min(LIST_ROWS, #rows)
  if n == 0 then return 0 end
  local panel = W.Acquire(self.panelPool, function() return W.MakeListPanel(self.content) end)
  W.SetPanelTitle(panel, title)
  local panelH = 20 + n * W.LIST_ROW_H + 4
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
  panel:SetSize(colW, panelH)
  for i = 1, n do
    local row = rows[i]
    local r = W.Acquire(panel._rows, function() return W.MakeListRow(panel) end)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -20 - (i - 1) * W.LIST_ROW_H)
    r:SetWidth(colW - 8)
    r.name:SetWidth(math.max(1, colW - 8 - (rightW or 48) - 6))
    r.name:SetText(row.name)
    r._tip = row.fullName or row.name
    local nc = row.nameColor or W.MUTED
    r.name:SetTextColor(nc[1], nc[2], nc[3])
    r.right:SetWidth(rightW or 48)
    r.right:SetText(row.right or "")
    r.right:SetTextColor(W.MUTED[1], W.MUTED[2], W.MUTED[3])
  end
  return panelH
end
```

Add two layout helpers beside it:

```lua
-- A pooled sub-heading inside the Top Of The List section, so the groups can be named without a
-- fixed header per group.
function I:RenderSubHead(text, y, indent)
  local fs = W.Acquire(self.pools.listHead,
    function() return W.MakeSectionHeader(self.content, "") end)
  fs:SetText(text)
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD + (indent or 0), y)
  return y - 18
end

-- One row of up to LIST_COLS panels. `specs` is { title, rows, rightW }; an empty list simply
-- leaves its column blank. The row advances by its TALLEST panel so nothing overlaps.
function I:RenderListRow(specs, y, innerW)
  local gap = 12
  local colW = math.floor((innerW - gap * (LIST_COLS - 1)) / LIST_COLS)
  local tallest, col = 0, 0
  for _, spec in ipairs(specs) do
    if col >= LIST_COLS then
      y = y - tallest - W.SECTION_GAP
      tallest, col = 0, 0
    end
    local h = self:RenderList(spec.title, spec.rows, y, PAD + col * (colW + gap), colW, spec.rightW)
    if h > tallest then tallest = h end
    col = col + 1
  end
  if tallest == 0 then return y end
  return y - tallest - W.SECTION_GAP
end
```

Add the constant beside `LIST_ROWS`:

```lua
local LIST_COLS = 3          -- All / Deposits / Withdrawals, side by side
```

Replace the entire ranked-list block at the end of `I:LayoutSections` (from `y = placeDivider(self.dividers.top, content, y)` to the `return`) with:

```lua
  -- ── Ranked lists: grouped, three columns of All / Deposits / Withdrawals ───────
  -- The triptych IS the organization: a metric's combined ranking and its two direction-split
  -- rankings sit side by side, so "what moves most" and "what moves most INTO the bank" are one
  -- glance apart rather than one scroll apart.
  y = placeDivider(self.dividers.top, content, y)

  local function itemRows(list, rightOf)
    local rows = {}
    for i = 1, math.min(LIST_ROWS, #(list or {})) do
      local it = list[i]
      local right = rightOf(it)
      if right then
        rows[#rows + 1] = {
          name = it.itemName or ("Item " .. tostring(it.itemID)),
          nameColor = W.QualityColor(it.quality or 1), right = right,
        }
      end
    end
    return rows
  end
  local function countRows(list, field)
    local rows = {}
    for i = 1, math.min(LIST_ROWS, #(list or {})) do
      local r = list[i]
      rows[#rows + 1] = { name = r.label or r.zone, right = tostring(r[field]) }
    end
    return rows
  end
  local moves = function(field) return function(it) return tostring(it[field]) end end

  y = self:RenderSubHead("ITEMS", y)
  y = self:RenderSubHead("Top Items By Movements", y, 10)
  y = self:RenderListRow({
    { title = "All",         rows = itemRows(stats.topItems, moves("moves")) },
    { title = "Deposits",    rows = itemRows(stats.topItemsIn, moves("movesIn")) },
    { title = "Withdrawals", rows = itemRows(stats.topItemsOut, moves("movesOut")) },
  }, y, innerW)
  y = self:RenderSubHead("Top Items By Quantity", y, 10)
  y = self:RenderListRow({
    { title = "All",         rows = itemRows(stats.topItemsByQuantity, moves("quantity")) },
    { title = "Deposits",    rows = itemRows(stats.topItemsByQuantityIn, moves("qtyIn")) },
    { title = "Withdrawals", rows = itemRows(stats.topItemsByQuantityOut, moves("qtyOut")) },
  }, y, innerW)

  y = self:RenderSubHead("CATEGORIES", y)
  y = self:RenderSubHead("Top Type \194\183 Sub-type", y, 10)
  y = self:RenderListRow({
    { title = "All",         rows = countRows(stats.topTypeSub, "count") },
    { title = "Deposits",    rows = countRows(stats.topTypeSubIn, "inCount") },
    { title = "Withdrawals", rows = countRows(stats.topTypeSubOut, "outCount") },
  }, y, innerW)

  y = self:RenderSubHead("WHERE", y)
  y = self:RenderSubHead("Top Banking Spots", y, 10)
  y = self:RenderListRow({
    { title = "All",         rows = countRows(stats.topZones, "count") },
    { title = "Deposits",    rows = countRows(stats.topZonesIn, "inCount") },
    { title = "Withdrawals", rows = countRows(stats.topZonesOut, "outCount") },
  }, y, innerW)

  -- Per-store item lists, in the store display order so the columns keep their places between
  -- refreshes. A coin-only store contributes no list and simply does not appear.
  local storeSpecs = {}
  for _, key in ipairs(C.StoreOrder) do
    local list = (stats.topItemsByStore or {})[key]
    if list and #list > 0 then
      storeSpecs[#storeSpecs + 1] =
        { title = storeLabel(key), rows = itemRows(list, moves("moves")) }
    end
  end
  if #storeSpecs > 0 then
    y = self:RenderSubHead("BY STORE", y)
    y = self:RenderListRow(storeSpecs, y, innerW)
  end

  return y - W.SECTION_GAP
```

Delete the now-dead `zoneList` / `movesList` / `qtyList` locals and the old two-column `leftTop`/`rightTop` arithmetic.

- [ ] **Step 10: Add a render smoke test**

Append to `tests/test_insights.lua`:

```lua
test("Insights: the reorganized list section renders every group", function()
  unfiltered()
  local stores = { "BANK", "WARBAND_BANK", "GUILD_BANK" }
  local ledger = {}
  for i = 1, 18 do
    ledger[#ledger + 1] = {
      ts = NOW - (i % 5) * DAY, char = "Mageling-Realm", classFile = "MAGE",
      kind = "ITEM", direction = (i % 3 == 0) and "WITHDRAW" or "DEPOSIT",
      store = stores[(i % #stores) + 1],
      itemID = 2589 + (i % 4), itemName = "Item " .. (i % 4), quality = i % 5,
      itemType = "Tradegoods", itemSubType = "Cloth", quantity = i,
      zone = (i % 2 == 0) and "Valdrakken" or "Dornogal",
    }
  end
  NS.db.global.ledger = ledger
  I:Refresh()
  assertTrue(#I.stats.topItemsIn > 0, "the deposits ranking has rows")
  assertTrue(#I.stats.topItemsOut > 0, "the withdrawals ranking has rows")
  assertTrue(#I.stats.topTypeSub > 0, "the type/sub-type ranking has rows")
  assertTrue(#I.panelPool.active > 0, "panels were acquired from the pool")
  -- A second pass must reuse, never re-allocate.
  local first = #I.panelPool.active + #I.panelPool.free
  I:Refresh()
  assertEqual(#I.panelPool.active + #I.panelPool.free, first, "panels are pooled, not leaked")
  NS.db.global.ledger = {}
end)
```

- [ ] **Step 11: Run the green gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `0 failed`, luacheck clean.

- [ ] **Step 12: Commit**

```bash
git add core/Database.lua modules/Insights.lua modules/InsightsWidgets.lua tests/
git commit -m "feat(insights): reorganize Top Of The List into an All/In/Out grid

Three columns instead of two, grouped under ITEMS / CATEGORIES / WHERE /
BY STORE sub-headings. Each metric becomes one row of three panels, so
the All / Deposits / Withdrawals triptych is itself the organization.

Adds the rankings behind it, all inside the existing single Stats pass:
item records gain movesIn/movesOut/qtyIn/qtyOut so six item rankings are
six sorts over the SAME record tables; topZones records gain the
direction split; byTypeSub pivots type and sub-type as one pair; and
itemsByStore drives a ranked list per store.

byZone deliberately keeps its plain count-map shape -- Export feeds it
straight to rankedRows, and reshaping it would break the stats CSV.

Panels are now pooled with per-pass titles, each carrying its own row
pool, because the per-store lists vary in count."
```

---

## Task 9: Rename preview mode to test mode and enrich the dataset

**Files:**
- Modify: `modules/LedgerTable.lua:115`, `:283-286`, `:312-416`
- Modify: `modules/Browser.lua:680`, `:709-722`, `:913-918`
- Modify: `settings/Schema.lua:221-224`
- Modify: `core/State.lua:27-29` (comment only), `core/Database.lua:54-57` (comment only)
- Test: `tests/test_ledgertable.lua`, `tests/test_browser.lua`, `tests/test_slash.lua`

**Interfaces:**
- Consumes: Task 1 (no `vendorPrice`).
- Produces: `NS.LedgerTable.testMode` (boolean), `LT:ToggleTestMode()`, `LT:BuildTestData()`. `NS.LedgerTable.previewMode` / `TogglePreview` / `BuildPreviewData` **no longer exist**. `frame.testBadge` replaces `frame.previewBadge`. Slash command is `/bl test`.

⚠️ **Deliberately out of scope:** `SessionWindow.previewSession` and `SW:TogglePreview` (`/bl session`) keep their names — a separate feature with no LootHistory counterpart.

- [ ] **Step 1: Write the failing tests**

In `tests/test_ledgertable.lua`, rename every existing `previewMode` / `TogglePreview` reference to the new names, then append:

```lua
-- ── Test-mode dataset coverage ─────────────────────────────────────────────────
-- The generator is deterministic (fixed-seed Park-Miller LCG, never math.random), so these
-- assertions are stable. The coverage seed pass is what guarantees them regardless of the dice.

local function testData() return NS.LedgerTable:BuildTestData() end

test("BuildTestData is byte-identical across two builds", function()
  local a, b = testData(), testData()
  assertEqual(#a, #b)
  for i = 1, #a do
    assertEqual(a[i].itemID, b[i].itemID, "entry " .. i .. " itemID")
    assertEqual(a[i].store, b[i].store, "entry " .. i .. " store")
    assertEqual(a[i].quantity, b[i].quantity, "entry " .. i .. " quantity")
  end
end)

test("BuildTestData covers every store and both directions", function()
  local stores, dirs = {}, {}
  for _, e in ipairs(testData()) do
    stores[e.store] = true
    dirs[e.direction] = true
  end
  for _, s in ipairs({ "BANK", "REAGENT_BANK", "WARBAND_BANK", "GUILD_BANK" }) do
    assertTrue(stores[s], "store " .. s .. " must appear")
  end
  assertTrue(dirs.DEPOSIT and dirs.WITHDRAW, "both directions must appear")
end)

test("BuildTestData covers every item quality 0-5", function()
  local seen = {}
  for _, e in ipairs(testData()) do
    if e.kind == "ITEM" then seen[e.quality] = true end
  end
  for q = 0, 5 do assertTrue(seen[q], "quality " .. q .. " must appear") end
end)

test("BuildTestData spans more than 14 days", function()
  local first, last
  for _, e in ipairs(testData()) do
    if not first or e.ts < first then first = e.ts end
    if not last or e.ts > last then last = e.ts end
  end
  assertTrue((last - first) > 14 * 86400, "the span must exceed a fortnight")
end)

test("BuildTestData spreads across many characters and zones", function()
  local chars, zones = {}, {}
  local nc, nz = 0, 0
  for _, e in ipairs(testData()) do
    if e.char and not chars[e.char] then chars[e.char] = true; nc = nc + 1 end
    if e.zone and not zones[e.zone] then zones[e.zone] = true; nz = nz + 1 end
  end
  assertTrue(nc >= 8, "at least 8 characters, got " .. nc)
  assertTrue(nz >= 6, "at least 6 zones, got " .. nz)
end)

test("BuildTestData never carries vendor value", function()
  for _, e in ipairs(testData()) do
    assertEqual(e.vendorPrice, nil)
  end
end)

test("LedgerTable:ToggleTestMode publishes and clears the dataset", function()
  assertTrue(NS.LedgerTable:ToggleTestMode(), "first toggle turns it on")
  assertTrue(NS.State.testRecords ~= nil, "the dataset is published to State")
  assertFalse(NS.LedgerTable:ToggleTestMode(), "second toggle turns it off")
  assertEqual(NS.State.testRecords, nil)
end)
```

Add `assertFalse` to the suite's header destructuring if it is not already there:
```lua
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse
```

- [ ] **Step 2: Run the suite to verify they fail**

Run: `lua tests/run.lua 2>&1 | grep -A2 FAIL`
Expected: FAIL with `attempt to call method 'BuildTestData' (a nil value)`.

- [ ] **Step 3: Replace the generator**

In `modules/LedgerTable.lua`, replace the whole `-- ── Preview dataset ──` block (the `PREVIEW_*` tables, `previewRng`, `BuildPreviewData`, `TogglePreview`) with:

```lua
-- ── Test dataset (test-mode) ────────────────────────────────────────────────────
-- A synthetic ledger so the window and the Insights charts can be seen (and positioned) without
-- waiting to actually fill a bank. A deliberately NON-uniform spread so the charts read like real
-- play: weighted stores/directions/classes/zones/types/qualities/timestamps, a handful of "hot"
-- items over a long tail, and an evening-leaning hour curve. A deterministic PRNG (fixed seed,
-- NOT math.random) keeps the data byte-identical every run so the headless tests stay stable. A
-- coverage seed pass first guarantees every store, both directions, every quality and every
-- character appear and that the range spans >14 days regardless of how the dice fall.

local TEST_CLASSES = {
  "MAGE", "PALADIN", "ROGUE", "PRIEST", "DRUID", "WARRIOR", "SHAMAN", "EVOKER",
}
-- A few "mains" do most of the banking.
local TEST_CLASS_W = {
  { "MAGE", 16 }, { "PALADIN", 13 }, { "ROGUE", 11 }, { "PRIEST", 9 },
  { "DRUID", 8 }, { "WARRIOR", 8 }, { "SHAMAN", 6 }, { "EVOKER", 5 },
}
local TEST_ZONES = {
  { name = "Valdrakken",       mapID = 2112 },
  { name = "Dornogal",         mapID = 2339 },
  { name = "Orgrimmar",        mapID = 85 },
  { name = "Stormwind City",   mapID = 84 },
  { name = "Silvermoon City",  mapID = 110 },
  { name = "Boralus",          mapID = 1161 },
}
local TEST_ZONE_W = { { 1, 26 }, { 2, 20 }, { 4, 16 }, { 3, 14 }, { 5, 12 }, { 6, 8 } }
-- The character bank takes the bulk; the reagent bank is a trickle.
local TEST_STORE_W = {
  { "BANK", 34 }, { "WARBAND_BANK", 26 }, { "GUILD_BANK", 22 }, { "REAGENT_BANK", 8 },
}
local TEST_TYPE_W = {
  { "Tradegoods", 30 }, { "Consumable", 22 }, { "Armor", 16 }, { "Weapon", 12 },
  { "Recipe", 8 }, { "Gem", 7 }, { "Miscellaneous", 5 },
}
local TEST_SUBTYPES = {
  Tradegoods    = { "Cloth", "Herb", "Metal & Stone", "Leather", "Elemental" },
  Consumable    = { "Potion", "Flask", "Food & Drink", "Bandage" },
  Armor         = { "Cloth", "Leather", "Mail", "Plate" },
  Weapon        = { "Swords", "Daggers", "Staves", "Bows" },
  Recipe        = { "Tailoring", "Alchemy", "Blacksmithing" },
  Gem           = { "Cut Gem", "Uncut Gem" },
  Miscellaneous = { "Junk", "Other" },
}
local TEST_QUALITY_W = { { 0, 7 }, { 1, 16 }, { 2, 28 }, { 3, 22 }, { 4, 11 }, { 5, 3 } }
local TEST_HOUR_W = {}   -- evening-leaning hour-of-day curve
do
  local w = { [0] = 2, [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 1, [6] = 2, [7] = 3,
              [8] = 4, [9] = 5, [10] = 6, [11] = 6, [12] = 7, [13] = 6, [14] = 5, [15] = 5,
              [16] = 6, [17] = 8, [18] = 11, [19] = 13, [20] = 14, [21] = 12, [22] = 9, [23] = 5 }
  for h = 0, 23 do TEST_HOUR_W[#TEST_HOUR_W + 1] = { h, w[h] } end
end
-- The first 8 are "hot" (recur often), the rest a long tail, so the ranked lists have real shape.
local TEST_ITEM_NAMES = {
  "Linen Cloth", "Serevite Ore", "Dragon Isles Herb", "Spectral Flask",
  "Refreshing Healing Potion", "Silk Cloth", "Awakened Fire", "Primal Chaos",
  "Thunderfury", "Hearthstone", "Writhebark", "Hochenblume",
  "Rousing Frost", "Mireslush Hide", "Resilient Leather", "Khaz'gorite Ore",
  "Vibrant Shard", "Illimited Diamond", "Alexstraszite", "Neltharite",
  "Convincingly Realistic Jumper Cables", "Zaralek Glowspore", "Bismuth", "Ironclaw Ore",
  "Weavercloth", "Gloom Chitin", "Storm Dust", "Null Stone",
  "Arathor's Spear", "Everburning Ember",
}
local TEST_DAY = 86400
local TEST_SPAN_DAYS = 21
local TEST_HOT_ITEMS = 8

-- Minimal-standard (Park-Miller) LCG: products stay below 2^46, so the double arithmetic is exact
-- and the sequence is identical on every platform. rng(n) returns an integer in [1, n].
local function testRng(seed)
  local state = seed % 2147483647
  if state <= 0 then state = state + 2147483646 end
  return function(n)
    state = (state * 16807) % 2147483647
    return (state % n) + 1
  end
end

-- Weighted pick from a { {value, weight}, ... } table.
local function testPick(rng, weighted)
  local total = 0
  for _, e in ipairs(weighted) do total = total + e[2] end
  local roll, acc = rng(total), 0
  for _, e in ipairs(weighted) do
    acc = acc + e[2]
    if roll <= acc then return e[1] end
  end
  return weighted[#weighted][1]
end

function LT:BuildTestData()
  local now = time()
  local rng = testRng(0x0BA17ED9)   -- fixed seed -> an identical dataset every run
  local out = {}

  -- Build one entry from the pivot values; everything else is derived and jittered.
  local function make(store, dir, quality, cls, dayOffset)
    local zone = TEST_ZONES[testPick(rng, TEST_ZONE_W)]
    local ty = testPick(rng, TEST_TYPE_W)
    local isGear = (ty == "Armor" or ty == "Weapon")
    -- ~45% of movements land on a hot item, the rest on the long tail.
    local idBase = (rng(100) <= 45) and rng(TEST_HOT_ITEMS)
                   or (TEST_HOT_ITEMS + rng(#TEST_ITEM_NAMES - TEST_HOT_ITEMS))
    local subs = TEST_SUBTYPES[ty]
    local secInto = testPick(rng, TEST_HOUR_W) * 3600 + (rng(60) - 1) * 60 + (rng(60) - 1)
    out[#out + 1] = {
      ts = now - dayOffset * TEST_DAY - secInto,
      char = cls:sub(1, 1) .. cls:sub(2):lower() .. "-Ravencrest", classFile = cls,
      kind = C.Kind.ITEM, direction = dir, store = store,
      guild = (store == "GUILD_BANK") and "Ka0s" or nil,
      itemID = 190000 + idBase, itemName = TEST_ITEM_NAMES[idBase], quality = quality,
      itemType = ty, itemSubType = subs[(idBase % #subs) + 1],
      quantity = isGear and 1 or ((quality <= 1) and (1 + rng(60)) or (1 + rng(8))),
      zone = zone.name, mapID = zone.mapID,
    }
  end

  -- 1) Coverage seed: every store, both directions, every quality 0-5 and every class appear at
  --    least once, and the timestamps walk the full window.
  local stores = { "BANK", "REAGENT_BANK", "WARBAND_BANK", "GUILD_BANK" }
  local seedN = math.max(#stores, #TEST_CLASSES, 6, TEST_SPAN_DAYS)
  for i = 1, seedN do
    make(stores[((i - 1) % #stores) + 1],
         (i % 2 == 0) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
         (i - 1) % 6,
         TEST_CLASSES[((i - 1) % #TEST_CLASSES) + 1],
         (i - 1) % TEST_SPAN_DAYS)
  end

  -- 2) Weighted bulk: deposits outnumber withdrawals, as a real bank does, and a third of the
  --    movements cluster onto the last few days.
  for _ = 1, 220 do
    local dayOffset = rng(TEST_SPAN_DAYS) - 1
    if rng(3) == 1 then dayOffset = rng(5) - 1 end
    make(testPick(rng, TEST_STORE_W),
         (rng(10) <= 6) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
         testPick(rng, TEST_QUALITY_W), testPick(rng, TEST_CLASS_W), dayOffset)
  end

  -- 3) Gold movements, at the two stores that hold coin.
  for i = 1, 30 do
    local store = (i % 2 == 0) and "WARBAND_BANK" or "GUILD_BANK"
    local cls = testPick(rng, TEST_CLASS_W)
    local zone = TEST_ZONES[testPick(rng, TEST_ZONE_W)]
    out[#out + 1] = {
      ts = now - (rng(TEST_SPAN_DAYS) - 1) * TEST_DAY - rng(80000),
      char = cls:sub(1, 1) .. cls:sub(2):lower() .. "-Ravencrest", classFile = cls,
      kind = C.Kind.MONEY,
      direction = (rng(10) <= 7) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
      store = store,
      guild = (store == "GUILD_BANK") and "Ka0s" or nil,
      itemName = "Gold", quantity = rng(500) * 10000,
      zone = zone.name, mapID = zone.mapID,
    }
  end

  return out
end

-- Toggle the test dataset (`/bl test`). Publishing it to State means every read-path query -- the
-- table AND Insights -- resolves against the same data, through the real render path (test-mode).
function LT:ToggleTestMode()
  self.testMode = not self.testMode
  NS.State.testRecords = self.testMode and self:BuildTestData() or nil
  if NS.Browser and NS.Browser.Show then NS.Browser:Show() end
  if NS.Browser and NS.Browser.OnDatasetChanged then
    NS.Browser:OnDatasetChanged()
  else
    self:Refresh()
  end
  return self.testMode
end
```

Change the flag declaration at `modules/LedgerTable.lua:115` from `LT.previewMode = false` to `LT.testMode = false`, and update the `LT:CurrentEntries` comment (line 283) to say "test mode".

- [ ] **Step 4: Rename the badge and the slash command**

In `modules/Browser.lua`:
- Line ~680: `if NS.LedgerTable and NS.LedgerTable.previewMode then return {} end` → `.testMode`.
- Line ~721-722: `frame.previewBadge` → `frame.testBadge`; `NS.LedgerTable.previewMode` → `.testMode`.
- Lines ~913-918: rename the local `previewBadge` → `testBadge`, change `SetText("PREVIEW")` to `SetText("TEST MODE")`, and `frame.previewBadge = previewBadge` → `frame.testBadge = testBadge`.
- Update the comment at line ~709 and the one above the badge to say "test mode".

In `settings/Schema.lua`, replace the `preview` command entry:

```lua
  { name = "test",     desc = "Toggle a sample ledger",  fn = function()
      local on = NS.LedgerTable and NS.LedgerTable.ToggleTestMode
        and NS.LedgerTable:ToggleTestMode()
      print("test mode " .. (on and "on" or "off"))
    end },
```

> Keep the command list's existing alphabetical/grouping order — move the entry if the surrounding list is ordered.

Update the comments in `core/State.lua:27` and `core/Database.lua:54,82,123` from "`/bl preview`" / "preview dataset" / "preview mode" to "`/bl test`" / "test dataset" / "test mode".

- [ ] **Step 5: Update the other suites**

Grep for stragglers and fix each: `grep -rn "previewMode\|TogglePreview\|BuildPreviewData\|previewBadge" --include="*.lua" .`

Expected remaining hits after the fix: only `modules/SessionWindow.lua` and `settings/Schema.lua`'s `session` command (`SW:TogglePreview`), which are deliberately out of scope. In `tests/test_slash.lua`, rename any `preview` command assertion to `test`.

- [ ] **Step 6: Run the green gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `0 failed`, luacheck clean.

- [ ] **Step 7: Commit**

```bash
git add core/State.lua core/Database.lua modules/LedgerTable.lua modules/Browser.lua \
        settings/Schema.lua tests/
git commit -m "feat(test-mode): rename /bl preview to /bl test and enrich the dataset

Adopts the Ka0s house vocabulary set by LootHistory's /lh test: the
command, the flag, the builders and the badge all move from 'preview' to
'test'. SessionWindow's own preview session (/bl session) is a separate
feature and keeps its name.

The old dataset was near-uniform across 8 items, 3 stores, 3 characters
and 1 zone, which made every chart a flat comb. The generator now
weights stores, directions, classes, zones, types and qualities, runs a
hot-item head over a long tail, and follows an evening-leaning hour
curve. A coverage seed pass still guarantees every store, both
directions, every quality and every character appear over a >14 day
span, and the fixed-seed Park-Miller LCG keeps it byte-identical so the
headless tests can assert on it."
```

---

## Task 10: Documentation sync

**Files:**
- Modify: `docs/ARCHITECTURE.md`, `docs/agent-context.md`, `docs/smoke-tests.md`, `docs/testing.md`, `README.md`
- Regenerate: `docs/test-cases.md`

**Interfaces:**
- Consumes: Tasks 1-9. No code changes.

- [ ] **Step 1: Regenerate the test inventory**

```bash
lua tests/run.lua --list > docs/test-cases.md
```

This file is generated — never hand-edit it.

- [ ] **Step 2: Update `docs/ARCHITECTURE.md`**

Cover, in the sections that already discuss each topic:

- **Schema v2** — the migration strips `vendorPrice`; `RunMigrations` is no longer a bare seam.
- **The accepted deviation** — a short, explicit subsection recording the CSV export-contract break: which columns went (ledger: `vendorPrice`, `value`, `valueRaw`, `net`; insights: the `Value moved` summary row and the `Top Items By Value` section), why (a value column with no value behind it is a promise the data no longer keeps), and that it is versioned by the schema bump.
- **`Database:Stats` keys** — remove `totalValue`, `valueByStore`, `valueByDay`, `topItemsByValue`, `biggestMove`; note `netByStore` is now a movement count; add `qualityByDirection`, `itemTypeByDirection`, `itemSubTypeByDirection`, `topItemsIn/Out`, `topItemsByQuantityIn/Out`, `topZonesIn/Out`, `topTypeSub(In/Out)`, `topItemsByStore`, `totals.itemsMoved`, `totals.topStore`.
- **Insights section order** — the four new `× In/Out` companions and the reorganized 3-column list grid.
- **Slash surface** — `/bl preview` → `/bl test`.

- [ ] **Step 3: Update `docs/agent-context.md`**

Refresh the hard rules and invariants: no value dimension anywhere, the pooled-panel rule (panels carry their own row pool), and the `/bl test` name.

- [ ] **Step 4: Update `docs/smoke-tests.md`**

- Rename the preview-mode scenario to `/bl test`, with the badge now reading **TEST MODE**.
- Add expected observations for the enriched dataset: every store present, both directions, a visibly uneven spread across characters/zones/types rather than a flat comb.
- Add a scenario for the four `× In/Out` companions (each sits immediately under its parent chart, green/red segments, legend present).
- Add a scenario for the reorganized Top Of The List grid (four groups, three columns, empty direction columns simply absent).
- Update the Deposits vs Withdrawals scenario: labels sit **below** the bar and stay readable at a lopsided split.
- Remove every value-chart scenario.

- [ ] **Step 5: Update `docs/testing.md` and `README.md`**

- `docs/testing.md`: refresh the per-suite descriptions for the suites that changed, and the total pass count if it is quoted.
- `README.md`: update the feature list and any command table (`/bl preview` → `/bl test`); remove value-related feature claims and screenshots' captions if they mention value.

- [ ] **Step 6: Verify no stale references remain**

```bash
grep -rn -i "vendorPrice\|EntryValue\|SignedValue\|totalValue\|valueByStore\|valueByDay\|topItemsByValue\|biggestMove\|value moved\|/bl preview\|previewMode" \
  --include="*.lua" --include="*.md" . | grep -v "^./docs/superpowers/" | grep -v "^./docs/audits/"
```

Expected: no hits outside `modules/SessionWindow.lua` (its `previewSession`, deliberately kept) and the frozen `docs/audits/` and `docs/superpowers/` bundles, which are historical records and must not be rewritten.

- [ ] **Step 7: Run the green gate and commit**

```bash
lua tests/run.lua && luacheck .
git add docs/ README.md
git commit -m "docs: sync for the Insights overhaul and schema v2

Records the accepted CSV export-contract deviation, the new and removed
Stats keys, the reorganized Insights section order, and the /bl preview
-> /bl test rename. Regenerates the test-cases inventory."
```

---

## Self-review notes

**Spec coverage.** Each numbered spec item maps to a task: value removal → Tasks 1-4; the icon bug → Task 5; ratio-bar labels and card font → Task 6; test mode → Task 9; the `× In/Out` companions → Task 7; the list reorganization → Task 8; the card-grid resolution → Task 4; docs and the deviation record → Task 10.

**Known plan wrinkle.** Task 1 Step 9 documents a real ordering trap and resolves it: deleting `Util.EntryValue` breaks `Database:Stats` immediately, so Tasks 1 and 2 cannot each end on a green gate independently. They **share one commit**, taken at Task 2 Step 6. If `modules/Export.lua`'s calls to the deleted helpers also break the gate at that point, fold Task 3 into the same commit. This is the one place in the plan where task boundaries and commit boundaries do not coincide.

**Naming consistency.** The names below are used identically wherever they appear: `I.BarLabel`, `I:RenderDirectionSplit`, `I:RenderSubHead`, `I:RenderListRow`, `I:RenderList(title, rows, y, x, colW, rightW)`, `W.SetPanelTitle`, `W.ReleasePanels`, `W.RATIO_H`, `W.RATIO_CAPTION_H`, `LT:ToggleTestMode`, `LT:BuildTestData`, `LT.testMode`, `frame.testBadge`, `totals.itemsMoved`, `totals.topStore`, `movesIn/movesOut/qtyIn/qtyOut`, `inCount/outCount`.
