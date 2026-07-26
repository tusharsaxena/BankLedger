local addonName, NS = ...   -- luacheck: ignore addonName
NS.Panel = NS.Panel or {}
local P = NS.Panel
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

-- The Ka0s settings-panel pattern (options-ui):
--   * A parent canvas category renders the LANDING PAGE — logo, one-liner, slash-command list —
--     with the same gold header every subcategory uses.
--   * Each settings group is a canvas SUBCATEGORY with a breadcrumb header
--     ("Ka0s Bank Ledger ▸ General"), a Defaults button, and a gold divider.
--   * Bodies render schema rows into a TWO-COLUMN grid; AceGUI Headings group them into sections.
-- The category is registered EAGERLY at load so the entry is always in the options list; each
-- body is built LAZILY on its first OnShow, because AceGUI lays out against the panel's current
-- width, which is 0 before the panel is first shown.
-- Every write routes through NS.Schema:Set (validate → write → onChange); reads via :Get.

local ADDON_TITLE   = "Ka0s Bank Ledger"
local ADDON_TAGLINE =
  "Keeps a passbook of every item and every coin that moves between your bags and your banks."

-- Layout constants — the exact Ka0s values (options-ui-§8). Named, never inlined.
local PADDING_X     = 16    -- left/right edge inset for the header, divider and body
local HEADER_TOP    = 20    -- title + Defaults button inset from the panel top
local HEADER_HEIGHT = 54    -- panel top → divider; the body starts at HEADER_HEIGHT + 8
local DEFAULTS_W    = 110   -- Defaults button width
local LOGO_SIZE     = 300   -- landing-page logo display size
local ROW_VSPACER   = 8     -- gap between two-column rows
local SECTION_TOP_SPACER, SECTION_BOTTOM_SPACER, SECTION_HEADING_H = 10, 6, 26
-- A cell-filling paired ACTION button insets to this (not a flush 0.5) so its right border clears
-- the ScrollFrame's clip (options-ui-§6/§8). Label-inset controls (checkbox/dropdown/slider) reserve
-- that gutter already and stay at 0.5 — they are immune (options-ui-§10).
local BUTTON_PAIR_REL = 0.492

local mainCategoryID   -- the parent category, the target of /bl config
local registered

-- ── Tooltip helper (an AceGUI widget via SetCallback, a plain frame via HookScript) ──
local function attachTooltip(widget, label, tooltip)
  if not widget or not tooltip then return end
  local anchor = widget.frame or widget
  if not anchor then return end
  local function show()
    if not GameTooltip then return end
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    if label and label ~= "" then GameTooltip:SetText(label, 1, 1, 1) end
    GameTooltip:AddLine(tooltip, nil, nil, nil, true)
    GameTooltip:Show()
  end
  local function hide() if GameTooltip then GameTooltip:Hide() end end
  if widget.SetCallback then
    widget:SetCallback("OnEnter", show); widget:SetCallback("OnLeave", hide)
  elseif widget.HookScript then
    widget:HookScript("OnEnter", show); widget:HookScript("OnLeave", hide)
  end
end

-- ── Header: "Ka0s Bank Ledger ▸ <title>" + Defaults button + gold divider ─────────
local function buildHeader(panel, title, opts)
  local displayTitle = title
  if not opts.isMain then
    displayTitle = ADDON_TITLE .. " |A:common-icon-forwardarrow:16:16|a " .. title
  end

  local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING_X, -HEADER_TOP)
  titleFS:SetText(displayTitle)

  local divider = panel:CreateTexture(nil, "ARTWORK")
  divider:SetAtlas("Options_HorizontalDivider", true)
  divider:SetPoint("TOPLEFT",  panel, "TOPLEFT",   PADDING_X, -HEADER_HEIGHT)
  divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING_X, -HEADER_HEIGHT)
  divider:SetVertexColor(titleFS:GetTextColor())   -- track the title's gold

  if opts.defaultsButton and AceGUI then
    -- MUST be an AceGUI Button, not a raw UIPanelButtonTemplate parented onto the canvas: a
    -- template button created as a DIRECT child of the Settings canvas inherits the canvas's red
    -- button skin. AceGUI creates under UIParent and reparents, keeping the dark/gold look
    -- (options-ui-§5).
    local btn = AceGUI:Create("Button")
    btn:SetText("Defaults")
    btn:SetWidth(DEFAULTS_W)
    btn.frame:SetParent(panel)
    btn.frame:ClearAllPoints()
    btn.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING_X, -HEADER_TOP)
    btn.frame:Show()
    panel.defaultsBtn = btn
  end
  return titleFS, divider
