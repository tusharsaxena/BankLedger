-- tests/test_skin_picker_preview.lua — the skin picker's preview on this addon's seam
-- (core/SkinSetup.lua; LibKa0s OptionsSkinPicker 11, spec.preview, R6-L1; Ka0sAddonsCommonTasks
-- docs/2026-11-03-SMOKE_ROUND6/, item R6-PV, the lead's call 2: test mode, `/bl test`).
--
-- The owner's rule: when the picker shows and the ledger window is hidden, the addon enters test
-- mode; the eye toggles it; every close puts the addon back as it was when the picker opened. The
-- library pins its own half (when it calls enter and exit, and on which routes); these cases pin
-- this addon's half against the library's real window: what `spec.preview` reads and writes, that
-- each call goes through LT:SetTestMode (the one path the Master controls checkbox, `/bl test` and
-- the combat ending take), and that a window this preview opened is the one it closes.
--
-- Leaves the harness with the picker down and unseen, test mode off and the ledger window hidden.

local T = _G.BL_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local O = NS.Helpers
local PATH = "settings.appearance.pickerSeen"

local function quietly(fn)
  local cf = mocks.DEFAULT_CHAT_FRAME
  local add = cf.AddMessage
  cf.AddMessage = function() end
  local ok, err = pcall(fn)
  cf.AddMessage = add
  if not ok then error(err, 0) end
end

local function testMode() return NS.LedgerTable:IsTestMode() end
local function windowShown()
  local f = NS.Browser:GetWindow()
  return f ~= nil and f:IsShown() and true or false
end

--- The picker down, test mode off and the ledger window hidden, before and after `fn`, whatever
--- `fn` raised.
local function clean(fn)
  local function reset()
    quietly(function()
      NS.HideSkinPicker()
      NS.Schema:Set(PATH, false)
      if testMode() then NS.LedgerTable:SetTestMode(false) end
      NS.Browser:Hide()
    end)
  end
  return function()
    reset()
    local ok, err = pcall(fn)
    reset()
    mocks.__fireTimers()
    if not ok then error(err, 0) end
  end
end

--- The picker up, as `/bl skin` and the first-run showing put it up.
local function open()
  local f
  quietly(function() f = NS.MaybeShowSkinPicker() end)
  assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
  return f
end

local function eye(f) quietly(function() f.preview:__fire("OnClick") end) end

-- ── the spec ────────────────────────────────────────────────────────────────────────────────

test("Skin preview: the spec passes spec.preview in test mode, and no one-shot onPreview", function()
  -- red under: minor 10's onPreview left in place (an eye that only enters, and no restore), or a
  -- mode other than the lead's call 2 gives this addon.
  local spec = NS.SkinPickerSpec()
  local h = spec.preview
  assertEqual(type(h), "table", "spec.preview")
  assertEqual(h.mode, "test", "BankLedger's preview mode is test mode (/bl test)")
  for _, k in ipairs({ "enter", "exit", "isActive", "isShown" }) do
    assertEqual(type(h[k]), "function", "spec.preview." .. k)
  end
  assertEqual(spec.onPreview, nil, "the one-shot eye is gone")
end)

test("Skin preview: isActive and isShown read test mode and the ledger window", clean(function()
  local h = NS.SkinPickerSpec().preview
  assertFalse(h.isActive(), "test mode off")
  assertFalse(h.isShown(), "the window hidden")
  NS.Browser:Show()
  assertTrue(h.isShown(), "the window shown")
  quietly(function() NS.LedgerTable:SetTestMode(true) end)
  assertTrue(h.isActive(), "test mode on")
end))

test("Skin preview: enter and exit go through LT:SetTestMode, the write seam", clean(function()
  -- red under: a preview that writes NS.State.testRecords itself, or calls Browser:Show alone, so
  -- the Master controls checkbox, the launcher and the combat refusal would not follow it.
  local LT = NS.LedgerTable
  local real, seen = LT.SetTestMode, {}
  LT.SetTestMode = function(self, on) seen[#seen + 1] = on; return real(self, on) end
  local ok, err = pcall(function()
    local h = NS.SkinPickerSpec().preview
    quietly(function() h.enter("eye") end)
    quietly(function() h.exit("eye") end)
  end)
  LT.SetTestMode = real
  if not ok then error(err, 0) end
  assertEqual(#seen, 2, "one SetTestMode call each")
  assertEqual(seen[1], true)
  assertEqual(seen[2], false)
end))

-- ── the picker, with the window hidden ──────────────────────────────────────────────────────

test("Skin preview: the picker opened with the window hidden enters test mode", clean(function()
  -- red under: no spec.preview (the library enters nothing at show), or an enter that starts test
  -- mode without the window.
  open()
  assertTrue(testMode(), "the picker turned test mode on")
  assertTrue(windowShown(), "and the ledger window shows the sample rows")
end))

test("Skin preview: the eye turns test mode off and on, and the window with it", clean(function()
  -- red under: minor 10's enter-only eye (a second click re-shows instead of turning it off), or an
  -- exit that leaves the window the preview opened standing over real data.
  local f = open()
  eye(f)
  assertFalse(testMode(), "the eye turned test mode off")
  assertFalse(windowShown(), "and closed the window the picker opened")
  eye(f)
  assertTrue(testMode(), "the eye turned test mode on again")
  assertTrue(windowShown(), "and opened the window")
  assertTrue(f:IsShown(), "the picker stays up through the eye")
end))

local ROUTES = {
  { "the close control", function(f) f.close:__fire("OnClick") end },
  { "Apply", function(f) f.apply:__fire("OnClick") end },
  { "the gear", function(f) f.settings:__fire("OnClick") end },
  -- What UISpecialFrames does on Escape; the shared mock's Hide runs no script, so OnHide is fired.
  { "Escape", function(f) f:Hide(); f:__fire("OnHide") end },
  { "NS.HideSkinPicker (the stand-down, a profile event)", function() NS.HideSkinPicker() end },
  { "O.HideSkinPicker", function() O.HideSkinPicker() end },
}

for _, route in ipairs(ROUTES) do
  test("Skin preview: closing by " .. route[1] .. " puts test mode and the window back", clean(function()
    -- red under: no restore on this route, or an exit that leaves the window open.
    local f = open()
    assertTrue(testMode(), "entered at show")
    quietly(function() route[2](f) end)
    assertFalse(f:IsShown(), "the route closed the picker")
    assertFalse(testMode(), "test mode is off again")
    assertFalse(windowShown(), "and the ledger window is hidden again")
  end))
end

test("Skin preview: an eye that turned it off leaves nothing to undo at the close", clean(function()
  local f = open()
  eye(f)
  quietly(function() f.close:__fire("OnClick") end)
  assertFalse(testMode(), "off at open, off at close")
  assertFalse(windowShown())
end))

-- ── a surface already up ────────────────────────────────────────────────────────────────────

test("Skin preview: a ledger window already shown is left alone at show and at close", clean(function()
  -- red under: an isShown that is missing or always false (the picker would swap the player's real
  -- rows for the sample), or a close that hides a window the player opened.
  NS.Browser:Show()
  local f = open()
  assertFalse(testMode(), "a shown window: no test mode at show")
  assertTrue(windowShown())
  quietly(function() f.close:__fire("OnClick") end)
  assertFalse(testMode())
  assertTrue(windowShown(), "the player's window stays open")
end))

test("Skin preview: the eye over a shown window turns test mode on and off, the window stays", clean(function()
  NS.Browser:Show()
  local f = open()
  eye(f)
  assertTrue(testMode(), "the eye turned test mode on")
  eye(f)
  assertFalse(testMode(), "and off")
  assertTrue(windowShown(), "the window the player opened is not the preview's to close")
  eye(f)
  quietly(function() f.close:__fire("OnClick") end)
  assertFalse(testMode(), "the close puts test mode back off")
  assertTrue(windowShown(), "and leaves the player's window open")
end))

test("Skin preview: test mode already on stays on; an eye that turned it off is undone at close", clean(function()
  quietly(function() NS.LedgerTable:SetTestMode(true) end)
  NS.Browser:Hide()
  local f = open()
  assertTrue(testMode(), "on at open")
  eye(f)
  assertFalse(testMode(), "the eye turned it off")
  quietly(function() f.close:__fire("OnClick") end)
  assertTrue(testMode(), "the close turned it back on")
  assertTrue(windowShown(), "with the window showing it")
end))

-- ── refusals ────────────────────────────────────────────────────────────────────────────────

test("Skin preview: in combat the enter is refused, said once, and the close undoes nothing", clean(function()
  -- The picker does not open in combat on its own (the first-run start waits), but O.SkinPicker
  -- shows it for a queue handed on in combat. Test mode's own refusal prints, as `/bl test` prints it.
  local real = mocks.InCombatLockdown
  local lines = {}
  local cf = mocks.DEFAULT_CHAT_FRAME
  local add = cf.AddMessage
  local ok, err = pcall(function()
    mocks.InCombatLockdown = function() return true end
    cf.AddMessage = function(_, m) lines[#lines + 1] = m end
    local f = O.SkinPicker(NS.SkinPickerSpec())
    assertTrue(f ~= nil and f:IsShown(), "the picker showed")
    assertFalse(testMode(), "no test mode in combat")
    assertFalse(windowShown(), "and no window")
    local said = 0
    for _, m in ipairs(lines) do
      if tostring(m):find("cannot start test mode during combat", 1, true) then said = said + 1 end
    end
    assertEqual(said, 1, "the refusal is printed once")
    f.close:__fire("OnClick")
    assertFalse(testMode(), "the close starts nothing")
  end)
  cf.AddMessage = add
  mocks.InCombatLockdown = real
  if not ok then error(err, 0) end
end))
