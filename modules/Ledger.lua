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

-- Which stores a given open FRAME can reach.
--
-- The retail bank frame is one window with tabs — "Bank" and "Warband Bank" along the bottom, plus
-- the reagent slots — all behind a single BANKFRAME_OPENED, and switching tabs fires nothing. There
-- is therefore no event that says "the warband bank is now open", so an addon cannot track which
-- tab you are looking at. It doesn't need to: on every pass it diffs the bags against EVERY store
-- the open frame can reach, and the "both sides must change" rule sorts out which one you actually
-- used. A store you didn't touch shows no change on its side and produces no row.
L.CONTEXT_STORES = {
  [C.Context.BANK_FRAME] = { C.Store.BANK, C.Store.REAGENT_BANK, C.Store.WARBAND_BANK },
  [C.Context.GUILD_BANK] = { C.Store.GUILD_BANK },
}

-- The stores a frame can reach ON THIS CLIENT. A container-backed store whose id group came back
-- empty does not exist on this build — the reagent bank is gone on 12.0.7, its contents having
-- moved into the bank tabs — so it is dropped rather than scanned as a permanently empty store
-- that clutters every debug line with `REAGENT_BANK 0`. Stores with their own API family (the guild
-- bank) have no id group and are always reachable.
function L:StoresFor(context)
  local out = {}
  for _, store in ipairs(L.CONTEXT_STORES[context] or {}) do
    local ids = C.STORE_CONTAINERS[store]
    if ids == nil or #ids > 0 then out[#out + 1] = store end
  end
  return out
end

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

  -- Gold, at the stores that hold it — under the SAME rule as items: both sides must change, in
  -- opposite directions, and the amount is the smaller of the two.
  --
  -- The purse alone proves nothing. The retail bank frame reaches the warband bank, so a bank-tab
  -- purchase, a repair or a mail COD landing mid-visit all look identical to a deposit if you only
  -- watch the player's balance — and each one used to be written to permanent history as a warband
  -- deposit (F-001). Requiring the store's own balance to mirror the change makes a money row as
  -- evidence-backed as an item row. A store whose balance cannot be read on BOTH snapshots
  -- contributes nothing: half an observation is not an observation.
  if L.MONEY_STORES[store] and before.storeMoney and after.storeMoney then
    local purseDelta = (after.money or 0) - (before.money or 0)
    local storeDelta = after.storeMoney - before.storeMoney
    if purseDelta ~= 0 and storeDelta ~= 0 and (purseDelta < 0) ~= (storeDelta < 0) then
      local amount = math.min(math.abs(purseDelta), math.abs(storeDelta))
      moves[#moves + 1] = {
        kind = C.Kind.MONEY, store = store, quantity = amount,
        direction = purseDelta < 0 and C.Direction.DEPOSIT or C.Direction.WITHDRAW,
      }
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

-- One-line summary of what a reconcile pass actually saw, emitted on EVERY pass — including a pass
-- that found nothing. A pass that produces no ledger row is the case that most needs explaining
-- (debug-logging-§8: log the not-recorded decisions too), and "silence" is not a diagnosis: it
-- cannot distinguish "the scan found no items in the store" from "the diff found no movement".
function L.DiffSummary(store, bagKinds, storeKinds, moveCount)
  return ("%s: bags %s kinds, store %s kinds -> %s moves"):format(
    tostring(store), tostring(bagKinds), tostring(storeKinds), tostring(moveCount))
end

-- Number of distinct item ids in a count map.
local function countKinds(map)
  local n = 0
  for _ in pairs(map or {}) do n = n + 1 end
  return n
end
L.CountKinds = countKinds

-- ── Snapshot scanning ───────────────────────────────────────────────────────────

-- Total count of each itemID across every container id belonging to `store`. Stores with their own
-- API family (guild bank, void storage) are scanned through their Compat readers instead.
function L:ScanStore(store)
  local counts = {}
  if store == C.Store.GUILD_BANK then return self:ScanGuildBank() end
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

-- Ask the server for every guild-bank tab's contents. Cheap and idempotent; the data lands later.
function L:QueryGuildBankTabs()
  local tabs = NS.Compat.GetNumGuildBankTabs()
  for tab = 1, tabs do NS.Compat.QueryGuildBankTab(tab) end
  if NS.State.debug and NS.Debug then
    NS.Debug("Store", "queried %s guild bank tabs", tabs)
  end
  return tabs
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

