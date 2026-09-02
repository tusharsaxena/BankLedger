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

test("Util.ClassIconMarkup honors a requested size", function()
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

-- ── Wowhead URL ────────────────────────────────────────────────────────────────
-- The CSV export's trailing column. A real link's bonus IDs are what make the URL resolve to the
-- variant that moved rather than to the base item, so they are the thing worth pinning down.

local GEAR_LINK = "|cffa335ee|Hitem:151300::::::::80:250::5:5:12801:13440:6652:13577:12699"
  .. ":1:28:2437|h[Sample Helm]|h|r"

test("Util.WowheadURL carries every bonus id from the item link", function()
  assertEqual(NS.Util.WowheadURL({ itemID = 151300, itemLink = GEAR_LINK }),
    "https://www.wowhead.com/item=151300?bonus=12801:13440:6652:13577:12699")
end)

test("Util.WowheadURL stops at the declared bonus count", function()
  -- The fields after the bonus list are crafting modifiers (here 1:28:2437) and belong to a
  -- different list -- reading past numBonusIDs would smuggle them into the URL as bonuses.
  local url = NS.Util.WowheadURL({ itemID = 151300, itemLink = GEAR_LINK })
  assertEqual(url:find("2437", 1, true), nil, "no modifier leaks into the bonus list")
end)

test("Util.WowheadURL omits the bonus query for an item that has none", function()
  assertEqual(NS.Util.WowheadURL({ itemID = 2589, itemLink = "|cff9d9d9d|Hitem:2589::::::::80:250"
    .. "::::::|h[Linen Cloth]|h|r" }), "https://www.wowhead.com/item=2589")
end)

test("Util.WowheadURL falls back to the stored item id when there is no link", function()
  assertEqual(NS.Util.WowheadURL({ itemID = 2589 }), "https://www.wowhead.com/item=2589")
end)

test("Util.WowheadURL accepts a bare item string as well as a full hyperlink", function()
  assertEqual(NS.Util.WowheadURL({ itemLink = "item:151300::::::::80:250::5:2:12801:13440" }),
    "https://www.wowhead.com/item=151300?bonus=12801:13440")
end)

test("Util.WowheadURL returns nothing for a row with no item at all", function()
  -- A gold movement, and a defensive nil.
  assertEqual(NS.Util.WowheadURL({ kind = "MONEY", itemName = "Gold" }), "")
  assertEqual(NS.Util.WowheadURL(nil), "")
end)

-- ── Master controls: the three settings the tab ADDED, and the code that honors them ──────────
--
-- A setting that is declared and not honored is worse than one that is absent, so each of these
-- drives the real drawing seam rather than the row. `Master scale` needs no case of its own here:
-- it is the pre-existing settings.windowScale, promoted rather than added, and the cases that
-- already covered it are unchanged.

--- A frame stand-in that records the three calls Util.ApplyMasterFrame makes.
local function fakeFrame()
  local f = { shown = false }
  f.SetScale   = function(_, v) f.scale = v end
  f.SetAlpha   = function(_, v) f.alpha = v end
  f.SetMovable = function(_, v) f.movable = v end
  f.IsShown    = function() return f.shown end
  return f
end

--- Run `fn` with the master settings temporarily set, then put every one of them back.
local function withSettings(values, fn)
  local g = NS.db.global.settings
  local saved = {}
  for k, v in pairs(values) do saved[k] = g[k]; g[k] = v end
  local ok, err = pcall(fn)
  for k in pairs(values) do g[k] = saved[k] end
  if not ok then error(err, 0) end
end

test("Util.ApplyMasterFrame applies scale, alpha AND the lock to one frame", function()
  -- Dies under: dropping any one of the three calls, or reading `windowScale` for the alpha.
  local f = fakeFrame()
  withSettings({ windowScale = 1.25, alpha = 0.4, locked = true }, function()
    NS.Util.ApplyMasterFrame(f)
  end)
  assertEqual(f.scale, 1.25)
  assertEqual(f.alpha, 0.4)
  assertEqual(f.movable, false, "Lock frame is expressed as SetMovable(false)")

  local g = fakeFrame()
  withSettings({ windowScale = 1.0, alpha = 1.0, locked = false }, function()
    NS.Util.ApplyMasterFrame(g)
  end)
  assertEqual(g.movable, true, "an unlocked frame must be movable again")
end)

test("Util.ApplyMasterFrame clamps a master alpha that would hide the addon outright", function()
  -- Hand-editable, like the row tints. A stored 0 is an addon that is invisible with no way back to
  -- the panel that set it, and a stored 5 is a window that never fades and reads as a dead slider.
  local f = fakeFrame()
  withSettings({ alpha = 0 }, function() NS.Util.ApplyMasterFrame(f) end)
  assertEqual(f.alpha, 0.1, "0 clamps to the lowest alpha you can still find on screen")
  withSettings({ alpha = 5 }, function() NS.Util.ApplyMasterFrame(f) end)
  assertEqual(f.alpha, 1)
  withSettings({ alpha = "opaque" }, function() NS.Util.ApplyMasterFrame(f) end)
  assertEqual(f.alpha, 1, "a non-number falls back to fully opaque, never to invisible")
end)

test("Util: every stop the Master alpha slider offers is a stop the drawing code draws", function()
  -- STEP 4.3, the declared-vs-honored rule. The composer's canonical row offers min = 0 while
  -- ApplyMasterFrame refuses anything under NS.Constants.MASTER_ALPHA_MIN, so an undecorated row
  -- would put two stops on the slider (0.00 and 0.05) that both render at 0.1 — a control whose
  -- bottom end visibly does nothing.
  --
  -- Dies under: dropping `min` from MASTER_DECOR["settings.alpha"] (the row falls back to the
  -- composer's 0 and the walk below finds a stop the clamp moved), or changing the clamp's floor
  -- without moving the constant both halves read.
  local row = NS.Schema:FindRow("settings.alpha")
  assertEqual(row.min, NS.Constants.MASTER_ALPHA_MIN,
    "the declared minimum must BE the honored floor, not merely near it")

  local f = fakeFrame()
  local stop = row.min
  while stop <= row.max + 1e-9 do
    local want = stop
    withSettings({ alpha = want }, function() NS.Util.ApplyMasterFrame(f) end)
    assertTrue(math.abs(f.alpha - want) < 1e-9,
      ("slider stop %.2f draws at %.2f — the row offers a value the clamp overrides")
        :format(want, f.alpha))
    stop = stop + row.step
  end
end)

test("Util.VisibilityAllows answers all four modes against the combat state", function()
  -- The dropdown exists because a boolean can only ever answer two of the four (options-ui-§15).
  --
  -- Dies under: collapsing inCombat/outOfCombat to one branch, or ignoring InCombatLockdown.
  local savedLockdown = mocks.InCombatLockdown
  local inCombat = false
  mocks.InCombatLockdown = function() return inCombat end

  local function allows(mode)
    local out
    withSettings({ visibility = mode }, function() out = NS.Util.VisibilityAllows() end)
    return out
  end

  assertTrue(allows("always"))
  assertFalse(allows("never"))
  assertFalse(allows("inCombat"), "out of combat, 'Only in combat' hides")
  assertTrue(allows("outOfCombat"))
  inCombat = true
  assertTrue(allows("inCombat"))
  assertFalse(allows("outOfCombat"), "in combat, 'Only out of combat' hides")
  assertTrue(allows("always"))
  -- A value nobody recognises shows the addon, so a corrupt key never costs the player the panel.
  assertTrue(allows("whenever"))

  mocks.InCombatLockdown = savedLockdown
end)

test("Util.ApplyVisibility hides only what was up, and re-shows only what IT hid", function()
  -- The transition half of the rule. Re-showing a window the player closed themselves would be the
  -- addon reopening a window on every combat drop, which is the failure the ledger exists to avoid.
  --
  -- Dies under: dropping State.hiddenByVisibility and re-showing everything on the way back.
  local savedLockdown = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return false end
  for k in pairs(NS.State.hiddenByVisibility) do NS.State.hiddenByVisibility[k] = nil end

  NS.Browser:Show()
  assertTrue(NS.Browser:GetWindow():IsShown(), "the ledger window must be up to start with")
  assertFalse(NS.SessionWindow:IsShown(), "the session window is deliberately left closed")

  withSettings({ visibility = "inCombat" }, function() NS.Util.ApplyVisibility() end)
  assertFalse(NS.Browser:GetWindow():IsShown(), "the rule must take the open window")
  assertEqual(NS.State.hiddenByVisibility.Browser, true)
  assertEqual(NS.State.hiddenByVisibility.SessionWindow, nil,
    "a window that was already closed must not be remembered")

  NS.Util.ApplyVisibility()   -- back to `always`
  assertTrue(NS.Browser:GetWindow():IsShown(), "the rule must put back what it took")
  assertEqual(NS.State.hiddenByVisibility.Browser, nil)
  assertFalse(NS.SessionWindow:IsShown(), "and must NOT open the one it never touched")

  NS.Browser:Hide()
  mocks.InCombatLockdown = savedLockdown
end)

test("Browser:Show refuses while General visibility says no", function()
  -- The gate at the door, not just at the transition: `never` has no transition to ride.
  local savedLockdown = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return false end
  NS.Browser:Hide()
  withSettings({ visibility = "never" }, function() NS.Browser:Show() end)
  local f = NS.Browser:GetWindow()
  assertFalse(f ~= nil and f:IsShown(), "the window opened against the visibility rule")
  NS.Browser:Show()
  assertTrue(NS.Browser:GetWindow():IsShown(), "and it opens again once the rule allows it")
  NS.Browser:Hide()
  mocks.InCombatLockdown = savedLockdown
end)

test("Util.ResetWindowPositions clears BOTH windows' stored geometry", function()
  -- The Master controls tab's "Reset position" button and the General page's Defaults button share
  -- this one body. Before the tab existed the act was only ever reachable as a side effect of the
  -- second, which is why it is a named seam now rather than two lines in P:RestoreDefaults.
  NS.db.global.settings.window = { x = 400, y = 300 }
  NS.db.global.settings.sessionWindow = { x = 120, y = 90 }
  NS.Util.ResetWindowPositions()
  assertEqual(next(NS.db.global.settings.window or {}), nil, "the ledger window's geometry survived")
  assertEqual(next(NS.db.global.settings.sessionWindow or {}), nil,
    "the session window's geometry survived")
end)
