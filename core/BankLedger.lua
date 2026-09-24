local addonName, NS = ...

local AceAddon = LibStub("AceAddon-3.0")
local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon
NS.bus = addon   -- closed message bus: SendMessage / RegisterMessage (architecture-§4)

-- Reclaim NS.Print from AceConsole. NewAddon(NS, …, "AceConsole-3.0") embeds AceConsole's mixins
-- directly onto NS, and its :Print method OVERWRITES the secret-safe, cyan-[BL]-prefixed NS.Print
-- defined in core/Util.lua — after which every `local print = NS.Print` call site would render
-- AceConsole's green "|cff33ff99<msg>|r:" form (no tag, trailing colon) and lose secret-safety. The
-- embed never touches NS.Util.print, so restore the real printer from it (architecture-§2).
if NS.Util and NS.Util.print then NS.Print = NS.Util.print end

-- Bus-receiver factory. A module that CONSUMES Ka0s_BankLedger_* messages must register on its OWN
-- AceEvent target, never on the shared bus-as-self: CallbackHandler keys callbacks by
-- (message, target), so two consumers that share a target silently clobber each other — only the
-- last registrant of a given message ever receives it. Each call returns a fresh AceEvent-embedded
-- table (nil if AceEvent is unavailable); SendMessage on NS.bus still fans out to every target.
function NS.NewBusTarget()
  local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
  if not AceEvent then return nil end
  local t = {}
  AceEvent:Embed(t)
  return t
end

-- NO LibSharedMedia REGISTRATION HERE ANY MORE. This used to open with
--   `LSM:Register("font", "JetBrains Mono", NS.Constants.FONT_MONO)`
-- against this addon's own copy of the face. LibKa0s-Media-1.0 owns that registration now and
-- makes it once, at file load, from core/MediaSetup.lua — see the note there. Two registrations
-- of ONE name against TWO paths is exactly the collision the library exists to end, and doing it
-- here as well would also be doing it LATER: OnInitialize runs after every file that names a
-- face at load time.
function addon:OnInitialize()
  NS:InitDB()
  if NS.Schema and NS.Schema.Register then NS.Schema:Register() end
  if NS.Slash and NS.Slash.Register then NS.Slash:Register() end
  -- Eager settings-category registration (options-ui-§1): the entry is present in the Blizzard
  -- options list from load, even though each panel BODY is built lazily on its first OnShow.
  if NS.Panel and NS.Panel.Register then NS.Panel:Register() end
end

-- ── THE LATCH, AND WHAT SURVIVES IT (slash-commands-§7) ────────────────────────────────────────
--
-- `addon:OnEnable` is now SETUP ONLY. The chat command, the dispatcher, the settings category and
-- the launcher registration come up on load in EITHER state, because the switch has to go both
-- ways: without them `/bl enable` does not exist and the player's only route back is the panel
-- they were trying not to open.
--
-- Everything that is a FEATURE — the capture events, the addon's own three registrations, the four
-- bus targets, the windows — comes up in `NS.StandUp` and goes away in `NS.StandDown`, and the
-- only thing that calls either is the latch in core/LifecycleSetup.lua.
function addon:OnEnable()
  -- The launcher (launcher-§1). SETUP, so it is registered in either state: the minimap button
  -- stays on the minimap and the broker row stays in the display while the addon is off, because
  -- `minimap.hide` is a per-installation display preference (launcher-§3) and says nothing about
  -- whether the addon is running. What the LEFT click does while disabled is core/LauncherSetup's
  -- business, and it is refused there.
  --
  -- AFTER OnInitialize, which is what makes it work at all: the descriptor answers
  -- `db.global.minimap` through a closure and NS:InitDB is what materializes it. Idempotent by
  -- the library's design.
  if NS.Launcher and NS.Launcher.Register then NS.Launcher:Register() end

  -- Take the `disabled` hold from the stored path. NOT a special case: it is the same call the
  -- checkbox and the two verbs make, and it is how the setting survives a /reload — the latch
  -- itself persists nothing.
  NS.SetDisabledHold(not NS.EnabledStored())
  -- The latch is born believing the addon is UP and fires a callback only on an edge, so a load in
  -- the enabled state produces no edge and nothing would be registered. This is the bring-up for
  -- that case, and it is guarded on the hold set rather than on the stored path so it can never
  -- stand up an addon a hold is holding down.
  if not NS.IsStoodDown() then NS.StandUp() end
  -- No [Init] line here: the debug flag is session-only and off at login, so a boot-time summary
  -- would always be gated off and never render. It rides the DebugLog:SetEnabled seam instead,
  -- emitted when capture is actually enabled (debug-logging-§5/§8).
end

