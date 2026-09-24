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

-- LibKa0s-Slash minor 15: the write seam may REFUSE, and the descriptor's `set` is the Schema
-- instance's own three-value member, so the library prints the refusal instead of echoing the
-- unchanged value as though the write had landed. No row this addon ships carries a `validate`
-- today (the parser refuses a dropdown value before the seam is reached, and clamps a slider), so
-- the case lends one to a live row for its duration: what it pins is the WIRING, seam to CLI.
-- red under: the descriptor handing over a `set` that drops the seam's answer (Slash minor 14 and
-- earlier behaved exactly so) -- the old value is echoed back as `key = value`.
test("slash: /bl set with a refused value prints INVALID, the reason and the why, and stores nothing",
  function()
    local path = "settings.rowHoverAlpha"
    local row = NS.SchemaRuntime.FindRow(path)
    local savedValidate, saved = row.validate, NS.Schema:Get(path)
    row.validate = function(v)
      if type(v) == "number" and v > 0.2 then return false, "too bright to read the row under it" end
      return true
    end
    local ok, out = pcall(captureChat, function() Sl:CliSet(path .. " 0.3") end)
    row.validate = savedValidate
    if not ok then error(out, 0) end
    assertEqual(#out, 3, "the INVALID line, the reason and the why: " .. joined(out))
    assertTrue(out[1]:find("Invalid value for " .. path, 1, true) ~= nil, out[1])
    assertTrue(out[2]:find("  invalid value", 1, true) ~= nil, out[2])
    assertTrue(out[3]:find("  too bright to read the row under it", 1, true) ~= nil, out[3])
    assertEqual(NS.Schema:Get(path), saved, "nothing was stored")
  end)

-- The docblock on S:Set says only NS.Schema:Set trims a refusal to two values, while the instance's
-- own Set (what the CLI reads) answers three. Both halves pinned, so neither drifts from the words.
test("schema: NS.Schema:Set trims a validate refusal to two values; the instance's Set answers three",
  function()
    local path = "settings.rowHoverAlpha"
    local row = NS.SchemaRuntime.FindRow(path)
    local savedValidate = row.validate
    row.validate = function() return false, "why" end
    local host = { NS.Schema:Set(path, 0.3) }
    local inst = { NS.SchemaRuntime.Set(path, 0.3) }
    row.validate = savedValidate
    assertEqual(#host, 2, "NS.Schema:Set answers false, reason")
    assertEqual(host[1], false)
    assertEqual(inst[1], false)
    assertEqual(inst[3], "why", "the instance passes the validate's why on")
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

test("Slash: /bl resetall is the wholesale reset — the schema, the filter lists AND the ledger", function()
  -- options-ui-§12 (BankLedger-A-02, Option A): the verb is the same act as Reset all settings. The
  -- mock has no StaticPopup_Show, so the request runs the act directly; the confirm is pinned in
  -- tests/test_reset_routes.lua. Before, this case pinned a schema walk that kept the ledger.
  -- red under: Sl:CliResetAll going back to the library's walk (the ledger survives).
  captureChat(function() Sl:CliSet("settings.qualityThreshold 4") end)
  NS.Filters:AddBlacklist(2589)
  NS.db.global.ledger = {
    { ts = os.time(), kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 2589 },
  }
  captureChat(function() Sl:CliResetAll() end)
  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0)
  assertEqual(NS.Filters:Count(NS.Filters:Blacklist()), 0)
  assertEqual(#NS.db.global.ledger, 0, "the verb kept recorded history")
end)

-- ── A bulk reset is ONE [Set] line (debug-logging-§10) ─────────────────────────────────────────
--
-- Standard v2.44.0: a reset through the settings helper is logged as ONE `[Set] <act> <scope>: N rows`
-- line and MUST NOT emit a per-row `[Set]` line, while each row's onChange still runs. The library's
-- Slash minor 8 brackets its row walk (`bulkBegin` / `bulkEnd`), and the seam mutes itself inside
-- the bracket.
--
-- `/bl resetall` NO LONGER RUNS THAT WALK. It is the wholesale Sl:ResetEverything (options-ui-§12),
-- which is not a walk through the seam and logs its own one line, worded by the act. The walk cases
-- below drive the library's CliResetAll on an instance built from the SAME seam members the Slash
-- descriptor hands over (settings/Slash.lua), because the descriptor still hands the library the
-- bracket pair and what they pin is the seam's half of that contract.

-- Every [Set] line one act writes to the debug buffer, with logging on for the act alone. Returns
-- the lines, then pcall's ok and err, so a case can read the lines of an act that raised.
local function setLinesProtected(fn)
  local savedDebug = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  local ok, err = pcall(fn)
  local out = {}
  for _, line in ipairs(NS.DebugLog.buffer) do
    if line:find("[Set]", 1, true) then out[#out + 1] = line end
  end
  NS.DebugLog:Clear()
  NS.State.debug = savedDebug
  return out, ok, err
end

-- The same, re-raising the act's error.
local function setLines(fn)
  local out, ok, err = setLinesProtected(fn)
  if not ok then error(err, 0) end
  return out
end

-- The library's bracketed row walk, on the seam members settings/Slash.lua's descriptor passes.
local R = NS.SchemaRuntime
local sweepCli = mocks.LibStub("LibKa0s-Slash-1.0"):New({
  slash = "/blsweep", commands = {}, print = function() end,
  get = R.Get, set = R.Set, findRow = R.FindRow, allRows = R.AllRows,
  applyDefault = R.ApplyDefault, bulkBegin = R.BulkBegin, bulkEnd = R.BulkEnd,
})
local function librarySweep() return sweepCli:CliResetAll() end

test("Slash: /bl resetall logs ONE [Set] line counting the rows it CHANGED, and no per-row [Set]", function()
  -- N is the stored rows whose value actually changed (debug-logging-§10), worded by the act: the
  -- wholesale reset's `reset account-wide settings to defaults (N rows)`, not the walk's
  -- `reset all: N rows`, since the verb is Sl:ResetEverything now (options-ui-§12).
  -- red under: routing the verb back to the library's walk (`reset all: 2 rows`), or counting every
  -- stored row rather than the changed ones.
  captureChat(function() Sl:CliResetAll() end)   -- baseline: every row at its default
  captureChat(function() Sl:CliSet("settings.qualityThreshold 4") end)
  captureChat(function() Sl:CliSet("settings.rowHoverAlpha 0.3") end)
  local lines
  captureChat(function() lines = setLines(function() Sl:OnSlash("resetall") end) end)
  assertEqual(#NS.Schema.Schema, 16, "the schema still carries sixteen rows")
  assertEqual(#lines, 1, "one line for the one act, got:\n" .. table.concat(lines, "\n"))
  assertTrue(lines[1]:find("[Set] reset account-wide settings to defaults (2 rows)", 1, true) ~= nil,
    "the line names the act and the rows changed, got: " .. tostring(lines[1]))
  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0, "the reset still happened")
end)

test("Slash: /bl resetall with every row already at its default logs 0 rows, and nothing per row", function()
  -- The act still happened, so it still gets its one line. It changed nothing, so N is 0.
  -- red under: the same routing as the case above.
  captureChat(function() Sl:CliResetAll() end)
  local lines
  captureChat(function() lines = setLines(function() Sl:CliResetAll() end) end)
  assertEqual(#lines, 1, "one line for the one act, got:\n" .. table.concat(lines, "\n"))
  assertTrue(lines[1]:find("[Set] reset account-wide settings to defaults (0 rows)", 1, true) ~= nil,
    tostring(lines[1]))
end)

test("Slash: the library's sweep logs ONE [Set] reset all line counting the rows it CHANGED", function()
  -- The walk visits all sixteen rows and two of them move.
  -- red under: dropping bulkBegin/bulkEnd from the seam (a `[Set] <path> = <value>` line per row),
  -- muting the seam without emitting the summary (none), or logging the library's `count` (16).
  librarySweep()   -- baseline: every row at its default
  NS.Schema:Set("settings.qualityThreshold", 4)
  NS.Schema:Set("settings.rowHoverAlpha", 0.3)
  local lines = setLines(librarySweep)
  assertEqual(#lines, 1, "one line for the one act, got:\n" .. table.concat(lines, "\n"))
  assertTrue(lines[1]:find("[Set] reset all: 2 rows", 1, true) ~= nil, tostring(lines[1]))
  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0, "the sweep still happened")
end)

-- A host act wrapped around the library's reset, one bracket inside another.
local function nestedResetAll(info)
  NS.Schema.BulkBegin("reset", "all")
  local ok, err = pcall(librarySweep)
  NS.Schema.BulkEnd("reset", "all", 0, (not ok) and err or nil, info)
  if not ok then error(err, 0) end
end

test("Slash: a reset nested inside another bracket logs ONE line, for the outermost act", function()
  -- The inner bracket's close must not emit: its writes join the outer tally, and the one line comes
  -- when the depth returns to 0.
  -- red under: emitting from every BulkEnd rather than only the outermost.
  librarySweep()
  NS.Schema:Set("settings.qualityThreshold", 4)
  NS.Schema:Set("settings.trackItems", false)
  local lines
  captureChat(function()
    lines = setLines(function() nestedResetAll({ profileReset = false }) end)
  end)
  assertEqual(#lines, 1, "one line for the nested act, got:\n" .. table.concat(lines, "\n"))
  assertTrue(lines[1]:find("[Set] reset all: 2 rows", 1, true) ~= nil, tostring(lines[1]))
end)

test("Slash: a bracket reporting profileReset logs nothing, even around a nested reset", function()
  -- The profile-event handler logs a whole-profile reset once; no bracket may add a second line.
  librarySweep()
  NS.Schema:Set("settings.qualityThreshold", 4)
  local lines
  captureChat(function()
    lines = setLines(function() nestedResetAll({ profileReset = true }) end)
  end)
  assertEqual(#lines, 0, "no [Set] line at all, got:\n" .. table.concat(lines, "\n"))
  local after = setLines(function() NS.Schema:Set("settings.qualityThreshold", 1) end)
  NS.Schema:Set("settings.qualityThreshold", 0)
  assertEqual(#after, 1, "and the seam logs again afterwards")
end)

test("Slash: the library's sweep still runs every row's onChange, and the seam logs again afterwards", function()
  -- Only the LOG collapses. A mute that also skipped onChange would leave the capture gate judging
  -- movements by settings the reset had replaced; a mute that stuck would silence every later write.
  --
  -- EVERY ROW THE SWEEP TOUCHES, which since v2.54.0 is every row but the exempt one: the Minimap
  -- button row is carved out of a sweep by S.RESET_EXEMPT (launcher-§3), so its onChange -- the hook
  -- that would move the button -- must NOT fire. Counted rather than assumed, and asserted from both
  -- sides, so neither a sweep that skipped everything nor one that skipped nothing reads as green.
  local fired, withOnChange, exemptFired = 0, 0, 0
  local wrapped = {}
  for _, row in ipairs(NS.Schema.Schema) do
    if row.onChange then
      local orig = row.onChange
      wrapped[row] = orig
      if NS.Schema.RESET_EXEMPT[row.path] then
        row.onChange = function(v) exemptFired = exemptFired + 1; return orig(v) end
      else
        withOnChange = withOnChange + 1
        row.onChange = function(v) fired = fired + 1; return orig(v) end
      end
    end
  end
  assertTrue(withOnChange > 0, "no row carries an onChange, so this case proves nothing")
  local ok, err = pcall(librarySweep)
  for row, orig in pairs(wrapped) do row.onChange = orig end
  if not ok then error(err, 0) end
  assertEqual(fired, withOnChange, "every swept row's onChange must fire once inside the bracket")
  assertEqual(exemptFired, 0, "an exempt row's onChange fired, so the sweep reached it after all")

  local lines = setLines(function() NS.Schema:Set("settings.qualityThreshold", 2) end)
  NS.Schema:Set("settings.qualityThreshold", 0)
  assertEqual(#lines, 1, "a single write after the reset is logged, once")
  assertTrue(lines[1]:find("settings.qualityThreshold = 2", 1, true) ~= nil, tostring(lines[1]))
end)

test("Slash: a row that raises mid-sweep logs ONE line marked as stopped, re-raises, and unmutes the seam", function()
  -- The library runs bulkEnd whenever bulkBegin ran, handing it the raised value, then re-raises.
  -- The line still comes, once, counting the rows changed before the raise, and says the reset
  -- stopped. The host's depth counter must unwind on that path, or one bad row mutes the seam for
  -- the rest of the session.
  -- red under: BulkEnd ignoring `err` (no marker), or the host swallowing the error.
  -- qualityThreshold comes before retentionDays in schema order, so it is reset and counted before
  -- the raise. retentionDays is written, counted, and then raises from its onChange.
  librarySweep()   -- baseline: every row at its default
  NS.Schema:Set("settings.qualityThreshold", 4)
  NS.Schema:Set("settings.retentionDays", 7)
  local row = NS.Schema:FindRow("settings.retentionDays")
  local orig = row.onChange
  row.onChange = function() error("boom", 0) end
  local lines, ok, err
  captureChat(function() lines, ok, err = setLinesProtected(librarySweep) end)
  row.onChange = orig
  librarySweep()   -- leave every row at its default
  assertTrue(not ok, "the raising row's error must reach the caller")
  assertEqual(err, "boom", "the error is re-raised unchanged")
  assertEqual(#lines, 1, "one line for the one act, got:\n" .. table.concat(lines, "\n"))
  assertTrue(lines[1]:find("[Set] reset all: 2 rows (stopped by an error)", 1, true) ~= nil,
    "the line counts the rows changed before the raise and is marked, got: " .. tostring(lines[1]))

  local after = setLines(function() NS.Schema:Set("settings.qualityThreshold", 3) end)
  NS.Schema:Set("settings.qualityThreshold", 0)
  assertEqual(#after, 1, "the seam must log again once the raising reset is over")
  assertTrue(after[1]:find("(stopped by an error)", 1, true) == nil, "the marker does not stick")
end)

test("Slash: a sweep row raising nil logs the line without the marker (the library hands err = nil)", function()
  -- Characterizes the documented upstream limit: the library hands bulkEnd the raw pcall value, so
  -- a raise of nil reaches the host as `err = nil` and cannot be told from success. The line is
  -- still emitted once and the seam still unmutes.
  local row = NS.Schema:FindRow("settings.retentionDays")
  local orig = row.onChange
  row.onChange = function() error(nil) end
  local lines, ok
  captureChat(function() lines, ok = setLinesProtected(librarySweep) end)
  row.onChange = orig
  assertTrue(not ok, "the raise still reaches the caller")
  assertEqual(#lines, 1, "one line for the one act, got:\n" .. table.concat(lines, "\n"))
  assertTrue(lines[1]:find("[Set] reset all: 0 rows", 1, true) ~= nil, tostring(lines[1]))
  assertTrue(lines[1]:find("stopped by an error", 1, true) == nil, tostring(lines[1]))
  local after = setLines(function() NS.Schema:Set("settings.qualityThreshold", 3) end)
  NS.Schema:Set("settings.qualityThreshold", 0)
  assertEqual(#after, 1, "the seam must log again once the raising reset is over")
end)

-- ── Dispatch and help ──────────────────────────────────────────────────────────

-- slash-commands-§4 (LibKa0s Slash minor 11): a bare /bl runs the `config` verb, which opens the
-- settings panel on its landing page, and `/bl help` is what prints the index. The degraded stub
-- mirrors both branches; its cases are in tests/test_libka0s.lua.

local function configEntry()
  for _, cmd in ipairs(NS.COMMANDS) do
    if cmd[1] == "config" then return cmd end
  end
end

-- Swap the config handler for a probe, run fn, restore it even if fn raises.
local function withConfigProbe(fn)
  local cmd = configEntry()
  local orig = cmd[3]
  local calls = {}
  cmd[3] = function(rest) calls[#calls + 1] = rest end
  local ok, err = pcall(fn)
  cmd[3] = orig
  if not ok then error(err, 0) end
  return calls
end

test("Slash: a bare /bl runs the config verb and prints nothing", function()
  local out
  local calls = withConfigProbe(function() out = captureChat(function() Sl:OnSlash("") end) end)
  assertEqual(#calls, 1, "a bare /bl must reach the config handler once")
  assertEqual(calls[1], "", "with an empty argument")
  assertEqual(#out, 0, "and print no help index: " .. joined(out))
end)

test("Slash: whitespace-only input is a bare /bl too", function()
  for _, input in ipairs({ " ", "   ", "\t", " \t  " }) do
    local out
    local calls = withConfigProbe(function() out = captureChat(function() Sl:OnSlash(input) end) end)
    assertEqual(#calls, 1, ("input %q must reach the config handler"):format(input))
    assertEqual(calls[1], "", ("input %q passes an empty argument"):format(input))
    assertEqual(#out, 0, ("input %q prints nothing: %s"):format(input, joined(out)))
  end
end)

test("Slash: a bare /bl opens the settings panel on its landing page, not a sub-page", function()
  -- The real config handler, end to end: P:Open -> O.OpenOptionsPanel -> Settings.OpenToCategory.
  -- The mock hands the main category id 1 and every subcategory id 2.
  local S = T.mocks.Settings
  local saved = S.OpenToCategory
  local opened = {}
  S.OpenToCategory = function(id) opened[#opened + 1] = id end
  local ok, err = pcall(function() captureChat(function() Sl:OnSlash("") end) end)
  S.OpenToCategory = saved
  if not ok then error(err, 0) end
  assertEqual(#opened, 1, "a bare /bl must open the settings panel once")
  assertEqual(opened[1], 1, "on the main category (the landing page), not a subcategory")
end)

test("Slash: with no config verb, a bare /bl falls back to the help index", function()
  local idx
  for i, cmd in ipairs(NS.COMMANDS) do if cmd[1] == "config" then idx = i end end
  local entry = table.remove(NS.COMMANDS, idx)
  local ok, out = pcall(captureChat, function() Sl:OnSlash("") end)
  table.insert(NS.COMMANDS, idx, entry)
  if not ok then error(out, 0) end
  assertTrue(joined(out):find("slash commands", 1, true) ~= nil, joined(out))
end)

test("Slash: /bl help prints the help index", function()
  local out
  local calls = withConfigProbe(function() out = captureChat(function() Sl:OnSlash("help") end) end)
  assertEqual(#calls, 0, "help must not open the settings panel")
  assertTrue(joined(out):find("slash commands", 1, true) ~= nil, joined(out))
  assertEqual(#out, #NS.COMMANDS + 1, "the full index: the header plus one row per verb")
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

-- ── Feature verbs while the addon is DISABLED (slash-commands-§2, standard v2.54.0) ─────────────
--
-- A verb that DRIVES THE ADDON'S FEATURES answers on ONE tagged line naming `/bl enable` and does
-- NOTHING ELSE. The gate is in the dispatcher, once, with the live set named as data -- a guard
-- pasted into each verb is a dozen places to forget and a wrong default for the next verb added.
--
-- The cases below assert BOTH halves every time, because a case that only reads the message passes
-- over a verb that printed the refusal and then went ahead and acted anyway.

local FEATURE_VERBS = { "show", "hide", "toggle", "session", "test", "purge" }
local LIVE_VERBS = { "help", "config", "version", "enable", "disable", "debug",
                     "get", "set", "list", "reset", "resetall" }

--- The collection's one refusal line (slash-commands-§7), matched by SHAPE rather than by its
--- words: LibKa0s-Slash-1.0 builds it from lib.DISABLED_LINE_FORMAT, and a suite that hard-coded
--- the sentence would be a second copy of the wording the format string exists to keep single.
local function isRefusal(line)
  return line:find("is disabled", 1, true) ~= nil
    and line:find("|cFFFFFF00/bl enable|r", 1, true) ~= nil
end

local function disableAddon() captureChat(function() Sl:OnSlash("disable") end) end

--- Run fn with the addon disabled, and put `settings.enabled` back however fn leaves it.
local function withDisabled(fn)
  local saved = NS.Schema:Get("settings.enabled")
  disableAddon()
  local ok, err = pcall(fn)
  NS.Schema:Set("settings.enabled", saved)
  if not ok then error(err, 0) end
end

local function entryFor(verb)
  for _, cmd in ipairs(NS.COMMANDS) do if cmd[1] == verb then return cmd end end
end

test("Slash: every registered verb is either a feature verb or on the LIVE list, never neither", function()
  -- The two lists in this file are the standard's, spelled out; the live set itself is the
  -- library's (lib.LIVE_VERBS, Slash minor 14), because this addon passes no `liveVerbs`. This case
  -- is what makes them agree: a verb added to NS.COMMANDS and to neither list below reddens here
  -- rather than quietly inheriting whichever behavior it happened to get. `perf` is reserved but
  -- unregistered in this addon (the performance-§12 exemption), so it appears on neither list.
  local classified = {}
  for _, v in ipairs(FEATURE_VERBS) do classified[v] = "feature" end
  for _, v in ipairs(LIVE_VERBS) do
    assertEqual(classified[v], nil, "`" .. v .. "` is on both lists")
    classified[v] = "live"
  end
  for _, cmd in ipairs(NS.COMMANDS) do
    assertTrue(classified[cmd[1]] ~= nil,
      "`/bl " .. cmd[1] .. "` is on neither list: decide whether it drives this addon's FEATURES "
      .. "(and so refuses while disabled) or belongs to the live set, and say so in both places")
  end
  for verb in pairs(classified) do
    assertTrue(entryFor(verb) ~= nil, "`" .. verb .. "` is listed here but registers no verb")
  end
end)

test("Slash: while disabled, every feature verb refuses on ONE line naming /bl enable, and does not act",
function()
  -- The handler is swapped for a probe, so "did not act" is proved at the strongest place there is:
  -- the verb's body never ran at all. The tagged single line is the whole courtesy -- no second line
  -- explaining the state, which is a lecture stapled to a command the player is about to re-run.
  --
  -- red under: moving the gate behind dispatch, dropping a verb from the refusal, printing a second
  -- line, or naming anything other than `/bl enable`.
  withDisabled(function()
    for _, verb in ipairs(FEATURE_VERBS) do
      local entry = entryFor(verb)
      assertTrue(entry ~= nil, "no such verb: " .. verb)
      local orig, ran = entry[3], 0
      entry[3] = function() ran = ran + 1 end
      local out
      local ok, err = pcall(function() out = captureChat(function() Sl:OnSlash(verb) end) end)
      entry[3] = orig
      if not ok then error(err, 0) end
      assertEqual(ran, 0, "`/bl " .. verb .. "` ran its handler while the addon was disabled")
      assertEqual(#out, 1,
        "`/bl " .. verb .. "` must answer on exactly one line, got:\n" .. joined(out))
      assertTrue(out[1]:find("|cff00ffff[BL]|r", 1, true) ~= nil, "untagged: " .. out[1])
      assertTrue(isRefusal(out[1]),
        "`/bl " .. verb .. "` refused without naming the way back: " .. out[1])
    end
  end)
end)

test("Slash: /bl show while disabled leaves the ledger window shut, and opens it once enabled",
function()
  -- The REAL handler this time, end to end, with the window read back. The control half is what
  -- stops this passing on a `Show` that opens nothing under any circumstances.
  --
  -- red under: the gate letting `show` through, or refusing it while the addon is enabled.
  NS.Browser:Hide()
  withDisabled(function()
    local out = captureChat(function() Sl:OnSlash("show") end)
    local w = NS.Browser:GetWindow()
    assertFalse(w ~= nil and w:IsShown(), "the ledger window opened while the addon was disabled")
    assertEqual(#out, 1, "one line and no more: " .. joined(out))
  end)
  captureChat(function() Sl:OnSlash("enable") end)
  captureChat(function() Sl:OnSlash("show") end)
  local w = NS.Browser:GetWindow()
  assertTrue(w ~= nil and w:IsShown(),
    "the control failed: /bl show does not open the window even when the addon is on")
  NS.Browser:Hide()
end)

test("Slash: /bl test while disabled does not start test mode", function()
  -- A second real handler, on state rather than on a frame, so the refusal is not a property of one
  -- module. Test mode is session state the Master controls checkbox shares.
  assertFalse(NS.LedgerTable:IsTestMode(), "precondition: test mode is off")
  withDisabled(function()
    local out = captureChat(function() Sl:OnSlash("test") end)
    assertFalse(NS.LedgerTable:IsTestMode(), "`/bl test` started a sample ledger while disabled")
    assertEqual(#out, 1, "one line and no more: " .. joined(out))
  end)
end)

test("Slash: an unknown verb is never REFUSED while disabled -- it is still unknown", function()
  -- It is not a feature verb, and the dispatcher's own `unknown command` plus the help index is a
  -- better answer than a line about a setting the player did not ask about.
  withDisabled(function()
    local out = captureChat(function() Sl:OnSlash("wibble") end)
    -- The FIRST line is the whole of it. The index that follows carries the refusal line under its
    -- own header, as it does whenever `help` renders while the addon is off, and that line is a
    -- statement about the rows below it rather than an answer to what was typed.
    assertFalse(isRefusal(out[1]),
      "an unknown verb got the disabled refusal instead of the unknown-verb answer: " .. out[1])
    assertTrue(out[1]:find("unknown command \'wibble\'", 1, true) ~= nil, joined(out))
  end)
end)

test("Slash: the live verbs keep answering while disabled, and none of them is refused", function()
  -- slash-commands-§2 MUSTs these. A player must be able to read and repair settings, and reach the
  -- panel, while the addon is off -- which is precisely when they are most likely to need to -- and
  -- `enable` above all, or the pair is one-way.
  --
  -- Re-disabled before EACH verb, because two of them (`enable`, `resetall`) legitimately turn the
  -- addon back on and the next verb must still be tested in the disabled state.
  --
  -- red under: any of these landing on the feature side of the gate.
  local saved = NS.Schema:Get("settings.enabled")
  local ok, err = pcall(function()
    for _, verb in ipairs(LIVE_VERBS) do
      disableAddon()
      assertEqual(NS.Schema:Get("settings.enabled"), false, "precondition for `/bl " .. verb .. "`")
      local out = captureChat(function() Sl:OnSlash(verb) end)
      -- `help` is the one exception in SHAPE and not in substance: the index prints in full, with
      -- the refusal line under its header, because the player has to be able to SEE `enable` in
      -- the list. It is a statement about the rows below it, not a refusal of `help`.
      if verb == "help" then
        assertTrue(#out > 2, "the help index was refused rather than printed")
      else
        for _, line in ipairs(out) do
          assertFalse(isRefusal(line),
            "`/bl " .. verb .. "` was refused, and the standard MUSTs that it answers: " .. line)
        end
      end
    end
    -- And the one that matters most, read back from the store rather than from its echo.
    disableAddon()
    captureChat(function() Sl:OnSlash("enable") end)
    assertEqual(NS.Schema:Get("settings.enabled"), true,
      "/bl enable must work while the addon is disabled, or the switch only goes one way")
  end)
  if NS.DebugLog and NS.DebugLog.Hide then NS.DebugLog:Hide() end
  NS.Schema:Set("settings.enabled", saved)
  if not ok then error(err, 0) end
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
    local g = line:match("^  |cff3399ff%[(.-)%]")
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
