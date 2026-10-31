local _, NS = ...
NS.Insights = NS.Insights or {}
local I = NS.Insights
local C = NS.Constants
local W = NS.InsightsWidgets

-- The Insights tab: a stat-card header, then a stack of breakdown sections, then ranked lists — all
-- computed off ONE Database:Stats pass over the SAME filter the ledger table uses, so the two views
-- can never disagree about which slice of the ledger they describe.
--
-- This file is about WHAT is shown: which breakdown, out of which Stats key, in which color and in
-- which order. HOW it is drawn lives in modules/InsightsWidgets.lua, and the I:Render* methods that
-- draw each chart shape live in modules/Insights_Render.lua.
--
-- A bank ledger measures FLOW, so the panel is organized around direction and store rather than
-- around a flat "count by category" list: the in/out split leads, and every breakdown that can be
-- split by direction carries a back-to-back companion answering "which way does this lean" — for a
-- store, a quality, an item type, a character.

local BAR_ROWS = 12          -- cap on a ranked bar list, so one section can't run off the page
local LIST_ROWS = 10         -- cap on a ranked list panel
local CARD_COLS = 4
local CARD_GAP, PAD = 8, 8
local EM_DASH = "\226\128\148"

-- ── Pure label / tooltip helpers (unit-tested) ────────────────────────────────

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
  -- The bar's own art faded and a flat knob over a corridor, in the skin's scroll.* tokens.
  if scroll.ScrollBar then NS.Skin.ScrollBar(scroll.ScrollBar) end

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
  self.splitBar = W.MakeSplitBar(content)

  self.pools = {}
  for _, key in ipairs(POOL_KEYS) do self.pools[key] = W.NewPool() end

  self.emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
  NS.Skin.Text(self.emptyText, "disabled")
  self.emptyText:Hide()

  self:Refresh()
end

-- Which filter the view computes against: the Insights tab's own filter state, which the Browser's
-- filter bar holds (B:CurrentFilter) whenever Insights is the tab on screen. History keeps its own;
-- a tab switch trades them (B:SwapTabState) and B:SelectTab then refreshes this view, so a refresh
-- that ran while History was on screen is repainted from Insights' own filter on the way back.
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

-- The cards that are a plain count of one totals field, and the ones that are a money figure.
-- card key → totals field. Module-level, so the mapping is walked, not re-listed, per call.
local COUNT_CARDS = {
  movements     = "entries",
  itemsIn       = "itemsDeposited",
  itemsOut      = "itemsWithdrawn",
  distinctItems = "distinctItems",
  chars         = "distinctChars",
  activeDays    = "activeDays",
}
local MONEY_CARDS = {
  goldIn  = "moneyIn",
  goldOut = "moneyOut",
}

-- The date range the slice covers. The em-dash is reserved for "this fact does not exist" — an
-- empty slice has no first or last movement to name.
local function spanText(t)
  if t.firstTs and t.lastTs then
    -- \226\128\147 = en-dash, the range dash.
    return NS.Util.FormatDate(t.firstTs) .. " \226\128\147 " .. NS.Util.FormatDate(t.lastTs)
  end
  return EM_DASH
end

local function topStoreText(t)
  return t.topStore and (C.StoreLabel[t.topStore.store] or t.topStore.store) or EM_DASH
end

local function busiestText(t)
  return t.busiestDay and (t.busiestDay.day .. "  (" .. t.busiestDay.count .. ")") or EM_DASH
end

-- The display value for every card, out of a totals table. Pure and separated from the layout so the
-- formatting rules (what counts as "nothing", which figures are signed) are testable.
--
-- Every count card is a STRING: the card widget sets text, and a missing figure renders as "0".
function I.CardValues(totals)
  local t = totals or {}
  local v = {}
  for card, field in pairs(COUNT_CARDS) do v[card] = tostring(t[field] or 0) end
  for card, field in pairs(MONEY_CARDS) do v[card] = W.Money(t[field] or 0) end
  v.netItems   = W.SignedCount(t.netItems or 0)
  v.netGold    = W.SignedMoney(t.netMoney or 0)
  v.itemsMoved = tostring((t.itemsDeposited or 0) + (t.itemsWithdrawn or 0))
  v.topStore   = topStoreText(t)
  v.span       = spanText(t)
  v.busiest    = busiestText(t)
  return v
