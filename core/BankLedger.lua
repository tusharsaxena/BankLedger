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

function addon:OnEnable()
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
  -- No [Init] line here: the debug flag is session-only and off at login, so a boot-time summary
  -- would always be gated off and never render. It rides the DebugLog:SetEnabled seam instead,
  -- emitted when capture is actually enabled (debug-logging-§5/§8).
end

-- Both combat edges take the same route: NS.Util.ApplyVisibility re-reads the rule and hides or
-- re-shows exactly the windows the rule itself took (core/State.lua's hiddenByVisibility).
function addon:OnCombatChanged()
  NS.Util.ApplyVisibility()
end

-- Retention cleanup runs once per session, deferred off the login/zone spike.
function addon:OnEnterWorld()
  if NS.State.cleanupDone then return end
  NS.State.cleanupDone = true
  if C_Timer and C_Timer.After then
    C_Timer.After(5, function()
      if NS.Database and NS.Database.PruneOld then NS.Database:PruneOld() end
    end)
  end
end
