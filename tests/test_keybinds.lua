-- tests/test_keybinds.lua — item 015: the key binding's own Keybindings section and the General
-- page's Keybindings tab.
--
-- launcher-§6 (standard v2.88.0) files every binding in this addon's OWN category,
-- BINDING_HEADER_BANKLEDGER, so Options -> Keybindings shows a "Ka0s Bank Ledger" section with no
-- blank header row; options-ui-§20 adds the General page's last tab, drawn by the library from
-- NS.BINDINGS, editing the client's one binding store. The capture, conflict, slot and sync
-- mechanics are LibKa0s's cases (tests/test_options_keybinds*.lua there, testing-§8); these pin
-- the host's half: the file, the table, the labels, where the tab sits, and that the page's own tab
-- reaches the client's store both ways and refuses in combat.
--
-- The binding API is the kit's tests/_kit/mock_bindings.lua, which tests/wow_mock.lua installs.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local P = NS.Panel
P:Register()

local S = dofile("tests/panel_support.lua")
local ctxFor, renderTab = S.ctxFor, S.renderTab
local GENERAL_TABS = S.GENERAL_TABS

local COMMAND = "CLICK BankLedgerToggleWindow:LeftButton"
local LABEL   = "Toggle ledger window"

--- Render General's Keybindings tab and hand back the row records the library drew, by spying on
--- the instance's KeybindRows (the tab's render looks it up at call time).
local function keybindRows()
  local O = NS.Helpers
  local real = O.KeybindRows
  local rows
  O.KeybindRows = function(...)
    rows = real(...)
    return rows
  end
  local ok, err = pcall(renderTab, "General", "Keybindings")
  O.KeybindRows = real
  if not ok then error(err, 0) end
  assertTrue(type(rows) == "table", "the Keybindings tab drew no rows")
  return rows
end

local function slotText(row, slot)
  return row.slots[slot].text
end

local function reset()
  mocks.clearBindings()
  mocks.setModifiers(nil)
end

-- ── Bindings.xml and NS.BINDINGS (launcher-§6) ───────────────────────────────────────────────

