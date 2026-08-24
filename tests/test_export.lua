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

-- ── The wowhead column ─────────────────────────────────────────────────────────

test("Export:CSV ends with the wowhead column", function()
  -- Appended last on purpose: a sheet keyed on column position keeps working.
  assertEqual(NS.Export.HEADER[#NS.Export.HEADER], "wowhead")
end)

test("Export:CSV writes a wowhead URL carrying the item's bonus ids", function()
  local row = cells(lines(NS.Export:CSV({ e({ itemID = 151300,
    itemLink = "|cffa335ee|Hitem:151300::::::::80:250::5:3:12801:13440:6652:1:28:2437"
      .. "|h[Sample Helm]|h|r" }) }))[2])
  assertEqual(row[columnIndex("wowhead")],
    "https://www.wowhead.com/item=151300?bonus=12801:13440:6652")
end)

test("Export:CSV writes a bare item URL when the row has no link", function()
  local row = cells(lines(NS.Export:CSV({ e() }))[2])
  assertEqual(row[columnIndex("wowhead")], "https://www.wowhead.com/item=2589")
end)

test("Export:CSV leaves the wowhead cell empty for a gold row", function()
  local row = cells(lines(NS.Export:CSV({
    e({ kind = "MONEY", itemID = NIL, itemName = "Gold", quality = NIL,
        itemType = NIL, itemSubType = NIL, quantity = 50000 }) }))[2])
  assertEqual(row[columnIndex("wowhead")], "")
end)

-- ── The export modal's Data Set dropdown ──────────────────────────────────────
--
-- The modal is this addon's SECOND LibKa0s-Widgets-1.0 consumer, after the filter bar, and until
-- now no case here touched it: a grep for MakeDropdown or CloseMenu in this file returned nothing.
-- Two defects lived in that gap and both are pinned below.
--
-- The environments are ISOLATED (T.makeMocks + the loader) rather than the shared NS, for two
-- reasons: the popup menu is a process-wide singleton behind a file-local, so the only way to get a
-- handle on it is to be the FIRST click in a freshly loaded Widgets.lua; and the degraded rung is
-- honestly reachable only by loading every LibKa0s major EXCEPT Widgets, which is the real shape of
-- "the vendored copy's NEEDS_CORE floor is unmet" or "the file was never copied in".

local function loadEnv(withWidgets)
  local m = T.makeMocks()
  local ns = {}
  local files = {}
  for _, path in ipairs(T.libka0sFiles) do
    if withWidgets or path ~= "libs/LibKa0s/Widgets.lua" then files[#files + 1] = path end
  end
  T.Loader.loadAll(files, ns, m)
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  ns:InitDB()
  ns.Schema:Register()
  ns.Ledger:Enable()
  return ns, m
end

test("Export modal: the Data Set control is a real LibKa0s-Widgets-1.0 dropdown", function()
  local ns, m = loadEnv(true)
  assertTrue(m.LibStub("LibKa0s-Widgets-1.0", true) ~= nil, "this rung HAS the library")
  local f = ns.Export:Open({})
  local ds = f.datasetDD
  assertTrue(ds ~= nil, "the modal keeps a handle on the control it built")
  assertEqual(ds:GetHeight(), 24, "the modal's own height, taller than the filter bar's 20")
  assertTrue(type(ds.SetOptions) == "function", "it is the library's dropdown, not a stand-in")
  assertEqual(ds.text:GetText(), "Data set: All Data", "seeded with the default data set")
end)

test("Export modal: with no Widgets library it REFUSES the Data Set control instead of raising",
  function()
    -- modules/Browser.lua:277's MakeDropdown is documented to answer nil with no library, and the
    -- SetHeight / ClearAllPoints that followed it here were unguarded -- so this rung raised.
    -- Latent only because the filter bar refuses to build without the library, so the Export button
    -- that calls Open never exists; a latent raise on a documented nil is still a defect.
    -- Review 2026-08-03 filed it as C-012 / F-013 T4.5 and it was never applied.
    local ns, m = loadEnv(false)
    assertTrue(m.LibStub("LibKa0s-Widgets-1.0", true) == nil, "the degraded rung has no library")
    assertTrue(ns.Browser:MakeDropdown(m.__stubFrame(), 100) == nil,
      "and the factory answers nil, as modules/Browser.lua:277 documents")
    local f
    local ok, err = pcall(function() f = ns.Export:Open({}) end)
    assertTrue(ok, "opening the modal must not raise on the documented nil: " .. tostring(err))
    assertTrue(f ~= nil, "the modal still exists")
    assertTrue(f.datasetDD == nil, "and it drew NO dead control that opens no menu")
    assertTrue(f.csvBtn ~= nil, "the one thing the modal is for is still there")
  end)

-- Opening the shared popup the only way the game can: a real click on a real dropdown. Answers the
-- menu frame, which no host is given a handle to.
local function openMenu(ns, m, ds)
  local onClick = ds:GetScript("OnClick")
  assertTrue(onClick ~= nil, "the dropdown wires an OnClick that opens the shared menu")
  local realCreateFrame, captured = m.CreateFrame, nil
  m.CreateFrame = function(...)
    local f = realCreateFrame(...)
    if not captured then captured = f end
    return f
  end
  local ok, err = pcall(onClick, ds)
  m.CreateFrame = realCreateFrame
  if not ok then error(err, 0) end
  assertTrue(captured ~= nil, "the click built the shared popup menu")
  assertTrue(captured:IsShown(), "and opening the dropdown showed it")
  return captured
end

test("Export modal: hiding the modal closes an open dropdown menu", function()
  -- The popup is parented to UIParent at FULLSCREEN_DIALOG, not to this modal, so the modal's own
  -- Hide() cannot reach it. Escape (the modal is in UISpecialFrames) and the titlebar close button
  -- both go through Hide, so the OnHide hook is the one seam that covers every non-click route.
  local ns, m = loadEnv(true)
  local f = ns.Export:Open({})
  local menu = openMenu(ns, m, f.datasetDD)
  f:Hide()
  assertTrue(menu:IsShown() == false, "hiding the modal closed the menu via W.CloseMenu()")
end)

test("Export modal: the titlebar close button closes the menu with the modal", function()
  local ns, m = loadEnv(true)
  local f = ns.Export:Open({})
  assertTrue(f.closeBtn ~= nil, "the modal keeps a handle on its close control")
  local menu = openMenu(ns, m, f.datasetDD)
  f.closeBtn:GetScript("OnClick")(f.closeBtn)
  assertTrue(f:IsShown() == false, "the close button hid the modal")
  assertTrue(menu:IsShown() == false, "and the shared menu went with it")
end)

test("Export modal: Escape reaches the same close path, because the modal is a UISpecialFrame",
  function()
    -- UISpecialFrames is how Escape closes this window, and it closes it by Hide() -- which is
    -- exactly the path the case above pins. Assert the registration, so the coverage above is
    -- coverage of the Escape route and not only of a direct Hide.
    local ns, m = loadEnv(true)
    ns.Export:Open({})
    local found = false
    for _, name in ipairs(m.UISpecialFrames or {}) do
      if name == "BankLedgerExportWindow" then found = true end
    end
    assertTrue(found, "the modal is in UISpecialFrames, so Escape hides it")
  end)
