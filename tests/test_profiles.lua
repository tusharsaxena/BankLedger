-- tests/test_profiles.lua — settings per profile (schema v3 and v4, docs/profiles.md).
--
-- What a profile holds and what stays account-wide, the one-time lift of the pre-v3 settings into
-- the Default profile, the v4 return of the retention window to db.global (owner decision D6), and
-- the one adopt path every profile event takes (NS.OnProfileEvent): the migrations, the enable
-- latch, every setting's effect re-applied, the panel refreshed and exactly one debug line, and
-- never a prune. And the Profiles page itself, and the global reset's veto (options-ui-§3, §12).

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

--- One recorded movement at `ts`, for the fixtures below.
local function recentEntryAt(ts)
  return { ts = ts, char = "A-R", kind = "ITEM", direction = "DEPOSIT", store = "BANK",
    itemID = 2589, itemName = "Linen Cloth", quantity = 1 }
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

test("Profiles: the defaults split — the ledger, its retention window and the minimap table are account-wide, everything else configured is per profile", function()
  -- D5 (settings only): recorded data stays account-wide; the settings, both filter lists and the
  -- saved view move into the profile. D6: the retention window, which governs the recorded data,
  -- stays account-wide and is the ONE settings key declared there.
  -- red under: a settings key left in (or put back into) defaults/Global.lua, or retentionDays
  -- declared per profile again.
  local g, p = NS.defaults.global, NS.defaults.profile
  assertTrue(type(g.ledger) == "table", "the ledger is account-wide")
  assertTrue(type(g.minimap) == "table", "LibDBIcon's table is account-wide")
  assertEqual(g.schemaVersion, 0, "the stamp is account-wide, and declared as 0")
  for _, key in ipairs({ "blacklist", "whitelist", "savedView" }) do
    assertEqual(g[key], nil, key .. " is still declared account-wide")
  end
  local globalKeys = {}
  for k in pairs(g.settings or {}) do globalKeys[#globalKeys + 1] = k end
  table.sort(globalKeys)
  assertEqual(table.concat(globalKeys, ","), "retentionDays",
    "the account-wide settings are the retention window and nothing else")
  assertEqual(g.settings.retentionDays, 30, "the account-wide window's default")
  assertEqual(p.settings.retentionDays, nil, "the retention window is declared per profile")
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
  local gs = rawget(NS.db.global, "settings")
  local inGlobal = type(gs) == "table" and rawget(gs, "qualityThreshold") or nil
  NS.Schema:Set("settings.qualityThreshold", saved)
  assertEqual(inProfile, 4, "the write did not reach db.profile.settings")
  assertEqual(inGlobal, nil, "the write reached db.global.settings")
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
    assertEqual(db.global.schemaVersion, NS.SCHEMA_VERSION, "stamped current")
    local p = sv.profiles.Default
    assertTrue(type(p) == "table", "the Default profile was not created")
    assertEqual(p.settings.qualityThreshold, 3, "a stored setting did not move")
    assertEqual(p.settings.trackMoney, false, "a stored false did not move")
    assertEqual(p.settings.window.point, "TOP", "a stored geometry table did not move")
    assertEqual(p.blacklist[2589], true, "the blacklist did not move")
    assertEqual(p.whitelist[4306], true, "the whitelist did not move")
    assertEqual(p.savedView.groupBy, "store", "the saved view did not move")
    for _, key in ipairs({ "blacklist", "whitelist", "savedView" }) do
      assertEqual(rawget(db.global, key), nil, key .. " was left in db.global")
    end
    for _, key in ipairs({ "qualityThreshold", "trackMoney", "window" }) do
      assertEqual(rawget(db.global.settings, key), nil, "settings." .. key .. " was left in db.global")
    end
  end)
end)

