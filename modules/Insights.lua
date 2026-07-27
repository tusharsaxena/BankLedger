local addonName, NS = ...   -- luacheck: ignore addonName
NS.Insights = NS.Insights or {}
local I = NS.Insights
local C = NS.Constants
local W = NS.InsightsWidgets

-- The Insights tab: a stat-card header, then a stack of breakdown sections, then ranked lists — all
-- computed off ONE Database:Stats pass over the SAME filter the ledger table uses, so the two views
-- can never disagree about which slice of the ledger they describe.
--
-- This file is about WHAT is shown: which breakdown, out of which Stats key, in which colour and in
-- which order. HOW it is drawn lives in modules/InsightsWidgets.lua.
--
-- A bank ledger measures FLOW, so the panel is organised around direction and store rather than
-- around a flat "count by category" list: the in/out split leads, and every breakdown that can be
-- split by direction carries a back-to-back companion answering "which way does this lean" — for a
-- store, a quality, an item type, a character.

local BAR_ROWS = 12          -- cap on a ranked bar list, so one section can't run off the page
local LIST_ROWS = 10         -- cap on a ranked list panel
local LIST_COLS = 3          -- All / Deposits / Withdrawals, side by side
local CARD_COLS = 4
local CARD_GAP, PAD = 8, 8
local EM_DASH = "\226\128\148"

-- ── Pure ranking helpers (unit-tested) ─────────────────────────────────────────

-- A count map → an array of { key, label, count, value } sorted count-desc, then label-asc so the
-- order is deterministic when counts tie. `limit` truncates (nil = keep everything).
function I.RankRows(map, labelOf, valueMap, limit)
  local rows = {}
  for key, count in pairs(map or {}) do
    rows[#rows + 1] = {
      key = key,
      label = labelOf and labelOf(key) or tostring(key),
      count = count,
      value = valueMap and valueMap[key] or nil,
    }
  end
  table.sort(rows, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return tostring(a.label) < tostring(b.label)
  end)
  if limit and #rows > limit then
    for i = #rows, limit + 1, -1 do rows[i] = nil end
  end
  return rows
end

-- The fraction (0..1) a row's count is of the largest count in the list — the bar fill. An empty
-- list, or one whose top count is 0, yields 0 rather than dividing by zero.
function I.BarFraction(rows, index)
  local top = rows and rows[1] and rows[1].count or 0
  local row = rows and rows[index]
  if not row or top <= 0 then return 0 end
  return row.count / top
end

-- A bar's final label string. `icon` is markup (a |T...|t texture escape) and is emitted WHOLE:
-- W.Truncate cuts on BYTES, so a cut that lands inside the escape breaks it and WoW renders the
-- raw texture path as text. Only the name is subject to the budget.
function I.BarLabel(row)
  local name = (W.Truncate(row.label, row.labelMax))
  return (row.icon or "") .. name
end

-- A chart element's hover tip: its FULL label and the figure it is showing. The element usually
-- prints that figure already, but the label beside it is often truncated to fit its column — the
-- tip is the one place the untruncated name and its number are guaranteed to appear together.
function I.ElementTip(label, value)
  label = tostring(label or "")
  if value == nil or value == "" then return label end
  return label .. ":  " .. tostring(value)
end

-- ── Stat cards ─────────────────────────────────────────────────────────────────
-- In display order, 4 per row; `wide` spans two columns. Every card shares one base headline font
-- and every card carries a tooltip: half of these are derived figures, and a bare number with a
-- two-word caption is a quiz, not an insight.

local CARD_DEFS = {
  { key = "movements", caption = "movements",
    tooltip = "Rows in the current slice — one per item stack or coin amount that crossed the line." },
  { key = "itemsIn", caption = "items deposited",
    tooltip = "Total stack count deposited into a bank from your bags." },
  { key = "itemsOut", caption = "items withdrawn",
    tooltip = "Total stack count withdrawn from a bank back into your bags." },
  { key = "netItems", caption = "net items",
    tooltip = "Items deposited minus items withdrawn. Positive means you are stockpiling." },
  { key = "distinctItems", caption = "distinct items",
    tooltip = "How many different items appear, however often each one moved." },
  { key = "chars", caption = "characters",
    tooltip = "How many of your characters appear in this slice." },
  { key = "activeDays", caption = "active days",
    tooltip = "Calendar days on which at least one movement happened." },
  { key = "topStore", caption = "top store",
    tooltip = "The store with the most movements in this slice." },
  { key = "itemsMoved", caption = "items moved",
    tooltip = "Every stack unit that crossed the line, in either direction: "
      .. "items deposited plus items withdrawn." },
  { key = "goldIn", caption = "gold deposited",
    tooltip = "Coin deposited into the guild and warband banks. The character bank has no coin slot." },
  { key = "goldOut", caption = "gold withdrawn",
    tooltip = "Coin withdrawn from the guild and warband banks." },
  { key = "netGold", caption = "net gold",
    tooltip = "Gold deposited minus gold withdrawn. Green means the banks gained; "
      .. "red means you drew down." },
  { key = "span", caption = "date range", wide = true,
    tooltip = "Earliest and latest movement in this slice." },
  { key = "busiest", caption = "busiest day", wide = true,
    tooltip = "The calendar day with the most movements, and how many." },
}

