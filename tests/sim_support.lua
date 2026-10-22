-- tests/sim_support.lua — the simulator suites' shared session fixture (not a suite).
--
-- tests/test_sim_session.lua and tests/test_sim_drivers.lua both run the addon's OWN simulator,
-- NS.Sim, in the shared environment: it is the one instance bound to NS.SimSeam, and one seam binds
-- one session for good, so an isolated copy would not be the session the addon runs. Every case
-- therefore starts and stops inside `withSession`, which restores what it touched whatever happens:
-- the mock's real containers, the real guild frame's visibility, the chat frame, the ledger window,
-- and the timer queue. Each pending AceTimer or session timer is drained before the next case.
if rawget(_G, "__BL_SIM_SUPPORT") then return rawget(_G, "__BL_SIM_SUPPORT") end

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks

local M = {}

M.BACKPACK, M.BANK_TAB_1, M.WARBAND_TAB_1 = 0, 6, 12   -- the mock's verbatim Enum.BagIndex ids

-- The REAL backpack the pool is drawn from: four distinct cached items, one with a bonus-id link.
-- Sorted by id, the pool is 2589, 4306, 19019 (the bonus link), 171276.
-- Field 13 of the item string is the bonus-id count: one bonus id, 6646.
M.BONUS_LINK = "|Hitem:19019::::::::::::1:6646|h[Thunderfury]|h"
local function realBackpack()
  return {
    slots = 16,
    { itemID = 4306, link = "|Hitem:4306::::::::::|h[Silk Cloth]|h", count = 7 },
    { itemID = 2589, link = "|Hitem:2589::::::::::|h[Linen Cloth]|h", count = 3 },
    { itemID = 19019, link = M.BONUS_LINK, count = 1 },
    { itemID = 171276, link = "|Hitem:171276::::::::::|h[Spectral Flask]|h", count = 2 },
    { itemID = 2589, link = "|Hitem:2589::::::::::|h[Linen Cloth]|h", count = 9 },
  }
end
M.REAL_LINEN = 12   -- the real backpack's 2589 count; the simulated backpack holds 40 of it

--- Every chat line `fn` prints, with the chat frame muted.
function M.chat(fn)
  local out = {}
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

--- True when one of `lines` contains `text`.
function M.has(lines, text)
  for _, line in ipairs(lines) do
    if tostring(line):find(text, 1, true) then return true end
  end
  return false
end

--- Drain every pending timer (a debounce, a lag half, a guarded reply), repeatedly: a timer may arm
--- the next one. Bounded, so a runaway chain fails the case instead of hanging the run.
function M.drain()
  for _ = 1, 20 do
    if mocks.__fireTimers() == 0 then return end
  end
  error("timers kept re-arming", 2)
end

