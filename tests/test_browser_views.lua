local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local mocks = T.mocks
local B = NS.Browser

-- ClearFilters pushes through to the table, so park and restore the shared filter around each case.
local function withCleanFilter(fn)
  local saved, savedActive = NS.LedgerTable.filter, B.activeFilter
  local ok, err = pcall(fn)
  NS.LedgerTable.filter, B.activeFilter = saved, savedActive
  if not ok then error(err, 0) end
end

-- tests/test_browser_views.lua: the saved view and the per-tab views, the cases for
-- modules/Browser_Views.lua. Lifted whole out of tests/test_browser.lua on the seam its watch-list
-- row named, when that file passed its 1300 re-check at 1442 lines.

-- ── The saved view ─────────────────────────────────────────────────────────────

-- CaptureView and ApplyView both read and write the filter bar's widgets, which only exist once the
-- window has been built. Stand in a minimal fake bar that honors the same tiny contract the real
-- dropdowns expose (_selected / _value / SetSelected / SelectValue) so the view logic itself is
-- exercised headlessly, rather than skipped.
local function fakeDropdown()
  local dd = { _selected = {}, _value = "all" }
  function dd:SetSelected(set)
    local s = {}
    if type(set) == "table" then for k, on in pairs(set) do if on then s[k] = true end end end
    self._selected = s
  end
  function dd:SelectValue(v) self._value = v end
  return dd
end

local function fakeSearch()
  local s = { _text = "" }
  function s:SetText(t) self._text = t or "" end
  function s:GetText() return self._text end
  return s
end

-- The active tab's saved-view slot (NS.db.profile.savedViews[tab]): what Save writes and Reset
-- clears. Read through the module's own active-tab accessor, so these cases follow whichever tab an
-- earlier suite left on screen rather than assuming History.
local function slot()
  local s = NS.db.profile.savedViews
  return type(s) == "table" and s[B:ActiveTab()] or nil
end

-- Run `fn` against a fake bar and parked saved views, restoring the real ones (and the shared
-- filter) whether it passes or throws.
local function withFakeBar(fn)
  local savedDd, savedSearch = B._dd, B._search
  local savedViews = NS.db.profile.savedViews
  local savedGroup, savedSort, savedAsc =
    NS.LedgerTable.groupBy, NS.LedgerTable.sortKey, NS.LedgerTable.sortAsc
  local dd = {}
  for _, k in ipairs({ "group", "date", "direction", "store", "quality", "type", "subtype", "char" }) do
    dd[k] = fakeDropdown()
  end
  B._dd, B._search = dd, fakeSearch()
  NS.db.profile.savedViews = nil
  local ok, err = pcall(function() withCleanFilter(function() fn(dd) end) end)
  B._dd, B._search = savedDd, savedSearch
  NS.db.profile.savedViews = savedViews
  NS.LedgerTable.groupBy, NS.LedgerTable.sortKey, NS.LedgerTable.sortAsc =
    savedGroup, savedSort, savedAsc
  if not ok then error(err, 0) end
end

test("Browser: with nothing saved, the baseline IS the stock view", function()
  withFakeBar(function()
    assertEqual(B._savedViewOrStock(), B._STOCK_VIEW)
  end)
end)

test("Browser: a corrupt saved view degrades to stock rather than erroring", function()
  withFakeBar(function()
    NS.db.profile.savedViews = { [B:ActiveTab()] = "not a table" }
    assertEqual(B._savedViewOrStock(), B._STOCK_VIEW, "a scalar is not a view")
    NS.db.profile.savedViews = "not a table either"
    assertEqual(B._savedViewOrStock(), B._STOCK_VIEW, "a scalar is not a set of views")
  end)
end)