-- ── Section chrome ─────────────────────────────────────────────────────────────

local SECTION_TITLES = {
  split      = "Deposits vs Withdrawals",
  store      = "Movements By Store",
  char       = "Movements By Character",
  -- Every companion mirrors its parent chart's full title, so a companion scrolled past on its
  -- own still says what it is a companion TO.
  charStore  = "Movements By Character \195\151 Store",
  charDir    = "Movements By Character \195\151 Deposits/Withdrawals",
  quality    = "Movements By Quality",
  itemType   = "Movements By Item Type",
  subType    = "Movements By Sub-type",
  storeDir   = "Movements By Store \195\151 Deposits/Withdrawals",
  qualityDir = "Movements By Quality \195\151 Deposits/Withdrawals",
  itemTypeDir= "Movements By Item Type \195\151 Deposits/Withdrawals",
  subTypeDir = "Movements By Sub-type \195\151 Deposits/Withdrawals",
  perDay     = "Movements Over Time (Per Day)",
  hour       = "Movements By Hour Of Day",
  weekday    = "Movements By Weekday",
  goldDay    = "Gold Moved Over Time (Per Day)",
  goldStore  = "Gold By Store",
}

local POOL_KEYS = {
  "store", "char", "quality", "itemType", "subType",
  "weekday", "goldStore", "charStore", "charDir", "perDay", "hour", "goldDay",
  "listHead",
  "itemTypeLeg", "subTypeLeg", "charStoreLeg", "charDirLeg",
  "storeDir", "qualityDir", "itemTypeDir", "subTypeDir",
  "storeDirLeg", "qualityDirLeg", "itemTypeDirLeg", "subTypeDirLeg",
}

-- ── Build ──────────────────────────────────────────────────────────────────────

function I:Attach(pane)
  if self.pane then return end
  self.pane = pane

  local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -26, 4)
  self.scroll = scroll

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)
  self.content = content
  scroll:SetScript("OnSizeChanged", function() I:Layout() end)

  -- Cards: one frame each, created once and repainted. Not pooled — the set is fixed.
  self.cards = {}
  for _, def in ipairs(CARD_DEFS) do
    self.cards[def.key] = W.MakeCard(content)
  end

  -- Section headers, dividers, strips and list panels: persistent chrome, shown or hidden per pass.
  self.headers = {}
  for key, title in pairs(SECTION_TITLES) do
    self.headers[key] = W.MakeSectionHeader(content, title)
  end
  self.dividers = {
    items = W.MakeSectionDivider(content, "ITEMS & FLOW"),
    gold  = W.MakeSectionDivider(content, "GOLD"),
    top   = W.MakeSectionDivider(content, "TOP OF THE LIST"),
  }
  self.strips = {
    perDay   = CreateFrame("Frame", nil, content),
    hour     = CreateFrame("Frame", nil, content),
    goldDay  = CreateFrame("Frame", nil, content),
  }
  -- Ranked-list panels are POOLED, not fixed: the per-store lists vary in count and every panel
  -- takes its title per pass.
  self.panelPool = W.NewPool()
  self.ratioBar = W.MakeRatioBar(content)

  self.pools = {}
  for _, key in ipairs(POOL_KEYS) do self.pools[key] = W.NewPool() end

  self.emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
  self.emptyText:Hide()

  self:Refresh()
end

-- Which filter the view computes against: the browser's shared filter, so the Insights numbers and
-- the table rows always describe the same slice of the ledger.
local function currentFilter()
  if NS.Browser and NS.Browser.CurrentFilter then return NS.Browser:CurrentFilter() end
  return {}
end

-- Pure one-line summary for the [Insights] trace.
function I.SummaryLine(scope, count)
  return ("computed scope=%s, %s movements"):format(tostring(scope), tostring(count))
end

function I:Refresh()
  if not self.content then return end
  local filter = currentFilter()
  self.stats = NS.Database:Stats(filter)
  self:Layout()
  if NS.State.debug and NS.Debug then
    NS.Debug("Insights", "%s",
      I.SummaryLine(next(filter) and "filtered" or "all", (self.stats.totals or {}).entries or 0))
  end
end

-- ── Card values ────────────────────────────────────────────────────────────────

-- The display value for every card, out of a totals table. Pure and separated from the layout so the
-- formatting rules (what counts as "nothing", which figures are signed) are testable.
function I.CardValues(totals)
  local t = totals or {}
  local span = EM_DASH
  if t.firstTs and t.lastTs then
    -- \226\128\147 = en-dash, the range dash.
    span = NS.Util.FormatDate(t.firstTs) .. " \226\128\147 " .. NS.Util.FormatDate(t.lastTs)
  end
  return {
    movements     = tostring(t.entries or 0),
    itemsIn       = tostring(t.itemsDeposited or 0),
    itemsOut      = tostring(t.itemsWithdrawn or 0),
    netItems      = W.SignedCount(t.netItems or 0),
    distinctItems = tostring(t.distinctItems or 0),
    chars         = tostring(t.distinctChars or 0),
    activeDays    = tostring(t.activeDays or 0),
    topStore      = t.topStore and (C.StoreLabel[t.topStore.store] or t.topStore.store) or EM_DASH,
    itemsMoved    = tostring((t.itemsDeposited or 0) + (t.itemsWithdrawn or 0)),
    goldIn        = W.Money(t.moneyIn or 0),
    goldOut       = W.Money(t.moneyOut or 0),
    netGold       = W.SignedMoney(t.netMoney or 0),
    span          = span,
    busiest       = t.busiestDay
      and (t.busiestDay.day .. "  (" .. t.busiestDay.count .. ")") or EM_DASH,
  }
