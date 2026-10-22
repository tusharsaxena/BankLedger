-- tests/test_sim_scenario.lua — the simulator's scenarios and its gate (modules/SimScenario.lua,
-- modules/Sim.lua's Host.Gate).
--
-- BL-11 (BankLedger#24; req-bl-sim §7, design-sim §11, OWNER_SCOPE C.2). The timelines are pure data:
-- these cases build them with no session, no world and no saved data in reach, and pin each
-- scenario's steps and labels. The gate is what lets `step`, `run` and the panel's click-ahead wait
-- for the real engine: closed on a lagged half still to land, a held baseline (unless the next step
-- carries holdOK) and a pending reconcile pass. tests/test_sim_e2e.lua runs every scenario to its end.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = dofile("tests/sim_support.lua")
local C = NS.Constants
local L = NS.L
local Host = NS.SimHost
local SCEN = Host.SCENARIOS
local WAIT = L["Waiting for the ledger to settle."]

-- The four scenarios, in picker order, with each step's kind and label.
local WANT = {
  bank = {
    { "OpenBank", "Open the bank" },
    { "Deposit", "Deposit 20 of item A to the bank" },
    { "Deposit", "Deposit 1 of item B to the bank" },
    { "Withdraw", "Withdraw 5 of item C from the bank" },
    { "CloseBank", "Close the bank" },
  },
  warband = {
    { "OpenBank", "Open the bank" },
    { "Deposit", "Deposit 20 of item A to the warband bank (its half lands 1.5 s later)" },
    { "Money", "Deposit 1,000 gold to the warband bank" },
    { "CloseBank", "Close the bank" },
    { "Switch", "Switch to the alt" },
    { "OpenBank", "Open the bank" },
    { "Withdraw", "Withdraw 10 of item A from the warband bank" },
    { "Money", "Withdraw 500 gold from the warband bank" },
    { "CloseBank", "Close the bank" },
  },
  guild = {
    { "GuildDataAway", "Guild bank data arrives while you are away" },
    { "OpenGuild", "Open the guild bank" },
    { "Withdraw", "Withdraw 5 of item D from the guild bank" },
    { "Deposit", "Deposit 3 of item A to the guild bank" },
    { "Money", "Withdraw 200 gold from the guild bank" },
    { "CloseGuild", "Close the guild bank" },
  },
  onesided = {
    { "OpenBank", "Open the bank" },
    { "Loot", "Loot 2 of item E into the bags" },
    { "Spend", "Repair for 25 gold" },
    { "Deposit", "Deposit 5 of item A to the warband bank (its half never lands)" },
    { "CloseBank", "Close the bank" },
  },
}

-- A world, a session log and a guild that raise on any read, so a timeline that reached for one
-- fails the case instead of quietly reading it.
local function trap(what)
  return setmetatable({}, { __index = function(_, k) error(what .. " read: " .. tostring(k), 2) end })
end

-- ── the timelines ────────────────────────────────────────────────────────────────────────────

test("Sim scenarios: bank, warband, guild and onesided, in that order, each with a label", function()
  assertEqual(table.concat(SCEN.names, ","), "bank,warband,guild,onesided")
  assertEqual(SCEN.defs.bank.label, L["Personal bank"])
  assertEqual(SCEN.defs.warband.label, L["Warband transfer"])
  assertEqual(SCEN.defs.guild.label, L["Guild bank"])
  assertEqual(SCEN.defs.onesided.label, L["One-sided change"])
end)

test("Sim scenarios: every timeline is pure: two builds are equal and fresh, and touch nothing", function()
  local savedWorld, savedLog = Host.world, NS.State.simLog
  local db = S.copy({ global = NS.db.global, profile = NS.db.profile })
  Host.world, NS.State.simLog = trap("world"), nil
  local ok, err = pcall(function()
    for _, name in ipairs(SCEN.names) do
      local def = SCEN.defs[name]
      local a = def.timeline(def, { scenario = name, seed = 1 })
      local b = def.timeline(def, { scenario = name, seed = 2 })
      assertTrue(S.deepEqual(a, b), name .. ": two builds differ")
      assertTrue(a ~= b and a[1] ~= b[1], name .. ": a build shares its tables")
    end
  end)
  Host.world, NS.State.simLog = savedWorld, savedLog
  if not ok then error(err, 0) end
  assertTrue(S.deepEqual({ global = NS.db.global, profile = NS.db.profile }, db),
    "building a timeline changed saved data")
end)

test("Sim scenarios: each scenario's step count, kinds and labels", function()
  for _, name in ipairs(SCEN.names) do
    local def = SCEN.defs[name]
    local steps = def.timeline(def, { scenario = name })
    local want = WANT[name]
    assertEqual(#steps, #want, name .. " step count")
    for i, w in ipairs(want) do
      assertEqual(steps[i].kind, w[1], name .. " step " .. i .. " kind")
      assertEqual(steps[i].label, L[w[2]], name .. " step " .. i .. " label")
      assertTrue(NS.SimDrivers.DRIVERS[steps[i].kind] ~= nil, name .. " step " .. i .. " has no driver")
    end
  end
end)

test("Sim scenarios: the driver arguments the expected rows rest on", function()
  local function steps(name) return SCEN.defs[name].timeline(SCEN.defs[name], {}) end
  local w = steps("warband")
  assertEqual(w[2].store, C.Store.WARBAND_BANK)
  assertEqual(w[2].lag, 1.5)
  assertEqual(w[2].settle, 3)
  assertEqual(w[3].copper, 1000 * 10000)
  assertEqual(w[5].to, "alt")
  assertEqual(w[8].copper, 500 * 10000)
  local g = steps("guild")
  assertEqual(g[3].store, C.Store.GUILD_BANK)
  assertEqual(g[5].copper, 200 * 10000)
  local o = steps("onesided")
  assertEqual(o[2].settle, 6.5)
  assertEqual(o[3].copper, 25 * 10000)
  assertEqual(o[4].lag, "never")
  assertTrue(o[5].holdOK == true, "the onesided close does not carry holdOK")
  -- holdOK is the onesided close's alone.
  for _, name in ipairs(SCEN.names) do
    for i, step in ipairs(steps(name)) do
      if not (name == "onesided" and i == 5) then
        assertTrue(step.holdOK == nil, name .. " step " .. i .. " carries holdOK")
      end
    end
  end
end)

-- ── the gate ─────────────────────────────────────────────────────────────────────────────────

test("Sim gate: open when settled; closed on a lagged half, a held baseline or a pending pass", function()
  local Ledger = NS.Ledger
  S.withSession("bank", function(sim)
    S.chat(function() sim:Step() end)   -- open the bank
    S.drain()
    assertTrue(Host.Gate() == true, "the gate is closed on a settled engine")

    Host.pendingLag = 1
    local open, line = Host.Gate()
    assertFalse(open, "a lagged half still to land did not close the gate")
    assertEqual(line, WAIT)
    Host.pendingLag = 0

    Ledger._settleSince = mocks.__now
    open, line = Host.Gate()
    assertFalse(open, "a held baseline did not close the gate")
    assertEqual(line, WAIT)
    Ledger._settleSince = nil

    Ledger._pendingTimer = {}
    open, line = Host.Gate()
    assertFalse(open, "a pending reconcile pass did not close the gate")
    assertEqual(line, WAIT)
    Ledger._pendingTimer = nil

    assertTrue(Host.Gate() == true, "the gate did not reopen")
  end)
end)

test("Sim gate: holdOK on the next step opens it over a live hold, never over a lagged half", function()
  local Ledger = NS.Ledger
  S.withSession("onesided", function(sim)
    S.chat(function()
      assertTrue(sim:Run())
      -- Up to the warband deposit whose store half never lands, held, with the close next.
      assertTrue(S.advance(60, function()
        return sim:Status().pos == 4 and Ledger._settleSince ~= nil and Ledger._pendingTimer ~= nil
      end), "the run did not reach the held deposit")
      sim:Pause()
    end)
    assertTrue(sim:Steps()[5].holdOK == true)
    assertTrue(Host.Gate() == true, "holdOK did not open the gate over the hold and its deadline")
    Host.pendingLag = 1
    assertFalse(Host.Gate(), "holdOK opened the gate over a lagged half")
    Host.pendingLag = 0
  end)
end)

test("Sim gate: a typed step answers 'settling' while it is closed, and plays once it opens", function()
  S.withSession("bank", function(sim)
    S.chat(function() sim:Step() end)   -- open the bank
    S.drain()
    S.chat(function() sim:Step() end)   -- a deposit: its pass is pending on the debounce
    assertEqual(sim:Status().pos, 2)
    local step, code
    local out = S.chat(function() step, code = sim:Step() end)
    assertTrue(step == nil, "a step played over a closed gate")
    assertEqual(code, "settling")
    assertTrue(S.has(out, WAIT), "the gate's own line was not printed: " .. table.concat(out, " || "))
    assertEqual(sim:Status().pos, 2, "a settling answer advanced the timeline")
    S.drain()
    S.chat(function() step = sim:Step() end)
    assertTrue(step ~= nil, "the step did not play once the gate opened")
    assertEqual(sim:Status().pos, 3)
  end)
end)

test("Sim gate: each played step stamps rowsBefore, and Host.Recorded counts its rows", function()
  S.withSession("bank", function(sim)
    for _ = 1, #sim:Steps() do
      S.chat(function() assertTrue(sim:Step() ~= nil, "a step did not play") end)
      S.drain()
    end
    local steps = sim:Steps()
    local want = { 0, 1, 1, 1, 0 }
    for i, step in ipairs(steps) do
      assertTrue(step.rowsBefore ~= nil, "step " .. i .. " has no rowsBefore")
      assertEqual(Host.Recorded(step, steps), want[i], "step " .. i .. " recorded")
    end
    assertEqual(#NS.State.simLog, 3)
  end)
  assertTrue(Host.Recorded({ rowsBefore = 0 }, {}) == nil, "Recorded answered with no session log")
end)