-- Full snapshot: the bags, every store the open frame can reach, and the money balance, as one
-- comparable value. Scanning all of a frame's stores together is what makes tab switching a
-- non-event — there is nothing to detect, because every tab was already measured.
function L:Snapshot(context)
  local stores, storeMoney = {}, {}
  for _, store in ipairs(self:StoresFor(context)) do
    stores[store] = self:ScanStore(store)
    -- The store's own coin balance, where it has one and this build can read it. nil is a real and
    -- expected answer — Diff treats it as "no money movement provable here" (see C-001).
    if L.MONEY_STORES[store] then
      storeMoney[store] = NS.Compat.GetStoreMoney(store)
    end
  end
  return {
    bags = self:ScanStore(C.Store.BAGS),
    stores = stores,
    money = NS.Compat.GetMoney(),
    storeMoney = storeMoney,
  }
end

-- The single-store view Diff consumes, pulled out of a whole-frame snapshot. Keeping Diff on the
-- narrow { bags, store, money, storeMoney } shape keeps it pure and keeps its tests readable.
local function storeView(snapshot, store)
  return {
    bags = snapshot.bags,
    store = (snapshot.stores or {})[store] or {},
    money = snapshot.money,
    storeMoney = (snapshot.storeMoney or {})[store],
  }
end

-- ── Diagnostics (`/bl debug scan`) ──────────────────────────────────────────────
-- A structured dump verb, which debug-logging-§4 explicitly sanctions. Its whole job is to replace
-- guesswork about the client's container model with ground truth: which `Enum.BagIndex` members
-- this build actually exposes and at what numeric ids, which ids report slots right now, and what
-- the addon's own id groups resolved to. Run it with a bank window open.
--
-- Returns an array of plain lines so it is testable and can be routed to the console or to chat.
local PROBE_MIN, PROBE_MAX = -8, 40

