local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function clean()
  NS.db.global.blacklist = {}
  NS.db.global.whitelist = {}
end

test("Filters: an added id reads back as blacklisted", function()
  clean()
  assertTrue(NS.Filters:AddBlacklist(2589))
  assertTrue(NS.Filters:IsBlacklisted(2589))
  clean()
end)

test("Filters: adding the same id twice is a no-op the second time", function()
  clean()
  NS.Filters:AddBlacklist(2589)
  assertFalse(NS.Filters:AddBlacklist(2589), "no change to report")
  clean()
end)

test("Filters: adding to one list removes the id from the other", function()
  clean()
  NS.Filters:AddBlacklist(2589)
  NS.Filters:AddWhitelist(2589)
  assertTrue(NS.Filters:IsWhitelisted(2589))
  assertFalse(NS.Filters:IsBlacklisted(2589), "an id can only be on one list")
  clean()
end)

test("Filters: removing an id that is not on the list reports no change", function()
  clean()
  assertFalse(NS.Filters:RemoveBlacklist(2589))
  clean()
end)

test("Filters: a removed id is no longer blacklisted", function()
  clean()
  NS.Filters:AddBlacklist(2589)
  assertTrue(NS.Filters:RemoveBlacklist(2589))
  assertFalse(NS.Filters:IsBlacklisted(2589))
  clean()
end)

test("Filters: a non-numeric id is rejected rather than stored", function()
  clean()
  assertFalse(NS.Filters:AddBlacklist("not an id"))
  assertEqual(NS.Filters:Count(NS.Filters:Blacklist()), 0)
  clean()
end)

test("Filters: an item link is accepted as an id", function()
  clean()
  local id = NS.Filters:ParseItemID("|cffffffff|Hitem:4306::::::::::|h[Silk Cloth]|h|r")
  assertEqual(id, 4306)
  clean()
end)

test("Filters.ParseItemID accepts a bare number and rejects plain text", function()
  assertEqual(NS.Filters:ParseItemID("2589"), 2589)
  assertEqual(NS.Filters:ParseItemID(2589), 2589)
  assertEqual(NS.Filters:ParseItemID("Linen Cloth"), nil)
end)

test("Filters: a write never mutates the previously stored table in place", function()
  -- Copy-on-write matters because AceDB hands out a SHARED default table: mutating it in place
  -- would poison the default for every later read in the session.
  clean()
  local before = NS.Filters:Blacklist()
  NS.Filters:AddBlacklist(2589)
  assertEqual(before[2589], nil, "the old table is untouched")
  assertTrue(NS.Filters:Blacklist()[2589], "the new table carries the id")
  clean()
end)

test("Filters.SortedIDs returns the ids in ascending order", function()
  clean()
  NS.Filters:AddBlacklist(4306)
  NS.Filters:AddBlacklist(2589)
  NS.Filters:AddBlacklist(19019)
  local ids = NS.Filters:SortedIDs(NS.Filters:Blacklist())
  assertEqual(ids[1], 2589)
  assertEqual(ids[2], 4306)
  assertEqual(ids[3], 19019)
  clean()
end)

test("Filters.ClearList empties one list and reports how many went", function()
  clean()
  NS.Filters:AddBlacklist(2589)
  NS.Filters:AddBlacklist(4306)
  NS.Filters:AddWhitelist(19019)
  assertEqual(NS.Filters:ClearList("blacklist"), 2)
  assertEqual(NS.Filters:Count(NS.Filters:Blacklist()), 0)
  assertEqual(NS.Filters:Count(NS.Filters:Whitelist()), 1, "the sibling list is untouched")
  clean()
end)

test("Filters.ClearList on an empty list reports zero", function()
  clean()
  assertEqual(NS.Filters:ClearList("blacklist"), 0)
  clean()
end)

test("Filters.ClearList ignores an unknown list name", function()
  assertEqual(NS.Filters:ClearList("nonesuch"), 0)
end)

test("Filters.ClearAll empties both lists in one go", function()
  clean()
  NS.Filters:AddBlacklist(2589)
  NS.Filters:AddWhitelist(4306)
  assertEqual(NS.Filters:ClearAll(), 2)
  assertEqual(NS.Filters:Count(NS.Filters:Blacklist()), 0)
  assertEqual(NS.Filters:Count(NS.Filters:Whitelist()), 0)
  clean()
end)

test("Filters: a list change re-caches the capture gate's upvalues", function()
  -- The gate reads cached upvalues for speed, so a list edit that failed to re-cache would leave
  -- the newly blacklisted item recording until the next /reload.
  clean()
  local move = { kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 171276, quantity = 1 }
  assertEqual(NS.Ledger:GateReason(move), nil)
  NS.Filters:AddBlacklist(171276)
  assertEqual(NS.Ledger:GateReason(move), "blacklist", "the gate saw the edit immediately")
  clean()
  NS.Ledger:RefreshUpvalues()
end)
