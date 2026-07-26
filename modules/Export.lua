local addonName, NS = ...   -- luacheck: ignore addonName
NS.Export = NS.Export or {}
local E = NS.Export
local C = NS.Constants

-- ── Serialization ───────────────────────────────────────────────────────────────
-- Pure, unit-tested helpers (CSV text). The modal UI below consumes them; it needs the live client,
-- so it is smoke-tested rather than unit-tested. Export is called directly by the Browser
-- (NS.Export:Open) — it registers no bus message.

-- RFC-4180 field quoting: wrap on comma/quote/CR/LF; double any embedded quote.
local function csvField(v)
  if v == nil then return "" end
  local s = tostring(v)
  if s:find('[,"\r\n]') then s = '"' .. s:gsub('"', '""') .. '"' end
  return s
end

-- Ledger CSV columns: { header, value(entry) }. `ts` is followed by human `date` and `time`.
-- Renamed raw columns carry a *Raw suffix beside a human sibling — human `quality` (label) before
-- `qualityRaw` (number), human `value` ("Ng Ns Nc") before `valueRaw` (copper) — so a spreadsheet
-- can sort on the raw number while a reader sees the readable form. `net` is the direction-signed
-- value: positive means it went into the store.
-- itemLink / mapID / subzone are intentionally not exported.
local COLUMNS = {
  { "ts",           function(e) return e.ts end },
  { "date",         function(e) return NS.Util.FormatDate(e.ts) end },
  { "time",         function(e) return NS.Util.FormatClock(e.ts) end },
  { "char",         function(e) return e.char end },
  { "classFile",    function(e) return e.classFile end },
  { "direction",    function(e) return C.DirectionLabel[e.direction] or e.direction end },
  { "store",        function(e) return C.StoreLabel[e.store] or e.store end },
  { "storeRaw",     function(e) return e.store end },
  { "guild",        function(e) return e.guild end },
  { "kind",         function(e) return C.KindLabel[e.kind] or e.kind end },
  { "itemID",       function(e) return e.itemID end },
  { "itemName",     function(e) return e.itemName end },
  { "quality",      function(e) return e.quality ~= nil and NS.Compat.QualityLabel(e.quality) or "" end },
  { "qualityRaw",   function(e) return e.quality end },
  { "itemType",     function(e) return e.itemType end },
  { "itemSubType",  function(e) return e.itemSubType end },
  { "quantity",     function(e) return e.quantity end },
  { "vendorPrice",  function(e) return NS.Util.PlainMoney(e.vendorPrice) end },
  { "value",        function(e) return NS.Util.PlainMoney(NS.Util.EntryValue(e)) end },
  { "valueRaw",     function(e) return NS.Util.EntryValue(e) end },
  { "net",          function(e) return NS.Util.SignedValue(e) end },
  { "zone",         function(e) return e.zone end },
}
local HEADER = {}
for i, c in ipairs(COLUMNS) do HEADER[i] = c[1] end

E.COLUMNS = COLUMNS
E.HEADER = HEADER