end

-- ── Shared key → display lookups ───────────────────────────────────────────────
-- Declared above the render helpers because those close over them; a local declared later would
-- resolve as a nil global at call time.

local function storeColor(key) return C.StoreRGB[key] or W.NEUTRAL end
local function storeLabel(key) return C.StoreLabel[key] or tostring(key) end
local function directionColor(key) return C.DirectionRGB[key] or W.NEUTRAL end
local function directionLabel(key) return C.DirectionLabel[key] or tostring(key) end

-- ── Render helpers ─────────────────────────────────────────────────────────────

-- A ranked horizontal-bar section. `rows` is an ordered array of
--   { label, fullLabel, labelColor, color, frac, value }
-- with `frac` relative to the largest row (normalized here, so callers can pass raw ratios).
-- Returns the new y cursor; an empty list hides the header and consumes no space.
function I:RenderBars(poolKey, headerKey, rows, y, w, legendPool)
  local header = self.headers[headerKey]
  if #rows == 0 then header:Hide(); return y end
  W.NormalizeFractions(rows)
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, y)
  header:Show()
  y = y - 18
  local innerW = w - PAD * 2
  for _, row in ipairs(rows) do
    local bar = W.Acquire(self.pools[poolKey], function() return W.MakeBar(self.content) end)
    local color = row.color or W.NEUTRAL
    bar.fill:SetColorTexture(color[1], color[2], color[3], 0.95)
    bar._tip = I.ElementTip(row.fullLabel or row.label, row.value)
    bar.label:SetText(I.BarLabel(row))
    -- The label defaults to its bar's colour, which makes a single bar self-legending.
    local lc = row.labelColor or color
    bar.label:SetTextColor(lc[1], lc[2], lc[3])
    bar.value:SetText(row.value or "")
    bar.value:SetTextColor(W.MUTED[1], W.MUTED[2], W.MUTED[3])
    W.PlaceBar(bar, self.content, PAD, y, innerW, row.frac)
    y = y - (W.BAR_H + W.BAR_GAP)
  end
  if legendPool then
    local legend = {}
    for _, row in ipairs(rows) do
      legend[#legend + 1] = { label = row.fullLabel or row.label, color = row.color or W.NEUTRAL }
    end
    return self:RenderLegend(legendPool, legend, y, w)
  end
  return y - W.SECTION_GAP
end

-- A per-row stacked-bar section (the "× Store" companion).
function I:RenderStacked(poolKey, headerKey, rows, y, w)
  local header = self.headers[headerKey]
  if #rows == 0 then header:Hide(); return y end
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, y)
  header:Show()
  y = y - 18
  local innerW = w - PAD * 2
  for _, row in ipairs(rows) do
    local bar = W.Acquire(self.pools[poolKey],
      function() return W.MakeStackedBar(self.content) end)
    bar._tip = I.ElementTip(row.fullLabel or row.label, row.value)
    bar.label:SetText((W.Truncate(row.label)))
    local lc = row.labelColor or W.MUTED
    bar.label:SetTextColor(lc[1], lc[2], lc[3])
    bar.value:SetText(row.value or "")
    bar.value:SetTextColor(W.MUTED[1], W.MUTED[2], W.MUTED[3])
    W.PlaceStackedBar(bar, self.content, PAD, y, innerW, row.segments)
    y = y - (W.BAR_H + W.BAR_GAP)
  end
  return y - W.SECTION_GAP
end

-- A back-to-back section: withdrawals grow left of a fixed centre axis, deposits grow right.
-- `rows` comes from W.BuildBackToBackRows, already scaled and sorted.
function I:RenderBackToBack(poolKey, headerKey, rows, y, w)
  local header = self.headers[headerKey]
  if #rows == 0 then header:Hide(); return y end
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, y)
  header:Show()
  y = y - 18
  local innerW = w - PAD * 2
  local leftColor = directionColor(C.Direction.WITHDRAW)
  local rightColor = directionColor(C.Direction.DEPOSIT)
  for _, row in ipairs(rows) do
    local bar = W.Acquire(self.pools[poolKey],
      function() return W.MakeBackToBackBar(self.content) end)
    bar._tip = I.ElementTip(row.fullLabel or row.label, row.value)
    bar.label:SetText(I.BarLabel(row))
    local lc = row.labelColor or W.MUTED
    bar.label:SetTextColor(lc[1], lc[2], lc[3])
    bar.value:SetText(row.value or "")
    bar.value:SetTextColor(W.MUTED[1], W.MUTED[2], W.MUTED[3])
    W.PlaceBackToBackBar(bar, self.content, PAD, y, innerW, row, leftColor, rightColor)
    y = y - (W.BAR_H + W.BAR_GAP)
  end
  return y - W.SECTION_GAP
