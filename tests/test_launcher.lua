-- tests/test_launcher.lua — the LibKa0s-Launcher-1.0 seam, and the Minimap button row it drives.
--
-- The library's own suite covers the launcher's semantics; duplicating them here is the
-- consumer-side copy testing-§8 forbids. What only this repo can assert is that the seam is wired,
-- that the MENU ENTRIES are the ones the standard's ADDONS.md records for this addon and each runs
-- its slash verb's own handler, that the inverting get/set at the write seam is the right way
-- round, and that a host missing either broker library degrades rather than raises.
--
-- ── THE ORDER OF THE CASES IS LOAD-BEARING ───────────────────────────────────────────────────
--
-- `NS.Launcher` is the ONE live instance the addon built at load, and `Register` is idempotent by
-- design: once it holds an object and an icon library it answers true and touches nothing. So the
-- no-broker case runs FIRST, while it is still unregistered, and every later case runs against the
-- fakes installed by the registration case — which are deliberately LEFT INSTALLED, because in the
-- client the launcher is registered for the rest of the session too. tests/test_lifecycle.lua runs
-- after this suite and calls addon:OnEnable, which re-enters Register and gets the early true.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = NS.Schema
-- The row's CLI path reads in its own sense (launcher-§3, standard v2.65.0); the STORED key is still
-- LibDBIcon's db.global.minimap.hide, which every assertion on storage below reads directly.
local MINIMAP_PATH = "minimap.shown"

local function readSource(path)
  local f = assert(io.open(path, "rb"))
  local src = f:read("*a")
  f:close()
  return src
end

local function captureChat(fn)
  local out = {}
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

-- The LibDBIcon half of the fake, kept at file scope so the later cases can read what the button
-- was last told to do. `shown` starts nil, which is neither true nor false and therefore reports
-- "nothing has moved this button yet".
local button = { registered = 0, shown = nil, name = nil, db = nil }

-- ── The seam, and the one file that is the addon's face ──────────────────────────────────────

test("Launcher: the seam is published, and it is the library's instance", function()
  assertTrue(type(NS.Launcher) == "table", "NS.Launcher exists")
  for _, member in ipairs({ "Register", "IsRegistered", "Object", "IsShown", "SetShown" }) do
    assertTrue(type(NS.Launcher[member]) == "function", "NS.Launcher:" .. member .. " is missing")
  end
  assertFalse(NS.Launcher.__degraded == true,
    "the harness loads LibKa0s, so this must be the live instance and not the stub")
end)

test("Launcher: the icon is the addon's OWN logo, and the same file ## IconTexture names", function()
  -- launcher-§4: one file is the addon's face in three places — the AddOns list, the minimap button
  -- and a broker display — so a player who has seen the addon once recognizes it in all three. The
  -- two spellings are in two files and nothing but this case makes them agree.
  --
  -- Dies under: pointing ## IconTexture back at a Blizzard icon, renaming the .tga, or typing the
  -- path into core/LauncherSetup.lua instead of deriving it from the folder name.
  local want = "Interface\\AddOns\\BankLedger\\media\\logos\\bankledger.logo.128.tga"
  assertEqual(NS.LOGO_ICON, want)

  local toc = readSource("BankLedger.toc"):match("## IconTexture:%s*([^\r\n]*)")
  assertEqual(toc, want, "the TOC's ## IconTexture must be the same file")
  assertFalse(toc:find("Interface\\Icons\\", 1, true) ~= nil,
    "a borrowed Blizzard icon makes the addon look like something else (anti-pattern #82)")
  assertEqual(tonumber(toc), nil, "a numeric file id says nothing to the next reader")

  local f = io.open("media/logos/bankledger.logo.128.tga", "rb")
  assertTrue(f ~= nil, "the file the launcher and the TOC both name must actually ship")
  local header = f:read(18)
  f:close()
  -- layout-§4: uncompressed (image type 2), 32-bit. An RLE or 24-bit file draws NOTHING and raises
  -- NOTHING, so no other gate in this repo would report it.
  assertEqual(header:byte(3), 2, "the 128 logo must be an UNCOMPRESSED TGA (image type 2)")
  assertEqual(header:byte(17), 32, "the 128 logo must be 32-bit")
  assertEqual(header:byte(13) + header:byte(14) * 256, 128, "the 128 logo must be 128 wide")
  assertEqual(header:byte(15) + header:byte(16) * 256, 128, "the 128 logo must be 128 tall")
end)

