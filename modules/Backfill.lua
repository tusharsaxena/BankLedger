local _, NS = ...
NS.Backfill = NS.Backfill or {}
local Backfill = NS.Backfill
local C = NS.Constants

-- THE LOGIN BACKFILL (BankLedger#2). An item the client had not cached when it moved is stored with
-- its id alone (L:BuildEntry, modules/Ledger.lua): the table shows "Item <id>" and the Insights
-- Type / Sub-type / Quality breakdowns never count it. Once per login, right after the retention
-- prune (addon:OnEnterWorld, core/BankLedger.lua), this pass asks the client about those ids and
-- fills the rows in.
--
-- Not a migration step: NS.MIGRATIONS runs synchronously at init and is stamped once, item loading
-- is asynchronous, and new uncached rows keep arriving after the schema is current. So it is a
-- bounded repair pass that runs on every login, with three guards because it writes SavedVariables:
--
--   * NIL FIELDS ONLY. A present name, quality, type, sub-type or link is never overwritten, so a
--     second pass is a no-op and a row a player already sees never changes under them.
--   * C.BACKFILL_MAX_IDS distinct ids per login; a large legacy ledger drains over several logins.
--   * ONE LedgerChanged for the whole pass, and only when a row changed, never one per id.
--
-- GET_ITEM_INFO_RECEIVED is registered on the addon object only while the pass waits, so
-- NS.StandDown's UnregisterAllEvents and CancelAllTimers reach it, and its CancelPending walk
-- (TIMER_MODULES) drops the pass's own state. Every handler also checks the latch as a belt.

local EVENT = "GET_ITEM_INFO_RECEIVED"

local function stoodDown() return NS.IsStoodDown and NS.IsStoodDown() end

local function debugOn() return NS.State and NS.State.debug and NS.Debug end

local function needsFill(row)
  return type(row) == "table" and row.kind == C.Kind.ITEM and row.itemID ~= nil
    and (row.itemName == nil or row.itemType == nil)
end

--- Pure. The distinct item ids, in ledger order, of rows still missing a name or a type -- at most
--- `cap` of them -- and a map from each listed id to its rows. One walk, no API call. Rows are held
--- by reference rather than by index, so a prune or a delete while the pass waits cannot point an
--- answer at the wrong row.
function Backfill.Collect(ledger, cap)
  local ids, rowsById = {}, {}
  for i = 1, #ledger do
    local row = ledger[i]
    if needsFill(row) then
      local rows = rowsById[row.itemID]
      if rows then
        rows[#rows + 1] = row
      elseif #ids < cap then
        ids[#ids + 1] = row.itemID
        rowsById[row.itemID] = { row }
      end
    end
  end
  return ids, rowsById
end

local FIELDS = { "itemName", "quality", "itemType", "itemSubType", "itemLink" }

--- Pure. Fill each row's nil fields from the resolved details; never overwrite, never add or remove
--- a row. Answers how many rows changed, so a second call answers 0.
function Backfill.Apply(rows, name, quality, itemType, itemSubType, link)
  local values = { name, quality, itemType, itemSubType, link }
  local changed = 0
  for _, row in ipairs(rows) do
    local touched = false
    for k, field in ipairs(FIELDS) do
      if row[field] == nil and values[k] ~= nil then
        row[field] = values[k]
        touched = true
      end
    end
    if touched then changed = changed + 1 end
  end
  return changed
end

-- Resolve one id's rows, each through its own stored link first and the id otherwise, as
-- L:BuildEntry enriches: the id alone answers with the base item, so a bonus-upgraded drop would
-- read back at its base quality. Answers the rows filled and whether every row resolved.
local function fillRows(rows, id)
  local filled, resolved = 0, true
  for _, row in ipairs(rows) do
    local name, quality, itemType, itemSubType, link = NS.Compat.GetItemDetails(row.itemLink or id)
    if name then
      filled = filled + Backfill.Apply({ row }, name, quality, itemType, itemSubType, link)
    else
      resolved = false
    end
  end
  return filled, resolved
end

-- The record /bl debug scan reads names what is bound now, and the pass's event is not, once it ends.
local function forgetEvent()
  local list = NS.EventRecord and NS.EventRecord.registered
  if not list then return end
  for i = #list, 1, -1 do
    if list[i] == EVENT then table.remove(list, i) end
  end
end

-- Let go of the event and the timeout, and drop the pass. Writes nothing.
local function release()
  local ad = NS.addon
  local p = Backfill.pass
  Backfill.pass = nil
  if not p then return end
  if ad and ad.UnregisterEvent then ad:UnregisterEvent(EVENT) end
  if p.timer and ad and ad.CancelTimer then ad:CancelTimer(p.timer) end
  forgetEvent()
end

local function finish(filled, unresolved)
  if filled > 0 and not stoodDown() and NS.Database then NS.Database:FireLedgerChanged() end
  if debugOn() then
    NS.Debug("Backfill", "done: %d rows filled, %d unresolved", filled, unresolved)
  end
end

-- The timeout: whatever is still pending stays unresolved, for the next login.
local function onTimeout()
  local p = Backfill.pass
  if not p then return end
  release()
  if stoodDown() then return end
  finish(p.filled, p.unresolved + p.left)
end

local function onItemInfo(_, itemID, success)
  local p = Backfill.pass
  if not p or stoodDown() then return end
  local rows = p.waiting[itemID]
  if not rows then return end
  p.waiting[itemID] = nil
  p.left = p.left - 1
  local resolved = false
  if success ~= false then
    local filled
    filled, resolved = fillRows(rows, itemID)
    p.filled = p.filled + filled
  end
  if not resolved then p.unresolved = p.unresolved + 1 end
  if p.left > 0 then return end
  release()
  finish(p.filled, p.unresolved)
end

-- Fill what the client already knows, and ask it about the rest. Answers the rows filled, the ids
-- still waiting (id -> rows) and how many there are.
local function firstPass(ids, rowsById)
  local filled, waiting, requested = 0, {}, 0
  for _, id in ipairs(ids) do
    local n, resolved = fillRows(rowsById[id], id)
    filled = filled + n
    if not resolved then
      waiting[id] = rowsById[id]
      requested = requested + 1
      NS.Item.LoadItem(id)
    end
  end
  return filled, waiting, requested
end

--- The login pass. Fills synchronously what is cached; registers GET_ITEM_INFO_RECEIVED for the rest
--- until every id has answered or C.BACKFILL_TIMEOUT seconds pass. A ledger with nothing to fill
--- writes no line (debug-logging-§9).
function Backfill:Run()
  if self.pass or stoodDown() then return end
  local ledger = NS.db and NS.db.global and NS.db.global.ledger
  if type(ledger) ~= "table" then return end
  local ids, rowsById = Backfill.Collect(ledger, C.BACKFILL_MAX_IDS)
  if #ids == 0 then return end
  local filled, waiting, requested = firstPass(ids, rowsById)
  if debugOn() then
    NS.Debug("Backfill", "%d rows over %d ids filled now, %d requested", filled, #ids, requested)
  end
  local ad = NS.addon
  if requested == 0 or not (ad and ad.ScheduleTimer) then
    return finish(filled, requested)
  end
  self.pass = { waiting = waiting, left = requested, filled = filled, unresolved = 0 }
  NS.RegisterEventSafely(ad, EVENT, onItemInfo)
  self.pass.timer = ad:ScheduleTimer(onTimeout, C.BACKFILL_TIMEOUT)
end

--- NS.StandDown's TIMER_MODULES walk: drop the pass with no write and no message. Dot-defined
--- because it reads no instance state; the walk calls it with a colon, which passes one ignored arg.
function Backfill.CancelPending()
  release()
end
