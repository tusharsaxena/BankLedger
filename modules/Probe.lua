local _, NS = ...
NS.Probe = NS.Probe or {}
local P = NS.Probe
local C = NS.Constants
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)

-- modules/Probe.lua — the probe verbs, `/bl debug probe start|stop|status|clear` (WoW Forever port
-- design, ruling R4). `/bl debug scan` reads the container model once, when asked; a probe records
-- what the client actually answers, over a whole session of play, so the facts the port's defaults
-- lean on can be read back afterwards from `WTF/Account/<account>/SavedVariables/BankLedger.lua`.
-- docs/forever-probes.md says which fact settles which default, and keeps a `/run` sheet beside it.
--
-- WHAT IT RECORDS, one entry per fact, oldest first:
--   * `start`: the client and build, the money-text readers (P9; the bare GetCoinTextureString is
--     tested for presence and never called), the instance, the map id, the character and realm keys,
--     the default skin and the keyring's slots and contents (P3).
--   * `bank`: at a bank open, then +1 s and +3 s (P1, P2, P10): every container id's slot count, the
--     bank group's shape, C_Bank's CanViewBank / FetchNumPurchasedBankTabs / FetchMaxNumBankTabs /
--     FetchDepositedMoney per bank type and ShouldUsePlayerBagsInBank, the keyring, the -2 socket
--     reads through ItemLocation and GetContainerItemInfo (R6), and the ledger's own context and
--     readiness wait beside them.
--   * `guild`: at a guild vault open, then +1 s and +3 s (P6): the frame, the tab count, the coin,
--     the current tab and how many of its slots read an item.
--   * `interaction`: PLAYER_INTERACTION_MANAGER_FRAME_SHOW's type, by number and name (P1).
--   * `event`: the open events and the bank cues (BAG_CONTAINER_UPDATE, BANK_TABS_CHANGED), with
--     the seconds since the bank opened, so the readiness guard's 6 s deadline can be tuned.
--
-- WHERE IT LIVES. The addon's existing SavedVariables, `db.global.probe` (never a new SV global),
-- capped at P.CAP entries: the oldest go first (except the newest `start` entry, which is pinned)
-- and `dropped` counts them. Account-wide like the ledger, and outside every profile, so no profile
-- reset reaches it; `/bl debug probe clear` does.
--
-- A DIAGNOSTIC, NOT A FEATURE. It reads the client RAW (C_Container, C_Bank and the guild globals,
-- never NS.Compat's wrapped members), so a running simulation never answers for the client. It
-- listens on its own AceEvent target, never the addon object, so it can never take an event from
-- the capture engine; it changes nothing the ledger records. Every read goes through `call`, a
-- pcall over the function VALUE, so a reader a build lacks or that errors off its frame records
-- `absent` or `ERROR ...` instead of raising.
--
-- THE LIFECYCLE. `start` is refused while the addon is stood down. NS.StandDown disarms it and
-- NS.StandUp re-arms a probe whose stored record is still active, so a probe started once keeps
-- recording across logins and reloads until `/bl debug probe stop`.

P.CAP = 200
P.PHASES = { 0, 1, 3 }                 -- seconds after an open
P.CONTAINER_MIN, P.CONTAINER_MAX = -3, 23
P.SOCKET_SLOTS = 9                     -- the bank-bag sockets a -2 read walks (R6, P10)
P.ITEM_CAP = 40                        -- keyring and socket lines per entry
P.VISIT_DEDUPE_SECONDS = 1             -- an interaction and an open event in the same instant
P.SAMPLE_COPPER = 123456               -- the money-text sample (P9)

local USAGE = "usage: /bl debug probe start | stop | status | clear"

-- The interaction types that open a bank or a guild vault, by Enum.PlayerInteractionType NAME.
local BANKERS = { Banker = "bank", CharacterBanker = "bank", AccountBanker = "bank", GuildBanker = "guild" }

-- The events the probe listens to while armed, and the visit each opens (nil: recorded only).
local EVENTS = {
  { "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" },
  { "BANKFRAME_OPENED", "bank" },
  { "GUILDBANKFRAME_OPENED", "guild" },
  { "BAG_CONTAINER_UPDATE" },
  { "BANK_TABS_CHANGED" },
}

-- ── Reads ───────────────────────────────────────────────────────────────────────

-- The answer of `fn(...)` as stored text: `absent` when the reader does not exist, `ERROR <msg>`
-- when it raised, else its first return through the secret-safe stringifier.
local function call(fn, ...)
  if type(fn) ~= "function" then return "absent" end
  local ok, value = pcall(fn, ...)
  if not ok then return "ERROR " .. tostring(value) end
  return NS.SafeToString(value)
end

-- Every return of `fn(...)`, joined with "|", or the same `absent` / `ERROR` answers.
local function callAll(fn, ...)
  if type(fn) ~= "function" then return "absent" end
  local res = { pcall(fn, ...) }
  if not res[1] then return "ERROR " .. tostring(res[2]) end
  local parts = {}
  for i = 2, #res do parts[#parts + 1] = NS.SafeToString(res[i]) end
  return table.concat(parts, "|")
end

local function slots(id)
  local n = tonumber(call(C_Container and C_Container.GetContainerNumSlots, id))
  return n or 0
end

local function slotLink(id, slot)
  local fn = C_Container and C_Container.GetContainerItemInfo
  if type(fn) ~= "function" then return nil end
  local ok, info = pcall(fn, id, slot)
  if not (ok and type(info) == "table") then return nil end
  return NS.SafeToString(info.hyperlink), info.stackCount
end

-- "Name=answer" for each Enum.BankType member, sorted by name, through `fn(bankType)`.
local function perBankType(fn)
  local bt = Enum and Enum.BankType
  if type(bt) ~= "table" then return "no Enum.BankType" end
  local names = {}
  for name, value in pairs(bt) do
    if type(value) == "number" then names[#names + 1] = name end
  end
  table.sort(names)
  for i, name in ipairs(names) do names[i] = name .. "=" .. call(fn, bt[name]) end
  return table.concat(names, " ")
end

-- "id=slots" for every id in the range that reports slots.
local function containerLine()
  local parts = {}
  for id = P.CONTAINER_MIN, P.CONTAINER_MAX do
    local n = slots(id)
    if n ~= 0 then parts[#parts + 1] = id .. "=" .. n end
  end
  return table.concat(parts, " ")
end

-- The bank group's ids with their slot counts, zeros included: the readiness guard's view.
local function bankShape()
  local ids = C.STORE_CONTAINERS[C.Store.BANK] or {}
  local parts, shape = {}, {}
  for i, id in ipairs(ids) do
    local n = slots(id)
    shape[id] = n
    parts[i] = id .. "=" .. n
  end
  return table.concat(parts, " "), shape
end

local function keyringInto(e)
  local id = (Enum and Enum.BagIndex and Enum.BagIndex.Keyring) or -1
  local n = slots(id)
  local items = {}
  for slot = 1, n do
    local link, count = slotLink(id, slot)
    if link and #items < P.ITEM_CAP then items[#items + 1] = slot .. " " .. link .. " x" .. tostring(count) end
  end
  e.keyringSlots, e.keyring = n, items
end

-- One socket's ItemLocation read: the link, `absent` with no ItemLocation, or nil when empty.
local function socketLocation(id, slot)
  local IL = ItemLocation
  if not (type(IL) == "table" and type(IL.CreateFromBagAndSlot) == "function") then return "absent" end
  local ok, loc = pcall(IL.CreateFromBagAndSlot, IL, id, slot)
  if not (ok and loc) then return nil end
  local item = C_Item
  if call(item and item.DoesItemExist, loc) ~= "true" then return nil end
  return call(item and item.GetItemLink, loc)
end

-- The -2 socket reads (R6): a line per slot that answered either way.
local function socketsInto(e)
  local id = (Enum and Enum.BagIndex and Enum.BagIndex.Characterbanktab) or -2
  local out = {}
  for slot = 1, P.SOCKET_SLOTS do
    local loc = socketLocation(id, slot)
    local info = slotLink(id, slot)
    if (loc and loc ~= "absent") or info then
      out[#out + 1] = ("%d loc=%s info=%s"):format(slot, tostring(loc), tostring(info))
    end
  end
  e.socketSlots, e.sockets = slots(id), out
end

-- The ledger's own state beside the facts. The readiness judgment (NS.Compat.UnreadyBankContainers,
-- LibKa0s-Compat-1.0's) is pure; the shape memory is read only off a simulation, which keeps a
-- memory of its own world.
local function ledgerInto(e, shape)
  local L = NS.Ledger
  e.context = NS.State and NS.State.openContext or nil
  e.waiting = L and L._unreadySince ~= nil or false
  local sim = NS.Sim and NS.Sim:IsActive()
  e.sim = sim and true or false
  if L and L.ShapeMemory and not sim then
    local missing = NS.Compat.UnreadyBankContainers(shape or {}, L:ShapeMemory())
    e.unready = missing and table.concat(missing, ",") or ""
  end
end

local function bankFacts()
  local bank = C_Bank or {}
  local e = { containers = containerLine() }
  local shape
  e.shape, shape = bankShape()
  e.canView = perBankType(bank.CanViewBank)
  e.purchasedTabs = perBankType(bank.FetchNumPurchasedBankTabs)
  e.maxTabs = perBankType(bank.FetchMaxNumBankTabs)
  e.deposited = perBankType(bank.FetchDepositedMoney)
  e.useBags = call(bank.ShouldUsePlayerBagsInBank)
  keyringInto(e)
  socketsInto(e)
  ledgerInto(e, shape)
  return e
end

local function guildFacts()
  local frame = GuildBankFrame
  local e = {
    shown = frame and call(frame.IsVisible, frame) or "absent",
    tabs = call(GetNumGuildBankTabs),
    money = call(GetGuildBankMoney),
    current = call(GetCurrentGuildBankTab),
  }
  local tab = tonumber(e.current)
  if tab then
    e.tabInfo = callAll(GetGuildBankTabInfo, tab)
    local filled = 0
    for slot = 1, (MAX_GUILDBANK_SLOTS_PER_TAB or 98) do
      local link = call(GetGuildBankItemLink, tab, slot)
      if link ~= "nil" and link ~= "absent" and link:sub(1, 5) ~= "ERROR" then filled = filled + 1 end
    end
    e.filled = filled
  end
  return e
end

local function buildLine()
  return callAll(GetBuildInfo)
end

local function startFacts()
  local currency = C_CurrencyInfo
  local e = {
    bareCoinTexture = type(GetCoinTextureString),
    currencyCoinTexture = call(currency and currency.GetCoinTextureString, P.SAMPLE_COPPER),
    moneyString = call(GetMoneyString, P.SAMPLE_COPPER),
    instance = callAll(GetInstanceInfo),
    mapID = call(C_Map and C_Map.GetBestMapForUnit, "player"),
    regionalNames = call(NS.Compat.RegionalNames),
    characterKey = call(NS.Compat.CharacterKey),
    realmKey = call(NS.Compat.RealmKey),
    defaultSkin = NS.SafeToString(NS.DEFAULT_SKIN),
  }
  keyringInto(e)
  return e
end

-- ── The record ──────────────────────────────────────────────────────────────────

local function stored()
  local g = NS.db and NS.db.global
  local p = g and g.probe
  if type(p) ~= "table" then return nil end
  if type(p.entries) ~= "table" then p.entries = {} end
  p.dropped = tonumber(p.dropped) or 0
  return p
end

local function ensure()
  local g = NS.db and NS.db.global
  if not g then return nil end
  if type(g.probe) ~= "table" then g.probe = { entries = {}, dropped = 0 } end
  return stored()
end

--- Appends one entry of `kind` (its fields from `data`) with a time stamp, dropping the oldest past
--- P.CAP. Answers false when there is no record to write into.
-- The entry the cap drops: the oldest, unless that is the NEWEST `start` entry (BL-REV). The start
-- facts (P9, P3, P-NAME, P-SKIN) are read only at a start or a resume, so an evening of merchants,
-- gossip and bag swaps must never push the last copy out; it is pinned and the next oldest goes.
local function evictIndex(list)
  if list[1].kind ~= "start" then return 1 end
  for i = 2, #list do
    if list[i].kind == "start" then return 1 end
  end
  return 2
end

function P:Record(kind, data)
  local p = stored()
  if not p then return false end
  local e = data or {}
  e.kind, e.at = kind, time()
  local list = p.entries
  list[#list + 1] = e
  while #list > P.CAP do
    table.remove(list, evictIndex(list))
    p.dropped = p.dropped + 1
  end
  return true
end

-- ── Visits ──────────────────────────────────────────────────────────────────────

P._lastVisit = {}

local function readPhase(kind, phase)
  if not P._armed then return end
  local e = kind == "bank" and bankFacts() or guildFacts()
  e.phase = phase
  P:Record(kind, e)
end

-- A bank or guild visit: the read now, then one per later phase. An interaction and an open event
-- of the same kind in the same instant are one visit.
local function visit(kind)
  local now = GetTime()
  local last = P._lastVisit[kind]
  if last and now - last < P.VISIT_DEDUPE_SECONDS then return end
  P._lastVisit[kind] = now
  if kind == "bank" then P._bankOpenedAt = now end
  local addon = NS.addon
  for _, phase in ipairs(P.PHASES) do
    if phase == 0 then readPhase(kind, 0)
    elseif addon and addon.ScheduleTimer then
      addon:ScheduleTimer(function() readPhase(kind, phase) end, phase)
    end
  end
end

local function interactionName(value)
  local types = Enum and Enum.PlayerInteractionType
  if type(types) ~= "table" then return nil end
  for name, v in pairs(types) do
    if v == value then return name end
  end
  return nil
end

local function onInteraction(_, value)
  local name = interactionName(value)
  P:Record("interaction", { type = value, name = name })
  local kind = name and BANKERS[name]
  if kind then visit(kind) end
end

local function onEvent(event, opens, ...)
  local args = {}
  for i = 1, select("#", ...) do args[i] = NS.SafeToString((select(i, ...))) end
  local since = P._bankOpenedAt and (GetTime() - P._bankOpenedAt) or nil
  P:Record("event", { event = event, args = table.concat(args, ","), sinceOpen = since })
  if opens then visit(opens) end
end

--- Starts listening, on the probe's own AceEvent target. Idempotent.
function P:Arm()
  if self._armed then return true end
  local target = NS.NewBusTarget()
  if not target then return false end
  self.__ev, self._armed, self._lastVisit = target, true, {}
  for _, row in ipairs(EVENTS) do
    local event, opens = row[1], row[2]
    local handler = event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and onInteraction
      or function(e, ...) onEvent(e, opens, ...) end
    NS.RegisterEventSafely(target, event, handler)
  end
  return true
end

--- Stops listening. The stored record, and whether it is active, are left as they are.
function P:Disarm()
  local target = self.__ev
  if target and target.UnregisterAllEvents then target:UnregisterAllEvents() end
  self.__ev, self._armed, self._bankOpenedAt = nil, nil, nil
end

function P:IsArmed() return self._armed == true end

--- NS.StandUp's call: re-arms a probe whose stored record is still active, and records this
--- session's start facts again (a login or reload can change the keyring and the money readers).
function P:Resume()
  local p = stored()
  if not (p and p.active) then return end
  self:Arm()
  self:Record("start", startFacts())
end

-- ── The verbs ───────────────────────────────────────────────────────────────────

local function statusLine(p)
  if not p then return "probe off: no record. /bl debug probe start begins one." end
  return ("probe %s: %d of %d entries kept, %d dropped; %s %s"):format(
    p.active and "on" or "off", #p.entries, P.CAP, p.dropped, tostring(p.client), tostring(p.build))
end

function P:Start()
  if NS.IsStoodDown and NS.IsStoodDown() then
    print("probe refused: the addon is disabled. /bl enable first.")
    return false
  end
  local p = ensure()
  if not p then return false end
  p.active, p.stoppedAt = true, nil
  p.client, p.build, p.startedAt = NS.Compat.ClientKey(), buildLine(), time()
  self:Arm()
  self:Record("start", startFacts())
  print(statusLine(p))
  return true
end

function P:Stop()
  self:Disarm()
  local p = stored()
  if p then p.active, p.stoppedAt = false, time() end
  print(statusLine(p))
end

function P:Clear()
  local p = stored()
  if p then p.entries, p.dropped = {}, 0 end
  print("probe record cleared.")
end

local VERBS = {
  start = function() P:Start() end,
  stop = function() P:Stop() end,
  status = function() print(statusLine(stored())) end,
  clear = function() P:Clear() end,
}

--- `/bl debug probe <word>`: the one entry from the debug verb.
function P:RunVerb(rest)
  local word = rest and tostring(rest):lower():match("^%s*(%S*)") or ""
  local verb = VERBS[word]
  if verb then verb() else print(USAGE) end
end
