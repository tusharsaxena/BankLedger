local _, NS = ...
NS.Insights = NS.Insights or {}
local I = NS.Insights
local C = NS.Constants
local W = NS.InsightsWidgets

-- The Insights tab's section renderers: the I:Render* methods the section builders in
-- modules/Insights.lua drive, one per chart shape. Peeled out of that file on the seam its watch-list
-- row named (docs/automated-tests/RESULTS.md), before a third release run carried it as Accepted. A
-- MOVE, not a rewrite: every I method keeps its name and behavior. What these need of Insights.lua's
-- file locals comes through ONE explicit seam table, I._renderSeam, published at that file's load.
local seam = I._renderSeam
local PAD, BAR_ROWS, LIST_ROWS = seam.PAD, seam.BAR_ROWS, seam.LIST_ROWS
local directionColor, directionLabel = seam.directionColor, seam.directionLabel

local LIST_COLS = 3          -- All / Deposits / Withdrawals, side by side

-- ── Render helpers ─────────────────────────────────────────────────────────────

-- A ranked horizontal-bar section. `rows` is an ordered array of
--   { label, fullLabel, labelColor, color, frac, value }
-- with `frac` relative to the largest row (normalized here, so callers can pass raw ratios).
-- Returns the new y cursor; an empty list hides the header and consumes no space.
function I:RenderBars(poolKey, headerKey, rows, y, w, legendPool)
  local header = self.headers[headerKey]
  if #rows == 0 then header:Hide(); return y end
  W.NormalizeFractions(rows)
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, y)
  header:Show()
  y = y - 18
  local innerW = w - PAD * 2
  for _, row in ipairs(rows) do
    local bar = W.Acquire(self.pools[poolKey], function() return W.MakeBar(self.content) end)
    local color = row.color or W.NEUTRAL
    NS.SkinBar(bar.fill, color[1], color[2], color[3], 0.95)
    bar._tip = I.ElementTip(row.fullLabel or row.label, row.value)
    bar.label:SetText(I.BarLabel(row))
    -- The label defaults to its bar's color, which makes a single bar self-legending.
    local lc = row.labelColor or color
    bar.label:SetTextColor(lc[1], lc[2], lc[3])
    bar.value:SetText(row.value or "")
    bar.value:SetTextColor(W.MUTED[1], W.MUTED[2], W.MUTED[3])
    W.PlaceBar(bar, self.content, PAD, y, innerW, row.frac)
    y = y - (W.BAR_H + W.BAR_GAP)
  end
  if legendPool then
    local legend = {}
    for _, row in ipairs(rows) do
      legend[#legend + 1] = { label = row.fullLabel or row.label, color = row.color or W.NEUTRAL }
    end
    return self:RenderLegend(legendPool, legend, y, w)
  end
  return y - W.SECTION_GAP
end

-- A per-row stacked-bar section (the "× Store" companion).
function I:RenderStacked(poolKey, headerKey, rows, y, w)
  local header = self.headers[headerKey]
  if #rows == 0 then header:Hide(); return y end
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, y)
  header:Show()
  y = y - 18
  local innerW = w - PAD * 2
  for _, row in ipairs(rows) do
    local bar = W.Acquire(self.pools[poolKey],
      function() return W.MakeStackedBar(self.content) end)
    bar._tip = I.ElementTip(row.fullLabel or row.label, row.value)
    bar.label:SetText((W.Truncate(row.label)))
    local lc = row.labelColor or W.MUTED
    bar.label:SetTextColor(lc[1], lc[2], lc[3])
    bar.value:SetText(row.value or "")
    bar.value:SetTextColor(W.MUTED[1], W.MUTED[2], W.MUTED[3])
    W.PlaceStackedBar(bar, self.content, PAD, y, innerW, row.segments)
    y = y - (W.BAR_H + W.BAR_GAP)
  end
  return y - W.SECTION_GAP
end

-- A back-to-back section: withdrawals grow left of a fixed center axis, deposits grow right.
-- `rows` comes from W.BuildBackToBackRows, already scaled and sorted.
function I:RenderBackToBack(poolKey, headerKey, rows, y, w)
  local header = self.headers[headerKey]
  if #rows == 0 then header:Hide(); return y end
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, y)
  header:Show()
  y = y - 18
  local innerW = w - PAD * 2
  local leftColor = directionColor(C.Direction.WITHDRAW)
  local rightColor = directionColor(C.Direction.DEPOSIT)
  for _, row in ipairs(rows) do
    local bar = W.Acquire(self.pools[poolKey],
      function() return W.MakeBackToBackBar(self.content) end)
    bar._tip = I.ElementTip(row.fullLabel or row.label, row.value)
    bar.label:SetText(I.BarLabel(row))
    local lc = row.labelColor or W.MUTED
    bar.label:SetTextColor(lc[1], lc[2], lc[3])
    bar.value:SetText(row.value or "")
    bar.value:SetTextColor(W.MUTED[1], W.MUTED[2], W.MUTED[3])
    W.PlaceBackToBackBar(bar, self.content, PAD, y, innerW, row, leftColor, rightColor)
    y = y - (W.BAR_H + W.BAR_GAP)
  end
  return y - W.SECTION_GAP
