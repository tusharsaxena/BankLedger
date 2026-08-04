local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local mocks = T.mocks
local B = NS.Browser
-- The Character dropdown's "Current" sentinel, as Browser.lua defines it. Duplicated here on
-- purpose: if the sentinel ever changes shape, this suite must fail rather than follow it silently.
local CURRENT = "\001current"

-- ── Character filter resolution ────────────────────────────────────────────────

test("Browser.ResolveCharFilter resolves the Current sentinel to the logged-in character", function()
  local got = B.ResolveCharFilter({ [CURRENT] = true }, "Mock-Realm")
  assertEqual(got["Mock-Realm"], true)
  assertEqual(got[CURRENT], nil, "the sentinel never reaches the query")
end)

test("Browser.ResolveCharFilter passes ordinary character keys through", function()
  local got = B.ResolveCharFilter({ ["Alt-Realm"] = true }, "Mock-Realm")
  assertEqual(got["Alt-Realm"], true)
  assertEqual(got["Mock-Realm"], nil)
end)

test("Browser.ResolveCharFilter mixes the sentinel with explicit names", function()
  local got = B.ResolveCharFilter({ [CURRENT] = true, ["Alt-Realm"] = true }, "Mock-Realm")
  assertEqual(got["Mock-Realm"], true)
  assertEqual(got["Alt-Realm"], true)
end)

test("Browser.ResolveCharFilter collapses the sentinel onto the same name once", function()
  -- Picking both "Current" and the logged-in character by name is one filter value, not two.
  local got = B.ResolveCharFilter({ [CURRENT] = true, ["Mock-Realm"] = true }, "Mock-Realm")
  local n = 0
  for _ in pairs(got) do n = n + 1 end
  assertEqual(n, 1)
end)

test("Browser.ResolveCharFilter returns nil for an empty selection (no filter)", function()
  assertEqual(B.ResolveCharFilter({}, "Mock-Realm"), nil)
  assertEqual(B.ResolveCharFilter(nil, "Mock-Realm"), nil)
end)

test("Browser.ResolveCharFilter falls back to the live player key", function()
  -- Production passes no key; the mock player is Mock-Realm (UnitName + GetNormalizedRealmName).
  assertEqual(B.ResolveCharFilter({ [CURRENT] = true })[NS.Util.PlayerKey()], true)
end)

test("Browser.ResolveCharFilter copies the set rather than aliasing it", function()
  local live = { ["Alt-Realm"] = true }
  local got = B.ResolveCharFilter(live, "Mock-Realm")
  live["Another-Realm"] = true   -- a later dropdown toggle must not reach the applied filter
  assertEqual(got["Another-Realm"], nil)
end)

-- ── Default filter state ───────────────────────────────────────────────────────

-- ClearFilters pushes through to the table, so park and restore the shared filter around each case.
local function withCleanFilter(fn)
  local saved, savedActive = NS.LedgerTable.filter, B.activeFilter
  local ok, err = pcall(fn)
  NS.LedgerTable.filter, B.activeFilter = saved, savedActive
  if not ok then error(err, 0) end
end

test("Browser:ClearFilters defaults the Character filter to the current character", function()
  -- The window opens scoped to you, on a fresh install and after a reset alike.
  withCleanFilter(function()
    B:ClearFilters()
    assertEqual((B.activeFilter.char or {})[NS.Util.PlayerKey()], true)
  end)
end)

test("Browser:ClearFilters leaves every other filter empty", function()
  withCleanFilter(function()
    B.activeFilter = { store = { BANK = true }, text = "cloth" }
    B:ClearFilters()
    assertEqual(B.activeFilter.store, nil)
    assertEqual(B.activeFilter.text, nil)
  end)
end)

