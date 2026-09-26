local _, NS = ...
NS.Diagnostics = NS.Diagnostics or {}
local X = NS.Diagnostics

-- modules/Diagnostics.lua — the sections of `/bl diagnostics` (debug-logging-§14, DX-BL).
--
-- THE LIBRARY OWNS THE REPORT, THIS FILE OWNS ITS CONTENT. LibKa0s-DebugLog-1.0's helper
-- (DebugLogDiagnostics.lua) writes the begin marker, the identity header (the [Init] summary, the
-- client build, the locale, the debug flag, the combat reads and the running LibKa0s minors), runs
-- each section below under its own pcall, applies the cap and writes the end marker. The console
-- descriptor in core/DebugLogSetup.lua hands it `X:Sections()`, called each time a report runs.
-- Nothing here builds a line buffer, a marker or a pcall wrapper of its own (anti-pattern #90).
--
-- READ-ONLY, AND THAT IS THE WHOLE CONTRACT. No section takes or releases a Lifecycle hold,
-- registers an event, arms a timer, writes a setting, asks the server for anything
-- (QueryGuildBankTab is a request, so the guild-bank tab counts are the client's cache and are
-- labeled so when the frame is shut), or calls Clear(). The report runs while the addon is
-- disabled, so every section reads state that may be released, and the two that describe runtime
-- machinery say they are stood down rather than print an idle engine as if it were a healthy one.
--
-- SECRET-SAFE BY ROUTE. Every value reaches a line as an argument of `out:add`, which stringifies
-- it through the console's SafeToString before any format sees it. Nothing here concatenates,
-- compares or adds a value read from the ledger or the client without `out:readable` first.
--
-- The report body is English diagnostic text and does not go through NS.L, like every trace line.

local LIST_CAP = 40   -- ids per filter list (the helper's default, spelled here for the reader)
local TAIL = 20       -- the newest ledger entries the report lists

-- The addons that replace or reskin the bank frames. A loaded one is the first suspect when a
-- visit records nothing: BankLedger reads the client's containers, but some of these hide or delay
-- the Blizzard frames whose open and close this addon keys its session on.
local BANK_ADDONS = {
  "ArkInventory", "AdiBags", "Baganator", "Bagnon", "BetterBags", "Combuctor", "ElvUI",
  "LiteBag", "OneBag3", "OneBank3",
}

-- The capture-critical rows, printed whatever their value (DX-BL's always-print set).
local ALWAYS = {
  "settings.enabled", "settings.trackItems", "settings.trackMoney", "settings.qualityThreshold",
  "settings.excludedStores", "settings.retentionDays",
}

local function yn(v) return v and "yes" or "no" end

local function global()
  return NS.db and NS.db.global or {}
end

-- ── state ──────────────────────────────────────────────────────────────────────────────────

local function testMode()
  local LT = NS.LedgerTable
  return (LT and LT.IsTestMode and LT:IsTestMode()) and true or false
end

function X.State(out)
  local g = global()
  out:add("State", "stored enabled=%s disabled=%s stood down=%s",
    NS.EnabledStored and NS.EnabledStored(), NS.IsDisabled and NS.IsDisabled(),
    NS.IsStoodDown and NS.IsStoodDown())
  out:joined("State", "holds:", NS.Lifecycle and NS.Lifecycle:Holds() or {})
  out:add("State", "schema stored=%s code=%s profile=account-wide", g.schemaVersion,
    NS.SCHEMA_VERSION)
  local st = NS.State or {}
  out:add("State", "test mode=%s sample rows=%s", testMode(),
    type(st.testRecords) == "table" and #st.testRecords or 0)
  out:add("State", "retention prune: done this session=%s armed=%s", yn(st.cleanupDone),
    yn(st.cleanupPending ~= nil))
end

-- ── settings ───────────────────────────────────────────────────────────────────────────────

--- The set-typed row (`settings.excludedStores`) as its members, the way `/bl get` renders it;
--- every other value as itself.
local function formatValue(row, v)
  if row and row.type == "table" and type(v) == "table" then
    local keys = {}
    for k, on in pairs(v) do
      if on then keys[#keys + 1] = tostring(k) end
    end
    table.sort(keys)
    if #keys == 0 then return "(none)" end
    return "{" .. table.concat(keys, ", ") .. "}"
  end
  return v
end

function X.Settings(out)
  local R, S = NS.SchemaRuntime, NS.Schema
  local rows = R and R.AllRows and R.AllRows() or (S and S.Schema) or {}
  local n = out:nonDefaults(rows, function(row) return S:Get(row.path) end, nil, formatValue,
    { always = ALWAYS, tag = "Set" })
  out:add("Set", "%s row(s) printed: the capture-critical six always, the rest only when changed", n)
end

-- ── filters ────────────────────────────────────────────────────────────────────────────────

function X.Filters(out)
  local F = NS.Filters
  if not F then return out:add("Filter", "filters module not loaded") end
  local lists = { { "blacklist", F:Blacklist() }, { "whitelist", F:Whitelist() } }
  for _, pair in ipairs(lists) do
    local ids = F:SortedIDs(pair[2])
    out:list("Filter", ("%s (%d):"):format(pair[1], #ids), ids, LIST_CAP)
  end
end

-- ── the ledger ─────────────────────────────────────────────────────────────────────────────

local function tally(map, key)
  if key == nil then key = "nil" end
  map[key] = (map[key] or 0) + 1
end

--- `key=count` pairs in the order of their rendered keys, so a secret key sorts as `<secret>`.
local function pairsOf(out, map)
  local parts = {}
  for key, n in pairs(map) do parts[#parts + 1] = out:str(key) .. "=" .. n end
  table.sort(parts)
  return parts
end

local function stamps(out, ledger)
  local oldest, newest
  for _, e in ipairs(ledger) do
    local ts = e.ts
    if out:readable(ts) then
      if oldest == nil or ts < oldest then oldest = ts end
      if newest == nil or ts > newest then newest = ts end
    end
  end
  out:add("Ledger", "oldest ts=%s", oldest or "-")
  out:add("Ledger", "newest ts=%s", newest or "-")
end

local function tail(out, ledger)
  local first = math.max(1, #ledger - TAIL + 1)
  out:add("Ledger", "last %s entries (stored fields, links not printed):", #ledger - first + 1)
  for i = first, #ledger do
    local e = ledger[i]
    out:add("Ledger", "  #%s ts=%s %s %s %s x%s id=%s %s char=%s", i, e.ts, e.store, e.direction,
      e.kind, e.quantity, e.itemID or "-", out:plain(e.itemName), e.char)
  end
end

function X.Ledger(out)
  local g = global()
  local ledger = type(g.ledger) == "table" and g.ledger or {}
  local byStore, byDir, byKind = {}, {}, {}
  for _, e in ipairs(ledger) do
    tally(byStore, e.store); tally(byDir, e.direction); tally(byKind, e.kind)
  end
  out:add("Ledger", "entries=%s (the live ledger, whatever test mode shows)", #ledger)
  out:joined("Ledger", "by store:", pairsOf(out, byStore))
  out:joined("Ledger", "by direction:", pairsOf(out, byDir))
  out:joined("Ledger", "by kind:", pairsOf(out, byKind))
  stamps(out, ledger)
  local s = g.settings or {}
  out:add("Ledger", "retention=%s day(s) (0 keeps everything)", s.retentionDays)
  tail(out, ledger)
end

-- ── the capture engine and the banking session ─────────────────────────────────────────────

local function snapshotLine(out, snap)
  local L = NS.Ledger
  local parts = { ("bags %s kinds"):format(L.CountKinds(snap.bags)) }
  local stores = {}
  for store in pairs(snap.stores or {}) do stores[#stores + 1] = tostring(store) end
  table.sort(stores)
  for _, store in ipairs(stores) do
    parts[#parts + 1] = ("%s %s kinds"):format(store, L.CountKinds(snap.stores[store]))
  end
  out:add("Capture", "snapshot: %s, money %s", table.concat(parts, ", "), snap.money)
end

function X.Capture(out)
  if NS.IsStoodDown and NS.IsStoodDown() then
    return out:add("Capture", "stood down: the capture engine is released (no events, no context)")
  end
  local L, st = NS.Ledger, NS.State or {}
  out:add("Capture", "openContext=%s snapshot=%s", st.openContext, yn(st.lastSnapshot))
  if type(st.lastSnapshot) == "table" then snapshotLine(out, st.lastSnapshot) end
  out:add("Capture", "settle pending=%s debounce armed=%s", yn(L._settleSince ~= nil),
    yn(L._pendingTimer ~= nil))
  local gate = L:GateState()
  out:add("Capture", "gate: enabled=%s trackItems=%s trackMoney=%s quality=%s", gate.enabled,
    gate.trackItems, gate.trackMoney, gate.quality)
  out:joined("Capture", "gate excluded stores:", gate.excluded)
  out:add("Capture", "gate filter sizes: blacklist=%s whitelist=%s", gate.blacklist,
    gate.whitelist)
end

function X.Session(out)
  if NS.IsStoodDown and NS.IsStoodDown() then
    return out:add("Session", "stood down: no banking session can open until the addon is enabled")
  end
  local st, SW = NS.State or {}, NS.SessionWindow or {}
  out:add("Session", "active=%s entries=%s preview=%s", st.sessionActive and true or false,
    type(st.sessionEntries) == "table" and #st.sessionEntries or 0,
    SW.previewSession and true or false)
end

-- ── the container model (`/bl debug scan`, folded in) ──────────────────────────────────────

function X.Scan(out)
  -- The guild bank's tab counts are what the client last cached. With the frame shut they are
  -- stale at best, and the report never queries the server to refresh them.
  if NS.Compat.IsGuildBankVisible() ~= true then
    out:add("Scan", "guild bank frame closed: the tab counts below are the client's cache, not fact")
  end
  for _, line in ipairs(NS.Ledger:Diagnose()) do out:add("Scan", "%s", line) end
end

-- ── windows, launcher, environment ─────────────────────────────────────────────────────────

local function geometry(g)
  if type(g) ~= "table" or not g.point then return "default" end
  return ("%s %s,%s %sx%s"):format(g.point, g.x, g.y, g.w, g.h)
end

local function windowLine(out, label, frame, stored)
  out:add("Window", "%s: built=%s shown=%s stored=%s", label, yn(frame),
    yn(frame and frame:IsShown()), geometry(stored))
end

function X.Windows(out)
  local s = global().settings or {}
  local B, SW = NS.Browser, NS.SessionWindow
  windowLine(out, "ledger", B and B.GetWindow and B:GetWindow(), s.window)
  windowLine(out, "session", SW and SW.GetWindow and SW:GetWindow(), s.sessionWindow)
  out:add("Window", "console: shown=%s scale=%s", yn(NS.DebugLog and NS.DebugLog:IsShown()),
    s.windowScale)
end

function X.Launcher(out)
  local LN, mm = NS.Launcher, global().minimap
  out:add("Launcher", "minimap shown=%s registered=%s degraded=%s angle=%s",
    LN and LN.IsShown and LN:IsShown(), LN and LN.IsRegistered and LN:IsRegistered(),
    yn(LN and LN.__degraded), type(mm) == "table" and mm.minimapPos or "-")
end

local function addonLoaded()
  local api = C_AddOns and C_AddOns.IsAddOnLoaded
  if type(api) ~= "function" then return nil end
  return api
end

function X.Environment(out)
  local api = addonLoaded()
  if not api then return out:add("Env", "bank-replacing addons loaded: unreadable (no API)") end
  local loaded = {}
  for _, name in ipairs(BANK_ADDONS) do
    local ok, on = pcall(api, name)
    if ok and on then loaded[#loaded + 1] = name end
  end
  out:joined("Env", "bank-replacing addons loaded:", loaded)
end

--- The sections, in report order. A fresh list each call: the helper runs whatever it is handed.
function X.Sections()
  return {
    { "state", X.State }, { "settings", X.Settings }, { "filters", X.Filters },
    { "ledger", X.Ledger }, { "capture", X.Capture }, { "session", X.Session },
    { "scan", X.Scan }, { "windows", X.Windows }, { "launcher", X.Launcher },
    { "environment", X.Environment },
  }
end