end

-- ── createPanel — a Frame for RegisterCanvasLayout(Sub)category, plus its render context ──
local function createPanel(title, opts)
  opts = opts or {}
  local panel = CreateFrame("Frame", nil)
  panel.name = title
  panel:Hide()
  buildHeader(panel, title, opts)

  local body = CreateFrame("Frame", nil, panel)
  body:SetPoint("TOPLEFT",     panel, "TOPLEFT",     0, -(HEADER_HEIGHT + 8))
  body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

  -- `refreshers` re-sync scalar widget VALUES in place (cheap; run on every OnShow). `rebuilders`
  -- tear down and recreate list rows (structural, expensive). Per options-ui-§11 a structural
  -- rebuild runs only on first paint, on an on-screen edit, or when `dirty` marks an off-screen
  -- change — never on every OnShow.
  return { panel = panel, body = body, scroll = nil,
           refreshers = {}, rebuilders = {}, dirty = false, lastGroup = nil }
end

-- Keep the settings-panel scrollbar ALWAYS visible — and inert when the page fits — so the reserved
-- right gutter, and therefore the body width, is identical across short and long subcategories
-- (options-ui-§10). AceGUI's stock FixScroll hides the bar and reclaims the 20px gutter when content
-- fits, which shifts the body width between pages and makes the panel jitter as you tab around.
-- Mirrors the stock FixScroll maths — note AceGUI's swapped names: `height` is the visible frame
-- height, `viewheight` the content height.
local function installAlwaysShownScrollbar(scroll)
  local bar = scroll.scrollbar
  if not (bar and scroll.scrollframe and scroll.content) then return end

  local function setInert(inert)
    if inert then
      if bar.Disable then bar:Disable() end
    else
      if bar.Enable then bar:Enable() end
    end
    local up, down = bar.ScrollUpButton, bar.ScrollDownButton
    if up and up.SetEnabled then up:SetEnabled(not inert) end
    if down and down.SetEnabled then down:SetEnabled(not inert) end
  end

  -- Wheel-scroll must be inert when the page fits. AceGUI's stock MoveScroll gates only on
  -- `scrollBarShown`, which this override keeps permanently true (to reserve the gutter) — so
  -- without this guard the wheel would still drift the parked thumb on a short page.
  local stockMoveScroll = scroll.MoveScroll
  scroll.MoveScroll = function(self, value)
    local height, viewheight = self.scrollframe:GetHeight(), self.content:GetHeight()
    if viewheight < height + 2 then return end
    return stockMoveScroll(self, value)
  end

  scroll.FixScroll = function(self)
    if self.updateLock then return end
    self.updateLock = true
    local status = self.status or self.localstatus
    local height, viewheight = self.scrollframe:GetHeight(), self.content:GetHeight()
    local offset = status.offset or 0
    -- Reserve the gutter and show the bar once (the stock "show" branch minus the auto-hide path).
    -- Once shown it stays shown, so the body never reflows between pages.
    if not self.scrollBarShown then
      self.scrollBarShown = true
      self.scrollbar:Show()
      self.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
      if self.content.original_width then
        self.content.width = self.content.original_width - 20
      end
      self:DoLayout()
    end
    if viewheight < height + 2 then
      self.scrollbar:SetValue(0)   -- content fits: park the thumb and grey the bar out
      setInert(true)
    else
      setInert(false)
      local value = (offset / (viewheight - height) * 1000)
      if value > 1000 then value = 1000 end
      self.scrollbar:SetValue(value)
      self:SetScroll(value)
      if value < 1000 then
        self.content:ClearAllPoints()
        self.content:SetPoint("TOPLEFT", 0, offset)
        self.content:SetPoint("TOPRIGHT", 0, offset)
        status.offset = offset
      end
    end
    self.updateLock = nil
  end
