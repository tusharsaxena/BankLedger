local addonName, NS = ...   -- luacheck: ignore addonName
NS.LedgerTable = NS.LedgerTable or {}
local LT = NS.LedgerTable
local C = NS.Constants

-- Virtualized pooled-row table over Database:Query — filter → sort → group → slice → bind.
-- Rows are pooled (events-frames-taint-§6): a 10,000-entry ledger still only ever builds as many
-- row frames as fit on screen.

local ROW_H = 18
local HEADER_H = 20
local ITEM_MIN = 150   -- minimum width of the flex (Item) column
local COL_GAP = 8      -- horizontal space between columns

-- Direction and store colours + the ▲/▼ direction glyphs live in Constants (C.DirectionRGB,
-- C.DirectionGlyph, C.StoreRGB): the filter dropdowns paint their options from the same tables, so
-- a store or a direction can never read one colour in the table and another in the menu.
--
-- The glyph is drawn as a real text glyph rather than a texture, because a glyph sits on the
-- label's own baseline — centred against the text by construction, where Blizzard's arrow textures
-- carry uneven padding (the up arrow's art sits low in its canvas, the down arrow's high) and
-- visibly misalign. It also takes the direction's colour from the same SetTextColor the label uses.
-- It needs the VENDORED font: the default WoW font has no ▲/▼ and renders a box, while the shipped
-- JetBrains Mono carries both. That is an accepted, documented deviation — the mono font is a
-- sanctioned styling exception scoped to the debug console (debug-logging-§2) and this extends it
-- to one glyph. See docs/ARCHITECTURE.md ▸ Documented deviations.
local ARROW_SIZE, ARROW_GAP = 12, 2

-- Gold movements name themselves "Gold" in the Item column. A quality colour would be a lie (gold
-- has no quality), so they take a pale gold — deliberately LIGHTER than the 1/0.82/0 the column
-- headers and window title use, so a gold row reads as data and never as a heading.
local MONEY_RGB = { 1.00, 0.91, 0.55 }

local EM_DASH = "\226\128\148"

-- ── Column model ────────────────────────────────────────────────────────────────
-- width 0 + flex = true means "absorb the remaining width" (the Item column). Character is
-- deliberately LAST; insert any new column BEFORE it so that stays true.
LT.COLUMNS = {
  { key = "date", label = "Date", width = 66, align = "LEFT",
    desc = "Date the movement happened.",
    valueFn = function(e) return NS.Util.FormatDate(e.ts) end,
    sortFn = function(e) return e.ts or 0 end },
  { key = "time", label = "Time", width = 40, align = "LEFT",
    desc = "Time of day the movement happened.",
    valueFn = function(e) return NS.Util.FormatClock(e.ts) end,
    sortFn = function(e) return e.ts or 0 end },
  { key = "direction", label = "In/Out", width = 74, align = "LEFT",
    desc = "Deposit (\226\150\188) means it left your bags for the store; "
      .. "withdraw (\226\150\178) means it came back out.",
    valueFn = function(e) return C.DirectionLabel[e.direction] or e.direction or "" end,
    sortFn = function(e) return e.direction or "" end },
  { key = "store", label = "Store", width = 112, align = "LEFT",
    desc = "Which bank the movement was to or from.",
    valueFn = function(e) return C.StoreLabel[e.store] or e.store or "" end,
    sortFn = function(e) return C.StoreLabel[e.store] or e.store or "" end },
  { key = "item", label = "Item", width = 0, flex = true, align = "LEFT",
    desc = "What moved. Gold movements show as Gold. Hover for the item tooltip.",
    valueFn = function(e)
      return e.itemName or (e.itemID and ("Item " .. e.itemID)) or "?"
    end,
    sortFn = function(e) return (e.itemName or ""):lower() end },
  { key = "qty", label = "Qty", width = 92, align = "RIGHT",
    desc = "How many moved — the stack size for an item, the amount for a gold movement.",
    valueFn = function(e)
      if e.kind == C.Kind.MONEY then return NS.Util.FormatMoney(e.quantity) end
      return tostring(e.quantity or 1)
    end,
    -- Sorts on what the cell shows: a gold row by its copper amount, an item row by stack size.
    sortFn = function(e) return e.quantity or 1 end },
  { key = "quality", label = "Quality", width = 64, align = "LEFT",
    desc = "Item quality (Poor to Legendary). Gold has none, and shows a dash.",
    valueFn = function(e)
      if e.kind == C.Kind.MONEY then return EM_DASH end
      return e.quality ~= nil and NS.Compat.QualityLabel(e.quality) or ""
    end,
    sortFn = function(e) return e.quality or -1 end },
  { key = "type", label = "Type", width = 86, align = "LEFT",
    desc = "Item type. Gold movements are typed as Gold.",
    valueFn = function(e) return NS.Util.EntryType(e) end,
    sortFn = function(e) return NS.Util.EntryType(e):lower() end },
  { key = "subtype", label = "Sub-type", width = 92, align = "LEFT",
    desc = "Item sub-type (Cloth, Potion, Swords, …). Gold movements are sub-typed as Gold.",
    valueFn = function(e) return NS.Util.EntrySubType(e) end,
    sortFn = function(e) return NS.Util.EntrySubType(e):lower() end },
  -- Character is always the last column (see the order note above).
  { key = "char", label = "Character", width = 144, align = "LEFT",
    desc = "Who moved it — full Name-Realm, class-coloured, behind its class icon.",
    valueFn = function(e) return NS.Util.ClassIconMarkup(e.classFile) .. (e.char or "") end,
    sortFn = function(e) return (e.char or ""):lower() end },
}

