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
  NS.db.profile.settings.window = {}
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", T.mocks.UIParent, "TOPLEFT", 77, -88)
  f:SetSize(1000, 700)
  NS.Browser:SaveGeometry()
  local saved = NS.db.profile.settings.window
  assertEqual(saved.point, "TOPLEFT")
  assertEqual(saved.x, 77)
  assertEqual(saved.y, -88)
  assertEqual(saved.w, 1000)
  assertEqual(saved.h, 700)
  NS.Browser:Hide()
end)

test("Browser:ApplyGeometry restores a saved position and size", function()
  NS.db.profile.settings.window = { point = "BOTTOMLEFT", x = 15, y = 25, w = 1100, h = 720 }
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
  NS.db.profile.settings.window = { point = "CENTER", x = 0, y = 0, w = 10, h = 10 }
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  NS.Browser:ApplyGeometry()
  assertEqual(f:GetWidth(), NS.Browser:MinWidth(), "a too-narrow saved width clamps to the floor")
  NS.Browser:Hide()
end)

test("Browser:SaveGeometry refuses to write a point-less table", function()
  -- Writing one would make ApplyGeometry fall through to the default and silently discard a real
  -- position the next time the window opened.
  NS.db.profile.settings.window = { point = "TOPLEFT", x = 5, y = -5, w = 1000, h = 600 }
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  f:ClearAllPoints()
  assertFalse(NS.Browser:SaveGeometry(), "an unanchored frame has nothing worth saving")
  assertEqual(NS.db.profile.settings.window.point, "TOPLEFT", "the last good value survives")
  NS.Browser:Hide()
end)

test("the ledger window saves its geometry when it hides", function()
  NS.db.profile.settings.window = {}
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", T.mocks.UIParent, "TOPLEFT", 111, -222)
  f:SetSize(980, 640)
  NS.Browser:Hide()
  local saved = NS.db.profile.settings.window
  assertEqual(saved.point, "TOPLEFT", "closing the window persisted the position")
  assertEqual(saved.x, 111)
  assertEqual(saved.w, 980)
end)

