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
