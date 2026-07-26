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

test("Constants: the bank group is exactly the six character-bank tabs", function()
  assertEqual(#C.BANK_IDS, 6)
  for _, id in ipairs({ 6, 7, 8, 9, 10, 11 }) do
    assertTrue(contains(C.BANK_IDS, id), "CharacterBankTab id " .. id)
  end
end)

test("Constants: the warband bank spans its five account tabs", function()
  assertEqual(#C.WARBAND_BANK_IDS, 5)
  for _, id in ipairs({ 12, 13, 14, 15, 16 }) do
    assertTrue(contains(C.WARBAND_BANK_IDS, id), "AccountBankTab id " .. id)
  end
end)

test("Constants: no container id belongs to two stores", function()
  -- The defect this guards: a numeric guess put AccountBankTab_1 (12) inside the character-bank
  -- range, so two-thirds of the "character bank" scan was actually the warband bank.
  local owner = {}
  for store, ids in pairs(C.STORE_CONTAINERS) do
    for _, id in ipairs(ids) do
      assertTrue(owner[id] == nil,
        "id " .. id .. " is claimed by both " .. tostring(owner[id]) .. " and " .. store)
      owner[id] = store
    end
  end
end)

test("Constants: no group lists the same id twice", function()
  -- Duplicates silently multiply every stack count in that store, because the scan sums per id.
  for store, ids in pairs(C.STORE_CONTAINERS) do
    local seen = {}
    for _, id in ipairs(ids) do
      assertTrue(not seen[id], store .. " lists id " .. id .. " more than once")
      seen[id] = true
    end
  end
end)

test("Constants: the enum's type constants are never mistaken for containers", function()
  -- Enum.BagIndex carries Characterbanktab = -2 and Accountbanktab = -3 alongside the real
  -- container members. They are types, not containers, and scanning them finds nothing.
  for store, ids in pairs(C.STORE_CONTAINERS) do
    for _, id in ipairs(ids) do
      assertTrue(id ~= -2 and id ~= -3, store .. " picked up a type constant (" .. id .. ")")
    end
  end
end)

test("Constants: a store absent from this build resolves to an empty group", function()
  -- The reagent bank has no container on 12.0.7; it must resolve empty, not to a stray id.
  assertEqual(#C.REAGENT_BANK_IDS, 0)
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

test("Constants: every store has a display colour", function()
  -- The table and the Store dropdown both paint from this one table; a store missing from it would
  -- silently fall back to grey in both.
  for _, key in ipairs(C.StoreOrder) do
    local rgb = C.StoreRGB[key]
    assertTrue(type(rgb) == "table" and #rgb == 3, "no colour for store " .. key)
  end
end)

test("Constants: every direction has a colour and a glyph", function()
  for _, key in ipairs(C.DirectionOrder) do
    assertTrue(type(C.DirectionRGB[key]) == "table", "no colour for direction " .. key)
    assertTrue((C.DirectionGlyph[key] or "") ~= "", "no glyph for direction " .. key)
  end
  -- ▲ leaves the store, ▼ enters it. Swapping them would invert the table's whole visual language.
  assertEqual(C.DirectionGlyph.WITHDRAW, "\226\150\178")
  assertEqual(C.DirectionGlyph.DEPOSIT, "\226\150\188")
end)
