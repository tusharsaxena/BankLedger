-- tests/test_backfill.lua — THE LOGIN BACKFILL (BankLedger#2, modules/Backfill.lua).
--
-- An item the client had not cached when it moved is stored with its id alone, so the table shows
-- "Item <id>" and the Insights breakdowns never count it. The login pass fills those rows in once
-- the client answers: name, quality, type, sub-type and the link, NIL FIELDS ONLY, at most
-- NS.Constants.BACKFILL_MAX_IDS distinct ids per login, and one coalesced LedgerChanged.
--
-- It writes SavedVariables, so the cases below are mostly about what it must NOT do: overwrite a
-- present field, touch a gold row, write twice, fire per id, or write anything after a stand-down
-- or its timeout.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local C = NS.Constants
local EVENT = "GET_ITEM_INFO_RECEIVED"
local UNCACHED, UNCACHED2 = 900001, 900002
local ENABLED_PATH = "settings.enabled"

local function itemRow(id, extra)
  local r = { ts = 1, kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = id, quantity = 1 }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end

local function clearQueue()
  mocks.__timers = setmetatable({}, getmetatable(mocks.__timers))
end

local cachedLater = {}

--- The client caches `id` (what RequestLoadItemDataByID eventually achieves in the live client).
local function cache(id, name, quality, itemType, itemSubType)
  mocks.__items[id] = { name, quality, itemType, itemSubType, 0 }
  cachedLater[id] = true
end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

--- Run `fn(sent)` over `rows` as the ledger, with LedgerChanged counted, a fresh load-request record
--- and an empty timer queue. Whatever happens, the pass is canceled and everything handed back.
local function withPass(rows, fn)
  local g = NS.db.global
  local savedLedger, savedSend, savedChat = g.ledger, NS.bus.SendMessage, mocks.DEFAULT_CHAT_FRAME.AddMessage
  local sent = 0
  NS.bus.SendMessage = function(self, msg, ...)
    if msg == NS.MSG.LEDGER_CHANGED then sent = sent + 1 end
    return savedSend(self, msg, ...)
  end
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  g.ledger = rows
  mocks.__loadRequests = {}
  clearQueue()
  local ok, err = pcall(fn, function() return sent end)
  NS.Backfill:CancelPending()
  g.ledger = savedLedger
  NS.bus.SendMessage = savedSend
  mocks.DEFAULT_CHAT_FRAME.AddMessage = savedChat
  for id in pairs(cachedLater) do mocks.__items[id] = nil end
  cachedLater = {}
  mocks.__itemVariants = {}
  mocks.__loadRequests = {}
  clearQueue()
  if not ok then error(err, 0) end
end

local function debugLines(fn)
  local savedDebug = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  local ok, err = pcall(fn)
  local out = {}
  for _, line in ipairs(NS.DebugLog.buffer) do out[#out + 1] = line end
  NS.DebugLog:Clear()
  NS.State.debug = savedDebug
  if not ok then error(err, 0) end
  return out
end

local function hasLine(lines, text)
  for _, line in ipairs(lines) do
    if line:find(text, 1, true) then return true end
  end
  return false
end

-- ── The pure halves ─────────────────────────────────────────────────────────────

test("backfill: Collect lists distinct incomplete item ids in ledger order, capped, with their rows", function()
  local a, b, c = itemRow(UNCACHED), itemRow(UNCACHED2), itemRow(UNCACHED)
  local ledger = {
    a, { kind = "MONEY", itemName = "Gold" }, b,
    itemRow(2589, { itemName = "Linen Cloth", itemType = "Tradegoods" }), c, itemRow(900003),
  }
  local ids, rowsById = NS.Backfill.Collect(ledger, 2)
  assertEqual(#ids, 2, "the cap holds")
  assertEqual(ids[1], UNCACHED)
  assertEqual(ids[2], UNCACHED2)
  assertEqual(#rowsById[UNCACHED], 2, "every row of a listed id is mapped")
  assertTrue(rowsById[UNCACHED][1] == a and rowsById[UNCACHED][2] == c)
  assertEqual(rowsById[900003], nil, "an id past the cap is left for the next login")
  assertEqual(rowsById[2589], nil, "a row with a name and a type is complete")
  assertEqual(C.BACKFILL_MAX_IDS, 40)
end)

test("backfill: Apply fills nil fields only, counts the rows it changed, and is idempotent", function()
  local fresh = itemRow(UNCACHED)
  local named = itemRow(UNCACHED, { itemName = "Kept", quality = 4 })
  local n = NS.Backfill.Apply({ fresh, named }, "Name", 2, "Armor", "Cloth", "|Hitem:900001|h")
  assertEqual(n, 2)
  assertEqual(fresh.itemName, "Name"); assertEqual(fresh.quality, 2)
  assertEqual(fresh.itemType, "Armor"); assertEqual(fresh.itemSubType, "Cloth")
  assertEqual(fresh.itemLink, "|Hitem:900001|h")
  assertEqual(named.itemName, "Kept", "a present name was overwritten")
  assertEqual(named.quality, 4, "a present quality was overwritten")
  assertEqual(named.itemType, "Armor")
  assertEqual(NS.Backfill.Apply({ fresh, named }, "Other", 5, "X", "Y", "Z"), 0, "a second Apply changed something")
  assertEqual(fresh.itemName, "Name")
end)

-- ── The pass ────────────────────────────────────────────────────────────────────

test("backfill: an uncached row gains name, quality, type and sub-type once the client answers", function()
  -- red under: no backfill (BankLedger#2), or a pass that never listens for the client's answer.
  local row = itemRow(UNCACHED)
  withPass({ row }, function(sent)
    NS.Backfill:Run()
    assertTrue(mocks.__loadRequests[UNCACHED], "the client was not asked to load the item")
    assertTrue(NS.addon.__events[EVENT] ~= nil, "the pass is not listening for the answer")
    assertEqual(row.itemName, nil)
    cache(UNCACHED, "Spectral Shard", 3, "Tradegoods", "Enchanting")
    mocks.__fireEvent(EVENT, UNCACHED, true)
    assertEqual(row.itemName, "Spectral Shard")
    assertEqual(row.quality, 3)
    assertEqual(row.itemType, "Tradegoods")
    assertEqual(row.itemSubType, "Enchanting")
    assertTrue(type(row.itemLink) == "string" and row.itemLink:find("item:900001") ~= nil, "no link filled")
    assertEqual(sent(), 1, "one LedgerChanged for the pass")
    assertEqual(NS.addon.__events[EVENT], nil, "the event outlived the pass")
    local still = false
    for _, e in ipairs(NS.EventRecord.registered) do if e == EVENT then still = true end end
    assertFalse(still, "the event record still lists the event the pass let go of")
  end)
end)

test("backfill: a present name or quality is never overwritten", function()
  local row = itemRow(2589, { itemName = "Custom", quality = 4 })
  withPass({ row }, function()
    NS.Backfill:Run()
    assertEqual(row.itemName, "Custom")
    assertEqual(row.quality, 4)
    assertEqual(row.itemType, "Tradegoods", "the nil type was not filled")
    assertEqual(row.itemSubType, "Cloth")
  end)
end)

test("backfill: a second pass changes nothing and sends nothing", function()
  local rows = { itemRow(2589), itemRow(4306) }
  withPass(rows, function(sent)
    NS.Backfill:Run()
    assertEqual(sent(), 1, "the synchronous fill sends once")
    local before = {}
    for i, r in ipairs(rows) do before[i] = r.itemName .. "|" .. r.quality .. "|" .. r.itemType end
    mocks.__loadRequests = {}
    NS.Backfill:Run()
    assertEqual(#NS.db.global.ledger, 2, "the pass added or removed a row")
    for i, r in ipairs(rows) do
      assertEqual(r.itemName .. "|" .. r.quality .. "|" .. r.itemType, before[i])
    end
    assertEqual(sent(), 1, "the second pass sent LedgerChanged")
    assertEqual(count(mocks.__loadRequests), 0, "the second pass asked the client again")
    assertEqual(#mocks.__timers, 0, "the second pass armed a timer")
  end)
end)

test("backfill: at most BACKFILL_MAX_IDS distinct ids are requested per pass", function()
  local rows = {}
  for i = 1, 100 do rows[i] = itemRow(910000 + i) end
  withPass(rows, function()
    NS.Backfill:Run()
    assertEqual(count(mocks.__loadRequests), 40)
  end)
end)

test("backfill: gold rows and complete rows are never touched", function()
  local gold = { ts = 1, kind = "MONEY", direction = "DEPOSIT", store = "BANK", quantity = 5, itemName = "Gold" }
  local full = itemRow(2589, { itemName = "Linen Cloth", quality = 1, itemType = "Tradegoods",
    itemSubType = "Cloth", itemLink = "kept" })
  withPass({ gold, full }, function(sent)
    NS.Backfill:Run()
    assertEqual(count(mocks.__loadRequests), 0)
    assertEqual(#mocks.__timers, 0)
    assertEqual(sent(), 0)
    assertEqual(gold.quality, nil); assertEqual(gold.itemType, nil)
    assertEqual(full.itemLink, "kept")
  end)
end)

test("backfill: a stored link resolves through the link, not the base id", function()
  -- red under: resolving through row.itemID alone, which reads a bonus-upgraded drop back at its
  -- base quality (the BuildEntry rule, modules/Ledger.lua).
  local link = "|cffa335ee|Hitem:2589::::::::80:::1:4800|h[Linen Cloth]|h|r"
  local row = itemRow(2589, { itemLink = link })
  withPass({ row }, function()
    mocks.__itemVariants[link] = { "Linen Cloth", 4, "Tradegoods", "Cloth", 0 }
    NS.Backfill:Run()
    assertEqual(row.quality, 4, "resolved through the base id")
    assertEqual(row.itemLink, link, "the stored link was replaced")
  end)
end)

test("backfill: answers arriving one by one still send exactly one LedgerChanged", function()
  local a, b = itemRow(UNCACHED), itemRow(UNCACHED2)
  withPass({ a, b }, function(sent)
    NS.Backfill:Run()
    cache(UNCACHED, "A", 2, "Armor", "Cloth")
    mocks.__fireEvent(EVENT, UNCACHED, true)
    assertEqual(sent(), 0, "sent before the pass ended")
    cache(UNCACHED2, "B", 2, "Armor", "Leather")
    mocks.__fireEvent(EVENT, UNCACHED2, true)
    assertEqual(sent(), 1)
    assertEqual(a.itemName, "A"); assertEqual(b.itemName, "B")
  end)
end)

test("backfill: a pass that fills nothing sends nothing", function()
  local row = itemRow(UNCACHED)
  withPass({ row }, function(sent)
    NS.Backfill:Run()
    mocks.__fireEvent(EVENT, UNCACHED, false)
    assertEqual(NS.addon.__events[EVENT], nil, "a failed answer did not end the pass")
    assertEqual(sent(), 0)
    assertEqual(row.itemName, nil)
  end)
end)

test("backfill: a stand-down mid-pass lets go of the event and writes nothing afterwards", function()
  -- red under: leaving GET_ITEM_INFO_RECEIVED registered, or the pass's state, behind NS.StandDown.
  local row = itemRow(UNCACHED)
  withPass({ row }, function(sent)
    NS.Backfill:Run()
    NS.Schema:Set(ENABLED_PATH, false)
    local ok, err = pcall(function()
      assertEqual(NS.addon.__events[EVENT], nil, "the event survived the stand-down")
      assertEqual(#mocks.__timers(), 0, "the timeout survived the stand-down")
      cache(UNCACHED, "Late", 2, "Armor", "Cloth")
      mocks.__fireEvent(EVENT, UNCACHED, true)
      assertEqual(row.itemName, nil, "a stood-down pass wrote the row")
      assertEqual(sent(), 0)
    end)
    NS.Schema:Set(ENABLED_PATH, true)
    if not ok then error(err, 0) end
  end)
end)

test("backfill: the timeout ends the pass and leaves unresolved rows untouched", function()
  local row = itemRow(UNCACHED)
  withPass({ row }, function(sent)
    NS.Backfill:Run()
    assertEqual(#mocks.__timers, 1)
    assertEqual(mocks.__timers[1].delay, C.BACKFILL_TIMEOUT)
    assertEqual(C.BACKFILL_TIMEOUT, 10)
    mocks.__fireTimers()
    assertEqual(NS.addon.__events[EVENT], nil, "the event outlived the timeout")
    cache(UNCACHED, "Late", 2, "Armor", "Cloth")
    mocks.__fireEvent(EVENT, UNCACHED, true)
    assertEqual(row.itemName, nil)
    assertEqual(sent(), 0)
  end)
end)

test("backfill: the login timer runs it once, right after the retention prune", function()
  -- red under: not hooking the pass into addon:OnEnterWorld's timer, or running it before PruneOld.
  local st, db, bf = NS.State, NS.Database, NS.Backfill
  local savedDone, savedPending, savedPrune, savedRun = st.cleanupDone, st.cleanupPending, db.PruneOld, bf.Run
  local order = {}
  db.PruneOld = function() order[#order + 1] = "prune" end
  bf.Run = function() order[#order + 1] = "backfill" end
  st.cleanupDone, st.cleanupPending = false, nil
  clearQueue()
  local ok, err = pcall(function()
    NS.addon:OnEnterWorld()
    mocks.__fireTimers()
    NS.addon:OnEnterWorld()
    mocks.__fireTimers()
  end)
  db.PruneOld, bf.Run = savedPrune, savedRun
  st.cleanupDone, st.cleanupPending = savedDone, savedPending
  clearQueue()
  if not ok then error(err, 0) end
  assertEqual(table.concat(order, ","), "prune,backfill")
end)

test("backfill: the debug console says what the pass filled, asked for and left", function()
  local rows = { itemRow(2589), itemRow(UNCACHED) }
  withPass(rows, function()
    local lines = debugLines(function()
      NS.Backfill:Run()
      mocks.__fireTimers()
    end)
    assertTrue(hasLine(lines, "[Backfill] 1 rows over 2 ids filled now, 1 requested"), table.concat(lines, " | "))
    assertTrue(hasLine(lines, "[Backfill] done: 1 rows filled, 1 unresolved"), table.concat(lines, " | "))
  end)
end)

test("backfill: a ledger with nothing to fill writes no line (quiet steady state)", function()
  withPass({ itemRow(2589, { itemName = "Linen Cloth", itemType = "Tradegoods" }) }, function()
    local lines = debugLines(function() NS.Backfill:Run() end)
    assertFalse(hasLine(lines, "[Backfill]"), table.concat(lines, " | "))
  end)
end)
