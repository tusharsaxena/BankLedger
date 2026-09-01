local addonName, NS = ...   -- luacheck: ignore addonName
NS.Schema = NS.Schema or {}
local S = NS.Schema
local C = NS.Constants
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

-- One row per setting. This single table drives the AceDB defaults check, the panel widgets, and
-- the slash get/set/list/reset dispatch (architecture-§5) — add a setting here and all three
-- surfaces pick it up with no other edit. Paths resolve against NS.db.global (account-wide).
--
-- `group` names one TAB on the page (options-ui-§13): H.RenderTabbedSchema partitions the page's
-- rows by `group` IN DECLARATION ORDER and draws one tab per distinct group, so the array's order
-- IS the tab order and a group's rows must stay CONTIGUOUS — a row filed under a group the page has
-- already left prints that tab a second time further down. Row order within a group drives the
-- two-column pairing. `wide` forces a full-width row; `solo` puts a row on its own line;
-- `skipRender` keeps a row in the schema — so the CLI, the defaults and a reset all still see it —
-- while the panel draws it by hand. Those names are LibKa0s-Options-1.0's, not ours: the flow
-- engine reads them.
--
-- The tabs, in order: Capture (what is recorded), Interface (what is on screen), History (how much
-- is kept, and the two ways to destroy it).
S.Schema = {
  -- ── Capture ──
  -- FIRST, because it is what the addon is for and what a player opens this page to change. The
  -- master switch leads on its own line (`solo`), then the two kind toggles across one line, then
  -- the quality gate, then the per-store grid — narrowest question to widest.
  { path = "settings.enabled", default = true, type = "bool", widget = "CheckBox",
    -- `solo` is spent here and nowhere else on the page: this is the switch every other row on
    -- the tab is conditional on, which is the "genuine pivot" the flag exists for.
    solo = true,
    group = "Capture", label = "Enable capture",
    tooltip = "Master switch for recording bank movements.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "enabled") end
    end },

  { path = "settings.trackItems", default = true, type = "bool", widget = "CheckBox",
    group = "Capture", label = "Track items",
    tooltip = "Record items moving between your bags and a bank.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "trackItems") end
    end },

  { path = "settings.trackMoney", default = true, type = "bool", widget = "CheckBox",
    group = "Capture", label = "Track gold",
    tooltip = "Record gold deposited to or withdrawn from the guild and warband banks. "
      .. "The character bank has no gold slot, so it is never counted.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "trackMoney") end
    end },

  { path = "settings.qualityThreshold", default = 0, type = "number", widget = "Dropdown",
    group = "Capture", label = "Minimum quality", values = C.QUALITY_OPTIONS,
    tooltip = "Only record items at or above this quality. Whitelisted items ignore this.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "quality") end
    end },

  -- Stored as the set of MUTED stores (excludedStores); the panel renders it inverted
  -- (invert = true) as "Record movements to and from", so a ticked box means "record this store".
  -- `skipRender` because no library maker draws a multi-select set picker, let alone an inverted
  -- one — RenderField dispatches on bool/number/string/color and answers nil for anything else. The
  -- row stays in the schema so `/bl list`, `/bl get` and every reset still see it; the panel emits
  -- the checkbox grid itself, from the Capture tab's `afterGroup` hook, which is what keeps it on
  -- the tab through a tab click (the strip re-renders the schema alone, not the page body).
  { path = "settings.excludedStores", default = {}, type = "table", widget = "MultiCheck",
    wide = true, invert = true, skipRender = true,
    group = "Capture", label = "Record movements to and from", values = C.STORE_OPTIONS,
    -- Spells the inversion out: the stored value is the MUTED set, so a ticked box means "record".
    tooltip = "Tick a store to RECORD movements to and from it. Unticking mutes that store; "
      .. "capture for every other store is unaffected.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "stores") end
    end },

  -- ── Interface ──
  -- Everything about what is on screen and how it looks. Three full lines, and each line is one
  -- question: scale and the launcher, then the two windows you can switch on, then the row tint
  -- pair — rest beside hover, so the reader compares them across the line instead of down a column.
  { path = "settings.windowScale", default = 1.0, type = "number", min = 0.6, max = 1.6,
    -- Declared explicitly because the two renderers disagree about the default: this addon's old
    -- panel assumed 0.05, LibKa0s-Options-1.0's makeSlider assumes 1. Left undeclared, the library
    -- would snap a 0.6-1.6 slider to its two endpoints and nothing else.
    step = 0.05,
    widget = "Slider",
    fmt = "%.2fx",   -- scale → "1.00x" in the slash list/get output (slash-commands-§5)
    group = "Interface", label = "Window scale",
    tooltip = "Scale of the ledger window.",
    -- The direct call repaints the window the user is almost certainly looking at with no latency;
    -- the broadcast is what reaches everything ELSE that scales. SessionWindow already subscribes
    -- to SettingsChanged and already reads windowScale, so it needed no change — it was simply
    -- never told (F-003). A second direct call would have been one line and anti-pattern #19, and
    -- would have left the same hole for the next window added.
    onChange = function(v)
      if NS.Browser and NS.Browser.SetScale then NS.Browser:SetScale(v) end
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "windowScale") end
    end },

  { path = "minimap.hide", default = false, type = "bool", widget = "CheckBox",
    group = "Interface", label = "Hide minimap button",
    tooltip = "Hide the Bank Ledger minimap button.",
    onChange = function(v)
      if NS.Browser and NS.Browser.SetMinimapHidden then NS.Browser:SetMinimapHidden(v) end
    end },

  { path = "settings.showSessionWindow", default = true, type = "bool", widget = "CheckBox",
    group = "Interface", label = "Session window",
    tooltip = "Show a small live window listing what you move while a bank is open. "
      .. "Turning this off never stops capture \226\128\148 only the window.",
    onChange = function()
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "sessionWindow") end
    end },

  -- A session-only row (never persisted): its value is the debug console WINDOW's visibility, not
  -- the NS.State.debug logging flag. get/set route to NS.DebugLog, and Schema:Set skips the
  -- db.global write for sessionOnly rows. Mirrors `/bl debug` with no argument.
  { path = "state.debugConsole", sessionOnly = true, default = false, type = "bool",
    widget = "CheckBox", group = "Interface", label = "Debug console",
    tooltip = "Show or hide the on-screen debug console. Session-only \226\128\148 resets on reload.",
    get = function() return NS.DebugLog ~= nil and NS.DebugLog:IsShown() end,
    set = function(v)
      if not NS.DebugLog then return end
      if v then NS.DebugLog:Show() else NS.DebugLog:Hide() end
    end },

  -- The row tint pair. Both were hardcoded in TWO files each — modules/LedgerTable.lua and
  -- modules/SessionWindow.lua built every pooled row with `1,1,1,0.03` behind the even rows and
  -- `1,0.82,0,0.10` under the cursor — and they are two answers to two questions, so they are two
  -- sliders rather than one "row emphasis". Neither value is Core.SKIN's: the shared skin owns the
  -- window edge, fill, border and title, and says so byte for byte in modules/Browser.lua's
  -- B:ApplySkin note. The table interior is this addon's own.
  --
  -- Both defaults ARE the literals they replaced, so an install that touches neither is drawn
  -- exactly as it was. Both are clamped at the read (NS.Util.RowTintAlpha): these come out of
  -- SavedVariables, where a hand-edited 5 is not an error, it is a table drawn opaque white.
  { path = "settings.rowStripeAlpha", default = 0.03, type = "number", min = 0, max = 0.3,
    step = 0.01, widget = "Slider", fmt = "%.2f",
    group = "Interface", label = "Row stripe opacity",
    tooltip = "How strongly every second row in the ledger and session tables is tinted. "
      .. "0 turns the banding off.",
    onChange = function() NS.Util.RefreshRowTint() end },

  { path = "settings.rowHoverAlpha", default = 0.10, type = "number", min = 0, max = 0.4,
    step = 0.01, widget = "Slider", fmt = "%.2f",
    group = "Interface", label = "Row hover opacity",
    tooltip = "How strongly the row under your cursor is highlighted in the ledger and session "
      .. "tables. 0 turns the highlight off.",
    onChange = function() NS.Util.RefreshRowTint() end },

  -- ── History ──
  -- LAST: what you set once and leave, and the only place anything is destroyed. The retention
  -- dropdown is the tab's one stored row; the live storage read-out and the two confirm-gated
  -- buttons beside it (Purge ledger, Reset all) are bespoke and have no path, which is the
  -- named exemption to "a tab holding fewer than two visible controls is not a subject".
  { path = "settings.retentionDays", default = 30, type = "number", widget = "Dropdown",
    group = "History", label = "Keep history for", values = C.RETENTION_OPTIONS,
    tooltip = "Automatically drop movements older than this. 'Always' keeps everything.",
    onChange = function()
      if NS.Database and NS.Database.PruneOld then NS.Database:PruneOld() end
    end },
}

