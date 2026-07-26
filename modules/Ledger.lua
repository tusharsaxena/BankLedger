local addonName, NS = ...   -- luacheck: ignore addonName
NS.Ledger = NS.Ledger or {}
local L = NS.Ledger
local C = NS.Constants

-- The capture engine: a snapshot differ.
--
-- WoW fires no "you deposited this" event, so a bank movement has to be *derived*. While a store's
-- UI is open the addon holds a snapshot of the player's bags + that store's contents; every time the
-- client says something changed it takes a fresh snapshot and diffs the two. An item that left the
-- bags AND arrived in the store is a deposit; the reverse is a withdrawal. Anything that moved on
-- only one side (loot landing in your bags, a stack destroyed) is deliberately NOT a movement.
--
-- Diff is pure — two snapshots in, movements out — which is what makes the whole feature testable
-- headlessly (tests/test_ledger.lua). Everything else in this file is the event shell around it.

-- Stores that actually hold gold. A character-bank money delta came from something else entirely
-- (a vendor sale, a quest turn-in that happened to land while the window was open), so logging it
-- as a deposit would be a lie. Guild and Warband banks are the only stores with a money slot.
L.MONEY_STORES = { GUILD_BANK = true, WARBAND_BANK = true }

-- Hot-path upvalues, re-cached whenever the settings or the filter lists change
-- (events-frames-taint-§7). The capture gate runs once per moved item, so it must not walk AceDB.
local DB_ENABLED, DB_TRACK_ITEMS, DB_TRACK_MONEY = true, true, true
local DB_QUALITY, DB_EXCLUDED = 0, {}
local DB_BLACKLIST, DB_WHITELIST = {}, {}

function L:RefreshUpvalues()
  local s = (NS.db and NS.db.global and NS.db.global.settings) or {}
  DB_ENABLED      = s.enabled ~= false
  DB_TRACK_ITEMS  = s.trackItems ~= false
  DB_TRACK_MONEY  = s.trackMoney ~= false
  DB_QUALITY      = s.qualityThreshold or 0
  DB_EXCLUDED     = s.excludedStores or {}
  DB_BLACKLIST    = (NS.Filters and NS.Filters:Blacklist()) or {}
  DB_WHITELIST    = (NS.Filters and NS.Filters:Whitelist()) or {}
end

-- ── Pure diff ───────────────────────────────────────────────────────────────────

-- Compare two snapshots and return the movements between the bags and `store`.
--
-- A snapshot is { bags = { [itemID] = count }, store = { [itemID] = count }, money = <copper> }.
-- Each movement is { kind, direction, store, itemID, quantity } — no item names, no timestamps:
-- enrichment is BuildEntry's job, so this stays pure and cheap.
--
-- Item movements come back in ascending itemID order and the money movement (if any) last, so the
-- output is deterministic run to run — which is what lets the tests assert on it by index.
function L.Diff(before, after, store)
  local moves = {}
  before = before or {}
  after = after or {}
  local bagsBefore, bagsAfter = before.bags or {}, after.bags or {}
  local storeBefore, storeAfter = before.store or {}, after.store or {}

  -- Every id that appears on either side of either snapshot.
  local ids, seen = {}, {}
  for _, map in ipairs({ bagsBefore, bagsAfter, storeBefore, storeAfter }) do
    for id in pairs(map) do
      if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
  end
  table.sort(ids)

  for _, id in ipairs(ids) do
    local bagDelta   = (bagsAfter[id] or 0) - (bagsBefore[id] or 0)
    local storeDelta = (storeAfter[id] or 0) - (storeBefore[id] or 0)
    -- A movement needs BOTH sides to have changed, in opposite directions. The quantity is the
    -- smaller of the two: if 5 left the bags but only 3 landed, only 3 actually moved.
    if storeDelta > 0 and bagDelta < 0 then
      moves[#moves + 1] = { kind = C.Kind.ITEM, direction = C.Direction.DEPOSIT, store = store,
                            itemID = id, quantity = math.min(storeDelta, -bagDelta) }
    elseif storeDelta < 0 and bagDelta > 0 then
      moves[#moves + 1] = { kind = C.Kind.ITEM, direction = C.Direction.WITHDRAW, store = store,
                            itemID = id, quantity = math.min(-storeDelta, bagDelta) }
    end
  end

  -- Gold, at the stores that hold it. The player's balance FALLING is a deposit into the store.
  if L.MONEY_STORES[store] then
    local delta = (after.money or 0) - (before.money or 0)
    if delta < 0 then
      moves[#moves + 1] = { kind = C.Kind.MONEY, direction = C.Direction.DEPOSIT, store = store,
                            quantity = -delta }
    elseif delta > 0 then
      moves[#moves + 1] = { kind = C.Kind.MONEY, direction = C.Direction.WITHDRAW, store = store,
                            quantity = delta }
    end
  end

  return moves
