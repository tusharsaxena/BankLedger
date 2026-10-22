-- tests/test_sim_drivers.lua — the simulator's event drivers (modules/SimDrivers.lua).
--
-- BL-10 (BankLedger#24, req-bl-sim §3). Each driver edits the simulated world, then fires the
-- client's event sequence through NS.Sim:Fire. Every case runs inside a live session (the bank
-- scenario's world, tests/sim_support.lua) with L:Dispatch replaced by a recorder, so it pins two
-- things and nothing else: the world delta, and the exact events delivered with their payloads.
-- The capture engine never sees them here; tests/test_sim_session.lua drives it end to end.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local S = dofile("tests/sim_support.lua")
local D = NS.SimDrivers
local Store = NS.Constants.Store
local BACKPACK, BANK_TAB_1, WARBAND_TAB_1 = S.BACKPACK, S.BANK_TAB_1, S.WARBAND_TAB_1

--- fn(world, seen, "main") inside a bank session with the dispatch recorder on.
local function driving(fn)
  S.withSession("bank", function()
    S.withDispatchSpy(function(seen)
      local w = NS.SimHost.world
      fn(w, seen, "main")
    end)
  end)
end

local function bag(w, key) return w.bags[key][BACKPACK] end
local function bank(w, key) return w.bank[key][BANK_TAB_1] end

test("SimDrivers: every event list is data, each row an event name and an optional payload token", function()
  local TOKENS = { touched = true, bag = true, store = true, slot = true }
  local n = 0
  for name, list in pairs(D.EVENTS) do
    n = n + 1
    assertTrue(#list > 0, name .. " fires nothing")
    for i, row in ipairs(list) do
      assertTrue(type(row[1]) == "string" and row[1]:match("^[A-Z_]+$") ~= nil, name .. " row " .. i)
      assertTrue(row[2] == nil or TOKENS[row[2]], name .. " row " .. i .. " has an unknown token")
    end
  end
  assertEqual(n, 11, "the driver event lists")
  for kind, fn in pairs(D.DRIVERS) do assertTrue(type(fn) == "function", kind) end
end)

test("SimDrivers: OpenBank and CloseBank fire the bank frame's two events and move nothing", function()
  driving(function(w, seen, key)
    local before = S.count(bag(w, key), w.pool[1].itemID)
    D.OpenBank()
    D.CloseBank()
    assertEqual(S.sequence(seen), "BANKFRAME_OPENED, BANKFRAME_CLOSED")
    assertEqual(S.count(bag(w, key), w.pool[1].itemID), before)
  end)
end)

test("SimDrivers: a BANK deposit moves bags to the bank tab and fires BAG_UPDATE per touched bag", function()
  driving(function(w, seen, key)
    local id = w.pool[1].itemID
    local detail = D.Deposit{ store = Store.BANK, item = 1, n = 20 }
    assertEqual(S.count(bag(w, key), id), 20, "backpack")
    assertEqual(S.count(bank(w, key), id), 40, "bank tab 1")
    assertEqual(S.sequence(seen),
      "BAG_UPDATE(0), BAG_UPDATE(6), PLAYERBANKSLOTS_CHANGED(1), BAG_UPDATE_DELAYED")
    assertTrue(detail:find("deposit 20", 1, true) ~= nil, detail)
  end)
end)

test("SimDrivers: a BANK withdrawal is the deposit's mirror", function()
  driving(function(w, seen, key)
    local id = w.pool[2].itemID
    D.Withdraw{ store = Store.BANK, item = 2, n = 5 }
    assertEqual(S.count(bag(w, key), id), 45, "backpack")
    assertEqual(S.count(bank(w, key), id), 15, "bank tab 1")
    assertEqual(S.sequence(seen),
      "BAG_UPDATE(0), BAG_UPDATE(6), PLAYERBANKSLOTS_CHANGED(2), BAG_UPDATE_DELAYED")
  end)
end)

test("SimDrivers: a WARBAND deposit with no lag fires the bag half, then the store half", function()
  driving(function(w, seen, key)
    local id = w.pool[1].itemID
    D.Deposit{ store = Store.WARBAND_BANK, item = 1, n = 20 }
    assertEqual(S.count(bag(w, key), id), 20)
    assertEqual(S.count(w.warband[WARBAND_TAB_1], id), 20)
    assertEqual(S.sequence(seen),
      "BAG_UPDATE(0), BAG_UPDATE_DELAYED, BAG_UPDATE(12), BAG_UPDATE_DELAYED")
    assertEqual(NS.SimHost.pendingLag, 0)
  end)
end)

test("SimDrivers: a lagged WARBAND deposit lands its store half on the session timer", function()
  driving(function(w, seen, key)
    local id = w.pool[1].itemID
    D.Deposit{ store = Store.WARBAND_BANK, item = 1, n = 20, lag = 1.5 }
    assertEqual(S.count(bag(w, key), id), 20, "the bag half left at once")
    assertEqual(S.count(w.warband[WARBAND_TAB_1], id), 0, "the store half landed early")
    assertEqual(S.sequence(seen), "BAG_UPDATE(0), BAG_UPDATE_DELAYED")
    assertEqual(NS.SimHost.pendingLag, 1, "the pending lag is not counted for the gate")
    local lagged = mocks.__timers[#mocks.__timers]
    assertEqual(lagged and lagged.delay, 1.5, "the store half is not on a 1.5 s timer")
    S.drain()
    assertEqual(S.count(w.warband[WARBAND_TAB_1], id), 20, "the store half never landed")
    assertEqual(S.sequence(seen),
      "BAG_UPDATE(0), BAG_UPDATE_DELAYED, BAG_UPDATE(12), BAG_UPDATE_DELAYED")
    assertEqual(NS.SimHost.pendingLag, 0)
  end)
end)

test("SimDrivers: a WARBAND deposit with lag \"never\" withholds the store half for good", function()
  driving(function(w, seen, key)
    local id = w.pool[1].itemID
    D.Deposit{ store = Store.WARBAND_BANK, item = 1, n = 5, lag = "never" }
    S.drain()
    assertEqual(S.count(bag(w, key), id), 35)
    assertEqual(S.count(w.warband[WARBAND_TAB_1], id), 0)
    assertEqual(S.sequence(seen), "BAG_UPDATE(0), BAG_UPDATE_DELAYED")
    assertEqual(NS.SimHost.pendingLag, 0)
  end)
end)

test("SimDrivers: a WARBAND withdrawal mirrors the deposit, lagged or not", function()
  driving(function(w, seen, key)
    local id = w.pool[1].itemID
    D.Deposit{ store = Store.WARBAND_BANK, item = 1, n = 20 }
    for i = #seen, 1, -1 do seen[i] = nil end
    D.Withdraw{ store = Store.WARBAND_BANK, item = 1, n = 10, lag = 1 }
    assertEqual(S.count(bag(w, key), id), 30, "the bag half arrived at once")
    assertEqual(S.count(w.warband[WARBAND_TAB_1], id), 20, "the store half left early")
    S.drain()
    assertEqual(S.count(w.warband[WARBAND_TAB_1], id), 10)
    assertEqual(S.sequence(seen),
      "BAG_UPDATE(0), BAG_UPDATE_DELAYED, BAG_UPDATE(12), BAG_UPDATE_DELAYED")
  end)
end)

test("SimDrivers: a GUILD deposit and withdrawal move against tab 1 and end on the guild data event", function()
  driving(function(w, seen, key)
    local id = w.pool[1].itemID
    D.Deposit{ store = Store.GUILD_BANK, item = 1, n = 3 }
    assertEqual(S.count(bag(w, key), id), 37)
    assertEqual(S.count(w.guild.tabs[1], id), 23)
    D.Withdraw{ store = Store.GUILD_BANK, item = 1, n = 5 }
    assertEqual(S.count(bag(w, key), id), 42)
    assertEqual(S.count(w.guild.tabs[1], id), 18)
    assertEqual(S.sequence(seen), "BAG_UPDATE(0), BAG_UPDATE_DELAYED, GUILDBANKBAGSLOTS_CHANGED, "
      .. "BAG_UPDATE(0), BAG_UPDATE_DELAYED, GUILDBANKBAGSLOTS_CHANGED")
  end)
end)

test("SimDrivers: Money moves coin between the purse and a store; Spend takes it from the purse alone", function()
  driving(function(w, seen, key)
    local SW = NS.SimWorld
    D.Money{ store = Store.WARBAND_BANK, dir = "deposit", copper = 10000000 }
    assertEqual(w.purse[key], SW.PURSE - 10000000)
    assertEqual(w.warbandMoney, SW.WARBAND_MONEY + 10000000)
    D.Money{ store = Store.WARBAND_BANK, dir = "withdraw", copper = 5000000 }
    assertEqual(w.purse[key], SW.PURSE - 5000000)
    assertEqual(w.warbandMoney, SW.WARBAND_MONEY + 5000000)
    D.Spend{ copper = 250000 }
    assertEqual(w.purse[key], SW.PURSE - 5250000)
    assertEqual(w.warbandMoney, SW.WARBAND_MONEY + 5000000, "a spend touched a store")
    assertEqual(S.sequence(seen), "PLAYER_MONEY, PLAYER_MONEY, PLAYER_MONEY")
  end)
end)

test("SimDrivers: Loot adds to the bags alone and fires BAG_UPDATE(0), BAG_UPDATE_DELAYED", function()
  driving(function(w, seen, key)
    local id = w.pool[4].itemID
    D.Loot{ item = 4, n = 2 }
    assertEqual(S.count(bag(w, key), id), 42)
    assertEqual(S.count(bank(w, key), id), 20)
    assertEqual(S.sequence(seen), "BAG_UPDATE(0), BAG_UPDATE_DELAYED")
  end)
end)

test("SimDrivers: OpenGuild shows the simulated frame, starts a fresh visit, then fires its pseudo-event", function()
  driving(function(w, seen)
    w.guild.queried[1] = true
    D.OpenGuild()
    assertTrue(w.guild.visible == true)
    assertTrue(next(w.guild.queried) == nil, "the visit kept the last visit's queried tabs")
    D.CloseGuild()
    assertTrue(w.guild.visible == false)
    assertEqual(S.sequence(seen), "GUILDBANK_FRAME_SHOWN, GUILDBANK_FRAME_HIDDEN")
  end)
end)

test("SimDrivers: GuildDataAway changes a tab with the frame hidden and fires only the data event", function()
  driving(function(w, seen)
    local id = w.pool[1].itemID
    D.GuildDataAway{ item = 1, n = 4 }
    assertEqual(S.count(w.guild.tabs[1], id), 24)
    assertTrue(w.guild.visible == false)
    assertEqual(S.sequence(seen), "GUILDBANKBAGSLOTS_CHANGED")
  end)
end)

test("SimDrivers: Switch closes an open frame first and fires no PLAYER_ENTERING_WORLD", function()
  driving(function(w, seen)
    NS.State.openContext = NS.Constants.Context.BANK_FRAME
    w.guild.visible = true
    D.Switch{ to = "alt" }
    NS.State.openContext = nil
    assertEqual(w.current, "alt")
    assertEqual(S.sequence(seen), "BANKFRAME_CLOSED, GUILDBANK_FRAME_HIDDEN")
    assertEqual(NS.Compat.PlayerName(), NS.L["Simbanker"], "the seam does not answer the alt")
    D.Switch{ to = "main" }
    assertEqual(S.sequence(seen), "BANKFRAME_CLOSED, GUILDBANK_FRAME_HIDDEN", "a closed frame was closed again")
  end)
end)

test("SimDrivers: \"bonus\" names the pool item whose link carries bonus ids", function()
  driving(function()
    local item = D.ResolveItem("bonus")
    assertEqual(item.itemID, 19019)
    assertEqual(item.link, S.BONUS_LINK)
    assertEqual(D.ResolveItem(1).itemID, 2589)
    assertTrue(D.ResolveItem(99) == nil)
  end)
end)

test("SimDrivers: a move the world cannot make fires nothing and says why", function()
  driving(function(_, seen)
    local detail = D.Withdraw{ store = Store.BANK, item = 1, n = 999 }
    assertEqual(#seen, 0)
    assertTrue(detail:find("short", 1, true) ~= nil, detail)
    detail = D.Withdraw{ store = Store.WARBAND_BANK, item = 1, n = 1, lag = 1 }
    assertEqual(#seen, 0)
    assertTrue(detail:find("short", 1, true) ~= nil, detail)
  end)
end)
