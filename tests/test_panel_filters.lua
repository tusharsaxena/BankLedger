-- tests/test_panel_filters.lua — the settings panel's **Filters tab**: its secondary strip, the id
-- list (LibKa0s-Options IdList) and the suggestion path.
--
-- Peeled out of tests/test_panel.lua, which had reached 1580 lines against layout-§1's 1500-line
-- cap. The seam is the largest block in that file answering one question, and the same seam Ka0s
-- Loot History's panel suite was cut at — the two addons draw the same strip, so a reader who knows
-- one finds the other where they expect it. Not one assertion changed in the move.
--
-- The helpers this block shares with the rest of the panel suite live in tests/panel_support.lua;
-- the ones only the Filters cases use came across with them.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = dofile("tests/panel_support.lua")
local AceGUI          = S.AceGUI
local panel           = S.panel
local ctxFor          = S.ctxFor
local renderPage      = S.renderPage
local renderTab       = S.renderTab
local GENERAL_TABS    = S.GENERAL_TABS
local FILTER_SUB_TABS = S.FILTER_SUB_TABS
local widgetLabeled   = S.widgetLabeled

-- ── the Filters tab's secondary strip (options-ui-§13) ─────────────────────────
--
-- Two id-lists are a list of like subjects inside one category, which is what a secondary strip is
-- for -- drawn inside the scroll as ordinary content, with its selection in ctx.activeSubTab keyed
-- by the PRIMARY tab's name. Session state, never persisted.
--
-- Dies under: promoting the lists back to two primary tabs, or keying the sub-selection off
-- ctx.activeTab (which a click on another primary tab would then overwrite).
test("Panel: the Filters tab draws a SECONDARY strip and renders only the selected list", function()
  local c = ctxFor("General")
  c.activeSubTab = nil
  local made = renderTab("General", "Filters")
  assertTrue(c.__subTabKids ~= nil and #c.__subTabKids == #FILTER_SUB_TABS,
    "one sub-tab per list")
  assertEqual(c.activeSubTab["Filters"], FILTER_SUB_TABS[1],
    "the sub-strip opens on the first list")

  -- One add-row, not two: the tab draws the selected list and nothing else.
  local boxes = 0
  for _, w in ipairs(made) do if w.type == "EditBox" then boxes = boxes + 1 end end
  assertEqual(boxes, 1, "exactly one add-row is on screen")

  c.__subTabKids[2]:__fire("OnClick")
  assertEqual(c.activeSubTab["Filters"], FILTER_SUB_TABS[2], "sub-tab 2 is the whitelist")
  c.activeSubTab = nil
  c.activeTab = GENERAL_TABS[1]
end)

-- ── the Filters tab's id list (LibKa0s-Options IdList, v1.35.0) ──────────────────────────────
--
-- Each list is ONE O.IdList with kind = "item" now: the box resolves a number, a shift-clicked link
-- or an item's NAME through O.ResolveId, and the entry lines are the library's. The host keeps the
-- storage. Every add and remove goes through NS.Filters' own writers, so F:_move still keeps the two
-- lists exclusive and db.global.{blacklist,whitelist} keep their [itemID] = true shape. The names
-- come from the kit's opt-in id lookups, which tests/wow_mock.lua installs (override 13).

-- The ledger a Filters case replaced, boxed so a nil one comes back as nil; leaveFilters restores it.
local savedLedger

--- Open Filters on `listKey` with the two lists seeded as given, and the ledger holding `ledgerRows`
--- (empty when omitted); hand back what the tab drew. The ledger is set every time because the
--- lists' add box takes its name candidates from it: rows left behind by another suite would be
--- unnamed ids, and a typed name waits on a lookup while any candidate is unnamed.
local function filtersTab(listKey, black, white, ledgerRows)
  NS.db.global.blacklist = black or {}
  NS.db.global.whitelist = white or {}
  if savedLedger == nil then savedLedger = { NS.db.global.ledger } end
  NS.db.global.ledger = ledgerRows or {}
  local c = ctxFor("General")
  c.activeSubTab = { Filters = listKey }
  return renderTab("General", "Filters"), c
end

--- The first drawn widget of `wtype`, optionally one whose text contains `part`.
local function firstOf(made, wtype, part)
  for _, w in ipairs(made) do
    if w.type == wtype and (part == nil
        or (type(w.text) == "string" and w.text:find(part, 1, true) ~= nil)) then
      return w
    end
  end
  return nil
end

