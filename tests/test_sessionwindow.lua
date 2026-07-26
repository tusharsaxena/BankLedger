local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local SW = NS.SessionWindow
local NOW = 1770000000

local function e(over)
  local x = {
    ts = NOW, char = "Mock-Realm", classFile = "MAGE",
    kind = "ITEM", direction = "DEPOSIT", store = "BANK",
    itemID = 2589, itemName = "Linen Cloth", quality = 1,
    itemType = "Tradegoods", itemSubType = "Cloth", vendorPrice = 20, quantity = 10,
  }
  for k, v in pairs(over or {}) do x[k] = v end
  return x
end

-- Put the module back into a known state: no session, no rows, the window setting on.
local function reset()
  NS.db.global.ledger = {}
  NS.db.global.settings.showSessionWindow = true
  NS.State.sessionEntries = {}
  NS.State.sessionActive = false
  SW.previewSession = false
end

-- ── Column model ───────────────────────────────────────────────────────────────

test("SessionWindow drops the Date, Time and Character columns", function()
  local present = {}
  for _, key in ipairs(SW.COLUMN_KEYS) do present[key] = true end
  assertFalse(present.date, "Date column must not appear in the session view")
  assertFalse(present.time, "Time column must not appear in the session view")
  assertFalse(present.char, "Character column must not appear in the session view")
end)

test("SessionWindow keeps the seven data columns, in table order", function()
  assertEqual(table.concat(SW.COLUMN_KEYS, ","),
    "direction,store,item,qty,quality,type,subtype")
end)