test("Keybinds: Bindings.xml files every binding in the addon's own category, labels and brand",
function()
  -- red under: category="ADDONS", a header= (a blank spacer row in the client's list), a default=
  -- key, a name that differs from NS.BINDINGS, or a label that still says "the ledger window".
  local list = T.assertBindingsXml("Bindings.xml", {
    category = "BINDING_HEADER_BANKLEDGER",
    commands = NS.BINDINGS,
    brand    = NS.BRAND_NAME,
    labels   = { [COMMAND] = LABEL },
  })
  assertEqual(#list, 1, "one binding")
  assertEqual(list[1].name, COMMAND, "the binding NAME never changes: saved keys survive")
end)

test("Keybinds: NS.BINDINGS is the one table, Show window first, each with a tooltip", function()
  assertEqual(#NS.BINDINGS, 1)
  assertEqual(NS.BINDINGS[1].command, COMMAND, "the Show window binding is first")
  for _, b in ipairs(NS.BINDINGS) do
    assertTrue(type(b.tooltip) == "string" and b.tooltip ~= "", b.command .. " has no tooltip")
  end
  assertEqual(rawget(_G, "BINDING_NAME_" .. COMMAND), NS.L[LABEL], "the label comes through L")
end)

-- ── The General page's Keybindings tab (options-ui-§20) ──────────────────────────────────────

test("Keybinds: the General strip ENDS in Keybindings, after every schema tab", function()
  -- red under: no opts.tabs entry, a `before` that pulls it forward, or a relabeled tab. Read off
  -- the spec the page hands the library's strip, spied at call time.
  local O = NS.Helpers
  local real = O.TabStrip
  local spec
  O.TabStrip = function(c, sp)
    spec = sp
    return real(c, sp)
  end
  local ok, err = pcall(renderTab, "General", GENERAL_TABS[1])
  O.TabStrip = real
  if not ok then error(err, 0) end
  assertTrue(type(spec) == "table" and type(spec.tabs) == "table", "General drew no tab strip")
  local keys, labels = {}, {}
  for i, t in ipairs(spec.tabs) do keys[i], labels[i] = t.key, t.label end
  assertEqual(table.concat(keys, ","), table.concat(GENERAL_TABS, ","), "the strip, in order")
  assertEqual(keys[#keys], "Keybindings", "the Keybindings tab is LAST")
  assertEqual(labels[#labels], "Keybindings", "labeled exactly Keybindings")
  assertEqual(keys[1], "Master controls", "Master controls stays first (options-ui-§15)")
  ctxFor("General").activeTab = GENERAL_TABS[1]
end)

test("Keybinds: the tab's rows are NS.BINDINGS in order, labeled with the BINDING_NAME_ text",
function()
  reset()
  local rows = keybindRows()
  assertEqual(#rows, #NS.BINDINGS, "one row per binding")
  for i, b in ipairs(NS.BINDINGS) do
    assertEqual(rows[i].command, b.command, "row " .. i .. " follows NS.BINDINGS")
    assertEqual(rows[i].label.text, rawget(_G, "BINDING_NAME_" .. b.command),
      "row " .. i .. " shows the client's label, not one of the addon's own")
    assertEqual(#rows[i].slots, 2, "two key slots, as the client keeps")
  end
  ctxFor("General").activeTab = GENERAL_TABS[1]
end)

test("Keybinds: a key bound through the tab is the client's key (GetBindingKey)", function()
  reset()
  local rows = keybindRows()
  local status = T.keybindThroughTab(rows[1], 1, "K", { ctrl = true })
  assertEqual(mocks.GetBindingKey(COMMAND), "CTRL-K", "the tab wrote the client's store")
  assertEqual(status, mocks.KEY_BOUND)
  assertEqual(mocks.__savedBindingSets[#mocks.__savedBindingSets], mocks.GetCurrentBindingSet(),
    "saved to the set in force")
  reset()
  ctxFor("General").activeTab = GENERAL_TABS[1]
end)

test("Keybinds: a key set on the client's page shows in the tab after UPDATE_BINDINGS", function()
  -- The other direction of OWNER_SCOPE 015's "sync across both": Options -> Keybindings calls
  -- SetBinding, which fires UPDATE_BINDINGS, and the tab repaints from GetBindingKey.
  reset()
  local rows = keybindRows()
  assertFalse(slotText(rows[1], 1) == "F7", "starts unbound")
  -- On screen, as the player looking at the tab has it: the library repaints only rows whose group
  -- is shown on a shown page. The client shows both; the fakes leave them hidden. The page's flag
  -- is put back raw afterwards, so no OnHide hook runs on its way out.
  local panel = ctxFor("General").panel
  local wasShown = panel.__shown
  panel:Show()
  rows[1].group.frame:Show()
  local ok, err = pcall(function()
    mocks.SetBinding("F7", COMMAND)
    assertFalse(slotText(rows[1], 1) == "F7", "repainted before the event: the case proves nothing")
    local lib = mocks.LibStub("LibKa0s-Options-1.0")
    lib.__keybindEventFrame:__fire("OnEvent", "UPDATE_BINDINGS")
    mocks.__fireTimers()
    assertEqual(slotText(rows[1], 1), "F7", "the tab shows the key the client's page set")
  end)
  panel.__shown = wasShown
  reset()
  if not ok then error(err, 0) end
  ctxFor("General").activeTab = GENERAL_TABS[1]
end)

test("Keybinds: in combat the tab refuses, and no binding is written", function()
  reset()
  local rows = keybindRows()
  local saved = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return true end
  local ok, err = pcall(function()
    local out = {}
    local savedAdd = mocks.DEFAULT_CHAT_FRAME.AddMessage
    mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, m) out[#out + 1] = m end
    local okPress, status = pcall(T.keybindThroughTab, rows[1], 1, "K")
    mocks.DEFAULT_CHAT_FRAME.AddMessage = savedAdd
    assertTrue(okPress, tostring(status))
    assertEqual(mocks.GetBindingKey(COMMAND), nil, "a key was bound in combat")
    assertEqual(#mocks.__bindingWrites, 0, "SetBinding was called in combat")
    assertEqual(#mocks.__savedBindingSets, 0, "SaveBindings was called in combat")
    local lib = mocks.LibStub("LibKa0s-Options-1.0")
    assertEqual(rows[1].status.text, lib.KEYBIND_STRINGS.COMBAT, "the outcome line says why")
  end)
  mocks.InCombatLockdown = saved
  reset()
  ctxFor("General").activeTab = GENERAL_TABS[1]
  if not ok then error(err, 0) end
end)
