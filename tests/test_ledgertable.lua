local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LT = NS.LedgerTable
local NOW = 1770000000

-- A `field = nil` override is invisible to pairs(), so clearing a field needs an explicit sentinel.
local NIL = {}

local function e(over)
  local x = {
    ts = NOW, char = "Mock-Realm", classFile = "MAGE",
    kind = "ITEM", direction = "DEPOSIT", store = "BANK",
    itemID = 2589, itemName = "Linen Cloth", quality = 1,
    itemType = "Tradegoods", quantity = 10,
  }
  for k, v in pairs(over or {}) do x[k] = (v ~= NIL) and v or nil end
  return x
end

-- ── Cell rendering ─────────────────────────────────────────────────────────────

test("LedgerTable:CellText renders the direction as a human label", function()
  assertEqual(LT:CellText("direction", e()), "Deposit")
  assertEqual(LT:CellText("direction", e({ direction = "WITHDRAW" })), "Withdraw")
end)

test("LedgerTable:Column exposes the spec behind a key, and nil for an unknown one", function()
  local col = LT:Column("item")
  assertTrue(col ~= nil, "the Item column must be reachable")
  assertEqual(col.key, "item")
  assertTrue(col.flex == true, "Item is the flex column the session window also relies on")
  assertEqual(LT:Column("nosuchcolumn"), nil)
end)

test("LedgerTable:PaintCell writes the column's text into the cell", function()
  -- A minimal FontString stand-in: PaintCell is the ONE place both windows set text and color, so
  -- it must be callable against any FontString, not just a pooled History row's.
  local calls = {}
  local fs = {
    SetText = function(_, v) calls.text = v end,
    SetTextColor = function(_, r, g, b) calls.rgb = { r, g, b } end,
  }
  LT:PaintCell(fs, "store", e())
  assertEqual(calls.text, "Character Bank")
  assertEqual(calls.rgb[1], 1.00, "the Character Bank keeps its gold from the shared palette")
end)

test("LedgerTable:PaintCell drives the direction glyph only for the Direction column", function()
  local glyph = { shown = nil, text = nil,
    SetText = function(self, v) self.text = v end,
    SetTextColor = function() end,
    SetShown = function(self, v) self.shown = v end }
  local fs = { SetText = function() end, SetTextColor = function() end }
  LT:PaintCell(fs, "direction", e({ direction = "WITHDRAW" }), glyph)
  assertEqual(glyph.text, "\226\150\178", "a withdrawal draws the up arrow")
  assertTrue(glyph.shown, "and the glyph is shown")
  -- Passing a glyph for any other column must leave it alone.
  glyph.text = "untouched"
  LT:PaintCell(fs, "store", e(), glyph)
  assertEqual(glyph.text, "untouched")
end)

