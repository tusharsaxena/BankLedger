local addonName, NS = ...   -- luacheck: ignore addonName
NS.Insights = NS.Insights or {}
local I = NS.Insights
local C = NS.Constants

-- The Insights tab: summary cards plus ranked horizontal bars, computed off the SAME filter the
-- ledger table uses, so the two views can never disagree about what they are showing.
--
-- Everything here is frame-light on purpose: each bar is one FontString pair plus one texture, and
-- the slots are created ONCE and repainted in place on every refresh. The Blizzard UI runs a
-- super-linear pass over a frame tree on some transitions, so re-allocating widgets per refresh is
-- what turns a smooth panel into a visible hitch.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLD = { 0.91, 0.77, 0.42 }
local BAR_RGB = { 0.35, 0.55, 0.85 }
local BAR_ROWS = 10          -- reusable slots per bar list
local BAR_ROW_H = 18
local CARD_W, CARD_H = 150, 44
local SECTION_GAP = 14

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

-- A signed copper amount as a coloured string: green for a net gain, red for a net loss, grey for
-- nothing. Pure, so the summary cards and any future surface read identically.
function I.FormatNet(copper)
  copper = copper or 0
  if copper == 0 then return "|cff808080\226\128\148|r" end   -- em-dash
  local body = NS.Util.FormatMoney(math.abs(copper))
  if copper > 0 then return "|cff40ff40+" .. body .. "|r" end
  return "|cffff4040-" .. body .. "|r"
end

-- ── Widget helpers ─────────────────────────────────────────────────────────────

local function makeFS(parent, template, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  fs:SetJustifyH(justify or "LEFT")
  return fs
end

-- A summary card: a small gold caption over a larger value line. Created once, repainted per refresh.
local function makeCard(parent, index)
  local col, rowIdx = (index - 1) % 4, math.floor((index - 1) / 4)
  local x, y = col * (CARD_W + 8), -rowIdx * (CARD_H + 6)
  local caption = makeFS(parent, "GameFontNormalSmall")
  caption:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  caption:SetWidth(CARD_W)
  caption:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  local value = makeFS(parent, "GameFontNormalLarge")
  value:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 16)
  value:SetWidth(CARD_W)
  return { caption = caption, value = value }
end

-- One reusable bar slot: label · bar · count/value.
local function makeBarRow(parent, index)
  local y = -(index - 1) * BAR_ROW_H
  local label = makeFS(parent)
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
  label:SetWidth(150)
  label:SetWordWrap(false)

  local track = parent:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("TOPLEFT", parent, "TOPLEFT", 158, y - 3)
  track:SetHeight(10)
  track:SetColorTexture(1, 1, 1, 0.06)

  local fill = parent:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", parent, "TOPLEFT", 158, y - 3)
  fill:SetHeight(10)
  fill:SetColorTexture(BAR_RGB[1], BAR_RGB[2], BAR_RGB[3], 0.85)

  local amount = makeFS(parent, "GameFontHighlightSmall", "RIGHT")
  amount:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
  amount:SetWidth(150)

  return { label = label, track = track, fill = fill, amount = amount }
end

-- ── Sections ───────────────────────────────────────────────────────────────────
-- Each section declares how to pull its rows out of a Stats result. Adding a breakdown is one entry
-- here — no new layout code.
local SECTIONS = {
  { title = "Movements by store",
    rows = function(s) return I.RankRows(s.byStore, function(k) return C.StoreLabel[k] or k end,
      s.valueByStore) end },
  { title = "Deposits vs withdrawals",
    rows = function(s) return I.RankRows(s.byDirection,
      function(k) return C.DirectionLabel[k] or k end) end },
  { title = "Movements by character",
    rows = function(s)
      local map, valueMap = {}, {}
      for ch, ce in pairs(s.byChar or {}) do map[ch] = ce.count; valueMap[ch] = ce.value end
      return I.RankRows(map, nil, valueMap, BAR_ROWS)
    end },
  { title = "Most-moved items",
    rows = function(s)
      local rows = {}
      for i, it in ipairs(s.topItems or {}) do
        if i > BAR_ROWS then break end
        rows[#rows + 1] = { key = it.itemID,
          label = it.itemName or ("Item " .. tostring(it.itemID)),
          count = it.moves, value = it.value }
      end
      return rows
    end },
}