test("Browser:ClearFilters does not scope test data to the real player", function()
  -- The test dataset is synthetic alts; defaulting to Current would open onto an empty table.
  withCleanFilter(function()
    -- Set the DATASET, not a flag beside it: test mode is derived from State.testRecords, so this
    -- is the only way to be in test mode and there is nothing left that can disagree with it.
    local saved = NS.State.testRecords
    NS.State.testRecords = { { kind = "ITEM" } }
    local ok, err = pcall(function()
      B:ClearFilters()
      assertEqual(B.activeFilter.char, nil, "test mode starts unscoped")
    end)
    NS.State.testRecords = saved
    if not ok then error(err, 0) end
  end)
end)

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

-- Run `fn` against a fake bar and a parked saved view, restoring the real ones (and the shared
-- filter) whether it passes or throws.
local function withFakeBar(fn)
  local savedDd, savedSearch = B._dd, B._search
  local savedView = NS.db.global.savedView
  local savedGroup, savedSort, savedAsc =
    NS.LedgerTable.groupBy, NS.LedgerTable.sortKey, NS.LedgerTable.sortAsc
  local dd = {}
  for _, k in ipairs({ "group", "date", "direction", "store", "quality", "type", "subtype", "char" }) do
    dd[k] = fakeDropdown()
  end
  B._dd, B._search = dd, fakeSearch()
  NS.db.global.savedView = nil
  local ok, err = pcall(function() withCleanFilter(function() fn(dd) end) end)
  B._dd, B._search = savedDd, savedSearch
  NS.db.global.savedView = savedView
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
    NS.db.global.savedView = "not a table"
    assertEqual(B._savedViewOrStock(), B._STOCK_VIEW, "a scalar is not a view")
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

test("Browser:ResetView drops the saved view, and Clear then lands on stock", function()
  withFakeBar(function(dd)
    NS.LedgerTable.groupBy = "store"
    dd.store:SetSelected({ BANK = true })
    B:SaveView()
    B:ResetView(true)

    assertEqual(NS.db.global.savedView, nil, "the saved view is gone from storage")
    assertEqual(NS.LedgerTable.groupBy, "none")
    assertEqual(B.activeFilter.store, nil)
    assertEqual(B._savedViewOrStock(), B._STOCK_VIEW)

    dd.store:SetSelected({ BANK = true })
    B:ClearFilters()
    assertEqual(B.activeFilter.store, nil, "Clear now lands on stock again")
  end)
end)

-- Regression: CaptureView's return is written verbatim to NS.db.global.savedView, so its SHAPE is a
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
    assertEqual(NS.db.global.savedView.store.GUILD_BANK, nil)
  end)
end)

test("Browser: a saved date range is stored as the OPTION, not a resolved timestamp", function()
  -- A frozen `from` would mean "the week ending whenever I pressed Save"; the option recomputes
  -- against each session's clock.
  withFakeBar(function(dd)
    dd.date:SelectValue("7d")
    B:SaveView()
    assertEqual(NS.db.global.savedView.date, "7d")
    assertEqual(NS.db.global.savedView.from, nil)
  end)
end)

test("Browser:ApplyView tolerates a scalar filter value in a stored view", function()
  withFakeBar(function(dd)
    B:ApplyView({ store = "BANK" }, "current")
    assertEqual(dd.store._selected.BANK, true)
    assertEqual((B.activeFilter.store or {}).BANK, true)
  end)
end)

test("Slash:CliResetAll also discards the saved view", function()
  withFakeBar(function(dd)
    dd.store:SetSelected({ BANK = true })
    B:SaveView()
    NS.Slash:CliResetAll()
    assertEqual(NS.db.global.savedView, nil)
  end)
end)

-- ── Toolbar geometry ───────────────────────────────────────────────────────────

test("Browser:MinWidth fits every table column and the whole toolbar", function()
  assertTrue(B:MinWidth() >= NS.LedgerTable:MinFrameWidth(),
    "the window floor must clear the column floor")
end)

-- ── Window geometry (the same exposure the session window had) ─────────────────
-- Saving only at the end of a drag or a resize means the geometry can live purely in the frame,
-- which outlives every Hide/Show — so it looks persistent for a whole game session and is gone on
-- the first /reload. Both windows anchor the save to guaranteed moments instead.

