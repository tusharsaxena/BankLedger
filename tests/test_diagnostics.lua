-- tests/test_diagnostics.lua — BankLedger's diagnostics report (debug-logging-§14, DX-BL).
--
-- The dispatcher half of the rule -- both forms, while disabled, append, ungated, the brand in both
-- markers, `diag` not running it -- is the kit's shared case, tests/_kit/test_diagnostics_contract.lua,
-- wired in tests/run.lua through Kit.diagnostics. What stays here is this addon's own content:
-- the sections modules/Diagnostics.lua hands the library, and the guarantees the library cannot
-- make for a host (a raising section, a secret value in the ledger, a stood-down engine, a capped
-- list, a closed guild-bank frame).
--
-- Most cases read the report through `NS.DebugLog:BuildDiagnostics()`, which writes nothing, so
-- they do not depend on what earlier suites left in the console. The ones that must see the
-- console itself (append, the cap's end marker) read `NS.DebugLog.buffer`.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local D = NS.DebugLog
local BRAND = "Ka0s Bank Ledger"

--- The report as one string per line, `[tag] msg`, and the raw report table.
local function build(spec)
  local r = D:BuildDiagnostics(spec)
  local lines = {}
  for i, l in ipairs(r.lines) do lines[i] = "[" .. l[1] .. "] " .. l[2] end
  return lines, r
end

local function has(lines, needle)
  for _, l in ipairs(lines) do
    if l:find(needle, 1, true) then return true end
  end
  return false
end

local function count(lines, needle)
  local n = 0
  for _, l in ipairs(lines) do
    if l:find(needle, 1, true) then n = n + 1 end
  end
  return n
end

--- Run `fn` with a set of NS fields swapped, putting every one back whatever happens.
local function with(tbl, key, value, fn)
  local saved = tbl[key]
  tbl[key] = value
  local ok, err = pcall(fn)
  tbl[key] = saved
  if not ok then error(err, 0) end
end

--- Run `fn` against a ledger of `entries`, restoring the real one after.
local function withLedger(entries, fn)
  with(NS.db.global, "ledger", entries, fn)
end

local function entry(i, over)
  local e = {
    ts = 1700000000 + i, char = "Tester-Realm", kind = "ITEM", direction = "DEPOSIT",
    store = "BANK", quantity = 1, itemID = 1000 + i, itemName = "Item " .. i,
    itemLink = "|cff0070dd|Hitem:" .. (1000 + i) .. "::|h[Item " .. i .. "]|h|r",
  }
  for k, v in pairs(over or {}) do e[k] = v end
  return e
end

-- ── the frame of the report ──────────────────────────────────────────────────────────────────

test("diagnostics: the descriptor names the full brand in both markers", function()
  local lines = build()
  assertEqual(lines[1], "[Diag] ==== " .. BRAND .. " diagnostics begin ====")
  assertTrue(lines[#lines]:find("[Diag] ==== " .. BRAND .. " diagnostics end: ", 1, true) == 1,
    "the end marker carries the brand: " .. lines[#lines])
end)

test("diagnostics: every DX-BL section runs, in order, without a failure line", function()
  local lines = build()
  assertEqual(count(lines, "failed:"), 0, "a section raised:\n" .. table.concat(lines, "\n"))
  local order = { "[State] ", "[Set] ", "[Filter] ", "[Ledger] ", "[Capture] ", "[Session] ",
    "[Scan] ", "[Window] ", "[Launcher] ", "[Env] " }
  local last = 0
  for _, tag in ipairs(order) do
    local at
    for i, l in ipairs(lines) do
      if l:find(tag, 1, true) == 1 then at = i; break end
    end
    assertTrue(at ~= nil, "no " .. tag .. "line in the report")
    assertTrue(at > last, tag .. "is out of order")
    last = at
  end
end)

test("diagnostics: the report stays inside the DX-BL size estimate on the test world", function()
  local lines = build()
  assertTrue(#lines <= 250, "the report ran to " .. #lines .. " lines")
end)

-- ── the sections ─────────────────────────────────────────────────────────────────────────────

test("diagnostics: the state section reports the stored switch, the holds and test mode", function()
  local lines = build()
  assertTrue(has(lines, "[State] stored enabled=true disabled=false stood down=false"),
    "the lifecycle line")
  assertTrue(has(lines, "[State] holds: -"), "no hold is held on a running addon")
  assertTrue(has(lines, "[State] schema stored=" .. tostring(NS.db.global.schemaVersion)
    .. " code=" .. tostring(NS.SCHEMA_VERSION) .. " profile=account-wide"), "the schema line")
  assertTrue(has(lines, "[State] test mode=false"), "the test-mode line")
end)

test("diagnostics: the capture-critical rows print even at their defaults", function()
  local lines = build()
  for _, path in ipairs({ "settings.enabled", "settings.trackItems", "settings.trackMoney",
    "settings.qualityThreshold", "settings.excludedStores", "settings.retentionDays" }) do
    assertTrue(has(lines, "[Set] " .. path .. " = "), path .. " was not printed")
  end
end)

test("diagnostics: a changed setting prints as path = value (default)", function()
  local S = NS.Schema
  local saved = S:Get("settings.rowStripeAlpha")
  S:Set("settings.rowStripeAlpha", 0.2)
  local ok, err = pcall(function()
    assertTrue(has(build(), "[Set] settings.rowStripeAlpha = 0.2 (0.03)"),
      "the changed row with its default")
  end)
  S:Set("settings.rowStripeAlpha", saved)
  if not ok then error(err, 0) end
end)

test("diagnostics: an unchanged, non-critical row is not printed", function()
  assertFalse(has(build(), "[Set] settings.rowHoverAlpha = "), "a default row was printed")
end)

test("diagnostics: the excluded-stores set renders as its members", function()
  local S = NS.Schema
  local saved = S:Get("settings.excludedStores")
  NS.db.global.settings.excludedStores = { GUILD_BANK = true, BANK = true }
  local ok, err = pcall(function()
    assertTrue(has(build(), "[Set] settings.excludedStores = {BANK, GUILD_BANK} ((none))"),
      "the set, sorted, beside its empty default")
  end)
  NS.db.global.settings.excludedStores = saved
  if not ok then error(err, 0) end
end)

test("diagnostics: a filter list past 40 ids is capped and the truncated line says so", function()
  local F = NS.Filters
  local ids = {}
  for i = 1, 45 do ids[i] = 50000 + i end
  for _, id in ipairs(ids) do F:AddBlacklist(id) end
  local ok, err = pcall(function()
    local lines, r = build()
    assertTrue(has(lines, "[Filter] blacklist (45):"), "the count of the whole list")
    assertTrue(has(lines, "(+5 more)"), "the ids past the cap collapse to one marker")
    assertTrue(r.capsHit, "the per-list flag is set")
    assertTrue(has(lines, "per-list caps hit=yes"), "and the truncated line reports it")
  end)
  F:ClearList("blacklist")
  if not ok then error(err, 0) end
end)

test("diagnostics: the ledger section counts by store, direction and kind", function()
  local entries = {
    entry(1), entry(2, { store = "WARBAND_BANK", direction = "WITHDRAW" }),
    entry(3, { kind = "MONEY", store = "GUILD_BANK", itemID = nil, itemName = "Gold" }),
  }
  withLedger(entries, function()
    local lines = build()
    assertTrue(has(lines, "[Ledger] entries=3"), "the total")
    assertTrue(has(lines, "[Ledger] by store: BANK=1, GUILD_BANK=1, WARBAND_BANK=1"), "by store")
    assertTrue(has(lines, "[Ledger] by direction: DEPOSIT=2, WITHDRAW=1"), "by direction")
    assertTrue(has(lines, "[Ledger] by kind: ITEM=2, MONEY=1"), "by kind")
    assertTrue(has(lines, "[Ledger] oldest ts=1700000001"), "the oldest stamp")
    assertTrue(has(lines, "[Ledger] newest ts=1700000003"), "the newest stamp")
  end)
end)

test("diagnostics: the ledger tail is the last 20 entries, links stripped", function()
  local entries = {}
  for i = 1, 25 do entries[i] = entry(i) end
  withLedger(entries, function()
    local lines = build()
    assertEqual(count(lines, "[Ledger]   #"), 20, "twenty tail rows")
    assertTrue(has(lines, "[Ledger]   #25 "), "the newest entry is in the tail")
    assertFalse(has(lines, "[Ledger]   #5 "), "an entry older than the tail is not")
    for _, l in ipairs(lines) do
      assertFalse(l:find("|H", 1, true) ~= nil, "a hyperlink escape survived: " .. l)
      assertFalse(l:find("|c", 1, true) ~= nil, "a color escape survived: " .. l)
    end
  end)
end)

test("diagnostics: a secret-shaped value in the ledger renders rather than raising", function()
  -- red under: a section that concatenates, compares or adds a ledger field before stringifying it
  -- ({} is the kit's secret stand-in: table.concat refuses it and arithmetic on it raises).
  local secret = {}
  local entries = { entry(1, { ts = secret, quantity = secret, itemName = secret, store = secret }) }
  withLedger(entries, function()
    local lines = build()
    assertEqual(count(lines, "failed:"), 0, "a section raised:\n" .. table.concat(lines, "\n"))
    assertTrue(has(lines, "<secret>"), "the value rendered as the sentinel")
  end)
end)

test("diagnostics: the capture section reports the engine and the cached gate", function()
  local lines = build()
  assertTrue(has(lines, "[Capture] openContext=nil snapshot=no"), "no frame is open")
  assertTrue(has(lines, "[Capture] settle pending=no debounce armed=no"), "nothing is armed")
  assertTrue(has(lines, "[Capture] gate: enabled=true trackItems=true trackMoney=true quality=0"),
    "the cached gate upvalues")
end)

test("diagnostics: the capture section summarizes an open frame's snapshot", function()
  local snap = { bags = { [1] = 2, [2] = 1 }, stores = { BANK = { [3] = 1 } }, money = 100,
    storeMoney = {} }
  with(NS.State, "openContext", "BANK_FRAME", function()
    with(NS.State, "lastSnapshot", snap, function()
      local lines = build()
      assertTrue(has(lines, "[Capture] openContext=BANK_FRAME snapshot=yes"), "the context")
      assertTrue(has(lines, "[Capture] snapshot: bags 2 kinds, BANK 1 kinds, money 100"),
        "the snapshot summary")
    end)
  end)
end)

test("diagnostics: a stood-down addon says so instead of reporting an empty engine", function()
  -- red under: a report that refuses, or reads as an idle engine, while the addon is disabled
  NS.SetDisabledHold(true)
  local ok, err = pcall(function()
    local lines = build()
    assertTrue(has(lines, "[State] stored enabled=true disabled=true stood down=true"),
      "the lifecycle line")
    assertTrue(has(lines, "[State] holds: disabled"), "the held key")
    assertTrue(has(lines, "[Capture] stood down: the capture engine is released"),
      "the engine section says it is stood down")
    assertTrue(has(lines, "[Session] stood down: no banking session can open"),
      "the session section says it is stood down")
  end)
  NS.SetDisabledHold(false)
  if not ok then error(err, 0) end
end)

test("diagnostics: the session section reports the live banking session", function()
  local lines = build()
  assertTrue(has(lines, "[Session] active=false entries=0 preview=false"), "the session line")
end)

test("diagnostics: Ledger:Diagnose is folded in as the scan section", function()
  local lines = build()
  for _, line in ipairs(NS.Ledger:Diagnose()) do
    assertTrue(has(lines, "[Scan] " .. line), "missing from the report: " .. line)
  end
end)

test("diagnostics: a closed guild-bank frame labels the tab counts as not fact", function()
  with(NS.Compat, "IsGuildBankVisible", function() return false end, function()
    assertTrue(has(build(), "[Scan] guild bank frame closed"), "the label")
  end)
  with(NS.Compat, "IsGuildBankVisible", function() return true end, function()
    assertFalse(has(build(), "[Scan] guild bank frame closed"), "no label while it is open")
  end)
end)

test("diagnostics: the report never queries the guild bank and never clears the console", function()
  -- red under: a section that calls QueryGuildBankTab (a server request) or D:Clear()
  local queried, cleared = 0, 0
  with(NS.Compat, "QueryGuildBankTab", function() queried = queried + 1 end, function()
    with(D, "Clear", function() cleared = cleared + 1 end, function()
      D:RunDiagnostics()
    end)
  end)
  assertEqual(queried, 0, "the report asked the server for guild-bank tabs")
  assertEqual(cleared, 0, "the report cleared the console")
end)

test("diagnostics: the window, launcher and environment sections are present", function()
  local lines = build()
  assertTrue(has(lines, "[Window] ledger: "), "the ledger window")
  assertTrue(has(lines, "[Window] session: "), "the session window")
  assertTrue(has(lines, "[Window] console: shown="), "the console")
  assertTrue(has(lines, "[Launcher] minimap shown="), "the launcher")
  assertTrue(has(lines, "[Env] bank-replacing addons loaded:"), "the bank-replacement check")
end)

test("diagnostics: a bank-replacing addon that is loaded is named", function()
  local api = { IsAddOnLoaded = function(name) return name == "Bagnon" end }
  with(_G, "C_AddOns", api, function()
    assertTrue(has(build(), "[Env] bank-replacing addons loaded: Bagnon"), "Bagnon named")
  end)
end)

-- ── the guarantees a host owes ───────────────────────────────────────────────────────────────

test("diagnostics: a raising section costs exactly one line and the next section runs", function()
  -- red under: sections run outside the library's per-section pcall, or one section's raise
  -- taking the ones after it down
  with(NS.Ledger, "Diagnose", function() error("boom") end, function()
    local lines = build()
    assertEqual(count(lines, "section scan failed:"), 1, "one failure line")
    assertEqual(count(lines, "[Scan] "), 0, "the failed section wrote nothing else")
    assertTrue(has(lines, "[Window] "), "the section after it still ran")
  end)
end)

test("diagnostics: an over-cap report ends in the truncated line, then the end marker", function()
  local n = D:RunDiagnostics({ maxLines = 20 })
  assertEqual(n, 20, "the report is held to the cap")
  local buf = D.buffer
  assertTrue(buf[#buf - 1]:find("truncated: ", 1, true) ~= nil,
    "the truncated line precedes the end marker: " .. tostring(buf[#buf - 1]))
  assertTrue(buf[#buf]:find("diagnostics end: 20 line(s)", 1, true) ~= nil,
    "the end marker counts the capped report: " .. tostring(buf[#buf]))
end)

test("diagnostics: the report leaves the debug flag exactly as it found it", function()
  -- red under: a report that turns logging on to write, or off afterwards
  for _, on in ipairs({ false, true }) do
    NS.State.debug = on
    D:RunDiagnostics()
    assertEqual(NS.State.debug, on, "the flag moved")
  end
  NS.State.debug = false
end)

test("diagnostics: /bl debug tests `diagnostics` before its other words", function()
  -- red under: a debug handler that toggles the window first, or reads `diagnostics` as unknown
  local ran, toggled = 0, 0
  with(D, "RunDiagnostics", function() ran = ran + 1 end, function()
    with(D, "Toggle", function() toggled = toggled + 1 end, function()
      NS.Slash:OnSlash("debug diagnostics")
      NS.Slash:OnSlash("debug Diagnostics")
      NS.Slash:OnSlash("debug diag")
    end)
  end)
  assertEqual(ran, 2, "both spellings ran the report")
  assertEqual(toggled, 1, "`debug diag` is an ordinary unknown word: it toggles the window")
end)

test("diagnostics: the verb is one COMMANDS row, and no alias of it exists", function()
  local rows = {}
  for _, cmd in ipairs(NS.COMMANDS) do
    if cmd[1] == "diagnostics" then rows[#rows + 1] = cmd end
    assertFalse(cmd[1] == "diag" or cmd[1] == "dump" or cmd[1] == "dx",
      "an alias of the report is registered: " .. cmd[1])
  end
  assertEqual(#rows, 1, "exactly one diagnostics row")
  assertEqual(#NS.COMMANDS, 18, "the verb table grew from 17 to 18")
end)
