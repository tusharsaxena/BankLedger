local addonName, NS = ...   -- luacheck: ignore addonName
NS.Panel = NS.Panel or {}
local P = NS.Panel
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

-- The LibKa0s-Options-1.0 instance, built in settings/OptionsSetup.lua, which the TOC loads just
-- above this file. Captured at file scope but never CALLED at file scope: everything below runs at
-- registration or render time, which is what lets the degraded stub be load-completing with an
-- empty member set (options-ui-§1).
--
-- AceGUI is reached through the instance's `O.AceGUI` field rather than a second LibStub call
-- (library-stack-§4). It is read at CALL time, not hoisted: the library re-resolves it at
-- CreateOptionsPanel, by which point an AceGUI absent at load may be present.
local O = NS.Helpers

-- The Ka0s settings-panel pattern (options-ui):
--   * A parent canvas category renders the LANDING PAGE — logo, one-liner, slash-command list —
--     with the same gold header every subcategory uses.
--   * Each settings group is a canvas SUBCATEGORY with a breadcrumb header
--     ("Ka0s Bank Ledger ▸ General"), a Defaults button, and a gold divider.
--   * Both settings pages are TABBED (options-ui-§13): a strip pinned in the page's chrome band,
--     one tab per subject, and the active tab's rows drawn into a TWO-COLUMN grid below it. General
--     partitions on the schema's own `group` field through O.RenderTabbedSchema; Filters has no
--     schema rows at all and drives the same O.TabStrip by hand.
--   * A tabbed page draws NO section headings — the tab is the heading.
-- The category is registered EAGERLY at load so the entry is always in the options list; each
-- body is built LAZILY on its first OnShow, because O.AceGUI lays out against the panel's current
-- width, which is 0 before the panel is first shown.
-- Every write routes through NS.Schema:Set (validate → write → onChange); reads via :Get.

local ADDON_TAGLINE =
  "Keeps a passbook of every item and every coin that moves between your bags and your banks."

-- The layout constants are the LIBRARY's now (options-ui-§8): a host copy is the copy that goes
-- stale, and five addons drifting apart is exactly what the shared table exists to stop. The three
-- a host page legitimately needs are published on the instance — O.ROW_VSPACER,
-- O.SECTION_HEADING_H, O.BUTTON_PAIR_REL — and are read from there below.
--
-- LOGO_SIZE has no library equivalent: the landing-page logo is this addon's own art.
local LOGO_SIZE = 300

local registered

-- One defaults action per page, reachable from BOTH routes — the header Defaults button and
-- Blizzard's own Settings-window footer control — and parked rather than wired, because the button
-- does not exist yet: the library builds it on the panel's first OnShow.
--
-- Only `defaultsOnClick` is set. The library's CreatePanel stamps an `OnDefault` that FORWARDS here
-- (Options minor 5), so the two routes cannot drift by construction and the host no longer has to
-- remember to set both. Setting OnDefault as well would replace that forwarder with a copy — the
-- exact duplication the forwarder removes.
local function setDefaultsAction(panel, fn)
  panel.defaultsOnClick = fn
end

-- ── createPanel — a Frame for RegisterCanvasLayout(Sub)category, plus its render context ──
-- Depth counter for P:Batch. A bulk write (a full reset walks every schema row) would otherwise pay
-- one refresh PER ROW, and one of General's refreshers walks the whole ledger to estimate the
-- SavedVariables size. Coalesced into one refresh at the end, which is also what options-ui-§11
-- describes for a global reset: the hook first, the refresh once, after.
local bulkDepth = 0

-- The host copy of "a paired action button" is GONE. It existed to inset a button to
-- O.BUTTON_PAIR_REL so the ScrollFrame clip would not shave its right border; the page's only two
-- such buttons — Purge ledger and Reset all — now go through the library's own O.InlineButtonPair,
-- which owns that inset, the pcall around a host onClick and the tooltip in one place.

