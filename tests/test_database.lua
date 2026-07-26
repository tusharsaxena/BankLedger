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
    itemType = "Tradegoods", itemSubType = "Cloth", vendorPrice = 20,
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
          itemType = "Consumable", vendorPrice = 5000, quantity = 2, ts = NOW - 3 * 86400 }),
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
  assertEqual(#NS.Database:QueryList(FIXTURE, { store = "VOID_STORAGE" }), 0)
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

test("Database:ActiveLedger prefers the preview dataset when one is published", function()
  withLedger({ entry() }, function()
    NS.State.testRecords = { entry(), entry() }
    assertEqual(#NS.Database:ActiveLedger(), 2)
    NS.State.testRecords = nil
    assertEqual(#NS.Database:ActiveLedger(), 1)
  end)
end)

-- ── Migrations ─────────────────────────────────────────────────────────────────

test("RunMigrations stamps a schema version onto a fresh database", function()
  assertEqual(NS.db.global.schemaVersion, 1)
end)

test("RunMigrations is idempotent — running it twice changes nothing", function()
  NS:RunMigrations()
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 1)
end)

test("NS.MigrationSummary renders a readable one-liner", function()
  assertEqual(NS.MigrationSummary(1, 2, 7), "v1 -> v2, 7 rows touched")
end)

test("NS.InitSummary identifies the build, schema, profile and size", function()
  local s = NS.InitSummary()
  assertTrue(s:find("BankLedger", 1, true) ~= nil, "names the addon")
  assertTrue(s:find("schema v1", 1, true) ~= nil, "names the schema version")
  assertTrue(s:find("profile 'Default'", 1, true) ~= nil, "names the profile")
  assertTrue(s:find("entries", 1, true) ~= nil, "carries the entry count")
end)
