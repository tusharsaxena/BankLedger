local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local Sl = NS.Slash

local function captureChat(fn)
  local out = {}
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

local function joined(out) return table.concat(out, "\n") end

-- ── Value formatting (slash-commands-§5) ───────────────────────────────────────
--
-- Sl.FormatSchemaValue and Sl.FormatKV are gone: both are LibKa0s-Slash-1.0's, lib-level rather
-- than on the instance. What is still OURS is the `format` descriptor hook, which is the only
-- reason a set renders as a set — see the LibKa0s-Slash section of tests/test_libka0s.lua for the
-- rendered-byte assertions, and the cases below for the behavior those bytes describe.

test("Slash: a set renders as a sorted brace list, through the format hook", function()
  local saved = NS.Schema:Get("settings.excludedStores")
  NS.Schema:Set("settings.excludedStores", { GUILD_BANK = true, BANK = true })
  local out = captureChat(function() Sl:CliGet("settings.excludedStores") end)
  assertTrue(out[1]:find("{BANK, GUILD_BANK}", 1, true) ~= nil,
    "a table-typed row must not fall through to the library's secret sentinel: " .. out[1])
  NS.Schema:Set("settings.excludedStores", saved or {})
end)

test("Slash: an empty set renders as (none), not as an empty brace pair", function()
  local saved = NS.Schema:Get("settings.excludedStores")
  NS.Schema:Set("settings.excludedStores", {})
  local out = captureChat(function() Sl:CliGet("settings.excludedStores") end)
  assertTrue(out[1]:find("(none)", 1, true) ~= nil, out[1])
  NS.Schema:Set("settings.excludedStores", saved or {})
end)

test("Slash: a number row keeps its declared fmt", function()
  local out = captureChat(function() Sl:CliGet("settings.windowScale") end)
  assertTrue(out[1]:find("1.00x", 1, true) ~= nil, out[1])
end)

test("Slash: a boolean row still reads true/false", function()
  local out = captureChat(function() Sl:CliGet("settings.enabled") end)
  assertTrue(out[1]:find("true", 1, true) ~= nil or out[1]:find("false", 1, true) ~= nil, out[1])
end)

test("Slash: the key = value line carries no trailing colon (house style)", function()
  local out = captureChat(function() Sl:CliGet("settings.enabled") end)
  assertFalse(out[1]:sub(-1) == ":")
end)
-- ── list ───────────────────────────────────────────────────────────────────────

test("Slash:BuildListLines opens with the green 'Available settings' header", function()
  local l = Sl:BuildListLines()
  assertEqual(l[1], "|cff33ff99Available settings|r")
end)

test("Slash:BuildListLines has no trailing colon on any line", function()
  for _, line in ipairs(Sl:BuildListLines()) do
    assertFalse(line:sub(-1) == ":", "trailing colon on: " .. line)
  end
end)

test("Slash:BuildListLines indents group headers by two and rows by four", function()
  local sawGroup, sawRow = false, false
  for i, line in ipairs(Sl:BuildListLines()) do
    if i > 1 then
      if line:match("^  |cff3399ff%[") then sawGroup = true end
      if line:match("^    |cFFFFFF00") then sawRow = true end
    end
  end
  assertTrue(sawGroup, "an azure [group] header at a two-space indent")
  assertTrue(sawRow, "a gold path row at a four-space indent")
end)

