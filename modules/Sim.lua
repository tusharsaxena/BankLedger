local addonName, NS = ...
-- modules/Sim.lua — the simulator's session host, on LibKa0s-Sim-1.0 (BankLedger#24, LibKa0s#54;
-- req-bl-sim §5-§6, OWNER_SCOPE C.1, C.3, C.4, C.11, C.13). Binds NS.SimSeam (core/SimSetup.lua)
-- to one session with Sim:New and publishes it as NS.Sim. Everything that is Bank Ledger's own lives
-- on NS.SimHost, never on the library's instance (C.4).
--
-- ── THE PRINCIPLE ────────────────────────────────────────────────────────────────────────────
--
-- A simulation runs the REAL capture engine against an invented world. The seam's providers
-- (modules/SimWorld.lua) answer every client read; the drivers (modules/SimDrivers.lua) edit that
-- world and fire the client's events through NS.Sim:Fire, which this descriptor hands to
-- L:Dispatch, the one entry every capture signal takes (modules/Ledger.lua). The engine decides
-- every row. Nothing here calls Database:Add.
--
-- ── SAVED DATA STAYS UNTOUCHED (H4) ──────────────────────────────────────────────────────────
--
-- The start sets NS.State.simLog = {}: while it is set, Database:Sink() answers it, so every row the
-- engine records lands in the session log and nowhere else, and Database:ActiveLedger() reads it
-- first, so the ledger window shows the simulated rows. The stop puts nil back. Attribution is
-- session-wide rather than per Fire (the reconcile that records a move runs on a timer after Fire
-- returns), which is safe because the refusals below guarantee no real storage frame is open while a
-- simulation runs. The destructive surface, /bl purge, refuses while one runs
-- (Database:PurgeRefused, C.13). A profile reset does NOT end a simulation (C.13): it touches no
-- state the session reads.
--
-- ── WHAT ENDS IT (H6) ────────────────────────────────────────────────────────────────────────
--
--   bank       a REAL bank or guild-bank frame opening or closing: L:Dispatch stops the session
--              BEFORE the real handler, so the real open snapshots the real world;
--   combat     addon:OnCombatChanged on PLAYER_REGEN_DISABLED (core/BankLedger.lua);
--   standDown  the first step of NS.StandDown (core/BankLedger.lua);
--   /reload    trivially: nothing is saved.
-- Real BAG_UPDATE_DELAYED, PLAYER_MONEY and GUILDBANKBAGSLOTS_CHANGED do NOT stop it: with a
-- simulated frame open they only cue a re-diff of the simulated world.
--
-- ── THE STOP ─────────────────────────────────────────────────────────────────────────────────
--
-- The library's two-phase stop. While the seam still answers (OnStopGuarded), L:DropContext cancels
-- the pending debounce and the settle window and ends the banking session, with NO Reconcile: a
-- final pass with the seam off would diff a simulated baseline against the real world and invent
-- movements. Then, with the seam off (OnStop), the session log and the world are released and the
-- ledger window swaps back to the saved dataset.

NS.SimHost = NS.SimHost or {}
local Host = NS.SimHost
local L = NS.L

-- ── the step delay ───────────────────────────────────────────────────────────────────────────
--
-- The pause after each step before `run` plays the next one. Once a fixed 1.5 s constant
-- (OWNER_SCOPE C.11); since the owner's 2026-10-23 ask it is the `settings.sim.stepDelay` slider,
-- default 1 s, and Host.STEP_DELAY is that DEFAULT (read from defaults/Profile.lua, its one
-- hardcoded copy) -- the fallback Host.StepDelay answers when the stored value is not one the row
-- takes. A step's own `settle` still raises the pause above it.
local C = NS.Constants
Host.STEP_DELAY = NS.defaults.profile.settings.sim.stepDelay

--- Whether v is a step delay the setting takes: a number in [MIN, MAX] on the slider's grid. The
--- schema row's validate is this check, so the slider, `/bl set` and the read agree.
--- @return boolean ok, string|nil why
function Host.ValidStepDelay(v)
  if type(v) ~= "number" or v ~= v or v < C.SIM_STEP_DELAY_MIN or v > C.SIM_STEP_DELAY_MAX then
    return false, ("a number of seconds from %g to %g"):format(C.SIM_STEP_DELAY_MIN, C.SIM_STEP_DELAY_MAX)
  end
  local n = v / C.SIM_STEP_DELAY_STEP
  if n ~= math.floor(n) then
    return false, ("a multiple of %g seconds"):format(C.SIM_STEP_DELAY_STEP)
  end
  return true
