-- tests/test_sim_e2e.lua — the simulator's acceptance suite: every scenario run to its end through
-- the REAL capture engine (BL-11; BankLedger#24, req-bl-sim §7, OWNER_SCOPE C.2 and C.13).
--
-- Each case starts a scenario on the addon's own NS.Sim and plays it with `Run` on a time-ordered
-- clock over the kit's timer queue (tests/sim_support.lua's S.advance): the debounce, the lagged
-- warband half, the settle window, the guarded tab replies, Run's step delays and the gate's polls
-- all happen in simulated seconds. The mock's REAL world holds DIFFERENT contents throughout (the
-- backpack, both bank tabs, the purse, the warband and guild balances, a guild tab) with every real
-- frame closed, so a read that escaped the seam shows up as a wrong row. And nothing may reach the
-- client: the real tab query and every container or money write the client has are spies that must
-- stay uncalled.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = dofile("tests/sim_support.lua")
local C = NS.Constants
local L = NS.L
local Host = NS.SimHost
local GOLD = 10000

-- The pool tests/sim_support.lua's real backpack gives, sorted by id: A, C, D (the bonus link), E.
local A, CC, D = 2589, 4306, 19019
local LINK = {
  [A] = "|Hitem:2589::::::::::|h[Linen Cloth]|h",
  [CC] = "|Hitem:4306::::::::::|h[Silk Cloth]|h",
  [D] = S.BONUS_LINK,
}

-- The client's writes: none may be called while a simulation runs (H4).
local WRITES = {
  "PickupContainerItem", "UseContainerItem", "SplitContainerItem", "PickupGuildBankItem",
  "SplitGuildBankItem", "AutoStoreGuildBankItem", "DepositGuildBankMoney", "WithdrawGuildBankMoney",
  "PickupGuildBankMoney", "DepositReagentBank", "QueryGuildBankTab",
}
local CONTAINER_WRITES = { "PickupContainerItem", "UseContainerItem", "SplitContainerItem" }
local BANK_WRITES = { "DepositMoney", "WithdrawMoney", "AutoDepositItemsIntoBank" }

-- ── the different real world, the spies and the debug buffer ────────────────────────────────

