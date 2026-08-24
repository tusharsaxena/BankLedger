-- tests/test_itemsetup.lua — the LibKa0s-Item-1.0 seam.
--
-- What is NOT here is the point: no case about resolving an item, because this addon's resolver
-- did not move. Compat.GetItemDetails still refuses an uncached item and records the skip, and
-- that refusal is this addon's policy (F-006), not the library's business.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local EPIC_LINK =
  "|cffa335ee|Hitem:258586::::::::80:250::5:3:10356:10355:1540:1:28:2462:::|h[Bloodfeather Chestguard]|h|r"

test("ItemSetup: the seam is published", function()
  assertTrue(type(NS.Item) == "table")
  assertTrue(type(NS.Item.ItemIDFromLink) == "function")
  assertTrue(type(NS.Item.QualityFromLink) == "function")
  assertTrue(type(NS.Item.QualityLabel) == "function")
  assertTrue(type(NS.Item.LoadItem) == "function")
end)

test("ItemSetup: the primitives answer what the deleted shims answered", function()
  assertEqual(NS.Item.ItemIDFromLink(EPIC_LINK), 258586)
  assertEqual(NS.Item.QualityLabel(4), "Epic")
  assertEqual(NS.Item.QualityLabel(nil), "Poor")
end)

-- The three cases below moved here verbatim from tests/test_compat.lua, where they covered
-- Compat.ItemIDFromLink and Compat.QualityLabel. Moved, not duplicated: the shims they named are
-- gone, and the primitives they describe now live behind the seam.
test("ItemSetup: ItemIDFromLink pulls the id out of a full item link", function()
  assertEqual(NS.Item.ItemIDFromLink(
    "|cffffffff|Hitem:2589::::::::::|h[Linen Cloth]|h|r"), 2589)
end)

test("ItemSetup: ItemIDFromLink accepts a bare itemString", function()
  assertEqual(NS.Item.ItemIDFromLink("item:19019::::::::::"), 19019)
end)

test("ItemSetup: ItemIDFromLink returns nil for anything that is not a link", function()
  assertEqual(NS.Item.ItemIDFromLink("Linen Cloth"), nil)
  assertEqual(NS.Item.ItemIDFromLink(nil), nil)
  assertEqual(NS.Item.ItemIDFromLink(2589), nil)
end)

test("ItemSetup: QualityLabel maps a quality id to its English name", function()
  assertEqual(NS.Item.QualityLabel(0), "Poor")
  assertEqual(NS.Item.QualityLabel(4), "Epic")
end)

test("ItemSetup: this addon now HAS the colour fallback it lacked", function()
  -- QualityFromLink was LootHistory-only before the library. It is the primitive whose absence let
  -- an upgrade-track drop read back at its base quality; having it here does not change the gate's
  -- policy, it just means the addon can see the quality when it chooses to.
  assertEqual(NS.Item.QualityFromLink(EPIC_LINK), 4)
end)

test("ItemSetup: the resolver did NOT move", function()
  -- Deliberate. Compat.GetItemDetails refuses an uncached item and records "uncached" rather than
  -- guessing, and LootHistory's resolver guesses. Both are right for their addon, and a shared
  -- resolver would have overturned one of them.
  assertTrue(type(NS.Compat.GetItemDetails) == "function", "the resolver stays in Compat")
  assertTrue(type(NS.Compat.ItemNameQuality) == "function", "and so does ItemNameQuality")
end)

test("ItemSetup: the moved shims are gone from Compat", function()
  assertEqual(NS.Compat.ItemIDFromLink, nil)
  assertEqual(NS.Compat.QualityLabel, nil)
  assertEqual(NS.Compat.LoadItem, nil)
end)
