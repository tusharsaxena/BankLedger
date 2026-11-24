-- tests/test_testmode_client.lua — test mode's seeds are per client (WoW Forever port design, the
-- per-client tables; clients-§5): modules/LedgerTable_TestMode.lua picks its class list, class
-- weights and zones ONCE at load, by the sample key core/SimSetup.lua seeded (NS.SAMPLE_CLIENT, from
-- ClientKey()). WoW Forever has the nine classic classes, so its row has no Evoker (a Warlock takes
-- the slot), and its zones are the classic capitals with the uiMapIDs the Forever client answers
-- (SkillMaster/defaults/Trainers_Forever.lua's precedent). Retail's dataset is pinned row for row
-- below: the port moved no Retail byte, and FB2-BL-01 (LibKa0s#104) moved only the four crowd
-- characters' names, now the library's seeded crowd rather than the ledger's own list. Every case
-- runs on both kit profiles (`KA0S_KIT_CLIENT=forever lua tests/run.lua`).

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local LT = NS.LedgerTable
local FOREVER = NS.Compat.ClientKey() == "forever"

-- The classes WoW Forever has (the classic nine; DropWatcher/core/ClassDataForever.lua's list).
local FOREVER_CLASSES = {
  WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
  SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true,
}

local function set(list)
  local out = {}
  for _, v in ipairs(list) do out[v] = true end
  return out
end

test("test mode: the seeds are a per-client table picked once by the sample key", function()
  local rows = LT.TEST_SEEDS_BY_CLIENT
  assertTrue(type(rows) == "table", "LT.TEST_SEEDS_BY_CLIENT")
  assertTrue(type(rows.retail) == "table" and type(rows.forever) == "table", "a row per client")
  assertTrue(LT.TEST_SEEDS == rows[NS.SAMPLE_CLIENT], "the seeds in force are not this client's row")
  assertEqual(NS.SAMPLE_CLIENT, FOREVER and "forever" or "retail")
end)

test("test mode: Retail's seed row is the pre-port data, Evoker and the modern capitals included", function()
  local r = LT.TEST_SEEDS_BY_CLIENT.retail
  assertEqual(table.concat(r.classes, ","), "MAGE,PALADIN,ROGUE,PRIEST,DRUID,WARRIOR,SHAMAN,EVOKER")
  local zones = {}
  for _, z in ipairs(r.zones) do zones[#zones + 1] = z.name .. "=" .. z.mapID end
  assertEqual(table.concat(zones, ","),
    "Valdrakken=2112,Dornogal=2339,Orgrimmar=85,Stormwind City=84,Silvermoon City=110,Boralus=1161")
end)

test("test mode: WoW Forever's seed row has only the classic classes, no Evoker", function()
  local f = LT.TEST_SEEDS_BY_CLIENT.forever
  for _, cls in ipairs(f.classes) do
    assertTrue(FOREVER_CLASSES[cls], cls .. " is not a WoW Forever class")
  end
  for _, e in ipairs(f.classWeights) do
    assertTrue(FOREVER_CLASSES[e[1]], e[1] .. " is weighted but not a WoW Forever class")
  end
  assertTrue(not set(f.classes).EVOKER, "an Evoker on WoW Forever")
  assertEqual(#f.classes, #LT.TEST_SEEDS_BY_CLIENT.retail.classes, "the same eight characters on both")
end)

test("test mode: WoW Forever's zones are the classic capitals, none of Retail's", function()
  local f, r = LT.TEST_SEEDS_BY_CLIENT.forever, LT.TEST_SEEDS_BY_CLIENT.retail
  local retailIDs = {}
  for _, z in ipairs(r.zones) do retailIDs[z.mapID] = true end
  assertEqual(#f.zones, #r.zones)
  for _, z in ipairs(f.zones) do
    assertTrue(not retailIDs[z.mapID], z.name .. " carries a Retail uiMapID")
    assertTrue(z.mapID >= 1453 and z.mapID <= 1458, z.name .. " is not a classic capital's uiMapID")
  end
  for _, z in ipairs(f.zones) do assertTrue(z.name ~= "Valdrakken" and z.name ~= "Dornogal", z.name) end
end)

test("test mode: every class in each row has a library character, shared or from the seeded crowd", function()
  local Sim = mocks.LibStub("LibKa0s-Sim-1.0")
  for client, row in pairs(LT.TEST_SEEDS_BY_CLIENT) do
    assertEqual(row.ownChars, nil, client .. ": a hand-kept name list is back (LibKa0s#104)")
    for _, cls in ipairs(row.classes) do
      local found
      for _, s in ipairs(Sim.Sample(client)) do
        if s.classFile == cls then found = s.fullName end
      end
      if not found then
        for _, c in ipairs(Sim.SampleCrowd(client, Sim.CROWD_MAX, LT.TEST_CROWD_SEED)) do
          if c.classFile == cls then found = c.fullName break end
        end
      end
      assertTrue(found ~= nil, client .. " " .. cls .. " has no character")
      assertEqual(found:find(" ", 1, true) ~= nil, client == "forever", client .. " " .. found .. "'s shape")
    end
  end
end)

test("test mode: the dataset's classes and zones are this client's own", function()
  local classes, zones = set(LT.TEST_SEEDS.classes), {}
  for _, z in ipairs(LT.TEST_SEEDS.zones) do zones[z.name] = z.mapID end
  local seenEvoker = false
  for _, x in ipairs(LT:BuildTestData()) do
    assertTrue(classes[x.classFile], tostring(x.classFile) .. " is not in this client's class list")
    assertEqual(zones[x.zone], x.mapID, tostring(x.zone) .. "'s mapID")
    if x.classFile == "EVOKER" then seenEvoker = true end
  end
  assertEqual(seenEvoker, not FOREVER, "Evoker rows on Retail, none on WoW Forever")
end)

-- One line per row, every field but the absolute timestamp (which is relative to time()).
local function fingerprint(rows)
  local now = mocks.time()
  local h = 5381
  for _, x in ipairs(rows) do
    local line = table.concat({
      tostring(now - x.ts), tostring(x.char), tostring(x.classFile), tostring(x.kind),
      tostring(x.direction), tostring(x.store), tostring(x.guild), tostring(x.itemID),
      tostring(x.itemName), tostring(x.quality), tostring(x.itemType), tostring(x.itemSubType),
      tostring(x.quantity), tostring(x.zone), tostring(x.mapID),
    }, "|")
    for i = 1, #line do h = (h * 33 + line:byte(i)) % 2147483647 end
  end
  return h
end

test("test mode: Retail's dataset is pinned, row for row (the crowd's names since FB2-BL-01)", function()
  local rows = LT:BuildTestData()
  assertEqual(#rows, 271)
  assertEqual(fingerprint(rows), 931075551)
end, (FOREVER and "Retail-only: pins Retail's pre-port dataset" or nil))

test("test mode: WoW Forever's dataset is deterministic across runs", function()
  assertEqual(fingerprint(LT:BuildTestData()), fingerprint(LT:BuildTestData()))
end)
