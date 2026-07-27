local addonName, NS = ...
local C = NS.Constants

-- AceDB init. Account-wide: the whole ledger + every setting live in NS.db.global.
function NS:InitDB()
  NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)
  NS:RunMigrations()   -- normalize the persisted schema before any ledger read
end

-- Schema-migration runner (toc-file-§2 / savedvariables-§1). Reads/writes db.global.schemaVersion
-- and ships even with an effectively empty body — the *seam* is the requirement: future schema
-- changes get a single, idempotent upgrade path invoked once at init, before any read of
-- db.global.ledger. Safe no-op when the DB isn't ready yet.
function NS:RunMigrations()
  local g = NS.db and NS.db.global
  if not g then return end
  g.schemaVersion = g.schemaVersion or 1
  -- v1 -> v2: the addon no longer derives, captures or persists vendor value, so the field leaves
  -- the SavedVariables file rather than merely going unread. Idempotent: clearing an absent field
  -- is a no-op, so a partially-migrated database converges on a second run.
  if g.schemaVersion < 2 then
    local n = 0
    for _, e in ipairs(g.ledger or {}) do
      if e.vendorPrice ~= nil then e.vendorPrice = nil; n = n + 1 end
    end
    g.schemaVersion = 2
    if NS.State.debug and NS.Debug then
      NS.Debug("Migrate", "%s", NS.MigrationSummary(1, 2, n))
    end
  end
end

-- Pure migration summary for the [Migrate] debug line.
function NS.MigrationSummary(from, to, rows)
  return ("v%s -> v%s, %s rows touched"):format(tostring(from), tostring(to), tostring(rows))
end