test("Launcher: the hand-rolled launcher is gone from modules/Browser.lua", function()
  -- It was `B:SetupMinimap` and `B:SetMinimapHidden`: thirty lines written once here and again, in
  -- another spelling, in every other Ka0s addon (anti-pattern #81). The library owns them now, and
  -- a second copy standing back up beside it is the exact failure this adoption undoes.
  local src = readSource("modules/Browser.lua")
  for _, gone in ipairs({ "SetupMinimap", "SetMinimapHidden", "LibDataBroker-1.1", "LibDBIcon-1.0" }) do
    assertEqual(src:find(gone, 1, true), nil, "modules/Browser.lua still names " .. gone)
  end
  assertEqual(NS.Browser.SetupMinimap, nil)
  assertEqual(NS.Browser.SetMinimapHidden, nil)
end)

-- ── Degradation (this case must run BEFORE the launcher is registered) ───────────────────────

test("Launcher: a host with neither broker library degrades and does NOT raise", function()
  -- The library resolves both with LibStub(..., true) at REGISTER time and degrades by name. The
  -- harness never loads either — tests/run.lua's loader skips the TOC's `libs\` lines — so this is
  -- the truly unregistered state rather than a simulated one.
  --
  -- WHAT IS NOT ASSERTED HERE, AND WHY: the notice. Since Launcher minor 2 (LibKa0s v1.56.0) the
  -- library prints a missing-library notice ONCE per instance, and this live instance has already
  -- been through Register before this suite runs (tests/test_ledger_settling.lua drives the real
  -- addon:OnEnable, which registers it), so a capture here is empty by design. The report is pinned
  -- by the next case, against a fresh load whose notice is still unspent.
  assertFalse(NS.Launcher:IsRegistered(), "this case must run before the registration case")
  assertEqual(mocks.__libs["LibDataBroker-1.1"], nil, "the harness ships neither broker library")

  local ok, err = pcall(function()
    captureChat(function() assertFalse(NS.Launcher:Register()) end)
  end)
  assertTrue(ok, "a host with no LibDataBroker must not raise: " .. tostring(err))
  assertFalse(NS.Launcher:IsRegistered())
  assertEqual(NS.Launcher:Object(), nil, "nothing was built")

  -- IsShown still answers from the STORE, so the Master-controls checkbox reflects what the player
  -- chose rather than reading true because nothing contradicted it.
  local saved = NS.db.global.minimap.hide
  NS.db.global.minimap.hide = true
  assertFalse(NS.Launcher:IsShown(), "IsShown reads the store, not the button")
  NS.db.global.minimap.hide = saved
end)

test("Launcher: the missing-broker notice prints once across two Register calls, without a [LibKa0s] tag",
  function()
    -- A FRESH load of the library and the whole addon, so this instance has never been through
    -- Register and its once-per-instance notice is still unspent. Its descriptor is the addon's own
    -- (core/LauncherSetup.lua, as the TOC loads it), so the line goes out through the addon's real
    -- printer rather than a stand-in.
    --
    -- Launcher minor 2: one missing library is ONE line in chat however many times Register is
    -- reached (OnEnable, then again from any later login path), and the line is UNTAGGED by the
    -- library, so the host printer's [BL] is the only tag on it. Before minor 2 it printed on every
    -- call and carried a [LibKa0s] tag inside the [BL] one.
    --
    -- Dies under: a re-vendor that loses the once-per-instance latch, a library tag coming back, or
    -- the descriptor's `print` no longer routing through NS.Print.
    local m = T.makeMocks()
    local ns = {}
    T.Loader.loadAll(T.libka0sFiles, ns, m)
    T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
    assertEqual(m.__libs["LibDataBroker-1.1"], nil, "the fresh load ships neither broker library")
    assertFalse(ns.Launcher.__degraded == true, "the fresh load must build the live instance")

    local out = {}
    m.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
    assertFalse(ns.Launcher:Register(), "first Register")
    assertFalse(ns.Launcher:Register(), "second Register")

    assertEqual(#out, 1, "one missing library is one line, not one per call: " .. table.concat(out, " || "))
    local line = out[1]
    assertTrue(line:find("LibDataBroker-1.1", 1, true) ~= nil, "the line names the missing library: " .. line)
    assertEqual(line:find("[LibKa0s]", 1, true), nil, "the library no longer tags its own line: " .. line)
    assertEqual(line:find("|cff00ffff[BL]|r ", 1, true), 1, "the host printer's [BL] is the one tag: " .. line)
    assertFalse(ns.Launcher:IsRegistered())
  end)

test("Launcher: LibDataBroker without LibDBIcon still gets the broker plugin", function()
  -- The honest half-answer: the display row exists, the minimap button does not, and Register says
  -- false because the section's headline surface is the button.
  -- The object is built ONCE and cached for the rest of the run, so this fake stamps the name it
  -- was given: the registration case below reads it back, and by then LDB is never asked again.
  mocks.__libs["LibDataBroker-1.1"] = {
    NewDataObject = function(_, name, obj) obj.__name = name; return obj end,
    GetDataObjectByName = function() return nil end,
  }
  local out = captureChat(function() assertFalse(NS.Launcher:Register()) end)
  mocks.__libs["LibDataBroker-1.1"] = nil
  assertTrue(table.concat(out, "\n"):find("LibDBIcon", 1, true) ~= nil,
    "the missing icon library is named: " .. table.concat(out, "\n"))
  assertTrue(NS.Launcher:Object() ~= nil, "the broker object was still built")
  assertFalse(NS.Launcher:IsRegistered(), "a broker plugin alone is not a registered launcher")
end)

-- ── Registration ─────────────────────────────────────────────────────────────────────────────

test("Launcher: it registers under the FOLDER name, against db.global.minimap", function()
  -- launcher-§1: the same name for BOTH registrations, and that name is the addon's folder name.
  -- It is not cosmetic — LibDBIcon keys the button's saved position off the table it is handed and
  -- a broker display labels the plugin by the name, so a second spelling splits the identity. This
  -- addon used to register as "Ka0s Bank Ledger", which is the TITLE.
  --
  -- The TABLE assertion is the other half of launcher-§3: the object LibDBIcon holds and the table
  -- the Minimap button row writes must be the SAME table, or the button and the checkbox disagree
  -- the first time either is used. A descriptor capturing it at file load could not be — AceDB
  -- replaces it — which is why core/LauncherSetup.lua passes a function.
  mocks.__libs["LibDataBroker-1.1"] = {
    NewDataObject = function(_, name, obj) obj.__name = name; return obj end,
    GetDataObjectByName = function() return nil end,
  }
  mocks.__libs["LibDBIcon-1.0"] = {
    Register = function(_, name, _, db)
      button.registered = button.registered + 1
      button.name, button.db = name, db
    end,
    Show = function(_, name) button.shown, button.name = true, name end,
    Hide = function(_, name) button.shown, button.name = false, name end,
    IsRegistered = function() return button.registered > 0 end,
  }

  assertTrue(NS.Launcher:Register(), "the launcher wired fully")
  assertTrue(NS.Launcher:IsRegistered())
  assertEqual(button.registered, 1)
  assertEqual(button.name, "BankLedger", "the FOLDER name, not the title and not the label")
  assertEqual(NS.Launcher:Object().__name, "BankLedger", "both registrations take the same name")
  assertTrue(rawequal(button.db, NS.db.global.minimap),
    "LibDBIcon must hold the very table the Minimap button row writes")
end)

test("Launcher: Register is idempotent, so no second button is built over the first", function()
  -- A host may call it from OnInitialize and again from a login handler; core/BankLedger.lua calls
  -- it from OnEnable, which the disable/enable cycle re-enters.
  local before = button.registered
  assertTrue(NS.Launcher:Register())
  NS.addon:OnEnable()
  assertEqual(button.registered, before, "LibDBIcon:Register ran a second time")
end)

test("Launcher: ONE object, of type launcher, wearing the addon's icon", function()
  -- `type = "launcher"` is the reason rather than a label: a display reads it to decide what to
  -- draw, and "data source" promises a `text` value this object does not have.
  local obj = NS.Launcher:Object()
  assertEqual(obj.type, "launcher")
  assertEqual(obj.icon, NS.LOGO_ICON)
  assertEqual(obj.label, "Ka0s Bank Ledger")
  assertTrue(type(obj.OnClick) == "function", "the one click implementation both surfaces dispatch into")
  assertTrue(type(obj.OnTooltipShow) == "function")
end)

test("Launcher: the broker label is the BRAND NAME in plain text, not the Title and not the folder",
function()
  -- launcher-§1 (standard v2.54.0). `label` is the string a broker display prints in its own row,
  -- and it prints it beside the other ten, so it is the single field that decides whether the
  -- collection reads as one collection in Titan Panel. Across the eleven adoptions it came out
  -- three ways because nothing said what it was; this addon's was "Bank Ledger".
  --
  -- Dies under: reverting to "Bank Ledger", wiring the field to the TOC's `## Title`, or spelling
  -- it with the folder name.
  local label = NS.Launcher:Object().label
  assertEqual(label, "Ka0s Bank Ledger", "`Ka0s <Name>`, the addon's brand name")
  assertEqual(label:find("|c", 1, true), nil, "no color escape: a display that draws the string "
    .. "raw would splatter this row across a list of plain-text ones")
  assertEqual(label:find("|r", 1, true), nil, "nor a color terminator")
  assertEqual(label:find("BankLedger", 1, true), nil,
    "the FOLDER name is the registration `name`, which LibDBIcon keys the saved position by")

  -- Not wired to the TOC's ## Title. They happen to read the same here, and the case still has to
  -- prove the wire is absent -- a host that derived one from the other would break the moment a
  -- Title grew an escape, which is exactly what happened to Ka0s Pretty Chat.
  local src = readSource("core/LauncherSetup.lua")
  assertEqual(src:find("GetAddOnMetadata", 1, true), nil,
    "the label must be spelled out, never read from the TOC's ## Title")
  assertTrue(src:find('NS.BRAND_NAME = "Ka0s Bank Ledger"', 1, true) ~= nil,
    "spelled as a plain literal in this file, once")
  assertTrue(src:find("label = NS.BRAND_NAME", 1, true) ~= nil,
    "and the descriptor reads that one spelling")
  -- ONE SPELLING, TWO READERS. The disabled refusal line (slash-commands-§7) renders the same brand
  -- name, and the standard requires it to be the SAME string this field carries -- launcher-§1
  -- forbids escapes here, which is what makes it safe to drop into a colored line. A second literal
  -- would be a second brand spelling waiting to drift.
  assertEqual(NS.BRAND_NAME, label, "the refusal line and the broker row read one brand name")
end)

test("Launcher: the brand literal is spelled at NS.BRAND_NAME and the missing-library clause only",
function()
  -- BankLedger-R-10. Every surface that shows the brand (the tooltip title, the options parent
  -- title, the window titles, the purge popup) reads NS.BRAND_NAME. The one other literal is
  -- core/CoreSetup.lua's NS.LIBKA0S_MISSING, which loads before core/LauncherSetup.lua declares the
  -- constant. Comments are stripped first: prose may name the brand, code may not re-spell it.
  --
  -- Dies under: any core/, settings/ or modules/ file putting "Ka0s Bank Ledger" back in code.
  local BRAND = "Ka0s Bank Ledger"
  local hits = {}
  for _, path in ipairs(T.Loader.tocFiles("BankLedger.toc")) do
    local rel = path:gsub("\\", "/")
    if rel:match("^core/") or rel:match("^settings/") or rel:match("^modules/") then
      local n = 0
      for line in (readSource(rel) .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        local code = line:gsub("%-%-.*$", "")
        if code:find(BRAND, 1, true) then hits[#hits + 1] = rel .. ":" .. n end
      end
    end
  end
  local where = table.concat(hits, ", ")
  assertEqual(#hits, 2, "expected exactly two code spellings, got: " .. where)
  assertTrue(where:find("core/CoreSetup.lua:", 1, true) ~= nil, where)
  assertTrue(where:find("core/LauncherSetup.lua:", 1, true) ~= nil, where)
  local src = readSource("core/LauncherSetup.lua")
  -- The tooltip title is the library's since Launcher minor 3, drawn from `label`, so the host hook
  -- must not spell a title of its own (anti-pattern #89).
  assertEqual(src:find("tt:AddLine(NS.BRAND_NAME", 1, true), nil,
    "the tooltip title is the library's, drawn from label = NS.BRAND_NAME")
  assertTrue(readSource("settings/OptionsSetup.lua"):find("local PARENT_TITLE = NS.BRAND_NAME", 1, true)
    ~= nil, "the options parent title reads the constant")
end)

-- ── The two buttons (launcher-§2, standard v2.67.0; Launcher minor 4) ────────────────────────
--
-- LEFT opens the settings panel, on every addon and in either state. RIGHT opens the client's own
-- context menu, one checkbox per toggle this addon really has, each wired to the handler its slash
-- verb already runs. The drawing, the order and the graying are the library's suite; what only this
-- repo can assert is WHICH entries it supplies and WHERE each click lands.

local menuMock = dofile("tests/menu_mock.lua")(mocks)

-- Open the options menu through the one click both surfaces share, with the fake MenuUtil installed
-- for exactly as long as the case needs it. Answers the opened menu.
local OWNER = {}
local function openMenu()
  menuMock.install()
  menuMock.reset()
  local ok, err = pcall(NS.Launcher:Object().OnClick, OWNER, "RightButton")
  menuMock.remove()
  if not ok then error(err, 0) end
  return menuMock.last
end

-- Swap `tbl[key]` for a counting spy for the length of `fn`, and answer the calls it saw.
local function spyOn(tbl, key, fn)
  local calls = {}
  local saved = tbl[key]
  tbl[key] = function(...) calls[#calls + 1] = { ... } end
  local ok, err = pcall(fn)
  tbl[key] = saved
  if not ok then error(err, 0) end
  return calls
end

test("Launcher: LEFT-click opens the settings panel and nothing else", function()
  -- launcher-§2 as of v2.67.0: the three left-click rungs are retired. Bank Ledger was rung (a) —
  -- its left click toggled the ledger — and that toggle is the menu's Show window entry now.
  --
  -- Dies under: a host `onClick` the library still honored, or openSettings pointing anywhere but
  -- the panel.
  local toggled = spyOn(NS.Browser, "Toggle", function()
    local opened = spyOn(NS.Panel, "Open", function()
      NS.Launcher:Object().OnClick(OWNER, "LeftButton")
    end)
    assertEqual(#opened, 1, "left-click opens the settings panel")
  end)
  assertEqual(#toggled, 0, "left-click no longer toggles the ledger window")
end)

test("Launcher: RIGHT-click opens the options menu: Enabled, Locked, Test mode, Show window", function()
  -- The four entries the standard's ADDONS.md records against this addon (WS-11): it has the
  -- addon-wide switch, the Master-controls Lock frame row, the sample-ledger test mode, and a
  -- primary window, the ledger browser. The title is the brand, the same `label` the tooltip draws.
  --
  -- Dies under: dropping any accessor/toggle pair from core/LauncherSetup.lua (half a pair draws
  -- nothing), or the right click opening the panel instead.
  local opened = spyOn(NS.Panel, "Open", function()
    local menu = openMenu()
    assertTrue(menu ~= nil, "right-click opened no menu")
    assertEqual(menu.owner, OWNER, "the menu anchors to the frame that was clicked")
    assertEqual(menu.titles[1], "Ka0s Bank Ledger", "the menu's title is the brand name")
    assertEqual(table.concat(menu:Texts(), " / "), "Enabled / Locked / Test mode / Show window")
  end)
  assertEqual(#opened, 0, "the right click opened the panel as well as the menu")
end)

test("Launcher: with no MenuUtil the right click falls back to the settings panel", function()
  -- A client without the 11.0 menu API: the library degrades to the panel, which holds every toggle
  -- the menu would have. The case is here because it is the state every OTHER suite runs in.
  local opened = spyOn(NS.Panel, "Open", function()
    NS.Launcher:Object().OnClick(OWNER, "RightButton")
  end)
  assertEqual(#opened, 1, "no menu API, so the right click opens the panel")
end)

test("Launcher: each menu entry runs the SAME handler its slash verb runs", function()
  -- Enabled -> `/bl enable|disable` (Sl:CliEnabled); Locked -> `/bl set settings.locked`, the only
  -- verb that writes the Lock frame row (Sl:CliSet); Test mode -> `/bl test` (LT:ToggleTestMode);
  -- Show window -> `/bl toggle` (B:Toggle). Each pair below drives the verb AND the entry into one
  -- spy, so a menu that grew its own copy of any of them goes red.
  local LT = NS.LedgerTable
  local savedLocked = S:Get("settings.locked")
  S:Set("settings.locked", false)
  local ok, err = pcall(function()
    local calls = spyOn(NS.Slash, "CliEnabled", function()
      NS.Slash:OnSlash("disable")
      openMenu():Click("Enabled")
    end)
    assertEqual(#calls, 2, "/bl disable and the Enabled entry reach Sl:CliEnabled once each")
    assertEqual(calls[1][2], false)
    assertEqual(calls[2][2], false, "an enabled addon's Enabled entry moves it to disabled")

    calls = spyOn(NS.Slash, "CliSet", function()
      NS.Slash:OnSlash("set settings.locked true")
      openMenu():Click("Locked")
    end)
    assertEqual(#calls, 2, "/bl set settings.locked and the Locked entry reach Sl:CliSet once each")
    assertEqual(calls[1][2], "settings.locked true")
    assertEqual(calls[2][2], "settings.locked true", "an unlocked addon's Locked entry locks it")

    calls = spyOn(LT, "ToggleTestMode", function()
      captureChat(function() NS.Slash:OnSlash("test") end)
      captureChat(function() openMenu():Click("Test mode") end)
    end)
    assertEqual(#calls, 2, "/bl test and the Test mode entry reach LT:ToggleTestMode once each")

    calls = spyOn(NS.Browser, "Toggle", function()
      NS.Slash:OnSlash("toggle")
      openMenu():Click("Show window")
    end)
    assertEqual(#calls, 2, "/bl toggle and the Show window entry reach B:Toggle once each")
  end)
  S:Set("settings.locked", savedLocked)
  if not ok then error(err, 0) end
end)

test("Launcher: the Locked entry really locks, through the Lock frame row's own seam", function()
  -- The spy above proves the route; this proves the route arrives. Clicking Locked on an unlocked
  -- addon stores settings.locked = true, which the row and the tooltip then both read.
  local savedLocked = S:Get("settings.locked")
  S:Set("settings.locked", false)
  local ok, err = pcall(function()
    captureChat(function() openMenu():Click("Locked") end)
    assertEqual(S:Get("settings.locked"), true, "the Locked entry did not lock")
    captureChat(function() openMenu():Click("Locked") end)
    assertEqual(S:Get("settings.locked"), false, "a second click unlocks")
  end)
  S:Set("settings.locked", savedLocked)
  if not ok then error(err, 0) end
end)

test("Launcher: each checkmark reads the live state, on every open", function()
  -- Never cached: flip each state and reopen. Show window reads the ledger frame itself.
  local LT = NS.LedgerTable
  local savedLocked = S:Get("settings.locked")
  local savedIsTest = LT.IsTestMode
  local testOn = false
  LT.IsTestMode = function() return testOn end
  local ok, err = pcall(function()
    NS.Browser:Hide()
    S:Set("settings.locked", false)
    local menu = openMenu()
    assertTrue(menu:Checked("Enabled"), "an enabled addon's Enabled entry is checked")
    assertFalse(menu:Checked("Locked"))
    assertFalse(menu:Checked("Test mode"))
    assertFalse(menu:Checked("Show window"), "the ledger window is closed")

    S:Set("settings.locked", true)
    testOn = true
    NS.Browser:Show()
    menu = openMenu()
    assertTrue(menu:Checked("Locked"))
    assertTrue(menu:Checked("Test mode"))
    assertTrue(menu:Checked("Show window"), "the ledger window is open")
  end)
  NS.Browser:Hide()
  LT.IsTestMode = savedIsTest
  S:Set("settings.locked", savedLocked)
  if not ok then error(err, 0) end
end)

test("Launcher: a raising menu handler is reported, not thrown at the player", function()
  -- The click runs inside the client's menu dispatch, where a raise is a red error box with nothing
  -- saying which addon caused it. The library pcalls it; this case is here because the guard is only
  -- worth anything if the host's printer is wired, and ours is.
  local saved = NS.Browser.Toggle
  NS.Browser.Toggle = function() error("boom", 0) end
  local ok, err = pcall(function()
    local out = captureChat(function() openMenu():Click("Show window") end)
    assertTrue(table.concat(out, "\n"):find("boom", 1, true) ~= nil,
      "the raise is named on one line: " .. table.concat(out, "\n"))
  end)
  NS.Browser.Toggle = saved
  if not ok then error(err, 0) end
end)

-- ── The status tooltip (launcher-§1, standard v2.66.0; Launcher minor 3, hints since minor 4) ─
--
-- The LIBRARY draws the tooltip now, in one shape across the eleven addons: title and version,
-- Enabled, Locked and Test mode where the addon has them, the host's own lines, then the two click
-- hints. What only this repo can assert is WHICH fields it hands over and that each one reads the
-- same state the settings panel reads -- the drawing itself is the library's suite.

-- The tooltip's lines as the library draws them, with its green/red value escapes stripped so a
-- case compares words. The mock is the same `AddLine` shape GameTooltip offers.
local function tooltipLines()
  local lines = {}
  NS.Launcher:Object().OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = text end })
  for i, line in ipairs(lines) do
    lines[i] = tostring(line):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  end
  return lines
end

test("Launcher: the descriptor passes this addon's state pairs, and none of the retired fields",
function()
  -- Bank Ledger HAS every state the library asks about: the addon-wide switch (isEnabled /
  -- setEnabled), the Master-controls "Lock frame" row (isLocked / toggleLock), the sample-ledger
  -- test mode (isTestMode / toggleTestMode) and a primary window, the ledger browser
  -- (isWindowShown / toggleWindow). Launcher minor 4 retired four fields; passing them is dead
  -- configuration (launcher-§5).
  --
  -- Dies under: dropping any field from core/LauncherSetup.lua, or a retired one coming back.
  local src = readSource("core/LauncherSetup.lua")
  for _, field in ipairs({ "version", "isEnabled", "setEnabled", "isLocked", "toggleLock",
      "isTestMode", "toggleTestMode", "isWindowShown", "toggleWindow", "openSettings" }) do
    assertTrue(src:find("\n  " .. field .. "%s*=") ~= nil, "the descriptor does not pass `" .. field .. "`")
  end
  for _, field in ipairs({ "onClick", "leftClickLabel", "disabledLine", "slash" }) do
    assertEqual(src:find("\n  " .. field .. "%s*="), nil, "the descriptor still passes the retired `" .. field .. "`")
  end
end)

test("Launcher: the tooltip draws the library's block around this addon's one extra line", function()
  -- Dies under: the host hook drawing a title or a click hint again (anti-pattern #89 -- the
  -- library draws both, so the hook's copy is a second one), or losing the movement count.
  local savedLocked = S:Get("settings.locked")
  S:Set("settings.locked", false)
  local lines = tooltipLines()
  S:Set("settings.locked", savedLocked)

  assertEqual(lines[1], "Ka0s Bank Ledger  v" .. NS.Version(), "title: the brand, then the TOC's version")
  assertEqual(lines[2], "Enabled: Yes")
  assertEqual(lines[3], "Locked: No")
  assertEqual(lines[4], "Test mode: Off")
  assertTrue(lines[5]:match("^%d+ movements?$") ~= nil, "the host's own line is the entry count: " .. lines[5])
  assertEqual(lines[6], "Left-click: Open settings")
  assertEqual(lines[7], "Right-click: Options menu")
  assertEqual(#lines, 7, "exactly seven lines, one title and one pair of hints: "
    .. table.concat(lines, " / "))
end)

test("Launcher: the tooltip's Locked and Test mode lines read what the panel reads, on every show",
function()
  -- Never cached: flip each state through the surface a player uses and hover again.
  --
  -- Dies under: isLocked reading anything but the store the Lock frame row writes, isTestMode
  -- reading anything but LT:IsTestMode (the Test mode row's own get), or either being captured once.
  local savedLocked = S:Get("settings.locked")
  local LT = NS.LedgerTable
  local savedIsTest = LT.IsTestMode
  local testOn = false
  LT.IsTestMode = function() return testOn end
  local ok, err = pcall(function()
    S:Set("settings.locked", true)
    testOn = true
    local lines = tooltipLines()
    assertEqual(lines[3], "Locked: Yes")
    assertEqual(lines[4], "Test mode: On")
    assertEqual(S:Get("state.testMode"), true, "the row and the tooltip read one switch")

    S:Set("settings.locked", false)
    testOn = false
    lines = tooltipLines()
    assertEqual(lines[3], "Locked: No")
    assertEqual(lines[4], "Test mode: Off")
  end)
  LT.IsTestMode = savedIsTest
  S:Set("settings.locked", savedLocked)
  if not ok then error(err, 0) end
end)

-- ── The Minimap button row (launcher-§3) ─────────────────────────────────────────────────────

test("Minimap row: it is composed onto Master controls, stored, and SHOWN by default", function()
  -- The composer emits it from `minimapPath` (LibKa0s v1.39.0, compose minor 7); it is never
  -- hand-written. STORED, not session-only: a button the player hid stays hidden across a reload.
  --
  -- Dies under: dropping minimapPath from S.MASTER_SPEC, or reinstating the old Interface-tab row.
  local row = S:FindRow(MINIMAP_PATH)
  assertTrue(row ~= nil, "no Minimap button row was composed")
  assertEqual(row.label, "Minimap button")
  assertEqual(row.group, "Master controls")
  assertEqual(row.type, "bool")
  assertEqual(row.widget, "CheckBox")
  assertEqual(row.default, true, "the row's own sense is SHOWN")
  assertFalse(row.sessionOnly == true, "the button's visibility survives a reload")
  assertTrue(row.startsLine == true, "Minimap button opens the fourth line of the canonical set")

  local seen = 0
  for _, r in ipairs(S.Schema) do if r.path == MINIMAP_PATH then seen = seen + 1 end end
  assertEqual(seen, 1, "two rows over one boolean is the drift options-ui-§15 exists to end")
end)

test("Minimap row: the label says SHOWN and LibDBIcon's key says HIDDEN", function()
  -- The whole cost of storing the library's own key, and it is cheaper than the alternative: a
  -- second boolean beside a field LibDBIcon writes itself, from its own right-click menu.
  --
  -- Dies under: dropping either arm of the inversion at the write seam.
  local saved = NS.db.global.minimap.hide

  S:Set(MINIMAP_PATH, false)
  assertEqual(NS.db.global.minimap.hide, true, "unticking the box must HIDE the button")
  assertEqual(S:Get(MINIMAP_PATH), false, "the row reads back in its own sense")

  S:Set(MINIMAP_PATH, true)
  assertEqual(NS.db.global.minimap.hide, false)
  assertEqual(S:Get(MINIMAP_PATH), true)

  NS.db.global.minimap.hide = saved
end)

test("Minimap row: writing it MOVES the button, not just the store", function()
  -- launcher-§3 asks for Show/Hide at the write seam so the button follows the checkbox
  -- immediately rather than at the next reload. It rides the row's onChange, which is the seam's
  -- own reaction hook — so a slash write, a panel click and a reset all reach it.
  local saved = NS.db.global.minimap.hide

  button.shown = nil
  S:Set(MINIMAP_PATH, false)
  assertEqual(button.shown, false, "LibDBIcon:Hide was never called")
  S:Set(MINIMAP_PATH, true)
  assertEqual(button.shown, true, "LibDBIcon:Show was never called")

  -- The same act through the CLI, because "the same function /bl set calls" is the point of a
  -- single write seam.
  captureChat(function() NS.Slash:CliSet(MINIMAP_PATH .. " false") end)
  assertEqual(button.shown, false)
  assertEqual(NS.db.global.minimap.hide, true)

  -- And a reset of the one row, which restores the row's default (SHOWN) and so un-hides it.
  captureChat(function() NS.Slash:CliReset(MINIMAP_PATH) end)
  assertEqual(button.shown, true)
  assertEqual(NS.db.global.minimap.hide, false)

  NS.db.global.minimap.hide = saved
end)

test("Minimap row: LibDBIcon's own minimapPos is never trampled", function()
  -- The library writes minimapPos into the same table when the player drags the button. The row
  -- addresses one field of that table and nothing here replaces the table whole (architecture-§5).
  local saved, savedPos = NS.db.global.minimap.hide, NS.db.global.minimap.minimapPos
  NS.db.global.minimap.minimapPos = 217.5
  S:Set(MINIMAP_PATH, false)
  S:Set(MINIMAP_PATH, true)
  assertEqual(NS.db.global.minimap.minimapPos, 217.5, "the dragged angle survived a write of hide")
  NS.db.global.minimap.hide, NS.db.global.minimap.minimapPos = saved, savedPos
end)

-- ── The CLI path reads in the row's own sense (launcher-§3, standard v2.65.0) ─────────────────
--
-- `minimap.shown` is the name a player types; `db.global.minimap.hide` is still where the boolean
-- lives, because LibDBIcon owns that key and writes it from its own right-click menu. So the rename
-- is a CLI rename only: no SavedVariables change, no migration, and a stored `shown` key would be
-- the second copy of one state anti-pattern #81 forbids.

--- Whether any `shown` key sits in the RAW minimap table (rawget, so an AceDB default cannot hide one).
local function hasStoredShown()
  local t = rawget(NS.db.global, "minimap")
  return type(t) == "table" and rawget(t, "shown") ~= nil
end

test("Minimap row: /bl get minimap.shown answers true while db.global.minimap.hide is false", function()
  local saved = NS.db.global.minimap.hide
  NS.db.global.minimap.hide = false
  local out = captureChat(function() NS.Slash:CliGet("minimap.shown") end)
  NS.db.global.minimap.hide = saved
  local line = table.concat(out, "\n")
  assertTrue(line:find("minimap.shown", 1, true) ~= nil, "the get names the path: " .. line)
  assertTrue(line:find("true", 1, true) ~= nil, "a shown button reads true: " .. line)
  assertTrue(line:find("unknown", 1, true) == nil, "the renamed path is known: " .. line)
end)

test("Minimap row: /bl set minimap.shown false stores minimap.hide = true, hides the button and writes no shown key", function()
  local saved = NS.db.global.minimap.hide
  button.shown = nil
  captureChat(function() NS.Slash:CliSet("minimap.shown false") end)
  assertEqual(NS.db.global.minimap.hide, true, "the stored key is still LibDBIcon's hide")
  assertEqual(button.shown, false, "the button was hidden")
  assertFalse(hasStoredShown(), "a stored `shown` key is a second copy of one state (anti-pattern #81)")
  captureChat(function() NS.Slash:CliSet("minimap.shown true") end)
  assertEqual(NS.db.global.minimap.hide, false)
  assertFalse(hasStoredShown())
  NS.db.global.minimap.hide = saved
end)

test("Minimap row: a targeted /bl reset minimap.shown restores shown", function()
  local saved = NS.db.global.minimap.hide
  NS.db.global.minimap.hide = true
  button.shown = nil
  captureChat(function() NS.Slash:CliReset("minimap.shown") end)
  assertEqual(NS.db.global.minimap.hide, false, "the row's default is SHOWN")
  assertEqual(button.shown, true, "the reset moved the button")
  assertEqual(S:Default(MINIMAP_PATH), true, "S:Default reads the row's own sense")
  assertFalse(hasStoredShown())
  NS.db.global.minimap.hide = saved
end)

test("Minimap row: the old path minimap.hide answers unknown setting", function()
  assertEqual(S:FindRow("minimap.hide"), nil, "no row answers the retired CLI path")
  local ok = S:Set("minimap.hide", false)
  assertFalse(ok, "the seam refuses the retired path")
  local out = captureChat(function() NS.Slash:CliGet("minimap.hide") end)
  assertTrue(table.concat(out, "\n"):find("not found", 1, true) ~= nil,
    "/bl get minimap.hide answers Setting not found: " .. table.concat(out, "\n"))
end)

test("Minimap row: a legacy store keeps its choice with no migration", function()
  -- A player who hid the button before the rename: the store carries hide = true and a dragged
  -- angle. The renamed path reads it as NOT shown, the button stays hidden, the angle is untouched,
  -- and a write never leaves a `shown` key behind.
  local g = NS.db.global
  local savedHide, savedPos = g.minimap.hide, g.minimap.minimapPos
  g.minimap.hide, g.minimap.minimapPos = true, 200
  local out = captureChat(function() NS.Slash:CliGet("minimap.shown") end)
  assertTrue(table.concat(out, "\n"):find("false", 1, true) ~= nil, "a hidden button reads false")
  assertEqual(S:Get(MINIMAP_PATH), false)
  assertEqual(g.minimap.hide, true, "the stored choice did not move")
  S:Set(MINIMAP_PATH, false)
  assertEqual(g.minimap.hide, true)
  assertEqual(button.shown, false, "the button stays hidden")
  assertEqual(g.minimap.minimapPos, 200, "the dragged angle is untouched")
  assertFalse(hasStoredShown(), "no `shown` key is ever written to the raw store")
  g.minimap.hide, g.minimap.minimapPos = savedHide, savedPos
end)

test("Minimap row: S:Register reports 0 failures with the renamed path", function()
  -- The row's path is not a stored path, so Validate must resolve it against the declared hide
  -- default rather than against a `shown` key the defaults deliberately do not ship.
  local out = captureChat(function() assertEqual(S:Register(), 0) end)
  assertEqual(#out, 0, "Register printed: " .. table.concat(out, " | "))
  assertEqual(NS.defaults.global.minimap.shown, nil, "the defaults ship no `shown` key")
end)

test("Minimap row: the defaults ship the table, so nothing has to seed it", function()
  -- architecture-§5: writing `minimap = { hide = false }` over a path a row addresses is a
  -- whole-section write over a schema row. The declared default is what materializes the table,
  -- and AceDB does it before any of this runs.
  assertEqual(type(NS.defaults.global.minimap), "table", "defaults/Global.lua ships db.global.minimap")
  assertEqual(NS.defaults.global.minimap.hide, false)
  assertEqual(type(rawget(NS.db.global, "minimap")), "table", "AceDB materializes the table default")
  assertEqual(readSource("core/LauncherSetup.lua"):find("hide = false", 1, true), nil,
    "the seam must not seed a table the defaults already ship")
end)

-- ── The reserved verbs (slash-commands-§2) ───────────────────────────────────────────────────

test("Verbs: /bl enable and /bl disable are registered, and described the same way", function()
  local seen = {}
  for _, cmd in ipairs(NS.COMMANDS) do seen[cmd[1]] = cmd[2] end
  assertTrue(seen.enable ~= nil, "`enable` is a RESERVED verb and must exist")
  assertTrue(seen.disable ~= nil, "`disable` is a RESERVED verb and must exist")
end)

test("Verbs: they write the Enable row's stored path, through the same write seam", function()
  -- ALIASES, never a second switch: the checkbox and the verbs can never show the player two
  -- different answers, and one onChange runs whichever surface was used.
  local saved = S:Get("settings.enabled")

  local out = captureChat(function() NS.Slash:OnSlash("disable") end)
  assertEqual(NS.db.global.settings.enabled, false, "/bl disable must write settings.enabled")
  assertEqual(S:Get("settings.enabled"), false)
  -- slash-commands-§5's single-line `path = value` echo, from the shared formatter.
  assertTrue(table.concat(out, "\n"):find("settings.enabled", 1, true) ~= nil,
    "the verb echoes what it wrote: " .. table.concat(out, "\n"))

  captureChat(function() NS.Slash:OnSlash("enable") end)
  assertEqual(NS.db.global.settings.enabled, true, "/bl enable must write settings.enabled")

  -- The long name is the same write.
  captureChat(function() NS.Slash:OnSlash("set settings.enabled false") end)
  assertEqual(S:Get("settings.enabled"), false)

  S:Set("settings.enabled", saved)
end)

test("Verbs: they hold NO state of their own", function()
  -- No second key, no session flag, no NS.enabled local. The store is the only record.
  local saved = S:Get("settings.enabled")
  captureChat(function() NS.Slash:OnSlash("disable") end)
  assertEqual(NS.enabled, nil, "the verbs must not publish a flag of their own")
  assertEqual(rawget(NS.State, "enabled"), nil, "nor a session one")
  -- Written back through the schema alone, and the verb agrees with it.
  S:Set("settings.enabled", true)
  local out = captureChat(function() NS.Slash:OnSlash("get settings.enabled") end)
  assertTrue(table.concat(out, "\n"):find("true", 1, true) ~= nil, table.concat(out, "\n"))
  S:Set("settings.enabled", saved)
end)

test("Verbs: the dispatcher answers while DISABLED, so the pair is never one-way", function()
  -- slash-commands-§2. A player who can turn the addon off and not back on has a switch that only
  -- goes one way, and the only route left is the settings panel they were trying not to open. The
  -- dispatcher and the settings registration are SETUP, not features: they come up on load in
  -- either state and stay up.
  --
  -- Dies under: gating Sl:Register, NS.COMMANDS or the chat-command registration on the setting.
  local saved = S:Get("settings.enabled")
  captureChat(function() NS.Slash:OnSlash("disable") end)
  assertEqual(S:Get("settings.enabled"), false, "the addon is disabled for the rest of this case")

  for _, verb in ipairs({ "", "help", "version", "list" }) do
    local out = captureChat(function() NS.Slash:OnSlash(verb) end)
    assertTrue(#out > 0 or verb == "", "`/bl " .. verb .. "` answered nothing while disabled")
  end

  -- And the one that matters most.
  captureChat(function() NS.Slash:OnSlash("enable") end)
  assertEqual(S:Get("settings.enabled"), true, "/bl enable must work while the addon is disabled")

  S:Set("settings.enabled", saved)
end)

-- ── The degraded arm ─────────────────────────────────────────────────────────────────────────

test("LibKa0s-Launcher degraded: the stub answers every member the addon reaches", function()
  -- A real load with libs/LibKa0s left out, which is the only honest way to exercise a stub: a
  -- hand-stub after the fact cannot reproduce a file that failed to finish loading.
  --
  -- The stub is NOT a hand-rolled copy of the library's registration (anti-pattern #47). It says
  -- it wired nothing, reads the store so the settings row still reflects what the player chose,
  -- and records a SetShown so a caller that drives the button from elsewhere is not lying to the
  -- store. The Master-controls row that normally drives it is composed by LibKa0s-Options and is
  -- therefore absent on this same arm.
  local Env = dofile("tests/degraded_env.lua")
  local ns = Env.loadDegraded()

  assertTrue(type(ns.Launcher) == "table", "the seam must publish a stub, not nil")
  assertTrue(ns.Launcher.__degraded == true)
  for _, member in ipairs({ "Register", "IsRegistered", "Object", "IsShown", "SetShown" }) do
    assertTrue(type(ns.Launcher[member]) == "function", "the stub is missing " .. member)
  end

  local ok, err = pcall(function()
    assertFalse(ns.Launcher:Register(), "a degraded install wires no launcher")
    assertFalse(ns.Launcher:IsRegistered())
    assertEqual(ns.Launcher:Object(), nil)
    -- No db at all on this arm: InitDB is never called for the degraded environment.
    assertEqual(ns.Launcher:IsShown(), true, "with no store to read, the row reads SHOWN")
    assertFalse(ns.Launcher:SetShown(false), "nothing to move, and it says so")
  end)
  assertTrue(ok, "the degradation stub raised: " .. tostring(err))

  assertEqual(ns.LOGO_ICON, NS.LOGO_ICON, "the icon path is spelled before the library gate")
end)
