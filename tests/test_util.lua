local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

test("Util.PlayerKey joins name and realm with spaces stripped", function()
  assertEqual(NS.Util.PlayerKey(), "Mock-Realm")
end)

test("Util.SplitPath splits a dotted settings path", function()
  local parts = NS.Util.SplitPath("settings.window.scale")
  assertEqual(#parts, 3)
  assertEqual(parts[1], "settings")
  assertEqual(parts[3], "scale")
end)

test("Util.SplitPath returns a single component for a bare key", function()
  local parts = NS.Util.SplitPath("enabled")
  assertEqual(#parts, 1)
  assertEqual(parts[1], "enabled")
end)

test("Util.FormatDate uses the locale-unambiguous DD-MMM-YYYY form", function()
  local s = NS.Util.FormatDate(0)
  assertTrue(s:match("^%d%d%-%a%a%a%-%d%d%d%d$") ~= nil, "DD-MMM-YYYY, got " .. s)
end)

test("Util.FormatClock renders HH:MM", function()
  assertTrue(NS.Util.FormatClock(0):match("^%d%d:%d%d$") ~= nil)
end)

test("Util.PlainMoney always renders gold, silver and copper parts", function()
  assertEqual(NS.Util.PlainMoney(1234567), "123g 45s 67c")
end)

test("Util.PlainMoney renders zero rather than an empty string", function()
  assertEqual(NS.Util.PlainMoney(0), "0g 0s 0c")
end)

test("Util.PlainMoney renders nil as empty", function()
  assertEqual(NS.Util.PlainMoney(nil), "")
end)

test("Util.FormatMoney is blank for nothing and compact for a real amount", function()
  assertEqual(NS.Util.FormatMoney(0), "")
  assertEqual(NS.Util.FormatMoney(nil), "")
  assertEqual(NS.Util.FormatMoney(10203), "1g 2s 3c")
end)

test("Util.EntryType is the stored item type for an item movement", function()
  assertEqual(NS.Util.EntryType({ kind = "ITEM", itemType = "Consumable" }), "Consumable")
  assertEqual(NS.Util.EntrySubType({ kind = "ITEM", itemSubType = "Flask" }), "Flask")
end)

test("Util.EntryType is Gold for a gold movement, which stores no type", function()
  -- This is what lets a "Gold" filter, group and column cell all mean the same thing.
  assertEqual(NS.Util.EntryType({ kind = "MONEY" }), "Gold")
  assertEqual(NS.Util.EntrySubType({ kind = "MONEY" }), "Gold")
end)

test("Util.EntryType is blank for an uncached item and for nothing at all", function()
  assertEqual(NS.Util.EntryType({ kind = "ITEM" }), "")
  assertEqual(NS.Util.EntrySubType({ kind = "ITEM" }), "")
  assertEqual(NS.Util.EntryType(nil), "")
  assertEqual(NS.Util.EntrySubType(nil), "")
end)

test("Util.ClassIconMarkup carries the class's slice of the icon sheet", function()
  -- The tcoords are fractions of a 256×256 sheet; the markup wants them in pixels.
  assertEqual(NS.Util.ClassIconMarkup("MAGE"),
    "|TInterface\\TargetingFrame\\UI-Classes-Circles:12:12:0:0:256:256:64:127:64:128|t ")
end)

test("Util.ClassIconMarkup honours a requested size", function()
  assertTrue(NS.Util.ClassIconMarkup("ROGUE", 16):find(":16:16:", 1, true) ~= nil)
end)

test("Util.ClassIconMarkup is empty for an unknown or missing class", function()
  -- Callers concatenate the result unconditionally, so it must never be nil.
  assertEqual(NS.Util.ClassIconMarkup(nil), "")
  assertEqual(NS.Util.ClassIconMarkup("NOTACLASS"), "")
end)

test("Util.FormatBytes steps through B, kB and MB", function()
  assertEqual(NS.Util.FormatBytes(820), "820 B")
  assertEqual(NS.Util.FormatBytes(2048), "2.0 kB")
  assertEqual(NS.Util.FormatBytes(3 * 1024 * 1024), "3.0 MB")
end)

test("Util.RangeFrom returns nil for the no-bound 'all' range", function()
  assertEqual(NS.Util.RangeFrom("all"), nil)
  assertEqual(NS.Util.RangeFrom(nil), nil)
end)

test("Util.RangeFrom windows are ordered today > 7d > 30d", function()
  local today, d7, d30 = NS.Util.RangeFrom("today"), NS.Util.RangeFrom("7d"), NS.Util.RangeFrom("30d")
  assertTrue(today > d7, "today starts later than 7 days ago")
  assertTrue(d7 > d30, "7 days ago is later than 30 days ago")
end)

test("Util.EntryValue is the amount itself for a gold movement", function()
  assertEqual(NS.Util.EntryValue({ kind = "MONEY", quantity = 12345 }), 12345)
end)

test("Util.EntryValue is vendor price times stack for an item movement", function()
  assertEqual(NS.Util.EntryValue({ kind = "ITEM", quantity = 4, vendorPrice = 250 }), 1000)
end)

test("Util.EntryValue is zero for an unpriced item", function()
  assertEqual(NS.Util.EntryValue({ kind = "ITEM", quantity = 4 }), 0)
end)

test("Util.EntryValue is zero for nothing at all", function()
  assertEqual(NS.Util.EntryValue(nil), 0)
end)

test("Util.SignedValue makes a deposit positive and a withdrawal negative", function()
  local e = { kind = "MONEY", quantity = 500 }
  e.direction = "DEPOSIT"
  assertEqual(NS.Util.SignedValue(e), 500)
  e.direction = "WITHDRAW"
  assertEqual(NS.Util.SignedValue(e), -500)
end)

-- ── Secret-safe printer (events-frames-taint-§8) ────────────────────────────────

test("NS.IsConcatSafe accepts an ordinary value", function()
  assertTrue(NS.IsConcatSafe("hello"))
  assertTrue(NS.IsConcatSafe(42))
end)

test("NS.IsConcatSafe rejects a value table.concat would refuse", function()
  -- A table is the closest headless stand-in for a combat "secret": table.concat raises on it, which
  -- is exactly the operation the detector must probe (a `..` probe would wrongly pass one through).
  assertFalse(NS.IsConcatSafe({}))
end)

test("NS.SafeToString substitutes a sentinel for an unconcatenable value", function()
  assertEqual(NS.SafeToString({}), "<secret>")
end)

test("NS.SafeToString passes nil and booleans through unmasked", function()
  assertEqual(NS.SafeToString(nil), "nil")
  assertEqual(NS.SafeToString(true), "true")
  assertEqual(NS.SafeToString(false), "false")
end)

test("NS.Print prefixes the cyan [BL] tag and space-joins its arguments", function()
  local captured
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) captured = msg end
  NS.Print("hello", 42)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  assertEqual(captured, "|cff00ffff[BL]|r hello 42")
end)

test("NS.Print never raises on a value that would break table.concat", function()
  local captured
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) captured = msg end
  NS.Print("value", {})
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  assertEqual(captured, "|cff00ffff[BL]|r value <secret>")
end)

test("NS.Print survives the AceConsole embed (architecture-§2)", function()
  -- NewAddon(NS, …, "AceConsole-3.0") stamps AceConsole's :Print onto NS, clobbering the custom
  -- printer. core/BankLedger.lua reclaims it from NS.Util.print; if that reclaim were ever dropped
  -- this test fails, because the AceConsole form has no cyan tag and a trailing colon.
  assertEqual(NS.Print, NS.Util.print, "NS.Print is the reclaimed secret-safe printer")
end)
