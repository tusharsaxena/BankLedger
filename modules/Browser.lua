local addonName, NS = ...   -- luacheck: ignore addonName
NS.Browser = NS.Browser or {}
local B = NS.Browser
local C = NS.Constants
local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)   -- the flat-skin dropdown, vendored
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)
local frame

local LDB_NAME = "Ka0s Bank Ledger"   -- LibDataBroker object + LibDBIcon registration key
local minimapObject                   -- the LDB launcher, created once on first Enable
local DBIcon                          -- LibDBIcon-1.0, resolved lazily in SetupMinimap

-- The standalone ledger window (standalone-windows): a plain, non-secure, movable/resizable frame,
-- so it touches nothing protected and needs no combat gate. It hosts two tabs — the History table
-- and the Insights charts — over ONE shared filter bar, so both views always describe the same
-- slice of the ledger.

-- The window CHROME this addon owns: the tab strip's two label colors and every height the
-- layout is measured from. The window EDGE is NOT here — background, 1px black border, 1px gray
-- inner highlight, gold title tint and gray divider are the normative Ka0s edge, and they live in
-- Core.SKIN (standalone-windows). B:ApplySkin below delegates to Core.ApplySkin rather than
-- restating them, so the ledger window, the session window, both export popups and the debug
-- console cannot drift apart. The seam stays because those four reach the edge through it.
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SKIN = {
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
--   Row-2 dropdowns: Date 110 · Direction 110 · Store 130 · Quality 100 · Type 110 ·
--                    Sub-type 110 · Character 140
local DD_W = { date = 110, direction = 110, store = 130, quality = 100, type = 110,
               subtype = 110, char = 140 }
local DD_GAP = 8
local DROPDOWNS_W = DD_W.date + DD_W.direction + DD_W.store + DD_W.type + DD_W.subtype
                  + DD_W.quality + DD_W.char + 6 * DD_GAP
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
  return math.max(EXPORT_MIN, (self:MinWidth() - 12) - (DROPDOWNS_W + DD_GAP))
end

-- Wear the shared Ka0s window edge. Every value this used to spell out — the WHITE8x8 backdrop at
-- edgeSize 1, the {0.06,0.06,0.08,0.92} fill, the black border, the {0.24,0.24,0.27,0.85} inner
-- highlight and divider, the {1,0.82,0} title — is Core.SKIN, byte for byte, and Core.ApplySkin
-- makes the same six calls in the same order, including building the inner-border child once.
-- Delegated rather than restated so a re-skin lands on all five Ka0s windows at once.
--
-- NS.ApplySkin is core/CoreSetup.lua's seam: the library's on a working install, and that file's
-- own pre-library copy when libs/LibKa0s is missing, so the window wears the same edge either
-- way. Guarded anyway, because this is the only file that skins a frame this addon owns.
function B:ApplySkin(f)
  if NS.ApplySkin then NS.ApplySkin(f) end
end

-- The close control every window this addon draws wears: the collection's `close` mark where the
-- shared art is there, and the thin × glyph it has always drawn where it is not. Light gray at
-- rest, the player's class color on hover, either way. Shared by the ledger window (Browser.lua),
-- the session window (SessionWindow.lua) and both export popups (Export.lua). NOT by the debug
-- console: that is the LIBRARY's window and wears Core's own 18x18 close — the edge is shared
-- across every Ka0s window, but the close control on a library-drawn window is the library's
-- (standalone-windows). The library draws that one for itself, once core/DebugLogSetup.lua hands it
-- `addonName`; this addon publishes NO wrapper onto `lib.MakeCloseButton`, and the paragraph headed
-- "IS DELIBERATELY NOT REPUBLISHED" in core/CoreSetup.lua says why it must not grow one.
--
-- TWO RUNGS, AND THE LOWER ONE STAYS. NS.Icon answers nil twice over — no LibKa0s at all, or a
-- catalog that no longer carries "close" — and both mean the same thing here: draw the ×. A
-- degraded install keeps a close button that works and looks exactly as it did before the mark
-- existed. Nothing below builds a path by concatenation to route around the nil, because a
-- plausible path to art that is not there is a title bar with no visible way out of it.
--
-- The art ships WHITE so a multiply lands wherever the caller asks; the two colors below are the
-- ones the glyph has always used, so the mark obeys this addon's own skin rather than replacing it.
local CLOSE_REST = { 0.85, 0.85, 0.85 }

function B:MakeCloseButton(parent, onClick)
  local close = CreateFrame("Button", nil, parent)
  close:SetSize(24, 24)
  local _, class = UnitClass("player")
  local cc = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or { r = 1, g = 0.82, b = 0 }

  local path = NS.Icon and NS.Icon("close")
  if path then
    local art = close:CreateTexture(nil, "OVERLAY")
    art:SetPoint("CENTER")
    art:SetSize(12, 12)
    art:SetTexture(path)
    art:SetVertexColor(CLOSE_REST[1], CLOSE_REST[2], CLOSE_REST[3])
    close:SetScript("OnEnter", function() art:SetVertexColor(cc.r, cc.g, cc.b) end)
    close:SetScript("OnLeave", function()
      art:SetVertexColor(CLOSE_REST[1], CLOSE_REST[2], CLOSE_REST[3])
    end)
    close.icon = art
  else
    local x = close:CreateFontString(nil, "OVERLAY")
    x:SetFont(STANDARD_TEXT_FONT, 24, "")
    x:SetPoint("CENTER", close, "CENTER", 0, 2)   -- the × sits low in its font box; nudge it up
    x:SetText("\195\151")
    x:SetTextColor(CLOSE_REST[1], CLOSE_REST[2], CLOSE_REST[3])
    close:SetScript("OnEnter", function() x:SetTextColor(cc.r, cc.g, cc.b) end)
    close:SetScript("OnLeave", function()
      x:SetTextColor(CLOSE_REST[1], CLOSE_REST[2], CLOSE_REST[3])
    end)
    close.glyph = x
  end

  close:SetScript("OnClick", onClick)
  return close
end

-- ── Window position/size persistence ──────────────────────────────────────────
-- settings.window = { point, x, y, w, h } relative to UIParent. Window geometry is runtime view
-- state, deliberately NOT a Schema row — an architecture-§5 carve-out written directly here
-- (standalone-windows requires it be persisted; it has no place in the settings panel).

-- WHEN the save runs matters as much as what it writes, and the obvious answer is wrong. Saving only
-- at the end of a drag or a resize means the geometry can live purely in the frame — which outlives
-- every Hide/Show, so it looks perfectly persistent for a whole game session and is gone on the
-- first /reload. The resize case is the easy one to miss: releasing the grip a pixel outside a 16×16
-- button never delivers its OnMouseUp. So the save is also anchored to moments that are GUARANTEED —
-- every OnHide, and PLAYER_LOGOUT for a /reload with the window still on screen, where OnHide never
-- runs. The interaction handlers stay; they cost nothing and keep the stored value current.
-- modules/SessionWindow.lua does exactly the same, through the same two method names.

function B:SaveGeometry()
  if not frame then return false end
  local settings = NS.db and NS.db.global and NS.db.global.settings
  if not settings then return false end
  local point, _, _, x, y = frame:GetPoint(1)
  -- A frame with no anchor has nothing worth saving, and a point-less table would make
  -- ApplyGeometry fall through to the default and silently discard the real position.
  if not point then return false end
  settings.window = {
    point = point, x = x or 0, y = y or 0,
    w = frame:GetWidth(), h = frame:GetHeight(),
  }
  return true
end

function B:ApplyGeometry()
  if not frame then return end
  local w = NS.db and NS.db.global.settings.window
  frame:ClearAllPoints()
  if w and w.point then
    frame:SetPoint(w.point, UIParent, w.point, w.x or 0, w.y or 0)
    -- Clamped on the way in as well as on the way out, so a size saved against an older column set
    -- (or a hand-edited SavedVariables) cannot reopen the window too small to read.
    if type(w.w) == "number" and type(w.h) == "number" then
      frame:SetSize(math.max(self._minW or 0, w.w), math.max(self._minH or 0, w.h))
    end
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

-- Persist at logout, the one teardown path that does not run OnHide.
function B:OnLogout()
  self:SaveGeometry()
end

-- Reset the persisted geometry and recenter the live frame. Used only by the destructive
-- "Reset all", since position is runtime state the ordinary settings resets leave alone.
function B:ResetWindow()
  if NS.db and NS.db.global and NS.db.global.settings then
    NS.db.global.settings.window = {}
  end
  if frame then
    frame:ClearAllPoints()
    self:ApplyGeometry()
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

-- The flat dropdown is LibKa0s-Widgets-1.0's now. What stays here is the INJECTION, and it stays
-- here because it cannot live there: the library builds no path of its own -- Media.Icon needs the
-- consuming addon's name, and a vendored copy does not know which folder it was copied into. So the
-- three pieces of art a Bank Ledger dropdown wears are resolved on this side and handed over.
--
-- FONT_MONO for the glyph because the row font has no ▲/▼, which is the same documented deviation
-- the Direction column in modules/LedgerTable.lua carries, for the same reason.
function B:MakeDropdown(parent, width)
  if not W then return nil end
  return W.Dropdown(parent, width, {
    chevron   = NS.Icon and NS.Icon("chevron-down"),
    check     = NS.Icon and NS.Icon("confirm"),
    glyphFont = C.FONT_MONO,
  })
end

-- A small flat-skin text button for the filter bar.
--
-- WORDS ONLY, and that is a decision rather than an omission. This factory did take an optional
-- RESOLVED PATH for a mark drawn BESIDE the label, and the filter bar's Export button was the one
-- caller wide enough to pass one. It does not any more: four buttons sit in a row here, three of
-- them too narrow for art beside a centred label (see the note in BuildFilterBar), and one marked
-- button among four unmarked ones read as an odd one out rather than as an affordance. The MODAL's
-- "Export to CSV" keeps its mark — that button is alone in its window, where the mark is the only
-- art on the surface and has nothing to be inconsistent with.
--
-- So a mark added back here belongs on ALL of these or none of them, and the tripwire in
-- tests/test_marks.lua pins the current answer: nothing under this factory resolves NS.Icon.
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
  -- Exposed the same way makeMenuRow exposes its own, and for the same kind of reason: the WORDS are
  -- the half of a BESIDE button that no other assertion can reach. Without this the mark suite can
  -- see the art and the anchors but not the label, so a call site that passed "" would ship a
  -- wordless glyph button — and an install without LibKa0s an entirely empty one — while every
  -- headless instrument in the repo stayed green.
  b.fs = fs
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

-- The dataset the filter bar reflects: whatever the table is currently showing (test data or the
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
  { value = "direction", label = "Group: Direction" },
  { value = "kind",      label = "Group: Item/Gold" },
  { value = "type",      label = "Group: Type" },
  { value = "subtype",   label = "Group: Sub-type" },
  { value = "quality",   label = "Group: Quality" },
  { value = "char",      label = "Group: Character" },
}
local DATE_OPTIONS = {
  { value = "all",   label = "Date: All" },
  { value = "today", label = "Today" },
  { value = "7d",    label = "Last 7 days" },
  { value = "30d",   label = "Last 30 days" },
}

-- The Character dropdown's "Current" sentinel. \001 is unprintable and illegal in a character name,
-- so this value can never collide with a real Name-Realm key.
local CURRENT_CHAR = "\001current"

-- Sort distinct options by label and prefix the "All" sentinel (kept first regardless of sort).
local function withAll(allLabel, items)
  table.sort(items, function(a, b) return a.label < b.label end)
  table.insert(items, 1, { value = "all", label = allLabel })
  return items
end

-- Data-driven option lists: only the values the dataset actually contains are offered, so an empty
-- ledger doesn't show five stores you've never used.
-- Direction and Store options carry the same colors (and, for a direction, the same ▲/▼ glyph) the
-- table paints those values with, straight out of the shared palette in Constants — so the menu
-- reads as the column it filters.
local function directionOptions()
  local present = {}
  for _, e in ipairs(dataset()) do present[e.direction or "DEPOSIT"] = true end
  local items = { { value = "all", label = "Direction: All" } }
  for _, k in ipairs(C.DirectionOrder) do
    if present[k] then
      items[#items + 1] = { value = k, label = C.DirectionLabel[k],
                            color = C.DirectionRGB[k], glyph = C.DirectionGlyph[k] }
    end
  end
  return items
end
local function storeOptions()
  local present = {}
  for _, e in ipairs(dataset()) do if e.store then present[e.store] = true end end
  local items = { { value = "all", label = "Store: All" } }
  for _, k in ipairs(C.StoreOrder) do
    if present[k] then
      items[#items + 1] = { value = k, label = C.StoreLabel[k], color = C.StoreRGB[k] }
    end
  end
  return items
end
-- Type and Sub-type both list EFFECTIVE types (NS.Util.EntryType), so "Gold" is offered whenever the
-- data holds a gold movement — the dropdown can list everything the column can show.
local function typeOptions()
  local seen, items = {}, {}
  for _, e in ipairs(dataset()) do
    local ty = NS.Util.EntryType(e)
    if ty ~= "" and not seen[ty] then
      seen[ty] = true
      items[#items + 1] = { value = ty, label = ty }
    end
  end
  return withAll("Type: All", items)
end
local function subTypeOptions()
  local seen, items = {}, {}
  for _, e in ipairs(dataset()) do
    local st = NS.Util.EntrySubType(e)
    if st ~= "" and not seen[st] then
      seen[st] = true
      items[#items + 1] = { value = st, label = st }
    end
  end
  return withAll("Sub-type: All", items)
end
-- Quality is the one data-driven list NOT sorted by label: Poor→Legendary is a meaningful order, so
-- the options stay in ascending quality id and carry the quality color. Gold rows have no quality
-- and so contribute no option — filtering on quality is, by definition, an item question.
local function qualityOptions()
  local present = {}
  for _, e in ipairs(dataset()) do
    if type(e.quality) == "number" then present[e.quality] = true end
  end
  local ids = {}
  for q in pairs(present) do ids[#ids + 1] = q end
  table.sort(ids)
  local items = { { value = "all", label = "Quality: All" } }
  for _, q in ipairs(ids) do
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    items[#items + 1] = { value = q, label = NS.Compat.QualityLabel(q),
                          color = c and { c.r, c.g, c.b } or nil }
  end
  return items
end
local function charOptions()
  local seen, items = {}, {}
  for _, e in ipairs(dataset()) do
    local ch = e.char
    if ch and not seen[ch] then
      seen[ch] = true
      local cc = e.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.classFile]
      items[#items + 1] = { value = ch, label = NS.Util.ClassIconMarkup(e.classFile) .. ch,
                            color = cc and { cc.r, cc.g, cc.b } or nil }
    end
  end
  -- Sorted on the label, which now begins with icon markup — identical for every row of one class,
  -- so it would sort by class and then name. Sort on the bare name instead.
  table.sort(items, function(a, b) return a.value < b.value end)
  table.insert(items, 1, { value = "all", label = "Character: All" })
  -- "Current" is a standing intent, not a name: it always means whoever is logged in right now, so
  -- it survives an alt swap where a hard-coded Name-Realm would not. Slotted directly under the
  -- "All" sentinel (Loot History puts it in the same place) and outside the alphabetical sort. It
  -- carries NO class icon — the icons mark the real character rows, and one here would read as a
  -- seventh character in the list rather than as the sentinel it is.
  table.insert(items, 2, { value = CURRENT_CHAR, label = "Character: Current" })
  return items
end

-- Copy a multi-select set into a plain filter value: a fresh set when non-empty, else nil (no
-- filter). Copied — never aliased to the dropdown's live set — so a later toggle can't mutate the
-- filter behind the table's back.
local function setToFilter(set)
  local copy, n = {}, 0
  if type(set) == "table" then for k in pairs(set) do copy[k] = true; n = n + 1 end end
  return n > 0 and copy or nil
end

-- Same, for the Character dropdown, resolving the CURRENT_CHAR sentinel to the logged-in character's
-- key on the way out — the filter that reaches Database:QueryList only ever holds real Name-Realm
-- keys, so nothing downstream has to know the sentinel exists. Resolved at apply time, not at build
-- time, so it still means "me" after a /reload on another character. `playerKey` is injectable for
-- the tests; production passes nothing and gets the live player.
function B.ResolveCharFilter(set, playerKey)
  local copy, n = {}, 0
  if type(set) == "table" then
    for k in pairs(set) do
      if k == CURRENT_CHAR then k = playerKey or NS.Util.PlayerKey() end
      if not copy[k] then n = n + 1 end
      copy[k] = true
    end
  end
  return n > 0 and copy or nil
end

-- Push the current filter to the table and refresh the footer. The filter is a singleton for the
-- whole window: it always drives the table (keeping matchCount and the footer current on either
-- tab), and it drives the Insights charts live while Insights is the tab on screen.
local function ApplyFilter()
  -- A COPY, not the live table. Handing over B.activeFilter itself meant a later dropdown toggle
  -- mutated the filter the table was already painting under, so the table could show results for
  -- criteria that had never been applied (F-013). Insights always got a copy; both consumers now
  -- have the same guarantee.
  if NS.LedgerTable then NS.LedgerTable:SetFilter(B:CurrentFilter()) end
  B:UpdateFooter()
  if lastTab == "Insights" and NS.Insights and NS.Insights.Refresh and NS.Insights.pane then
    NS.Insights:Refresh()
  end
end

-- The immediate path, by name — what a dropdown selection and the tests use, as against the
-- debounced B:ScheduleApplyFilter the search box goes through.
function B:ApplyFilterNow()
  ApplyFilter()
end

-- Coalesce a BURST of filter edits into one recompute. Applying a filter costs a full
-- Database:Query on History and a full Database:Stats (roughly twenty sorts) on Insights, and the
-- search box fires OnTextChanged per keystroke — so typing "linen" used to pay that five times, four
-- of them for a prefix the user was already past. Same idiom as Ledger's reconcile debounce.
--
-- Only the SEARCH BOX goes through here. A dropdown selection is a single deliberate act and must
-- feel instant, so those keep calling ApplyFilter directly (C3: a debounce applied too broadly is a
-- worse experience than the cost it saves).
local FILTER_DEBOUNCE = 0.20
local pendingFilterTimer

function B:ScheduleApplyFilter()
  local addon = NS.addon
  -- No timer library (a headless run): apply inline rather than silently drop the edit.
  if not (addon and addon.ScheduleTimer) then return ApplyFilter() end
  if pendingFilterTimer and addon.CancelTimer then addon:CancelTimer(pendingFilterTimer) end
  pendingFilterTimer = addon:ScheduleTimer(function()
    pendingFilterTimer = nil
    ApplyFilter()
  end, FILTER_DEBOUNCE)
end

-- One repaint per burst of recorded entries. A reconcile pass records one entry per moved stack, so
-- emptying a 20-slot bag into the bank fans out 20 EntryAdded messages and, before this, 20 full
-- repaints of a window showing the same data each time. The ledger is fully written by the time the
-- timer runs, so the single repaint sees all of them.
local pendingRefreshTimer

function B:ScheduleLedgerRefresh()
  local addon = NS.addon
  if not (addon and addon.ScheduleTimer) then return self:OnLedgerChanged() end
  if pendingRefreshTimer then return end   -- already queued; the one pass will cover this entry too
  pendingRefreshTimer = addon:ScheduleTimer(function()
    pendingRefreshTimer = nil
    B:OnLedgerChanged()
  end, 0)
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
  dd.subtype:SetOptions(subTypeOptions())
  dd.quality:SetOptions(qualityOptions())
  dd.char:SetOptions(charOptions())
end

-- The Character filter's DEFAULT selection: the character you are on. Opening the ledger answers
-- "what did I move?" far more often than "what did all eleven of my alts move?", so the window
-- starts scoped to you and widens on demand — one step to "All", instead of everyone having to
-- narrow it every session. Test mode is the exception: its dataset is synthetic alts, so scoping
-- it to the real player would open the window on an empty table.
local function defaultCharSelection()
  if NS.LedgerTable and NS.LedgerTable:IsTestMode() then return {} end
  return { [CURRENT_CHAR] = true }
end

-- ── The view: group + sort + column filters ───────────────────────────────────
-- A "view" is everything the filter bar expresses EXCEPT the character scope: the grouping, the
-- sort, the six multi-select column filters, the date range and the search text. STOCK_VIEW is the
-- out-of-the-box baseline; the user's own baseline, once they press Save, lives account-wide in
-- NS.db.global.savedView.
--
-- Character is deliberately NOT part of a view. "What did I move?" is the question the window is
-- opened to answer far more often than "what did all my alts move?", so the scope is a per-session
-- default of Current that widens on demand — never something a stale save can pin to one alt.
--
-- Field names match the activeFilter / Database:QueryList keys, so nothing has to translate between
-- the two shapes. An empty set means "All". `date` stores the RANGE OPTION ("7d"), never a resolved
-- timestamp, so it recomputes against each session's clock instead of freezing a week in the past.
local STOCK_VIEW = {
  groupBy = "none", sortKey = "date", sortAsc = false,
  direction = {}, store = {}, quality = {}, itemType = {}, itemSubType = {},
  date = "all", search = "",
}

-- The baseline Clear returns to: the saved view when one exists, else stock. Type-checked, so a
-- SavedVariables value corrupted to a scalar degrades to stock rather than erroring on first paint.
local function savedViewOrStock()
  local v = NS.db and NS.db.global and NS.db.global.savedView
  if type(v) == "table" then return v end
  return STOCK_VIEW
end

-- Normalize a stored view field into a selection set. Tolerates a bare scalar and the "all" sentinel
-- alongside the set form — cheap insurance for a table that survives in SavedVariables across
-- versions, and it keeps a hand-edited saved view from breaking the bar.
local function asSet(v)
  local s = {}
  if type(v) == "table" then
    for k, on in pairs(v) do if on then s[k] = true end end
  elseif v ~= nil and v ~= "all" then
    s[v] = true
  end
  return s
end

-- The five multi-select column filters, as the pair of names each one goes by: the field in a view,
-- and the dropdown on the bar that holds it. ONE ordered array, read by both CaptureView and
-- ApplyView, so the two halves of the round trip can never disagree about which sets a view carries
-- — or in what order the bar is painted.
local VIEW_SETS = {
  { view = "direction",   dd = "direction" },
  { view = "store",       dd = "store" },
  { view = "quality",     dd = "quality" },
  { view = "itemType",    dd = "type" },
  { view = "itemSubType", dd = "subtype" },
}

-- The table's own share of a view — group and sort — defaulted for the build where the table module
-- is not loaded. `sortAsc` is a strict `== true`, not a truthiness pass-through.
--
-- With no table module the third return is nil, NOT false. It feeds a table constructor whose result
-- is written verbatim to SavedVariables, and a nil in a constructor leaves the KEY ABSENT from the
-- stored view — which is what master's `sortAsc = LT and LT.sortAsc == true` did. An absent key and
-- a stored `false` are different facts on disk, so the nil is load-bearing; do not tidy it to false.
local function tableViewState(LT)
  if not LT then return "none", "date", nil end
  return LT.groupBy or "none", LT.sortKey or "date", LT.sortAsc == true
end

-- Capture what is on screen as a view table. Every set is a COPY (setToFilter's fresh table), never
-- an alias of a live dropdown's set — otherwise the next toggle would silently rewrite the view the
-- user just saved, the same aliasing hazard ApplyFilter guards against (F-013).
function B:CaptureView()
  local dd, LT = self._dd, NS.LedgerTable
  local groupBy, sortKey, sortAsc = tableViewState(LT)
  local v = {
    groupBy = groupBy,
    sortKey = sortKey,
    sortAsc = sortAsc,
    date   = (dd and dd.date._value) or "all",
    search = (self._search and self._search:GetText()) or "",
  }
  for _, f in ipairs(VIEW_SETS) do
    v[f.view] = setToFilter(dd and dd[f.dd]._selected) or {}
  end
  return v
end

-- Push a view's group/sort onto the table. Guarded: a partial build can reach here without it.
local function applyTableState(view)
  if not NS.LedgerTable then return end
  NS.LedgerTable.groupBy = view.groupBy or "none"
  NS.LedgerTable.sortKey = view.sortKey or "date"
  NS.LedgerTable.sortAsc = view.sortAsc == true
end

-- Normalize a view's five column filters into selection sets, still keyed the way the view is.
local function viewSets(view)
  local s = {}
  for _, f in ipairs(VIEW_SETS) do s[f.view] = asSet(view[f.view]) end
  return s
end

-- Paint the bar itself. The character dropdown takes the session scope, not anything from the view.
local function paintDropdowns(dd, view, sets, date, chars)
  if not dd then return end
  dd.group:SelectValue(view.groupBy or "none")
  dd.date:SelectValue(date)
  for _, f in ipairs(VIEW_SETS) do dd[f.dd]:SetSelected(sets[f.view]) end
  dd.char:SetSelected(chars)
end

-- The resolved filter the table and Insights actually query with. `date == "all"` means no lower
-- bound at all (nil, never 0), and an empty search means no text clause.
local function buildActiveFilter(chars, sets, date, search)
  return {
    char        = B.ResolveCharFilter(chars),
    direction   = setToFilter(sets.direction),
    store       = setToFilter(sets.store),
    quality     = setToFilter(sets.quality),
    itemType    = setToFilter(sets.itemType),
    itemSubType = setToFilter(sets.itemSubType),
    from = (date ~= "all") and NS.Util.RangeFrom(date) or nil,
    text = (search ~= "") and search or nil,
  }
end

-- Paint a view: the table's group/sort, every dropdown, the search box and the resolved filter. The
-- character scope is not in the view — it resets to `scope` ("all" for everyone, anything else for
-- the current player). That scope write goes last and carries the single ApplyFilterNow that paints
-- everything set above it, so a view swap costs one query, not nine.
function B:ApplyView(view, scope)
  view = view or STOCK_VIEW
  local chars = (scope == "all") and {} or defaultCharSelection()
  local date   = view.date or "all"
  local search = view.search or ""

  applyTableState(view)
  local sets = viewSets(view)
  paintDropdowns(self._dd, view, sets, date, chars)
  -- Set the box before rebuilding activeFilter: OnTextChanged fires on SetText and writes
  -- activeFilter.text itself, so doing it the other way round would let the widget clobber the
  -- value we just resolved.
  if self._search then self._search:SetText(search) end

  self.activeFilter = buildActiveFilter(chars, sets, date, search)
  B:ApplyFilterNow()
end

-- Return the bar to its baseline: the saved view when there is one, else stock, always scoped to the
-- current character. This is what the Clear button, a dataset swap and the first build all use, so
-- "the view you start from" has exactly one definition.
function B:ClearFilters()
  self:ApplyView(savedViewOrStock(), "current")
end

-- Save what is on screen as the account-wide baseline. Account-wide, like the ledger itself: a bank
-- ledger is cross-character by design, so a per-alt view would fragment the one thing the addon
-- exists to join up.
function B:SaveView()
  if not (NS.db and NS.db.global) then return end
  NS.db.global.savedView = self:CaptureView()
  print("view saved as your default.")
end

-- Drop the saved baseline back to stock and apply it now. `silent` suppresses the chat line for
-- programmatic callers (Slash:CliResetAll prints its own single confirmation); the bar's Reset
-- button passes nothing and keeps the message.
function B:ResetView(silent)
  if NS.db and NS.db.global then NS.db.global.savedView = nil end
  self:ApplyView(STOCK_VIEW, "current")
  if not silent then print("view reset to stock defaults.") end
end

-- Test seams: the module-locals the view machinery is built on, exposed by name rather than
-- reconstructed in the tests, so a change to either definition is caught rather than duplicated.
B._STOCK_VIEW = STOCK_VIEW
B._savedViewOrStock = savedViewOrStock

-- The dataset changed under the bar (entering/leaving test mode): rebuild the dropdowns from the
-- new data, since the old values may not exist in it. Entering test mode opens on the STOCK view
-- across ALL characters — the test data is synthetic alts, so a saved Store/Type filter would very
-- likely match nothing and the window would look broken. Leaving it restores the saved view.
function B:OnDatasetChanged()
  self:RefreshFilterOptions()
  if NS.LedgerTable and NS.LedgerTable:IsTestMode() then
    self:ApplyView(STOCK_VIEW, "all")
  else
    self:ClearFilters()
  end
  self:UpdateFooter()
  self:UpdateDbSize()
  self:UpdateTestBadge()
  if NS.Insights and NS.Insights.Refresh then NS.Insights:Refresh() end
end

function B:UpdateTestBadge()
  if not (frame and frame.testBadge) then return end
  frame.testBadge:SetShown(NS.LedgerTable and NS.LedgerTable:IsTestMode() or false)
end

-- Draw the collection's `search` mark inside the item-name box and answer the LEFT inset the box's
-- text and placeholder should then use.
--
-- The inset is RETURNED rather than written at the call site because a nil icon has to leave the
-- box laid out exactly as it always was, and the only way that stays true is for the one decision —
-- is there a mark? — to own both numbers. Two independent spellings of "6 or 21" is how a degraded
-- install ends up with its placeholder indented around art that is not there.
--
-- Gray, matching the dropdown arrows on the same bar rather than the white the art ships as; the
-- mark is an affordance on this row, not a highlight.
local SEARCH_INSET, SEARCH_INSET_MARKED = 6, 21
local function MakeSearchMark(box)
  local path = NS.Icon and NS.Icon("search")
  if not path then return SEARCH_INSET end
  local art = box:CreateTexture(nil, "OVERLAY")
  art:SetPoint("LEFT", box, "LEFT", 5, 0)
  art:SetSize(11, 11)
  art:SetTexture(path)
  art:SetVertexColor(0.7, 0.7, 0.72)
  box.icon = art
  return SEARCH_INSET_MARKED
end

-- Build the SHARED, singleton filter bar into `bar` — a window-level host anchored once in
-- EnsureFrame, above both tab panes, so one filter drives the table AND the charts.
--   Row 1: Group by · [search…] · Clear
--   Row 2: Date · Direction · Store · Type · Character · Export
function B:BuildFilterBar(bar)
  -- No dropdown widget, no filter bar. Seven controls that open nothing is a browser that looks
  -- broken; the ledger table underneath still works, and the absence is legible.
  if not W then
    if NS.Print then NS.Print("Filters need LibKa0s. The ledger itself is unaffected.") end
    return
  end

  local ROW1, ROW2 = 0, -24
  local dd = {}
  self._dd = dd

  dd.group = self:MakeDropdown(bar, 110)
  dd.group:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, ROW1)
  dd.group:SetOptions(GROUP_OPTIONS)
  dd.group:SetValue("none", "Group: None")
  dd.group.onSelect = function(v) if NS.LedgerTable then NS.LedgerTable:SetGroupBy(v) end end

  -- Export is created here (ahead of its row-2 position) so the row-1 Clear button can anchor to
  -- it; SetPoint only needs the frame to exist, not to be positioned yet. Its own anchor (to the
  -- Character dropdown) is set at the end of the Row 2 block below.
  --
  -- It carries NO mark, and neither does anything else on this bar. Export briefly did, on the
  -- arithmetic that it was the only button wide enough: it is exportW wide (166 at the window's
  -- floor) while the Save · Reset · Clear cluster below splits exportW - 12 three ways, 51px a
  -- button, and "Clear" in GameFontHighlightSmall is most of thirty of those CENTRED pixels — a
  -- 12px mark at an 8px inset would sit under its first letter. But "the only one that fits" is not
  -- the same as "the one that should have it", and a single marked button in a row of four read as
  -- an inconsistency rather than an affordance. Words for all four.
  local exportW = B:ExportWidth()
  local exportBtn = makeBarButton(bar, "Export", exportW, function() B:OpenExport() end,
    "Export the current tab — ledger rows (History) or the summary (Insights).")
  self._exportBtn = exportBtn   -- the mark suite reads it back to prove it stayed words-only

  -- Right cluster: Save · Reset · Clear, spanning exactly exportW so its right edge sits flush above
  -- Export's and both stay static as the window widens. Three buttons + two 6px gaps = exportW:
  -- Clear and Reset each take floor((exportW - 12) / 3), Save absorbs the rounding remainder so the
  -- widths sum exactly.
  local btnW = math.floor((exportW - 12) / 3)
  local clear = makeBarButton(bar, "Clear", btnW, function() B:ClearFilters() end,
    "Return the filters, grouping and sort to your saved view "
    .. "(or the stock defaults when nothing is saved). Character goes back to Current, not All.")
  clear:SetPoint("TOPRIGHT", exportBtn, "TOPRIGHT", 0, ROW1 - ROW2)

  local resetBtn = makeBarButton(bar, "Reset", btnW, function() B:ResetView() end,
    "Discard your saved view, returning the defaults to stock.")
  resetBtn:SetPoint("RIGHT", clear, "LEFT", -6, 0)

  local saveBtn = makeBarButton(bar, "Save", exportW - 12 - 2 * btnW, function() B:SaveView() end,
    "Save the current grouping, sort and filters as your default view. "
    .. "Character scope is not saved \226\128\148 it always starts at Current.")
  saveBtn:SetPoint("RIGHT", resetBtn, "LEFT", -6, 0)

  -- Item-name search. Its LEFT sits beside Group; its RIGHT is pinned to the row-2 Character
  -- dropdown below it (set once that exists), so the two right edges stay aligned at every window
  -- width. Top-corner anchoring keeps the box in row 1 despite the row-2 reference.
  local search = CreateFrame("EditBox", nil, bar, "BackdropTemplate")
  search:SetHeight(20)
  search:SetPoint("TOPLEFT", dd.group, "TOPRIGHT", 8, 0)
  search:SetAutoFocus(false)
  search:SetFontObject("GameFontHighlightSmall")
  search:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
                       insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  search:SetBackdropColor(0.1, 0.1, 0.12, 0.9)
  search:SetBackdropBorderColor(0.24, 0.24, 0.27, 0.9)
  -- The mark goes in first because it decides where the words start. "Search items…" is unchanged
  -- and stays a sentence: the magnifier says what the box is, it does not replace what it says.
  local searchInset = MakeSearchMark(search)
  search:SetTextInsets(searchInset, 6, 0, 0)
  local ph = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ph:SetPoint("LEFT", searchInset, 0)
  ph:SetText("Search items…")
  search:SetScript("OnTextChanged", function(self2)
    local t = self2:GetText()
    ph:SetShown(t == "")
    B.activeFilter.text = (t ~= "") and t or nil
    B:ScheduleApplyFilter()
  end)
  search:SetScript("OnEscapePressed", function(self2) self2:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(self2) self2:ClearFocus() end)
  self._search = search

  -- Row 2, left→right in the same order the columns appear in the table.
  dd.date = self:MakeDropdown(bar, DD_W.date)
  dd.date:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, ROW2)
  dd.date:SetOptions(DATE_OPTIONS)
  dd.date:SetValue("all", "Date: All")
  dd.date.onSelect = function(v)
    B.activeFilter.from = (v ~= "all") and NS.Util.RangeFrom(v) or nil
    B:ApplyFilterNow()
  end

  dd.direction = self:MakeDropdown(bar, DD_W.direction)
  dd.direction:SetPoint("LEFT", dd.date, "RIGHT", DD_GAP, 0)
  dd.direction:SetMulti(true)
  dd.direction:SetOptions(directionOptions())
  dd.direction.onMultiSelect = function(set)
    B.activeFilter.direction = setToFilter(set)
    B:ApplyFilterNow()
  end

  dd.store = self:MakeDropdown(bar, DD_W.store)
  dd.store:SetPoint("LEFT", dd.direction, "RIGHT", DD_GAP, 0)
  dd.store:SetMulti(true)
  dd.store:SetOptions(storeOptions())
  dd.store.onMultiSelect = function(set)
    B.activeFilter.store = setToFilter(set)
    B:ApplyFilterNow()
  end

  dd.quality = self:MakeDropdown(bar, DD_W.quality)
  dd.quality:SetPoint("LEFT", dd.store, "RIGHT", DD_GAP, 0)
  dd.quality:SetMulti(true)
  dd.quality.onMultiSelect = function(set)
    B.activeFilter.quality = setToFilter(set)
    B:ApplyFilterNow()
  end

  dd.type = self:MakeDropdown(bar, DD_W.type)
  dd.type:SetPoint("LEFT", dd.quality, "RIGHT", DD_GAP, 0)
  dd.type:SetMulti(true)
  dd.type.onMultiSelect = function(set)
    B.activeFilter.itemType = setToFilter(set)
    B:ApplyFilterNow()
  end

  dd.subtype = self:MakeDropdown(bar, DD_W.subtype)
  dd.subtype:SetPoint("LEFT", dd.type, "RIGHT", DD_GAP, 0)
  dd.subtype:SetMulti(true)
  dd.subtype.onMultiSelect = function(set)
    B.activeFilter.itemSubType = setToFilter(set)
    B:ApplyFilterNow()
  end

  dd.char = self:MakeDropdown(bar, DD_W.char)
  dd.char:SetPoint("LEFT", dd.subtype, "RIGHT", DD_GAP, 0)
  dd.char:SetMulti(true)
  dd.char.onMultiSelect = function(set)
    B.activeFilter.char = B.ResolveCharFilter(set)
    B:ApplyFilterNow()
  end

  -- Pin the row-1 search box's right edge to the Character dropdown's; -ROW2 lifts the top-right
  -- corner from row 2 back up into row 1.
  search:SetPoint("TOPRIGHT", dd.char, "TOPRIGHT", 0, -ROW2)
  exportBtn:SetPoint("LEFT", dd.char, "RIGHT", DD_GAP, 0)
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
    B:SaveGeometry()
  end)
  frame.titleBar = titleBar

  local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("CENTER")
  title:SetText("Ka0s Bank Ledger")
  frame.title = title

  local testBadge = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  testBadge:SetPoint("LEFT", title, "RIGHT", 10, 0)
  testBadge:SetText("TEST MODE")
  testBadge:SetTextColor(1, 0.15, 0.15)
  testBadge:Hide()
  frame.testBadge = testBadge

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
  -- Options first, THEN the defaults: SetSelected repaints the collapsed label off the option list,
  -- so an empty list here would leave the Character button reading "All" while Current is applied.
  B:ClearFilters()
  B:UpdateDbSize()

  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    B:SaveGeometry()
    if NS.LedgerTable and NS.LedgerTable.Refresh then NS.LedgerTable:Refresh() end
  end)
  frame.resizeGrip = grip

  -- The single seam for the [UI] show/hide trace, so it fires once per visibility change whatever
  -- the call path. The dropdown popup itself is no longer this file's to close on hide — it is
  -- LibKa0s-Widgets-1.0's process-wide singleton now, and the library owns its own lifecycle.
  frame:HookScript("OnShow", function()
    if NS.State.debug and NS.Debug then NS.Debug("UI", "window shown") end
  end)
  frame:HookScript("OnHide", function()
    -- The save that actually carries geometry across a game session: closing the window is
    -- guaranteed to happen, where the drag/resize handlers may never have fired.
    B:SaveGeometry()
    if NS.State.debug and NS.Debug then NS.Debug("UI", "window hidden") end
  end)

  B:ApplySkin(frame)
  B:ApplyGeometry()
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
  B:UpdateTestBadge()
end

function B:Hide()
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
-- "Hide minimap button" setting writes and LibDBIcon owns — so registration alone honors the
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
  if NS.Insights and NS.Insights.Enable then NS.Insights:Enable() end
  B:SetupMinimap()

  -- A private bus target, never the shared bus-as-self: CallbackHandler keys callbacks by
  -- (message, target), so sharing one would silently clobber the Ledger's SettingsChanged handler
  -- and the Insights consumers of the same messages (architecture-§4).
  --
  -- There is deliberately NO fallback to NS.bus. A nil here means AceEvent is missing, and
  -- registering on the shared bus is exactly the receiver-clobber this factory exists to prevent —
  -- the "safety" fallback would have caused the failure it was written to avoid (F-010). Live
  -- refresh simply stays inert, as it already does in SessionWindow and Insights. The window itself,
  -- the minimap button and the tabs above still work, which is why they are set up first.
  B.__ev = NS.NewBusTarget()
  if not B.__ev then return end
  B.__ev:RegisterMessage("Ka0s_BankLedger_SettingsChanged", function() B:OnSettingsChanged() end)
  B.__ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", function() B:OnLedgerChanged() end)
  B.__ev:RegisterMessage("Ka0s_BankLedger_EntryAdded", function() B:ScheduleLedgerRefresh() end)
  -- The last belt on geometry: a /reload with the window on screen tears the frame down without
  -- running OnHide, so PLAYER_LOGOUT is the only remaining chance to write the position out.
  if B.__ev.RegisterEvent then
    B.__ev:RegisterEvent("PLAYER_LOGOUT", function() B:OnLogout() end)
  end
end