end

-- ── Shared key → display lookups ───────────────────────────────────────────────
-- Declared above the render helpers because those close over them; a local declared later would
-- resolve as a nil global at call time.

-- The store palette is this addon's own categorical meaning, kept under every skin (the rollout's
-- exception E7); the direction pair is the skin's sem.good / sem.bad (W.POSITIVE / W.NEGATIVE, the
-- reused triples modules/InsightsWidgets.lua resolves per skin).
local function storeColor(key) return C.StoreRGB[key] or W.NEUTRAL end
local function storeLabel(key) return C.StoreLabel[key] or tostring(key) end
local DIRECTION_COLOR = { [C.Direction.DEPOSIT] = W.POSITIVE, [C.Direction.WITHDRAW] = W.NEGATIVE }
local function directionColor(key) return DIRECTION_COLOR[key] or W.NEUTRAL end
local function directionLabel(key) return C.DirectionLabel[key] or tostring(key) end

-- The I:Render* section renderers live in modules/Insights_Render.lua, which loads straight after
-- this file. These are the file locals they need, handed over by name through one explicit table
-- rather than as globals.
I._renderSeam = {
  PAD            = PAD,
  BAR_ROWS       = BAR_ROWS,
  LIST_ROWS      = LIST_ROWS,
  directionColor = directionColor,
  directionLabel = directionLabel,
}

-- ── Layout ─────────────────────────────────────────────────────────────────────

function I:HideAllSections()
  for _, h in pairs(self.headers) do h:Hide() end
  for _, s in pairs(self.strips) do s:Hide() end
  for _, d in pairs(self.dividers) do d:Hide() end
  self.splitBar:Hide()
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

-- ── Sections ───────────────────────────────────────────────────────────────────
-- One file-local builder per section of the pane, in the order they are drawn. Each takes `self`
-- explicitly (the module's public surface stays as it was), takes and returns the running `y`, and
-- owns exactly the widgets its own comment describes. This is pure geometry: a builder that returns
-- a `y` off by a pixel shifts every section below it.

-- 1 ── Deposits vs withdrawals, as one back-to-back bar about a center axis: withdrawals left,
-- deposits right, both scaled against the larger. Same form, same side-to-direction mapping and
-- same shared-peak scale as every "× Deposits/Withdrawals" chart below it, so the headline split
-- and its breakdowns read as one chart family rather than two ways of saying the same thing. The
-- captions carry the shares, which is what a peak-scaled pair cannot show in its lengths.
local function sectionSplit(self, y, innerW, stats, total)
  local content = self.content
  local inCount = (stats.byDirection or {})[C.Direction.DEPOSIT] or 0
  local outCount = (stats.byDirection or {})[C.Direction.WITHDRAW] or 0
  if inCount + outCount > 0 then
    local header = self.headers.split
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, y)
    header:Show()
    y = y - 20
    local inFrac, outFrac = W.PeakShares(inCount, outCount)
    W.PlaceSplitBar(self.splitBar, content, PAD, y, innerW,
      { frac = outFrac, color = directionColor(C.Direction.WITHDRAW),
        text = ("Withdrawals %d \194\183 %d%%"):format(outCount, W.Percent(outCount, total)),
        tip = ("Withdrawals: %d of %d movements"):format(outCount, total) },
      { frac = inFrac, color = directionColor(C.Direction.DEPOSIT),
        text = ("Deposits %d \194\183 %d%%"):format(inCount, W.Percent(inCount, total)),
        tip = ("Deposits: %d of %d movements"):format(inCount, total) })
    self.splitBar:Show()
    y = y - W.SPLIT_H - W.SPLIT_CAPTION_H - W.SECTION_GAP
  else
    self.headers.split:Hide()
    self.splitBar:Hide()
  end
  return y