-- A set-map rendered full-width as a wrapping checkbox grid. With row.invert, a CHECKED box means
-- the store is recorded (i.e. NOT in the muted set), so the stored value is the logical inverse of
-- the checkbox state.
local function makeMultiCheck(ctx, row, scroll)
  local invert = row.invert
  local group = O.AceGUI:Create("InlineGroup")
  group:SetTitle(row.label); group:SetFullWidth(true); group:SetLayout("Flow")
  local boxes = {}
  for _, opt in ipairs(row.values) do
    local cb = O.AceGUI:Create("CheckBox")
    cb:SetLabel(opt.text); cb:SetWidth(170)
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

  -- Registered AND run once, which is what every library maker does with its own refresh closure.
  -- This used to be registration alone, and it worked only because the old OnShow handler ended in
  -- a P:Refresh() that ran every refresher after the build. The library's renderer does not — a
  -- maker owns seeding its own widget — so without the call the grid drew every box unticked no
  -- matter what was stored, and only corrected itself on the next unrelated write.
  local function refresh()
    local cur = NS.Schema:Get(row.path) or {}
    for value, cb in pairs(boxes) do
      local muted = cur[value] and true or false
      cb:SetValue(invert and not muted or (not invert and muted))
    end
  end
  ctx.refreshers[#ctx.refreshers + 1] = refresh
  refresh()
end

-- ── The History tab's tail: the live storage read-out and the two destructive buttons ─────────
--
-- Drawn from the History tab's `afterGroup` hook, NOT from the page renderer. A tab click
-- re-renders the SCHEMA and nothing else (options-ui-§13: RenderTabbedSchema clears the scroll and
-- calls itself), so anything the page body drew by hand would be on the page exactly once — until
-- the player clicked another tab and came back, and then never again.
--
-- "Reset all" MOVED HERE from the right of Window scale, where the library's `pairWith` used to
-- put it. Two reasons, and the second is the one that decided it: a button that wipes the whole
-- ledger has no business one pixel from the slider a player drags to size the window; and this is
-- now the page's one destructive corner, beside Purge and under the read-out that says how much
-- there is to lose. Both stay confirm-gated — the buttons only raise a StaticPopup.
local function renderStorage(ctx)
  local scroll = O.EnsureScroll(ctx)
  if not scroll then return end
  O.AddSpacer(scroll, O.ROW_VSPACER)

  local statsLabel = O.TextRow(ctx, "")
  if not statsLabel then return end

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
  -- Parked so the bus handler below can reach the CURRENT read-out. The handler is registered once
  -- and lives for the session, while `statsLabel` is released and rebuilt on every render of this
  -- tab — a handler closing over the first one would go on writing into a released widget the
  -- moment the player clicked away and back.
  P.__storageRefresh = refreshStats

  -- Both ellipses say the same thing: the click opens a confirm dialog, it does not do the deed.
  O.InlineButtonPair(ctx,
    { text = "Purge ledger\226\128\166",
      tooltip = "Delete every recorded movement. Your settings are left alone.",
      onClick = function()
        if type(StaticPopup_Show) == "function" then StaticPopup_Show("KA0S_BANKLEDGER_PURGE")
        elseif NS.Database and NS.Database.Purge then NS.Database:Purge() end
      end },
    { text = "Reset all\226\128\166",
      tooltip = "Delete the recorded history AND return every setting, filter list and saved "
        .. "view to its default. This is the destructive form of the header's Defaults button.",
      onClick = function()
        if type(StaticPopup_Show) == "function" then
          StaticPopup_Show("KA0S_BANKLEDGER_RESETALL")
        elseif NS.Slash and NS.Slash.ResetEverything then
          NS.Slash:ResetEverything()
        end
      end })

  -- Live-refresh while the panel is open, on a private bus target (NOT NS.bus-as-self) so it can't
  -- clobber the Browser/Insights consumers of the same messages (architecture-§4).
  if not P.__ev then
    local ev = NS.NewBusTarget()
    if ev then
      local onChange = function()
        if ctx.panel:IsShown() and P.__storageRefresh then P.__storageRefresh() end
      end
      ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", onChange)
      ev:RegisterMessage("Ka0s_BankLedger_EntryAdded", onChange)
      P.__ev = ev
    end
  end
end

-- ── The Capture tab's tail: the inverted per-store grid ───────────────────────
--
-- The row declares `skipRender = true` so the flow engine walks past it; this emits the grid into
-- the same scroll, from the Capture tab's `afterGroup` hook, for the same reason renderStorage
-- hangs off History's. No library maker draws a multi-select set picker, let alone an inverted one.
local function renderStoreGrid(ctx)
  local storesRow = NS.Schema:FindRow("settings.excludedStores")
  if not storesRow then return end
  local scroll = O.EnsureScroll(ctx)
  if not scroll then return end
  makeMultiCheck(ctx, storesRow, scroll)
  O.AddSpacer(scroll, O.ROW_VSPACER)
end

-- The General page's tab hooks, by tab name. Hoisted to file scope deliberately: the library's
-- RenderRows keeps its own call-local "already fired" ledger rather than consuming the host's
-- entries, precisely so a shared table survives a second render.
local GENERAL_AFTER_TAB = {
  ["Capture"] = renderStoreGrid,
  ["History"] = renderStorage,
}

-- ── Filters sub-page: blacklist / whitelist item-id management ─────────────────

-- Display name for an id: "Name  (id)" once cached, "Item <id>" until the client caches it (a
-- background load is kicked off so a later rebuild fills the name in).
local function filterEntryLabel(id, onCached)
  local name, quality = NS.Compat.ItemNameQuality(id)
  if not name then
    if NS.Item.LoadItem then NS.Item.LoadItem(id, onCached) end
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
    local empty = O.AceGUI:Create("Label")
    empty:SetFullWidth(true)
    empty:SetText("|cff808080(none)|r")
    listGroup:AddChild(empty)
  else
    for _, id in ipairs(ids) do
      local rowG = O.AceGUI:Create("SimpleGroup")
      rowG:SetLayout("Flow"); rowG:SetFullWidth(true)
      local lbl = O.AceGUI:Create("Label")
      lbl:SetRelativeWidth(0.78)
      lbl:SetText(filterEntryLabel(id, function()
        if ctx.panel:IsShown() then rebuildFilterList(ctx, listGroup, listKey) end
      end))
      rowG:AddChild(lbl)
      local rm = O.AceGUI:Create("Button")
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

-- One list (blacklist or whitelist): description, add-row, bulk clear, live list.
--
-- It draws NO heading. It used to, because both lists were stacked down one scroll and the heading
-- was the only thing telling them apart; the page is a tab strip now and the tab IS the heading, so
-- a "Blacklist" heading under a tab labelled Blacklist would say the word twice — which is the same
-- rule the library applies to a tabbed schema page (RenderRows' `noHeadings`).
local function makeFilterSection(ctx, listKey, desc)
  local scroll = O.EnsureScroll(ctx)

  local descLabel = O.AceGUI:Create("Label")
  descLabel:SetFullWidth(true); descLabel:SetText(desc)
  scroll:AddChild(descLabel)
  O.AddSpacer(scroll, 6)

  local listGroup = O.AceGUI:Create("SimpleGroup")
  listGroup:SetLayout("List"); listGroup:SetFullWidth(true)

  local addRow = O.AceGUI:Create("SimpleGroup")
  addRow:SetLayout("Flow"); addRow:SetFullWidth(true)
  local box = O.AceGUI:Create("EditBox")
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
  local addBtn = O.AceGUI:Create("Button")
  addBtn:SetText("Add"); addBtn:SetRelativeWidth(0.20)
  addBtn:SetCallback("OnClick", submit)
  addRow:AddChild(addBtn)
  scroll:AddChild(addRow)
  O.AddSpacer(scroll, 4)

  local clearRow = O.AceGUI:Create("SimpleGroup")
  clearRow:SetLayout("Flow"); clearRow:SetFullWidth(true)
  local clearBtn = O.AceGUI:Create("Button")
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
  O.AddSpacer(scroll, 4)

  scroll:AddChild(listGroup)

  -- Painted as part of the page render rather than through a separate rebuilder tier. The library's
  -- registry now owns that distinction: a scalar write runs refreshers (RefreshScalars), a
  -- structural change re-runs the whole renderer (RefreshAllPanels), and both skip a page that is
  -- not on screen and mark it dirty instead. The id lists are structural, so their bus handler
  -- calls RefreshAllPanels and this simply draws whatever the list holds right now.
  rebuildFilterList(ctx, listGroup, listKey)
end

-- The Filters strip. Two lists, two tabs, in the order the capture gate consults them: an item is
-- refused by the blacklist first, and the whitelist is the exception that overrides the quality
-- gate afterwards.
--
-- Hand-driven rather than through H.RenderTabbedSchema, because that function partitions SCHEMA
-- ROWS by `group` and this page has none — both lists are storage carve-outs mutated through
-- NS.Filters, not settings with paths. So the page calls the same H.TabStrip underneath it, keeps
-- the active tab in the same `ctx.activeTab` the library uses, and re-renders on select exactly the
-- way RenderTabbedSchema does. What it must NOT do is invent a second piece of state for which tab
-- is showing: the library's refresh path reads ctx.activeTab, and a private copy would go stale the
-- first time a page was marked dirty while hidden.
local FILTER_TABS = {
  { key = "blacklist", label = "Blacklist",
    tooltip = "Items that are never recorded, whatever their quality." },
  { key = "whitelist", label = "Whitelist",
    tooltip = "Items that are always recorded, even below your minimum quality." },
}

local FILTER_DESC = {
  blacklist = "Items here are never recorded when they move from now on. Existing rows are left "
    .. "untouched (this only affects future movements \226\128\148 delete old rows from the ledger table "
    .. "if you want them gone).",
  whitelist = "Items here are always recorded, even when they fall below your minimum quality. "
    .. "Adding an id to one list removes it from the other.",
}

local function buildFilters(ctx)
  -- A stale pointer heals to the first tab rather than being trusted — the same self-repair the
  -- library does, and for the same reason: the alternative is a page that is blank until the user
  -- clicks something.
  if not FILTER_DESC[ctx.activeTab] then ctx.activeTab = FILTER_TABS[1].key end

  O.TabStrip(ctx, {
    tabs  = FILTER_TABS,
    value = ctx.activeTab,
    onSelect = function(key)
      if key == ctx.activeTab then return end
      ctx.activeTab = key
      O.ClearScroll(ctx)
      buildFilters(ctx)
      if ctx.scroll and ctx.scroll.DoLayout then ctx.scroll:DoLayout() end
    end,
  })

  makeFilterSection(ctx, ctx.activeTab, FILTER_DESC[ctx.activeTab])

  -- Live-update both lists when they change from elsewhere (the ledger table's right-click menu),
  -- on a private bus target. While the page is on screen we repaint immediately; while it is hidden
  -- we only flag it dirty, so the next OnShow repaints once instead of every tab click paying an
  -- O.AceGUI teardown+rebuild (options-ui-§11).
  if not P.__evFilters then
    local ev = NS.NewBusTarget()
    if ev then
      -- A list change is STRUCTURAL — rows appear and disappear — so it is a re-render rather
      -- than a scalar refresh. RefreshAllPanels re-runs each page's renderer, and the library
      -- already does the on-screen / mark-dirty split this used to do by hand: a hidden page is
      -- flagged and repaints once on its next show, instead of every tab click paying an AceGUI
      -- teardown (options-ui-§11).
      ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", function() O.RefreshAllPanels() end)
      P.__evFilters = ev
    end
  end
end

-- ── Landing page: logo + tagline + slash-command list (options-ui-§5) ───────────
local function buildMainContent(ctx)
  local scroll = O.EnsureScroll(ctx)

  local logoGroup = O.AceGUI:Create("SimpleGroup")
  logoGroup:SetLayout(nil); logoGroup:SetFullWidth(true); logoGroup:SetHeight(LOGO_SIZE)
  local tex = logoGroup.frame:CreateTexture(nil, "ARTWORK")
  tex:SetTexture(NS.Constants.LOGO_PATH)
  tex:SetSize(LOGO_SIZE, LOGO_SIZE)
  tex:SetPoint("TOPLEFT", logoGroup.frame, "TOPLEFT", 0, 0)
  scroll:AddChild(logoGroup)
  O.AddSpacer(scroll, 8)

  local desc = O.AceGUI:Create("Label")
  desc:SetFullWidth(true); desc:SetText(ADDON_TAGLINE)
  if desc.label and desc.label.SetFontObject and _G.GameFontHighlight then
    desc.label:SetFontObject(_G.GameFontHighlight)
  end
  scroll:AddChild(desc)
  O.AddSpacer(scroll, 12)

  local heading = O.AceGUI:Create("Heading")
  heading:SetFullWidth(true); heading:SetHeight(O.SECTION_HEADING_H); heading:SetText("Slash Commands")
  if heading.label and heading.label.SetFontObject and _G.GameFontNormalLarge then
    heading.label:SetFontObject(_G.GameFontNormalLarge)
  end
  scroll:AddChild(heading)
  O.AddSpacer(scroll, 6)

  -- Rendered through NS.Slash:LandingRows(), which is LibKa0s-Slash-1.0's ONE command-row
  -- formatter — the same one `/bl help` uses, un-indented because here each row is its own
  -- label (options-ui-§5, slash-commands-§4).
  --
  -- This page used to carry a SECOND formatter for the same data: doubled spaces around an em
  -- dash that was explicitly wrapped white, with the description left bare. Two renderers for
  -- one table in one repo drift the moment either is touched, and this one had already drifted
  -- from the chat help. Collapsing them is a deliberate, user-visible convergence — the spacing
  -- tightens, the dash loses its color span and the description gains one. Recorded in
  -- this repo's GitHub issues rather than left to look like an accident.
  for _, row in ipairs((NS.Slash and NS.Slash.LandingRows and NS.Slash:LandingRows()) or {}) do
    local labelRow = O.AceGUI:Create("Label")
    labelRow:SetFullWidth(true)
    labelRow:SetText(row)
    scroll:AddChild(labelRow)
  end
end

-- ── Diagnostics ────────────────────────────────────────────────────────────────
-- `/bl debug panel` — a structured dump of what the header's Defaults button ACTUALLY is at
-- runtime (debug-logging-§4, the same shape as Ledger:Diagnose). Kept because it is the tool that
-- found the load-order skinning race (see ensureDefaultsButton): a widget's region list is what
-- distinguishes "stock Blizzard art" from "restyled by a UI skin", and that is invisible in code.
-- A skinned button carries extra BORDER/BACKGROUND regions; an unskinned one is the bare 5-region
-- UI-Panel-Button-Up (fileID 130828 — the red stone button).
-- Every reporter below takes the `add` sink as its first argument, because the sink is the one thing
-- that genuinely has to be built per call (it captures the `out` array). Everything else is a
-- file-local, and every accessor stays guarded — this runs precisely when the widget is broken.

-- One texture's art — an atlas name or a texture path is the direct answer to "why is it red".
local function describeTexture(add, tex, label)
  if not tex then add("%s: none", label); return end
  local atlas = tex.GetAtlas and tex:GetAtlas()
  local path = tex.GetTexture and tex:GetTexture()
  local r, g, b, a = 1, 1, 1, 1
  if tex.GetVertexColor then r, g, b, a = tex:GetVertexColor() end
  add("%s: atlas=%s texture=%s vertex=%.2f/%.2f/%.2f/%.2f",
    label, tostring(atlas), tostring(path), r or 1, g or 1, b or 1, a or 1)
end

-- A modern UIPanelButtonTemplate draws its face from CHILD REGIONS (a 3-slice or a NineSlice),
-- not from a NormalTexture — so "normal: none" means the color is in one of these.
local function dumpRegions(add, frame, tag)
  if not frame.GetRegions then return end
  local n = select("#", frame:GetRegions())
  add("%s: %d regions", tag, n)
  for i = 1, n do
    local reg = select(i, frame:GetRegions())
    if reg and reg.GetObjectType and reg:GetObjectType() == "Texture" then
      describeTexture(add, reg, ("  %s[%d] %s"):format(tag, i, tostring(reg:GetDrawLayer())))
    end
  end
  -- The NineSlice is a child FRAME, so it is not in GetRegions.
  if frame.NineSlice then dumpRegions(add, frame.NineSlice, tag .. ".NineSlice") end
end

-- Which O.AceGUI actually served the widget: with several addons loaded, the FIRST copy to load
-- wins for all of them, so this may not be the copy this addon vendors.
local function reportAceGUI(add)
  -- The registered major is `AceGUI-3.0`. The key is NOT reached through the O.AceGUI instance:
  -- LibStub.minors is keyed by the MAJOR STRING, and a v2.17.1 dialect sweep had rewritten this
  -- one to "O.AceGUI-3.0", a name nothing has ever registered, so the line always printed nil.
  local minor = LibStub and LibStub.minors and LibStub.minors["AceGUI-3.0"]
  add("AceGUI=%s minor=%s", O.AceGUI and "yes" or "NO", tostring(minor))
  if O.AceGUI then
    local wv = O.AceGUI.WidgetVersions and O.AceGUI.WidgetVersions["Button"]
    add("Button widget registered=%s version=%s",
      (O.AceGUI.WidgetRegistry and O.AceGUI.WidgetRegistry["Button"]) and "yes" or "NO", tostring(wv))
  end
end

-- What the frame is, and the parent chain — which proves whether it really ended up on our canvas
-- panel. The chain stays capped at depth 6.
local function reportFrame(add, f)
  add("frame objectType=%s shown=%s size=%.0fx%.0f",
    f.GetObjectType and f:GetObjectType() or "?", tostring(f:IsShown()),
    f:GetWidth() or 0, f:GetHeight() or 0)

  local chain, node, depth = {}, f:GetParent(), 0
  while node and depth < 6 do
    chain[#chain + 1] = (node.GetName and node:GetName()) or
      ((node.GetObjectType and node:GetObjectType() or "?") .. "(anon)")
    node = node.GetParent and node:GetParent()
    depth = depth + 1
  end
  add("parent chain: %s", table.concat(chain, " < "))
end

-- The button's whole art: the three state textures, the full region tree, and the label.
local function reportArt(add, f)
  describeTexture(add, f.GetNormalTexture and f:GetNormalTexture(), "normal")
  describeTexture(add, f.GetHighlightTexture and f:GetHighlightTexture(), "highlight")
  describeTexture(add, f.GetPushedTexture and f:GetPushedTexture(), "pushed")
  dumpRegions(add, f, "btn")

  local fs = f.GetFontString and f:GetFontString()
  if fs then
    local r, g, b = fs:GetTextColor()
    add("label=%q color=%.2f/%.2f/%.2f", tostring(fs:GetText()), r or 0, g or 0, b or 0)
  end
end

function P:Diagnose()
  local out = {}
  local function add(fmt, ...)
    out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
  end

  reportAceGUI(add)

  local btn = P.general and P.general.panel and P.general.panel.defaultsBtn
  if not btn then
    add("defaultsBtn=NIL \226\128\148 no button was built; anything on screen is not ours")
    return out
  end
  add("defaultsBtn type=%s aceType=%s", type(btn), tostring(btn.type))

  local f = btn.frame
  if not f then add("defaultsBtn.frame=NIL"); return out end
  reportFrame(add, f)
  reportArt(add, f)
  return out
end

-- ── Refresh / Defaults ─────────────────────────────────────────────────────────

-- Test seam over the library's page registry. The page bodies are lazy, so a suite otherwise has no
-- handle on a live ctx — and a refresh path no case could reach is how this one shipped walking a
-- single page for so long.
function P.__pagesForTest() return O.__panels and O.__panels() or {} end

-- Scalar re-sync only: run each rendered widget's updater closure. Structural rebuilds are the
-- rebuilders' job and are gated separately (options-ui-§11).
function P:Refresh()
  if bulkDepth > 0 then return end
  -- Delegated. The library keeps the registry now, and its refreshCtx already does the two things
  -- this function used to do by hand: skip a page that is not on screen (the Blizzard window shows
  -- one subcategory at a time, and one of General's refreshers walks the whole ledger to estimate
  -- the SavedVariables size — F-018), and mark a hidden page dirty so it repaints once on its next
  -- show instead of on every tab click.
  --
  -- SCALAR, not structural: writing a value does not change which rows exist. The Filters page's
  -- id-lists DO change shape, and their bus handler calls RefreshAllPanels instead.
  if O.RefreshScalars then O.RefreshScalars() end
end

--- Run `fn` with panel refreshes coalesced into exactly ONE, at the end.
---
--- For a bulk write — a full reset walks every schema row, and every one of those goes through the
--- write seam. Without this the ledger gets walked once per row while the General page is open.
--- Re-entrant, and the depth is unwound on the error path too: latched above zero, the panel would
--- silently stop refreshing for the rest of the session.
function P:Batch(fn)
  bulkDepth = bulkDepth + 1
  local ok, err = pcall(fn)
  bulkDepth = bulkDepth - 1
  if bulkDepth == 0 then P:Refresh() end
  if not ok then error(err, 0) end
end

function P:RestoreDefaults()
  if NS.Slash and NS.Slash.CliResetAll then NS.Slash:CliResetAll() end
  -- CliResetAll already batches its own row walk; this call is what repaints after the two window
  -- resets below, which are not schema writes and so never reach the write seam.
  -- Defaults also recenters both windows (position is part of the stock state); the ledger is left alone.
  if NS.Browser and NS.Browser.ResetWindow then NS.Browser:ResetWindow() end
  if NS.SessionWindow and NS.SessionWindow.ResetWindow then NS.SessionWindow:ResetWindow() end
  P:Refresh()
end

-- ── Registration ───────────────────────────────────────────────────────────────
--
-- Three pages, two of them tabbed. The library owns the shell and the TIMING of every body — first show, and again
-- after a refresh marked the page dirty while it was hidden, because those are the two moments only
-- its registry can see. It builds each page's Defaults button on that first show (the O.AceGUI
-- skinning race) and refuses to render under combat while closing the Settings window, which is a
-- guard this addon previously had only on the `/bl config` route and not on the Blizzard AddOns
-- sidebar.
--
-- Every renderer starts with O.ClearScroll. A re-render releases the previous widgets and, with
-- them, the refresher closures that captured them; keeping those would pcall an ever-growing pile
-- of dead closures on every later write (options-ui-§11).

function P:Register()
  if registered then return end
  registered = true

  -- The landing page's body. Handed over rather than registered as a page: it belongs to the parent
  -- category, which the library creates itself from the descriptor's `mainPanelName`.
  O.SetMainBuilder(function(ctx)
    O.ClearScroll(ctx)
    buildMainContent(ctx)
    if ctx.scroll and ctx.scroll.DoLayout then ctx.scroll:DoLayout() end
  end)

  -- General = every schema row, on three tabs: Capture (what is recorded, with the store grid
  -- hanging off it), Interface (what is on screen) and History (how much is kept, plus the storage
  -- read-out and the two destructive buttons). Both bespoke blocks are afterGroup hooks, because a
  -- tab click re-renders the schema alone.
  O.RegisterOptionsPage("general", "General", function(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return end
    local ctx = O.CreatePanel("BankLedgerGeneralPanel", "General", {
      pageKey = "general",
      defaultsButton = true,
      -- Names the window resets too: P:RestoreDefaults calls BOTH ResetWindow()s, which clear the
      -- stored geometry of the ledger and session windows (a storage carve-out, not a schema row)
      -- and recenter them. A tooltip that promised only "every setting" understated the button.
      defaultsTooltip = "Restore every Bank Ledger setting to its default, and recentre the "
        .. "ledger and session windows at their default size. Your recorded history is never "
        .. "touched.",
    })
    P.general = ctx
    -- Non-destructive on both routes, so it is safe behind Blizzard's own un-gated footer control.
    -- The destructive path stays behind the confirm-gated KA0S_BANKLEDGER_RESETALL popup.
    setDefaultsAction(ctx.panel, function() P:RestoreDefaults() end)

    -- ONE LINE of adoption (options-ui-§13). The schema's `group` field already declared the
    -- sections; RenderTabbedSchema partitions on it in declaration order and pins a tab strip in
    -- the page's chrome band instead of stacking three headed sections down one scroll. Both
    -- bespoke blocks moved into GENERAL_AFTER_TAB above, because a tab click re-renders only what
    -- this call draws.
    O.SetRenderer(ctx, function(c)
      O.ClearScroll(c)
      O.RenderTabbedSchema(c, "general", GENERAL_AFTER_TAB)
      if c.scroll and c.scroll.DoLayout then c.scroll:DoLayout() end
    end)

    Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, "General")
  end)

  -- Filters = blacklist / whitelist item-id management, one list per tab. No schema rows at all, so
  -- the whole body is host-drawn — but into the library's scroll, under the library's own tab strip,
  -- through its spacers.
  O.RegisterOptionsPage("filters", "Filters", function(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return end
    local ctx = O.CreatePanel("BankLedgerFiltersPanel", "Filters", {
      pageKey = "filters",
      defaultsButton = true,
      defaultsTooltip = "Clear the item blacklist and whitelist. Your recorded history is never "
        .. "touched.",
    })
    P.filters = ctx
    -- Defaults here = clear both id-lists, whose stock state is empty. The page holds no Schema
    -- rows, so this is what "restore defaults" means for what it manages.
    setDefaultsAction(ctx.panel, function()
      if type(StaticPopup_Show) == "function" then
        StaticPopup_Show("KA0S_BANKLEDGER_CLEAR_FILTERS")
      elseif NS.Filters then
        NS.Filters:ClearAll()
      end
    end)

    O.SetRenderer(ctx, function(c)
      O.ClearScroll(c)
      buildFilters(c)
      if c.scroll and c.scroll.DoLayout then c.scroll:DoLayout() end
    end)

    Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, "Filters")
  end)

  O.CreateOptionsPanel()
end

function P:Open()
  -- options-ui-§2: REFUSE in combat. The library's OpenOptionsPanel carries the same refusal and
  -- the same reasoning (never defer-and-replay: a panel that pops itself open the instant combat
  -- drops steals focus during post-pull recovery), so this delegates rather than duplicating it.
  O.OpenOptionsPanel()
end
