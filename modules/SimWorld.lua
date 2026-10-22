local _, NS = ...
-- modules/SimWorld.lua — the simulator's world model and every answer the seam asks it for
-- (BankLedger#24, req-bl-sim §2; the seam itself is core/SimSetup.lua).
--
-- RUNTIME ONLY. A world is built by SW.Build at the start of a session and held on the host's own
-- table, NS.SimHost.world (OWNER_SCOPE C.4): never in SavedVariables, never on the library instance
-- or the seam. The session host (modules/Sim.lua) assigns it and drops it on stop.
--
-- REAL ITEMS, INVENTED PLACEMENT. `main` is the real player and the item pool is the player's real
-- bag contents, both read with the seam bypassed (NS.SimSeam:Live), so the item facts the pure
-- Compat members answer (GetItemDetails, ItemNameQuality) stay real. `alt` is invented. Where the
-- items sit, and every balance, is the simulator's.
--
-- THE PROVIDERS are registered once, at file load, for every wrapped Compat key but the guarded
-- QueryGuildBankTab (core/SimSetup.lua owns its answer). Each one answers fully from
-- NS.SimHost.world, read at call time, and never calls its `fallback` (the live member): while a
-- session runs, the client is not asked. With no world yet they answer the empty world (0 slots,
-- nil, false), never the live one.
--
-- THE MUTATION API (SW.Move, SW.Money, SW.Switch, SW.MarkQueried, SW.ResetVisit) is pure world
-- editing for the drivers (modules/SimDrivers.lua). It fires nothing: a driver edits, then fires.
-- Load position is conventional: nothing here is read by another file at load.

NS.SimWorld = NS.SimWorld or {}
local SW = NS.SimWorld
local C = NS.Constants
local Store = C.Store

local GOLD = 10000                       -- copper per gold
SW.PURSE = 5000 * GOLD                   -- each character's carried money
SW.WARBAND_MONEY = 20000 * GOLD
SW.GUILD_MONEY = 100000 * GOLD
SW.BACKPACK_SLOTS = 20
SW.TAB_SLOTS = 98                        -- the first character-bank tab and the first warband tab
SW.GUILD_TABS = 2
SW.POOL_MIN = 4                          -- fewer distinct real items than this: the fallback pool
SW.POOL_MAX = 8                          -- at most this many pool items are placed

-- The fixed ids modules/SessionWindow.lua's preview already uses, minus its legendary.
SW.FALLBACK_IDS = { 2589, 194863, 171276, 6948 }

-- The starting stack of every pool item, per group. The warband bank starts empty.
local SEED = { BAGS = 40, BANK = 20, GUILD_BANK = 20 }

-- A class different from main's for the invented alt: the first of these that is not main's.
local ALT_CLASSES = { "PALADIN", "WARRIOR" }

-- Container id -> its group, from the real Enum.BagIndex-derived id groups.
local GROUP_OF = {}
for group, ids in pairs(C.STORE_CONTAINERS) do
  for _, id in ipairs(ids) do GROUP_OF[id] = group end
end

-- ── reading the world ────────────────────────────────────────────────────────────────────────

local function world() return NS.SimHost and NS.SimHost.world end

local function guild()
  local w = world()
  return w and w.guild
end

local function currentChar()
  local w = world()
  return w and w.chars[w.current]
end

-- The id groups that hold a container for `charKey` (bags and bank are per character).
local function groupTable(w, charKey, group)
  if group == Store.BAGS then return w.bags[charKey] end
  if group == Store.BANK then return w.bank[charKey] end
  if group == Store.WARBAND_BANK then return w.warband end
  return nil
end

-- The current character's container `id`, or nil for an id no group holds or with no slots.
local function containerAt(id)
  local w = world()
  local group = GROUP_OF[id]
  if not (w and group) then return nil end
  local t = groupTable(w, w.current, group)
  return t and t[id]
end

-- A fresh { itemID, link, count } triple, as Compat answers; nil for an empty slot.
local function triple(s)
  if not s then return nil end
  return { itemID = s.itemID, link = s.link, count = s.count }
end

-- ── building it ──────────────────────────────────────────────────────────────────────────────

local function newContainer(size) return { size = size } end

-- The group's containers for one character: the first id of the group gets `size`, the rest none.
local function newGroup(ids, size)
  local t = {}
  if ids[1] ~= nil then t[ids[1]] = newContainer(size) end
  return t
end

-- The backpack is id 0 on every build (core/Constants.lua guarantees it in C.BAG_IDS).
local BACKPACK = GROUP_OF[0] == Store.BAGS and 0 or C.BAG_IDS[1]

local function newBags() return { [BACKPACK] = newContainer(SW.BACKPACK_SLOTS) } end

local function debugLine(fmt, ...)
  if NS.State and NS.State.debug and NS.Debug then NS.Debug("Sim", fmt, ...) end
end

-- The item pool: distinct { itemID, link } from the player's REAL bags, read with the seam
-- bypassed. Fewer than SW.POOL_MIN gives the fixed fallback ids, warmed and reported once.
function SW.BuildPool()
  local links = {}
  local counts = NS.SimSeam:Live(NS.Ledger.ScanStore, NS.Ledger, Store.BAGS, links)
  local ids = {}
  for id in pairs(counts or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  local pool = {}
  if #ids >= SW.POOL_MIN then
    for i = 1, math.min(#ids, SW.POOL_MAX) do pool[i] = { itemID = ids[i], link = links[ids[i]] } end
    return pool, false
  end
  for i, id in ipairs(SW.FALLBACK_IDS) do
    NS.Item.LoadItem(id)
    pool[i] = { itemID = id, link = select(5, NS.Compat.GetItemDetails(id)) }
  end
  debugLine("item pool: %d real bag items, using the %d fixed fallback ids", #ids, #pool)
  return pool, true
end

-- main is the real player; alt is invented on the real realm with a different class.
local function buildChars()
  local seam = NS.SimSeam
  local name, realm = seam:Live(NS.Compat.PlayerName)
  local classFile = seam:Live(NS.Compat.PlayerClass)
  local altClass = ALT_CLASSES[1] == classFile and ALT_CLASSES[2] or ALT_CLASSES[1]
  local altName = NS.L["Simbanker"]
  return {
    main = { key = name .. "-" .. realm, name = name, realm = realm, classFile = classFile },
    alt = { key = altName .. "-" .. realm, name = altName, realm = realm, classFile = altClass },
  }
end

local function buildGuild()
  local tabs = {}
  for t = 1, SW.GUILD_TABS do tabs[t] = newContainer(NS.Compat.GuildBankTabSize()) end
  return {
    name = NS.SimSeam:Live(NS.Compat.GetGuildName) or NS.L["Simulated Guild"],
    visible = false, tabs = tabs, queried = {}, money = SW.GUILD_MONEY,
  }
end

-- Every pool item placed, one slot each, in the first container of each seeded group.
local function seed(w)
  local function fill(container, count)
    for i, item in ipairs(w.pool) do
      container[i] = { itemID = item.itemID, link = item.link, count = count }
    end
  end
  for charKey in pairs(w.chars) do
    fill(w.bags[charKey][BACKPACK], SEED.BAGS)
    local bankTab = w.bank[charKey][C.BANK_IDS[1]]
    if bankTab then fill(bankTab, SEED.BANK) end
  end
  fill(w.guild.tabs[1], SEED.GUILD_BANK)
end

--- A fresh world. `opts.empty` leaves every container empty (the pool is still drawn).
function SW.Build(opts)
  opts = opts or {}
  local chars = buildChars()
  local pool, fallback = SW.BuildPool()
  local w = {
    chars = chars, current = "main",
    bags = {}, bank = {}, purse = {},
    warband = newGroup(C.WARBAND_BANK_IDS, SW.TAB_SLOTS),
    warbandMoney = SW.WARBAND_MONEY,
    guild = buildGuild(),
    pool = pool, poolFallback = fallback, links = {},
  }
  for charKey in pairs(chars) do
    w.bags[charKey] = newBags()
    w.bank[charKey] = newGroup(C.BANK_IDS, SW.TAB_SLOTS)
    w.purse[charKey] = SW.PURSE
  end
  for _, item in ipairs(pool) do w.links[item.itemID] = item.link end
  if not opts.empty then seed(w) end
  return w
end

-- ── the mutation API (pure world edits; nothing fires) ───────────────────────────────────────

-- The ordered { id, container } list a group holds for `charKey`; guild tabs for GUILD_BANK.
local function containersOf(w, charKey, group)
  local out = {}
  if group == Store.GUILD_BANK then
    for t, tab in ipairs(w.guild.tabs) do out[#out + 1] = { id = t, c = tab } end
    return out
  end
  local t = groupTable(w, charKey, group) or {}
  for _, id in ipairs(C.STORE_CONTAINERS[group] or {}) do
    if t[id] then out[#out + 1] = { id = id, c = t[id] } end
  end
  return out
end

local function countOf(list, itemID)
  local n = 0
  for _, e in ipairs(list) do
    for slot = 1, e.c.size do
      local s = e.c[slot]
      if s and s.itemID == itemID then n = n + s.count end
    end
  end
  return n
end

-- Removes `n` of `itemID` (the caller has checked there are enough). Answers the first container
-- id touched and the link of the stack it took from.
local function take(list, itemID, n)
  local firstID, link
  for _, e in ipairs(list) do
    for slot = 1, e.c.size do
      local s = e.c[slot]
      if n > 0 and s and s.itemID == itemID then
        local k = math.min(n, s.count)
        s.count, n = s.count - k, n - k
        if s.count == 0 then e.c[slot] = nil end
        firstID, link = firstID or e.id, link or s.link
      end
    end
  end
  return firstID, link
end

-- The slot a stack of `itemID` lands in: an existing stack of it, else the first empty slot.
local function landing(list, itemID)
  local emptyAt
  for _, e in ipairs(list) do
    for slot = 1, e.c.size do
      local s = e.c[slot]
      if s and s.itemID == itemID then return e, slot end
      if not s and not emptyAt then emptyAt = { e, slot } end
    end
  end
  if emptyAt then return emptyAt[1], emptyAt[2] end
  return nil
end

--- Moves `n` of `itemID` for `charKey` from one group to another (C.Store values). Either side may
--- be nil: `from` nil is an arrival (a loot, a guild-mate's deposit, a lagged store half), `to` nil
--- a departure. Answers true, fromID, toID (the container id or guild tab touched on each side), or
--- false and a reason ("short", "full") with the world untouched.
function SW.Move(charKey, fromGroup, toGroup, itemID, n)
  local w = world()
  if not w then return false, "no world" end
  local src = fromGroup and containersOf(w, charKey, fromGroup)
  local dst = toGroup and containersOf(w, charKey, toGroup)
  if src and countOf(src, itemID) < n then return false, "short" end
  local e, slot
  if dst then
    e, slot = landing(dst, itemID)
    if not e then return false, "full" end
  end
  local fromID, link
  if src then fromID, link = take(src, itemID, n) end
  if not dst then return true, fromID, nil end
  local s = e.c[slot]
  if s then
    s.count = s.count + n
  else
    e.c[slot] = { itemID = itemID, link = link or w.links[itemID], count = n }
  end
  return true, fromID, e.id
end

local MONEY_FIELD = { [Store.WARBAND_BANK] = "warband", [Store.GUILD_BANK] = "guild" }

--- Moves `copper` from the current character's purse into `store` (negative: out of the store into
--- the purse). `store` nil is a spend: the purse alone loses `copper` (a repair, a vendor buy).
--- Answers false, with nothing changed, when a side would go below zero or the store holds no coin.
function SW.Money(store, copper)
  local w = world()
  if not w then return false end
  local purse = w.purse[w.current] - copper
  if purse < 0 then return false end
  if store ~= nil then
    local field = MONEY_FIELD[store]
    if not field then return false end
    local balance = (field == "warband" and w.warbandMoney or w.guild.money) + copper
    if balance < 0 then return false end
    if field == "warband" then w.warbandMoney = balance else w.guild.money = balance end
  end
  w.purse[w.current] = purse
  return true
end

--- Makes `to` ("main" or "alt") the current character. False for an unknown key.
function SW.Switch(to)
  local w = world()
  if not (w and w.chars[to]) then return false end
  w.current = to
  return true
end

--- Marks a guild tab queried this visit: GetGuildBankSlot answers it from now on.
function SW.MarkQueried(tab)
  local g = guild()
  if g then g.queried[tab] = true end
end

--- Starts a new guild-bank visit: no tab is queried.
function SW.ResetVisit()
  local g = guild()
  if g then g.queried = {} end
end

-- ── the providers: fn(fallback, ...), answering from the world ───────────────────────────────

local P = {}

function P.GetContainerNumSlots(_, bagID)
  local c = containerAt(bagID)
  return c and c.size or 0
end

function P.GetContainerSlot(_, bagID, slot)
  local c = containerAt(bagID)
  return triple(c and c[slot])
end

-- Data only for a tab queried this visit, as the client (Compat.QueryGuildBankTab's note).
function P.GetGuildBankSlot(_, tab, slot)
  local g = guild()
  if not (g and g.queried[tab]) then return nil end
  local t = g.tabs[tab]
  return triple(t and t[slot])
end

function P.GetNumGuildBankTabs()
  local g = guild()
  return g and #g.tabs or 0
end

function P.GetCurrentGuildBankTab() return 1 end

function P.IsGuildBankVisible()
  local g = guild()
  return (g and g.visible) == true
end

-- The F-001 semantics of Compat.GetStoreMoney: guild coin only while its frame is up.
function P.GetStoreMoney(_, store)
  local w = world()
  if not w then return nil end
  if store == Store.WARBAND_BANK then return w.warbandMoney end
  if store == Store.GUILD_BANK and w.guild.visible == true then return w.guild.money end
  return nil
end

function P.GetMoney()
  local w = world()
  return w and w.purse[w.current] or 0
end

function P.GetGuildName()
  local g = guild()
  return g and g.name
end

function P.PlayerName()
  local c = currentChar()
  if not c then return "Unknown", "Unknown" end
  return c.name, c.realm
end

function P.PlayerClass()
  local c = currentChar()
  return c and c.classFile
end

SW.PROVIDERS = P

for key, fn in pairs(P) do NS.SimSeam:SetProvider(key, fn) end