end

-- A wrapped legend of color-swatch chips, aligned under where the bars begin (not under the text
-- labels), so it reads as belonging to the track. The chip is a flat 10px color (no bar texture: it
-- is a key, not a bar of data), in the same token color as the bars it names.
function I:RenderLegend(poolKey, rows, y, w)
  local x0 = PAD + W.LABEL_W + 6
  local chipW = 122
  local x, rowY = x0, y
  for _, row in ipairs(rows) do
    if x + chipW > w - PAD then x = x0; rowY = rowY - 16 end
    local chip = W.Acquire(self.pools[poolKey], function() return W.MakeSwatch(self.content) end)
    chip.sw:SetColorTexture(row.color[1], row.color[2], row.color[3], 0.95)
    chip._tip = row.label
    chip.fs:SetWidth(chipW - 16)
    chip.fs:SetText((W.Truncate(row.label, W.LEGEND_MAXCHARS)))
    chip:ClearAllPoints()
    chip:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, rowY)
    chip:SetWidth(chipW)
    x = x + chipW
  end
  return rowY - 16 - W.SECTION_GAP
end

-- The tallest bucket in a strip, floored at 1 so an all-empty strip scales rather than dividing
-- by zero.
local function stripPeak(buckets)
  local peak = 1
  for _, b in ipairs(buckets) do
    if (b.magnitude or 0) > peak then peak = b.magnitude end
  end
  return peak
end

-- One axis line under the whole strip, separating the bars from their labels.
local function stripAxisLine(strip)
  strip.axisLine = strip.axisLine or strip:CreateTexture(nil, "ARTWORK")
  strip.axisLine:SetColorTexture(NS.SkinColor("chart.axis"))
  strip.axisLine:ClearAllPoints()
  strip.axisLine:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, -W.STRIP_AXIS_GAP)
  strip.axisLine:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, -W.STRIP_AXIS_GAP)
  strip.axisLine:SetHeight(1)
  strip.axisLine:Show()
end

-- Right-align the rotated label so labels of different lengths all start at the axis line and
-- hang straight down from it.
local function placeStripLabel(f, label, barW)
  f.axis:SetText(label)
  local tw = f.axis:GetStringWidth()
  if type(tw) ~= "number" then tw = 0 end
  f.axis:ClearAllPoints()
  f.axis:SetPoint("CENTER", f, "BOTTOMLEFT", barW / 2 - 2,
    -(tw / 2) - W.STRIP_AXIS_GAP - W.STRIP_LABEL_GAP)
  f.axis:Show()
end

-- A per-bucket vertical strip. `buckets` is ordered { magnitude, label, tip }.
function I:RenderStrip(poolKey, headerKey, strip, buckets, y, w)
  local header = self.headers[headerKey]
  if #buckets == 0 then header:Hide(); strip:Hide(); return y end
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, y)
  header:Show()
  y = y - 18
  local innerW = w - PAD * 2
  strip:ClearAllPoints()
  strip:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, y)
  strip:SetSize(innerW, W.STRIP_H)
  strip:Show()

  local slot, barW, stride = W.StripMetrics(#buckets, innerW)
  local peak = stripPeak(buckets)
  stripAxisLine(strip)

  for i, b in ipairs(buckets) do
    local f = W.Acquire(self.pools[poolKey], function() return W.MakeStripBar(strip) end)
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", (i - 1) * slot, 0)
    f:SetSize(barW, W.STRIP_H)
    W.PaintStripBar(f)   -- a pooled bar, any skin
    local mag = b.magnitude or 0
    f.fill:SetSize(barW, math.max(1, (mag / peak) * (W.STRIP_H - 2)))
    -- An empty bucket keeps a ghost of a bar: it marks that the day existed and was quiet, which a
    -- gap of nothing cannot distinguish from a day that fell outside the range.
    f.fill:SetAlpha(mag == 0 and 0.12 or 0.9)
    f._tip = b.tip
    if b.label and ((i - 1) % stride == 0) then
      placeStripLabel(f, b.label, barW)
    else
      f.axis:SetText("")
      f.axis:Hide()
    end
  end
  return y - W.STRIP_H - W.STRIP_LABEL_H - W.SECTION_GAP
end

-- A ranked list panel, acquired from the pool and titled per pass. `rows` is
-- { name, fullName, nameColor, right }. Returns the panel's height (0 when there is nothing to
-- show, so the caller can collapse the slot) so columns of differing lengths can be stacked.
function I:RenderList(title, rows, y, x, colW, rightW)
  local n = math.min(LIST_ROWS, #rows)
  if n == 0 then return 0 end
  local panel = W.Acquire(self.panelPool, function() return W.MakeListPanel(self.content) end)
  W.SetPanelTitle(panel, title)
  local panelH = 20 + n * W.LIST_ROW_H + 4
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
  panel:SetSize(colW, panelH)
  for i = 1, n do
    local row = rows[i]
    local r = W.Acquire(panel._rows, function() return W.MakeListRow(panel) end)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -20 - (i - 1) * W.LIST_ROW_H)
    r:SetWidth(colW - 8)
    r.name:SetWidth(math.max(1, colW - 8 - (rightW or 48) - 6))
    r.name:SetText(row.name)
    r._tip = I.ElementTip(row.fullName or row.name, row.right)
    local nc = row.nameColor or W.MUTED
    r.name:SetTextColor(nc[1], nc[2], nc[3])
    r.right:SetWidth(rightW or 48)
    r.right:SetText(row.right or "")
    r.right:SetTextColor(W.MUTED[1], W.MUTED[2], W.MUTED[3])
  end
  return panelH
