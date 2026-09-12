local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- A small, explicit fixture so every assertion below reads against known data.
local NOW = 1770000000
local function entry(over)
  local e = {
    ts = NOW, char = "Mock-Realm", classFile = "MAGE",
    kind = "ITEM", direction = "DEPOSIT", store = "BANK",
    itemID = 2589, itemName = "Linen Cloth", quality = 1,
    itemType = "Tradegoods", itemSubType = "Cloth",
    quantity = 10, zone = "Testville", mapID = 2657,
  }
  for k, v in pairs(over or {}) do e[k] = v end
  return e
end

local function withLedger(entries, fn)
  local saved = NS.db.global.ledger
  NS.db.global.ledger = entries
  local ok, err = pcall(fn)
  NS.db.global.ledger = saved
  if not ok then error(err, 0) end
end

test("Database:Add appends and returns the new index", function()
  withLedger({}, function()
    local i = NS.Database:Add(entry())
    assertEqual(i, 1)
    assertEqual(NS.Database:Count(), 1)
  end)
end)

test("Database:Add fires EntryAdded on the bus", function()
  withLedger({}, function()
    local seen = 0
    local target = NS.NewBusTarget()
    target:RegisterMessage("Ka0s_BankLedger_EntryAdded", function() seen = seen + 1 end)
    NS.Database:Add(entry())
    target:UnregisterMessage("Ka0s_BankLedger_EntryAdded")
    assertEqual(seen, 1)
  end)
end)

test("Database: two consumers of one message both receive it", function()
  -- CallbackHandler keys callbacks by (message, target). If two consumers shared a target the
  -- second would silently clobber the first — the exact bug NS.NewBusTarget exists to prevent.
  withLedger({}, function()
    local a, b = 0, 0
    local ta, tb = NS.NewBusTarget(), NS.NewBusTarget()
    ta:RegisterMessage("Ka0s_BankLedger_EntryAdded", function() a = a + 1 end)
    tb:RegisterMessage("Ka0s_BankLedger_EntryAdded", function() b = b + 1 end)
    NS.Database:Add(entry())
    ta:UnregisterMessage("Ka0s_BankLedger_EntryAdded")
    tb:UnregisterMessage("Ka0s_BankLedger_EntryAdded")
    assertEqual(a, 1)
    assertEqual(b, 1)
  end)
end)

-- ── QueryList ──────────────────────────────────────────────────────────────────

local FIXTURE = {
  entry(),
  entry({ direction = "WITHDRAW", store = "GUILD_BANK", itemID = 4306,
          itemName = "Silk Cloth", quantity = 3, ts = NOW - 86400 }),
  -- Built explicitly, not through entry(): a `field = nil` override is invisible to pairs(), so it
  -- would silently inherit the item fields instead of clearing them.
  { ts = NOW - 2 * 86400, char = "Mock-Realm", classFile = "MAGE", kind = "MONEY",
    direction = "DEPOSIT", store = "GUILD_BANK", itemName = "Gold", quantity = 50000,
    zone = "Testville", mapID = 2657 },
  entry({ char = "Alt-Realm", classFile = "ROGUE", store = "WARBAND_BANK",
          itemID = 171276, itemName = "Spectral Flask", quality = 3,
          itemType = "Consumable", itemSubType = "Flask",
          quantity = 2, ts = NOW - 3 * 86400 }),
}

