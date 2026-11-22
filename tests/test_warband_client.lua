-- tests/test_warband_client.lua — the Warband Bank is Retail's alone (WoW Forever port design, ruling
-- R1; clients-§4, clients-§6): declared `warbandBank = { "retail" }` in core/Constants.lua's
-- C.FEATURE_CLIENTS and gated where each surface is built, so on WoW Forever it is ABSENT, never
-- hidden. Every case runs on both kit profiles (`KA0S_KIT_CLIENT=forever lua tests/run.lua`) and
-- asserts the feature present on Retail and absent on WoW Forever: the store order, label, mute grid
-- options, container groups, bank-frame reach and coin stores, the capture copy, the test-mode
-- dataset, the session preview and the simulator's scenarios.
--
-- The cases that exercise the warband store itself (a warband move, its lagged half, its balance)
-- live beside their subjects and pass T.WARBAND_ONLY, a declared skip on WoW Forever.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local C = NS.Constants
local RETAIL = NS.Compat.ClientKey() == "retail"
local W = "WARBAND_BANK"

local function contains(list, value)
  for _, v in ipairs(list or {}) do if v == value then return true end end
  return false
end

local function optionValues(options)
  local out = {}
  for _, opt in ipairs(options or {}) do out[#out + 1] = opt.value end
  return out
end

test("warband: declared Retail-only, its ForClient answer the running client's", function()
  local clients = C.FEATURE_CLIENTS.warbandBank
  assertEqual(#clients, 1)
  assertEqual(clients[1], "retail")
  assertEqual(C.FEATURE.warbandBank, RETAIL)
  assertEqual(C.FEATURE.warbandBank, NS.Compat.ForClient(clients))
end)

test("warband: the store is in the order, labels and container groups on Retail only", function()
  assertEqual(contains(C.StoreOrder, W), RETAIL, "StoreOrder")
  assertEqual(C.StoreLabel[W] ~= nil, RETAIL, "StoreLabel")
  assertEqual(C.STORE_CONTAINERS[W] ~= nil, RETAIL, "STORE_CONTAINERS")
  assertEqual(contains(C.CONTAINER_STORES, W), RETAIL, "CONTAINER_STORES")
  assertEqual(#C.WARBAND_BANK_IDS > 0, RETAIL, "WARBAND_BANK_IDS")
  -- The enum member stays on both clients: it is the stored key, and no surface.
  assertEqual(C.Store.WARBAND_BANK, W)
end)

test("warband: no container group holds an account-bank tab on WoW Forever", function()
  -- Forever's enum carries AccountBankTab_1..9 (15..23); nothing there may scan them.
  local account = {}
  for name, id in pairs(T.mocks.Enum.BagIndex) do
    if name:match("^AccountBankTab_%d+$") then account[id] = true end
  end
  assertTrue(next(account) ~= nil, "the mock enum has no account tabs to check against")
  local found = false
  for _, ids in pairs(C.STORE_CONTAINERS) do
    for _, id in ipairs(ids) do if account[id] then found = true end end
  end
  assertEqual(found, RETAIL, "an account tab in a container group")
end)

test("warband: the Banks to record options and the schema row offer it on Retail only", function()
  assertEqual(contains(optionValues(C.STORE_OPTIONS), W), RETAIL, "C.STORE_OPTIONS")
  local row = NS.Schema:FindRow("settings.excludedStores")
  assertEqual(contains(optionValues(row.values), W), RETAIL, "the excludedStores row")
end)

test("warband: the bank frame reaches it, and it holds coin, on Retail only", function()
  assertEqual(contains(NS.Ledger.CONTEXT_STORES[C.Context.BANK_FRAME], W), RETAIL, "CONTEXT_STORES")
  assertEqual(contains(NS.Ledger:StoresFor(C.Context.BANK_FRAME), W), RETAIL, "StoresFor")
  assertEqual(NS.Ledger.MONEY_STORES[W] == true, RETAIL, "MONEY_STORES")
  assertTrue(NS.Ledger.MONEY_STORES.GUILD_BANK, "the guild bank holds coin on both clients")
  local s = NS.Ledger:Snapshot(C.Context.BANK_FRAME)
  assertEqual(s.stores[W] ~= nil, RETAIL, "the bank-frame snapshot's stores")
  assertTrue(s.stores.BANK ~= nil, "the character bank is scanned on both clients")
  if not RETAIL then assertEqual(s.storeMoney[W], nil, "a warband balance read on WoW Forever") end
end)

test("warband: the capture copy names the warband bank on Retail only", function()
  assertEqual(C.COIN_BANKS_TEXT, RETAIL and "the guild and warband banks" or "the guild bank")
  local tip = NS.Schema:FindRow("settings.trackMoney").tooltip
  assertTrue(tip:find(C.COIN_BANKS_TEXT, 1, true) ~= nil, tip)
  assertEqual(tip:lower():find("warband", 1, true) ~= nil, RETAIL, "the Record gold tooltip: " .. tip)
end)

test("warband: the Insights gold cards' tooltips name it on Retail only", function()
  local I = NS.Insights
  if not I.pane then I:Attach(T.mocks.CreateFrame()) end
  I:Layout()
  for _, key in ipairs({ "goldIn", "goldOut" }) do
    local tip = I.cards[key]._tip
    assertTrue(type(tip) == "string" and tip:find(C.COIN_BANKS_TEXT, 1, true) ~= nil,
      key .. " tooltip: " .. tostring(tip))
    assertEqual(tip:lower():find("warband", 1, true) ~= nil, RETAIL, key .. " tooltip: " .. tip)
  end
end)

test("warband: the test-mode dataset has Warband Bank rows on Retail only", function()
  local warband, guildGold = 0, 0
  for _, e in ipairs(NS.LedgerTable:BuildTestData()) do
    if e.store == W then warband = warband + 1 end
    if e.kind == C.Kind.MONEY and e.store == "GUILD_BANK" then guildGold = guildGold + 1 end
  end
  assertEqual(warband > 0, RETAIL, "Warband Bank rows: " .. warband)
  -- Every gold movement sits at a store that holds coin: half the guild bank's on Retail, all of
  -- them on WoW Forever.
  assertEqual(guildGold, RETAIL and 15 or 30, "guild-bank gold rows")
end)

test("warband: the session preview shows the Warband Bank on Retail only", function()
  local rows = NS.SessionWindow:BuildPreviewSession()
  local warband, gold = 0, nil
  for _, e in ipairs(rows) do
    if e.store == W then warband = warband + 1 end
    if e.kind == C.Kind.MONEY then gold = e end
  end
  assertEqual(warband, RETAIL and 3 or 0, "Warband Bank preview rows")
  assertTrue(gold ~= nil, "the preview carries its one gold movement")
  assertEqual(gold.store, RETAIL and W or "GUILD_BANK", "the gold movement's store")
  assertTrue(NS.Ledger.MONEY_STORES[gold.store], "the preview's gold sits where gold can live")
  assertEqual(gold.guild ~= nil, not RETAIL, "only a guild-bank gold row carries the guild")
  assertEqual(#rows, 6, "the same six rows on both clients")
end)

test("warband: the simulator registers the warband scenario and step on Retail only", function()
  local scenarios = NS.SimHost.SCENARIOS
  assertEqual(scenarios.defs.warband ~= nil, RETAIL, "the warband scenario's def")
  assertEqual(contains(scenarios.names, "warband"), RETAIL, "the warband scenario's name")
  local onesided = scenarios.defs.onesided
  local warbandStep = false
  for _, step in ipairs(onesided.timeline(onesided, {})) do
    if step.store == W then warbandStep = true end
  end
  assertEqual(warbandStep, RETAIL, "the onesided scenario's warband step")
  for _, name in ipairs(scenarios.names) do
    local def = scenarios.defs[name]
    for i, step in ipairs(def.timeline(def, {})) do
      assertFalse(not RETAIL and step.store == W, name .. " step " .. i .. " moves to the Warband Bank")
    end
  end
end)