local COLUMN_BY_KEY = {}
for _, col in ipairs(LT.COLUMNS) do COLUMN_BY_KEY[col.key] = col end

-- Pure cell text for a column key + entry (unit-tested; the UI binds through the same path).
function LT:CellText(key, entry)
  local col = COLUMN_BY_KEY[key]
  if not col then return "" end
  return col.valueFn(entry)
end

-- The column spec behind a key (label, width, align, desc, valueFn, sortFn), or nil.
--
-- Public because the session window (modules/SessionWindow.lua) renders a SUBSET of these same
-- columns in its own slim table. Sharing the spec — rather than restating widths and valueFns there
-- — is what guarantees the Item column shows the same text and measures the same width in both
-- windows. See also LT:PaintCell for the matching colour seam.
function LT:Column(key)
  return COLUMN_BY_KEY[key]
end

-- ── Pipeline ────────────────────────────────────────────────────────────────────
LT.filter = {}
LT.previewMode = false

-- Active sort. Default: newest movement first.
LT.sortKey = "date"
LT.sortAsc = false

-- Columns whose sortFn yields a number: a new sort on these starts descending (largest/newest
-- first); text columns start ascending (A→Z). Re-clicking the active column toggles.
local NUMERIC_SORT = { date = true, time = true, qty = true, quality = true }

-- Grouping. "none" = flat; otherwise entries are partitioned under collapsible headers.
LT.groupBy = "none"
LT.collapsed = {}
LT.groupAsc = true

-- The default WoW font has no ▲/▼ glyphs, so the arrows use inline texture markup. ":0" sizes the
-- texture to the surrounding line height.
local ARROW_ASC  = " |TInterface\\Buttons\\Arrow-Up-Up:0|t"
local ARROW_DESC = " |TInterface\\Buttons\\Arrow-Down-Up:0|t"

-- Group identity + display label for an entry under the active group-by. The key is namespaced by
-- group mode, so the collapsed-state map can never collide across modes. \001 is an unprintable
-- separator.
local function groupOf(groupBy, e)
  local raw, label
  if groupBy == "store" then
    label = C.StoreLabel[e.store] or e.store or "Unknown"; raw = e.store or "?"
  elseif groupBy == "direction" then
    label = C.DirectionLabel[e.direction] or e.direction or "?"; raw = e.direction or "?"
  elseif groupBy == "kind" then
    label = C.KindLabel[e.kind] or e.kind or "?"; raw = e.kind or "?"
  elseif groupBy == "type" or groupBy == "subtype" then
    -- The effective type, so gold movements gather under "Gold" exactly as the column shows them.
    label = (groupBy == "type") and NS.Util.EntryType(e) or NS.Util.EntrySubType(e)
    if label == "" then label = "Unknown" end
    raw = label
  elseif groupBy == "quality" then
    -- Keyed on the quality id, so the group sorts Poor→Legendary rather than alphabetically. Gold
    -- has no quality; it gathers under its own group instead of vanishing into "Poor".
    if e.quality == nil then
      label = "None"; raw = "none"
    else
      label = NS.Compat.QualityLabel(e.quality); raw = tostring(e.quality)
    end
  elseif groupBy == "char" then
    raw = e.char or "Unknown"; label = raw
  elseif groupBy == "day" then
    -- The key stays ISO (stable, unique per calendar day); the label matches the Date column.
    raw = date("%Y-%m-%d", e.ts or 0); label = NS.Util.FormatDate(e.ts or 0)
  else
    label = "?"; raw = "?"
  end
  return groupBy .. "\001" .. raw, label
end

-- groupBy mode → the table column it corresponds to (which drives the header arrow and the
-- group-order toggle) and the human prefix each group header carries.
local GROUP_COLUMN = { store = "store", direction = "direction", char = "char", day = "date",
                       type = "type", subtype = "subtype", quality = "quality" }