-- Serialize entries against a column set to a CSV string (header + one row each, CRLF-terminated).
local function serializeCSV(entries, columns, header)
  local lines = { table.concat(header, ",") }
  for _, e in ipairs(entries or {}) do
    local cells = {}
    for i, c in ipairs(columns) do cells[i] = csvField(c[2](e)) end
    lines[#lines + 1] = table.concat(cells, ",")
  end
  return table.concat(lines, "\r\n") .. "\r\n"
end

-- Full CSV dump of the ledger rows.
function E:CSV(entries)
  return serializeCSV(entries, COLUMNS, HEADER)
end

-- ── Insights CSV ────────────────────────────────────────────────────────────────
-- The Insights tab's Export produces an ANALYTICS csv — a flat, sectioned dump mirroring the
-- Insights view (summary cards + each breakdown + the ranked list) rather than raw ledger rows.
-- Columns: Section, Label, Count, Value. Pure — takes a Database:Stats result, returns text.

-- Count-map → array of { label, count, value } sorted count-desc then label-asc. `labelOf` maps a
-- raw key to a display label; `valueMap` (optional) supplies the value column per key.
local function rankedRows(map, labelOf, valueMap)
  local rows = {}
  for key, count in pairs(map or {}) do
    rows[#rows + 1] = { label = labelOf and labelOf(key) or tostring(key),
      count = count, value = valueMap and valueMap[key] or nil }
  end
  table.sort(rows, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return tostring(a.label) < tostring(b.label)
  end)
  return rows
end

function E:InsightsCSV(stats)
  stats = stats or {}
  local t = stats.totals or {}
  local lines = { "Section,Label,Count,Value" }
  local function row(section, label, count, valueCopper)
    lines[#lines + 1] = table.concat({
      csvField(section), csvField(label),
      count ~= nil and csvField(count) or "",
      valueCopper ~= nil and csvField(NS.Util.PlainMoney(valueCopper)) or "",
    }, ",")
  end
  local function section(name, rows)
    for _, r in ipairs(rows) do row(name, r.label, r.count, r.value) end
  end

  -- Summary (the stat cards).
  row("Summary", "Movements", t.entries or 0)
  row("Summary", "Distinct items", t.distinctItems or 0)
  row("Summary", "Characters", t.distinctChars or 0)
  row("Summary", "Items deposited", t.itemsDeposited or 0)
  row("Summary", "Items withdrawn", t.itemsWithdrawn or 0)
  row("Summary", "Net items", t.netItems or 0)
  row("Summary", "Gold in", nil, t.moneyIn or 0)
  row("Summary", "Gold out", nil, t.moneyOut or 0)
  row("Summary", "Net gold", nil, t.netMoney or 0)
  row("Summary", "Gold moved", nil, t.moneyMoved or 0)
  row("Summary", "Value moved", nil, t.totalValue or 0)
  row("Summary", "Active days", t.activeDays or 0)
  if t.firstTs and t.lastTs then
    row("Summary", "Date range",
      NS.Util.FormatDate(t.firstTs) .. " to " .. NS.Util.FormatDate(t.lastTs))
  end
  if t.busiestDay then
    row("Summary", "Busiest day", t.busiestDay.day .. " (" .. t.busiestDay.count .. ")")
  end

  local storeLabel = function(k) return C.StoreLabel[k] or k end
  section("By Store", rankedRows(stats.byStore, storeLabel, stats.valueByStore))
  -- Net flow per store: signed, so a store you keep draining reads negative.
  for _, s in ipairs(C.StoreOrder) do
    local net = (stats.netByStore or {})[s]
    if net ~= nil then row("Net by Store", storeLabel(s), nil, net) end
  end
  -- Gross coin moved per store, beside the value figures above.
  for _, s in ipairs(C.StoreOrder) do
    local amount = (stats.moneyByStore or {})[s]
    if amount ~= nil then row("Money By Store", storeLabel(s), nil, amount) end
  end
  section("By Direction", rankedRows(stats.byDirection, function(k) return C.DirectionLabel[k] or k end))
  section("By Kind", rankedRows(stats.byKind, function(k) return C.KindLabel[k] or k end))
  section("By Item Type", rankedRows(stats.byItemType))
  section("By Sub-type", rankedRows(stats.byItemSubType))

  -- Quality in ASCENDING quality order rather than by count: Poor→Legendary is the meaningful
  -- ordering, and a spreadsheet reader gets it for free that way.
  local qualityIDs = {}
  for q in pairs(stats.byQuality or {}) do qualityIDs[#qualityIDs + 1] = q end
  table.sort(qualityIDs)
  for _, q in ipairs(qualityIDs) do
    row("By Quality", NS.Compat.QualityLabel(q), stats.byQuality[q])
  end

  section("By Zone", rankedRows(stats.byZone))

  local charRows = {}
  for _, ce in pairs(stats.byChar or {}) do
    charRows[#charRows + 1] = { label = ce.char, count = ce.count, value = ce.value }
  end
  table.sort(charRows, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return tostring(a.label) < tostring(b.label)
  end)
  section("By Character", charRows)

  -- The item index, ranked three ways — the same three lists the Insights panel shows, so an export
  -- answers "what moved most", "what was worth most" and "what moved in bulk" without re-sorting.
  local function itemName(it) return it.itemName or ("item " .. tostring(it.itemID)) end
  for _, it in ipairs(stats.topItems or {}) do
    row("Top Items", itemName(it), it.moves, it.value)
  end
  for _, it in ipairs(stats.topItemsByValue or {}) do
    row("Top Items By Value", itemName(it), it.moves, it.value)
  end
  for _, it in ipairs(stats.topItemsByQuantity or {}) do
    row("Top Items By Quantity", itemName(it), it.quantity, it.value)
  end

  -- Per-day activity, chronological. `value` is the vendor value moved; the coin column follows in
  -- its own section so a day's gold traffic is separable from its item traffic.
  local dayKeys = {}
  for day in pairs(stats.byDay or {}) do dayKeys[#dayKeys + 1] = day end
  table.sort(dayKeys)
  for _, day in ipairs(dayKeys) do
    row("By Day", day, stats.byDay[day], (stats.valueByDay or {})[day] or 0)
  end
  local moneyDays = {}
  for day in pairs(stats.moneyByDay or {}) do moneyDays[#moneyDays + 1] = day end
  table.sort(moneyDays)
  for _, day in ipairs(moneyDays) do
    row("Gold By Day", day, nil, stats.moneyByDay[day])
  end

  -- When the banking happens. Fixed 24-hour and Sunday-first weekday grids rather than only the
  -- buckets that fired, so an empty hour reads as a quiet hour instead of a missing row.
  for h = 0, 23 do
    row("By Hour", ("%02d:00"):format(h), (stats.byHour or {})[h] or 0)
  end
  local WEEKDAY = { [0] = "Sunday", [1] = "Monday", [2] = "Tuesday", [3] = "Wednesday",
                    [4] = "Thursday", [5] = "Friday", [6] = "Saturday" }
  for d = 0, 6 do
    row("By Weekday", WEEKDAY[d], (stats.byWeekday or {})[d] or 0)
  end

  return table.concat(lines, "\r\n") .. "\r\n"
end

-- ── Export modal ────────────────────────────────────────────────────────────────
-- A small skinned window: a Data Set selector (All Data / Current View) plus an Export-to-CSV
-- button. Reuses the Browser's flat skin and close glyph.
local WHITE = "Interface\\Buttons\\WHITE8X8"
local frame, copyFrame
-- Per-open config: { title, providers = { allData, currentView }, csv = function(dataset) }.
local config = {}
local dataset = "allData"

-- Centre a popup on the ledger window (falling back to the screen when it isn't built/shown).
local function centerOnBrowser(f)
  f:ClearAllPoints()
  local win = NS.Browser and NS.Browser.GetWindow and NS.Browser:GetWindow()
  if win and win:IsShown() then
    f:SetPoint("CENTER", win, "CENTER", 0, 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

local function EnsureCopyFrame()
  if copyFrame then return copyFrame end
  copyFrame = CreateFrame("Frame", "BankLedgerExportCopyWindow", UIParent, "BackdropTemplate")
  copyFrame:SetSize(640, 420)
  copyFrame:SetPoint("CENTER")
  copyFrame:SetFrameStrata("FULLSCREEN")
  copyFrame:EnableMouse(true)
  copyFrame:SetMovable(true)
  copyFrame:SetClampedToScreen(true)

  local tbar = CreateFrame("Frame", nil, copyFrame)
  tbar:SetPoint("TOPLEFT", 1, -1); tbar:SetPoint("TOPRIGHT", -1, -1); tbar:SetHeight(26)
  tbar:EnableMouse(true); tbar:RegisterForDrag("LeftButton")
  tbar:SetScript("OnDragStart", function() copyFrame:StartMoving() end)
  tbar:SetScript("OnDragStop", function() copyFrame:StopMovingOrSizing() end)
  local t = tbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("CENTER"); t:SetText("Export \226\128\148 Ctrl+C, then Esc")
  copyFrame.title = t

  if NS.Browser and NS.Browser.MakeCloseButton then
    NS.Browser:MakeCloseButton(tbar, function() copyFrame:Hide() end)
      :SetPoint("RIGHT", tbar, "RIGHT", -6, 0)
  end

  local scroll = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -30); scroll:SetPoint("BOTTOMRIGHT", -28, 10)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetFont(NS.Constants.FONT_MONO, 10, "")
  edit:SetAutoFocus(false)
  edit:SetWidth(590)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); copyFrame:Hide() end)
  scroll:SetScrollChild(edit)
  copyFrame.scroll, copyFrame.edit = scroll, edit

  if NS.Browser and NS.Browser.ApplySkin then NS.Browser:ApplySkin(copyFrame) end
  -- Denser than the shared skin: CSV is dense monospace text, so the world behind must not bleed in.
  copyFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
  copyFrame:Hide()
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "BankLedgerExportCopyWindow")
  end
  return copyFrame
end

local function ShowCopy(text)
  local f = EnsureCopyFrame()
  centerOnBrowser(f)
  f.edit:SetWidth(f.scroll:GetWidth() > 0 and f.scroll:GetWidth() or 590)
  f.edit:SetText(text)
  f.edit:SetCursorPosition(0)
  f:Show(); f.edit:SetFocus(); f.edit:HighlightText()
end

-- The data for the current Data Set selection. An empty table when the provider is missing.
local function selectedData()
  local fn = config.providers and config.providers[dataset]
  return (fn and fn()) or {}
end

-- Flat-skin button matching the Browser bar buttons.
local function makeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width, 24)
  b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
                  insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  b:SetBackdropColor(0.1, 0.1, 0.12, 0.9)
  b:SetBackdropBorderColor(0.24, 0.24, 0.27, 0.9)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER"); fs:SetText(text)
  b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.82, 0) end)
  b:SetScript("OnLeave", function() fs:SetTextColor(1, 1, 1) end)
  b:SetScript("OnClick", onClick)
  return b
