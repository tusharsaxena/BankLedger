local addonName, NS = ...   -- luacheck: ignore addonName
NS.SessionWindow = NS.SessionWindow or {}
local SW = NS.SessionWindow
local C = NS.Constants

-- The "Current Banking Session" window (standalone-windows): a small, live passbook of what you move
-- during ONE visit to a bank, opened automatically whenever a storage frame is open.
--
-- A banking session is the span between a storage frame opening and closing — exactly the span
-- modules/Ledger.lua already arms `NS.State.openContext` for — so this window rides the
-- Ka0s_BankLedger_SessionChanged message rather than re-deriving the span from the open/close events.
-- That matters for the guild bank, which gets no usable open event and is armed by the arrival of tab
-- data instead.
--
-- Nothing here is persisted but the window's geometry. Session rows are REFERENCES to the entries
-- Database:Add already stored, held in NS.State.sessionEntries and dropped when the frame closes —
-- there is no second copy of the ledger and no new SavedVariables field.
--
-- It is deliberately NOT a second instance of NS.LedgerTable. That module is a stateful singleton
-- (one row pool, one display list, one sort/group/filter/collapse state) and this table has no
-- sorting, no grouping, no filtering and no collapsing — so a slim renderer is smaller than the
-- refactor that would generalise it. What is NOT duplicated is the definition of a column: the
-- widths, labels, tooltips, cell text and cell colours all come from LedgerTable's public
-- `Column` / `PaintCell` seams, so a column reads identically in both windows.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROW_H = 18
local HEADER_H = 20
local COL_GAP = 8
local ITEM_MIN = 150          -- minimum width of the flex (Item) column
local SCROLLBAR_GUTTER = 24
local PANE_MARGIN = 12
local ARROW_SIZE, ARROW_GAP = 12, 2
local TITLE = "Ka0s Bank Ledger - Current Banking Session"

-- The History window's columns, minus the four the session view has no use for:
--   * date/time  — every row happened moments ago, during this session
--   * char       — capture only ever records the logged-in character's own movements
-- Order matches the History table, so the two windows read the same left-to-right.
SW.COLUMN_KEYS = { "direction", "store", "item", "qty", "quality", "type", "subtype" }

-- Default and minimum window size. The width is DERIVED from the column model (below) so it can
-- never be too narrow for the columns it must show; the height is a comfortable ~13 rows.
local DEFAULT_H, MIN_H = 320, 200

local frame

-- ── Column geometry ─────────────────────────────────────────────────────────────

