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

test("ItemSetup: BonusIDsFromLink is on the seam", function()
  -- Item minor 3 (LibKa0s#51). Util.WowheadURL reads its bonus ids through it, so a seam without
  -- it would take the CSV export's URL column down on the install that lacks the member.
  assertTrue(type(NS.Item.BonusIDsFromLink) == "function")
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

test("ItemSetup: this addon now HAS the color fallback it lacked", function()
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

-- ── The library-absent stub ──────────────────────────────────────────────────────────────────
--
-- core/ItemSetup.lua carries a local copy of every primitive for the install where libs/LibKa0s is
-- missing. Both arms come from a real load of the TOC up to core/ItemSetup.lua, once with the
-- library and once without, so the comparison is against the branch that actually runs.

local Env = dofile("tests/degraded_env.lua")

-- Count 2 followed by crafting modifiers (1:28:2437) that must not leak into the bonus list.
local BONUS_FIXTURES = {
  { "a gear link with count 2 then modifiers",
    "|cffa335ee|Hitem:151300::::::::80:250::5:2:12801:13440:1:28:2437|h[Sample Helm]|h|r" },
  { "a bare item string", "item:151300::::::::80:250::5:2:12801:13440" },
  { "a link with no bonuses", "|cff9d9d9d|Hitem:2589::::::::80:250::::::|h[Linen Cloth]|h|r" },
  { "a non-link", "Linen Cloth" },
  { "a non-string", 2589 },
}

test("ItemSetup degraded: BonusIDsFromLink answers what the library answers", function()
  local live = Env.loadUpTo("core/ItemSetup.lua", true)
  local degraded, dm = Env.loadUpTo("core/ItemSetup.lua", false)
  assertTrue(dm.LibStub("LibKa0s-Item-1.0", true) == nil,
    "the degraded arm still has the library — this case would prove nothing")
  for _, f in ipairs(BONUS_FIXTURES) do
    local want, got = live.Item.BonusIDsFromLink(f[2]), degraded.Item.BonusIDsFromLink(f[2])
    if want == nil then
      assertEqual(got, nil, f[1])
    else
      assertEqual(type(got), "table", f[1])
      assertEqual(table.concat(got, ":"), table.concat(want, ":"), f[1])
      assertEqual(#got, #want, f[1])
    end
  end
  -- Pin the contract itself, so the two arms cannot agree on a wrong answer.
  assertEqual(table.concat(degraded.Item.BonusIDsFromLink(BONUS_FIXTURES[1][2]), ":"), "12801:13440")
  assertEqual(#degraded.Item.BonusIDsFromLink(BONUS_FIXTURES[3][2]), 0)
  assertEqual(degraded.Item.BonusIDsFromLink("Linen Cloth"), nil)
end)

test("ItemSetup degraded: the stub carries every member the live Item library exports", function()
  -- testing-§8's stub-surface parity. The stub mirrors the LIBRARY TABLE, so tests/run.lua maps
  -- the major to the mock LibStub's answer for it.
  local degraded = Env.loadUpTo("core/ItemSetup.lua", false)
  T.assertSurfaceParity(degraded.Item, "LibKa0s-Item-1.0")
end)