test("SessionWindow resolves every column key against the shared LedgerTable spec", function()
  local cols = SW:Columns()
  assertEqual(#cols, #SW.COLUMN_KEYS, "every key must resolve to a real column")
  for _, col in ipairs(cols) do
    assertTrue(type(col.valueFn) == "function", "column " .. col.key .. " needs a valueFn")
  end
end)

test("SessionWindow:MinFrameWidth covers every column plus the gutter and margins", function()
  -- Fixed columns at full width + the Item column at its 150px minimum + one 8px gap each
  -- + a 24px scrollbar gutter + 12px of pane margin.
  local expected = 0
  for _, col in ipairs(SW:Columns()) do
    expected = expected + (col.flex and 150 or col.width) + 8
  end
  expected = math.ceil(expected + 24 + 12)
  assertEqual(SW:MinFrameWidth(), expected)
  -- It is narrower than the History window, which carries four more columns and a toolbar.
  assertTrue(SW:MinFrameWidth() < NS.Browser:MinWidth(),
    "the session window should be narrower than the full ledger window")
end)

test("SessionWindow:ColumnLayout lays columns left to right with the Item column flexing", function()
  local slots = SW:ColumnLayout()
  assertEqual(#slots, #SW.COLUMN_KEYS)
  assertEqual(slots[1].x, 0, "the first column starts at the left margin")
  for i = 2, #slots do
    assertTrue(slots[i].x > slots[i - 1].x, "columns must advance left to right")
  end
  for _, slot in ipairs(slots) do
    if slot.col.flex then
      assertTrue(slot.width >= 150, "the flex column never drops below its minimum")
    else
      assertEqual(slot.width, slot.col.width, "a fixed column keeps its declared width")
    end
  end
end)

-- ── Session lifecycle ──────────────────────────────────────────────────────────

test("SessionWindow:StartSession arms the session and clears the previous visit", function()
  reset()
  NS.State.sessionEntries = { e() }
  SW:StartSession("BANK_FRAME")
  assertTrue(NS.State.sessionActive, "the session must be active")
  assertEqual(#SW:Entries(), 0, "a new visit starts with an empty table")
  SW:EndSession()
end)

test("SessionWindow:EndSession disarms and drops the rows", function()
  reset()
  SW:StartSession("BANK_FRAME")
  SW:OnEntryAdded(e())
  assertEqual(#SW:Entries(), 1)
  SW:EndSession()
  assertFalse(NS.State.sessionActive, "the session must be closed")
  assertEqual(#SW:Entries(), 0, "session rows are dropped, never persisted")
  assertFalse(SW:IsShown(), "the window closes with the bank frame")
end)

test("SessionWindow collects movements only while a session is open", function()
  reset()
  SW:OnEntryAdded(e())
  assertEqual(#SW:Entries(), 0, "a movement outside a session is not a session movement")
  SW:StartSession("BANK_FRAME")
  SW:OnEntryAdded(e())
  SW:OnEntryAdded(e({ direction = "WITHDRAW" }))
  assertEqual(#SW:Entries(), 2)
  SW:EndSession()
  SW:OnEntryAdded(e())
  assertEqual(#SW:Entries(), 0, "nothing is collected after the frame closes")
end)

test("SessionWindow shows newest movement first", function()
  reset()
  SW:StartSession("BANK_FRAME")
  SW:OnEntryAdded(e({ itemName = "First" }))
  SW:OnEntryAdded(e({ itemName = "Second" }))
  SW:OnEntryAdded(e({ itemName = "Third" }))
  local list = SW:DisplayList()
  assertEqual(list[1].itemName, "Third")
  assertEqual(list[3].itemName, "First")
  SW:EndSession()
end)

test("SessionWindow:DisplayList never reorders the session list in place", function()
  reset()
  SW:StartSession("BANK_FRAME")
  SW:OnEntryAdded(e({ itemName = "First" }))
  SW:OnEntryAdded(e({ itemName = "Second" }))
  SW:DisplayList()
  assertEqual(SW:Entries()[1].itemName, "First", "capture order is preserved")
  SW:EndSession()
end)

-- ── The bus wiring (the real seam Ledger fires) ────────────────────────────────

test("SessionChanged from the Ledger opens and closes a session", function()
  reset()
  NS.bus:SendMessage("Ka0s_BankLedger_SessionChanged", true, "BANK_FRAME")
  assertTrue(NS.State.sessionActive, "an open frame starts a session")
  NS.bus:SendMessage("Ka0s_BankLedger_SessionChanged", false, "BANK_FRAME")
  assertFalse(NS.State.sessionActive, "a closed frame ends it")
end)

test("Ledger:OpenContext and CloseContext drive the session window", function()
  reset()
  NS.Ledger:OpenContext("BANK_FRAME")
  assertTrue(NS.State.sessionActive, "arming the differ starts a banking session")
  NS.Ledger:CloseContext()
  assertFalse(NS.State.sessionActive, "disarming ends it")
end)

test("a recorded movement reaches the session window through EntryAdded", function()
  reset()
  NS.Ledger:OpenContext("BANK_FRAME")
  NS.Database:Add(e())
  assertEqual(#SW:Entries(), 1, "the live capture path feeds the session view")
  NS.Ledger:CloseContext()
end)

-- ── The setting ────────────────────────────────────────────────────────────────

test("the disable setting suppresses the window without suppressing collection", function()
  reset()
  NS.Schema:Set("settings.showSessionWindow", false)
  assertFalse(SW:Enabled())
  SW:StartSession("BANK_FRAME")
  assertFalse(SW:IsShown(), "the window stays closed")
  SW:OnEntryAdded(e())
  assertEqual(#SW:Entries(), 1, "capture and collection are untouched by a display setting")
  SW:EndSession()
  NS.Schema:Set("settings.showSessionWindow", true)
  assertTrue(SW:Enabled())
end)

test("the window stays shut while capture itself is off", function()
  -- With capture off nothing can ever be recorded, so a live window is guaranteed to stay empty for
  -- the whole visit — which reads as broken rather than as switched off.
  reset()
  NS.Schema:Set("settings.enabled", false)
  assertFalse(SW:Enabled())
  SW:StartSession("BANK_FRAME")
  assertFalse(SW:IsShown())
  SW:EndSession()
  NS.Schema:Set("settings.enabled", true)
  assertTrue(SW:Enabled())
end)

test("settings.showSessionWindow defaults to enabled", function()
  assertEqual(NS.Schema:Default("settings.showSessionWindow"), true)
end)

test("turning the setting off closes an open session window", function()
  reset()
  SW:StartSession("BANK_FRAME")
  assertTrue(SW:IsShown(), "a session opens the window while the setting is on")
  NS.Schema:Set("settings.showSessionWindow", false)
  assertFalse(SW:IsShown(), "the SettingsChanged reaction closes it immediately")
  NS.Schema:Set("settings.showSessionWindow", true)
  SW:EndSession()
end)

-- ── Pruning ────────────────────────────────────────────────────────────────────

test("SessionWindow:PruneMissing drops rows deleted from the ledger", function()
  reset()
  NS.Ledger:OpenContext("BANK_FRAME")
  local keep = e({ itemName = "Kept" })
  local gone = e({ itemName = "Deleted" })
  NS.Database:Add(keep)
  NS.Database:Add(gone)
  assertEqual(#SW:Entries(), 2)
  NS.Database:Delete(function(r) return r == gone end)
  assertEqual(#SW:Entries(), 1, "a deleted movement cannot stay on screen")
  assertEqual(SW:Entries()[1].itemName, "Kept")
  NS.Ledger:CloseContext()
end)

test("a purge empties the session view", function()
  reset()
  NS.Ledger:OpenContext("BANK_FRAME")
  NS.Database:Add(e())
  NS.Database:Purge()
  assertEqual(#SW:Entries(), 0)
  NS.Ledger:CloseContext()
end)

-- ── Preview session (preview-mode) ─────────────────────────────────────────────

test("SessionWindow:TogglePreview shows placeholder rows through the real render path", function()
  reset()
  assertTrue(SW:TogglePreview(), "the first toggle turns the sample on")
  assertTrue(#SW:Entries() > 0, "the sample session has rows")
  assertTrue(SW:IsShown(), "and the window is on screen to be positioned")
  assertFalse(SW:TogglePreview(), "the second toggle turns it off")
  assertEqual(#SW:Entries(), 0)
  assertFalse(SW:IsShown())
end)

test("SessionWindow:TogglePreview refuses to overwrite a real session", function()
  reset()
  SW:StartSession("BANK_FRAME")
  SW:OnEntryAdded(e())
  assertEqual(SW:TogglePreview(), nil, "a real visit's data is never replaced by placeholders")
  assertEqual(#SW:Entries(), 1)
  SW:EndSession()
end)

test("a preview session is never pruned against the live ledger", function()
  reset()
  SW:TogglePreview()
  local n = #SW:Entries()
  assertEqual(SW:PruneMissing(), 0, "synthetic rows are not in the ledger and must survive")
  assertEqual(#SW:Entries(), n)
  SW:TogglePreview()
end)

test("a real session replaces a preview session's rows", function()
  reset()
  SW:TogglePreview()
  assertTrue(#SW:Entries() > 0)
  SW:StartSession("BANK_FRAME")
  assertEqual(#SW:Entries(), 0)
  assertFalse(SW.previewSession, "the sample flag clears when a real visit starts")
  SW:EndSession()
end)

-- ── Geometry persistence ───────────────────────────────────────────────────────

test("SessionWindow:ResetWindow clears the persisted geometry carve-out", function()
  reset()
  NS.db.global.settings.sessionWindow = { point = "TOPLEFT", x = 11, y = 22, w = 900, h = 700 }
  SW:ResetWindow()
  assertEqual(next(NS.db.global.settings.sessionWindow), nil,
    "the geometry carve-out resets to empty")
end)

test("the session window's geometry is a separate carve-out from the main window's", function()
  reset()
  NS.db.global.settings.window = { point = "CENTER", x = 1, y = 2 }
  NS.db.global.settings.sessionWindow = { point = "TOPLEFT", x = 3, y = 4 }
  SW:ResetWindow()
  assertEqual(NS.db.global.settings.window.x, 1, "resetting one window must not move the other")
end)