-- The column specs this window renders, resolved from LedgerTable. Resolved lazily (not at load)
-- because the TOC loads this file after LedgerTable but a nil-safe read is cheaper than a load-order
-- assumption.
function SW:Columns()
  local cols = {}
  for _, key in ipairs(self.COLUMN_KEYS) do
    local col = NS.LedgerTable and NS.LedgerTable.Column and NS.LedgerTable:Column(key)
    if col then cols[#cols + 1] = col end
  end
  return cols
end

-- The minimum (and default-open) window width: every fixed column at full width, the Item column at
-- its minimum, one gap each, plus the scrollbar gutter and the pane margins. Pure — unit-tested.
function SW:MinFrameWidth()
  local w = 0
  for _, col in ipairs(self:Columns()) do
    w = w + (col.flex and ITEM_MIN or col.width) + COL_GAP
  end
  return math.ceil(w + SCROLLBAR_GUTTER + PANE_MARGIN)
end

-- Width available to the columns right now, with a pre-layout fallback.
local function contentWidth()
  local w = SW.rowHost and SW.rowHost:GetWidth()
  if type(w) ~= "number" or w <= 0 then return SW:MinFrameWidth() - SCROLLBAR_GUTTER - PANE_MARGIN end
  return w
end

-- Cumulative x offset + width for each column, with the Item column absorbing the slack. Shared by
-- the header cells and the row cells so the two can never drift apart.
function SW:ColumnLayout()
  local cols = self:Columns()
  local fixed = 0
  for _, col in ipairs(cols) do
    if not col.flex then fixed = fixed + col.width + COL_GAP end
  end
  local flexW = math.max(ITEM_MIN, contentWidth() - fixed)
  local out, x = {}, 0
  for _, col in ipairs(cols) do
    local w = col.flex and flexW or col.width
    out[#out + 1] = { col = col, x = x, width = w }
    x = x + w + COL_GAP
  end
  return out
end

-- ── Session data ────────────────────────────────────────────────────────────────

function SW:Entries()
  return NS.State.sessionEntries or {}
end

-- Is the window allowed to appear at all? The setting gates the WINDOW only — capture is untouched,
-- so turning it off loses no history.
function SW:Enabled()
  local s = NS.db and NS.db.global and NS.db.global.settings
  if not s then return true end
  return s.showSessionWindow ~= false
end

-- A session started: throw away the previous visit's rows and open on an empty table. Clearing here
-- (rather than on close) is what makes the window answer "what did I do THIS visit".
function SW:StartSession(context)
  NS.State.sessionEntries = {}
  NS.State.sessionActive = true
  SW.previewSession = false
  SW.context = context
  if NS.State.debug and NS.Debug then
    NS.Debug("Session", "started (%s)", tostring(context))
  end
  if self:Enabled() then self:Show() else self:Hide() end
end

function SW:EndSession()
  NS.State.sessionActive = false
  SW.context = nil
  if NS.State.debug and NS.Debug then
    NS.Debug("Session", "ended, %s movements", tostring(#self:Entries()))
  end
  self:Hide()
  NS.State.sessionEntries = {}
end

-- A movement was recorded. Only movements made DURING a session belong here; anything else (a
-- preview dataset toggle, a future backfill) is ignored rather than silently attributed to a visit
-- that isn't happening.
function SW:OnEntryAdded(entry)
  if not (NS.State.sessionActive and entry) then return end
  local list = NS.State.sessionEntries
  list[#list + 1] = entry
  self:Refresh()
end

-- The stored ledger changed under us (a row deleted from the History table, a purge, a retention
-- prune). Drop any session row that no longer exists, so this view can never outlive its data.
function SW:PruneMissing()
  if SW.previewSession then return 0 end
  local present = {}
  for _, e in ipairs((NS.Database and NS.Database:Ledger()) or {}) do present[e] = true end
  local kept, dropped = {}, 0
  for _, e in ipairs(self:Entries()) do
    if present[e] then kept[#kept + 1] = e else dropped = dropped + 1 end
  end
  NS.State.sessionEntries = kept
  if dropped > 0 then self:Refresh() end
  return dropped
end

-- Newest movement first, matching the History window's default sort. A fresh array each time, so the
-- session list itself is never reordered in place.
function SW:DisplayList()
  local src = self:Entries()
  local out = {}
  for i = #src, 1, -1 do out[#out + 1] = src[i] end
  return out
end

-- ── Preview session (preview-mode) ──────────────────────────────────────────────
-- The window is positionable, so it must be placeable without waiting to actually stand at a bank
-- (preview-mode). `/bl session` opens it on a synthetic visit fed through the REAL render path. The
-- rows are never recorded, and a real session opening replaces them.

local PREVIEW_ROWS = {
  { "WITHDRAW", "BANK",         2589,   "Linen Cloth",     1, "Tradegoods",    "Cloth",  20,     40 },
  { "DEPOSIT",  "BANK",         194863, "Serevite Ore",    1, "Tradegoods",    "Metal",  35,     200 },
  { "DEPOSIT",  "WARBAND_BANK", 171276, "Spectral Flask",  3, "Consumable",    "Flask",  5000,   4 },
  { "WITHDRAW", "WARBAND_BANK", 19019,  "Thunderfury",     5, "Weapon",        "Swords", 250000, 1 },
  { "DEPOSIT",  "GUILD_BANK",   6948,   "Hearthstone",     1, "Miscellaneous", "Junk",   0,      1 },
}

function SW:BuildPreviewSession()
  local _, classFile = UnitClass("player")
  local now = time()
  local out = {}
  for i, r in ipairs(PREVIEW_ROWS) do
    out[#out + 1] = {
      ts = now - (#PREVIEW_ROWS - i) * 20,
      char = NS.Util.PlayerKey(), classFile = classFile,
      kind = C.Kind.ITEM, direction = r[1], store = r[2],
      guild = (r[2] == "GUILD_BANK") and NS.Compat.GetGuildName() or nil,
      itemID = r[3], itemName = r[4], quality = r[5],
      itemType = r[6], itemSubType = r[7], vendorPrice = r[8], quantity = r[9],
    }
  end
  -- One gold movement, at a store that actually holds gold.
  out[#out + 1] = {
    ts = now, char = NS.Util.PlayerKey(), classFile = classFile,
    kind = C.Kind.MONEY, direction = C.Direction.DEPOSIT, store = "WARBAND_BANK",
    itemName = "Gold", quantity = 1234567,
  }
  return out
end

-- Toggle a synthetic session so the window can be positioned on demand. A no-op refusal while a REAL
-- session is open — that data is the point, and replacing it with placeholders would be a lie.
function SW:TogglePreview()
  if NS.State.sessionActive and not SW.previewSession then return nil end
  if SW.previewSession then
    SW.previewSession = false
    NS.State.sessionEntries = {}
    self:Hide()
    return false
  end
  SW.previewSession = true
  NS.State.sessionEntries = self:BuildPreviewSession()
  self:Show()
  return true
end

-- ── Window geometry persistence ─────────────────────────────────────────────────
-- settings.sessionWindow = { point, x, y, w, h }. A storage carve-out written directly here, exactly
-- as settings.window is for the main window: geometry is runtime view state that standalone-windows
-- requires be persisted and that has no place in the settings panel (architecture-§5).

local function saveWindow()
  if not frame then return end
  local point, _, _, x, y = frame:GetPoint(1)
  if not (NS.db and NS.db.global and NS.db.global.settings) then return end
  NS.db.global.settings.sessionWindow = {
    point = point, x = x, y = y, w = frame:GetWidth(), h = frame:GetHeight(),
  }
end

local function restoreWindow()
  local g = NS.db and NS.db.global and NS.db.global.settings.sessionWindow
  frame:ClearAllPoints()
  if g and g.point then
    frame:SetPoint(g.point, UIParent, g.point, g.x or 0, g.y or 0)
    if type(g.w) == "number" and type(g.h) == "number" then
      frame:SetSize(math.max(SW._minW or 0, g.w), math.max(MIN_H, g.h))
    end
  else
    -- Default: right of centre, clear of the bank frame rather than on top of it.
    frame:SetPoint("CENTER", UIParent, "CENTER", 420, 0)
  end
end

function SW:ResetWindow()
  if NS.db and NS.db.global and NS.db.global.settings then
    NS.db.global.settings.sessionWindow = {}
  end
  if frame then
    frame:SetSize(SW._minW or 0, DEFAULT_H)
    restoreWindow()
  end
end

-- ── Pooled rows ─────────────────────────────────────────────────────────────────

function SW:AcquireRow()
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

  row.cells = {}
  for _, col in ipairs(self:Columns()) do
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH(col.align)
    fs:SetHeight(ROW_H)
    fs:SetWordWrap(false)
    row.cells[col.key] = fs
  end

  -- The ▲/▼ direction glyph, in the vendored mono font for the same reason (and under the same
  -- documented deviation) as the History table's: WoW's default font renders both as a box.
  local glyph = row:CreateFontString(nil, "OVERLAY")
  glyph:SetFont(C.FONT_MONO, ARROW_SIZE, "")
  glyph:SetJustifyH("CENTER")
  glyph:SetWidth(ARROW_SIZE)
  glyph:SetHeight(ROW_H)
  glyph:Hide()
  row.dirGlyph = glyph

  -- Shift-left-click links the item, exactly as in the History table. No right-click menu here: its
  -- actions (delete, blacklist) belong to the history view, not to a live session read-out.
  row:RegisterForClicks("LeftButtonUp")
  row:SetScript("OnClick", function(self2)
    local e = self2.entry
    if e and e.itemLink and IsShiftKeyDown() and ChatEdit_InsertLink then
      ChatEdit_InsertLink(e.itemLink)
    end
  end)
  row:SetScript("OnEnter", function(self2)
    local e = self2.entry
    if not (e and GameTooltip) then return end
    if e.itemLink then
      GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(e.itemLink)
      GameTooltip:Show()
    elseif e.kind == C.Kind.MONEY then
      GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
      GameTooltip:AddLine(C.KindLabel.MONEY, 1, 0.91, 0.55)
      GameTooltip:AddDoubleLine("Amount", NS.Util.FormatMoney(e.quantity), 0.9, 0.9, 0.9, 1, 1, 1)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  self:LayoutRowCells(row)
  return row
end

function SW:LayoutRowCells(row)
  for _, slot in ipairs(self:ColumnLayout()) do
    local fs = row.cells[slot.col.key]
    if fs then
      fs:ClearAllPoints()
      -- The In/Out cell gives its first ARROW_SIZE+ARROW_GAP pixels to the direction glyph.
      if slot.col.key == "direction" and row.dirGlyph then
        row.dirGlyph:ClearAllPoints()
        row.dirGlyph:SetPoint("LEFT", row, "LEFT", slot.x, 0)
        fs:SetPoint("LEFT", row, "LEFT", slot.x + ARROW_SIZE + ARROW_GAP, 0)
        fs:SetWidth(math.max(1, slot.width - ARROW_SIZE - ARROW_GAP))
      else
        fs:SetPoint("LEFT", row, "LEFT", slot.x, 0)
        fs:SetWidth(slot.width)
      end
    end
  end
end

function SW:ReleaseAllRows()
  local pool = self.rowPool
  for _, row in ipairs(pool.active) do
    row:Hide()
    pool.free[#pool.free + 1] = row
  end
  for i = #pool.active, 1, -1 do pool.active[i] = nil end
end

-- ── Header ──────────────────────────────────────────────────────────────────────
-- Plain FontStrings on a plain frame, NOT Buttons: the session view has no sort, so a clickable
-- header would be a control that does nothing. The column tooltip is kept — it explains the column
-- rather than acting on it — so it hangs off a mouse-enabled, click-less frame.

function SW:BuildHeaderCells()
  local header = self.headerFrame
  header.cells = header.cells or {}
  for _, slot in ipairs(self:ColumnLayout()) do
    local col = slot.col
    local cell = header.cells[col.key]
    if not cell then
      cell = CreateFrame("Frame", nil, header)
      cell:SetHeight(HEADER_H)
      cell:EnableMouse(true)
      local fs = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      fs:SetPoint("LEFT", 0, 0)
      fs:SetJustifyH(col.align)
      fs:SetText(col.label)
      fs:SetTextColor(1, 0.82, 0)
      cell.fs = fs
      cell:SetScript("OnEnter", function(self2)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self2, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(col.label, 1, 0.82, 0)
        if col.desc then GameTooltip:AddLine(col.desc, 0.9, 0.9, 0.9, true) end
        GameTooltip:Show()
      end)
      cell:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
      header.cells[col.key] = cell
    end
    cell:ClearAllPoints()
    cell:SetPoint("LEFT", header, "LEFT", slot.x, 0)
    cell:SetWidth(slot.width)
    if cell.fs then cell.fs:SetWidth(slot.width) end
  end
end

-- ── Frame construction ──────────────────────────────────────────────────────────

local function ensureFrame()
  if frame then return frame end

  local minW = SW:MinFrameWidth()
  SW._minW = minW

  frame = CreateFrame("Frame", "BankLedgerSessionWindow", UIParent, "BackdropTemplate")
  frame:SetSize(minW, DEFAULT_H)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetClampedToScreen(true)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(minW, MIN_H)
  elseif frame.SetMinResize then
    frame:SetMinResize(minW, MIN_H)
  end

  local skin = (NS.Browser and NS.Browser.SKIN) or { titleBarH = 30 }

  local titleBar = CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", 1, -1)
  titleBar:SetPoint("TOPRIGHT", -1, -1)
  titleBar:SetHeight(skin.titleBarH or 30)
  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
  titleBar:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    saveWindow()
  end)
  frame.titleBar = titleBar

  local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("CENTER")
  title:SetText(TITLE)
  frame.title = title

  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
  divider:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
  divider:SetHeight(1)
  frame.divider = divider

  if NS.Browser and NS.Browser.MakeCloseButton then
    local close = NS.Browser:MakeCloseButton(titleBar, function() SW:Hide() end)
    close:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
    frame.closeButton = close
  end

  -- One pane, straight under the title bar: no tab strip, no filter bar, no footer.
  local pane = CreateFrame("Frame", nil, frame)
  pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -((skin.titleBarH or 30) + 8))
  pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
  SW.pane = pane

  local header = CreateFrame("Frame", nil, pane)
  header:SetPoint("TOPLEFT", 0, 0)
  header:SetPoint("TOPRIGHT", -SCROLLBAR_GUTTER, 0)
  header:SetHeight(HEADER_H)
  SW.headerFrame = header

  local scroll = CreateFrame("ScrollFrame", nil, pane, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  -- 16px of bottom inset keeps the scrollbar's down-arrow clear of the resize grip.
  scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -SCROLLBAR_GUTTER, 16)
  scroll:SetScript("OnVerticalScroll", function(self2, offset)
    FauxScrollFrame_OnVerticalScroll(self2, offset, ROW_H, function() SW:Bind() end)
  end)
  scroll:SetScript("OnSizeChanged", function() SW:Bind() end)
  SW.scroll = scroll

  local host = CreateFrame("Frame", nil, pane)
  host:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  host:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
  SW.rowHost = host

  SW.rowPool = { active = {}, free = {} }

  local empty = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
  empty:SetPoint("CENTER", scroll, "CENTER", 0, 0)
  empty:SetText("Nothing has moved yet this session.")
  empty:Hide()
  SW.emptyText = empty

  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    saveWindow()
    SW:Refresh()
  end)
  frame.resizeGrip = grip

  if NS.Browser and NS.Browser.ApplySkin then
    NS.Browser:ApplySkin(frame)
  else
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  end

  SW:BuildHeaderCells()
  restoreWindow()
  frame:SetScale((NS.db and NS.db.global.settings.windowScale) or 1.0)
  frame:Hide()

  -- ESC closes it and it joins the standard close-stack (standalone-windows).
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "BankLedgerSessionWindow")
  end
  return frame
end

-- ── Render ──────────────────────────────────────────────────────────────────────

function SW:Refresh()
  if not frame then return end
  self.displayList = self:DisplayList()
  self:Bind()
end

function SW:Bind()
  if not (frame and self.scroll) then return end
  self:BuildHeaderCells()
  local list = self.displayList or {}
  local viewH = self.scroll:GetHeight()
  if type(viewH) ~= "number" or viewH <= 0 then viewH = ROW_H * 13 end
  local numVisible = math.max(1, math.floor(viewH / ROW_H))

  FauxScrollFrame_Update(self.scroll, #list, numVisible, ROW_H)
  local offset = FauxScrollFrame_GetOffset(self.scroll) or 0

  self:ReleaseAllRows()
  self.emptyText:SetShown(#list == 0)
  if #list == 0 then return end

  local pool = self.rowPool
  for i = 1, numVisible do
    local entry = list[offset + i]
    if entry then
      local row = self:AcquireRow()
      row:SetPoint("TOP", self.rowHost, "TOP", 0, -(i - 1) * ROW_H)
      self:LayoutRowCells(row)
      self:BindRow(row, entry, offset + i)
      pool.active[#pool.active + 1] = row
    end
  end
end

function SW:BindRow(row, entry, absIndex)
  row.entry = entry
  row.stripe:SetShown(absIndex % 2 == 0)
  -- Text AND colour come from LedgerTable's shared seam, so a cell can never read one way in the
  -- History window and another here.
  for _, col in ipairs(self:Columns()) do
    NS.LedgerTable:PaintCell(row.cells[col.key], col.key,
      entry, col.key == "direction" and row.dirGlyph or nil)
  end
end

-- ── Visibility ──────────────────────────────────────────────────────────────────

function SW:Show()
  if not self:Enabled() then return end
  local f = ensureFrame()
  self:Refresh()
  f:Show()
end

function SW:Hide()
  if frame then frame:Hide() end
end

function SW:Toggle()
  if frame and frame:IsShown() then self:Hide() else self:Show() end
end

function SW:IsShown()
  return (frame and frame:IsShown()) and true or false
end

-- The frame (or nil if never built), so a sibling can anchor to it.
function SW:GetWindow() return frame end

function SW:SetScale(v)
  if frame then frame:SetScale(v) end
end

-- A setting changed: honour the scale, and close immediately if the window was just switched off.
function SW:OnSettingsChanged()
  if not frame then return end
  frame:SetScale((NS.db and NS.db.global.settings.windowScale) or 1.0)
  if not self:Enabled() then self:Hide() end
end

-- ── Enable ──────────────────────────────────────────────────────────────────────

function SW:Enable()
  if self._enabled then return end
  self._enabled = true
  -- A private bus target (never the shared bus-as-self): CallbackHandler keys callbacks by
  -- (message, target), so sharing one with the Browser or Insights would silently clobber their
  -- handlers for the same messages (architecture-§4).
  SW.__ev = NS.NewBusTarget()
  if not SW.__ev then return end
  SW.__ev:RegisterMessage("Ka0s_BankLedger_SessionChanged", function(_, active, context)
    if active then SW:StartSession(context) else SW:EndSession() end
  end)
  SW.__ev:RegisterMessage("Ka0s_BankLedger_EntryAdded", function(_, entry)
    SW:OnEntryAdded(entry)
  end)
  SW.__ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", function() SW:PruneMissing() end)
  SW.__ev:RegisterMessage("Ka0s_BankLedger_SettingsChanged", function() SW:OnSettingsChanged() end)
end