function L:Diagnose()
  local out = {}
  local function add(fmt, ...)
    out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
  end

  add("openContext=%s snapshot=%s", tostring(NS.State.openContext),
    NS.State.lastSnapshot and "yes" or "no")

  -- Which BagIndex members this build exposes, sorted by id — the values the id groups are built
  -- from. A member that is absent here is one this addon must not assume.
  local members = {}
  if Enum and Enum.BagIndex then
    for name, value in pairs(Enum.BagIndex) do
      if type(value) == "number" then members[#members + 1] = { name = name, value = value } end
    end
  end
  table.sort(members, function(a, b)
    if a.value ~= b.value then return a.value < b.value end
    return a.name < b.name
  end)
  add("Enum.BagIndex has %s members", #members)
  for _, m in ipairs(members) do add("  BagIndex.%s = %s", m.name, m.value) end

  -- What this addon's own groups resolved to, so a wrong group is visible beside the truth above.
  for _, store in ipairs({ "BAGS", "BANK", "REAGENT_BANK", "WARBAND_BANK" }) do
    local ids = C.STORE_CONTAINERS[store] or {}
    local parts = {}
    for i, id in ipairs(ids) do parts[i] = tostring(id) end
    add("group %s = [%s]", store, table.concat(parts, ", "))
  end

  -- Probe every plausible container id for slots and contents, whatever group it belongs to. This
  -- is the line that says where the bank actually lives on this client.
  add("container probe (id: slots / filled / distinct ids)")
  for id = PROBE_MIN, PROBE_MAX do
    local slots = NS.Compat.GetContainerNumSlots(id)
    if slots and slots > 0 then
      local filled, seen, kinds = 0, {}, 0
      for slot = 1, slots do
        local info = NS.Compat.GetContainerSlot(id, slot)
        if info then
          filled = filled + 1
          if not seen[info.itemID] then seen[info.itemID] = true; kinds = kinds + 1 end
        end
      end
      add("  %s: %s / %s / %s", id, slots, filled, kinds)
    end
  end

  add("money=%s", NS.Compat.GetMoney())

  -- Money capture rests on being able to read a STORE's own coin balance, not just the purse: a
  -- purse delta alone cannot tell a warband deposit apart from a bank-tab purchase. This line says
  -- which balance readers this build exposes, and what each one actually returns right now.
  add("money API: purse=%s guildBank=%s bankFetch=%s bankTypes=%s",
    type(GetMoney), type(GetGuildBankMoney),
    type(C_Bank and C_Bank.FetchDepositedMoney), tostring(Enum and Enum.BankType ~= nil))
  if Enum and Enum.BankType then
    local names = {}
    for name, value in pairs(Enum.BankType) do
      if type(value) == "number" then names[#names + 1] = ("%s=%s"):format(name, value) end
    end
    table.sort(names)
    add("  Enum.BankType: %s", table.concat(names, ", "))
  end
  -- Read each candidate behind a pcall: a reader that exists but errors off its own frame is no
  -- more usable than one that is absent, and this is the line that tells the two apart.
  local function probeMoney(label, fn)
    if type(fn) ~= "function" then return add("  %s: absent", label) end
    local ok, value = pcall(fn)
    add("  %s: %s", label, ok and tostring(value) or ("ERROR " .. tostring(value)))
  end
  probeMoney("GetGuildBankMoney()", GetGuildBankMoney)
  if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
    if Enum.BankType.Account then
      probeMoney("C_Bank.FetchDepositedMoney(Account)",
        function() return C_Bank.FetchDepositedMoney(Enum.BankType.Account) end)
    end
    if Enum.BankType.Character then
      probeMoney("C_Bank.FetchDepositedMoney(Character)",
        function() return C_Bank.FetchDepositedMoney(Enum.BankType.Character) end)
    end
  end

  -- Guild bank: which API globals this build exposes, and what each tab actually reports. A tab
  -- showing 0 filled when you can see items in it means the query has not landed yet.
  add("guild bank API: link=%s info=%s query=%s numTabs=%s current=%s visible=%s",
    type(GetGuildBankItemLink), type(GetGuildBankItemInfo), type(QueryGuildBankTab),
    type(GetNumGuildBankTabs), tostring(NS.Compat.GetCurrentGuildBankTab()),
    tostring(NS.Compat.IsGuildBankVisible()))
  -- The guild bank fires no close event, so its OnHide hook IS its close path. A `no` here means a
  -- guild session will linger until some unrelated bag update triggers the visibility backstop.
  add("guild bank close hook: %s (frame=%s)",
    L._guildHooked and "installed" or "NOT INSTALLED", type(GuildBankFrame))
  local tabs = NS.Compat.GetNumGuildBankTabs()
  add("guild bank tabs=%s (tab: filled / distinct ids)", tabs)
  local tabSize = NS.Compat.GuildBankTabSize()
  for tab = 1, tabs do
    local filled, seen, kinds = 0, {}, 0
    for slot = 1, tabSize do
      local info = NS.Compat.GetGuildBankSlot(tab, slot)
      if info then
        filled = filled + 1
        if not seen[info.itemID] then seen[info.itemID] = true; kinds = kinds + 1 end
      end
    end
    add("  tab %s: %s / %s", tab, filled, kinds)
  end

  -- Which events this build actually accepted. An event in the unavailable list is one Blizzard has
  -- retired; if a capture-critical one is in there, that is why nothing is being recorded.
  add("events registered (%s): %s", #L.registeredEvents, table.concat(L.registeredEvents, ", "))
  add("events UNAVAILABLE (%s): %s", #L.unavailableEvents,
    #L.unavailableEvents > 0 and table.concat(L.unavailableEvents, ", ") or "none")
  return out
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
    -- An id the client has not cached has NO quality, so it cannot be judged against the user's
    -- minimum — and "cannot be judged" is not "passes" (F-006). Ask the client to cache it so the
    -- next move of that id can be judged properly, and report the skip honestly: the console says
    -- "uncached", rather than the row silently appearing under a threshold that should have
    -- excluded it. At the default threshold of 0 this branch is unreachable (every quality clears
    -- 0), so nothing changes for a user who never set one.
    local _, quality = NS.Compat.ItemNameQuality(id)
    if quality == nil then
      if DB_QUALITY > 0 then
        NS.Compat.LoadItem(id)
        return "uncached"
      end
    elseif quality < DB_QUALITY then
      return "quality"
    end
  end
  return nil
end

-- ── Entry construction ──────────────────────────────────────────────────────────

-- Turn a movement into a stored ledger entry: stamp who/where/when and, for an item, whatever the
-- client has cached about it. An item the client hasn't cached yet stores its id alone and the
-- table shows "Item <id>". There is NO backfill: the stored row keeps only its id, so such an item
-- stays invisible to the Type / Sub-type / Quality breakdowns for good. This is why GateReason
-- refuses to admit an uncached item under a non-zero quality threshold rather than recording it and
-- hoping — a row that can never be classified is not one a threshold ever asked for.
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
  local name, quality, itemType, itemSubType, link = NS.Compat.GetItemDetails(move.itemID)
  entry.itemName = name
  entry.quality = quality
  entry.itemType = itemType
  entry.itemSubType = itemSubType
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

-- A BANKING SESSION is exactly the span an open storage frame is armed for — the same span
-- openContext tracks — so the session window rides this seam rather than re-deriving it from the
-- open/close events (which would miss the guild bank, armed by tab data rather than by an event).
-- Ledger is the ONLY sender of this message (architecture-§4). Declared here, above Reconcile, so
-- every session boundary in this file can reach it — including the guild bank's self-disarm.
local function fireSessionChanged(active, context)
  if NS.bus then
    NS.bus:SendMessage("Ka0s_BankLedger_SessionChanged", active and true or false, context)
  end
end

-- ── Event shell ─────────────────────────────────────────────────────────────────
-- A store's UI opening arms the differ (take the baseline snapshot); every change event while it is
-- open re-snapshots and records what moved; closing disarms it. Capture is entirely inert outside
-- an open store, which is what keeps a loot or a vendor purchase out of the ledger.

-- Re-snapshot against the baseline, record everything that moved, and make the new snapshot the
-- baseline. One summary debug line per pass, never one per item (debug-logging-§9).
-- Do two snapshots differ anywhere — bags, any store, or the money balance?
function L.SnapshotsDiffer(a, b)
  local function mapsDiffer(x, y)
    x, y = x or {}, y or {}
    for id, count in pairs(x) do if (y[id] or 0) ~= count then return true end end
    for id, count in pairs(y) do if (x[id] or 0) ~= count then return true end end
    return false
  end
  if (a.money or 0) ~= (b.money or 0) then return true end
  if mapsDiffer(a.bags, b.bags) then return true end
  local stores = {}
  for store in pairs(a.stores or {}) do stores[store] = true end
  for store in pairs(b.stores or {}) do stores[store] = true end
  for store in pairs(stores) do
    if mapsDiffer((a.stores or {})[store], (b.stores or {})[store]) then return true end
  end
  return false
end

-- How long to keep waiting for a half-finished movement to complete, and how often to look.
--
-- The two sides of one deposit can be **seconds** apart, not milliseconds: the bags update
-- immediately while a warband tab waits on a server round-trip. Debouncing alone cannot cover that
-- — pick any window and a slower round-trip beats it — so the baseline is *held* until the change
-- balances out instead of being advanced past a transaction that is still in flight.
-- The wait is **event-driven, not polled**. The other half of a movement cannot arrive silently: a
-- warband tab is a container, so the client updating it fires BAG_UPDATE_DELAYED and drives a
-- reconcile on its own. The timer here is only a give-up deadline for a change that will never
-- balance — an item deleted or looted while the bank is open. Polling for it instead burned a dozen
-- full rescans (bags + 6 bank tabs + 5 warband tabs, ~1600 slot reads each) to learn nothing.
L.SETTLE_TIMEOUT_SECONDS = 6
-- Floor for the deadline, so a re-arm late in the window can't schedule a near-zero timer.
L.SETTLE_MIN_RECHECK_SECONDS = 0.5

-- Re-snapshot against the baseline and record what moved, for EVERY store the open frame reaches.
-- Returns the total number of entries written.
--
-- The baseline advances only when the world is **settled**: either a movement was recorded, or
-- nothing changed at all. A pass that sees a one-sided change has caught a transaction mid-flight,
-- so it keeps the old baseline and looks again shortly. Advancing there was the bug that lost every
-- warband movement — the pass that saw "bags −1, warband unchanged" moved the goalposts, so the
-- pass a second later saw "warband +1, bags unchanged" and rejected that half too.
function L:Reconcile()
  local context = NS.State.openContext
  if not context then return 0 end
  local before = NS.State.lastSnapshot
  local after = self:Snapshot(context)
  if not before then
    NS.State.lastSnapshot = after
    return 0
  end

  local totalRecorded = 0
  for _, store in ipairs(self:StoresFor(context)) do
    local moves = L.Diff(storeView(before, store), storeView(after, store), store)
    -- Emitted before the skip, so a store that found nothing still says what it saw. Silence is not
    -- a diagnosis: it cannot distinguish "this store scanned empty" from "nothing moved".
    if NS.State.debug and NS.Debug then
      NS.Debug("Diff", "%s", L.DiffSummary(store, countKinds(after.bags),
        countKinds((after.stores or {})[store]), #moves))
    end
    if #moves > 0 then
      local recorded, skipped = 0, 0
      for _, move in ipairs(moves) do
        if self:Record(move) then recorded = recorded + 1 else skipped = skipped + 1 end
      end
      totalRecorded = totalRecorded + recorded
      if NS.State.debug and NS.Debug then
        NS.Debug("Move", "%s", L.MoveSummary(store, recorded, skipped))
      end
    end
  end

  local now = (GetTime and GetTime()) or 0
  if totalRecorded > 0 or not L.SnapshotsDiffer(before, after) then
    -- Settled: either the movement completed, or nothing is in flight.
    NS.State.lastSnapshot = after
    L._settleSince = nil
  else
    -- A one-sided change: the other half may still be on its way from the server. HOLD the baseline
    -- so the next pass can still see this half, and look again shortly.
    L._settleSince = L._settleSince or now
    if now - L._settleSince >= L.SETTLE_TIMEOUT_SECONDS then
      -- It never balanced, so it was never a movement (an item looted into the bags while the bank
      -- happened to be open, say). Accept the new state as the baseline and stop waiting, otherwise
      -- a stale delta would sit there and eventually pair with something unrelated.
      NS.State.lastSnapshot = after
      L._settleSince = nil
      if NS.State.debug and NS.Debug then
        NS.Debug("Diff", "one-sided change never settled; baseline re-anchored")
      end
    else
      -- Arm the deadline for whatever is LEFT of the window, not a fixed retry interval: events
      -- drive the real re-checks, so with nothing in flight this fires exactly once. Re-arming on
      -- the remainder each time keeps the deadline alive across event-driven rescheduling, which
      -- cancels the pending timer.
      self:ScheduleReconcile(math.max(L.SETTLE_MIN_RECHECK_SECONDS,
        L.SETTLE_TIMEOUT_SECONDS - (now - L._settleSince)))
    end
  end

  -- Armed by data rather than by an open event, the guild bank has to disarm itself too, or it
  -- would keep rescanning six 98-slot tabs on every bag update for the rest of the session. Only an
  -- explicit false counts: nil means this build cannot tell, and a false negative must not disarm.
  if context == C.Context.GUILD_BANK and NS.Compat.IsGuildBankVisible() == false then
    NS.State.openContext, NS.State.lastSnapshot, L._settleSince = nil, nil, nil
    if NS.State.debug and NS.Debug then NS.Debug("Store", "GUILD_BANK disarmed (window gone)") end
    -- Disarming here ends the session as surely as CloseContext does; the guild bank never gets a
    -- close event, so without this the session window would sit open after the frame vanished.
    fireSessionChanged(false, context)
  end
  return totalRecorded
end

-- Coalesce change events into ONE reconcile pass per user action.
--
-- A single deposit reports itself through more than one event, and they do not arrive together: the
-- bags update on `BAG_UPDATE_DELAYED` while the warband tabs update on their own beat a moment
-- later. Reconciling per event therefore splits one movement across two passes — the first sees
-- bags −1 with the store unchanged, the second sees store +1 with the bags unchanged, and the
-- "both sides must change" rule correctly rejects both halves. The movement vanishes.
--
-- Debouncing lines the passes up with user actions instead of with events, which is the unit the
-- rule is actually about. It also collapses the several full container scans one action used to
-- trigger into one. (Blizzard does exactly this themselves: `BAG_UPDATE_DELAYED` is a debounced
-- `BAG_UPDATE`.) Two genuinely separate actions stay separate, because they are further apart than
-- the window — which is what keeps "looted, then deposited later" from pairing up into a phantom row.
L.DEBOUNCE_SECONDS = 0.35

function L:ScheduleReconcile(delay)
  if not NS.State.openContext then return end
  local addon = NS.addon
  -- No timer library (a headless run): reconcile inline rather than silently drop the change.
  if not (addon and addon.ScheduleTimer) then return self:Reconcile() end
  self:CancelPendingReconcile()
  L._pendingTimer = addon:ScheduleTimer(function()
    L._pendingTimer = nil
    L:Reconcile()
  end, delay or L.DEBOUNCE_SECONDS)
end

function L:CancelPendingReconcile()
  local addon = NS.addon
  if L._pendingTimer and addon and addon.CancelTimer then
    addon:CancelTimer(L._pendingTimer)
  end
  L._pendingTimer = nil
end

-- Notice the guild bank CLOSING.
--
-- Every other frame announces its own close and `CloseContext` runs off that event. The guild bank
-- announces nothing: `GUILDBANKFRAME_CLOSED` registers without complaint and never fires on 12.0.7,
-- exactly like its `_OPENED` sibling. The `IsGuildBankVisible()` check inside `Reconcile` is not a
-- substitute, because closing the window changes no container and moves no money — so no event
-- fires, no reconcile pass runs, and the context stays armed until some unrelated bag update happens
-- along. That check is the backstop for a frame that vanished without hiding; this is the close.
--
-- The frame's own `OnHide` is the one notice the client does give. `GuildBankFrame` lives in
-- Blizzard_GuildBankUI, loaded on demand, so the hook is installed the first time the guild bank is
-- actually in play rather than at load — and once only, because a hook cannot be removed and this
-- runs on every arming. Hooking `OnHide` on a plain non-secure frame taints nothing.
function L:HookGuildBankFrame()
  if L._guildHooked then return true end
  local frame = GuildBankFrame
  if not (frame and type(frame.HookScript) == "function") then return false end
  L._guildHooked = true
  frame:HookScript("OnHide", function()
    -- Only ever ends the GUILD BANK's own session. The guild frame also hides whenever it is simply
    -- not the window on screen, and closing the character bank's context on that basis would throw
    -- away a baseline that is still in use.
    if NS.State.openContext == C.Context.GUILD_BANK then L:CloseContext() end
  end)
  if NS.State.debug and NS.Debug then NS.Debug("Store", "GUILD_BANK close hook installed") end
  return true
end

function L:OpenContext(context)
  NS.State.openContext = context
  L._settleSince = nil
  -- The guild bank only holds data for tabs that have been queried, so ask for all of them up
  -- front. The replies arrive asynchronously on GUILDBANKBAGSLOTS_CHANGED and reconcile normally.
  if context == C.Store.GUILD_BANK then
    self:QueryGuildBankTabs()
    self:HookGuildBankFrame()
  end
  local snap = self:Snapshot(context)
  NS.State.lastSnapshot = snap
  -- The baseline counts go in the open line, per store: a store that scans as empty here can never
  -- produce a movement, so that shows up immediately rather than as unexplained silence later.
  if NS.State.debug and NS.Debug then
    local parts = {}
    for _, store in ipairs(self:StoresFor(context)) do
      parts[#parts + 1] = ("%s %s"):format(store, countKinds(snap.stores[store]))
    end
    NS.Debug("Store", "%s opened (baseline: bags %s kinds; stores %s)",
      tostring(context), countKinds(snap.bags), table.concat(parts, ", "))
  end
  fireSessionChanged(true, context)
end

-- Guild bank data arrived.
--
-- The guild bank gets no usable open event: GUILDBANKFRAME_OPENED is a valid name that registers
-- without complaint and then never fires on 12.0.7, so waiting for it left the addon permanently
-- unarmed and every guild deposit unrecorded. What the server DOES reliably send is the tab
-- contents themselves, so data arriving is the signal that the guild bank is in play — the first
-- one lands when the window opens, before anything can be moved, which is exactly when the baseline
-- wants taking.
function L:OnGuildBankData()
  -- Never steal the context from a bank frame that is already open; that one has its own events.
  if not NS.State.openContext then
    self:OpenContext(C.Store.GUILD_BANK)
  end
  self:ScheduleReconcile()
end

function L:CloseContext()
  local context = NS.State.openContext
  if not context then return end
  -- Run the pending pass NOW rather than waiting out the debounce: the frame is closing and the
  -- last action's second half may still be in flight.
  self:CancelPendingReconcile()
  self:Reconcile()
  NS.State.openContext = nil
  NS.State.lastSnapshot = nil
  L._settleSince = nil
  if NS.State.debug and NS.Debug then NS.Debug("Store", "%s closed", tostring(context)) end
  fireSessionChanged(false, context)
end

-- Which FRAME an open-event belongs to. There is deliberately no event for the warband or reagent
-- tabs, because the game fires none — they ride inside BANK_FRAME (see L.CONTEXT_STORES).
local OPEN_EVENTS = {
  BANKFRAME_OPENED        = C.Context.BANK_FRAME,
  GUILDBANKFRAME_OPENED   = C.Context.GUILD_BANK,
}
local CLOSE_EVENTS = {
  BANKFRAME_CLOSED        = true,
  GUILDBANKFRAME_CLOSED   = true,
}
-- Events that mean "something in an open container changed". Each is a cue to re-diff, never a
-- movement in itself.
local CHANGE_EVENTS = {
  "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED",
  "PLAYER_MONEY",
}
-- Guild bank data. Handled separately because it ARMS the guild-bank context as well as
-- reconciling it — see L:OnGuildBankData.
local GUILD_DATA_EVENTS = { "GUILDBANKBAGSLOTS_CHANGED" }

-- Which event names this build accepted, and which it rejected. Read back by `/bl debug scan`.
L.registeredEvents = {}
L.unavailableEvents = {}

-- Register one event in isolation.
--
-- Blizzard retires events between expansions, and on modern retail `RegisterEvent` **raises** on an
-- unknown name rather than ignoring it. A bare `for ... do addon:RegisterEvent(...) end` therefore
-- turns one stale name into a silent catastrophe: the loop aborts and every remaining event goes
-- unregistered, leaving the addon deaf with no visible error unless the player has script errors
-- switched on. That is exactly how this addon shipped able to see `BANKFRAME_OPENED` and nothing
-- else. Isolating each registration means a name this build lacks is recorded and skipped while
-- every other event still binds.
function L:RegisterEventSafely(addon, event, handler)
  local ok = pcall(addon.RegisterEvent, addon, event, handler)
  local list = ok and L.registeredEvents or L.unavailableEvents
  list[#list + 1] = event
  return ok
end

function L:Enable()
  if self._enabled then return end
  self._enabled = true
  self:RefreshUpvalues()

  local addon = NS.addon
  L.registeredEvents, L.unavailableEvents = {}, {}
  for event, context in pairs(OPEN_EVENTS) do
    self:RegisterEventSafely(addon, event, function() L:OpenContext(context) end)
  end
  for event in pairs(CLOSE_EVENTS) do
    self:RegisterEventSafely(addon, event, function() L:CloseContext() end)
  end
  for _, event in ipairs(CHANGE_EVENTS) do
    -- Debounced, not immediate: one user action fires several of these, and the halves of a single
    -- movement do not all arrive on the same one.
    self:RegisterEventSafely(addon, event, function() L:ScheduleReconcile() end)
  end
  for _, event in ipairs(GUILD_DATA_EVENTS) do
    self:RegisterEventSafely(addon, event, function() L:OnGuildBankData() end)
  end

  -- Re-cache the hot-path upvalues whenever a setting changes. Registered on this module's OWN
  -- AceEvent target, never the shared bus-as-self, so it can't clobber another consumer of the same
  -- message (architecture-§4).
  L.__ev = NS.NewBusTarget()
  if L.__ev then
    L.__ev:RegisterMessage("Ka0s_BankLedger_SettingsChanged", function() L:RefreshUpvalues() end)
  end
end
