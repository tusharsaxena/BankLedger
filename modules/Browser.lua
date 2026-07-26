local addonName, NS = ...   -- luacheck: ignore addonName
NS.Browser = NS.Browser or {}
local B = NS.Browser
local C = NS.Constants
local frame
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

local LDB_NAME = "Ka0s Bank Ledger"   -- LibDataBroker object + LibDBIcon registration key
local minimapObject                   -- the LDB launcher, created once on first Enable
local DBIcon                          -- LibDBIcon-1.0, resolved lazily in SetupMinimap

-- The standalone ledger window (standalone-windows): a plain, non-secure, movable/resizable frame,
-- so it touches nothing protected and needs no combat gate. It hosts two tabs — the History table
-- and the Insights charts — over ONE shared filter bar, so both views always describe the same
-- slice of the ledger.

-- Flat skin, built from stock Blizzard textures only. Centralised here as one SKIN table + one
-- ApplySkin seam so a future settings-driven re-skin has a single touch point; the debug console
-- reuses the same seam.
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CHECK_MARKUP = "|TInterface\\Buttons\\UI-CheckBox-Check:0|t "
local SKIN = {
  bg          = { 0.06, 0.06, 0.08, 0.92 },
  border      = { 0, 0, 0, 1 },
  innerBorder = { 0.24, 0.24, 0.27, 0.85 },
  divider     = { 0.24, 0.24, 0.27, 0.85 },
  title       = { 1.0, 0.82, 0.0 },
  tabActive   = { 1.0, 0.82, 0.0 },
  tabIdle     = { 0.7, 0.7, 0.72 },
  titleBarH   = 30,
  tabStripH   = 26,
  contentGap  = 14,
  defaultH    = 660,
  minH        = 440,
}
B.SKIN = SKIN

-- ── Toolbar geometry (single source of truth) ──────────────────────────────────
-- The row-2 filter dropdowns pack left from the pane's left edge; their combined span never
-- changes. The Export button fills the slack from the last dropdown to the window's right edge AT
-- MIN WIDTH and is static — it does not grow when the window widens. EnsureFrame (the window floor)
-- and BuildFilterBar (Export sizing) both read the helpers below, so the two can never drift.
--   Row-2 dropdowns: Date 110 · Direction 110 · Store 130 · Type 110 · Character 140
local DROPDOWNS_W = 110 + 110 + 130 + 110 + 140 + 4 * 8
local EXPORT_MIN  = 110
local TOOLBAR_MIN = DROPDOWNS_W + 8 + EXPORT_MIN + 12

-- Minimum (and default-open) window width: the wider of the column-derived table floor and the
-- toolbar-fit floor, so neither the columns nor the toolbar can ever overflow.
function B:MinWidth()
  local colW = (NS.LedgerTable and NS.LedgerTable.MinFrameWidth and NS.LedgerTable:MinFrameWidth())
    or 900
  return math.max(colW, TOOLBAR_MIN)
end

-- Static Export width: from the last dropdown's right edge (+8px gap) to the bar's right edge at
-- min width, never narrower than EXPORT_MIN.
function B:ExportWidth()
  return math.max(EXPORT_MIN, (self:MinWidth() - 12) - (DROPDOWNS_W + 8))
end

-- Apply the flat skin. Kept separate so a future settings panel can re-skin live.
function B:ApplySkin(f)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  f:SetBackdropColor(unpack(SKIN.bg))
  f:SetBackdropBorderColor(unpack(SKIN.border))

  if not f.innerBorder then
    local inner = CreateFrame("Frame", nil, f, "BackdropTemplate")
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    inner:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    f.innerBorder = inner
  end
  f.innerBorder:SetBackdropBorderColor(unpack(SKIN.innerBorder))

  if f.title then f.title:SetTextColor(unpack(SKIN.title)) end
  if f.divider then f.divider:SetColorTexture(unpack(SKIN.divider)) end
end

-- Thin × close glyph, light grey by default and the player's class colour on hover. Shared by the
-- ledger window, the debug console and the export popups.
function B:MakeCloseButton(parent, onClick)
  local close = CreateFrame("Button", nil, parent)
  close:SetSize(24, 24)
  local x = close:CreateFontString(nil, "OVERLAY")
  x:SetFont(STANDARD_TEXT_FONT, 24, "")
  x:SetPoint("CENTER", close, "CENTER", 0, 2)   -- the × sits low in its font box; nudge it up
  x:SetText("\195\151")
  x:SetTextColor(0.85, 0.85, 0.85)
  local _, class = UnitClass("player")
  local cc = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or { r = 1, g = 0.82, b = 0 }
  close:SetScript("OnEnter", function() x:SetTextColor(cc.r, cc.g, cc.b) end)
  close:SetScript("OnLeave", function() x:SetTextColor(0.85, 0.85, 0.85) end)
  close:SetScript("OnClick", onClick)
  return close
