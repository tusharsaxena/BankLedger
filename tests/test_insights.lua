local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local W = NS.InsightsWidgets
local I = NS.Insights
local NOW = 1770000000
local DAY = 86400

-- ── Palette ────────────────────────────────────────────────────────────────────

test("InsightsWidgets.PaletteColor returns an rgb triple for rank 1", function()
  local c = W.PaletteColor(1)
  assertEqual(#c, 3)
  for _, v in ipairs(c) do
    assertTrue(v >= 0 and v <= 1, "each channel is a 0..1 fraction")
  end
end)

test("InsightsWidgets.PaletteColor gives adjacent ranks different colours", function()
  -- The whole point of the rank-ordered palette: two neighbouring bars must never look alike.
  for rank = 1, W.PALETTE_SIZE - 1 do
    local a, b = W.PaletteColor(rank), W.PaletteColor(rank + 1)
    assertFalse(a[1] == b[1] and a[2] == b[2] and a[3] == b[3],
      "ranks " .. rank .. " and " .. (rank + 1) .. " must differ")
  end
end)

test("InsightsWidgets.PaletteColor cycles past the end of the palette", function()
  local first = W.PaletteColor(1)
  local wrapped = W.PaletteColor(W.PALETTE_SIZE + 1)
  assertEqual(wrapped[1], first[1])
  assertEqual(wrapped[3], first[3])
end)

test("InsightsWidgets.PaletteMap assigns colours by list position", function()
  local m = W.PaletteMap({ "Tradegoods", "Consumable", "Weapon" })
  assertEqual(m.Tradegoods[1], W.PaletteColor(1)[1])
  assertEqual(m.Weapon[1], W.PaletteColor(3)[1])
  assertEqual(m.Nothing, nil)
end)

test("InsightsWidgets.PaletteMap of an empty list is empty", function()
  assertEqual(next(W.PaletteMap({})), nil)
  assertEqual(next(W.PaletteMap(nil)), nil)
end)

-- ── Labels ─────────────────────────────────────────────────────────────────────

test("InsightsWidgets.Truncate leaves a short label alone", function()
  local text, cut = W.Truncate("Cloth", 17)
  assertEqual(text, "Cloth")
  assertFalse(cut)
end)

test("InsightsWidgets.Truncate cuts a long label to an ellipsis at the limit", function()
  local text, cut = W.Truncate("Explosive Sheep Wrangling Kit", 10)
  assertTrue(cut, "it must report that it cut")
  assertEqual(text, "Explosive" .. "\226\128\166")
  -- 9 kept glyphs + the 3-byte ellipsis.
  assertEqual(#text, 9 + 3)
end)

test("InsightsWidgets.Truncate handles nil as an empty label", function()
  assertEqual((W.Truncate(nil, 5)), "")
end)

test("InsightsWidgets.ShortChar drops the realm from a Name-Realm key", function()
  assertEqual(W.ShortChar("Mageling-Ravencrest"), "Mageling")
  assertEqual(W.ShortChar("Mageling"), "Mageling")
  assertEqual(W.ShortChar(nil), "?")
end)

test("InsightsWidgets.FitFontSize keeps the base size when the string fits", function()
  assertEqual(W.FitFontSize(80, 120, 20, 11), 20)
  assertEqual(W.FitFontSize(120, 120, 20, 11), 20)
end)

test("InsightsWidgets.FitFontSize shrinks proportionally when it overflows", function()
  assertEqual(W.FitFontSize(240, 120, 20, 5), 10)
end)

test("InsightsWidgets.FitFontSize never shrinks below the floor", function()
  assertEqual(W.FitFontSize(10000, 100, 20, 11), 11)
end)

test("InsightsWidgets.FitFontSize treats a missing measurement as fitting", function()
  assertEqual(W.FitFontSize(nil, 120, 20, 11), 20)
  assertEqual(W.FitFontSize(0, 120, 20, 11), 20)
end)

-- ── Signed formatting ──────────────────────────────────────────────────────────

test("InsightsWidgets.SignedMoney colours a gain green and a loss red", function()
  assertTrue(W.SignedMoney(100):find("40ff40", 1, true) ~= nil, "green for a gain")
  assertTrue(W.SignedMoney(100):find("+", 1, true) ~= nil, "and carries the sign")
  assertTrue(W.SignedMoney(-100):find("ff4040", 1, true) ~= nil, "red for a loss")
end)

test("InsightsWidgets.SignedMoney renders zero as a neutral dash", function()
  assertTrue(W.SignedMoney(0):find("808080", 1, true) ~= nil)
  assertTrue(W.SignedMoney(nil):find("808080", 1, true) ~= nil)
end)

test("InsightsWidgets.SignedCount signs a count the same way", function()
  assertTrue(W.SignedCount(7):find("+7", 1, true) ~= nil)
  assertTrue(W.SignedCount(-7):find("-7", 1, true) ~= nil)
  assertTrue(W.SignedCount(0):find("808080", 1, true) ~= nil)
end)

test("InsightsWidgets.Money renders nothing as a plain zero, not an empty cell", function()
  assertEqual(W.Money(0), "0")
  assertEqual(W.Money(nil), "0")
  assertEqual(W.Money(10000), "1g")
end)

-- ── Diverging + ratio geometry ─────────────────────────────────────────────────

test("InsightsWidgets.DivergingFill sends a gain right and a loss left", function()
  local side, frac = W.DivergingFill(50, 100)
  assertEqual(side, "right")
  assertEqual(frac, 0.5)
  side, frac = W.DivergingFill(-100, 100)
  assertEqual(side, "left")
  assertEqual(frac, 1)
end)

test("InsightsWidgets.DivergingFill draws nothing for zero or no scale", function()
  local side, frac = W.DivergingFill(0, 100)
  assertEqual(side, "none")
  assertEqual(frac, 0)
  side, frac = W.DivergingFill(50, 0)
  assertEqual(side, "none")
  assertEqual(frac, 0)
end)

test("InsightsWidgets.DivergingFill shares one scale across both directions", function()
  -- +100 must be visibly twice -50, which only holds if both divide by the same absolute peak.
  local _, big = W.DivergingFill(100, 100)
  local _, small = W.DivergingFill(-50, 100)
  assertEqual(big / small, 2)
end)

test("InsightsWidgets.DivergingFill clamps a magnitude past the scale", function()
  local _, frac = W.DivergingFill(500, 100)
  assertEqual(frac, 1)
end)

test("InsightsWidgets.RatioShares splits proportionally and sums to one", function()
  local a, b = W.RatioShares(75, 25)
  assertEqual(a, 0.75)
  assertEqual(b, 0.25)
  assertEqual(a + b, 1)
end)

test("InsightsWidgets.RatioShares reads an empty split as balanced", function()
  local a, b = W.RatioShares(0, 0)
  assertEqual(a, 0.5)
  assertEqual(b, 0.5)
end)

test("InsightsWidgets.RatioShares treats a negative side as zero", function()
  local a, b = W.RatioShares(-5, 10)
  assertEqual(a, 0)
  assertEqual(b, 1)
end)

test("InsightsWidgets.Percent rounds to a whole percentage", function()
  assertEqual(W.Percent(1, 3), 33)
  assertEqual(W.Percent(2, 3), 67)
  assertEqual(W.Percent(3, 3), 100)
end)

test("InsightsWidgets.Percent is zero for an empty total, never a divide by zero", function()
  assertEqual(W.Percent(5, 0), 0)
  assertEqual(W.Percent(5, nil), 0)
end)

-- ── Strip metrics ──────────────────────────────────────────────────────────────

test("InsightsWidgets.StripMetrics widens the bars when there are few buckets", function()
  local slot, barW = W.StripMetrics(4, 400)
  assertEqual(slot, 100)
  assertEqual(barW, 14, "capped at the maximum bar width")
end)

test("InsightsWidgets.StripMetrics keeps a minimum bar width when buckets are dense", function()
  local _, barW = W.StripMetrics(400, 400)
  assertEqual(barW, 2)
end)

test("InsightsWidgets.StripMetrics thins the axis labels as the bars tighten", function()
  local _, _, wide = W.StripMetrics(4, 400)
  assertEqual(wide, 1, "a wide strip labels every bucket")
  local _, _, dense = W.StripMetrics(100, 400)
  assertTrue(dense > 1, "a dense strip must skip labels to keep them legible")
end)

test("InsightsWidgets.StripMetrics survives zero buckets", function()
  local slot, barW, stride = W.StripMetrics(0, 400)
  assertTrue(slot > 0 and barW > 0 and stride >= 1)
end)

-- ── Day keys ───────────────────────────────────────────────────────────────────

test("InsightsWidgets.DayKeys covers every day inclusive of both ends", function()
  local keys = W.DayKeys(NOW - 2 * DAY, NOW)
  assertEqual(#keys, 3)
  assertEqual(keys[3], os.date("%Y-%m-%d", NOW))
end)

test("InsightsWidgets.DayKeys includes the quiet days in between", function()
  -- A strip that plots only active days compresses a fortnight of silence into no space and lies
  -- about the shape of the history, so the gaps must be present as zero-height buckets.
  local keys = W.DayKeys(NOW - 9 * DAY, NOW)
  assertEqual(#keys, 10)
end)

test("InsightsWidgets.DayKeys caps a long span to the most recent bars", function()
  local keys = W.DayKeys(NOW - 200 * DAY, NOW, 30)
  assertEqual(#keys, 30)
  assertEqual(keys[30], os.date("%Y-%m-%d", NOW), "the cap keeps the NEWEST days")
end)

test("InsightsWidgets.DayKeys is empty without both ends, or when they are inverted", function()
  assertEqual(#W.DayKeys(nil, NOW), 0)
  assertEqual(#W.DayKeys(NOW, nil), 0)
  assertEqual(#W.DayKeys(NOW, NOW - DAY), 0)
end)

test("InsightsWidgets.ShortDay compacts an ISO day key for the axis", function()
  assertEqual(W.ShortDay("2026-07-04"), "7/4")
  assertEqual(W.ShortDay("nonsense"), "nonsense")
end)

-- ── Sorting + normalizing ──────────────────────────────────────────────────────

test("InsightsWidgets.SortedByCount ranks count-desc then key-asc", function()
  local rows = W.SortedByCount({ zebra = 2, apple = 2, mango = 5 })
  assertEqual(rows[1].key, "mango")
  assertEqual(rows[2].key, "apple")
  assertEqual(rows[3].key, "zebra")
end)

test("InsightsWidgets.NormalizeFractions makes the largest bar fill its track", function()
  local rows = W.NormalizeFractions({ { frac = 5 }, { frac = 10 }, { frac = 0 } })
  assertEqual(rows[2].frac, 1)
  assertEqual(rows[1].frac, 0.5)
  assertEqual(rows[3].frac, 0)
end)

test("InsightsWidgets.NormalizeFractions leaves an all-zero list alone", function()
  local rows = W.NormalizeFractions({ { frac = 0 }, { frac = 0 } })
  assertEqual(rows[1].frac, 0, "no division by zero")
end)

-- ── Stacked bars ───────────────────────────────────────────────────────────────

test("InsightsWidgets.StackSegments orders segments by their global rank", function()
  local segs = W.StackSegments({ B = 1, A = 5 }, { "A", "B" })
  assertEqual(segs[1].key, "A")
  assertEqual(segs[2].key, "B")
  -- Reversing the global order reverses the segments, whatever the magnitudes are.
  segs = W.StackSegments({ B = 1, A = 5 }, { "B", "A" })
  assertEqual(segs[1].key, "B")
end)

test("InsightsWidgets.StackSegments returns the row's total", function()
  local _, total = W.StackSegments({ A = 5, B = 1 }, { "A", "B" })
  assertEqual(total, 6)
end)

test("InsightsWidgets.StackSegments lumps the overflow into one Other segment, last", function()
  local mags, order = {}, {}
  for i = 1, 12 do
    mags["k" .. i] = 13 - i
    order[i] = "k" .. i
  end
  local segs = W.StackSegments(mags, order, 4)
  assertEqual(#segs, 4, "three kept plus one Other")
  assertEqual(segs[4].key, "__OTHER__")
  -- The Other segment carries everything the cut dropped.
  local kept = segs[1].mag + segs[2].mag + segs[3].mag
  local all = 0
  for _, v in pairs(mags) do all = all + v end
  assertEqual(segs[4].mag, all - kept)
end)

test("InsightsWidgets.StackSegments drops zero and negative magnitudes", function()
  local segs = W.StackSegments({ A = 0, B = 3, C = -1 }, { "A", "B", "C" })
  assertEqual(#segs, 1)
  assertEqual(segs[1].key, "B")
end)

test("InsightsWidgets.BuildStackRows scales every row against the biggest row", function()
  local rows = W.BuildStackRows({ Alt = { BANK = 5 }, Main = { BANK = 10 } }, { "BANK" })
  assertEqual(rows[1].label, "Main", "the biggest row sorts first")
  assertEqual(rows[1].segments[1].frac, 1)
  assertEqual(rows[2].segments[1].frac, 0.5)
end)

test("InsightsWidgets.BuildStackRows breaks total ties on the label", function()
  local rows = W.BuildStackRows({ Zed = { BANK = 3 }, Abe = { BANK = 3 } }, { "BANK" })
  assertEqual(rows[1].label, "Abe")
end)

test("InsightsWidgets.BuildStackRows tips each segment with its category and value", function()
  local rows = W.BuildStackRows({ Main = { BANK = 4 } }, { "BANK" },
    { catLabelOf = function() return "Character Bank" end })
  assertEqual(rows[1].segments[1].tip, "Character Bank: 4")
end)

test("InsightsWidgets.BuildStackRows of an empty matrix is empty", function()
  assertEqual(#W.BuildStackRows({}, { "BANK" }), 0)
  assertEqual(#W.BuildStackRows(nil, { "BANK" }), 0)
end)

-- ── Pools ──────────────────────────────────────────────────────────────────────

test("InsightsWidgets pools reuse a released widget instead of building another", function()
  local pool = W.NewPool()
  local built = 0
  local factory = function()
    built = built + 1
    return { Show = function() end, Hide = function() end }
  end
  W.Acquire(pool, factory)
  W.Acquire(pool, factory)
  assertEqual(built, 2)
  W.ReleaseAll(pool)
  assertEqual(#pool.active, 0)
  assertEqual(#pool.free, 2)
  W.Acquire(pool, factory)
  W.Acquire(pool, factory)
  assertEqual(built, 2, "a second pass must allocate nothing")
  W.ReleaseAll(pool)
end)

-- ── Card values ────────────────────────────────────────────────────────────────

test("Insights.CardValues renders every declared card", function()
  local v = I.CardValues({ entries = 12, itemsDeposited = 30, itemsWithdrawn = 8, netItems = 22,
    distinctItems = 5, distinctChars = 2, activeDays = 3,
    moneyIn = 20000, moneyOut = 5000, netMoney = 15000, moneyMoved = 25000,
    firstTs = NOW - DAY, lastTs = NOW, busiestDay = { day = "2026-02-01", count = 9 },
    topStore = { store = "GUILD_BANK", count = 7 } })
  assertEqual(v.movements, "12")
  assertEqual(v.itemsIn, "30")
  assertEqual(v.itemsOut, "8")
  assertEqual(v.distinctItems, "5")
  assertEqual(v.chars, "2")
  assertEqual(v.activeDays, "3")
  assertEqual(v.topStore, "Guild Bank")
  assertEqual(v.itemsMoved, "38")
  assertEqual(v.goldIn, "2g")
  assertEqual(v.goldOut, "50s")
  assertTrue(v.netItems:find("+22", 1, true) ~= nil, "net items is signed")
  assertTrue(v.netGold:find("40ff40", 1, true) ~= nil, "net gold is signed and coloured")
  assertTrue(v.busiest:find("2026-02-01", 1, true) ~= nil)
  assertTrue(v.busiest:find("(9)", 1, true) ~= nil, "the busiest day carries its count")
  assertTrue(v.span:find("\226\128\147", 1, true) ~= nil, "the range uses an en-dash")
end)

test("Insights.CardValues shows a dash where there is genuinely nothing", function()
  local v = I.CardValues({})
  assertEqual(v.movements, "0", "a count of nothing is zero, not a dash")
  assertEqual(v.span, "\226\128\148", "no date range at all is a dash")
  assertEqual(v.busiest, "\226\128\148")
end)

test("Insights.CardValues survives being handed nothing at all", function()
  local v = I.CardValues(nil)
  assertEqual(v.movements, "0")
end)

test("Insights.CardValues covers every card the panel declares", function()
  -- A card with no value would silently render a dash forever, so the two lists must agree.
  local values = I.CardValues({ entries = 1 })
  for _, key in ipairs({ "movements", "itemsIn", "itemsOut", "netItems", "distinctItems", "chars",
                         "activeDays", "topStore", "itemsMoved", "goldIn", "goldOut", "netGold",
                         "span", "busiest" }) do
    assertTrue(values[key] ~= nil, "card '" .. key .. "' has no value")
  end
end)

test("Insights.CardValues no longer produces value or biggest-move cards", function()
  local v = I.CardValues({ entries = 3, itemsDeposited = 10, itemsWithdrawn = 4 })
  assertEqual(v.value, nil)
  assertEqual(v.biggest, nil)
end)

test("Insights.CardValues reports items moved and the top store", function()
  local v = I.CardValues({
    entries = 3, itemsDeposited = 10, itemsWithdrawn = 4,
    topStore = { store = "GUILD_BANK", count = 7 },
  })
  assertEqual(v.itemsMoved, "14")
  assertEqual(v.topStore, "Guild Bank")
end)

test("Insights.CardValues em-dashes the top store on an empty slice", function()
  assertEqual(I.CardValues({}).topStore, "\226\128\148")
end)

test("Insights.SummaryLine names the scope and the count", function()
  assertEqual(I.SummaryLine("filtered", 12), "computed scope=filtered, 12 movements")
end)

-- ── Render smoke test ──────────────────────────────────────────────────────────
-- Insights deliberately computes against the Browser's SHARED filter, which means these cases have
-- to state the filter they expect rather than inherit whatever the last suite left behind — opening
-- the ledger window scopes it to the current character, which would silently empty every fixture.
local function unfiltered()
  NS.Browser.activeFilter = {}
end
-- Attach the real panel to a stub pane and drive a full layout pass. The maths above is unit-tested
-- in isolation; this proves the ~16 sections actually bind against a Stats result without raising,
-- which is the failure mode that would otherwise only show up in-game.

test("Insights:Attach and Refresh survive an empty ledger", function()
  unfiltered()
  NS.db.global.ledger = {}
  I:Attach(T.mocks.CreateFrame())
  assertTrue(I.content ~= nil, "the panel built")
  I:Refresh()
  assertEqual((I.stats.totals or {}).entries, 0)
end)

test("Insights:Refresh lays out every section against a populated ledger", function()
  unfiltered()
  local stores = { "BANK", "WARBAND_BANK", "GUILD_BANK" }
  local chars = { { "Mageling-Realm", "MAGE" }, { "Sneakerz-Realm", "ROGUE" } }
  local ledger = {}
  for i = 1, 24 do
    local who = chars[(i % #chars) + 1]
    ledger[#ledger + 1] = {
      ts = NOW - (i % 6) * DAY, char = who[1], classFile = who[2],
      kind = "ITEM", direction = (i % 3 == 0) and "WITHDRAW" or "DEPOSIT",
      store = stores[(i % #stores) + 1],
      itemID = 2589 + (i % 4), itemName = "Item " .. (i % 4), quality = i % 5,
      itemType = "Tradegoods", itemSubType = "Cloth", quantity = i,
      zone = (i % 2 == 0) and "Valdrakken" or "Dornogal",
    }
  end
  -- Two coin movements, so the GOLD section is exercised too.
  ledger[#ledger + 1] = { ts = NOW, char = "Mageling-Realm", classFile = "MAGE",
    kind = "MONEY", direction = "DEPOSIT", store = "WARBAND_BANK",
    itemName = "Gold", quantity = 500000, zone = "Valdrakken" }
  ledger[#ledger + 1] = { ts = NOW - DAY, char = "Sneakerz-Realm", classFile = "ROGUE",
    kind = "MONEY", direction = "WITHDRAW", store = "GUILD_BANK",
    itemName = "Gold", quantity = 120000, zone = "Valdrakken" }
  NS.db.global.ledger = ledger

  I:Refresh()
  assertEqual(I.stats.totals.entries, 26)
  assertTrue(I.stats.totals.moneyMoved > 0, "the GOLD section had data to render")
  NS.db.global.ledger = {}
end)

test("Insights:Refresh renders a slice with no gold at all", function()
  unfiltered()
  -- The GOLD divider and its two charts must hide rather than render empty: two blank charts under a
  -- banner read as a broken addon, not as "you moved no gold".
  NS.db.global.ledger = {
    { ts = NOW, char = "Mageling-Realm", classFile = "MAGE", kind = "ITEM", direction = "DEPOSIT",
      store = "BANK", itemID = 2589, itemName = "Linen Cloth", quality = 1,
      itemType = "Tradegoods", itemSubType = "Cloth", quantity = 5,
      zone = "Valdrakken" },
  }
  I:Refresh()
  assertEqual(I.stats.totals.moneyMoved, 0)
  assertEqual(I.stats.totals.entries, 1)
  NS.db.global.ledger = {}
end)

test("Insights: the four direction-split companions render without raising", function()
  unfiltered()
  NS.db.global.ledger = {
    { ts = NOW, char = "Mageling-Realm", classFile = "MAGE", kind = "ITEM", direction = "DEPOSIT",
      store = "BANK", itemID = 2589, itemName = "Linen Cloth", quality = 1,
      itemType = "Tradegoods", itemSubType = "Cloth", quantity = 5, zone = "Valdrakken" },
    { ts = NOW - DAY, char = "Mageling-Realm", classFile = "MAGE", kind = "ITEM",
      direction = "WITHDRAW", store = "GUILD_BANK", itemID = 4306, itemName = "Silk Cloth",
      quality = 2, itemType = "Tradegoods", itemSubType = "Cloth", quantity = 2,
      zone = "Valdrakken" },
  }
  I:Refresh()
  assertTrue(next(I.stats.qualityByDirection) ~= nil, "the quality split had data")
  assertTrue(next(I.stats.storeByDirection) ~= nil, "the store split had data")
  NS.db.global.ledger = {}
end)

-- ── Icon markup must survive truncation ────────────────────────────────────────
-- Regression: the class icon was concatenated into the label BEFORE W.Truncate cut it at 17
-- bytes, so the cut landed inside the |T...|t escape and WoW rendered the raw texture path.

test("Insights.BarLabel truncates the name and leaves the icon escape intact", function()
  local icon = "|TInterface\\TargetingFrame\\UI-Classes-Circles:12:12:0:0:256:256:0:64:0:64|t "
  local out = I.BarLabel({ icon = icon, label = "Verylongcharactername", labelMax = 14 })
  assertTrue(out:sub(1, #icon) == icon, "the icon escape is emitted whole and unmodified")
  assertTrue(out:find("|t", 1, true) ~= nil, "the escape is still closed")
  -- The budget applies to the NAME only: the rendered label is the icon verbatim followed by
  -- exactly what W.Truncate makes of the name. Asserting that relationship rather than a byte
  -- count keeps the test honest if the ellipsis ever changes.
  assertEqual(out, icon .. (W.Truncate("Verylongcharactername", 14)),
    "only the name passes through the budget")
end)

test("Insights.BarLabel is a plain truncation when there is no icon", function()
  assertEqual(I.BarLabel({ label = "Bank" }), "Bank")
end)

test("Insights: character bars carry the icon out of band", function()
  local rows = {}
  for _, ce in pairs({ ["Verylongcharactername-Ravencrest"] = {
    char = "Verylongcharactername-Ravencrest", classFile = "MAGE", count = 3 } }) do
    rows[#rows + 1] = ce
  end
  -- The row the layout builds must keep icon and label separate.
  local row = { icon = NS.Util.ClassIconMarkup(rows[1].classFile),
                label = W.ShortChar(rows[1].char), fullLabel = rows[1].char, labelMax = 14 }
  local out = I.BarLabel(row)
  assertEqual(row.label:find("|T", 1, true), nil, "the label field holds no markup")
  assertTrue(#out >= #row.icon, "the rendered label leads with the icon")
end)

test("InsightsWidgets exports the ratio bar's two-part height", function()
  assertEqual(W.RATIO_H, 22)
  assertEqual(W.RATIO_CAPTION_H, 14)
end)

test("InsightsWidgets pools list panels, each carrying its own row pool", function()
  local parent = T.mocks.CreateFrame()
  local pool = W.NewPool()
  local a = W.Acquire(pool, function() return W.MakeListPanel(parent) end)
  W.SetPanelTitle(a, "Top Items")
  assertTrue(a._rows ~= nil, "a pooled panel owns its row pool")
  W.ReleasePanels(pool)
  assertEqual(#pool.active, 0, "releasing empties the active list")
  local b = W.Acquire(pool, function() return W.MakeListPanel(parent) end)
  assertTrue(a == b, "the released panel is reused, never re-allocated")
end)

test("InsightsWidgets.MakeCard builds every headline on one base font template", function()
  local a = W.MakeCard(T.mocks.CreateFrame())
  local b = W.MakeCard(T.mocks.CreateFrame())
  -- The headline is the FIRST font string a card creates; the caption follows it. Asserting the
  -- template is what catches a reintroduced second, smaller template for the wide cards.
  assertEqual(a.__fontTemplates[1], "GameFontNormalHuge")
  assertEqual(b.__fontTemplates[1], "GameFontNormalHuge")
  assertEqual(a.__fontTemplates[2], "GameFontDisableSmall", "the caption keeps its own template")
end)

test("Insights: the reorganized list section renders every group", function()
  unfiltered()
  local stores = { "BANK", "WARBAND_BANK", "GUILD_BANK" }
  local ledger = {}
  for i = 1, 18 do
    ledger[#ledger + 1] = {
      ts = NOW - (i % 5) * DAY, char = "Mageling-Realm", classFile = "MAGE",
      kind = "ITEM", direction = (i % 3 == 0) and "WITHDRAW" or "DEPOSIT",
      store = stores[(i % #stores) + 1],
      itemID = 2589 + (i % 4), itemName = "Item " .. (i % 4), quality = i % 5,
      itemType = "Tradegoods", itemSubType = "Cloth", quantity = i,
      zone = (i % 2 == 0) and "Valdrakken" or "Dornogal",
    }
  end
  NS.db.global.ledger = ledger
  I:Refresh()
  assertTrue(#I.stats.topItemsIn > 0, "the deposits ranking has rows")
  assertTrue(#I.stats.topItemsOut > 0, "the withdrawals ranking has rows")
  assertTrue(#I.stats.topTypeSub > 0, "the type/sub-type ranking has rows")
  assertTrue(#I.panelPool.active > 0, "panels were acquired from the pool")
  -- A second pass must reuse, never re-allocate.
  local first = #I.panelPool.active + #I.panelPool.free
  I:Refresh()
  assertEqual(#I.panelPool.active + #I.panelPool.free, first, "panels are pooled, not leaked")
  NS.db.global.ledger = {}
end)
