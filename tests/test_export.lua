local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local NOW = 1770000000
-- A `field = nil` override is invisible to pairs(), so clearing a field needs an explicit sentinel.
local NIL = {}
local function e(over)
  local x = {
    ts = NOW, char = "Mock-Realm", classFile = "MAGE",
    kind = "ITEM", direction = "DEPOSIT", store = "BANK",
    itemID = 2589, itemName = "Linen Cloth", quality = 1,
    itemType = "Tradegoods", itemSubType = "Cloth",
    quantity = 10, zone = "Testville",
  }
  for k, v in pairs(over or {}) do x[k] = (v ~= NIL) and v or nil end
  return x
end

local function lines(csv)
  local out = {}
  for line in csv:gmatch("([^\r\n]+)") do out[#out + 1] = line end
  return out
end

local function cells(line)
  -- Adequate for the fixtures below, which carry no quoted commas.
  local out = {}
  for field in (line .. ","):gmatch("(.-),") do out[#out + 1] = field end
  return out
end

local function columnIndex(name)
  for i, h in ipairs(NS.Export.HEADER) do if h == name then return i end end
  return nil
end

test("Export:CSV emits a header row even with no data", function()
  local l = lines(NS.Export:CSV({}))
  assertEqual(#l, 1)
  assertEqual(l[1], table.concat(NS.Export.HEADER, ","))
end)

test("Export:CSV emits one row per entry", function()
  assertEqual(#lines(NS.Export:CSV({ e(), e(), e() })), 4)   -- header + 3
end)

test("Export:CSV uses CRLF line endings (RFC 4180)", function()
  assertTrue(NS.Export:CSV({ e() }):find("\r\n", 1, true) ~= nil)
end)

test("Export:CSV writes the human direction and store labels", function()
  local row = cells(lines(NS.Export:CSV({ e() }))[2])
  assertEqual(row[columnIndex("direction")], "Deposit")
  assertEqual(row[columnIndex("store")], "Character Bank")
end)

test("Export:CSV keeps the raw store token beside its label", function()
  -- The label is for a reader; the raw token is what a script should match on.
  local row = cells(lines(NS.Export:CSV({ e() }))[2])
  assertEqual(row[columnIndex("storeRaw")], "BANK")
end)

test("Export:CSV pairs each human column with its raw sibling", function()
  local row = cells(lines(NS.Export:CSV({ e({ quality = 4 }) }))[2])
  assertEqual(row[columnIndex("quality")], "Epic")
  assertEqual(row[columnIndex("qualityRaw")], "4")
end)

test("Export:CSV renders a gold row's kind label", function()
  local row = cells(lines(NS.Export:CSV({
    e({ kind = "MONEY", itemID = NIL, itemName = "Gold", quality = NIL,
        itemType = NIL, itemSubType = NIL, quantity = 50000 }) }))[2])
  assertEqual(row[columnIndex("kind")], "Gold")
end)

test("Export:CSV quotes a field containing a comma and doubles embedded quotes", function()
  local csv = NS.Export:CSV({ e({ itemName = 'Cloth, "fine"' }) })
  assertTrue(csv:find('"Cloth, ""fine"""', 1, true) ~= nil, "RFC-4180 quoting")
end)

test("Export:CSV leaves an absent field empty rather than writing nil", function()
  local row = cells(lines(NS.Export:CSV({ e({ guild = NIL }) }))[2])
  assertEqual(row[columnIndex("guild")], "")
end)

test("Export:CSV never emits the item link (a raw link is unusable in a spreadsheet)", function()
  assertEqual(columnIndex("itemLink"), nil)
end)

-- ── Insights CSV ───────────────────────────────────────────────────────────────

local function insightsCSV()
  local saved = NS.db.global.ledger
  NS.db.global.ledger = {
    e(),
    e({ direction = "WITHDRAW", itemID = 4306, itemName = "Silk Cloth", quantity = 3 }),
    e({ kind = "MONEY", store = "GUILD_BANK", itemID = NIL, itemName = "Gold",
        quality = NIL, itemType = NIL, itemSubType = NIL, quantity = 50000 }),
  }
  local csv = NS.Export:InsightsCSV(NS.Database:Stats({}))
  NS.db.global.ledger = saved
  return csv
end

test("Export:InsightsCSV starts with the four-column header", function()
  assertEqual(lines(insightsCSV())[1], "Section,Label,Count,Value")
end)

test("Export:InsightsCSV carries the summary card values", function()
  local csv = insightsCSV()
  assertTrue(csv:find("Summary,Movements,3", 1, true) ~= nil, "the movement total")
  assertTrue(csv:find("Summary,Items deposited,10", 1, true) ~= nil)
  assertTrue(csv:find("Summary,Items withdrawn,3", 1, true) ~= nil)
end)

test("Export:InsightsCSV includes a per-store breakdown", function()
  assertTrue(insightsCSV():find("By Store,Character Bank", 1, true) ~= nil)
end)

test("Export:InsightsCSV includes the signed net-by-store rows", function()
  local csv = insightsCSV()
  assertTrue(csv:find("Net by Store,Guild Bank", 1, true) ~= nil)
end)

test("Export:InsightsCSV includes the direction and kind breakdowns", function()
  local csv = insightsCSV()
  assertTrue(csv:find("By Direction,Deposit", 1, true) ~= nil)
  assertTrue(csv:find("By Kind,", 1, true) ~= nil)
end)

test("Export:InsightsCSV includes the top-items ranking", function()
  assertTrue(insightsCSV():find("Top Items,Linen Cloth", 1, true) ~= nil)
end)

-- ── The expanded Insights CSV sections ─────────────────────────────────────────
-- The panel's new charts each have a matching CSV section, so an export stays a faithful dump of
-- what is on screen rather than a subset of it.

test("Export:InsightsCSV carries the two new summary figures", function()
  local csv = insightsCSV()
  assertTrue(csv:find("Summary,Net items,7", 1, true) ~= nil, "10 in - 3 out")
  assertTrue(csv:find("Summary,Gold moved,", 1, true) ~= nil)
end)

test("Export:InsightsCSV includes the sub-type breakdown", function()
  assertTrue(insightsCSV():find("By Sub-type,Cloth,2", 1, true) ~= nil)
end)

test("Export:InsightsCSV includes the quality breakdown, in quality order", function()
  local csv = insightsCSV()
  assertTrue(csv:find("By Quality,Common,2", 1, true) ~= nil)
end)

test("Export:InsightsCSV includes the zone breakdown", function()
  assertTrue(insightsCSV():find("By Zone,Testville,3", 1, true) ~= nil)
end)

test("Export:InsightsCSV includes the gross coin per store", function()
  assertTrue(insightsCSV():find("Money By Store,Guild Bank", 1, true) ~= nil)
end)

test("Export:InsightsCSV includes the extra top-item ranking", function()
  assertTrue(insightsCSV():find("Top Items By Quantity,Linen Cloth", 1, true) ~= nil)
end)

test("Export:InsightsCSV includes a per-day coin section", function()
  assertTrue(insightsCSV():find("Gold By Day,", 1, true) ~= nil)
end)

test("Export:InsightsCSV emits a full 24-hour and 7-day grid", function()
  -- Fixed grids, not just the buckets that fired: a zero row says "quiet hour", a missing row says
  -- nothing at all.
  local csv = insightsCSV()
  local hours, days = 0, 0
  for _, line in ipairs(lines(csv)) do
    if line:find("^By Hour,") then hours = hours + 1 end
    if line:find("^By Weekday,") then days = days + 1 end
  end
  assertEqual(hours, 24)
  assertEqual(days, 7)
  assertTrue(csv:find("By Weekday,Sunday,", 1, true) ~= nil, "Sunday is the first weekday row")
end)

test("Export:InsightsCSV keeps the original section headers unchanged", function()
  -- The new sections were appended; a downstream sheet keyed on these names must keep working.
  local csv = insightsCSV()
  for _, header in ipairs({ "Summary,", "By Store,", "Net by Store,", "By Direction,",
                            "By Kind,", "By Item Type,", "By Character,", "Top Items,",
                            "By Day," }) do
    assertTrue(csv:find(header, 1, true) ~= nil, "missing section " .. header)
  end
end)

test("Export:InsightsCSV survives an empty stats result", function()
  local csv = NS.Export:InsightsCSV({})
  assertTrue(csv:find("Summary,Movements,0", 1, true) ~= nil)
end)

test("Export:InsightsCSV survives being handed nothing at all", function()
  assertTrue(NS.Export:InsightsCSV(nil):find("Section,Label", 1, true) ~= nil)
end)

-- ── Value is gone from both CSVs (schema v2) ────────────────────────────────────

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