end

-- A pooled sub-heading inside the Top Of The List section, so the groups can be named without a
-- fixed header per group.
function I:RenderSubHead(text, y, indent)
  local fs = W.Acquire(self.pools.listHead,
    function() return W.MakeSectionHeader(self.content, "") end)
  fs:SetText(text)
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD + (indent or 0), y)
  return y - 18
end

-- One row of up to LIST_COLS panels. `specs` is { title, rows, rightW }; an empty list simply
-- leaves its column blank. The row advances by its TALLEST panel so nothing overlaps.
function I:RenderListRow(specs, y, innerW)
  local gap = 12
  local colW = math.floor((innerW - gap * (LIST_COLS - 1)) / LIST_COLS)
  local tallest, col = 0, 0
  for _, spec in ipairs(specs) do
    if col >= LIST_COLS then
      y = y - tallest - W.SECTION_GAP
      tallest, col = 0, 0
    end
    local h = self:RenderList(spec.title, spec.rows, y, PAD + col * (colW + gap), colW, spec.rightW)
    if h > tallest then tallest = h end
    col = col + 1
  end
  if tallest == 0 then return y end
  return y - tallest - W.SECTION_GAP
end

-- A "<segment> x Deposits/Withdrawals" companion, drawn back to back, in the
-- direction colors, with a legend. `labelOf`/`labelColorOf` keep each row recognizable against
-- the parent chart it sits under.
function I:RenderDirectionSplit(poolKey, headerKey, legendKey, matrix, opts, y, w)
  if not next(matrix or {}) then
    self.headers[headerKey]:Hide()
    return y
  end
  -- Deposits right of the center axis, withdrawals left of it. Both sides share one scale, so the
  -- split sits on the same vertical line in every row and the lean of the whole chart reads at a
  -- glance rather than row by row.
  local rows = W.BuildBackToBackRows(matrix, C.Direction.DEPOSIT, C.Direction.WITHDRAW, {
    labelOf = opts.labelOf, labelColorOf = opts.labelColorOf, valueFmt = tostring,
  })
  -- Each half's tip carries its share of THAT ROW's movements, not of the chart: the question a
  -- split bar raises is "how much of this store/quality/type went each way", and the percentage is
  -- what the eye cannot read off two bar lengths.
  for _, row in ipairs(rows) do
    row.rightTip = ("%s: %d (%d%%)"):format(
      directionLabel(C.Direction.DEPOSIT), row.rightMag, W.Percent(row.rightMag, row.total))
    row.leftTip = ("%s: %d (%d%%)"):format(
      directionLabel(C.Direction.WITHDRAW), row.leftMag, W.Percent(row.leftMag, row.total))
  end
  -- Cap at BAR_ROWS to match the parent bar chart above it: the rows are already sorted
  -- total-desc, so truncating after the sort keeps the largest.
  if #rows > BAR_ROWS then
    for i = #rows, BAR_ROWS + 1, -1 do rows[i] = nil end
  end
  y = self:RenderBackToBack(poolKey, headerKey, rows, y, w)
  -- Legend order follows the CHART left-to-right (withdraw, deposit), not C.DirectionOrder: a
  -- legend that reads in the opposite order to the thing it explains is a small lie.
  local legend = {}
  for _, key in ipairs({ C.Direction.WITHDRAW, C.Direction.DEPOSIT }) do
    legend[#legend + 1] = { label = directionLabel(key), color = directionColor(key) }
  end
  return self:RenderLegend(legendKey, legend, y, w)
end
