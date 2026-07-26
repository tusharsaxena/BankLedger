local addonName, NS = ...   -- luacheck: ignore addonName
NS.Schema = NS.Schema or {}
local S = NS.Schema
local C = NS.Constants
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

-- One row per setting. This single table drives the AceDB defaults check, the panel widgets, and
-- the slash get/set/list/reset dispatch (architecture-§5) — add a setting here and all three
-- surfaces pick it up with no other edit. Paths resolve against NS.db.global (account-wide).
--
-- `group` names the panel section header, and row order within a group drives the two-column
-- pairing. `wide` forces a full-width row; `soloRow` puts a row on its own line.
S.Schema = {
  -- ── Master Controls ──
  -- The master switches and the window controls, ahead of what is actually captured: the same
  -- shape the sibling Ka0s addons use, so General reads the same way across the suite.
  { path = "settings.enabled", default = true, type = "boolean", widget = "CheckBox",
    group = "Master Controls", label = "Enable capture",
    tooltip = "Master switch for recording bank movements.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "enabled") end
    end },

  { path = "minimap.hide", default = false, type = "boolean", widget = "CheckBox",
    group = "Master Controls", label = "Hide minimap button",
    tooltip = "Hide the Bank Ledger minimap button.",
    onChange = function(v)
      if NS.Browser and NS.Browser.SetMinimapHidden then NS.Browser:SetMinimapHidden(v) end
    end },

  -- A session-only row (never persisted): its value is the debug console WINDOW's visibility, not
  -- the NS.State.debug logging flag. get/set route to NS.DebugLog, and Schema:Set skips the
  -- db.global write for sessionOnly rows. Mirrors `/bl debug` with no argument.
  { path = "state.debugConsole", sessionOnly = true, default = false, type = "boolean",
    widget = "CheckBox", soloRow = true, group = "Master Controls", label = "Debug console",
    tooltip = "Show or hide the on-screen debug console. Session-only \226\128\148 resets on reload.",
    get = function() return NS.DebugLog ~= nil and NS.DebugLog:IsShown() end,
    set = function(v)
      if not NS.DebugLog then return end
      if v then NS.DebugLog:Show() else NS.DebugLog:Hide() end
    end },

  -- Paired with the "Reset all" button by the panel's `companions` map (settings/Panel.lua).
  { path = "settings.windowScale", default = 1.0, type = "number", min = 0.6, max = 1.6,
    widget = "Slider",
    fmt = "%.2fx",   -- scale → "1.00x" in the slash list/get output (slash-commands-§5)
    group = "Master Controls", label = "Window scale",
    tooltip = "Scale of the ledger window.",
    onChange = function(v)
      if NS.Browser and NS.Browser.SetScale then NS.Browser:SetScale(v) end
    end },

  -- ── Capture ──
  -- What gets recorded: the two scope dropdowns first, then the kind toggles, then the per-store
  -- grid — narrowest-to-widest, as the sibling addons order their collection section.
  { path = "settings.qualityThreshold", default = 0, type = "number", widget = "Dropdown",
    group = "Capture", label = "Minimum quality", options = C.QUALITY_OPTIONS,
    tooltip = "Only record items at or above this quality. Whitelisted items ignore this.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "quality") end
    end },

  { path = "settings.retentionDays", default = 30, type = "number", widget = "Dropdown",
    group = "Capture", label = "Keep history for", options = C.RETENTION_OPTIONS,
    tooltip = "Automatically drop movements older than this. 'Always' keeps everything.",
    onChange = function()
      if NS.Database and NS.Database.PruneOld then NS.Database:PruneOld() end
    end },

  { path = "settings.trackItems", default = true, type = "boolean", widget = "CheckBox",
    group = "Capture", label = "Track items",
    tooltip = "Record items moving between your bags and a bank.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "trackItems") end
    end },

  { path = "settings.trackMoney", default = true, type = "boolean", widget = "CheckBox",
    group = "Capture", label = "Track gold",
    tooltip = "Record gold deposited to or withdrawn from the guild and warband banks. "
      .. "The character bank has no gold slot, so it is never counted.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "trackMoney") end
    end },

  -- Stored as the set of MUTED stores (excludedStores); the panel renders it inverted
  -- (invert = true) as "Record movements to and from", so a ticked box means "record this store".
  { path = "settings.excludedStores", default = {}, type = "table", widget = "MultiCheck",
    wide = true, invert = true,
    group = "Capture", label = "Record movements to and from", options = C.STORE_OPTIONS,
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "stores") end
    end },
}
-- NOTE: the debug LOGGING flag (NS.State.debug) is deliberately NOT a schema setting — it is
-- session-only, set via `/bl debug on|off`, and always off after a reload (debug-logging-§5). The
-- console WINDOW's visibility IS the `state.debugConsole` row above.
-- NOTE: `settings.window` (geometry) and the blacklist/whitelist id-sets are storage carve-outs,
-- mutated by their owning modules rather than through Schema:Set (architecture-§5).

function S:FindRow(path)
  for _, row in ipairs(S.Schema) do
    if row.path == path then return row end
  end
  return nil
end

function S:ReadPath(root, path)
  local node = root
  for _, key in ipairs(NS.Util.SplitPath(path)) do
    if type(node) ~= "table" then return nil end
    node = node[key]
  end
  return node
end

