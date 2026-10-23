-- tests/test_sim_panel.lua — the simulator's step panel, Bank Ledger's half (BL-12, BankLedger#24;
-- LibKa0s#53 #54, host contract H7 and H10, OWNER_SCOPE C.5, C.7, C.11).
--
-- The panel is LibKa0s-Sim-1.0's: its rows, states, controls, picker, click-ahead, stale-click
-- guard and placement are pinned by the library's own suites. Bank Ledger passes only the
-- presentation fields (modules/Sim.lua's NS.SimHost.PANEL): the title, each step's label and
-- tooltip, the Start and Stop tooltips, the ledger window to dock beside and the done tick. These
-- cases read the rows through the published NS.Sim:PanelRows() and assert what is Bank Ledger's,
-- plus the host obligations: the panel opens with a start, docks beside the ledger window, keeps a
-- dragged position for the session only (NS.db untouched), and goes away on a stand-down stop.
--
-- The one reach past the public surface is the click: a row is clicked by firing OnClick on the
-- library's headless test record of row buttons (the panel frame's `__rowButtons`, by row index),
-- because no public member clicks a row. Its STATE is never read from there.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = dofile("tests/sim_support.lua")
local L = NS.L
local Host = NS.SimHost
local ENABLED_PATH = "settings.enabled"

local function field(rows, key)
  local out = {}
  for i, row in ipairs(rows) do out[i] = tostring(row[key]) end
  return table.concat(out, "|")
end

local function panelFrame() return mocks.BankLedgerSimPanel end

-- ── the presentation fields ──────────────────────────────────────────────────────────────────

test("sim panel: the descriptor carries Bank Ledger's presentation fields, and no store", function()
  local P = Host.PANEL
  assertEqual(P.title, NS.BRAND_NAME .. " - Simulation")
  assertEqual(P.check, NS.Icon("confirm"), "the done tick is the declared confirm icon")
  assertEqual(P.store, nil, "a panel store: the position must be session-only (C.11)")
  for _, key in ipairs({ "stepLabel", "stepTip", "anchorTo" }) do
    assertEqual(type(P[key]), "function", key)
  end
  assertTrue(type(P.startTip) == "table" and #P.startTip > 0, "no Start tooltip")
  assertTrue(type(P.stopTip) == "table" and #P.stopTip > 0, "no Stop tooltip")
end)

test("sim panel: idle, the rows are Start, one per step and Stop, each beside its typed command", function()
  -- The picker follows the last session's scenario, so a bank session first puts it on bank.
  S.withSession("bank", function() end)
  local rows = NS.Sim:PanelRows()
  assertEqual(#rows, 7, "Start, the bank scenario's five steps, Stop")
  assertEqual(field(rows, "key"), "start|step|step|step|step|step|stop")
  assertEqual(rows[1].command, "/bl sim start bank")
  for i = 2, 6 do assertEqual(rows[i].command, "/bl sim step") end
  assertEqual(rows[7].command, "/bl sim stop")
  assertEqual(rows[1].label, "Start: " .. L["Personal bank"])
  -- No world yet: an item move names the scenario's letter.
  assertEqual(rows[3].label, "Deposit 20 × item A to Character Bank")
  assertEqual(rows[2].label, L["Open the bank"])
  assertEqual(field(rows, "state"), "ready|locked|locked|locked|locked|locked|locked")
end)

test("sim panel: running, a move names the REAL item, and the rows take the running states", function()
  S.withSession("warband", function(sim)
    local rows = sim:PanelRows()
    assertEqual(rows[3].label, "Deposit 20 × Linen Cloth to Warband Bank",
      "the warband deposit names the pool's first real item")
    assertEqual(rows[1].state, "done", "Start is done once the world is ready")
    assertEqual(rows[2].state, "ready", "the first step is next")
    assertEqual(rows[3].state, "locked")
    assertEqual(rows[#rows].state, "cancel", "Stop cancels a running session")
    S.chat(function() sim:Step() end)
    S.drain()
    rows = sim:PanelRows()
    assertEqual(rows[2].state, "done")
    assertEqual(rows[3].state, "ready")
  end)
end)

test("sim panel: a step's tooltip says what it moves, the lagged half, and the events it fires", function()
  S.withSession("warband", function(sim)
    local tip = sim:PanelRows()[3].tip
    local text = {}
    for _, line in ipairs(tip) do text[#text + 1] = line[1] .. ": " .. line[2] end
    text = table.concat(text, " | ")
    assertTrue(text:find("Injects: Moves 20 × Linen Cloth from the bags to the Warband Bank; "
      .. "the warband half lands 1.5 s later", 1, true) ~= nil, text)
    assertTrue(text:find("Fires: BAG_UPDATE, BAG_UPDATE_DELAYED, BAG_UPDATE, BAG_UPDATE_DELAYED", 1, true) ~= nil,
      text)
    assertTrue(text:find("Through: " .. L["the real capture engine"], 1, true) ~= nil, text)
  end)
end)

test("sim panel: a played move's label and tooltip count the rows the engine recorded", function()
  S.withSession("bank", function(sim)
    S.chat(function() sim:Step() end)   -- open
    S.drain()
    S.chat(function() sim:Step() end)   -- deposit 20 of the first pool item
    S.drain()
    local row = sim:PanelRows()[3]
    assertTrue(row.label:find("(1 recorded)", 1, true) ~= nil, row.label)
    local recorded
    for _, line in ipairs(row.tip) do if line[1] == L["Recorded"] then recorded = line[2] end end
    assertEqual(recorded, "1")
  end)
end)

-- ── opening, repainting and clicking ─────────────────────────────────────────────────────────

test("sim panel: a start opens it beside the ledger window, which the start also opens", function()
  NS.Sim:HidePanel()
  S.withSession("bank", function(sim)
    assertTrue(sim:IsPanelShown(), "the start did not open the panel")
    local win = NS.Browser:GetWindow()
    assertTrue(win:IsShown(), "the start did not open the ledger window")
    local point, rel, relPoint, x, y = panelFrame():GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOPLEFT>TOPRIGHT", "not docked right of the ledger window")
    assertTrue(rel == win, "docked to something other than the ledger window")
    assertEqual(x .. "," .. y, "8,0")
  end)
  NS.Sim:HidePanel()
end)

test("sim panel: with the ledger window shut it floats rather than docking beside a hidden frame", function()
  NS.Browser:Hide()
  assertEqual(Host.PanelAnchor(), nil)
  NS.Browser:Show()
  assertTrue(Host.PanelAnchor() == NS.Browser:GetWindow())
  NS.Browser:Hide()
end)

test("sim panel: a typed step repaints the shown panel", function()
  S.withSession("bank", function(sim)
    assertTrue(sim:IsPanelShown(), "the premise: the panel is up")
    local real, asked = Host.StepLabel, 0
    Host.StepLabel = function(...) asked = asked + 1 return real(...) end
    local ok, err = pcall(S.chat, function() NS.Slash:OnSlash("sim step") end)
    Host.StepLabel = real
    if not ok then error(err, 0) end
    -- The step line asks once; the repaint asks again for every step row.
    assertTrue(asked > #sim:Steps(), "the panel's rows were not composed again: " .. asked)
  end)
end)

test("sim panel: clicking a done row does nothing; clicking the next row plays it", function()
  S.withSession("bank", function(sim)
    S.chat(function() sim:Step() end)
    S.drain()
    local buttons = panelFrame().__rowButtons
    local before, events = sim:Status().pos, sim:Status().events
    local out = S.chat(function() buttons[2]:__fire("OnClick") end)   -- the played Open row
    assertEqual(#out, 0, "a done row printed: " .. table.concat(out, " || "))
    assertEqual(sim:Status().pos, before, "a done row advanced the session")
    assertEqual(sim:Status().events, events, "a done row fired an event")
    out = S.chat(function() buttons[3]:__fire("OnClick") end)          -- the ready row
    assertEqual(sim:Status().pos, before + 1, "the ready row did not play")
    assertTrue(S.has(out, "Simulation step 2 of 5: "), table.concat(out, " || "))
  end)
end)

-- ── auto-play: a typed start plays on its own (LibKa0s v1.76.0, Sim 2.3.5; OWNER_SCOPE A.1) ─────
--
-- The member sim:Start{} plays nothing (sim_support's withSession), but the typed `/bl sim start`
-- arms the run: it plays every step on its own, the descriptor's stepDelay apart, and the gate
-- still holds a step until the ledger settles. These cases start through the typed verb inside the
-- quiet world (withSession with no scenario) and run the clock with sim_support's advance.

--- Type `/bl sim start <scenario>` inside the quiet world and run fn(sim) on the started session.
local function typedSession(scenario, fn)
  S.withSession(nil, function(sim)
    S.chat(function() NS.Slash:OnSlash("sim start " .. scenario) end)
    assertTrue(sim:IsActive(), "the typed start did not start a session")
    fn(sim)
  end)
end

test("sim: a typed /bl sim start bank plays on its own", function()
  typedSession("bank", function(sim)
    local st = sim:Status()
    assertTrue(st.playing, "a typed start did not arm the run")
    local steps = sim:Steps()
    local at, last = {}, 0
    local met = S.advance(120, function()
      local now = sim:Status()
      if now.pos > last then
        for p = last + 1, now.pos do at[p] = mocks.__now end
        last = now.pos
      end
      return now.total > 0 and now.pos == now.total and not now.playing
    end)
    assertTrue(met, ("the run stopped at step %d of %d with no verb typed"):format(last, #steps))
    for p = 2, #steps do
      local gap, want = at[p] - at[p - 1], Host.DelayAfter(steps[p - 1])
      assertTrue(gap >= want, ("step %d played %.2f s after step %d, under the %.2f s delay")
        :format(p, gap, p - 1, want))
    end
    assertEqual(Host.DelayAfter({}), 1, "the default step delay is 1 s")
  end)
end)

test("sim panel: the controls are Pause, Restart and Stop", function()
  typedSession("bank", function(sim)
    assertTrue(sim:IsPanelShown(), "the typed start did not open the panel")
    local c = panelFrame().controls
    assertTrue(c ~= nil, "the panel has no controls bar")
    assertEqual(c.run, nil, "the run-all control is still there")
    assertTrue(c.restart ~= nil and c.stop ~= nil, "Restart or Stop is missing")
    assertTrue(c.pause:IsEnabled(), "Pause is disabled while the run plays")
    assertEqual(c.pause.label:GetText(), "Pause")
    sim:Pause()
  end)
end)

test("sim panel: clicking the ready row while it plays pauses and plays one step", function()
  typedSession("bank", function(sim)
    assertTrue(S.advance(30, function() return sim:Status().pos >= 1 end), "the first step never played")
    local st = sim:Status()
    assertTrue(st.playing and st.pos < st.total, "the premise: the run plays with steps left")
    local before = st.pos
    S.chat(function() panelFrame().__rowButtons[before + 2]:__fire("OnClick") end)   -- the ready row
    S.drain()
    st = sim:Status()
    assertEqual(st.pos, before + 1, "the click did not play exactly one step")
    assertTrue(st.paused, "the click did not hold the run")
    assertFalse(st.playing, "the run kept playing after the click")
  end)
end)

-- ── the session-only position (C.11, H10) ────────────────────────────────────────────────────

test("sim panel: a drag moves it for the session and writes NOTHING to NS.db; Reset redocks", function()
  S.withSession("bank", function(sim)
    local f = panelFrame()
    local before = S.copy(NS.db.sv)
    f:ClearAllPoints()
    f:SetPoint("CENTER", mocks.UIParent, "CENTER", 11, 22)
    f:__fire("OnDragStop")
    sim:HidePanel()
    sim:ShowPanel()
    local point, _, relPoint, x, y = f:GetPoint(1)
    assertEqual(("%s>%s %s,%s"):format(point, relPoint, x, y), "CENTER>CENTER 11,22",
      "the dragged point did not hold for the session")
    assertTrue(S.deepEqual(before, NS.db.sv), "a drag wrote to the saved variables")
    sim:ResetPanelPosition()
    local p2, rel2, rp2 = f:GetPoint(1)
    assertEqual(p2 .. ">" .. rp2, "TOPLEFT>TOPRIGHT", "Reset did not redock it")
    assertTrue(rel2 == NS.Browser:GetWindow(), "Reset docked it to something other than the ledger window")
    assertTrue(S.deepEqual(before, NS.db.sv), "Reset wrote to the saved variables")
  end)
  NS.Sim:HidePanel()
end)

test("sim panel: no schema row and no default hold its position", function()
  for _, path in ipairs({ "settings/Schema.lua", "core/Database.lua" }) do
    local fh = assert(io.open(path, "r"))
    local src = fh:read("*a")
    fh:close()
    assertFalse(src:find("simPanel", 1, true) ~= nil, path .. " names simPanel")
  end
end)

-- ── the stand-down ───────────────────────────────────────────────────────────────────────────

test("sim panel: a stand-down stop hides it", function()
  S.withSession("bank", function(sim)
    assertTrue(sim:IsPanelShown(), "the premise: the panel is up")
    local ok, err = pcall(S.chat, function() NS.Schema:Set(ENABLED_PATH, false) end)
    local shown = sim:IsPanelShown()
    S.chat(function() NS.Schema:Set(ENABLED_PATH, true) end)
    if not ok then error(err, 0) end
    assertFalse(sim:IsActive(), "the stand-down did not stop the simulation")
    assertFalse(shown, "the panel outlived the stand-down stop")
  end)
end)
