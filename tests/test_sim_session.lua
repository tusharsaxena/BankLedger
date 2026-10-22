-- tests/test_sim_session.lua — the simulator's session host (modules/Sim.lua) on LibKa0s-Sim-1.0.
--
-- BL-10 (BankLedger#24, LibKa0s#54; OWNER_SCOPE C.1, C.3, C.4, C.11, C.13). The session runs the
-- REAL capture engine against the simulated world, so these cases drive the addon's own NS.Sim in
-- the shared environment (tests/sim_support.lua) and read what the engine recorded. They pin the
-- host contract the library leaves to its host: the refusals and their order, the saved ledger
-- untouched (H4), the auto-stops (H6), the stop order, and the exclusivity with test mode and
-- purge (H5). The mock's REAL backpack holds different contents from the simulated one throughout,
-- so a read that escaped the seam shows up as a wrong count.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = dofile("tests/sim_support.lua")
local C = NS.Constants
local L = NS.L
local SchemaS = NS.Schema
local ENABLED_PATH = "settings.enabled"

local BANK_LINE = L["Close the bank first: a simulation cannot run beside a real bank visit."]
local TEST_LINE = L["Turn test mode off before starting a simulation."]
local COMBAT_LINE = L["A simulation cannot start in combat."]
local VIS_LINE = L["A simulation cannot start while General visibility keeps the ledger window closed."]

local function withCombat(on, fn)
  local saved = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return on end
  local ok, err = pcall(fn)
  mocks.InCombatLockdown = saved
  if not ok then error(err, 0) end
end

local function withVisibility(mode, fn)
  local g = NS.db.profile.settings
  local saved = g.visibility
  g.visibility = mode
  local ok, err = pcall(fn)
  g.visibility = saved
  if not ok then error(err, 0) end
end

--- Start the bank scenario in the current world and answer ok and the lines Start printed.
local function tryStart()
  local ok
  local lines = S.chat(function() ok = NS.Sim:Start{ scenario = "bank" } end)
  return ok, lines
end

-- ── the refusals (req-bl-sim §6) ──────────────────────────────────────────────────────────────

test("Sim session: a real bank frame open refuses, by its context or a live guild frame", function()
  S.withSession(nil, function()
    NS.State.openContext = C.Context.BANK_FRAME
    local ok, lines = tryStart()
    NS.State.openContext = nil
    assertFalse(ok, "started beside an armed bank frame")
    assertTrue(S.has(lines, BANK_LINE), table.concat(lines, " || "))
    mocks.__guildVisible = true
    ok, lines = tryStart()
    mocks.__guildVisible = false
    assertFalse(ok, "started beside a real guild bank frame")
    assertTrue(S.has(lines, BANK_LINE), table.concat(lines, " || "))
  end)
end)

test("Sim session: test mode, combat and General visibility each refuse with their own line", function()
  S.withSession(nil, function()
    NS.State.testRecords = {}
    local ok, lines = tryStart()
    NS.State.testRecords = nil
    assertFalse(ok)
    assertTrue(S.has(lines, TEST_LINE), table.concat(lines, " || "))
    withCombat(true, function()
      ok, lines = tryStart()
      assertFalse(ok)
      assertTrue(S.has(lines, COMBAT_LINE), table.concat(lines, " || "))
    end)
    withVisibility("never", function()
      ok, lines = tryStart()
      assertFalse(ok)
      assertTrue(S.has(lines, VIS_LINE), table.concat(lines, " || "))
    end)
  end)
end)

test("Sim session: the refusals apply in order: test mode, combat, a real bank, visibility", function()
  S.withSession(nil, function()
    NS.State.testRecords = {}
    NS.State.openContext = C.Context.BANK_FRAME
    local lines
    withCombat(true, function()
      withVisibility("never", function()
        local _, l = tryStart()
        lines = l
      end)
    end)
    NS.State.testRecords = nil
    assertTrue(S.has(lines, TEST_LINE) and not S.has(lines, COMBAT_LINE), table.concat(lines, " || "))
    withCombat(true, function()
      local _, l = tryStart()
      assertTrue(S.has(l, COMBAT_LINE) and not S.has(l, BANK_LINE), table.concat(l, " || "))
    end)
    withVisibility("never", function()
      local _, l = tryStart()
      assertTrue(S.has(l, BANK_LINE) and not S.has(l, VIS_LINE), table.concat(l, " || "))
    end)
    NS.State.openContext = nil
  end)
end)

test("Sim session: stood down, Start refuses with the dispatcher's disabled line before anything else", function()
  S.withSession(nil, function()
    NS.State.testRecords = {}
    S.chat(function() SchemaS:Set(ENABLED_PATH, false) end)
    local ok, lines = tryStart()
    S.chat(function() SchemaS:Set(ENABLED_PATH, true) end)
    NS.State.testRecords = nil
    assertFalse(ok, "started while stood down")
    assertTrue(S.has(lines, NS.Slash:DisabledLine()), table.concat(lines, " || "))
    assertFalse(S.has(lines, TEST_LINE), "the stood-down check did not run first")
  end)
end)

test("Sim session: a second Start while one runs is the library's 'already running'", function()
  S.withSession("bank", function(sim)
    local ok = S.chat(function() assertFalse(sim:Start{ scenario = "bank" }) end)
    assertTrue(S.has(ok, "already running"), table.concat(ok, " || "))
  end)
end)

-- ── the start ────────────────────────────────────────────────────────────────────────────────

test("Sim session: a start prints the host's no-save line, builds the world and swaps the dataset", function()
  local lines = S.withSession("bank", function(sim)
    assertTrue(sim:IsActive())
    assertTrue(type(NS.SimHost.world) == "table", "no world")
    assertEqual(NS.SimHost.pendingLag, 0)
    assertTrue(type(NS.State.simLog) == "table" and #NS.State.simLog == 0, "no session log")
    assertEqual(NS.Database:DatasetKind(), "sim")
    assertTrue(NS.Database:Sink() == NS.State.simLog, "the write sink is not the session log")
    assertTrue(sim:Status().ready, "prepare never called ready()")
    assertTrue(NS.Browser:GetWindow() ~= nil and NS.Browser:GetWindow():IsShown(), "the ledger window did not open")
  end)
  assertTrue(S.has(lines, "nothing here is saved"), table.concat(lines, " || "))
  assertEqual(NS.Database:DatasetKind(), "live", "the stop did not swap the dataset back")
  assertTrue(NS.State.simLog == nil and NS.SimHost.world == nil, "the stop left session state behind")
end)

test("Sim session: the step delay is 1.5 s, raised to a step's settle", function()
  assertEqual(NS.SimHost.STEP_DELAY, 1.5)
  -- Read through the library's Run: the tick after a step is set with the descriptor's stepDelay.
  S.withSession("bank", function(sim)
    local steps = sim:Steps()
    steps[1].settle = 6.5
    S.chat(function() assertTrue(sim:Run()) end)
    local tick = mocks.__timers[#mocks.__timers]
    assertEqual(tick and tick.delay, 6.5, "the step's settle did not raise the delay")
    sim:Pause()
  end)
end)

-- ── the bank scenario, end to end ────────────────────────────────────────────────────────────

test("Sim session: the bank scenario records 2 deposits and 1 withdrawal into the session log", function()
  local before, count = S.copy(NS.db.global.ledger), NS.Database:Count()
  local rows
  S.withSession("bank", function(sim)
    local total = #sim:Steps()
    assertEqual(total, 5)
    for _ = 1, total do
      S.chat(function() assertTrue(sim:Step() ~= nil, "a step did not play") end)
      S.drain()
    end
    rows = NS.State.simLog
  end)
  assertEqual(#rows, 3, "the session log rows")
  local want = {
    { C.Direction.DEPOSIT, 2589, 20 }, { C.Direction.DEPOSIT, 19019, 1 }, { C.Direction.WITHDRAW, 4306, 5 },
  }
  for i, w in ipairs(want) do
    local e = rows[i]
    assertEqual(e.store, C.Store.BANK, "row " .. i .. " store")
    assertEqual(e.kind, C.Kind.ITEM, "row " .. i .. " kind")
    assertEqual(e.direction, w[1], "row " .. i .. " direction")
    assertEqual(e.itemID, w[2], "row " .. i .. " item")
    assertEqual(e.quantity, w[3], "row " .. i .. " quantity")
    assertTrue(e.sim == true, "row " .. i .. " is not stamped sim")
  end
  assertEqual(rows[2].itemLink, S.BONUS_LINK, "the bonus-id link was not kept")
  assertTrue(S.deepEqual(NS.db.global.ledger, before), "the saved ledger changed")
  assertEqual(NS.Database:Count(), count, "the saved ledger's count changed")
end)

test("Sim session: the guarded QueryGuildBankTab never reaches the client during a session", function()
  S.withSession("bank", function()
    local before = mocks.__guildQueryCount
    NS.SimDrivers.OpenGuild()
    assertEqual(NS.State.openContext, C.Context.GUILD_BANK, "the simulated guild frame did not open a context")
    S.drain()
    NS.SimDrivers.CloseGuild()
    assertEqual(mocks.__guildQueryCount, before, "a guild tab query reached the client")
    assertTrue(NS.Sim:Session().queries >= 2, "the guarded queries were not counted")
  end)
end)

-- ── the auto-stops (H6) ──────────────────────────────────────────────────────────────────────

test("Sim session: a REAL bank open stops it first, and the real open snapshots the real world", function()
  S.withSession("bank", function(sim, lines)
    S.chat(function() sim:Step() end)
    assertEqual(NS.State.openContext, C.Context.BANK_FRAME)
    assertEqual(NS.State.lastSnapshot.bags[2589], 40, "the simulated open did not snapshot the sim world")
    local out = S.chat(function() mocks.__fire("BANKFRAME_OPENED") end)
    for _, l in ipairs(out) do lines[#lines + 1] = l end
    assertFalse(sim:IsActive(), "a real bank open did not stop the simulation")
    assertEqual(NS.State.openContext, C.Context.BANK_FRAME, "the real open did not arm its context")
    assertEqual(NS.State.lastSnapshot.bags[2589], S.REAL_LINEN, "the real open snapshotted the simulated world")
    assertTrue(S.has(out, L["Simulation stopped: a real bank window opened or closed."]), table.concat(out, " || "))
    S.chat(function() mocks.__fire("BANKFRAME_CLOSED") end)
  end)
end)

test("Sim session: a real guild frame showing stops it too", function()
  S.withSession("bank", function(sim)
    NS.Ledger:HookGuildBankFrame()
    S.chat(function() mocks.__openGuildBank() end)
    assertFalse(sim:IsActive(), "a real guild bank show did not stop the simulation")
    S.chat(function() mocks.__closeGuildBank() end)
  end)
end)

test("Sim session: real change events do not stop it", function()
  S.withSession("bank", function(sim)
    S.chat(function()
      mocks.__fire("BAG_UPDATE_DELAYED")
      mocks.__fire("PLAYER_MONEY")
      mocks.__fire("GUILDBANKBAGSLOTS_CHANGED")
    end)
    S.drain()
    assertTrue(sim:IsActive(), "a real change event stopped the simulation")
  end)
end)

test("Sim session: combat stops it with its own line", function()
  S.withSession("bank", function(sim)
    local out = S.chat(function() NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED") end)
    assertFalse(sim:IsActive(), "combat did not stop the simulation")
    assertTrue(S.has(out, L["Simulation stopped: you entered combat."]), table.concat(out, " || "))
    S.chat(function() NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED") end)
  end)
end)

test("Sim session: the stand-down stops it as its FIRST step, while the simulated context is armed", function()
  S.withSession("bank", function(sim)
    S.chat(function() sim:Step() end)
    local order = {}
    local stop, cancelAll = sim.Stop, NS.addon.CancelAllTimers
    sim.Stop = function(self, reason)
      order[#order + 1] = "stop " .. tostring(reason) .. (NS.State.openContext and " (armed)" or "")
      return stop(self, reason)
    end
    NS.addon.CancelAllTimers = function(self, ...)
      order[#order + 1] = "timers"
      return cancelAll(self, ...)
    end
    local ok, err = pcall(S.chat, function() SchemaS:Set(ENABLED_PATH, false) end)
    sim.Stop, NS.addon.CancelAllTimers = stop, cancelAll
    S.chat(function() SchemaS:Set(ENABLED_PATH, true) end)
    if not ok then error(err, 0) end
    assertEqual(order[1], "stop standDown (armed)", table.concat(order, ", "))
    assertFalse(sim:IsActive(), "the stand-down did not stop the simulation")
  end)
end)

test("Sim session: a profile reset leaves it running (OWNER_SCOPE C.13)", function()
  S.withSession("bank", function(sim)
    S.chat(function() NS.db:ResetProfile() end)
    assertTrue(sim:IsActive(), "a profile reset ended the simulation")
  end)
end)

-- ── the stop order ───────────────────────────────────────────────────────────────────────────

test("Sim session: the stop drops the context with the seam on, cancels the debounce and never reconciles", function()
  S.withSession("bank", function(sim)
    local Lg = NS.Ledger
    S.chat(function()
      sim:Step()
      sim:Step()   -- a deposit: its reconcile is now pending on the debounce
    end)
    assertTrue(Lg._pendingTimer ~= nil, "no debounce pending to cancel")
    local pending = Lg._pendingTimer
    local seamOn, reconciles, sessionEnds = nil, 0, 0
    local drop, reconcile, send = Lg.DropContext, Lg.Reconcile, NS.bus.SendMessage
    Lg.DropContext = function(self)
      seamOn = NS.Compat.GetMoney() == NS.SimHost.world.purse.main
      return drop(self)
    end
    Lg.Reconcile = function(...) reconciles = reconciles + 1; return reconcile(...) end
    NS.bus.SendMessage = function(self, name, active, ...)
      if name == NS.MSG.SESSION_CHANGED and active == false then sessionEnds = sessionEnds + 1 end
      return send(self, name, active, ...)
    end
    local ok, err = pcall(function()
      S.chat(function() sim:Stop("stop") end)
      S.drain()
    end)
    Lg.DropContext, Lg.Reconcile, NS.bus.SendMessage = drop, reconcile, send
    if not ok then error(err, 0) end
    assertTrue(seamOn == true, "DropContext ran after the seam went off")
    assertEqual(reconciles, 0, "a reconcile ran during or after the stop")
    assertTrue(Lg._pendingTimer == nil and pending.cancelled == true, "the pending debounce survived")
    assertEqual(sessionEnds, 1, "SESSION_CHANGED(false) was not sent once")
    assertEqual(NS.State.openContext, nil)
  end)
end)

-- ── exclusivity (H5) ─────────────────────────────────────────────────────────────────────────

test("Sim session: test mode refuses to start while a simulation runs", function()
  S.withSession("bank", function()
    local on, refusal = NS.LedgerTable:SetTestMode(true)
    assertFalse(on, "test mode started over a simulation")
    assertEqual(refusal, L["Stop the simulation before turning on test mode."])
    assertEqual(NS.Database:DatasetKind(), "sim")
  end)
end)

test("Sim session: purge refuses through Database:Purge, the verb and the panel button", function()
  local before, count = S.copy(NS.db.global.ledger), NS.Database:Count()
  S.withSession("bank", function()
    local shown = {}
    local savedShow = mocks.StaticPopup_Show
    mocks.StaticPopup_Show = function(name) shown[#shown + 1] = name end
    local results, lines = {}, nil
    local ok, err = pcall(function()
      lines = S.chat(function()
        results.db = NS.Database:Purge()
        NS.Slash:OnSlash("purge")
        local PS = dofile("tests/panel_support.lua")
        for _, w in ipairs(PS.renderTab("General", "History")) do
          if w.type == "Button" and w.text == "Purge ledger\226\128\166" then w:__fire("OnClick") end
        end
      end)
    end)
    mocks.StaticPopup_Show = savedShow
    if not ok then error(err, 0) end
    assertTrue(results.db == false, "Database:Purge did not refuse")
    assertEqual(#shown, 0, "a purge confirm opened during a simulation: " .. table.concat(shown, ", "))
    local refusals = 0
    for _, l in ipairs(lines) do
      if l:find(L["Stop the simulation first."], 1, true) then refusals = refusals + 1 end
    end
    assertEqual(refusals, 3, table.concat(lines, " || "))
  end)
  assertTrue(S.deepEqual(NS.db.global.ledger, before), "the real ledger changed")
  assertEqual(NS.Database:Count(), count)
end)
