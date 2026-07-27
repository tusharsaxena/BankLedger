local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

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

test("Browser:ClearFilters does not scope preview data to the real player", function()
  -- The preview dataset is synthetic alts; defaulting to Current would open onto an empty table.
  withCleanFilter(function()
    local saved = NS.LedgerTable.previewMode
    NS.LedgerTable.previewMode = true
    local ok, err = pcall(function()
      B:ClearFilters()
      assertEqual(B.activeFilter.char, nil, "preview mode starts unscoped")
    end)
    NS.LedgerTable.previewMode = saved
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
