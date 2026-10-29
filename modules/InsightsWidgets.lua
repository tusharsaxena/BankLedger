local _, NS = ...
NS.InsightsWidgets = NS.InsightsWidgets or {}
local W = NS.InsightsWidgets

-- The Insights tab's visual vocabulary: KPI cards, horizontal bars, stacked bars, diverging bars,
-- split bars, per-bucket vertical strips, ranked list panels, legends and section dividers — plus
-- the color and label helpers they share.
--
-- Peeled out of modules/Insights.lua so that file stays about WHAT is shown (which breakdown, from
-- which Stats key) and this one about HOW. Nothing here knows what a ledger entry is: every
-- primitive takes plain numbers, strings and {r,g,b} triples, which is also what makes the math
-- below unit-testable without a client.
--
-- Everything is POOLED. The Blizzard UI runs a super-linear pass over a frame tree on some
-- transitions, so re-allocating widgets on every refresh is what turns a smooth panel into a visible
-- hitch. Widgets are created once, released on each layout, and re-acquired in place.

-- ── The skin's colors ─────────────────────────────────────────────────────────
-- Every color the Insights tab draws is a token of the player's skin (core/SkinSetup.lua's
-- NS.Skin, over LibKa0s-Skin-1.0; anti-pattern #107: no typed look value). The named triples below
-- are REUSED tables, resolved from the tokens at load and again, in place, on every skin switch
-- (W.ReskinColors, from modules/Insights.lua's OnLooksChanged listener), so a caller that holds one
-- (a row's color, the segment default) keeps a live color and its identity. Ka0s Default's tokens
-- are the values these drew before the skin engine.
W.GOLD     = {}   -- text.heading: section headings, panel titles, the card headline
W.NEUTRAL  = {}   -- chart.other: the "everything else" bucket and the default bar color
W.MUTED    = {}   -- text.value: bar values, list text, legend labels and the legend's hover line
W.POSITIVE = {}   -- sem.good: net in, the same green as a DEPOSIT
W.NEGATIVE = {}   -- sem.bad: net out, the same red as a WITHDRAW
W.TIP_TITLE = {}  -- gtip.title: a tooltip's title line
W.TIP_BODY  = {}  -- gtip.body: a tooltip's wrapped body
W.TIP_VALUE = {}  -- gtip.value: a one-line element tip
local TRACK, AXIS_ALT = {}, {}   -- chart.track (a bar's track), chart.axisAlt (a split's baseline)

W.BAR_H, W.BAR_GAP = 16, 3
W.SPLIT_H, W.SPLIT_CAPTION_H = 22, 14   -- the headline split bar, and the caption row beneath it
W.SECTION_GAP = 16
W.STRIP_H = 46
W.STRIP_LABEL_H = 40        -- room under a strip for its rotated x-axis labels
W.STRIP_AXIS_GAP = 2        -- gap between the bar bases and the axis line
W.STRIP_LABEL_GAP = 7       -- gap between the axis line and the label text
W.LIST_ROW_H = 16
W.LABEL_W, W.VALUE_W = 118, 104   -- fixed label/value columns; the track fills the rest
W.LABEL_MAXCHARS = 17
W.LEGEND_MAXCHARS = 14
W.MAX_STACK_SEGS = 9        -- segment ceiling per stacked bar (matches the texture pool below)
W.MIN_HEADLINE_SIZE = 11    -- floor for the shrink-to-fit KPI headline font
W.MAX_DAY_BARS = 60         -- cap on a per-day strip, so a long history stays readable
W.CARD_H = 52
-- Coin glyphs render ~14px by default and dominate a bar label at that size.
W.COIN_H = 10

-- ── Pure helpers (unit-tested) ─────────────────────────────────────────────────

-- A categorical palette for the breakdowns with no predefined color of their own (item type,
-- sub-type, weekday). Sequence is inverse-VIBGYOR — R→O→Y→G→B→I→V — then the same rainbow in a
-- lighter and a darker band, so adjacent ranks are always rainbow-distinct and two lookalikes never
-- end up side by side. Colors are assigned by a category's RANK in its chart's sort order, so
-- consecutive bars always draw from dissimilar hues.
--
-- The palette is the skin's chart.series (Ka0s Default's is exactly this addon's old palette),
-- copied into reused { r, g, b } entries by W.ReskinColors, so a skin with its own series recolors
-- every categorical chart on a switch.
local PALETTE = {}

local function resolve(t, name)
  local r, g, b = NS.Skin.Color(name)
  t[1], t[2], t[3] = r or 1, g or 1, b or 1
end

--- Resolve every cached color, and the palette, from the live skin. At load and on every switch.
function W.ReskinColors()
  resolve(W.GOLD, "text.heading");   resolve(W.NEUTRAL, "chart.other")
  resolve(W.MUTED, "text.value");    resolve(W.POSITIVE, "sem.good")
  resolve(W.NEGATIVE, "sem.bad");    resolve(W.TIP_TITLE, "gtip.title")
  resolve(W.TIP_BODY, "gtip.body");  resolve(W.TIP_VALUE, "gtip.value")
  resolve(TRACK, "chart.track");     resolve(AXIS_ALT, "chart.axisAlt")
  TRACK[4] = select(4, NS.Skin.Color("chart.track")) or 1
  AXIS_ALT[4] = select(4, NS.Skin.Color("chart.axisAlt")) or 1
  local series = NS.Skin.Token("chart.series")
  if type(series) ~= "table" or #series == 0 then series = { { 1, 1, 1 } } end
  for i, c in ipairs(series) do
    local t = PALETTE[i] or {}
    t[1], t[2], t[3] = c[1], c[2], c[3]
    PALETTE[i] = t
  end
  for i = #PALETTE, #series + 1, -1 do PALETTE[i] = nil end
  W.PALETTE_SIZE = #PALETTE
end
W.ReskinColors()

-- 1-based rank → palette color (cycles past the end).
function W.PaletteColor(rank)
  rank = tonumber(rank) or 1
  return PALETTE[((math.floor(rank) - 1) % #PALETTE) + 1]
end

-- { key → color } from an ordered key list, so one category keeps ONE color across every chart
-- that shares that order (item type in its own bar list and in the per-character companion).
function W.PaletteMap(orderedKeys)
  local m = {}
  for i, k in ipairs(orderedKeys or {}) do m[k] = W.PaletteColor(i) end
  return m
end

-- Cap a label to a glyph count with a trailing ellipsis. English-only labels, so a byte-based sub is
-- safe. Returns the text and whether it was cut (the caller keeps the full string for the tooltip).
-- Never pass a string with markup (e.g. a |T...|t texture escape) concatenated in: the cut is
-- byte-based and can land inside the escape. Keep markup out of band and prepend it after
-- truncating.
function W.Truncate(text, maxChars)
  text = tostring(text or "")
  maxChars = maxChars or W.LABEL_MAXCHARS
  if #text <= maxChars then return text, false end
  return text:sub(1, maxChars - 1) .. "\226\128\166", true
end

-- Shrink a headline only when its rendered string would overflow its card, so ordinary numbers keep
-- the full size and a long coin string still fits on one line.
function W.FitFontSize(stringWidth, maxWidth, baseSize, minSize)
  if not stringWidth or stringWidth <= 0 or stringWidth <= maxWidth then return baseSize end
  return math.max(minSize or W.MIN_HEADLINE_SIZE, baseSize * maxWidth / stringWidth)
end

-- Item-quality color as {r,g,b}: the skin's q.* where it sets one, else the client's color
-- (NS.QualityColor; game meaning, never re-hued), with the owner token bl.qualityUnknown for an
-- unknown id or a headless build (the rollout's D9, kept exact by X1).
function W.QualityColor(q)
  local r, g, b = NS.QualityColor(q or 1)
  if r then return { r, g, b } end
  return NS.SkinRGB("bl.qualityUnknown")
end

-- A class color is game meaning, kept under every skin (the rollout's E3); its fallback is the
-- skin's text.muted.
function W.ClassColor(classFile)
  local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if c then return { c.r, c.g, c.b } end
  return NS.SkinRGB("text.muted")
end

-- "Name-Realm" → "Name". A per-character bar is 118px wide; the realm is the same for almost every
-- row and is what gets cut, so drop it up front and keep the part that distinguishes the rows.
function W.ShortChar(key)
  return (type(key) == "string" and key:match("^[^-]+")) or tostring(key or "?")
end

-- Copper → display string (coin glyphs in-game, "Ng Ns Nc" headless, "0" for nothing).
function W.Money(copper)
  copper = copper or 0
  if copper <= 0 then return "0" end
  return NS.Util.FormatMoney(copper, W.COIN_H)
end

-- A SIGNED copper amount, colored: green for a net gain, red for a net loss, a gray em-dash for
-- exactly nothing (which is a real answer, not a missing one). The escapes are the skin's
-- sem.goodAlt, sem.badAlt and text.disabled (NS.SkinEscape), each rounding to the bytes these wrote
-- before the skin engine under Ka0s Default (40ff40, ff4040, 808080); read per call, so a switch
-- reaches the next refresh.
local function esc(name) return NS.SkinEscape(name) or "" end

function W.SignedMoney(copper)
  copper = copper or 0
  if copper == 0 then return esc("text.disabled") .. "\226\128\148|r" end
  local body = W.Money(math.abs(copper))
  if copper > 0 then return esc("sem.goodAlt") .. "+" .. body .. "|r" end
  return esc("sem.badAlt") .. "-" .. body .. "|r"
end

-- A signed COUNT, colored the same way.
function W.SignedCount(n)
  n = n or 0
  if n == 0 then return esc("text.disabled") .. "\226\128\148|r" end
  if n > 0 then return esc("sem.goodAlt") .. "+" .. n .. "|r" end
  return esc("sem.badAlt") .. n .. "|r"
end

-- Two magnitudes as fractions of the LARGER of the two, so the bigger side is always 1.0 and the
-- smaller reads as its proportion of it. This is the scale a center-axis split bar wants: the same
-- shared-peak rule W.BuildBackToBackRows applies down a column of rows, applied to a single pair.
-- Both sides zero gives 0/0 — two zero-width halves, not a division by zero.
function W.PeakShares(a, b)
  a, b = math.max(0, a or 0), math.max(0, b or 0)
  local peak = math.max(a, b)
  if peak <= 0 then return 0, 0 end
  return a / peak, b / peak
end

-- A whole-number percentage of a total (0 when the total is 0, never a division by zero).
function W.Percent(part, total)
  if not total or total <= 0 then return 0 end
  return math.floor((part or 0) / total * 100 + 0.5)
end

-- Every calendar day from firstTs to lastTs INCLUSIVE, gaps included, capped to the most recent
-- MAX_DAY_BARS. Gaps matter: a strip that only plots active days silently compresses a fortnight of
-- inactivity into no space at all and lies about the shape of the history.
function W.DayKeys(firstTs, lastTs, maxBars)
  local keys = {}
  if not (firstTs and lastTs) or lastTs < firstTs then return keys end
  local function dayStart(ts)
    local d = date("*t", ts)
    return ts - (d.hour * 3600 + d.min * 60 + d.sec)
  end
  for ts = dayStart(firstTs), dayStart(lastTs), 86400 do
    keys[#keys + 1] = date("%Y-%m-%d", ts)
  end
  maxBars = maxBars or W.MAX_DAY_BARS
  if #keys > maxBars then
    local trimmed = {}
    for i = #keys - maxBars + 1, #keys do trimmed[#trimmed + 1] = keys[i] end
    keys = trimmed
  end
  return keys
end

-- "YYYY-MM-DD" → compact "M/D" for a strip's x-axis label.
function W.ShortDay(key)
  local m, d = tostring(key or ""):match("^%d+%-(%d+)%-(%d+)$")
  if m then return tonumber(m) .. "/" .. tonumber(d) end
  return tostring(key or "")
end

W.WEEKDAY_LABEL = { [0] = "Sun", [1] = "Mon", [2] = "Tue", [3] = "Wed",
                    [4] = "Thu", [5] = "Fri", [6] = "Sat" }

-- A key→count map as a { key, count } array, count-desc then key-asc so ties are deterministic.
function W.SortedByCount(map)
  local rows = {}
  for k, c in pairs(map or {}) do rows[#rows + 1] = { key = k, count = c } end
  table.sort(rows, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return tostring(a.key) < tostring(b.key)
  end)
  return rows
end

-- Normalize a row list's `frac` fields so the largest bar exactly fills its track and the rest
-- scale against it. A list whose largest value is 0 is left alone rather than divided by zero.
function W.NormalizeFractions(rows)
  local maxFrac = 0
  for _, row in ipairs(rows or {}) do
    if (row.frac or 0) > maxFrac then maxFrac = row.frac end
  end
  if maxFrac > 0 then
    for _, row in ipairs(rows) do row.frac = (row.frac or 0) / maxFrac end
  end
  return rows
end

-- Reduce one character's per-category magnitudes to at most `maxSegs` stacked segments: keep the top
-- (maxSegs-1) by magnitude, lump the rest into a single "__OTHER__", then order the kept segments by
-- their GLOBAL rank in catOrder so a category holds the same position in every row.
-- Returns the segment list and the row's untruncated total.
function W.StackSegments(catMags, catOrder, maxSegs)
  maxSegs = maxSegs or W.MAX_STACK_SEGS
  local list, total = {}, 0
  for k, v in pairs(catMags or {}) do
    if v and v > 0 then list[#list + 1] = { key = k, mag = v }; total = total + v end
  end
  table.sort(list, function(a, b)
    if a.mag ~= b.mag then return a.mag > b.mag end
    return tostring(a.key) < tostring(b.key)
  end)
  local kept, otherMag = {}, 0
  if #list > maxSegs then
    for i = 1, maxSegs - 1 do kept[#kept + 1] = list[i] end
    for i = maxSegs, #list do otherMag = otherMag + list[i].mag end
  else
    for i = 1, #list do kept[#kept + 1] = list[i] end
  end
  local rank = {}
  for i, k in ipairs(catOrder or {}) do rank[k] = i end
  table.sort(kept, function(a, b)
    return (rank[a.key] or math.huge) < (rank[b.key] or math.huge)
  end)
  if otherMag > 0 then kept[#kept + 1] = { key = "__OTHER__", mag = otherMag } end
  return kept, total
end

-- The default segment color, shaped as a function so it slots straight into `opts.colorOf or ...`.
-- Module-level for readability, not for speed: the inline `function() return W.NEUTRAL end` it
-- replaces sat on the `or` fallback, so it was only ever allocated when a caller omitted `colorOf` —
-- and the one production call site (modules/Insights.lua, sectionCharStore) always passes `colorOf`.
-- In the shipping addon that closure was minted zero times. Do not claim a per-call saving here.
-- `labelColorOf` deliberately has no default: a nil labelColor means "use the widget default", not white.
local function neutralColor() return W.NEUTRAL end

-- First pass over the matrix: each row's untruncated total, and the scale every row shares.
-- `rowMax` starts at 1, not 0 — that is the divide-by-zero guard, and the reason an all-empty
-- matrix yields zero-width segments rather than NaN ones.
local function stackTotals(matrix, catOrder)
  local rowMax, totals = 1, {}
  for key, mags in pairs(matrix) do
    local _, total = W.StackSegments(mags, catOrder)
    totals[key] = total
    if total > rowMax then rowMax = total end
  end
  return totals, rowMax
end

-- One row's segments. The "__OTHER__" sentinel forces both the neutral color and the literal
-- tooltip name, bypassing the caller's colorOf/catLabelOf.
-- The three formatters arrive as arguments rather than in an options bag: they are read once per
-- segment, and locals are upvalue reads where a bag would be a hash lookup each time.
local function buildSegments(segs, rowMax, colorOf, catLabelOf, valueFmt)
  local segments = {}
  for _, s in ipairs(segs) do
    local isOther = s.key == "__OTHER__"
    segments[#segments + 1] = {
      frac = s.mag / rowMax,
      color = isOther and W.NEUTRAL or (colorOf(s.key) or W.NEUTRAL),
      tip = (isOther and "Other" or catLabelOf(s.key)) .. ": " .. valueFmt(s.mag),
    }
  end
  return segments
end

-- Total-desc then label-asc. The tostring() is what keeps mixed-type keys (numeric quality ids
-- against strings) from raising.
local function byTotalThenLabel(a, b)
  if a.total ~= b.total then return a.total > b.total end
  return tostring(a.label) < tostring(b.label)
end

-- Build stacked-bar rows from a { rowKey → { category → magnitude } } matrix. Row width is the row's
-- share of the biggest row's total, so the rows are comparable to each other; each segment is that
-- category's share of the same scale. Rows sort total-desc then label-asc.
--   labelOf(rowKey)   → the row's display label      colorOf(catKey) → the segment color
--   catLabelOf(catKey)→ the segment's tooltip name   valueFmt(mag)   → the value string
function W.BuildStackRows(matrix, catOrder, opts)
  opts = opts or {}
  local labelOf = opts.labelOf or tostring
  local colorOf = opts.colorOf or neutralColor
  local catLabelOf = opts.catLabelOf or tostring
  local valueFmt = opts.valueFmt or tostring
  local colorOfLabel = opts.labelColorOf
  matrix = matrix or {}

  local totals, rowMax = stackTotals(matrix, catOrder)

  local rows = {}
  for key, mags in pairs(matrix) do
    -- Segments are recomputed rather than cached from the totals pass: StackSegments' __OTHER__
    -- bucketing depends on catOrder, so both passes must ask it the same question.
    local segments = buildSegments(W.StackSegments(mags, catOrder), rowMax, colorOf, catLabelOf, valueFmt)
    rows[#rows + 1] = {
      label = labelOf(key), labelColor = colorOfLabel and colorOfLabel(key) or nil,
      value = valueFmt(totals[key]), segments = segments, total = totals[key],
    }
  end
  table.sort(rows, byTotalThenLabel)
  return rows
end

-- One back-to-back row's magnitudes, label and color; each side clamped at 0.
local function backToBackRow(key, mags, rightKey, leftKey, opts)
  mags = mags or {}
  local rightMag = math.max(0, mags[rightKey] or 0)
  local leftMag = math.max(0, mags[leftKey] or 0)
  return {
    key = key, label = (opts.labelOf or tostring)(key),
    labelColor = opts.labelColorOf and opts.labelColorOf(key) or nil,
    rightMag = rightMag, leftMag = leftMag, total = rightMag + leftMag,
  }
end

-- Back-to-back ("butterfly") rows from a two-category matrix: one category grows LEFT of a fixed
-- center axis, the other grows RIGHT. Returns the rows and the shared scale.
--
-- Both sides share ONE scale — the largest single-category magnitude anywhere in the list — which
-- is what makes the form worth having: the split sits on the same vertical line in every row, so
-- "which way does this lean" reads straight down the center without comparing bar lengths. A
-- left-aligned stacked bar puts that boundary in a different place on every row and answers the
-- question only after arithmetic.
--
-- Domain-agnostic like everything else here: the caller names the two category keys.
--   labelOf(rowKey) → display label   labelColorOf(rowKey) → the label's {r,g,b}
--   valueFmt(total) → the value string
-- Rows sort total-desc then label-asc, so ties are deterministic.
function W.BuildBackToBackRows(matrix, rightKey, leftKey, opts)
  opts = opts or {}
  local valueFmt = opts.valueFmt or tostring

  local rows, scale = {}, 0
  for key, mags in pairs(matrix or {}) do
    local row = backToBackRow(key, mags, rightKey, leftKey, opts)
    scale = math.max(scale, row.rightMag, row.leftMag)
    rows[#rows + 1] = row
  end
  -- A list whose every magnitude is 0 keeps 0-width halves rather than dividing by zero.
  for _, row in ipairs(rows) do
    row.rightFrac = scale > 0 and (row.rightMag / scale) or 0
    row.leftFrac = scale > 0 and (row.leftMag / scale) or 0
    row.value = valueFmt(row.total)
  end
  table.sort(rows, byTotalThenLabel)
  return rows, scale
end

-- ── Pools ──────────────────────────────────────────────────────────────────────

-- The pool lives in LibKa0s-Pool-1.0 now (core/PoolSetup.lua). These three stay as names because
-- every call site in modules/Insights.lua reads W.Acquire / W.ReleaseAll, and renaming forty call
-- sites to prove a point is not a refactor.
W.NewPool    = function() return NS.Pool.New() end
W.Acquire    = function(pool, factory) return NS.Pool.Acquire(pool, factory) end
W.ReleaseAll = function(pool) return NS.Pool.ReleaseAll(pool) end

-- ── Tooltips ───────────────────────────────────────────────────────────────────

-- A one-line tip pinned just above-right of the cursor rather than anchored to a (far-right) row
-- edge, so it reads beside whatever the mouse is actually over. GetCursorPosition returns physical
-- pixels, hence the divide by UIParent's effective scale.
function W.CursorTooltip(owner, text, rgb)
  if not (text and text ~= "" and GameTooltip) then return end
  GameTooltip:SetOwner(owner, "ANCHOR_NONE")
  if GetCursorPosition and UIParent and UIParent.GetEffectiveScale then
    local scale = UIParent:GetEffectiveScale() or 1
    local cx, cy = GetCursorPosition()
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
      (cx or 0) / scale + 5, (cy or 0) / scale + 5)
  end
  GameTooltip:ClearLines()
  rgb = rgb or W.TIP_VALUE
  GameTooltip:AddLine(text, rgb[1], rgb[2], rgb[3])
  GameTooltip:Show()
end

local function hideTooltip() if GameTooltip then GameTooltip:Hide() end end

-- ── KPI card ───────────────────────────────────────────────────────────────────
-- A bordered panel: gold headline over a gray caption. Every card shares one base headline font;
-- a long value (money, a date range) shrinks to fit via SetCard rather than clipping.

--
-- The box and the headline are the skin's Card (card.bg under card.border, the headline in
-- text.heading and the skin's face), which on Ka0s Default is call for call the backdrop these cards
-- always drew; the caption is text.disabled. Both are recorded, so a skin switch repaints them, and
-- W.ReskinCard then re-reads the headline's base font, which the shrink pass resets to.
function W.MakeCard(parent)
  local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")

  -- Every card shares ONE base headline font. A long string (a date range, a coin amount) is
  -- handled by the shrink-to-fit pass in SetCard, not by a second smaller template -- two nominal
  -- sizes made the wide cards read as a different kind of card.
  local value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  value:SetPoint("TOP", 0, -9)
  value:SetPoint("LEFT", 4, 0)
  value:SetPoint("RIGHT", -4, 0)
  value:SetJustifyH("CENTER")
  value:SetWordWrap(false)
  card.value = value
  NS.Skin.Card(card, { title = value })

  local caption = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  caption:SetPoint("BOTTOM", 0, 7)
  caption:SetJustifyH("CENTER")
  NS.Skin.Text(caption, "disabled")
  card.caption = caption

  W.ReskinCard(card)

  card:EnableMouse(true)
  card:SetScript("OnEnter", function(self)
    if not (self._tip and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(self._caption or "", W.TIP_TITLE[1], W.TIP_TITLE[2], W.TIP_TITLE[3])
    GameTooltip:AddLine(self._tip, W.TIP_BODY[1], W.TIP_BODY[2], W.TIP_BODY[3], true)
    GameTooltip:Show()
  end)
  card:SetScript("OnLeave", hideTooltip)
  return card
end

--- Remember the headline's base font (after the skin painted it), so the shrink-to-fit pass can
--- always reset before measuring. At build and after every skin switch, which repaints the face.
function W.ReskinCard(card)
  local file, size, flags = card.value:GetFont()
  if type(size) == "number" then
    card.fontFile, card.baseSize, card.fontFlags = file, size, flags
  end
end

-- Paint and place a card. `width` drives the shrink-to-fit measurement.
function W.SetCard(card, spec, width)
  card._caption, card._tip = spec.caption, spec.tooltip
  card.caption:SetText(spec.caption or "")
  card.value:SetText((spec.value ~= nil and spec.value ~= "") and spec.value or "\226\128\148")
  if card.baseSize then
    card.value:SetFont(card.fontFile, card.baseSize, card.fontFlags)
    local w = card.value:GetStringWidth()
    if type(w) == "number" and type(width) == "number" then
      local size = W.FitFontSize(w, width - 12, card.baseSize, W.MIN_HEADLINE_SIZE)
      if size < card.baseSize then card.value:SetFont(card.fontFile, size, card.fontFlags) end
    end
  end
end

-- ── Horizontal bar ─────────────────────────────────────────────────────────────

function W.MakeBar(parent)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(W.BAR_H)
  local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  NS.Skin.Font(label)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  bar.label = label
  local track = bar:CreateTexture(nil, "BACKGROUND")
  bar.track = track
  local fill = bar:CreateTexture(nil, "ARTWORK")
  bar.fill = fill
  local value = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  NS.Skin.Font(value)
  value:SetJustifyH("RIGHT")
  value:SetWordWrap(false)
  bar.value = value
  bar:EnableMouse(true)
  bar:SetScript("OnEnter", function(self) W.CursorTooltip(self, self._tip, W.TIP_TITLE) end)
  bar:SetScript("OnLeave", hideTooltip)
  return bar
end

-- A track's and a baseline's flat colors (chart.track, chart.axisAlt), painted on every placement
-- so a refresh after a skin switch repaints a pooled bar; never the bar texture (NS.SkinBar), which
-- is for data alone.
local function paintTrack(bar)
  bar.track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
  if bar.baseline then bar.baseline:SetColorTexture(AXIS_ALT[1], AXIS_ALT[2], AXIS_ALT[3], AXIS_ALT[4]) end
end

-- Position a bar inside `host` at y with total width barW, filled to `frac` of its track.
function W.PlaceBar(bar, host, x, y, barW, frac)
  paintTrack(bar)
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
  bar:SetWidth(barW)
  bar.label:ClearAllPoints()
  bar.label:SetPoint("LEFT", 0, 0)
  bar.label:SetWidth(W.LABEL_W)
  bar.value:ClearAllPoints()
  bar.value:SetPoint("RIGHT", 0, 0)
  bar.value:SetWidth(W.VALUE_W)
  local trackW = math.max(1, barW - W.LABEL_W - W.VALUE_W - 12)
  bar.track:ClearAllPoints()
  bar.track:SetPoint("LEFT", W.LABEL_W + 6, 0)
  bar.track:SetSize(trackW, W.BAR_H - 4)
  bar.fill:ClearAllPoints()
  bar.fill:SetPoint("LEFT", bar.track, "LEFT", 0, 0)
  bar.fill:SetSize(math.max(1, trackW * math.min(1, frac or 0)), W.BAR_H - 4)
  return trackW
end

-- ── Split bar ──────────────────────────────────────────────────────────────────
-- The headline two-way split, drawn as ONE back-to-back row: both halves grow out from a fixed
-- center axis, scaled against the larger of the two, so the bigger side fills its half and the
-- smaller is its visible proportion. Same form and same reading as the "× Deposits/Withdrawals"
-- companions further down the panel — a 100%-stacked ratio bar here would have answered the same
-- question in a different visual language, and the eye pays for that inconsistency.

function W.MakeSplitBar(parent)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(W.SPLIT_H)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  bar.track = track
  local baseline = bar:CreateTexture(nil, "OVERLAY")
  bar.baseline = baseline
  bar.left = CreateFrame("Frame", nil, bar)
  bar.right = CreateFrame("Frame", nil, bar)
  for _, side in ipairs({ bar.left, bar.right }) do
    side:EnableMouse(true)
    local tex = side:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(side)
    side.tex = tex
    side:SetScript("OnEnter", function(self) W.CursorTooltip(self, self._tip) end)
    side:SetScript("OnLeave", hideTooltip)
  end
  -- The captions sit BELOW the bar, pinned to its two ends. Inside the bar they were unreadable at
  -- a lopsided split -- the narrow share had no room for its own text and dropped it entirely.
  local lfs = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  NS.Skin.Font(lfs)
  lfs:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
  lfs:SetJustifyH("LEFT")
  lfs:SetWordWrap(false)
  bar.leftText = lfs
  local rfs = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  NS.Skin.Font(rfs)
  rfs:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
  rfs:SetJustifyH("RIGHT")
  rfs:SetWordWrap(false)
  bar.rightText = rfs
  return bar
end

-- `left`/`right` are { frac, color, text, tip }, each `frac` a share of ONE HALF of the bar (1.0
-- fills its side exactly) — feed them from W.PeakShares. The two texts are painted in the caption
-- row under the bar, each in its own direction color, so both stay readable at any split --
-- including 97/3, where in-bar text vanishes. The per-side hover tips carry the exact numbers.
function W.PlaceSplitBar(bar, host, x, y, barW, left, right)
  paintTrack(bar)
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
  bar:SetWidth(barW)
  bar.track:ClearAllPoints()
  bar.track:SetPoint("LEFT", 0, 0)
  bar.track:SetSize(barW, W.SPLIT_H)
  bar.baseline:ClearAllPoints()
  bar.baseline:SetPoint("CENTER", bar.track, "CENTER", 0, 0)
  bar.baseline:SetSize(1, W.SPLIT_H + 2)
  local halfW = barW / 2
  -- Anchored to the bar's CENTER, not to its edges: that is what pins the split to one line and
  -- lets each half's LENGTH — rather than its share of a fixed width — carry the magnitude.
  local function place(side, anchor, spec)
    local w = halfW * math.min(1, math.max(0, spec.frac or 0))
    side:ClearAllPoints()
    side:SetPoint(anchor, bar, "CENTER", 0, 0)
    side:SetSize(math.max(1, w), W.SPLIT_H)
    NS.SkinBar(side.tex, spec.color[1], spec.color[2], spec.color[3], 0.9)
    side._tip = spec.tip
    side:SetShown(w > 0)
  end
  place(bar.left, "RIGHT", left)
  place(bar.right, "LEFT", right)
  bar.leftText:SetText(left.text or "")
  bar.leftText:SetTextColor(left.color[1], left.color[2], left.color[3])
  bar.rightText:SetText(right.text or "")
  bar.rightText:SetTextColor(right.color[1], right.color[2], right.color[3])
end

-- ── Stacked bar ────────────────────────────────────────────────────────────────

function W.MakeStackedBar(parent)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(W.BAR_H)
  local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  NS.Skin.Font(label)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  bar.label = label
  local track = bar:CreateTexture(nil, "BACKGROUND")
  bar.track = track
  local value = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  NS.Skin.Font(value)
  value:SetJustifyH("RIGHT")
  value:SetWordWrap(false)
  bar.value = value
  -- Each segment is a mouse-enabled FRAME rather than a bare texture, so it can carry its own
  -- "<category>: <value>" tip — the only way to read a stacked bar precisely.
  bar.segs = {}
  for i = 1, W.MAX_STACK_SEGS do
    local seg = CreateFrame("Frame", nil, bar)
    seg:EnableMouse(true)
    local tex = seg:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(seg)
    seg.tex = tex
    seg:SetScript("OnEnter", function(self) W.CursorTooltip(self, self._tip) end)
    seg:SetScript("OnLeave", hideTooltip)
    bar.segs[i] = seg
  end
  bar:EnableMouse(true)
  bar:SetScript("OnEnter", function(self) W.CursorTooltip(self, self._tip, W.TIP_TITLE) end)
  bar:SetScript("OnLeave", hideTooltip)
  return bar
end

function W.PlaceStackedBar(bar, host, x, y, barW, segments)
  paintTrack(bar)
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
  bar:SetWidth(barW)
  bar.label:ClearAllPoints()
  bar.label:SetPoint("LEFT", 0, 0)
  bar.label:SetWidth(W.LABEL_W)
  bar.value:ClearAllPoints()
  bar.value:SetPoint("RIGHT", 0, 0)
  bar.value:SetWidth(W.VALUE_W)
  local trackW = math.max(1, barW - W.LABEL_W - W.VALUE_W - 12)
  bar.track:ClearAllPoints()
  bar.track:SetPoint("LEFT", W.LABEL_W + 6, 0)
  bar.track:SetSize(trackW, W.BAR_H - 4)
  local offset = 0
  for i = 1, #bar.segs do
    local seg, spec = bar.segs[i], (segments or {})[i]
    if spec and (spec.frac or 0) > 0 then
      local segW = math.max(1, trackW * math.min(1, spec.frac))
      seg:ClearAllPoints()
      seg:SetPoint("LEFT", bar.track, "LEFT", offset, 0)
      seg:SetSize(segW, W.BAR_H - 4)
      NS.SkinBar(seg.tex, spec.color[1], spec.color[2], spec.color[3], 0.95)
      seg._tip = spec.tip
      seg:Show()
      offset = offset + segW
    else
      seg:Hide()
    end
  end
  return trackW
end

-- ── Back-to-back bar ───────────────────────────────────────────────────────────
-- Two magnitudes meeting at a fixed center axis: one grows left, the other right. The honest form
-- for a two-way split across many rows — the boundary never moves, so the lean of every row is
-- readable down one line instead of one bar at a time.

function W.MakeBackToBackBar(parent)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(W.BAR_H)
  local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  NS.Skin.Font(label)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  bar.label = label
  local track = bar:CreateTexture(nil, "BACKGROUND")
  bar.track = track
  local baseline = bar:CreateTexture(nil, "OVERLAY")
  bar.baseline = baseline
  local value = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  NS.Skin.Font(value)
  value:SetJustifyH("RIGHT")
  value:SetWordWrap(false)
  bar.value = value
  -- Each half is a mouse-enabled FRAME, not a bare texture, so it can carry its own
  -- "<category>: <n>" tip — the only way to read the exact split off the chart.
  bar.leftSide = CreateFrame("Frame", nil, bar)
  bar.rightSide = CreateFrame("Frame", nil, bar)
  for _, side in ipairs({ bar.leftSide, bar.rightSide }) do
    side:EnableMouse(true)
    local tex = side:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(side)
    side.tex = tex
    side:SetScript("OnEnter", function(self) W.CursorTooltip(self, self._tip) end)
    side:SetScript("OnLeave", hideTooltip)
  end
  bar:EnableMouse(true)
  bar:SetScript("OnEnter", function(self) W.CursorTooltip(self, self._tip, W.TIP_TITLE) end)
  bar:SetScript("OnLeave", hideTooltip)
  return bar
end

-- `row` is a W.BuildBackToBackRows row ({ leftFrac, rightFrac, leftTip, rightTip }); each fraction
-- is of ONE HALF of the track, so a 1.0 fills its side exactly.
function W.PlaceBackToBackBar(bar, host, x, y, barW, row, leftColor, rightColor)
  paintTrack(bar)
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
  bar:SetWidth(barW)
  bar.label:ClearAllPoints()
  bar.label:SetPoint("LEFT", 0, 0)
  bar.label:SetWidth(W.LABEL_W)
  bar.value:ClearAllPoints()
  bar.value:SetPoint("RIGHT", 0, 0)
  bar.value:SetWidth(W.VALUE_W)
  local trackW = math.max(2, barW - W.LABEL_W - W.VALUE_W - 12)
  local halfW = trackW / 2
  bar.track:ClearAllPoints()
  bar.track:SetPoint("LEFT", W.LABEL_W + 6, 0)
  bar.track:SetSize(trackW, W.BAR_H - 4)
  bar.baseline:ClearAllPoints()
  bar.baseline:SetPoint("CENTER", bar.track, "CENTER", 0, 0)
  bar.baseline:SetSize(1, W.BAR_H - 2)

  -- Anchored to the track's CENTER, not to its edges: that is what pins the split to one line.
  local function place(side, frac, anchor, color, tip)
    local w = halfW * math.min(1, math.max(0, frac or 0))
    side:ClearAllPoints()
    side:SetPoint(anchor, bar.track, "CENTER", 0, 0)
    side:SetSize(math.max(1, w), W.BAR_H - 4)
    NS.SkinBar(side.tex, color[1], color[2], color[3], 0.95)
    side._tip = tip
    side:SetShown(w > 0)
  end
  place(bar.leftSide, row.leftFrac, "RIGHT", leftColor, row.leftTip)
  place(bar.rightSide, row.rightFrac, "LEFT", rightColor, row.rightTip)
  return trackW
end

-- ── Vertical strip ─────────────────────────────────────────────────────────────
-- Per-bucket columns (per day, per hour) with a baseline axis and rotated x-axis labels.

function W.MakeStripBar(parent)
  local f = CreateFrame("Frame", nil, parent)
  local fill = f:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("BOTTOM", 0, 0)
  f.fill = fill
  -- The axis label is rotated 90° CCW so it reads bottom-to-top: a horizontal date label needs ~34px
  -- and the bars are often 6px apart. text.muted, recorded, so a switch repaints it.
  local axis = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  axis:SetRotation(math.pi / 2)
  NS.Skin.Text(axis, "muted")
  f.axis = axis
  W.PaintStripBar(f)
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(self)
    if not (self._tip and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(self._tip, W.TIP_VALUE[1], W.TIP_VALUE[2], W.TIP_VALUE[3])
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", hideTooltip)
  return f
end

--- A strip bar's fill: chart.bar in the owner's bar texture (NS.SkinBar). At build and on every
--- placement (modules/Insights.lua RenderStrip), so a refresh after a skin switch repaints it.
function W.PaintStripBar(f)
  NS.SkinBar(f.fill, NS.SkinColor("chart.bar"))
end

-- How wide each bar is, and how many buckets to skip between axis labels, for `n` buckets across
-- `innerW` pixels. Pure, so the thinning rule is testable: labels stay at least ~11px apart.
function W.StripMetrics(n, innerW)
  n = math.max(1, n or 1)
  local slot = innerW / n
  local barW = math.max(2, math.min(14, slot - 2))
  local stride = math.max(1, math.ceil(11 / math.max(0.01, slot)))
  return slot, barW, stride
end

-- ── Ranked list panel ──────────────────────────────────────────────────────────

-- A bordered ranked-list panel. Pooled, so the title is set per pass rather than baked in, and
-- each panel carries its OWN row pool: rows are parented to a specific panel at creation and can
-- never be shared across panels.
function W.MakeListPanel(parent, title)
  local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  -- The skin's Panel (panel.bg under panel.border; on Ka0s Default call for call the backdrop it
  -- always drew), its title in the heading color: both recorded, so a switch repaints them.
  NS.Skin.Panel(p)
  local t = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t:SetPoint("TOPLEFT", 6, -5)
  NS.Skin.Text(t, "heading")
  t:SetText(title or "")
  p.title = t
  p._rows = W.NewPool()
  return p
end

function W.SetPanelTitle(panel, text)
  panel.title:SetText(text or "")
end

-- Release a panel pool AND every panel's rows, so a shrinking pass leaves no orphan row visible.
-- A panel owns a row pool, so releasing the panels releases their rows first. That ordering used
-- to be two nested loops here; it is the library's `before` hook now.
function W.ReleasePanels(pool)
  NS.Pool.ReleaseAll(pool, function(p) NS.Pool.ReleaseAll(p._rows) end)
end

function W.MakeListRow(parent)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(W.LIST_ROW_H)
  local name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  NS.Skin.Font(name)
  name:SetJustifyH("LEFT")
  name:SetPoint("LEFT", 4, 0)
  name:SetWordWrap(false)
  r.name = name
  local right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  NS.Skin.Font(right)
  right:SetJustifyH("RIGHT")
  right:SetPoint("RIGHT", -4, 0)
  right:SetWordWrap(false)
  r.right = right
  r:EnableMouse(true)
  r:SetScript("OnEnter", function(self) W.CursorTooltip(self, self._tip) end)
  r:SetScript("OnLeave", hideTooltip)
  return r
end

-- ── Legend + section chrome ────────────────────────────────────────────────────

function W.MakeSwatch(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(14)
  local sw = f:CreateTexture(nil, "ARTWORK")
  sw:SetSize(10, 10)
  sw:SetPoint("LEFT", f, "LEFT", 0, 0)
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("LEFT", sw, "RIGHT", 4, 0)
  -- text.value, recorded; its hover line is the same token (W.MUTED), the inventory's BL-G2 ruling.
  NS.Skin.Text(fs, "text.value")
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  f.sw, f.fs = sw, fs
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(self) W.CursorTooltip(self, self._tip, W.MUTED) end)
  f:SetScript("OnLeave", hideTooltip)
  return f
end

function W.MakeSectionHeader(parent, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetText(text or "")
  NS.Skin.Text(fs, "heading")   -- recorded, so a switch repaints it
  return fs
end

-- A full-width band: a large centered gold title flanked by rules — the same separator look the
-- settings panel's section headings use, so the two surfaces read as one addon.
function W.MakeSectionDivider(parent, text)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(26)
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("CENTER", f, "CENTER", 0, 0)
  fs:SetText(text or "")
  f.fs = fs
  -- The rules are the skin's section.rule (the heading gold at .35 under Ka0s Default), recorded.
  local lineL = f:CreateTexture(nil, "ARTWORK")
  NS.Skin.Divider(lineL, { token = "section.rule" })
  lineL:SetHeight(1.25)
  lineL:SetPoint("LEFT", f, "LEFT", 0, 0)
  lineL:SetPoint("RIGHT", fs, "LEFT", -8, 0)
  local lineR = f:CreateTexture(nil, "ARTWORK")
  NS.Skin.Divider(lineR, { token = "section.rule" })
  lineR:SetHeight(1.25)
  lineR:SetPoint("LEFT", fs, "RIGHT", 8, 0)
  lineR:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  W.ReskinDivider(f)
  return f
end

--- A section divider's title: the heading color and face (S.Text, which a skin switch replays at
--- the face's own size), then 1.5x that size. At build and after every switch, so the replay never
--- leaves the title at 1x.
function W.ReskinDivider(f)
  NS.Skin.Text(f.fs, "heading")
  local file, size, flags = f.fs:GetFont()
  if type(size) == "number" then f.fs:SetFont(file, size * 1.5, flags) end
end
