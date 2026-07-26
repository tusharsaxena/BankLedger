local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local LT = NS.LedgerTable
local NOW = 1770000000

-- A `field = nil` override is invisible to pairs(), so clearing a field needs an explicit sentinel.
local NIL = {}

local function e(over)
  local x = {
    ts = NOW, char = "Mock-Realm", classFile = "MAGE",
    kind = "ITEM", direction = "DEPOSIT", store = "BANK",
    itemID = 2589, itemName = "Linen Cloth", quality = 1,
    itemType = "Tradegoods", vendorPrice = 20, quantity = 10,
  }
  for k, v in pairs(over or {}) do x[k] = (v ~= NIL) and v or nil end
  return x
end

-- ── Cell rendering ─────────────────────────────────────────────────────────────

test("LedgerTable:CellText renders the direction as a human label", function()
  assertEqual(LT:CellText("direction", e()), "Deposit")
  assertEqual(LT:CellText("direction", e({ direction = "WITHDRAW" })), "Withdraw")
end)

test("LedgerTable:CellText renders the store as a human label", function()
  assertEqual(LT:CellText("store", e()), "Character Bank")
  assertEqual(LT:CellText("store", e({ store = "WARBAND_BANK" })), "Warband Bank")
end)

test("LedgerTable:CellText falls back to 'Item <id>' for an uncached item", function()
  assertEqual(LT:CellText("item", e({ itemName = NIL, itemID = 12345 })), "Item 12345")
end)

test("LedgerTable:CellText shows a gold row's amount as money in the Qty column", function()
  -- There is no Value column: a gold movement's amount IS its quantity, formatted as money so a
  -- "50000" can never read as 50,000 items.
  assertEqual(LT:CellText("qty", e({ kind = "MONEY", quantity = 50000 })), "5g")
end)

test("LedgerTable:CellText shows the stack size for an item row", function()
  assertEqual(LT:CellText("qty", e({ quantity = 7 })), "7")
end)

test("LedgerTable:CellText renders the quality label, and blank when unknown", function()
  assertEqual(LT:CellText("quality", e({ quality = 4 })), "Epic")
  assertEqual(LT:CellText("quality", e({ quality = NIL })), "")
end)

test("LedgerTable:CellText shows a dash for a gold row's quality", function()
  assertEqual(LT:CellText("quality", e({ kind = "MONEY", quality = NIL })), "\226\128\148")
end)

test("LedgerTable:CellText renders the item type and sub-type, and blank when unknown", function()
  assertEqual(LT:CellText("type", e()), "Tradegoods")
  assertEqual(LT:CellText("subtype", e({ itemSubType = "Cloth" })), "Cloth")
  assertEqual(LT:CellText("subtype", e({ itemSubType = NIL })), "")
end)

test("LedgerTable:CellText types a gold row as Gold on both type columns", function()
  assertEqual(LT:CellText("type", e({ kind = "MONEY", itemType = NIL })), "Gold")
  assertEqual(LT:CellText("subtype", e({ kind = "MONEY", itemSubType = NIL })), "Gold")
end)

test("LedgerTable:CellText returns empty for an unknown column key", function()
  assertEqual(LT:CellText("nonesuch", e()), "")
end)

-- ── Sorting ────────────────────────────────────────────────────────────────────

local function withSort(key, asc, fn)
  local sk, sa = LT.sortKey, LT.sortAsc
  LT.sortKey, LT.sortAsc = key, asc
  local ok, err = pcall(fn)
  LT.sortKey, LT.sortAsc = sk, sa
  if not ok then error(err, 0) end
end

test("LedgerTable:SortEntries orders by the active column", function()
  local list = { e({ ts = NOW - 100 }), e({ ts = NOW }), e({ ts = NOW - 50 }) }
  withSort("date", false, function()
    local out = LT:SortEntries(list)
    assertEqual(out[1].ts, NOW, "newest first when descending")
    assertEqual(out[3].ts, NOW - 100)
  end)
end)

test("LedgerTable:SortEntries honours the ascending direction", function()
  local list = { e({ ts = NOW }), e({ ts = NOW - 100 }) }
  withSort("date", true, function()
    assertEqual(LT:SortEntries(list)[1].ts, NOW - 100)
  end)
end)

