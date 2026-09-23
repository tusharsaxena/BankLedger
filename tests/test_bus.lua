-- tests/test_bus.lua -- the closed message bus's wire contract (architecture-§4).
--
-- Four messages cross this addon's bus. Their WIRE NAMES are typed in this file on purpose, once,
-- as the contract: they are what a receiver outside the addon would bind to, and a change to any
-- of them is a change a player's other addons would feel. Everywhere else in the addon they are
-- reached through the declared constants, and the one place those constants are declared is
-- pinned below.
--
-- The receiver and sender cases were written BEFORE the addon moved onto declared constants, and
-- passed against the literal call sites: they are the characterization that the move changed no
-- wire name, no subscription and no payload.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local WIRE = {
  ENTRY_ADDED      = "Ka0s_BankLedger_EntryAdded",
  LEDGER_CHANGED   = "Ka0s_BankLedger_LedgerChanged",
  SESSION_CHANGED  = "Ka0s_BankLedger_SessionChanged",
  SETTINGS_CHANGED = "Ka0s_BankLedger_SettingsChanged",
}
local IS_WIRE = {}
for _, name in pairs(WIRE) do IS_WIRE[name] = true end

--- The addon's own messages `target` is subscribed to, sorted and joined, so a case compares one
--- string and a failure prints the whole set.
local function subscriptions(target)
  local out = {}
  for msg, byTarget in pairs(mocks.__msgRegistry) do
    if type(msg) == "string" and msg:find("^Ka0s_BankLedger_") and byTarget[target] ~= nil then
      out[#out + 1] = msg
    end
  end
  table.sort(out)
  return table.concat(out, ",")
end

--- Run `fn` with NS.bus:SendMessage observed; answer every send as { name, n, ... }.
local function sends(fn)
  local sent = {}
  local raw = NS.bus.SendMessage
  NS.bus.SendMessage = function(self, name, ...)
    sent[#sent + 1] = { name = name, n = select("#", ...), ... }
    return raw(self, name, ...)
  end
  local ok, err = pcall(fn)
  NS.bus.SendMessage = raw
  if not ok then error(err, 0) end
  return sent
end

-- ── receivers ────────────────────────────────────────────────────────────────────────────────

test("bus: each module's receiver subscribes to exactly the wire names it always has", function()
  NS.addon:OnEnable()
  local expected = {
    Ledger        = WIRE.SETTINGS_CHANGED,
    Browser       = table.concat({ WIRE.ENTRY_ADDED, WIRE.LEDGER_CHANGED, WIRE.SETTINGS_CHANGED }, ","),
    SessionWindow = table.concat({ WIRE.ENTRY_ADDED, WIRE.LEDGER_CHANGED, WIRE.SESSION_CHANGED,
                                   WIRE.SETTINGS_CHANGED }, ","),
    Insights      = table.concat({ WIRE.ENTRY_ADDED, WIRE.LEDGER_CHANGED }, ","),
  }
  for name, want in pairs(expected) do
    local ev = NS[name].__ev
    assertTrue(ev ~= nil, name .. " stood up no bus target")
    assertEqual(subscriptions(ev), want, name .. "'s subscriptions")
  end
end)

test("bus: no live registration names an addon message outside the four", function()
  NS.addon:OnEnable()
  for msg, byTarget in pairs(mocks.__msgRegistry) do
    if type(msg) == "string" and msg:find("^Ka0s_BankLedger_") and next(byTarget) ~= nil then
      assertTrue(IS_WIRE[msg], "a receiver is subscribed to " .. msg .. ", which nothing sends")
    end
  end
end)

-- ── senders: the name and the payload's arity and values ─────────────────────────────────────

test("bus: Database:Add sends EntryAdded with the entry and its index", function()
  local saved = NS.db.global.ledger
  NS.db.global.ledger = {}
  local e = { ts = 1770000000, char = "Mock-Realm", classFile = "MAGE", kind = "ITEM",
    direction = "DEPOSIT", store = "BANK", itemID = 2589, itemName = "Linen Cloth", quality = 1,
    quantity = 10 }
  local ok, sent = pcall(sends, function() NS.Database:Add(e) end)
  NS.db.global.ledger = saved
  assertTrue(ok, tostring(sent))
  assertEqual(#sent, 1)
  assertEqual(sent[1].name, WIRE.ENTRY_ADDED)
  assertEqual(sent[1].n, 2)
  assertTrue(sent[1][1] == e, "the payload is not the entry itself")
  assertEqual(sent[1][2], 1)
end)

test("bus: Database:FireLedgerChanged sends LedgerChanged with no payload", function()
  local sent = sends(function() NS.Database:FireLedgerChanged() end)
  assertEqual(#sent, 1)
  assertEqual(sent[1].name, WIRE.LEDGER_CHANGED)
  assertEqual(sent[1].n, 0)
end)

test("bus: a settings write and the row-tint refresh send SettingsChanged with their reason", function()
  local cur = NS.Schema:Get("settings.trackItems")
  local sent = sends(function()
    NS.Schema:Set("settings.trackItems", cur)
    NS.Util.RefreshRowTint()
  end)
  assertEqual(#sent, 2)
  assertEqual(sent[1].name, WIRE.SETTINGS_CHANGED)
  assertEqual(sent[1][1], "trackItems")
  assertEqual(sent[2].name, WIRE.SETTINGS_CHANGED)
  assertEqual(sent[2][1], "rowTint")
end)

test("bus: opening and closing the bank frame sends SessionChanged true, then false", function()
  local L = dofile("tests/ledger_support.lua")
  local sent
  L.withContainers({ [L.BAG_ID] = { slots = 1 }, [L.BANK_ID] = { slots = 1 } }, function()
    sent = sends(function()
      NS.Ledger:OpenContext("BANK_FRAME")
      NS.Ledger:CloseContext()
    end)
  end)
  local session = {}
  for _, s in ipairs(sent) do
    if s.name == WIRE.SESSION_CHANGED then session[#session + 1] = s end
  end
  assertEqual(#session, 2)
  assertEqual(session[1].n, 2)
  assertEqual(session[1][1], true)
  assertEqual(session[1][2], "BANK_FRAME")
  assertEqual(session[2][1], false)
  assertEqual(session[2][2], "BANK_FRAME")
end)

-- ── the declaration: once, strict, and the same table on a library-less load ─────────────────

test("bus: NS.MSG declares exactly the four wire names", function()
  local n = 0
  for key, name in pairs(NS.MSG) do
    n = n + 1
    assertEqual(name, WIRE[key], "NS.MSG." .. tostring(key))
  end
  assertEqual(n, 4)
end)

test("bus: NS.MSG is LibKa0s-Bus-1.0's strict catalog, so a mistyped key raises", function()
  -- The publisher half is the reason: CallbackHandler's Fire returns quietly for a nil name, so
  -- SendMessage(NS.MSG.TYPO) against a plain table would send nothing and say nothing.
  local ok, err = pcall(function() return NS.MSG.ENTRY_ADDDED end)
  assertTrue(not ok, "reading an undeclared key answered instead of raising")
  assertTrue(tostring(err):find("no bus message named ENTRY_ADDDED", 1, true) ~= nil, tostring(err))
  ok = pcall(function() NS.MSG.NEW_ONE = "Ka0s_BankLedger_NewOne" end)
  assertTrue(not ok, "a key added after load was accepted")
end)

test("bus: without LibKa0s, NS.MSG is the same four names as a plain table", function()
  local Env = dofile("tests/degraded_env.lua")
  local ns, m = Env.loadDegraded()
  assertTrue(m.LibStub("LibKa0s-Bus-1.0", true) == nil, "the degraded arm still has the library")
  assertTrue(getmetatable(ns.MSG) == nil, "the degraded catalog carries a metatable")
  local n = 0
  for key, name in pairs(ns.MSG) do
    n = n + 1
    assertEqual(name, WIRE[key], "degraded MSG." .. tostring(key))
  end
  assertEqual(n, 4)
end)

test("bus: no addon file but core/Constants.lua types a message's wire name", function()
  -- architecture-§4's declare-once MUST, measured: a quoted Ka0s_BankLedger_ literal anywhere in
  -- the shipped files except the one declaration. Comments may name a message; a string may not.
  local Loader = T.Loader
  local found = {}
  for _, path in ipairs(Loader.tocFiles("BankLedger.toc")) do
    local f = io.open(path, "rb")
    if f then
      local src = f:read("*a")
      f:close()
      local count = 0
      for _ in src:gmatch("[\"']Ka0s_BankLedger_") do count = count + 1 end
      if count > 0 then found[path] = count end
    end
  end
  for path, count in pairs(found) do
    assertTrue(path == "core/Constants.lua", path .. " types " .. count .. " wire-name literal(s)")
  end
  assertEqual(found["core/Constants.lua"], 4)
end)