test("Browser:SaveView then ClearFilters returns to the SAVED view, not stock", function()
  withFakeBar(function(dd)
    -- Set up a view by hand, exactly as the widgets would after the user drove them.
    NS.LedgerTable.groupBy, NS.LedgerTable.sortKey, NS.LedgerTable.sortAsc = "store", "qty", true
    dd.store:SetSelected({ BANK = true })
    dd.quality:SetSelected({ [4] = true })
    dd.date:SelectValue("7d")
    B._search:SetText("linen")
    B:SaveView()

    -- Wander off it, then Clear.
    NS.LedgerTable.groupBy = "none"
    dd.store:SetSelected({})
    B._search:SetText("silk")
    B:ClearFilters()

    assertEqual(NS.LedgerTable.groupBy, "store")
    assertEqual(NS.LedgerTable.sortKey, "qty")
    assertEqual(NS.LedgerTable.sortAsc, true)
    assertEqual(dd.store._selected.BANK, true)
    assertEqual(dd.quality._selected[4], true)
    assertEqual(dd.date._value, "7d")
    assertEqual(B._search:GetText(), "linen")
    assertEqual((B.activeFilter.store or {}).BANK, true)
    assertEqual(B.activeFilter.text, "linen")
  end)
end)

test("Browser: a 'typesub' grouping survives SaveView and comes back on Clear", function()
  withFakeBar(function(dd)
    NS.LedgerTable.groupBy = "typesub"
    B:SaveView()
    assertEqual(slot().groupBy, "typesub", "stored verbatim")
    NS.LedgerTable.groupBy = "none"
    B:ClearFilters()
    assertEqual(NS.LedgerTable.groupBy, "typesub")
    assertEqual(dd.group._value, "typesub", "the Group dropdown shows the saved mode")
  end)
end)

test("Browser:ResetView drops the saved view, and Clear then lands on stock", function()
  withFakeBar(function(dd)
    NS.LedgerTable.groupBy = "store"
    dd.store:SetSelected({ BANK = true })
    B:SaveView()
    B:ResetView(true)

    assertEqual(slot(), nil, "the saved view is gone from storage")
    assertEqual(NS.LedgerTable.groupBy, "none")
    assertEqual(B.activeFilter.store, nil)
    assertEqual(B._savedViewOrStock(), B._STOCK_VIEW)

    dd.store:SetSelected({ BANK = true })
    B:ClearFilters()
    assertEqual(B.activeFilter.store, nil, "Clear now lands on stock again")
  end)
end)

-- Regression: CaptureView's return is written verbatim to a NS.db.profile.savedViews slot, so its SHAPE is a
-- SavedVariables shape. With no table module the sort direction must be a nil in the constructor,
-- which leaves the `sortAsc` KEY ABSENT from the stored view — a refactor that defaulted it to
-- `false` instead would start writing a key that was never on disk before, and an absent key and a
-- stored false are different facts to everything that reads the file back.
test("Browser:CaptureView omits sortAsc entirely when the table module is not loaded", function()
  withFakeBar(function()
    local LT = NS.LedgerTable
    local ok, v = pcall(function()
      NS.LedgerTable = nil
      return B:CaptureView()
    end)
    NS.LedgerTable = LT
    assertTrue(ok, "CaptureView must survive a build with no table module")

    local present = false
    for k in pairs(v) do if k == "sortAsc" then present = true end end
    assertFalse(present, "the sortAsc key must be absent, not stored as false")
    assertEqual(v.sortAsc, nil)
    -- The other two table-state defaults still land, exactly as before.
    assertEqual(v.groupBy, "none")
    assertEqual(v.sortKey, "date")
  end)
end)

test("Browser:CaptureView never captures the character scope", function()
  -- Character is a per-session default of Current, not something a stale save can pin to one alt.
  withFakeBar(function(dd)
    dd.char:SetSelected({ ["Alt-Realm"] = true })
    assertEqual(B:CaptureView().char, nil)
  end)
end)

test("Browser:ApplyView always scopes to the current character", function()
  withFakeBar(function(dd)
    dd.char:SetSelected({ ["Alt-Realm"] = true })
    B:SaveView()
    B:ClearFilters()
    assertEqual((B.activeFilter.char or {})[NS.Util.PlayerKey()], true)
    assertEqual((B.activeFilter.char or {})["Alt-Realm"], nil)
  end)
end)

test("Browser:ApplyView with the 'all' scope drops the character filter entirely", function()
  -- What entering test mode uses: the synthetic dataset is alts, so scoping to the real player
  -- would open the window onto an empty table.
  withFakeBar(function()
    B:ApplyView(B._STOCK_VIEW, "all")
    assertEqual(B.activeFilter.char, nil)
  end)
end)