end

local function ensureScroll(ctx)
  if ctx.scroll then return ctx.scroll end
  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("List")
  scroll.frame:SetParent(ctx.body)
  scroll.frame:ClearAllPoints()
  scroll.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      PADDING_X - 4, -8)
  scroll.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -(PADDING_X + 12), 8)
  scroll.frame:Show()
  installAlwaysShownScrollbar(scroll)
  ctx.scroll = scroll
  return scroll
end

local function addSpacer(scroll, height)
  local sp = AceGUI:Create("SimpleGroup")
  sp:SetLayout(nil); sp:SetFullWidth(true); sp:SetHeight(height)
  scroll:AddChild(sp)
end

-- A section heading: a centred gold label flanked by dividers (options-ui-§7). The same widget the
-- landing page uses for "Slash Commands", so headings read identically everywhere.
local function section(ctx, label)
  local scroll = ensureScroll(ctx)
  if ctx.lastGroup ~= nil then addSpacer(scroll, SECTION_TOP_SPACER) end
  local h = AceGUI:Create("Heading")
  h:SetText(label); h:SetFullWidth(true); h:SetHeight(SECTION_HEADING_H)
  if h.label and h.label.SetFontObject and _G.GameFontNormalLarge then
    h.label:SetFontObject(_G.GameFontNormalLarge)
  end
  scroll:AddChild(h)
  addSpacer(scroll, SECTION_BOTTOM_SPACER)
end

-- ── Widget makers ───────────────────────────────────────────────────────────────
local function applyWidth(w, rel)
  if rel then w:SetRelativeWidth(rel) else w:SetFullWidth(true) end
end

-- The single seam for a paired action button's width — insets to BUTTON_PAIR_REL so the right
-- border isn't shaved by the ScrollFrame clip. Never hand-set 0.5 on a paired button.
local function makePairButton(text, onClick)
  local btn = AceGUI:Create("Button")
  btn:SetText(text)
  btn:SetRelativeWidth(BUTTON_PAIR_REL)
  if onClick then btn:SetCallback("OnClick", onClick) end
  return btn
end

