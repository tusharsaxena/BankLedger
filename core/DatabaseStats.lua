local _, NS = ...
local C = NS.Constants

-- The Insights aggregation, Database:Stats, and its accumulate*/derive* helpers. Peeled out of
-- core/Database.lua as a pure move (BL-07) when the write sink pushed that file past 1000 lines;
-- it loads straight after it (BankLedger.toc) and extends the same NS.Database table.
NS.Database = NS.Database or {}
local Database = NS.Database

-- Nested-table increment used by the per-character × store matrix and its siblings.
local function bump(matrix, k1, k2, amt)
  if k1 == nil or k2 == nil then return end
  local m = matrix[k1]; if not m then m = {}; matrix[k1] = m end
  m[k2] = (m[k2] or 0) + amt
end

-- One bucket set for a single Stats() pass. Every field is written by exactly one of the
-- accumulate* helpers below, so a new breakdown is a field here plus a line in its helper rather
-- than another guard in a shared loop body.
local function newAccumulator()
  return {
    byStore = {}, byDirection = {}, byKind = {}, byDay = {}, byChar = {},
    byItem = {}, byItemType = {},
    netByStore = {}, charByStore = {},
    -- The second wave of breakdowns, added for the expanded Insights panel. Every one is a plain
    -- extra accumulator in the SAME single pass — the panel got richer without the aggregation
    -- getting slower, and no existing key changed name or meaning.
    byItemSubType = {}, byQuality = {}, byZone = {},
    byHour = {}, byWeekday = {},
    moneyByDay = {}, moneyByStore = {},
    charByDirection = {}, storeByDirection = {},
    qualityByDirection = {}, itemTypeByDirection = {}, itemSubTypeByDirection = {},
    -- Third wave: the direction-split rankings behind the reorganized "Top Of The List" grid.
    byTypeSub = {}, itemsByStore = {}, zoneByDirection = {},
    distinctItems = 0, distinctChars = 0,
    firstTs = nil, lastTs = nil,
    itemsDeposited = 0, itemsWithdrawn = 0,
    moneyIn = 0, moneyOut = 0,
  }
end

-- The breakdowns every entry contributes to, gold and items alike.
local function accumulateCore(A, e, store, dir)
  A.byStore[store] = (A.byStore[store] or 0) + 1
  A.byDirection[dir] = (A.byDirection[dir] or 0) + 1
  A.byKind[e.kind or "ITEM"] = (A.byKind[e.kind or "ITEM"] or 0) + 1
  -- Net flow per store, counted in MOVEMENTS: +1 for a deposit, -1 for a withdrawal. The only
  -- signed non-gold quantity the addon keeps now that vendor value is gone (schema v2).
  A.netByStore[store] = (A.netByStore[store] or 0) + (C.DirectionSign[dir] or 1)

  bump(A.storeByDirection, store, dir, 1)
  if e.zone and e.zone ~= "" then
    A.byZone[e.zone] = (A.byZone[e.zone] or 0) + 1
    bump(A.zoneByDirection, e.zone, dir, 1)
  end
end

local function accumulateMoney(A, store, dir, qty)
  if dir == "DEPOSIT" then A.moneyIn = A.moneyIn + qty else A.moneyOut = A.moneyOut + qty end
  A.moneyByStore[store] = (A.moneyByStore[store] or 0) + qty
end

-- Type, sub-type, the type+sub-type pivot and quality — the item classification axes.
local function accumulateItemTaxonomy(A, e, dir)
  local ty = e.itemType
  if ty and ty ~= "" then
    A.byItemType[ty] = (A.byItemType[ty] or 0) + 1
    bump(A.itemTypeByDirection, ty, dir, 1)
  end
  local sty = e.itemSubType
  if sty and sty ~= "" then
    A.byItemSubType[sty] = (A.byItemSubType[sty] or 0) + 1
    bump(A.itemSubTypeByDirection, sty, dir, 1)
  end
  -- Type + sub-type as one pivot. Keyed on a tab-joined pair so "Armor/Cloth" and
  -- "Tradegoods/Cloth" can never collide; `label` is the display form.
  if ty and ty ~= "" and sty and sty ~= "" then
    local key = ty .. "\t" .. sty
    local tsRec = A.byTypeSub[key]
    if not tsRec then
      tsRec = { type = ty, subType = sty, label = ty .. " \194\183 " .. sty,
                count = 0, inCount = 0, outCount = 0 }
      A.byTypeSub[key] = tsRec
    end
    tsRec.count = tsRec.count + 1
    if dir == "DEPOSIT" then tsRec.inCount = tsRec.inCount + 1
    else tsRec.outCount = tsRec.outCount + 1 end
  end
  -- Quality is an item question by definition: a gold movement has none, and bucketing it under
  -- Poor would invent a fact. Keyed on the numeric id so the chart can sort Poor→Legendary.
  if type(e.quality) == "number" then
    A.byQuality[e.quality] = (A.byQuality[e.quality] or 0) + 1
    bump(A.qualityByDirection, e.quality, dir, 1)
  end
