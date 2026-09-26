local _, NS = ...
NS.LedgerTable = NS.LedgerTable or {}
local LT = NS.LedgerTable
local C = NS.Constants

-- The History table's test mode: the synthetic dataset and the one switch that puts it on screen.
-- Peeled out of modules/LedgerTable.lua (anti-pattern #53: that file sat in the 1000-1500 band at
-- two release runs). It is a MOVE, not a rewrite -- the block below reached into none of that file's
-- locals, only into NS, C and LT's own methods (LT:Refresh), which it calls through the shared
-- NS.LedgerTable table. The load order is therefore conventional rather than load-bearing: every
-- caller reaches these methods at run time, never at file load.

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
-- The character bank takes the bulk; the guild bank is the lightest.
local TEST_STORE_W = {
  { "BANK", 38 }, { "WARBAND_BANK", 30 }, { "GUILD_BANK", 24 },
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

-- THE RNG CALL SEQUENCE IS THE CONTRACT for everything below: the dataset is asserted byte-identical
-- run to run, so every helper here consumes the stream at exactly the point the one body it was cut
-- out of did. A helper that draws must therefore stay at its old position in the statement order —
-- never hoisted above a neighbor that also draws, and never sequenced by argument-evaluation order.

-- "MAGE" -> "Mage-Ravencrest". Draws nothing.
local function testCharName(cls)
  return cls:sub(1, 1) .. cls:sub(2):lower() .. "-Ravencrest"
end

-- Only guild-bank rows carry a guild. Draws nothing.
local function testGuild(store)
  return (store == "GUILD_BANK") and "Ka0s" or nil
end

-- ~45% of movements land on a hot item, the rest on the long tail. Draws once or twice.
local function testItemID(rng)
  return (rng(100) <= 45) and rng(TEST_HOT_ITEMS)
         or (TEST_HOT_ITEMS + rng(#TEST_ITEM_NAMES - TEST_HOT_ITEMS))
end

-- Gear moves one at a time; junk moves in big stacks and good stuff in small ones. Draws at most
-- once, and only on the non-gear paths — which is exactly what the original expression did.
local function testQuantity(rng, isGear, quality)
  if isGear then return 1 end
  if quality <= 1 then return 1 + rng(60) end
  return 1 + rng(8)
end

-- Build one entry from the pivot values; everything else is derived and jittered.
-- Draw order: zone -> type -> item id -> second-of-day -> quantity.
local function makeTestEntry(out, rng, now, store, dir, quality, cls, dayOffset)
  local zone = TEST_ZONES[testPick(rng, TEST_ZONE_W)]
  local ty = testPick(rng, TEST_TYPE_W)
  local isGear = (ty == "Armor" or ty == "Weapon")
  local idBase = testItemID(rng)
  local subs = TEST_SUBTYPES[ty]
  local secInto = testPick(rng, TEST_HOUR_W) * 3600 + (rng(60) - 1) * 60 + (rng(60) - 1)
  local quantity = testQuantity(rng, isGear, quality)
  out[#out + 1] = {
    ts = now - dayOffset * TEST_DAY - secInto,
    char = testCharName(cls), classFile = cls,
    kind = C.Kind.ITEM, direction = dir, store = store,
    guild = testGuild(store),
    itemID = 190000 + idBase, itemName = TEST_ITEM_NAMES[idBase], quality = quality,
    itemType = ty, itemSubType = subs[(idBase % #subs) + 1],
    quantity = quantity,
    zone = zone.name, mapID = zone.mapID,
  }
end

-- 1) Coverage seed: every store, both directions, every quality 0-5 and every class appear at least
--    once, and the timestamps walk the full window. seedN is what guarantees all four invariants
--    regardless of how the dice fall.
local function seedCoverage(out, rng, now)
  local stores = { "BANK", "WARBAND_BANK", "GUILD_BANK" }
  local seedN = math.max(#stores, #TEST_CLASSES, 6, TEST_SPAN_DAYS)
  for i = 1, seedN do
    makeTestEntry(out, rng, now,
      stores[((i - 1) % #stores) + 1],
      (i % 2 == 0) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
      (i - 1) % 6,
      TEST_CLASSES[((i - 1) % #TEST_CLASSES) + 1],
      (i - 1) % TEST_SPAN_DAYS)
  end
end

-- 2) Weighted bulk: deposits outnumber withdrawals, as a real bank does, and a third of the
--    movements cluster onto the last few days.
local function bulkMovements(out, rng, now)
  for _ = 1, 220 do
    local dayOffset = rng(TEST_SPAN_DAYS) - 1
    if rng(3) == 1 then dayOffset = rng(5) - 1 end
    makeTestEntry(out, rng, now,
      testPick(rng, TEST_STORE_W),
      (rng(10) <= 6) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
      testPick(rng, TEST_QUALITY_W), testPick(rng, TEST_CLASS_W), dayOffset)
  end
end

-- 3) Gold movements, at the two stores that hold coin.
-- Draw order: class -> zone -> ts day -> ts seconds -> direction -> amount. The store comes from
-- the loop index, not the dice.
local function goldMovements(out, rng, now)
  for i = 1, 30 do
    local store = (i % 2 == 0) and "WARBAND_BANK" or "GUILD_BANK"
    local cls = testPick(rng, TEST_CLASS_W)
    local zone = TEST_ZONES[testPick(rng, TEST_ZONE_W)]
    out[#out + 1] = {
      ts = now - (rng(TEST_SPAN_DAYS) - 1) * TEST_DAY - rng(80000),
      char = testCharName(cls), classFile = cls,
      kind = C.Kind.MONEY,
      direction = (rng(10) <= 7) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
      store = store,
      guild = testGuild(store),
      itemName = "Gold", quantity = rng(500) * 10000,
      zone = zone.name, mapID = zone.mapID,
    }
  end
end

function LT:BuildTestData()
  local now = time()
  local rng = testRng(0x0BA17ED9)   -- fixed seed -> an identical dataset every run
  local out = {}
  seedCoverage(out, rng, now)
  bulkMovements(out, rng, now)
  goldMovements(out, rng, now)
  return out
end

-- Is the sample dataset on screen? DERIVED from the one stored fact rather than tracked beside it,
-- so a flag and a dataset can never disagree — and every write path can ask the same question the
-- read paths already answer through State.
function LT:IsTestMode()
  return NS.State.testRecords ~= nil
end

-- Set test mode to a VALUE. The one path the Master controls `Test mode` checkbox, `/bl test` and the
-- combat ending all take (options-ui-§15, standard v2.47.0). Publishing the dataset to State means
-- every read-path query -- the table AND Insights -- resolves against the same data, through the real
-- render path (test-mode).
--
-- Answers IsTestMode(), and on a refused start a second value: the one line saying why, for the
-- caller to print. Asking for the state already in force changes nothing and builds nothing.
--
-- A START opens the ledger window, because the sample is only worth anything on screen. It is refused
-- in combat (combat ends test mode, so one started inside a fight would be the one that covers it) and
-- when General visibility would keep the window shut (B:Show refuses then, and a sample loaded behind
-- a window that will not open is test mode on with nothing to show for it). A STOP never opens
-- anything: the combat ending comes through here, and a window popping open on the pull is exactly
-- what options-ui-§2 refuses.
--
-- Every change repaints an open settings panel, so the checkbox follows the starts and stops it did
-- not make itself.
function LT:SetTestMode(on)
  on = on and true or false
  if on == self:IsTestMode() then return on end
  if on then
    if InCombatLockdown and InCombatLockdown() then
      return false, "cannot start test mode during combat."
    end
    if NS.Util.VisibilityAllows and not NS.Util.VisibilityAllows() then
      return false, "cannot start test mode \226\128\148 General visibility is keeping the ledger "
        .. "window closed."
    end
    NS.State.testRecords = self:BuildTestData()
    if NS.Browser and NS.Browser.Show then NS.Browser:Show() end
  else
    NS.State.testRecords = nil
  end
  if NS.Browser and NS.Browser.OnDatasetChanged then
    NS.Browser:OnDatasetChanged()
  else
    self:Refresh()
  end
  if NS.Panel and NS.Panel.Refresh then NS.Panel:Refresh() end
  return self:IsTestMode()
end

-- `/bl test`: flip it. Same answers as SetTestMode, refusal line included.
function LT:ToggleTestMode()
  return self:SetTestMode(not self:IsTestMode())
end
