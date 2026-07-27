local addonName, NS = ...   -- luacheck: ignore addonName
NS.Slash = NS.Slash or {}
local Sl = NS.Slash
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

-- Confirm dialogs for the destructive actions. Registered once; in-game only.
if type(StaticPopupDialogs) == "table" then
  StaticPopupDialogs["KA0S_BANKLEDGER_PURGE"] = {
    text = "Delete ALL Ka0s Bank Ledger history? This cannot be undone.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
      if NS.Database and NS.Database.Purge then NS.Database:Purge() end
      print("ledger purged.")
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
  StaticPopupDialogs["KA0S_BANKLEDGER_RESETALL"] = {
    text = "Reset ALL Ka0s Bank Ledger settings AND delete ALL recorded history? "
      .. "This cannot be undone.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function() Sl:ResetEverything() end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
  -- Bulk-clear confirms for the two item-id filter lists. Non-destructive: clearing a list only
  -- empties its id-set — stored history is never touched (filtering is point-in-time, so there are
  -- no hidden rows to reconcile).
  StaticPopupDialogs["KA0S_BANKLEDGER_CLEAR_BLACKLIST"] = {
    text = "Clear ALL item ids from the blacklist? Future movements of them will be recorded "
      .. "again; your existing history is unaffected.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
      local n = (NS.Filters and NS.Filters:ClearList("blacklist")) or 0
      print(("blacklist cleared (%d %s)."):format(n, n == 1 and "id" or "ids"))
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
  StaticPopupDialogs["KA0S_BANKLEDGER_CLEAR_WHITELIST"] = {
    text = "Clear ALL item ids from the whitelist?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
      local n = (NS.Filters and NS.Filters:ClearList("whitelist")) or 0
      print(("whitelist cleared (%d %s)."):format(n, n == 1 and "id" or "ids"))
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
  -- The Filters subcategory's top-right Defaults button (options-ui-§5) clears BOTH lists in one
  -- action — their default state is empty. Non-destructive, like the per-list clears.
  StaticPopupDialogs["KA0S_BANKLEDGER_CLEAR_FILTERS"] = {
    text = "Reset all filters to defaults (clear the item blacklist AND whitelist)? "
      .. "Your existing history is unaffected.",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
      local n = (NS.Filters and NS.Filters:ClearAll()) or 0
      print(("filters reset (%d %s cleared)."):format(n, n == 1 and "id" or "ids"))
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
    preferredIndex = 3,
  }
end

-- The confirm-gated full reset: wipe the ledger AND restore every persisted piece of account state
-- to its stock shape. CliResetAll covers the schema settings and the filter lists; this adds the
-- window-geometry carve-out the non-destructive resets deliberately leave alone.
function Sl:ResetEverything()
  if NS.Database and NS.Database.Purge then NS.Database:Purge() end
  Sl:CliResetAll()   -- resets settings + filter lists and prints the confirmation line
  if NS.Browser and NS.Browser.ResetWindow then NS.Browser:ResetWindow() end
  if NS.SessionWindow and NS.SessionWindow.ResetWindow then NS.SessionWindow:ResetWindow() end
  if NS.Panel and NS.Panel.Refresh then NS.Panel:Refresh() end
end

function Sl:Register()
  NS.addon:RegisterChatCommand("bl", function(input) Sl:OnSlash(input) end)
  NS.addon:RegisterChatCommand("bankledger", function(input) Sl:OnSlash(input) end)
end

-- Bare `/bl` prints the help index (slash-commands-§4); window display is explicit
-- (`/bl toggle`, `/bl show|hide`). Only the VERB is lower-cased — `rest` keeps its case, so schema
-- paths survive `/bl set <path> <value>`.
function Sl:OnSlash(input)
  if input == nil or input:match("^%s*$") then
    return Sl:PrintHelp()
  end
  local verb, rest = input:match("^(%S+)%s*(.-)$")
  verb = verb and verb:lower()
  for _, cmd in ipairs(NS.COMMANDS) do
    if cmd.name == verb then return cmd.fn(rest) end
  end
  print("unknown command '" .. tostring(verb) .. "'")
  Sl:PrintHelp()
end

-- The help index, generated from NS.COMMANDS (slash-commands-§4): a version/alias header, then one
-- prefixed row per command — gold command, em-dash, white description. Never hand-maintained.
function Sl:PrintHelp()
  print("v" .. tostring(Sl:Version()) ..
    " slash commands (|cffffff00/bankledger|r is an alias for |cffffff00/bl|r)")
  for _, cmd in ipairs(NS.COMMANDS) do
    print(("|cffffff00/bl %s|r — |cffffffff%s|r"):format(cmd.name, cmd.desc))
  end
end

-- ── Schema-driven CLI: list / get / set / reset (slash-commands-§5 output format) ──

-- The shared value formatter for list/get/set, so the three can never diverge. Type-aware and
-- schema-driven: a row's optional `fmt` formats numbers (windowScale "%.2fx" → "1.00x"); booleans
-- render true/false; a table setting renders as a sorted {a, b} of its present keys, or "(none)".
function Sl.FormatSchemaValue(row, v)
  if v == nil then return "nil" end
  if row and row.fmt and type(v) == "number" then return row.fmt:format(v) end
  if row and row.type == "boolean" then return v and "true" or "false" end
  if row and row.type == "table" then
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k, on in pairs(v) do if on then keys[#keys + 1] = tostring(k) end end
    table.sort(keys)
    if #keys == 0 then return "(none)" end
    return "{" .. table.concat(keys, ", ") .. "}"
  end
  return tostring(v)
end

-- The shared coloured `key = value` line — gold key, white value, ` = ` left default — reused by
-- the list rows and the get/set echo so the colouring can't drift (slash-commands-§5).
function Sl.FormatKV(path, valueStr)
  return ("|cffffff00%s|r = |cffffffff%s|r"):format(tostring(path), tostring(valueStr))
end

-- The declared group order for `/bl list` (slash-commands-§5's "stable, declared page order").
-- Bank Ledger's schema groups are its panel section headers, which stand in for the standard's
-- `[page]` headers; any group not named here is appended in first-seen order.
--
-- These are SCHEMA GROUP NAMES and must match them exactly. The old value named "Window", a group
-- that no longer exists, and omitted "Master Controls" — so every name in it was inert and the
-- listing silently fell through to first-seen order (F-007). Exposed on NS.Slash so a test can
-- assert each name still resolves, because a name that matches nothing fails invisibly.
local LIST_GROUP_ORDER = { "Master Controls", "Capture" }
Sl.LIST_GROUP_ORDER = LIST_GROUP_ORDER

-- Build the `/bl list` lines (tag-less content; CliList prints each through NS.Print, which
-- prepends the cyan tag) as a pure array, so the output shape is unit-testable without capturing
-- chat. Header green, [group] headers azure, value rows via FormatKV — two-space indent on group
-- headers, four-space on value rows (slash-commands-§5).
function Sl:BuildListLines()
  local lines = { "|cff33ff99Available settings|r" }

  local byGroup, seenOrder = {}, {}
  for _, row in ipairs(NS.Schema.Schema) do
    local g = row.group or "?"
    if not byGroup[g] then byGroup[g] = {}; seenOrder[#seenOrder + 1] = g end
    byGroup[g][#byGroup[g] + 1] = row
  end

  local emitted = {}
  local function emit(g)
    if emitted[g] or not byGroup[g] then return end
    emitted[g] = true
    lines[#lines + 1] = "  |cff3399ff[" .. g .. "]|r"
    for _, row in ipairs(byGroup[g]) do
      local v = NS.Schema:Get(row.path)
      lines[#lines + 1] = "    " .. Sl.FormatKV(row.path, Sl.FormatSchemaValue(row, v))
    end
  end

  for _, g in ipairs(LIST_GROUP_ORDER) do emit(g) end
  for _, g in ipairs(seenOrder) do emit(g) end
  return lines
end

function Sl:CliList()
  for _, line in ipairs(Sl:BuildListLines()) do print(line) end
end

function Sl:CliGet(arg)
  local path = (strtrim and strtrim(tostring(arg or "")) or tostring(arg or "")):match("^(%S+)")
  if not path then
    print("Usage: /bl get <path>")
    return
  end
  local row = NS.Schema:FindRow(path)
  if not row then
    print("Setting not found: " .. path)
    return
  end
  print(Sl.FormatKV(path, Sl.FormatSchemaValue(row, NS.Schema:Get(path))))
end

function Sl:CliSet(arg)
  local path, raw = tostring(arg or ""):match("^(%S+)%s+(.+)$")
  if not path then
    print("Usage: /bl set <path> <value>  (try /bl list)")
    return
  end
  local row = NS.Schema:FindRow(path)
  if not row then
    print("Setting not found: " .. path)
    return
  end
  local value = raw
  if row.type == "number" then
    value = tonumber(raw)
    if not value then print("expected a number"); return end
  elseif row.type == "boolean" then
    value = (raw == "true" or raw == "1" or raw == "on" or raw == "yes")
  end
  local ok, err = NS.Schema:Set(path, value)
  if ok then
    -- Read back the STORED value so the echo reflects any clamping or coercion (slash-commands-§5).
    print(Sl.FormatKV(path, Sl.FormatSchemaValue(row, NS.Schema:Get(path))))
  else
    print("error: " .. tostring(err))
  end
end

-- `/bl version` → the canonical single-line answer every Ka0s addon shares (slash-commands-§3).
-- Read from the TOC metadata so it can't drift from the packaged manifest, with the in-code
-- constant as the fallback.
-- The addon's version, resolved once. The TOC's ## Version is the truth; NS.version is the fallback
-- for builds where the metadata API is unavailable. `/bl version` and the help header both come
-- through here, so they cannot report different numbers (F-017).
function Sl:Version()
  return (NS.Compat and NS.Compat.GetAddOnMetadata
    and NS.Compat.GetAddOnMetadata(NS.name, "Version")) or NS.version or "?"
end

function Sl:CliVersion()
  print("v" .. tostring(Sl:Version()))
end

function Sl:CliReset(arg)
  local path = arg and tostring(arg):match("^%S+") or nil
  if not path then print("Usage: /bl reset <path>"); return end
  local row = NS.Schema:FindRow(path)
  local def = NS.Schema:Default(path)
  if not row or def == nil then print("Setting not found: " .. tostring(path)); return end
  NS.Schema:Set(path, def)
  -- Echoed through the shared formatter so a table default reads "(none)", not a raw table pointer.
  print(path .. " reset to " .. Sl.FormatSchemaValue(row, def))
end

-- Reset every user setting to its default. Covers the schema rows AND the two item-id filter lists
-- — the lists are user-configured settings even though they are a storage carve-out with no Schema
-- widget. Non-destructive: the ledger and the window geometry are left alone (the confirm-gated
-- Sl:ResetEverything handles those).
function Sl:CliResetAll()
  for _, row in ipairs(NS.Schema.Schema) do
    NS.Schema:Set(row.path, row.default)
  end
  if NS.Filters and NS.Filters.ClearAll then NS.Filters:ClearAll() end
  print("all settings reset to defaults")
end
