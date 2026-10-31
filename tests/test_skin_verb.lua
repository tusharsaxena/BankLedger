-- tests/test_skin_verb.lua — the reserved `skin` verb (LibKa0s v1.82.0, OptionsSkinPicker minor 3's
-- O.SkinVerb; BL-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-16):
-- a `skin` row right after `config` runs NS.RunSkinVerb, which hands O.SkinVerb this addon's
-- first-run spec (NS.SkinPickerSpec), so `/bl skin` shows the picker a new profile shows whatever
-- settings.appearance.pickerSeen says. Refused while the addon is disabled (the library's gate: it is
-- a feature verb, not one of lib.LIVE_VERBS), a gray line on every call in combat (the library's),
-- and the library-absent line without LibKa0s. LibKa0sSkinTester's tests/test_skin_verb.lua is the
-- pattern. Leaves the picker down, the profile marked unseen and the skin on Ka0s Default.

local T = _G.BL_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local O = NS.Helpers
local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OptionsLib = mocks.LibStub("LibKa0s-Options-1.0")
local OWNER = "BankLedger"
local SEEN = "settings.appearance.pickerSeen"
local ENABLED = "settings.enabled"

local function strings() return OptionsLib.SKIN_PICKER_STRINGS end

local function captureChat(fn)
  local out = {}
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = tostring(msg) end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

local function anyLine(lines, fragment)
  for _, l in ipairs(lines) do if l:find(fragment, 1, true) then return true end end
  return false
end

--- A profile that has closed the first-run picker, so only the verb can bring it back; `fn` runs
--- with the picker down, and everything is put back whatever it raised.
local function seenProfile(fn)
  return function()
    NS.HideSkinPicker()
    NS.Schema:Set(SEEN, true)
    local ok, err = pcall(fn)
    NS.HideSkinPicker()
    captureChat(function()
      if NS.Schema:Get(ENABLED) ~= true then NS.Slash:CliEnabled(true) end
      NS.Schema:Set(SEEN, false)
      NS.WriteSkinChoice("ka0s", "ka0s")
      Skin:SetChoice(OWNER, "ka0s", "ka0s")
      if NS.LedgerTable and NS.LedgerTable.IsTestMode and NS.LedgerTable:IsTestMode() then
        NS.LedgerTable:SetTestMode(false)
      end
      if NS.Browser and NS.Browser.Hide then NS.Browser:Hide() end
    end)
    if mocks.__fireTimers then mocks.__fireTimers() end
    if not ok then error(err, 0) end
  end
end

--- Run `fn(calls)` with O.SkinVerb replaced by a recorder answering `a, b`.
local function spying(a, b, fn)
  local real = O.SkinVerb
  local calls = {}
  O.SkinVerb = function(spec) calls[#calls + 1] = spec; return a, b end
  local ok, err = pcall(fn, calls)
  O.SkinVerb = real
  if not ok then error(err, 0) end
end

test("skin verb: the row sits right after config, with the library's help words", function()
  local at
  for i, c in ipairs(NS.COMMANDS) do if c[1] == "skin" then at = i end end
  assertTrue(at ~= nil, "a skin row")
  assertEqual(NS.COMMANDS[at - 1][1], "config", "after config")
  assertEqual(NS.COMMANDS[at][2], strings().VERB_HELP, "one wording for every host")
  assertEqual(type(NS.COMMANDS[at][3]), "function")
end)

test("skin verb: /bl skin hands O.SkinVerb this addon's first-run spec", seenProfile(function()
  -- red under: no skin row (the dispatcher answers "unknown command"), or a spec of its own.
  spying({ spy = true }, nil, function(calls)
    local out = captureChat(function() NS.Slash:OnSlash("skin") end)
    assertEqual(#calls, 1, "one call through the library's act")
    assertFalse(anyLine(out, "unknown command"), "a known verb")
    local spec, want = calls[1], NS.SkinPickerSpec()
    assertEqual(spec.owner, OWNER)
    assertTrue(rawequal(spec.get, NS.SkinChoice) and rawequal(spec.set, NS.WriteSkinChoice),
      "the read and write seams")
    assertEqual(spec.page, want.page)
    assertEqual(spec.tab, want.tab)
  end)
end))

test("skin verb: on a profile that closed the picker, /bl skin shows it", seenProfile(function()
  local win
  captureChat(function() win = NS.RunSkinVerb() end)
  assertTrue(type(win) == "table", "the picker's frame")
  assertTrue(win:IsShown(), "and it is up")
  assertEqual(NS.Schema:Get(SEEN), true, "showing it does not reset the seen flag")
end))

test("skin verb: the library's reason is passed on, and nothing is printed over it", seenProfile(function()
  spying(nil, "queued", function()
    local win, why
    local out = captureChat(function() win, why = NS.RunSkinVerb() end)
    assertEqual(win, nil)
    assertEqual(why, "queued")
    assertEqual(#out, 0, "the library says queued itself")
  end)
end))

test("skin verb: in combat every call prints the library's gray line and shows nothing", seenProfile(function()
  local saved = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return true end
  local ok, err = pcall(function()
    local first, second
    first = captureChat(function() NS.Slash:OnSlash("skin") end)
    second = captureChat(function() NS.Slash:OnSlash("skin") end)
    assertTrue(anyLine(first, strings().VERB_COMBAT), "the first call says why")
    assertTrue(anyLine(second, strings().VERB_COMBAT), "and so does every later one")
  end)
  mocks.InCombatLockdown = saved
  if not ok then error(err, 0) end
end))

test("skin verb: refused while the addon is disabled, and the act never runs", seenProfile(function()
  captureChat(function() NS.Slash:CliEnabled(false) end)
  spying({ spy = true }, nil, function(calls)
    local out = captureChat(function() NS.Slash:OnSlash("skin") end)
    assertEqual(#calls, 0, "no picker while disabled")
    assertEqual(#out, 1, "one refusal line")
    assertTrue(out[1]:find("is disabled", 1, true) ~= nil, "the disabled line")
  end)
end))

test("skin verb: without LibKa0s the verb prints the library-absent line", function()
  local Env = dofile("tests/degraded_env.lua")
  local ns, m = Env.loadDegraded()
  local at
  for i, c in ipairs(ns.COMMANDS) do if c[1] == "skin" then at = i end end
  assertTrue(at ~= nil, "the row ships on both arms")
  -- That copy prints through its own mock world's chat frame.
  local out, win, why = {}, nil, nil
  local saved = m.DEFAULT_CHAT_FRAME.AddMessage
  m.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = tostring(msg) end
  local ok, err = pcall(function() win, why = ns.RunSkinVerb() end)
  m.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  assertEqual(win, nil)
  assertEqual(why, "absent")
  assertTrue(anyLine(out, "/bl skin is unavailable: the LibKa0s library did not load."), "names the verb")
end)
