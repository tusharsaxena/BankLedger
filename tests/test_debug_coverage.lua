-- tests/test_debug_coverage.lua — WHAT THE DEBUG CONSOLE SAYS (debug-logging-§8 and §9).
--
-- The other suites pin that the sink is gated, formatted and secret-safe. This one pins its
-- CONTENT: the lines a support read of a pasted log needs to reconstruct what happened, and the
-- silence a repeating path owes the 3000-line buffer when nothing it reports has changed.
--
-- Two kinds of case:
--
--   * DIAGNOSIS LINES (§8). The state edges the addon reacts to (the stand-down and stand-up, the
--     combat edges), deferred work held and flushed (the settle hold, the login prune), refusals
--     that name their guard (a window show, a test-mode start, a guild frame showing over an armed
--     bank), and the dependency tail of the [Init] line. Each case says what it is red under.
--   * QUIET STEADY STATE (§9). A reconcile pass that changes nothing writes nothing, however many
--     times the bank's events drive it. Asserted on the whole buffer, not on a count of lines: the
--     console folds a repeat into `(xN)` on the line before, and a folded repeat is still a line
--     the rule forbids.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LS = dofile("tests/ledger_support.lua")
local withContainers = LS.withContainers
local BAG_ID, BANK_ID = LS.BAG_ID, LS.BANK_ID

local S = NS.Schema
local ENABLED_PATH = "settings.enabled"

local function muted(fn)
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
end