test("Browser:SaveView stores COPIES, so a later toggle cannot rewrite the saved view", function()
  withFakeBar(function(dd)
    dd.store:SetSelected({ BANK = true })
    B:SaveView()
    dd.store:SetSelected({ BANK = true, GUILD_BANK = true })   -- the user keeps filtering
    assertEqual(slot().store.GUILD_BANK, nil)
  end)
end)

test("Browser: a saved date range is stored as the OPTION, not a resolved timestamp", function()
  -- A frozen `from` would mean "the week ending whenever I pressed Save"; the option recomputes
  -- against each session's clock.
  withFakeBar(function(dd)
    dd.date:SelectValue("7d")
    B:SaveView()
    assertEqual(slot().date, "7d")
    assertEqual(slot().from, nil)
  end)
end)

test("Browser:ApplyView tolerates a scalar filter value in a stored view", function()
  withFakeBar(function(dd)
    B:ApplyView({ store = "BANK" }, "current")
    assertEqual(dd.store._selected.BANK, true)
    assertEqual((B.activeFilter.store or {}).BANK, true)
  end)
end)

test("Slash:CliResetAll (the profile reset) also discards the saved view", function()
  -- `/bl resetall` is Sl:ResetEverything now (options-ui-§12), and its db:ResetProfile() takes
  -- savedViews with the rest of the profile. red under: a reset that keeps savedViews.
  -- The reset's unseen profile would show the first-run picker, whose preview turns test mode on
  -- and repaints the bar this fake cannot take; the picker is its own suite (R6-PV).
  withFakeBar(function(dd)
    dd.store:SetSelected({ BANK = true })
    B:SaveView()
    T.withoutFirstRunPicker(function() NS.Slash:CliResetAll() end)
    assertEqual(NS.db.profile.savedViews, nil)
  end)
end)

-- ── Per-tab views (owner request 2026-10-07) ────────────────────────────────────
-- History and Insights each keep their OWN live filter state and their OWN saved view. The bar is
-- one set of widgets, so a tab switch captures the outgoing tab's state and paints the incoming
-- tab's; Save, Reset and Clear act on the tab on screen and never reach the other. Driven through
-- the real window, so the widgets, SelectTab and the stash all run as they do in game.

local function muted(fn)
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
end

local function withTabs(fn)
  local savedViews = NS.db.profile.savedViews
  local savedGroup, savedSort, savedAsc =
    NS.LedgerTable.groupBy, NS.LedgerTable.sortKey, NS.LedgerTable.sortAsc
  NS.db.profile.savedViews = nil
  local ok, err = pcall(function()
    muted(function()
      B:Show()
      B:SelectTab("History")
      B:ClearAllTabs()
    end)
    fn(B._dd)
  end)
  muted(function()
    B:SelectTab("History")
    NS.db.profile.savedViews = savedViews
    B:ClearAllTabs()
    B:Hide()
  end)
  NS.LedgerTable.groupBy, NS.LedgerTable.sortKey, NS.LedgerTable.sortAsc =
    savedGroup, savedSort, savedAsc
  if not ok then error(err, 0) end
end

local function views() return NS.db.profile.savedViews or {} end

test("Per-tab views: Save on a tab writes that tab's slot and never the other's", function()
  -- red under: one shared savedView (Save on Insights rewrites the view History comes back to).
  withTabs(function()
    muted(function()
      B:ApplyView({ store = { BANK = true } }, "current")
      B:SaveView()
      B:SelectTab("Insights")
      B:ApplyView({ quality = { [4] = true } }, "current")
      B:SaveView()
    end)
    assertEqual(views().History.store.BANK, true, "History's slot holds History's view")
    assertEqual(next(views().History.quality), nil, "Insights' Save reached History's slot")
    assertEqual(views().Insights.quality[4], true, "Insights' slot holds Insights' view")
    assertEqual(next(views().Insights.store), nil, "History's Save reached Insights' slot")
  end)
end)

