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

-- THE SEEDS ARE PER CLIENT (BL-09; clients-§5): one row per client, picked ONCE at load by the
-- sample key core/SimSetup.lua seeded from ClientKey() (NS.SAMPLE_CLIENT). Retail's row is the
-- pre-port data, unchanged, so its dataset is byte-identical (tests/test_testmode_client.lua pins
-- it). WoW Forever has the nine classic classes, so its row has no Evoker: a Warlock takes the slot
-- and the weight, keeping eight characters and the same draw shape. Its zones are the classic
-- capitals with the uiMapIDs the Forever client answers (1453-1458, SkillMaster's
-- defaults/Trainers_Forever.lua precedent), weighted as Retail's are. `ownChars` is this ledger's
-- own name for each class the shared sample set has none of (see THE SAMPLE CHARACTERS below).
local TEST_SEEDS_BY_CLIENT = {
  retail = {
    classes = { "MAGE", "PALADIN", "ROGUE", "PRIEST", "DRUID", "WARRIOR", "SHAMAN", "EVOKER" },
    -- A few "mains" do most of the banking.
    classWeights = {
      { "MAGE", 16 }, { "PALADIN", 13 }, { "ROGUE", 11 }, { "PRIEST", 9 },
      { "DRUID", 8 }, { "WARRIOR", 8 }, { "SHAMAN", 6 }, { "EVOKER", 5 },
    },
    zones = {
      { name = "Valdrakken",       mapID = 2112 },
      { name = "Dornogal",         mapID = 2339 },
      { name = "Orgrimmar",        mapID = 85 },
      { name = "Stormwind City",   mapID = 84 },
      { name = "Silvermoon City",  mapID = 110 },
      { name = "Boralus",          mapID = 1161 },
    },
    ownChars = {
      ROGUE  = "Mockshade-Samplerealm",
      DRUID  = "Samplegrove-Mockrealm",
      SHAMAN = "Mocktotem-Samplerealm",
      EVOKER = "Samplescale-Mockrealm",
    },
  },
  forever = {
    classes = { "MAGE", "PALADIN", "ROGUE", "PRIEST", "DRUID", "WARRIOR", "SHAMAN", "WARLOCK" },
    classWeights = {
      { "MAGE", 16 }, { "PALADIN", 13 }, { "ROGUE", 11 }, { "PRIEST", 9 },
      { "DRUID", 8 }, { "WARRIOR", 8 }, { "SHAMAN", 6 }, { "WARLOCK", 5 },
    },
    zones = {
      { name = "Ironforge",        mapID = 1455 },
      { name = "Orgrimmar",        mapID = 1454 },
      { name = "Undercity",        mapID = 1458 },
      { name = "Stormwind City",   mapID = 1453 },
      { name = "Thunder Bluff",    mapID = 1456 },
      { name = "Darnassus",        mapID = 1457 },
    },
    ownChars = {
      ROGUE   = "Mockshade Samplestep",
      DRUID   = "Samplegrove Mockbark",
      SHAMAN  = "Mocktotem Sampletide",
      WARLOCK = "Samplehex Mockember",
    },
  },
}
local TEST_SEEDS = TEST_SEEDS_BY_CLIENT[NS.SAMPLE_CLIENT == "forever" and "forever" or "retail"]
LT.TEST_SEEDS_BY_CLIENT, LT.TEST_SEEDS = TEST_SEEDS_BY_CLIENT, TEST_SEEDS   -- read-only, for the tests

local TEST_CLASSES = TEST_SEEDS.classes
local TEST_CLASS_W = TEST_SEEDS.classWeights
local TEST_ZONES = TEST_SEEDS.zones
local TEST_ZONE_W = { { 1, 26 }, { 2, 20 }, { 4, 16 }, { 3, 14 }, { 5, 12 }, { 6, 8 } }
-- The character bank takes the bulk; the guild bank is the lightest. Per client: the Warband Bank is
-- Retail's alone (C.FEATURE.warbandBank, ruling R1), so on WoW Forever the dataset has no row there,
-- its coverage seed walks the two stores that exist and every gold movement is the guild bank's.
local WARBAND = C.FEATURE.warbandBank
local TEST_STORE_W = WARBAND and {
  { "BANK", 38 }, { "WARBAND_BANK", 30 }, { "GUILD_BANK", 24 },
} or {
  { "BANK", 38 }, { "GUILD_BANK", 24 },
}
local TEST_COVER_STORES = WARBAND and { "BANK", "WARBAND_BANK", "GUILD_BANK" } or { "BANK", "GUILD_BANK" }
local TEST_GOLD_ALT = WARBAND and "WARBAND_BANK" or "GUILD_BANK"
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