--- Every debug line `fn` writes, with logging on for it alone and chat muted. `fn` receives a
--- reader for the buffer so far, for a case that compares the buffer at two points.
local function debugLines(fn)
  local savedDebug = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  local function snapshot()
    local out = {}
    for _, line in ipairs(NS.DebugLog.buffer) do out[#out + 1] = line end
    return out
  end
  local ok, err = pcall(muted, function() fn(snapshot) end)
  local out = snapshot()
  NS.DebugLog:Clear()
  NS.State.debug = savedDebug
  if not ok then error(err, 0) end
  return out
end

--- The lines carrying `[tag]`.
local function tagged(lines, tag)
  local out = {}
  for _, line in ipairs(lines) do
    if line:find("[" .. tag .. "]", 1, true) then out[#out + 1] = line end
  end
  return out
end

local function hasLine(lines, text)
  for _, line in ipairs(lines) do
    if line:find(text, 1, true) then return true end
  end
  return false
end

local function withSettings(values, fn)
  local g = NS.db.profile.settings
  local saved = {}
  for k, v in pairs(values) do saved[k] = g[k]; g[k] = v end
  local ok, err = pcall(fn)
  for k in pairs(values) do g[k] = saved[k] end
  if not ok then error(err, 0) end
end

local function withCombat(inCombat, fn)
  local saved = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return inCombat end
  local ok, err = pcall(fn)
  mocks.InCombatLockdown = saved
  if not ok then error(err, 0) end
end

local function clearContext()
  NS.State.openContext, NS.State.lastSnapshot, NS.Ledger._settleSince = nil, nil, nil
end

-- ── State edges: the stand-down and the stand-up ──────────────────────────────

test("debug: a stand-up writes the event record's one [State] line, and a stand-down none", function()
  -- red under: dropping traceEvents from NS.StandUp (core/BankLedger.lua), or bringing back a host
  -- `stood down` / `stood up` line. The EDGE is the library's `[Lifecycle]` line
  -- (tests/test_debug_library.lua); what only the host knows is how many events the stand-up
  -- registered and which names this client refused, since NS.RegisterEventSafely swallows those.
  local lines = debugLines(function()
    S:Set(ENABLED_PATH, false)
    S:Set(ENABLED_PATH, true)
  end)
  local state = tagged(lines, "State")
  assertEqual(#state, 1, "one line, after the stand-up, got: " .. table.concat(state, " | "))
  assertTrue(state[1]:find("%[State%] events: %d+ registered, 0 unavailable") ~= nil, state[1])
end)

test("debug: a stand-down inside the login prune window says the prune was postponed", function()
  -- red under: dropping the `armed` line from addon:OnEnterWorld, or reading cleanupPending after
  -- step 1 of NS.StandDown clears it. Without both, an armed prune that a stand-down canceled is a
  -- hold with no flush and no word of why.
  local st = NS.State
  local savedDone, savedPending = st.cleanupDone, st.cleanupPending
  st.cleanupDone, st.cleanupPending = false, nil
  local ok, err = pcall(function()
    local lines = debugLines(function()
      NS.addon:OnEnterWorld()
      S:Set(ENABLED_PATH, false)
      S:Set(ENABLED_PATH, true)
    end)
    assertTrue(hasLine(lines, "[Prune] login retention pass armed: runs in 5s"), "no armed line")
    assertTrue(hasLine(lines, "[State] login prune postponed"),
      "the stand-down did not say the prune was postponed")
  end)
  if st.cleanupPending and NS.addon.CancelTimer then NS.addon:CancelTimer(st.cleanupPending) end
  st.cleanupDone, st.cleanupPending = savedDone, savedPending
  if not ok then error(err, 0) end
end)

test("debug: a retention window of Always still writes the prune's one line", function()
  -- red under: PruneOld's early return for `days == 0` staying silent. The login pass's armed line
  -- would then have no flush, and "why was nothing pruned" no answer.
  local saved = NS.db.global.settings.retentionDays
  NS.db.global.settings.retentionDays = 0
  local lines = debugLines(function() NS.Database:PruneOld() end)
  NS.db.global.settings.retentionDays = saved
  assertTrue(hasLine(lines, "[Prune] retention always: nothing pruned"), table.concat(lines, " | "))
end)

-- ── State edges: combat ────────────────────────────────────────────────────────

test("debug: a combat edge under a combat-bound visibility rule writes one [Combat] line", function()
  -- red under: dropping traceCombat from addon:OnCombatChanged. Under `Only out of combat` the pull
  -- is what takes the ledger window, and the log is the only place that can say so.
  NS.Browser:Show()
  local lines
  withCombat(true, function()
    withSettings({ visibility = "outOfCombat" }, function()
      lines = debugLines(function() NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED") end)
    end)
  end)
  local combat = tagged(lines, "Combat")
  assertEqual(#combat, 1, "one line per edge, got: " .. table.concat(combat, " | "))
  assertTrue(combat[1]:find("entered: visibility outOfCombat, hid 1, re-showed 0", 1, true) ~= nil,
    combat[1])
  -- And the way back re-shows what the rule took, on its own line.
  withCombat(false, function()
    withSettings({ visibility = "outOfCombat" }, function()
      lines = debugLines(function() NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED") end)
    end)
  end)
  assertTrue(hasLine(lines, "[Combat] left: visibility outOfCombat, hid 0, re-showed 1"),
    table.concat(lines, " | "))
  NS.Browser:Hide()
end)

test("debug: a combat edge the addon does not react to writes nothing", function()
  -- red under: tracing every PLAYER_REGEN_* edge. Under `always`, with no test mode to end, the
  -- visibility pass is a no-op, and a line per pull is a dungeon's worth of noise in the buffer.
  NS.Browser:Hide()
  local lines
  withCombat(true, function()
    withSettings({ visibility = "always" }, function()
      lines = debugLines(function()
        for _ = 1, 5 do
          NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
          NS.addon:OnCombatChanged("PLAYER_REGEN_ENABLED")
        end
      end)
    end)
  end)
  assertEqual(#lines, 0, "an unreacted edge was traced: " .. table.concat(lines, " | "))
end)

-- ── Refusals name their guard ──────────────────────────────────────────────────

test("debug: a refused ledger-window show names the visibility guard", function()
  -- red under: Browser:Show's early return staying silent. `/bl show` doing nothing is the report;
  -- the guard is the answer.
  NS.Browser:Hide()
  local lines
  withCombat(false, function()
    withSettings({ visibility = "never" }, function()
      lines = debugLines(function() NS.Browser:Show() end)
    end)
  end)
  assertTrue(hasLine(lines, "[UI] window show refused: visibility never"), table.concat(lines, " | "))
end)

test("debug: a session start with the session window switched off says why it did not show", function()
  -- red under: the [Session] started line losing its guard. A bank visit with no session window is
  -- otherwise indistinguishable from a session that never started.
  local lines
  withSettings({ showSessionWindow = false }, function()
    lines = debugLines(function()
      NS.SessionWindow:StartSession("BANK_FRAME")
      NS.SessionWindow:EndSession()
    end)
  end)
  assertTrue(hasLine(lines, "[Session] started (BANK_FRAME), window not shown: session window off"),
    table.concat(lines, " | "))
end)

test("debug: `/bl session` traces each outcome, naming the guard that holds the window shut", function()
  -- red under: SW:TogglePreview writing no line. A refusal (a real session is open) and a preview
  -- that SW:Show holds shut both print a chat reply while nothing changes on screen, so the trace
  -- must say which guard was the reason.
  local SW = NS.SessionWindow
  local savedActive, savedPreview = NS.State.sessionActive, SW.previewSession
  local lines
  local ok, err = pcall(function()
    NS.State.sessionActive, SW.previewSession = false, false
    withSettings({ showSessionWindow = false }, function()
      lines = debugLines(function()
        SW:TogglePreview()
        SW:TogglePreview()
      end)
    end)
    assertTrue(hasLine(lines, "[Session] preview on, window not shown: session window off"),
      table.concat(lines, " | "))
    assertTrue(hasLine(lines, "[Session] preview off"), table.concat(lines, " | "))
    lines = debugLines(function() SW:TogglePreview(); SW:TogglePreview() end)
    assertFalse(hasLine(lines, "window not shown"), table.concat(lines, " | "))
    assertTrue(hasLine(lines, "[Session] preview on"), table.concat(lines, " | "))
    NS.State.sessionActive = true
    lines = debugLines(function() SW:TogglePreview() end)
    assertTrue(hasLine(lines, "[Session] preview refused: a real session is open"),
      table.concat(lines, " | "))
  end)
  NS.State.sessionActive, SW.previewSession = savedActive, savedPreview
  NS.State.sessionEntries = {}
  SW:Hide()
  if not ok then error(err, 0) end
end)

test("debug: test mode traces its start, its stop and a refused start", function()
  -- red under: LT:SetTestMode writing no line. `/bl test` goes through no write seam, so without
  -- these the log cannot say that the rows a reporter saw were the sample ledger.
  local lines
  local ok, err = pcall(function()
    withCombat(true, function()
      lines = debugLines(function() NS.LedgerTable:SetTestMode(true) end)
    end)
    assertTrue(hasLine(lines, "[Table] test mode start refused: in combat"), table.concat(lines, " | "))
    withCombat(false, function()
      lines = debugLines(function()
        NS.LedgerTable:SetTestMode(true)
        NS.LedgerTable:SetTestMode(false)
      end)
    end)
    assertTrue(hasLine(lines, "[Table] test mode on: "), table.concat(lines, " | "))
    assertTrue(hasLine(lines, "[Table] test mode off"), table.concat(lines, " | "))
  end)
  NS.State.testRecords = nil
  NS.Browser:Hide()
  if not ok then error(err, 0) end
end)

test("debug: the guild frame showing over an armed bank frame says the context was kept", function()
  -- red under: the OnShow hook's refusal staying silent. A guild visit made while the bank frame is
  -- still armed records nothing on the guild side, and this line is why.
  clearContext()
  NS.Ledger._guildHooked = nil
  NS.Ledger:HookGuildBankFrame()
  local lines = debugLines(function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__openGuildBank()
  end)
  clearContext()
  assertTrue(hasLine(lines, "[Store] GUILD_BANK shown while BANK_FRAME is open: context kept"),
    table.concat(lines, " | "))
end)

-- ── Dependencies, once, on the [Init] line ────────────────────────────────────

test("debug: the [Init] summary carries the dependency tail", function()
  -- red under: dropping dependencySummary from NS.InitSummary. The loaded bank-replacing addons are
  -- the first suspect when a visit records nothing, and the line the library writes when logging is
  -- switched on is the one moment "once, at enable" can be read.
  -- The launcher is NOT in the tail any more: its own Register lines land through the console's
  -- at-enable queue right after this one (tests/test_debug_library.lua), so a launcher fact here
  -- would be the second line for one state.
  local s = NS.InitSummary()
  assertTrue(s:find(", bank addons: [^,]+$") ~= nil, s)
  assertEqual(s:find("launcher", 1, true), nil, s)
end)

-- ── Deferred work: the settle hold ─────────────────────────────────────────────

test("debug: a one-sided change writes one hold line, and its settling writes the flush", function()
  -- red under: dropping traceHold from settleBaseline. The hold is the deferred work behind every
  -- warband deposit; without its two lines a movement recorded seconds late, or never, is silent.
  local lines
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 171276, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    lines = debugLines(function()
      NS.Ledger:OpenContext("BANK_FRAME")
      mocks.__containers[BAG_ID][1] = nil
      NS.Ledger:Reconcile()   -- one-sided: the hold starts
      NS.Ledger:Reconcile()   -- still one-sided: the same hold, no second line
      mocks.__containers[BANK_ID][1] = { itemID = 171276, count = 1 }
      NS.Ledger:Reconcile()   -- completes
    end)
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
  local held, settled = 0, 0
  for _, line in ipairs(tagged(lines, "Diff")) do
    if line:find("one-sided change: baseline held", 1, true) then held = held + 1 end
    if line:find("held change settled after", 1, true) then settled = settled + 1 end
  end
  assertEqual(held, 1, "one hold line per hold: " .. table.concat(lines, " | "))
  assertEqual(settled, 1, "the settle is the hold's flush: " .. table.concat(lines, " | "))
end)

test("debug: a close that drops a held change says so", function()
  -- red under: CloseContext's closed line losing the held flag. A hold line with no end is only
  -- evidence if the close that threw the change away is marked.
  local lines
  withContainers({
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 1 },
  }, function()
    lines = debugLines(function()
      NS.Ledger:OpenContext("BANK_FRAME")
      mocks.__containers[BAG_ID][1] = { itemID = 19019, count = 1 }   -- looted, never balances
      NS.Ledger:Reconcile()
      NS.Ledger:CloseContext()
    end)
  end)
  assertTrue(hasLine(lines, "[Store] BANK_FRAME closed, held change dropped"),
    table.concat(lines, " | "))
end)

-- ── Quiet steady state: the reconcile pass ─────────────────────────────────────

test("debug: reconcile passes that change nothing write nothing after the first", function()
  -- red under: reconcileStore writing its [Diff] line on every pass (the traceDiff change gate
  -- removed). An open bank is driven by BAG_UPDATE_DELAYED, PLAYER_MONEY, a guild member's
  -- deposit and the settle deadline; each unchanged pass used to repeat one line per store.
  -- Compared as the whole buffer, so a repeat the console folds into `(xN)` fails too.
  local first, after
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 2589, count = 5 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    debugLines(function(snapshot)
      NS.Ledger:OpenContext("BANK_FRAME")
      NS.Ledger:Reconcile()
      first = snapshot()
      for _ = 1, 10 do NS.Ledger:Reconcile() end
      after = snapshot()
    end)
    NS.Ledger:CloseContext()
  end)
  assertTrue(#tagged(first, "Diff") >= 1, "the first pass after an open still says what it saw")
  assertEqual(table.concat(after, "\n"), table.concat(first, "\n"),
    "ten unchanged passes changed the buffer")
end)

test("debug: a pass that records a movement still writes its [Diff] and [Move] lines", function()
  -- The other half of the gate: a real change is never silenced. red under: gating the [Diff] line
  -- on the summary alone, which would drop a pass whose kinds count happened to match the last.
  local lines
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 2592, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    lines = debugLines(function()
      NS.Ledger:OpenContext("BANK_FRAME")
      NS.Ledger:Reconcile()
      mocks.__containers[BAG_ID][1] = nil
      mocks.__containers[BANK_ID][1] = { itemID = 2592, count = 1 }
      NS.Ledger:Reconcile()
    end)
    clearContext()
  end)
  NS.Database:Delete(function(e) return e.itemID == 2592 end)
  assertTrue(hasLine(lines, "-> 1 moves"), table.concat(lines, " | "))
  assertTrue(hasLine(lines, "[Move] BANK: recorded 1, skipped 0"), table.concat(lines, " | "))
end)

test("debug: a pass that skips several movements writes one [Skip] line naming each", function()
  -- red under: tracing the skip inside Ledger:Record, once per movement (the shape before
  -- DL-BL-02). A deposit of thirty blacklisted stacks was thirty lines on one bag scan; the pass
  -- now writes one, and still names every item and its reason (debug-logging-§9).
  local lines
  NS.Filters:AddBlacklist(2589)
  NS.Filters:AddBlacklist(2592)
  local ok, err = pcall(function()
    withContainers({
      [BAG_ID]  = { slots = 2, [1] = { itemID = 2589, count = 5 }, [2] = { itemID = 2592, count = 3 } },
      [BANK_ID] = { slots = 2 },
    }, function()
      lines = debugLines(function()
        NS.Ledger:OpenContext("BANK_FRAME")
        mocks.__containers[BAG_ID][1], mocks.__containers[BAG_ID][2] = nil, nil
        mocks.__containers[BANK_ID][1] = { itemID = 2589, count = 5 }
        mocks.__containers[BANK_ID][2] = { itemID = 2592, count = 3 }
        NS.Ledger:Reconcile()
      end)
      clearContext()
    end)
  end)
  NS.Filters:RemoveBlacklist(2589)
  NS.Filters:RemoveBlacklist(2592)
  if not ok then error(err, 0) end
  local skip = tagged(lines, "Skip")
  assertEqual(#skip, 1, "one line per pass: " .. table.concat(skip, " | "))
  assertTrue(skip[1]:find("BANK: 2589 DEPOSIT (blacklist), 2592 DEPOSIT (blacklist)", 1, true) ~= nil,
    skip[1])
  assertTrue(hasLine(lines, "[Move] BANK: recorded 0, skipped 2"), table.concat(lines, " | "))
end)

test("debug: the [Diff] gate starts fresh on every open", function()
  -- red under: OpenContext not forgetting its stores' [Diff] gate keys. A second visit that finds the same store as
  -- the first would otherwise open with no [Diff] line at all.
  local count = 0
  withContainers({
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 1 },
  }, function()
    local lines = debugLines(function()
      for _ = 1, 2 do
        NS.Ledger:OpenContext("BANK_FRAME")
        NS.Ledger:Reconcile()
        NS.Ledger:CloseContext()
      end
    end)
    for _, line in ipairs(tagged(lines, "Diff")) do
      if line:find("BANK: ", 1, true) and not line:find("WARBAND", 1, true) then
        count = count + 1
      end
    end
  end)
  assertTrue(count >= 2, "each visit's first pass writes its line, got " .. count)
  assertFalse(NS.State.openContext ~= nil, "the fixture left a context armed")
end)
