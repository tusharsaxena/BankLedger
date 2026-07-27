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

test("Slash.FormatSchemaValue renders booleans as true/false", function()
  local row = { type = "boolean" }
  assertEqual(Sl.FormatSchemaValue(row, true), "true")
  assertEqual(Sl.FormatSchemaValue(row, false), "false")
end)

test("Slash.FormatSchemaValue applies a row's number format", function()
  assertEqual(Sl.FormatSchemaValue({ type = "number", fmt = "%.2fx" }, 1), "1.00x")
end)

test("Slash.FormatSchemaValue renders a set as a sorted brace list", function()
  local row = { type = "table" }
  assertEqual(Sl.FormatSchemaValue(row, { GUILD_BANK = true, BANK = true }),
    "{BANK, GUILD_BANK}")
end)

test("Slash.FormatSchemaValue renders an empty set as (none)", function()
  assertEqual(Sl.FormatSchemaValue({ type = "table" }, {}), "(none)")
end)

test("Slash.FormatSchemaValue renders nil as nil", function()
  assertEqual(Sl.FormatSchemaValue({ type = "number" }, nil), "nil")
end)

test("Slash.FormatKV colours the key gold and the value white", function()
  assertEqual(Sl.FormatKV("settings.enabled", "true"),
    "|cffffff00settings.enabled|r = |cfffffffftrue|r")
end)

test("Slash.FormatKV carries no trailing colon (house style)", function()
  assertFalse(Sl.FormatKV("a", "b"):sub(-1) == ":")
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
      if line:match("^    |cffffff00") then sawRow = true end
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

test("Slash:CliSet prints usage when the value is missing", function()
  local out = captureChat(function() Sl:CliSet("settings.windowScale") end)
  assertTrue(joined(out):find("Usage", 1, true) ~= nil)
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

test("Slash: help rows are gold command, em-dash, white description", function()
  local out = captureChat(function() Sl:PrintHelp() end)
  assertTrue(out[2]:find("|cffffff00/bl ", 1, true) ~= nil)
  assertTrue(out[2]:find("\226\128\148", 1, true) ~= nil, "an em-dash separator")
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

test("Slash: every declared /bl list group actually exists in the schema", function()
  -- F-007: the constant named "Window", a group that no longer exists, and omitted "Master
  -- Controls" — so the "declared order" silently was not the order in force. Ordering by a name
  -- nothing matches is invisible until someone compares the output to the panel.
  local groups = {}
  for _, row in ipairs(NS.Schema.Schema) do groups[row.group or "?"] = true end
  for _, name in ipairs(NS.Slash.LIST_GROUP_ORDER) do
    assertTrue(groups[name], ("/bl list orders by %q, which no schema row declares"):format(name))
  end
end)