--- Spy on one NS.Filters writer for the length of `fn`, still calling through to the real one.
local function spyWriter(name, fn)
  local real, calls = NS.Filters[name], {}
  NS.Filters[name] = function(self, id) calls[#calls + 1] = id; return real(self, id) end
  local ok, err = pcall(fn)
  NS.Filters[name] = real
  if not ok then error(err, 0) end
  return calls
end

local function typeInto(made, text)
  local box = firstOf(made, "EditBox")
  assertTrue(box ~= nil, "the Filters tab has no add box")
  box:__fire("OnEnterPressed", text)
end

local function leaveFilters(c)
  NS.db.global.blacklist, NS.db.global.whitelist = {}, {}
  if savedLedger then NS.db.global.ledger = savedLedger[1] end
  savedLedger = nil
  c.activeSubTab = nil
  c.activeTab = GENERAL_TABS[1]
end

test("Filters tab: an item id typed into the box goes through Filters:AddBlacklist", function()
  -- red under: onAdd writing db.global.blacklist directly (the spy sees nothing), or not wired.
  local made, c = filtersTab("blacklist")
  local calls = spyWriter("AddBlacklist", function() typeInto(made, "2589") end)
  assertEqual(#calls, 1, "one add, one writer call")
  assertEqual(calls[1], 2589)
  -- The stored shape is unchanged: a number key, the value true, and nothing else in the set.
  local keys = 0
  for k, v in pairs(NS.db.global.blacklist) do
    keys = keys + 1
    assertEqual(type(k), "number", "keyed by the numeric item id")
    assertEqual(v, true, "stored as [itemID] = true")
  end
  assertEqual(keys, 1, "exactly the one id")
  leaveFilters(c)
end)

test("Filters tab: a shift-clicked item link adds the id inside it", function()
  -- red under: a kind other than "item" (a link of another type resolves to nothing).
  local made, c = filtersTab("blacklist")
  local link = "|cffffffff|Hitem:4306::::::::::|h[Silk Cloth]|h|r"
  local calls = spyWriter("AddBlacklist", function() typeInto(made, link) end)
  assertEqual(calls[1], 4306)
  leaveFilters(c)
end)

test("Filters tab: an item typed by NAME resolves to its id, whatever its case", function()
  -- The new capability: the old box took a number or a link and nothing else.
  -- red under: kind omitted (the id-only kind resolves no name), or the old id-or-link submit.
  local made, c = filtersTab("blacklist")
  local calls = spyWriter("AddBlacklist", function() typeInto(made, "linen cloth") end)
  assertEqual(calls[1], 2589)
  leaveFilters(c)
end)

test("Filters tab: input that names no item adds nothing and says why on the tab", function()
  -- red under: kind omitted (the id-only kind's reason reads "No entry named"), or the old editor's
  -- submit, which reported a bad input only as a chat line.
  local made, c = filtersTab("blacklist")
  local calls = spyWriter("AddBlacklist", function() typeInto(made, "Nonesuch Blade") end)
  assertEqual(#calls, 0, "nothing reaches the writer")
  assertEqual(next(NS.db.global.blacklist), nil, "the list is untouched")
  assertTrue(firstOf(made, "Label", "No item named 'Nonesuch Blade'") ~= nil,
    "the reason is shown under the box")
  leaveFilters(c)
end)

test("Filters tab: an entry draws an X on the left (removeStyle = \"icon\", LibKa0s v1.44.0)", function()
  -- red under: removeStyle omitted from the O.IdList spec (the library draws the old right-hand
  -- Remove button instead), or the library drawing the X with the wrong atlas.
  local made, c = filtersTab("blacklist", { [2589] = true })
  local x = firstOf(made, "Icon")
  assertTrue(x ~= nil, "the entry has an X icon")
  assertEqual(x.__removeAtlas, "transmog-icon-remove", "the X wears the library's remove atlas")
  assertTrue(firstOf(made, "Button", "Remove") == nil, "no right-hand Remove button is drawn")
  leaveFilters(c)
end)

test("Filters tab: an entry's X goes through Filters:RemoveBlacklist", function()
  -- red under: onRemove not wired, or pointed at the other list's writer.
  local made, c = filtersTab("blacklist", { [2589] = true })
  local rm = firstOf(made, "Icon")
  assertTrue(rm ~= nil, "the entry has an X icon")
  local calls = spyWriter("RemoveBlacklist", function() rm:__fire("OnClick") end)
  assertEqual(calls[1], 2589)
  assertEqual(next(NS.db.global.blacklist), nil, "the id is gone from the store")
  leaveFilters(c)
end)

test("Filters tab: adding on Whitelist takes the id off Blacklist (Filters:_move, unchanged)", function()
  -- red under: the Whitelist tab's onAdd calling AddBlacklist, or writing the store directly.
  local made, c = filtersTab("whitelist", { [2589] = true })
  local calls = spyWriter("AddWhitelist", function() typeInto(made, "2589") end)
  assertEqual(calls[1], 2589)
  assertTrue(NS.db.global.whitelist[2589] == true, "now on the whitelist")
  assertTrue(NS.db.global.blacklist[2589] == nil, "and off the blacklist")
  leaveFilters(c)
end)

test("Filters tab: an entry reads its item name and id; an empty list reads (none)", function()
  -- red under: dropping kind = "item" (the line reads "Unknown entry 2589"), or dropping emptyText.
  local made, c = filtersTab("blacklist", { [2589] = true })
  local line = firstOf(made, "InteractiveLabel", "Linen Cloth")
  assertTrue(line ~= nil and line.text:find("(2589)", 1, true) ~= nil, "name and id on the line")
  made = filtersTab("blacklist")
  assertTrue(firstOf(made, "Label", "(none)") ~= nil, "the empty list says so")
  assertTrue(firstOf(made, "Button", "Clear all") ~= nil, "Clear all stays the host's button")
  leaveFilters(c)
end)

test("Filters tab: an uncached item is asked for, and the list redraws when it lands", function()
  -- red under: kind omitted (the id-only kind neither names an item nor loads one), or the old
  -- editor's label, which read "Item <id>" and redrew only its own group.
  mocks.addIdRecord("item", 99001, "Gilded Trinket", 134400, true)
  local landed
  local savedAfter, savedRefresh = mocks.C_Timer.After, NS.Helpers.RefreshAllPanels
  mocks.C_Timer.After = function(_, cb) landed = cb end
  local ok, made, c = pcall(filtersTab, "blacklist", { [99001] = true })
  mocks.C_Timer.After = savedAfter
  if not ok then error(made, 0) end
  assertTrue(firstOf(made, "InteractiveLabel", "Unknown item 99001") ~= nil, "unnamed until cached")
  assertTrue(mocks.__loadRequests[99001] == true, "the client was asked to load it")
  assertTrue(type(landed) == "function", "a load callback is waiting")

  -- The redraw is this page's own (ctx.rebuild -> O.RefreshPanel on this ctx), not a sweep.
  local redraws = 0
  NS.Helpers.RefreshPanel = function(ctx, structural)
    if ctx == c and structural then redraws = redraws + 1 end
  end
  mocks.addIdRecord("item", 99001, "Gilded Trinket", 134400)
  local ran, err = pcall(landed)
  NS.Helpers.RefreshPanel = savedRefresh
  if not ran then error(err, 0) end
  assertEqual(redraws, 1, "the load landing redraws the list")
  made = filtersTab("blacklist", { [99001] = true })
  assertTrue(firstOf(made, "InteractiveLabel", "Gilded Trinket") ~= nil, "named once cached")
  mocks.__idRecords.item[99001] = nil
  leaveFilters(c)
end)

test("Filters tab: several uncached items cost one load check and one redraw", function()
  -- LibKa0s v1.35.0 (re-cut) batches a render's asks: the first id carries the callback, the rest
  -- only ask, so a blacklist of uncached items repaints the page once, not once per item.
  -- red under: the pre-re-cut widget, which armed one callback per id and redrew on each.
  mocks.addIdRecord("item", 99003, "Gilded Trinket", 134400, true)
  mocks.addIdRecord("item", 99004, "Tarnished Locket", 134400, true)
  local pending = {}
  local savedAfter, savedRefresh = mocks.C_Timer.After, NS.Helpers.RefreshPanel
  mocks.C_Timer.After = function(_, cb) pending[#pending + 1] = cb end
  local ok, made, c = pcall(filtersTab, "blacklist", { [99003] = true, [99004] = true })
  mocks.C_Timer.After = savedAfter
  if not ok then error(made, 0) end
  assertTrue(mocks.__loadRequests[99003] == true and mocks.__loadRequests[99004] == true,
    "both items were asked for")
  assertEqual(#pending, 1, "one load check for the whole render")

  local redraws = 0
  NS.Helpers.RefreshPanel = function(ctx, structural)
    if ctx == c and structural then redraws = redraws + 1 end
  end
  mocks.addIdRecord("item", 99003, "Gilded Trinket", 134400)
  mocks.addIdRecord("item", 99004, "Tarnished Locket", 134400)
  local ran, err = pcall(function() for _, cb in ipairs(pending) do cb() end end)
  NS.Helpers.RefreshPanel = savedRefresh
  if not ran then error(err, 0) end
  assertEqual(redraws, 1, "both loads landing redraw the list once")
  mocks.__idRecords.item[99003], mocks.__idRecords.item[99004] = nil, nil
  leaveFilters(c)
end)

--- How many EditBoxes `fn` created with the General page ON SCREEN: one per repaint of the Filters
--- tab, which draws exactly one. Firing OnShow draws the page but never marks it shown, and a hidden
--- page is only flagged dirty by a refresh, so without the Show the repaints this counts never run.
local function editBoxesMadeBy(fn)
  local frame = panel("General")
  local wasShown = frame:IsShown()
  frame:Show()
  local before = #AceGUI.__created
  local ok, err = pcall(fn)
  if not wasShown then frame:Hide() end
  if not ok then error(err, 0) end
  local boxes = 0
  for i = before + 1, #AceGUI.__created do
    if AceGUI.__created[i].type == "EditBox" then boxes = boxes + 1 end
  end
  return boxes
end

test("Filters tab: one add redraws the page once, not twice", function()
  -- The writer fires LedgerChanged synchronously and the page's own listener repaints on it; the
  -- widget then asks for its own redraw. Two full repaints per click is the anti-pattern #39 cost.
  -- (Since the v1.35.0 re-cut the widget clears the box and the status line BEFORE onAdd, so an
  -- onAdd that repaints no longer races the pool; the double repaint is still the waste.)
  -- red under: dropping the write guard that holds the LedgerChanged repaint off during an add.
  local made, c = filtersTab("blacklist")
  local boxes = editBoxesMadeBy(function() typeInto(made, "2589") end)
  assertEqual(boxes, 1, "exactly one repaint follows one add")
  assertTrue(NS.db.global.blacklist[2589] == true, "the add landed")
  leaveFilters(c)
end)

test("Filters tab: one X-click redraws the page once, not twice", function()
  -- red under: the write guard wrapping onAdd but not onRemove.
  local made, c = filtersTab("blacklist", { [2589] = true })
  local rm = firstOf(made, "Icon")
  local boxes = editBoxesMadeBy(function() rm:__fire("OnClick") end)
  assertEqual(boxes, 1, "exactly one repaint follows one remove")
  assertEqual(next(NS.db.global.blacklist), nil, "the remove landed")
  leaveFilters(c)
end)

test("Filters tab: the list's own redraw repaints this page, never every rendered page", function()
  -- red under: no ctx.rebuild, where the widget falls back to O.RefreshAllPanels.
  local made, c = filtersTab("blacklist")
  local saved, sweeps = NS.Helpers.RefreshAllPanels, 0
  NS.Helpers.RefreshAllPanels = function() sweeps = sweeps + 1 end
  local ok, err = pcall(typeInto, made, "2589")
  NS.Helpers.RefreshAllPanels = saved
  if not ok then error(err, 0) end
  assertEqual(sweeps, 0, "an add sweeps no page but this one")
  leaveFilters(c)
end)

test("Filters tab: a list change from elsewhere still repaints the open tab", function()
  -- The guard holds the listener off only for the page's OWN write; the ledger table's right-click
  -- Blacklist goes through the same writer outside it and must still show up on an open tab.
  -- red under: the guard left set after a write, or the listener dropped.
  local _, c = filtersTab("blacklist")
  local boxes = editBoxesMadeBy(function() NS.Filters:AddBlacklist(4306) end)
  assertEqual(boxes, 1, "the open tab repaints for an outside change")
  leaveFilters(c)
end)

test("Filters tab: an entry's name is drawn in its item quality color", function()
  -- The client's ITEM_QUALITY_COLORS[q].hex is a whole color code, "|cff" prefix included, and
  -- IdList prepends it as-is. red under: a palette hex without the prefix (the line read
  -- "ff0070ddRuned Band|r"), which is what tests/wow_mock.lua answered before it matched the client.
  mocks.addIdRecord("item", 99104, "Runed Band", 134400, nil, 3)
  local ok, made, c = pcall(filtersTab, "blacklist", { [99104] = true })
  mocks.__idRecords.item[99104] = nil
  if not ok then error(made, 0) end
  local line = firstOf(made, "InteractiveLabel", "Runed Band")
  assertTrue(line ~= nil, "the entry is drawn")
  assertEqual(line.text:find("|cff0070ddRuned Band|r", 1, true), 1,
    "a rare item's name opens in the rare color code")
  leaveFilters(c)
end)

-- ── the Filters tab's suggestions (LibKa0s v1.35.0 re-cut, issue #31) ────────────────────────
--
-- The client has no item-name search: C_Item's name lookups answer only for an item the player
-- carries or carried this session. So the add box gets `candidates` -- every item id the ledger has
-- recorded, plus both lists' ids -- which the widget names itself, lists as the player types, and
-- resolves a typed name against. The dropdown is a library frame, not an AceGUI widget, so a case
-- records the frames CreateFrame hands out and finds the one carrying `rows`, and reads each row off
-- the library's own record on it (`row.entry`, `row.labelText`): the kit's frame stub keeps no
-- FontString text. This harness's C_Timer.After is a no-op, so each case queues the typing debounce
-- and runs it by hand.

local ZEPHYR = "Potion of the Hushed Zephyr"
local ZEPHYR_IDS = { 191395, 191396, 191397 }
-- The words the add box's refusal and tooltip end with. Spelled here, not read off settings/Panel.lua:
-- a case that reads its answer out of the thing it tests agrees with itself whatever that says.
local NAME_HINT = "Names work for items you carry (or carried this session), items on either list "
  .. "and items your ledger has recorded; otherwise use the id or shift-click a link."

-- The dropdown, once a case has seen it built: there is one per library instance, built the first
-- time it shows, so later cases find it here rather than among their own frames.
local seenDropdown

--- One suggestion case. `fn(s)` gets:
---   s.item(id, name, quality, tier) -- a cached item record, removed again when the case ends;
---   s.rows(ids)                     -- ledger rows recording `ids`, plus a gold row with no item;
---   s.notCarried()                  -- C_Item's name lookups answer nothing for a plain name, as
---                                      the client's do for an item not in the bags this session;
---   s.flush()                       -- run the queued timers (the typing debounce, a lookup);
---   s.dropdown(), s.c               -- the dropdown frame; set s.c to the ctx to leave Filters.
local function suggestCase(name, fn)
  test(name, function()
    local realFrame, realAfter = mocks.CreateFrame, mocks.C_Timer.After
    local realInstant, realInfo = mocks.C_Item.GetItemInfoInstant, mocks.C_Item.GetItemInfo
    local frames, queue, seeded = {}, {}, {}
    mocks.CreateFrame = function(...)
      local f = realFrame(...)
      frames[#frames + 1] = f
      return f
    end
    mocks.C_Timer.After = function(_, cb) queue[#queue + 1] = cb end
    local s = {}
    function s.item(id, itemName, quality, tier)
      mocks.addIdRecord("item", id, itemName, 134400, nil, quality)
      if tier then mocks.setCraftedQuality(id, tier) end
      seeded[#seeded + 1] = id
    end
    function s.rows(ids)
      local rows = {}
      for i, id in ipairs(ids) do rows[i] = { itemID = id, quantity = 1 } end
      rows[#rows + 1] = { quantity = 100 }
      return rows
    end
    function s.notCarried()
      local function byName(real)
        return function(key, ...)
          if type(key) == "string" and not tonumber(key) and not key:find("item:%d") then
            return nil
          end
          return real(key, ...)
        end
      end
      mocks.C_Item.GetItemInfoInstant = byName(realInstant)
      if realInfo then mocks.C_Item.GetItemInfo = byName(realInfo) end
    end
    -- The bags: the kit answers GetContainerItemID from mocks.__bags, and this file's own
    -- GetContainerNumSlots reads the scanner's M.__containers, so a case carrying items lends it
    -- the kit's slot count for its length.
    local realSlots = mocks.C_Container.GetContainerNumSlots
    function s.carry(ids)
      mocks.setBagItems(0, ids)
      mocks.C_Container.GetContainerNumSlots = function(bag) return #(mocks.__bags[bag] or {}) end
    end
    function s.flush()
      for _ = 1, 50 do
        if #queue == 0 then return end
        local due = queue
        queue = {}
        for _, cb in ipairs(due) do cb() end
      end
    end
    function s.dropdown()
      for i = #frames, 1, -1 do
        if type(frames[i].rows) == "table" then seenDropdown = frames[i] end
      end
      return seenDropdown
    end
    local ok, err = pcall(fn, s)
    mocks.CreateFrame, mocks.C_Timer.After = realFrame, realAfter
    mocks.C_Item.GetItemInfoInstant, mocks.C_Item.GetItemInfo = realInstant, realInfo
    mocks.C_Container.GetContainerNumSlots = realSlots
    mocks.setBagItems(0, {})
    for _, id in ipairs(seeded) do
      mocks.__idRecords.item[id] = nil
      mocks.__craftedQuality[id] = nil
    end
    if s.c then leaveFilters(s.c) end
    if not ok then error(err, 0) end
  end)
end

--- Type into the add box as AceGUI's EditBox reports it, then let the debounce run.
local function typeText(made, text, s)
  local box = firstOf(made, "EditBox")
  assertTrue(box ~= nil, "the Filters tab has no add box")
  box:SetText(text)
  box:__fire("OnTextChanged", text)
  s.flush()
end

--- The ids the dropdown's visible rows carry, in order; "" while it is hidden.
local function shownIds(s)
  local dd = s.dropdown()
  if not (dd and dd:IsShown()) then return "" end
  local ids = {}
  for _, row in ipairs(dd.rows) do
    if row:IsShown() and row.entry then ids[#ids + 1] = row.entry.id end
  end
  return table.concat(ids, ",")
end

suggestCase("Filters tab: typing lists the items the ledger recorded and the other list holds", function(s)
  -- red under: no candidates. The bags are empty, so the dropdown would have nothing to list.
  s.item(99101, "Glimmering Opal")
  s.item(99102, "Glimmering Shard")
  local made
  made, s.c = filtersTab("blacklist", nil, { [99102] = true }, s.rows({ 99101, 99101 }))
  typeText(made, "glimmering", s)
  assertEqual(shownIds(s), "99101,99102", "the ledger's item and the whitelist's, each once")
end)

suggestCase("Filters tab: a name the client's lookup cannot find resolves through the ledger's ids", function(s)
  -- The owner's case: an item the player does not carry, so C_Item answers nothing for its name.
  -- red under: no candidates (the name resolves to nothing and the add is refused).
  s.item(99103, "Gossamer Thread")
  s.notCarried()
  local made
  made, s.c = filtersTab("blacklist", nil, nil, s.rows({ 99103 }))
  local calls = spyWriter("AddBlacklist", function() typeInto(made, "gossamer thread") end)
  assertEqual(table.concat(calls, ","), "99103")
end)

suggestCase("Filters tab: picking a suggestion adds it through the list's own writer, once", function(s)
  -- red under: no candidates (no row to pick), or a pick that reaches the writer twice.
  s.item(99101, "Glimmering Opal")
  local made
  made, s.c = filtersTab("whitelist", nil, nil, s.rows({ 99101 }))
  typeText(made, "glimm", s)
  local dd = s.dropdown()
  assertTrue(dd ~= nil and dd:IsShown(), "the dropdown is up")
  local black
  local white = spyWriter("AddWhitelist", function()
    black = spyWriter("AddBlacklist", function() dd.rows[1]:__fire("OnClick") end)
  end)
  assertEqual(table.concat(white, ","), "99101", "one call, with the picked id")
  assertEqual(#black, 0, "the other list's writer is not called")
  assertTrue(NS.db.global.whitelist[99101] == true, "the pick landed on the whitelist")
end)

suggestCase("Filters tab: a name three ranks share lists every rank; Enter without a pick adds none", function(s)
  for tier, id in ipairs(ZEPHYR_IDS) do s.item(id, ZEPHYR, 1, tier) end
  local made
  made, s.c = filtersTab("blacklist", nil, nil, s.rows(ZEPHYR_IDS))
  typeText(made, ZEPHYR, s)
  -- red under: no candidates (nothing listed, the player cannot pick a rank)
  assertEqual(shownIds(s), "191395,191396,191397", "every rank is its own row")
  for i = 1, 3 do
    assertTrue(s.dropdown().rows[i].labelText:find("Tier" .. i, 1, true) ~= nil,
      "row " .. i .. " is labeled with its rank")
  end
  local box = firstOf(made, "EditBox")
  local calls = spyWriter("AddBlacklist", function() box:__fire("OnEnterPressed", ZEPHYR) end)
  -- red under: no candidates, where the client's one answer for the name adds its first rank
  assertEqual(#calls, 0, "neither one rank nor all three")
  assertTrue(firstOf(made, "Label", "Several items are named '" .. ZEPHYR
    .. "' \226\128\148 pick one from the list, or use the id.") ~= nil, "the refusal says why")
  assertEqual(shownIds(s), "191395,191396,191397", "the ranks stay listed to pick from")
  calls = spyWriter("AddBlacklist", function() s.dropdown().rows[3]:__fire("OnClick") end)
  assertEqual(table.concat(calls, ","), "191397", "the picked rank, and only it")
end)

suggestCase("Filters tab: a name two ranks in the bags share is refused unpicked, with no ledger", function(s)
  -- The everyday case: two ranks of one crafted potion in the bags, nothing on the lists or in the
  -- ledger. The client's name lookup answers ONE id for the name (here rank 1, which the player
  -- does not even carry). red under LibKa0s v1.35.0 as first tagged (48b486d), which checked that
  -- answer against the host's candidates alone: Enter added 191395, one rank, and not a listed one.
  for tier, id in ipairs(ZEPHYR_IDS) do s.item(id, ZEPHYR, 1, tier) end
  s.carry({ 191396, 191397 })
  local made
  made, s.c = filtersTab("blacklist")
  typeText(made, ZEPHYR, s)
  assertEqual(shownIds(s), "191396,191397", "both carried ranks are listed")
  local box = firstOf(made, "EditBox")
  local calls = spyWriter("AddBlacklist", function() box:__fire("OnEnterPressed", ZEPHYR) end)
  assertEqual(#calls, 0, "no rank is added unpicked")
  assertTrue(firstOf(made, "Label", "Several items are named '" .. ZEPHYR
    .. "' \226\128\148 pick one from the list, or use the id.") ~= nil, "the refusal says why")
  calls = spyWriter("AddBlacklist", function() s.dropdown().rows[2]:__fire("OnClick") end)
  assertEqual(table.concat(calls, ","), "191397", "the picked rank, and only it")
end)

suggestCase("Filters tab: Enter after retyping adds what was typed, not the old highlighted row", function(s)
  -- A fast typist: highlight a row, type a different name and press Enter before the debounce has
  -- re-listed. red under LibKa0s v1.35.0 as first tagged (48b486d), where a keystroke left the
  -- highlight up and Enter took the stale row (99101, an item the box no longer names).
  s.item(99101, "Glimmering Opal")
  s.item(99105, "Gossamer Thread")
  local made
  made, s.c = filtersTab("blacklist", nil, nil, s.rows({ 99101, 99105 }))
  typeText(made, "glimm", s)
  local box = firstOf(made, "EditBox")
  box.editbox:__fire("OnArrowPressed", "DOWN")
  box:SetText("Gossamer Thread")
  box:__fire("OnTextChanged", "Gossamer Thread")   -- the debounce is queued and NOT run
  local calls = spyWriter("AddBlacklist", function() box:__fire("OnEnterPressed", "Gossamer Thread") end)
  assertEqual(table.concat(calls, ","), "99105", "the typed name's item, once")
end)

--- Ledger rows recording `ids` that count every read of their fields into `reads[1]`.
local function countedRows(s, ids, reads)
  local rows = {}
  for i, real in ipairs(s.rows(ids)) do
    rows[i] = setmetatable({}, { __index = function(_, k) reads[1] = reads[1] + 1; return real[k] end })
  end
  return rows
end

suggestCase("Filters tab: the name candidates walk the ledger once until it changes", function(s)
  -- IdList asks for its candidates at the draw, on the first keystroke and at every submit; the
  -- ledger grows with rows, not items, so walking it each time is the cost. red under a
  -- filterCandidates that walks the whole ledger on every call.
  s.item(99101, "Glimmering Opal")
  s.notCarried()
  local reads = { 0 }
  local made
  made, s.c = filtersTab("blacklist", nil, nil, countedRows(s, { 99101, 99101, 99101 }, reads))
  local drawn = reads[1]
  typeText(made, "glimm", s)
  typeInto(made, "Unseen Relic")
  typeInto(made, "Unseen Relic")
  assertEqual(reads[1], drawn, "no row is read again while the ledger is unchanged")
end)

suggestCase("Filters tab: a ledger change reaches the name candidates", function(s)
  -- The memo must not outlive the ledger it read. DeleteAt then Add leaves the same table at the
  -- same length with a different item in it, which only LedgerChanged tells apart.
  s.item(99101, "Glimmering Opal")
  s.item(99105, "Gossamer Thread")
  s.notCarried()
  local made
  made, s.c = filtersTab("blacklist", nil, nil, s.rows({ 99101 }))
  NS.Database:DeleteAt(1)
  NS.Database:Add({ itemID = 99105, quantity = 1 })
  local black = spyWriter("AddBlacklist", function()
    typeInto(made, "Glimmering Opal")
    typeInto(made, "Gossamer Thread")
  end)
  assertEqual(table.concat(black, ","), "99105", "the deleted row's item is gone, the added one found")
end)

suggestCase("Filters tab: an item recorded after the tab was drawn resolves by name", function(s)
  -- A bank visit with the settings open: Add appends in place and fires EntryAdded, never
  -- LedgerChanged, so only the ledger's length says the memo is stale. red under a memo keyed
  -- without the length.
  s.item(99101, "Glimmering Opal")
  s.item(99105, "Gossamer Thread")
  s.notCarried()
  local made
  made, s.c = filtersTab("blacklist", nil, nil, s.rows({ 99101 }))
  NS.Database:Add({ itemID = 99105, quantity = 1 })
  local black = spyWriter("AddBlacklist", function() typeInto(made, "Gossamer Thread") end)
  assertEqual(table.concat(black, ","), "99105")
end)

suggestCase("Filters tab: a ledger table swapped with no message still reaches the candidates", function(s)
  -- Same length, same message count, a different table: only its identity tells. red under a memo
  -- keyed without the ledger table.
  s.item(99101, "Glimmering Opal")
  s.item(99105, "Gossamer Thread")
  s.notCarried()
  local made
  made, s.c = filtersTab("blacklist", nil, nil, s.rows({ 99101 }))
  NS.db.global.ledger = s.rows({ 99105 })
  local black = spyWriter("AddBlacklist", function() typeInto(made, "Gossamer Thread") end)
  assertEqual(table.concat(black, ","), "99105")
end)

suggestCase("Filters tab: a list table swapped with no message still reaches the candidates", function(s)
  -- Defaults and a profile change hand the lists new tables. red under a memo keyed without them.
  s.item(99106, "Tarnished Locket")
  s.notCarried()
  local made
  made, s.c = filtersTab("blacklist")
  NS.db.global.whitelist = { [99106] = true }
  local black = spyWriter("AddBlacklist", function() typeInto(made, "Tarnished Locket") end)
  assertEqual(table.concat(black, ","), "99106")
end)

suggestCase("Filters tab: a shared name with one rank known here adds that rank", function(s)
  -- Characterization of the limit docs/settings-panel.md states: the client has no item-name
  -- search, so with only rank 3 in the ledger and none carried, nothing here knows ranks 1 and 2
  -- exist, and the name is not ambiguous to anything this addon can see.
  for tier, id in ipairs(ZEPHYR_IDS) do s.item(id, ZEPHYR, 1, tier) end
  s.notCarried()
  local made
  made, s.c = filtersTab("blacklist", nil, nil, s.rows({ 191397 }))
  local calls = spyWriter("AddBlacklist", function() typeInto(made, ZEPHYR) end)
  assertEqual(table.concat(calls, ","), "191397", "the one known rank")
end)

suggestCase("Filters tab: a name nothing knows is refused, saying where names come from", function(s)
  -- red under: the library's default hint, which says "ones this list knows" and never that the
  -- ledger's items count too.
  s.notCarried()
  local made
  made, s.c = filtersTab("blacklist")
  local calls = spyWriter("AddBlacklist", function() typeInto(made, "Unseen Relic") end)
  assertEqual(#calls, 0, "nothing reaches the writer")
  assertTrue(firstOf(made, "Label", "No item named 'Unseen Relic' that the game can find. "
    .. NAME_HINT) ~= nil, "the refusal ends with the tab's own hint")
  -- And the box's tooltip says it before anything is typed. GameTooltip is nil in this harness
  -- (tests/wow_mock.lua override 10), so the case lends it a recorder for one hover.
  local lines = {}
  mocks.GameTooltip = {
    SetOwner = function() end, SetText = function() end, Show = function() end,
    Hide = function() end, AddLine = function(_, text) lines[#lines + 1] = text end,
  }
  local ok, err = pcall(function() firstOf(made, "EditBox"):__fire("OnEnter") end)
  mocks.GameTooltip = nil
  if not ok then error(err, 0) end
  assertTrue(type(lines[1]) == "string" and lines[1]:find(NAME_HINT, 1, true) ~= nil,
    "the add box's tooltip carries the hint")
end)

test("Panel: every renderable schema row reaches the page on ITS OWN tab", function()
  -- A row drifting into the wrong group renders under the wrong tab, which the partition case in
  -- tests/test_schema.lua catches in the data. This is the same claim about the drawn page: the row
  -- must be on the tab its group names, and must NOT be on the others.
  for _, tab in ipairs(GENERAL_TABS) do
    local made = renderTab("General", tab)
    for _, row in ipairs(NS.Schema.Schema) do
      if not row.skipRender then
        local drawn = widgetLabeled(made, row.label) ~= nil
        if row.group == tab then
          assertTrue(drawn, row.path .. " (" .. tostring(row.label) .. ") never reached its tab")
        else
          assertFalse(drawn, row.path .. " leaked onto the '" .. tab .. "' tab")
        end
      end
    end
  end
end)

test("Panel: a boolean row is a CheckBox and a range row is a Slider", function()
  -- The two canonical labels moved with their rows: "Enable capture" is "Enable Bank Ledger" and
  -- "Window scale" is "Master scale", both on Master controls (options-ui-§15).
  local master = renderTab("General", "Master controls")
  assertEqual(widgetLabeled(master, "Enable Bank Ledger").type, "CheckBox")
  assertEqual(widgetLabeled(master, "Master scale").type, "Slider")
  assertEqual(widgetLabeled(master, "Master alpha").type, "Slider")
  assertEqual(widgetLabeled(master, "General visibility").type, "Dropdown")
  assertEqual(widgetLabeled(master, "Test mode").type, "CheckBox")
  local iface = renderTab("General", "Interface")
  assertEqual(widgetLabeled(iface, "Row stripe opacity").type, "Slider")
  assertEqual(widgetLabeled(iface, "Row hover opacity").type, "Slider")
end)

test("Panel: the Master controls tab closes with the two reset buttons", function()
  -- The composer's afterGroup hook, wired under the group's own name — rename the group and the
  -- pair silently detaches (options-ui-§15). "Reset all settings" is options-ui-§12's global reset,
  -- so this is also the case that proves it did not stay behind on History as a second control.
  --
  -- Dies under: dropping GENERAL_AFTER_TAB["Master controls"], or renaming the group.
  local master = renderTab("General", "Master controls")
  local seenPosition, paired = false, false
  for _, w in ipairs(master) do
    if w.type == "Button" and w.text == "Reset position" then seenPosition = true
    elseif seenPosition and w.type == "Button" and w.text == "Reset all settings" then
      paired = true; break
    end
  end
  assertTrue(paired, "Reset all settings must follow Reset position inside the same row")

  for _, tab in ipairs({ "Capture", "Interface", "History" }) do
    for _, w in ipairs(renderTab("General", tab)) do
      assertFalse(w.type == "Button" and (w.text or ""):find("Reset all", 1, true) ~= nil,
        "a second Reset all is drawn on the '" .. tab .. "' tab")
    end
  end
end)

test("Panel: a numeric ENUM row is a Dropdown, not a slider over its indices", function()
  -- The whole reason LibKa0s-Options-1.0 went to OptionsWidgets minor 5. Neither of these rows
  -- declares min/max/step, so under minor 4 they rendered as 0-to-1 sliders — a control that could
  -- not express any of their values, with nothing raising. The two now live on different tabs.
  local q = widgetLabeled(renderTab("General", "Capture"), "Minimum quality")
  local r = widgetLabeled(renderTab("General", "History"), "Keep history for")
  assertEqual(q.type, "Dropdown")
  assertEqual(r.type, "Dropdown")
  assertEqual(r.list[30], "30 days", "the entries carry their own labels, not stringified values")
  assertEqual(r.value, NS.Schema:Get("settings.retentionDays"), "seeded from the store")
end)

test("Panel: a checkbox write goes through the single write seam", function()
  local made = renderTab("General", "Capture")
  local cb = widgetLabeled(made, "Track gold")
  local saved = NS.Schema:Get("settings.trackMoney")
  cb:__fire("OnValueChanged", false)
  assertEqual(NS.Schema:Get("settings.trackMoney"), false, "the widget wrote through NS.Schema:Set")
  cb:__fire("OnValueChanged", true)
  assertEqual(NS.Schema:Get("settings.trackMoney"), true)
  NS.Schema:Set("settings.trackMoney", saved)
end)

test("Panel: History draws Purge alone — Reset all left with the Master controls tab", function()
  -- "Reset all…" used to be the right half of this pair, and it raised the SAME popup the Master
  -- controls tab's "Reset all settings" raises now. Two controls over one act is what the revamp
  -- removes, so it moved rather than being copied, and Purge is alone in its pair.
  --
  -- Dies under: putting the second spec back into renderStorage's InlineButtonPair call.
  local history = renderTab("General", "History")
  local seenPurge = false
  for _, w in ipairs(history) do
    if w.type == "Button" and w.text == "Purge ledger\226\128\166" then seenPurge = true
    elseif seenPurge and w.type == "Button" then
      assertFalse(true, "History drew a second button beside Purge: " .. tostring(w.text))
    end
  end
  assertTrue(seenPurge, "the Purge button is missing from History")
end)

test("Panel: the store grid renders as an inverted checkbox set, host-drawn", function()
  -- `skipRender = true` keeps the row out of the flow engine; the page emits this grid itself. The
  -- inversion is the part worth pinning: the row STORES the muted set, so a TICKED box means
  -- "record this store".
  local made = renderTab("General", "Capture")
  local group
  for _, w in ipairs(made) do
    if w.type == "InlineGroup" then group = w end
  end
  assertTrue(group ~= nil, "no InlineGroup for the store grid")
  assertEqual(group.titleText, NS.Schema:FindRow("settings.excludedStores").label)
  local row = NS.Schema:FindRow("settings.excludedStores")
  assertEqual(#group.children, #row.values, "one checkbox per store option")

  local saved = NS.Schema:Get("settings.excludedStores")
  NS.Schema:Set("settings.excludedStores", {})
  renderTab("General", "Capture")   -- re-render so the boxes seed from the empty muted set
  local made2 = renderTab("General", "Capture")
  local grid
  for _, w in ipairs(made2) do if w.type == "InlineGroup" then grid = w end end
  for _, cb in ipairs(grid.children) do
    assertTrue(cb.value == true, cb.labelText .. " should be TICKED when nothing is muted")
  end
  -- Unticking one must MUTE it, i.e. write it INTO the stored set.
  local first = row.values[1].value
  grid.children[1]:__fire("OnValueChanged", false)
  assertTrue((NS.Schema:Get("settings.excludedStores") or {})[first] == true,
    "unticking a store must add it to the muted set")
  NS.Schema:Set("settings.excludedStores", saved or {})
end)

test("Panel: a tab's only headings are the SUBSECTION ones its rows declare", function()
  -- RenderTabbedSchema renders the active group with `noHeadings`, because a tab labelled Capture
  -- over a section headed Capture says the same word twice. A SUBSECTION heading is the exception
  -- and is deliberately not suppressed (options-ui-§7): it names a kind of control the tab mixes,
  -- and it is declared by the row's `subgroup`, never drawn by a builder.
  --
  -- So the claim is not "no Heading" — it is "every Heading on this tab is one its rows asked for,
  -- and none of them repeats the tab's own name".
  --
  -- Dies under: dropping `subgroup` from the Interface rows (Windows/Table rows vanish), or drawing
  -- a heading by hand from an afterGroup hook.
  for _, tab in ipairs(GENERAL_TABS) do
    local declared = {}
    for _, row in ipairs(NS.Schema:PageRows()) do
      if row.group == tab and row.subgroup then declared[row.subgroup] = true end
    end
    local drawn = {}
    for _, w in ipairs(renderTab("General", tab)) do
      if w.type == "Heading" then
        assertTrue(declared[w.text] == true,
          tab .. " drew a heading no row declared: " .. tostring(w.text))
        assertFalse(w.text == tab, tab .. " drew a heading repeating its own tab name")
        drawn[w.text] = true
      end
    end
    for name in pairs(declared) do
      assertTrue(drawn[name] == true, tab .. " declared the subsection '" .. name
        .. "' and drew no heading for it")
    end
  end
end)

test("Panel: the storage read-out lands on the History tab and nowhere else", function()
  -- It was the casualty the first time the store grid raised: the library's per-page pcall stopped
  -- the renderer, and everything after the raise silently never drew. It is now drawn from the
  -- History tab's afterGroup hook, which is what keeps it on the page through a tab click — the
  -- page renderer's own trailing calls would have survived exactly one render.
  local function readoutIn(made)
    for _, w in ipairs(made) do
      if w.type == "Label" and (w.text or ""):find("Database size", 1, true) then return true end
    end
    return false
  end
  assertTrue(readoutIn(renderTab("General", "History")), "no storage read-out on History")
  assertFalse(readoutIn(renderTab("General", "Capture")), "the read-out leaked onto Capture")
  assertFalse(readoutIn(renderTab("General", "Interface")), "the read-out leaked onto Interface")

  -- And it survives a second visit to the tab, which is the whole point of the afterGroup hook.
  assertTrue(readoutIn(renderTab("General", "History")), "the read-out vanished on a re-render")
end)

-- The two Filters-page cases that used to live here are GONE with the page (R3). What they proved
-- — which list is drawn under which tab, and a stale tab pointer healing to the first — is now
-- General's, and both are covered above: "the strip's FIRST tab is Master controls, and it is not
-- the Filters page's" asserts the bodies, and the heal is RenderTabbedSchema's own (it repoints
-- ctx.activeTab at groups[1] when the pointer names a group the page no longer has), exercised by
-- every renderTab call in this file.

test("Panel: re-rendering a page releases the previous widgets and their refreshers", function()
  -- Every render appends refresher closures that capture the widgets it made. Keeping them across a
  -- re-render leaves every later write pcall'ing an ever-growing pile of dead closures
  -- (options-ui-§11) — which is what O.ClearScroll at the top of each renderer prevents.
  local ctx = ctxFor("General")
  assertTrue(ctx ~= nil, "the General ctx is in the library's registry")
  renderPage("General")
  local first = #ctx.refreshers
  renderPage("General")
  assertEqual(#ctx.refreshers, first, "the refresher list must be replaced, not appended to")
end)


-- ── the id list packs two entries to a line (LibKa0s v1.47.0 `columns`) ──────────────────────
--
-- `columns` is OptionsWidgets minor 24; the canvas fit that makes it a MAXIMUM rather than a count
-- is v1.50.0, minor 27. Both lists this page draws are item lists and both take two, so unlike Loot
-- History's Filters tab there is no per-list distinction to pin -- what is pinned is the packing
-- itself, which is ROW-MAJOR (1 2 / 3 4). A column-major library would put the same ids on screen
-- in an order no reader could follow and the flat order alone would not notice.

--- Every drawn entry, with the row it landed in and its position across that row.
---
--- `line` is the entry's ROW's index within the created slice, not a row count: two entries packed
--- into one Flow row share the row object and therefore the index, and an entry on the next row
--- down has a larger one, because the library creates each row before the widgets that go into it.
--- So it is an ORDER, and only ever compared as one.
local function packedEntries(ws)
  local out = {}
  for line, w in ipairs(ws) do
    local kids = type(w.children) == "table" and w.children or {}
    local col = 0
    for _, kid in ipairs(kids) do
      if type(kid) == "table" and kid.type == "InteractiveLabel" and type(kid.text) == "string" then
        local id = kid.text:match("%((%d+)%)|r") or kid.text:match("^Unknown %a+ (%d+)")
        if id then
          col = col + 1
          out[#out + 1] = { id = tonumber(id), line = line, col = col }
        end
      end
    end
  end
  return out
end

test("Filters tab: the id list packs two entries to a line, row-major", function()
  -- SAY WHAT CANVAS THIS PACKS INTO. `columns` is a maximum fitted to the measured content width,
  -- and the kit's ScrollFrame fixture is 400 (380 of content once the scrollbar patch takes its
  -- gutter) -- under the icon style's 520px floor for two columns. Unarmed, the library would
  -- correctly draw ONE column and this case would assert the fixture rather than the packing.
  -- 700 pays for two in either style; see S.withCanvas.
  S.withCanvas(700, function()
    local made = filtersTab("blacklist", { [11111] = true, [22222] = true, [33333] = true })
    local drawn = packedEntries(made)
    assertEqual(#drawn, 3, "the three blacklisted ids are drawn")
    -- red under no `columns` (each entry takes a line of its own), and red under column-major.
    assertEqual(drawn[1].line, drawn[2].line, "the first two share one line")
    assertEqual(drawn[1].col, 1, "the first is the left column")
    assertEqual(drawn[2].col, 2, "the second is beside it, not under it")
    assertTrue(drawn[3].line > drawn[2].line, "the third starts the next line down")
    assertEqual(drawn[3].col, 1, "and is the left column of that line")
  end)
  local c = ctxFor("General")
  c.activeSubTab = nil
  c.activeTab = GENERAL_TABS[1]
end)
