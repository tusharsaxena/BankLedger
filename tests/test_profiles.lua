-- tests/test_profiles.lua — settings per profile (schema v3, docs/profiles.md).
--
-- What a profile holds and what stays account-wide, the one-time lift of the pre-v3 settings into
-- the Default profile, and the one adopt path every profile event takes (NS.OnProfileEvent): the
-- migrations, the enable latch, every setting's effect re-applied, the panel refreshed and exactly
-- one debug line. And the Profiles page itself (options-ui-§3).

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local AceDB = mocks.__libs["AceDB-3.0"]

local function muted(fn)
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function() end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
end

--- Every debug line `fn` writes, with logging on for it alone and chat muted.
local function debugLines(fn)
  local savedDebug = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  local ok, err = pcall(muted, fn)
  local out = {}
  for _, line in ipairs(NS.DebugLog.buffer) do out[#out + 1] = line end
  NS.DebugLog:Clear()
  NS.State.debug = savedDebug
  if not ok then error(err, 0) end
  return out
end

local function withTag(lines, tag)
  local out = {}
  for _, line in ipairs(lines) do
    if line:find(tag, 1, true) then out[#out + 1] = line end
  end
  return out
end

--- A pre-v3 SavedVariables root: the shape every install had through schema v2, with the settings,
--- both filter lists and the saved view under `global` beside the ledger.
local function legacyStore()
  return {
    global = {
      schemaVersion = 2,
      ledger = {
        { ts = 1, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
          itemID = 2589, itemName = "Linen Cloth", quantity = 10 },
      },
      minimap = { hide = true, minimapPos = 200 },
      settings = { qualityThreshold = 3, trackMoney = false, window = { point = "TOP", x = 1, y = 2 } },
      blacklist = { [2589] = true },
      whitelist = { [4306] = true },
      savedView = { groupBy = "store" },
    },
  }
end

--- Run `fn` with NS.db swapped for a fresh db built over `sv`, the way NS:InitDB builds it, and put
--- the suite's own db back afterwards whatever happens.
local function withDb(sv, fn)
  local saved = NS.db
  NS.db = AceDB:New(sv, NS.defaults, true)
  local ok, err = pcall(fn, NS.db)
  NS.db = saved
  if not ok then error(err, 0) end
end

-- ── what lives where ─────────────────────────────────────────────────────────────────────────

test("Profiles: the defaults split — the ledger and the minimap table are account-wide, everything configured is per profile", function()
  -- D5 (settings only): recorded data stays account-wide; the settings, both filter lists and the
  -- saved view move into the profile.
  -- red under: a settings key left in (or put back into) defaults/Global.lua.
  local g, p = NS.defaults.global, NS.defaults.profile
  assertTrue(type(g.ledger) == "table", "the ledger is account-wide")
  assertTrue(type(g.minimap) == "table", "LibDBIcon's table is account-wide")
  assertEqual(g.schemaVersion, 0, "the stamp is account-wide, and declared as 0")
  for _, key in ipairs({ "settings", "blacklist", "whitelist", "savedView" }) do
    assertEqual(g[key], nil, key .. " is still declared account-wide")
  end
  assertTrue(type(p.settings) == "table", "the settings are per profile")
  assertTrue(type(p.blacklist) == "table" and type(p.whitelist) == "table",
    "both filter lists are per profile")
  assertEqual(p.ledger, nil, "the ledger must not be per profile")
end)

test("Profiles: a schema write lands in the active profile, never in db.global", function()
  -- red under: resolveRoot answering db.global again.
  local saved = NS.Schema:Get("settings.qualityThreshold")
  NS.Schema:Set("settings.qualityThreshold", 4)
  local inProfile = rawget(NS.db.profile.settings, "qualityThreshold")
  local inGlobal = rawget(NS.db.global, "settings")
  NS.Schema:Set("settings.qualityThreshold", saved)
  assertEqual(inProfile, 4, "the write did not reach db.profile.settings")
  assertEqual(inGlobal, nil, "a settings table appeared under db.global")
end)

test("Profiles: the filter lists are written into the active profile", function()
  -- red under: NS.Filters still writing db.global.
  muted(function() NS.Filters:AddBlacklist(99999) end)
  local inProfile = NS.db.profile.blacklist[99999]
  local inGlobal = rawget(NS.db.global, "blacklist")
  muted(function() NS.Filters:RemoveBlacklist(99999) end)
  assertEqual(inProfile, true, "the id did not land in the profile's list")
  assertEqual(inGlobal, nil, "a blacklist appeared under db.global")
end)

-- ── the v3 lift (savedvariables-§1) ─────────────────────────────────────────────────────────

test("Migrate v3: every stored setting, both lists and the saved view land in the Default profile, and leave db.global", function()
  -- red under: a missing step (settings stay in global and the profile reads defaults), a step that
  -- copies without clearing, or one that lifts into the wrong profile.
  local sv = legacyStore()
  withDb(sv, function(db)
    NS:RunMigrations()
    assertEqual(db.global.schemaVersion, 3, "stamped v3")
    local p = sv.profiles.Default
    assertTrue(type(p) == "table", "the Default profile was not created")
    assertEqual(p.settings.qualityThreshold, 3, "a stored setting did not move")
    assertEqual(p.settings.trackMoney, false, "a stored false did not move")
    assertEqual(p.settings.window.point, "TOP", "a stored geometry table did not move")
    assertEqual(p.blacklist[2589], true, "the blacklist did not move")
    assertEqual(p.whitelist[4306], true, "the whitelist did not move")
    assertEqual(p.savedView.groupBy, "store", "the saved view did not move")
    for _, key in ipairs({ "settings", "blacklist", "whitelist", "savedView" }) do
      assertEqual(rawget(db.global, key), nil, key .. " was left in db.global")
    end
  end)
end)

test("Migrate v3: the recorded ledger and LibDBIcon's table are not touched", function()
  -- red under: a step that lifts more than the four profile keys.
  local sv = legacyStore()
  withDb(sv, function(db)
    NS:RunMigrations()
    assertEqual(#db.global.ledger, 1, "the ledger moved or was emptied")
    assertEqual(db.global.ledger[1].itemName, "Linen Cloth", "a ledger entry was rewritten")
    assertEqual(db.global.minimap.hide, true, "the minimap table was touched")
    assertEqual(db.global.minimap.minimapPos, 200, "the minimap angle was touched")
    assertEqual(sv.profiles.Default.ledger, nil, "the ledger was copied into the profile")
  end)
end)

test("Migrate v3: reads resolve against the lifted profile, and unset rows read their defaults", function()
  -- The runner runs before anything reads db.profile (savedvariables-§1), so the lazily built
  -- profile is built OVER the lifted values: the player's choices win, the rest are defaults.
  -- red under: a lift that runs after the first db.profile read and is overwritten, or a profile
  -- that reads nil for a row the legacy store never stored.
  withDb(legacyStore(), function()
    NS:RunMigrations()
    assertEqual(NS.Schema:Get("settings.qualityThreshold"), 3, "the lifted value is not what reads")
    assertEqual(NS.Schema:Get("settings.trackMoney"), false, "a lifted false reads as the default")
    assertEqual(NS.Schema:Get("settings.trackItems"), true, "an unstored row does not read its default")
    assertEqual(NS.Filters:Count(NS.Filters:Blacklist()), 1, "the lifted blacklist is not what reads")
  end)
end)

test("Migrate v3: idempotent — a second run moves nothing and changes nothing", function()
  -- red under: a step that re-lifts, or one that clears the profile when global is empty.
  local sv = legacyStore()
  withDb(sv, function(db)
    NS:RunMigrations()
    local again = NS.MIGRATIONS[3](db.global, db)
    NS:RunMigrations()
    assertEqual(again, 0, "the second pass moved something")
    assertEqual(sv.profiles.Default.settings.qualityThreshold, 3, "the second pass changed a value")
    assertEqual(sv.profiles.Default.blacklist[2589], true, "the second pass dropped the list")
    assertEqual(db.global.schemaVersion, 3)
  end)
end)

test("Migrate v3: a store with nothing to lift is stamped and gains no profile keys", function()
  -- A v2 install that never changed a setting: AceDB's logout strip left no `settings` at all.
  -- red under: a step that fabricates a profile table or raises on the absent keys.
  local sv = { global = { schemaVersion = 2, ledger = {} } }
  withDb(sv, function(db)
    local n = NS.MIGRATIONS[3](db.global, db)
    assertEqual(n, 0, "rows were counted where nothing moved")
    assertEqual(sv.profiles.Default, nil, "a Default profile was fabricated with nothing in it")
  end)
end)

test("Migrate v3: the [Migrate] line counts each value it moved", function()
  -- Three settings, two lists and a view: six rows.
  -- red under: a step that returns 0, or counts the keys rather than the values.
  local lines
  withDb(legacyStore(), function()
    lines = withTag(debugLines(function() NS:RunMigrations() end), "[Migrate]")
  end)
  assertEqual(#lines, 1, "one migration line")
  assertTrue(lines[1]:find("v2 -> v3, 6 rows touched", 1, true) ~= nil, tostring(lines[1]))
end)

-- ── the adopt path (NS.OnProfileEvent) ───────────────────────────────────────────────────────

--- Run `fn` with a second profile "Alt" whose stored settings differ from Default's, then return to
--- Default and delete it, whatever happens.
local function withAltProfile(altSettings, fn)
  local sv = NS.db.sv
  sv.profiles.Alt = { settings = altSettings }
  local ok, err = pcall(fn)
  muted(function()
    if NS.db:GetCurrentProfile() ~= "Default" then NS.db:SetProfile("Default") end
  end)
  NS.db:DeleteProfile("Alt")
  if not ok then error(err, 0) end
end

test("Profiles: a switch re-reads every setting from the new profile", function()
  -- red under: anything caching the old profile's table (the seam's root, a module's settings read).
  withAltProfile({ qualityThreshold = 4, retentionDays = 0 }, function()
    assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0, "precondition: Default's value")
    muted(function() NS.db:SetProfile("Alt") end)
    assertEqual(NS.Schema:Get("settings.qualityThreshold"), 4, "the switch did not reach the seam")
    assertEqual(NS.Schema:Get("settings.trackItems"), true, "an unstored row does not read its default")
  end)
  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0, "switching back did not restore Default")
end)

test("Profiles: a switch re-caches the capture gate, and leaves the recorded ledger alone", function()
  -- The gate caches the settings and both lists on its hot path; SettingsChanged is what re-caches
  -- it. The ledger is account-wide, so no profile event may touch it.
  -- red under: a handler that sends no SettingsChanged (the gate judges by Default's settings).
  local move = { kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 171276, quantity = 1,
    quality = 1 }
  local before = #NS.db.global.ledger
  withAltProfile({ qualityThreshold = 4, retentionDays = 0 }, function()
    assertEqual(NS.Ledger:GateReason(move), nil, "precondition: Default records it")
    muted(function() NS.db:SetProfile("Alt") end)
    assertEqual(NS.Ledger:GateReason(move), "quality", "the gate still judges by Default's floor")
    assertEqual(#NS.db.global.ledger, before, "the switch touched the recorded ledger")
  end)
  assertEqual(NS.Ledger:GateReason(move), nil, "switching back left the gate on Alt's floor")
end)

test("Profiles: a switch to a disabled profile stands the addon down, and back stands it up", function()
  -- slash-commands-§7: the switch can flip the stored enabled path with no verb and no checkbox.
  -- red under: dropping NS.ReevaluateEnabled from the adopt path.
  withAltProfile({ enabled = false, retentionDays = 0 }, function()
    muted(function() NS.db:SetProfile("Alt") end)
    assertTrue(NS.IsDisabled(), "the disabled profile did not take the hold")
    assertTrue(NS.IsStoodDown(), "the disabled profile did not stand the addon down")
    muted(function() NS.db:SetProfile("Default") end)
    assertFalse(NS.IsDisabled(), "switching back left the addon disabled")
    assertFalse(NS.IsStoodDown(), "switching back left the addon stood down")
  end)
end)

test("Profiles: a switch re-applies the master chrome and the stored geometry to a built window", function()
  -- red under: the adopt path skipping Util.ApplyMasterChrome or B:ApplyGeometry.
  local B = NS.Browser
  muted(function() B:Show() end)
  local frame = B:GetWindow()
  -- The stub frame does not model scale or alpha; record them, as tests/test_util.lua does.
  local savedScale, savedAlpha = rawget(frame, "SetScale"), rawget(frame, "SetAlpha")
  frame.SetScale = function(_, v) frame.scale = v end
  frame.SetAlpha = function(_, v) frame.alpha = v end
  withAltProfile({ windowScale = 1.5, alpha = 0.6, retentionDays = 0,
    window = { point = "TOPLEFT", x = 11, y = -22 } }, function()
    muted(function() NS.db:SetProfile("Alt") end)
    assertEqual(frame.scale, 1.5, "the new profile's scale was not applied")
    assertEqual(frame.alpha, 0.6, "the new profile's alpha was not applied")
    local point, _, _, x, y = frame:GetPoint(1)
    assertEqual(point, "TOPLEFT", "the new profile's geometry was not applied")
    assertEqual(x, 11); assertEqual(y, -22)
  end)
  local backScale = frame.scale
  frame.SetScale, frame.SetAlpha = savedScale, savedAlpha
  muted(function() B:Hide() end)
  assertEqual(backScale, 1.0, "switching back left Alt's scale")
end)

test("Profiles: one profile event is one SettingsChanged and one LedgerChanged", function()
  -- architecture-§4: one act, one message each. The reason names the act.
  -- red under: a per-row broadcast, or a second SettingsChanged from a helper the handler calls.
  local settings, ledger = {}, 0
  local target = NS.NewBusTarget()
  target:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, reason) settings[#settings + 1] = reason end)
  target:RegisterMessage(NS.MSG.LEDGER_CHANGED, function() ledger = ledger + 1 end)
  local ok, err = pcall(withAltProfile, { retentionDays = 0 }, function()
    muted(function() NS.db:SetProfile("Alt") end)
  end)
  target:UnregisterMessage(NS.MSG.SETTINGS_CHANGED)
  target:UnregisterMessage(NS.MSG.LEDGER_CHANGED)
  if not ok then error(err, 0) end
  -- Two switches ran: to Alt, and back to Default in withAltProfile's cleanup.
  assertEqual(#settings, 2, "expected one SettingsChanged per switch: " .. table.concat(settings, ","))
  assertEqual(settings[1], "profile", "the reason names the act")
  assertEqual(ledger, 2, "expected one LedgerChanged per switch")
end)

test("Profiles: a switch logs exactly one [Profile] line naming the profile, and no [Set] line", function()
  -- debug-logging-§10: a switch rewrites no rows, so it is not a [Set] line.
  -- red under: a missing line, a per-row [Set] line, or a second line from anywhere.
  local lines
  withAltProfile({ retentionDays = 0 }, function()
    lines = debugLines(function() NS.db:SetProfile("Alt") end)
  end)
  local prof, set = withTag(lines, "[Profile]"), withTag(lines, "[Set]")
  assertEqual(#prof, 1, "one line for the one switch, got:\n" .. table.concat(lines, "\n"))
  assertTrue(prof[1]:find("switched to profile 'Alt'", 1, true) ~= nil, tostring(prof[1]))
  assertEqual(#set, 0, "a switch wrote a [Set] line: " .. table.concat(set, "\n"))
end)

--- Run `fn` with the account-wide ledger swapped for `entries`, and put the suite's own back
--- afterwards whatever happens. The adopt path runs the retention prune, so a test that keeps the
--- shipped 30-day window must choose what that prune can see.
local function withLedger(entries, fn)
  local saved = NS.db.global.ledger
  NS.db.global.ledger = entries
  local ok, err = pcall(fn)
  NS.db.global.ledger = saved
  if not ok then error(err, 0) end
end

--- Every line in `lines` except the views' one-per-pass render summaries (debug-logging-§9): the
--- History table's `[Table] rendered …` and the Insights `[Insights] computed …`. A profile event
--- repaints the built views, exactly as any setting change does, and each pass is its own flow's
--- one line; they are not the act's log, which is what debug-logging-§10 counts. Anything else --
--- a [Prune], a per-row [Set], a second [Profile] -- stays in, so the count below is every line
--- the act and its reactors wrote.
local RENDER_PASS = { "[Table] rendered ", "[Insights] computed " }
local function withoutRenderPasses(lines)
  local out = {}
  for _, line in ipairs(lines) do
    local render = false
    for _, tag in ipairs(RENDER_PASS) do
      if line:find(tag, 1, true) then render = true; break end
    end
    if not render then out[#out + 1] = line end
  end
  return out
end

local function recentEntry(ts)
  return { ts = ts, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
    itemID = 2589, itemName = "Linen Cloth", quantity = 1 }
end

test("Profiles: under the shipped 30-day retention, a switch, a copy and a reset each log their one line and no no-op [Prune] line", function()
  -- debug-logging-§10: the act's line is the only one. The adopt path runs the retention prune, and
  -- a prune that removes nothing is no material effect, so it must not add a [Prune] line. Counts
  -- EVERY line, not one tag: the fixtures elsewhere set retentionDays = 0, which skips the prune.
  -- red under: applyProfileEffects calling PruneOld without its quiet-if-none flag.
  local now = T.mocks.__now
  local switch, copy, reset
  withLedger({ recentEntry(now) }, function()
    withAltProfile({ qualityThreshold = 2 }, function()
      assertEqual(NS.db.profile.settings.retentionDays, 30, "precondition: Default keeps 30 days")
      switch = debugLines(function() NS.db:SetProfile("Alt") end)
      assertEqual(NS.db.profile.settings.retentionDays, 30, "precondition: Alt keeps 30 days")
      muted(function() NS.db:SetProfile("Default") end)
      copy = debugLines(function() NS.db:CopyProfile("Alt") end)
      reset = debugLines(function() NS.db:ResetProfile() end)
    end)
    assertEqual(#NS.db.global.ledger, 1, "a recent entry was pruned")
  end)
  switch, copy, reset = withoutRenderPasses(switch), withoutRenderPasses(copy), withoutRenderPasses(reset)
  assertEqual(#switch, 1, "a switch wrote more than its line:\n" .. table.concat(switch, "\n"))
  assertTrue(switch[1]:find("[Profile] switched to profile 'Alt'", 1, true) ~= nil, tostring(switch[1]))
  assertEqual(#copy, 1, "a copy wrote more than its line:\n" .. table.concat(copy, "\n"))
  assertTrue(copy[1]:find("copied profile 'Alt' -> 'Default'", 1, true) ~= nil, tostring(copy[1]))
  assertEqual(#reset, 1, "a reset wrote more than its line:\n" .. table.concat(reset, "\n"))
  assertTrue(reset[1]:find("reset profile 'Default' to defaults", 1, true) ~= nil, tostring(reset[1]))
end)

test("Profiles: a profile event whose retention prune removes rows still reports them, as a material effect", function()
  -- debug-logging-§10 lets a reactor log a material effect the act's line cannot show: history that
  -- aged out under the new profile's window. docs/profiles.md names this one extra [Prune] line.
  -- red under: the adopt path silencing the prune outright, so history goes with no trace.
  local now = T.mocks.__now
  local lines
  withLedger({ recentEntry(now), recentEntry(now - 60 * 86400) }, function()
    withAltProfile({ retentionDays = 30 }, function()
      lines = withoutRenderPasses(debugLines(function() NS.db:SetProfile("Alt") end))
    end)
    assertEqual(#NS.db.global.ledger, 1, "the 60-day-old entry was not aged out")
  end)
  assertEqual(#lines, 2, "expected the switch line and one prune line:\n" .. table.concat(lines, "\n"))
  local prune = withTag(lines, "[Prune]")
  assertEqual(#prune, 1, "no [Prune] line for the removed row:\n" .. table.concat(lines, "\n"))
  assertTrue(prune[1]:find("removed 1 entries", 1, true) ~= nil, tostring(prune[1]))
  assertEqual(#withTag(lines, "[Profile]"), 1, "the switch line is missing")
end)

test("Profiles: a copy logs one [Set] line naming both profiles, and takes the source's values", function()
  -- red under: the copy line carrying the active profile as its source (AceDB passes the SOURCE).
  local lines, q
  withAltProfile({ qualityThreshold = 2, retentionDays = 0 }, function()
    lines = withTag(debugLines(function() NS.db:CopyProfile("Alt") end), "[Set]")
    q = NS.Schema:Get("settings.qualityThreshold")
    muted(function() NS.db:ResetProfile() end)
  end)
  assertEqual(#lines, 1, "one line for the one copy")
  assertTrue(lines[1]:find("copied profile 'Alt' -> 'Default'", 1, true) ~= nil, tostring(lines[1]))
  assertEqual(q, 2, "the copy did not take the source's value")
end)

test("Profiles: AceDBOptions' own Reset Profile is the same act, and logs its line without a count", function()
  -- The reset from the Profiles page does not come through Sl:ResetEverything, so nothing counted
  -- its rows; the line MAY omit N (debug-logging-§10). A count left pending by an earlier reset
  -- must not leak into it.
  -- red under: a stale pending count, or no line at all for a page-driven reset.
  muted(function() NS.Schema:Set("settings.qualityThreshold", 4) end)
  local lines = withTag(debugLines(function() NS.db:ResetProfile() end), "[Set]")
  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0, "the reset did not reset")
  assertEqual(#lines, 1, "one line for the one reset")
  assertTrue(lines[1]:find("reset profile 'Default' to defaults", 1, true) ~= nil, tostring(lines[1]))
  assertTrue(lines[1]:find("rows)", 1, true) == nil, "a count was invented: " .. tostring(lines[1]))
end)

test("Profiles: AceDBOptions' own Reset Profile ends test mode and closes the debug console, as Reset all settings does", function()
  -- options-ui-§12: the page's Reset Profile and Reset all settings MUST be the same act, and the
  -- act ends the session-only rows a profile reset cannot reach. The page calls db:ResetProfile()
  -- directly, so the handler, not Sl:ResetEverything, has to do it.
  -- red under: ending the session rows in Sl:ResetEverything only.
  local ok, err = pcall(function()
    muted(function()
      NS.Schema:Set("state.testMode", true)
      NS.DebugLog:Show()
    end)
    assertTrue(NS.LedgerTable:IsTestMode(), "precondition: test mode is on")
    muted(function() NS.db:ResetProfile() end)
    assertFalse(NS.LedgerTable:IsTestMode(), "the page's reset left test mode on")
    assertFalse(NS.DebugLog:IsShown(), "the page's reset left the console open")
  end)
  NS.State.testRecords = nil
  muted(function() NS.Browser:Hide() end)
  NS.DebugLog:Hide()
  if not ok then error(err, 0) end
end)

test("Profiles: a switch leaves test mode alone", function()
  -- A switch is not a reset; ending the player's preview on one would be a surprise.
  -- red under: ending the session rows on every profile event.
  local on
  local ok, err = pcall(withAltProfile, { retentionDays = 0 }, function()
    muted(function() NS.Schema:Set("state.testMode", true) end)
    muted(function() NS.db:SetProfile("Alt") end)
    on = NS.LedgerTable:IsTestMode()
  end)
  muted(function() NS.Schema:Set("state.testMode", false) end)
  NS.State.testRecords = nil
  muted(function() NS.Browser:Hide() end)
  if not ok then error(err, 0) end
  assertTrue(on, "a profile switch ended test mode")
end)

test("Profiles: the global reset's blast radius is the active profile — the list, the other profiles and the ledger survive", function()
  -- options-ui-§12 "Testing (MUST)": after a global reset with two or more of what a player adds,
  -- exactly the shipped set survives; the profile LIST is unchanged and the active profile is still
  -- the one you were on; and the profile-changed message went out.
  -- red under: a reset that deletes or switches profiles, reaches another profile, or keeps an id.
  local reasons, names, current, altQ, bl, ledger = {}, nil, nil, nil, nil, nil
  local before = #NS.db.global.ledger
  local target = NS.NewBusTarget()
  target:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, r) reasons[#reasons + 1] = r end)
  local ok, err = pcall(withAltProfile, { qualityThreshold = 3, retentionDays = 0 }, function()
    muted(function()
      NS.Filters:AddBlacklist(2589)
      NS.Filters:AddBlacklist(4306)
      NS.Schema:Set("settings.qualityThreshold", 4)
    end)
    reasons = {}
    muted(function() NS.Slash:ResetEverything() end)
    names = table.concat((NS.db:GetProfiles()), ",")
    current = NS.db:GetCurrentProfile()
    bl = NS.Filters:Count(NS.Filters:Blacklist())
    ledger = #NS.db.global.ledger
    altQ = NS.db.sv.profiles.Alt.settings.qualityThreshold
  end)
  target:UnregisterMessage(NS.MSG.SETTINGS_CHANGED)
  if not ok then error(err, 0) end
  assertEqual(names, "Alt,Default", "the reset changed the profile list")
  assertEqual(current, "Default", "the reset switched profile")
  assertEqual(bl, 0, "the reset kept a player-added id")
  assertEqual(NS.Schema:Get("settings.qualityThreshold"), 0, "the reset kept a setting")
  assertEqual(altQ, 3, "the reset reached another profile")
  assertEqual(ledger, before, "the reset touched the recorded ledger")
  assertEqual(reasons[1], "profile", "the profile-changed message did not go out")
end)

-- ── the Profiles page (options-ui-§3) ─────────────────────────────────────────────────────────

test("Profiles page: registered after General, with no Defaults button, over AceDBOptions' table for NS.db", function()
  -- red under: registering it at file load (it would precede General), a Defaults button (a second
  -- reset beside Reset Profile), or handing AceDBOptions some other db.
  NS.Panel:Register()
  local frame = mocks.__settingsPanels["Profiles"]
  assertTrue(frame ~= nil, "the Profiles page was not registered")
  local order = {}
  for _, page in ipairs(NS.Helpers.__pages()) do order[#order + 1] = page.key end
  assertEqual(order[#order], "profiles", "Profiles is not the last page: " .. table.concat(order, ","))
  local opts = mocks.__aceConfig.tables["BankLedger-Profiles"]
  assertTrue(opts ~= nil, "no options table was registered")
  assertEqual(opts.handler, NS.db, "the options table was built for another db")
  local ctx = NS.ProfilesPage.ctx
  assertTrue(ctx ~= nil, "the page kept no context")
  frame:__fire("OnShow")
  assertEqual(rawget(ctx.panel, "defaultsBtn"), nil, "the Profiles page grew a Defaults button")
  local opened = mocks.__aceConfig.opened
  assertEqual(opened[#opened].app, "BankLedger-Profiles", "the first show did not open the table")
  assertTrue(opened[#opened].container.frame:IsShown(), "AceConfigDialog was handed a hidden frame")
end)
