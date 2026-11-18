-- tests/test_report_verbs.lua — the two report verbs on LibKa0s-DebugLog-1.0's D:Report
-- (debug-logging-§15, slash-commands-§1 "Chat or the console", LibKa0s#79, AD-79-BL).
--
-- A REPORT is a multi-line read-out the player asks for by name. This addon has two besides the
-- diagnostics report (which keeps §14's own helper and is tests/test_diagnostics.lua's): `/bl debug
-- scan` (NS.Ledger:Diagnose) and `/bl debug panel` (NS.Panel:Diagnose). Each is written through
-- D:Report: ungated, the console revealed, a `/bl <title>` header, and exactly ONE chat pointer.
-- A refusal inside a report verb stays in chat and writes nothing. Without the library, the stub in
-- core/DebugLogSetup.lua streams the report to chat with no pointer.
--
-- `/bl session` is NOT a report: its handler toggles the session window's sample and answers in one
-- line, so it stays in chat (tests/test_sessionwindow.lua).

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local D = NS.DebugLog
local POINTER = "%s: %d lines written to the debug console. Use Copy to share it."

local function captureChat(m, fn)
  local out = {}
  local saved = m.DEFAULT_CHAT_FRAME.AddMessage
  m.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  m.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

--- Run `/bl debug <word>` with logging OFF and the console HIDDEN, and answer the chat lines, the
--- console lines it added, and the flag and visibility after.
local function runVerb(word)
  local savedFlag = NS.State.debug
  NS.State.debug = false
  if D:IsShown() then D:Hide() end
  local before = #D.buffer
  local chat = captureChat(mocks, function() NS.Slash:OnSlash("debug " .. word) end)
  local added = {}
  for i = before + 1, #D.buffer do added[#added + 1] = D.buffer[i] end
  local after = { flag = NS.State.debug, shown = D:IsShown() }
  NS.State.debug = savedFlag
  if D:IsShown() then D:Hide() end
  return chat, added, after
end

local function with(tbl, key, value, fn)
  local saved = tbl[key]
  tbl[key] = value
  local ok, err = pcall(fn)
  tbl[key] = saved
  if not ok then error(err, 0) end
end

-- The panel dump runs against a settings page whose Defaults button was never built (the shape
-- tests/test_panel.lua pins line for line), so the case reads the dump's routing, not the mock
-- widget tree an earlier suite left on the real page.
local function noDefaultsButton(fn) with(NS.Panel, "general", nil, fn) end
local function asIs(fn) fn() end

for _, verb in ipairs({
  { word = "scan",  tag = "[Scan]",  around = asIs,
    body = function() return NS.Ledger:Diagnose() end },
  { word = "panel", tag = "[Panel]", around = noDefaultsButton,
    body = function() return NS.Panel:Diagnose() end },
}) do
  local title = "debug " .. verb.word

  test("report verbs: /bl " .. title .. " writes the report with logging off and leaves it off", function()
    verb.around(function()
      local chat, added, after = runVerb(verb.word)
      local body = verb.body()
      -- Falsification (testing-§12): writing through the gated sink NS.Debug instead of D:Report
      -- writes nothing with the flag off, so `added` is empty and this goes red.
      assertEqual(#added, #body + 1, "the header and every body line landed")
      assertTrue(added[1]:find(verb.tag .. " /bl " .. title, 1, true) ~= nil,
        "the report opens with its /bl header: " .. tostring(added[1]))
      for i, line in ipairs(body) do
        assertTrue(added[i + 1]:find(verb.tag .. " " .. line, 1, true) ~= nil,
          ("body line %d under %s: %s"):format(i, verb.tag, tostring(added[i + 1])))
      end
      assertFalse(after.flag, "the report turned trace logging on")
      assertTrue(#chat >= 1, "no chat pointer")
    end)
  end)

  test("report verbs: /bl " .. title .. " reveals the console and prints exactly one chat pointer", function()
    verb.around(function()
      local chat, added, after = runVerb(verb.word)
      assertTrue(after.shown, "the hidden console was not revealed")
      -- Falsification (testing-§12): a report printed to chat line by line, or a second
      -- acknowledgement beside the library's pointer, makes #chat > 1 and goes red.
      assertEqual(#chat, 1, "exactly one chat line: " .. table.concat(chat, " | "))
      assertTrue(chat[1]:find(POINTER:format(title, #added), 1, true) ~= nil,
        "the pointer names the report and its line count: " .. tostring(chat[1]))
    end)
  end)
end

test("report verbs: /bl debug panel with no settings panel refuses in chat and writes nothing", function()
  with(NS, "Panel", nil, function()
    local chat, added, after = runVerb("panel")
    assertEqual(#added, 0, "a refusal wrote to the console")
    assertFalse(after.shown, "a refusal revealed the console")
    assertEqual(#chat, 1, "one refusal line: " .. table.concat(chat, " | "))
    assertTrue(chat[1]:find("settings panel not built yet", 1, true) ~= nil, tostring(chat[1]))
    assertTrue(chat[1]:find("lines written to the debug console", 1, true) == nil,
      "a refusal printed a report pointer")
  end)
end)

test("report verbs: without LibKa0s the stub streams /bl debug scan to chat with no pointer", function()
  local env = dofile("tests/degraded_env.lua")
  local ns, m = env.loadDegraded()
  assertTrue(m.LibStub("LibKa0s-DebugLog-1.0", true) == nil,
    "the degraded arm still has the library")
  local entry
  for _, c in ipairs(ns.COMMANDS) do if c[1] == "debug" then entry = c end end
  assertTrue(entry ~= nil, "no debug verb")
  local body = ns.Ledger:Diagnose()
  local raw = captureChat(m, function() entry[3]("scan") end)
  -- The degraded printer's once-per-session "library is missing" notice (core/CoreSetup.lua) rides
  -- on the first line this environment prints. It is the printer's, not the report's.
  local chat = {}
  for _, line in ipairs(raw) do
    if not line:find("library is missing from this installation", 1, true) then chat[#chat + 1] = line end
  end
  assertEqual(#chat, #body, "every body line streamed to chat, nothing else: " .. table.concat(chat, " | "))
  for _, line in ipairs(chat) do
    assertTrue(line:find("lines written to the debug console", 1, true) == nil, "the stub printed a pointer")
  end
  assertTrue(chat[1]:find(body[1], 1, true) ~= nil, "the first body line: " .. tostring(chat[1]))
end)
