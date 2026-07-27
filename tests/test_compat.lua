local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("Compat.ItemIDFromLink pulls the id out of a full item link", function()
  assertEqual(NS.Compat.ItemIDFromLink(
    "|cffffffff|Hitem:2589::::::::::|h[Linen Cloth]|h|r"), 2589)
end)

test("Compat.ItemIDFromLink accepts a bare itemString", function()
  assertEqual(NS.Compat.ItemIDFromLink("item:19019::::::::::"), 19019)
end)

test("Compat.ItemIDFromLink returns nil for anything that is not a link", function()
  assertEqual(NS.Compat.ItemIDFromLink("Linen Cloth"), nil)
  assertEqual(NS.Compat.ItemIDFromLink(nil), nil)
  assertEqual(NS.Compat.ItemIDFromLink(2589), nil)
end)

test("Compat.QualityLabel maps a quality id to its English name", function()
  assertEqual(NS.Compat.QualityLabel(0), "Poor")
  assertEqual(NS.Compat.QualityLabel(4), "Epic")
end)

test("Compat.QualityLabel defaults to Poor when given nothing", function()
  assertEqual(NS.Compat.QualityLabel(nil), "Poor")
end)

test("Compat.GetItemDetails returns name, quality, type, subtype and vendor price", function()
  local name, quality, itemType, itemSubType = NS.Compat.GetItemDetails(171276)
  assertEqual(name, "Spectral Flask")
  assertEqual(quality, 3)
  assertEqual(itemType, "Consumable")
  assertEqual(itemSubType, "Flask")
end)

test("Compat.GetItemDetails returns nil for an item the client has not cached", function()
  assertEqual(NS.Compat.GetItemDetails(999999), nil)
end)

test("Compat.ItemNameQuality resolves an id the client knows", function()
  local name, quality = NS.Compat.ItemNameQuality(2589)
  assertEqual(name, "Linen Cloth")
  assertEqual(quality, 1)
end)

test("Compat.GetContainerNumSlots reports zero for an unreachable container", function()
  assertEqual(NS.Compat.GetContainerNumSlots(-99), 0)
end)

test("Compat.GetContainerSlot returns a normalized triple for a filled slot", function()
  mocks.__containers[0] = { slots = 1, [1] = { itemID = 4306, link = "L", count = 9 } }
  local info = NS.Compat.GetContainerSlot(0, 1)
  assertEqual(info.itemID, 4306)
  assertEqual(info.count, 9)
  assertEqual(info.link, "L")
  mocks.__containers[0] = nil
end)

test("Compat.GetContainerSlot returns nil for an empty slot", function()
  assertEqual(NS.Compat.GetContainerSlot(0, 1), nil)
end)

test("Compat.GetZone returns the zone and subzone", function()
  local zone, subzone = NS.Compat.GetZone()
  assertEqual(zone, "Testville")
  assertEqual(subzone, "The Vault")
end)

test("Compat.GetGuildName returns the player's guild", function()
  assertEqual(NS.Compat.GetGuildName(), "Ka0s")
end)

test("Compat.GetMoney reads the carried balance", function()
  local saved = mocks.__money
  mocks.__money = 777
  assertEqual(NS.Compat.GetMoney(), 777)
  mocks.__money = saved
end)

test("Compat.GetPlayerMapID returns the current map id", function()
  assertEqual(NS.Compat.GetPlayerMapID(), 2657)
end)

test("Compat.GetAddOnMetadata degrades to nil when neither getter exists", function()
  -- Neither C_AddOns nor the bare global is stubbed, so the shim must return nil rather than raise.
  assertTrue(NS.Compat.GetAddOnMetadata("BankLedger", "Version") == nil)
end)