test("Database:QueryList with no filter returns everything", function()
  assertEqual(#NS.Database:QueryList(FIXTURE, nil), 4)
  assertEqual(#NS.Database:QueryList(FIXTURE, {}), 4)
end)

test("Database:QueryList filters on a scalar store", function()
  assertEqual(#NS.Database:QueryList(FIXTURE, { store = "GUILD_BANK" }), 2)
end)

test("Database:QueryList filters on a store SET (multi-select)", function()
  local got = NS.Database:QueryList(FIXTURE, { store = { BANK = true, WARBAND_BANK = true } })
  assertEqual(#got, 2)
end)

test("Database:QueryList filters on direction", function()
  assertEqual(#NS.Database:QueryList(FIXTURE, { direction = "WITHDRAW" }), 1)
end)

test("Database:QueryList filters on kind", function()
  assertEqual(#NS.Database:QueryList(FIXTURE, { kind = "MONEY" }), 1)
end)

test("Database:QueryList filters on character", function()
  assertEqual(#NS.Database:QueryList(FIXTURE, { char = "Alt-Realm" }), 1)
end)

test("Database:QueryList filters on item sub-type", function()
  assertEqual(#NS.Database:QueryList(FIXTURE, { itemSubType = "Cloth" }), 2)
end)

test("Database:QueryList filters on an item sub-type SET (multi-select)", function()
  -- The gold row has no sub-type at all, so a sub-type filter must exclude it rather than match it.
  local got = NS.Database:QueryList(FIXTURE, { itemSubType = { Cloth = true, Flask = true } })
  assertEqual(#got, 3)
end)

test("Database:QueryList filters gold movements under the type 'Gold'", function()
  -- A gold row stores no itemType; it is filtered by the type the Type column shows for it.
  assertEqual(#NS.Database:QueryList(FIXTURE, { itemType = "Gold" }), 1)
  assertEqual(#NS.Database:QueryList(FIXTURE, { itemSubType = "Gold" }), 1)
end)

test("Database:QueryList mixes Gold with real item types in one set", function()
  local got = NS.Database:QueryList(FIXTURE, { itemType = { Gold = true, Consumable = true } })
  assertEqual(#got, 2)
end)

test("Database:QueryList filters on an exact quality", function()
  assertEqual(#NS.Database:QueryList(FIXTURE, { quality = 3 }), 1)
end)

test("Database:QueryList filters on a quality SET", function()
  assertEqual(#NS.Database:QueryList(FIXTURE, { quality = { [1] = true, [3] = true } }), 3)
end)

test("Database:QueryList filters on a from/to timestamp window, inclusive", function()
  assertEqual(#NS.Database:QueryList(FIXTURE, { from = NOW - 86400 }), 2)
  assertEqual(#NS.Database:QueryList(FIXTURE, { to = NOW - 2 * 86400 }), 2)
end)

test("Database:QueryList text search is a case-insensitive substring on the item name", function()
  assertEqual(#NS.Database:QueryList(FIXTURE, { text = "cloth" }), 2)
  assertEqual(#NS.Database:QueryList(FIXTURE, { text = "FLASK" }), 1)
end)

test("Database:QueryList combines filters with AND", function()
  local got = NS.Database:QueryList(FIXTURE, { store = "GUILD_BANK", kind = "MONEY" })
  assertEqual(#got, 1)
  assertEqual(got[1].itemName, "Gold")
end)

test("Database:QueryList returns nothing when the filters exclude everything", function()
  -- BAGS is a real Store member that can never be an entry's `store`: it is the counterparty of
  -- every movement, never its target. So it matches nothing, by construction.
  assertEqual(#NS.Database:QueryList(FIXTURE, { store = "BAGS" }), 0)
end)

-- ── Export / delete / prune / stats plumbing ───────────────────────────────────

test("Database:Export returns plain copies, not the stored tables", function()
  withLedger({ entry() }, function()
    local out = NS.Database:Export({})
    assertEqual(#out, 1)
    assertTrue(out[1] ~= NS.db.global.ledger[1], "a copy, so a consumer can't mutate the store")
    assertEqual(out[1].itemName, "Linen Cloth")
  end)
end)

test("Database:DeleteAt removes one entry and compacts the array", function()
  withLedger({ entry(), entry({ itemID = 4306 }) }, function()
    assertTrue(NS.Database:DeleteAt(1))
    assertEqual(NS.Database:Count(), 1)
    assertEqual(NS.Database:Ledger()[1].itemID, 4306)
  end)
end)

test("Database:DeleteAt rejects an out-of-range index", function()
  withLedger({ entry() }, function()
    assertFalse(NS.Database:DeleteAt(0))
    assertFalse(NS.Database:DeleteAt(99))
    assertFalse(NS.Database:DeleteAt("one"))
    assertEqual(NS.Database:Count(), 1)
  end)
end)

test("Database:Delete removes every entry matching the predicate", function()
  withLedger({ entry(), entry({ store = "GUILD_BANK" }), entry() }, function()
    assertEqual(NS.Database:Delete(function(e) return e.store == "BANK" end), 2)
    assertEqual(NS.Database:Count(), 1)
  end)
end)

test("Database:Purge empties the ledger and reports the count", function()
  withLedger({ entry(), entry() }, function()
    assertEqual(NS.Database:Purge(), 2)
    assertEqual(NS.Database:Count(), 0)
  end)
end)

-- The [Data] lines a call emits with logging on. debug-logging-§8 requires every user-initiated
-- delete or purge of stored data to be traced, and under standard v2.44.0 debug-logging-§10 that
-- includes recorded data such as this log. The line is the only headless witness that the trace
-- exists at all.
local function dataLines(fn)
  local savedDebug = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  local ok, err = pcall(fn)
  local out = {}
  for _, line in ipairs(NS.DebugLog.buffer) do
    if line:find("[Data]", 1, true) then out[#out + 1] = line end
  end
  NS.DebugLog:Clear()
  NS.State.debug = savedDebug
  if not ok then error(err, 0) end
  return out
end

test("Database:Delete traces one [Data] line naming how many entries it removed", function()
  -- The History table's right-click Delete reaches the log through here
  -- (modules/LedgerTable.lua). DeleteAt and Purge already traced; this was the one delete verb
  -- that did not.
  withLedger({ entry(), entry({ store = "GUILD_BANK" }), entry() }, function()
    local lines = dataLines(function()
      NS.Database:Delete(function(e) return e.store == "BANK" end)
    end)
    assertEqual(#lines, 1, "one line per delete act, not one per entry")
    assertTrue(lines[1]:find("delete removed 2 entries", 1, true) ~= nil,
      "the line names the count, got: " .. tostring(lines[1]))
  end)
end)

test("Database:Delete writes no line while logging is off", function()
  withLedger({ entry() }, function()
    local savedDebug = NS.State.debug
    NS.State.debug = false
    NS.DebugLog:Clear()
    NS.Database:Delete(function() return true end)
    local n = #NS.DebugLog.buffer
    NS.State.debug = savedDebug
    assertEqual(n, 0, "the trace is behind the debug gate")
  end)
end)

-- PruneOld compares against the addon's `time()`, which is the mock's clock — not os.time(). Using
-- the wrong clock here would make the window silently meaningless.
local MOCK_NOW = T.mocks.__now

test("Database:PruneOld drops entries past the retention window", function()
  local saved = NS.db.global.settings.retentionDays
  NS.db.global.settings.retentionDays = 30
  withLedger({ entry({ ts = MOCK_NOW }), entry({ ts = MOCK_NOW - 60 * 86400 }) }, function()
    assertEqual(NS.Database:PruneOld(), 1)
    assertEqual(NS.Database:Count(), 1)
  end)
  NS.db.global.settings.retentionDays = saved
end)

test("Database:PruneOld keeps everything when retention is Always (0)", function()
  local saved = NS.db.global.settings.retentionDays
  NS.db.global.settings.retentionDays = 0
  withLedger({ entry({ ts = MOCK_NOW - 900 * 86400 }) }, function()
    assertEqual(NS.Database:PruneOld(), 0)
    assertEqual(NS.Database:Count(), 1)
  end)
  NS.db.global.settings.retentionDays = saved
end)

-- The message is the expensive part: every LedgerChanged repaints the ledger window, the session
-- window and the Insights charts. PruneOld runs on every login, so a pass that aged nothing out
-- used to pay for three full repaints to report that nothing had happened.
test("Database:PruneOld broadcasts LedgerChanged only when a row actually went", function()
  local saved = NS.db.global.settings.retentionDays
  NS.db.global.settings.retentionDays = 30
  local sent, savedSend = 0, NS.bus.SendMessage
  NS.bus.SendMessage = function(self, msg, ...)
    if msg == "Ka0s_BankLedger_LedgerChanged" then sent = sent + 1 end
    return savedSend(self, msg, ...)
  end
  withLedger({ entry({ ts = MOCK_NOW }) }, function()
    assertEqual(NS.Database:PruneOld(), 0, "nothing is old enough to drop")
    assertEqual(sent, 0, "a prune that removed nothing must not repaint every view")
  end)
  withLedger({ entry({ ts = MOCK_NOW - 60 * 86400 }) }, function()
    assertEqual(NS.Database:PruneOld(), 1)
    assertEqual(sent, 1, "a prune that removed a row still broadcasts, exactly once")
  end)
  NS.bus.SendMessage = savedSend
  NS.db.global.settings.retentionDays = saved
end)

test("Database:StorageStats reports count, span and an estimated size", function()
  local now = MOCK_NOW
  withLedger({ entry({ ts = now - 3 * 86400 }), entry({ ts = now }) }, function()
    local s = NS.Database:StorageStats(now)
    assertEqual(s.count, 2)
    assertEqual(s.days, 3)
    assertTrue(s.bytes > 0, "a non-zero size estimate")
  end)
end)

test("Database:StorageStats reports a zero span for an empty ledger", function()
  withLedger({}, function()
    local s = NS.Database:StorageStats()
    assertEqual(s.count, 0)
    assertEqual(s.days, 0)
    assertEqual(s.bytes, 0)
  end)
end)

test("Database:ActiveLedger prefers the test dataset when one is published", function()
  withLedger({ entry() }, function()
    NS.State.testRecords = { entry(), entry() }
    assertEqual(#NS.Database:ActiveLedger(), 2)
    NS.State.testRecords = nil
    assertEqual(#NS.Database:ActiveLedger(), 1)
  end)
end)

-- ── Migrations ─────────────────────────────────────────────────────────────────

test("RunMigrations stamps a schema version onto a fresh database", function()
  -- Schema v2 shipped alongside this suite, so a freshly-initialized database is already migrated.
  assertEqual(NS.db.global.schemaVersion, 2)
end)

test("RunMigrations is idempotent — running it twice changes nothing", function()
  NS:RunMigrations()
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
end)

test("NS.MigrationSummary renders a readable one-liner", function()
  assertEqual(NS.MigrationSummary(1, 2, 7), "v1 -> v2, 7 rows touched")
end)

test("NS.InitSummary identifies the build, schema, profile and size", function()
  local s = NS.InitSummary()
  assertTrue(s:find("BankLedger", 1, true) ~= nil, "names the addon")
  assertTrue(s:find("schema v2", 1, true) ~= nil, "names the schema version")
  assertTrue(s:find("profile 'Default'", 1, true) ~= nil, "names the profile")
  assertTrue(s:find("entries", 1, true) ~= nil, "carries the entry count")
end)

-- ── Schema v1 -> v2: vendorPrice leaves the SavedVariables file --------------------

test("RunMigrations strips vendorPrice from every stored entry and bumps to v2", function()
  local saved, savedVer = NS.db.global.ledger, NS.db.global.schemaVersion
  NS.db.global.schemaVersion = 1
  NS.db.global.ledger = {
    { ts = 1, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
      itemID = 2589, itemName = "Linen Cloth", quantity = 10, vendorPrice = 20 },
    { ts = 2, char = "A-R", kind = "MONEY", direction = "DEPOSIT", store = "GUILD_BANK",
      itemName = "Gold", quantity = 50000 },
  }
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
  assertEqual(NS.db.global.ledger[1].vendorPrice, nil)
  assertEqual(NS.db.global.ledger[1].quantity, 10, "the rest of the entry is untouched")
  NS.db.global.ledger, NS.db.global.schemaVersion = saved, savedVer
end)

test("RunMigrations is idempotent on an already-migrated database", function()
  local saved, savedVer = NS.db.global.ledger, NS.db.global.schemaVersion
  NS.db.global.schemaVersion = 2
  NS.db.global.ledger = { { ts = 1, kind = "ITEM", quantity = 3 } }
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
  assertEqual(NS.db.global.ledger[1].quantity, 3)
  NS.db.global.ledger, NS.db.global.schemaVersion = saved, savedVer
end)

-- This migration runs against real user SavedVariables and a ledger is irreplaceable, so its
-- boundary cases are pinned here rather than left to inspection.

test("RunMigrations treats a database with no schemaVersion key at all as v1", function()
  local saved, savedVer = NS.db.global.ledger, NS.db.global.schemaVersion
  NS.db.global.schemaVersion = nil
  NS.db.global.ledger = {
    { ts = 1, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
      itemID = 2589, itemName = "Linen Cloth", quantity = 10, vendorPrice = 20 },
  }
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2, "an absent version is treated as v1 and upgraded")
  assertEqual(NS.db.global.ledger[1].vendorPrice, nil)
  NS.db.global.ledger, NS.db.global.schemaVersion = saved, savedVer
end)

-- The next three read the [Migrate] line rather than the stamp. That is deliberate: the stamp alone
-- cannot tell a fresh install from a database that was walked, because BOTH end at
-- NS.SCHEMA_VERSION. Asserting on the stamp, the empty-store case below stays green under the exact
-- mistake it exists to catch — seeding unconditionally at 1, which migrates an empty ledger and then
-- stamps it current anyway. The debug line is the only headless witness that the pass ran, and it is
-- also what docs/smoke-tests.md reads in the client, so the two checks now agree on their evidence.

local function migrationLines(fn)
  local savedDebug = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  local ok, err = pcall(fn)
  local out = {}
  for _, line in ipairs(NS.DebugLog.buffer) do
    if line:find("[Migrate]", 1, true) then out[#out + 1] = line end
  end
  NS.DebugLog:Clear()
  NS.State.debug = savedDebug
  if not ok then error(err, 0) end
  return out
end

test("RunMigrations announces the v1->v2 pass the smoke step reads", function()
  -- The exact string docs/smoke-tests.md S-25 looks for in the client. Pinned here so the in-game
  -- step has a headless twin and a rename of MigrationSummary cannot silently break it.
  -- red under: the disarmed runner this item removed — no line at all was emitted.
  local saved, savedVer = NS.db.global.ledger, NS.db.global.schemaVersion
  local lines = migrationLines(function()
    NS.db.global.schemaVersion = nil
    NS.db.global.ledger = {
      { ts = 1, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
        itemID = 2589, itemName = "Linen Cloth", quantity = 10, vendorPrice = 20 },
    }
    NS:RunMigrations()
  end)
  NS.db.global.ledger, NS.db.global.schemaVersion = saved, savedVer
  assertEqual(#lines, 1, "exactly one migration line")
  assertTrue(lines[1]:find("v1 -> v2, 1 rows touched", 1, true) ~= nil,
    "the line names the ladder and the row count: " .. tostring(lines[1]))
end)

test("RunMigrations stamps a stamp-less EMPTY store at the current version without replaying v1->v2",
function()
  -- The other half of the discriminator, and the requirement the retired shipped default existed to
  -- meet. A fresh install carries no stamp and no entries, and must not be read as a pre-stamp
  -- database: the walk would find nothing and still report a migration that never happened.
  -- red under: seeding unconditionally at 1.
  local saved, savedVer = NS.db.global.ledger, NS.db.global.schemaVersion
  local lines = migrationLines(function()
    NS.db.global.schemaVersion = nil
    NS.db.global.ledger = {}
    NS:RunMigrations()
  end)
  local after = NS.db.global.schemaVersion
  NS.db.global.ledger, NS.db.global.schemaVersion = saved, savedVer
  assertEqual(after, NS.SCHEMA_VERSION,
    "an empty unstamped store is a fresh install and starts at the current shape")
  assertEqual(#lines, 0, "and no pass ran, so nothing was announced")
end)

test("RunMigrations seeds a stamp-less store whose ledger is nil, without raising", function()
  -- The ledger is the discriminator, so the discriminator has to survive the states the ledger is
  -- actually in — and nil is one this suite already models a case for. Kept apart from the empty-
  -- table case above because the obvious tightening, `next(g.ledger) == nil`, passes that one and
  -- raises on this one, against a real SavedVariables file at login.
  -- red under: dropping the `g.ledger == nil` clause from the discriminator.
  local saved, savedVer = NS.db.global.ledger, NS.db.global.schemaVersion
  NS.db.global.schemaVersion = nil
  NS.db.global.ledger = nil
  local ok
  local lines = migrationLines(function() ok = pcall(function() NS:RunMigrations() end) end)
  local after = NS.db.global.schemaVersion
  NS.db.global.ledger, NS.db.global.schemaVersion = saved, savedVer
  assertTrue(ok, "must not raise on a nil ledger")
  assertEqual(after, NS.SCHEMA_VERSION, "nothing to migrate, so nothing to do")
  assertEqual(#lines, 0, "and no pass ran, so nothing was announced")
end)

test("RunMigrations survives a database with no ledger at all", function()
  local saved, savedVer = NS.db.global.ledger, NS.db.global.schemaVersion
  NS.db.global.schemaVersion = 1
  NS.db.global.ledger = nil
  local ok, err = pcall(function() NS:RunMigrations() end)
  assertTrue(ok, "must not raise on a nil ledger: " .. tostring(err))
  assertEqual(NS.db.global.schemaVersion, 2)
  assertEqual(NS.db.global.ledger, nil, "no ledger is fabricated where none existed")
  NS.db.global.ledger, NS.db.global.schemaVersion = saved, savedVer
end)

test("RunMigrations never downgrades a future schema version", function()
  local saved, savedVer = NS.db.global.ledger, NS.db.global.schemaVersion
  NS.db.global.schemaVersion = 3
  NS.db.global.ledger = {
    { ts = 1, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
      itemID = 2589, itemName = "Linen Cloth", quantity = 10, vendorPrice = 20 },
  }
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 3, "a future version is left exactly as it was")
  assertEqual(NS.db.global.ledger[1].vendorPrice, 20,
    "a future schema's entries are not touched by the v1->v2 step")
  NS.db.global.ledger, NS.db.global.schemaVersion = saved, savedVer
end)

test("Database:Export never emits a vendorPrice field", function()
  local saved = NS.db.global.ledger
  NS.db.global.ledger = {
    { ts = 1, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
      itemID = 2589, itemName = "Linen Cloth", quantity = 10, vendorPrice = 20 },
  }
  local out = NS.Database:Export()
  assertEqual(out[1].vendorPrice, nil)
  assertEqual(out[1].itemName, "Linen Cloth")
  NS.db.global.ledger = saved
end)

-- ── Schema version ─────────────────────────────────────────────────────────────

test("Database: schemaVersion is NOT a shipped AceDB default", function()
  -- This case is what F-008's became. That one asserted the shipped default EQUALLED the runner's
  -- target, and the equality is precisely what broke the runner: AceDB strips a stored value still
  -- equal to its default at logout, so the stamp came back as the target and `< NS.SCHEMA_VERSION`
  -- was never true (BANKLEDGER-R-02). There is no default left to keep in step; what needs pinning
  -- now is that nobody reinstates one, because a reinstated default is silent — every suite here
  -- stays green and only a real player's logout can tell.
  -- red under: putting `schemaVersion = NS.SCHEMA_VERSION` back into NS.defaults.global.
  assertEqual(NS.defaults.global.schemaVersion, nil)
end)

test("Database: a fresh database needs no migration", function()
  -- Seeded explicitly rather than read off NS.defaults.global, which no longer carries the key.
  local saved = NS.db.global.schemaVersion
  NS.db.global.schemaVersion = NS.SCHEMA_VERSION
  NS:RunMigrations()
  local after = NS.db.global.schemaVersion
  NS.db.global.schemaVersion = saved
  assertEqual(after, NS.SCHEMA_VERSION, "already current, and left alone")
end)

test("Database: an older database is migrated up to the current version", function()
  local savedVersion, savedLedger = NS.db.global.schemaVersion, NS.db.global.ledger
  NS.db.global.schemaVersion = 1
  NS.db.global.ledger = { { kind = "ITEM", itemID = 2589, vendorPrice = 20 } }
  NS:RunMigrations()
  local version, price = NS.db.global.schemaVersion, NS.db.global.ledger[1].vendorPrice
  NS.db.global.schemaVersion, NS.db.global.ledger = savedVersion, savedLedger
  assertEqual(version, NS.SCHEMA_VERSION)
  assertEqual(price, nil, "the v1->v2 pass still strips vendor value")
end)
