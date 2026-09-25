-- tests/test_schema_runtime.lua -- the settings write seam, characterized (architecture-§5).
--
-- settings/Schema.lua's single write seam is what every settings surface reaches: a panel widget,
-- `/bl set`, `/bl reset`, the resetall sweep and the host verbs. These cases pin what a caller of
-- NS.Schema can observe of it -- the order of the store, the [Set] line, the row's reaction and the
-- panel repaint; the exact answers, arity included; what a refusal leaves behind; the one inverted
-- path; and the same seam on a load with no LibKa0s at all.
--
-- The first group was written BEFORE the seam moved onto LibKa0s-Schema-1.0 and passed against the
-- host's own implementation; it is the characterization that the move changed nothing a caller can
-- see.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = NS.Schema
local PATH = "settings.qualityThreshold"

--- Run `fn(log)` with the seam's four observable effects recorded, in order, into `log`: the [Set]
--- debug line, the row's onChange (with what the store held at that moment), and the panel repaint.
--- Everything swapped is put back, raise or not.
local function observed(row, fn)
  local log = {}
  local savedDebug, savedFlag, savedOnChange = NS.Debug, NS.State.debug, row.onChange
  local P = NS.Panel
  local savedRefresh = P and P.Refresh
  NS.Debug = function(tag, fmt, ...) log[#log + 1] = ("debug:[%s] " .. fmt):format(tag, ...) end
  NS.State.debug = true
  row.onChange = function(v)
    log[#log + 1] = ("onChange:%s stored=%s"):format(tostring(v), tostring(S:Get(row.path)))
  end
  if P then P.Refresh = function() log[#log + 1] = "refresh" end end
  local ok, err = pcall(fn, log)
  NS.Debug, NS.State.debug, row.onChange = savedDebug, savedFlag, savedOnChange
  if P then P.Refresh = savedRefresh end
  if not ok then error(err, 0) end
  return log
end

-- ── the seam, characterized ──────────────────────────────────────────────────────────────────

test("Schema:Set stores, then logs one [Set] line, then reacts, then repaints -- once each", function()
  local row = S:FindRow(PATH)
  local log = observed(row, function() S:Set(PATH, 3) end)
  S:Set(PATH, 0)
  assertEqual(table.concat(log, " | "),
    "debug:[Set] settings.qualityThreshold = 3 | onChange:3 stored=3 | refresh")
end)

test("Schema:Set answers exactly `true` on success, and `false, reason` on a refusal", function()
  local n, ok = select("#", S:Set(PATH, 2)), S:Set(PATH, 2)
  assertEqual(n, 1, "success answers one value")
  assertEqual(ok, true)
  S:Set(PATH, 0)

  local got = { S:Set("settings.nonesuch", 1) }
  assertEqual(select("#", S:Set("settings.nonesuch", 1)), 2, "an unknown path answers two values")
  assertEqual(got[1], false)
  assertEqual(got[2], "unknown path: settings.nonesuch")
end)

test("Schema:Set refuses a value its row's validate rejects, and stores and calls nothing", function()
  local row = S:FindRow(PATH)
  local savedValidate = row.validate
  row.validate = function(v) return v ~= 5, "five is right out" end
  local answers
  local log = observed(row, function()
    answers = { n = select("#", S:Set(PATH, 5)), S:Set(PATH, 5) }
  end)
  row.validate = savedValidate
  assertEqual(answers.n, 2, "a validate refusal answers two values")
  assertEqual(answers[1], false)
  assertEqual(answers[2], "invalid value")
  assertEqual(NS.db.global.settings.qualityThreshold, 0, "nothing was stored")
  assertEqual(#log, 0, "no line, no reaction, no repaint: " .. table.concat(log, " | "))
end)

test("the live seam takes the row, not writeThrough, when settings.enabled has one", function()
  -- settings.enabled is on S.WRITE_THROUGH, and a full load composes its row. The library's
  -- writeRow answers the indexed row first, so the write validates and runs the row's onChange --
  -- the latch -- rather than being stored raw.
  local row = S:FindRow("settings.enabled")
  assertTrue(row ~= nil, "the full load composed no settings.enabled row")
  assertFalse(row.writeThrough == true, "FindRow answered the synthetic writeThrough row")
  local log = observed(row, function() S:Set("settings.enabled", true) end)
  assertTrue(table.concat(log, " | "):find("onChange:true", 1, true) ~= nil,
    "the row's onChange did not run: " .. table.concat(log, " | "))
end)

test("Schema:Set on an unknown path stores nothing, anywhere", function()
  S:Set("settings.nonesuch", 1)
  S:Set("nonesuch", 1)
  assertEqual(NS.db.global.settings.nonesuch, nil)
  assertEqual(NS.db.global.nonesuch, nil)
end)

test("Schema:Set on a session-only row calls its own set, reacts and repaints, stores nothing", function()
  local row = S:FindRow("state.debugConsole")
  assertTrue(row ~= nil and row.sessionOnly == true, "precondition: the composed console row")
  local log = observed(row, function() S:Set("state.debugConsole", true) end)
  S:Set("state.debugConsole", false)
  assertEqual(table.concat(log, " | "),
    "debug:[Set] state.debugConsole = true | onChange:true stored=true | refresh")
  assertEqual(NS.db.global.state, nil)
end)

test("Minimap row: the seam writes LibDBIcon's hide flag inverted, into the table LibDBIcon holds", function()
  local held = NS.db.global.minimap
  assertEqual(S:Set(S.MINIMAP_PATH, false), true)
  assertTrue(NS.db.global.minimap == held, "the seam replaced the table LibDBIcon holds")
  assertEqual(held.hide, true, "SHOWN = false is hide = true")
  assertEqual(S:Get(S.MINIMAP_PATH), false, "and reads back in the row's own sense")
  assertEqual(S:Set(S.MINIMAP_PATH, true), true)
  assertEqual(held.hide, false)
  assertEqual(S:Get(S.MINIMAP_PATH), true)
end)

test("Schema:ApplyDefault restores one row and answers `true`; a pathless row answers `false`", function()
  S:Set(PATH, 4)
  local row = S:FindRow(PATH)
  assertEqual(select("#", S:ApplyDefault(row)), 1)
  assertEqual(S:Get(PATH), 0)
  assertEqual(S:ApplyDefault({ label = "no path" }), false)
  assertEqual(S:ApplyDefault(nil), false)
end)

test("Schema:ApplyDefault leaves the Minimap row alone inside a bracket, and resets it outside one", function()
  -- launcher-§3's carve-out is scoped to a sweep: `/bl reset minimap.shown` is the player naming
  -- that exact row, and it applies.
  local row = S:FindRow(S.MINIMAP_PATH)
  S:Set(S.MINIMAP_PATH, false)
  S.BulkBegin("reset", "all")
  local inside = S:ApplyDefault(row)
  S.BulkEnd("reset", "all")
  assertEqual(inside, false, "the sweep did not skip the exempt row")
  assertEqual(S:Get(S.MINIMAP_PATH), false)
  assertEqual(S:ApplyDefault(row), true)
  assertEqual(S:Get(S.MINIMAP_PATH), true, "a named reset outside a sweep applies")
end)

test("Schema:Default answers a fresh copy of the row's default, and nil for an unknown path", function()
  assertEqual(S:Default(PATH), 0)
  assertEqual(S:Default("settings.nonesuch"), nil)
  local a = S:Default("settings.excludedStores")
  a.BANK = true
  assertEqual(S:Default("settings.excludedStores").BANK, nil)
end)

test("Schema.SameValue compares tables by content and tells false from absent", function()
  assertTrue(S.SameValue({ BANK = true }, { BANK = true }))
  assertFalse(S.SameValue({ BANK = true }, {}))
  assertFalse(S.SameValue({ a = false }, {}))
  assertTrue(S.SameValue(1, 1))
  assertFalse(S.SameValue(1, "1"))
end)

-- ── the same seam with no LibKa0s ────────────────────────────────────────────────────────────

local Env = dofile("tests/degraded_env.lua")

--- A library-less load with its database built, the way OnInitialize builds it.
local function degraded()
  local ns, m = Env.loadDegraded()
  ns:InitDB()
  return ns, m
end

test("Schema degraded: a write lands, reads back, reacts and answers as the live seam does", function()
  local ns = degraded()
  local reacted
  local row = ns.Schema:FindRow(PATH)
  local saved = row.onChange
  row.onChange = function(v) reacted = v end
  local n = select("#", ns.Schema:Set(PATH, 4))
  local ok = ns.Schema:Set(PATH, 4)
  row.onChange = saved
  assertEqual(n, 1)
  assertEqual(ok, true)
  assertEqual(ns.db.global.settings.qualityThreshold, 4)
  assertEqual(ns.Schema:Get(PATH), 4)
  assertEqual(reacted, 4)
  local refused = { ns.Schema:Set("settings.nonesuch", 1) }
  assertEqual(refused[1], false)
  assertEqual(refused[2], "unknown path: settings.nonesuch")
  assertEqual(ns.db.global.settings.nonesuch, nil)
end)

test("Schema degraded: a table value is stored as a copy, and the default stays whole", function()
  local ns = degraded()
  local given = { BANK = true }
  ns.Schema:Set("settings.excludedStores", given)
  given.GUILD_BANK = true
  assertEqual(ns.db.global.settings.excludedStores.GUILD_BANK, nil, "the store aliases the caller")
  ns.Schema:Set("settings.excludedStores", ns.Schema:Default("settings.excludedStores"))
  ns.db.global.settings.excludedStores.BANK = true
  assertEqual(ns.Schema:Default("settings.excludedStores").BANK, nil, "the default was poisoned")
end)

test("Schema degraded: a bracketed sweep writes every row back and closes its bracket", function()
  -- Driven through the stub's own bracket and ApplyDefault, the shape any sweep takes. It used to
  -- ride on the degraded `/bl resetall`, which carried its own walk; that verb is the wholesale
  -- Sl:ResetEverything now (options-ui-§12), so the stub's bracket is pinned directly.
  -- red under: the stub's ApplyDefault writing nothing, or a BulkEnd that leaves the bracket open.
  local ns, m = degraded()
  ns.Schema:Set(PATH, 4)
  ns.Schema:Set("settings.trackItems", false)
  local saved = m.DEFAULT_CHAT_FRAME.AddMessage
  m.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local ok, err = pcall(function()
    ns.Schema.BulkBegin("reset", "all")
    for _, row in ipairs(ns.Schema.Schema) do ns.Schema:ApplyDefault(row) end
    ns.Schema.BulkEnd("reset", "all", nil, nil, { profileReset = false })
  end)
  m.DEFAULT_CHAT_FRAME.AddMessage = saved
  assertTrue(ok, tostring(err))
  assertEqual(ns.Schema:Get(PATH), 0)
  assertEqual(ns.Schema:Get("settings.trackItems"), true)
  -- The bracket closed: a later write is a plain write again.
  assertEqual(ns.Schema:Set(PATH, 1), true)
  assertEqual(ns.db.global.settings.qualityThreshold, 1)
end)

-- ── what the adoption of LibKa0s-Schema-1.0 changed, on purpose ─────────────────────────────

local mocks = T.mocks

test("Schema runtime: the seam is a LibKa0s-Schema-1.0 instance, and the host names are bound to it", function()
  local lib = mocks.LibStub("LibKa0s-Schema-1.0", true)
  assertTrue(lib ~= nil, "the major is not loaded")
  assertTrue(NS.__schemaLib == lib, "settings/Schema.lua resolved something other than the library")
  local R = NS.SchemaRuntime
  assertTrue(R.AllRows() == S.Schema, "the instance holds a copy of the rows, not the rows")
  assertTrue(S.BulkBegin == R.BulkBegin and S.BulkEnd == R.BulkEnd, "the bracket is not the instance's")
  assertTrue(S.SameValue == lib.SameValue, "S.SameValue is not the library's")
  assertTrue(S:FindRow("settings.enabled") == R.FindRow("settings.enabled"))
end)

--- Run `fn` with one extra row appended to the live schema, and take it out again afterwards.
local function withExtraRow(row, fn)
  NS.SchemaRuntime.AddRows({ row })
  local ok, err = pcall(fn)
  for i = #S.Schema, 1, -1 do
    if S.Schema[i] == row then table.remove(S.Schema, i) end
  end
  NS.SchemaRuntime.Reindex()
  if not ok then error(err, 0) end
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

test("Schema:Register reports a path missing from the defaults even when the row has a default", function()
  -- The dead conjunct the adoption removed: the host's own check passed a row whose path was
  -- missing from defaults/Global.lua as long as the row carried a `default`. AceDB builds the store
  -- from the defaults table, not from the rows, so such a row would still read nil.
  local count, out
  withExtraRow({ path = "settings.notInDefaults", default = true, type = "bool", group = "Capture",
      label = "x", widget = "CheckBox" }, function()
    out = captureChat(function() count = S:Register() end)
  end)
  assertEqual(count, 1)
  assertEqual(#out, 1, table.concat(out, " | "))
  assertTrue(out[1]:find("settings.notInDefaults", 1, true) ~= nil, out[1])
  assertTrue(out[1]:find("does not resolve against the defaults", 1, true) ~= nil, out[1])
  assertEqual(S:Register(), 0, "the live schema is clean again")
end)

test("Schema:Register reports a second row declaring a path already taken, and FindRow keeps the first", function()
  local first = S:FindRow(PATH)
  local count, out
  withExtraRow({ path = PATH, default = 0, type = "number", group = "Capture", label = "dup",
      widget = "Dropdown" }, function()
    out = captureChat(function() count = S:Register() end)
    assertTrue(S:FindRow(PATH) == first, "a later duplicate took the path over")
  end)
  assertEqual(count, 1)
  assertTrue(out[1]:find("duplicate", 1, true) ~= nil or out[1]:find("already", 1, true) ~= nil, out[1])
end)

test("Options: the page Defaults act skips the Minimap button row and logs one [Set] line", function()
  -- O.RestoreDefaults is not reached from anything this addon draws today (settings/OptionsSetup.lua
  -- says why), but its descriptor field is the one the library would call. Before the adoption it
  -- wrote S:Set(path, S:Default(path)) with no bracket, so it would have swept the Minimap row
  -- back to shown, which launcher-§3 forbids.
  local O = NS.Helpers
  assertTrue(type(O.RestoreDefaults) == "function", "precondition: the live Options instance")
  S:Set(S.MINIMAP_PATH, false)
  S:Set(PATH, 4)
  local lines = {}
  local savedDebug, savedFlag = NS.Debug, NS.State.debug
  NS.Debug = function(tag, fmt, ...)
    if tag == "Set" then lines[#lines + 1] = ("[%s] " .. fmt):format(tag, ...) end
  end
  NS.State.debug = true
  local ok, err = pcall(O.RestoreDefaults, "general")
  NS.Debug, NS.State.debug = savedDebug, savedFlag
  local minimap = S:Get(S.MINIMAP_PATH)
  S:Set(S.MINIMAP_PATH, true)
  assertTrue(ok, tostring(err))
  assertEqual(minimap, false, "the sweep reset the exempt Minimap row")
  assertEqual(S:Get(PATH), 0, "the rest of the page was reset")
  assertEqual(#lines, 1, table.concat(lines, " | "))
  assertEqual(lines[1], "[Set] reset general: 1 rows")
end)
