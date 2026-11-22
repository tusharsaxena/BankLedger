-- tests/test_probe.lua — the probe verbs, `/bl debug probe start|stop|status|clear` (WoW Forever
-- port design, ruling R4; modules/Probe.lua). A probe records what the client actually answers into
-- the addon's existing SavedVariables, a capped `probe` table under db.global, never a new SV
-- global: the start facts (client, build, money-text readers, instance, keyring), every bank visit's
-- facts at the open, +1 s and +3 s (per-container slot counts, the bank model's C_Bank answers, the
-- -2 socket reads, the keyring), the guild vault's reads, the banker's interaction type and the
-- bank cue events. It is a diagnostic: it never changes what the ledger records.
--
-- Every case runs on both kit profiles and asserts the client's own answer.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local P = NS.Probe
local FOREVER = NS.Compat.ClientKey() == "forever"
local KEYRING, SOCKETS = mocks.Enum.BagIndex.Keyring, mocks.Enum.BagIndex.Characterbanktab
local BANK_ID = mocks.Enum.BagIndex.CharacterBankTab_1

local function captureChat(fn)
  local out = {}
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return table.concat(out, "\n")
end

local function slash(words)
  return captureChat(function() NS.Slash:OnSlash("debug probe " .. words) end)
end

local function record() return NS.db.global.probe end