end

-- A wrapped legend of colour-swatch chips, aligned under where the bars begin (not under the text
-- labels), so it reads as belonging to the track.
function I:RenderLegend(poolKey, rows, y, w)
  local x0 = PAD + W.LABEL_W + 6
  local chipW = 122
  local x, rowY = x0, y
  for _, row in ipairs(rows) do
    if x + chipW > w - PAD then x = x0; rowY = rowY - 16 end
    local chip = W.Acquire(self.pools[poolKey], function() return W.MakeSwatch(self.content) end)
    chip.sw:SetColorTexture(row.color[1], row.color[2], row.color[3], 0.95)
    chip._tip = row.label
    chip.fs:SetWidth(chipW - 16)
    chip.fs:SetText((W.Truncate(row.label, W.LEGEND_MAXCHARS)))
    chip:ClearAllPoints()
    chip:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, rowY)
    chip:SetWidth(chipW)
    x = x + chipW
  end
  return rowY - 16 - W.SECTION_GAP
end

-- A per-bucket vertical strip. `buckets` is ordered { magnitude, label, tip }.
function I:RenderStrip(poolKey, headerKey, strip, buckets, y, w)
  local header = self.headers[headerKey]
  if #buckets == 0 then header:Hide(); strip:Hide(); return y end
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, y)
  header:Show()
  y = y - 18
  local innerW = w - PAD * 2
  strip:ClearAllPoints()
  strip:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, y)
  strip:SetSize(innerW, W.STRIP_H)
  strip:Show()

  local slot, barW, stride = W.StripMetrics(#buckets, innerW)
  local peak = 1
  for _, b in ipairs(buckets) do
    if (b.magnitude or 0) > peak then peak = b.magnitude end
  end

  -- One axis line under the whole strip, separating the bars from their labels.
  strip.axisLine = strip.axisLine or strip:CreateTexture(nil, "ARTWORK")
  strip.axisLine:SetColorTexture(0.45, 0.45, 0.5, 0.8)
  strip.axisLine:ClearAllPoints()
  strip.axisLine:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, -W.STRIP_AXIS_GAP)
  strip.axisLine:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, -W.STRIP_AXIS_GAP)
  strip.axisLine:SetHeight(1)
  strip.axisLine:Show()

  for i, b in ipairs(buckets) do
    local f = W.Acquire(self.pools[poolKey], function() return W.MakeStripBar(strip) end)
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", (i - 1) * slot, 0)
    f:SetSize(barW, W.STRIP_H)
    local mag = b.magnitude or 0
    f.fill:SetSize(barW, math.max(1, (mag / peak) * (W.STRIP_H - 2)))
    -- An empty bucket keeps a ghost of a bar: it marks that the day existed and was quiet, which a
    -- gap of nothing cannot distinguish from a day that fell outside the range.
    f.fill:SetAlpha(mag == 0 and 0.12 or 0.9)
    f._tip = b.tip
    if b.label and ((i - 1) % stride == 0) then
      f.axis:SetText(b.label)
      -- Right-align the rotated label so labels of different lengths all start at the axis line and
      -- hang straight down from it.
      local tw = f.axis:GetStringWidth()
      if type(tw) ~= "number" then tw = 0 end
      f.axis:ClearAllPoints()
      f.axis:SetPoint("CENTER", f, "BOTTOMLEFT", barW / 2 - 2,
        -(tw / 2) - W.STRIP_AXIS_GAP - W.STRIP_LABEL_GAP)
      f.axis:Show()
    else
      f.axis:SetText("")
      f.axis:Hide()
    end
  end
  return y - W.STRIP_H - W.STRIP_LABEL_H - W.SECTION_GAP
end

-- A ranked list panel, acquired from the pool and titled per pass. `rows` is
-- { name, fullName, nameColor, right }. Returns the panel's height (0 when there is nothing to
-- show, so the caller can collapse the slot) so columns of differing lengths can be stacked.
function I:RenderList(title, rows, y, x, colW, rightW)
  local n = math.min(LIST_ROWS, #rows)
  if n == 0 then return 0 end
  local panel = W.Acquire(self.panelPool, function() return W.MakeListPanel(self.content) end)
  W.SetPanelTitle(panel, title)
  local panelH = 20 + n * W.LIST_ROW_H + 4
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
  panel:SetSize(colW, panelH)
  for i = 1, n do
    local row = rows[i]
    local r = W.Acquire(panel._rows, function() return W.MakeListRow(panel) end)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -20 - (i - 1) * W.LIST_ROW_H)
    r:SetWidth(colW - 8)
    r.name:SetWidth(math.max(1, colW - 8 - (rightW or 48) - 6))
    r.name:SetText(row.name)
    r._tip = I.ElementTip(row.fullName or row.name, row.right)
    local nc = row.nameColor or W.MUTED
    r.name:SetTextColor(nc[1], nc[2], nc[3])
    r.right:SetWidth(rightW or 48)
    r.right:SetText(row.right or "")
    r.right:SetTextColor(W.MUTED[1], W.MUTED[2], W.MUTED[3])
  end
  return panelH
end

