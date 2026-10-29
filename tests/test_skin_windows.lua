-- tests/test_skin_windows.lua — the windows' surfaces on the skin (the skinning rollout's BL-02;
-- core/SkinSetup.lua's NS.Skin over LibKa0s-Skin-1.0, skinning-§3, anti-pattern #107).
--
-- What this pins, and nothing the library pins itself: Ka0s Default draws the values these surfaces
-- drew before the skin engine (the History table's cached colors and the four tinted marks, the row
-- tints, the Insights triples, the palette and the signed escapes, the close control's own tints),
-- and a skin switch moves every one of them with no reload, because each is either a recorded
-- primitive or a host cache re-resolved in an OnLooksChanged listener.
--
-- THE SWITCH SKIN. A shipped skin no longer moves every token these cases compare (Loot History's
-- tests/skin_support.lua says why), so the cases switch to SWITCH, a test-only skin: Obsidian's
-- tokens with every color Ka0s Default would still draw inverted, so each compared token moves.
--
-- Ka0s Loot History's tests/test_skin_table.lua and tests/test_skin_insights.lua are the pattern.
-- Every case puts the skin back on Ka0s Default, stored and applied, whatever it raised.

local T = _G.BL_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "BankLedger"
local LT, W = NS.LedgerTable, NS.InsightsWidgets

-- ── the switch skin ──────────────────────────────────────────────────────────────────────────

local SWITCH = "bl-switch"

local function isColor(v)
  return type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number"
    and type(v[3]) == "number"
end

local function same(a, b)
  for i = 1, 4 do
    if (a[i] or 1) ~= (b[i] or 1) then return false end
  end
  return true
end

local function switchKey()
  if not Skin:GetSkin(SWITCH) then
    local base, ob = Skin:ResolveSkin(Skin.DEFAULT), Skin:ResolveSkin("obsidian")
    local tokens = {}
    for name, v in pairs(ob) do tokens[name] = v end
    for name, v in pairs(base) do
      if isColor(v) and isColor(tokens[name]) and same(v, tokens[name]) then
        tokens[name] = { 1 - v[1], 1 - v[2], 1 - v[3], v[4] }
      end
    end
    -- The palette too, entry by entry, so a categorical chart has somewhere to move.
    local series = {}
    for i, c in ipairs(base["chart.series"] or {}) do series[i] = { 1 - c[1], 1 - c[2], 1 - c[3], c[4] } end
    tokens["chart.series"] = series
    Skin:RegisterSkin({ key = SWITCH, label = "Switch (test)", tokens = tokens })
  end
  return SWITCH
end

-- ── back on Ka0s Default ─────────────────────────────────────────────────────────────────────
--
-- tests/test_skinsetup.lua's reset, for its reasons: a skin change queues the library's
-- settings-page re-render on the kit's timers, and the stored half has to follow the applied one.
local function reset()
  NS.WriteSkinChoice("ka0s", "ka0s")
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  if mocks.__fireTimers then mocks.__fireTimers() end
end

local function clean(fn)
  return function()
    reset()
    local ok, err = pcall(fn)
    reset()
    if not ok then error(err, 0) end
  end
end

local function switch()
  Skin:SetChoice(OWNER, "ka0s", switchKey())
  if mocks.__fireTimers then mocks.__fireTimers() end
end

local function rgb(t) return ("%.4f,%.4f,%.4f"):format(t[1], t[2], t[3]) end
local function tok(name)
  local r, g, b = NS.Skin.Color(name)
  return ("%.4f,%.4f,%.4f"):format(r, g, b)
end

-- A texture stand-in that remembers its last SetColorTexture.
local function recTex()
  local t = {}
  function t:SetColorTexture(r, g, b, a) self.c = { r, g, b, a } end
  t.SetShown = function() end
  return t
end

-- ── the History table ────────────────────────────────────────────────────────────────────────

test("skin windows: Ka0s Default's table colors are the values the table drew before the skin", clean(function()
  -- red under: a cached color resolved from the wrong token, or a token that moves Ka0s Default.
  assertEqual(rgb(LT._rgb.gold), "1.0000,0.9100,0.5500", "a gold row's pale gold (bl.gold, BL-G1)")
  assertEqual(rgb(LT._rgb.body), "0.9000,0.9000,0.9000", "the cells' flat gray")
  assertEqual(rgb(LT._rgb.header), "1.0000,0.8200,0.0000", "the header gold")
  assertEqual(rgb(LT._rgb.good), "0.3500,0.8000,0.4500", "a deposit")
  assertEqual(rgb(LT._rgb.bad), "1.0000,0.3300,0.3300", "a withdrawal")
end))

test("skin windows: a switch re-resolves the table's cached colors and its tinted marks", clean(function()
  -- The cache is what PaintCell reads 200 times a scroll tick, so a switch that left it alone would
  -- paint every row in the old skin; the marks are strings built once, so they would keep the old
  -- tint beside a relabelled header.
  local before = LT._rgb.header[1]
  switch()
  assertEqual(rgb(LT._rgb.gold), tok("bl.gold"), "bl.gold follows the switched skin")
  assertEqual(rgb(LT._rgb.header), tok("list.header.text"))
  assertEqual(rgb(LT._rgb.good), tok("sem.good"))
  assertTrue(LT._rgb.header[1] ~= before, "the switch skin did not move list.header.text")
  local fs = { text = "" }
  function fs:SetText(v) self.text = v end
  local frame, sortKey, sortAsc, groupBy = LT.headerFrame, LT.sortKey, LT.sortAsc, LT.groupBy
  LT.headerFrame = { buttons = { date = { fs = fs } } }
  LT.sortKey, LT.sortAsc, LT.groupBy = "date", true, "none"
  LT:UpdateHeaderArrows()
  LT.headerFrame, LT.sortKey, LT.sortAsc, LT.groupBy = frame, sortKey, sortAsc, groupBy
  local function b(v) return math.floor(v * 255 + 0.5) end
  local want = ("%d:%d:%d|t"):format(b(LT._rgb.header[1]), b(LT._rgb.header[2]), b(LT._rgb.header[3]))
  assertTrue(fs.text:find(want, 1, true) ~= nil, "the sort arrow kept the old skin's tint: " .. fs.text)
end))

test("skin windows: the row tints take the skin's RGB and keep the player's slider alpha", clean(function()
  -- The rollout's D2: list.stripe / list.hover give the color, the Interface sliders the alpha.
  local g = NS.db.profile.settings
  local saved = { g.rowStripeAlpha, g.rowHoverAlpha }
  g.rowStripeAlpha, g.rowHoverAlpha = 0.2, 0.4
  local ok, err = pcall(function()
    local row = { stripe = recTex(), rowHover = recTex() }
    NS.Util.ApplyRowTint(row, true)
    assertEqual(rgb(row.stripe.c), "1.0000,1.0000,1.0000", "Ka0s Default's stripe white")
    assertEqual(rgb(row.rowHover.c), "1.0000,0.8200,0.0000", "Ka0s Default's hover gold")
    assertEqual(row.stripe.c[4], 0.2, "the stripe slider's alpha")
    switch()
    NS.Util.ApplyRowTint(row, true)
    assertEqual(rgb(row.stripe.c), tok("list.stripe"), "the switched skin's stripe")
    assertEqual(rgb(row.rowHover.c), tok("list.hover"), "the switched skin's hover")
    assertEqual(row.rowHover.c[4], 0.4, "the hover slider's alpha still wins")
  end)
  g.rowStripeAlpha, g.rowHoverAlpha = saved[1], saved[2]
  if not ok then error(err, 0) end
end))

test("skin windows: the row menu's destructive entry is the skin's danger escape", clean(function()
  local items = LT:RowMenuItems({ itemID = 1 })
  assertEqual(items[4].label, "|cffff5555Delete|r", "Ka0s Default keeps its bytes")
  switch()
  items = LT:RowMenuItems({ itemID = 1 })
  assertEqual(items[4].label, NS.SkinEscape("sem.danger") .. "Delete|r")
end))

-- ── Insights ─────────────────────────────────────────────────────────────────────────────────

test("skin windows: Ka0s Default's Insights colors are the values Insights drew before the skin", clean(function()
  assertEqual(rgb(W.GOLD), "1.0000,0.8200,0.0000")
  assertEqual(rgb(W.NEUTRAL), "0.5500,0.6200,0.7200")
  assertEqual(rgb(W.MUTED), "0.8000,0.8000,0.8200")
  assertEqual(rgb(W.PaletteColor(1)), "0.9000,0.2500,0.2500", "the palette's first hue")
  assertEqual(W.PALETTE_SIZE, 21)
  assertTrue(W.SignedMoney(0):find("^|cff808080") ~= nil, "the gray em-dash")
  assertTrue(W.SignedCount(3) == "|cff40ff40+3|r", W.SignedCount(3))
  assertTrue(W.SignedCount(-3) == "|cffff4040-3|r", W.SignedCount(-3))
  -- A quality the client has no color for (a headless build): bl.qualityUnknown, D9.
  local saved = mocks.ITEM_QUALITY_COLORS
  mocks.ITEM_QUALITY_COLORS = nil
  local ok, got = pcall(W.QualityColor, 99)
  mocks.ITEM_QUALITY_COLORS = saved
  assertTrue(ok, tostring(got))
  assertEqual(rgb(got), "0.6000,0.6000,0.6200", "an unknown quality (bl.qualityUnknown, D9)")
end))

test("skin windows: a switch moves the Insights triples in place, the palette and the escapes", clean(function()
  -- In place: a row's color and the segment default hold these tables, so identity is the contract.
  local gold, neutral, first = W.GOLD, W.NEUTRAL, W.PaletteColor(1)
  switch()
  assertTrue(W.GOLD == gold and W.NEUTRAL == neutral, "the triples were replaced, not moved")
  assertEqual(rgb(W.GOLD), tok("text.heading"))
  assertEqual(rgb(W.NEUTRAL), tok("chart.other"))
  assertEqual(rgb(W.MUTED), tok("text.value"))
  local series = NS.Skin.Token("chart.series")
  assertEqual(rgb(first), rgb(series[1]), "the palette follows chart.series")
  assertEqual(W.SignedCount(3), NS.SkinEscape("sem.goodAlt") .. "+3|r")
end))

-- ── the close control ────────────────────────────────────────────────────────────────────────

test("skin windows: the close control keeps its own look under Ka0s Default and is the skin's elsewhere",
  clean(function()
    -- DECISIONS BankLedger D1: today's 0.85 rest and class-color hover are kept while the owner draws
    -- Ka0s Default (the primitive's stockDefault), and the primitive is recorded so any other skin
    -- paints close.rest / close.hot.
    local close = NS.Browser:MakeCloseButton(mocks.UIParent, function() end)
    local rec = Skin.painted and Skin.painted[close]
    assertTrue(rec ~= nil and rec.owner == OWNER, "the close control is not recorded for this owner")
    local args = rec.calls and rec.calls.CloseButton
    local opts = type(args) == "table" and (args[1] or args.n and args[1]) or nil
    assertTrue(type(opts) == "table" and opts.stockDefault == true,
      "the close control is not kept as this addon's own under Ka0s Default")
    assertEqual(tok("bl.closeRest"), "0.8500,0.8500,0.8500", "Ka0s Default's rest tint")
    switch()
    assertEqual(tok("bl.closeRest"), tok("close.rest"), "elsewhere the rest tint is the skin's close.rest")
  end))