end

-- One-line render summary for the [Move] trace: a bag scan touches dozens of slots, so the sink
-- emits ONE summary per pass carrying the counts, never a line per item (debug-logging-§9).
function L.MoveSummary(store, recorded, skipped)
  return ("%s: recorded %s, skipped %s"):format(
    tostring(store), tostring(recorded), tostring(skipped))
end

-- ── Snapshot scanning ───────────────────────────────────────────────────────────

-- Total count of each itemID across every container id belonging to `store`. Stores with their own
-- API family (guild bank, void storage) are scanned through their Compat readers instead.
function L:ScanStore(store)
  local counts = {}
  if store == C.Store.GUILD_BANK then return self:ScanGuildBank() end
  if store == C.Store.VOID_STORAGE then return self:ScanVoidStorage() end
  for _, bagID in ipairs(C.STORE_CONTAINERS[store] or {}) do
    local slots = NS.Compat.GetContainerNumSlots(bagID)
    for slot = 1, slots do
      local info = NS.Compat.GetContainerSlot(bagID, slot)
      if info then
        counts[info.itemID] = (counts[info.itemID] or 0) + (info.count or 1)
      end
    end
  end
  return counts
end

function L:ScanGuildBank()
  local counts = {}
  local tabSize = NS.Compat.GuildBankTabSize()
  for tab = 1, NS.Compat.GetNumGuildBankTabs() do
    for slot = 1, tabSize do
      local info = NS.Compat.GetGuildBankSlot(tab, slot)
      if info then
        counts[info.itemID] = (counts[info.itemID] or 0) + (info.count or 1)
      end
    end
  end
  return counts
end

-- Void storage is two pages of 80 single-item slots.
local VOID_PAGES, VOID_SLOTS = 2, 80
function L:ScanVoidStorage()
  local counts = {}
  for page = 1, VOID_PAGES do
    for slot = 1, VOID_SLOTS do
      local info = NS.Compat.GetVoidStorageSlot(page, slot)
      if info then
        counts[info.itemID] = (counts[info.itemID] or 0) + 1
      end
    end
  end
  return counts
end

-- Full snapshot: the bags, the open store, and the money balance, as one comparable value.
function L:Snapshot(store)
  return {
    bags = self:ScanStore(C.Store.BAGS),
    store = self:ScanStore(store),
    money = NS.Compat.GetMoney(),
  }
end

-- ── Capture gate ────────────────────────────────────────────────────────────────

-- Why a movement was NOT recorded, or nil when it passes. Returning a *reason* rather than a
-- boolean is deliberate: the debug console logs the skips too, so a missing ledger row can be
-- explained without guessing (debug-logging-§8).
function L:GateReason(move)
  if not DB_ENABLED then return "disabled" end
  if move.kind == C.Kind.MONEY then
    if not DB_TRACK_MONEY then return "kind" end
  elseif not DB_TRACK_ITEMS then
    return "kind"
  end
  if DB_EXCLUDED[move.store] then return "store" end
  if move.kind == C.Kind.ITEM then
    local id = move.itemID
    if id and DB_BLACKLIST[id] then return "blacklist" end
    if id and DB_WHITELIST[id] then return nil end   -- whitelist bypasses the quality gate
    local _, quality = NS.Compat.ItemNameQuality(id)
    if quality ~= nil and quality < DB_QUALITY then return "quality" end
  end
  return nil
end

-- ── Entry construction ──────────────────────────────────────────────────────────

-- Turn a movement into a stored ledger entry: stamp who/where/when and, for an item, whatever the
-- client has cached about it. An item the client hasn't cached yet stores its id alone — the table
-- shows "Item <id>" and a later session fills in the name.
function L:BuildEntry(move)
  local zone, subzone = NS.Compat.GetZone()
  local _, classFile = UnitClass("player")
  local entry = {
    ts = time(),
    char = NS.Util.PlayerKey(),
    classFile = classFile,
    kind = move.kind,
    direction = move.direction,
    store = move.store,
    quantity = move.quantity,
    zone = zone ~= "" and zone or nil,
    subzone = subzone ~= "" and subzone or nil,
    mapID = NS.Compat.GetPlayerMapID(),
  }

  if move.store == C.Store.GUILD_BANK then
    entry.guild = NS.Compat.GetGuildName()
  end

  if move.kind == C.Kind.MONEY then
    -- A money row has no item, but the table and the filters read `itemName`, so give gold a name.
    entry.itemName = "Gold"
    return entry
  end

  entry.itemID = move.itemID
  local name, quality, itemType, itemSubType, vendorPrice, link =
    NS.Compat.GetItemDetails(move.itemID)
  entry.itemName = name
  entry.quality = quality
  entry.itemType = itemType
  entry.itemSubType = itemSubType
  entry.vendorPrice = vendorPrice
  entry.itemLink = link
  return entry
