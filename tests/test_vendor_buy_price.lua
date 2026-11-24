-- tests/test_vendor_buy_price.lua — the vendor buy price on a ledger row's item tooltip, read from
-- the optional ForeverDB through LibKa0s-ForeverDB-1.0 (SF-BL-01, LibKa0s#105; WowAddonStandards
-- clients-§11). WoW Forever only, behind `settings.showVendorBuyPrice` (default on).
--
-- The suite runs under both kit profiles. Every case drives the real row OnEnter of the History
-- table and of the session window on a fresh load, with the kit's ForeverDB fake
-- (tests/_kit/mock_foreverdb.lua: invented data in ForeverDB's shape, never a real row) installed in
-- one of its presets.

local T = _G.BL_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local NOW = 1770000000

local function fresh()
  local m = T.makeMocks()
  local ns = {}
  T.Loader.loadAll(T.libka0sFiles, ns, m)
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  ns:InitDB()
  ns.Schema:Register()
  ns.Ledger:Enable()
  return ns, m
end

-- A GameTooltip that records every line a hover writes, in order.
local function spy(m)
  local seen = { lines = {} }
  m.GameTooltip = {
    SetOwner = function() end,
    AddLine = function(_, text) seen.lines[#seen.lines + 1] = text end,
    AddDoubleLine = function(_, l, r) seen.lines[#seen.lines + 1] = tostring(l) .. "=" .. tostring(r) end,
    SetHyperlink = function(_, link) seen.link = link end,
    SetText = function(_, text) seen.lines[#seen.lines + 1] = text end,
    ClearLines = function() end,
    Show = function() seen.shown = true end,
    Hide = function() end,
    IsOwned = function() return true end,
    ClearAllPoints = function() end,
    SetPoint = function() end,
  }
  return seen
end

local function hover(m, el)
  local seen = spy(m)
  el:__fire("OnEnter")
  el:__fire("OnLeave")
  m.GameTooltip = nil
  return seen
end

local function entry(over)
  local x = { ts = NOW, char = "Mock-Realm", classFile = "MAGE", kind = "ITEM", direction = "DEPOSIT",
    store = "BANK", itemID = 2589, itemName = "Linen Cloth", quality = 1, quantity = 10,
    itemLink = "|cffffffff|Hitem:2589::::::::70:::::|h[Linen Cloth]|h|r" }
  for k, v in pairs(over or {}) do x[k] = v end
  return x
end

-- The History row and the session row, each bound to `e`.
local function rows(ns, e)
  ns.Browser:Show()
  ns.SessionWindow:Show()
  local hist = ns.LedgerTable:BuildRow()
  hist.item = { kind = "row", entry = e }
  local sess = ns.SessionWindow:BuildRow()
  sess.entry = e
  return { History = hist, session = sess }
end

-- ── Characterization: the item tooltips as they were before the feature ──────────────────────

test("vendor price: a History item row's tooltip is the item link, then the hint line", function()
  local ns, m = fresh()
  local seen = hover(m, rows(ns, entry()).History)
  assertTrue(seen.link ~= nil, "no hyperlink")
  assertTrue(seen.shown, "not shown")
  assertTrue((seen.lines[#seen.lines] or ""):find("Shift-click to link", 1, true) ~= nil,
    "the hint line is not the last line")
end)

test("vendor price: a session item row's tooltip is the item link alone", function()
  local ns, m = fresh()
  local seen = hover(m, rows(ns, entry()).session)
  assertTrue(seen.link ~= nil, "no hyperlink")
  assertEqual(#seen.lines, 0, "the session row wrote lines of its own")
end)

-- ── The feature ───────────────────────────────────────────────────────────────────────────────

local FDB = dofile("tests/_kit/mock_foreverdb.lua")
local Env = dofile("tests/degraded_env.lua")
local FOREVER = T.NS.Compat.ClientKey() == "forever"
local LINE = "Vendor buy price"

-- The line the feature wrote, or nil.
local function priceLine(seen)
  for i, line in ipairs(seen.lines) do
    if tostring(line):find(LINE, 1, true) == 1 then return line, i end
  end
  return nil
end

-- A fresh load with the fake installed in `preset`, a blade row (the fixture's item every vendor
-- source names) bound to both tables, and the fake's handle.
local function withFake(preset, over)
  local ns, m = fresh()
  local fdb = FDB.install(m, { preset = preset })
  local e = entry(over or { itemID = FDB.IDS.blade, itemName = "Fixture Blade",
    itemLink = "|cff1eff00|Hitem:" .. FDB.IDS.blade .. "::::::::70:::::|h[Fixture Blade]|h|r" })
  return ns, m, fdb, rows(ns, e)
end

test("vendor price: declared WoW Forever's alone, its ForClient answer the running client's", function()
  local C = T.NS.Constants
  local clients = C.FEATURE_CLIENTS.vendorBuyPrice
  assertEqual(#clients, 1)
  assertEqual(clients[1], "forever")
  assertEqual(C.FEATURE.vendorBuyPrice, FOREVER)
end)

test("vendor price: the setting is a Forever-only Interface row, on by default", function()
  local ns = fresh()
  assertEqual(ns.defaults.profile.settings.showVendorBuyPrice, true)
  assertEqual(ns.db.profile.settings.showVendorBuyPrice, true)
  local row
  for _, r in ipairs(ns.Schema.Schema or {}) do
    if r.path == "settings.showVendorBuyPrice" then row = r end
  end
  assertTrue(row ~= nil, "no schema row")
  assertEqual(row.group, "Interface")
  assertEqual(row.clients[1], "forever")
  assertTrue(row.tooltip:find("Needs the ForeverDB addon", 1, true) ~= nil,
    "the row does not say the feature needs ForeverDB")
end)

test("vendor price: with ForeverDB, both rows add the lowest vendor price on WoW Forever only", function()
  local ns, m, fdb, r = withFake("present")
  assertEqual(fdb.loads, 0, "ForeverDB loaded before any hover (at file load or login)")
  local want = LINE .. "=" .. ns.Util.FormatMoney(1200)   -- the fixture's cheaper vendor
  local seen = hover(m, r.History)
  local line, at = priceLine(seen)
  if FOREVER then
    assertEqual(line, want)
    assertEqual(at, #seen.lines - 1, "the price is not directly above the hint line")
    assertEqual(fdb.loads, 1, "the first hover did not load ForeverDB exactly once")
  else
    assertEqual(line, nil, "Retail showed a ForeverDB price")
    assertEqual(fdb.loads, 0, "Retail loaded ForeverDB")
  end
  line = priceLine(hover(m, r.session))
  assertEqual(line, FOREVER and want or nil, "the session row")
  assertEqual(fdb.loads, FOREVER and 1 or 0, "a second hover loaded it again")
  fdb.restore()
end)

test("vendor price: an item no vendor sells adds no line", function()
  local _, m, fdb, r = withFake("present", { itemID = FDB.IDS.pebble, itemName = "Fixture Pebble",
    itemLink = "|cff9d9d9d|Hitem:" .. FDB.IDS.pebble .. "::::::::70:::::|h[Fixture Pebble]|h|r" })
  assertEqual(priceLine(hover(m, r.History)), nil)
  assertEqual(priceLine(hover(m, r.session)), nil)
  fdb.restore()
end)

for _, preset in ipairs({ "missing", "loadfails", "reshaped" }) do
  test("vendor price: ForeverDB " .. preset .. " leaves both tooltips exactly as they were", function()
    local _, m, fdb, r = withFake(preset)
    local seen = hover(m, r.History)
    assertEqual(priceLine(seen), nil)
    assertTrue((seen.lines[#seen.lines] or ""):find("Shift-click to link", 1, true) ~= nil, "the hint line moved")
    assertEqual(#hover(m, r.session).lines, 0, "the session row wrote a line")
    if preset == "missing" or not FOREVER then assertEqual(fdb.loads, 0, "a load was attempted") end
    fdb.restore()
  end)
end

test("vendor price: the setting off adds no line and loads nothing", function()
  local ns, m, fdb, r = withFake("present")
  ns.db.profile.settings.showVendorBuyPrice = false
  assertEqual(priceLine(hover(m, r.History)), nil)
  assertEqual(priceLine(hover(m, r.session)), nil)
  assertEqual(fdb.loads, 0, "ForeverDB loaded with the feature off")
  fdb.restore()
end)

test("vendor price: in combat the first hover loads nothing; once loaded, combat still shows it", function()
  local ns, m, fdb, r = withFake("present")
  m.InCombatLockdown = function() return true end
  assertEqual(priceLine(hover(m, r.History)), nil, "a combat hover showed a price before any load")
  assertEqual(fdb.loads, 0, "a combat hover loaded ForeverDB")
  m.InCombatLockdown = function() return false end
  local want = FOREVER and (LINE .. "=" .. ns.Util.FormatMoney(1200)) or nil
  assertEqual(priceLine(hover(m, r.History)), want, "out of combat")
  m.InCombatLockdown = function() return true end
  assertEqual(priceLine(hover(m, r.session)), want, "in combat, once loaded")
  assertEqual(fdb.loads, FOREVER and 1 or 0)
  fdb.restore()
end)

test("vendor price: a gold movement and a row with no item id add no line", function()
  local ns, m, fdb = withFake("present")
  local gold = entry({ kind = "MONEY", itemLink = false, quantity = 500 })
  gold.itemID = nil
  assertEqual(ns.LedgerTable.AddVendorBuyPrice(gold), false)
  assertEqual(ns.LedgerTable.AddVendorBuyPrice(nil), false)
  assertEqual(fdb.loads, 0)
  fdb.restore()
  m.GameTooltip = nil
end)

test("vendor price degraded: the stand-in carries every member the live ForeverDB major exports", function()
  local degraded, dm = Env.loadUpTo("core/ForeverDBSetup.lua", false)
  assertTrue(dm.LibStub("LibKa0s-ForeverDB-1.0", true) == nil,
    "the degraded arm still has the library — this case would prove nothing")
  T.assertSurfaceParity(degraded.ForeverDB, "LibKa0s-ForeverDB-1.0")
  local ok, reason = degraded.ForeverDB.Available()
  assertEqual(ok, false); assertEqual(reason, "missing")
  local price, npc = degraded.ForeverDB.VendorPrice(1)
  assertEqual(price, nil); assertEqual(npc, nil)
end)
