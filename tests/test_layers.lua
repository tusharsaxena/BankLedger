-- tests/test_layers.lua — where every frame this addon builds sits (frame-layering, item 030).
--
-- The kit's frame-layer recorder (tests/_kit/mock_layers.lua) is installed on a FRESH mock before
-- the addon loads, so every frame the addon builds answers its strata, level, toplevel and clamp.
-- A fresh environment rather than the shared NS, because the shared NS built these windows long
-- ago, before any recorder was installed, and the windows are built once.
--
-- What it pins, one case per frame class of the layers table in core/Constants.lua:
--   * the ledger and session windows: WINDOW (HIGH), toplevel, clamped (BAN-Z01, BAN-Z02)
--   * the export dialog: MODAL (DIALOG), toplevel, clamped (BAN-Z05)
--   * the row context menu: POPUP (FULLSCREEN_DIALOG), no full-screen click catcher, dismissed by a
--     GLOBAL_MOUSE_DOWN listener held only while it shows (BAN-Z03), closed with its window (BAN-Z09)
--   * the degraded resize grip at window + LEVEL.GRIP, as the library's (BAN-Z07)
--   * no strata string and no bare level number at any call site (BAN-Z06)

local T = _G.BL_TEST
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local VALID_STRATA = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
                       FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true }