-- "kind" is the Item/Gold split, NOT the Type column — its prefix says so, now that Type groups too.
local GROUP_PREFIX = { store = "Store", direction = "Direction", kind = "Item/Gold",
                       char = "Character", day = "Day", type = "Type", subtype = "Sub-type",
                       quality = "Quality" }

-- Stable sort by the active column into a NEW array (entries are never mutated). Lua 5.1's
-- table.sort is not stable, so equal keys tiebreak on the original index to keep their prior order.
function LT:SortEntries(entries)
  local col = COLUMN_BY_KEY[self.sortKey]
  if not col or not col.sortFn then return entries end
  local keyFn, asc = col.sortFn, self.sortAsc
  local deco = {}
  for i = 1, #entries do
    deco[i] = { r = entries[i], i = i, k = keyFn(entries[i]) }
  end
  table.sort(deco, function(a, b)
    if a.k ~= b.k then
      if asc then return a.k < b.k end
      return a.k > b.k
    end
    return a.i < b.i
  end)
  local out = {}
  for i = 1, #deco do out[i] = deco[i].r end
  return out
end

-- Handle a header click. If the table is grouped by this column, flip the GROUP order; otherwise
-- set the row sort.
function LT:SetSort(key)
  local col = COLUMN_BY_KEY[key]
  if not col or not col.sortFn then return end
  local groupedCol = self.groupBy ~= "none" and GROUP_COLUMN[self.groupBy] or nil
  if key == groupedCol then
    self.groupAsc = not self.groupAsc
    self:UpdateHeaderArrows()
    self:Refresh()
    return
  end
  if self.sortKey == key then
    self.sortAsc = not self.sortAsc
  else
    self.sortKey = key
    self.sortAsc = not NUMERIC_SORT[key]
  end
  self:UpdateHeaderArrows()
  self:Refresh()
end

function LT:SetGroupBy(key)
  self.groupBy = key or "none"
  self:Refresh()
end

function LT:ToggleCollapse(key)
  self.collapsed[key] = (not self.collapsed[key]) or nil
  self:Refresh()
end

