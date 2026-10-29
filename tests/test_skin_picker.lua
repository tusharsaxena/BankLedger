-- tests/test_skin_picker.lua — the first-run skin picker on this addon's seam (core/SkinSetup.lua;
-- LibKa0s OptionsSkinPicker 1, LibKa0s#64; the skinning rollout's BL-04, owner ruling O3, X6).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands
-- O.SkinPicker (its owner, its two seams, the Skin tab's page and key, the eye, the close); WHEN it
-- shows (a profile whose `pickerSeen` is false, once after login and after every profile event,
-- never while the addon stands down, held through combat); and that only the player's close marks
-- it seen. The trigger cases spy on O.SkinPicker; the last cases drive the library's real window:
-- a pick previews unsaved and Apply saves it, the close control puts the stored skin back, the
-- eye opens the ledger window in test mode, and the stand-down takes a pending preview down unseen.
--
-- Ka0s Loot History's tests/test_skin_picker.lua is the pattern. Leaves the harness on `Default`,
-- the picker down and marked unseen, the skin on Ka0s Default.

local T = _G.BL_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local O = NS.Helpers
local PATH = "settings.appearance.pickerSeen"
local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "BankLedger"

-- Every frame built from here on, by parent, so a case can reach the picker list's rows: the
-- shared mock's frames do not list their children, and the picker builds its window, rows
-- included, on its first show, which is in this file.
local childrenOf = setmetatable({}, { __mode = "k" })
do
  local create = mocks.CreateFrame
  mocks.CreateFrame = function(frameType, name, parent, ...)
    local f = create(frameType, name, parent, ...)
    if parent ~= nil then
      local list = childrenOf[parent] or {}
      childrenOf[parent] = list
      list[#list + 1] = f
    end
    return f
  end
end

--- Run `fn(calls)` with O.SkinPicker replaced by a recorder: each call's spec, in order.
local function spying(fn)
  local real = O.SkinPicker
  local calls = {}
  O.SkinPicker = function(spec)
    calls[#calls + 1] = spec
    return { spy = true }
  end
  local ok, err = pcall(fn, calls)
  O.SkinPicker = real
  if not ok then error(err, 0) end
end

local function quietly(fn)
  local cf = mocks.DEFAULT_CHAT_FRAME
  local add = cf.AddMessage
  cf.AddMessage = function() end
  local ok, err = pcall(fn)
  cf.AddMessage = add
  if not ok then error(err, 0) end
end

--- The picker down (quietly), the profile back on Default, its key false and the skin back on Ka0s
--- Default, stored and worn, whatever `fn` raised.
local function clean(fn)
  return function()
    NS.HideSkinPicker()
    NS.Schema:Set(PATH, false)
    local ok, err = pcall(fn)
    NS.HideSkinPicker()
    quietly(function()
      if NS.db:GetCurrentProfile() ~= "Default" then NS.db:SetProfile("Default") end
      NS.HideSkinPicker()
      NS.Schema:Set(PATH, false)
      NS.WriteSkinChoice("ka0s", "ka0s")
      Skin:SetChoice(OWNER, "ka0s", "ka0s")
    end)
    mocks.__fireTimers()
    if not ok then error(err, 0) end
  end
end

--- The skin the Skin major wears for this addon now, and the one its profile stores.
local function worn() return select(2, Skin:GetChoice(OWNER)) end
local function stored() return select(2, NS.SkinChoice()) end

--- Open the window's list and click the row for skin `key`, as the player does.
local function pickRow(f, key)
  f.dd:__fire("OnClick")
  local hit = false
  for _, r in ipairs(childrenOf[f.list] or {}) do
    if r.key == key then r:__fire("OnClick"); hit = true end
  end
  assertTrue(hit, "no row for " .. key)
end

-- ── the key and the spec ─────────────────────────────────────────────────────────────────────

test("Skin picker: pickerSeen defaults to false, a skip-render row on the Skin tab", function()
  -- red under: a default of true (no profile would ever show it, against O3), or a row that draws
  -- itself.
  assertEqual(NS.defaults.profile.settings.appearance.pickerSeen, false)
  local row = NS.Schema:FindRow(PATH)
  assertTrue(row ~= nil, PATH .. " is not a schema row")
  assertEqual(row.type, "bool")
  assertEqual(row.group, "Appearance")
  assertTrue(row.skipRender == true, "nothing draws it")
end)

test("Skin picker: the spec names this owner, its seams, the Skin tab and the eye", function()
  -- red under: a set that is not the write seam (a pick would never reach the profile), or a page
  -- or tab key the gear cannot find.
  local spec = NS.SkinPickerSpec()
  assertEqual(spec.owner, OWNER)
  assertTrue(rawequal(spec.get, NS.SkinChoice), "get is the read seam")
  assertTrue(rawequal(spec.set, NS.WriteSkinChoice), "set is the write seam")
  -- The page key is read from settings/Panel.lua's own registration, not a literal: the library
  -- matches it exactly (OptionsRegistry's p.key, Options' ctx.pageKey), and a display name in its
  -- place ("General") opens the landing page and selects no tab.
  local f = assert(io.open((T.root or ".") .. "/settings/Panel.lua", "rb"))
  local src = f:read("*a")
  f:close()
  local registered = src:match('O%.RegisterOptionsPage%("([^"]+)", "General"')
  local panelKey = src:match('"BankLedgerGeneralPanel", "General", {%s*pageKey = "([^"]+)"')
  assertTrue(registered ~= nil, "the General page's RegisterOptionsPage key was not found")
  assertEqual(panelKey, registered, "the General panel's pageKey is its registered key")
  assertEqual(spec.page, registered, "the gear opens the page by its registered key")
  assertEqual(spec.tab, "Appearance", "the Skin tab's key")
  assertEqual(type(spec.onPreview), "function", "the eye: this addon has a window to preview in (X6)")
  assertEqual(type(spec.onClose), "function")
end)

-- ── when it shows ────────────────────────────────────────────────────────────────────────────

test("Skin picker: an unseen profile shows it; a seen one does not", clean(function()
  spying(function(calls)
    NS.MaybeShowSkinPicker()
    assertEqual(#calls, 1, "pickerSeen false: the picker shows")
    assertEqual(calls[1].owner, OWNER)
    NS.Schema:Set(PATH, true)
    NS.MaybeShowSkinPicker()
    assertEqual(#calls, 1, "pickerSeen true: it does not show again")
  end)
end))

test("Skin picker: login arms it once, two seconds in, on a timer the stand-down cancels", clean(function()
  -- red under: dropping the call from addon:OnEnterWorld, arming it on every PLAYER_ENTERING_WORLD,
  -- or a C_Timer.After the stand-down cannot cancel.
  local st = NS.State
  local saved = { st.pickerDone, st.pickerPending, st.cleanupDone, st.cleanupPending }
  st.pickerDone, st.pickerPending = false, nil
  st.cleanupDone, st.cleanupPending = true, nil   -- the retention prune stays out of this case
  local ok, err = pcall(function()
    NS.addon:OnEnterWorld()
    local fuse = st.pickerPending
    assertTrue(fuse ~= nil, "OnEnterWorld armed no picker timer")
    assertEqual(fuse.delay, 2, "two seconds in")
    NS.addon:OnEnterWorld()
    assertTrue(rawequal(st.pickerPending, fuse), "a second PLAYER_ENTERING_WORLD arms nothing more")
    spying(function(calls)
      fuse.callback()
      assertEqual(#calls, 1, "the login timer shows the picker")
      NS.addon:OnEnterWorld()
      assertEqual(st.pickerPending, nil, "once per session: a later zone change arms nothing")
    end)
    -- The stand-down drops a timer still armed, so the next stand-up's login re-arms it.
    st.pickerDone = false
    NS.addon:OnEnterWorld()
    assertTrue(st.pickerPending ~= nil, "re-armed")
    quietly(function() NS.Schema:Set("settings.enabled", false) end)
    assertEqual(st.pickerPending, nil, "the stand-down drops the armed picker timer")
    assertTrue(st.pickerDone == false, "and the session's check is still owed")
  end)
  quietly(function() NS.Schema:Set("settings.enabled", true) end)
  if st.pickerPending and NS.addon.CancelTimer then NS.addon:CancelTimer(st.pickerPending) end
  st.pickerDone, st.pickerPending, st.cleanupDone, st.cleanupPending = saved[1], saved[2], saved[3], saved[4]
  if not ok then error(err, 0) end
end))

test("Skin picker: in combat a start waits for PLAYER_REGEN_ENABLED, once", clean(function()
  local real = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return true end
  local ok, err = pcall(function()
    spying(function(calls)
      assertEqual(NS.MaybeShowSkinPicker(), nil)
      NS.MaybeShowSkinPicker()
      assertEqual(#calls, 0, "nothing shows in combat")
      mocks.InCombatLockdown = function() return false end
      mocks.__fireEvent("PLAYER_REGEN_ENABLED")
      assertEqual(#calls, 1, "the combat edge shows it, once for two held starts")
      mocks.__fireEvent("PLAYER_REGEN_ENABLED")
      assertEqual(#calls, 1, "the one-shot target is gone")
    end)
  end)
  mocks.InCombatLockdown = real
  if not ok then error(err, 0) end
end))

test("Skin picker: a held start is dropped by HideSkinPicker", clean(function()
  local real = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return true end
  local ok, err = pcall(function()
    spying(function(calls)
      NS.MaybeShowSkinPicker()
      NS.HideSkinPicker()
      mocks.InCombatLockdown = function() return false end
      mocks.__fireEvent("PLAYER_REGEN_ENABLED")
      assertEqual(#calls, 0, "a dropped start must not fire on the combat edge")
    end)
  end)
  mocks.InCombatLockdown = real
  if not ok then error(err, 0) end
end))

test("Skin picker: never while the addon is switched off", clean(function()
  quietly(function()
    spying(function(calls)
      NS.Schema:Set("settings.enabled", false)
      local ok, err = pcall(function()
        assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 0, "a disabled addon shows no picker")
      end)
      NS.Schema:Set("settings.enabled", true)
      if not ok then error(err, 0) end
    end)
  end)
end))

test("Skin picker: a new profile and a reset profile show it again", clean(function()
  -- Both start from the defaults, pickerSeen false (O3). red under: no call on the profile adopt
  -- path (NS.OnProfileEvent), or one before the latch re-reads the new profile's switch.
  local db = NS.db
  NS.Schema:Set(PATH, true)
  quietly(function()
    spying(function(calls)
      db:SetProfile("PickerProbe")
      assertEqual(#calls, 1, "a new profile shows the picker")
      NS.Schema:Set(PATH, true)
      db:ResetProfile()
      assertEqual(#calls, 2, "a reset profile shows it again")
      NS.Schema:Set(PATH, true)
      db:SetProfile("Default")
      assertEqual(#calls, 2, "back on a profile that has seen it: no picker")
    end)
  end)
  if db.DeleteProfile then quietly(function() pcall(db.DeleteProfile, db, "PickerProbe", true) end) end
end))

-- ── the real window ──────────────────────────────────────────────────────────────────────────

test("Skin picker: the player's close marks it seen; this addon's own hide does not", clean(function()
  local f = NS.MaybeShowSkinPicker()
  assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
  NS.HideSkinPicker()
  assertEqual(NS.Schema:Get(PATH), false, "a hide this addon makes is not the player's close")
  f = NS.MaybeShowSkinPicker()
  assertTrue(f ~= nil and f:IsShown(), "it shows again while unseen")
  O.HideSkinPicker()
  assertEqual(NS.Schema:Get(PATH), true, "the player's close sets pickerSeen")
  assertEqual(NS.MaybeShowSkinPicker(), nil, "and it does not show again")
end))

test("Skin picker: a profile that has seen it takes a shown picker down, unmarked", clean(function()
  local f = NS.MaybeShowSkinPicker()
  assertTrue(f ~= nil and f:IsShown())
  NS.db.profile.settings.appearance.pickerSeen = true
  NS.MaybeShowSkinPicker()
  assertFalse(f:IsShown(), "the picker stayed up on a profile that has seen it")
end))

test("Skin picker: the title names this addon", clean(function()
  local f = NS.MaybeShowSkinPicker()
  assertTrue(f ~= nil and f:IsShown())
  assertEqual(f.title:GetText(), "Choose a skin for " .. NS.BRAND_NAME)
end))

test("Skin picker: a pick previews, unsaved; Apply saves it and marks the picker seen", clean(function()
  -- red under: a spec.set that is not the write seam (Apply would save nothing), or an onClose
  -- that does not write pickerSeen (the picker would come back on the next login).
  quietly(function()
    local f = NS.MaybeShowSkinPicker()
    assertTrue(f ~= nil and f:IsShown())
    pickRow(f, "obsidian")
    assertEqual(worn(), "obsidian", "the pick is worn at once")
    assertEqual(stored(), "ka0s", "a pick alone writes nothing to the profile")
    assertEqual(NS.Schema:Get(PATH), false, "a pick does not end the showing")
    f.apply:__fire("OnClick")
    assertFalse(f:IsShown(), "Apply closes the window")
    assertEqual(stored(), "obsidian", "Apply saves through NS.WriteSkinChoice")
    assertEqual(NS.Schema:Get(PATH), true, "Apply marks the picker seen")
  end)
end))

test("Skin picker: the close control puts the stored skin back, saves nothing, and marks it seen", clean(function()
  quietly(function()
    local f = NS.MaybeShowSkinPicker()
    pickRow(f, "obsidian")
    f.close:__fire("OnClick")
    assertFalse(f:IsShown(), "the close control closes the window")
    assertEqual(worn(), "ka0s", "closing puts back the stored skin")
    assertEqual(stored(), "ka0s", "and writes nothing")
    assertEqual(NS.Schema:Get(PATH), true, "a close by the player still counts as seen")
  end)
end))

test("Skin picker: the eye opens the ledger window in test mode", clean(function()
  -- DECISIONS BankLedger D8. red under: an onPreview that opens nothing, or one that starts test
  -- mode a second time over a mode already on.
  local LT, B = NS.LedgerTable, NS.Browser
  local ok, err = pcall(function()
    quietly(function() NS.SkinPickerSpec().onPreview() end)
    assertTrue(LT:IsTestMode(), "the eye did not start test mode")
    local f = B:GetWindow()
    assertTrue(f ~= nil and f:IsShown(), "the eye did not show the ledger window")
    B:Hide()
    quietly(function() NS.SkinPickerSpec().onPreview() end)
    assertTrue(B:GetWindow():IsShown(), "with test mode already on, the eye still shows the window")
  end)
  quietly(function() if LT:IsTestMode() then LT:SetTestMode(false) end end)
  B:Hide()
  if not ok then error(err, 0) end
end))

test("Skin picker: the eye in combat starts nothing and says why", clean(function()
  local LT = NS.LedgerTable
  local real = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return true end
  local lines = {}
  local cf = mocks.DEFAULT_CHAT_FRAME
  local add = cf.AddMessage
  cf.AddMessage = function(_, m) lines[#lines + 1] = m end
  local ok, err = pcall(function()
    NS.SkinPickerSpec().onPreview()
    assertFalse(LT:IsTestMode(), "test mode started in combat")
    assertEqual(#lines, 1, "the refusal is printed once")
    assertTrue(tostring(lines[1]):find("combat", 1, true) ~= nil, "the line names combat")
  end)
  cf.AddMessage = add
  mocks.InCombatLockdown = real
  if not ok then error(err, 0) end
end))

test("Skin picker: the stand-down with a preview pending puts the old skin back, unsaved, unseen", clean(function()
  quietly(function()
    local f = NS.MaybeShowSkinPicker()
    pickRow(f, "obsidian")
    NS.Schema:Set("settings.enabled", false)
    local ok, err = pcall(function()
      assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
      assertFalse(f:IsShown(), "the stand-down takes the picker down")
      assertEqual(worn(), "ka0s", "the pending preview is put back")
      assertEqual(stored(), "ka0s", "and never saved")
      assertEqual(NS.Schema:Get(PATH), false, "a stand-down is not the player's close")
    end)
    NS.Schema:Set("settings.enabled", true)
    if not ok then error(err, 0) end
  end)
end))

test("Skin picker: degraded, the seam answers nothing and raises nothing", function()
  -- Without LibKa0s the Options stub's SkinPicker draws nothing: no skin to pick.
  local dns = dofile("tests/degraded_env.lua").loadDegraded()
  assertEqual(type(dns.MaybeShowSkinPicker), "function")
  assertEqual(dns.MaybeShowSkinPicker(), nil)
  dns.HideSkinPicker()
end)
