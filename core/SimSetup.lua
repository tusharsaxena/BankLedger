local addonName, NS = ...
-- core/SimSetup.lua — the simulator's answer seam, on LibKa0s-Sim-1.0 (library-stack-§7; BankLedger#24,
-- LibKa0s#54; the host contract H1-H10 is in libs/LibKa0s's docs/api/Sim/).
--
-- THE SEAM. At load, straight after core/Compat.lua and before any other file can read a member
-- (the LOAD-BEARING TOC slot, host contract H2), Sim:NewSeam wraps every NS.Compat function member in
-- place, once, except the three PURE ones below. While a simulation session runs, a wrapped member
-- asks the simulator's provider first; idle, it calls straight through to the live member, so the
-- whole cost of the seam is one field test per call. This file names no client API: core/Compat.lua
-- stays the only caller (compat). A member added to NS.Compat after this file loads, or one
-- replaced by assignment, escapes the wrap; the seam's Unwrapped() lists it, and
-- tests/test_sim_seam.lua asserts that list is empty after the whole addon loads.
--
-- PURE. GuildBankTabSize is a constant; GetItemDetails and ItemNameQuality are real item facts
-- about real cached items (the simulator's pool is drawn from the player's real bags), so the
-- simulator answers them exactly as the client does and they are never wrapped.
--
-- GUARDED. QueryGuildBankTab is the addon's one outward request to the server. While a session runs
-- its live body never runs, whatever a provider or a caller does (inside Live included): the guarded
-- answer marks the tab queried in the simulated world, counts the query on the session, and fires
-- the client's asynchronous reply, GUILDBANKBAGSLOTS_CHANGED, 0.2 s later on the session's timer.
--
-- HOST TABLES (OWNER_SCOPE C.4). NS.SimHost is the host's own table for host fields (its world,
-- its counters); NS.SimSeam is the seam, held for SetProvider and Live. Nothing host-side is ever
-- written onto the library instance or the seam.
--
-- LIBRARY ABSENT. Nothing is wrapped. NS.SimSeam is the inert seam stub and NS.Sim the inert
-- session stub, both the library's reference copies (LibKa0s tests/test_sim_stub.lua): every
-- member answers, nothing simulates, and /bl sim says the simulator needs the library. When the
-- library is present NS.Sim is the live instance modules/Sim.lua builds with Sim:New.

local Sim = LibStub and LibStub("LibKa0s-Sim-1.0", true)

NS.SimHost = NS.SimHost or {}

-- The members that answer for nobody. Never wrapped.
local PURE = { GuildBankTabSize = true, GetItemDetails = true, ItemNameQuality = true }

-- The guarded tab query. Reads NS.SimHost.world and NS.Sim at call time: both are a no-op until the
-- simulator's world and session exist. Never calls the client.
local function guardedQuery(tab)
  local world = NS.SimHost.world
  local guild = world and world.guild
  if guild then
    guild.queried = guild.queried or {}
    guild.queried[tab] = true
  end
  local sim = NS.Sim
  if not sim then return end
  local session = sim:Session()
  if session then session.queries = (session.queries or 0) + 1 end
  if NS.State and NS.State.debug and NS.Debug then
    NS.Debug("Sim", "guarded QueryGuildBankTab(%s): no client call, reply in 0.2s", tostring(tab))
  end
  sim:After(0.2, function() sim:Fire("GUILDBANKBAGSLOTS_CHANGED") end)
end
NS.SimHost.GuardedQuery = guardedQuery

-- ── the degradation stubs (host contract H9) ──────────────────────────────────────────────────

local function newSeamStub()
  local seam = {}
  function seam.SetProvider() end
  function seam.Live(_, fn, ...) return fn(...) end
  function seam.Keys() return {} end
  function seam.Unwrapped() return {} end
  return seam
end

local function newSimStub(say)
  local line = NS.L["The simulator needs LibKa0s-Sim-1.0."]
  local sim = {}
  local function no() return false end
  local function noop() end
  local function absent() return false, "absent" end
  sim.IsActive, sim.IsDelivering, sim.IsPanelShown = no, no, no
  function sim.Fire() return 0 end
  function sim.DeliverForCleanup() return 0 end
  function sim.After() return nil end
  function sim.Start() say(line); return false, line end
  sim.Stop = no
  sim.OnStop, sim.OnStopGuarded, sim.AddListener = noop, noop, noop
  function sim.Status() return { active = false } end
  function sim.Session() return nil end
  function sim.Steps() return {} end
  function sim.Step() return nil, "absent" end
  sim.Run, sim.Pause, sim.Resume, sim.Restart = absent, absent, absent, absent
  function sim.RunVerb() say(line); return false, "absent" end
  sim.ShowPanel, sim.TogglePanel = no, no
  sim.HidePanel, sim.RefreshPanel, sim.ResetPanelPosition = noop, noop, noop
  function sim.PanelRows() return {} end
  return sim
end

-- ── the seam ──────────────────────────────────────────────────────────────────────────────────

if Sim then
  NS.SimSeam = Sim:NewSeam(NS.Compat, {
    name = addonName,
    pure = PURE,
    guarded = { QueryGuildBankTab = guardedQuery },
  })
else
  NS.SimSeam = newSeamStub()
  -- NS.Print is resolved at call time: core/CoreSetup.lua, which publishes it, loads later.
  NS.Sim = newSimStub(function(line) NS.Print(line) end)
end