test("Browser:SaveGeometry writes the live position and size", function()
  NS.db.global.settings.window = {}
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", T.mocks.UIParent, "TOPLEFT", 77, -88)
  f:SetSize(1000, 700)
  NS.Browser:SaveGeometry()
  local saved = NS.db.global.settings.window
  assertEqual(saved.point, "TOPLEFT")
  assertEqual(saved.x, 77)
  assertEqual(saved.y, -88)
  assertEqual(saved.w, 1000)
  assertEqual(saved.h, 700)
  NS.Browser:Hide()
end)

test("Browser:ApplyGeometry restores a saved position and size", function()
  NS.db.global.settings.window = { point = "BOTTOMLEFT", x = 15, y = 25, w = 1100, h = 720 }
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  f:ClearAllPoints()
  f:SetSize(0, 0)
  NS.Browser:ApplyGeometry()
  local point, _, _, x, y = f:GetPoint(1)
  assertEqual(point, "BOTTOMLEFT")
  assertEqual(x, 15)
  assertEqual(y, 25)
  assertEqual(f:GetWidth(), 1100)
  NS.Browser:Hide()
end)

test("Browser:ApplyGeometry never restores a size below the window floor", function()
  NS.db.global.settings.window = { point = "CENTER", x = 0, y = 0, w = 10, h = 10 }
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  NS.Browser:ApplyGeometry()
  assertEqual(f:GetWidth(), NS.Browser:MinWidth(), "a too-narrow saved width clamps to the floor")
  NS.Browser:Hide()
end)

test("Browser:SaveGeometry refuses to write a point-less table", function()
  -- Writing one would make ApplyGeometry fall through to the default and silently discard a real
  -- position the next time the window opened.
  NS.db.global.settings.window = { point = "TOPLEFT", x = 5, y = -5, w = 1000, h = 600 }
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  f:ClearAllPoints()
  assertFalse(NS.Browser:SaveGeometry(), "an unanchored frame has nothing worth saving")
  assertEqual(NS.db.global.settings.window.point, "TOPLEFT", "the last good value survives")
  NS.Browser:Hide()
end)

test("the ledger window saves its geometry when it hides", function()
  NS.db.global.settings.window = {}
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", T.mocks.UIParent, "TOPLEFT", 111, -222)
  f:SetSize(980, 640)
  NS.Browser:Hide()
  local saved = NS.db.global.settings.window
  assertEqual(saved.point, "TOPLEFT", "closing the window persisted the position")
  assertEqual(saved.x, 111)
  assertEqual(saved.w, 980)
end)

test("the ledger window saves its geometry at logout", function()
  NS.db.global.settings.window = {}
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  f:ClearAllPoints()
  f:SetPoint("CENTER", T.mocks.UIParent, "CENTER", 9, 19)
  f:SetSize(960, 620)
  NS.Browser:OnLogout()
  assertEqual(NS.db.global.settings.window.x, 9)
  assertEqual(NS.db.global.settings.window.y, 19)
  NS.Browser:Hide()
end)

test("Browser:ExportWidth leaves the Export button a usable width", function()
  -- The filter dropdowns grew; Export takes the slack and must not collapse to nothing.
  assertTrue(B:ExportWidth() >= 110, "got " .. B:ExportWidth())
end)

-- ── Coalescing ─────────────────────────────────────────────────────────────────
-- Both of these count how many times the expensive work actually ran. The filter path is spied at
-- LedgerTable:SetFilter, which is the first thing an application does.

local function countingFilter(fn)
  local calls, saved = 0, NS.LedgerTable.SetFilter
  NS.LedgerTable.SetFilter = function() calls = calls + 1 end
  local ok, err = pcall(fn, function() return calls end)
  NS.LedgerTable.SetFilter = saved
  if not ok then error(err, 0) end
  return calls
end

