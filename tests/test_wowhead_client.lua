-- tests/test_wowhead_client.lua — the Wowhead link base per client (WoW Forever port, owner ruling
-- R7; clients-§5). Retail keeps https://www.wowhead.com/item=; WoW Forever item ids are Forever's
-- own, so its links go to https://www.wowhead.com/forever/item=. The base is a per-client table
-- picked once at load by ClientKey(), and the one builder (Util.WowheadURL) is what the CSV
-- export's `wowhead` column calls. Every case runs on both kit profiles
-- (`KA0S_KIT_CLIENT=forever lua tests/run.lua`) and asserts the client's own answer.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local U = NS.Util
local FOREVER = NS.Compat.ClientKey() == "forever"
local RETAIL_BASE = "https://www.wowhead.com/item="
local FOREVER_BASE = "https://www.wowhead.com/forever/item="
local BASE = FOREVER and FOREVER_BASE or RETAIL_BASE

test("wowhead: the item URL base is a per-client table picked once by ClientKey()", function()
  local rows = U.WOWHEAD_ITEM_URL_BY_CLIENT
  assertTrue(type(rows) == "table", "Util.WOWHEAD_ITEM_URL_BY_CLIENT")
  assertEqual(rows.retail, RETAIL_BASE, "Retail is unchanged")
  assertEqual(rows.forever, FOREVER_BASE, "WoW Forever uses the forever path (R7)")
  assertEqual(U.WOWHEAD_ITEM_URL, rows[NS.Compat.ClientKey()], "the client's row is the one used")
end)

test("wowhead: Util.WowheadURL builds on the client's base", function()
  assertEqual(U.WowheadURL({ itemID = 2589 }), BASE .. "2589")
end)

test("wowhead: the bonus query rides on the client's base", function()
  assertEqual(U.WowheadURL({ itemLink = "item:151300::::::::80:250::5:2:12801:13440" }),
    BASE .. "151300?bonus=12801:13440")
end)

test("wowhead: a link with no bonuses gives a plain item URL on the client's base", function()
  -- The shape of a classic-era item link: no bonus list at all.
  assertEqual(U.WowheadURL({ itemLink = "|cffffffff|Hitem:2589::::::::60:::::|h[Linen Cloth]|h|r" }),
    BASE .. "2589")
end)

test("wowhead: the CSV export's wowhead column carries the client's base", function()
  local csv = NS.Export:CSV({ { ts = 1, char = "Mock", direction = "DEPOSIT", store = "BANK",
    kind = "ITEM", itemID = 2589, itemName = "Linen Cloth", quantity = 1 } })
  local row = csv:match("\r?\n([^\r\n]+)")
  assertTrue(row ~= nil, "a data row")
  assertEqual(row:match("([^,]*)$"), BASE .. "2589")
end)

test("wowhead: no gold row gets a URL on either client", function()
  assertEqual(U.WowheadURL({ kind = "MONEY", itemName = "Gold" }), "")
end)