end

--- The seconds `run` waits between steps NOW: the stored setting, read at every call so a change
--- lands on the next step, or Host.STEP_DELAY when the stored value is not one the setting takes
--- (SavedVariables is hand-editable).
--- @return number
function Host.StepDelay()
  local st = NS.db and NS.db.profile and NS.db.profile.settings
  local v = type(st) == "table" and type(st.sim) == "table" and st.sim.stepDelay or nil
  if Host.ValidStepDelay(v) then return v end
  return Host.STEP_DELAY
end

--- The descriptor's stepDelay: the pause after `step`, the setting raised to the step's `settle`.
--- @return number
function Host.DelayAfter(step)
  return math.max(Host.StepDelay(), (step and step.settle) or 0)
end

--- The scenarios, filled in place at file load by modules/SimScenario.lua (the library reads them
--- at call time): { names = { ordered }, defs = { [name] = def } }.
Host.SCENARIOS = Host.SCENARIOS or { names = {}, defs = {} }

local function debug(fmt, ...)
  if NS.State.debug and NS.Debug then NS.Debug("Sim", fmt, ...) end
end

-- ── refusals (req-bl-sim §6) ─────────────────────────────────────────────────────────────────

-- Each answers its line or nil, checked in this order; the second value is the guard the [Sim] line
-- names. The library runs the refusal inside NS.SimSeam:Live, so every world read below answers the
-- real client, and it has already refused an unknown scenario and a second session. A real group,
-- an instance and being unguilded are NOT refused: nothing the engine computes reads them, and the
-- guild scenario invents a guild.
local CHECKS = {
  function()
    -- The dispatcher's own line (slash-commands-§7): settings/Slash.lua answers it on both arms.
    if NS.IsStoodDown and NS.IsStoodDown() then return NS.Slash:DisabledLine(), "stood down" end
  end,
  function()
    if NS.State.testRecords ~= nil then
      return L["Turn test mode off before starting a simulation."], "test mode"
    end
  end,
  function()
    if InCombatLockdown and InCombatLockdown() then
      return L["A simulation cannot start in combat."], "combat"
    end
  end,
  -- A real storage frame: its context and the simulated one would share the engine.
  function()
    if NS.State.openContext ~= nil or NS.Compat.IsGuildBankVisible() == true then
      return L["Close the bank first: a simulation cannot run beside a real bank visit."], "real bank open"
    end
  end,
  function()
    local guard = NS.Util.VisibilityRefusal and NS.Util.VisibilityRefusal()
    if guard then
      return L["A simulation cannot start while General visibility keeps the ledger window closed."], guard
    end
  end,
}

--- Why a simulation may not start now, as the one line to print, or nil when it may.
function Host.Refusal(opts)
  for i = 1, #CHECKS do
    local line, guard = CHECKS[i](opts or {})
    if line then
      debug("start refused: %s", tostring(guard))
      return line
    end
  end
  return nil
end

-- ── the start and the steps ──────────────────────────────────────────────────────────────────

local function datasetChanged()
  local B = NS.Browser
  if B and B.OnDatasetChanged then B:OnDatasetChanged() end
end

--- The descriptor's prepare: the world, the session log, the dataset swap and the ledger window,
--- then ready() once. The seam is already on; the world's own real reads go through Live.
function Host.Prepare(_, _, _, ready)
  Host.world = NS.SimWorld.Build()
  Host.pendingLag = 0
  NS.State.simLog = {}
  datasetChanged()
  if NS.Browser and NS.Browser.Show then NS.Browser:Show() end
  -- The step panel opens beside the ledger window it just opened (Sim-1.0 docks it to anchorTo).
  if NS.Sim and NS.Sim.ShowPanel then NS.Sim:ShowPanel() end
  debug("world built: %d pool items%s", #Host.world.pool,
    Host.world.poolFallback and " (the fixed fallback ids)" or "")
  ready()
end

--- The descriptor's play: one step is one driver call, and the driver's answer is the step's detail.
--- It first stamps `rowsBefore`, the session log's length as the step starts, so Host.Recorded can
--- say what the engine recorded for it (req-bl-sim §7). A host field: the library writes only
--- `ranAt`, `detail` and `index` into a step.
function Host.Play(step)
  local driver = NS.SimDrivers.DRIVERS[step.kind]
  if not driver then error(("no simulator driver for step kind %s"):format(tostring(step.kind)), 0) end
  step.rowsBefore = #(NS.State.simLog or {})
  return driver(step)