test("Slash:BuildListLines emits one row for every schema row", function()
  local rows = 0
  for i, line in ipairs(Sl:BuildListLines()) do
    if i > 1 and line:match("^    ") then rows = rows + 1 end
  end
  assertEqual(rows, #NS.Schema.Schema)
end)

test("Slash:BuildListLines groups the rows under their declared page order", function()
  -- Asserted against the SCHEMA's first group rather than a literal. The old form named "Capture"
  -- on both sides, so it agreed with a LIST_GROUP_ORDER that named a non-existent group and matched
  -- nothing — the listing was really falling through to first-seen order, and the test passed
  -- anyway (F-007).
  local lines = Sl:BuildListLines()
  local firstGroup
  for i = 2, #lines do
    local g = lines[i]:match("^  |cff3399ff%[(.-)%]")
    if g then firstGroup = g; break end
  end
  assertEqual(firstGroup, NS.Schema.Schema[1].group,
    "the listing must lead with the panel's first section")
end)

-- ── get / set / reset ──────────────────────────────────────────────────────────

test("Slash:CliGet prints the single-line path = value form", function()
  local out = captureChat(function() Sl:CliGet("settings.enabled") end)
  assertEqual(#out, 1)
  assertTrue(out[1]:find("settings.enabled", 1, true) ~= nil)
end)

test("Slash:CliGet reports an unknown path rather than printing nil", function()
  local out = captureChat(function() Sl:CliGet("settings.nonesuch") end)
  assertTrue(joined(out):find("Setting not found", 1, true) ~= nil)
end)

test("Slash:CliGet prints a usage line when given nothing", function()
  local out = captureChat(function() Sl:CliGet("") end)
  assertTrue(joined(out):find("Usage", 1, true) ~= nil)
end)

test("Slash:CliSet writes a boolean from a human word", function()
  captureChat(function() Sl:CliSet("settings.trackMoney false") end)
  assertEqual(NS.Schema:Get("settings.trackMoney"), false)
  captureChat(function() Sl:CliSet("settings.trackMoney on") end)
  assertEqual(NS.Schema:Get("settings.trackMoney"), true)
end)

test("Slash:CliSet writes a number and echoes the STORED value back", function()
  local out = captureChat(function() Sl:CliSet("settings.windowScale 1.25") end)
  assertEqual(NS.Schema:Get("settings.windowScale"), 1.25)
  assertTrue(out[#out]:find("1.25x", 1, true) ~= nil, "echoed through the shared formatter")
  captureChat(function() Sl:CliSet("settings.windowScale 1.0") end)
end)

test("Slash:CliSet rejects a non-numeric value for a number setting", function()
  local out = captureChat(function() Sl:CliSet("settings.windowScale huge") end)
  assertTrue(joined(out):find("expected a number", 1, true) ~= nil)
end)

test("Slash:CliSet reports an unknown path", function()
  local out = captureChat(function() Sl:CliSet("settings.nonesuch 1") end)
  assertTrue(joined(out):find("Setting not found", 1, true) ~= nil)
end)

test("Slash:CliSet refuses a value-less set and says why", function()
  -- A deliberate change of wording, not a regression. The old parser matched `^(%S+)%s+(.+)$`, so a
  -- path with no value failed to match at all and fell through to the usage line. The library
  -- matches `^(%S+)%s*(.*)$`, so the path IS resolved and the empty value reaches the type-aware
  -- parser — which answers with what is actually wrong with it. The usage line still fires on a
  -- bare `/bl set`.
  local out = captureChat(function() Sl:CliSet("settings.windowScale") end)
  local all = joined(out)
  assertTrue(all:find("Invalid value for settings.windowScale", 1, true) ~= nil, all)
  assertTrue(all:find("expected a number", 1, true) ~= nil, all)
  local bare = captureChat(function() Sl:CliSet("") end)
  assertTrue(joined(bare):find("Usage: /bl set <path> <value>", 1, true) ~= nil, joined(bare))
end)

test("Slash:CliReset restores one setting to its default", function()
  captureChat(function() Sl:CliSet("settings.qualityThreshold 4") end)
  captureChat(function() Sl:CliReset("settings.qualityThreshold") end)
  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0)
end)

test("Slash:CliReset echoes a table default through the shared formatter", function()
  local out = captureChat(function() Sl:CliReset("settings.excludedStores") end)
  assertTrue(joined(out):find("(none)", 1, true) ~= nil, "not a raw table pointer")
end)

-- slash-commands-§5: ONE colored `key = value` renderer across the whole read/write surface, so a
-- reset echo is byte-identical in shape to the get/set echo two functions away.
test("Slash:CliReset echoes the colored key = value shape, like get and set", function()
  local out = captureChat(function() Sl:CliReset("settings.qualityThreshold") end)
  local want = T.mocks.LibStub("LibKa0s-Slash-1.0", true).FormatKV("settings.qualityThreshold", "0")
  assertTrue(out[#out]:find(want, 1, true) ~= nil,
    "colored key = value after the [BL] tag, got: " .. out[#out])
end)

-- The echo reads the STORED value back, so it reports what was actually written rather than what
-- was requested — the same clamping guarantee CliSet gives.
test("Slash:CliReset echoes the stored value, not the requested one", function()
  captureChat(function() Sl:CliSet("settings.windowScale 1.25") end)
  local out = captureChat(function() Sl:CliReset("settings.windowScale") end)
  local stored = NS.Schema:Get("settings.windowScale")
  assertEqual(stored, 1.0, "reset must restore the default")
  assertTrue(joined(out):find(("%.2fx"):format(stored), 1, true) ~= nil, joined(out))
end)

test("Slash:CliResetAll restores the schema AND clears the filter lists", function()
  captureChat(function() Sl:CliSet("settings.qualityThreshold 4") end)
  NS.Filters:AddBlacklist(2589)
  captureChat(function() Sl:CliResetAll() end)
  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0)
  assertEqual(NS.Filters:Count(NS.Filters:Blacklist()), 0)
end)

-- ── Dispatch and help ──────────────────────────────────────────────────────────

test("Slash: a bare /bl prints the help index", function()
  local out = captureChat(function() Sl:OnSlash("") end)
  assertTrue(joined(out):find("slash commands", 1, true) ~= nil)
end)

test("Slash: the help index has one row per COMMANDS entry, plus the header", function()
  local out = captureChat(function() Sl:PrintHelp() end)
  assertEqual(#out, #NS.COMMANDS + 1)
end)

test("Slash: the help header names both the short verb and its alias", function()
  local out = captureChat(function() Sl:PrintHelp() end)
  assertTrue(out[1]:find("/bankledger", 1, true) ~= nil)
  assertTrue(out[1]:find("/bl", 1, true) ~= nil)
end)

test("Slash: help rows are gold command, em-dash, white description, indented", function()
  -- The color codes are UPPERCASE and the row carries a two-space indent: both are
  -- LibKa0s-Slash-1.0's one command-row formatter, which the settings landing page now shares.
  local out = captureChat(function() Sl:PrintHelp() end)
  assertTrue(out[2]:find("  |cFFFFFF00/bl ", 1, true) ~= nil, out[2])
  assertTrue(out[2]:find("\226\128\148", 1, true) ~= nil, "an em-dash separator")
  assertTrue(out[2]:find("|cFFFFFFFF", 1, true) ~= nil, "the description is wrapped white")
end)

test("Slash: an unknown verb says so and then prints the help index", function()
  local out = captureChat(function() Sl:OnSlash("wibble") end)
  assertTrue(out[1]:find("unknown command 'wibble'", 1, true) ~= nil)
  assertTrue(#out > 1, "followed by the help index")
end)

test("Slash: dispatch lower-cases only the verb, preserving the argument's case", function()
  -- Schema paths are camelCase, so lower-casing the remainder would break every `set`.
  captureChat(function() Sl:OnSlash("SET settings.windowScale 1.15") end)
  assertEqual(NS.Schema:Get("settings.windowScale"), 1.15)
  captureChat(function() Sl:CliSet("settings.windowScale 1.0") end)
end)

test("Slash:CliVersion prints a single tagged version line", function()
  local out = captureChat(function() Sl:CliVersion() end)
  assertEqual(#out, 1)
  assertTrue(out[1]:find("v" .. NS.version, 1, true) ~= nil)
end)

test("Slash: every chat line carries the cyan [BL] tag", function()
  local out = captureChat(function() Sl:PrintHelp(); Sl:CliList(); Sl:CliVersion() end)
  for _, line in ipairs(out) do
    assertTrue(line:find("|cff00ffff[BL]|r", 1, true) == 1, "untagged line: " .. line)
  end
end)

test("Slash: /bl list groups in schema declaration order, matching the panel", function()
  -- The F-007 guard, rebuilt. The old shape was a hand-maintained LIST_GROUP_ORDER constant that
  -- named "Window" — a group that no longer existed — and omitted "Master Controls", so every name
  -- in it was inert and the listing silently fell through to first-seen order while the test passed.
  -- LibKa0s-Slash-1.0 has no such constant: it groups strictly in allRows() order, which IS the
  -- panel's order. So the invariant is now asserted against the schema itself, and there is no
  -- second list left to rot.
  local want = {}
  local seen = {}
  for _, row in ipairs(NS.Schema.Schema) do
    local g = row.group or "?"
    if not seen[g] then seen[g] = true; want[#want + 1] = g end
  end
  local got = {}
  for _, line in ipairs(Sl:BuildListLines()) do
    local g = line:match("^  |cff3399ff%\[(.-)%\]")
    if g then got[#got + 1] = g end
  end
  assertEqual(#got, #want, "one heading per declared schema group")
  for i, g in ipairs(want) do
    assertEqual(got[i], g, "heading " .. i .. " is out of declaration order")
  end
end)

test("Slash: /bl version and the help header report the same version", function()
  -- F-017: the help header read NS.version directly while /bl version preferred the TOC metadata,
  -- so the two could disagree the moment the TOC was bumped without the constant.
  local versionLine = captureChat(function() Sl:CliVersion() end)[1]
  local helpHeader = captureChat(function() Sl:PrintHelp() end)[1]
  local v = versionLine:match("v([%d%.]+)")
  assertTrue(v ~= nil, "no version in " .. tostring(versionLine))
  assertTrue(helpHeader:find("v" .. v, 1, true) ~= nil,
    ("help says %q, /bl version says v%s"):format(helpHeader, v))
end)
