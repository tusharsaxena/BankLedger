-- tests/test_disabled.lua — THE STAND-DOWN CONFORMANCE SUITE (slash-commands-§7).
--
-- Disabled means the addon is NOT RUNNING. Not hidden, not quiet, not skipping a repaint. A player
-- who unticks *Enable Bank Ledger* has asked for the same outcome they would get by unticking the
-- addon in Blizzard's own AddOns list, minus the /reload.
--
-- ── WHY EVERY ASSERTION BELOW IS ON THE REGISTRATION SET ─────────────────────────────────────
--
-- Eleven addons in this collection, this one among them, implemented "disabled" as a DRAW GATE: a
-- stored boolean read as one rung of a show ladder and one rung of a capture gate. The frames went
-- away, every event stayed registered, and the client went on walking the registration list on
-- every bag update, building the argument frame, entering Lua and running the comparison that
-- decided to leave. From outside that is indistinguishable from standing down, which is how the
-- shape survived eleven audits.
--
-- A SUITE THAT ASSERTS "THE HANDLER RETURNED EARLY" CERTIFIES THE DRAW GATE IT EXISTS TO CATCH,
-- because an early return is exactly what a draw gate does. So nothing here reads a handler's
-- return value. Every case reads the kit's recording registry — `mocks.__registrations()`,
-- `mocks.__timers()`, `mocks.__shownFrames()`, `mocks.__svWrites()`, `mocks.__printed()` — which
-- is the only surface that can tell the two apart.
--
-- `mocks.__fire` is deliberately NOT the proof on its own: a frame's `__fire` reaches its OnEvent
-- whether or not it ever registered, so a case that only fires an event can pass against broken
-- code. Firing is the step-6 belt; the registration assertions are the substance.
--
-- ── WHAT SURVIVES, AND WHY IT IS ALLOWED TO ──────────────────────────────────────────────────
--
-- Setup, never features: the chat command and the dispatcher, the settings category and the panel
-- body (including the panel's own live-refresh bus targets), the AceDB handle and its profile
-- callbacks, and the launcher's registration. The allow-list below is built from the panel's two
-- targets BY IDENTITY rather than by event name, so it can never quietly excuse a module's target
-- that happens to watch the same message.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = NS.Schema
local ENABLED_PATH = "settings.enabled"
local HOLD_PERF = (LibStub and LibStub("LibKa0s-Lifecycle-1.0", true) or {}).HOLD_PERF or "perf"

-- ── The SavedVariables write survey ──────────────────────────────────────────────────────────
--
-- tests/wow_mock.lua's AceDB override (override 5) builds its stores itself, so the kit's AceDB
-- fake never records a root for them and `mocks.__svWrites()` would diff NOTHING: every "no write"
-- below would pass over an empty survey. The kit's answer for a root it did not create is
-- `__watchSv(globalName)`, so the suite names `BankLedgerDB` -- the global the TOC declares, and
-- the one AceDB is a view onto in the client.
--
-- RE-POINTED BEFORE EVERY BASELINE, and that is not a workaround: tests/degraded_env.lua builds
-- whole extra copies of the addon, each with its own store, so the suite says WHICH copy it is
-- asking about -- the live one -- every time it re-baselines. The control case after step 6 is
-- what proves this survey can see a write at all.
mocks.__watchSv("BankLedgerDB")

local function watchStore()
  BankLedgerDB = { global = NS.db.global, profiles = { Default = NS.db.profile } }
  mocks.__resetSvWrites()
end

local function captureChat(fn)
  local out = {}
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

-- ── WHOSE REGISTRATIONS ARE THESE ────────────────────────────────────────────────────────────
--
-- The build's registry holds everything: this addon's, the panel body's two live-refresh targets
-- (which MUST survive -- the panel is setup), and whatever fixtures earlier suites left behind on
-- tables of their own. So ownership is established BY TARGET IDENTITY and by nothing else.
--
-- NOT AS A TEMPORAL DIFF -- "what appeared between disabled and enabled" -- which was the first
-- shape this file took and which a DRAW GATE passes: with the registrations never removed they are
-- present in both samples, the difference is empty, and the suite certifies the thing it exists to
-- catch. Ownership is remembered instead, and the set only ever GROWS: a module's `__ev` is nil
-- while the addon is down, so a survivor would otherwise become unattributable at exactly the
-- moment it matters.
local OWNERS = {}

local BUS_MODULES = { "Ledger", "Browser", "SessionWindow", "Insights" }

local function noteOwners()
  if NS.addon then OWNERS[NS.addon] = "addon" end
  for _, name in ipairs(BUS_MODULES) do
    local module = NS[name]
    if module and module.__ev then OWNERS[module.__ev] = name end
  end
  return OWNERS
end

--- Every LIVE registration this addon owns, as a sorted array of `"<kind>/<event>"`.
local function registrations()
  local out = {}
  for _, reg in ipairs(mocks.__registrations()) do
    if OWNERS[reg.target] then
      out[#out + 1] = { key = OWNERS[reg.target] .. ":" .. reg.kind .. "/" .. tostring(reg.event)
        .. (reg.unit and ("/" .. reg.unit) or ""), target = reg.target, event = reg.event }
    end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

local function keysOf(regs)
  local out = {}
  for i, r in ipairs(regs) do out[i] = r.key end
  return out
end

local function counted(list)
  local out = {}
  for _, k in ipairs(list) do out[k] = (out[k] or 0) + 1 end
  return out
end

local function describe(regs)
  return table.concat(keysOf(regs), ", ")
end

--- The frames shown in `after` that were not shown in `before`.
local function newlyShown(before, after)
  local was = {}
  for _, f in ipairs(before) do was[f] = true end
  local out = {}
  for _, f in ipairs(after) do if not was[f] then out[#out + 1] = f end end
  return out
end

--- Bring the addon DOWN, then back UP through the one write seam, and report what the stand-up
--- added: the registration set R_on, and the frames it put on screen.
---
--- Down first, deliberately. The baseline has to be what THIS addon registers when it is enabled,
--- and the only way to know that is to watch it arrive.
local function baseline()
  S:Set(ENABLED_PATH, false)
  local F_pre = mocks.__shownFrames()
  S:Set(ENABLED_PATH, true)
  noteOwners()
  NS.Browser:Show()
  NS.SessionWindow:Show()
  return registrations(), newlyShown(F_pre, mocks.__shownFrames())
end

--- Disable through the SINGLE WRITE SEAM -- never by calling NS.StandDown directly. The suite has
--- to exercise the route the checkbox and the verb take, or it proves only that a teardown function
--- works when called.
local function disable() S:Set(ENABLED_PATH, false) end
local function enable()  S:Set(ENABLED_PATH, true)  end

-- ── 1-3. The registration set ─────────────────────────────────────────────────

test("disabled: the baseline is non-empty, and the disable empties the registration set", function()
  -- THE ASSERTION THE WHOLE SUITE EXISTS FOR, and the one that reddened this addon at HEAD.
  --
  -- red under: dropping the `ad:UnregisterAllEvents()` or the bus-target teardown in NS.StandDown
  -- (core/BankLedger.lua), or reverting `settings.enabled` to a rung of the capture gate with the
  -- registrations left in place -- which is what this addon shipped before the latch.
  local R_on = baseline()
  assertTrue(#R_on > 0,
    "the baseline is empty: an addon that registers nothing when enabled passes every later "
    .. "assertion trivially")

  disable()
  local survivors = registrations()
  assertEqual(#survivors, 0, "still registered while disabled: " .. describe(survivors))

  -- By name as well as by count, because a count can be right for the wrong reason.
  local live = counted(keysOf(survivors))
  for _, key in ipairs(keysOf(R_on)) do
    assertEqual(live[key], nil, "`" .. key .. "` survived the stand-down")
  end
  enable()
end)

-- ── 4. Nothing left to wake up ────────────────────────────────────────────────

--- Empty the kit's timer queue while keeping it CALLABLE: `mocks.__timers()` answers the live set
--- through the queue's metatable, so a bare `{}` would take that answer away. An earlier suite can
--- leave a plain C_Timer.After entry queued (the options panel's 0.4 s LoadItem check), and a case
--- that asserts "nothing is armed" has to start from a queue that holds only what it armed itself.
local function clearTimerQueue()
  mocks.__timers = setmetatable({}, getmetatable(mocks.__timers))
end

--- Run `fn` with the retention prune's session state reset and PruneOld swapped for a counter, and
--- put both back afterwards whatever `fn` did. Answers the counter's reader.
local function withPruneWindow(fn)
  local st, db = NS.State, NS.Database
  local savedDone, savedPending, savedPrune = st.cleanupDone, st.cleanupPending, db.PruneOld
  local pruned = 0
  db.PruneOld = function() pruned = pruned + 1 end
  st.cleanupDone, st.cleanupPending = false, nil
  clearTimerQueue()
  local ok, err = pcall(fn, function() return pruned end)
  if st.cleanupPending and NS.addon.CancelTimer then NS.addon:CancelTimer(st.cleanupPending) end
  db.PruneOld = savedPrune
  st.cleanupDone, st.cleanupPending = savedDone, savedPending
  clearTimerQueue()
  if not ok then error(err, 0) end
end

test("disabled: no timer, ticker or OnUpdate is left armed", function()
  -- red under: dropping the CancelAllTimers or the per-module CancelPending walk in NS.StandDown.
  -- A coalescing repaint timer that re-arms and then discovers it has nothing to paint is the most
  -- expensive shape slash-commands-§7 names.
  --
  -- red under: arming the retention prune through C_Timer.After (core/BankLedger.lua's
  -- OnEnterWorld). A bare After returns no handle, so CancelAllTimers cannot reach it and it wakes
  -- five seconds later to find the latch. The login PEW is driven here, inside the window.
  withPruneWindow(function()
    local R_on = baseline()
    NS.Browser:ScheduleLedgerRefresh()
    NS.Ledger:ScheduleReconcile()
    NS.addon:OnEnterWorld()
    disable()
    assertEqual(#mocks.__timers(), 0, "something is still going to wake up")

    -- And nothing re-arms for the rest of the run. Driven the way the client would drive it: every
    -- event the enabled addon was registered for, fired at the mock. Nothing reaches a handler,
    -- because nothing is registered -- which is the point.
    for _, r in ipairs(R_on) do if r.event then mocks.__fire(r.event) end end
    mocks.__fire("PLAYER_REGEN_DISABLED")
    assertEqual(#mocks.__timers(), 0, "a stood-down addon armed a fresh timer")
    enable()
  end)
end)

test("disabled: a stand-down inside the prune window postpones the prune rather than canceling it",
function()
  -- The login PEW arms the retention prune five seconds out; the player disables inside those five
  -- seconds. The prune must not run while disabled -- it writes SavedVariables -- but the session
  -- must not lose it either: the next PEW after the stand-up arms it again, and it runs once.
  --
  -- red under: setting NS.State.cleanupDone BEFORE the timer (the latch-before-timer shape), which
  -- skipped retention for the rest of the session; and under a C_Timer.After that the stand-down
  -- cannot cancel.
  withPruneWindow(function(prunedCount)
    local st = NS.State
    NS.addon:OnEnterWorld()
    disable()
    assertEqual(#mocks.__timers(), 0, "the prune timer outlived the stand-down")
    assertEqual(st.cleanupDone, false, "a canceled prune latched the session as pruned")
    assertEqual(prunedCount(), 0, "the prune ran while disabled")

    enable()
    NS.addon:OnEnterWorld()
    mocks.__fireTimers()
    assertEqual(prunedCount(), 1, "the next PEW after the stand-up did not prune exactly once")
    assertEqual(st.cleanupDone, true, "the prune ran but the session latch was not set")
  end)
end)

-- ── 4b. The capture context ───────────────────────────────────────────────────
--
-- The fields a bank visit arms -- the open context, its baseline snapshot, the settle window and the
-- banking session -- are cleared only by events (a close, or the guild-bank disarm), and every one of
-- those events is unregistered while the addon is down. So the stand-down drops them itself. Without
-- that, the stand-up diffs against a baseline taken before the switch was thrown and records what
-- the player did while the addon was off.

local LS = dofile("tests/ledger_support.lua")
local ITEM = 171276

--- Put the capture context and the banking session back to "no visit", whatever the case left.
local function clearVisit()
  NS.State.openContext, NS.State.lastSnapshot, NS.Ledger._settleSince = nil, nil, nil
  if NS.State.sessionActive and NS.SessionWindow.EndSession then NS.SessionWindow:EndSession() end
  NS.Database:Delete(function(e) return e.itemID == ITEM end)
  clearTimerQueue()
end

test("disabled at the bank: a movement made while disabled is not recorded after re-enable",
function()
  -- red under: removing the DropContext call from NS.StandDown (core/BankLedger.lua). The context
  -- and its pre-disable baseline survive, the stand-up re-registers BAG_UPDATE_DELAYED, and the
  -- next pass diffs the deposit made while the addon was off into a row.
  baseline()
  local ok, err = pcall(LS.withContainers, {
    [LS.BAG_ID]  = { slots = 1, [1] = { itemID = ITEM, count = 5 } },
    [LS.BANK_ID] = { slots = 1 },
  }, function()
    mocks.__fire("BANKFRAME_OPENED")
    assertTrue(NS.State.openContext ~= nil, "the bank open did not arm a context")
    local before = #NS.db.global.ledger
    disable()
    mocks.__containers[LS.BAG_ID][1] = nil
    mocks.__containers[LS.BANK_ID][1] = { itemID = ITEM, count = 5 }
    enable()
    mocks.__fire("BAG_UPDATE_DELAYED")
    mocks.__fireTimers()
    assertEqual(#NS.db.global.ledger, before, "a movement made while disabled was recorded")
  end)
  clearVisit()
  if not ok then error(err, 0) end
end)

test("disabled at the bank: the stand-down disarms the context and ends the session", function()
  -- red under: removing the DropContext call from NS.StandDown (core/BankLedger.lua). The context
  -- stays armed across the stand-down, so away from any bank every PLAYER_MONEY after the stand-up
  -- queues a full rescan, and the banking session never ends.
  baseline()
  local ok, err = pcall(LS.withContainers, {
    [LS.BAG_ID]  = { slots = 1, [1] = { itemID = ITEM, count = 5 } },
    [LS.BANK_ID] = { slots = 1 },
  }, function()
    mocks.__fire("BANKFRAME_OPENED")
    assertTrue(NS.State.sessionActive == true, "the bank open did not start a session")
    disable()
    assertEqual(NS.State.openContext, nil, "the open context survived the stand-down")
    assertEqual(NS.State.lastSnapshot, nil, "the baseline survived the stand-down")
    assertEqual(NS.Ledger._settleSince, nil, "the settle window survived the stand-down")
    assertEqual(NS.State.sessionActive, false, "the banking session survived the stand-down")
    mocks.__fire("BANKFRAME_CLOSED")   -- walked away while off; nothing is registered to hear it
    enable()
    clearTimerQueue()
    mocks.__fire("PLAYER_MONEY")
    assertEqual(#mocks.__timers(), 0, "a stood-up addon away from any bank queued a rescan")
  end)
  clearVisit()
  if not ok then error(err, 0) end
end)

-- ── 5. Nothing on screen ──────────────────────────────────────────────────────

test("disabled: every frame that was shown is hidden, and the show ladder keeps it shut", function()
  -- Hidden AT THE SOURCE, not imperatively: NS.Util.VisibilityAllows answers no while the latch is
  -- down, so a Show called afterwards -- by a settings change, a combat transition, a verb -- puts
  -- nothing back.
  --
  -- red under: removing the IsStoodDown rung from NS.Util.VisibilityAllows (core/Util.lua).
  local _, F_on = baseline()
  assertTrue(#F_on > 0, "the baseline showed no frame at all")

  disable()
  local stillUp = {}
  for _, f in ipairs(mocks.__shownFrames()) do stillUp[f] = true end
  for _, f in ipairs(F_on) do
    assertFalse(stillUp[f] == true, "a frame the addon put up is still up while disabled")
  end

  NS.Browser:Show()
  NS.SessionWindow:Show()
  assertFalse(NS.Browser:GetWindow() ~= nil and NS.Browser:GetWindow():IsShown(),
    "the ledger window re-opened while the addon was disabled")
  assertFalse(NS.SessionWindow:IsShown(), "the session window re-opened while the addon was disabled")
  enable()
end)

-- ── 6. Fire everything at it anyway ───────────────────────────────────────────

test("disabled: firing every baseline event writes nothing, prints nothing and shows nothing",
function()
  -- The client will not fire these, because nothing is registered. A SURVIVOR would receive them,
  -- so they are fired anyway -- including the combat-entry event by name, which is the one that
  -- catches a `locked = true` write and a chat line on entering combat while disabled.
  --
  -- __fireUnconditional is the falsification half: it reaches the addon's handlers THOUGH they are
  -- unregistered, so "nothing happened" is a claim about this addon rather than about a harness
  -- that has lost the ability to dispatch. Its own writes are measured separately and are allowed
  -- to be zero only because the handlers themselves do nothing while down.
  --
  -- red under: a handler that writes SavedVariables or prints while the latch is down, or a
  -- registration left in place for any of these events.
  local R_on = baseline()
  local events = {}
  for _, r in ipairs(R_on) do if r.event then events[r.event] = true end end
  events.PLAYER_REGEN_DISABLED = true
  events.PLAYER_REGEN_ENABLED = true
  events.PLAYER_LOGOUT = true

  disable()
  watchStore()
  mocks.__resetPrinted()
  local shownBefore = #mocks.__shownFrames()

  local delivered = 0
  for event in pairs(events) do delivered = delivered + mocks.__fire(event) end
  assertEqual(delivered, 0, "the client still reached a handler: something is registered")

  -- And the unconditional half: every owner target, every event, registered or not. A handler
  -- that survived as a method still runs here, so its write or its line lands in the surveys below.
  for target in pairs(OWNERS) do
    for event in pairs(events) do mocks.__fireUnconditional(target, event) end
  end

  local writes = mocks.__svWrites()
  assertEqual(#writes, 0,
    "a SavedVariables write originated from a game event while disabled: "
    .. (writes[1] and writes[1].path or ""))
  assertEqual(#mocks.__printed(), 0, "a disabled addon said something to the player")
  assertEqual(#mocks.__shownFrames(), shownBefore, "an event put a frame on screen while disabled")
  enable()
end)

test("disabled: the CONTROL -- the write and print surveys really would catch a survivor", function()
  -- Step 6's silence is true of a correctly stood-down addon AND of a harness that has lost the
  -- ability to see a write or a line at all. This plants a survivor of exactly the shape §7 names --
  -- a handler still on the addon table, reachable by the event's own name -- and proves both
  -- surveys see it. Without this case, step 6 is asserting on its own silence.
  --
  -- red under: the SavedVariables watch or the print capture going blind.
  baseline()
  disable()
  watchStore()
  mocks.__resetPrinted()
  local settings = NS.db.global.settings
  local savedLocked = settings.locked
  NS.addon.PLAYER_REGEN_DISABLED = function()
    settings.locked = not settings.locked
    NS.Print("survivor")
  end
  local ok, err = pcall(function()
    assertEqual(mocks.__fireUnconditional(NS.addon, "PLAYER_REGEN_DISABLED"), 1,
      "the kit could not reach a planted survivor at all")
    assertTrue(#mocks.__svWrites() > 0, "the write survey did not see the survivor's write")
    assertTrue(#mocks.__printed() > 0, "the print survey did not see the survivor's line")
  end)
  NS.addon.PLAYER_REGEN_DISABLED = nil
  settings.locked = savedLocked
  enable()
  if not ok then error(err, 0) end
end)

-- ── 7. The slash surface ──────────────────────────────────────────────────────
--
-- NOT THE STAND-DOWN. Steps 1-6 are. A green case here says nothing about whether the addon is
-- inert; it says the command surface still answers, which is the other half of the ruling.

local FEATURE_VERBS = { "show", "hide", "toggle", "session", "test", "purge" }

-- The live set is the LIBRARY'S (lib.LIVE_VERBS), because this addon passes no `liveVerbs`. Read
-- from the library rather than retyped, so this suite and the dispatcher cannot disagree about it.
local LIVE = {}
do
  local slashLib = mocks.LibStub and mocks.LibStub("LibKa0s-Slash-1.0", true)
  for _, verb in ipairs(slashLib and slashLib.LIVE_VERBS or {}) do LIVE[verb] = true end
end

local function isRefusal(line)
  return line:find("is disabled", 1, true) ~= nil
    and line:find("|cFFFFFF00/bl enable|r", 1, true) ~= nil
end

test("disabled: every reserved verb and the bare /bl still answer normally", function()
  -- slash-commands-§2 MUSTs this and v2.57.0 restored it after v2.56.0 had cut the disabled surface
  -- to `enable` and `help`. That cut failed on the most ordinary thing anyone tried: `/bl` on a
  -- disabled addon answered with a refusal instead of opening the settings panel, which is the one
  -- surface a player uses to switch it back on by hand.
  --
  -- WALKS EVERY NS.COMMANDS ENTRY, not a hand-picked list: a verb added to the table later is
  -- classified here by the library's own live set, and the refused remainder must be exactly the
  -- feature verbs. The disable is re-asserted before EVERY verb, because `enable` and `resetall`
  -- legitimately turn the addon back on, and a walk without it would test the rest enabled.
  --
  -- red under: passing a `liveVerbs` to the Slash descriptor, re-introducing a host-side gate in
  -- front of the dispatcher, or a new verb that refuses without being a feature verb.
  local saved = S:Get(ENABLED_PATH)
  local ok, err = pcall(function()
    assertTrue(next(LIVE) ~= nil, "no live set to classify against: LibKa0s-Slash-1.0 did not load")
    local refused = {}
    for _, entry in ipairs(NS.COMMANDS) do
      local verb = entry[1]
      disable()
      if LIVE[verb] then
        local out = captureChat(function() NS.Slash:OnSlash(verb) end)
        if verb == "help" then
          -- `help` prints its index IN FULL, with the refusal line under the header: the player
          -- has to be able to SEE `enable` in the list. It is a statement about the index, not a
          -- refusal of `help`.
          assertTrue(#out > 2, "the help index was refused rather than printed")
        else
          for _, line in ipairs(out) do
            assertFalse(isRefusal(line), "`/bl " .. verb .. "` was refused: " .. line)
          end
        end
      else
        -- Probed, so a gate that let it through cannot act on the suite's world while failing.
        local orig, ran = entry[3], 0
        entry[3] = function() ran = ran + 1 end
        local out = captureChat(function() NS.Slash:OnSlash(verb) end)
        entry[3] = orig
        assertEqual(ran, 0, "`/bl " .. verb .. "` ran while disabled")
        assertEqual(#out, 1, "`/bl " .. verb .. "` answered on more than one line")
        assertTrue(isRefusal(out[1]), "`/bl " .. verb .. "` did not print the refusal: " .. out[1])
        local n = #refused
        refused[n + 1] = verb
      end
    end
    assertEqual(table.concat(refused, ","), table.concat(FEATURE_VERBS, ","),
      "the refused verbs must be exactly this addon's feature verbs, in COMMANDS order")

    -- A reserved verb this addon never SHIPS is not refused (LibKa0s-Slash-1.0 minor 14). `perf`
    -- is reserved, and unregistered here under the performance-§12 exemption, so it answers the
    -- unknown-verb line in both states -- which is what it answers while the addon is running.
    disable()
    -- The FIRST line is the answer; the index printed under it carries the refusal line beneath its
    -- header, as `help` does, and is a statement about the feature rows rather than about `perf`.
    local perfOut = captureChat(function() NS.Slash:OnSlash("perf") end)
    local first = perfOut[1] or ""
    assertTrue(first:find("unknown command 'perf'", 1, true) ~= nil,
      "`/bl perf` on a disabled addon must answer unknown command first: " .. first)
    assertFalse(isRefusal(first), "`/bl perf` was refused although this addon ships no perf verb")

    -- The bare verb, which is the case that settled the reversal.
    disable()
    local opened = 0
    local savedOpen = NS.Panel.Open
    NS.Panel.Open = function() opened = opened + 1 end
    captureChat(function() NS.Slash:OnSlash("") end)
    NS.Panel.Open = savedOpen
    assertEqual(opened, 1, "the bare /bl must open the settings panel while disabled")

    -- And the one that matters most, read back from the store rather than from its echo.
    disable()
    captureChat(function() NS.Slash:OnSlash("enable") end)
    assertEqual(S:Get(ENABLED_PATH), true,
      "/bl enable must work while disabled, or the switch only goes one way")
  end)
  if NS.DebugLog and NS.DebugLog.Hide then NS.DebugLog:Hide() end
  S:Set(ENABLED_PATH, saved)
  if not ok then error(err, 0) end
end)

test("disabled: every feature verb answers ONE refusal line and reaches no write seam", function()
  -- This addon takes slash-commands-§2's SHOULD. The suite pins that choice so it cannot drift
  -- silently: an addon that declined would assert its feature verbs act normally instead.
  --
  -- The handler is swapped for a probe, so "did not act" is proved at the strongest place there
  -- is: the verb's body never ran. And the wording is matched against the SHAPE the library builds
  -- from lib.DISABLED_LINE_FORMAT rather than against a host copy of the sentence.
  --
  -- red under: a host-side refusal with its own wording, a second line, or a verb slipping onto
  -- the live list.
  local saved = S:Get(ENABLED_PATH)
  disable()
  watchStore()
  local ok, err = pcall(function()
    for _, verb in ipairs(FEATURE_VERBS) do
      local entry
      for _, cmd in ipairs(NS.COMMANDS) do if cmd[1] == verb then entry = cmd end end
      assertTrue(entry ~= nil, "no such verb: " .. verb)
      local orig, ran = entry[3], 0
      entry[3] = function() ran = ran + 1 end
      local out = captureChat(function() NS.Slash:OnSlash(verb) end)
      entry[3] = orig
      assertEqual(ran, 0, "`/bl " .. verb .. "` ran its handler while the addon was disabled")
      assertEqual(#out, 1, "`/bl " .. verb .. "` must answer on exactly one line")
      assertTrue(isRefusal(out[1]), "not the collection's refusal line: " .. out[1])
      assertTrue(out[1]:find(NS.BRAND_NAME, 1, true) ~= nil,
        "the line must carry the brand name the broker row wears: " .. out[1])
    end
    assertEqual(#mocks.__svWrites(), 0, "a refused verb still wrote the stored tree")

    -- A TYPO is not a refusal. The gate sits after the COMMANDS lookup, so a word this addon does
    -- not ship still gets the unknown-verb answer: telling a player who mistyped that the addon is
    -- off tells them their spelling was fine.
    local out = captureChat(function() NS.Slash:OnSlash("wibble") end)
    assertTrue(out[1]:find("unknown command 'wibble'", 1, true) ~= nil,
      "an unknown verb got the disabled refusal: " .. table.concat(out, "\n"))
  end)
  S:Set(ENABLED_PATH, saved)
  if not ok then error(err, 0) end
end)

-- ── 8. The launcher ───────────────────────────────────────────────────────────

test("disabled: the launcher's LEFT click is refused and its RIGHT click opens the panel", function()
  -- launcher-§2. Bank Ledger is rung (a) -- the left click drives a primary window, which is a
  -- feature -- so it prints the one refusal line and does nothing else. Rung (c)'s carve-out does
  -- not reach this addon: that rung's left click opens the settings panel and nothing else, which
  -- slash-commands-§7 keeps standing.
  --
  -- THE GATE IS THE LIBRARY'S (Launcher minor 2): the descriptor hands over `isEnabled` and
  -- `disabledLine`, and the library refuses the left click before `onClick` is ever called. So the
  -- Browser:Toggle spy is the proof: never called while disabled, called once after enable.
  --
  -- red under: dropping `isEnabled` from the descriptor in core/LauncherSetup.lua, which is the
  -- minimap button with no disabled gate the audit found.
  local object = NS.Launcher:Object()
  assertTrue(object ~= nil and type(object.OnClick) == "function", "no launcher object to click")

  local saved = S:Get(ENABLED_PATH)
  local toggles = 0
  local savedToggle = NS.Browser.Toggle
  NS.Browser.Toggle = function() toggles = toggles + 1 end
  disable()
  watchStore()
  local shownBefore = #mocks.__shownFrames()
  local ok, err = pcall(function()
    local out = captureChat(function() object.OnClick(object, "LeftButton") end)
    assertEqual(#out, 1, "the left click must answer on exactly one line")
    assertTrue(isRefusal(out[1]), "not the collection's refusal line: " .. out[1])
    assertEqual(toggles, 0, "the left click reached Browser:Toggle while disabled")
    assertEqual(#mocks.__svWrites(), 0, "the click wrote the stored tree of a disabled addon")
    assertEqual(#mocks.__shownFrames(), shownBefore, "the click put a frame on screen")

    local opened = 0
    local savedOpen = NS.Panel.Open
    NS.Panel.Open = function() opened = opened + 1 end
    captureChat(function() object.OnClick(object, "RightButton") end)
    NS.Panel.Open = savedOpen
    assertEqual(opened, 1, "the right click opens the panel in EITHER state")

    enable()
    local after = captureChat(function() object.OnClick(object, "LeftButton") end)
    assertEqual(#after, 0, "an enabled left click printed: " .. table.concat(after, "\n"))
    assertEqual(toggles, 1, "an enabled left click must toggle the ledger exactly once")
  end)
  NS.Browser.Toggle = savedToggle
  S:Set(ENABLED_PATH, saved)
  if not ok then error(err, 0) end
end)

test("disabled: the launcher's tooltip still shows, says Enabled: No and points at /bl enable",
function()
  -- launcher-§1 (standard v2.66.0): the tooltip is ALWAYS drawn, disabled included, since that is
  -- when a player hovers to ask why the button does nothing. The library draws it; this case pins
  -- that the host's isEnabled and disabledLine feed it, and that the hover writes and prints nothing.
  --
  -- red under: dropping `isEnabled` (the line would read Yes) or `disabledLine` (the hint would lose
  -- its /bl) from the descriptor in core/LauncherSetup.lua.
  local object = NS.Launcher:Object()
  local saved = S:Get(ENABLED_PATH)
  local function hover()
    local lines = {}
    object.OnTooltipShow({ AddLine = function(_, text)
      lines[#lines + 1] = tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    end })
    return lines
  end
  disable()
  watchStore()
  local ok, err = pcall(function()
    local lines
    local out = captureChat(function() lines = hover() end)
    assertEqual(#out, 0, "a hover printed: " .. table.concat(out, "\n"))
    assertEqual(#mocks.__svWrites(), 0, "a hover wrote the stored tree of a disabled addon")
    local all = table.concat(lines, "\n")
    assertTrue(lines[1]:find(NS.BRAND_NAME, 1, true) == 1, "the title still draws: " .. all)
    assertEqual(lines[2], "Enabled: No")
    assertTrue(all:find("\nLocked: ", 1, true) ~= nil, all)
    assertTrue(all:find("\nTest mode: ", 1, true) ~= nil, all)
    assertEqual(lines[#lines - 1], "Left-click: disabled \226\128\148 /bl enable")
    assertEqual(lines[#lines], "Right-click: Open settings")

    enable()
    lines = hover()
    assertEqual(lines[2], "Enabled: Yes")
    assertEqual(lines[#lines - 1], "Left-click: Toggle ledger window")
  end)
  S:Set(ENABLED_PATH, saved)
  if not ok then error(err, 0) end
end)

test("disabled: the launcher's left click carries no host gate", function()
  -- The refusal is the library's rung (a)/(b) gate now, fed by the descriptor's `isEnabled` and
  -- `disabledLine`. A host-side RefuseIfDisabled inside onClick would be the collection's rule
  -- written twice, so the anti-regression is a source read.
  local fh = assert(io.open("core/LauncherSetup.lua", "rb"))
  local src = fh:read("*a")
  fh:close()
  assertEqual(src:find("RefuseIfDisabled", 1, true), nil,
    "core/LauncherSetup.lua still gates the left click host-side")
  assertTrue(src:find("isEnabled%s*=") ~= nil, "the descriptor does not hand over isEnabled")
  assertTrue(src:find("disabledLine%s*=") ~= nil, "the descriptor does not hand over disabledLine")
end)

-- ── 9. Restoration, from CURRENT state ────────────────────────────────────────

test("disabled: re-enabling rebuilds the registration set, from the settings as they are NOW",
function()
  -- performance-§6's restore-from-current-state rule, which the latch inherits: the rebuild reads
  -- the settings as they are at stand-up, never a snapshot taken on the way down.
  local R_on = baseline()
  local before = counted(keysOf(R_on))

  disable()
  enable()
  noteOwners()
  local after = counted(keysOf(registrations()))
  for key, n in pairs(before) do
    assertEqual(after[key], n, "`" .. key .. "` did not come back")
  end
  for key, n in pairs(after) do
    assertEqual(before[key], n, "`" .. key .. "` arrived that was not there before")
  end

  -- The same cycle with ONE setting changed while disabled. `trackMoney` is a capture-gate upvalue
  -- the Ledger re-reads on Enable, so a rebuild from a snapshot would come back with the old value.
  local savedTrack = S:Get("settings.trackMoney")
  disable()
  S:Set("settings.trackMoney", not savedTrack)
  enable()
  assertEqual(NS.Ledger:GateReason({ kind = "MONEY", direction = "DEPOSIT", store = "BANK",
    amount = 100 }), (not savedTrack) and nil or "kind",
    "the rebuild used a snapshot taken on the way down rather than the setting as it is now")
  S:Set("settings.trackMoney", savedTrack)
end)

-- ── 10. The latch ─────────────────────────────────────────────────────────────

test("disabled: releasing one hold does not stand up an addon the other still holds down",
function()
  -- The trap, and it is reachable in play: `/bl disable` is a live verb, so a player can switch the
  -- addon off during a suspended perf arm, and `/bl enable` is live too. A resume that called a
  -- bare StandUp would bring the addon back mid-capture; a disable that called one on its way out
  -- would do the same.
  --
  -- red under: replacing NS.SetDisabledHold's latch call with a direct NS.StandUp / NS.StandDown
  -- pair, which is the boolean this major exists to replace.
  assertTrue(NS.Lifecycle ~= nil, "the latch is absent: LibKa0s-Lifecycle-1.0 did not load")
  baseline()
  local function live() noteOwners() return #registrations() end

  -- perf first, then disabled.
  NS.Lifecycle:Hold(HOLD_PERF)
  disable()
  NS.Lifecycle:Release(HOLD_PERF)
  assertEqual(live(), 0, "releasing the perf hold resurrected an addon the player had disabled")
  assertTrue(NS.Lifecycle:IsDown(), "the latch reports up with the disabled hold still taken")
  enable()
  assertTrue(live() > 0, "the addon did not come back when the last hold went")

  -- And the other order: disabled first, then perf.
  disable()
  NS.Lifecycle:Hold(HOLD_PERF)
  enable()
  assertEqual(live(), 0, "re-enabling stood the addon up in the middle of a suspended arm")
  NS.Lifecycle:Release(HOLD_PERF)
  assertTrue(live() > 0, "the addon did not come back when the last hold went")
  assertEqual(#NS.Lifecycle:Holds(), 0, "a hold was left taken")
end)

test("disabled: the `disabled` hold is taken at LOAD from the stored path", function()
  -- `perf` is session-only; `disabled` is persisted, and surviving a /reload is the entire point of
  -- that setting. addon:OnEnable re-takes the hold from the store rather than starting up and
  -- hiding -- and brings the launcher up in either state, because the launcher is setup.
  --
  -- red under: dropping the NS.SetDisabledHold(not NS.EnabledStored()) read from addon:OnEnable, or
  -- an unguarded NS.StandUp() after it (core/BankLedger.lua).
  baseline()
  disable()
  -- A fresh session: the store still says off, and the latch -- which persists nothing -- starts
  -- with no hold. Releasing the hold directly models that, and stands the addon up, so the load
  -- path below has something to get wrong: without its stored-path read it leaves the addon up.
  assertTrue(NS.Lifecycle ~= nil, "the latch is absent: LibKa0s-Lifecycle-1.0 did not load")
  NS.Lifecycle:Release(NS.HOLD_DISABLED)
  assertEqual(S:Get(ENABLED_PATH), false, "the store must still say off for this to model a reload")
  NS.addon:OnEnable()          -- the load path, with the store already saying off
  noteOwners()
  local live = registrations()
  assertEqual(#live, 0, "a load with `enabled = false` stood the addon up anyway: " .. describe(live))
  assertTrue(NS.IsDisabled(), "the `disabled` hold was not taken at load")
  assertTrue(NS.Launcher:Object() ~= nil, "the launcher must come up in EITHER state")
  enable()
  assertTrue(#registrations() > 0, "the addon did not come back after the load-time hold")
end)
