-- tests/test_sim_seam.lua — the simulator's answer seam (core/SimSetup.lua) on LibKa0s-Sim-1.0.
--
-- BL-08 (BankLedger#24, LibKa0s#54). core/SimSetup.lua wraps NS.Compat with Sim:NewSeam straight
-- after core/Compat.lua: the three pure members are left alone, QueryGuildBankTab is guarded, and
-- every other function member is wrapped. These cases pin the host contract the library cannot
-- enforce for us (H2: nothing escapes the wrap, the TOC slot, no captured member) and the four seam
-- members the host leans on (one owner per answer, a pure key refused, Live restoring bypass and
-- re-raising the original value).
--
-- Anything that mutates a seam -- a provider, a session -- runs in an ISOLATED environment from
-- tests/degraded_env.lua's loadUpTo, never on the shared NS.SimSeam: a provider left on the shared
-- seam would answer for every suite after this one, and one seam binds one session for good.

local T = _G.BL_TEST
local NS = T.NS
local Loader = T.Loader
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Env = dofile("tests/degraded_env.lua")
local loadUpTo = Env.loadUpTo

-- The 15 function members of core/Compat.lua, minus the 3 pure ones.
local WRAPPED = {
  "GetContainerNumSlots", "GetContainerSlot", "GetCurrentGuildBankTab", "GetGuildBankSlot",
  "GetGuildName", "GetMoney", "GetNumGuildBankTabs", "GetStoreMoney", "IsGuildBankVisible",
  "PlayerClass", "PlayerName", "QueryGuildBankTab",
}
local PURE = { "GetItemDetails", "GuildBankTabSize", "ItemNameQuality" }

--- An isolated environment loaded through core/SimSetup.lua, with the library, and its Sim major.
local function isolated()
  local ns, m = loadUpTo("core/SimSetup.lua", true)
  local Sim = m.LibStub("LibKa0s-Sim-1.0", true)
  assertTrue(Sim ~= nil, "the isolated environment has no LibKa0s-Sim-1.0")
  return ns, m, Sim
end

--- A bare session bound to `ns.SimSeam`: one scenario with no steps, readied at once.
local function bareSession(ns, Sim, deliver)
  local sim = Sim:New{
    name = "BankLedger", seam = ns.SimSeam, slash = "/bl sim",
    deliver = deliver or function() return 0 end,
    isStoodDown = function() return false end,
    scenarios = { names = { "bare" }, defs = { bare = { label = "Bare", timeline = function() return {} end } } },
    prepare = function(_, _, _, ready) ready() end,
    play = function() end,
    print = function() end,
  }
  return sim
end

test("Sim seam: the vendored LibKa0s-Sim-1.0 registered and NS.SimSeam is its seam", function()
  local Sim = T.mocks.LibStub("LibKa0s-Sim-1.0", true)
  assertTrue(Sim ~= nil, "LibKa0s-Sim-1.0 did not register")
  assertTrue(type(NS.SimSeam) == "table" and type(NS.SimSeam.Unwrapped) == "function",
    "NS.SimSeam is not a seam")
  assertTrue(type(NS.SimHost) == "table", "NS.SimHost, the host's own table, is missing")
end)

test("Sim seam: Keys() is the 12 wrapped Compat members, sorted", function()
  assertEqual(table.concat(NS.SimSeam:Keys(), ","), table.concat(WRAPPED, ","))
end)

test("Sim seam: the three pure members are not wrapped", function()
  local keys = {}
  for _, k in ipairs(NS.SimSeam:Keys()) do keys[k] = true end
  for _, k in ipairs(PURE) do
    assertTrue(type(NS.Compat[k]) == "function", k .. " is not a Compat member")
    assertTrue(not keys[k], k .. " is pure and must not be wrapped")
  end
end)

test("Sim seam: Unwrapped() is EMPTY after the whole addon loads (host contract H2)", function()
  local escaped = NS.SimSeam:Unwrapped()
  assertEqual(#escaped, 0, "Compat members escaped the wrap: " .. table.concat(escaped, ", "))
end)

test("Sim seam: with no session, every wrapped member answers what the bare Compat answers", function()
  -- Two fresh environments over identical mocks: one stops at core/Compat.lua (unwrapped), the other
  -- at core/SimSetup.lua (wrapped). Each member gets the same arguments in both.
  local bare = loadUpTo("core/Compat.lua", true)
  local wrapped, wm = isolated()
  local ARGS = {
    GetContainerNumSlots = { 0 }, GetContainerSlot = { 0, 1 }, GetGuildBankSlot = { 1, 1 },
    GetStoreMoney = { "WARBAND" },
  }
  for _, k in ipairs(WRAPPED) do
    if k ~= "QueryGuildBankTab" then
      local args = ARGS[k] or {}
      local want = { bare.Compat[k](unpack(args)) }
      local got = { wrapped.Compat[k](unpack(args)) }
      assertEqual(#got, #want, k .. " answered a different number of values")
      for i = 1, #want do
        if type(want[i]) == "table" then
          for f, v in pairs(want[i]) do assertEqual(got[i][f], v, k .. " field " .. tostring(f)) end
        else
          assertEqual(got[i], want[i], k .. " value " .. i)
        end
      end
    end
  end
  -- The guarded member calls live while idle: the mock records the query.
  local before = wm.__guildQueryCount
  wrapped.Compat.QueryGuildBankTab(2)
  assertEqual(wm.__guildQueryCount, before + 1, "an idle guarded member did not reach the client")
  assertTrue(wm.__guildQueried[2] == true)
end)

test("Sim seam: SetProvider on a pure key raises", function()
  local ns = isolated()
  for _, k in ipairs(PURE) do
    local ok = pcall(ns.SimSeam.SetProvider, ns.SimSeam, k, function() end)
    assertTrue(not ok, "SetProvider on the pure key " .. k .. " did not raise")
  end
end)

test("Sim seam: a second SetProvider on one key raises; release with nil first", function()
  local ns = isolated()
  local fn = function() return 1 end
  ns.SimSeam:SetProvider("GetMoney", fn)
  local ok = pcall(ns.SimSeam.SetProvider, ns.SimSeam, "GetMoney", fn)
  assertTrue(not ok, "a second provider for GetMoney did not raise")
  ns.SimSeam:SetProvider("GetMoney", nil)
  ns.SimSeam:SetProvider("GetMoney", fn)
end)

test("Sim seam: Live(fn) restores bypass when fn raises, and re-raises the same value", function()
  local ns, m, Sim = isolated()
  m.GetMoney = function() return 7 end
  ns.SimSeam:SetProvider("GetMoney", function() return 42 end)
  local sim = bareSession(ns, Sim)
  assertTrue(sim:Start{ scenario = "bare" }, "the bare session did not start")
  assertEqual(ns.Compat.GetMoney(), 42, "a session's provider did not answer")
  assertEqual(ns.SimSeam:Live(function() return ns.Compat.GetMoney() end), 7, "Live did not read live")
  local thrown = { "boom" }
  local ok, err = pcall(ns.SimSeam.Live, ns.SimSeam, function() error(thrown) end)
  assertTrue(not ok, "Live swallowed the error")
  assertTrue(err == thrown, "Live did not re-raise the original error value")
  assertEqual(ns.Compat.GetMoney(), 42, "bypass outlived the raising Live")
  sim:Stop()
  assertEqual(ns.Compat.GetMoney(), 7, "the stopped seam still answered from the provider")
end)

test("Sim seam: a guarded QueryGuildBankTab never reaches the client during a session", function()
  local ns, m, Sim = isolated()
  local fired = {}
  local sim = bareSession(ns, Sim, function(event) fired[#fired + 1] = event; return 1 end)
  ns.Sim = sim
  ns.SimHost.world = { guild = { queried = {} } }
  assertTrue(sim:Start{ scenario = "bare" }, "the bare session did not start")
  local before = m.__guildQueryCount
  ns.Compat.QueryGuildBankTab(1)
  ns.SimSeam:Live(ns.Compat.QueryGuildBankTab, 2)
  assertEqual(m.__guildQueryCount, before, "a guarded query reached the client")
  assertTrue(ns.SimHost.world.guild.queried[1] and ns.SimHost.world.guild.queried[2],
    "the guarded query did not mark the tabs queried in the sim world")
  assertEqual(sim:Session().queries, 2, "the session did not count the guarded queries")
  assertEqual(#fired, 0, "the reply fired synchronously")
  m.__fireTimers()
  assertEqual(table.concat(fired, ","), "GUILDBANKBAGSLOTS_CHANGED,GUILDBANKBAGSLOTS_CHANGED",
    "the asynchronous replies did not fire")
  sim:Stop()
end)

test("Sim seam: the guarded query is inert with no sim world and no session", function()
  local ns, m = isolated()
  ns.SimHost.world = nil
  local guarded = ns.SimHost.GuardedQuery
  assertTrue(type(guarded) == "function", "core/SimSetup.lua does not publish its guarded answer")
  local before = m.__guildQueryCount
  guarded(1)
  assertEqual(m.__guildQueryCount, before, "the guarded answer called the client")
end)

test("TOC: core/SimSetup.lua loads immediately after core/Compat.lua, annotated LOAD-BEARING", function()
  local toc = Loader.tocFiles("BankLedger.toc")
  local at
  for i, p in ipairs(toc) do if p == "core/Compat.lua" then at = i end end
  assertTrue(at ~= nil, "core/Compat.lua is not in BankLedger.toc")
  assertEqual(toc[at + 1], "core/SimSetup.lua")
  local lines = {}
  for line in (Loader.readFile("BankLedger.toc") .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = (line:gsub("\r$", ""))
  end
  for i, line in ipairs(lines) do
    if line == "core\\SimSetup.lua" then
      assertTrue(lines[i - 1]:find("^# LOAD%-BEARING:") ~= nil,
        "the line above core\\SimSetup.lua must be a '# LOAD-BEARING:' comment")
    end
  end
end)

test("Sim seam: no file caches a Compat member or the Compat table outside core/Compat.lua", function()
  -- A captured member is the live one and escapes the seam (host contract H1).
  local offenders = {}
  for _, path in ipairs(Loader.tocFiles("BankLedger.toc")) do
    if path ~= "core/Compat.lua" then
      local src = Loader.readFile(path)
      for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        if not line:find("^%s*%-%-") and (line:find("=%s*NS%.Compat%.[%a_]+%s*[\r]?$")
          or line:find("=%s*NS%.Compat%s*[\r]?$")) then
          offenders[#offenders + 1] = path .. ": " .. line
        end
      end
    end
  end
  assertEqual(#offenders, 0, "captured Compat reads: " .. table.concat(offenders, " | "))
end)