--- A fully loaded addon on its own mock, with the layer recorder installed before the load. Every
--- frame also records its RegisterEvent / UnregisterEvent calls, which this addon's frame stub
--- otherwise answers with the frame and forgets.
local function loadLayered()
  local m = T.makeMocks()
  dofile("tests/_kit/mock_layers.lua")(m)
  local layered = m.CreateFrame
  m.__built = {}
  m.CreateFrame = function(...)
    local f = layered(...)
    rawset(f, "__evts", {})
    rawset(f, "RegisterEvent", function(self, ev) self.__evts[ev] = true; return self end)
    rawset(f, "UnregisterEvent", function(self, ev) self.__evts[ev] = nil; return self end)
    m.__built[#m.__built + 1] = f
    return f
  end
  local ns = {}
  T.Loader.loadAll(T.libka0sFiles, ns, m)
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  ns:InitDB()
  ns.Schema:Register()
  ns.Ledger:Enable()
  return ns, m
end

local function entry()
  return { ts = 1770000000, char = "Mock-Realm", classFile = "MAGE", kind = "ITEM",
           direction = "DEPOSIT", store = "BANK", itemID = 2589, itemName = "Linen Cloth",
           quality = 1, itemType = "Tradegoods", quantity = 10 }
end

--- Open the row menu off a stand-in anchor and answer the menu and every frame built doing it.
local function openRowMenu(ns, m)
  local before = #m.__built
  local anchor = m.CreateFrame("Frame", nil, m.UIParent)
  ns.LedgerTable:ShowRowMenu(anchor, entry())
  local built = {}
  for i = before + 2, #m.__built do built[#built + 1] = m.__built[i] end
  local menu
  for _, f in ipairs(built) do
    if f.__parent == m.UIParent and f.__template == "BackdropTemplate" then menu = f end
  end
  return menu, built
end

-- ── The table ───────────────────────────────────────────────────────────────────

test("Layers: NS.Constants.LAYERS names the addon's tiers with the standard's keys", function()
  local ns = loadLayered()
  local L = ns.Constants.LAYERS
  assertTrue(type(L) == "table" and type(L.STRATA) == "table" and type(L.LEVEL) == "table",
    "one LAYERS = { STRATA, LEVEL } table (frame-layering-§5)")
  assertEqual(L.STRATA.WINDOW, "HIGH")
  assertEqual(L.STRATA.MODAL, "DIALOG")
  assertEqual(L.STRATA.POPUP, "FULLSCREEN_DIALOG")
  for key, s in pairs(L.STRATA) do
    assertTrue(VALID_STRATA[s], "STRATA." .. key .. " is not a client strata: " .. tostring(s))
  end
  assertEqual(L.LEVEL.GRIP, 10, "the library's GRIP_LEVEL, which the degraded grip reproduces")
end)

-- ── Windows and the dialog ─────────────────────────────────────────────────────

test("Layers: the ledger window is HIGH, toplevel and clamped", function()
  local ns, m = loadLayered()
  ns.Browser:Show()
  local L = m.__layers(ns.Browser:GetWindow())
  assertEqual(L.strata, "HIGH")
  assertTrue(L.toplevel, "a click must raise it over the session window and Settings (BAN-Z01)")
  assertTrue(L.clamped)
  ns.Browser:Hide()
end)

test("Layers: the session window is HIGH, toplevel and clamped", function()
  local ns, m = loadLayered()
  ns.SessionWindow:Show()
  local f = ns.SessionWindow:GetWindow()
  assertTrue(f ~= nil, "the session window was not built")
  local L = m.__layers(f)
  assertEqual(L.strata, "HIGH")
  assertTrue(L.toplevel, "a click must raise it over the ledger window (BAN-Z02)")
  assertTrue(L.clamped)
  ns.SessionWindow:Hide()
end)

test("Layers: the export dialog is DIALOG, toplevel and clamped", function()
  local ns, m = loadLayered()
  local L = m.__layers(ns.Export:Open({}))
  assertEqual(L.strata, "DIALOG")
  assertTrue(L.toplevel, "a click must raise it over the console and sim panel (BAN-Z05)")
  assertTrue(L.clamped)
end)

-- ── The row context menu ───────────────────────────────────────────────────────

test("Layers: the row menu is FULLSCREEN_DIALOG and builds no full-screen click catcher", function()
  local ns, m = loadLayered()
  local menu, built = openRowMenu(ns, m)
  assertTrue(menu ~= nil, "the row menu was not built")
  assertEqual(m.__layers(menu).strata, "FULLSCREEN_DIALOG")
  assertTrue(menu:IsShown(), "the menu shows")
  for _, f in ipairs(built) do
    if f ~= menu then
      assertTrue(f.__parent ~= m.UIParent,
        "a second UIParent frame was built beside the row menu: the retired catcher (BAN-Z03)")
    end
  end
end)

test("Layers: the row menu listens for GLOBAL_MOUSE_DOWN only while it shows", function()
  local ns, m = loadLayered()
  local menu = openRowMenu(ns, m)
  assertTrue(menu.__evts.GLOBAL_MOUSE_DOWN, "registered when the menu opens")
  menu:Hide()
  assertFalse(menu.__evts.GLOBAL_MOUSE_DOWN, "dropped when it hides")
end)

test("Layers: a press outside the row menu closes it; a press on it does not", function()
  local ns, m = loadLayered()
  local menu = openRowMenu(ns, m)
  rawset(menu, "IsMouseOver", function() return true end)
  menu:__fire("OnEvent", "GLOBAL_MOUSE_DOWN", "LeftButton")
  assertTrue(menu:IsShown(), "a press on the menu's own row must not close it before the release")
  rawset(menu, "IsMouseOver", function() return false end)
  menu:__fire("OnEvent", "GLOBAL_MOUSE_DOWN", "RightButton")
  assertFalse(menu:IsShown(), "a press anywhere else closes it")
end)

test("Layers: hiding the ledger window closes the row menu (BAN-Z09)", function()
  local ns, m = loadLayered()
  ns.Browser:Show()
  local menu = openRowMenu(ns, m)
  ns.Browser:Hide()
  assertFalse(menu:IsShown(), "B:Hide left the row menu floating")

  ns.Browser:Show()
  openRowMenu(ns, m)
  assertTrue(menu:IsShown())
  ns.Browser:GetWindow():Hide()   -- Escape, the key binding: the frame's own OnHide
  assertFalse(menu:IsShown(), "the window's OnHide left the row menu floating")
end)

test("Layers: LedgerTable:HideRowMenu is a no-op before the menu exists", function()
  local ns = loadLayered()
  local ok, err = pcall(function() ns.LedgerTable:HideRowMenu() end)
  assertTrue(ok, tostring(err))
end)

-- ── The degraded grip ──────────────────────────────────────────────────────────

test("Layers: the degraded resize grip sits at window + LEVEL.GRIP, as the library's", function()
  local ns, m = dofile("tests/degraded_env.lua").loadDegraded()
  dofile("tests/_kit/mock_layers.lua")(m)
  local f = m.CreateFrame("Frame", nil, m.UIParent)
  local grip = ns.MakeResizable(f, { minWidth = 100, minHeight = 100 })
  assertTrue(grip ~= nil, "the fallback builds a grip")
  assertEqual(m.__layers(grip).level, m.__layers(f).level + ns.Constants.LAYERS.LEVEL.GRIP,
    "the grip must clear the rows (window + 3/4), like Core's GRIP_LEVEL (BAN-Z07)")
end)

-- ── No literals at call sites ──────────────────────────────────────────────────

test("Layers: no strata string and no bare level number at any call site", function()
  local p = io.popen("ls core/*.lua modules/*.lua settings/*.lua")
  local files = {}
  for path in p:lines() do files[#files + 1] = path end
  p:close()
  assertTrue(#files > 10, "the source listing came back empty")
  for _, path in ipairs(files) do
    local body = T.Loader.readFile(path)
    assertFalse(body:find('SetFrameStrata%(%s*"') ~= nil,
      path .. " sets a strata string; read NS.Constants.LAYERS.STRATA (frame-layering-§5)")
    assertFalse(body:find("SetFrameLevel%(%s*%d") ~= nil,
      path .. " sets an absolute frame level (frame-layering-§3)")
  end
end)
