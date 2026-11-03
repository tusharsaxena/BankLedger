-- tests/test_sim_checkbox.lua — the Sim mode checkbox on Master controls (R6-SIM, LibKa0s OptionsCompose minor 19).
--
-- The owner, 2026-11-04: "Add a sim checkbox in settings (next to test) for all Ka0s addons that
-- support it." The composer draws the row from the host's isSimMode / toggleSim pair, and this
-- addon hands it NS.IsSimMode and NS.ToggleSim, the SAME two functions its launcher descriptor
-- carries, so the box, the launcher's Sim mode entry and `/bl sim` are one act. The sim's listener
-- repaints the page, so a sim started or ended elsewhere shows on the box at once.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = dofile("tests/sim_support.lua")
local SIM_PATH = "state.sim"

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local body = fh:read("*a")
  fh:close()
  return body
end

local function findRow(path)
  for i, row in ipairs(NS.Schema.Schema) do
    if row.path == path then return row, i end
  end
end

--- Run fn with NS.Sim:RunVerb spied: answers the verb lines it was handed, in order. The real verb
--- still runs, so the act is the slash verb's own.
local function withVerbSpy(fn)
  local sim = NS.Sim
  local real, seen = sim.RunVerb, {}
  sim.RunVerb = function(self, line, ...)
    seen[#seen + 1] = line
    return real(self, line, ...)
  end
  local ok, err = pcall(fn, seen)
  sim.RunVerb = real
  if not ok then error(err, 0) end
  return seen
end

test("Sim mode: the composed row opens the line below Minimap button and Test mode, session-only", function()
  -- Emitted by the composer from the host's isSimMode / toggleSim (compose minor 19), never
  -- hand-written. Test mode sits in the second column beside Minimap button, so Sim mode opens the
  -- next line, straight after it.
  -- Dies under: dropping isSimMode or toggleSim from the spec S:ComposeMaster hands the composer.
  local row, idx = findRow(SIM_PATH)
  assertTrue(row ~= nil, "no state.sim row was composed")
  local _, testIdx = findRow("state.testMode")
  assertEqual(idx, testIdx + 1, "Sim mode must follow Test mode")
  assertEqual(row.label, "Sim mode")
  assertEqual(row.type, "bool")
  assertEqual(row.widget, "CheckBox")
  assertEqual(row.group, "Master controls")
  assertTrue(row.sessionOnly == true, "the sim is session state, never a stored setting")
  assertEqual(row.default, false)
  assertTrue(row.startsLine == true, "Test mode is in the second column, so Sim mode opens a line")
  assertTrue(type(row.get) == "function" and type(row.set) == "function", "the composer binds get/set")
  local canonical = "Run the addon's simulation, the same as its sim slash command"
  assertEqual(row.tooltip:sub(1, #canonical), canonical, "the composed words must lead: " .. row.tooltip)
  assertTrue(row.tooltip:find("/bl sim", 1, true) ~= nil, "the note names the verb: " .. row.tooltip)
  assertEqual((NS.Schema.MASTER_DECOR[SIM_PATH] or {}).get, nil, "the decor must not replace the composer's get")
  assertEqual((NS.Schema.MASTER_DECOR[SIM_PATH] or {}).set, nil, "the decor must not replace the composer's set")
end)

test("Sim mode: the box and the launcher carry the same pair, NS.IsSimMode and NS.ToggleSim", function()
  -- One pair, hoisted, rather than a copy inlined in each descriptor (releasing.md, R6-SIM-L's
  -- hosts-owe item 1).
  -- Dies under: the launcher's pair built inline again, or the Master spec passing other functions.
  assertTrue(type(NS.IsSimMode) == "function" and type(NS.ToggleSim) == "function", "no NS pair")
  local launcher = read("core/LauncherSetup.lua")
  assertTrue(launcher:find("isSimMode%s*=%s*NS%.IsSimMode") ~= nil, "the launcher does not pass NS.IsSimMode")
  assertTrue(launcher:find("toggleSim%s*=%s*NS%.ToggleSim") ~= nil, "the launcher does not pass NS.ToggleSim")
  local schema = read("settings/Schema.lua")
  assertTrue(schema:find("spec%.isSimMode%s*,%s*spec%.toggleSim%s*=%s*NS%.IsSimMode%s*,%s*NS%.ToggleSim") ~= nil,
    "the Master controls spec does not pass the same pair")
end)

test("Sim mode: ticking with no sim running runs the bare /bl sim verb, and the box reads the live state", function()
  -- The bare verb prints the status and the verbs and opens the sim panel, the act the launcher's
  -- Sim mode entry has always taken; it starts no scenario by itself, so the box reads unticked
  -- until one starts.
  S.withSession(nil, function(sim)
    assertFalse(NS.Schema:Get(SIM_PATH), "the box is ticked with no sim running")
    local seen = withVerbSpy(function()
      S.chat(function() NS.Schema:Set(SIM_PATH, true) end)
    end)
    assertEqual(#seen, 1, "ticking must run the verb once")
    assertEqual(seen[1], "", "ticking must run the bare verb, as /bl sim does")
    assertTrue(sim:IsPanelShown(), "the bare verb opens the sim panel")
    assertFalse(NS.Schema:Get(SIM_PATH), "no scenario started, so the box reads unticked")
    sim:HidePanel()
  end)
end)

test("Sim mode: the box reads a running sim, and unticking it stops the sim through /bl sim stop", function()
  S.withSession("bank", function(sim)
    assertTrue(NS.Schema:Get(SIM_PATH), "a running sim must read ticked")
    -- Ticking a box that already reads ticked is no act at all.
    local again = withVerbSpy(function()
      S.chat(function() NS.Schema:Set(SIM_PATH, true) end)
    end)
    assertEqual(#again, 0, "a tick over a running sim must not toggle it")
    assertTrue(sim:IsActive(), "the sim stopped on a tick")
    local seen = withVerbSpy(function()
      S.chat(function() NS.Schema:Set(SIM_PATH, false) end)
    end)
    assertEqual(seen[1], "stop", "unticking must run /bl sim stop")
    assertFalse(sim:IsActive(), "unticking did not stop the sim")
    assertFalse(NS.Schema:Get(SIM_PATH), "the box still reads ticked after the stop")
  end)
end)

test("Sim mode: a sim started or ended from elsewhere repaints the settings page", function()
  -- The sim's listener signals the library's refresh (O.RefreshScalars, through NS.Panel:Refresh),
  -- so an open page shows a sim started from the slash verb, the panel or the launcher, and one
  -- that stops itself, at once.
  -- Dies under: dropping the panel refresh from modules/Sim.lua's listener.
  local O = NS.Helpers
  local real, calls = O.RefreshScalars, 0
  O.RefreshScalars = function(...) calls = calls + 1; return real(...) end
  local ok, err = pcall(function()
    local atStart, atStop
    S.withSession(nil, function(sim)
      local before = calls
      S.chat(function() assert(sim:Start{ scenario = "bank" }, "the sim did not start") end)
      atStart = calls - before
      before = calls
      S.chat(function() sim:Stop("stop") end)
      atStop = calls - before
    end)
    assertTrue(atStart > 0, "starting the sim did not refresh the settings page")
    assertTrue(atStop > 0, "stopping the sim did not refresh the settings page")
  end)
  O.RefreshScalars = real
  if not ok then error(err, 0) end
end)

test("Sim mode: Reset all settings leaves a running sim running and its box ticked (OWNER_SCOPE C.13)", function()
  -- This addon's reset is Sl:ResetEverything, one db:ResetProfile(), and the owner's C.13 keeps a
  -- simulation running through it: it touches no state the session reads. The box says so.
  S.withSession("bank", function(sim)
    S.chat(function() NS.Slash:ResetEverything() end)
    assertTrue(sim:IsActive(), "the reset ended the simulation")
    assertTrue(NS.Schema:Get(SIM_PATH), "the box reads unticked over a running sim")
  end)
end)
