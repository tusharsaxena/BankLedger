local addonName, NS = ...
-- core/SimSetup.lua — the simulator's answer seam, on LibKa0s-Sim-1.0 (library-stack-§7; BankLedger#24,
-- LibKa0s#54; the host contract H1-H10 is in libs/LibKa0s's docs/api/Sim/).
--
-- THE SEAM. At load, straight after core/Compat.lua and core/CompatClient.lua and before any other
-- file can read a member (the LOAD-BEARING TOC slot, host contract H2), Sim:NewSeam wraps every NS.Compat function member in
-- place, once, except the five PURE ones below. While a simulation session runs, a wrapped member
-- asks the simulator's provider first; idle, it calls straight through to the live member, so the
-- whole cost of the seam is one field test per call. This file names no client API: the compat
-- family (core/Compat.lua, core/CompatClient.lua) stays the only caller (compat). A member added to NS.Compat after this file loads, or one
-- replaced by assignment, escapes the wrap; the seam's Unwrapped() lists it, and
-- tests/test_sim_seam.lua asserts that list is empty after the whole addon loads.
--
-- PURE. GuildBankTabSize is a constant; GetItemDetails and ItemNameQuality are real item facts
-- about real cached items (the simulator's pool is drawn from the player's real bags), so the
-- simulator answers them exactly as the client does and they are never wrapped. So are the
-- container groups (ContainerGroups, read once at load from the enum: a fact of the install) and
-- the readiness judgment (UnreadyBankContainers, a pure function of its arguments). So are
-- core/CompatClient.lua's eight: which client this is (IsForever, IsRetail, ClientKey, ForClient)
-- and how this client spells a name (RegionalNames, UnitCharacterName, CharacterKey, RealmKey) are
-- facts of the install, not of the simulated world. The simulator's alt is answered one level up,
-- by PlayerName and PlayerClass, so a module reaches the player's identity through those.
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
local PURE = {
  GuildBankTabSize = true, GetItemDetails = true, ItemNameQuality = true,
  ContainerGroups = true, UnreadyBankContainers = true,
  IsForever = true, IsRetail = true, ClientKey = true, ForClient = true,
  RegionalNames = true, UnitCharacterName = true, CharacterKey = true, RealmKey = true,
}

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

-- ── the Sim mode pair (Launcher minor 7, OptionsCompose minor 19) ──────────────────────────────
--
-- ONE pair for every Sim mode switch: the launcher menu's entry (core/LauncherSetup.lua) and the
-- Master controls checkbox (settings/Schema.lua's S:ComposeMaster) both take these two functions,
-- so neither can drift from `/bl sim`. The owner's rule (R7-SIM, smoke round 7 call 2): checked
-- while the sim window is open and/or a sim runs, unchecked when neither. So IsSimMode answers
-- window shown OR session running. ToggleSim is `/bl sim`'s own acts: from off the bare verb (the
-- status, the verbs and the sim window, where a scenario is picked), which leaves the box ticked;
-- from on, `/bl sim stop` when a session runs, then the window closed, so one untick (or one click
-- on the launcher's entry) leaves it unticked. Both read NS.Sim at call time, the live instance
-- modules/Sim.lua builds or the stub below. The start's refusals (test mode, combat, a real bank)
-- are the session's own and unchanged: opening the window starts nothing.
function NS.IsSimMode()
  local s = NS.Sim
  if type(s) ~= "table" then return false end
  if type(s.IsActive) == "function" and s:IsActive() == true then return true end
  return type(s.IsPanelShown) == "function" and s:IsPanelShown() == true
end

function NS.ToggleSim()
  local s = NS.Sim
  if type(s) ~= "table" or type(s.RunVerb) ~= "function" then return end
  if not NS.IsSimMode() then
    s:RunVerb("")
    return
  end
  if type(s.IsActive) == "function" and s:IsActive() then s:RunVerb("stop") end
  if type(s.HidePanel) == "function" then s:HidePanel() end
end

-- ── the sample characters (LibKa0s#87, Sim minor 3) ────────────────────────────────────────────
--
-- The made-up people this addon shows: test mode's sample ledger (modules/LedgerTable_TestMode.lua)
-- and the simulator's alt (modules/SimWorld.lua). They are the collection's one set,
-- LibKa0s-Sim-1.0's Sim.SAMPLE, under preview-mode's convention: a name starts Sample or Mock, the
-- realm is Samplerealm or Mockrealm and never a real one, and a name is data, never localized.
-- The set is per client (WoW Forever port, BL-02; clients-§5): Retail's rows are "Name-Realm",
-- WoW Forever's "First Surname" with no realm in the name (forever-quirks-§4). NS.SAMPLE_CLIENT is
-- the client's key, seeded ONCE at load from NS.Compat.ClientKey() (core/CompatClient.lua, which
-- loads first), "retail" for a client that is neither. NS.SampleCharacters() answers
-- Sim.Sample(NS.SAMPLE_CLIENT), a fresh copy the caller owns. Without the library it answers a copy
-- of NS.SAMPLE_FALLBACK, that client's twin in NS.SAMPLE_FALLBACKS: the library's rows limited to
-- the four fields this addon reads. tests/test_sample_characters.lua holds both twins to the
-- library's rows field for field, so neither can drift.
NS.SAMPLE_FALLBACKS = {
  retail = {
    { name = "Samplehunter", realm = "Samplerealm", fullName = "Samplehunter-Samplerealm", classFile = "HUNTER" },
    { name = "Sampleblade",  realm = "Samplerealm", fullName = "Sampleblade-Samplerealm",  classFile = "PALADIN" },
    { name = "Mockflame",    realm = "Mockrealm",   fullName = "Mockflame-Mockrealm",      classFile = "MAGE" },
    { name = "Samplemender", realm = "Samplerealm", fullName = "Samplemender-Samplerealm", classFile = "PRIEST" },
    { name = "Mockshield",   realm = "Mockrealm",   fullName = "Mockshield-Mockrealm",     classFile = "WARRIOR" },
  },
  forever = {
    { name = "Samplehunter", realm = "Samplerealm", fullName = "Samplehunter Mockstride", classFile = "HUNTER" },
    { name = "Sampleblade",  realm = "Samplerealm", fullName = "Sampleblade Mockvale",    classFile = "PALADIN" },
    { name = "Mockflame",    realm = "Mockrealm",   fullName = "Mockflame Samplewick",    classFile = "MAGE" },
    { name = "Samplemender", realm = "Samplerealm", fullName = "Samplemender Mockbrook",  classFile = "PRIEST" },
    { name = "Mockshield",   realm = "Mockrealm",   fullName = "Mockshield Sampleforge",  classFile = "WARRIOR" },
  },
}
NS.SAMPLE_CLIENT = NS.Compat.ClientKey() == "forever" and "forever" or "retail"
NS.SAMPLE_FALLBACK = NS.SAMPLE_FALLBACKS[NS.SAMPLE_CLIENT]

function NS.SampleCharacters()
  if Sim and type(Sim.Sample) == "function" then return Sim.Sample(NS.SAMPLE_CLIENT) end
  local rows = {}
  for i, row in ipairs(NS.SAMPLE_FALLBACK) do
    rows[i] = { name = row.name, realm = row.realm, fullName = row.fullName, classFile = row.classFile }
  end
  return rows
end

--- The shared sample character of `classFile`, or nil when the set has none of that class.
function NS.SampleCharacterOf(classFile)
  for _, row in ipairs(NS.SampleCharacters()) do
    if row.classFile == classFile then return row end
  end
  return nil
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