test("Browser: a burst of search keystrokes costs ONE filter application", function()
  -- F-004: OnTextChanged fires per character, and each application is a full Database:Query plus,
  -- on Insights, a full Database:Stats. Typing "linen" paid for five.
  local duringTyping
  local total = countingFilter(function(count)
    mocks.__timers = {}
    B:ScheduleApplyFilter()
    B:ScheduleApplyFilter()
    B:ScheduleApplyFilter()
    B:ScheduleApplyFilter()
    B:ScheduleApplyFilter()
    duringTyping = count()
    mocks.__fireTimers()
  end)
  assertEqual(duringTyping, 0, "nothing recomputed while the user is still typing")
  assertEqual(total, 1, "five keystrokes, one recompute")
end)

test("Browser: the debounced filter still applies when there is no timer library", function()
  -- Headless, and any load order where AceTimer is missing: dropping the edit silently would be
  -- far worse than paying for it inline.
  local saved = NS.addon
  local total = countingFilter(function()
    NS.addon = nil
    B:ScheduleApplyFilter()
  end)
  NS.addon = saved
  assertEqual(total, 1, "applied inline rather than dropped")
end)

test("Browser: a 20-stack deposit repaints the window once, not twenty times", function()
  -- F-005: EntryAdded is one message per moved stack, and each one drove a full OnLedgerChanged.
  local calls, saved = 0, B.OnLedgerChanged
  B.OnLedgerChanged = function() calls = calls + 1 end
  mocks.__timers = {}
  for _ = 1, 20 do B:ScheduleLedgerRefresh() end
  local duringDeposit = calls
  mocks.__fireTimers()
  B.OnLedgerChanged = saved
  assertEqual(duringDeposit, 0, "no repaint mid-burst")
  assertEqual(calls, 1, "twenty entries, one repaint")
end)

-- ── Filter ownership ───────────────────────────────────────────────────────────

test("Browser hands the table a filter COPY, not its own mutable one", function()
  -- F-013: the table held a live reference to Browser.activeFilter, so a later dropdown toggle
  -- reached the table's filter before ApplyFilter ran — the table could paint under criteria that
  -- had never been applied. Insights already got a copy; both consumers now get the same guarantee.
  withCleanFilter(function()
    local captured
    local saved = NS.LedgerTable.SetFilter
    NS.LedgerTable.SetFilter = function(_, f) captured = f end
    local ok, err = pcall(function()
      B.activeFilter = { store = { BANK = true } }
      B:ApplyFilterNow()
    end)
    NS.LedgerTable.SetFilter = saved
    if not ok then error(err, 0) end
    assertTrue(captured ~= nil, "the table was handed a filter")
    assertTrue(captured ~= B.activeFilter, "and it is not the Browser's own table")
    B.activeFilter.text = "typed after applying"
    assertEqual(captured.text, nil, "a later edit cannot reach an already-applied filter")
  end)
end)