-- NOTE: the debug LOGGING flag (NS.State.debug) is deliberately NOT a schema setting — it is
-- session-only, set via `/bl debug on|off`, and always off after a reload (debug-logging-§5). The
-- console WINDOW's visibility IS the `state.debugConsole` row above.
-- NOTE: four storage carve-outs are mutated by their owning module rather than through Schema:Set
-- (architecture-§5). None is a schema row, so none has a widget, a default or an onChange; check
-- this list before writing a key under db.global directly. All four are:
--   1. `settings.window` — the ledger window's geometry. Written by B:SaveGeometry
--      (modules/Browser.lua:147), cleared by B:ResetWindow (:185).
--   2. `settings.sessionWindow` — the session window's geometry. Written by SW:SaveGeometry
--      (modules/SessionWindow.lua:252), cleared by SW:ResetWindow (:289).
--   3. `savedView` — the account-wide column/sort baseline. Written by B:SaveView
--      (modules/Browser.lua:748), cleared by B:ResetView (:757).
--   4. `blacklist` / `whitelist` — the filter id-sets, copy-on-write in modules/Filters.lua:81,
--      :83, :95, :112, :122-123, which then calls Database:FireLedgerChanged itself.

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
  -- An open panel MUST reflect live state after a mutation (options-ui-§11), and the write seam is
  -- where that belongs: this is "the same function /bl set calls" (options-ui-§1), so a slash
  -- write, a panel widget and any future caller all repaint by the same route. It used to be
  -- nowhere, so `/bl set` with the settings window open left every widget showing the old value
  -- until the window was closed and reopened.
  --
  -- Cheap by construction: P:Refresh skips every page that is not on screen, and re-syncing a
  -- widget's value does not fire its OnValueChanged, so this cannot loop back through here.
  if NS.Panel and NS.Panel.Refresh then NS.Panel:Refresh() end
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
  { "show",     "Open the ledger window",  function() NS.Browser:Show() end },
  { "hide",     "Close the ledger window", function() NS.Browser:Hide() end },
  { "toggle",   "Toggle the ledger window", function() NS.Browser:Toggle() end },
  { "config",   "Open settings",           function()
      if NS.Panel then NS.Panel:Open() end
    end },
  { "version",  "Print addon version",     function() NS.Slash:CliVersion() end },
  { "get",      "Get a setting value",     function(a) NS.Slash:CliGet(a) end },
  { "set",      "Set a setting value",     function(a) NS.Slash:CliSet(a) end },
  { "list",     "List all settings",       function() NS.Slash:CliList() end },
  { "reset",    "Reset one setting",       function(a) NS.Slash:CliReset(a) end },
  { "resetall", "Reset all settings",      function() NS.Slash:CliResetAll() end },
  { "session",  "Toggle the banking-session window (sample data outside a bank)",
    function()
      if not NS.SessionWindow then return end
      local on = NS.SessionWindow:TogglePreview()
      if on == nil then
        print("a real banking session is open \226\128\148 showing what you actually moved.")
      else
        print("session window sample " .. (on and "on" or "off"))
      end
    end },
  { "test",     "Toggle a sample ledger",  function()
      local on = NS.LedgerTable and NS.LedgerTable.ToggleTestMode
        and NS.LedgerTable:ToggleTestMode()
      print("test mode " .. (on and "on" or "off"))
    end },
  { "purge",    "Delete ALL ledger history (asks first)", function()
      if type(StaticPopup_Show) == "function" then
        StaticPopup_Show("KA0S_BANKLEDGER_PURGE")
      elseif NS.Database and NS.Database.Purge then
        NS.Database:Purge()
      end
    end },
  { "debug",    "Toggle the console; 'on'/'off' set logging", function(rest)
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
  { "help",     "Show this help",          function() NS.Slash:PrintHelp() end },
}