end

local DATASET_OPTIONS = {
  { value = "allData", label = "All Data" },
  { value = "currentView", label = "Current View" },
}
local function datasetLabel(v)
  for _, o in ipairs(DATASET_OPTIONS) do if o.value == v then return o.label end end
  return v
end

local function EnsureFrame()
  if frame then return frame end
  frame = CreateFrame("Frame", "BankLedgerExportWindow", UIParent, "BackdropTemplate")
  frame:SetSize(372, 150)
  frame:SetPoint("CENTER")
  -- DIALOG (below the dropdown menu's FULLSCREEN catcher) so an outside click closes the Data Set
  -- menu; the copy window (FULLSCREEN) still opens above this modal.
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true); frame:SetMovable(true); frame:SetClampedToScreen(true)

  local tbar = CreateFrame("Frame", nil, frame)
  tbar:SetPoint("TOPLEFT", 1, -1); tbar:SetPoint("TOPRIGHT", -1, -1); tbar:SetHeight(26)
  tbar:EnableMouse(true); tbar:RegisterForDrag("LeftButton")
  tbar:SetScript("OnDragStart", function() frame:StartMoving() end)
  tbar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
  local t = tbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("CENTER"); t:SetText("Export")
  frame.titleFS = t
  if NS.Browser and NS.Browser.MakeCloseButton then
    NS.Browser:MakeCloseButton(tbar, function() frame:Hide() end)
      :SetPoint("RIGHT", tbar, "RIGHT", -6, 0)
  end

  local ds = NS.Browser:MakeDropdown(frame, 148)
  ds:SetHeight(24)
  ds:ClearAllPoints()
  ds:SetPoint("TOPLEFT", 16, -40)
  ds:SetPoint("TOPRIGHT", -16, -40)
  ds:SetOptions(DATASET_OPTIONS)
  ds:SetValue(dataset, "Data set: " .. datasetLabel(dataset))
  ds.onSelect = function(v)
    dataset = v
    ds:SetValue(v, "Data set: " .. datasetLabel(v))
  end

  local csvBtn = makeButton(frame, "Export to CSV", 150, function()
    local serialize = config.csv or function(d) return E:CSV(d) end
    ShowCopy(serialize(selectedData()))
  end)
  csvBtn:SetPoint("TOPLEFT", 16, -80)
  csvBtn:SetPoint("TOPRIGHT", -16, -80)

  if NS.Browser and NS.Browser.ApplySkin then NS.Browser:ApplySkin(frame) end
  frame:Hide()
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "BankLedgerExportWindow")
  end
  return frame
end

-- Build (once) and show the export modal for the given config. `cfg.title` is the header the
-- invoking tab supplies; `cfg.providers` feeds the Data Set dropdown; `cfg.csv` serializes the
-- selected dataset. Always re-centres on the ledger window.
function E:Open(cfg)
  config = cfg or {}
  local f = EnsureFrame()
  if f.titleFS then f.titleFS:SetText(config.title or "Export") end
  centerOnBrowser(f)
  f:Show()
end
