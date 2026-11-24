-- tests/test_skin_chrome.lua — the windows' chrome on the skin's own primitives (causes A1, L8 and
-- L9 of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING/).
--
-- A fresh addon on the kit's paint recorder, because the shared mock's regions store nothing: every
-- case reads what the drawing setters were told (M.__paint), so a repaint that never reached the
-- client's setters is red, where comparing a token getter before and after would pass.

local T = _G.BL_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "BankLedger"
local TAB_NAMES = { "History", "Insights" }

local function fresh()
  local m = T.makeMocks()
  dofile("tests/_kit/mock_paint.lua")(m)
  local ns = {}
  T.Loader.loadAll(T.libka0sFiles, ns, m)
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  ns:InitDB()
  ns.Schema:Register()
  ns.Ledger:Enable()
  return ns, m, m.LibStub("LibKa0s-Skin-1.0")
end

local function rgb(c) return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3]) end
local function tok(ns, name) return rgb({ ns.Skin.Color(name) }) end
local GOLD = rgb({ 1, 0.82, 0 })   -- Ka0s Default's gold: every skin's selected dropdown row

local function switch(m, Skin, key)
  Skin:SetChoice(OWNER, "ka0s", key)
  if m.__fireTimers then m.__fireTimers() end
end

-- ── the ledger window's tabs (A1) ────────────────────────────────────────────────────────────

test("skin chrome: the ledger tabs are the skin's Tab, with the active one selected", function()
  local ns, m, Skin = fresh()
  ns.Browser:Show()
  local tabs = ns.Browser:GetWindow().tabs
  local active = ns.Browser:ActiveTab()
  for _, name in ipairs(TAB_NAMES) do
    local tab = tabs[name]
    local rec = Skin.painted[tab]
    assertTrue(rec ~= nil and rec.owner == OWNER and rec.calls.Tab ~= nil, name .. " is not the skin's Tab")
    assertEqual(rgb(m.__paint(tab.label).textColor), tok(ns, name == active and "tab.onText" or "tab.text"),
      name .. "'s label")
    assertTrue(rawget(tab, "underline") == nil, name .. " still hand-builds an underline")
  end
end)

test("skin chrome: selecting a tab moves the skin's selection, and a switch repaints it", function()
  local ns, m, Skin = fresh()
  ns.Browser:Show()
  local tabs = ns.Browser:GetWindow().tabs
  ns.Browser:SelectTab("Insights")
  assertEqual(rgb(m.__paint(tabs.Insights.label).textColor), tok(ns, "tab.onText"))
  assertEqual(rgb(m.__paint(tabs.History.label).textColor), tok(ns, "tab.text"))
  local before = rgb(m.__paint(tabs.History.label).textColor)
  switch(m, Skin, "obsidian")
  assertTrue(before ~= tok(ns, "tab.text"), "Obsidian does not move tab.text, so this asserts nothing")
  assertEqual(rgb(m.__paint(tabs.Insights.label).textColor), tok(ns, "tab.onText"), "the selected label")
  assertEqual(rgb(m.__paint(tabs.History.label).textColor), tok(ns, "tab.text"), "the other label")
  local line = Skin.painted[tabs.Insights].regions.line
  assertEqual(rgb(m.__paint(line).color), tok(ns, "tab.onLine"), "the underline on the selected tab")
  ns.Browser:SelectTab("History")
end)

test("skin chrome: the tab strip sits on the skin's tab.rule", function()
  local ns, m = fresh()
  ns.Browser:Show()
  local rule = ns.Browser:GetWindow().tabRule
  assertTrue(rule ~= nil, "no rule under the tab strip")
  local rec = m.LibStub("LibKa0s-Skin-1.0").painted[rule]
  assertEqual(rgb(m.__paint(rec.regions.line).color), tok(ns, "tab.rule"))
end)

