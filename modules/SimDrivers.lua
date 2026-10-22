local _, NS = ...
-- modules/SimDrivers.lua — the simulator's event drivers (BankLedger#24, req-bl-sim §3).
--
-- ONE DRIVER PER CLIENT ACTION. Each driver edits the simulated world first, through the world's
-- mutation API (modules/SimWorld.lua), and then fires, in client order, the events the real client
-- would fire for that action, each through NS.Sim:Fire, so it reaches the real capture engine by the
-- same L:Dispatch a client event takes (modules/Sim.lua's deliver). A driver never records a row:
-- the engine decides every row from what the seam answers. An event Bank Ledger does not register
-- runs no handler, which is realistic and harmless.
--
-- THE EVENT LISTS ARE DATA (D.EVENTS, below). The exact 12.1.5 sequence for a warband deposit is an
-- in-client check on the owner's smoke list (OWNER_SCOPE C.13); a correction is a one-line edit to
-- the list here, never a code change. A payload token names what the driver hands the event:
--   "touched"  one event per container the move touched (the bag side, then the store side);
--   "bag"      the bag-side container id;
--   "store"    the store-side container id;
--   "slot"     the bank-tab slot the stack now sits in (or left);
--   nil        no payload.
--
-- DRIVER ARGUMENTS are one table, the scenario step itself (modules/SimScenario.lua):
--   store  C.Store.BANK / WARBAND_BANK / GUILD_BANK
--   item   a pool index (1 = the first real item), or "bonus" (the first pool item whose link
--          carries bonus ids, else the last pool item)
--   n      the stack size moved
--   lag    WARBAND only: nil fires both halves together, a number of seconds delays the store half
--          on the session's own timer (NS.Sim:After), "never" withholds it
--   dir    Money: "deposit" (purse into the store) or "withdraw"
--   copper Money and Spend
--   to     Switch: "main" or "alt"
-- Each driver answers a short detail string (what it did, or why it could not), which is the
-- step's `detail` (modules/Sim.lua's play).
--
-- NS.SimHost.pendingLag counts the lagged store halves still to land, for the host gate.
-- Load position is conventional: everything here is reached at call time.

NS.SimDrivers = NS.SimDrivers or {}
local D = NS.SimDrivers
local C = NS.Constants
local Store = C.Store

D.EVENTS = {
  OpenBank      = { { "BANKFRAME_OPENED" } },
  CloseBank     = { { "BANKFRAME_CLOSED" } },
  BankMove      = { { "BAG_UPDATE", "touched" }, { "PLAYERBANKSLOTS_CHANGED", "slot" },
                    { "BAG_UPDATE_DELAYED" } },
  WarbandBag    = { { "BAG_UPDATE", "bag" }, { "BAG_UPDATE_DELAYED" } },
  WarbandStore  = { { "BAG_UPDATE", "store" }, { "BAG_UPDATE_DELAYED" } },
  GuildMove     = { { "BAG_UPDATE", "bag" }, { "BAG_UPDATE_DELAYED" }, { "GUILDBANKBAGSLOTS_CHANGED" } },
  Money         = { { "PLAYER_MONEY" } },
  Loot          = { { "BAG_UPDATE", "bag" }, { "BAG_UPDATE_DELAYED" } },
  OpenGuild     = { { "GUILDBANK_FRAME_SHOWN" } },
  CloseGuild    = { { "GUILDBANK_FRAME_HIDDEN" } },
  GuildDataAway = { { "GUILDBANKBAGSLOTS_CHANGED" } },
}

-- ── helpers ──────────────────────────────────────────────────────────────────────────────────

local function world() return NS.SimHost and NS.SimHost.world end

-- The world keys its per-character tables by role ("main" / "alt"), the current one being w.current.
local function charKey(w) return w.current end

--- Fire one event list. `p` holds the payload values the tokens name.
function D.FireList(list, p)
  p = p or {}
  local sim = NS.Sim
  for _, row in ipairs(list) do
    local event, token = row[1], row[2]
    if token == "touched" then
      for _, id in ipairs(p.touched or {}) do sim:Fire(event, id) end
    elseif token then
      sim:Fire(event, p[token])
    else
      sim:Fire(event)
    end
  end
end

local function hasBonus(link)
  local ids = link and NS.Item and NS.Item.BonusIDsFromLink and NS.Item.BonusIDsFromLink(link)
  return ids ~= nil and #ids > 0
