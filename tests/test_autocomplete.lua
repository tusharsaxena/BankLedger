local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The search box's autocomplete (P9): the seam (B:MakeAutocomplete), the list's placement under
-- the search box, the provider (B.SuggestNames: distinct names under the other filters, from the
-- dataset on screen, test mode included) and the pick (B.PickName / B:SetSearchText).
--
-- The list widget itself (keyboard, focus, debounce, pooling) is LibKa0s-Widgets-1.0's and pinned
-- by the library's own suite; this one pins what this addon feeds it and does with a pick. Every
-- case runs through `case`, which puts back the ledger, test mode and the filter bar.

local mocks = T.mocks
local B = NS.Browser

-- Two Linen rows (one name, offered once), a Silk row in another store, a gold movement, an item
-- whose name holds "li" past its start, one that holds no "li" at all, and a name the test-mode
-- sample never uses.
local ROWS = {
  { itemID = 2589, itemName = "Linen Cloth", quality = 1, store = "BANK", itemType = "Tradegoods" },
  { itemID = 2589, itemName = "Linen Cloth", quality = 1, store = "BANK", itemType = "Tradegoods" },
  { itemID = 4306, itemName = "Silk Cloth", quality = 1, store = "WARBAND_BANK", itemType = "Tradegoods" },
  { itemID = 6948, itemName = "Hearthstone", quality = 1, store = "BANK", itemType = "Misc" },
  { itemID = 7000, itemName = "Flask of Lightning", quality = 3, store = "BANK", itemType = "Consumable" },
  { itemID = 7001, itemName = "Qwerty Ledger Orb", quality = 4, store = "BANK", itemType = "Misc" },
}

local function seed()
  NS.db.global.ledger = {}
  for i, r in ipairs(ROWS) do
    NS.Database:Add({
      ts = 1770000000 + i, char = "Mock-Realm", classFile = "MAGE",
      kind = "ITEM", direction = "DEPOSIT", store = r.store,
      itemID = r.itemID, itemName = r.itemName, quality = r.quality,
      itemType = r.itemType, quantity = 1, zone = "Testville", mapID = 2657,
    })
  end
  NS.Database:Add({
    ts = 1770000100, char = "Mock-Realm", classFile = "MAGE",
    kind = "MONEY", direction = "DEPOSIT", store = "GUILD_BANK",
    itemName = "Gold", quantity = 50000, zone = "Testville", mapID = 2657,
  })
end

local function case(name, fn)
  test(name, function()
    local savedLedger = NS.db.global.ledger
    local wasTest = NS.LedgerTable:IsTestMode()
    seed()
    B:Show()
    B:RefreshFilterOptions()
    B:ApplyView(nil, "all")
    local ok, err = pcall(fn)
    if B._autocomplete then B._autocomplete:Close() end
    if NS.LedgerTable:IsTestMode() ~= wasTest then NS.LedgerTable:SetTestMode(wasTest) end
    NS.db.global.ledger = savedLedger
    B:ApplyView(nil, "all")
    B:SelectTab("History")
    B:Hide()
    mocks.__timers = {}
    if not ok then error(err, 0) end
  end)
end

local function texts(items)
  local out = {}
  for i, it in ipairs(items or {}) do out[i] = it.text end
  return table.concat(out, ",")
end

-- Type into the real search box as a player would: the text lands, the client fires
-- OnTextChanged with userInput, and the debounces run out.
local function typeText(text)
  B._search:SetText(text)
  B._search:__fire("OnTextChanged", true)
  mocks.__fireTimers()
end

-- ── the seam and the list's placement ──

test("Autocomplete: the seam answers a library handle on a real box, nil on a box it cannot hook", function()
  local box = mocks.CreateFrame("EditBox")
  local h = B:MakeAutocomplete(box, { provider = function() return {} end })
  assertTrue(h ~= nil and type(h.Close) == "function", "no handle for a real box")
  h:Release()
  assertEqual(B:MakeAutocomplete({}, { provider = function() return {} end }), nil)
end)

