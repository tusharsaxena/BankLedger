-- tests/test_sim_world.lua — the simulator's world model and its providers (modules/SimWorld.lua).
--
-- BL-09 (BankLedger#24, req-bl-sim §2). The providers are called directly, as fn(fallback, ...),
-- against a built world: no session is needed to prove what they answer, and the fallback handed to
-- them raises, so a provider that reached for the live member would fail loudly.
--
-- Every case builds in an ISOLATED environment from tests/degraded_env.lua's loadUpTo, loaded
-- through modules/SimWorld.lua with the library: it gets its own mocks (so a case may fill the real
-- bags or unguild the player) and its own seam, so nothing set here reaches the shared suite.

local T = _G.BL_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local Env = dofile("tests/degraded_env.lua")

local BACKPACK, BANK_TAB_1, WARBAND_TAB_1 = 0, 6, 12   -- the mock's verbatim Enum.BagIndex ids

local function live() error("a provider called its live fallback", 2) end

--- An isolated environment, its mocks, and a world built in it and installed on NS.SimHost.
--- `prep(m)` runs on the mocks before the build.
local function built(prep, opts)
  local ns, m = Env.loadUpTo("modules/SimWorld.lua", true)
  if prep then prep(m) end
  ns.SimHost.world = ns.SimWorld.Build(opts)
  return ns, m, ns.SimHost.world, ns.SimWorld.PROVIDERS
end

--- Four distinct real items in the mock's backpack, one carrying bonus ids in its link.
local function realBags(m)
  m.__containers[BACKPACK] = {
    slots = 16,
    { itemID = 4306, link = "|Hitem:4306::::::::::|h[Silk Cloth]|h", count = 7 },
    { itemID = 2589, link = "|Hitem:2589::::::::::|h[Linen Cloth]|h", count = 3 },
    { itemID = 19019, link = "|Hitem:19019::::::::::2:1:6646|h[Thunderfury]|h", count = 1 },
    { itemID = 171276, link = "|Hitem:171276::::::::::|h[Spectral Flask]|h", count = 2 },
    { itemID = 2589, link = "|Hitem:2589::::::::::|h[Linen Cloth]|h", count = 9 },
  }
end

local function assertTriple(got, itemID, count, what)
  assertTrue(type(got) == "table", what .. ": not a triple")
  assertEqual(got.itemID, itemID, what .. " itemID")
  assertEqual(got.count, count, what .. " count")
  assertTrue(got.link == nil or type(got.link) == "string", what .. " link")
end

test("SimWorld: a slot answers Compat's { itemID, link, count } triple, and an empty one nil", function()
  local ns, m, w, P = built(realBags)
  -- The live Compat answer for the same kind of slot, for the shape.
  local real = ns.Compat.GetContainerSlot(BACKPACK, 1)
  local item = w.pool[1]
  local sim = P.GetContainerSlot(live, BACKPACK, 1)
  for k in pairs(real) do assertTrue(sim[k] ~= nil, "the sim triple lacks " .. k) end
  for k in pairs(sim) do assertTrue(real[k] ~= nil, "the sim triple has an extra field " .. k) end
  assertTriple(sim, item.itemID, 40, "backpack slot 1")
  assertEqual(sim.link, item.link)
  assertTriple(P.GetContainerSlot(live, BANK_TAB_1, 1), item.itemID, 20, "bank tab 1 slot 1")
  assertEqual(P.GetContainerSlot(live, BACKPACK, 20), nil, "an empty slot answered")
  sim.count = 999
  assertEqual(P.GetContainerSlot(live, BACKPACK, 1).count, 40, "the answer aliased the world")
  m.__containers = {}
end)

test("SimWorld: slot counts are 20 backpack, 98 for the first bank and warband tab, 0 elsewhere", function()
  local _, _, _, P = built()
  assertEqual(P.GetContainerNumSlots(live, BACKPACK), 20)
  assertEqual(P.GetContainerNumSlots(live, BANK_TAB_1), 98)
  assertEqual(P.GetContainerNumSlots(live, WARBAND_TAB_1), 98)
  for _, id in ipairs({ 1, 4, 5, 7, 11, 13, 16, -2, -3, 99 }) do
    assertEqual(P.GetContainerNumSlots(live, id), 0, "container " .. id)
    assertEqual(P.GetContainerSlot(live, id, 1), nil, "container " .. id .. " slot 1")
  end
end)

test("SimWorld: a guild tab answers nil until it is queried this visit, then its data", function()
  local ns, _, w, P = built()
  assertEqual(P.GetNumGuildBankTabs(live), 2)
  assertEqual(P.GetCurrentGuildBankTab(live), 1)
  assertEqual(P.GetGuildBankSlot(live, 1, 1), nil, "an unqueried tab answered")
  ns.SimWorld.MarkQueried(1)
  assertTriple(P.GetGuildBankSlot(live, 1, 1), w.pool[1].itemID, 20, "guild tab 1 slot 1")
  assertEqual(P.GetGuildBankSlot(live, 2, 1), nil, "tab 2 was never queried")
  ns.SimWorld.ResetVisit()
  assertEqual(P.GetGuildBankSlot(live, 1, 1), nil, "a new visit kept the old query")
  -- The guarded query core/SimSetup.lua answers marks the same set.
  ns.SimHost.GuardedQuery(2)
  assertTrue(w.guild.queried[2] == true, "the guarded query did not mark the world's tab")
end)

test("SimWorld: IsGuildBankVisible is strictly true or false, never nil", function()
  local ns, _, w, P = built()
  assertEqual(P.IsGuildBankVisible(live), false)
  w.guild.visible = true
  assertEqual(P.IsGuildBankVisible(live), true)
  ns.SimHost.world = nil
  assertEqual(P.IsGuildBankVisible(live), false, "no world answered other than false")
end)

test("SimWorld: guild money is nil while the guild frame is hidden, set while visible", function()
  local ns, _, w, P = built()
  local Store = ns.Constants.Store
  assertEqual(P.GetStoreMoney(live, Store.GUILD_BANK), nil)
  w.guild.visible = true
  assertEqual(P.GetStoreMoney(live, Store.GUILD_BANK), 100000 * 10000)
  assertEqual(P.GetStoreMoney(live, Store.BANK), nil, "the character bank holds no coin")
  assertEqual(P.GetStoreMoney(live, Store.BAGS), nil)
  assertEqual(P.GetStoreMoney(live, nil), nil)
end)

test("SimWorld: warband money answers the world's balance, and Money moves it", function()
  local ns, _, _, P = built()
  local Store, SW = ns.Constants.Store, ns.SimWorld
  assertEqual(P.GetStoreMoney(live, Store.WARBAND_BANK), 20000 * 10000)
  assertTrue(SW.Money(Store.WARBAND_BANK, 1000 * 10000))
  assertEqual(P.GetStoreMoney(live, Store.WARBAND_BANK), 21000 * 10000)
  assertEqual(P.GetMoney(live), 4000 * 10000, "the purse did not pay the deposit")
  assertTrue(SW.Money(Store.WARBAND_BANK, -500 * 10000))
  assertEqual(P.GetMoney(live), 4500 * 10000)
  assertTrue(SW.Money(nil, 25 * 10000), "a spend was refused")
  assertEqual(P.GetMoney(live), 4475 * 10000)
  assertEqual(P.GetStoreMoney(live, Store.WARBAND_BANK), 20500 * 10000, "a spend moved a store")
  assertFalse(SW.Money(Store.WARBAND_BANK, 1000000 * 10000), "an overdraft was accepted")
  assertFalse(SW.Money(Store.BANK, 1), "a coinless store took coin")
  assertEqual(P.GetMoney(live), 4475 * 10000, "a refused move changed the purse")
end)

test("SimWorld: the purse follows `current` across Switch", function()
  local ns, _, w, P = built()
  local SW = ns.SimWorld
  assertEqual(P.GetMoney(live), 5000 * 10000)
  assertTrue(SW.Money(nil, 100 * 10000))
  assertTrue(SW.Switch("alt"))
  assertEqual(w.current, "alt")
  assertEqual(P.GetMoney(live), 5000 * 10000, "the alt shares main's purse")
  assertTrue(SW.Switch("main"))
  assertEqual(P.GetMoney(live), 4900 * 10000)
  assertFalse(SW.Switch("nobody"), "an unknown character was switched to")
end)

test("SimWorld: main is the real player; after Switch the identity members answer the alt", function()
  local ns, _, w, P = built()
  local name, realm = P.PlayerName(live)
  assertEqual(name, "Mock")
  assertEqual(realm, "Realm")
  assertEqual(P.PlayerClass(live), "MAGE")
  assertEqual(w.chars.main.key, "Mock-Realm")
  ns.SimWorld.Switch("alt")
  name, realm = P.PlayerName(live)
  assertEqual(name, "Simbanker")
  assertEqual(realm, "Realm", "the alt is not on the real realm")
  assertTrue(P.PlayerClass(live) ~= "MAGE" and P.PlayerClass(live) ~= nil, "the alt shares main's class")
  assertEqual(w.chars.alt.key, "Simbanker-Realm")
end)

test("SimWorld: the pool is drawn from the player's REAL bags, distinct, links kept", function()
  local ns, _, w = built(realBags)
  assertFalse(w.poolFallback, "real bags with four items fell back")
  local ids = {}
  for _, item in ipairs(w.pool) do ids[#ids + 1] = item.itemID end
  assertEqual(table.concat(ids, ","), "2589,4306,19019,171276")
  assertEqual(w.pool[3].link, "|Hitem:19019::::::::::2:1:6646|h[Thunderfury]|h", "the bonus-id link was lost")
  assertTrue(ns.SimWorld.PROVIDERS ~= nil)
end)

test("SimWorld: an empty bag falls back to the fixed ids, warmed, and reports it once", function()
  local lines = {}
  local ns, m = built(function(mk) mk.__containers = {} end)
  -- Build again with logging on and a recording sink, now that the environment exists.
  ns.State.debug = true
  ns.Debug = function(tag, fmt, ...) lines[#lines + 1] = tag .. ": " .. string.format(fmt, ...) end
  local w = ns.SimWorld.Build()
  assertTrue(w.poolFallback, "an empty bag did not fall back")
  local ids = {}
  for _, item in ipairs(w.pool) do ids[#ids + 1] = item.itemID end
  assertEqual(table.concat(ids, ","), "2589,194863,171276,6948")
  for _, id in ipairs(ids) do assertTrue(m.__loadRequests[id], "fallback id " .. id .. " was not warmed") end
  assertEqual(#lines, 1, "the fallback was not reported exactly once: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("^Sim: ") ~= nil, "the report is not on the Sim tag")
  realBags(m)
  ns.SimWorld.Build()
  assertEqual(#lines, 1, "a real pool reported a fallback")
end)

test("SimWorld: an unguilded player's world invents the guild name", function()
  local _, _, w, P = built(function(m) m.GetGuildInfo = function() return nil end end)
  assertEqual(w.guild.name, "Simulated Guild")
  assertEqual(P.GetGuildName(live), "Simulated Guild")
  local _, _, w2 = built()
  assertEqual(w2.guild.name, "Ka0s", "a guilded player's world did not keep the real guild")
end)

test("SimWorld: providers are registered for exactly seam:Keys() minus the guarded key", function()
  local ns = Env.loadUpTo("modules/SimWorld.lua", true)
  local P, seam = ns.SimWorld.PROVIDERS, ns.SimSeam
  local count = 0
  for _ in pairs(P) do count = count + 1 end
  local keys = seam:Keys()
  assertEqual(count, #keys - 1, "provider count")
  for _, key in ipairs(keys) do
    local ok = pcall(seam.SetProvider, seam, key, function() end)
    if key == "QueryGuildBankTab" then
      assertTrue(ok, "QueryGuildBankTab has a provider; it stays guarded")
      assertTrue(P[key] == nil)
      seam:SetProvider(key, nil)
    else
      assertFalse(ok, key .. " has no provider registered")
      assertTrue(type(P[key]) == "function", key .. " is not in SW.PROVIDERS")
    end
  end
end)

test("SimWorld: Build reads the real world only inside the seam's Live", function()
  local ns, m = Env.loadUpTo("modules/SimWorld.lua", true)
  realBags(m)
  local depth, outside = 0, {}
  local seam = ns.SimSeam
  local realLive = seam.Live
  seam.Live = function(self, fn, ...)
    depth = depth + 1
    local out = { pcall(realLive, self, fn, ...) }
    depth = depth - 1
    if not out[1] then error(out[2], 0) end
    return unpack(out, 2)
  end
  local function spy(name, fn)
    return function(...)
      if depth == 0 then outside[#outside + 1] = name end
      return fn(...)
    end
  end
  m.UnitName, m.UnitClass = spy("UnitName", m.UnitName), spy("UnitClass", m.UnitClass)
  m.GetRealmName = spy("GetRealmName", m.GetRealmName)
  m.GetNormalizedRealmName = spy("GetNormalizedRealmName", m.GetNormalizedRealmName)
  m.GetGuildInfo = spy("GetGuildInfo", m.GetGuildInfo)
  m.C_Container.GetContainerNumSlots = spy("GetContainerNumSlots", m.C_Container.GetContainerNumSlots)
  m.C_Container.GetContainerItemInfo = spy("GetContainerItemInfo", m.C_Container.GetContainerItemInfo)
  local w = ns.SimWorld.Build()
  seam.Live = realLive
  assertEqual(#outside, 0, "the build read the client outside Live: " .. table.concat(outside, ", "))
  assertEqual(w.chars.main.name, "Mock")
  assertFalse(w.poolFallback)
end)

test("SimWorld: Move edits the world only, with the touched ids; a short move changes nothing", function()
  local ns, _, w, P = built()
  local Store, SW = ns.Constants.Store, ns.SimWorld
  local A = w.pool[1].itemID
  local ok, fromID, toID = SW.Move("main", Store.BAGS, Store.WARBAND_BANK, A, 15)
  assertTrue(ok)
  assertEqual(fromID, BACKPACK)
  assertEqual(toID, WARBAND_TAB_1)
  assertTriple(P.GetContainerSlot(live, BACKPACK, 1), A, 25, "backpack after the deposit")
  assertTriple(P.GetContainerSlot(live, WARBAND_TAB_1, 1), A, 15, "warband after the deposit")
  assertEqual(P.GetContainerSlot(live, WARBAND_TAB_1, 1).link, w.pool[1].link)
  local before = P.GetContainerSlot(live, BACKPACK, 1).count
  assertFalse(SW.Move("main", Store.BAGS, Store.BANK, A, 1000), "a short move was accepted")
  assertEqual(P.GetContainerSlot(live, BACKPACK, 1).count, before, "a refused move took items")
  -- A one-sided arrival (loot), a one-sided departure, and the guild tab.
  assertTrue(SW.Move("main", nil, Store.BAGS, A, 5))
  assertEqual(P.GetContainerSlot(live, BACKPACK, 1).count, before + 5)
  ok, fromID, toID = SW.Move("main", Store.GUILD_BANK, Store.BAGS, w.pool[2].itemID, 5)
  assertTrue(ok)
  assertEqual(fromID, 1, "the guild side answers its tab")
  assertEqual(toID, BACKPACK)
  -- The alt's bags are its own.
  SW.Switch("alt")
  assertTriple(P.GetContainerSlot(live, BACKPACK, 1), A, 40, "the alt's backpack")
  assertTriple(P.GetContainerSlot(live, WARBAND_TAB_1, 1), A, 15, "the warband is account-wide")
end)

test("SimWorld: an empty-built world still draws its pool, and no file names NS.db", function()
  local _, _, w, P = built(realBags, { empty = true })
  assertEqual(#w.pool, 4)
  assertEqual(P.GetContainerSlot(live, BACKPACK, 1), nil, "an empty world was seeded")
  local src = T.Loader.readFile("modules/SimWorld.lua")
  assertEqual(src:find("NS%.db"), nil, "modules/SimWorld.lua reaches SavedVariables")
end)

test("SimWorld: during a session the wrapped Compat answers from the world, not the client", function()
  local ns, m = Env.loadUpTo("modules/SimWorld.lua", true)
  local Sim = m.LibStub("LibKa0s-Sim-1.0", true)
  local sim = Sim:New{
    name = "BankLedger", seam = ns.SimSeam, slash = "/bl sim",
    deliver = function() return 0 end, isStoodDown = function() return false end,
    scenarios = { names = { "bare" }, defs = { bare = { label = "Bare", timeline = function() return {} end } } },
    prepare = function(_, _, _, ready) ready() end, play = function() end, print = function() end,
  }
  ns.SimHost.world = ns.SimWorld.Build()
  m.__guildVisible = false
  assertTrue(sim:Start{ scenario = "bare" }, "the bare session did not start")
  assertEqual(ns.Compat.GetMoney(), 5000 * 10000)
  assertEqual(ns.Compat.IsGuildBankVisible(), false)
  assertEqual(ns.Compat.GetContainerNumSlots(BACKPACK), 20)
  assertEqual(ns.Compat.PlayerName(), "Mock")
  sim:Stop()
  assertEqual(ns.Compat.GetMoney(), m.__money, "the stopped seam still answered from the world")
end)
