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

-- The regression this addon shipped once: the popup menu is LibKa0s-Widgets-1.0's process-wide
-- singleton, parented to UIParent rather than to this window, so this window's own Hide/OnHide
-- cannot reach it on its own. modules/Browser.lua must call W.CloseMenu() from every place it
-- closes the window by a route other than a click on the dropdown itself, or a menu left open by
-- Escape or a slash command orphans over the game. Caught here by opening the real shared menu
-- (a genuine click, not a stand-in) and watching W.CloseMenu() actually reach it through B:Hide().
test("the ledger window closes an open dropdown menu when it hides", function()
  NS.Browser:Show()
  local dd = B._dd and B._dd.group
  assertTrue(dd ~= nil, "the group dropdown exists once the filter bar is built")
  local onClick = dd:GetScript("OnClick")
  assertTrue(onClick ~= nil, "the dropdown wires an OnClick that opens the shared menu")

  -- The shared menu is a file-local inside Widgets.lua with no handle exposed to a host; capture
  -- the frame the click builds by spying on CreateFrame for the duration of the click, the same
  -- way the library's own suite captures it.
  --
  -- GetStringWidth used to be forced sane on every frame minted here, because the shared mock's
  -- catch-all answered it with the frame itself and the popup's row-width math then added a number
  -- to a table. It is a real stub on the FontString now (tests/wow_mock.lua), so the spy only
  -- captures.
  local realCreateFrame = mocks.CreateFrame
  local capturedMenu
  mocks.CreateFrame = function(...)
    local f = realCreateFrame(...)
    if not capturedMenu then capturedMenu = f end
    return f
  end
  local ok, err = pcall(onClick, dd)
  mocks.CreateFrame = realCreateFrame
  if not ok then error(err, 0) end

  assertTrue(capturedMenu ~= nil, "the click built (or reused) the shared popup menu")
  assertTrue(capturedMenu:IsShown(), "opening the dropdown showed the shared menu")

  NS.Browser:Hide()
  assertFalse(capturedMenu:IsShown(), "hiding the window closed the menu via W.CloseMenu()")
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

-- ── The dropdown forwarder ────────────────────────────────────────
--
-- The widget itself is LibKa0s-Widgets-1.0's now, and its behaviour is asserted in that repo's
-- tests/test_widgets.lua -- the cases that used to sit here moved there verbatim. What is still this
-- addon's is the INJECTION: three resolved paths that only a host can produce, because the library
-- builds a path from an addon name it does not have. Getting one of them wrong draws nothing and
-- raises nothing, which is the failure this addon's mark suite exists for.

-- A spy on W.Dropdown, not a read of dropdown internals: the library's own docs (see
-- ../LibKa0s/docs/api/Widgets/version-2-docs.md, "`__`-prefixed instance fields are INTERNAL")
-- say a host may not read `dd.__check` / `dd.__glyphFont` — that is the suite exercising the
-- library from the inside, not a precedent this host gets to borrow. Wrapping the constructor and
-- capturing the `opts` table MakeDropdown hands it tests exactly what the forwarder exists to do —
-- which host-resolved paths it injects — without reaching past the published surface to check it.
local function spyOnDropdown(fn)
  local Widgets = T.mocks.LibStub("LibKa0s-Widgets-1.0", true)
  local realDropdown = Widgets.Dropdown
  local capturedOpts
  Widgets.Dropdown = function(parent, width, opts)
    capturedOpts = opts
    return realDropdown(parent, width, opts)
  end
  local ok, err = pcall(fn)
  Widgets.Dropdown = realDropdown
  if not ok then error(err, 0) end
  return capturedOpts
end

test("Browser: MakeDropdown injects this addon's chevron, tick and mono face", function()
  local dd
  local capturedOpts = spyOnDropdown(function()
    dd = B:MakeDropdown(mocks.UIParent, 110)
  end)
  assertTrue(dd ~= nil, "MakeDropdown built a dropdown")
  assertTrue(capturedOpts ~= nil, "MakeDropdown called W.Dropdown")
  assertEqual(capturedOpts.chevron, NS.Icon("chevron-down"),
    "the collapsed button is handed the collection's chevron")
  assertEqual(capturedOpts.check, NS.Icon("confirm"),
    "and a multi-select row's tick is handed the collection's check glyph")
  assertEqual(capturedOpts.glyphFont, NS.Constants.FONT_MONO,
    "the direction glyph is handed the face that actually has the character")
end)

test("Browser: MakeDropdown still hands back a working dropdown with no LibKa0s art", function()
  -- The rung below. Red under: a forwarder that concatenates a nil into a path.
  local realIcon = NS.Icon
  NS.Icon = function() return nil end
  local dd
  local capturedOpts = spyOnDropdown(function()
    dd = B:MakeDropdown(mocks.UIParent, 110)
  end)
  NS.Icon = realIcon
  assertEqual(capturedOpts.chevron, nil, "no chevron path is handed over when this addon has no art")
  assertEqual(dd.arrow.__texture, "Interface\\Buttons\\Arrow-Down-Up",
    "the library falls back to Blizzard's own arrow — dd.arrow is a documented, host-readable field")
end)

-- ── Degraded: LibKa0s-Widgets-1.0 absent ────────────────────────────────
--
-- Spec §10: seven controls that open nothing is a browser that looks broken, so the filter bar refuses
-- to draw rather than build them. A fully isolated environment, loaded with every LibKa0s major
-- EXCEPT Widgets -- the actual shape of "the vendored copy's NEEDS_CORE floor is unmet" or "the file
-- was never copied in" -- is the only honest way to exercise the branch that runs in that install,
-- the same reasoning test_libka0s.lua's own degraded cases already rest on.

local function loadWithoutWidgets()
  local m = T.makeMocks()
  local ns = {}
  local files = {}
  for _, path in ipairs(T.libka0sFiles) do
    if path ~= "libs/LibKa0s/Widgets.lua" then files[#files + 1] = path end
  end
  T.Loader.loadAll(files, ns, m)
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  ns:InitDB()
  ns.Schema:Register()
  ns.Ledger:Enable()
  return ns, m
end

test("Browser: the window still opens and the ledger table still populates with no Widgets library",
  function()
    local ns, m = loadWithoutWidgets()
    assertTrue(m.LibStub("LibKa0s-Widgets-1.0", true) == nil, "the degraded arm still has the library")
    ns.Database:Add({
      ts = 1770000000, char = "Mock-Realm", classFile = "MAGE",
      kind = "ITEM", direction = "DEPOSIT", store = "BANK",
      itemID = 2589, itemName = "Linen Cloth", quality = 1,
      itemType = "Tradegoods", itemSubType = "Cloth",
      quantity = 10, zone = "Testville", mapID = 2657,
    })
    local ok, err = pcall(function() ns.Browser:Show() end)
    assertTrue(ok, "opening the browser must not error with no dropdown widget: " .. tostring(err))
    assertTrue(ns.Browser:GetWindow():IsShown(), "the ledger window still opens")
    assertEqual(ns.LedgerTable.matchCount, 1, "the table underneath still queries and populates")
    ns.Browser:Hide()
  end)