--- A time-ordered clock over the kit's timer queue, for the cases that need real elapsed time (the
--- settle window, a lag half, Run's step delays and gate polls). `__fireTimers` runs every queued
--- entry at once with the clock standing still; this instead moves `__now` to each entry's due time
--- (its queue time plus its `delay`) and runs the entries one at a time, earliest first, in queue
--- order on a tie. It stops when `done()` answers true, when nothing is left, or when the next entry
--- falls more than `seconds` ahead of the start; entries not run go back on the queue with the rest
--- of their delay. Answers whether `done()` was met.
function M.advance(seconds, done)
  local stop = mocks.__now + seconds
  local pending, seq = {}, 0
  local function collect()
    local q = mocks.__timers
    if #q == 0 then return end
    mocks.__timers = setmetatable({}, getmetatable(q))
    for _, t in ipairs(q) do
      seq = seq + 1
      pending[#pending + 1] = { t = t, due = mocks.__now + (tonumber(t.delay) or 0), seq = seq }
    end
  end
  local function canceled(t) return t.cancelled or (t.timer and t.timer.cancelled) end
  local met = false
  for _ = 1, 10000 do
    collect()
    if done and done() then met = true break end
    local best
    for i, p in ipairs(pending) do
      if not canceled(p.t) and (not best or p.due < pending[best].due
        or (p.due == pending[best].due and p.seq < pending[best].seq)) then
        best = i
      end
    end
    if not best or pending[best].due > stop then break end
    local p = table.remove(pending, best)
    if p.due > mocks.__now then mocks.__now = p.due end
    p.t.fn()
  end
  for _, p in ipairs(pending) do
    if not canceled(p.t) then
      p.t.delay = math.max(0, p.due - mocks.__now)
      mocks.__timers[#mocks.__timers + 1] = p.t
    end
  end
  return met
end

--- Run the started session's whole timeline with `Run` on the clock above, and answer whether it
--- reached its end within `limit` simulated seconds (default 120).
function M.runToEnd(sim, limit)
  local ok, why = sim:Run()
  assert(ok, "Run refused: " .. tostring(why))
  return M.advance(limit or 120, function()
    local st = sim:Status()
    return st.total > 0 and st.pos == st.total and not st.playing
  end)
end

--- The real world a session must refuse beside or leave alone, made quiet: no real frame open, the
--- real guild frame hidden, the real backpack filled.
local function quietWorld()
  local saved = {
    guild = mocks.__guildVisible, backpack = mocks.__containers[M.BACKPACK],
    open = NS.State.openContext,
  }
  mocks.__guildVisible = false
  mocks.__containers[M.BACKPACK] = realBackpack()
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
  return saved
end

local function restore(saved)
  if NS.Sim:IsActive() then NS.Sim:Stop("stop") end
  M.drain()
  mocks.__guildVisible = saved.guild
  mocks.__containers[M.BACKPACK] = saved.backpack
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
  NS.Ledger._settleSince = nil
  if NS.Browser and NS.Browser.Hide then NS.Browser:Hide() end
end

--- Runs fn(sim, lines) inside the quiet world, chat captured into `lines`. `scenario` nil runs fn
--- with no session started (a refusal case); otherwise the session is started first and must start.
function M.withSession(scenario, fn)
  local saved = quietWorld()
  local lines = {}
  local ok, err = pcall(function()
    local more = M.chat(function()
      if scenario then
        local started, why = NS.Sim:Start{ scenario = scenario }
        assert(started, "the simulation did not start: " .. tostring(why))
      end
      fn(NS.Sim, lines)
    end)
    for _, l in ipairs(more) do lines[#lines + 1] = l end
  end)
  M.chat(function() restore(saved) end)
  if not ok then error(err, 0) end
  return lines
end

--- Runs fn(seen) with L:Dispatch replaced by a recorder: each delivered event is { event, ... }.
--- Nothing reaches the capture engine while it runs.
function M.withDispatchSpy(fn)
  local L = NS.Ledger
  local original, seen = L.Dispatch, {}
  L.Dispatch = function(_, event, ...) seen[#seen + 1] = { event, ... } return 1 end
  local ok, err = pcall(fn, seen)
  L.Dispatch = original
  if not ok then error(err, 0) end
end

--- `seen` as "EVENT(arg)" strings joined by ", ".
function M.sequence(seen)
  local out = {}
  for _, e in ipairs(seen) do
    out[#out + 1] = e[2] ~= nil and ("%s(%s)"):format(e[1], tostring(e[2])) or e[1]
  end
  return table.concat(out, ", ")
end

--- How many of `itemID` a simulated container (or guild tab) holds.
function M.count(container, itemID)
  local n = 0
  for slot = 1, (container and container.size or 0) do
    local s = container[slot]
    if s and s.itemID == itemID then n = n + s.count end
  end
  return n
end

--- Plain deep equality, for the saved-ledger before/after check.
function M.deepEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not M.deepEqual(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

--- A deep copy, for the same check.
function M.copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = M.copy(x) end
  return out
end

rawset(_G, "__BL_SIM_SUPPORT", M)
return M
