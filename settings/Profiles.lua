local _, NS = ...

-- settings/Profiles.lua — the Profiles sub-page (options-ui-§3). AceConfigDialog draws the
-- AceDBOptions table into an AceGUI group inside our canvas; the flow engine never renders it, so
-- the tab strip does not apply (options-ui-§13).
--
-- A profile holds every setting but one, both item-id filter lists and the saved view; the recorded
-- ledger and the retention window that governs it are account-wide, and no control on this page
-- reaches either (docs/profiles.md, owner decision D6). Switching, copying or
-- resetting a profile reaches NS.OnProfileEvent (core/Database.lua), which re-applies the new
-- profile. Reset Profile here is the same act as Reset all settings, the General page's Defaults and
-- `/bl resetall` (options-ui-§12); only those three ask first, because AceDBOptions' own button does
-- not.
--
-- NO DEFAULTS BUTTON: profile management has its own destructive controls, and a header Defaults
-- here would be a second reset beside Reset Profile. Nothing on this page is a schema row, and the
-- global reset's veto names the page anyway (S.VetoedFromResetAll, settings/Schema.lua, passed to the
-- library as `skipRestoreAll`), so no row walk can reach it.
--
-- Registered by settings/Panel.lua's P:Register straight after General, so it is the last entry in
-- the Settings tree. Optional dependency: without AceDBOptions, AceConfig, AceConfigDialog or AceGUI
-- the builder answers nil and the library skips the page.

NS.ProfilesPage = NS.ProfilesPage or {}
local PP = NS.ProfilesPage

local APPNAME = "BankLedger-Profiles"
local TITLE = "Profiles"

function PP.Build(mainCategory)
  if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
  if not LibStub then return nil end
  local AceDBOptions    = LibStub("AceDBOptions-3.0", true)
  local AceConfig       = LibStub("AceConfig-3.0", true)
  local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
  local AceGUI          = LibStub("AceGUI-3.0", true)
  if not (AceDBOptions and AceConfig and AceConfigDialog and AceGUI) then return nil end
  if not (NS.db and NS.db.profile) then return nil end
  local O = NS.Helpers

  AceConfig:RegisterOptionsTable(APPNAME, AceDBOptions:GetOptionsTable(NS.db))

  local ctx = O.CreatePanel("BankLedgerProfilesPanel", TITLE, {
    pageKey = NS.Schema.PROFILES_PAGE, defaultsButton = false,
  })
  PP.ctx = ctx

  -- Built on first show, never in the builder (options-ui-§5), and re-opened on every render
  -- because AceConfigDialog re-reads the current profile on each Open.
  local container
  O.SetRenderer(ctx, function()
    if not container then
      container = AceGUI:Create("SimpleGroup")
      container:SetLayout("Fill")
      container.frame:SetParent(ctx.body)
      container.frame:ClearAllPoints()
      container.frame:SetPoint("TOPLEFT", ctx.body, "TOPLEFT", 8, -8)
      container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8, 8)
    end
    -- SHOWN EXPLICITLY, every render. AceGUI:Release hides a frame before pooling it, and neither
    -- AceGUI:Create nor AceConfigDialog:Open shows it again; created on first show, this group is
    -- often a pooled one, and AceConfigDialog would fill a hidden frame: a blank page.
    container.frame:Show()
    AceConfigDialog:Open(APPNAME, container)
  end)

  return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, TITLE)
end