end

-- ── Window position/size persistence ──────────────────────────────────────────
-- settings.window = { point, x, y, w, h } relative to UIParent. Window geometry is runtime view
-- state, deliberately NOT a Schema row — an architecture-§5 carve-out written directly here
-- (standalone-windows requires it be persisted; it has no place in the settings panel).

local function SaveWindow()
  if not frame then return end
  local point, _, _, x, y = frame:GetPoint(1)
  NS.db.global.settings.window = {
    point = point, x = x, y = y, w = frame:GetWidth(), h = frame:GetHeight(),
  }
end

local function RestoreWindow()
  local w = NS.db and NS.db.global.settings.window
  frame:ClearAllPoints()
  if w and w.point then
    frame:SetPoint(w.point, UIParent, w.point, w.x or 0, w.y or 0)
    if w.w and w.h then
      frame:SetSize(math.max(B._minW or 0, w.w), math.max(B._minH or 0, w.h))
    end
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

-- Reset the persisted geometry and recentre the live frame. Used only by the destructive
-- "Reset all", since position is runtime state the ordinary settings resets leave alone.
function B:ResetWindow()
  if NS.db and NS.db.global and NS.db.global.settings then
    NS.db.global.settings.window = {}
  end
  if frame then
    frame:ClearAllPoints()
    RestoreWindow()
  end
end

-- ── Tabs ──────────────────────────────────────────────────────────────────────
local TABS = { "History", "Insights" }
local lastTab = "History"   -- remembered within a session

-- Let the owning module build its pane content the first time the tab is shown (lazy per-tab build,
-- standalone-windows). The filter bar and footer are NOT here — they are shared window chrome built
-- once in EnsureFrame, so both panes render off the same singleton filter.
local function BuildPane(name)
  local pane = frame.panes[name]
  if pane._built then return end
  pane._built = true
  if name == "History" then
    if NS.LedgerTable and NS.LedgerTable.Attach then NS.LedgerTable:Attach(pane) end
  elseif name == "Insights" then
    if NS.Insights and NS.Insights.Attach then NS.Insights:Attach(pane) end
  end
end

function B:SelectTab(name)
  if not frame then return end
  lastTab = name
  for _, t in ipairs(TABS) do
    local active = (t == name)
    frame.panes[t]:SetShown(active)
    frame.tabs[t].label:SetTextColor(unpack(active and SKIN.tabActive or SKIN.tabIdle))
    frame.tabs[t].underline:SetShown(active)
  end
  BuildPane(name)
  if name == "History" and NS.LedgerTable and NS.LedgerTable.Refresh then
    NS.LedgerTable:Refresh()
    B:RefreshFilterOptions()
  elseif name == "Insights" and NS.Insights and NS.Insights.Refresh then
    NS.Insights:Refresh()
  end
  B:UpdateFooter()
  B:UpdateDbSize()
  if NS.State.debug and NS.Debug then NS.Debug("UI", "tab -> %s", tostring(name)) end
end

local function CreateTabStrip()
  local strip = CreateFrame("Frame", nil, frame)
  strip:SetPoint("TOPLEFT", frame.divider, "BOTTOMLEFT", 6, -2)
  strip:SetPoint("TOPRIGHT", frame.divider, "BOTTOMRIGHT", -6, -2)
  strip:SetHeight(SKIN.tabStripH)
  frame.tabStrip = strip
  frame.tabs = {}

  local x = 0
  for _, name in ipairs(TABS) do
    local tab = CreateFrame("Button", nil, strip)
    tab:SetSize(90, SKIN.tabStripH)
    tab:SetPoint("LEFT", x, 0)
    local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(name)
    tab.label = label
    local underline = tab:CreateTexture(nil, "ARTWORK")
    underline:SetColorTexture(unpack(SKIN.tabActive))
    underline:SetHeight(2)
    underline:SetPoint("BOTTOMLEFT", 8, 0)
    underline:SetPoint("BOTTOMRIGHT", -8, 0)
    tab.underline = underline
    tab:SetScript("OnClick", function() B:SelectTab(name) end)
    frame.tabs[name] = tab
    x = x + 94
  end
end

-- ── Filter bar ────────────────────────────────────────────────────────────────
-- Compact custom dropdowns + a search box matching the flat skin. Deliberately not Blizzard's
-- UIDropDownMenu: the look stays consistent and there is no protected-call surface to taint.