end

--- How many rows the engine recorded for a played step: from its `rowsBefore` to the next played
--- step's, or to the session log's length while it is the last one played. A row lands on the
--- reconcile pass after the step's events (the debounce, a lagged half), so the count grows until the
--- next step plays. nil for a step that has not played, or with no session log.
function Host.Recorded(step, steps)
  local log = NS.State.simLog
  if not (log and step and step.rowsBefore) then return nil end
  local upTo = #log
  for i = (step.index or #(steps or {})) + 1, #(steps or {}) do
    local later = steps[i]
    if later.rowsBefore then upTo = later.rowsBefore break end
  end
  return upTo - step.rowsBefore
end

-- ── the gate (design-sim §11, OWNER_SCOPE C.2) ───────────────────────────────────────────────

local WAIT_LINE = L["Waiting for the ledger to settle."]

-- The step the session plays next, or nil.
local function nextStep()
  local sim = NS.Sim
  if not (sim and sim.Steps and sim.Status) then return nil end
  return sim:Steps()[(sim:Status().pos or 0) + 1]
end

--- The descriptor's gate: open (true) when the engine has settled, else false and the line to print.
--- The library asks it before every step: Step, each Run tick and the panel's click-ahead. Closed
--- while any of these holds:
---   a lagged store half has still to land (NS.SimHost.pendingLag > 0, modules/SimDrivers.lua);
---   the engine holds a one-sided baseline (NS.Ledger._settleSince), unless the next step carries
---     `holdOK`, as the onesided scenario's close does;
---   a reconcile pass is pending (NS.Ledger._pendingTimer), the debounce after the step's events.
--- While a hold is live the pending timer is the hold's own deadline re-check, armed for the rest of
--- the settle window, so `holdOK` covers it too: without that a close meant to land on a live hold
--- would wait out the window and find the baseline re-anchored.
function Host.Gate()
  local Ledger = NS.Ledger
  if (Host.pendingLag or 0) > 0 then return false, WAIT_LINE end
  local holding = Ledger._settleSince ~= nil
  local holdOK = false
  if holding then
    local step = nextStep()
    holdOK = step ~= nil and step.holdOK == true
    if not holdOK then return false, WAIT_LINE end
  end
  if Ledger._pendingTimer ~= nil and not holdOK then return false, WAIT_LINE end
  return true
end

-- ── the panel's presentation (Sim-1.0's `d.panel`; host contract H7, H10) ─────────────────────
--
-- The panel itself (its rows, states, controls, picker, click-ahead and placement) is the
-- library's. These fields say only what Bank Ledger's steps are called and what their tooltips say.
-- No `store`: the panel's position is SESSION-ONLY (OWNER_SCOPE C.11), held in the library
-- instance's memory, so a simulation writes nothing to SavedVariables. No schema row, no default.

local Store = NS.Constants.Store
local LETTER = { "A", "C", "D", "E" }   -- modules/SimScenario.lua's item letters, by pool index

-- The idle preview's pool (BL-12): with no world, the step panel names the items from the pool
-- NS.SimWorld.DrawPool draws from the live bags, the SAME pure function a Start's world draws its
-- pool with, so the idle rows read as the running rows will. Redrawn on each panel refresh (the
-- first step row's label or tooltip), so a bag change shows; false when the bags hold too few
-- distinct items, and the rows keep the scenario's letters (the Start then takes the fixed
-- fallback ids). Never consulted while a world exists.
local preview = nil

--- The idle preview pool: redrawn when `refresh` is set or none was drawn yet; nil when the bags
--- hold too few distinct items.
function Host.PreviewPool(refresh)
  if refresh or preview == nil then
    preview = (NS.SimWorld and NS.SimWorld.DrawPool and NS.SimWorld.DrawPool()) or false
  end
  return preview or nil
end

-- A panel refresh composes the rows in order, so its first step row redraws the preview pool.
local function refreshPreview(i)
  if Host.world == nil and i == 1 then Host.PreviewPool(true) end
end

-- The item a step's `item` names: from the world's pool while one exists, else from the idle
-- preview pool; nil when neither exists or the drivers cannot resolve it.
local function resolveStepItem(ref)
  local pool = Host.world == nil and Host.PreviewPool() or nil
  if not (Host.world or pool) then return nil end
  local D = NS.SimDrivers
  local resolve = D and D.ResolveItem
  return resolve and resolve(ref, pool) or nil