end

-- Gate, build, store. Returns the new entry's index, or nil when the gate dropped it.
function L:Record(move)
  local reason = self:GateReason(move)
  if reason then
    if NS.State.debug and NS.Debug then
      NS.Debug("Skip", "%s %s %s (%s)", tostring(move.store), tostring(move.direction),
        tostring(move.itemID or "gold"), reason)
    end
    return nil
  end
  return NS.Database:Add(self:BuildEntry(move))
end

-- ── Event shell ─────────────────────────────────────────────────────────────────
-- A store's UI opening arms the differ (take the baseline snapshot); every change event while it is
-- open re-snapshots and records what moved; closing disarms it. Capture is entirely inert outside
-- an open store, which is what keeps a loot or a vendor purchase out of the ledger.

-- Re-snapshot against the baseline, record everything that moved, and make the new snapshot the
-- baseline. One summary debug line per pass, never one per item (debug-logging-§9).
function L:Reconcile()
  local store = NS.State.openStore
  if not store then return 0 end
  local before = NS.State.lastSnapshot
  local after = self:Snapshot(store)
  NS.State.lastSnapshot = after
  if not before then return 0 end

  local moves = L.Diff(before, after, store)
  if #moves == 0 then return 0 end

  local recorded, skipped = 0, 0
  for _, move in ipairs(moves) do
    if self:Record(move) then recorded = recorded + 1 else skipped = skipped + 1 end
  end
  if NS.State.debug and NS.Debug then
    NS.Debug("Move", "%s", L.MoveSummary(store, recorded, skipped))
  end
  return recorded
end

function L:OpenStore(store)
  NS.State.openStore = store
  NS.State.lastSnapshot = self:Snapshot(store)
  if NS.State.debug and NS.Debug then NS.Debug("Store", "%s opened", tostring(store)) end
end

function L:CloseStore()
  local store = NS.State.openStore
  if not store then return end
  self:Reconcile()   -- catch anything the last change event missed before the window closed
  NS.State.openStore = nil
  NS.State.lastSnapshot = nil
  if NS.State.debug and NS.Debug then NS.Debug("Store", "%s closed", tostring(store)) end
end

-- Which store an open-event belongs to. The character-bank frame hosts the reagent and warband tabs
-- too, so BANK is the baseline and the tab-specific events refine it.
local OPEN_EVENTS = {
  BANKFRAME_OPENED        = C.Store.BANK,
  GUILDBANKFRAME_OPENED   = C.Store.GUILD_BANK,
  VOID_STORAGE_OPEN       = C.Store.VOID_STORAGE,
}
local CLOSE_EVENTS = {
  BANKFRAME_CLOSED        = true,
  GUILDBANKFRAME_CLOSED   = true,
  VOID_STORAGE_CLOSE      = true,
}
-- Events that mean "something in an open container changed". Each is a cue to re-diff, never a
-- movement in itself.
local CHANGE_EVENTS = {
  "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED",
  "GUILDBANKBAGSLOTS_CHANGED", "VOID_STORAGE_UPDATE", "VOID_STORAGE_CONTENTS_UPDATE",
  "PLAYER_MONEY",
}

function L:Enable()
  if self._enabled then return end
  self._enabled = true
  self:RefreshUpvalues()

  local addon = NS.addon
  for event, store in pairs(OPEN_EVENTS) do
    addon:RegisterEvent(event, function() L:OpenStore(store) end)
  end
  for event in pairs(CLOSE_EVENTS) do
    addon:RegisterEvent(event, function() L:CloseStore() end)
  end
  for _, event in ipairs(CHANGE_EVENTS) do
    addon:RegisterEvent(event, function() L:Reconcile() end)
  end

  -- Re-cache the hot-path upvalues whenever a setting changes. Registered on this module's OWN
  -- AceEvent target, never the shared bus-as-self, so it can't clobber another consumer of the same
  -- message (architecture-§4).
  L.__ev = NS.NewBusTarget()
  if L.__ev then
    L.__ev:RegisterMessage("Ka0s_BankLedger_SettingsChanged", function() L:RefreshUpvalues() end)
  end
end