test("Per-tab views: Reset on a tab drops only that tab's saved view", function()
  -- red under: a Reset that clears every saved view, or the one shared key.
  withTabs(function()
    muted(function()
      B:ApplyView({ store = { BANK = true } }, "current")
      B:SaveView()
      B:SelectTab("Insights")
      B:ApplyView({ quality = { [4] = true } }, "current")
      B:SaveView()
      B:ResetView(true)
    end)
    assertEqual(views().Insights, nil, "Insights' saved view survived its Reset")
    assertEqual(B.activeFilter.quality, nil, "Reset did not land Insights on stock")
    assertEqual(views().History.store.BANK, true, "Insights' Reset discarded History's saved view")
    muted(function()
      B:SelectTab("History")
      B:ResetView(true)
    end)
    assertEqual(NS.db.profile.savedViews, nil, "an emptied set of views is left in the profile")
  end)
end)

test("Per-tab views: Clear on a tab returns to that tab's own saved view", function()
  -- red under: Clear reading another tab's slot, or touching the other tab's live state.
  withTabs(function(dd)
    muted(function()
      B:ApplyView({ store = { BANK = true } }, "current")
      B:SaveView()
      B:SelectTab("Insights")
      B:ApplyView({ quality = { [4] = true } }, "current")
      B:SaveView()
      B:ApplyView({ direction = { WITHDRAW = true } }, "all")   -- wander off Insights' baseline
      B:ClearFilters()
    end)
    assertEqual((B.activeFilter.quality or {})[4], true, "Insights' Clear missed its own saved view")
    assertEqual(B.activeFilter.store, nil, "Insights' Clear applied History's saved view")
    assertEqual(B.activeFilter.direction, nil, "Clear left the wandered-off filter on")
    muted(function()
      B:ApplyView({ direction = { DEPOSIT = true } }, "current")   -- History's live state
      B:SelectTab("History")
    end)
    assertEqual((B.activeFilter.store or {}).BANK, true, "History's live state was lost to the Clear")
    muted(function() B:ClearFilters() end)
    assertEqual((B.activeFilter.store or {}).BANK, true, "History's Clear missed its own saved view")
    assertEqual(B.activeFilter.quality, nil, "History's Clear applied Insights' saved view")
    assertTrue(dd.quality._selected[4] == nil, "the bar shows Insights' quality on History")
  end)
end)

test("Per-tab views: switching tabs restores each tab's live state exactly", function()
  -- Filters, date, search, group, sort AND the character scope each come back as the player left
  -- them on that tab. red under: one shared live filter (the Insights edits show on History).
  withTabs(function(dd)
    muted(function()
      B:ApplyView({ groupBy = "store", sortKey = "qty", sortAsc = true, store = { BANK = true },
                    date = "7d", search = "linen" }, "all")
      B:SelectTab("Insights")
    end)
    assertEqual(B.activeFilter.store, nil, "Insights opened on History's live filter")
    assertEqual(B._search:GetText(), "", "Insights opened on History's search text")
    assertEqual((B.activeFilter.char or {})[NS.Util.PlayerKey()], true,
      "an unvisited tab opens scoped to the current character")
    muted(function()
      B:ApplyView({ groupBy = "day", quality = { [3] = true }, search = "silk" },
        { ["Alt-Realm"] = true })
      B:SelectTab("History")
    end)
    assertEqual(NS.LedgerTable.groupBy, "store")
    assertEqual(NS.LedgerTable.sortKey, "qty")
    assertEqual(NS.LedgerTable.sortAsc, true)
    assertEqual(dd.store._selected.BANK, true)
    assertEqual(dd.quality._selected[3], nil, "Insights' quality leaked onto History")
    assertEqual(dd.date._value, "7d")
    assertEqual(B._search:GetText(), "linen")
    assertEqual((B.activeFilter.store or {}).BANK, true)
    assertEqual(B.activeFilter.text, "linen")
    assertEqual(B.activeFilter.char, nil, "History's All scope was not restored")
    muted(function() B:SelectTab("Insights") end)
    assertEqual(NS.LedgerTable.groupBy, "day")
    assertEqual(dd.quality._selected[3], true)
    assertEqual(dd.store._selected.BANK, nil, "History's store leaked onto Insights")
    assertEqual(B.activeFilter.text, "silk")
    assertEqual((B.activeFilter.char or {})["Alt-Realm"], true, "Insights' character scope was lost")
    assertEqual((B.activeFilter.char or {})[NS.Util.PlayerKey()], nil)
  end)
end)