test("LedgerTable:PaintCell is a safe no-op for a missing cell or column", function()
  LT:PaintCell(nil, "store", e())
  LT:PaintCell({ SetText = function() end, SetTextColor = function() end }, "nosuchcolumn", e())
  assertTrue(true, "neither call may raise")
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

test("LedgerTable:SortEntries honors the ascending direction", function()
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

-- The group KEY is what the collapsed-state map in SavedVariables is keyed on, so it is a storage
-- contract: change its shape and every user's collapsed groups silently reset. This case pins the
-- exact (key, label) pair every mode produces, including the unknown-mode fallback — the header item
-- is the only place both halves surface together.
test("LedgerTable:GroupEntries emits the exact key and label for every group mode", function()
  local cases = {
    { mode = "store",      entry = {},                       key = "store\001BANK",
      label = "Store: Character Bank" },
    { mode = "direction",  entry = {},                       key = "direction\001DEPOSIT",
      label = "Direction: Deposit" },
    { mode = "kind",       entry = {},                       key = "kind\001ITEM",
      label = "Item/Gold: Item" },
    { mode = "type",       entry = {},                       key = "type\001Tradegoods",
      label = "Type: Tradegoods" },
    { mode = "subtype",    entry = { itemSubType = "Cloth" }, key = "subtype\001Cloth",
      label = "Sub-type: Cloth" },
    { mode = "quality",    entry = {},                       key = "quality\0011",
      label = "Quality: Common" },
    { mode = "char",       entry = {},                       key = "char\001Mock-Realm",
      label = "Character: Mock-Realm" },
    -- The key stays ISO so it is stable and unique per calendar day; the label matches the Date column.
    -- os.date, because the mock's `date` global is injected into the ADDON's environment, not this one.
    { mode = "day",        entry = {},                       key = "day\001" .. os.date("%Y-%m-%d", NOW),
      label = "Day: " .. NS.Util.FormatDate(NOW) },
    -- An unrecognized mode falls back to "?" on both halves rather than to nil.
    { mode = "nosuchmode", entry = {},                       key = "nosuchmode\001?",
      label = "?: ?" },
  }
  for _, c in ipairs(cases) do
    withGroup(c.mode, function()
      local header = LT:GroupEntries({ e(c.entry) })[1]
      assertEqual(header.key, c.key, c.mode .. " key")
      assertEqual(header.label, c.label, c.mode .. " label")
    end)
  end
end)

test("LedgerTable:GroupEntries defaults a missing group value rather than dropping the entry",
function()
  local cases = {
    { mode = "store",   entry = { store = NIL },    key = "store\001?",
      label = "Store: Unknown" },
    { mode = "char",    entry = { char = NIL },     key = "char\001Unknown",
      label = "Character: Unknown" },
    -- Gold has no quality, and gets its own group rather than falling into Poor.
    { mode = "quality", entry = { quality = NIL },  key = "quality\001none",
      label = "Quality: None" },
    { mode = "type",    entry = { itemType = NIL }, key = "type\001Unknown",
      label = "Type: Unknown" },
    { mode = "subtype", entry = {},                 key = "subtype\001Unknown",
      label = "Sub-type: Unknown" },
  }
  for _, c in ipairs(cases) do
    withGroup(c.mode, function()
      local header = LT:GroupEntries({ e(c.entry) })[1]
      assertEqual(header.key, c.key, c.mode .. " key")
      assertEqual(header.label, c.label, c.mode .. " label")
    end)
  end
end)

-- ── Test dataset (test-mode) ───────────────────────────────────────────────────

test("LedgerTable:BuildTestData produces a non-trivial sample ledger", function()
  local data = LT:BuildTestData()
  assertTrue(#data > 150, "enough rows for the charts to look real, got " .. #data)
end)

test("LedgerTable:BuildTestData is deterministic across runs", function()
  -- A fixed-seed PRNG, never math.random: the tests below could not assert on the data otherwise.
  local a, b = LT:BuildTestData(), LT:BuildTestData()
  assertEqual(#a, #b)
  assertEqual(a[1].itemID, b[1].itemID)
  assertEqual(a[#a].quantity, b[#b].quantity)
end)

test("LedgerTable:BuildTestData covers every store", function()
  local seen = {}
  for _, x in ipairs(LT:BuildTestData()) do seen[x.store] = true end
  for _, store in ipairs({ "BANK", "WARBAND_BANK", "GUILD_BANK" }) do
    assertTrue(seen[store], store .. " is missing from the test data")
  end
end)

test("LedgerTable:BuildTestData covers both directions and both kinds", function()
  local dirs, kinds = {}, {}
  for _, x in ipairs(LT:BuildTestData()) do dirs[x.direction] = true; kinds[x.kind] = true end
  assertTrue(dirs.DEPOSIT and dirs.WITHDRAW, "both directions")
  assertTrue(kinds.ITEM and kinds.MONEY, "items and gold")
end)

test("LedgerTable:BuildTestData only puts gold where gold can live", function()
  for _, x in ipairs(LT:BuildTestData()) do
    if x.kind == "MONEY" then
      assertTrue(NS.Ledger.MONEY_STORES[x.store], x.store .. " has no gold slot")
    end
  end
end)

test("LedgerTable:BuildTestData stamps the guild name only on guild-bank rows", function()
  for _, x in ipairs(LT:BuildTestData()) do
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
  for _, s in ipairs({ "BANK", "WARBAND_BANK", "GUILD_BANK" }) do
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

-- ── Test mode is a read-only sandbox ───────────────────────────────────────────
-- The sample rows carry synthetic item ids (190001+) and live only in State. Any menu action that
-- WRITES would cross out of the sandbox: blacklisting one puts a fake id into the real, persisted
-- capture filter, and Delete matches nothing in real storage while still firing LedgerChanged.

-- Build the menu under a given test-mode state and put State back BEFORE asserting. State.testRecords
-- is global to the suite, so a failed assertion left mid-test would otherwise leak test mode into
-- every later file (Insights and Export both resolve their data through it).
local function menuByLabel(entry, testMode)
  local saved = NS.State.testRecords
  NS.State.testRecords = testMode and { { kind = "ITEM" } } or nil
  local ok, items = pcall(function() return NS.LedgerTable:RowMenuItems(entry) end)
  NS.State.testRecords = saved
  if not ok then error(items, 0) end
  local out = {}
  for _, item in ipairs(items) do
    -- Labels carry color escapes; key on the visible text.
    out[(item.label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))] = item
  end
  return out
end

test("LedgerTable:IsTestMode is derived from the published dataset, not a second flag", function()
  -- One stored fact means the two can never disagree.
  local saved = NS.State.testRecords
  NS.State.testRecords = nil
  local whenClear = NS.LedgerTable:IsTestMode()
  NS.State.testRecords = { { kind = "ITEM" } }
  local whenSet = NS.LedgerTable:IsTestMode()
  NS.State.testRecords = saved
  assertFalse(whenClear)
  assertTrue(whenSet)
end)

test("LedgerTable row menu offers the mutating actions on a real row", function()
  local m = menuByLabel({ itemID = 2589, itemName = "Linen Cloth", itemLink = "|Hitem:2589|h" }, false)
  assertTrue(m["Blacklist item"].enabled, "blacklist is live")
  assertTrue(m["Whitelist item"].enabled)
  assertTrue(m["Delete"].enabled)
end)

test("LedgerTable row menu disables every mutating action in test mode", function()
  local m = menuByLabel({ itemID = 190001, itemName = "Sample", itemLink = "|Hitem:190001|h" }, true)
  assertFalse(m["Blacklist item"].enabled, "a synthetic id must never reach the real filter list")
  assertFalse(m["Whitelist item"].enabled)
  assertFalse(m["Delete"].enabled, "Delete matched nothing yet still broadcast LedgerChanged")
  assertTrue(m["Link to chat"].enabled, "linking mutates nothing, so it stays available")
end)

test("LedgerTable row menu still disables item actions on a money row", function()
  -- The pre-existing rule (no itemID, no item actions) must survive the test-mode gate.
  local m = menuByLabel({ kind = "MONEY", quantity = 5000 }, false)
  assertFalse(m["Blacklist item"].enabled)
  assertFalse(m["Link to chat"].enabled)
  assertTrue(m["Delete"].enabled, "a real money row is still deletable")
end)
