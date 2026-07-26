local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local D = NS.DebugLog

local function captureChat(fn)
  local out = {}
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

-- ── Line formatters (pure, so the coloured view can never drift from the copy buffer) ──

test("DebugLog.FormatPlain renders '<ts> | [<tag>] <msg>' with no colour codes", function()
  assertEqual(D.FormatPlain("12:34:56", "Move", "hello"), "12:34:56 | [Move] hello")
end)

test("DebugLog.FormatPlain tolerates a missing tag", function()
  assertEqual(D.FormatPlain("12:34:56", nil, "hello"), "12:34:56 | [] hello")
end)

test("DebugLog.FormatColored uses the mandated timestamp and tag colours", function()
  local s = D.FormatColored("12:34:56", "Move", "hello")
  assertTrue(s:find("|cff6f8faf12:34:56|r", 1, true) ~= nil, "steel-blue timestamp")
  assertTrue(s:find("|cffc9a66b[Move]|r", 1, true) ~= nil, "tan/gold tag")
end)

test("DebugLog.FormatColored escapes the separator pipe so it renders literally", function()
  assertTrue(D.FormatColored("12:34:56", "Move", "hello"):find("||", 1, true) ~= nil)
end)

test("DebugLog: the plain and coloured lines carry the same tag and message", function()
  local plain = D.FormatPlain("12:34:56", "Prune", "removed 4")
  local colored = D.FormatColored("12:34:56", "Prune", "removed 4")
  assertTrue(plain:find("[Prune] removed 4", 1, true) ~= nil)
  assertTrue(colored:find("[Prune]|r removed 4", 1, true) ~= nil)
end)

-- ── The gated sink ─────────────────────────────────────────────────────────────

test("NS.Debug writes nothing while logging is off", function()
  NS.State.debug = false
  D:Clear()
  NS.Debug("Move", "should not appear")
  assertEqual(#D.buffer, 0)
end)

test("NS.Debug appends a line while logging is on", function()
  NS.State.debug = true
  D:Clear()
  NS.Debug("Move", "recorded 3")
  assertEqual(#D.buffer, 1)
  assertTrue(D.buffer[1]:find("[Move] recorded 3", 1, true) ~= nil)
  NS.State.debug = false
end)

test("NS.Debug formats its arguments into the message", function()
  NS.State.debug = true
  D:Clear()
  NS.Debug("Store", "%s opened", "BANK")
  assertTrue(D.buffer[1]:find("[Store] BANK opened", 1, true) ~= nil)
  NS.State.debug = false
end)

test("NS.Debug never raises on a value table.concat would reject", function()
  -- The classic combat crash: an unguarded "secret" value reaching string.format. Every argument
  -- goes through NS.SafeToString first, so it logs as <secret> instead (events-frames-taint-§8).
  NS.State.debug = true
  D:Clear()
  NS.Debug("Move", "%s", {})
  assertTrue(D.buffer[1]:find("<secret>", 1, true) ~= nil)
  NS.State.debug = false
end)

test("DebugLog:Clear empties the copy buffer", function()
  NS.State.debug = true
  NS.Debug("Move", "one")
  D:Clear()
  assertEqual(#D.buffer, 0)
  NS.State.debug = false
end)

-- ── Enabled state (session-only, window-independent) ───────────────────────────

test("DebugLog:SetEnabled flips the session-only flag", function()
  captureChat(function() D:SetEnabled(true) end)
  assertTrue(NS.State.debug)
  captureChat(function() D:SetEnabled(false) end)
  assertFalse(NS.State.debug)
end)

test("DebugLog:SetEnabled acks in chat with a colour-coded state word", function()
  local on = captureChat(function() D:SetEnabled(true) end)
  local off = captureChat(function() D:SetEnabled(false) end)
  assertTrue(on[1]:find("|cff40ff40ON|r", 1, true) ~= nil, "ON is green")
  assertTrue(off[1]:find("|cffff4040OFF|r", 1, true) ~= nil, "OFF is red")
end)

test("DebugLog:SetEnabled brackets BOTH transitions in the console", function()
  D:Clear()
  captureChat(function() D:SetEnabled(true) end)
  local afterEnable = #D.buffer
  captureChat(function() D:SetEnabled(false) end)
  assertTrue(afterEnable >= 1, "an 'enabled' line")
  assertTrue(#D.buffer > afterEnable, "a 'disabled' line, written after the flag flipped off")
  assertTrue(D.buffer[#D.buffer]:find("logging disabled", 1, true) ~= nil)
end)

test("DebugLog:SetEnabled emits an [Init] session summary on enable", function()
  -- On ENABLE, not at login: the flag is session-only and off at login, so a load-time summary
  -- would always be gated off and never render (debug-logging-§5).
  D:Clear()
  captureChat(function() D:SetEnabled(true) end)
  local found = false
  for _, line in ipairs(D.buffer) do
    if line:find("[Init]", 1, true) and line:find("BankLedger", 1, true) then found = true end
  end
  assertTrue(found, "an [Init] line naming the build")
  captureChat(function() D:SetEnabled(false) end)
end)

test("DebugLog:SetEnabled emits no [Init] summary on disable", function()
  captureChat(function() D:SetEnabled(true) end)
  D:Clear()
  captureChat(function() D:SetEnabled(false) end)
  for _, line in ipairs(D.buffer) do
    assertFalse(line:find("[Init]", 1, true) ~= nil, "no summary when capture stops")
  end
end)

test("DebugLog: the enabled state is never written to SavedVariables", function()
  captureChat(function() D:SetEnabled(true) end)
  assertEqual(NS.db.global.debug, nil)
  assertEqual(NS.db.global.settings.debug, nil)
  captureChat(function() D:SetEnabled(false) end)
end)

test("DebugLog: the header toggle flips the same flag as the slash verb", function()
  -- Both paths must funnel through the single SetEnabled seam, or the header label and the flag
  -- drift apart.
  NS.State.debug = false
  captureChat(function() D._toggleClickForTest() end)
  assertTrue(NS.State.debug)
  captureChat(function() D._toggleClickForTest() end)
  assertFalse(NS.State.debug)
end)

test("DebugLog:UpdateScrollBar is a clean no-op under a stub frame", function()
  -- The headless mock's stub frame returns itself from every method, so the scroll sync must
  -- type-check its returns rather than assume numbers (debug-logging-§11).
  local ok = pcall(function() D:UpdateScrollBar() end)
  assertTrue(ok, "no error from the scroll sync")
end)