end

-- The per-item record and the per-store item index, both split by direction.
local function accumulateItemIndex(A, e, store, dir, qty)
  local id = e.itemID
  if id == nil then return end
  local isIn = (dir == "DEPOSIT")
  local rec = A.byItem[id]
  if rec then
    rec.moves = rec.moves + 1
    rec.quantity = rec.quantity + qty
  else
    rec = { itemID = id, itemName = e.itemName, quality = e.quality,
            moves = 1, quantity = qty,
            movesIn = 0, movesOut = 0, qtyIn = 0, qtyOut = 0 }
    A.byItem[id] = rec
    A.distinctItems = A.distinctItems + 1
  end
  if isIn then
    rec.movesIn = rec.movesIn + 1
    rec.qtyIn = rec.qtyIn + qty
  else
    rec.movesOut = rec.movesOut + 1
    rec.qtyOut = rec.qtyOut + qty
  end
  -- Per-store item index, for the per-store All/Deposits/Withdrawals panels. Split by
  -- direction here so each store gets the same three rankings the global lists have.
  local m = A.itemsByStore[store]
  if not m then m = {}; A.itemsByStore[store] = m end
  local sRec = m[id]
  if not sRec then sRec = { moves = 0, movesIn = 0, movesOut = 0 }; m[id] = sRec end
  sRec.moves = sRec.moves + 1
  if isIn then sRec.movesIn = sRec.movesIn + 1 else sRec.movesOut = sRec.movesOut + 1 end
end

local function accumulateItem(A, e, store, dir, qty)
  if dir == "DEPOSIT" then A.itemsDeposited = A.itemsDeposited + qty
  else A.itemsWithdrawn = A.itemsWithdrawn + qty end
  accumulateItemTaxonomy(A, e, dir)
  accumulateItemIndex(A, e, store, dir, qty)
end

-- Day, hour-of-day and weekday buckets plus the first/last timestamp span.
local function accumulateTime(A, e, qty)
  if not e.ts then return end
  local day = date("%Y-%m-%d", e.ts)
  A.byDay[day] = (A.byDay[day] or 0) + 1
  if e.kind == "MONEY" then A.moneyByDay[day] = (A.moneyByDay[day] or 0) + qty end
  if not A.firstTs or e.ts < A.firstTs then A.firstTs = e.ts end
  if not A.lastTs or e.ts > A.lastTs then A.lastTs = e.ts end
  -- Hour-of-day and weekday, for the "when do I actually visit the bank" strips. `wday` is
  -- 1-based with Sunday = 1; normalized to 0..6 so it indexes a plain weekday-label array.
  local t = date("*t", e.ts)
  if t then
    A.byHour[t.hour] = (A.byHour[t.hour] or 0) + 1
    local wd = (t.wday or 1) - 1
    A.byWeekday[wd] = (A.byWeekday[wd] or 0) + 1
  end
end

local function accumulateChar(A, e, store, dir)
  local ch = e.char
  if not ch then return end
  bump(A.charByDirection, ch, dir, 1)
  local ce = A.byChar[ch]
  if not ce then
    ce = { char = ch, classFile = e.classFile, count = 0 }
    A.byChar[ch] = ce
    A.distinctChars = A.distinctChars + 1
  end
  ce.count = ce.count + 1
  bump(A.charByStore, ch, store, 1)
end

-- One comparator factory: rank on `field` desc, tiebreak on the item id asc.
local function byField(field)
  return function(a, b)
    if a[field] ~= b[field] then return a[field] > b[field] end
    return (a.itemID or 0) < (b.itemID or 0)
  end
end