local function swap(tbl, key, value, saved)
  saved[#saved + 1] = { tbl, key, tbl[key] }
  tbl[key] = value
end

--- Runs fn(calls) with the real world made different from the simulated one, every client write
--- a spy counting into `calls`, debug logging on and the clock saved; answers the debug lines.
local function withRealWorld(fn)
  local saved, calls = {}, {}
  local function spy(name) return function() calls[name] = (calls[name] or 0) + 1 end end
  swap(mocks, "__money", 4242, saved)
  swap(mocks, "__warbandMoney", 77 * GOLD, saved)
  swap(mocks, "__guildBankMoney", 33 * GOLD, saved)
  swap(mocks, "__guildTabs", { [1] = { [1] = { itemID = 6948, count = 9 } } }, saved)
  swap(mocks.__containers, S.BANK_TAB_1, { slots = 4, [1] = { itemID = 6948, count = 3 } }, saved)
  swap(mocks.__containers, S.WARBAND_TAB_1, { slots = 4, [1] = { itemID = 194863, count = 2 } }, saved)
  for _, name in ipairs(WRITES) do swap(mocks, name, spy(name), saved) end
  for _, name in ipairs(CONTAINER_WRITES) do swap(mocks.C_Container, name, spy("C_Container." .. name), saved) end
  for _, name in ipairs(BANK_WRITES) do swap(mocks.C_Bank, name, spy("C_Bank." .. name), saved) end
  local now, debug = mocks.__now, NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  local ok, err = pcall(fn, calls)
  local lines = {}
  for _, line in ipairs(NS.DebugLog.buffer) do lines[#lines + 1] = line end
  NS.DebugLog:Clear()
  NS.State.debug = debug
  for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] end
  mocks.__now = now
  if not ok then error(err, 0) end
  return lines
end

--- Every entry the session window took into its live session list while `fn` ran.
local function withSessionSpy(fn)
  local SW = NS.SessionWindow
  local original, got = SW.OnEntryAdded, {}
  SW.OnEntryAdded = function(self, entry)
    if NS.State.sessionActive and entry then got[#got + 1] = entry end
    return original(self, entry)
  end
  local ok, err = pcall(fn, got)
  SW.OnEntryAdded = original
  if not ok then error(err, 0) end
  return got
end

--- Plays `name` to its end with Run (or, `restart`, one step then Restart and Run), stops it, and
--- answers what it saw: { rows, window, steps, recorded, calls, lines, stopped }.
local function play(name, restart)
  local out = {}
  local queries = mocks.__guildQueryCount
  out.lines = withRealWorld(function(calls)
    out.calls = calls
    out.window = withSessionSpy(function()
      S.withSession(name, function(sim)
        if restart then
          S.chat(function() assertTrue(sim:Step() ~= nil, "the first step did not play") end)
          S.advance(10)
          S.chat(function() assertTrue(sim:Restart(), "Restart refused") end)
          assertTrue(sim:IsActive(), "Restart left no session")
          assertEqual(sim:Status().pos, 0, "Restart did not rebuild the timeline")
        end
        local done
        S.chat(function() done = S.runToEnd(sim) end)
        assertTrue(done, name .. ": Run did not reach the end")
        out.rows, out.steps, out.recorded = NS.State.simLog, sim:Steps(), {}
        for i, step in ipairs(out.steps) do out.recorded[i] = Host.Recorded(step, out.steps) end
        S.chat(function() sim:Stop("stop") end)
        out.stopped = { kind = NS.Database:DatasetKind(), log = NS.State.simLog, active = sim:IsActive() }
      end)
    end)
  end)
  out.queries = mocks.__guildQueryCount - queries
  return out
end

local function hasLine(lines, text)
  for _, line in ipairs(lines) do
    if tostring(line):find(text, 1, true) then return true end
  end
  return false
end

-- Asserts each row against { store, direction, kind, quantity, itemID?, char, classFile, guild? }.
local function assertRows(rows, want, what)
  assertEqual(#rows, #want, what .. " row count")
  for i, w in ipairs(want) do
    local e, tag = rows[i], what .. " row " .. i
    assertEqual(e.store, w.store, tag .. " store")
    assertEqual(e.direction, w.direction, tag .. " direction")
    assertEqual(e.kind, w.kind, tag .. " kind")
    assertEqual(e.quantity, w.quantity, tag .. " quantity")
    assertEqual(e.itemID, w.itemID, tag .. " item")
    assertEqual(e.itemLink, w.itemID and LINK[w.itemID] or nil, tag .. " link")
    assertEqual(e.char, w.char, tag .. " char")
    assertEqual(e.classFile, w.classFile, tag .. " class")
    assertEqual(e.guild, w.guild, tag .. " guild")
    assertTrue(e.sim == true, tag .. " is not stamped sim")
  end
end

-- What every scenario owes, whatever it records.
local function assertClean(r, before, count, what)
  assertTrue(S.deepEqual(NS.db.global.ledger, before), what .. ": the saved ledger changed")
  assertEqual(NS.Database:Count(), count, what .. ": the saved ledger's count changed")
  assertEqual(r.stopped.kind, "live", what .. ": the dataset did not swap back to live")
  assertTrue(r.stopped.log == nil, what .. ": the session log outlived the stop")
  assertFalse(r.stopped.active, what .. ": the session outlived the stop")
  assertEqual(r.queries, 0, what .. ": a guild tab query reached the client")
  for name, n in pairs(r.calls) do error(("%s: the client write %s was called %d times"):format(what, name, n), 0) end
  for i, step in ipairs(r.steps) do
    assertTrue(step.ranAt ~= nil, what .. ": step " .. i .. " never ran")
  end
end

-- The identities the rows are stamped with, read live before any session.
local function identities()
  local name, realm = NS.Compat.PlayerName()
  local main = { key = NS.Util.PlayerKey(), class = NS.Compat.PlayerClass() }
  local alt = { key = (L["Simbanker"] .. "-" .. realm):gsub(" ", ""), class = nil }
  alt.class = main.class == "PALADIN" and "WARRIOR" or "PALADIN"
  return main, alt, name
end

-- ── the scenarios ────────────────────────────────────────────────────────────────────────────

test("Sim e2e: bank records 3 BANK rows, the bonus link kept, with the saved ledger untouched", function()
  local before, count = S.copy(NS.db.global.ledger), NS.Database:Count()
  local main = identities()
  local r = play("bank")
  assertRows(r.rows, {
    { store = C.Store.BANK, direction = C.Direction.DEPOSIT, kind = C.Kind.ITEM, quantity = 20, itemID = A,
      char = main.key, classFile = main.class },
    { store = C.Store.BANK, direction = C.Direction.DEPOSIT, kind = C.Kind.ITEM, quantity = 1, itemID = D,
      char = main.key, classFile = main.class },
    { store = C.Store.BANK, direction = C.Direction.WITHDRAW, kind = C.Kind.ITEM, quantity = 5, itemID = CC,
      char = main.key, classFile = main.class },
  }, "bank")
  assertEqual(#r.window, 3, "the session window did not receive the rows")
  assertClean(r, before, count, "bank")
end)

test("Sim e2e: warband records main's 2 deposits and the alt's 2 withdrawals through a held baseline", function()
  local before, count = S.copy(NS.db.global.ledger), NS.Database:Count()
  local main, alt = identities()
  local r = play("warband")
  local W = C.Store.WARBAND_BANK
  assertRows(r.rows, {
    { store = W, direction = C.Direction.DEPOSIT, kind = C.Kind.ITEM, quantity = 20, itemID = A,
      char = main.key, classFile = main.class },
    { store = W, direction = C.Direction.DEPOSIT, kind = C.Kind.MONEY, quantity = 1000 * GOLD,
      char = main.key, classFile = main.class },
    { store = W, direction = C.Direction.WITHDRAW, kind = C.Kind.ITEM, quantity = 10, itemID = A,
      char = alt.key, classFile = alt.class },
    { store = W, direction = C.Direction.WITHDRAW, kind = C.Kind.MONEY, quantity = 500 * GOLD,
      char = alt.key, classFile = alt.class },
  }, "warband")
  assertEqual(#r.window, 4, "the session window did not receive the rows")
  assertTrue(hasLine(r.lines, "[Diff] one-sided change: baseline held"), table.concat(r.lines, " | "))
  assertTrue(hasLine(r.lines, "[Diff] held change settled after"), table.concat(r.lines, " | "))
  assertEqual(r.recorded[2], 1, "the lagged deposit's step recorded")
  assertClean(r, before, count, "warband")
end)

test("Sim e2e: guild records 3 GUILD_BANK rows stamped with the guild", function()
  local before, count = S.copy(NS.db.global.ledger), NS.Database:Count()
  local main = identities()
  local guild = NS.Compat.GetGuildName() or L["Simulated Guild"]
  local r = play("guild")
  local G = C.Store.GUILD_BANK
  assertRows(r.rows, {
    { store = G, direction = C.Direction.WITHDRAW, kind = C.Kind.ITEM, quantity = 5, itemID = D,
      char = main.key, classFile = main.class, guild = guild },
    { store = G, direction = C.Direction.DEPOSIT, kind = C.Kind.ITEM, quantity = 3, itemID = A,
      char = main.key, classFile = main.class, guild = guild },
    { store = G, direction = C.Direction.WITHDRAW, kind = C.Kind.MONEY, quantity = 200 * GOLD,
      char = main.key, classFile = main.class, guild = guild },
  }, "guild")
  assertEqual(#r.window, 3, "the session window did not receive the rows")
  assertEqual(r.recorded[1], 0, "guild data while away recorded a row")
  assertClean(r, before, count, "guild")
end)

test("Sim e2e: guild data while away arms no context and records nothing (issue #12)", function()
  withRealWorld(function()
    S.withSession("guild", function(sim)
      local seen = 0
      local got = withSessionSpy(function()
        S.chat(function() assertTrue(sim:Step() ~= nil, "the away step did not play") end)
        S.advance(10)
        seen = #NS.State.simLog
      end)
      assertEqual(sim:Status().pos, 1)
      assertTrue(NS.State.openContext == nil, "guild data while away armed a context")
      assertEqual(seen, 0, "guild data while away recorded a row")
      assertEqual(#got, 0, "the session window took a row")
      assertFalse(NS.State.sessionActive == true, "guild data while away started a banking session")
    end)
  end)
end)

test("Sim e2e: onesided records 0 rows and the close drops the held change", function()
  local before, count = S.copy(NS.db.global.ledger), NS.Database:Count()
  local r = play("onesided")
  assertEqual(#r.rows, 0, "the onesided scenario recorded a row")
  assertEqual(#r.window, 0, "the session window took a row")
  assertTrue(hasLine(r.lines, "[Diff] one-sided change never settled; baseline re-anchored"),
    table.concat(r.lines, " | "))
  assertTrue(hasLine(r.lines, "[Store] BANK_FRAME closed, held change dropped"), table.concat(r.lines, " | "))
  assertClean(r, before, count, "onesided")
end)

test("Sim e2e: Restart plays every scenario again from the start, to the same end", function()
  local want = { bank = 3, warband = 4, guild = 3, onesided = 0 }
  for _, name in ipairs(Host.SCENARIOS.names) do
    local before, count = S.copy(NS.db.global.ledger), NS.Database:Count()
    local r = play(name, true)
    assertEqual(#r.rows, want[name], name .. " rows after a restart")
    assertClean(r, before, count, name .. " (restart)")
  end
end)

-- ── the pacing (BL-11, owner report 2026-10-23) ──────────────────────────────────────────────
--
-- The owner's bank run sat a few seconds on one step before it played on. The cause: a step that
-- moves an item the capture gate refuses (the owner blacklists the Hearthstone, which a real bag
-- pool draws; an uncached item under a quality threshold, whose info the client answers late, is
-- the same case) left a complete movement unrecorded, which the engine read as a one-sided change
-- and held for the whole settle window, closing the host gate. Each case asserts every step plays
-- within the step delay plus one gate poll (SimTimeline's GATE_POLL, 0.25 s) of the one before.

local GATE_POLL = 0.25

--- Plays `name` to its end with Run, the mock clock recorded at each step's play; answers the
--- gaps between consecutive plays and the session log's row count.
local function pace(name)
  local times, rows = {}, nil
  withRealWorld(function()
    S.withSession(name, function(sim)
      local play0 = Host.Play
      Host.Play = function(step) times[#times + 1] = mocks.__now return play0(step) end
      local ok, err = pcall(function()
        local done
        S.chat(function() done = S.runToEnd(sim) end)
        assertTrue(done, name .. ": Run did not reach the end")
      end)
      Host.Play = play0
      if not ok then error(err, 0) end
      rows = #NS.State.simLog
    end)
  end)
  local gaps = {}
  for i = 2, #times do gaps[#gaps + 1] = times[i] - times[i - 1] end
  return gaps, rows
end

local function assertPaced(gaps, what)
  local limit = Host.StepDelay() + GATE_POLL + 1e-6
  for i, gap in ipairs(gaps) do
    assertTrue(gap <= limit, ("%s: step %d played %.2f s after step %d (limit %.2f s)")
      :format(what, i + 1, gap, i, limit))
  end
end

test("Sim pacing: the bank scenario plays every step about one step delay apart", function()
  local gaps, rows = pace("bank")
  assertEqual(#gaps, 4, "the five steps did not all play")
  assertPaced(gaps, "bank")
  assertEqual(rows, 3)
end)

test("Sim pacing: a step moving a blacklisted item does not stall the run", function()
  NS.Filters:AddBlacklist(CC)   -- item C, the bank scenario's withdrawal (step 4)
  local ok, err = pcall(function()
    local gaps, rows = pace("bank")
    assertPaced(gaps, "bank, item C blacklisted")
    assertEqual(rows, 2, "the blacklisted withdrawal was recorded")
  end)
  NS.Filters:RemoveBlacklist(CC)
  if not ok then error(err, 0) end
end)

test("Sim pacing: the flask's late item info under a quality threshold does not stall the run", function()
  -- The bonus-link item (step 3, the owner's flask) is not in the client's cache: GetItemInfo
  -- answers nil for it throughout, as for an item whose info has not arrived yet.
  local settings, saved = NS.db.profile.settings, mocks.__items[D]
  local threshold = settings.qualityThreshold
  mocks.__items[D] = nil
  settings.qualityThreshold = 1
  NS.Ledger:RefreshUpvalues()
  local ok, err = pcall(function()
    local gaps, rows = pace("bank")
    assertPaced(gaps, "bank, the flask uncached")
    assertEqual(rows, 2, "the uncached deposit was judged against the threshold")
  end)
  mocks.__items[D] = saved
  settings.qualityThreshold = threshold
  NS.Ledger:RefreshUpvalues()
  if not ok then error(err, 0) end
end)