end

-- The scenario's letter for an unresolved `item`: B for the bonus item, A/C/D/E by pool index.
local function itemLetter(ref)
  if ref == "bonus" then return "B" end
  return LETTER[tonumber(ref) or 0] or tostring(ref)
end

-- The name a step's `item` names: the real item's (from its link), its id when the link carries
-- no name; the scenario's letter when no pool has the item.
local function itemName(ref)
  local item = resolveStepItem(ref)
  if not item then return L["item %s"]:format(itemLetter(ref)) end
  local name = type(item.link) == "string" and item.link:match("%[(.-)%]")
  if name and name ~= "" then return name end
  return tostring(item.itemID)
end

local function storeLabel(store) return NS.Constants.StoreLabel[store] or tostring(store) end

-- Item moves get a label built from the real item; every other step keeps its scenario label.
local MOVE_LABEL = {
  Deposit  = L["Deposit %d × %s to %s"],
  Withdraw = L["Withdraw %d × %s from %s"],
}

--- A timeline step's name (`d.panel.stepLabel`): 'Deposit 20 × Linen Cloth to Warband Bank', with
--- the rows the engine has recorded for it once it played and recorded any. The library prints the
--- same name in its step line, which runs before the debounced pass records, so the count shows on
--- the panel row and its tooltip as it lands.
function Host.StepLabel(step, i, steps)
  refreshPreview(i)
  local label
  if MOVE_LABEL[step.kind] then
    label = MOVE_LABEL[step.kind]:format(step.n or 0, itemName(step.item), storeLabel(step.store))
  elseif step.kind == "Loot" then
    label = L["Loot %d × %s into the bags"]:format(step.n or 0, itemName(step.item))
  else
    label = step.label or step.kind
  end
  local n = step.ranAt and Host.Recorded(step, steps or NS.Sim:Steps())
  if n and n > 0 then label = L["%s (%d recorded)"]:format(label, n) end
  return label
end