end

-- 2 ── Movements by store, in the shared store colors.
local function sectionStores(self, y, w, stats, total)
  local storeRows = {}
  for _, e in ipairs(W.SortedByCount(stats.byStore)) do
    storeRows[#storeRows + 1] = {
      label = storeLabel(e.key), color = storeColor(e.key), frac = e.count,
      value = ("%d  %d%%"):format(e.count, W.Percent(e.count, total)),
    }
  end
  y = self:RenderBars("store", "store", storeRows, y, w)
  return self:RenderDirectionSplit("storeDir", "storeDir", "storeDirLeg", stats.storeByDirection,
    { labelOf = storeLabel, labelColorOf = storeColor }, y, w)
end

-- Count-desc, then character name ascending so the order is stable between refreshes.
local function byCountThenChar(a, b)
  if a.count ~= b.count then return a.count > b.count end
  return a.char < b.char
end

-- 3 ── Movements by character, class-colored and behind the class icon.
local function sectionChars(self, y, w, stats)
  local charRows = {}
  for _, ce in pairs(stats.byChar or {}) do
    if (ce.count or 0) > 0 then charRows[#charRows + 1] = ce end
  end
  table.sort(charRows, byCountThenChar)
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
  return self:RenderBars("char", "char", barCharRows, y, w)
end

-- character → classFile, built once and threaded through both character charts below: the stack's
-- label color and the direction split's label color are the same fact.
local function classMap(stats)
  local classOf = {}
  for ch, ce in pairs(stats.byChar or {}) do classOf[ch] = ce.classFile end
  return classOf
end

-- 5 ── Character × Store, then Character × Deposits/Withdrawals.
local function sectionCharStore(self, y, w, stats, classOf)
  -- Segment order follows the parent chart's order, so a store keeps the same position in every
  -- character's bar.
  local storeOrder = {}
  for _, e in ipairs(W.SortedByCount(stats.byStore)) do storeOrder[#storeOrder + 1] = e.key end
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
  -- them share one center axis and one reading.
  return self:RenderDirectionSplit("charDir", "charDir", "charDirLeg", stats.charByDirection,
    { labelOf = W.ShortChar,
      labelColorOf = function(ch) return W.ClassColor(classOf[ch]) end }, y, w)
end

-- 7 ── Quality, in ASCENDING quality order (Poor→Legendary is meaningful; count-desc is not) and
-- in the game's own quality colors, so the bars are self-legending.
local function sectionQuality(self, y, w, stats)
  local qualityIDs = {}
  for q in pairs(stats.byQuality or {}) do qualityIDs[#qualityIDs + 1] = q end
  table.sort(qualityIDs)
  -- These rows are NOT in count order, so the largest bar is not row 1 — RenderBars normalizes
  -- against the true peak, not against the first row, which is what makes that safe.
  local qualityRows = {}
  for _, q in ipairs(qualityIDs) do
    local color = W.QualityColor(q)
    qualityRows[#qualityRows + 1] = { label = NS.Item.QualityLabel(q), color = color,
      labelColor = color, frac = stats.byQuality[q], value = tostring(stats.byQuality[q]) }
  end
  y = self:RenderBars("quality", "quality", qualityRows, y, w)
  return self:RenderDirectionSplit("qualityDir", "qualityDir", "qualityDirLeg",
    stats.qualityByDirection,
    { labelOf = NS.Item.QualityLabel, labelColorOf = W.QualityColor }, y, w)
end

-- A ranked bar chart drawn from the categorical palette by rank, so adjacent bars are always
-- dissimilar hues. Returns the new y and the key → color map, which the direction-split companion
-- reuses so both charts color a category the same way.
local function paletteRows(self, map, poolKey, headerKey, legendKey, y, w, total)
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
  return self:RenderBars(poolKey, headerKey, rows, y, w, legendKey), colors
end

-- 8/9 ── Item type and sub-type.
local function sectionTypes(self, y, w, stats, total)
  local typeColors, subColors
  y, typeColors = paletteRows(self, stats.byItemType, "itemType", "itemType", "itemTypeLeg",
    y, w, total)
  y = self:RenderDirectionSplit("itemTypeDir", "itemTypeDir", "itemTypeDirLeg",
    stats.itemTypeByDirection,
    { labelOf = tostring, labelColorOf = function(k) return typeColors[k] end }, y, w)
  y, subColors = paletteRows(self, stats.byItemSubType, "subType", "subType", "subTypeLeg",
    y, w, total)
  return self:RenderDirectionSplit("subTypeDir", "subTypeDir", "subTypeDirLeg",
    stats.itemSubTypeByDirection,
    { labelOf = tostring, labelColorOf = function(k) return subColors[k] end }, y, w)
end

-- 10/11/12 ── Movements over time: per day, per hour of day, per weekday.
local function sectionTime(self, y, w, stats, dayKeys)
  -- 10 ── Movements over time. One day-key list drives the strip.
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

  -- 12 ── Weekday, Sunday first (calendar order, not count order), each day its own palette color.
  local weekdayRows = {}
  for d = 0, 6 do
    local count = (stats.byWeekday or {})[d]
    if count then
      weekdayRows[#weekdayRows + 1] = { label = W.WEEKDAY_LABEL[d], color = W.PaletteColor(d + 1),
        frac = count, value = tostring(count) }
    end
  end
  return self:RenderBars("weekday", "weekday", weekdayRows, y, w)
end

-- Amount-desc, then store label ascending.
local function byAmountThenLabel(a, b)
  if a.count ~= b.count then return a.count > b.count end
  return a.label < b.label
end

-- ── GOLD ──────────────────────────────────────────────────────────────────────
-- Shown only when the slice actually holds a coin movement: two empty charts under a big GOLD
-- banner would say "this addon is broken", not "you moved no gold".
local function sectionGold(self, y, w, stats, totals, dayKeys)
  -- `<= 0`, the exact inversion of the `> 0` guard this was lifted out of. `== 0` would draw the
  -- banner and both charts for a negative total; moneyMoved happens to be a sum of two gross
  -- non-negative accumulators today, but this guard does not lean on that invariant.
  if (totals.moneyMoved or 0) <= 0 then
    -- Hide the chrome as well as the charts, or a previous slice's banner and headers stay on screen.
    self.dividers.gold:Hide()
    self.headers.goldDay:Hide()
    self.headers.goldStore:Hide()
    self.strips.goldDay:Hide()
    return y
  end
  y = placeDivider(self.dividers.gold, self.content, y)

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
  table.sort(goldRows, byAmountThenLabel)
  return self:RenderBars("goldStore", "goldStore", goldRows, y, w)
end

-- The ranked-list row builders, shared by every triptych below.
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

local function moves(field) return function(it) return tostring(it[field]) end end

-- Per-store lists, each store its OWN sub-section with the same All / Deposits / Withdrawals
-- triptych every other metric gets — so "what moves through the guild bank, and which way" is
-- answered in one place instead of by cross-referencing a single combined panel against the
-- charts above. Stores run in display order so a store keeps its position between refreshes; a
-- coin-only store has no item list and simply does not appear.
local function storeLists(self, y, innerW, stats)
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
  return y
end

-- ── Ranked lists: grouped, three columns of All / Deposits / Withdrawals ───────
-- The triptych IS the organization: a metric's combined ranking and its two direction-split
-- rankings sit side by side, so "what moves most" and "what moves most INTO the bank" are one
-- glance apart rather than one scroll apart.
local function sectionTopLists(self, y, innerW, stats)
  y = placeDivider(self.dividers.top, self.content, y)

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

  return storeLists(self, y, innerW, stats)
end

-- The pane below the cards, section by section, in drawing order. Section ORDER is the product:
-- each chart sits directly under the thing it breaks down.
function I:LayoutSections(y, w, stats, totals)
  local innerW = w - PAD * 2
  local total = totals.entries or 0
  -- One day-key list serves both the per-day strip and the gold-per-day strip.
  local dayKeys = W.DayKeys(totals.firstTs, totals.lastTs)
  local classOf = classMap(stats)

  y = placeDivider(self.dividers.items, self.content, y)
  y = sectionSplit(self, y, innerW, stats, total)
  y = sectionStores(self, y, w, stats, total)
  y = sectionChars(self, y, w, stats)
  y = sectionCharStore(self, y, w, stats, classOf)
  y = sectionQuality(self, y, w, stats)
  y = sectionTypes(self, y, w, stats, total)
  y = sectionTime(self, y, w, stats, dayKeys)
  y = sectionGold(self, y, w, stats, totals, dayKeys)
  y = sectionTopLists(self, y, innerW, stats)

  return y - W.SECTION_GAP
end

-- ── Live refresh ───────────────────────────────────────────────────────────────
-- Registered on this module's OWN AceEvent target, never the shared bus-as-self, so it can't clobber
-- the Browser's consumers of the same messages (architecture-§4).

-- One aggregation per burst of recorded entries, for the same reason the Browser coalesces its
-- repaint. Off-screen this costs nothing either way — Refresh already returns early — but the
-- on-screen case is exactly when the user is at the bank emptying their bags.
local pendingRefreshTimer

function I:ScheduleRefresh()
  if not (self.pane and self.pane:IsShown()) then return end
  local addon = NS.addon
  if not (addon and addon.ScheduleTimer) then return self:Refresh() end
  if pendingRefreshTimer then return end
  pendingRefreshTimer = addon:ScheduleTimer(function()
    pendingRefreshTimer = nil
    if I.pane and I.pane:IsShown() then I:Refresh() end
  end, 0)
end

--- The stand-down's uniform name (core/BankLedger.lua). The handle is a file local, out of reach
--- of AceTimer's cancel-all, and ScheduleRefresh refuses to arm while one is outstanding.
function I.CancelPending()
  local addon = NS.addon
  if pendingRefreshTimer and addon and addon.CancelTimer then
    addon:CancelTimer(pendingRefreshTimer)
  end
  pendingRefreshTimer = nil
end

function I:Enable()
  if self._enabled then return end
  self._enabled = true
  I.__ev = NS.NewBusTarget()
  if not I.__ev then return end
  local onChange = function()
    if I.pane and I.pane:IsShown() then I:Refresh() end
  end
  -- LedgerChanged is already one message per bulk operation, so it refreshes synchronously.
  -- EntryAdded is one message per moved stack, and a Refresh here is a full Database:Stats pass —
  -- so a 20-slot deposit would aggregate the whole ledger twenty times. Collapse the burst.
  I.__ev:RegisterMessage(NS.MSG.LEDGER_CHANGED, onChange)
  I.__ev:RegisterMessage(NS.MSG.ENTRY_ADDED, function() I:ScheduleRefresh() end)
end

-- ── A skin switch ──────────────────────────────────────────────────────────────
-- Fires after the new skin is resolved and every recorded frame repainted (NS.Skin.OnLooksChanged):
-- the cards, panels, section headings, captions, rules, axis labels and the scroll bar are recorded
-- primitives and repaint themselves. What is left is the host's own: the cached color triples and
-- the palette, each card's base headline font (the shrink pass resets to it), each section
-- divider's 1.5x title, and then a refresh, which repaints every pooled bar, track, strip and list
-- row in the new colors while the pane is up; a hidden pane refreshes when its tab is next selected.
function I:Reskin()
  W.ReskinColors()
  if not self.pane then return end
  for _, card in pairs(self.cards or {}) do W.ReskinCard(card) end
  for _, d in pairs(self.dividers or {}) do W.ReskinDivider(d) end
  if self.pane:IsShown() then self:Refresh() end
end

if NS.Skin then NS.Skin.OnLooksChanged(function() I:Reskin() end) end