B.activeFilter = {}

-- One shared popup menu, reused by every dropdown, with a full-screen catcher that closes it on an
-- outside click. The menu sits above the HIGH-strata window; the catcher one strata below it.
local menu
local function EnsureMenu()
  if menu then return menu end
  menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  menu:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
  menu:SetBackdropBorderColor(0, 0, 0, 1)
  menu:Hide()
  menu.buttons = {}

  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN")
  catcher:Hide()
  catcher:SetScript("OnClick", function() menu:Hide() end)
  menu.catcher = catcher
  menu:SetScript("OnHide", function() catcher:Hide() end)

  function menu:Populate(dd)
    local ROW_H = 16
    for _, b in ipairs(self.buttons) do b:Hide() end
    local opts = dd._options or {}
    local w = math.max(dd:GetWidth(), 90)
    for i, opt in ipairs(opts) do
      local b = self.buttons[i]
      if not b then
        b = CreateFrame("Button", nil, self)
        b:SetHeight(ROW_H)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", 8, 0)
        fs:SetPoint("RIGHT", -8, 0)
        fs:SetJustifyH("LEFT")
        b.fs = fs
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.82, 0, 0.15)
        self.buttons[i] = b
      end
      b:SetWidth(w)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 0, -4 - (i - 1) * ROW_H)
      -- Selection state: single-select highlights the one active value; multi-select highlights
      -- every value in the set (and highlights "all" when the set is empty = no filter).
      local selected
      if dd.multi then
        selected = (opt.value == "all") and (not next(dd._selected)) or (dd._selected[opt.value] or false)
      else
        selected = (opt.value == dd._value)
      end
      local check = (dd.multi and selected) and CHECK_MARKUP or ""
      b.fs:SetText(check .. opt.label)
      if selected then
        b.fs:SetTextColor(1, 0.82, 0)
      elseif opt.color then
        b.fs:SetTextColor(opt.color[1], opt.color[2], opt.color[3])
      else
        b.fs:SetTextColor(0.9, 0.9, 0.9)
      end
      b:SetScript("OnClick", function()
        if dd.multi then
          -- Toggle in place and keep the menu open, so several can be picked in one visit.
          dd:ToggleSelected(opt.value)
          menu:Populate(dd)
          if dd.onMultiSelect then dd.onMultiSelect(dd._selected) end
        else
          dd:SetValue(opt.value, opt.label)
          menu:Hide()
          if dd.onSelect then dd.onSelect(opt.value) end
        end
      end)
      b:Show()
    end
    self:SetSize(w, #opts * ROW_H + 8)
  end
  return menu
end

-- A dropdown button: shows the current label plus a ▼ texture; clicking opens the shared menu.
local function MakeDropdown(parent, width)
  local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
  dd:SetSize(width, 20)
  dd:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
                   insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  dd:SetBackdropColor(0.1, 0.1, 0.12, 0.9)
  dd:SetBackdropBorderColor(0.24, 0.24, 0.27, 0.9)

  local fs = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("LEFT", 6, 0)
  fs:SetPoint("RIGHT", -16, 0)
  fs:SetJustifyH("LEFT")
  dd.text = fs

  -- The ▼ glyph is not in the default WoW font (it renders as a box), so use the arrow texture.
  local arrow = dd:CreateTexture(nil, "OVERLAY")
  arrow:SetSize(12, 12)
  arrow:SetPoint("RIGHT", -4, 0)
  arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
  arrow:SetVertexColor(0.7, 0.7, 0.72)

  dd._selected = {}   -- multi-select value set (empty = "All"); only used when dd.multi is true
  function dd:SetOptions(opts)
    self._options = opts
    if self.multi then self:UpdateMultiLabel() end
  end
  function dd:SetValue(v, label) self._value = v; self.text:SetText(label or "") end
  function dd:SelectValue(v)
    for _, o in ipairs(self._options or {}) do
      if o.value == v then self:SetValue(o.value, o.label); return end
    end
    self:SetValue(v, tostring(v))
  end

  function dd:SetMulti(on) self.multi = on and true or false end
  function dd:SetSelected(set)
    local s = {}
    if type(set) == "table" then for k, on in pairs(set) do if on then s[k] = true end end end
    self._selected = s
    self:UpdateMultiLabel()
  end
  function dd:ToggleSelected(value)
    if value == "all" then
      self._selected = {}
    else
      self._selected[value] = (not self._selected[value]) or nil
    end
    self:UpdateMultiLabel()
  end
  -- Collapsed-button summary: the "All" label when empty, the single option's label when one is
  -- picked, else "<Prefix>: N selected" (the prefix comes from the "all" sentinel's label).
  function dd:UpdateMultiLabel()
    local n, firstLabel
    for _, o in ipairs(self._options or {}) do
      if o.value ~= "all" and self._selected[o.value] then
        n = (n or 0) + 1
        firstLabel = firstLabel or o.label
      end
    end
    local allLabel = (self._options and self._options[1] and self._options[1].label) or "All"
    if not n then
      self.text:SetText(allLabel)
    elseif n == 1 then
      self.text:SetText(firstLabel)
    else
      self.text:SetText((allLabel:match("^(.-):") or allLabel) .. ": " .. n .. " selected")
    end
  end

  dd:SetScript("OnClick", function(self2)
    local m = EnsureMenu()
    if m:IsShown() and m._owner == self2 then m:Hide(); return end
    m._owner = self2
    m:Populate(self2)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", self2, "BOTTOMLEFT", 0, -1)
    m.catcher:Show()
    m:Show()
  end)
  return dd
end

-- Shared factory so sibling modules (Export) can build a flat-skin dropdown off the same machinery.
function B:MakeDropdown(parent, width) return MakeDropdown(parent, width) end

-- A small flat-skin text button for the filter bar.
local function makeBarButton(parent, text, width, onClick, tooltip)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width, 20)
  b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
                  insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  b:SetBackdropColor(0.1, 0.1, 0.12, 0.9)
  b:SetBackdropBorderColor(0.24, 0.24, 0.27, 0.9)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER")
  fs:SetText(text)
  b:SetScript("OnEnter", function(self2)
    fs:SetTextColor(1, 0.82, 0)
    if tooltip and GameTooltip then
      GameTooltip:SetOwner(self2, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(tooltip, 0.9, 0.9, 0.9, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function()
    fs:SetTextColor(1, 1, 1)
    if GameTooltip then GameTooltip:Hide() end
  end)
  b:SetScript("OnClick", onClick)
  return b
end

-- The dataset the filter bar reflects: whatever the table is currently showing (preview data or the
-- live ledger), so the dropdown options and the footer always match what is on screen.
local function dataset()
  if NS.LedgerTable and NS.LedgerTable.CurrentEntries then
    return NS.LedgerTable:CurrentEntries()
  end
  return NS.Database:Ledger()
end

local GROUP_OPTIONS = {
  { value = "none",      label = "Group: None" },
  { value = "day",       label = "Group: Day" },
  { value = "store",     label = "Group: Store" },
  { value = "direction", label = "Group: In/Out" },
  { value = "kind",      label = "Group: Item/Gold" },
  { value = "char",      label = "Group: Character" },
}
local DATE_OPTIONS = {
  { value = "all",   label = "Date: All" },
  { value = "today", label = "Today" },
  { value = "7d",    label = "Last 7 days" },
  { value = "30d",   label = "Last 30 days" },
}

-- Sort distinct options by label and prefix the "All" sentinel (kept first regardless of sort).
local function withAll(allLabel, items)
  table.sort(items, function(a, b) return a.label < b.label end)
  table.insert(items, 1, { value = "all", label = allLabel })
  return items
end

-- Data-driven option lists: only the values the dataset actually contains are offered, so an empty
-- ledger doesn't show five stores you've never used.
local function directionOptions()
  local present = {}
  for _, e in ipairs(dataset()) do present[e.direction or "DEPOSIT"] = true end
  local items = { { value = "all", label = "In/Out: All" } }
  for _, k in ipairs(C.DirectionOrder) do
    if present[k] then items[#items + 1] = { value = k, label = C.DirectionLabel[k] } end
  end
  return items
end
local function storeOptions()
  local present = {}
  for _, e in ipairs(dataset()) do if e.store then present[e.store] = true end end
  local items = { { value = "all", label = "Store: All" } }
  for _, k in ipairs(C.StoreOrder) do
    if present[k] then items[#items + 1] = { value = k, label = C.StoreLabel[k] } end
  end
  return items
end
local function typeOptions()
  local seen, items = {}, {}
  for _, e in ipairs(dataset()) do
    local ty = e.itemType
    if ty and ty ~= "" and not seen[ty] then
      seen[ty] = true
      items[#items + 1] = { value = ty, label = ty }
    end
  end
  return withAll("Type: All", items)
end
local function charOptions()
  local seen, items = {}, {}
  for _, e in ipairs(dataset()) do
    local ch = e.char
    if ch and not seen[ch] then
      seen[ch] = true
      local cc = e.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.classFile]
      items[#items + 1] = { value = ch, label = ch, color = cc and { cc.r, cc.g, cc.b } or nil }
    end
  end
  return withAll("Character: All", items)
end

-- Copy a multi-select set into a plain filter value: a fresh set when non-empty, else nil (no
-- filter). Copied — never aliased to the dropdown's live set — so a later toggle can't mutate the
-- filter behind the table's back.
local function setToFilter(set)
  local copy, n = {}, 0
  if type(set) == "table" then for k in pairs(set) do copy[k] = true; n = n + 1 end end
  return n > 0 and copy or nil
end

-- Push the current filter to the table and refresh the footer. The filter is a singleton for the
-- whole window: it always drives the table (keeping matchCount and the footer current on either
-- tab), and it drives the Insights charts live while Insights is the tab on screen.
local function ApplyFilter()
  if NS.LedgerTable then NS.LedgerTable:SetFilter(B.activeFilter) end
  B:UpdateFooter()
  if lastTab == "Insights" and NS.Insights and NS.Insights.Refresh and NS.Insights.pane then
    NS.Insights:Refresh()
  end
end

-- The active filter as a plain copy, for Insights. It shares the exact field shape
-- Database:QueryList consumes, so the two views can never filter by different criteria.
function B:CurrentFilter()
  local out = {}
  for k, v in pairs(self.activeFilter or {}) do out[k] = v end
  return out
end

function B:UpdateFooter()
  if not self._footer then return end
  local shown = (NS.LedgerTable and NS.LedgerTable.matchCount) or 0
  local total = #dataset()
  self._footer:SetText(("Showing %d of %d"):format(shown, total))
end

-- Estimated SavedVariables size of the stored ledger (the same estimate the settings panel shows).
-- Recomputed only when the ledger changes or the window (re)opens — never on a filter keystroke,
-- since filtering cannot change what is stored. \226\137\136 = "≈".
function B:UpdateDbSize()
  if not self._dbFooter then return end
  local bytes = (NS.Database and NS.Database.StorageStats and NS.Database:StorageStats().bytes) or 0
  self._dbFooter:SetText(("Database \226\137\136 %s"):format(NS.Util.FormatBytes(bytes)))
end

-- Recompute the data-driven dropdowns from the current dataset.
function B:RefreshFilterOptions()
  local dd = self._dd
  if not dd then return end
  dd.direction:SetOptions(directionOptions())
  dd.store:SetOptions(storeOptions())
  dd.type:SetOptions(typeOptions())
  dd.char:SetOptions(charOptions())
end

-- Clear every filter and return the group/sort to stock.
function B:ClearFilters()
  self.activeFilter = {}
  local dd = self._dd
  if dd then
    dd.group:SelectValue("none")
    dd.date:SelectValue("all")
    dd.direction:SetSelected({})
    dd.store:SetSelected({})
    dd.type:SetSelected({})
    dd.char:SetSelected({})
  end
  if self._search then self._search:SetText("") end
  if NS.LedgerTable then
    NS.LedgerTable.groupBy = "none"
    NS.LedgerTable.sortKey = "date"
    NS.LedgerTable.sortAsc = false
  end
  ApplyFilter()
end

-- The dataset changed under the bar (entering/leaving preview mode): rebuild the dropdowns from the
-- new data and clear the filters, since the old values may not exist in it.
function B:OnDatasetChanged()
  self:RefreshFilterOptions()
  self:ClearFilters()
  self:UpdateFooter()
  self:UpdateDbSize()
  self:UpdatePreviewBadge()
  if NS.Insights and NS.Insights.Refresh then NS.Insights:Refresh() end
end

function B:UpdatePreviewBadge()
  if not (frame and frame.previewBadge) then return end
  frame.previewBadge:SetShown(NS.LedgerTable and NS.LedgerTable.previewMode or false)
end

-- Build the SHARED, singleton filter bar into `bar` — a window-level host anchored once in
-- EnsureFrame, above both tab panes, so one filter drives the table AND the charts.
--   Row 1: Group by · [search…] · Clear
--   Row 2: Date · In/Out · Store · Type · Character · Export
function B:BuildFilterBar(bar)
  local ROW1, ROW2 = 0, -24
  local dd = {}
  self._dd = dd

  dd.group = MakeDropdown(bar, 110)
  dd.group:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, ROW1)
  dd.group:SetOptions(GROUP_OPTIONS)
  dd.group:SetValue("none", "Group: None")
  dd.group.onSelect = function(v) if NS.LedgerTable then NS.LedgerTable:SetGroupBy(v) end end

  -- Export is created here (ahead of its row-2 position) so the row-1 Clear button can anchor to
  -- it; SetPoint only needs the frame to exist, not to be positioned yet. Its own anchor (to the
  -- Character dropdown) is set at the end of the Row 2 block below.
  local exportW = B:ExportWidth()
  local exportBtn = makeBarButton(bar, "Export", exportW, function() B:OpenExport() end,
    "Export the current tab — ledger rows (History) or the summary (Insights).")

  local clear = makeBarButton(bar, "Clear", exportW, function() B:ClearFilters() end,
    "Clear every filter and return the grouping and sort to their defaults.")
  clear:SetPoint("TOPRIGHT", exportBtn, "TOPRIGHT", 0, ROW1 - ROW2)

  -- Item-name search. Its LEFT sits beside Group; its RIGHT is pinned to the row-2 Character
  -- dropdown below it (set once that exists), so the two right edges stay aligned at every window
  -- width. Top-corner anchoring keeps the box in row 1 despite the row-2 reference.
  local search = CreateFrame("EditBox", nil, bar, "BackdropTemplate")
  search:SetHeight(20)
  search:SetPoint("TOPLEFT", dd.group, "TOPRIGHT", 8, 0)
  search:SetAutoFocus(false)
  search:SetFontObject("GameFontHighlightSmall")
  search:SetTextInsets(6, 6, 0, 0)
  search:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
                       insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  search:SetBackdropColor(0.1, 0.1, 0.12, 0.9)
  search:SetBackdropBorderColor(0.24, 0.24, 0.27, 0.9)
  local ph = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ph:SetPoint("LEFT", 6, 0)
  ph:SetText("Search items…")
  search:SetScript("OnTextChanged", function(self2)
    local t = self2:GetText()
    ph:SetShown(t == "")
    B.activeFilter.text = (t ~= "") and t or nil
    ApplyFilter()
  end)
  search:SetScript("OnEscapePressed", function(self2) self2:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(self2) self2:ClearFocus() end)
  self._search = search

  -- Row 2, left→right in the same order the columns appear in the table.
  dd.date = MakeDropdown(bar, 110)
  dd.date:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, ROW2)
  dd.date:SetOptions(DATE_OPTIONS)
  dd.date:SetValue("all", "Date: All")
  dd.date.onSelect = function(v)
    B.activeFilter.from = (v ~= "all") and NS.Util.RangeFrom(v) or nil
    ApplyFilter()
  end

  dd.direction = MakeDropdown(bar, 110)
  dd.direction:SetPoint("LEFT", dd.date, "RIGHT", 8, 0)
  dd.direction:SetMulti(true)
  dd.direction:SetOptions(directionOptions())
  dd.direction.onMultiSelect = function(set)
    B.activeFilter.direction = setToFilter(set)
    ApplyFilter()
  end

  dd.store = MakeDropdown(bar, 130)
  dd.store:SetPoint("LEFT", dd.direction, "RIGHT", 8, 0)
  dd.store:SetMulti(true)
  dd.store:SetOptions(storeOptions())
  dd.store.onMultiSelect = function(set)
    B.activeFilter.store = setToFilter(set)
    ApplyFilter()
  end

  dd.type = MakeDropdown(bar, 110)
  dd.type:SetPoint("LEFT", dd.store, "RIGHT", 8, 0)
  dd.type:SetMulti(true)
  dd.type.onMultiSelect = function(set)
    B.activeFilter.itemType = setToFilter(set)
    ApplyFilter()
  end

  dd.char = MakeDropdown(bar, 140)
  dd.char:SetPoint("LEFT", dd.type, "RIGHT", 8, 0)
  dd.char:SetMulti(true)
  dd.char.onMultiSelect = function(set)
    B.activeFilter.char = setToFilter(set)
    ApplyFilter()
  end

  -- Pin the row-1 search box's right edge to the Character dropdown's; -ROW2 lifts the top-right
  -- corner from row 2 back up into row 1.
  search:SetPoint("TOPRIGHT", dd.char, "TOPRIGHT", 0, -ROW2)
  exportBtn:SetPoint("LEFT", dd.char, "RIGHT", 8, 0)
end

-- Route the Export button to the right dataset for the active tab. History exports the ledger rows;
-- Insights exports the summary computed off the SAME shared filter.
function B:OpenExport()
  local title = "Export " .. tostring(lastTab)
  if lastTab == "Insights" then
    NS.Export:Open({
      title = title,
      providers = {
        allData     = function() return NS.Database:Stats({}) end,
        currentView = function() return NS.Database:Stats(B:CurrentFilter()) end,
      },
      csv = function(stats) return NS.Export:InsightsCSV(stats) end,
    })
  else
    NS.Export:Open({
      title = title,
      providers = {
        allData     = function() return NS.Database:Export({}) end,
        currentView = function()
          return (NS.LedgerTable and NS.LedgerTable.OrderedFilteredEntries
            and NS.LedgerTable:OrderedFilteredEntries()) or {}
        end,
      },
      csv = function(entries) return NS.Export:CSV(entries) end,
    })
  end
end

-- ── Frame construction ────────────────────────────────────────────────────────

local function EnsureFrame()
  if frame then return frame end

  frame = CreateFrame("Frame", "BankLedgerWindow", UIParent, "BackdropTemplate")
  -- Default size == minimum size: wide enough for every column and the whole toolbar, so the window
  -- can grow but never shrink into overflow. B:MinWidth() is the single source of truth, and the
  -- filter bar reads the same helper, so the two can't drift.
  local minW, minH = B:MinWidth(), SKIN.minH
  B._minW, B._minH = minW, minH
  frame:SetSize(minW, SKIN.defaultH)
  frame:SetFrameStrata("HIGH")
  frame:EnableMouse(true)   -- capture clicks over the whole window; no click-through to the world
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetClampedToScreen(true)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(minW, minH)
  elseif frame.SetMinResize then
    frame:SetMinResize(minW, minH)
  end

  local titleBar = CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", 1, -1)
  titleBar:SetPoint("TOPRIGHT", -1, -1)
  titleBar:SetHeight(SKIN.titleBarH)
  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
  titleBar:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SaveWindow()
  end)
  frame.titleBar = titleBar

  local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("CENTER")
  title:SetText("Ka0s Bank Ledger")
  frame.title = title

  local previewBadge = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  previewBadge:SetPoint("LEFT", title, "RIGHT", 10, 0)
  previewBadge:SetText("PREVIEW")
  previewBadge:SetTextColor(1, 0.15, 0.15)
  previewBadge:Hide()
  frame.previewBadge = previewBadge

  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
  divider:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
  divider:SetHeight(1)
  frame.divider = divider

  local close = B:MakeCloseButton(titleBar, function() B:Hide() end)
  close:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
  frame.closeButton = close

  -- Shared window chrome: one singleton filter bar above both panes, one shared footer below them.
  -- Layout, top to bottom: title bar · tab strip · gap · FILTER BAR · panes · FOOTER.
  local FILTERBAR_H, FILTER_GAP, FOOTER_H = 46, 8, 18
  local barTop  = SKIN.titleBarH + SKIN.tabStripH + SKIN.contentGap
  local paneTop = barTop + FILTERBAR_H + FILTER_GAP

  frame.panes = {}
  for _, name in ipairs(TABS) do
    local pane = CreateFrame("Frame", nil, frame)
    pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -paneTop)
    pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, FOOTER_H)
    pane:Hide()
    frame.panes[name] = pane
  end

  CreateTabStrip()

  local filterHost = CreateFrame("Frame", nil, frame)
  filterHost:SetPoint("TOPLEFT",  frame, "TOPLEFT",   6, -barTop)
  filterHost:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -barTop)
  filterHost:SetHeight(FILTERBAR_H)
  frame.filterHost = filterHost

  -- Shared footer: "Showing X of Y" bottom-left, estimated DB size bottom-right. x = -20 keeps the
  -- size text left of the 16px resize grip so the two never overlap.
  local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 3)
  B._footer = footer
  local dbFooter = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  dbFooter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 3)
  dbFooter:SetJustifyH("RIGHT")
  B._dbFooter = dbFooter

  B:BuildFilterBar(filterHost)
  B:RefreshFilterOptions()
  B:UpdateDbSize()

  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    SaveWindow()
    if NS.LedgerTable and NS.LedgerTable.Refresh then NS.LedgerTable:Refresh() end
  end)
  frame.resizeGrip = grip

  -- Close any open dropdown menu whenever the window hides — this also covers the ESC path, which
  -- calls frame:Hide() directly rather than B:Hide(). Also the single seam for the [UI] show/hide
  -- trace, so it fires once per visibility change whatever the call path.
  frame:HookScript("OnShow", function()
    if NS.State.debug and NS.Debug then NS.Debug("UI", "window shown") end
  end)
  frame:HookScript("OnHide", function()
    if menu then menu:Hide() end
    if NS.State.debug and NS.Debug then NS.Debug("UI", "window hidden") end
  end)

  B:ApplySkin(frame)
  RestoreWindow()
  frame:SetScale((NS.db and NS.db.global.settings.windowScale) or 1.0)
  frame:Hide()

  -- ESC closes the window and it joins the standard close-stack (standalone-windows).
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "BankLedgerWindow")
  end
  return frame