-- The client events a step's driver fires, as one comma list (modules/SimDrivers.lua's D.EVENTS).
local MOVE_EVENTS = {
  [Store.BANK] = { "BankMove" }, [Store.WARBAND_BANK] = { "WarbandBag", "WarbandStore" },
  [Store.GUILD_BANK] = { "GuildMove" },
}
local function eventsOf(step)
  local D = NS.SimDrivers
  local lists = MOVE_EVENTS[step.store] and (step.kind == "Deposit" or step.kind == "Withdraw")
    and MOVE_EVENTS[step.store] or { step.kind == "Spend" and "Money" or step.kind }
  local out = {}
  for _, key in ipairs(lists) do
    for _, row in ipairs((D and D.EVENTS and D.EVENTS[key]) or {}) do out[#out + 1] = row[1] end
  end
  return out
end

-- What a move does to the world, with its lagged warband half.
local function moveLine(step)
  local deposit = step.kind == "Deposit"
  local line = L[deposit and "Moves %d × %s from the bags to the %s" or "Moves %d × %s from the %s to the bags"]
    :format(step.n or 0, itemName(step.item), storeLabel(step.store))
  if step.lag == "never" then
    line = line .. L["; the warband half never lands"]
  elseif type(step.lag) == "number" then
    line = line .. L["; the warband half lands %s s later"]:format(tostring(step.lag))
  end
  return line
end

--- A timeline step's tooltip (`d.panel.stepTip`), { left, right } lines: what the step injects, the
--- events it fires, and once it played what the driver did and how many rows the engine recorded.
function Host.StepTip(step, i)
  refreshPreview(i)
  local lines = {}
  if MOVE_LABEL[step.kind] then lines[#lines + 1] = { L["Injects"], moveLine(step) } end
  local events = eventsOf(step)
  if #events > 0 then lines[#lines + 1] = { L["Fires"], table.concat(events, ", ") } end
  lines[#lines + 1] = { L["Through"], L["the real capture engine"] }
  if step.ranAt then
    if step.detail then lines[#lines + 1] = { L["Did"], tostring(step.detail) } end
    lines[#lines + 1] = { L["Recorded"], tostring(Host.Recorded(step, NS.Sim:Steps()) or 0) }
  end
  return lines
end

--- The window the panel docks beside: the ledger window while it is shown, else nil (it floats).
function Host.PanelAnchor()
  local f = NS.Browser and NS.Browser.GetWindow and NS.Browser:GetWindow()
  if f and f:IsShown() then return f end
  return nil
end

local PANEL = {
  title = NS.BRAND_NAME .. " - Simulation",
  stepLabel = function(step, i, steps) return Host.StepLabel(step, i, steps) end,
  stepTip = function(step, i) return Host.StepTip(step, i) end,
  startTip = {
    { L["Builds"], L["a simulated world from your real bag items"] },
    { L["Opens"], L["the ledger window on the simulation's rows"] },
    { L["Saves"], L["nothing: your ledger is not touched"] },
  },
  stopTip = {
    { L["Ends"], L["the simulation"] },
    { L["Restores"], L["your saved ledger in the window"] },
  },
  anchorTo = function() return Host.PanelAnchor() end,
  check = NS.Icon and NS.Icon("confirm") or nil,
}
Host.PANEL = PANEL

-- ── the marker (preview-mode, host contract H8) ──────────────────────────────────────────────

--- The strip's line while the dataset is the simulation's (Database:DatasetKind() == "sim"), naming
--- the running scenario by its label; nil for any other dataset.
function Host.MarkerText()
  if NS.Database:DatasetKind() ~= "sim" then return nil end
  local name = NS.Sim:Status().scenario
  local def = name and Host.SCENARIOS.defs[name]
  return L["Simulation: %s - nothing here is saved."]:format(def and def.label or tostring(name))
end

-- Both windows' strips follow the dataset: the ledger window's, and the session window's (it draws
-- the simulated rows too).
local function repaintMarkers()
  if NS.Browser and NS.Browser.UpdateTestStrip then NS.Browser:UpdateTestStrip() end
  if NS.SessionWindow and NS.SessionWindow.UpdateTestStrip then NS.SessionWindow:UpdateTestStrip() end
end
Host.RepaintMarkers = repaintMarkers

-- ── the session (LibKa0s-Sim-1.0) ────────────────────────────────────────────────────────────

-- The stop lines for the host's own reasons and the stand-down.
local STOP_TEXT = {
  bank      = L["Simulation stopped: a real bank window opened or closed."],
  combat    = L["Simulation stopped: you entered combat."],
  standDown = L["Simulation stopped: the addon stood down."],
}

-- The library's lines in this addon's words, by its STRINGS keys. STARTED makes the saved-data
-- claim the library leaves to its host (H4); tests/test_sim_session.lua's before/after check backs it.
local LINES = {
  STARTED = L["Simulation started (%s): nothing here is saved, and your ledger is not touched."],
}

local Lib = LibStub and LibStub("LibKa0s-Sim-1.0", true)
if Lib then
  NS.Sim = Lib:New({
    name = addonName,
    seam = NS.SimSeam,
    slash = "/bl sim",
    -- BL-05's one lookup: every capture signal, the two guild-bank pseudo-events included.
    deliver = function(event, ...) return NS.Ledger:Dispatch(event, ...) end,
    isStoodDown = function() return NS.IsStoodDown ~= nil and NS.IsStoodDown() end,
    scenarios = Host.SCENARIOS,
    prepare = function(...) return Host.Prepare(...) end,
    play = function(step) return Host.Play(step) end,
    refusal = function(opts) return Host.Refusal(opts) end,
    gate = function(session) return Host.Gate(session) end,
    stepDelay = function(step) return Host.DelayAfter(step) end,
    stopText = STOP_TEXT,
    L = LINES,
    print = function(line) NS.Print(line) end,
    debug = function(_, fmt, ...) debug(fmt, ...) end,
    panel = PANEL,
  })
end
-- Library absent: NS.Sim is core/SimSetup.lua's inert stub, whose OnStop and OnStopGuarded do
-- nothing, so the registrations below are harmless.

-- ── the stop ─────────────────────────────────────────────────────────────────────────────────

-- While the seam still answers: drop the simulated context with no final pass.
NS.Sim:OnStopGuarded(function() NS.Ledger:DropContext() end)

-- With the seam off, each step isolated by the library.
NS.Sim:OnStop(function()
  NS.State.simLog = nil
  Host.world, Host.pendingLag = nil, 0
end)
NS.Sim:OnStop(function() datasetChanged() end)

-- The markers repaint on the start and the stop: a listener runs on every transition, and only a
-- change in IsActive moves a marker.
local wasActive = false
NS.Sim:AddListener(function(sim)
  local active = sim:IsActive()
  if active == wasActive then return end
  wasActive = active
  repaintMarkers()
end)