-- Turn an (already-sorted) entry array into the flat display list. With no grouping every entry is
-- a { kind = "row" } item; with grouping, entries are partitioned under { kind = "header" } items
-- labelled "<Column>: <Value>" with a count. A collapsed group emits only its header. The active
-- row sort still holds within each group.
function LT:GroupEntries(entries)
  local list = {}
  local groupBy = self.groupBy
  if not groupBy or groupBy == "none" then
    for _, e in ipairs(entries) do list[#list + 1] = { kind = "row", entry = e } end
    return list
  end

  local colKey = GROUP_COLUMN[groupBy]
  local col = colKey and COLUMN_BY_KEY[colKey]
  local sortFn = col and col.sortFn
  local prefix = GROUP_PREFIX[groupBy] or "?"

  local order, byKey = {}, {}
  for _, e in ipairs(entries) do
    local key, valueLabel = groupOf(groupBy, e)
    local g = byKey[key]
    if not g then
      g = { key = key, label = prefix .. ": " .. valueLabel, rows = {},
            sortKey = sortFn and sortFn(e) or valueLabel }
      byKey[key] = g
      order[#order + 1] = g
    end
    g.rows[#g.rows + 1] = e
  end

  local asc = self.groupAsc ~= false
  table.sort(order, function(a, b)
    if a.sortKey ~= b.sortKey then
      if asc then return a.sortKey < b.sortKey end
      return a.sortKey > b.sortKey
    end
    return a.key < b.key
  end)

  for _, g in ipairs(order) do
    local collapsed = self.collapsed[g.key] or false
    list[#list + 1] = { kind = "header", key = g.key, label = g.label,
                        count = #g.rows, collapsed = collapsed }
    if not collapsed then
      for _, e in ipairs(g.rows) do list[#list + 1] = { kind = "row", entry = e } end
    end
  end
  return list
end

-- The base dataset the table shows: the synthetic dataset in preview mode, else the live ledger.
function LT:CurrentEntries()
  return NS.Database:ActiveLedger()
end

-- Filter → sort → group into the flat display list the virtualizer binds. matchCount is the number
-- of entries that passed the filter (the "X" the footer shows), captured before grouping inserts
-- header items.
function LT:BuildDisplayList()
  local entries = NS.Database:QueryList(self:CurrentEntries(), self.filter)
  self.matchCount = #entries
  return self:GroupEntries(self:SortEntries(entries))
end

function LT:SetFilter(filter)
  self.filter = filter or {}
  self:Refresh()
end

-- The filtered entries in the current sort/group order (group headers dropped) — the "Current View"
-- dataset the Export modal serializes, so what you export is what you see.
function LT:OrderedFilteredEntries()
  local out = {}
  for _, item in ipairs(self:BuildDisplayList()) do
    if item.kind == "row" then out[#out + 1] = item.entry end
  end
  return out
end

-- ── Preview dataset (preview-mode) ──────────────────────────────────────────────
-- A synthetic ledger so the window and the Insights charts can be seen (and positioned) without
-- waiting to actually fill a bank. A deterministic PRNG — a fixed seed, NOT math.random — keeps the
-- data byte-identical every run, so the headless tests can assert on it.
local PREVIEW_ITEMS = {
  { 2589,  "Linen Cloth",           1, "Tradegoods", "Cloth" },
  { 4306,  "Silk Cloth",            1, "Tradegoods", "Cloth" },
  { 171276,"Spectral Flask",        3, "Consumable", "Flask" },
  { 19019, "Thunderfury",           5, "Weapon",     "Swords" },
  { 6948,  "Hearthstone",           1, "Miscellaneous", "Junk" },
  { 194863,"Serevite Ore",          1, "Tradegoods", "Metal" },
  { 190316,"Refreshing Healing Potion", 2, "Consumable", "Potion" },
  { 200071,"Dragon Isles Herb",     2, "Tradegoods", "Herb" },
}
local PREVIEW_STORES = { "BANK", "WARBAND_BANK", "GUILD_BANK" }
local PREVIEW_CHARS = {
  { "Mageling-Ravencrest", "MAGE" },
  { "Tankadin-Ravencrest", "PALADIN" },
  { "Sneakerz-Ravencrest", "ROGUE" },
}
local PREVIEW_DAY, PREVIEW_SPAN_DAYS = 86400, 21

-- Minimal-standard (Park–Miller) LCG: products stay below 2^46, so the double arithmetic is exact
-- and the sequence is identical on every platform. rng(n) returns an integer in [1, n].
local function previewRng(seed)
  local state = seed % 2147483647
  if state <= 0 then state = state + 2147483646 end
  return function(n)
    state = (state * 16807) % 2147483647
    return (state % n) + 1
  end
end

function LT:BuildPreviewData()
  local now = time()
  local rng = previewRng(0x0BA17ED9)   -- fixed seed → an identical dataset every run
  local out = {}

  local function push(store, dir, itemIdx, ch, dayOffset)
    local it = PREVIEW_ITEMS[itemIdx]
    local who = PREVIEW_CHARS[ch]
    local qty = (it[3] >= 4) and 1 or (1 + rng(40))
    out[#out + 1] = {
      ts = now - dayOffset * PREVIEW_DAY - rng(80000),
      char = who[1], classFile = who[2],
      kind = C.Kind.ITEM, direction = dir, store = store,
      guild = (store == "GUILD_BANK") and "Ka0s" or nil,
      itemID = it[1], itemName = it[2], quality = it[3],
      itemType = it[4], itemSubType = it[5],
      quantity = qty,
      zone = "Valdrakken", mapID = 2112,
    }
  end

  -- Coverage seed: every store, both directions and every character appear at least once, and the
  -- timestamps reach both ends of the window, whatever the dice do afterwards.
  for i = 1, PREVIEW_SPAN_DAYS do
    push(PREVIEW_STORES[((i - 1) % #PREVIEW_STORES) + 1],
         (i % 2 == 0) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
         ((i - 1) % #PREVIEW_ITEMS) + 1,
         ((i - 1) % #PREVIEW_CHARS) + 1,
         (i - 1) % PREVIEW_SPAN_DAYS)
  end

  -- Weighted bulk: deposits outnumber withdrawals, as a real bank does.
  for _ = 1, 140 do
    push(PREVIEW_STORES[rng(#PREVIEW_STORES)],
         (rng(10) <= 6) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
         rng(#PREVIEW_ITEMS), rng(#PREVIEW_CHARS), rng(PREVIEW_SPAN_DAYS) - 1)
  end

  -- Gold movements, at the two stores that hold gold.
  for i = 1, 24 do
    local store = (i % 2 == 0) and "WARBAND_BANK" or "GUILD_BANK"
    local who = PREVIEW_CHARS[rng(#PREVIEW_CHARS)]
    out[#out + 1] = {
      ts = now - (rng(PREVIEW_SPAN_DAYS) - 1) * PREVIEW_DAY - rng(80000),
      char = who[1], classFile = who[2],
      kind = C.Kind.MONEY,
      direction = (rng(10) <= 7) and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
      store = store,
      guild = (store == "GUILD_BANK") and "Ka0s" or nil,
      itemName = "Gold",
      quantity = rng(500) * 10000,
      zone = "Valdrakken", mapID = 2112,
    }
  end

  return out
end

-- Toggle the preview dataset (`/bl preview`). Publishing it to State means every read-path query —
-- the table AND Insights — resolves against the same data, through the real render path
-- (preview-mode).
function LT:TogglePreview()
  self.previewMode = not self.previewMode
  NS.State.testRecords = self.previewMode and self:BuildPreviewData() or nil
  if NS.Browser and NS.Browser.Show then NS.Browser:Show() end
  if NS.Browser and NS.Browser.OnDatasetChanged then
    NS.Browser:OnDatasetChanged()
  else
    self:Refresh()
  end
  return self.previewMode
end

-- ── Pooled rows ─────────────────────────────────────────────────────────────────

local function qualityColor(q)
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

-- Paint ONE cell: set its text from the column's valueFn and its colour from the shared palette.
--
-- The single definition of "what colour is this cell", so the History table and the session window's
-- slim table can never disagree. `glyphFS` is the row's direction glyph FontString; pass it only for
-- the "direction" column (any other column ignores it).
function LT:PaintCell(fs, colKey, entry, glyphFS)
  local col = COLUMN_BY_KEY[colKey]
  if not (fs and col and entry) then return end
  fs:SetText(col.valueFn(entry))
  if colKey == "item" or colKey == "quality" then
    if entry.kind == C.Kind.MONEY then
      fs:SetTextColor(MONEY_RGB[1], MONEY_RGB[2], MONEY_RGB[3])
    else
      fs:SetTextColor(qualityColor(entry.quality))
    end
  elseif colKey == "direction" then
    local rgb = C.DirectionRGB[entry.direction] or C.NEUTRAL_RGB
    fs:SetTextColor(rgb[1], rgb[2], rgb[3])
    if glyphFS then
      local glyph = C.DirectionGlyph[entry.direction]
      glyphFS:SetText(glyph or "")
      glyphFS:SetTextColor(rgb[1], rgb[2], rgb[3])
      glyphFS:SetShown(glyph ~= nil)
    end
  elseif colKey == "store" then
    local rgb = C.StoreRGB[entry.store] or C.NEUTRAL_RGB
    fs:SetTextColor(rgb[1], rgb[2], rgb[3])
  elseif colKey == "char" then
    local cc = RAID_CLASS_COLORS and entry.classFile and RAID_CLASS_COLORS[entry.classFile]
    if cc then fs:SetTextColor(cc.r, cc.g, cc.b) else fs:SetTextColor(0.9, 0.9, 0.9) end
  else
    fs:SetTextColor(0.9, 0.9, 0.9)
  end
end

function LT:AcquireRow()
  local pool = self.rowPool
  local row = table.remove(pool.free)
  if row then
    row:Show()
    return row
  end

  row = CreateFrame("Button", nil, self.rowHost)
  row:SetHeight(ROW_H)
  row:SetPoint("LEFT", self.rowHost, "LEFT", 0, 0)
  row:SetPoint("RIGHT", self.rowHost, "RIGHT", 0, 0)

  local stripe = row:CreateTexture(nil, "BACKGROUND")
  stripe:SetAllPoints()
  stripe:SetColorTexture(1, 1, 1, 0.03)
  row.stripe = stripe

  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0, 0.10)

  -- One FontString per data column, laid out left→right with the Item column flexing.
  row.cells = {}
  for _, col in ipairs(self.COLUMNS) do
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH(col.align)
    fs:SetHeight(ROW_H)
    fs:SetWordWrap(false)
    row.cells[col.key] = fs
  end

  -- The direction glyph, drawn to the left of the In/Out text and coloured with it.
  local glyph = row:CreateFontString(nil, "OVERLAY")
  glyph:SetFont(C.FONT_MONO, ARROW_SIZE, "")
  glyph:SetJustifyH("CENTER")
  glyph:SetWidth(ARROW_SIZE)
  glyph:SetHeight(ROW_H)
  glyph:Hide()
  row.dirGlyph = glyph

  -- Group-header styling; hidden for data rows.
  local header = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  header:SetPoint("LEFT", 4, 0)
  header:SetTextColor(1, 0.82, 0)
  header:Hide()
  row.header = header

  row:SetScript("OnEnter", function(self2)
    local item = self2.item
    if not (item and item.kind == "row") then return end
    local e = item.entry
    if not GameTooltip then return end
    if e.itemLink then
      GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(e.itemLink)
      GameTooltip:AddLine("Shift-click to link \194\183 right-click for options", 0.5, 0.5, 0.5)
      GameTooltip:Show()
    elseif e.kind == C.Kind.MONEY then
      -- A gold movement has no item to hover, so build the tooltip by hand rather than leave the
      -- row silent: the amount is the one thing the Qty cell can truncate.
      GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
      GameTooltip:AddLine(C.KindLabel.MONEY, MONEY_RGB[1], MONEY_RGB[2], MONEY_RGB[3])
      GameTooltip:AddDoubleLine("Amount", NS.Util.FormatMoney(e.quantity), 0.9, 0.9, 0.9, 1, 1, 1)
      GameTooltip:AddLine("Right-click for options", 0.5, 0.5, 0.5)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  -- A header left-click toggles collapse. Data rows: shift-left-click links the item to chat;
  -- right-click opens the row action menu.
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:SetScript("OnClick", function(self2, button)
    local item = self2.item
    if not item then return end
    if item.kind == "header" then
      if button == "LeftButton" then LT:ToggleCollapse(item.key) end
      return
    end
    local link = item.entry.itemLink
    if button == "LeftButton" then
      if IsShiftKeyDown() and link and ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
      end
    elseif button == "RightButton" then
      LT:ShowRowMenu(self2, item.entry)
    end
  end)

  self:LayoutRowCells(row)
  return row
end

-- Width available for columns (the row host's viewport), with a fallback before first layout.
function LT:ContentWidth()
  local w = self.rowHost and self.rowHost:GetWidth()
  if not w or w <= 0 then return 900 end
  return w
end

-- The minimum window width that shows every column without truncation: fixed column widths + gaps
-- + the Item column's minimum + the scrollbar gutter + the pane margins. The Browser uses this as
-- both the default and the minimum window width, so columns can never overflow.
function LT:MinFrameWidth()
  local w = 0
  for _, col in ipairs(self.COLUMNS) do
    w = w + (col.flex and ITEM_MIN or col.width) + COL_GAP
  end
  return math.ceil(w + 24 + 12)
end

-- Position each cell by cumulative column widths; the flex column takes the slack.
function LT:LayoutRowCells(row)
  local total = self:ContentWidth()
  local fixed = 0
  for _, col in ipairs(self.COLUMNS) do
    if not col.flex then fixed = fixed + col.width + COL_GAP end
  end
  local flexW = math.max(ITEM_MIN, total - fixed)

  local x = 0
  for _, col in ipairs(self.COLUMNS) do
    local w = col.flex and flexW or col.width
    local fs = row.cells[col.key]
    fs:ClearAllPoints()
    -- The In/Out cell gives its first ARROW_SIZE+ARROW_GAP pixels to the direction glyph.
    if col.key == "direction" and row.dirGlyph then
      row.dirGlyph:ClearAllPoints()
      row.dirGlyph:SetPoint("LEFT", row, "LEFT", x, 0)
      fs:SetPoint("LEFT", row, "LEFT", x + ARROW_SIZE + ARROW_GAP, 0)
      fs:SetWidth(math.max(1, w - ARROW_SIZE - ARROW_GAP))
    else
      fs:SetPoint("LEFT", row, "LEFT", x, 0)
      fs:SetWidth(w)
    end
    x = x + w + COL_GAP
  end
end

function LT:ReleaseAllRows()
  local pool = self.rowPool
  for _, row in ipairs(pool.active) do
    row:Hide()
    pool.free[#pool.free + 1] = row
  end
  for i = #pool.active, 1, -1 do pool.active[i] = nil end
end

-- ── Attach + render ─────────────────────────────────────────────────────────────

function LT:Attach(pane)
  if self.frame then return end
  self.pane = pane

  -- Header row (its right inset matches the row host, so header columns line up with data cells).
  local header = CreateFrame("Frame", nil, pane)
  header:SetPoint("TOPLEFT", 0, 0)
  header:SetPoint("TOPRIGHT", -24, 0)
  header:SetHeight(HEADER_H)
  self.headerFrame = header

  -- A FauxScrollFrame drives the scrollbar + offset. Pooled rows live in a sibling overlay
  -- (rowHost) aligned with the scroll viewport, so the ScrollFrame never clips them.
  local scroll = CreateFrame("ScrollFrame", nil, pane, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  -- The bottom is raised 16px so the scrollbar's down-arrow clears the window resize grip.
  scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -24, 16)
  scroll:SetScript("OnVerticalScroll", function(self2, offset)
    FauxScrollFrame_OnVerticalScroll(self2, offset, ROW_H, function() LT:Bind() end)
  end)
  scroll:SetScript("OnSizeChanged", function() LT:Bind() end)
  self.scroll = scroll

  local host = CreateFrame("Frame", nil, pane)
  host:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  host:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
  self.rowHost = host

  self.rowPool = { active = {}, free = {} }

  local empty = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
  empty:SetPoint("CENTER", scroll, "CENTER", 0, 0)
  empty:Hide()
  self.emptyText = empty

  self:BuildHeaderCells()
  self.frame = pane
  self:Refresh()
end

function LT:MakeHeaderButton(col)
  local btn = CreateFrame("Button", nil, self.headerFrame)
  btn:SetHeight(HEADER_H)
  local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("LEFT", 0, 0)
  fs:SetJustifyH(col.align)
  fs:SetText(col.label)
  fs:SetTextColor(1, 0.82, 0)
  btn.fs = fs
  btn:SetScript("OnEnter", function(self2)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self2, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(col.label, 1, 0.82, 0)
    if col.desc then GameTooltip:AddLine(col.desc, 0.9, 0.9, 0.9, true) end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  btn:SetScript("OnClick", function() LT:SetSort(col.key) end)
  return btn
end

-- Repaint the sort arrow: the grouped column shows the group-order arrow, the row-sort column the
-- sort arrow, everything else its bare label.
function LT:UpdateHeaderArrows()
  local header = self.headerFrame
  if not header or not header.buttons then return end
  local groupedCol = self.groupBy ~= "none" and GROUP_COLUMN[self.groupBy] or nil
  for key, btn in pairs(header.buttons) do
    if btn.fs then
      local col = COLUMN_BY_KEY[key]
      local label = col and col.label or ""
      if key == groupedCol then
        label = label .. (self.groupAsc and ARROW_ASC or ARROW_DESC)
      elseif key == self.sortKey then
        label = label .. (self.sortAsc and ARROW_ASC or ARROW_DESC)
      end
      btn.fs:SetText(label)
    end
  end
end

function LT:BuildHeaderCells()
  local header = self.headerFrame
  header.buttons = header.buttons or {}
  local total = self:ContentWidth()
  local fixed = 0
  for _, col in ipairs(self.COLUMNS) do
    if not col.flex then fixed = fixed + col.width + COL_GAP end
  end
  local flexW = math.max(ITEM_MIN, total - fixed)

  local x = 0
  for _, col in ipairs(self.COLUMNS) do
    local w = col.flex and flexW or col.width
    local btn = header.buttons[col.key]
    if not btn then
      btn = self:MakeHeaderButton(col)
      header.buttons[col.key] = btn
    end
    btn:ClearAllPoints()
    btn:SetPoint("LEFT", header, "LEFT", x, 0)
    btn:SetWidth(w)
    if btn.fs then btn.fs:SetWidth(w) end
    x = x + w + COL_GAP
  end
  self:UpdateHeaderArrows()
end

-- Pure one-line render summary for the [Table] trace: one line per render pass, never one per row
-- (debug-logging-§9). filterCount is the number of active filter keys.
function LT.RenderSummary(matchCount, total, filterCount, groupBy, sortKey, sortAsc)
  return ("rendered %s/%s rows (group=%s, sort=%s %s, filters=%s)"):format(
    tostring(matchCount), tostring(total), tostring(groupBy or "none"),
    tostring(sortKey), sortAsc and "asc" or "desc", tostring(filterCount or 0))
end

-- Recompute the display list and repaint. A safe no-op before Attach.
function LT:Refresh()
  if not self.frame then return end
  self.displayList = self:BuildDisplayList()
  self:Bind()
  if NS.State.debug and NS.Debug then
    local total = #(NS.Database:ActiveLedger() or {})
    local fc = 0
    for _ in pairs(self.filter or {}) do fc = fc + 1 end
    NS.Debug("Table", "%s", LT.RenderSummary(
      self.matchCount or 0, total, fc, self.groupBy, self.sortKey, self.sortAsc))
  end
end

-- Bind the visible slice of the display list onto pooled rows.
function LT:Bind()
  if not self.frame then return end
  self:BuildHeaderCells()   -- keep header columns aligned with rows across resizes
  local list = self.displayList or {}
  local scroll = self.scroll
  local viewH = scroll:GetHeight()
  if type(viewH) ~= "number" or viewH <= 0 then viewH = ROW_H * 20 end
  local numVisible = math.max(1, math.floor(viewH / ROW_H))

  FauxScrollFrame_Update(scroll, #list, numVisible, ROW_H)
  local offset = FauxScrollFrame_GetOffset(scroll) or 0

  self:ReleaseAllRows()
  self.emptyText:SetShown(#list == 0)
  if #list == 0 then
    self.emptyText:SetText(next(self.filter or {}) and "No movements match your filters."
      or "No bank movements recorded yet. Open your bank and move something.")
    return
  end

  local pool = self.rowPool
  for i = 1, numVisible do
    local item = list[offset + i]
    if item then
      local row = self:AcquireRow()
      row:SetPoint("TOP", self.rowHost, "TOP", 0, -(i - 1) * ROW_H)
      self:LayoutRowCells(row)
      self:BindRow(row, item, offset + i)
      pool.active[#pool.active + 1] = row
    end
  end
end

function LT:BindRow(row, item, absIndex)
  row.item = item
  row.stripe:SetShown(absIndex % 2 == 0)

  if item.kind == "header" then
    for _, col in ipairs(self.COLUMNS) do row.cells[col.key]:SetText("") end
    row.dirGlyph:Hide()
    row.header:Show()
    -- +/- box marks collapsed/expanded. Texture markup, not a glyph: this is inline in the header's
    -- own label, which uses the GAME font (no ▲/▼ there — only the vendored mono font has them).
    local arrow = item.collapsed and "|TInterface\\Buttons\\UI-PlusButton-Up:0|t"
      or "|TInterface\\Buttons\\UI-MinusButton-Up:0|t"
    row.header:SetText(arrow .. "  " .. (item.label or "")
      .. "  |cff808080(" .. (item.count or 0) .. ")|r")
    return
  end

  row.header:Hide()
  local e = item.entry
  for _, col in ipairs(self.COLUMNS) do
    self:PaintCell(row.cells[col.key], col.key,
      e, col.key == "direction" and row.dirGlyph or nil)
  end
end

-- ── Row context menu (right-click) ──────────────────────────────────────────────
local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"
local rowMenu
local function EnsureRowMenu()
  if rowMenu then return rowMenu end
  rowMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  rowMenu:SetFrameStrata("FULLSCREEN_DIALOG")
  rowMenu:SetBackdrop({ bgFile = WHITE8X8, edgeFile = WHITE8X8, edgeSize = 1 })
  rowMenu:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
  rowMenu:SetBackdropBorderColor(0.62, 0.5, 0.18, 1)
  rowMenu:Hide()
  rowMenu.buttons = {}

  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN")
  catcher:Hide()
  catcher:SetScript("OnClick", function() rowMenu:Hide() end)
  catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  rowMenu.catcher = catcher
  rowMenu:SetScript("OnHide", function() catcher:Hide() end)
  return rowMenu
end

function LT:ShowRowMenu(anchor, entry)
  local m = EnsureRowMenu()
  local MENU_ROW_H, W = 18, 160
  local items = {
    { label = "Link to chat", enabled = entry.itemLink ~= nil, fn = function()
        if entry.itemLink and ChatEdit_InsertLink then ChatEdit_InsertLink(entry.itemLink) end
      end },
    -- Blacklisting is point-in-time: it stops FUTURE movements of this id being recorded and leaves
    -- every stored row alone. Manage the list in Settings ▸ Filters.
    { label = "Blacklist item", enabled = entry.itemID ~= nil, fn = function()
        if NS.Filters:AddBlacklist(entry.itemID) then
          NS.Print(("blacklisted %s. Manage in Settings \226\150\184 Filters."):format(
            entry.itemName or ("item " .. tostring(entry.itemID))))
        end
      end },
    { label = "Whitelist item", enabled = entry.itemID ~= nil, fn = function()
        if NS.Filters:AddWhitelist(entry.itemID) then
          NS.Print(("whitelisted %s. Manage in Settings \226\150\184 Filters."):format(
            entry.itemName or ("item " .. tostring(entry.itemID))))
        end
      end },
    { label = "|cffff5555Delete|r", enabled = true, fn = function()
        NS.Database:Delete(function(r) return r == entry end)   -- fires LedgerChanged
        LT:Refresh()
      end },
  }

  for _, b in ipairs(m.buttons) do b:Hide() end
  for i, item in ipairs(items) do
    local b = m.buttons[i]
    if not b then
      b = CreateFrame("Button", nil, m)
      b:SetHeight(MENU_ROW_H)
      local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("LEFT", 8, 0)
      fs:SetJustifyH("LEFT")
      b.fs = fs
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 0.82, 0, 0.15)
      m.buttons[i] = b
    end
    b:SetWidth(W)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 0, -4 - (i - 1) * MENU_ROW_H)
    b.fs:SetText(item.label)
    if item.enabled then
      b.fs:SetTextColor(0.9, 0.9, 0.9)
      b:EnableMouse(true)
      b:SetScript("OnClick", function() m:Hide(); item.fn() end)
    else
      b.fs:SetTextColor(0.5, 0.5, 0.5)
      b:EnableMouse(false)
      b:SetScript("OnClick", nil)
    end
    b:Show()
  end

  m:SetSize(W, #items * MENU_ROW_H + 8)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, 0)
  m.catcher:Show()
  m:Show()
end