end

function B:Show()
  local f = EnsureFrame()
  f:Show()
  -- Eager-build the History pane so the table attaches and matchCount is fresh — the shared footer
  -- then reads correctly even when the window opens straight onto the Insights tab.
  BuildPane("History")
  B:SelectTab(lastTab)
  B:UpdatePreviewBadge()
end

function B:Hide()
  if menu then menu:Hide() end
  if frame then frame:Hide() end
end

function B:Toggle()
  local f = EnsureFrame()
  if f:IsShown() then f:Hide() else B:Show() end
end

-- The ledger window frame (or nil if never built). Lets sibling modules anchor popups to it.
function B:GetWindow() return frame end

function B:SetScale(v)
  if frame then frame:SetScale(v) end
end

function B:OnSettingsChanged()
  if frame then frame:SetScale(NS.db.global.settings.windowScale or 1.0) end
  self:SetMinimapHidden(NS.db.global.minimap and NS.db.global.minimap.hide)
end

-- ── Minimap button (LibDataBroker + LibDBIcon) ────────────────────────────────
-- A launcher data object: left-click toggles the window, right-click opens Settings, and the
-- tooltip shows the live entry count. Visibility lives in db.global.minimap — the same table the
-- "Hide minimap button" setting writes and LibDBIcon owns — so registration alone honours the
-- persisted hide state across a reload.