end

--- The pool entry a step's `item` names, or nil.
function D.ResolveItem(ref)
  local w = world()
  local pool = w and w.pool or {}
  if ref == "bonus" then
    for _, item in ipairs(pool) do
      if hasBonus(item.link) then return item end
    end
    return pool[#pool]
  end
  return pool[tonumber(ref) or 0]
end

-- The slot of the current character's bank container `id` holding `itemID`, else 1.
local function bankSlot(w, id, itemID)
  local c = w.bank[charKey(w)][id]
  for slot = 1, (c and c.size or 0) do
    local s = c[slot]
    if s and s.itemID == itemID then return slot end
  end
  return 1
end

local function moved(verb, n, item, store)
  return ("%s %d x %s %s %s"):format(verb, n, tostring(item.itemID), verb == "deposit" and "to" or "from",
    tostring(store))
end

-- ── the bank frame ───────────────────────────────────────────────────────────────────────────

function D.OpenBank()
  D.FireList(D.EVENTS.OpenBank)
  return "bank opened"
end

function D.CloseBank()
  D.FireList(D.EVENTS.CloseBank)
  return "bank closed"
end

-- ── item moves ───────────────────────────────────────────────────────────────────────────────

-- BANK: one move, both sides at once.
local function bankMove(w, a, item, deposit)
  local from, to = Store.BAGS, Store.BANK
  if not deposit then from, to = to, from end
  local ok, fromID, toID = NS.SimWorld.Move(charKey(w), from, to, item.itemID, a.n)
  if not ok then return false, fromID end
  local bankID = deposit and toID or fromID
  local bagID = deposit and fromID or toID
  D.FireList(D.EVENTS.BankMove, { touched = { bagID, bankID }, slot = bankSlot(w, bankID, item.itemID) })
  return true
end

-- The lagged store half of a warband move, landed (or taken) after `lag` seconds.
local function landLater(w, a, item, deposit)
  local host = NS.SimHost
  host.pendingLag = (host.pendingLag or 0) + 1
  local key = charKey(w)
  local handle = NS.Sim:After(a.lag, function()
    host.pendingLag = math.max(0, (host.pendingLag or 1) - 1)
    local to, from = Store.WARBAND_BANK, nil
    if not deposit then to, from = nil, Store.WARBAND_BANK end
    local ok, fromID, toID = NS.SimWorld.Move(key, from, to, item.itemID, a.n)
    if ok then D.FireList(D.EVENTS.WarbandStore, { store = deposit and toID or fromID }) end
  end)
  if not handle then host.pendingLag = math.max(0, host.pendingLag - 1) end
end

-- WARBAND: the bag half now; the store half with it, later, or never.
local function warbandMove(w, a, item, deposit)
  local key = charKey(w)
  if a.lag == nil then
    local from, to = Store.BAGS, Store.WARBAND_BANK
    if not deposit then from, to = to, from end
    local ok, fromID, toID = NS.SimWorld.Move(key, from, to, item.itemID, a.n)
    if not ok then return false, fromID end
    D.FireList(D.EVENTS.WarbandBag, { bag = deposit and fromID or toID })
    D.FireList(D.EVENTS.WarbandStore, { store = deposit and toID or fromID })
    return true
  end
  -- A lagged withdrawal must still find the stock it will take.
  if not deposit and not NS.SimWorld.Has(key, Store.WARBAND_BANK, item.itemID, a.n) then
    return false, "short"
  end
  local ok, fromID, toID
  if deposit then
    ok, fromID = NS.SimWorld.Move(key, Store.BAGS, nil, item.itemID, a.n)
  else
    ok, fromID, toID = NS.SimWorld.Move(key, nil, Store.BAGS, item.itemID, a.n)
  end
  if not ok then return false, fromID end
  D.FireList(D.EVENTS.WarbandBag, { bag = deposit and fromID or toID })
  if a.lag ~= "never" then landLater(w, a, item, deposit) end
  return true
end

-- GUILD: bags and a guild tab at once.
local function guildMove(w, a, item, deposit)
  local from, to = Store.BAGS, Store.GUILD_BANK
  if not deposit then from, to = to, from end
  local ok, fromID, toID = NS.SimWorld.Move(charKey(w), from, to, item.itemID, a.n)
  if not ok then return false, fromID end
  D.FireList(D.EVENTS.GuildMove, { bag = deposit and fromID or toID })
  return true
end

local MOVERS = { [Store.BANK] = bankMove, [Store.WARBAND_BANK] = warbandMove, [Store.GUILD_BANK] = guildMove }

local function move(a, deposit)
  local w = world()
  local item = D.ResolveItem(a.item)
  local mover = MOVERS[a.store]
  if not (w and item and mover) then return "skipped: no world, item or store" end
  local ok, why = mover(w, a, item, deposit)
  local verb = deposit and "deposit" or "withdraw"
  if not ok then return ("skipped %s: %s"):format(verb, tostring(why)) end
  return moved(verb, a.n, item, a.store)
end

function D.Deposit(a) return move(a, true) end
function D.Withdraw(a) return move(a, false) end

-- ── money ────────────────────────────────────────────────────────────────────────────────────

function D.Money(a)
  local copper = a.dir == "withdraw" and -a.copper or a.copper
  if not NS.SimWorld.Money(a.store, copper) then return "skipped money: refused" end
  D.FireList(D.EVENTS.Money)
  return ("%s %d copper %s"):format(tostring(a.dir), a.copper, tostring(a.store))
end

function D.Spend(a)
  if not NS.SimWorld.Money(nil, a.copper) then return "skipped spend: refused" end
  D.FireList(D.EVENTS.Money)
  return ("spent %d copper"):format(a.copper)
end

-- ── loot ─────────────────────────────────────────────────────────────────────────────────────

function D.Loot(a)
  local w = world()
  local item = D.ResolveItem(a.item)
  if not (w and item) then return "skipped: no world or item" end
  local ok, _, toID = NS.SimWorld.Move(charKey(w), nil, Store.BAGS, item.itemID, a.n)
  if not ok then return "skipped loot: full" end
  D.FireList(D.EVENTS.Loot, { bag = toID })
  return ("looted %d x %s"):format(a.n, tostring(item.itemID))
end

-- ── the guild bank ───────────────────────────────────────────────────────────────────────────

local function guild()
  local w = world()
  return w and w.guild
end

function D.OpenGuild()
  local g = guild()
  if not g then return "skipped: no world" end
  g.visible = true
  NS.SimWorld.ResetVisit()
  -- The handler opens the context, whose tab queries are guarded: their replies arrive 0.2 s later.
  D.FireList(D.EVENTS.OpenGuild)
  return "guild bank opened"
end

function D.CloseGuild()
  local g = guild()
  if not g then return "skipped: no world" end
  g.visible = false
  D.FireList(D.EVENTS.CloseGuild)
  return "guild bank closed"
end

--- Another member's deposit while the player is away: the tab changes, the frame stays hidden, and
--- the data event that follows must not arm a context (issue #12).
function D.GuildDataAway(a)
  local w = world()
  local item = D.ResolveItem(a.item)
  if not (w and item) then return "skipped: no world or item" end
  local ok = NS.SimWorld.Move(charKey(w), nil, Store.GUILD_BANK, item.itemID, a.n)
  if not ok then return "skipped: guild tab full" end
  D.FireList(D.EVENTS.GuildDataAway)
  return ("guild data away: %d x %s"):format(a.n, tostring(item.itemID))
end

-- ── a relog ──────────────────────────────────────────────────────────────────────────────────

--- Closes any open frame first, the way logging out does, then makes `to` the current character.
--- No PLAYER_ENTERING_WORLD: its one handler is the once-per-session prune, which touches only the
--- real ledger.
function D.Switch(a)
  if NS.State.openContext == C.Context.BANK_FRAME then D.CloseBank() end
  local g = guild()
  if g and g.visible then D.CloseGuild() end
  if not NS.SimWorld.Switch(a.to) then return "skipped: unknown character " .. tostring(a.to) end
  return "switched to " .. tostring(a.to)
end

-- The step kinds modules/Sim.lua's play may run: the drivers above, and nothing else in this table.
D.DRIVERS = {
  OpenBank = D.OpenBank, CloseBank = D.CloseBank, Deposit = D.Deposit, Withdraw = D.Withdraw,
  Money = D.Money, Spend = D.Spend, Loot = D.Loot, OpenGuild = D.OpenGuild, CloseGuild = D.CloseGuild,
  GuildDataAway = D.GuildDataAway, Switch = D.Switch,
}