-- Top items, ranked five ways off the one byItem index. Each list is a fresh array of the SAME
-- record tables (never a copy), so five rankings cost five sorts and no extra memory. Every
-- comparator ends on the item id, so a tie can never reorder run to run.
local function deriveTopItems(A)
  local topItems, topItemsByQuantity = {}, {}
  local topItemsIn, topItemsOut = {}, {}
  local topItemsByQuantityIn, topItemsByQuantityOut = {}, {}
  for _, rec in pairs(A.byItem) do
    topItems[#topItems + 1] = rec
    topItemsByQuantity[#topItemsByQuantity + 1] = rec
    if rec.movesIn > 0 then
      topItemsIn[#topItemsIn + 1] = rec
      topItemsByQuantityIn[#topItemsByQuantityIn + 1] = rec
    end
    if rec.movesOut > 0 then
      topItemsOut[#topItemsOut + 1] = rec
      topItemsByQuantityOut[#topItemsByQuantityOut + 1] = rec
    end
  end
  table.sort(topItems, function(a, b)
    if a.moves ~= b.moves then return a.moves > b.moves end
    if a.quantity ~= b.quantity then return a.quantity > b.quantity end
    return (a.itemID or 0) < (b.itemID or 0)
  end)
  table.sort(topItemsByQuantity, byField("quantity"))
  table.sort(topItemsIn, byField("movesIn"))
  table.sort(topItemsOut, byField("movesOut"))
  table.sort(topItemsByQuantityIn, byField("qtyIn"))
  table.sort(topItemsByQuantityOut, byField("qtyOut"))
  return topItems, topItemsByQuantity, topItemsIn, topItemsOut,
         topItemsByQuantityIn, topItemsByQuantityOut
end

-- Where the banking actually happens, ranked three ways. Ties break on the zone name.
local function deriveTopZones(A)
  local topZones, topZonesIn, topZonesOut = {}, {}, {}
  for zone, count in pairs(A.byZone) do
    local m = A.zoneByDirection[zone] or {}
    local rec = { zone = zone, count = count,
                  inCount = m.DEPOSIT or 0, outCount = m.WITHDRAW or 0 }
    topZones[#topZones + 1] = rec
    if rec.inCount > 0 then topZonesIn[#topZonesIn + 1] = rec end
    if rec.outCount > 0 then topZonesOut[#topZonesOut + 1] = rec end
  end
  local function byZoneField(field)
    return function(a, b)
      if a[field] ~= b[field] then return a[field] > b[field] end
      return a.zone < b.zone
    end
  end
  table.sort(topZones, byZoneField("count"))
  table.sort(topZonesIn, byZoneField("inCount"))
  table.sort(topZonesOut, byZoneField("outCount"))
  return topZones, topZonesIn, topZonesOut
end

-- Type + sub-type pairs, ranked three ways. Ties break on the display label.
local function deriveTopTypeSub(A)
  local topTypeSub, topTypeSubIn, topTypeSubOut = {}, {}, {}
  for _, rec in pairs(A.byTypeSub) do
    topTypeSub[#topTypeSub + 1] = rec
    if rec.inCount > 0 then topTypeSubIn[#topTypeSubIn + 1] = rec end
    if rec.outCount > 0 then topTypeSubOut[#topTypeSubOut + 1] = rec end
  end
  local function byTSField(field)
    return function(a, b)
      if a[field] ~= b[field] then return a[field] > b[field] end
      return a.label < b.label
    end
  end
  table.sort(topTypeSub, byTSField("count"))
  table.sort(topTypeSubIn, byTSField("inCount"))
  table.sort(topTypeSubOut, byTSField("outCount"))
  return topTypeSub, topTypeSubIn, topTypeSubOut
end

-- Three ranked item lists per store — all, deposits, withdrawals — off the per-store index, so a
-- store gets the same All/Deposits/Withdrawals treatment the global lists have. Names and
-- qualities come from the shared byItem records, so a store list can never disagree with the
-- global one about an item. As with the global rankings, the three arrays hold the SAME
-- record tables.
local function deriveTopItemsByStore(A)
  local byStoreAll, byStoreIn, byStoreOut = {}, {}, {}
  for store, ids in pairs(A.itemsByStore) do
    local all, into, outOf = {}, {}, {}
    for id, sRec in pairs(ids) do
      local rec = A.byItem[id]
      local out = { itemID = id, itemName = rec and rec.itemName,
                    quality = rec and rec.quality,
                    moves = sRec.moves, movesIn = sRec.movesIn, movesOut = sRec.movesOut }
      all[#all + 1] = out
      if out.movesIn > 0 then into[#into + 1] = out end
      if out.movesOut > 0 then outOf[#outOf + 1] = out end
    end
    table.sort(all, byField("moves"))
    table.sort(into, byField("movesIn"))
    table.sort(outOf, byField("movesOut"))
    byStoreAll[store] = all
    byStoreIn[store] = into
    byStoreOut[store] = outOf
  end
  return byStoreAll, byStoreIn, byStoreOut
end

local function deriveDays(A)
  local activeDays, busiestDay = 0, nil
  for day, count in pairs(A.byDay) do
    activeDays = activeDays + 1
    if not busiestDay or count > busiestDay.count then busiestDay = { day = day, count = count } end
  end
  return activeDays, busiestDay
end

-- The store with the most movements, for the "top store" card. Ties break on the store key so
-- the card cannot flicker between two equally-busy stores across refreshes.
local function deriveTopStore(A)
  local topStore
  for store, count in pairs(A.byStore) do
    if not topStore or count > topStore.count
      or (count == topStore.count and store < topStore.store) then
      topStore = { store = store, count = count }
    end
  end
  return topStore
end

-- Aggregate the (optionally filtered) ledger in one O(n) pass. Returns count maps,
-- per-store/character/day breakdowns, a pre-sorted top-items list, and the totals the Insights
-- widgets consume. Value is not derived or reported (schema v2). "Net" per store is a MOVEMENT
-- count — deposits add, withdrawals subtract — so a store's net flow reads as "did you put more in
-- than you took out", the only signed non-gold quantity left once vendor value is gone.
--
-- The per-entry work lives in the accumulate* helpers above and the rankings in the derive*
-- helpers; both split the loop *body* and the tail, not the single pass.
function Database:Stats(filter)
  local entries = self:Query(filter or {})
  local A = newAccumulator()

  for _, e in ipairs(entries) do
    local qty   = e.quantity or 1
    local store = e.store or "BAGS"
    local dir   = e.direction or "DEPOSIT"

    accumulateCore(A, e, store, dir)
    if e.kind == "MONEY" then
      accumulateMoney(A, store, dir, qty)
    else
      accumulateItem(A, e, store, dir, qty)
    end
    accumulateTime(A, e, qty)
    accumulateChar(A, e, store, dir)
  end

  local topItems, topItemsByQuantity, topItemsIn, topItemsOut,
        topItemsByQuantityIn, topItemsByQuantityOut = deriveTopItems(A)
  local topZones, topZonesIn, topZonesOut = deriveTopZones(A)
  local topTypeSub, topTypeSubIn, topTypeSubOut = deriveTopTypeSub(A)
  local topItemsByStore, topItemsByStoreIn, topItemsByStoreOut = deriveTopItemsByStore(A)
  local activeDays, busiestDay = deriveDays(A)

  return {
    byStore = A.byStore, byDirection = A.byDirection, byKind = A.byKind, byDay = A.byDay,
    byChar = A.byChar, byItem = A.byItem, byItemType = A.byItemType, topItems = topItems,
    netByStore = A.netByStore,
    charByStore = A.charByStore,
    byItemSubType = A.byItemSubType, byQuality = A.byQuality, byZone = A.byZone,
    byHour = A.byHour, byWeekday = A.byWeekday,
    moneyByDay = A.moneyByDay, moneyByStore = A.moneyByStore,
    charByDirection = A.charByDirection, storeByDirection = A.storeByDirection,
    qualityByDirection = A.qualityByDirection, itemTypeByDirection = A.itemTypeByDirection,
    itemSubTypeByDirection = A.itemSubTypeByDirection,
    topItemsByQuantity = topItemsByQuantity,
    topItemsIn = topItemsIn, topItemsOut = topItemsOut,
    topItemsByQuantityIn = topItemsByQuantityIn, topItemsByQuantityOut = topItemsByQuantityOut,
    topZones = topZones, topZonesIn = topZonesIn, topZonesOut = topZonesOut,
    topTypeSub = topTypeSub, topTypeSubIn = topTypeSubIn, topTypeSubOut = topTypeSubOut,
    topItemsByStore = topItemsByStore,
    topItemsByStoreIn = topItemsByStoreIn, topItemsByStoreOut = topItemsByStoreOut,
    totals = {
      entries = #entries, distinctItems = A.distinctItems, distinctChars = A.distinctChars,
      firstTs = A.firstTs, lastTs = A.lastTs, activeDays = activeDays, busiestDay = busiestDay,
      itemsDeposited = A.itemsDeposited, itemsWithdrawn = A.itemsWithdrawn,
      -- Net items is signed the same way netMoney is: positive means you are a net saver.
      netItems = A.itemsDeposited - A.itemsWithdrawn,
      moneyIn = A.moneyIn, moneyOut = A.moneyOut, netMoney = A.moneyIn - A.moneyOut,
      moneyMoved = A.moneyIn + A.moneyOut,
      itemsMoved = A.itemsDeposited + A.itemsWithdrawn,
      topStore = deriveTopStore(A),
    },
  }
end
