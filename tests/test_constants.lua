local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local C = NS.Constants

local function contains(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

test("Constants: every Store enum member appears in the display order", function()
  for key in pairs(C.Store) do
    assertTrue(contains(C.StoreOrder, key), key .. " is missing from StoreOrder")
  end
end)

test("Constants: every Store enum member has a display label", function()
  for key in pairs(C.Store) do
    assertTrue(C.StoreLabel[key] ~= nil, key .. " has no label")
  end
end)

test("Constants: every Store enum value equals its key (the stable stored form)", function()
  for key, value in pairs(C.Store) do assertEqual(value, key) end
end)

test("Constants: every Direction enum member has a label and a sign", function()
  for key in pairs(C.Direction) do
    assertTrue(C.DirectionLabel[key] ~= nil, key .. " has no label")
    assertTrue(C.DirectionSign[key] ~= nil, key .. " has no sign")
  end
end)

test("Constants: a deposit signs positive and a withdrawal negative", function()
  assertEqual(C.DirectionSign.DEPOSIT, 1)
  assertEqual(C.DirectionSign.WITHDRAW, -1)
end)

test("Constants: every Kind has a label, including the reserved CURRENCY", function()
  for key in pairs(C.Kind) do
    assertTrue(C.KindLabel[key] ~= nil, key .. " has no label")
  end
end)

test("Constants: the bag id group covers the backpack, four bags and the reagent bag", function()
  assertEqual(#C.BAG_IDS, 6)
  assertTrue(contains(C.BAG_IDS, 0), "the backpack")
  assertTrue(contains(C.BAG_IDS, 5), "the reagent bag")
end)

test("Constants: the bank id group includes the classic bank container", function()
  assertTrue(contains(C.BANK_IDS, -1), "the classic bank container id")
end)

test("Constants: the warband bank spans its five account tabs", function()
  assertEqual(#C.WARBAND_BANK_IDS, 5)
end)

test("Constants: every container-backed store maps to a non-empty id list", function()
  for store, ids in pairs(C.STORE_CONTAINERS) do
    assertTrue(#ids > 0, store .. " has no container ids")
  end
end)

test("Constants: the guild bank and void storage are NOT container-id scanned", function()
  -- They have their own API families and are read through Compat instead.
  assertEqual(C.STORE_CONTAINERS.GUILD_BANK, nil)
  assertEqual(C.STORE_CONTAINERS.VOID_STORAGE, nil)
end)

test("Constants: the store mute options exclude BAGS", function()
  -- Bags are the counterparty of every movement, so muting them would mute everything.
  for _, opt in ipairs(C.STORE_OPTIONS) do
    assertTrue(opt.value ~= "BAGS", "BAGS must not be a mutable store")
  end
end)

test("Constants: every quality option carries a numeric value and a label", function()
  assertTrue(#C.QUALITY_OPTIONS > 0)
  for _, opt in ipairs(C.QUALITY_OPTIONS) do
    assertEqual(type(opt.value), "number")
    assertTrue(opt.label ~= nil and opt.label ~= "")
  end
end)

test("Constants: the retention presets offer an 'Always' (0) option", function()
  local found = false
  for _, opt in ipairs(C.RETENTION_OPTIONS) do
    if opt.value == 0 then found = true; assertEqual(opt.label, "Always") end
  end
  assertTrue(found, "a 0-day 'Always' preset")
end)