test("the Group dropdown offers 'Type & SubType' right after Sub-type", function()
  NS.Browser:Show()
  local dd = B._dd and B._dd.group
  assertTrue(dd ~= nil, "the group dropdown exists once the filter bar is built")
  local values, label = {}, nil
  for _, o in ipairs(dd._options or {}) do
    values[#values + 1] = o.value
    if o.value == "typesub" then label = o.label end
  end
  assertEqual(table.concat(values, ","),
    "none,day,store,direction,kind,type,subtype,typesub,quality,char")
  assertEqual(label, "Group: Type & SubType")
  NS.Browser:Hide()
end)

test("the Group dropdown is wide enough for its longest closed label, and Search keeps its floor", function()
  NS.Browser:Show()
  local dd = B._dd and B._dd.group
  assertTrue(dd ~= nil, "the group dropdown exists once the filter bar is built")
  assertEqual(dd:GetWidth(), B._GROUP_W, "Group is built at GROUP_W, not a literal")
  -- The closed label gets the width minus 6 px left and 16 px right (the arrow) and never wraps;
  -- ~6 px a character in GameFontHighlightSmall is the budget every option label must fit.
  local longest = 0
  for _, o in ipairs(dd._options or {}) do longest = math.max(longest, #o.label) end
  assertEqual(longest, #"Group: Type & SubType", "Type & SubType is the longest Group label")
  assertTrue(B._GROUP_W - 22 >= longest * 6,
    "closed label budget " .. (B._GROUP_W - 22) .. " px < " .. longest * 6 .. " px")
  -- Row 1 spans exactly the row-2 dropdowns (Search's right edge is pinned to Character's), so a
  -- wider Group narrows only Search; at the window's minimum width it must keep SEARCH_MIN.
  local searchAtMin = B._DROPDOWNS_W - B._GROUP_W - 8
  assertTrue(searchAtMin >= B._SEARCH_MIN,
    "search at min width " .. searchAtMin .. " < " .. B._SEARCH_MIN)
  NS.Browser:Hide()
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

  -- The shared menu is a file-local inside WidgetsDropdown.lua with no handle exposed to a host; capture
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
  NS.db.profile.settings.window = {}
  NS.Browser:Show()
  local f = NS.Browser:GetWindow()
  f:ClearAllPoints()
  f:SetPoint("CENTER", T.mocks.UIParent, "CENTER", 9, 19)
  f:SetSize(960, 620)
  NS.Browser:OnLogout()
  assertEqual(NS.db.profile.settings.window.x, 9)
  assertEqual(NS.db.profile.settings.window.y, 19)
  NS.Browser:Hide()
end)

-- ── The resize grip (BankLedger#21) ───────────────────────────────────────────
-- Characterization of the grip, written against the hand-built one and kept through the move onto
-- LibKa0s-Core's MakeResizable. What it pins is the CONTRACT, not the art: sizing starts from the
-- bottom-right corner, the floor is the window's minimum, and geometry is written ONCE, on the
-- grip's release. A size change that is not a release — a drag tick, ApplyGeometry, ResetWindow's
-- SetSize — writes nothing (docs/schema.md: ApplyGeometry writes nothing). That is the half a host
-- breaks by wiring its save onto `onResize`, which also runs on every OnSizeChanged; the mock's
-- SetSize never fires OnSizeChanged, so these cases fire it by hand.

-- A fresh, fully loaded addon whose window `frameName` records its SetResizable and SetResizeBounds
-- calls. Fresh because the shared NS built its windows long before this suite ran, and the bounds
-- are set once, at construction. `open` builds the window in that environment.
local function buildRecordingBounds(frameName, open)
  local m = T.makeMocks()
  local seen = {}
  local realCreateFrame = m.CreateFrame
  m.CreateFrame = function(kind, name, ...)
    local f = realCreateFrame(kind, name, ...)
    if name == frameName then
      f.SetResizable = function(self, v) seen.resizable = v; return self end
      f.SetResizeBounds = function(self, ...) seen.bounds = { ... }; return self end
    end
    return f
  end
  local ns = {}
  T.Loader.loadAll(T.libka0sFiles, ns, m)
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  ns:InitDB()
  ns.Schema:Register()
  ns.Ledger:Enable()
  open(ns)
  return ns, seen
end

-- Count calls to `owner[key]` while `fn` runs, calling through, and put the real one back.
local function counting(owner, key, fn)
  local real, n = owner[key], 0
  owner[key] = function(...) n = n + 1; return real(...) end
  local ok, err = pcall(fn)
  owner[key] = real
  if not ok then error(err, 0) end
  return n
end

test("the ledger window's grip sizes from BOTTOMRIGHT and saves geometry on release", function()
  NS.db.profile.settings.window = {}
  B:Show()
  local f = B:GetWindow()
  local grip = f.resizeGrip
  assertTrue(grip ~= nil, "the ledger window has no resize grip")
  local sizedFrom = {}
  f.StartSizing = function(_, point) sizedFrom[#sizedFrom + 1] = point end
  local saves, refreshes
  local ok, err = pcall(function()
    refreshes = counting(NS.LedgerTable, "Refresh", function()
      saves = counting(B, "SaveGeometry", function()
        f:ClearAllPoints()
        f:SetPoint("CENTER", T.mocks.UIParent, "CENTER", 0, 0)
        grip:__fire("OnMouseDown", "LeftButton")
        f:SetSize(1300, 800)
        grip:__fire("OnMouseUp", "LeftButton")
      end)
    end)
  end)
  f.StartSizing = nil
  if not ok then error(err, 0) end
  assertEqual(table.concat(sizedFrom, ","), "BOTTOMRIGHT", "one sizing, from the bottom-right")
  assertEqual(saves, 1, "the release saves geometry exactly once")
  assertEqual(NS.db.profile.settings.window.w, 1300)
  assertEqual(NS.db.profile.settings.window.h, 800)
  assertEqual(refreshes, 1, "the release refreshes the table exactly once")
  B:Hide()
end)

test("the ledger window is resizable with its floor as the minimum bound", function()
  local ns, seen = buildRecordingBounds("BankLedgerWindow", function(ns) ns.Browser:Show() end)
  assertTrue(seen.resizable == true, "the ledger window was never made resizable")
  assertTrue(seen.bounds ~= nil, "the ledger window was never bounded")
  -- Only the first two: the minimum is this window's, and a maximum is whatever the grip adds.
  assertEqual(seen.bounds[1], ns.Browser:MinWidth())
  assertEqual(seen.bounds[2], ns.Browser.SKIN.minH)
  ns.Browser:Hide()
end)

test("a size change outside the grip neither saves nor rebuilds the display list", function()
  NS.db.profile.settings.window = {}
  B:Show()
  local f = B:GetWindow()
  local saves
  local refreshes = counting(NS.LedgerTable, "Refresh", function()
    saves = counting(B, "SaveGeometry", function()
      f:__fire("OnSizeChanged", 1300, 800)
      B:ApplyGeometry()
    end)
  end)
  assertEqual(saves, 0, "a size change wrote geometry")
  assertEqual(refreshes, 0, "a size change rebuilt the display list")
  B:Hide()
end)

test("the footer's size text stays clear of the grip", function()
  B:Show()
  local grip = B:GetWindow().resizeGrip
  local point, _, _, gx = grip:GetPoint(1)
  assertEqual(point, "BOTTOMRIGHT")
  local _, _, _, fx = B._dbFooter:GetPoint(1)
  assertEqual(fx, -20, "the DB-size text moved off its right inset")
  assertTrue(grip:GetWidth() + math.abs(gx) < math.abs(fx),
    "the DB-size text sits under the grip")
  B:Hide()
end)

test("one grip implementation per arm: neither window hand-builds a grip", function()
  -- The grip is core/CoreSetup.lua's NS.MakeResizable on both arms (BankLedger#21): Core's on a
  -- working install, the moved pre-library grip on a degraded one. A window that sized itself again
  -- would be a third implementation, free to drift from both.
  local offenders = {}
  for _, file in ipairs({ "modules/Browser.lua", "modules/Browser_Chrome.lua", "modules/SessionWindow.lua" }) do
    local fh = assert(io.open(file, "r"))
    local src = fh:read("*a"); fh:close()
    for _, needle in ipairs({ "StartSizing(", "SizeGrabber", "SetResizable(", "SetResizeBounds(" }) do
      if src:find(needle, 1, true) then offenders[#offenders + 1] = file .. ": " .. needle end
    end
  end
  assertEqual(table.concat(offenders, ", "), "")
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
  -- The precondition, stated rather than inherited: the debounce refuses to arm while a handle is
  -- outstanding, and an earlier case in the run can leave one queued on a timer list this line is
  -- about to discard. B:CancelPending is the stand-down's own seam for dropping it
  -- (core/BankLedger.lua), which is exactly the act wanted here.
  B:CancelPending()
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
-- The widget itself is LibKa0s-Widgets-1.0's now, and its behavior is asserted in that repo's
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
  assertTrue(dd.arrow.__texture:find("chevron-down", 1, true) ~= nil,
    "an owned dropdown with no host art draws the Ka0s chevron (Widgets minor 18), never the client rung")
end)

-- ── The item-name search box: LibKa0s-Widgets-1.0's SearchBox (LibKa0s#52) ──────────────────
--
-- The box is the library's now, reached through B:MakeSearchBox beside the dropdown's seam. These
-- cases read the PUBLISHED surface back (box.hint, box.icon, the five scripts the constructor sets,
-- the text insets) and the host's own layout; the search, autocomplete and view cases elsewhere in
-- this suite and in tests/test_autocomplete.lua are the unedited characterization of its behavior.

local function spyOnSearchBox(fn)
  local Widgets = T.mocks.LibStub("LibKa0s-Widgets-1.0", true)
  local real = Widgets.SearchBox
  local seen
  Widgets.SearchBox = function(parent, width, opts)
    seen = { parent = parent, width = width, opts = opts }
    return real(parent, width, opts)
  end
  local ok, err = pcall(fn)
  Widgets.SearchBox = real
  if not ok then error(err, 0) end
  return seen
end

test("Browser: MakeSearchBox forwards to W.SearchBox with a COPY of the caller's opts", function()
  local opts = { hint = "Find", icon = NS.Icon("search") }
  local box
  local seen = spyOnSearchBox(function() box = B:MakeSearchBox(mocks.UIParent, opts) end)
  assertTrue(seen ~= nil, "MakeSearchBox never reached W.SearchBox")
  assertTrue(seen.opts ~= opts, "the library was handed the caller's own table")
  assertEqual(seen.opts.hint, "Find")
  assertTrue(box ~= nil and box.hint ~= nil, "no library box came back")
  assertEqual(box.hint:GetText(), "Find")
end)

test("Browser: the filter bar's search box is the library's, with the hint and the magnifier", function()
  local Widgets = T.mocks.LibStub("LibKa0s-Widgets-1.0", true)
  B:Show()
  local box = B._search
  assertTrue(box ~= nil and box.hint ~= nil, "the search box carries no library hint")
  assertEqual(box.hint:GetText(), "Search items\226\128\166")
  assertEqual(box.hint.__template, "GameFontDisableSmall")
  -- A second library box, built with the same icon, answers the same skin values.
  local ref = Widgets.SearchBox(mocks.UIParent, nil, { icon = NS.Icon("search") })
  assertEqual(box.__h, ref.__h, "the search box's height is not the library's")
  assertEqual(table.concat(box.__insets, ","), table.concat(ref.__insets, ","))
  assertEqual(box.__insets[1], 21, "the typed text does not clear the magnifier")
  local _, _, _, hintX = box.hint:GetPoint(1)
  assertEqual(hintX, 21, "the hint does not clear the magnifier")
  assertTrue(box.icon ~= nil, "the magnifier is missing")
  assertEqual(box.icon.__texture, NS.Icon("search"))
  B:Hide()
end)

test("Browser: the search box's border goes gold with the keys and back to gray without them", function()
  B:Show()
  local box = B._search
  local last
  box.SetBackdropBorderColor = function(_, r, g, b, a) last = { r, g, b, a } end
  local ok, err = pcall(function()
    box:__fire("OnEditFocusGained")
    assertEqual(table.concat(last, ","), "1,0.82,0,0.9", "focus did not light the gold line")
    box:__fire("OnEditFocusLost")
    assertEqual(table.concat(last, ","), "0.24,0.24,0.27,0.9", "losing focus left the line gold")
  end)
  box.SetBackdropBorderColor = nil
  B:Hide()
  if not ok then error(err, 0) end
end)

test("Browser: the search box's RIGHT edge is pinned to the Character dropdown", function()
  B:Show()
  local box, char = B._search, B._dd and B._dd.char
  assertTrue(char ~= nil, "no Character dropdown")
  local p1, rel1, rp1, x1 = box:GetPoint(1)
  assertEqual(p1 .. ">" .. rp1, "TOPLEFT>TOPRIGHT")
  assertTrue(rel1 == B._dd.group, "the box's LEFT is not beside the Group dropdown")
  assertEqual(x1, 8)
  local found = false
  for i = 1, #box.__points do
    local p, rel, rp = box:GetPoint(i)
    if p == "TOPRIGHT" and rel == char and rp == "TOPRIGHT" then found = true end
  end
  assertTrue(found, "the box's right edge is not pinned to the Character dropdown")
  B:Hide()
end)

test("Browser: typing runs the library's hint, then the filter, then the Autocomplete hook", function()
  B:Show()
  local box = B._search
  local realSuggest, asked = B.SuggestNames, nil
  B.SuggestNames = function(text) asked = text; return {} end
  local ok, err = pcall(function()
    mocks.__timers = {}
    box:SetText("li")
    box:__fire("OnTextChanged", true)
    mocks.__fireTimers()
  end)
  B.SuggestNames = realSuggest
  local hintShown = box.hint:IsShown()
  local text = B.activeFilter.text
  B:SetSearchText("")
  box:__fire("OnTextChanged", false)
  mocks.__timers = {}
  B:Hide()
  if not ok then error(err, 0) end
  assertFalse(hintShown, "the library's OnTextChanged did not hide the hint")
  assertEqual(text, "li", "the host's onChange did not set the filter clause")
  assertEqual(asked, "li", "the Autocomplete hook no longer runs after the library's handler")
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

-- ── The test-mode strip: LibKa0s-Widgets-1.0's TestStrip (BankLedger#23, LibKa0s#48) ─────────
--
-- One strip per kind, both directly under the filter bar: the library's amber test strip
-- (f.testStrip, kind "test") and its cyan simulation strip (f.simStrip, kind "sim"). The red TEST
-- MODE badge on the title is only the degraded fallback: it shows in test mode when no strip was
-- built (no Widgets library), and never beside a strip. The library publishes the strip's HEIGHT
-- and nothing about the body below it, so the host computes its own reserve
-- (TEST_STRIP.HEIGHT + 2 * STRIP_GAP = 22) and shifts BOTH panes down by it while either strip shows.
-- Each case runs in a FRESH environment: the window is a singleton built once, and the strip's
-- constructor call is only observable while it is being built.

local STRIP_TEXT = "TEST MODE: a sample ledger, not your bank. Combat ends it."
local STRIP_RESERVE = 22

local function loadFresh(withoutWidgets)
  local m = T.makeMocks()
  local ns = {}
  local files = {}
  for _, path in ipairs(T.libka0sFiles) do
    if not (withoutWidgets and path == "libs/LibKa0s/Widgets.lua") then files[#files + 1] = path end
  end
  T.Loader.loadAll(files, ns, m)
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  ns:InitDB()
  ns.Schema:Register()
  ns.Ledger:Enable()
  return ns, m
end

-- Spy on the constructor while the window is built: what it was handed, and what the host did to
-- the strip it got back that the mock frame does not record (the mouse). `opts`/`mouse` are the
-- test strip's; `simOpts`/`simMouse` the simulation strip's.
local function showSpyingOnStrip(ns, m)
  local Widgets = m.LibStub("LibKa0s-Widgets-1.0", true)
  local real, seen = Widgets.TestStrip, { mouse = false, simMouse = false }
  Widgets.TestStrip = function(parent, opts)
    local sim = type(opts) == "table" and opts.kind == "sim"
    if sim then seen.simOpts = opts else seen.opts = opts end
    local s = real(parent, opts)
    s.EnableMouse = function(_, v)
      if sim then seen.simMouse = v else seen.mouse = v end
    end
    return s
  end
  local ok, err = pcall(function() ns.Browser:Show() end)
  Widgets.TestStrip = real
  if not ok then error(err, 0) end
  return seen
end

local function paneY(ns, name)
  local pane = ns.Browser:GetWindow().panes[name]
  local point, _, _, _, y = pane:GetPoint(1)
  assertEqual(point, "TOPLEFT", name .. "'s first point is not its TOPLEFT")
  local p2 = pane:GetPoint(2)
  assertEqual(p2, "BOTTOMRIGHT", name .. "'s second point is not its BOTTOMRIGHT")
  assertEqual(#pane.__points, 2, name .. " is not anchored by exactly TOPLEFT and BOTTOMRIGHT")
  return y
end

test("Browser: test mode on shows the strip under the filter bar and shifts both panes by 22", function()
  local ns, m = loadFresh()
  local seen = showSpyingOnStrip(ns, m)
  local f = ns.Browser:GetWindow()
  local baseH, baseI = paneY(ns, "History"), paneY(ns, "Insights")
  assertTrue(f.testStrip ~= nil, "the window built no test-mode strip")
  assertFalse(f.testStrip:IsShown(), "the strip shows outside test mode")
  assertTrue(seen.opts ~= nil, "the strip was not built through W.TestStrip")
  assertTrue(seen.opts.icon ~= nil and seen.opts.icon == ns.Icon("info"),
    "the strip's mark is not the info icon")
  assertEqual(f.testStrip.kind, "test", "the test strip is not the test flavor")
  assertTrue(f.simStrip ~= nil, "the window built no simulation strip")
  assertEqual(f.simStrip.kind, "sim", "the simulation strip is not the simulation flavor")
  assertTrue(seen.simOpts ~= nil and seen.simOpts.icon == ns.Icon("info"),
    "the simulation strip's mark is not the info icon")
  assertTrue(seen.simMouse == true, "the simulation strip's mouse was not enabled")
  local sp1, srel1, srp1, sx1, sy1 = f.simStrip:GetPoint(1)
  assertEqual(sp1 .. ">" .. srp1 .. "@" .. sx1 .. "," .. sy1, "TOPLEFT>BOTTOMLEFT@0,-2")
  assertTrue(srel1 == f.filterHost, "the simulation strip is not anchored to the filter bar")

  assertTrue(ns.LedgerTable:SetTestMode(true), "test mode did not start")
  assertTrue(f.testStrip:IsShown(), "the strip is hidden in test mode")
  assertEqual(f.testStrip.text:GetText(), ns.L[STRIP_TEXT])
  local p1, rel1, rp1, x1, y1 = f.testStrip:GetPoint(1)
  local p2, rel2, rp2, x2, y2 = f.testStrip:GetPoint(2)
  assertEqual(p1 .. ">" .. rp1, "TOPLEFT>BOTTOMLEFT")
  assertEqual(p2 .. ">" .. rp2, "TOPRIGHT>BOTTOMRIGHT")
  assertTrue(rel1 == f.filterHost and rel2 == f.filterHost, "the strip is not anchored to the filter bar")
  assertEqual(x1 .. "," .. y1 .. "," .. x2 .. "," .. y2, "0,-2,0,-2")
  assertEqual(paneY(ns, "History"), baseH - STRIP_RESERVE, "History did not move down by the reserve")
  assertEqual(paneY(ns, "Insights"), baseI - STRIP_RESERVE, "Insights did not move down by the reserve")
  assertFalse(f.simStrip:IsShown(), "the simulation strip shows in test mode")
  assertFalse(f.testBadge:IsShown(), "the red badge shows beside the strip; it is the fallback only")
  ns.LedgerTable:SetTestMode(false)
end)

test("Browser: test mode off hides the strip and the badge and puts both panes back", function()
  local ns = loadFresh()
  ns.Browser:Show()
  local f = ns.Browser:GetWindow()
  local baseH, baseI = paneY(ns, "History"), paneY(ns, "Insights")
  ns.LedgerTable:SetTestMode(true)
  assertFalse(ns.LedgerTable:SetTestMode(false), "test mode did not stop")
  assertFalse(f.testStrip:IsShown(), "the strip outlived test mode")
  assertFalse(f.simStrip:IsShown(), "the simulation strip shows outside a simulation")
  assertFalse(f.testBadge:IsShown(), "the badge outlived test mode")
  assertEqual(paneY(ns, "History"), baseH)
  assertEqual(paneY(ns, "Insights"), baseI)
end)

test("Browser: opening the window while test mode is already on reserves the strip's space", function()
  local ns = loadFresh()
  ns.Browser:Show()
  local f = ns.Browser:GetWindow()
  local baseH = paneY(ns, "History")
  ns.Browser:Hide()
  -- On behind the window's back: the dataset flips without the window being told.
  ns.State.testRecords = ns.LedgerTable:BuildTestData()
  assertTrue(ns.LedgerTable:IsTestMode(), "the premise: test mode is on")
  ns.Browser:Show()
  assertTrue(f.testStrip:IsShown(), "B:Show did not show the strip")
  assertEqual(paneY(ns, "History"), baseH - STRIP_RESERVE, "B:Show did not reserve the strip's space")
  ns.State.testRecords = nil
end)

test("Browser: combat ending test mode hides the strip and restores the panes", function()
  local ns = loadFresh()
  ns.Browser:Show()
  local f = ns.Browser:GetWindow()
  local baseH, baseI = paneY(ns, "History"), paneY(ns, "Insights")
  ns.LedgerTable:SetTestMode(true)
  assertTrue(f.testStrip:IsShown(), "the premise: the strip is up")
  ns.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
  assertFalse(ns.LedgerTable:IsTestMode(), "combat did not end test mode")
  assertFalse(f.testStrip:IsShown(), "the strip outlived the combat ending")
  assertEqual(paneY(ns, "History"), baseH)
  assertEqual(paneY(ns, "Insights"), baseI)
end)

test("Browser: with no Widgets library there is no strip and no shift, and the badge still shows",
  function()
    local ns, m = loadFresh(true)
    assertTrue(m.LibStub("LibKa0s-Widgets-1.0", true) == nil, "the degraded arm still has the library")
    ns.Browser:Show()
    local f = ns.Browser:GetWindow()
    local baseH = paneY(ns, "History")
    assertTrue(ns.LedgerTable:SetTestMode(true), "test mode did not start")
    T.assertNil(f.testStrip, "a strip was built without the library")
    T.assertNil(f.simStrip, "a simulation strip was built without the library")
    assertEqual(paneY(ns, "History"), baseH, "the panes moved for a strip that is not there")
    assertTrue(f.testBadge:IsShown(), "the badge is the only marker left, and it is gone")
    assertEqual(f.testBadge:GetText(), ns.L["TEST MODE"])
    ns.LedgerTable:SetTestMode(false)
  end)

test("Browser: hovering the strip shows the test-mode tooltip, and leaving hides it", function()
  local ns, m = loadFresh()
  local seen = showSpyingOnStrip(ns, m)
  local strip = ns.Browser:GetWindow().testStrip
  assertTrue(seen.mouse == true, "the strip's mouse was not enabled, so it can never be hovered")
  local lines, hidden = {}, false
  m.GameTooltip = {
    SetOwner = function() end, Show = function() end,
    Hide = function() hidden = true end,
    AddLine = function(_, text) lines[#lines + 1] = text end,
  }
  local ok, err = pcall(function()
    strip:__fire("OnEnter")
    strip:__fire("OnLeave")
  end)
  m.GameTooltip = nil
  if not ok then error(err, 0) end
  assertEqual(table.concat(lines, " | "), "Test mode | Shows: a sample ledger, not your bank"
    .. " | Ended by: combat, /bl test, the launcher menu")
  assertTrue(hidden, "OnLeave did not hide the tooltip")
end)

-- ── LibKa0s-Widgets-1.0 minor 4: a selection that outlives its option list ─────
--
-- WHAT CHANGED, and it is a change to THIS ADDON'S visible behavior, not only a new seam.
-- UpdateMultiLabel used to walk `_options` and ask which of them were selected, so a selected value
-- with no row in the CURRENT option list was invisible to it and the button fell back to the "All"
-- label. Minor 4 labels every value in `_selected`, from its option row when there is one and from
-- the raw value when there is not.
--
-- This addon's five column filters are all data-driven off the live dataset (typeOptions,
-- subTypeOptions, storeOptions, qualityOptions, charOptions all walk `dataset()`), and a SAVED VIEW
-- is applied against whatever option lists today's ledger produces -- so the selection genuinely can
-- outlive its list here, and the old label was a lie: "Type: All" on a bar that was filtering.
--
-- Character is the one that CANNOT: charOptions always inserts the "all" sentinel and the "Current"
-- sentinel by hand, and the only default selection is the Current sentinel, so its selection always
-- has a row. Pinned below so a change to that stays visible.

-- One real row, so the data-driven option lists are not empty. Restores whatever was there.
local function withTradegoodsRow(fn)
  local saved = NS.db.global.ledger
  NS.db.global.ledger = {}
  NS.Database:Add({
    ts = 1770000000, char = "Mock-Realm", classFile = "MAGE",
    kind = "ITEM", direction = "DEPOSIT", store = "BANK",
    itemID = 2589, itemName = "Linen Cloth", quality = 1,
    itemType = "Tradegoods", itemSubType = "Cloth",
    quantity = 10, zone = "Testville", mapID = 2657,
  })
  B:Show()
  B:RefreshFilterOptions()
  local ok, err = pcall(fn)
  B:ApplyView(nil, "all")
  NS.db.global.ledger = saved
  if not ok then error(err, 0) end
end

test("Browser: a saved filter with no row in today's option list is NAMED, not hidden behind All",
  function()
    withTradegoodsRow(function()
      local dd = B._dd
      local hasConsumable = false
      for _, o in ipairs(dd.type._options or {}) do
        if o.value == "Consumable" then hasConsumable = true end
      end
      assertFalse(hasConsumable, "today's dataset produces no Consumable row, which is the premise")

      -- A saved view is applied against whatever option lists TODAY'S ledger produces. This one
      -- names a type that is no longer in it — the ledger it was saved against had one.
      B:ApplyView({ itemType = { Consumable = true } }, "all")
      assertEqual(dd.type.text:GetText(), "Consumable",
        "minor 4 labels the raw value; minor 3 said 'Type: All' while the filter was on")
      assertTrue(B.activeFilter.itemType ~= nil, "and the filter really is on, which is the point")
    end)
  end)

test("Browser: a selection that DOES have a row still labels from that row", function()
  withTradegoodsRow(function()
    local dd = B._dd
    B:ApplyView({ itemType = { Tradegoods = true } }, "all")
    assertEqual(dd.type.text:GetText(), "Tradegoods", "the row's own label, not a count")
  end)
end)

test("Browser: the Character filter's selection can never outlive its option list", function()
  -- charOptions() inserts the "all" sentinel and the "Current" sentinel by hand, outside the
  -- data-driven loop, and defaultCharSelection() only ever picks the Current sentinel -- so the
  -- label change above cannot reach this dropdown.
  B:Show()
  local dd = B._dd
  local haveAll, haveCurrent = false, false
  for _, o in ipairs(dd.char._options or {}) do
    if o.value == "all" then haveAll = true end
    if o.value == CURRENT then haveCurrent = true end
  end
  assertTrue(haveAll, "the All sentinel is always a row")
  assertTrue(haveCurrent, "and so is the Current sentinel, whatever the dataset holds")
end)

-- ── Minimap button ─────────────────────────────────────────────────────────────
--
-- NOT HERE ANY MORE. The Browser owned the whole launcher until this addon adopted
-- LibKa0s-Launcher-1.0 (launcher-§1): B:SetupMinimap built the LDB object and handed it to
-- LibDBIcon, B:SetMinimapHidden drove Show/Hide, and both are gone. The two cases that stood here
-- -- that the defaults ship db.global.minimap so nothing has to seed it, and that the seam never
-- writes that table whole over the row it holds -- moved to tests/test_launcher.lua with the code
-- they describe, rather than being deleted: the question they ask is still a live one, it is just
-- no longer asked of this module.


-- ── The simulation marker (BankLedger#24, preview-mode; LibKa0s-Sim-1.0 host contract H8) ──────
--
-- While a simulation runs (Database:DatasetKind() == "sim") the simulation strip (f.simStrip, kind
-- "sim") says so, naming the scenario; the test strip and the red TEST MODE badge stay hidden. The
-- strip comes and goes with the start and the stop, and the panes move by the same reserve. Runs in
-- the shared environment, on the addon's own NS.Sim.

do
  local SS = dofile("tests/sim_support.lua")

  test("Browser: a simulation shows the sim strip with its scenario line, and never the badge",
  function()
    local inH, inI
    SS.withSession("warband", function()
      local f = NS.Browser:GetWindow()
      assertTrue(f.simStrip:IsShown(), "no marker while a simulation runs")
      assertEqual(f.simStrip.kind, "sim", "the simulation's strip is not the simulation flavor")
      assertEqual(f.simStrip.text:GetText(), NS.SimHost.MarkerText())
      assertEqual(f.simStrip.text:GetText(),
        NS.L["Simulation: %s - nothing here is saved."]:format(NS.L["Warband transfer"]))
      assertFalse(f.testStrip:IsShown(), "the test strip shows for a simulation")
      assertFalse(f.testBadge:IsShown(), "the TEST MODE badge shows for a simulation")
      inH, inI = paneY(NS, "History"), paneY(NS, "Insights")
    end)
    local f = NS.Browser:GetWindow()
    assertFalse(f.simStrip:IsShown(), "the marker outlived the simulation")
    assertFalse(f.testStrip:IsShown())
    assertFalse(f.testBadge:IsShown())
    assertEqual(inH, paneY(NS, "History") - STRIP_RESERVE, "History did not make the strip room")
    assertEqual(inI, paneY(NS, "Insights") - STRIP_RESERVE, "Insights did not make the strip room")
  end)

  test("Browser: the strip's tooltip describes the simulation while one runs", function()
    SS.withSession("bank", function()
      assertEqual(table.concat(NS.Browser.StripTipLines(), " | "), "Simulation | Shows: a simulated bank"
        .. " visit; nothing here is saved | Ended by: /bl sim stop, combat, a real bank window")
    end)
    assertEqual(NS.Browser.StripTipLines()[1], "Test mode", "the test lines are back once it stops")
  end)

  test("Browser: a stop repaints the strip through the session listener", function()
    SS.withSession("bank", function(sim)
      local f = NS.Browser:GetWindow()
      local real, painted = NS.Browser.UpdateTestStrip, 0
      NS.Browser.UpdateTestStrip = function(...) painted = painted + 1 return real(...) end
      local ok, err = pcall(SS.chat, function() sim:Stop("stop") end)
      NS.Browser.UpdateTestStrip = real
      if not ok then error(err, 0) end
      assertTrue(painted >= 2, "the stop's dataset swap and its listener each repaint: " .. painted)
      assertFalse(f.simStrip:IsShown())
    end)
  end)
end