test("Per-tab views: a tab's first visit opens on its own saved view", function()
  -- red under: the unvisited tab inheriting the outgoing tab's live state or saved view.
  withTabs(function()
    NS.db.profile.savedViews = { Insights = { groupBy = "day", quality = { [4] = true } } }
    muted(function()
      B:ClearAllTabs()
      B:ApplyView({ store = { BANK = true } }, "current")
      B:SelectTab("Insights")
    end)
    assertEqual((B.activeFilter.quality or {})[4], true, "Insights did not open on its saved view")
    assertEqual(B.activeFilter.store, nil, "Insights opened on History's live state")
    assertEqual(NS.LedgerTable.groupBy, "day")
  end)
end)

test("Per-tab views: a profile event drops every tab's live state onto the new profile's views", function()
  -- NS.OnProfileEvent repaints through B:ClearAllTabs, so the tab off screen does not come back
  -- on a live state captured under the old profile. red under: NS.OnProfileEvent calling only
  -- B:ClearFilters (the Insights stash survives the profile change).
  withTabs(function()
    muted(function()
      B:SelectTab("Insights")
      B:ApplyView({ store = { BANK = true } }, "current")
      B:SelectTab("History")
      NS.OnProfileEvent("OnProfileChanged")
      B:SelectTab("Insights")
    end)
    assertEqual(B.activeFilter.store, nil, "Insights came back on a live state the profile change discarded")
  end)
end)

test("Per-tab views: a tab switch paints the incoming pane once, not twice", function()
  -- SwapTabState's ApplyView already repaints the incoming tab; SelectTab painting it again was a
  -- second full query (History) or Stats pass (Insights) per switch (BL-R-03). The History filter
  -- options are still rebuilt on the way in.
  -- red under: SelectTab refreshing the incoming pane on a real switch.
  withTabs(function()
    local ins, lt, opts = 0, 0, 0
    local realIns, realLt, realOpts = NS.Insights.Refresh, NS.LedgerTable.Refresh, B.RefreshFilterOptions
    NS.Insights.Refresh = function(...) ins = ins + 1; return realIns(...) end
    NS.LedgerTable.Refresh = function(...) lt = lt + 1; return realLt(...) end
    B.RefreshFilterOptions = function(...) opts = opts + 1; return realOpts(...) end
    local insOnSwitch, ltOnSwitch
    local ok, err = pcall(function()
      muted(function() B:SelectTab("Insights") end)
      insOnSwitch = ins
      lt, opts = 0, 0
      muted(function() B:SelectTab("History") end)
      ltOnSwitch = lt
    end)
    NS.Insights.Refresh, NS.LedgerTable.Refresh, B.RefreshFilterOptions = realIns, realLt, realOpts
    if not ok then error(err, 0) end
    assertTrue(insOnSwitch <= 1, "Insights painted " .. tostring(insOnSwitch) .. " times on one switch")
    assertTrue(ltOnSwitch <= 1, "History's table painted " .. tostring(ltOnSwitch) .. " times on one switch")
    assertTrue(opts >= 1, "the History filter options were not rebuilt on the way in")
  end)
end)

test("Per-tab views: Save and Reset name the tab as a printer argument, same line as ever", function()
  -- events-frames-taint-§8 (BL-A-05): the tab rides as its own argument, not a pre-formatted string.
  withTabs(function()
    local lines = {}
    local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
    mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) lines[#lines + 1] = msg end
    local ok, err = pcall(function()
      B:SaveView()
      B:ResetView()
    end)
    mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
    if not ok then error(err, 0) end
    assertEqual(lines[1], NS.PREFIX .. " History view saved as your default.")
    assertEqual(lines[2], NS.PREFIX .. " History view reset to stock defaults.")
  end)
end)