-- A pooled sub-heading inside the Top Of The List section, so the groups can be named without a
-- fixed header per group.
function I:RenderSubHead(text, y, indent)
  local fs = W.Acquire(self.pools.listHead,
    function() return W.MakeSectionHeader(self.content, "") end)
  fs:SetText(text)
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD + (indent or 0), y)
  return y - 18
end

-- One row of up to LIST_COLS panels. `specs` is { title, rows, rightW }; an empty list simply
-- leaves its column blank. The row advances by its TALLEST panel so nothing overlaps.
function I:RenderListRow(specs, y, innerW)
  local gap = 12
  local colW = math.floor((innerW - gap * (LIST_COLS - 1)) / LIST_COLS)
  local tallest, col = 0, 0
  for _, spec in ipairs(specs) do
    if col >= LIST_COLS then
      y = y - tallest - W.SECTION_GAP
      tallest, col = 0, 0
    end
    local h = self:RenderList(spec.title, spec.rows, y, PAD + col * (colW + gap), colW, spec.rightW)
    if h > tallest then tallest = h end
    col = col + 1
  end
  if tallest == 0 then return y end
  return y - tallest - W.SECTION_GAP
end

-- ── Layout ─────────────────────────────────────────────────────────────────────

function I:HideAllSections()
  for _, h in pairs(self.headers) do h:Hide() end
  for _, s in pairs(self.strips) do s:Hide() end
  for _, d in pairs(self.dividers) do d:Hide() end
  self.ratioBar:Hide()
end

function I:Layout()
  if not self.content then return end
  local w = self.scroll:GetWidth()
  if type(w) ~= "number" or w <= 0 then w = 820 end
  self.content:SetWidth(w)

  for _, key in ipairs(POOL_KEYS) do W.ReleaseAll(self.pools[key]) end
  W.ReleasePanels(self.panelPool)

  local stats = self.stats or {}
  local totals = stats.totals or {}

  -- Cards paint even on an empty slice: "0 movements" is an answer, and a header that vanishes makes
  -- the panel look broken rather than empty.
  local colW = math.floor((w - PAD * 2 - CARD_GAP * (CARD_COLS - 1)) / CARD_COLS)
  local values = I.CardValues(totals)
  local col, rowY = 0, -PAD
  for _, def in ipairs(CARD_DEFS) do
    local span = def.wide and 2 or 1
    if col + span > CARD_COLS then col = 0; rowY = rowY - W.CARD_H - CARD_GAP end
    local card = self.cards[def.key]
    local cardW = colW * span + CARD_GAP * (span - 1)
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD + col * (colW + CARD_GAP), rowY)
    card:SetSize(cardW, W.CARD_H)
    W.SetCard(card, { caption = def.caption, value = values[def.key], tooltip = def.tooltip }, cardW)
    col = col + span
  end

  local y = rowY - W.CARD_H - 14

  if (totals.entries or 0) == 0 then
    self:HideAllSections()
    self.emptyText:SetText(next(currentFilter())
      and "No movements match your filters."
      or "No bank movements recorded yet. Open your bank and move something.")
    self.emptyText:ClearAllPoints()
    self.emptyText:SetPoint("TOP", self.content, "TOP", 0, y - 10)
    self.emptyText:Show()
    self.content:SetHeight(math.max(1, -y + 60))
    return
  end
  self.emptyText:Hide()

  y = self:LayoutSections(y, w, stats, totals)
  self.content:SetHeight(math.max(1, -y + PAD))
end

local function placeDivider(divider, content, y)
  divider:ClearAllPoints()
  divider:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, y)
  divider:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, y)
  divider:Show()
  return y - 30
end


