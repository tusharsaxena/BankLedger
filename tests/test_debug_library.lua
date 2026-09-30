-- tests/test_debug_library.lua — THE LINES LibKa0s WRITES INTO THIS ADDON'S CONSOLE (v1.65.0).
--
-- From LibKa0s v1.65.0 four library modules log what they decide through the host's gated sink,
-- the descriptor's `debug(tag, message)` field (debug-logging-§4): Slash its refusals (`[Cmd]`),
-- Lifecycle its stand-down / stand-up edges (`[Lifecycle]`), the Options combat lock its refusals
-- (`[Cfg]`), and the Launcher its events, with its state lines through the console's at-enable
-- queue (`[Launcher]`). This suite pins two things for each:
--
--   * THE LINE LANDS HERE. The descriptor was handed NS.DebugSink (core/DebugLogSetup.lua), so the
--     library's line is in this addon's buffer, not lost. Red under a descriptor missing `debug`.
--   * IT IS WRITTEN ONCE. The host writes no second line for the same refusal or edge (a host
--     MUST NOT duplicate a library line). Red under a host `stood down` / `stood up` line coming
--     back, or a host matching the refusal's chat line and logging it again.
--
-- And the at-enable queue: a state line written at OnEnable, while logging is off by design, lands
-- once the first time logging is turned on, after the [Init] line.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue =
  T.test, T.assertEqual, T.assertTrue

local S = NS.Schema
local ENABLED_PATH = "settings.enabled"