local function entriesOf(kind)
  local out = {}
  for _, e in ipairs((record() or {}).entries or {}) do
    if e.kind == kind then out[#out + 1] = e end
  end
  return out
end

-- Every case starts and ends with no probe armed and no record, and the mock's containers, timers
-- and bank context as they were.
local function fresh(fn)
  return function()
    P:Disarm()
    NS.db.global.probe = nil
    mocks.__timers = {}
    local saved = {}
    for _, id in ipairs({ KEYRING, SOCKETS, BANK_ID }) do saved[id] = mocks.__containers[id] end
    local ok, err = pcall(fn)
    P:Disarm()
    NS.db.global.probe = nil
    for _, id in ipairs({ KEYRING, SOCKETS, BANK_ID }) do mocks.__containers[id] = saved[id] end
    if NS.State.openContext then NS.Ledger:CloseContext() end
    NS.State.openContext, NS.State.lastSnapshot = nil, nil
    NS.Ledger:ForgetBankShape()
    mocks.__timers = {}
    if not ok then error(err, 0) end
  end
end

local function with(tbl, key, value, fn)
  local saved = tbl[key]
  tbl[key] = value
  local ok, err = pcall(fn)
  tbl[key] = saved
  if not ok then error(err, 0) end
end

local KEY_LINK = "|cffffffff|Hitem:5396::::::::::|h[Key to Searing Gorge]|h|r"
local BAG_LINK = "|cffffffff|Hitem:4500::::::::::|h[Traveler's Backpack]|h|r"

-- ── The verbs ───────────────────────────────────────────────────────────────────

test("probe: the four verbs are the debug verb's, and a bare or unknown word prints the usage", fresh(function()
  for _, words in ipairs({ "", "bogus" }) do
    local chat = slash(words)
    assertTrue(chat:find("/bl debug probe start", 1, true) ~= nil, "usage for '" .. words .. "': " .. chat)
    assertTrue(chat:find("stop", 1, true) and chat:find("status", 1, true) and chat:find("clear", 1, true),
      "the usage names every verb: " .. chat)
  end
  assertNil(record(), "the usage writes nothing to SavedVariables")
end))

test("probe: status with no record says the probe is off", fresh(function()
  local chat = slash("status")
  assertTrue(chat:find("probe off", 1, true) ~= nil, chat)
  assertNil(record(), "status creates no record")
end))

test("probe: start stamps the client and the build into db.global.probe and arms", fresh(function()
  local chat = slash("start")
  local p = record()
  assertTrue(type(p) == "table", "the record lives under db.global.probe")
  assertTrue(p.active == true, "active")
  assertEqual(p.client, NS.Compat.ClientKey())
  local version, build = mocks.GetBuildInfo()
  assertTrue(tostring(p.build):find(version, 1, true) ~= nil, "build names the version: " .. tostring(p.build))
  assertTrue(tostring(p.build):find(build, 1, true) ~= nil, "build names the build number")
  assertTrue(type(p.startedAt) == "number", "a start stamp")
  assertTrue(P:IsArmed(), "the probe listens")
  assertTrue(chat:find("probe on", 1, true) ~= nil, chat)
  local s = slash("status")
  assertTrue(s:find("probe on", 1, true) ~= nil, s)
  assertTrue(s:find(NS.Compat.ClientKey(), 1, true) ~= nil, "status names the client: " .. s)
end))

test("probe: the start facts carry the money-text readers, the identity and the instance", fresh(function()
  slash("start")
  local e = entriesOf("start")[1]
  assertTrue(e ~= nil, "one start entry")
  -- P9: the bare global's presence is recorded, never called; the two helpers are tried.
  assertTrue(e.bareCoinTexture ~= nil, "GetCoinTextureString presence")
  assertTrue(e.currencyCoinTexture ~= nil, "C_CurrencyInfo.GetCoinTextureString answer")
  assertTrue(e.moneyString ~= nil, "GetMoneyString answer")
  assertTrue(e.instance ~= nil, "GetInstanceInfo")
  assertEqual(e.mapID, tostring(mocks.C_Map.GetBestMapForUnit("player")))
  assertEqual(e.regionalNames, tostring(NS.Compat.RegionalNames()))
  assertEqual(e.characterKey, tostring(NS.Compat.CharacterKey()))
  assertEqual(e.defaultSkin, tostring(NS.DEFAULT_SKIN))
end))

test("probe: the start facts record the keyring's slots and contents", fresh(function()
  mocks.__containers[KEYRING] = { slots = 4, [2] = { itemID = 5396, link = KEY_LINK, count = 1 } }
  slash("start")
  local e = entriesOf("start")[1]
  assertEqual(e.keyringSlots, 4)
  assertTrue(type(e.keyring) == "table" and #e.keyring == 1, "one key")
  assertTrue(e.keyring[1]:find("^2 ") and e.keyring[1]:find(KEY_LINK, 1, true), e.keyring[1])
end))

-- ── A bank visit ────────────────────────────────────────────────────────────────

test("probe: a bank open records the bank facts at the open, +1 s and +3 s", fresh(function()
  mocks.__containers[BANK_ID] = { slots = 28 }
  slash("start")
  mocks.__timers = {}
  mocks.__fireEvent("BANKFRAME_OPENED")
  local banks = entriesOf("bank")
  assertEqual(#banks, 1, "the open's read is taken at once")
  assertEqual(banks[1].phase, 0)
  mocks.__fireTimers()
  banks = entriesOf("bank")
  assertEqual(#banks, 3, "+1 s and +3 s follow")
  assertEqual(banks[2].phase, 1)
  assertEqual(banks[3].phase, 3)
  local e = banks[1]
  assertTrue(e.containers:find(BANK_ID .. "=28", 1, true) ~= nil, "per-container slots: " .. e.containers)
  assertTrue(e.shape:find(BANK_ID .. "=28", 1, true) ~= nil, "the bank group's shape: " .. e.shape)
  assertTrue(e.canView:find("Character=true", 1, true) ~= nil, e.canView)
  assertTrue(e.canView:find("Account=" .. tostring(not FOREVER), 1, true) ~= nil,
    "the account bank is locked on Forever: " .. e.canView)
  assertTrue(e.deposited:find("Account=", 1, true) ~= nil, e.deposited)
  assertTrue(e.purchasedTabs ~= nil and e.useBags ~= nil and e.maxTabs ~= nil, "the C_Bank model answers")
  assertEqual(e.context, "BANK_FRAME", "the ledger's own context beside the facts")
  assertTrue(#entriesOf("event") >= 1, "the open event itself is recorded")
end))

test("probe: a bank read records the -2 socket reads through ItemLocation and GetContainerItemInfo", fresh(function()
  mocks.__containers[SOCKETS] = { slots = 9, [2] = { itemID = 4500, link = BAG_LINK, count = 1 } }
  local loc = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
  local item = mocks.C_Item
  with(mocks, "ItemLocation", loc, function()
    with(item, "DoesItemExist", function(l) return l.bag == SOCKETS and l.slot == 2 end, function()
      with(item, "GetItemLink", function(l) return l.slot == 2 and BAG_LINK or nil end, function()
        slash("start")
        mocks.__fireEvent("BANKFRAME_OPENED")
      end)
    end)
  end)
  local e = entriesOf("bank")[1]
  assertTrue(type(e.sockets) == "table" and #e.sockets == 1, "one socket answered")
  assertTrue(e.sockets[1]:find("^2 "), e.sockets[1])
  assertTrue(e.sockets[1]:find("loc=" .. BAG_LINK, 1, true) ~= nil, "the ItemLocation read: " .. e.sockets[1])
  assertTrue(e.sockets[1]:find("info=" .. BAG_LINK, 1, true) ~= nil, "the GetContainerItemInfo read")
end))

test("probe: a bank read without ItemLocation still records the GetContainerItemInfo read", fresh(function()
  mocks.__containers[SOCKETS] = { slots = 9, [1] = { itemID = 4500, link = BAG_LINK, count = 1 } }
  with(mocks, "ItemLocation", nil, function()
    slash("start")
    mocks.__fireEvent("BANKFRAME_OPENED")
  end)
  local e = entriesOf("bank")[1]
  assertTrue(#e.sockets == 1 and e.sockets[1]:find("loc=absent", 1, true) ~= nil, e.sockets[1] or "none")
end))

test("probe: the bank cue events are recorded with the seconds since the open", fresh(function()
  slash("start")
  mocks.__fireEvent("BANKFRAME_OPENED")
  mocks.__fireEvent("BAG_CONTAINER_UPDATE")
  mocks.__fireEvent("BANK_TABS_CHANGED", 0)
  local seen = {}
  for _, e in ipairs(entriesOf("event")) do seen[e.event] = e end
  for _, name in ipairs({ "BANKFRAME_OPENED", "BAG_CONTAINER_UPDATE", "BANK_TABS_CHANGED" }) do
    assertTrue(seen[name] ~= nil, name .. " recorded")
  end
  assertTrue(seen.BANK_TABS_CHANGED.sinceOpen ~= nil, "seconds since the bank opened")
  assertEqual(seen.BANK_TABS_CHANGED.args, "0")
end))

test("probe: the banker's interaction type is recorded by number and name", fresh(function()
  with(mocks.Enum, "PlayerInteractionType", { Banker = 8, GuildBanker = 10 }, function()
    slash("start")
    mocks.__fireEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
  end)
  local e = entriesOf("interaction")[1]
  assertEqual(e.type, 8)
  assertEqual(e.name, "Banker")
  assertEqual(#entriesOf("bank"), 1, "a banker's interaction takes the bank read")
end))

-- ── The guild vault ─────────────────────────────────────────────────────────────

test("probe: a guild banker records the guild-vault reads at the open, +1 s and +3 s", fresh(function()
  with(mocks.Enum, "PlayerInteractionType", { Banker = 8, GuildBanker = 10 }, function()
    slash("start")
    mocks.__fireEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 10)
    -- The vault's own open event in the same instant is the same visit, not a second one.
    mocks.__fireEvent("GUILDBANKFRAME_OPENED")
    mocks.__fireTimers()
  end)
  local guilds = entriesOf("guild")
  assertEqual(#guilds, 3, "one visit, three reads")
  local e = guilds[1]
  assertEqual(e.phase, 0)
  assertEqual(e.tabs, "8")
  assertEqual(e.money, tostring(mocks.GetGuildBankMoney()))
  assertEqual(e.current, "1")
  assertTrue(e.shown ~= nil, "the frame's visibility")
  assertEqual(#entriesOf("bank"), 0, "a guild banker takes no bank read")
end))

test("probe: GUILDBANKFRAME_OPENED alone takes the guild-vault reads", fresh(function()
  slash("start")
  mocks.__fireEvent("GUILDBANKFRAME_OPENED")
  assertEqual(#entriesOf("guild"), 1)
end))

-- ── The cap, stop, clear ────────────────────────────────────────────────────────

test("probe: the record is capped; the oldest entries go and the drop is counted", fresh(function()
  slash("start")
  local before = #record().entries
  for i = 1, P.CAP + 7 do P:Record("test", { n = i }) end
  local p = record()
  assertEqual(#p.entries, P.CAP, "capped at P.CAP")
  assertEqual(p.dropped, before + 7, "every dropped entry counted")
  assertEqual(p.entries[#p.entries].n, P.CAP + 7, "the newest is kept")
end))

-- BL-REV: the start entry holds the P9, P3, P-NAME and P-SKIN facts, and nothing re-reads them
-- mid-session. An evening of ordinary interactions must not evict the newest one.
test("probe: the newest start entry is never evicted by the cap", fresh(function()
  slash("start")
  for i = 1, P.CAP * 2 do P:Record("interaction", { n = i }) end
  local starts = entriesOf("start")
  assertEqual(#starts, 1, "the start facts survive a full record")
  assertEqual(#record().entries, P.CAP, "still capped at P.CAP")
  assertEqual(record().entries[#record().entries].n, P.CAP * 2, "the newest is kept")
end))

test("probe: a resumed probe records fresh start facts, and only the newest start is pinned", fresh(function()
  slash("start")
  P:Disarm()
  P:Resume()                                       -- a login or reload with the probe still active
  assertTrue(P:IsArmed(), "re-armed")
  assertEqual(#entriesOf("start"), 2, "a resume records the start facts again")
  for i = 1, P.CAP * 2 do P:Record("interaction", { n = i }) end
  assertEqual(#entriesOf("start"), 1, "older start entries age out like any other")
end))

test("probe: stop unarms, stamps the stop and keeps the record", fresh(function()
  slash("start")
  local chat = slash("stop")
  assertTrue(chat:find("probe off", 1, true) ~= nil, chat)
  local p = record()
  assertFalse(p.active, "inactive")
  assertTrue(type(p.stoppedAt) == "number", "a stop stamp")
  assertFalse(P:IsArmed(), "nothing listens")
  local n = #p.entries
  mocks.__fireEvent("BANKFRAME_OPENED")
  assertEqual(#record().entries, n, "a stopped probe records nothing")
end))

test("probe: clear empties the entries and keeps the probe's state", fresh(function()
  slash("start")
  for i = 1, 3 do P:Record("test", { n = i }) end
  local chat = slash("clear")
  assertTrue(chat:find("cleared", 1, true) ~= nil, chat)
  local p = record()
  assertEqual(#p.entries, 0)
  assertEqual(p.dropped, 0)
  assertTrue(p.active == true, "a running probe keeps running")
end))

-- ── The lifecycle ───────────────────────────────────────────────────────────────

test("probe: start is refused while the addon is disabled, and a disable disarms a running probe", fresh(function()
  slash("start")
  NS.SetDisabledHold(true)
  local ok, err = pcall(function()
    assertFalse(P:IsArmed(), "the stand-down disarms the probe")
    assertTrue(record().active == true, "the stored intent survives the stand-down")
    NS.db.global.probe = nil
    local chat = slash("start")
    assertTrue(chat:find("disabled", 1, true) ~= nil, chat)
    assertNil(record(), "a refused start writes nothing")
    NS.db.global.probe = { active = true, entries = {}, dropped = 0 }
  end)
  NS.SetDisabledHold(false)
  if not ok then error(err, 0) end
  assertTrue(P:IsArmed(), "the stand-up re-arms a probe left active")
end))

test("probe: the record is db.global's, and the TOC declares no new SavedVariables global", function()
  local fh = assert(io.open("BankLedger.toc", "r"))
  local toc = fh:read("*a")
  fh:close()
  assertEqual(toc:match("## SavedVariables: ([^\r\n]+)"), "BankLedgerDB")
  assertNil(toc:match("SavedVariablesPerCharacter"), "no per-character store")
end)