-- A "<segment> x Deposits/Withdrawals" companion, drawn back to back, in the
-- direction colours, with a legend. `labelOf`/`labelColorOf` keep each row recognisable against
-- the parent chart it sits under.
function I:RenderDirectionSplit(poolKey, headerKey, legendKey, matrix, opts, y, w)
  if not next(matrix or {}) then
    self.headers[headerKey]:Hide()
    return y
  end
  -- Deposits right of the centre axis, withdrawals left of it. Both sides share one scale, so the
  -- split sits on the same vertical line in every row and the lean of the whole chart reads at a
  -- glance rather than row by row.
  local rows = W.BuildBackToBackRows(matrix, C.Direction.DEPOSIT, C.Direction.WITHDRAW, {
    labelOf = opts.labelOf, labelColorOf = opts.labelColorOf, valueFmt = tostring,
  })
  -- Each half's tip carries its share of THAT ROW's movements, not of the chart: the question a
  -- split bar raises is "how much of this store/quality/type went each way", and the percentage is
  -- what the eye cannot read off two bar lengths.
  for _, row in ipairs(rows) do
    row.rightTip = ("%s: %d (%d%%)"):format(
      directionLabel(C.Direction.DEPOSIT), row.rightMag, W.Percent(row.rightMag, row.total))
    row.leftTip = ("%s: %d (%d%%)"):format(
      directionLabel(C.Direction.WITHDRAW), row.leftMag, W.Percent(row.leftMag, row.total))
  end
  -- Cap at BAR_ROWS to match the parent bar chart above it: the rows are already sorted
  -- total-desc, so truncating after the sort keeps the largest.
  if #rows > BAR_ROWS then
    for i = #rows, BAR_ROWS + 1, -1 do rows[i] = nil end
  end
  y = self:RenderBackToBack(poolKey, headerKey, rows, y, w)
  -- Legend order follows the CHART left-to-right (withdraw, deposit), not C.DirectionOrder: a
  -- legend that reads in the opposite order to the thing it explains is a small lie.
  local legend = {}
  for _, key in ipairs({ C.Direction.WITHDRAW, C.Direction.DEPOSIT }) do
    legend[#legend + 1] = { label = directionLabel(key), color = directionColor(key) }
  end
  return self:RenderLegend(legendKey, legend, y, w)
end

function I:LayoutSections(y, w, stats, totals)
  local content, innerW = self.content, w - PAD * 2
  local total = totals.entries or 0

  y = placeDivider(self.dividers.items, content, y)

  -- 1 ── Deposits vs withdrawals, as one proportional bar. The question here is "what share", not
  -- "which is bigger", so a ratio bar answers it directly where two bars would not.
  local inCount = (stats.byDirection or {})[C.Direction.DEPOSIT] or 0
  local outCount = (stats.byDirection or {})[C.Direction.WITHDRAW] or 0
  if inCount + outCount > 0 then
    local header = self.headers.split
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, y)
    header:Show()
    y = y - 20
    local inFrac, outFrac = W.RatioShares(inCount, outCount)
    W.PlaceRatioBar(self.ratioBar, content, PAD, y, innerW,
      { frac = inFrac, color = directionColor(C.Direction.DEPOSIT),
        text = ("Deposits %d \194\183 %d%%"):format(inCount, W.Percent(inCount, total)),
        tip = ("Deposits: %d of %d movements"):format(inCount, total) },
      { frac = outFrac, color = directionColor(C.Direction.WITHDRAW),
        text = ("Withdrawals %d \194\183 %d%%"):format(outCount, W.Percent(outCount, total)),
        tip = ("Withdrawals: %d of %d movements"):format(outCount, total) })
    self.ratioBar:Show()
    y = y - W.RATIO_H - W.RATIO_CAPTION_H - W.SECTION_GAP
  else
    self.headers.split:Hide()
    self.ratioBar:Hide()
  end

  -- 2 ── Movements by store, in the shared store colours.
  local storeRows = {}
  for _, e in ipairs(W.SortedByCount(stats.byStore)) do
    storeRows[#storeRows + 1] = {
      label = storeLabel(e.key), color = storeColor(e.key), frac = e.count,
      value = ("%d  %d%%"):format(e.count, W.Percent(e.count, total)),
    }
  end
  y = self:RenderBars("store", "store", storeRows, y, w)
  y = self:RenderDirectionSplit("storeDir", "storeDir", "storeDirLeg", stats.storeByDirection,
    { labelOf = storeLabel, labelColorOf = storeColor }, y, w)

  -- 3 ── Movements by character, class-coloured and behind the class icon.
  local charRows = {}
  for _, ce in pairs(stats.byChar or {}) do
    if (ce.count or 0) > 0 then charRows[#charRows + 1] = ce end
  end
  table.sort(charRows, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.char < b.char
  end)
  local barCharRows = {}
  for i, ce in ipairs(charRows) do
    if i > BAR_ROWS then break end
    barCharRows[#barCharRows + 1] = {
      icon = NS.Util.ClassIconMarkup(ce.classFile), label = W.ShortChar(ce.char),
      -- 14, not the default 17: the class icon eats ~14px of the 118px label column.
      labelMax = 14,
      fullLabel = ce.char, color = W.ClassColor(ce.classFile),
      frac = ce.count, value = tostring(ce.count),
    }
  end
  y = self:RenderBars("char", "char", barCharRows, y, w)

  -- 5 ── Character × Store. Segment order follows the parent chart's order, so a store keeps the
  -- same position in every character's bar.
  local storeOrder = {}
  for _, e in ipairs(W.SortedByCount(stats.byStore)) do storeOrder[#storeOrder + 1] = e.key end
  local classOf = {}
  for ch, ce in pairs(stats.byChar or {}) do classOf[ch] = ce.classFile end
  y = self:RenderStacked("charStore", "charStore",
    W.BuildStackRows(stats.charByStore, storeOrder, {
      labelOf = W.ShortChar, colorOf = storeColor, catLabelOf = storeLabel,
      valueFmt = tostring,
      labelColorOf = function(ch) return W.ClassColor(classOf[ch]) end,
    }), y, w)
  if next(stats.charByStore or {}) then
    local legend = {}
    for _, key in ipairs(storeOrder) do
      legend[#legend + 1] = { label = storeLabel(key), color = storeColor(key) }
    end
    y = self:RenderLegend("charStoreLeg", legend, y, w)
  end

  -- 5 ── Movements By Character × Deposits/Withdrawals: who fills the bank and who empties it.
  -- Rendered through the same back-to-back path as every other direction companion, so all of
  -- them share one centre axis and one reading.
  y = self:RenderDirectionSplit("charDir", "charDir", "charDirLeg", stats.charByDirection,
    { labelOf = W.ShortChar,
      labelColorOf = function(ch) return W.ClassColor(classOf[ch]) end }, y, w)

  -- 7 ── Quality, in ASCENDING quality order (Poor→Legendary is meaningful; count-desc is not) and
  -- in the game's own quality colours, so the bars are self-legending.
  local qualityIDs = {}
  for q in pairs(stats.byQuality or {}) do qualityIDs[#qualityIDs + 1] = q end
  table.sort(qualityIDs)
  -- These rows are NOT in count order, so the largest bar is not row 1 — RenderBars normalizes
  -- against the true peak, not against the first row, which is what makes that safe.
  local qualityRows = {}
  for _, q in ipairs(qualityIDs) do
    local color = W.QualityColor(q)
    qualityRows[#qualityRows + 1] = { label = NS.Compat.QualityLabel(q), color = color,
      labelColor = color, frac = stats.byQuality[q], value = tostring(stats.byQuality[q]) }
  end
  y = self:RenderBars("quality", "quality", qualityRows, y, w)
  y = self:RenderDirectionSplit("qualityDir", "qualityDir", "qualityDirLeg",
    stats.qualityByDirection,
    { labelOf = NS.Compat.QualityLabel, labelColorOf = W.QualityColor }, y, w)

  -- 8/9 ── Item type and sub-type, from the categorical palette by rank, so adjacent bars are
  -- always dissimilar hues.
  local function paletteRows(map, poolKey, headerKey, legendKey, yy)
    local ranked = W.SortedByCount(map)
    local keys = {}
    for _, e in ipairs(ranked) do keys[#keys + 1] = e.key end
    local colors = W.PaletteMap(keys)
    local rows = {}
    for i, e in ipairs(ranked) do
      if i > BAR_ROWS then break end
      rows[#rows + 1] = { label = tostring(e.key), color = colors[e.key],
        frac = e.count, value = ("%d  %d%%"):format(e.count, W.Percent(e.count, total)) }
    end
    return self:RenderBars(poolKey, headerKey, rows, yy, w, legendKey), colors
  end
  local typeColors, subColors
  y, typeColors = paletteRows(stats.byItemType, "itemType", "itemType", "itemTypeLeg", y)
  y = self:RenderDirectionSplit("itemTypeDir", "itemTypeDir", "itemTypeDirLeg",
    stats.itemTypeByDirection,
    { labelOf = tostring, labelColorOf = function(k) return typeColors[k] end }, y, w)
  y, subColors = paletteRows(stats.byItemSubType, "subType", "subType", "subTypeLeg", y)
  y = self:RenderDirectionSplit("subTypeDir", "subTypeDir", "subTypeDirLeg",
    stats.itemSubTypeByDirection,
    { labelOf = tostring, labelColorOf = function(k) return subColors[k] end }, y, w)

  -- 10 ── Movements over time. One day-key list drives the strip.
  local dayKeys = W.DayKeys(totals.firstTs, totals.lastTs)
  local perDay = {}
  for _, key in ipairs(dayKeys) do
    local count = (stats.byDay or {})[key] or 0
    local label = W.ShortDay(key)
    perDay[#perDay + 1] = { magnitude = count, label = label,
      tip = ("%s:  %d movements"):format(key, count) }
  end
  y = self:RenderStrip("perDay", "perDay", self.strips.perDay, perDay, y, w)

  -- 11 ── Hour of day, 24 fixed buckets (a quiet hour is a fact, so every hour is plotted).
  local hourBuckets = {}
  for h = 0, 23 do
    local count = (stats.byHour or {})[h] or 0
    hourBuckets[#hourBuckets + 1] = { magnitude = count, label = ("%02d"):format(h),
      tip = ("%02d:00  %d movements"):format(h, count) }
  end
  y = self:RenderStrip("hour", "hour", self.strips.hour, hourBuckets, y, w)

  -- 12 ── Weekday, Sunday first (calendar order, not count order), each day its own palette colour.
  local weekdayRows = {}
  for d = 0, 6 do
    local count = (stats.byWeekday or {})[d]
    if count then
      weekdayRows[#weekdayRows + 1] = { label = W.WEEKDAY_LABEL[d], color = W.PaletteColor(d + 1),
        frac = count, value = tostring(count) }
    end
  end
  y = self:RenderBars("weekday", "weekday", weekdayRows, y, w)

  -- ── GOLD ──────────────────────────────────────────────────────────────────────
  -- Shown only when the slice actually holds a coin movement: two empty charts under a big GOLD
  -- banner would say "this addon is broken", not "you moved no gold".
  if (totals.moneyMoved or 0) > 0 then
    y = placeDivider(self.dividers.gold, content, y)

    local goldDay = {}
    for _, key in ipairs(dayKeys) do
      local amount = (stats.moneyByDay or {})[key] or 0
      goldDay[#goldDay + 1] = { magnitude = amount, label = W.ShortDay(key),
        tip = ("%s:  %s"):format(key, W.Money(amount)) }
    end
    y = self:RenderStrip("goldDay", "goldDay", self.strips.goldDay, goldDay, y, w)

    local goldRows = {}
    for key, amount in pairs(stats.moneyByStore or {}) do
      if amount > 0 then
        goldRows[#goldRows + 1] = { label = storeLabel(key), color = storeColor(key),
          frac = amount, value = W.Money(amount), count = amount }
      end
    end
    table.sort(goldRows, function(a, b)
      if a.count ~= b.count then return a.count > b.count end
      return a.label < b.label
    end)
    y = self:RenderBars("goldStore", "goldStore", goldRows, y, w)
  else
    self.dividers.gold:Hide()
    self.headers.goldDay:Hide()
    self.headers.goldStore:Hide()
    self.strips.goldDay:Hide()
  end

  -- ── Ranked lists: grouped, three columns of All / Deposits / Withdrawals ───────
  -- The triptych IS the organization: a metric's combined ranking and its two direction-split
  -- rankings sit side by side, so "what moves most" and "what moves most INTO the bank" are one
  -- glance apart rather than one scroll apart.
  y = placeDivider(self.dividers.top, content, y)

  local function itemRows(list, rightOf)
    local rows = {}
    for i = 1, math.min(LIST_ROWS, #(list or {})) do
      local it = list[i]
      local right = rightOf(it)
      if right then
        rows[#rows + 1] = {
          name = it.itemName or ("Item " .. tostring(it.itemID)),
          nameColor = W.QualityColor(it.quality or 1), right = right,
        }
      end
    end
    return rows
  end
  local function countRows(list, field)
    local rows = {}
    for i = 1, math.min(LIST_ROWS, #(list or {})) do
      local r = list[i]
      rows[#rows + 1] = { name = r.label or r.zone, right = tostring(r[field]) }
    end
    return rows
  end
  local moves = function(field) return function(it) return tostring(it[field]) end end

  y = self:RenderSubHead("ITEMS", y)
  y = self:RenderSubHead("Top Items By Movements", y, 10)
  y = self:RenderListRow({
    { title = "All",         rows = itemRows(stats.topItems, moves("moves")) },
    { title = "Deposits",    rows = itemRows(stats.topItemsIn, moves("movesIn")) },
    { title = "Withdrawals", rows = itemRows(stats.topItemsOut, moves("movesOut")) },
  }, y, innerW)
  y = self:RenderSubHead("Top Items By Quantity", y, 10)
  y = self:RenderListRow({
    { title = "All",         rows = itemRows(stats.topItemsByQuantity, moves("quantity")) },
    { title = "Deposits",    rows = itemRows(stats.topItemsByQuantityIn, moves("qtyIn")) },
    { title = "Withdrawals", rows = itemRows(stats.topItemsByQuantityOut, moves("qtyOut")) },
  }, y, innerW)

  y = self:RenderSubHead("CATEGORIES", y)
  y = self:RenderSubHead("Top Type \194\183 Sub-type", y, 10)
  y = self:RenderListRow({
    { title = "All",         rows = countRows(stats.topTypeSub, "count") },
    { title = "Deposits",    rows = countRows(stats.topTypeSubIn, "inCount") },
    { title = "Withdrawals", rows = countRows(stats.topTypeSubOut, "outCount") },
  }, y, innerW)

  y = self:RenderSubHead("WHERE", y)
  y = self:RenderSubHead("Top Banking Spots", y, 10)
  y = self:RenderListRow({
    { title = "All",         rows = countRows(stats.topZones, "count") },
    { title = "Deposits",    rows = countRows(stats.topZonesIn, "inCount") },
    { title = "Withdrawals", rows = countRows(stats.topZonesOut, "outCount") },
  }, y, innerW)

  -- Per-store lists, each store its OWN sub-section with the same All / Deposits / Withdrawals
  -- triptych every other metric gets — so "what moves through the guild bank, and which way" is
  -- answered in one place instead of by cross-referencing a single combined panel against the
  -- charts above. Stores run in display order so a store keeps its position between refreshes; a
  -- coin-only store has no item list and simply does not appear.
  local anyStore = false
  for _, key in ipairs(C.StoreOrder) do
    local all = (stats.topItemsByStore or {})[key]
    if all and #all > 0 then
      if not anyStore then
        y = self:RenderSubHead("BY STORE", y)
        anyStore = true
      end
      y = self:RenderSubHead(storeLabel(key), y, 10)
      y = self:RenderListRow({
        { title = "All", rows = itemRows(all, moves("moves")) },
        { title = "Deposits",
          rows = itemRows((stats.topItemsByStoreIn or {})[key], moves("movesIn")) },
        { title = "Withdrawals",
          rows = itemRows((stats.topItemsByStoreOut or {})[key], moves("movesOut")) },
      }, y, innerW)
    end
  end

  return y - W.SECTION_GAP
end

-- ── Live refresh ───────────────────────────────────────────────────────────────
-- Registered on this module's OWN AceEvent target, never the shared bus-as-self, so it can't clobber
-- the Browser's consumers of the same messages (architecture-§4).

function I:Enable()
  if self._enabled then return end
  self._enabled = true
  I.__ev = NS.NewBusTarget()
  if not I.__ev then return end
  local onChange = function()
    if I.pane and I.pane:IsShown() then I:Refresh() end
  end
  I.__ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", onChange)
  I.__ev:RegisterMessage("Ka0s_BankLedger_EntryAdded", onChange)
end