-- ── Build ──────────────────────────────────────────────────────────────────────

function I:Attach(pane)
  if self.pane then return end
  self.pane = pane

  local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -26, 0)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)
  self.content = content

  -- Summary cards.
  local cardHost = CreateFrame("Frame", nil, content)
  cardHost:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
  cardHost:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -4)
  cardHost:SetHeight(CARD_H * 2 + 6)
  self.cards = {}
  for i = 1, 8 do self.cards[i] = makeCard(cardHost, i) end

  -- One bar list per section, stacked below the cards.
  self.sections = {}
  local anchor = cardHost
  local anchorGap = SECTION_GAP
  for i, spec in ipairs(SECTIONS) do
    local host = CreateFrame("Frame", nil, content)
    host:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -anchorGap)
    host:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -anchorGap)
    host:SetHeight(20 + BAR_ROWS * BAR_ROW_H)

    local title = makeFS(host, "GameFontNormal")
    title:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    title:SetText(spec.title)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local divider = host:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -18)
    divider:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -18)
    divider:SetHeight(1)
    divider:SetTexture(WHITE)
    divider:SetVertexColor(0.24, 0.24, 0.27, 0.85)

    local rowHost = CreateFrame("Frame", nil, host)
    rowHost:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -24)
    rowHost:SetPoint("TOPRIGHT", host, "TOPRIGHT", -8, -24)
    rowHost:SetHeight(BAR_ROWS * BAR_ROW_H)

    local slots = {}
    for r = 1, BAR_ROWS do slots[r] = makeBarRow(rowHost, r) end

    self.sections[i] = { spec = spec, host = host, rowHost = rowHost, slots = slots }
    anchor, anchorGap = host, SECTION_GAP
  end

  self:Refresh()
end

-- Which filter the view computes against: the browser's shared filter, so the Insights numbers and
-- the table rows always describe the same slice of the ledger.
local function currentFilter()
  if NS.Browser and NS.Browser.CurrentFilter then return NS.Browser:CurrentFilter() end
  return {}
end

function I:Refresh()
  if not self.pane then return end
  local stats = NS.Database:Stats(currentFilter())
  local t = stats.totals or {}

  local cards = {
    { "Movements",      tostring(t.entries or 0) },
    { "Items in",       tostring(t.itemsDeposited or 0) },
    { "Items out",      tostring(t.itemsWithdrawn or 0) },
    { "Characters",     tostring(t.distinctChars or 0) },
    { "Gold in",        NS.Util.FormatMoney(t.moneyIn or 0) },
    { "Gold out",       NS.Util.FormatMoney(t.moneyOut or 0) },
    { "Net gold",       I.FormatNet(t.netMoney or 0) },
    { "Value moved",    NS.Util.FormatMoney(t.totalValue or 0) },
  }
  for i, card in ipairs(self.cards) do
    local spec = cards[i]
    card.caption:SetText(spec and spec[1] or "")
    card.value:SetText((spec and spec[2] ~= "" and spec[2]) or "\226\128\148")
  end

  local barWidth = math.max(60, (self.sections[1] and self.sections[1].rowHost:GetWidth() or 400) - 320)
  for _, section in ipairs(self.sections) do
    local rows = section.spec.rows(stats) or {}
    for r, slot in ipairs(section.slots) do
      local row = rows[r]
      if row then
        slot.label:SetText(row.label)
        slot.amount:SetText(row.value and row.value > 0
          and (row.count .. "   " .. NS.Util.FormatMoney(row.value))
          or tostring(row.count))
        slot.track:SetWidth(barWidth)
        slot.fill:SetWidth(math.max(1, barWidth * I.BarFraction(rows, r)))
        slot.track:Show(); slot.fill:Show()
      else
        slot.label:SetText("")
        slot.amount:SetText("")
        slot.track:Hide(); slot.fill:Hide()
      end
    end
  end

  if NS.State.debug and NS.Debug then
    NS.Debug("Insights", "recomputed over %s movements", tostring(t.entries or 0))
  end
end

-- Live-refresh while the tab is on screen. Registered on this module's OWN AceEvent target, never
-- the shared bus-as-self, so it can't clobber the Browser's consumers of the same messages
-- (architecture-§4).
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