test("Migrate v3: the retention window stays in db.global and is not lifted (D6)", function()
  -- A v2 store keeps its retention choice under global.settings; the lift leaves it there.
  -- red under: the step lifting every settings key, retentionDays included, into the profile.
  local sv = legacyStore()
  sv.global.settings.retentionDays = 7
  withDb(sv, function(db)
    NS:RunMigrations()
    assertEqual(rawget(db.global.settings, "retentionDays"), 7, "the player's window left db.global")
    assertEqual(rawget(sv.profiles.Default.settings, "retentionDays"), nil,
      "the window was lifted into the Default profile")
    assertEqual(NS.Schema:Get("settings.retentionDays"), 7, "the row does not read the kept value")
    assertEqual(sv.profiles.Default.settings.qualityThreshold, 3, "the other settings did not move")
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
    assertEqual(db.global.schemaVersion, NS.SCHEMA_VERSION)
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
  -- Three settings, two lists and a view: six rows. v4 finds nothing to move on this store.
  -- red under: a step that returns 0, or counts the keys rather than the values.
  local lines
  withDb(legacyStore(), function()
    lines = withTag(debugLines(function() NS:RunMigrations() end), "[Migrate]")
  end)
  assertEqual(#lines, 1, "one migration line")
  assertTrue(lines[1]:find("v2 -> v4, 6 rows touched", 1, true) ~= nil, tostring(lines[1]))
end)

-- ── the v4 step: the retention window back to db.global (owner decision D6) ─────────────────────

--- A store a pre-D6 build of v3 wrote: stamped 3, the settings in profiles, and the retention window
--- lifted with them, into Default and into a second profile the player made afterwards.
local function preD6Store()
  return {
    global = { schemaVersion = 3, ledger = { recentEntryAt(1) } },
    profiles = {
      Default = { settings = { qualityThreshold = 3, retentionDays = 7 } },
      Alt = { settings = { retentionDays = 0 } },
    },
  }
end

test("Migrate v4: a profile's retention window goes back to db.global, the Default profile's value winning", function()
  -- red under: a missing v4 (the window stays per profile and the row reads 30), a step that picks
  -- Alt's value over Default's, or one that copies without clearing the profiles, or one that
  -- counts a key's PRESENCE in db.global as the player's choice (savedvariables-§1): real AceDB
  -- copyDefaults rawsets the declared 30 into db.global.settings on first access, before v4 runs,
  -- and the mock keeps scalar defaults behind __index, so the fixture writes that backfill itself.
  -- A presence-only step would let the backfilled 30 win and silently undo a player's Always (0).
  local sv = preD6Store()
  sv.global.settings = { retentionDays = 30 }
  withDb(sv, function(db)
    local n = NS.MIGRATIONS[4](db.global, db)
    db.global.schemaVersion = 4
    assertEqual(n, 2, "one row per profile value removed")
    assertEqual(rawget(db.global.settings, "retentionDays"), 7, "the Default profile's window did not win")
    assertEqual(rawget(sv.profiles.Default.settings, "retentionDays"), nil, "Default still holds a window")
    assertEqual(rawget(sv.profiles.Alt.settings, "retentionDays"), nil, "Alt still holds a window")
    assertEqual(sv.profiles.Default.settings.qualityThreshold, 3, "another setting was touched")
    assertEqual(#db.global.ledger, 1, "the ledger was touched")
    assertEqual(NS.Schema:Get("settings.retentionDays"), 7, "the row does not read the moved value")
  end)
end)

test("Migrate v4: idempotent — a second run moves nothing, and the runner stamps v4", function()
  -- red under: a step that re-reads a cleared key, or one that resets global on an empty pass.
  local sv = preD6Store()
  withDb(sv, function(db)
    NS:RunMigrations()
    assertEqual(db.global.schemaVersion, 4, "stamped v4")
    local again = NS.MIGRATIONS[4](db.global, db)
    assertEqual(again, 0, "the second pass moved something")
    assertEqual(rawget(db.global.settings, "retentionDays"), 7, "the second pass changed the window")
  end)
end)

test("Migrate v4: a player choice already in db.global is kept over a profile's copy", function()
  -- Global holds a value off the declared default, so the player chose it there; a profile's copy
  -- is cleared, not promoted.
  -- red under: a step that lets the first profile's value overwrite global unconditionally.
  local sv = preD6Store()
  sv.global.settings = { retentionDays = 90 }
  withDb(sv, function(db)
    NS.MIGRATIONS[4](db.global, db)
    assertEqual(rawget(db.global.settings, "retentionDays"), 90, "global's own choice was overwritten")
    assertEqual(rawget(sv.profiles.Default.settings, "retentionDays"), nil, "Default still holds a window")
  end)
end)

test("Migrate v4: a Default profile with no stored window keeps its implicit 30 over another profile's shorter one", function()
  -- The pre-D6 build declared 30 in the profile defaults and AceDB's logout strip removed a stored
  -- 30, so a Default profile WITHOUT the key held 30. The shorter Alt window must not become the
  -- account-wide one, or the next login prune deletes shared history Default's characters kept.
  -- red under: a step that reads the absent key as "Default holds nothing" and falls through to
  -- the next profile (savedvariables-§1's forbidden presence test): global would read 7, and the
  -- prune below would drop the ten-day-old movement.
  local now = mocks.__now
  local sv = {
    global = { schemaVersion = 3, settings = { retentionDays = 30 },
      ledger = { recentEntryAt(now - 10 * 86400) } },
    profiles = {
      Default = { settings = { qualityThreshold = 3 } },
      Alt = { settings = { retentionDays = 7 } },
    },
  }
  withDb(sv, function(db)
    local n
    muted(function()
      n = NS.MIGRATIONS[4](db.global, db)
      db.global.schemaVersion = 4
    end)
    assertEqual(n, 1, "one row per profile value removed")
    assertEqual(rawget(db.global.settings, "retentionDays"), 30, "another profile's window was promoted")
    assertEqual(rawget(sv.profiles.Alt.settings, "retentionDays"), nil, "Alt still holds a window")
    assertEqual(sv.profiles.Default.settings.qualityThreshold, 3, "another setting was touched")
    assertEqual(NS.Schema:Get("settings.retentionDays"), 30, "the row does not read Default's window")
    local pruned
    muted(function() pruned = NS.Database:PruneOld() end)
    assertEqual(pruned, 0, "the login prune deleted shared history Default kept")
    assertEqual(#db.global.ledger, 1, "the ten-day-old movement is gone")
  end)
end)

test("Migrate v4: a store with no Default profile resolves to the pre-D6 default, not the first other profile", function()
  -- red under: a step that promotes the first other profile's window in name order.
  local sv = {
    global = { schemaVersion = 3, settings = { retentionDays = 30 }, ledger = {} },
    profiles = { Alt = { settings = { retentionDays = 7 } }, Main = { settings = { retentionDays = 14 } } },
  }
  withDb(sv, function(db)
    assertEqual(NS.MIGRATIONS[4](db.global, db), 2, "one row per profile value removed")
    assertEqual(rawget(db.global.settings, "retentionDays"), 30, "another profile's window was promoted")
    assertEqual(rawget(sv.profiles.Alt.settings, "retentionDays"), nil, "Alt still holds a window")
    assertEqual(rawget(sv.profiles.Main.settings, "retentionDays"), nil, "Main still holds a window")
  end)
end)

test("Migrate v4: a store with no profile window is left alone", function()
  -- A v2 upgrade takes the new v3, which never lifts the window, so v4 has nothing to do.
  -- red under: a step that raises on a profile with no settings table, or counts nothing as a row.
  local sv = { global = { schemaVersion = 3, ledger = {} },
    profiles = { Default = { settings = { trackMoney = false } }, Bare = {} } }
  withDb(sv, function(db)
    assertEqual(NS.MIGRATIONS[4](db.global, db), 0, "rows were counted where nothing moved")
    assertEqual(sv.profiles.Default.settings.trackMoney, false, "an unrelated setting was touched")
  end)
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
--- afterwards whatever happens. No profile event prunes (D6), so the entries a test picks are what
--- lets it prove that: an entry past the 30-day window is one only a prune could take.
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

test("Profiles: under the shipped 30-day retention, a switch, a copy and a reset each log their one line and nothing else", function()
  -- debug-logging-§10: the act's line is the only one. Counts EVERY line, not one tag, so a
  -- [Prune] line (a profile event must not prune at all, D6) or a per-row [Set] line shows up.
  -- red under: the adopt path running the retention prune, or any reactor logging beside the act.
  local now = T.mocks.__now
  local switch, copy, reset
  withLedger({ recentEntryAt(now) }, function()
    withAltProfile({ qualityThreshold = 2 }, function()
      assertEqual(NS.Database:RetentionDays(), 30, "precondition: the account keeps 30 days")
      switch = debugLines(function() NS.db:SetProfile("Alt") end)
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

test("Profiles: a switch, a copy, a profile reset and the global reset never prune recorded history (D6)", function()
  -- Owner decision D6: a profile event never prunes or deletes history. The ledger holds a movement
  -- older than the 30-day window, one the next LOGIN would age out; no profile act may take it,
  -- even when the profile switched to still carries a stale window of its own.
  -- red under: the adopt path calling Database:PruneOld (any profile event would drop the old row),
  -- or retention read from the profile (Alt's stale 1-day window).
  local now = T.mocks.__now
  local old, recent = recentEntryAt(now - 60 * 86400), recentEntryAt(now)
  local after, prunes = {}, 0
  withLedger({ old, recent }, function()
    withAltProfile({ qualityThreshold = 2, retentionDays = 1 }, function()
      assertEqual(NS.Database:RetentionDays(), 30, "precondition: the account keeps 30 days")
      local acts = {
        { "switch", function() NS.db:SetProfile("Alt") end },
        { "switch back", function() NS.db:SetProfile("Default") end },
        { "copy", function() NS.db:CopyProfile("Alt") end },
        { "profile reset", function() NS.db:ResetProfile() end },
        { "global reset", function() NS.Slash:ResetEverything() end },
      }
      for _, act in ipairs(acts) do
        prunes = prunes + #withTag(debugLines(act[2]), "[Prune]")
        after[#after + 1] = { act[1], #NS.db.global.ledger, NS.db.global.ledger[1] }
      end
    end)
  end)
  for _, a in ipairs(after) do
    assertEqual(a[2], 2, "the " .. a[1] .. " pruned recorded history")
    assertTrue(a[3] == old, "the " .. a[1] .. " rewrote the ledger")
  end
  assertEqual(prunes, 0, "a profile event ran the retention prune")
end)

test("Profiles: a profile reset and the global reset leave the retention window alone", function()
  -- D6: the window is account-wide, so no settings reset moves it. From Always (0) back to the
  -- 30-day default would delete every older movement at the next login.
  -- red under: the window stored in the profile (the reset takes it), or a reset that walks it.
  local saved = NS.Schema:Get("settings.retentionDays")
  local afterProfile, afterGlobal
  local ok, err = pcall(function()
    muted(function() NS.Schema:Set("settings.retentionDays", 0) end)
    muted(function() NS.db:ResetProfile() end)
    afterProfile = NS.Schema:Get("settings.retentionDays")
    muted(function() NS.Slash:ResetEverything() end)
    afterGlobal = NS.Schema:Get("settings.retentionDays")
  end)
  muted(function() NS.Schema:Set("settings.retentionDays", saved) end)
  if not ok then error(err, 0) end
  assertEqual(afterProfile, 0, "Reset Profile moved the account-wide window")
  assertEqual(afterGlobal, 0, "Reset all settings moved the account-wide window")
end)

-- ── the retention window is account-wide (owner decision D6) ───────────────────────────────────

test("Retention: a write lands in db.global, never in a profile, and every profile reads the one value", function()
  -- D6: the window governs the SHARED ledger, so it is one value for the account.
  -- red under: the row losing its own get/set (the seam's walk stores it in the profile), or
  -- Database:RetentionDays / PruneOld reading db.profile again.
  local saved = NS.Schema:Get("settings.retentionDays")
  local inGlobal, inProfile, onAlt, pruneReads
  local ok, err = pcall(withAltProfile, { qualityThreshold = 2 }, function()
    muted(function() NS.Schema:Set("settings.retentionDays", 7) end)
    inGlobal = rawget(NS.db.global.settings, "retentionDays")
    inProfile = rawget(NS.db.profile.settings, "retentionDays")
    muted(function() NS.db:SetProfile("Alt") end)
    onAlt = NS.Schema:Get("settings.retentionDays")
    pruneReads = NS.Database:RetentionDays()
  end)
  muted(function() NS.Schema:Set("settings.retentionDays", saved) end)
  if not ok then error(err, 0) end
  assertEqual(inGlobal, 7, "the write did not reach db.global.settings")
  assertEqual(inProfile, nil, "the write reached the profile")
  assertEqual(onAlt, 7, "another profile reads a window of its own")
  assertEqual(pruneReads, 7, "the prune reads a window other than the account-wide one")
end)

test("Retention: a stale per-profile value is never what the prune reads", function()
  -- A profile table carrying `retentionDays` (a pre-D6 build's leftover, or a hand edit) must not
  -- decide what is pruned.
  -- red under: PruneOld reading db.profile.settings.retentionDays.
  local now = T.mocks.__now
  local left
  withLedger({ recentEntryAt(now), recentEntryAt(now - 60 * 86400) }, function()
    local savedG = NS.Schema:Get("settings.retentionDays")
    NS.db.global.settings.retentionDays = 0
    NS.db.profile.settings.retentionDays = 30
    local ok, err = pcall(function() muted(function() NS.Database:PruneOld() end) end)
    NS.db.profile.settings.retentionDays = nil
    NS.db.global.settings.retentionDays = savedG
    if not ok then error(err, 0) end
    left = #NS.db.global.ledger
  end)
  assertEqual(left, 2, "the profile's stale 30 days pruned history the account keeps Always")
end)

test("Retention: the Settings tooltip says the window is account-wide", function()
  -- D6: the panel gives no other hint that this row is shared across profiles.
  -- red under: the tooltip losing its account-wide sentence.
  local row = NS.Schema:FindRow("settings.retentionDays")
  assertTrue(row ~= nil and type(row.tooltip) == "string", "the row has no tooltip")
  assertTrue(row.tooltip:find("Account-wide", 1, true) ~= nil, tostring(row.tooltip))
  assertTrue(row.tooltip:find("every profile", 1, true) ~= nil, tostring(row.tooltip))
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

-- ── the global reset's veto, named once (options-ui-§3, options-ui-§12) ────────────────────────

test("Reset veto: S.VetoedFromResetAll vetoes the Profiles page and every stored row, and passes the session-only rows", function()
  -- options-ui-§3: the Profiles page is excluded from the global reset by the descriptor's
  -- `skipRestoreAll`, named once; options-ui-§12: it vetoes the page and every row whose value lives
  -- in the profile. The account-wide rows (minimap, retention) are stored too, and vetoed with them.
  -- red under: a veto that lets a profile row, the retention row or a Profiles-page row through, or
  -- one that vetoes a session-only row (the profile reset cannot reach it, so the walk must).
  local S = NS.Schema
  local veto = S.VetoedFromResetAll
  assertTrue(type(veto) == "function", "no named veto")
  assertEqual(S.PROFILES_PAGE, "profiles", "the Profiles page key")
  assertTrue(veto({ page = S.PROFILES_PAGE, sessionOnly = true }), "a Profiles-page row got through")
  for _, path in ipairs({ "settings.qualityThreshold", "settings.enabled", S.RETENTION_PATH,
      S.MINIMAP_PATH }) do
    local row = S:FindRow(path)
    assertTrue(row ~= nil, "no row " .. path)
    assertTrue(veto(row), path .. " is not vetoed")
  end
  for _, path in ipairs({ "state.testMode", "state.debugConsole" }) do
    local row = S:FindRow(path)
    assertTrue(row ~= nil and row.sessionOnly, "precondition: " .. path .. " is session-only")
    assertFalse(veto(row), path .. " is vetoed, so a reset would leave it on")
  end
end)

test("Reset veto: the Options descriptor passes it as skipRestoreAll, and the Profiles page keys itself by it", function()
  -- The wiring, read from the source: the library keeps its descriptor private.
  -- red under: dropping `skipRestoreAll` from settings/OptionsSetup.lua, or the page keyed by a
  -- literal the veto does not name.
  local function read(path)
    local fh = assert(io.open(path, "rb"))
    local body = fh:read("*a")
    fh:close()
    return body
  end
  assertTrue(read("settings/OptionsSetup.lua"):match("skipRestoreAll%s*=%s*NS%.Schema%.VetoedFromResetAll") ~= nil,
    "the Options descriptor does not pass the veto as skipRestoreAll")
  assertTrue(read("settings/Profiles.lua"):match("pageKey%s*=%s*NS%.Schema%.PROFILES_PAGE") ~= nil,
    "the Profiles page is not keyed by the veto's page name")
end)

test("Reset veto: the library's global reset over this descriptor ends the session rows, resets the profile, and keeps the window and the history", function()
  -- O.RestoreAllDefaults is not on a live path here (the addon's reset is Sl:ResetEverything), but
  -- the descriptor hands it the veto, so the walk it would make is pinned: session rows restored,
  -- the profile reset, the retention window and the recorded ledger untouched (D6).
  -- red under: a veto that lets the retention row through (the walk would put Always back to 30
  -- days), or one that stops the walk ending test mode.
  local now = T.mocks.__now
  local saved = NS.Schema:Get("settings.retentionDays")
  local q, window, testMode, left
  withLedger({ recentEntryAt(now - 900 * 86400) }, function()
    local ok, err = pcall(function()
      muted(function()
        NS.Schema:Set("settings.retentionDays", 0)
        NS.Schema:Set("settings.qualityThreshold", 4)
        NS.Schema:Set("state.testMode", true)
        NS.Helpers.RestoreAllDefaults()
      end)
      q = NS.Schema:Get("settings.qualityThreshold")
      window = NS.Schema:Get("settings.retentionDays")
      testMode = NS.LedgerTable:IsTestMode()
      left = #NS.db.global.ledger
    end)
    NS.State.testRecords = nil
    muted(function()
      NS.Browser:Hide()
      NS.Schema:Set("settings.retentionDays", saved)
    end)
    if not ok then error(err, 0) end
  end)
  assertEqual(q, 0, "the profile was not reset")
  assertEqual(window, 0, "the reset moved the account-wide retention window")
  assertFalse(testMode, "the reset left test mode on")
  assertEqual(left, 1, "the reset pruned recorded history")
end)

-- ── the /bl profile verb (LibKa0s-Slash-1.0 minor 17) ────────────────────────────────────────
--
-- The verb's behavior is the library's (Sl:CliProfile, tests/test_slash_profile.lua in LibKa0s).
-- What is pinned here is this addon's wiring: the COMMANDS row, the descriptor's `profiles` store
-- read at call time, that a switch reaches the adopt path above, and that nothing is ever created.

--- Every chat line `fn` prints.
local function captureChat(fn)
  local out = {}
  local saved = mocks.DEFAULT_CHAT_FRAME.AddMessage
  mocks.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  mocks.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

local function joinedChat(out) return table.concat(out, "\n") end

--- The number of stored profiles, for "nothing was created".
local function profileCount()
  local n = 0
  for _ in pairs(NS.db.sv.profiles) do n = n + 1 end
  return n
end

test("Profile verb: one COMMANDS row, after resetall, described through NS.L", function()
  -- red under: a missing row, a second one, or the row moved away from the settings verbs.
  local at, rows, resetallAt = nil, 0, nil
  for i, cmd in ipairs(NS.COMMANDS) do
    if cmd[1] == "profile" then at, rows = i, rows + 1 end
    if cmd[1] == "resetall" then resetallAt = i end
  end
  assertEqual(rows, 1, "exactly one profile row")
  assertEqual(at, resetallAt + 1, "the profile row sits right after resetall")
  assertEqual(NS.COMMANDS[at][2], "List profiles, or switch to one: profile <name>")
  assertEqual(type(NS.COMMANDS[at][3]), "function")
end)

test("Profile verb: bare /bl profile lists every profile, current marked, then the hint", function()
  -- red under: no `profiles` field on the descriptor (the unavailable line), or a store read once
  -- at load, before InitDB built NS.db.
  withAltProfile({ retentionDays = 0 }, function()
    local out = captureChat(function() NS.Slash:OnSlash("profile") end)
    assertEqual(#out, 4, "the header, Alt, Default and the hint:\n" .. joinedChat(out))
    for _, line in ipairs(out) do
      assertTrue(line:find("|cff00ffff[BL]|r", 1, true) ~= nil, "untagged: " .. line)
      assertFalse(line:match(":%s*$") ~= nil, "a line ends in a colon: " .. line)
    end
    assertTrue(out[1]:find("Profiles", 1, true) ~= nil, out[1])
    assertTrue(out[2]:find("  Alt", 1, true) ~= nil and not out[2]:find("(current)", 1, true), out[2])
    assertTrue(out[3]:find("  Default (current)", 1, true) ~= nil, out[3])
    assertTrue(out[4]:find("/bl profile <name>", 1, true) ~= nil, out[4])
  end)
end)

test("Profile verb: /bl profile <name> switches, and the adopt path runs", function()
  -- red under: a row that does not reach cli:CliProfile, or a store that is not NS.db.
  local lines
  withAltProfile({ qualityThreshold = 4, retentionDays = 0 }, function()
    local out
    lines = debugLines(function()
      out = captureChat(function() NS.Slash:OnSlash("profile Alt") end)
    end)
    assertEqual(NS.db:GetCurrentProfile(), "Alt", "the verb did not switch")
    assertEqual(NS.Schema:Get("settings.qualityThreshold"), 4, "the switch did not reach the seam")
    assertEqual(#out, 1, joinedChat(out))
    assertTrue(out[1]:find("Switched to profile 'Alt'.", 1, true) ~= nil, out[1])
  end)
  local prof = withTag(lines, "[Profile]")
  assertEqual(#prof, 1, "the adopt path's one line:\n" .. table.concat(lines, "\n"))
  assertTrue(prof[1]:find("switched to profile 'Alt'", 1, true) ~= nil, prof[1])
end)

test("Profile verb: quotes are stripped, and case and inner spaces are kept", function()
  -- red under: the host lower-casing or re-splitting `rest` before the library sees it.
  local sv = NS.db.sv
  sv.profiles["My Alt"] = { settings = { retentionDays = 0 } }
  local ok, err = pcall(function()
    captureChat(function() NS.Slash:OnSlash('profile "My Alt"') end)
    assertEqual(NS.db:GetCurrentProfile(), "My Alt", "a quoted name with a space did not switch")
    captureChat(function() NS.Slash:OnSlash("PROFILE 'Default'") end)
    assertEqual(NS.db:GetCurrentProfile(), "Default", "single quotes, upper-case verb")
  end)
  muted(function()
    if NS.db:GetCurrentProfile() ~= "Default" then NS.db:SetProfile("Default") end
  end)
  NS.db:DeleteProfile("My Alt")
  if not ok then error(err, 0) end
end)

test("Profile verb: an unknown name is refused, suggests the near match, and creates nothing", function()
  -- red under: routing the name straight to db:SetProfile, which creates what it is handed.
  withAltProfile({ retentionDays = 0 }, function()
    local before = profileCount()
    local out = captureChat(function() NS.Slash:OnSlash("profile alt") end)
    assertEqual(NS.db:GetCurrentProfile(), "Default", "an unknown name switched")
    assertEqual(profileCount(), before, "an unknown name created a profile")
    assertTrue(NS.db.sv.profiles.alt == nil, "the typo is now a stored profile")
    local all = joinedChat(out)
    assertTrue(all:find("No profile named 'alt'.", 1, true) ~= nil, all)
    assertTrue(all:find("Did you mean 'Alt'?", 1, true) ~= nil, all)
    assertTrue(all:find("Default (current)", 1, true) ~= nil, "the list follows the refusal: " .. all)
  end)
end)

test("Profile verb: the current profile answers already-on, and switches nothing", function()
  local lines = debugLines(function()
    local out = captureChat(function() NS.Slash:OnSlash("profile Default") end)
    assertEqual(#out, 1, joinedChat(out))
    assertTrue(out[1]:find("Already on profile 'Default'.", 1, true) ~= nil, out[1])
  end)
  assertEqual(#withTag(lines, "[Profile]"), 0, "a no-op fired the adopt path")
end)

test("Profile verb: a switch in combat is refused", function()
  -- red under: the verb switching mid-combat; the adopt path re-applies window geometry.
  local savedLockdown = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return true end
  local ok, err = pcall(withAltProfile, { retentionDays = 0 }, function()
    local out = captureChat(function() NS.Slash:OnSlash("profile Alt") end)
    assertEqual(NS.db:GetCurrentProfile(), "Default", "switched in combat")
    assertTrue(joinedChat(out):find("Can't switch profiles in combat.", 1, true) ~= nil, joinedChat(out))
  end)
  mocks.InCombatLockdown = savedLockdown
  if not ok then error(err, 0) end
end)