local function makeCheckbox(ctx, row, parent, rel)
  local cb = AceGUI:Create("CheckBox")
  cb:SetLabel(row.label); applyWidth(cb, rel)
  cb:SetCallback("OnValueChanged", function(_, _, v) NS.Schema:Set(row.path, v and true or false) end)
  attachTooltip(cb, row.label, row.tooltip)
  parent:AddChild(cb)
  ctx.refreshers[#ctx.refreshers + 1] =
    function() cb:SetValue(NS.Schema:Get(row.path) and true or false) end
  cb:SetValue(NS.Schema:Get(row.path) and true or false)
  return cb
end

local function makeDropdown(ctx, row, parent, rel)
  local dd = AceGUI:Create("Dropdown")
  dd:SetLabel(row.label); applyWidth(dd, rel)
  local list, order = {}, {}
  for i, opt in ipairs(row.options) do list[opt.value] = opt.label; order[i] = opt.value end
  dd:SetList(list, order)
  dd:SetCallback("OnValueChanged", function(_, _, key) NS.Schema:Set(row.path, key) end)
  attachTooltip(dd, row.label, row.tooltip)
  parent:AddChild(dd)
  ctx.refreshers[#ctx.refreshers + 1] = function() dd:SetValue(NS.Schema:Get(row.path)) end
  dd:SetValue(NS.Schema:Get(row.path))
  return dd
end

local function makeSlider(ctx, row, parent, rel)
  local s = AceGUI:Create("Slider")
  s:SetLabel(row.label)
  s:SetSliderValues(row.min or 0, row.max or 1, row.step or 0.05)
  applyWidth(s, rel)
  s:SetCallback("OnMouseUp", function(_, _, v) NS.Schema:Set(row.path, v) end)
  attachTooltip(s, row.label, row.tooltip)
  parent:AddChild(s)
  ctx.refreshers[#ctx.refreshers + 1] =
    function() s:SetValue(NS.Schema:Get(row.path) or row.default) end
  s:SetValue(NS.Schema:Get(row.path) or row.default)
  return s
end

-- A set-map rendered full-width as a wrapping checkbox grid. With row.invert, a CHECKED box means
-- the store is recorded (i.e. NOT in the muted set), so the stored value is the logical inverse of
-- the checkbox state.
local function makeMultiCheck(ctx, row, scroll)
  local invert = row.invert
  local group = AceGUI:Create("InlineGroup")
  group:SetTitle(row.label); group:SetFullWidth(true); group:SetLayout("Flow")
  local boxes = {}
  for _, opt in ipairs(row.options) do
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(opt.label); cb:SetWidth(170)
    cb:SetCallback("OnValueChanged", function(_, _, v)
      local cur = NS.Schema:Get(row.path) or {}
      local copy = {}
      for k, val in pairs(cur) do copy[k] = val end
      copy[opt.value] = ((invert and not v) or (not invert and v)) or nil
      NS.Schema:Set(row.path, copy)
    end)
    group:AddChild(cb)
    boxes[opt.value] = cb
  end
  scroll:AddChild(group)
  ctx.refreshers[#ctx.refreshers + 1] = function()
    local cur = NS.Schema:Get(row.path) or {}
    for value, cb in pairs(boxes) do
      local muted = cur[value] and true or false
      cb:SetValue(invert and not muted or (not invert and muted))
    end
  end
end

-- ── Two-column schema render (options-ui-§6) ────────────────────────────────────
-- Rows pair into 50%/50% Flow lines. A MultiCheck (or wide = true) row breaks onto its own
-- full-width line; a group change emits a section heading. `companions` optionally maps a row's
-- path → function(parentRow) that adds a widget into the SAME row, right of the field.
local function renderSchema(ctx, companions, opts)
  opts = opts or {}
  local scroll = ensureScroll(ctx)
  local pendingRow

  local function flushRow()
    if pendingRow then
      scroll:AddChild(pendingRow); addSpacer(scroll, ROW_VSPACER); pendingRow = nil
    end
  end
  local function startRow()
    local r = AceGUI:Create("SimpleGroup"); r:SetLayout("Flow"); r:SetFullWidth(true); return r
  end

  for _, row in ipairs(NS.Schema.Schema) do
    local include = not ((opts.only and row.group ~= opts.only)
      or (opts.skip and row.group and opts.skip[row.group])
      or row.panelSkip)
    if include then
      if row.group and row.group ~= ctx.lastGroup then
        flushRow(); section(ctx, row.group); ctx.lastGroup = row.group
      end

      if row.widget == "MultiCheck" or row.wide then
        flushRow()
        makeMultiCheck(ctx, row, scroll)
      else
        -- A soloRow widget sits alone on its own line: flush any half-filled row first.
        if row.soloRow then flushRow() end
        if not pendingRow then pendingRow = startRow() end
        if row.widget == "CheckBox" then makeCheckbox(ctx, row, pendingRow, 0.5)
        elseif row.widget == "Dropdown" then makeDropdown(ctx, row, pendingRow, 0.5)
        elseif row.widget == "Slider" then makeSlider(ctx, row, pendingRow, 0.5) end
        local comp = companions and companions[row.path]
        if comp then
          comp(pendingRow)
          flushRow()
        elseif row.soloRow or #pendingRow.children >= 2 then
          flushRow()
        end
      end
    end
  end
  flushRow()
end

-- ── Storage section: live DB stats + purge ─────────────────────────────────────
local function renderStorage(ctx)
  local scroll = ensureScroll(ctx)
  section(ctx, "Storage")

  local rowFrame = AceGUI:Create("SimpleGroup")
  rowFrame:SetLayout("Flow"); rowFrame:SetFullWidth(true)

  local statsLabel = AceGUI:Create("Label")
  statsLabel:SetRelativeWidth(0.5)
  rowFrame:AddChild(statsLabel)

  -- "Purge ledger…" — the ellipsis says it opens a confirm dialog.
  local purgeBtn = makePairButton("Purge ledger\226\128\166", function()
    if type(StaticPopup_Show) == "function" then StaticPopup_Show("KA0S_BANKLEDGER_PURGE")
    elseif NS.Database and NS.Database.Purge then NS.Database:Purge() end
  end)
  rowFrame:AddChild(purgeBtn)
  scroll:AddChild(rowFrame)

  local function refreshStats()
    local s = NS.Database:StorageStats()
    local line1
    if s.count == 0 then
      line1 = "No movements recorded yet."
    else
      local count = (BreakUpLargeNumbers and BreakUpLargeNumbers(s.count)) or s.count
      line1 = string.format("%s %s recorded over %d %s.",
        tostring(count), s.count == 1 and "movement" or "movements",
        s.days, s.days == 1 and "day" or "days")
    end
    -- \226\137\136 = "≈". The real SavedVariables file size can't be read in-game, so it's estimated.
    statsLabel:SetText(line1 .. "\nDatabase size: \226\137\136 " ..
      NS.Util.FormatBytes(s.bytes) .. "  (estimated)")
  end
  ctx.refreshers[#ctx.refreshers + 1] = refreshStats
  refreshStats()

  -- Live-refresh while the panel is open, on a private bus target (NOT NS.bus-as-self) so it can't
  -- clobber the Browser/Insights consumers of the same messages (architecture-§4).
  if not P.__ev then
    local ev = NS.NewBusTarget()
    if ev then
      local onChange = function() if ctx.panel:IsShown() then refreshStats() end end
      ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", onChange)
      ev:RegisterMessage("Ka0s_BankLedger_EntryAdded", onChange)
      P.__ev = ev
    end
  end
end

-- Run a page's structural rebuilders (list rows) and relayout, then clear its dirty flag. Called on
-- first paint, on an on-screen edit, and on the next OnShow after an off-screen change — the gate
-- that keeps AceGUI teardown+rebuild off every tab click (options-ui-§11).
local function runRebuilders(ctx)
  for _, fn in ipairs(ctx.rebuilders or {}) do pcall(fn) end
  ctx.dirty = false
  if ctx.scroll and ctx.scroll.DoLayout then ctx.scroll:DoLayout() end
end

-- ── Filters sub-page: blacklist / whitelist item-id management ─────────────────

-- Display name for an id: "Name  (id)" once cached, "Item <id>" until the client caches it (a
-- background load is kicked off so a later rebuild fills the name in).
local function filterEntryLabel(id, onCached)
  local name, quality = NS.Compat.ItemNameQuality(id)
  if not name then
    if NS.Compat.LoadItem then NS.Compat.LoadItem(id, onCached) end
    return "|cffaaaaaaItem " .. id .. "|r"
  end
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
  local hex = c and c.color and c.color.GenerateHexColor and c.color:GenerateHexColor()
  local shown = hex and ("|c" .. hex .. name .. "|r") or name
  return shown .. "  |cff808080(" .. id .. ")|r"
end

-- Rebuild `listGroup` from the ids currently on `listKey`. Each row: item label + Remove button.
local function rebuildFilterList(ctx, listGroup, listKey)
  listGroup:ReleaseChildren()
  local set = (listKey == "blacklist") and NS.Filters:Blacklist() or NS.Filters:Whitelist()
  local ids = NS.Filters:SortedIDs(set)
  if #ids == 0 then
    local empty = AceGUI:Create("Label")
    empty:SetFullWidth(true)
    empty:SetText("|cff808080(none)|r")
    listGroup:AddChild(empty)
  else
    for _, id in ipairs(ids) do
      local rowG = AceGUI:Create("SimpleGroup")
      rowG:SetLayout("Flow"); rowG:SetFullWidth(true)
      local lbl = AceGUI:Create("Label")
      lbl:SetRelativeWidth(0.78)
      lbl:SetText(filterEntryLabel(id, function()
        if ctx.panel:IsShown() then rebuildFilterList(ctx, listGroup, listKey) end
      end))
      rowG:AddChild(lbl)
      local rm = AceGUI:Create("Button")
      rm:SetText("Remove"); rm:SetRelativeWidth(0.20)
      rm:SetCallback("OnClick", function()
        if listKey == "blacklist" then NS.Filters:RemoveBlacklist(id)
        else NS.Filters:RemoveWhitelist(id) end
        rebuildFilterList(ctx, listGroup, listKey)
        if ctx.scroll and ctx.scroll.DoLayout then ctx.scroll:DoLayout() end
      end)
      rowG:AddChild(rm)
      listGroup:AddChild(rowG)
    end
  end
  if listGroup.DoLayout then listGroup:DoLayout() end
end

-- One section (blacklist or whitelist): heading, description, add-row, bulk clear, live list.
local function makeFilterSection(ctx, listKey, title, desc)
  local scroll = ensureScroll(ctx)
  section(ctx, title)

  local descLabel = AceGUI:Create("Label")
  descLabel:SetFullWidth(true); descLabel:SetText(desc)
  scroll:AddChild(descLabel)
  addSpacer(scroll, 6)

  local listGroup = AceGUI:Create("SimpleGroup")
  listGroup:SetLayout("List"); listGroup:SetFullWidth(true)

  local addRow = AceGUI:Create("SimpleGroup")
  addRow:SetLayout("Flow"); addRow:SetFullWidth(true)
  local box = AceGUI:Create("EditBox")
  box:SetLabel("Add item id or link")
  box:SetRelativeWidth(0.78)
  local function submit()
    local id = NS.Filters:ParseItemID(box:GetText())
    if not id then
      print("enter a numeric item id (or shift-click an item link).")
      return
    end
    if listKey == "blacklist" then NS.Filters:AddBlacklist(id) else NS.Filters:AddWhitelist(id) end
    box:SetText("")
    rebuildFilterList(ctx, listGroup, listKey)
    if ctx.scroll and ctx.scroll.DoLayout then ctx.scroll:DoLayout() end
  end
  box:SetCallback("OnEnterPressed", function() submit() end)
  addRow:AddChild(box)
  local addBtn = AceGUI:Create("Button")
  addBtn:SetText("Add"); addBtn:SetRelativeWidth(0.20)
  addBtn:SetCallback("OnClick", submit)
  addRow:AddChild(addBtn)
  scroll:AddChild(addRow)
  addSpacer(scroll, 4)

  local clearRow = AceGUI:Create("SimpleGroup")
  clearRow:SetLayout("Flow"); clearRow:SetFullWidth(true)
  local clearBtn = AceGUI:Create("Button")
  clearBtn:SetText("Clear all"); clearBtn:SetRelativeWidth(0.30)
  clearBtn:SetCallback("OnClick", function()
    local popup = (listKey == "blacklist") and "KA0S_BANKLEDGER_CLEAR_BLACKLIST"
      or "KA0S_BANKLEDGER_CLEAR_WHITELIST"
    if type(StaticPopup_Show) == "function" then
      StaticPopup_Show(popup)
    elseif NS.Filters then
      NS.Filters:ClearList(listKey)
    end
  end)
  clearRow:AddChild(clearBtn)
  scroll:AddChild(clearRow)
  addSpacer(scroll, 4)

  scroll:AddChild(listGroup)

  -- A structural rebuild (rows added/removed), so it registers as a REBUILDER: it fires on first
  -- paint, on an on-screen edit, and on the next OnShow after an off-screen change — never on every
  -- OnShow (options-ui-§11).
  ctx.rebuilders[#ctx.rebuilders + 1] = function() rebuildFilterList(ctx, listGroup, listKey) end
end

local function buildFilters(ctx)
  makeFilterSection(ctx, "blacklist", "Blacklist",
    "Items here are never recorded when they move from now on. Existing rows are left untouched "
    .. "(this only affects future movements — delete old rows from the ledger table if you want "
    .. "them gone).")
  makeFilterSection(ctx, "whitelist", "Whitelist",
    "Items here are always recorded, even when they fall below your minimum quality. Adding an id "
    .. "to one list removes it from the other.")

  -- Live-update both lists when they change from elsewhere (the ledger table's right-click menu),
  -- on a private bus target. While the page is on screen we repaint immediately; while it is hidden
  -- we only flag it dirty, so the next OnShow repaints once instead of every tab click paying an
  -- AceGUI teardown+rebuild (options-ui-§11).
  if not P.__evFilters then
    local ev = NS.NewBusTarget()
    if ev then
      ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", function()
        if ctx.panel:IsShown() then runRebuilders(ctx) else ctx.dirty = true end
      end)
      P.__evFilters = ev
    end
  end
end

-- ── Landing page: logo + tagline + slash-command list (options-ui-§5) ───────────
local function buildMainContent(ctx)
  local scroll = ensureScroll(ctx)

  local logoGroup = AceGUI:Create("SimpleGroup")
  logoGroup:SetLayout(nil); logoGroup:SetFullWidth(true); logoGroup:SetHeight(LOGO_SIZE)
  local tex = logoGroup.frame:CreateTexture(nil, "ARTWORK")
  tex:SetTexture(NS.Constants.LOGO_PATH)
  tex:SetSize(LOGO_SIZE, LOGO_SIZE)
  tex:SetPoint("TOPLEFT", logoGroup.frame, "TOPLEFT", 0, 0)
  scroll:AddChild(logoGroup)
  addSpacer(scroll, 8)

  local desc = AceGUI:Create("Label")
  desc:SetFullWidth(true); desc:SetText(ADDON_TAGLINE)
  if desc.label and desc.label.SetFontObject and _G.GameFontHighlight then
    desc.label:SetFontObject(_G.GameFontHighlight)
  end
  scroll:AddChild(desc)
  addSpacer(scroll, 12)

  local heading = AceGUI:Create("Heading")
  heading:SetFullWidth(true); heading:SetHeight(SECTION_HEADING_H); heading:SetText("Slash Commands")
  if heading.label and heading.label.SetFontObject and _G.GameFontNormalLarge then
    heading.label:SetFontObject(_G.GameFontNormalLarge)
  end
  scroll:AddChild(heading)
  addSpacer(scroll, 6)

  -- Generated from NS.COMMANDS, so this list stays in lockstep with `/bl help` (options-ui-§5).
  for _, cmd in ipairs(NS.COMMANDS or {}) do
    local labelRow = AceGUI:Create("Label")
    labelRow:SetFullWidth(true)
    labelRow:SetText(("|cffffff00/bl %s|r  |cffffffff\226\128\148|r  %s"):format(cmd.name, cmd.desc))
    scroll:AddChild(labelRow)
  end
end

-- ── Refresh / Defaults ─────────────────────────────────────────────────────────

-- Scalar re-sync only: run each rendered widget's updater closure. Structural rebuilds are the
-- rebuilders' job and are gated separately (options-ui-§11).
function P:Refresh()
  if not P.general or not P.general.refreshers then return end
  for _, fn in ipairs(P.general.refreshers) do pcall(fn) end
end

function P:RestoreDefaults()
  if NS.Slash and NS.Slash.CliResetAll then NS.Slash:CliResetAll() end
  -- Defaults also recentres the window (position is part of the stock state); the ledger is left alone.
  if NS.Browser and NS.Browser.ResetWindow then NS.Browser:ResetWindow() end
  P:Refresh()
end

-- ── Registration ───────────────────────────────────────────────────────────────
function P:Register()
  if registered then return end
  if not (AceGUI and Settings and Settings.RegisterCanvasLayoutCategory
          and Settings.RegisterCanvasLayoutSubcategory) then return end
  registered = true

  -- Parent category = the landing page.
  local mainCtx = createPanel(ADDON_TITLE, { isMain = true })
  local mainRendered = false
  mainCtx.panel:SetScript("OnShow", function()
    if mainRendered then return end
    mainRendered = true
    buildMainContent(mainCtx)
    if mainCtx.scroll and mainCtx.scroll.DoLayout then mainCtx.scroll:DoLayout() end
  end)
  local mainCategory = Settings.RegisterCanvasLayoutCategory(mainCtx.panel, ADDON_TITLE)
  Settings.RegisterAddOnCategory(mainCategory)
  mainCategoryID = mainCategory and mainCategory.GetID and mainCategory:GetID()

  -- General subcategory = the actual settings.
  local ctx = createPanel("General", { defaultsButton = true })
  P.general = ctx
  if ctx.panel.defaultsBtn then
    ctx.panel.defaultsBtn:SetCallback("OnClick", function() P:RestoreDefaults() end)
  end
  local rendered = false
  ctx.panel:SetScript("OnShow", function()
    if not rendered then
      rendered = true
      -- "Reset all" sits to the right of Window scale; it wipes the ledger AND the settings.
      renderSchema(ctx, {
        ["settings.windowScale"] = function(parentRow)
          parentRow:AddChild(makePairButton("Reset all", function()
            if type(StaticPopup_Show) == "function" then
              StaticPopup_Show("KA0S_BANKLEDGER_RESETALL")
            elseif NS.Slash and NS.Slash.ResetEverything then
              NS.Slash:ResetEverything()
            end
          end))
        end,
      })
      renderStorage(ctx)
      if ctx.scroll and ctx.scroll.DoLayout then ctx.scroll:DoLayout() end
    end
    P:Refresh()
  end)
  Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, "General")

  -- Filters subcategory = blacklist / whitelist item-id management.
  local fctx = createPanel("Filters", { defaultsButton = true })
  P.filters = fctx
  -- Defaults here = clear both id-lists (their stock state is empty), confirm-gated. The page holds
  -- no Schema rows, so this is the "restore defaults" for what it manages.
  if fctx.panel.defaultsBtn then
    fctx.panel.defaultsBtn:SetCallback("OnClick", function()
      if type(StaticPopup_Show) == "function" then
        StaticPopup_Show("KA0S_BANKLEDGER_CLEAR_FILTERS")
      elseif NS.Filters then
        NS.Filters:ClearAll()
      end
    end)
  end
  local fRendered = false
  fctx.panel:SetScript("OnShow", function()
    if not fRendered then
      fRendered = true
      buildFilters(fctx)
      runRebuilders(fctx)   -- first paint of both id-lists
    elseif fctx.dirty then
      runRebuilders(fctx)   -- lists changed while hidden → repaint once (options-ui-§11)
    end
    for _, fn in ipairs(fctx.refreshers) do pcall(fn) end
  end)
  Settings.RegisterCanvasLayoutSubcategory(mainCategory, fctx.panel, "Filters")
end

function P:Open()
  -- options-ui-§2: REFUSE in combat — Blizzard's category-switch is protected, and calling it under
  -- lockdown taints the panel for the rest of the session. A grey notice and an early return; never
  -- defer-and-replay on PLAYER_REGEN_ENABLED (a panel that pops itself open the instant combat drops
  -- steals focus during post-pull recovery). \226\128\148 = em-dash.
  if InCombatLockdown and InCombatLockdown() then
    print("|cff808080cannot open settings during combat \226\128\148 "
      .. "Blizzard's category-switch is protected|r")
    return
  end
  if Settings and Settings.OpenToCategory and mainCategoryID then
    Settings.OpenToCategory(mainCategoryID)
  end
end