function B:SetupMinimap()
  if minimapObject then return end
  local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
  DBIcon = DBIcon or (LibStub and LibStub("LibDBIcon-1.0", true))
  if not (LDB and DBIcon) then return end

  minimapObject = LDB:NewDataObject(LDB_NAME, {
    type  = "launcher",
    label = "Bank Ledger",
    icon  = "Interface\\Icons\\inv_misc_bag_15",
    OnClick = function(_, button)
      if button == "RightButton" then
        if NS.Panel and NS.Panel.Open then NS.Panel:Open() end
      else
        B:Toggle()
      end
    end,
    OnTooltipShow = function(tt)
      tt:AddLine("Ka0s Bank Ledger", 1, 0.82, 0)
      local n = (NS.Database and NS.Database.Count) and NS.Database:Count() or 0
      tt:AddLine(n == 1 and "1 movement" or (n .. " movements"), 0.7, 0.7, 0.7)
      tt:AddLine(" ")
      tt:AddLine("Left-click: open the ledger", 0.5, 0.5, 0.5)
      tt:AddLine("Right-click: open settings", 0.5, 0.5, 0.5)
    end,
  })

  local mm = NS.db.global.minimap
  if not mm then mm = { hide = false }; NS.db.global.minimap = mm end
  DBIcon:Register(LDB_NAME, minimapObject, mm)
