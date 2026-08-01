local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = NS.Schema

test("Schema: every row's path resolves against the defaults table", function()
  -- The boot validator returns the number of unresolved paths; a typo in a path would otherwise
  -- read nil forever, silently.
  assertEqual(S:Register(), 0)
end)

test("Schema: every row declares a label, a widget and a group", function()
  for _, row in ipairs(S.Schema) do
    assertTrue(row.label ~= nil and row.label ~= "", row.path .. " has no label")
    assertTrue(row.widget ~= nil, row.path .. " has no widget")
    assertTrue(row.group ~= nil, row.path .. " has no group")
  end
end)

-- ── Propagation ────────────────────────────────────────────────────────────────

local function rowFor(path)
  for _, row in ipairs(S.Schema) do
    if row.path == path then return row end
  end
  return nil
end

-- Run `fn` and return the SettingsChanged reasons broadcast while it ran.
local function reasonsFrom(fn)
  local seen = {}
  local target = NS.NewBusTarget()
  target:RegisterMessage("Ka0s_BankLedger_SettingsChanged", function(_, reason)
    seen[#seen + 1] = reason
  end)
  local ok, err = pcall(fn)
  target:UnregisterMessage("Ka0s_BankLedger_SettingsChanged")
  if not ok then error(err, 0) end
  return seen
end

test("Schema: changing the window scale broadcasts it so every window rescales", function()
  -- F-003: the row called Browser:SetScale directly and sent nothing, so SessionWindow — which
  -- already subscribes and already reads windowScale — never heard about it until a /reload.
  local reasons = reasonsFrom(function() rowFor("settings.windowScale").onChange(1.25) end)
  local found = false
  for _, r in ipairs(reasons) do if r == "windowScale" then found = true end end
  assertTrue(found, "windowScale must reach the bus, not just the Browser")
end)

test("Schema: every row declares a default", function()
  for _, row in ipairs(S.Schema) do
    assertTrue(row.default ~= nil, row.path .. " has no default")
  end
end)

test("Schema: dropdown rows carry their option list", function()
  for _, row in ipairs(S.Schema) do
    if row.widget == "Dropdown" or row.widget == "MultiCheck" then
      assertTrue(type(row.values) == "table" and #row.values > 0,
        row.path .. " has no options")
    end
  end
end)

test("Schema:FindRow finds a declared path and rejects an unknown one", function()
  assertTrue(S:FindRow("settings.enabled") ~= nil)
  assertEqual(S:FindRow("settings.nonesuch"), nil)
end)

test("Schema:Get reads the stored value", function()
  NS.db.global.settings.qualityThreshold = 3
  assertEqual(S:Get("settings.qualityThreshold"), 3)
  S:Set("settings.qualityThreshold", S:Default("settings.qualityThreshold"))
end)

test("Schema:Set writes through the single seam and reads back", function()
  S:Set("settings.qualityThreshold", 4)
  assertEqual(S:Get("settings.qualityThreshold"), 4)
  S:Set("settings.qualityThreshold", 0)
end)

test("Schema:Set rejects an unknown path with a reason", function()
  local ok, err = S:Set("settings.nonesuch", 1)
  assertFalse(ok)
  assertTrue(err:find("unknown path", 1, true) ~= nil)
end)

test("Schema:Set writes a nested path, creating intermediate tables", function()
  S:Set("settings.windowScale", 1.25)
  assertEqual(NS.db.global.settings.windowScale, 1.25)
  S:Set("settings.windowScale", 1.0)
end)

test("Schema:Set fires the row's onChange", function()
  local row = S:FindRow("settings.enabled")
  local saved = row.onChange
  local fired = 0
  row.onChange = function() fired = fired + 1 end
  S:Set("settings.enabled", false)
  S:Set("settings.enabled", true)
  row.onChange = saved
  assertEqual(fired, 2)
end)

test("Schema:Set deep-copies a table value so the default can't be aliased", function()
  -- Without the copy, resetting to the default would alias db.global to the SHARED default table,
  -- and any later in-place mutation would poison the default for the rest of the session.
  local def = S:Default("settings.excludedStores")
  S:Set("settings.excludedStores", def)
  NS.db.global.settings.excludedStores.BANK = true
  assertEqual(S:Default("settings.excludedStores").BANK, nil, "the default is untouched")
  S:Set("settings.excludedStores", {})
end)

test("Schema:Default returns a fresh copy each time", function()
  local a, b = S:Default("settings.excludedStores"), S:Default("settings.excludedStores")
  assertTrue(a ~= b, "two separate tables")
end)

test("Schema: a session-only row never touches SavedVariables", function()
  -- state.debugConsole is the debug console WINDOW's visibility, held in the window, not the DB.
  S:Set("state.debugConsole", true)
  assertEqual(NS.db.global.state, nil, "nothing was written under db.global")
  S:Set("state.debugConsole", false)
end)

test("Schema: the session-only row reads through its own getter", function()
  S:Set("state.debugConsole", true)
  assertEqual(S:Get("state.debugConsole"), NS.DebugLog:IsShown())
  S:Set("state.debugConsole", false)
end)

test("Schema: the debug LOGGING flag is deliberately not a schema row", function()
  -- It is session-only and set through /bl debug on|off, never persisted (debug-logging-§5).
  assertEqual(S:FindRow("state.debug"), nil)
end)

-- ── COMMANDS ───────────────────────────────────────────────────────────────────

-- The entries are POSITIONAL triples — { name, description, handler } — because that is the shape
-- LibKa0s-Slash-1.0 reads (entry[1]/entry[2]/entry[3]). They were keyed until the adoption, and the
-- flip moved every consumer at once: dispatch, the chat help index and the settings landing page.
test("COMMANDS: every entry is a { name, description, handler } triple", function()
  for i, cmd in ipairs(NS.COMMANDS) do
    assertTrue(type(cmd[1]) == "string" and cmd[1] ~= "", "entry " .. i .. " has no name")
    assertTrue(type(cmd[2]) == "string" and cmd[2] ~= "", cmd[1] .. " has no description")
    assertEqual(type(cmd[3]), "function", cmd[1] .. " has no handler")
    -- The keyed shape must not linger alongside the positional one: two truths about one entry is
    -- how a consumer keeps reading the stale half.
    assertTrue(cmd.name == nil and cmd.desc == nil and cmd.fn == nil,
      cmd[1] .. " still carries the old keyed fields")
  end
end)

test("COMMANDS: names are unique, so dispatch can never be ambiguous", function()
  local seen = {}
  for _, cmd in ipairs(NS.COMMANDS) do
    assertFalse(seen[cmd[1]], "duplicate command: " .. cmd[1])
    seen[cmd[1]] = true
  end
end)

test("COMMANDS: the standard's required verbs are all present", function()
  local names = {}
  for _, cmd in ipairs(NS.COMMANDS) do names[cmd[1]] = true end
  for _, required in ipairs({ "get", "set", "list", "reset", "resetall",
                              "config", "version", "debug", "help" }) do
    assertTrue(names[required], "missing the '" .. required .. "' verb")
  end
end)

test("COMMANDS: a test verb exists (test-mode)", function()
  local names = {}
  for _, cmd in ipairs(NS.COMMANDS) do names[cmd[1]] = true end
  assertTrue(names.test)
end)

test("Schema: the four Master Controls switches pair into two full rows", function()
  -- The panel pairs consecutive non-wide rows two to a line (settings/Panel.lua renderRows), so
  -- this order plus the absence of any row-breaking flag is what produces the intended 2x2:
  --   Enable capture   Hide minimap button
  --   Session window   Debug console
  -- A stray soloRow/wide on any of the four would push the rest down into a ragged single column.
  local want = { "settings.enabled", "minimap.hide",
                 "settings.showSessionWindow", "state.debugConsole" }
  local i = 1
  for _, row in ipairs(S.Schema) do
    if row.group == "Master Controls" and row.widget == "CheckBox" then
      assertEqual(row.path, want[i], "Master Controls checkbox #" .. i .. " is out of order")
      assertFalse(row.soloRow == true, row.path .. " breaks the two-column pairing")
      assertFalse(row.wide == true, row.path .. " breaks the two-column pairing")
      i = i + 1
    end
  end
  assertEqual(i - 1, #want, "expected exactly four Master Controls checkboxes")
end)

test("Schema: every row carries a tooltip", function()
  -- The panel renders one per row; a missing one is an empty hover with no explanation, and the
  -- inverted per-store grid is exactly the row that most needed the sentence (F-019).
  for _, row in ipairs(S.Schema) do
    assertTrue((row.tooltip or "") ~= "", row.path .. " has no tooltip")
  end
end)

-- ── LibKa0s-Options-1.0 row vocabulary ─────────────────────────────────────────
--
-- The flow engine reads a fixed set of row field names. Three of them are easy to get wrong in a
-- way nothing reports: a missing `step` silently snaps a slider to its endpoints, an unrenderable
-- type silently drops a row from the page, and the old `soloRow` / `panelSkip` spellings are simply
-- never read.

test("Schema: settings.windowScale declares its own step", function()
  -- The library's makeSlider defaults `row.step or 1`. With min 0.6 and max 1.6 that is a slider
  -- with exactly two positions, and nothing raises.
  local row = NS.Schema:FindRow("settings.windowScale")
  assertEqual(row.step, 0.05, "an undeclared step becomes 1 and collapses the slider")
  assertTrue(row.min < row.max)
end)

test("Schema: a row the library cannot draw is marked skipRender, not left to vanish", function()
  -- RenderField dispatches on bool/number/string/color and returns nil for anything else — one row
  -- silently missing from the page, never an error. `skipRender` makes the host-drawn intent
  -- explicit and keeps the row visible to the CLI and to every reset.
  local RENDERABLE = { bool = true, number = true, string = true, color = true }
  for _, row in ipairs(NS.Schema.Schema) do
    if not RENDERABLE[row.type] then
      assertTrue(row.skipRender == true,
        row.path .. " is type '" .. tostring(row.type) .. "', which no library maker draws — it "
        .. "must declare skipRender = true or it will silently disappear from its page")
    end
  end
end)

test("Schema: no row uses the pre-library field spellings", function()
  -- soloRow -> solo, panelSkip -> skipRender. Both old names are simply never read by the library,
  -- so a row carrying one lays out wrong with nothing to notice it.
  for _, row in ipairs(NS.Schema.Schema) do
    assertTrue(row.soloRow == nil, row.path .. " uses soloRow; the library reads solo")
    assertTrue(row.panelSkip == nil, row.path .. " uses panelSkip; the library reads skipRender")
  end
end)

test("Schema: a numeric row carrying values is an enum the panel must draw as a dropdown", function()
  -- LibKa0s-Options-1.0 minor 5 infers this from `values`. Before it, both of these rendered as
  -- 0-to-1 sliders because neither declares min/max/step.
  for _, path in ipairs({ "settings.qualityThreshold", "settings.retentionDays" }) do
    local row = NS.Schema:FindRow(path)
    assertEqual(row.type, "number", path)
    assertTrue(type(row.values) == "table" and #row.values > 0, path .. " has no values list")
    assertTrue(row.min == nil and row.max == nil,
      path .. " is an enum; declaring min/max would make it look like a range")
  end
end)