test("LedgerTable:SortEntries is stable across equal keys", function()
  -- Lua 5.1's table.sort is not stable, so equal keys must tiebreak on the original index or the
  -- table visibly reshuffles rows that should not move.
  local list = { e({ itemName = "A" }), e({ itemName = "B" }), e({ itemName = "C" }) }
  withSort("date", false, function()
    local out = LT:SortEntries(list)
    assertEqual(out[1].itemName, "A")
    assertEqual(out[2].itemName, "B")
    assertEqual(out[3].itemName, "C")
  end)
end)

test("LedgerTable:SortEntries never mutates the array it is given", function()
  local list = { e({ ts = NOW - 100 }), e({ ts = NOW }) }
  withSort("date", false, function()
    LT:SortEntries(list)
    assertEqual(list[1].ts, NOW - 100, "the caller's order is untouched")
  end)
end)

test("LedgerTable:SortEntries sorts the Qty column on what the cell shows", function()
  -- A gold row's quantity is its copper amount — the same number the Qty cell formats as money.
  local list = { e({ quantity = 1 }), e({ kind = "MONEY", quantity = 99999 }) }
  withSort("qty", false, function()
    assertEqual(LT:SortEntries(list)[1].kind, "MONEY")
  end)
end)

-- ── Grouping ───────────────────────────────────────────────────────────────────

local function withGroup(mode, fn)
  local g, c = LT.groupBy, LT.collapsed
  LT.groupBy, LT.collapsed = mode, {}
  local ok, err = pcall(fn)
  LT.groupBy, LT.collapsed = g, c
  if not ok then error(err, 0) end
end

