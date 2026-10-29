-- tests/test_skinsetup.lua — the LibKa0s-Skin-1.0 seam (core/SkinSetup.lua, skinning-§3; the
-- skinning rollout's BL-01).
--
-- What this addon owes the skin engine, and nothing the library pins itself: the owner is
-- registered under the folder name with this addon's read and write seams and its owner tokens; the
-- seven appearance keys default to Ka0s Default and are skipRender schema rows on the Appearance
-- tab; the tab sits after History and before Keybindings; the profile's skin is applied on every
-- profile event; one pick, from this addon's tab or from another addon's copy, is ONE effective
-- SetChoice (one OnLooksChanged, at most one reload request), however many store writes follow it;
-- and every library widget factory this addon calls is handed the owner.
--
-- Ka0s Loot History's tests/test_skinsetup.lua is the pattern. Every case that moves the skin puts
-- it back on Ka0s Default, stored and applied.

local T = _G.BL_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

NS.Panel:Register()
local PS = dofile("tests/panel_support.lua")
local renderTab, ctxFor, GENERAL_TABS = PS.renderTab, PS.ctxFor, PS.GENERAL_TABS

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "BankLedger"

-- ONE listener of each kind for the whole file: the library keeps a listener for the session and
-- the same function twice is one entry, so each case resets the counters instead of registering.
local looks, reloads = 0, 0
NS.Skin.OnLooksChanged(function() looks = looks + 1 end)
Skin:OnReloadRequest(OWNER, function() reloads = reloads + 1 end)

local OptionsLib = mocks.LibStub("LibKa0s-Options-1.0")

-- Which settings pages were on screen before the first skin change (see reset). Taken at the first
-- reset rather than at file scope: the runner loads every suite file before it runs any.
local WAS_SHOWN

--- Back on Ka0s Default, stored and applied, with the counters cleared.
---
--- AND THE LIBRARY'S DEFERRED RE-RENDER RUN: a skin change re-renders the shown pages on the next
--- frame (C_Timer.After(0), queued on the kit's timers); left queued it would run inside a later
--- suite. AND THE PAGES PUT BACK ON SCREEN: away from Ka0s Default the library gives each page a
--- backdrop texture, which the kit's CreateTexture answers with the frame itself, so the way back
--- hides the page. Showing each page that was on screen again restores what the client has.
local function reset()
  if not WAS_SHOWN then
    WAS_SHOWN = {}
    for ctx in pairs(OptionsLib.__shownPages or {}) do
      if ctx.panel and ctx.panel:IsShown() then WAS_SHOWN[ctx] = true end
    end
  end
  NS.WriteSkinChoice("ka0s", "ka0s", { panel = true, fonts = false }, { font = false, texture = false })
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  Skin:SetIgnore(OWNER, true, false)
  if mocks.__fireTimers then mocks.__fireTimers() end
  for ctx in pairs(WAS_SHOWN) do
    local panel = ctx.panel
    if rawequal(rawget(panel, "__ka0sSkinBg"), panel) then rawset(panel, "__ka0sSkinBg", nil) end
    if not (panel:IsShown() and OptionsLib.__shownPages[ctx]) then
      panel:Show()
      panel:__fire("OnShow")
    end
  end
  if mocks.__fireTimers then mocks.__fireTimers() end
  looks, reloads = 0, 0
end

--- Run `fn` with the skin reset before and after, whatever `fn` raised.
local function clean(fn)
  return function()
    reset()
    local ok, err = pcall(fn)
    reset()
    if not ok then error(err, 0) end
  end
end

--- Run `fn` with chat silenced (a `/bl set` echoes its value).
local function quiet(fn)
  local cf = mocks.DEFAULT_CHAT_FRAME
  local add = cf.AddMessage
  cf.AddMessage = function() end
  local ok, err = pcall(fn)
  cf.AddMessage = add
  if not ok then error(err, 0) end
end

local function close(a, b) return math.abs(a - b) < 1e-6 end

-- ── the owner ────────────────────────────────────────────────────────────────────────────────

test("Skin seam: the owner is the folder name, and NS.Skin is its facade", function()
  -- red under: registering under the brand or a typo (the library keys every frame and every
  -- listener by owner), or publishing a facade of some other owner.
  assertTrue(Skin:IsOwner(OWNER), "core/SkinSetup.lua did not register the owner")
  assertTrue(rawequal(NS.Skin, Skin:For(OWNER)), "NS.Skin is not Skin:For(\"BankLedger\")")
  assertEqual(NS.Skin.owner, OWNER)
  assertEqual(Skin:OwnerLabel(OWNER), NS.BRAND_NAME, "the copy confirmation names the addon by its brand")
end)

test("Skin seam: the read answers Ka0s Default before the profile store exists", function()
  -- RegisterOwner calls `get` at FILE LOAD, before NS:InitDB; a getter that raised there would be a
  -- visible Lua error on every login.
  local db = NS.db
  NS.db = nil
  local ok, source, skin = pcall(NS.SkinChoice)
  local ok2, font, texture = pcall(NS.SkinOverride)
  NS.db = db
  assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
  assertEqual(source, "ka0s")
  assertEqual(skin, "ka0s")
  assertTrue(ok2, "NS.SkinOverride raised without a store: " .. tostring(font))
  assertTrue(font == false and texture == false, "no store, no override")
end)

-- ── the owner tokens (skinning-§1; the rollout's X1, X2, X12) ─────────────────────────────────

test("Skin seam: each owner token draws its Ka0s Default pixel and follows its role elsewhere", clean(function()
  -- red under: a token the library refused (a library family, a malformed definition), a default
  -- that is not the literal the call site drew, or a follow that names no library token.
  for name, def in pairs(NS.SKIN_TOKENS) do
    assertTrue(name:match("^bl%.") ~= nil, name .. ": an owner token is in the bl. namespace")
    local r, g, b = NS.Skin.Color(name)
    assertTrue(r ~= nil, name .. " does not resolve: the library refused it")
    assertTrue(close(r, def.default[1]) and close(g, def.default[2]) and close(b, def.default[3]),
      ("%s under Ka0s Default: %s,%s,%s"):format(name, r, g, b))
  end
  Skin:SetChoice(OWNER, "ka0s", "obsidian")
  for name, def in pairs(NS.SKIN_TOKENS) do
    local r, g, b = NS.Skin.Color(name)
    local fr, fg, fb = NS.Skin.Color(def.follow)
    assertTrue(close(r, fr) and close(g, fg) and close(b, fb),
      name .. " under Obsidian is not its follow token " .. def.follow)
  end
end))

test("Skin seam: the gold movement token is today's pale gold, not sem.gold", function()
  -- BL-G1: modules/LedgerTable.lua's MONEY_RGB. Snapping it to sem.gold moves Ka0s Default 0.05 in
  -- green, which the rollout's O1 forbids without asking.
  assertEqual(table.concat({ NS.SkinColor("bl.gold") }, ","), "1,0.91,0.55")
end)

-- ── the keys and the rows ────────────────────────────────────────────────────────────────────

local KEYS = {
  { "source", "ka0s", "string" }, { "skin", "ka0s", "string" },
  { "ignorePanel", true, "bool" }, { "ignoreFonts", false, "bool" },
  { "font", "", "string" }, { "texture", "", "string" },
  { "pickerSeen", false, "bool" },
}

test("Skin seam: the appearance keys default to today's look, as seven skipRender Appearance rows", function()
  -- red under: a default other than today's look (ignorePanel on: the owner's call of 2026-10-27;
  -- pickerSeen false on every profile: the rollout's O3), the keys moved out of `settings`, or a row
  -- that renders itself on top of the library's choice grids.
  local d = NS.defaults.profile.settings.appearance
  for _, k in ipairs(KEYS) do
    local key, want, kind = k[1], k[2], k[3]
    assertEqual(d[key], want, "default of " .. key)
    local path = "settings.appearance." .. key
    local row = NS.Schema:FindRow(path)
    assertTrue(row ~= nil, path .. " is not a schema row")
    assertEqual(row.type, kind, path .. ": type")
    assertEqual(row.group, "Appearance", path .. ": group")
    assertTrue(row.skipRender == true, path .. ": the tab draws it, so it must be skipRender")
  end
end)

test("Skin seam: the skin row's values are every registered skin, in the library's order", function()
  local values = NS.Schema:FindRow("settings.appearance.skin").values
  local skins = Skin:Skins()
  assertEqual(#values, #skins, "one value per registered skin")
  for i, def in ipairs(skins) do assertEqual(values[i].value, def.key, "value " .. i) end
  assertEqual(values[1].value, "ka0s", "Ka0s Default first")
end)

test("Skin seam: /bl set refuses a skin that is not registered and applies one that is", clean(function()
  -- The `values` check is the CLI parser's (LibKa0s-Slash-1.0), so this drives the verb.
  quiet(function()
    NS.Slash:CliSet("settings.appearance.skin no-such-skin")
    assertEqual(NS.db.profile.settings.appearance.skin, "ka0s", "an unknown skin was stored")
    assertEqual(looks, 0, "a refused set repainted")
    NS.Slash:CliSet("settings.appearance.skin obsidian")
  end)
  assertEqual(NS.db.profile.settings.appearance.skin, "obsidian", "a registered skin was refused")
  local _, applied = Skin:GetChoice(OWNER)
  assertEqual(applied, "obsidian", "a bare set must move the applied skin (the row's onChange)")
  assertEqual(looks, 1, "one set, one repaint")
end))

test("Skin seam: /bl set reaches an exception, and only its own half", clean(function()
  quiet(function() NS.Slash:CliSet("settings.appearance.ignoreFonts true") end)
  local panel, fonts = Skin:GetIgnore(OWNER)
  assertEqual(fonts, true, "the set applied")
  assertEqual(panel, true, "the other half untouched")
end))

-- ── the tab ──────────────────────────────────────────────────────────────────────────────────

test("Skin seam: the Skin tab sits after History and before Keybindings, labeled Skin", function()
  -- skinning-§3 and options-ui-§20: Keybindings stays last; seven tabs, inside options-ui-§13's
  -- budget. Read off the spec the page hands the library's strip.
  local O = NS.Helpers
  local real = O.TabStrip
  local spec
  O.TabStrip = function(c, sp)
    spec = sp
    return real(c, sp)
  end
  local ok, err = pcall(renderTab, "General", GENERAL_TABS[1])
  O.TabStrip = real
  if not ok then error(err, 0) end
  local at = {}
  for i, t in ipairs(spec.tabs) do at[t.key] = { i = i, label = t.label } end
  assertEqual(#spec.tabs, 7, "seven tabs")
  assertTrue(at.Appearance ~= nil, "no Appearance tab")
  assertEqual(at.Appearance.i, at.History.i + 1, "Appearance follows History")
  assertEqual(at.Keybindings.i, #spec.tabs, "Keybindings stays last")
  assertEqual(at.Appearance.label, "Skin", "the library's label")
  ctxFor("General").activeTab = GENERAL_TABS[1]
end)

--- Render the Appearance tab and answer the check box whose label ends with `name`.
local function choiceNamed(name)
  local made = renderTab("General", "Appearance")
  for _, w in ipairs(made) do
    local label = tostring(w.labelText or "")
    if w.type == "CheckBox" and label:sub(-#name) == name then return w end
  end
  return nil
end

test("Skin seam: one tab pick is one effective SetChoice, one repaint and no reload", clean(function()
  -- The tab calls SetChoice first, then the write seam, which writes the rows through
  -- NS.Schema:Set; each row's onChange applies only its own half and finds it applied already.
  -- red under: an onChange that re-applies the whole stored pair (two repaints, the first to a
  -- half-written skin), or a seam that writes the profile around NS.Schema:Set.
  local ok, err = pcall(function()
    local cb = choiceNamed("Obsidian")
    assertTrue(cb ~= nil, "the Appearance tab drew no Obsidian choice")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    assertEqual(looks, 1, "one pick must repaint exactly once")
    assertEqual(reloads, 0, "a Ka0s-to-Ka0s pick asks for no reload")
    local source, skin = Skin:GetChoice(OWNER)
    assertEqual(source, "ka0s")
    assertEqual(skin, "obsidian", "the pick did not move the applied skin")
    assertEqual(NS.db.profile.settings.appearance.skin, "obsidian", "the pick did not reach the profile")
  end)
  ctxFor("General").activeTab = GENERAL_TABS[1]
  if not ok then error(err, 0) end
end))

test("Skin seam: the tab's Ignore fonts reaches the library and the profile, one repaint", clean(function()
  local ok, err = pcall(function()
    local cb = choiceNamed("Ignore fonts")
    assertTrue(cb ~= nil, "the Appearance tab drew no Ignore fonts box")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the library's exception moved")
    assertEqual(panel, true, "and the other kept")
    assertEqual(NS.db.profile.settings.appearance.ignoreFonts, true, "the profile holds it")
    assertEqual(looks, 1, "one toggle repaints once")
  end)
  ctxFor("General").activeTab = GENERAL_TABS[1]
  if not ok then error(err, 0) end
end))

test("Skin seam: another addon's copy to every Ka0s addon repaints BankLedger once", clean(function()
  -- The library's copy calls SetChoice for each owner, then WriteChoice, which reaches this addon's
  -- registered setter. Driven through a fake second owner.
  Skin:RegisterOwner("BLSkinProbeAddon", { label = "Skin Probe",
    get = function() return "ka0s", "ember" end, set = function() end })
  Skin:SetChoice(OWNER, "ka0s", "ember")
  assertTrue(Skin:WriteChoice(OWNER, "ka0s", "ember"), "the copy's write did not reach this addon's setter")
  assertEqual(looks, 1, "a copy must repaint this addon exactly once")
  assertEqual(NS.db.profile.settings.appearance.skin, "ember", "the copy did not land in the profile")
end))

-- ── the profile events ───────────────────────────────────────────────────────────────────────

test("Skin seam: a profile switch applies the new profile's skin, exceptions and overrides", clean(function()
  -- NS.OnProfileEvent applies the skin whether or not a window was ever built. red under: not
  -- applying it on a switch, or applying the pair and dropping the exceptions.
  local db = NS.db
  local ok, err = pcall(function()
    quiet(function() db:SetProfile("SkinProbe") end)
    local a = db.profile.settings.appearance
    a.skin, a.ignoreFonts = "glass", true
    quiet(function() db:SetProfile("Default") end)
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "back on Default, Default's skin")
    looks = 0
    quiet(function() db:SetProfile("SkinProbe") end)
    assertEqual(select(2, Skin:GetChoice(OWNER)), "glass", "the switch did not move the applied skin")
    assertEqual(select(2, Skin:GetIgnore(OWNER)), true, "the stored fonts exception came with it")
    assertEqual(looks, 2, "one repaint for the skin and one for the exception")
  end)
  quiet(function()
    if db:GetCurrentProfile() ~= "Default" then db:SetProfile("Default") end
    if db.DeleteProfile then pcall(db.DeleteProfile, db, "SkinProbe", true) end
  end)
  if not ok then error(err, 0) end
end))

-- ── the owner handed to every library factory ────────────────────────────────────────────────

test("Skin seam: every Widgets factory this addon calls is handed the owner", function()
  -- red under: a factory call without `owner` (the widget keeps the library's stock look whatever
  -- the player picked). The calls are spied on the library table, which every seam reads at call
  -- time.
  local W = mocks.LibStub("LibKa0s-Widgets-1.0")
  local seen = {}
  local saved = {}
  for _, name in ipairs({ "Dropdown", "SearchBox", "Autocomplete" }) do
    saved[name] = W[name]
    W[name] = function(a, b, c)
      local opts = (name == "Dropdown" or name == "SearchBox") and c or b
      seen[name] = type(opts) == "table" and opts.owner or "none"
      return saved[name](a, b, c)
    end
  end
  local ok, err = pcall(function()
    local B = NS.Browser
    local parent = mocks.CreateFrame("Frame")
    B:MakeDropdown(parent, 100)
    local box = B:MakeSearchBox(parent, {})
    B:MakeAutocomplete(box or mocks.CreateFrame("EditBox"), { provider = function() return {} end })
    W.TestStrip(parent, { owner = OWNER })   -- the strip builders run inside window builds; see below
  end)
  for name, fn in pairs(saved) do W[name] = fn end
  if not ok then error(err, 0) end
  for _, name in ipairs({ "Dropdown", "SearchBox", "Autocomplete" }) do
    assertEqual(seen[name], OWNER, name .. " was not handed the owner")
  end
  -- The two mode strips (modules/Browser.lua buildModeStrip, modules/SessionWindow.lua buildStrip)
  -- are built inside their windows' first show, so they are held by the source.
  for _, path in ipairs({ "modules/Browser.lua", "modules/SessionWindow.lua" }) do
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    for call in src:gmatch("W%.TestStrip%b()") do
      assertTrue(call:find("owner = addonName", 1, true) ~= nil, path .. ": a TestStrip without the owner")
    end
  end
end)