--- Bring the FEATURES up, from the settings AS THEY ARE NOW.
---
--- Never from a snapshot taken on the way down (performance-§6): a setting can be changed while the
--- addon is disabled, and each module's Enable re-reads what it needs, so the rebuilt registration
--- set reflects the new value rather than the old one.
function NS.StandUp()
  local self = NS.addon
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
  -- The General visibility rule's two transitions (options-ui-§15). `Only in combat` and `Only
  -- out of combat` are answers that CHANGE without anything being clicked, so the setting is
  -- unhonored without these: a window opened out of combat would simply stay up through a pull.
  self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatChanged")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatChanged")
  if NS.Ledger and NS.Ledger.Enable then NS.Ledger:Enable() end
  if NS.Browser and NS.Browser.Enable then NS.Browser:Enable() end
  -- Enabled independently of the Browser: the session window appears on a bank open whether or not
  -- the main ledger window has ever been built.
  if NS.SessionWindow and NS.SessionWindow.Enable then NS.SessionWindow:Enable() end
end

-- ── THE STAND-DOWN (slash-commands-§7) ─────────────────────────────────────────────────────────
--
-- ONE teardown body, reached from two arms: the latch's `disabled` hold, and AceAddon's own
-- `OnDisable`. Two arms onto ONE body is not the parallel-lifecycle anti-pattern — two BODIES
-- would be, and that is what this addon used to have, because "disabled" tore nothing down at all.
--
-- Each module gates its Enable behind a private `_enabled` latch, so with nothing to release it a
-- stand-down then stand-up brings all four back inert — no error, no capture, no windows.
--
-- AceAddon does not do this for us. Its AceEvent embed unregisters what was registered on the ADDON
-- object, which is where the Ledger's capture events live, but every module's live-refresh
-- subscription sits on a private target handed out by NS.NewBusTarget() that AceAddon has never
-- seen and cannot reach. Releasing the latch alone would therefore have the next Enable stand a
-- SECOND target up beside a first that is still subscribed, and SessionWindow:OnEntryAdded appends
-- unconditionally (modules/SessionWindow.lua:149-154) — one moved stack, two rows. So the targets
-- go with the latch.
--
-- `_guildHooked` deliberately stays set. It is not part of this cycle: it records a `HookScript`
-- hook installed on GuildBankFrame's OnShow, which nothing here takes off again, so clearing it
-- would let the next stand-up hook the same frame a second time. The hook's own body is gated on
-- the stand-down (modules/Ledger.lua) — the sanctioned shape for a hook that cannot be undone.
local BUS_MODULES = { "Ledger", "Browser", "SessionWindow", "Insights" }

-- Every module that arms a debounce timer, and therefore has a handle to drop. Canceling at the
-- AceTimer level alone is not enough: each module remembers its own handle and refuses to schedule
-- while one is outstanding, so a handle left behind a stand-down is a debounce that never fires
-- again after the stand-up.
local TIMER_MODULES = { "Ledger", "Browser", "Insights" }

--- Make the addon INERT. Every registration gone, every timer canceled, every window shut.
---
--- NOT a draw gate (anti-pattern #85). Nothing here sets a flag for a handler to consult: the
--- handlers are unregistered, so the client stops walking this addon's registration list, stops
--- building the argument frame and stops entering Lua — which is the cost the player was trying to
--- stop paying and the only part of it they cannot see.
---
--- WHAT IS NOT TORN DOWN, because it is SETUP and not a feature: the chat command registration, the
--- dispatcher and NS.COMMANDS; the settings category and the panel body with its own live-refresh
--- target; the AceDB handle, the single write seam and the profile callbacks; the launcher's
--- registration.
---
--- NO SECURE WORK IS DEFERRED HERE, and the absence is a fact about this addon rather than an
--- omission: it registers no state driver, writes no secure attribute and owns no protected frame,
--- so there is nothing that combat lockdown could refuse. That is also why it keeps NO event
--- registration at all while disabled — the PLAYER_REGEN_ENABLED a disabled addon is permitted to
--- keep exists to finish pending secure work, and there is none to finish.
function NS.StandDown()
  local ad = NS.addon

  -- 1. EVERY TIMER. AceTimer's own cancel-all takes the handles, and each module drops the handle
  --    it remembers so the next stand-up can schedule again. The retention prune's handle is the
  --    addon object's own, so it is dropped here: the next PEW after a stand-up re-arms it.
  if ad and ad.CancelAllTimers then ad:CancelAllTimers() end
  if NS.State then NS.State.cleanupPending = nil end
  for _, name in ipairs(TIMER_MODULES) do
    local module = NS[name]
    if module and module.CancelPending then module:CancelPending() end
  end

  -- 2. EVERY EVENT ON THE ADDON OBJECT — the three this file registers, and the Ledger's entire
  --    bank/bag/mail/guild capture set, which is registered there too. UnregisterAllEvents rather
  --    than a list to keep current: a list is what goes stale on the first event added to
  --    modules/Ledger.lua, and this addon has exactly one AceEvent target of its own.
  if ad and ad.UnregisterAllEvents then ad:UnregisterAllEvents() end
  if NS.Ledger then NS.Ledger.registeredEvents, NS.Ledger.unavailableEvents = {}, {} end

  -- 3. THE CAPTURE GATE'S CACHED ANSWER, refreshed before the bus target that carries the refresh
  --    is dropped below. The gate is a BELT behind unregistered events rather than the mechanism —
  --    it is unreachable once step 2 has run — but a belt reading a cache from before the switch
  --    was thrown is a belt that says "capture is on" about an addon that is off.
  if NS.Ledger and NS.Ledger.RefreshUpvalues then NS.Ledger:RefreshUpvalues() end

  -- 3b. THE CAPTURE CONTEXT — the open context, its baseline, the settle window and the banking
  --    session. Every path that normally clears them is an event step 2 just unregistered, so left
  --    alone they outlive the switch and the stand-up diffs against a pre-disable baseline. Before
  --    step 4, because SessionWindow's bus target must still be subscribed to hear
  --    SessionChanged(false) and end the session. No flush: nothing moved at the moment of
  --    disabling is captured.
  if NS.Ledger and NS.Ledger.DropContext then NS.Ledger:DropContext() end

  -- 4. THE FOUR PRIVATE BUS TARGETS, and the latches that would otherwise refuse to rebuild them.
  for _, name in ipairs(BUS_MODULES) do
    local module = NS[name]
    if module then
      local ev = module.__ev
      if ev then
        if ev.UnregisterAllMessages then ev:UnregisterAllMessages() end
        if ev.UnregisterAllEvents then ev:UnregisterAllEvents() end
        module.__ev = nil
      end
      module._enabled = nil
    end
  end

  -- 5. THE WINDOWS. Hidden here, but held shut AT THE SOURCE — NS.Util.VisibilityAllows answers no
  --    while the latch is down, and every Show in this addon consults it. Hiding imperatively and
  --    stopping there is the other half of the draw gate: a hidden frame comes back on a combat
  --    transition, a target swap or a settings change, and the addon is then visibly running while
  --    it claims to be off.
  if NS.Browser and NS.Browser.Hide then NS.Browser:Hide() end
  if NS.SessionWindow and NS.SessionWindow.Hide then NS.SessionWindow:Hide() end
end

-- AceAddon's arm onto the same body. It can disable and re-enable an addon at any point in a
-- session, and when it does the addon must end up in exactly the state the latch would produce.
function addon:OnDisable()
  NS.StandDown()
end

-- Both combat edges take the same route: NS.Util.ApplyVisibility re-reads the rule and hides or
-- re-shows exactly the windows the rule itself took (core/State.lua's hiddenByVisibility).
--
-- The pull also ENDS test mode (options-ui-§15, standard v2.47.0): no sample ledger covers real data
-- in a fight. AceEvent hands the event name in, and only PLAYER_REGEN_DISABLED ends it. It goes first,
-- so the visibility pass sees the real dataset, and it goes through LT:SetTestMode(false), which never
-- opens a window and repaints the panel so the Test mode box unticks. One line says where it went.
function addon:OnCombatChanged(event)
  local LT = NS.LedgerTable
  if event == "PLAYER_REGEN_DISABLED" and LT and LT.IsTestMode and LT:IsTestMode() then
    LT:SetTestMode(false)
    NS.Print("test mode off \226\128\148 combat started.")
  end
  NS.Util.ApplyVisibility()
end

-- Retention cleanup runs once per session, deferred off the login/zone spike.
function addon:OnEnterWorld()
  local st = NS.State
  if st.cleanupDone or st.cleanupPending then return end
  if not self.ScheduleTimer then return end
  -- An AceTimer handle, so NS.StandDown's CancelAllTimers cancels it (slash-commands-§7: every
  -- timer is canceled, not left armed to find a flag). StandDown also drops the handle, and the
  -- latch is set only when the prune actually runs, so a stand-down inside the five seconds
  -- POSTPONES the prune to the next PLAYER_ENTERING_WORLD rather than skipping it for the session.
  -- PruneOld writes SavedVariables, so the body still checks the latch as a belt behind the cancel.
  st.cleanupPending = self:ScheduleTimer(function()
    st.cleanupPending = nil
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    st.cleanupDone = true
    if NS.Database and NS.Database.PruneOld then NS.Database:PruneOld() end
  end, 5)
end