function S:WritePath(root, path, value)
  local parts = NS.Util.SplitPath(path)
  local node = root
  for i = 1, #parts - 1 do
    local key = parts[i]
    if type(node[key]) ~= "table" then node[key] = {} end
    node = node[key]
  end
  node[parts[#parts]] = value
end

-- Deep-copy table values so the write path never stores (or hands out) a live reference to a schema
-- `default` table. Without this, S:Set(path, row.default) on a reset would alias the DB to the
-- shared default table, and any in-place mutation of the stored set would silently poison the
-- default for the rest of the session.
local function deepcopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do out[k] = deepcopy(val) end
  return out
end

-- The single write seam. Panel widgets and the slash `set` both route through here, so validation,
-- the debug trace and the onChange reaction can never be skipped by one caller.
function S:Set(path, value)
  local row = S:FindRow(path)
  if not row then return false, "unknown path: " .. tostring(path) end
  if row.validate and not row.validate(value) then return false, "invalid value" end
  if row.sessionOnly then
    -- Session-only rows never touch db.global; the row's own set() applies the value.
    if row.set then row.set(value) end
  else
    S:WritePath(NS.db.global, path, deepcopy(value))
  end
  -- Every settings mutation is logged ONCE, here at the write seam (debug-logging-§10). Downstream
  -- reactors must not re-echo the same value.
  if NS.State and NS.State.debug and NS.Debug then
    NS.Debug("Set", "%s = %s", tostring(path), tostring(value))
  end
  if row.onChange then row.onChange(value) end
  return true
end

function S:Get(path)
  local row = S:FindRow(path)
  if row and row.get then return row.get() end
  return S:ReadPath(NS.db.global, path)
end

function S:Default(path)
  local row = S:FindRow(path)
  return row and deepcopy(row.default)
end

-- Boot validation (architecture-§5): every schema path must resolve against the defaults table, so
-- a typo in a path is caught loudly at load instead of silently reading nil forever. Returns the
-- number of unresolved paths, which is what the headless test asserts on.
function S:Register()
  local g = NS.defaults and NS.defaults.global
  if not g then return 0 end
  local unresolved = 0
  for _, row in ipairs(S.Schema) do
    -- Session-only rows (state.debugConsole) have no db-backed default to resolve — skip them.
    if not row.sessionOnly and S:ReadPath(g, row.path) == nil and row.default == nil then
      unresolved = unresolved + 1
      print("schema path missing default: " .. tostring(row.path))
    end
  end
  return unresolved
end

-- Slash command table. Dispatch lives in Slash.lua and the help index is generated from this, so
-- `/bl help`, the README's command table and the settings landing page can never drift
-- (slash-commands-§3).
NS.COMMANDS = {
  { name = "show",     desc = "Open the ledger window",  fn = function() NS.Browser:Show() end },
  { name = "hide",     desc = "Close the ledger window", fn = function() NS.Browser:Hide() end },
  { name = "toggle",   desc = "Toggle the ledger window", fn = function() NS.Browser:Toggle() end },
  { name = "config",   desc = "Open settings",           fn = function()
      if NS.Panel then NS.Panel:Open() end
    end },
  { name = "version",  desc = "Print addon version",     fn = function() NS.Slash:CliVersion() end },
  { name = "get",      desc = "Get a setting value",     fn = function(a) NS.Slash:CliGet(a) end },
  { name = "set",      desc = "Set a setting value",     fn = function(a) NS.Slash:CliSet(a) end },
  { name = "list",     desc = "List all settings",       fn = function() NS.Slash:CliList() end },
  { name = "reset",    desc = "Reset one setting",       fn = function(a) NS.Slash:CliReset(a) end },
  { name = "resetall", desc = "Reset all settings",      fn = function() NS.Slash:CliResetAll() end },
  { name = "preview",  desc = "Toggle a sample ledger",  fn = function()
      local on = NS.LedgerTable and NS.LedgerTable.TogglePreview and NS.LedgerTable:TogglePreview()
      print("preview mode " .. (on and "on" or "off"))
    end },
  { name = "purge",    desc = "Delete ALL ledger history (asks first)", fn = function()
      if type(StaticPopup_Show) == "function" then
        StaticPopup_Show("KA0S_BANKLEDGER_PURGE")
      elseif NS.Database and NS.Database.Purge then
        NS.Database:Purge()
      end
    end },
  { name = "debug",    desc = "Toggle the console; 'on'/'off' set logging", fn = function(rest)
      -- `/bl debug` toggles the WINDOW only (the logging flag is untouched); `/bl debug on|off`
      -- sets the session-only logging flag through the DebugLog seam. Logging runs even with the
      -- console closed, so a bug can be reproduced first and the log read afterwards.
      local arg = rest and tostring(rest):lower():match("^%s*(%S*)") or ""
      if not NS.DebugLog then return end
      if arg == "on" then NS.DebugLog:SetEnabled(true)
      elseif arg == "off" then NS.DebugLog:SetEnabled(false)
      elseif arg == "panel" then
        -- Structured dump of the settings header's Defaults button (debug-logging-§4). Same RAW
        -- append as `scan`, so it works whether or not logging is enabled.
        NS.DebugLog:Show()
        if NS.Panel and NS.Panel.Diagnose then
          for _, line in ipairs(NS.Panel:Diagnose()) do NS.DebugLog:Add("Panel", line) end
        else
          NS.DebugLog:Add("Panel", "settings panel not built yet \226\128\148 run /bl config first")
        end
      elseif arg == "scan" then
        -- A structured dump verb (debug-logging-§4): writes the client's real container model into
        -- the console through the RAW append, so it works whether or not logging is enabled.
        NS.DebugLog:Show()
        for _, line in ipairs(NS.Ledger:Diagnose()) do NS.DebugLog:Add("Scan", line) end
      else NS.DebugLog:Toggle() end
    end },
  { name = "help",     desc = "Show this help",          fn = function() NS.Slash:PrintHelp() end },
}