test("Autocomplete: the seam copies the caller's opts rather than handing the table over", function()
  local W = mocks.LibStub("LibKa0s-Widgets-1.0")
  local real, seen = W.Autocomplete, nil
  local opts = { maxRows = 3, provider = function() return {} end }
  W.Autocomplete = function(_, o) seen = o; return {} end
  local ok, err = pcall(B.MakeAutocomplete, B, mocks.CreateFrame("EditBox"), opts)
  W.Autocomplete = real
  if not ok then error(err, 0) end
  assertTrue(seen ~= nil and seen ~= opts, "the library was handed the caller's own table")
  assertEqual(seen.maxRows, 3)
end)

test("Autocomplete: with no Autocomplete in the Widgets library the seam answers nil", function()
  -- A Widgets shell from another addon's older vendored copy can refuse this file's pairing and
  -- leave Autocomplete unset; the box then stays a plain filter box.
  local W = mocks.LibStub("LibKa0s-Widgets-1.0")
  local real = W.Autocomplete
  W.Autocomplete = nil
  local ok, got = pcall(B.MakeAutocomplete, B, mocks.CreateFrame("EditBox"),
    { provider = function() return {} end })
  W.Autocomplete = real
  assertTrue(ok, tostring(got))
  assertEqual(got, nil)
end)

case("Autocomplete: typing in Search opens the list directly under the box, as wide as it", function()
  -- Both bottom corners are anchored, so the list is the box's width and follows it through every
  -- window resize with no handler of its own.
  local box, h = B._search, B._autocomplete
  assertTrue(h ~= nil, "the filter bar attached no autocomplete")
  typeText("li")
  assertTrue(h:IsShown(), "typing opened no list")
  local list = h.__list
  local p1, rel1, rp1 = list:GetPoint(1)
  local p2, rel2, rp2 = list:GetPoint(2)
  assertEqual(p1 .. ">" .. rp1, "TOPLEFT>BOTTOMLEFT")
  assertEqual(p2 .. ">" .. rp2, "TOPRIGHT>BOTTOMRIGHT")
  assertTrue(rel1 == box and rel2 == box, "the list is not anchored to the search box")
  assertEqual(texts(h.__items), "Linen Cloth,Flask of Lightning")
end)

case("Autocomplete: switching tab and closing the window both close the list", function()
  local h = B._autocomplete
  typeText("li")
  assertTrue(h:IsShown())
  B:SelectTab("Insights")
  assertFalse(h:IsShown(), "a tab switch left the list open")
  typeText("li")
  assertTrue(h:IsShown())
  B:Hide()
  assertFalse(h:IsShown(), "closing the window left the list open")
end)

-- ── the provider ──