test("LedgerTable:GroupEntries with no grouping emits one row item each", function()
  withGroup("none", function()
    local list = LT:GroupEntries({ e(), e() })
    assertEqual(#list, 2)
    assertEqual(list[1].kind, "row")
  end)
end)

test("LedgerTable:GroupEntries inserts a header per group, with a count", function()
  withGroup("store", function()
    local list = LT:GroupEntries({ e(), e({ store = "GUILD_BANK" }), e() })
    -- 2 headers + 3 rows
    assertEqual(#list, 5)
    local headers = 0
    for _, item in ipairs(list) do if item.kind == "header" then headers = headers + 1 end end
    assertEqual(headers, 2)
  end)
end)

test("LedgerTable:GroupEntries labels a header with its column prefix and value", function()
  withGroup("store", function()
    local list = LT:GroupEntries({ e() })
    assertEqual(list[1].label, "Store: Character Bank")
    assertEqual(list[1].count, 1)
  end)
end)

test("LedgerTable:GroupEntries emits only the header for a collapsed group", function()
  withGroup("store", function()
    local list = LT:GroupEntries({ e(), e() })
    local key = list[1].key
    LT.collapsed[key] = true
    local collapsedList = LT:GroupEntries({ e(), e() })
    assertEqual(#collapsedList, 1, "just the header")
    assertEqual(collapsedList[1].collapsed, true)
  end)
end)

test("LedgerTable:GroupEntries namespaces group keys by mode, so they cannot collide", function()
  withGroup("store", function()
    local storeKey = LT:GroupEntries({ e() })[1].key
    LT.groupBy = "direction"
    local dirKey = LT:GroupEntries({ e() })[1].key
    assertTrue(storeKey ~= dirKey, "different modes produce different keys")
  end)
end)

test("LedgerTable:GroupEntries groups gold and items apart under 'kind'", function()
  withGroup("kind", function()
    local list = LT:GroupEntries({ e(), e({ kind = "MONEY" }) })
    assertEqual(#list, 4)   -- 2 headers + 2 rows
    -- 'kind' is the Item/Gold split; the Type prefix belongs to the Type column's own grouping.
    -- 'kind' maps to no table column, so its groups order by label: Gold before Item.
    assertEqual(list[1].label, "Item/Gold: Gold")
    assertEqual(list[3].label, "Item/Gold: Item")
  end)
end)

test("LedgerTable:GroupEntries groups by item type and sub-type", function()
  withGroup("type", function()
    local list = LT:GroupEntries({ e(), e({ itemType = "Consumable" }) })
    assertEqual(#list, 4)
    assertEqual(list[1].label, "Type: Consumable", "groups sort by label ascending")
  end)
  withGroup("subtype", function()
    local list = LT:GroupEntries({ e({ itemSubType = "Cloth" }), e({ itemSubType = "Herb" }) })
    assertEqual(#list, 4)
    assertEqual(list[1].label, "Sub-type: Cloth")
  end)
end)

test("LedgerTable:GroupEntries gathers gold under Gold when grouping by type", function()
  withGroup("type", function()
    local list = LT:GroupEntries({ e({ kind = "MONEY" }), e({ kind = "MONEY" }) })
    assertEqual(#list, 3)   -- one header + two rows
    assertEqual(list[1].label, "Type: Gold")
  end)
end)

test("LedgerTable:GroupEntries labels an untyped item group Unknown", function()
  withGroup("type", function()
    assertEqual(LT:GroupEntries({ e({ itemType = NIL }) })[1].label, "Type: Unknown")
  end)
end)

test("LedgerTable:GroupEntries orders quality groups Poor to Legendary", function()
  withGroup("quality", function()
    local list = LT:GroupEntries({ e({ quality = 4 }), e({ quality = 1 }) })
    assertEqual(list[1].label, "Quality: Common", "quality sorts by id, not alphabetically")
    assertEqual(list[3].label, "Quality: Epic")
  end)
end)

test("LedgerTable:GroupEntries puts gold in its own quality group", function()
  -- Gold has no quality at all; folding it into Poor would misreport it.
  withGroup("quality", function()
    local list = LT:GroupEntries({ e({ kind = "MONEY", quality = NIL }), e({ quality = 0 }) })
    assertEqual(list[1].label, "Quality: None")
  end)
end)

-- ── Preview dataset (preview-mode) ─────────────────────────────────────────────

test("LedgerTable:BuildPreviewData produces a non-trivial sample ledger", function()
  local data = LT:BuildPreviewData()
  assertTrue(#data > 150, "enough rows for the charts to look real, got " .. #data)
end)

test("LedgerTable:BuildPreviewData is deterministic across runs", function()
  -- A fixed-seed PRNG, never math.random: the tests below could not assert on the data otherwise.
  local a, b = LT:BuildPreviewData(), LT:BuildPreviewData()
  assertEqual(#a, #b)
  assertEqual(a[1].itemID, b[1].itemID)
  assertEqual(a[#a].quantity, b[#b].quantity)
end)

test("LedgerTable:BuildPreviewData covers every store", function()
  local seen = {}
  for _, x in ipairs(LT:BuildPreviewData()) do seen[x.store] = true end
  for _, store in ipairs({ "BANK", "WARBAND_BANK", "GUILD_BANK" }) do
    assertTrue(seen[store], store .. " is missing from the preview data")
  end
end)

test("LedgerTable:BuildPreviewData covers both directions and both kinds", function()
  local dirs, kinds = {}, {}
  for _, x in ipairs(LT:BuildPreviewData()) do dirs[x.direction] = true; kinds[x.kind] = true end
  assertTrue(dirs.DEPOSIT and dirs.WITHDRAW, "both directions")
  assertTrue(kinds.ITEM and kinds.MONEY, "items and gold")
end)

test("LedgerTable:BuildPreviewData only puts gold where gold can live", function()
  for _, x in ipairs(LT:BuildPreviewData()) do
    if x.kind == "MONEY" then
      assertTrue(NS.Ledger.MONEY_STORES[x.store], x.store .. " has no gold slot")
    end
  end
end)

test("LedgerTable:BuildPreviewData stamps the guild name only on guild-bank rows", function()
  for _, x in ipairs(LT:BuildPreviewData()) do
    if x.store == "GUILD_BANK" then assertTrue(x.guild ~= nil)
    else assertEqual(x.guild, nil) end
  end
end)

test("LedgerTable.RenderSummary is one line carrying the render's shape", function()
  local line = LT.RenderSummary(12, 400, 2, "store", "date", false)
  assertTrue(line:find("12/400", 1, true) ~= nil, "the shown/total counts")
  assertTrue(line:find("group=store", 1, true) ~= nil)
  assertTrue(line:find("sort=date desc", 1, true) ~= nil)
  assertTrue(line:find("filters=2", 1, true) ~= nil)
end)

test("LedgerTable:MinFrameWidth is wide enough for every column", function()
  assertTrue(LT:MinFrameWidth() > 800, "got " .. LT:MinFrameWidth())
end)