end

function B:SetMinimapHidden(hide)
  if DBIcon and DBIcon:IsRegistered(LDB_NAME) then
    if hide then DBIcon:Hide(LDB_NAME) else DBIcon:Show(LDB_NAME) end
  end
end

-- Keep the window current when the ledger changes underneath it. The shared filter bar and footer
-- refresh on either tab; the table repaints only when History is the visible tab, and Insights
-- live-refreshes itself through its own bus subscription.
function B:OnLedgerChanged()
  if not (frame and frame:IsShown()) then return end
  if lastTab == "History" and NS.LedgerTable and NS.LedgerTable.Refresh then
    NS.LedgerTable:Refresh()
  end
  self:RefreshFilterOptions()
  self:UpdateFooter()
  self:UpdateDbSize()
end

function B:Enable()
  if self._enabled then return end
  self._enabled = true
  -- A private bus target (never the shared bus-as-self) so these can't clobber the Ledger's
  -- SettingsChanged handler or the Insights consumers of the same messages (architecture-§4).
  B.__ev = NS.NewBusTarget() or NS.bus
  B.__ev:RegisterMessage("Ka0s_BankLedger_SettingsChanged", function() B:OnSettingsChanged() end)
  B.__ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", function() B:OnLedgerChanged() end)
  B.__ev:RegisterMessage("Ka0s_BankLedger_EntryAdded", function() B:OnLedgerChanged() end)
  if NS.Insights and NS.Insights.Enable then NS.Insights:Enable() end
  B:SetupMinimap()
end

-- Print the addon's chat notice when the window can't be built (used by the slash verbs when the
-- UI libraries are unavailable — a soft fallback rather than a hard error).
function B:Unavailable()
  print("the ledger window is unavailable (a required library did not load).")
end