--- Every console line `fn` writes, with logging on for it alone and chat collected, not printed.
local function debugLines(fn)
  local savedDebug, savedAdd = NS.State.debug, mocks.DEFAULT_CHAT_FRAME.AddMessage
  local chat = {}
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) chat[#chat + 1] = msg end
  NS.State.debug = true
  NS.DebugLog:Clear()
  local ok, err = pcall(fn)
  local out = {}
  for _, line in ipairs(NS.DebugLog.buffer) do out[#out + 1] = line end
  NS.DebugLog:Clear()
  NS.State.debug = savedDebug
  mocks.DEFAULT_CHAT_FRAME.AddMessage = savedAdd
  if not ok then error(err, 0) end
  return out, chat
end

--- The lines carrying `[tag]`.
local function tagged(lines, tag)
  local out = {}
  for _, line in ipairs(lines) do
    if line:find("[" .. tag .. "]", 1, true) then out[#out + 1] = line end
  end
  return out
end

--- How many lines contain `text`, plainly.
local function count(lines, text)
  local n = 0
  for _, line in ipairs(lines) do
    if line:find(text, 1, true) then n = n + 1 end
  end
  return n
end

local function joined(lines) return table.concat(lines, " | ") end

-- ── Slash (minor 18): the dispatcher's own refusals ──────────────────────────────────────────

test("library lines: an unknown verb's refusal is one [Cmd] line in this console, beside its chat line",
  function()
    local lines, chat = debugLines(function() NS.Slash:OnSlash("frobnicate") end)
    local cmd = tagged(lines, "Cmd")
    assertEqual(#cmd, 1, "one line per refusal, got: " .. joined(lines))
    assertTrue(cmd[1]:find("[Cmd] refused frobnicate: unknown verb", 1, true) ~= nil, cmd[1])
    assertTrue(count(chat, "unknown command 'frobnicate'") == 1, "the chat line is unchanged: " .. joined(chat))
  end)

test("library lines: the disabled gate's refusal is one [Cmd] line naming the verb and the guard",
  function()
    local lines = debugLines(function()
      S:Set(ENABLED_PATH, false)
      NS.Slash:OnSlash("show")
      S:Set(ENABLED_PATH, true)
    end)
    local cmd = tagged(lines, "Cmd")
    assertEqual(#cmd, 1, "one line per refusal, got: " .. joined(lines))
    assertTrue(cmd[1]:find("[Cmd] refused show: disabled", 1, true) ~= nil, cmd[1])
    assertEqual(count(lines, "is disabled"), 0, "no host line repeats the chat refusal: " .. joined(lines))
  end)

test("library lines: a refused /bl set names the path and the guard", function()
  local lines = debugLines(function() NS.Slash:OnSlash("set settings.nosuchrow 1") end)
  local cmd = tagged(lines, "Cmd")
  assertEqual(#cmd, 1, joined(lines))
  assertTrue(cmd[1]:find("[Cmd] refused set settings.nosuchrow: not found", 1, true) ~= nil, cmd[1])
end)

test("library lines: with logging off a Slash refusal writes nothing", function()
  local saved = NS.State.debug
  NS.State.debug = false
  NS.DebugLog:Clear()
  local savedAdd = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local ok, err = pcall(function() NS.Slash:OnSlash("frobnicate") end)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = savedAdd
  local n = #NS.DebugLog.buffer
  NS.State.debug = saved
  if not ok then error(err, 0) end
  assertEqual(n, 0, "the gate is the host's sink; off, nothing lands")
end)

-- ── Lifecycle (minor 3): the stand-down and stand-up edges ───────────────────────────────────

test("library lines: each Lifecycle edge is one [Lifecycle] line, and the host writes no second", function()
  local lines = debugLines(function()
    S:Set(ENABLED_PATH, false)
    S:Set(ENABLED_PATH, true)
  end)
  local edges = tagged(lines, "Lifecycle")
  assertEqual(#edges, 2, "one line per edge, got: " .. joined(lines))
  assertTrue(edges[1]:find("[Lifecycle] stood down: added disabled (holds: disabled)", 1, true) ~= nil, edges[1])
  assertTrue(edges[2]:find("[Lifecycle] stood up: released disabled (holds: none)", 1, true) ~= nil, edges[2])
  assertEqual(count(lines, "stood down"), 1, "one stand-down line in the whole buffer: " .. joined(lines))
  assertEqual(count(lines, "stood up"), 1, "one stand-up line in the whole buffer: " .. joined(lines))
end)

test("library lines: a hold call that changes nothing writes no edge", function()
  local lines = debugLines(function() S:Set(ENABLED_PATH, true) end)
  assertEqual(#tagged(lines, "Lifecycle"), 0, joined(lines))
end)

-- ── Options (minor 27): the combat lock's refusals ───────────────────────────────────────────

test("library lines: a write the Options combat lock refuses is one [Cfg] line in this console", function()
  local saved = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return true end
  local lines = debugLines(function()
    -- The seam every panel write asks first; a subject no other case uses, so this combat's
    -- once-per-text memory cannot have spent it.
    assertTrue(NS.Helpers.__combatRefused("write", "debuglib.pin"), "locked in combat")
    NS.Helpers.__combatRefused("write", "debuglib.pin")
  end)
  mocks.InCombatLockdown = saved
  local cfg = tagged(lines, "Cfg")
  assertEqual(#cfg, 1, "one line per refused act per combat, got: " .. joined(lines))
  assertTrue(cfg[1]:find("[Cfg] write debuglib.pin refused (in combat)", 1, true) ~= nil, cfg[1])
end)

-- ── The at-enable queue: state written at OnEnable lands when logging is turned on ───────────

--- A FRESH load of the library and the whole addon, taken through the load path with logging off
--- (the flag is session-only and off at every login), as tests/test_launcher.lua builds one.
local function freshLoad(stored)
  local m = T.makeMocks()
  local ns = {}
  T.Loader.loadAll(T.libka0sFiles, ns, m)
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  m.DEFAULT_CHAT_FRAME.AddMessage = function() end
  ns:InitDB()
  ns.Schema:Register()
  if stored ~= nil then ns.db.profile.settings.enabled = stored end
  ns.addon:OnEnable()
  return ns
end

local function buffer(ns)
  local out = {}
  for _, line in ipairs(ns.DebugLog.buffer) do out[#out + 1] = line end
  return out
end

test("library lines: the Launcher's and the login's state lines land once, after [Init], on enable",
  function()
    local ns = freshLoad()
    assertEqual(#ns.DebugLog.buffer, 0, "logging is off at login, so nothing is written yet")
    ns.DebugLog:SetEnabled(true)
    local lines = buffer(ns)
    local init, launcher, events
    for i, line in ipairs(lines) do
      if line:find("[Init]", 1, true) then init = init or i end
      if line:find("[Launcher] LibDataBroker-1.1 absent; no launcher", 1, true) then launcher = i end
      if line:find("[State] events at login: ", 1, true) then events = i end
    end
    assertTrue(init ~= nil, "the [Init] line: " .. joined(lines))
    assertTrue(launcher ~= nil and launcher > init, "the Launcher's held line lands after [Init]: " .. joined(lines))
    assertTrue(events ~= nil and events > init, "the login's event record lands after [Init]: " .. joined(lines))
    assertEqual(count(lines, "[Launcher]"), 1, "held once: " .. joined(lines))

    -- One-shot: a second enable edge writes the held lines no second time.
    ns.DebugLog:SetEnabled(false)
    ns.DebugLog:Clear()
    ns.DebugLog:SetEnabled(true)
    lines = buffer(ns)
    assertEqual(count(lines, "[Launcher]"), 0, "the queue flushed once: " .. joined(lines))
    assertEqual(count(lines, "events at login"), 0, joined(lines))
    ns.DebugLog:SetEnabled(false)
  end)

test("library lines: a load in the disabled state says so once logging is on, and no edge line twice",
  function()
    local ns = freshLoad(false)
    assertTrue(ns.IsStoodDown(), "the stored switch stood the addon down at load")
    ns.DebugLog:SetEnabled(true)
    local lines = buffer(ns)
    assertEqual(count(lines, "[State] stood down at login (holds: disabled)"), 1, joined(lines))
    assertEqual(count(lines, "stood down"), 1, "the library's edge line was gated off at load: " .. joined(lines))
    assertEqual(count(lines, "events at login"), 0, "nothing stood up: " .. joined(lines))
    ns.DebugLog:SetEnabled(false)
  end)

-- ── DebugLogGates (minor 1): the [Diff] gate is the console's, so a Clear re-arms it ─────────

test("library lines: the [Diff] change gate is the console's, re-armed by a Clear", function()
  local D = NS.DebugLog
  local key = NS.Ledger.DiffGateKey("BANK")
  local lines = debugLines(function()
    D.DebugForget(key)
    assertTrue(D.DebugChanged(key, "Diff", "%s", "BANK: pin"), "the first line writes")
    assertTrue(D.DebugChanged(key, "Diff", "%s", "BANK: pin") == false, "a repeat is held")
    D:Clear()
    assertTrue(D.DebugChanged(key, "Diff", "%s", "BANK: pin"), "a Clear re-arms the gate")
  end)
  assertEqual(count(lines, "[Diff] BANK: pin"), 1, "the buffer after the Clear holds the one line")
  assertEqual(NS.Ledger._lastDiff, nil, "no hand-rolled memo beside the console's gate")
end)