-- ── the footer (A1; the library's W.Footer since AD-89-BL) ───────────────────────────────────
--
-- The ledger's footer is LibKa0s-Widgets-1.0's Footer (standalone-windows, *The footer*): no fill of
-- its own, a hairline in the skin's `divider` along its top, both lines in `text.muted`, painted for
-- this owner so a switch repaints them. AD-89-BL retired the hand-built 18 px band on the skin's
-- `foot.bg` (S.Footer) that this case pinned before; it now pins the library's look.

test("skin chrome: the ledger footer is the library's, unfilled, and its hairline and lines follow a switch",
function()
  local ns, m, Skin = fresh()
  ns.Browser:Show()
  local win = ns.Browser:GetWindow()
  local foot = win.footer
  assertTrue(foot ~= nil and foot.line ~= nil, "no library footer")
  T.assertNil(win.footerBar, "the hand-built band is still there")
  local rec = Skin.painted[foot]
  assertTrue(rec == nil or rec.calls.Footer == nil, "the footer is still painted as the skin's filled band")
  T.assertNil(m.__paint(foot).backdropColor, "the footer draws a fill of its own")
  assertEqual(ns.Browser._footer:GetParent(), foot, "the record count is not on the footer")
  assertEqual(ns.Browser._dbFooter:GetParent(), foot, "the database size is not on the footer")
  local function looks()
    return rgb(m.__paint(foot.line).color), rgb(m.__paint(foot.left).textColor),
      rgb(m.__paint(foot.right).textColor)
  end
  local line, left, right = looks()
  assertEqual(line, tok(ns, "divider"), "the hairline is not the skin's divider")
  assertEqual(left, tok(ns, "text.muted"), "the left line is not text.muted")
  assertEqual(right, tok(ns, "text.muted"), "the right line is not text.muted")
  switch(m, Skin, "obsidian")
  line, left, right = looks()
  assertEqual(line, tok(ns, "divider"), "the hairline after a switch")
  assertEqual(left, tok(ns, "text.muted"), "the left line after a switch")
  assertEqual(right, tok(ns, "text.muted"), "the right line after a switch")
end)

-- ── the grips and the marks (L8) ─────────────────────────────────────────────────────────────

test("skin chrome: both windows' grips name this addon as the skin owner", function()
  local ns = fresh()
  local real, seen = ns.MakeResizable, {}
  ns.MakeResizable = function(f, opts)
    seen[#seen + 1] = opts.owner
    return real(f, opts)
  end
  ns.Browser:Show()
  ns.SessionWindow:Show()
  assertEqual(table.concat(seen, ","), OWNER .. "," .. OWNER)
  ns.SessionWindow:Hide()
end)

test("skin chrome: sort arrows take list.header.arrow (SF-L2), not icon.arrow", function()
  local ns, m, Skin = fresh()
  local tokens = {}
  for k, v in pairs(Skin:ResolveSkin("obsidian")) do tokens[k] = v end
  tokens["list.header.arrow"] = { 0, 1, 0, 1 }
  tokens["icon.arrow"] = { 1, 0, 0, 1 }
  Skin:RegisterSkin({ key = "bl-arrow", label = "Arrow (test)", tokens = tokens })
  switch(m, Skin, "bl-arrow")
  local fs = { text = "" }
  function fs:SetText(v) self.text = v end
  local LT = ns.LedgerTable
  local saved = LT.headerFrame
  LT.headerFrame, LT.sortKey, LT.sortAsc, LT.groupBy = { buttons = { date = { fs = fs } } }, "date", true, "none"
  LT:UpdateHeaderArrows()
  LT.headerFrame = saved
  assertTrue(fs.text:find(":0:255:0|t", 1, true) ~= nil, "the sort arrow is not in list.header.arrow: " .. fs.text)
end)

-- ── the title bars (L9) ──────────────────────────────────────────────────────────────────────

test("skin chrome: every title bar takes title.height and anchors its title on title.align", function()
  local ns, m, Skin = fresh()
  ns.Browser:Show()
  ns.SessionWindow:Show()
  local export = ns.Export:Open({})
  local bars = {
    { "ledger", ns.Browser:GetWindow().titleBar, ns.Browser:GetWindow().title },
    { "session", ns.SessionWindow:GetWindow().titleBar, ns.SessionWindow:GetWindow().title },
    { "export", export.titleBar, export.titleFS },
  }
  for _, b in ipairs(bars) do
    local rec = Skin.painted[b[2]]
    assertTrue(rec ~= nil and rec.calls.TitleBar ~= nil, b[1] .. " is not the skin's TitleBar")
    assertEqual(b[2]:GetHeight(), Skin:ResolveSkin("ka0s")["title.height"], b[1] .. "'s height")
    assertEqual((b[3]:GetPoint(1)), "CENTER", b[1] .. "'s title anchor")
  end
  local tokens = {}
  for k, v in pairs(Skin:ResolveSkin("obsidian")) do tokens[k] = v end
  tokens["title.align"] = "LEFT"
  Skin:RegisterSkin({ key = "bl-left", label = "Left (test)", tokens = tokens })
  switch(m, Skin, "bl-left")
  for _, b in ipairs(bars) do
    assertEqual((b[3]:GetPoint(1)), "LEFT", b[1] .. "'s title follows title.align")
  end
  ns.SessionWindow:Hide()
end)

test("skin chrome: the typed title height is title.height in every registered skin", function()
  -- Browser's SKIN.titleBarH is what the tab strip, the panes and the session pane measure from, and
  -- S.TitleBar's `place` gives the bars title.height. A skin that moved the token would stand the
  -- bar over the content, or leave a gap under it, with nothing else going red.
  local ns, m, Skin = fresh()
  local typed = ns.Browser.SKIN.titleBarH
  ns.Browser:Show()
  ns.SessionWindow:Show()
  local export = ns.Export:Open({})
  local bars = { ledger = ns.Browser:GetWindow().titleBar, session = ns.SessionWindow:GetWindow().titleBar,
                 export = export.titleBar }
  assertEqual(ns.SessionWindow:GetWindow()._paneTop, typed + 8, "the session pane's top")
  local skins = Skin:Skins()
  assertTrue(#skins > 1, "no skins to read")
  for _, def in ipairs(skins) do
    assertEqual(Skin:ResolveSkin(def.key)["title.height"], typed, def.key .. "'s title.height")
    switch(m, Skin, def.key)
    for name, bar in pairs(bars) do
      assertEqual(bar:GetHeight(), typed, name .. "'s bar under " .. def.key)
    end
  end
  switch(m, Skin, "ka0s")
  ns.SessionWindow:Hide()
end)

-- ── the header on the band (R5-WIN) ─────────────────────────────────────────────────────────

-- Round 5 (Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND5, the owner's items 2 and 5, the lead's
-- call 6): each window's title bar takes the band's rect (S.Band: Shell's own inset, `win.borderSize`
-- in from a flat edge, else 1, at `title.height`), so no body color shows between the edge and the
-- band in any skin; and every header child is anchored LEFT, CENTER or RIGHT to the band at y 0, its
-- geometric middle, never to a hand-placed bar at a hard-coded 1 px. The test badge rides the title's
-- right edge at y 0, so it is on the same middle. Headless, only the anchor shape can be measured.
local CENTERED = { LEFT = true, CENTER = true, RIGHT = true }

local function assertOnBand(region, band, what)
  local n = region:GetNumPoints()
  assertTrue(n >= 1 and n <= 2, what .. ": anchored")
  for i = 1, n do
    local point, rel, relPoint, _, y = region:GetPoint(i)
    assertTrue(CENTERED[point], ("%s: a %s point, never TOP*"):format(what, tostring(point)))
    assertEqual(relPoint, point, what .. ": to the band's own " .. tostring(point))
    assertTrue(rel == band, what .. ": anchored to the band")
    assertEqual(y, 0, what .. ": y 0, the band's middle")
  end
end

test("skin chrome: every window's header is on its band, in every skin (R5-WIN)", function()
  local ns, m, Skin = fresh()
  ns.Browser:Show()
  ns.SessionWindow:Show()
  local export = ns.Export:Open({})
  local ledger, session = ns.Browser:GetWindow(), ns.SessionWindow:GetWindow()
  local windows = {
    { "ledger", ledger, ledger.titleBar, ledger.title, ledger.closeButton },
    { "session", session, session.titleBar, session.title, session.closeButton },
    { "export", export, export.titleBar, export.titleFS, export.closeBtn },
  }
  -- Smoke round 2 (SR2-L2): no shipped skin draws a flat 2 px edge any more, so the 2 px branch of
  -- Shell's inset is kept covered by a test-local skin that sets one, and the nine shipped skins are
  -- pinned at their 1 px separately below.
  local shipped = {}
  for _, def in ipairs(Skin:Skins()) do shipped[#shipped + 1] = def.key end
  local tokens = {}
  for k, v in pairs(Skin:ResolveSkin("obsidian")) do tokens[k] = v end
  tokens["win.borderStyle"], tokens["win.borderSize"] = "flat", 2
  Skin:RegisterSkin({ key = "bl-edge2", label = "Edge 2 (test)", tokens = tokens })
  local insets, shippedInsets = {}, {}
  for _, def in ipairs(Skin:Skins()) do
    switch(m, Skin, def.key)
    local t = Skin:ResolveSkin(def.key)
    local inset = (t["win.borderStyle"] or "flat") == "flat" and t["win.borderSize"] or 1
    insets[inset] = true
    if def.key ~= "bl-edge2" then
      shippedInsets[inset] = true
      -- Ka0s Default keeps its own inner rule (EDGE); every other shipped skin draws none (SR2-L2).
      assertEqual(not t["win.inner"], def.key ~= "ka0s", def.key .. "'s inner rule (SR2-L2)")
    end
    for _, w in ipairs(windows) do
      local what = w[1] .. " under " .. def.key
      local band = ns.Skin.Band(w[2])
      assertTrue(band ~= nil, what .. ": a band")
      local _, rel, _, x, y = band:GetPoint(1)
      assertTrue(rel == w[2], what .. ": the band is the window's")
      assertEqual(x, inset, what .. ": the band at Shell's inset")
      assertEqual(y, -inset, what .. ": the band at Shell's inset")
      assertTrue(rawget(w[3], "__allPoints") == band, what .. ": the title bar takes the band's rect")
      assertOnBand(w[4], band, what .. "'s title")
      assertOnBand(w[5], band, what .. "'s close")
    end
  end
  assertTrue(insets[1] and insets[2], "the skins cover a 1 px and a 2 px edge")
  assertEqual(#shipped, 9, "the nine shipped skins")
  assertTrue(shippedInsets[1] and not shippedInsets[2], "every shipped skin sits its band at a 1 px inset")
  local badge = ledger.testBadge
  local point, rel, relPoint, _, y = badge:GetPoint(1)
  assertEqual(point .. relPoint, "LEFTRIGHT", "the badge rides the title's right edge")
  assertTrue(rel == ledger.title and y == 0, "on the title's, so the band's, middle")
  switch(m, Skin, "ka0s")
  ns.SessionWindow:Hide()
end)

-- ── no line under the title (R4-SEP) ────────────────────────────────────────────────────────

-- The owner's round 4 sign-off: no window has a line under its title band, as the Skin Tester's
-- showroom. Each window keeps its 1px `dividerBar` frame, because the ledger's tab strip anchors to
-- it, but nothing is drawn on it: no S.Divider call, so no rule texture. The rule under the tabs
-- (`tabRule`) is a body rule and stays.
local function watchDividers(ns)
  local seen, real = {}, ns.Skin.Divider
  ns.Skin.Divider = function(target, opts)
    seen[target] = true
    return real(target, opts)
  end
  return seen
end

local function headerLines(ns, Skin, seen)
  local lines = {}
  for name, win in pairs({ ledger = ns.Browser:GetWindow(), session = ns.SessionWindow:GetWindow() }) do
    local bar = win.dividerBar
    assertTrue(bar ~= nil, name .. " lost the dividerBar the layout anchors to")
    assertEqual(bar:GetHeight(), 1, name .. "'s dividerBar keeps its 1px")
    if seen[bar] or (Skin and Skin.painted[bar]) then lines[#lines + 1] = name end
  end
  table.sort(lines)
  return table.concat(lines, ",")
end

test("skin chrome: no window draws a line under its title band (R4-SEP)", function()
  local ns, _, Skin = fresh()
  local seen = watchDividers(ns)
  ns.Browser:Show()
  ns.SessionWindow:Show()
  assertEqual(headerLines(ns, Skin, seen), "", "a window with a line under its title")
  local win = ns.Browser:GetWindow()
  assertEqual(select(2, win.tabStrip:GetPoint(1)), win.dividerBar, "the tab strip still hangs from it")
  assertTrue(seen[win.tabRule] == true, "the rule under the tabs is a body rule and stays")
  ns.SessionWindow:Hide()
end)

-- ── degraded: today's look, with no skin to read ─────────────────────────────────────────────

local function degraded()
  local m = T.makeMocks()
  dofile("tests/_kit/mock_paint.lua")(m)
  local ns = {}
  T.Loader.loadAll(T.Loader.tocFiles("BankLedger.toc"), ns, m)
  return ns, m
end

test("skin chrome degraded: a Tab draws the label pair and a 2px underline, and selection moves them", function()
  local ns, m = degraded()
  local S = ns.Skin
  local tab = m.CreateFrame("Button", nil, m.UIParent)
  local fs = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  S.Tab(tab, { text = fs, selected = false })
  assertEqual(rgb(m.__paint(fs).textColor), rgb(ns.SKIN_FALLBACK["text.muted"]))
  assertTrue(not tab.__line:IsShown(), "an unselected tab shows no underline")
  S.SetTabSelection(tab, true)
  assertEqual(rgb(m.__paint(fs).textColor), rgb(ns.SKIN_FALLBACK["text.accent"]))
  assertTrue(tab.__line:IsShown(), "the selected tab shows its underline")
  assertEqual(rgb(m.__paint(tab.__line).color), rgb(ns.SKIN_FALLBACK["tab.onLine"]))
end)

test("skin chrome degraded: MarkText tints with the host copy's token", function()
  local ns = degraded()
  assertEqual(ns.Skin.MarkText("a\\b", 0, "icon.arrow"), "|Ta\\b:0:0:0:0:64:64:0:64:0:64:255:209:0|t")
  assertEqual(ns.Skin.MarkText("a\\b", 14, "no.such.token"), "|Ta\\b:14:14|t", "no color, the art's own")
end)

test("skin chrome degraded: HudFont draws, with a client face, the size floor and real flags", function()
  local ns, m = degraded()
  local S = ns.Skin
  local fs = m.UIParent:CreateFontString(nil, "OVERLAY")
  local function font() return table.concat(m.__paint(fs).font, "|") end
  S.HudFont(fs, { face = "a.ttf", size = 20, flags = "THICKOUTLINE" })
  assertEqual(font(), "a.ttf|20|THICKOUTLINE", "what the caller resolved, as it is")
  S.HudFont(fs, {})
  assertEqual(font(), m.STANDARD_TEXT_FONT .. "|12|OUTLINE", "no face, size or flags")
  S.HudFont(fs, { face = "a.ttf" })
  S.HudFont(fs)
  assertEqual(font(), m.STANDARD_TEXT_FONT .. "|12|OUTLINE", "no opts at all")
  S.HudFont(fs, { face = "a.ttf" })
  S.HudFont(fs, { face = "", size = 0, flags = S.FROM_SKIN })
  assertEqual(font(), m.STANDARD_TEXT_FONT .. "|12|OUTLINE", "the sentinel never reaches SetFont")
end)

test("skin chrome degraded: HudFont writes both shadow arms, so a cleared shadow clears", function()
  local ns, m = degraded()
  local S = ns.Skin
  local fs = m.UIParent:CreateFontString(nil, "OVERLAY")
  S.HudFont(fs, { shadow = true })
  local on = m.__paint(fs)
  assertEqual(on.shadowColor[4], 1, "on: an opaque shadow")
  assertEqual(on.shadowOffset[1] .. "," .. on.shadowOffset[2], "1,-1", "on: the offset")
  S.HudFont(fs, { shadow = false })
  local off = m.__paint(fs)
  assertEqual(off.shadowColor[4], 0, "off clears the color")
  assertEqual(off.shadowOffset[1] .. "," .. off.shadowOffset[2], "0,0", "off clears the offset")
end)

test("skin chrome degraded: HudFont with no face anywhere leaves the string alone", function()
  local ns, m = degraded()
  local fs = m.UIParent:CreateFontString(nil, "OVERLAY")
  m.STANDARD_TEXT_FONT = nil
  local answer = ns.Skin.HudFont(fs, { shadow = true })
  assertEqual(answer, nil)
  local p = m.__paint(fs)
  assertEqual(p.font, nil, "no SetFont")
  assertEqual(p.shadowOffset, nil, "no shadow either")
end)

test("skin chrome degraded: no window draws a line under its title band (R4-SEP)", function()
  local ns = degraded()
  ns:InitDB()
  ns.Schema:Register()
  ns.Ledger:Enable()
  local seen = watchDividers(ns)
  ns.Browser:Show()
  ns.SessionWindow:Show()
  assertEqual(headerLines(ns, nil, seen), "", "a window with a line under its title")
  ns.SessionWindow:Hide()
end)

-- ── the Character dropdown's selected row (FB2-BL-01; LibKa0s v1.113.0 Dropdown minor 4, D3) ──
--
-- The owner, 2026-11-24: "make the current selected always be a different color than the other
-- texts - e.g. gold in ka0s default", naming this dropdown's "Character: Current". Every dropdown in
-- this addon is the library's W.Dropdown (B:MakeDropdown) on the shared menu, so the rule is the
-- library's; these cases pin that Bank Ledger's own Character dropdown follows it on every skin.

local CLASS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, HUNTER = { r = 0.67, g = 0.83, b = 0.45 } }

--- A fresh addon whose ledger holds one row each of two class-colored characters, the window open.
local function charDropdown()
  local ns, m, Skin = fresh()
  m.RAID_CLASS_COLORS = CLASS
  m.__cursorX, m.__cursorY = 100, 100
  for _, row in ipairs({ { "Samplemage-Samplerealm", "MAGE" }, { "Samplehunter-Samplerealm", "HUNTER" } }) do
    ns.Database:Add({
      ts = 1770000000, char = row[1], classFile = row[2], kind = "ITEM", direction = "DEPOSIT",
      store = "BANK", itemID = 2589, itemName = "Linen Cloth", quality = 1, itemType = "Tradegoods",
      itemSubType = "Cloth", quantity = 10, zone = "Testville", mapID = 2657,
    })
  end
  ns.Browser:Show()
  ns.Browser:RefreshFilterOptions()
  return ns, m, Skin, ns.Browser._dd.char
end

--- Open `dd` and answer its menu's painted label colors by label text (class icon markup stripped).
--- The shared menu is built once per environment and reused, so it is captured on the first open
--- (the CreateFrame spy test_browser.lua uses) and kept on the mocks for the later ones.
local function openColors(m, dd)
  local saved = m.CreateFrame
  m.CreateFrame = function(...)
    local f = saved(...)
    if not rawget(m, "__blMenu") then rawset(m, "__blMenu", f) end
    return f
  end
  local ok, err = pcall(dd.__fire, dd, "OnClick")
  m.CreateFrame = saved
  if not ok then error(err, 0) end
  local W, menu = m.LibStub("LibKa0s-Widgets-1.0"), rawget(m, "__blMenu")
  assertTrue(menu ~= nil and menu.buttons ~= nil and menu:IsShown(), "the click did not open the shared menu")
  local out = {}
  for _, b in ipairs(menu.buttons) do
    if b:IsShown() then
      local text = tostring(b.fs:GetText() or ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
      out[text] = rgb(m.__paint(b.fs).textColor)
    end
  end
  W.CloseMenu()
  return out
end

local function find(colors, needle)
  for text, c in pairs(colors) do if text:find(needle, 1, true) then return c end end
end

test("skin dropdown: Character: Current paints the selected color, off plain and class rows, on every skin", function()
  -- red under: the library's selected row painting the skin's menu.textSel (its accent: the WoW
  -- Forever skin's tan) instead of Ka0s Default's gold, or a class color winning over the selection.
  -- The owner's 2026-11-24 ruling: the selected row is gold in every skin; only where gold sits
  -- under 20 CIEDE2000 from a skin's menu.text does its menu.textSel stand in (none of the nine does).
  local ns, m, Skin, dd = charDropdown()
  local W = m.LibStub("LibKa0s-Widgets-1.0")
  assertTrue(type(W.SelectedColor) == "function", "LibKa0s v1.113.0's W.SelectedColor is missing")
  local mage = rgb({ CLASS.MAGE.r, CLASS.MAGE.g, CLASS.MAGE.b })
  for _, def in ipairs(Skin:Skins()) do
    switch(m, Skin, def.key)
    ns.Browser:ApplyView(nil, nil)   -- the default scope: the Current sentinel
    local colors = openColors(m, dd)
    local current, all, mageRow = find(colors, "Character: Current"), find(colors, "Character: All"),
      find(colors, "Samplemage")
    assertTrue(current and all and mageRow, def.key .. ": the menu lacks a row")
    assertEqual(current, rgb({ W.SelectedColor(OWNER) }), def.key .. ": Current is not the selected color")
    assertEqual(current, GOLD, def.key .. ": Current is not Ka0s Default's gold")
    assertEqual(all, tok(ns, "menu.text"), def.key .. ": a plain row is not menu.text")
    assertTrue(current ~= all, def.key .. ": the selected row reads like a plain one")
    assertTrue(current ~= mage, def.key .. ": the selected row reads like a class-colored one")
    assertEqual(mageRow, mage, def.key .. ": an unselected character keeps its class color")
  end
  switch(m, Skin, "ka0s")
end)

test("skin dropdown: a selected character row trades its class color for the selected color", function()
  local ns, m, Skin, dd = charDropdown()
  local W = m.LibStub("LibKa0s-Widgets-1.0")
  for _, key in ipairs({ "ka0s", "azeroth", "forever" }) do
    switch(m, Skin, key)
    ns.Browser:ApplyView(nil, { ["Samplehunter-Samplerealm"] = true })
    local colors = openColors(m, dd)
    local hunter = find(colors, "Samplehunter")
    assertEqual(hunter, rgb({ W.SelectedColor(OWNER) }), key .. ": the selected hunter row")
    assertEqual(hunter, GOLD, key .. ": the selected hunter row is not gold")
    assertTrue(hunter ~= rgb({ CLASS.HUNTER.r, CLASS.HUNTER.g, CLASS.HUNTER.b }), key .. ": still its class color")
    assertEqual(find(colors, "Character: Current"), tok(ns, "menu.text"), key .. ": Current is not selected now")
  end
  switch(m, Skin, "ka0s")
end)
