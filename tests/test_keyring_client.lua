-- tests/test_keyring_client.lua — the keyring (Enum.BagIndex.Keyring, -1) is in the bags group on
-- WoW Forever only (WoW Forever port design, ruling R5; clients-§5). The groups are
-- LibKa0s-Compat-1.0's ContainerGroups (LibKa0s#101, routed as NS.Compat.ContainerGroups), which
-- core/Constants.lua reads ONCE at load; its per-client pattern table adds `^Keyring$` to WoW
-- Forever's bags row, and Retail's row is the addon's pre-port list unchanged. Forever's keyring is a live
-- container (KEYRING_CONTAINER = Enum.BagIndex.Keyring), so a key the player owns counts as
-- carried. Retail's enum also names Keyring = -1, but before 11.2 -1 was the legacy bank container,
-- and nothing has shown what it answers today, so Retail never scans it. Every case runs on both kit
-- profiles (`KA0S_KIT_CLIENT=forever lua tests/run.lua`) and asserts the client's own answer.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local C = NS.Constants
local FOREVER = NS.Compat.ClientKey() == "forever"
local KEYRING = mocks.Enum.BagIndex.Keyring

local S = dofile("tests/ledger_support.lua")
local withContainers = S.withContainers
local BAG_ID, BANK_ID = S.BAG_ID, S.BANK_ID

local function contains(list, value)
  for _, v in ipairs(list or {}) do if v == value then return true end end
  return false
end

test("keyring: the mock's enum names Keyring = -1 on both clients", function()
  assertEqual(KEYRING, -1)
end)

test("keyring: the library's bags patterns are a row per client, the keyring on Forever's only", function()
  local all = NS.Compat.CONTAINER_PATTERNS_BY_CLIENT
  assertTrue(type(all) == "table", "NS.Compat.CONTAINER_PATTERNS_BY_CLIENT")
  assertTrue(type(all.retail) == "table" and type(all.forever) == "table", "a row per client")
  local rows = { retail = all.retail.bags, forever = all.forever.bags }
  assertTrue(contains(rows.forever, "^Keyring$"), "Forever's row names the keyring")
  assertTrue(not contains(rows.retail, "^Keyring$"), "Retail's row does not")
  -- Retail's row is the addon's pre-port list, unchanged; Forever's is it plus the keyring.
  local retail = { "^Backpack$", "^Bag_%d+$", "^ReagentBag$" }
  assertEqual(#rows.retail, #retail)
  for i, p in ipairs(retail) do assertEqual(rows.retail[i], p) end
  assertEqual(#rows.forever, #retail + 1)
  for _, p in ipairs(retail) do assertTrue(contains(rows.forever, p), "Forever keeps " .. p) end
  -- The bank row is the addon's pre-swap list; the account bank is Retail's alone (R1).
  local bank = { "^Bank$", "^BankBag_%d+$", "^CharacterBankTab_%d+$" }
  for _, client in ipairs({ "retail", "forever" }) do
    assertEqual(table.concat(all[client].bank, " "), table.concat(bank, " "), client .. " bank row")
  end
  assertEqual(table.concat(all.retail.accountBank, " "), "^AccountBankTab_%d+$", "Retail's account row")
  assertEqual(#all.forever.accountBank, 0, "Forever declares no account bank")
end)

test("keyring: the bags group holds -1 on WoW Forever and not on Retail", function()
  assertEqual(contains(C.BAG_IDS, KEYRING), FOREVER, "keyring in C.BAG_IDS")
  assertEqual(contains(C.STORE_CONTAINERS.BAGS, KEYRING), FOREVER, "keyring in the BAGS store")
  assertEqual(#C.BAG_IDS, FOREVER and 7 or 6)
  for id = 0, 5 do assertTrue(contains(C.BAG_IDS, id), "bag id " .. id) end
  for store, ids in pairs(C.STORE_CONTAINERS) do
    if store ~= "BAGS" then assertTrue(not contains(ids, KEYRING), store .. " holds no keyring") end
  end
end)

test("keyring: a key carried from the keyring into the bank is a deposit on WoW Forever only", function()
  -- The defect R5 closes: with the keyring outside every group, the key left nothing the scan saw
  -- and arrived in the bank, a one-sided change that writes no row. In the bags group it is a
  -- DEPOSIT. Retail does not scan -1, so the same container change writes nothing there.
  local before = NS.Database:Count()
  withContainers({
    [KEYRING] = { slots = 1, [1] = { itemID = 5396, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[KEYRING][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = 5396, count = 1 }
    assertEqual(NS.Ledger:Reconcile(), FOREVER and 1 or 0)
    if FOREVER then
      local e = NS.Database:Ledger()[NS.Database:Count()]
      assertEqual(e.store, "BANK")
      assertEqual(e.direction, "DEPOSIT")
      assertEqual(e.itemID, 5396)
    end
  end)
  NS.Database:Delete(function(e) return e.itemID == 5396 end)
  assertEqual(NS.Database:Count(), before)
end)

test("keyring: a key moved between the keyring and the backpack writes nothing", function()
  -- Both sides are the bags on WoW Forever (an internal move); on Retail the keyring is unscanned.
  local before = NS.Database:Count()
  withContainers({
    [KEYRING] = { slots = 1, [1] = { itemID = 5396, count = 1 } },
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[KEYRING][1] = nil
    mocks.__containers[BAG_ID][1] = { itemID = 5396, count = 1 }
    assertEqual(NS.Ledger:Reconcile(), 0)
  end)
  assertEqual(NS.Database:Count(), before)
end)
