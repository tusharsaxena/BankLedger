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

-- ── the footer band (A1) ─────────────────────────────────────────────────────────────────────

test("skin chrome: the ledger footer is the skin's band, under both strings, and follows a switch", function()
  local ns, m, Skin = fresh()
  ns.Browser:Show()
  local bar = ns.Browser:GetWindow().footerBar
  assertTrue(bar ~= nil, "no footer band")
  local rec = Skin.painted[bar]
  assertTrue(rec ~= nil and rec.calls.Footer ~= nil, "the band is not the skin's Footer")
  assertEqual(ns.Browser._footer:GetParent(), bar, "a string on the window would sit under the band")
  assertEqual(ns.Browser._dbFooter:GetParent(), bar, "a string on the window would sit under the band")
  -- The geometry: taller and the band covers the panes' last rows, since they stop at _footerH.
  local win = ns.Browser:GetWindow()
  assertEqual(bar:GetHeight(), win._footerH - 1, "the band ends where the panes do")
  assertEqual(#rawget(bar, "__points"), 2, "the band's two bottom anchors")
  local left, right = { bar:GetPoint(1) }, { bar:GetPoint(2) }
  assertEqual(table.concat({ left[1], left[3], left[4], left[5] }, " "), "BOTTOMLEFT BOTTOMLEFT 1 1",
    "inside the window's 1px edge")
  assertEqual(left[2], win)
  assertEqual(table.concat({ right[1], right[3], right[4], right[5] }, " "), "BOTTOMRIGHT BOTTOMRIGHT -1 1",
    "inside the window's 1px edge")
  assertEqual(right[2], win)
  local function fill()
    local p = m.__paint(bar)
    return rgb(p.backdropColor or m.__paint(rec.regions.bg or rec.regions.fill).color)
  end
  assertEqual(fill(), tok(ns, "foot.bg"))
  switch(m, Skin, "obsidian")
  assertEqual(fill(), tok(ns, "foot.bg"), "the band after a switch")
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