case("Autocomplete: suggestions are the distinct names containing the text, prefix matches first", function()
  assertEqual(texts(B.SuggestNames("li")), "Linen Cloth,Flask of Lightning")
  assertEqual(texts(B.SuggestNames("  LI ")), "Linen Cloth,Flask of Lightning",
    "case and surrounding blanks do not matter")
  assertEqual(texts(B.SuggestNames("cloth")), "Linen Cloth,Silk Cloth", "Linen is offered once")
  assertEqual(#B.SuggestNames(""), 0)
  assertEqual(#B.SuggestNames("   "), 0)
  assertEqual(#B.SuggestNames("zzz"), 0)
end)

case("Autocomplete: Gold is offered when a gold movement is in the slice, in the table's pale gold", function()
  local got = B.SuggestNames("go")
  assertEqual(texts(got), "Gold")
  local m = NS.LedgerTable.MONEY_RGB
  assertEqual(table.concat(got[1].color, ","), table.concat(m, ","))
end)

case("Autocomplete: an item suggestion wears its quality color", function()
  local got = B.SuggestNames("flask")
  local c = mocks.ITEM_QUALITY_COLORS[3]
  assertEqual(table.concat(got[1].color, ","), table.concat({ c.r, c.g, c.b }, ","))
end)

case("Autocomplete: suggestions honor the other filters and set the typed text aside", function()
  B.activeFilter.store = { BANK = true }
  B.activeFilter.text = "zzz"   -- the box's own text clause must not hide what it would offer
  assertEqual(texts(B.SuggestNames("cloth")), "Linen Cloth", "Silk lives only in the warband bank")
  assertEqual(#B.SuggestNames("go"), 0, "the gold movement is in the guild bank")
end)

case("Autocomplete: no more than eight suggestions", function()
  for i = 1, 12 do
    NS.Database:Add({ ts = 1770001000 + i, char = "Mock-Realm", kind = "ITEM",
      direction = "DEPOSIT", store = "BANK", itemID = 9000 + i,
      itemName = ("Linen Bolt %02d"):format(i), quality = 1, quantity = 1 })
  end
  assertEqual(#B.SuggestNames("linen"), B._SUGGEST_MAX)
  assertEqual(B._SUGGEST_MAX, 8)
end)

case("Autocomplete: in test mode the suggestions come from the sample, not the live ledger", function()
  assertTrue(NS.LedgerTable:SetTestMode(true), "test mode did not start")
  local sampleNames, first = {}, nil
  for _, e in ipairs(NS.State.testRecords) do
    if e.itemName then
      sampleNames[e.itemName] = true
      if not first and e.kind ~= "MONEY" then first = e.itemName end
    end
  end
  local got = B.SuggestNames(first:sub(1, 3))
  assertTrue(#got > 0, "the sample offered nothing")
  local hasFirst = false
  for _, it in ipairs(got) do
    assertTrue(sampleNames[it.text], it.text .. " is not a sample name")
    if it.text == first then hasFirst = true end
  end
  assertTrue(hasFirst, first .. " was not offered")
  assertEqual(#B.SuggestNames("qwerty"), 0, "a live-ledger name leaked into test mode")
end)

-- ── the pick ──

case("Autocomplete: a pick sets the exact name in Search and applies it once, at once", function()
  local calls, real = 0, NS.LedgerTable.SetFilter
  NS.LedgerTable.SetFilter = function(self, f) calls = calls + 1; return real(self, f) end
  local ok, err = pcall(function()
    B:ScheduleApplyFilter()   -- the debounce SetText's OnTextChanged arms in the client
    B.PickName({ text = "Linen Cloth" })
    mocks.__fireTimers()
  end)
  NS.LedgerTable.SetFilter = real
  if not ok then error(err, 0) end
  assertEqual(B._search:GetText(), "Linen Cloth")
  assertEqual(B.activeFilter.text, "Linen Cloth")
  assertEqual(calls, 1, "the pick applied the filter more than once, or waited for the debounce")
  assertEqual(NS.LedgerTable.matchCount, 2)
end)

case("Autocomplete: clicking a row in the list picks its name", function()
  local h = B._autocomplete
  typeText("sil")
  assertTrue(h:IsShown())
  h.__rows[1]:__fire("OnClick")
  assertFalse(h:IsShown(), "the pick left the list open")
  assertEqual(B._search:GetText(), "Silk Cloth")
  assertEqual(B.activeFilter.text, "Silk Cloth")
  assertEqual(NS.LedgerTable.matchCount, 1)
end)

case("Autocomplete: on Insights a pick filters the shared view too", function()
  B:SelectTab("Insights")
  B.PickName({ text = "Gold" })
  assertEqual(B.activeFilter.text, "Gold")
  assertEqual(B._search:GetText(), "Gold")
end)

-- ── the stand-down ──

case("Autocomplete: disabling the addon closes an open list, and the list asks nothing after", function()
  -- The list registers no event and arms no OnUpdate; its only live state is an open frame and a
  -- typing debounce, and the stand-down's window close (B:Hide) takes both.
  local h, asked = B._autocomplete, 0
  B._search:SetText("li")
  B._search:__fire("OnTextChanged", true)   -- a keystroke whose debounce is still pending
  local real = B.SuggestNames
  B.SuggestNames = function(...) asked = asked + 1; return real(...) end
  local ok, err = pcall(function()
    NS.Schema:Set("settings.enabled", false)
    mocks.__fireTimers()
  end)
  B.SuggestNames = real
  NS.Schema:Set("settings.enabled", true)
  if not ok then error(err, 0) end
  assertFalse(h:IsShown(), "the list is still open while the addon is disabled")
  assertEqual(asked, 0, "the pending keystroke reached the provider after the stand-down")
end)