-- Pure [Init] session summary for the SetEnabled seam (debug-logging-§5/§8): addon name + version,
-- schema version, active profile, and entry count — e.g.
-- "BankLedger v0.1.0, schema v1, profile 'Default', 412 entries".
-- Guarded so it can't error before the DB is ready. All values are plain constants/counts, so a raw
-- tostring is secret-safe here.
function NS.InitSummary()
  local g = NS.db and NS.db.global
  local schema = (g and g.schemaVersion) or 0
  local profile = (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?"
  local entries = (g and g.ledger and #g.ledger) or 0
  return ("%s v%s, schema v%s, profile '%s', %s entries"):format(
    tostring(NS.name), tostring(NS.version), tostring(schema), tostring(profile), tostring(entries))
end

NS.Database = NS.Database or {}
local Database = NS.Database

function Database:Ledger()
  return NS.db.global.ledger
end

-- The dataset every read-path query (Query/Stats/Export, and therefore the table + Insights)
-- resolves against: the synthetic preview dataset while `/bl preview` is on, otherwise the live
-- account-wide ledger.
function Database:ActiveLedger()
  return (NS.State and NS.State.testRecords) or NS.db.global.ledger
end

function Database:Count()
  return #NS.db.global.ledger
end

-- Append an entry to the account-wide ledger; fire EntryAdded; return its index.
function Database:Add(entry)
  local ledger = NS.db.global.ledger
  ledger[#ledger + 1] = entry
  local index = #ledger
  if NS.bus then
    NS.bus:SendMessage("Ka0s_BankLedger_EntryAdded", entry, index)
  end
  return index
end

-- Filter an arbitrary entry array by the filter spec. Every field is optional and AND-combined.
-- kind/direction/store/char/itemType/itemSubType each accept a scalar (equality) OR a set table
-- (membership, for the browser's multi-select filters); quality accepts a number (exact) or a set.
-- itemType/itemSubType match the entry's EFFECTIVE type — a gold movement's is "Gold".
--   kind · direction · store · char · itemType · itemSubType · quality · from/to (ts, inclusive) ·
--   text (case-insensitive substring on itemName)
-- An empty/nil filter returns everything. Kept generic (not tied to the live ledger) so the browser
-- can filter its preview dataset through exactly the same code.
function Database:QueryList(entries, filter)
  filter = filter or {}
  local qIsSet = type(filter.quality) == "table"
  local qExact = type(filter.quality) == "number" and filter.quality or nil
  local from, to = filter.from, filter.to
  local text = filter.text and filter.text:lower() or nil

  -- Scalar-or-set membership test shared by every set-capable field.
  local function matches(spec, value)
    if spec == nil then return true end
    if type(spec) == "table" then return spec[value] == true end
    return spec == value
  end

  local out = {}
  for _, e in ipairs(entries) do
    local ok = matches(filter.kind, e.kind)
      and matches(filter.direction, e.direction)
      and matches(filter.store, e.store)
      and matches(filter.char, e.char)
      -- Matched on the EFFECTIVE type (NS.Util.EntryType), so "Gold" filters gold movements — the
      -- same value the Type column shows for them. Item rows are unaffected.
      and matches(filter.itemType, NS.Util.EntryType(e))
      and matches(filter.itemSubType, NS.Util.EntrySubType(e))
    if ok and qIsSet then
      if not filter.quality[e.quality] then ok = false end
    elseif ok and qExact and (e.quality or 0) ~= qExact then
      ok = false
    end
    if ok and from and (e.ts or 0) < from then ok = false end
    if ok and to and (e.ts or 0) > to then ok = false end
    if ok and text then
      local name = e.itemName and e.itemName:lower() or ""
      if not name:find(text, 1, true) then ok = false end
    end
    if ok then out[#out + 1] = e end
  end
  return out
end

-- Query the active dataset (live ledger, or the preview dataset while preview mode is on).
function Database:Query(filter)
  return self:QueryList(self:ActiveLedger(), filter)
end

-- Plain, metatable-free copy of the (optionally filtered) ledger — the forward-compatible export
-- contract (see docs/data-model.md). The field shape is stable except across schema bumps.
function Database:Export(filter)
  local out = {}
  for _, e in ipairs(self:Query(filter or {})) do
    out[#out + 1] = {
      ts = e.ts, char = e.char, classFile = e.classFile,
      kind = e.kind, direction = e.direction, store = e.store, guild = e.guild,
      itemID = e.itemID, itemLink = e.itemLink, itemName = e.itemName, quality = e.quality,
      itemType = e.itemType, itemSubType = e.itemSubType,
      quantity = e.quantity, zone = e.zone, mapID = e.mapID, subzone = e.subzone,
    }
  end
  return out
end

-- Aggregate the (optionally filtered) ledger in one O(n) pass. Returns count maps,
-- per-store/character/day breakdowns, a pre-sorted top-items list, and the totals the Insights
-- widgets consume. Value is not derived or reported (schema v2). "Net" per store is a MOVEMENT
-- count — deposits add, withdrawals subtract — so a store's net flow reads as "did you put more in
-- than you took out", the only signed non-gold quantity left once vendor value is gone.
function Database:Stats(filter)
  local entries = self:Query(filter or {})
  local byStore, byDirection, byKind, byDay, byChar, byItem, byItemType = {}, {}, {}, {}, {}, {}, {}
  local netByStore = {}
  local charByStore = {}
  local distinctItems, distinctChars = 0, 0
  local firstTs, lastTs
  local itemsDeposited, itemsWithdrawn = 0, 0
  local moneyIn, moneyOut = 0, 0
  -- The second wave of breakdowns, added for the expanded Insights panel. Every one is a plain
  -- extra accumulator in the SAME single pass — the panel got richer without the aggregation
  -- getting slower, and no existing key changed name or meaning.
  local byItemSubType, byQuality, byZone = {}, {}, {}
  local byHour, byWeekday = {}, {}
  local moneyByDay, moneyByStore = {}, {}
  local charByDirection, storeByDirection = {}, {}

  -- Nested-table increment used by the per-character × store matrix.
  local function bump(matrix, k1, k2, amt)
    if k1 == nil or k2 == nil then return end
    local m = matrix[k1]; if not m then m = {}; matrix[k1] = m end
    m[k2] = (m[k2] or 0) + amt
  end

  for _, e in ipairs(entries) do
    local qty = e.quantity or 1
    local store = e.store or "BAGS"
    local dir = e.direction or "DEPOSIT"

    byStore[store] = (byStore[store] or 0) + 1
    byDirection[dir] = (byDirection[dir] or 0) + 1
    byKind[e.kind or "ITEM"] = (byKind[e.kind or "ITEM"] or 0) + 1
    -- Net flow per store, counted in MOVEMENTS: +1 for a deposit, -1 for a withdrawal. The only
    -- signed non-gold quantity the addon keeps now that vendor value is gone (schema v2).
    netByStore[store] = (netByStore[store] or 0) + (C.DirectionSign[dir] or 1)

    bump(storeByDirection, store, dir, 1)
    if e.zone and e.zone ~= "" then byZone[e.zone] = (byZone[e.zone] or 0) + 1 end

    if e.kind == "MONEY" then
      if dir == "DEPOSIT" then moneyIn = moneyIn + qty else moneyOut = moneyOut + qty end
      moneyByStore[store] = (moneyByStore[store] or 0) + qty
    else
      if dir == "DEPOSIT" then itemsDeposited = itemsDeposited + qty
      else itemsWithdrawn = itemsWithdrawn + qty end
      local ty = e.itemType
      if ty and ty ~= "" then byItemType[ty] = (byItemType[ty] or 0) + 1 end
      local sty = e.itemSubType
      if sty and sty ~= "" then byItemSubType[sty] = (byItemSubType[sty] or 0) + 1 end
      -- Quality is an item question by definition: a gold movement has none, and bucketing it under
      -- Poor would invent a fact. Keyed on the numeric id so the chart can sort Poor→Legendary.
      if type(e.quality) == "number" then
        byQuality[e.quality] = (byQuality[e.quality] or 0) + 1
      end
      local id = e.itemID
      if id ~= nil then
        local rec = byItem[id]
        if rec then
          rec.moves = rec.moves + 1
          rec.quantity = rec.quantity + qty
        else
          byItem[id] = { itemID = id, itemName = e.itemName, quality = e.quality,
                         moves = 1, quantity = qty }
          distinctItems = distinctItems + 1
        end
      end
    end

    if e.ts then
      local day = date("%Y-%m-%d", e.ts)
      byDay[day] = (byDay[day] or 0) + 1
      if e.kind == "MONEY" then moneyByDay[day] = (moneyByDay[day] or 0) + qty end
      if not firstTs or e.ts < firstTs then firstTs = e.ts end
      if not lastTs or e.ts > lastTs then lastTs = e.ts end
      -- Hour-of-day and weekday, for the "when do I actually visit the bank" strips. `wday` is
      -- 1-based with Sunday = 1; normalized to 0..6 so it indexes a plain weekday-label array.
      local t = date("*t", e.ts)
      if t then
        byHour[t.hour] = (byHour[t.hour] or 0) + 1
        local wd = (t.wday or 1) - 1
        byWeekday[wd] = (byWeekday[wd] or 0) + 1
      end
    end

    local ch = e.char
    if ch then
      bump(charByDirection, ch, dir, 1)
      local ce = byChar[ch]
      if not ce then
        ce = { char = ch, classFile = e.classFile, count = 0 }
        byChar[ch] = ce
        distinctChars = distinctChars + 1
      end
      ce.count = ce.count + 1
      bump(charByStore, ch, store, 1)
    end
  end

  -- Top items, ranked two ways off the one byItem index. Each list is a fresh array of the SAME
  -- record tables (never a copy), so the rankings cost two sorts and no extra memory. Every
  -- comparator ends on the item id, so a tie can never reorder run to run.
  local topItems, topItemsByQuantity = {}, {}
  for _, rec in pairs(byItem) do
    topItems[#topItems + 1] = rec
    topItemsByQuantity[#topItemsByQuantity + 1] = rec
  end
  table.sort(topItems, function(a, b)
    if a.moves ~= b.moves then return a.moves > b.moves end
    if a.quantity ~= b.quantity then return a.quantity > b.quantity end
    return (a.itemID or 0) < (b.itemID or 0)
  end)
  table.sort(topItemsByQuantity, function(a, b)
    if a.quantity ~= b.quantity then return a.quantity > b.quantity end
    return (a.itemID or 0) < (b.itemID or 0)
  end)

  -- Where the banking actually happens, ranked. Ties break on the zone name.
  local topZones = {}
  for zone, count in pairs(byZone) do topZones[#topZones + 1] = { zone = zone, count = count } end
  table.sort(topZones, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.zone < b.zone
  end)

  local activeDays, busiestDay = 0, nil
  for day, count in pairs(byDay) do
    activeDays = activeDays + 1
    if not busiestDay or count > busiestDay.count then busiestDay = { day = day, count = count } end
  end

  -- The store with the most movements, for the "top store" card. Ties break on the store key so
  -- the card cannot flicker between two equally-busy stores across refreshes.
  local topStore
  for store, count in pairs(byStore) do
    if not topStore or count > topStore.count
      or (count == topStore.count and store < topStore.store) then
      topStore = { store = store, count = count }
    end
  end

  return {
    byStore = byStore, byDirection = byDirection, byKind = byKind, byDay = byDay,
    byChar = byChar, byItem = byItem, byItemType = byItemType, topItems = topItems,
    netByStore = netByStore,
    charByStore = charByStore,
    byItemSubType = byItemSubType, byQuality = byQuality, byZone = byZone,
    byHour = byHour, byWeekday = byWeekday,
    moneyByDay = moneyByDay, moneyByStore = moneyByStore,
    charByDirection = charByDirection, storeByDirection = storeByDirection,
    topItemsByQuantity = topItemsByQuantity,
    topZones = topZones,
    totals = {
      entries = #entries, distinctItems = distinctItems, distinctChars = distinctChars,
      firstTs = firstTs, lastTs = lastTs, activeDays = activeDays, busiestDay = busiestDay,
      itemsDeposited = itemsDeposited, itemsWithdrawn = itemsWithdrawn,
      -- Net items is signed the same way netMoney is: positive means you are a net saver.
      netItems = itemsDeposited - itemsWithdrawn,
      moneyIn = moneyIn, moneyOut = moneyOut, netMoney = moneyIn - moneyOut,
      moneyMoved = moneyIn + moneyOut,
      itemsMoved = itemsDeposited + itemsWithdrawn,
      topStore = topStore,
    },
  }
end

local function fireLedgerChanged()
  if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_LedgerChanged") end
end

-- Public LedgerChanged emitter for non-Database owners of a visible-ledger change (NS.Filters calls
-- it after mutating db.global). Keeps Database the single sending module for this message
-- (architecture-§4's one-sender-per-message invariant).
function Database:FireLedgerChanged()
  fireLedgerChanged()
end

-- Delete a single entry by index (from the table's right-click menu). Compacts the array.
function Database:DeleteAt(index)
  local ledger = NS.db.global.ledger
  if type(index) ~= "number" or index < 1 or index > #ledger then return false end
  local ts = ledger[index] and ledger[index].ts
  table.remove(ledger, index)
  fireLedgerChanged()
  if NS.State.debug and NS.Debug then
    NS.Debug("Data", "deleted entry @%s", tostring(ts))
  end
  return true
end

-- Delete every entry for which pred(entry) is true. Rebuild-and-swap (no array holes).
-- Returns the number removed; fires LedgerChanged.
function Database:Delete(pred)
  local ledger = NS.db.global.ledger
  local kept, removed = {}, 0
  for _, e in ipairs(ledger) do
    if pred(e) then removed = removed + 1 else kept[#kept + 1] = e end
  end
  NS.db.global.ledger = kept
  fireLedgerChanged()
  return removed
end

-- Wipe the whole ledger (`/bl purge`). Returns the count removed.
function Database:Purge()
  local removed = #NS.db.global.ledger
  NS.db.global.ledger = {}
  fireLedgerChanged()
  if NS.State.debug and NS.Debug then
    NS.Debug("Data", "purge-all removed %s entries", tostring(removed))
  end
  return removed
end

-- Rough per-entry byte cost as written to the SavedVariables .lua file. WoW gives addons no way to
-- read the real on-disk file size, so this estimates: a fixed overhead covering key names, table
-- syntax and numeric fields, plus the length of each string field.
local ENTRY_OVERHEAD = 192
local function estimateEntryBytes(e)
  local n = ENTRY_OVERHEAD
  local strFields = { e.itemLink, e.itemName, e.zone, e.subzone, e.char, e.itemType,
                      e.itemSubType, e.guild }
  for _, s in ipairs(strFields) do
    if type(s) == "string" then n = n + #s end
  end
  return n
end

-- Storage summary for the settings panel: entry count, span in days since the earliest entry, and
-- an ESTIMATED SavedVariables byte size. `now` is injectable for tests; it defaults to time().
function Database:StorageStats(now)
  local ledger = NS.db.global.ledger
  local firstTs, bytes = nil, 0
  for _, e in ipairs(ledger) do
    if e.ts and (not firstTs or e.ts < firstTs) then firstTs = e.ts end
    bytes = bytes + estimateEntryBytes(e)
  end
  local days = 0
  if firstTs then
    now = now or time()
    days = math.max(1, math.ceil((now - firstTs) / 86400))
  end
  return { count = #ledger, days = days, bytes = bytes }
end

-- Retention cleanup. Drops entries older than settings.retentionDays (0 == Always). Rebuild-and-swap
-- avoids O(n^2) shifting and array holes. Fires LedgerChanged when it actually runs.
function Database:PruneOld()
  local days = NS.db.global.settings.retentionDays
  if not days or days == 0 then return 0 end
  local cutoff = time() - days * 86400
  local ledger = NS.db.global.ledger
  local kept = {}
  for _, e in ipairs(ledger) do
    if (e.ts or 0) >= cutoff then kept[#kept + 1] = e end
  end
  local removed = #ledger - #kept
  NS.db.global.ledger = kept
  fireLedgerChanged()
  if NS.State.debug and NS.Debug then
    NS.Debug("Prune", "retention %sd: removed %s entries", tostring(days), tostring(removed))
  end
  return removed
end
