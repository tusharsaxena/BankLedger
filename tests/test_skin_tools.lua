-- tests/test_skin_tools.lua — this addon's own AceGUI widgets and its tool surfaces on the skin (the
-- skinning rollout's BL-04; core/SkinSetup.lua's NS.SkinPaintAce / NS.SkinPaintAceTree /
-- NS.SkinOnRelease over LibKa0s-Skin-1.0's SkinAce, skinning-§3).
--
-- What this pins:
--
--   * every AceGUI widget settings/Panel.lua acquires itself is painted for this owner while the
--     Scope's "Ignore settings panel" is off, EVEN THROUGH A HANDLE THAT IS NOT THE LIBRARY'S OWNER
--     PROXY (each case renders through the raw AceGUI fake, so the host's own NS.SkinPaintAce is
--     what paints); nothing is painted while the panel is ignored (a new profile's default); a
--     release hands the widget back stock; the Profiles page paints the tree AceConfigDialog drew;
--     the degraded seam paints nothing and still runs a host's release work.
--   * the debug console and the export copy window are painted for this owner by the LIBRARY.
--     LibKa0s-DebugLog-1.0 (minor 22) and W.CopyWindow (Widgets minor 16) treat `addonName` as the
--     owner ONLY when the host passes no `applySkin`: a host hook owns the whole job and is never
--     skinned over. Both descriptors passed one (routing to B:ApplySkin); both hooks are gone.
--   * the remaining tool seams (the sim panel's `name`, the Widgets factories' `owner`) still name
--     the owner. This addon holds performance-§12's exemption, so there is no perf panel.
--
-- The kit's widgets are recorders without AceGUI's regions, so "painted" is read where the library
-- keeps it: `Skin.__ace[widget].owner` (SkinAce.lua's weak state table), set while owned and
-- cleared by the restore. Ka0s Loot History's tests/test_skin_settings.lua and
-- tests/test_skin_tools.lua are the pattern. Leaves the skin on Ka0s Default, the panel ignored.

local T = _G.BL_TEST
local NS, mocks, Loader = T.NS, T.mocks, T.Loader
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

NS.Panel:Register()
local PS = dofile("tests/panel_support.lua")
local AceGUI = PS.AceGUI
local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OptionsLib = mocks.LibStub("LibKa0s-Options-1.0")
local OWNER = "BankLedger"
local O = NS.Helpers

-- ── the skin back on Ka0s Default (tests/test_skinsetup.lua's reset) ────────────────────────────
local WAS_SHOWN
local function reset(panelIgnored)
  if not WAS_SHOWN then
    WAS_SHOWN = {}
    for ctx in pairs(OptionsLib.__shownPages or {}) do
      if ctx.panel and ctx.panel:IsShown() then WAS_SHOWN[ctx] = true end
    end
  end
  local ignored = panelIgnored ~= false
  NS.WriteSkinChoice("ka0s", "ka0s", { panel = ignored, fonts = false })
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  Skin:SetIgnore(OWNER, ignored, false)
  mocks.__fireTimers()
  for ctx in pairs(WAS_SHOWN) do
    local panel = ctx.panel
    if rawequal(rawget(panel, "__ka0sSkinBg"), panel) then rawset(panel, "__ka0sSkinBg", nil) end
    if not (panel:IsShown() and OptionsLib.__shownPages[ctx]) then
      panel:Show()
      panel:__fire("OnShow")
    end
  end
  mocks.__fireTimers()
end

local function ownerOf(w)
  local st = Skin.__ace and Skin.__ace[w]
  return st and st.owner or nil
end

-- The widgets settings/Panel.lua acquires ITSELF, told apart from the library makers' rows (which
-- the raw handle below leaves unpainted, since the makers paint through the proxy): on Capture the
-- store grid's check boxes, one per store option; on Filters the list's description label and the
-- host's "Clear all..." button. A SimpleGroup has no painter and is never owned.
local function hostWidgets(tab, made)
  local want = {}
  if tab == "Capture" then
    for _, opt in ipairs(NS.Schema:FindRow("settings.excludedStores").values) do
      want[#want + 1] = function(w) return w.type == "CheckBox" and w.labelText == opt.text end
    end
  else
    want[1] = function(w) return w.type == "Button" and w.text == "Clear all\226\128\166" end
    want[2] = function(w) return w.type == "Label" and type(w.text) == "string" and #w.text > 20 end
  end
  local out = {}
  for _, match in ipairs(want) do
    for _, w in ipairs(made) do
      if match(w) then out[#out + 1] = w; break end
    end
  end
  assertEqual(#out, #want, tab .. ": every widget the host acquires was drawn")
  return out
end

--- Run `fn` on `skin`, the settings panel skinned (or ignored), with O.AceGUI swapped for the raw
--- AceGUI fake (no owner proxy), so only the host's own NS.SkinPaintAce can paint what the panel
--- acquires. Put back whatever `fn` raised.
local function withRawAce(skin, panelIgnored, fn)
  reset(panelIgnored)
  local saved = O.AceGUI
  local ok, err = pcall(function()
    NS.ApplySkinChoice("ka0s", skin)
    mocks.__fireTimers()
    O.AceGUI = AceGUI
    fn()
  end)
  O.AceGUI = saved
  PS.renderTab("General", "Master controls")
  reset()
  if not ok then error(err, 0) end
end

--- Render `tab` of the General page and answer the widgets the host acquired on it.
local function paintedOn(tab)
  return hostWidgets(tab, PS.renderTab("General", tab))
end

-- ── the panel's own widgets ─────────────────────────────────────────────────────────────────────

test("skin tools: under a non-default skin the panel's own widgets paint, past the proxy", function()
  -- red under: dropping NS.SkinPaintAce from settings/Panel.lua's acquire (the raw handle here
  -- paints nothing of its own). Capture draws the store grid's check boxes, Filters its label and
  -- its Clear all button.
  withRawAce("obsidian", false, function()
    for _, tab in ipairs({ "Capture", "Filters" }) do
      local ws = paintedOn(tab)
            for _, w in ipairs(ws) do
        assertEqual(ownerOf(w), OWNER, tab .. ": a " .. w.type .. " is painted for this owner")
        assertTrue(type(rawget(w, "OnRelease")) == "function", tab .. ": its release is wrapped")
      end
    end
  end)
end)

test("skin tools: a release hands every painted widget back stock, the pool clean", function()
  -- red under: a host that replaced the widget's OnRelease outright (the restore never runs).
  withRawAce("obsidian", false, function()
    local ws = paintedOn("Capture")
    for _, w in ipairs(ws) do
      assertEqual(ownerOf(w), OWNER, "owned before the release")
      if not w.__released then AceGUI:Release(w) end
      assertEqual(ownerOf(w), nil, "and nothing of this owner rides it to the next acquirer")
      assertEqual(rawget(w, "OnRelease"), nil, "the wrapper is taken back")
    end
  end)
end)

test("skin tools: while the Scope ignores the settings panel nothing is painted", function()
  -- A new profile's default (settings.appearance.ignorePanel = true): the page stays stock AceGUI,
  -- so Ka0s Default's settings page looks as it did before the skin engine.
  withRawAce("obsidian", true, function()
    for _, w in ipairs(paintedOn("Capture")) do
      assertEqual(ownerOf(w), nil, "a " .. w.type .. " was painted on an ignored panel")
    end
  end)
end)

test("skin tools: the Profiles page paints the tree AceConfigDialog drew", function()
  -- red under: dropping NS.SkinPaintAceTree from settings/Profiles.lua's renderer.
  local seen
  local paintTree = NS.SkinPaintAceTree
  NS.SkinPaintAceTree = function(container)
    seen = container
    return paintTree(container)
  end
  local ok, err = pcall(function()
    local PP = NS.ProfilesPage
    assertTrue(PP ~= nil, "settings/Profiles.lua published no page")
    local src = Loader.readFile("settings/Profiles.lua")
    local open = src:find("AceConfigDialog:Open%(APPNAME, container%)")
    local paint = src:find("NS%.SkinPaintAceTree%(container%)")
    assertTrue(open ~= nil and paint ~= nil and paint > open,
      "the renderer paints the container after AceConfigDialog fills it")
    if PP.ctx and mocks.__settingsPanels and mocks.__settingsPanels["Profiles"] then
      PS.renderPage("Profiles")
      assertTrue(seen ~= nil, "rendering the Profiles page painted no tree")
    end
  end)
  NS.SkinPaintAceTree = paintTree
  if not ok then error(err, 0) end
end)

test("skin tools: degraded, PaintAce and PaintAceTree paint nothing and a release still runs", function()
  local dns, dm = dofile("tests/degraded_env.lua").loadDegraded()
  local ace = dm.__libs["AceGUI-3.0"]
  local w = ace:Create("SimpleGroup")
  assertEqual(dns.SkinPaintAce(w), false, "PaintAce is a no-op")
  assertEqual(dns.SkinPaintAceTree(w), 0, "PaintAceTree paints nothing")
  local ran
  dns.SkinOnRelease(w, function(released) ran = released end)
  ace:Release(w)
  assertTrue(ran == w, "the host's release work runs without the library")
end)

-- ── the tool surfaces ──────────────────────────────────────────────────────────────────────────

-- Re-run one seam file against a fake LibKa0s major that records the descriptor it is handed, into
-- a scratch namespace, so the fields the library reads are asserted rather than inferred.
local function capture(file, major, ns)
  local captured
  local fake = { New = function(_, d) captured = d; return {} end }
  local fakeLibStub = setmetatable({}, { __call = function(_, name)
    if name == major then return fake end
  end })
  local scratch = setmetatable({ LibStub = fakeLibStub }, { __index = mocks })
  Loader.load(file, ns, scratch)
  return captured
end

test("skin tools: the debug console's descriptor names the owner and passes no applySkin", function()
  local d = capture("core/DebugLogSetup.lua", "LibKa0s-DebugLog-1.0", {
    Constants = { FONT_MONO = "mono" }, LIBKA0S_MISSING = "",
  })
  assertTrue(d ~= nil, "core/DebugLogSetup.lua must build its console through DebugLog:New")
  assertEqual(d.addonName, OWNER, "addonName is the folder, the owner core/SkinSetup.lua registered")
  assertTrue(d.applySkin == nil,
    "a host applySkin owns the whole job, so the library never paints the console for its owner")
  assertTrue(d.skin == nil, "a host skin table opts the console out of its owner the same way")
end)

test("skin tools: the live debug console and its copy window are painted for this owner", function()
  NS.DebugLog:Show()
  local f = NS.DebugLog._frameForTest
  assertTrue(f ~= nil, "the console frame")
  -- DebugLogWindow's adopt(): an owned console colors its lines from the owner's palette.
  assertTrue(rawget(f, "__logLine") ~= nil, "the console was built unowned (no palette line)")
  local rec = Skin.painted[f]
  assertTrue(rec ~= nil and rec.owner == OWNER, "the console window is recorded for " .. OWNER)
  NS.DebugLog:ShowCopy()
  local cf = NS.DebugLog._copyFrameForTest
  assertTrue(cf ~= nil, "the console's copy window")
  assertTrue(rawget(cf, "__copyDesc") ~= nil, "the console's copy window was not painted for an owner")
  cf:Hide()
  NS.DebugLog:Hide()
end)

test("skin tools: the export copy window is painted for this owner", function()
  NS.Export.__showCopy("a,b\n1,2")
  local f = NS.Export.__copyWindow:GetFrame()
  assertTrue(f ~= nil, "the export copy window")
  assertTrue(rawget(f, "__copyDesc") ~= nil,
    "the export copy window was painted by a host applySkin, not for its owner")
  local rec = Skin.painted[f]
  assertTrue(rec ~= nil and rec.owner == OWNER, "the export copy window is recorded for " .. OWNER)
  f:Hide()
end)

test("skin tools: every remaining factory seam passes the owner", function()
  -- The sim panel's owner is the Sim descriptor's `name` (SimPanel minor 7): read here so a rename
  -- goes red. No perf panel: performance-§12's exemption (docs/performance.md).
  local sim = Loader.readFile("modules/Sim.lua")
  assertTrue(sim:find("name%s*=%s*addonName") ~= nil or sim:find('name%s*=%s*"BankLedger"') ~= nil,
    "the Sim descriptor's name is the owner")
  local export = Loader.readFile("modules/Export.lua")
  assertTrue(export:find("applySkin%s*=") == nil, "modules/Export.lua passes no applySkin")
  local console = Loader.readFile("core/DebugLogSetup.lua")
  assertTrue(console:find("applySkin%s*=") == nil, "core/DebugLogSetup.lua passes no applySkin")
end)