-- ── The shared dropdown menu ───────────────────────────────────────────────────
--
-- The popup every dropdown drops is one shared frame behind two file-locals (the singleton and
-- EnsureMenu), so the only way in is the way the game takes: build a real dropdown and fire its
-- OnClick. The menu is the first frame that call creates, and the kit collects every suite before
-- it runs any case, so nothing else can have opened a dropdown first — the assert in the first
-- case below is what fails if that ever stops being true.
local MENU
do
  local dd = B:MakeDropdown(mocks.UIParent, 110)
  dd:SetMulti(true)
  dd:SetOptions({})   -- empty: the width loop is what needs the measuring stub installed below
  local made, realCreateFrame = {}, mocks.CreateFrame
  mocks.CreateFrame = function(...)
    local f = realCreateFrame(...)
    made[#made + 1] = f
    return f
  end
  dd:__fire("OnClick")
  mocks.CreateFrame = realCreateFrame
  MENU = made[1]
  -- The mock's CreateFontString hands back the frame itself, so the real measuring FontString
  -- reports a table rather than a width and the width loop would raise on the first option. Stand
  -- in a stub that measures 6px per character: the widths asserted below are that stub's
  -- arithmetic, and what is being pinned is the +pad / cap / floor rules around it.
  if MENU then
    MENU.measure = {
      SetText = function(self, t) self._t = t or "" end,
      GetStringWidth = function(self) return #(self._t or "") * 6 end,
      Hide = function() end,
    }
  end
end

-- The tick markup Populate prefixes to a selected multi-select row, as Browser.lua spells it.
-- Duplicated here on purpose, like the Character sentinel above: if the markup changes shape this
-- suite must fail rather than follow it silently.
local CHECK = "|TInterface\\Buttons\\UI-CheckBox-Check:0|t "

-- A recording stand-in for a row's FontString. The mock resolves every FontString to its own frame,
-- which conflates a row's label, its glyph and the button itself; these keep the three apart so the
-- paint rules are observable at all.
local function fakeFS()
  local r = { points = {} }
  function r:SetText(t) self.text = t end
  function r:SetTextColor(a, b, c) self.color = { a, b, c } end
  function r:SetShown(v) self.shown = v and true or false end
  function r:ClearAllPoints() self.points = {} end
  function r:SetPoint(p, x, y) self.points[#self.points + 1] = { p, x, y } end
  return r
end

-- A recording stand-in for a pooled row button.
local function fakeRow()
  local b = { fs = fakeFS(), glyph = fakeFS(), points = {}, scripts = {} }
  function b:SetWidth(w) self.width = w end
  function b:ClearAllPoints() self.points = {} end
  function b:SetPoint(p, x, y) self.points[#self.points + 1] = { p, x, y } end
  function b:SetScript(k, fn) self.scripts[k] = fn end
  function b:Show() self.shown = true end
  function b:Hide() self.shown = false end
  return b
end

-- Seed `n` recording rows into the shared pool, then populate it. Seeding is not a shortcut: rows
-- are pooled on the menu and reused across dropdowns, so this IS the path every dropdown after the
-- first one takes, and it is the one that can leak a stale glyph or color.
local function populate(dd, opts, n)
  dd:SetOptions(opts)
  MENU.buttons = {}
  for i = 1, (n or #opts) do MENU.buttons[i] = fakeRow() end
  MENU:Populate(dd)
  return MENU.buttons
end

-- The mock resolves CreateTexture to the frame itself, so the dropdown's 12x12 arrow overwrites the
-- button's own size on the way out of MakeDropdown. Re-assert the width after building, or every
-- dropdown reports 12px wide and the "never narrower than its own button" rule is unobservable.
local function menuDropdown(multi, width)
  local dd = B:MakeDropdown(mocks.UIParent, width or 110)
  dd:SetWidth(width or 110)
  dd:SetMulti(multi)
  return dd
end

local MENU_OPTS = {
  { value = "all", label = "All" },
  { value = "BANK", label = "Bank", color = { 0.4, 0.6, 1 } },
  { value = "GUILD_BANK", label = "Guild", glyph = "\226\150\178" },
}

test("Browser menu: Populate shows one row per option and sizes the menu to them", function()
  assertTrue(MENU ~= nil and MENU.buttons ~= nil, "the shared menu was captured on its first open")
  local dd = menuDropdown(true)
  local rows = populate(dd, MENU_OPTS)
  assertEqual(#MENU.buttons, 3)
  for i = 1, 3 do
    assertEqual(rows[i].shown, true, "row " .. i .. " is shown")
    assertEqual(rows[i].width, MENU.__w, "every row spans the menu")
    assertEqual(rows[i].points[1][1], "TOPLEFT")
    assertEqual(rows[i].points[1][3], -4 - (i - 1) * 16, "rows stack on a 16px pitch")
  end
  assertEqual(MENU.__h, 3 * 16 + 8, "height is the rows plus the 4px inset top and bottom")
end)

test("Browser menu: a freak label is capped at 320px", function()
  local dd = menuDropdown(false)
  populate(dd, { { value = "x", label = string.rep("W", 200) } })
  assertEqual(MENU.__w, 320)
end)

test("Browser menu: the menu is never narrower than 90px, nor than its own dropdown", function()
  local narrow = menuDropdown(false, 40)
  populate(narrow, { { value = "x", label = "A" } })
  assertEqual(MENU.__w, 90, "the floor holds even under a 40px dropdown")

  local wide = menuDropdown(false, 200)
  populate(wide, { { value = "x", label = "A" } })
  assertEqual(MENU.__w, 200, "and it never undercuts the button it drops from")
end)

test("Browser menu: rows are POOLED — a shorter dropdown hides the spares, never rebuilds", function()
  local dd = menuDropdown(true)
  local rows = populate(dd, { MENU_OPTS[1], MENU_OPTS[2] }, 3)
  assertEqual(#MENU.buttons, 3, "the third row is kept for the next dropdown")
  assertEqual(rows[3].shown, false, "and it is hidden rather than left on screen")
end)

test("Browser menu: multi-select ticks 'all' exactly when nothing is selected", function()
  local dd = menuDropdown(true)
  local rows = populate(dd, MENU_OPTS)
  assertEqual(rows[1].fs.text, CHECK .. "All", "an empty set IS 'All'")
  assertEqual(rows[2].fs.text, "Bank")

  dd:SetSelected({ BANK = true })
  rows = populate(dd, MENU_OPTS)
  assertEqual(rows[1].fs.text, "All", "'all' loses its tick once a real value is picked")
  assertEqual(rows[2].fs.text, CHECK .. "Bank")
end)

test("Browser menu: single-select marks the active value and never draws a tick", function()
  local dd = menuDropdown(false)
  dd._value = "BANK"
  local rows = populate(dd, MENU_OPTS)
  assertEqual(rows[2].fs.text, "Bank", "no tick markup on a single-select menu")
  assertEqual(rows[2].fs.color[1], 1, "the active value still goes gold")
  assertEqual(rows[2].fs.color[2], 0.82)
end)

test("Browser menu: selected rows go gold, the rest keep the value's own color", function()
  local dd = menuDropdown(true)
  local rows = populate(dd, MENU_OPTS)
  assertEqual(rows[1].fs.color[1], 1, "the selected row is gold")
  assertEqual(rows[1].fs.color[2], 0.82)
  assertEqual(rows[2].fs.color[1], 0.4, "an unselected row keeps its store/direction/class color")
  assertEqual(rows[3].fs.color[1], 0.9, "and a colorless one falls back to gray")
end)

test("Browser menu: a glyphed row shows its glyph and indents its text past it", function()
  local dd = menuDropdown(true)
  local rows = populate(dd, MENU_OPTS)
  assertEqual(rows[3].glyph.text, "\226\150\178")
  assertEqual(rows[3].glyph.shown, true)
  assertEqual(rows[3].fs.points[1][2], 22, "the label clears the glyph")
  assertEqual(rows[2].glyph.text, "", "a glyphless row is repainted blank, not left stale")
  assertEqual(rows[2].glyph.shown, false)
  assertEqual(rows[2].fs.points[1][2], 8, "and starts at the margin")
end)

test("Browser menu: clicking a multi-select row toggles it and leaves the menu open", function()
  local dd = menuDropdown(true)
  local reported
  dd.onMultiSelect = function(set) reported = set end
  local rows = populate(dd, MENU_OPTS)
  MENU:Show()
  rows[2].scripts.OnClick()
  assertEqual(dd._selected.BANK, true)
  assertEqual(MENU:IsShown(), true, "several values can be picked in one visit")
  assertEqual((reported or {}).BANK, true, "the owner is told about the new set")
end)

test("Browser menu: clicking a single-select row sets the value and closes the menu", function()
  local dd = menuDropdown(false)
  local reported
  dd.onSelect = function(v) reported = v end
  local rows = populate(dd, MENU_OPTS)
  MENU:Show()
  rows[2].scripts.OnClick()
  assertEqual(dd._value, "BANK")
  assertEqual(MENU:IsShown(), false)
  assertEqual(reported, "BANK")
end)