-- THE SAMPLE CHARACTERS (LibKa0s#87, preview-mode's sample-character convention). A class's
-- character is the collection's shared one where the set has that class (core/SimSetup.lua's
-- NS.SampleCharacterOf: Mockflame-Mockrealm the mage, Sampleblade-Samplerealm the paladin,
-- Samplemender-Samplerealm the priest, Mockshield-Mockrealm the warrior), and this ledger's own
-- name for the four classes it has none of. Every name starts Sample or Mock, every realm is
-- Samplerealm or Mockrealm, never a real one; names are data and never localized. The own names are
-- per client like the shared set (BL-02; clients-§5), picked once at load by the key core/SimSetup.lua
-- seeded: "Name-Realm" on Retail, "First Surname" on WoW Forever (forever-quirks-§4). They live in
-- the client's seed row above (BL-09), with the class list they name.
local TEST_OWN_CHARS = TEST_SEEDS.ownChars
local TEST_GUILD = "Sample Company"

-- "MAGE" -> "Mockflame-Mockrealm". Draws nothing.
local function testCharName(cls)
  local shared = NS.SampleCharacterOf(cls)
  return shared and shared.fullName or TEST_OWN_CHARS[cls]
end

-- Only guild-bank rows carry a guild. Draws nothing.
local function testGuild(store)
  return (store == "GUILD_BANK") and TEST_GUILD or nil
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
  local stores = TEST_COVER_STORES
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

-- 3) Gold movements, at the stores that hold coin (the guild bank alone on WoW Forever).
-- Draw order: class -> zone -> ts day -> ts seconds -> direction -> amount. The store comes from
-- the loop index, not the dice.
local function goldMovements(out, rng, now)
  for i = 1, 30 do
    local store = (i % 2 == 0) and TEST_GOLD_ALT or "GUILD_BANK"
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
-- while a simulation runs (the two datasets are exclusive), in combat (combat ends test mode, so one started inside a fight would be the one that covers it) and
-- when General visibility would keep the window shut (B:Show refuses then, and a sample loaded behind
-- a window that will not open is test mode on with nothing to show for it). A STOP never opens
-- anything: the combat ending comes through here, and a window popping open on the pull is exactly
-- what options-ui-§2 refuses.
--
-- Every change repaints an open settings panel, so the checkbox follows the starts and stops it did
-- not make itself.
--
-- Each outcome is one `[Table]` line (debug-logging-§8): the dataset swap is the material effect a
-- reader cannot infer from the `[Set] state.testMode` line (debug-logging-§10), `/bl test` writes no
-- `[Set]` line at all, and a refused start names its guard.

-- Why a start is refused, or nil: the player's line, and the guard for the trace.
local function startRefusal()
  -- A simulation and test mode are exclusive (Sim-1.0 host contract H5): each refuses while the
  -- other runs, so the window's dataset is never both at once (BankLedger#24).
  if NS.Sim and NS.Sim:IsActive() then
    return NS.L["Stop the simulation before turning on test mode."], "simulation"
  end
  if InCombatLockdown and InCombatLockdown() then
    return "cannot start test mode during combat.", "combat"
  end
  if NS.Util.VisibilityAllows and not NS.Util.VisibilityAllows() then
    return "cannot start test mode \226\128\148 General visibility is keeping the ledger "
      .. "window closed.", "visibility"
  end
end

local function traceTestMode(on, rows, guard)
  if not (NS.State.debug and NS.Debug) then return end
  if guard == "combat" then
    NS.Debug("Table", "test mode start refused: in combat")
  elseif guard == "simulation" then
    NS.Debug("Table", "test mode start refused: a simulation is running")
  elseif guard then
    NS.Debug("Table", "test mode start refused: %s",
      tostring(NS.Util.VisibilityRefusal and NS.Util.VisibilityRefusal()))
  elseif on then
    NS.Debug("Table", "test mode on: %s sample rows", tostring(rows))
  else
    NS.Debug("Table", "test mode off")
  end
end

function LT:SetTestMode(on)
  on = on and true or false
  if on == self:IsTestMode() then return on end
  if on then
    local refusal, guard = startRefusal()
    if refusal then
      traceTestMode(on, nil, guard)
      return false, refusal
    end
    NS.State.testRecords = self:BuildTestData()
    traceTestMode(on, #NS.State.testRecords)
    if NS.Browser and NS.Browser.Show then NS.Browser:Show() end
  else
    NS.State.testRecords = nil
    traceTestMode(on)
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
