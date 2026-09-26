-- tests/test_libka0s_slash.lua — the LibKa0s-Slash-1.0 seam: that it is actually wired, that it renders
-- what the deleted host CLI rendered, and that it degrades rather than errors when the vendored library
-- is absent.
--
-- These cases were the LibKa0s-Slash section of tests/test_libka0s.lua until BL-ATS-01 (the
-- 2026-09-26 automated-tests sweep, ATS-24) moved them here whole: that file had crossed 1000 lines on
-- case count, and each LibKa0s surface is a self-contained seam. The move changed no case. The
-- reasoning in that file's header -- degraded cases LOAD the addon without libs/LibKa0s rather than
-- hand-stubbing the absence, byte cases compare rendered strings -- applies here unchanged.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Loader = T.Loader

-- The degraded-install environment builder, from the one shared home tests/degraded_env.lua, so this
-- suite and tests/test_libka0s.lua build the same environment rather than two that can drift.
local loadDegraded = dofile("tests/degraded_env.lua").loadDegraded

local function joinLines(t) return table.concat(t, "\n") end

-- Runs fn with the chat frame's AddMessage captured; the same helper tests/test_libka0s.lua uses.
local function captureChat(fn, m)
  m = m or T.mocks
  local out = {}
  local saved = m.DEFAULT_CHAT_FRAME.AddMessage
  m.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  m.DEFAULT_CHAT_FRAME.AddMessage = saved
  if not ok then error(err, 0) end
  return out
end

-- The seam's TOC position, read from the shipped TOC exactly as tests/test_libka0s.lua reads it.
local toc = Loader.tocFiles("BankLedger.toc")
local function at(path)
  for i, p in ipairs(toc) do if p == path then return i end end
  return nil
end
local function loadsBefore(a, b)
  local ia, ib = at(a), at(b)
  assertTrue(ia ~= nil, a .. " is not in BankLedger.toc")
  assertTrue(ib ~= nil, b .. " is not in BankLedger.toc")
  assertTrue(ia < ib, a .. " must load before " .. b .. " (TOC positions "
    .. tostring(ia) .. " and " .. tostring(ib) .. ")")
end

-- ── LibKa0s-Slash-1.0 ────────────────────────────────────────────────────────────────────────

local slashlib = T.mocks.LibStub("LibKa0s-Slash-1.0", true)
local Sl = NS.Slash

local function chat(fn) return captureChat(fn) end

test("LibKa0s-Slash: the vendored major registered and the CLI is running on it", function()
  assertTrue(slashlib ~= nil, "LibKa0s-Slash-1.0 did not register")
  -- The host's own formatters are GONE, not shadowed. Their absence is what proves the dispatcher
  -- and the schema verbs are the library's rather than the deleted 264-line implementation.
  assertTrue(Sl.FormatSchemaValue == nil, "the host's value formatter should be deleted")
  assertTrue(Sl.FormatKV == nil, "the host's key=value formatter should be deleted")
  assertTrue(Sl.LIST_GROUP_ORDER == nil, "the hand-maintained group order should be deleted")
end)

test("LibKa0s-Slash: the module needs the minor that carries the format hook", function()
  -- `format` landed at Slash minor 5. Against minor 4 it is ignored SILENTLY and
  -- settings.excludedStores renders as "<secret>" — the CLI telling a user a plain settings value
  -- is combat-protected.
  local _, minor = T.mocks.LibStub:GetLibrary("LibKa0s-Slash-1.0", true)
  assertTrue((minor or 0) >= 5,
    "vendored Slash is minor " .. tostring(minor) .. "; the format hook needs 5 — re-vendor")
end)

test("LibKa0s-Slash: every printed line still carries the [BL] tag", function()
  -- The descriptor's `print`. Omit it and the library's default sink writes straight to the chat
  -- frame untagged — every line of /bl help, /bl list and every echo loses its prefix at once.
  local out = chat(function() Sl:CliList() end)
  assertTrue(#out > 3)
  for _, line in ipairs(out) do
    assertTrue(line:sub(1, #NS.PREFIX) == NS.PREFIX, "untagged line: " .. line)
  end
end)

test("LibKa0s-Slash: /bl list keeps its section headings", function()
  -- The descriptor's `groupKey`. The library defaults to `row.page`; this schema declares `group`.
  -- Without it every row collapses under a single "[settings]" heading — a silent, total loss of
  -- structure that no error reports.
  local lines = Sl:BuildListLines()
  assertEqual(lines[1], "|cff33ff99Available settings|r", "the green header is unchanged")
  local headings = {}
  for _, line in ipairs(lines) do
    local g = line:match("^  |cff3399ff%[(.-)%]")
    if g then headings[#headings + 1] = g end
  end
  -- One heading per TAB, in tab order (options-ui-§13): `group` names a tab now, so the chat
  -- listing and the panel's strip are the same partition read two ways. FOUR, not six: the two
  -- item-id lists are tabs of the page but not settings, so nothing files a row under them and the
  -- CLI has nothing to list — which is exactly right, `/bl set blacklist` is not an edit the chat
  -- grammar has.
  assertEqual(headings[1], "Master controls")
  assertEqual(headings[2], "Capture")
  assertEqual(headings[3], "Interface")
  assertEqual(headings[4], "History")
  assertEqual(#headings, 4)
end)

test("LibKa0s-Slash: a set-typed row renders as a set, never as the secret sentinel", function()
  -- The whole reason Slash minor 5 exists. lib.FormatValue ends at Core's SafeToString, which
  -- probes table.concat and refuses a table — so without the `format` hook this row reads
  -- "<secret>" in /bl list, /bl get and /bl reset alike.
  local saved = NS.Schema:Get("settings.excludedStores")
  NS.Schema:Set("settings.excludedStores", { GUILD_BANK = true, BANK = true })
  local got = chat(function() Sl:CliGet("settings.excludedStores") end)[1]
  assertEqual(got, NS.PREFIX .. " " ..
    slashlib.FormatKV("settings.excludedStores", "{BANK, GUILD_BANK}"))
  NS.Schema:Set("settings.excludedStores", {})
  local empty = chat(function() Sl:CliGet("settings.excludedStores") end)[1]
  assertEqual(empty, NS.PREFIX .. " " ..
    slashlib.FormatKV("settings.excludedStores", "(none)"))
  NS.Schema:Set("settings.excludedStores", saved or {})
end)

test("LibKa0s-Slash: the format hook defers to the library for every OTHER row type", function()
  -- Returning nil for a row it does not own is what keeps numbers formatted by their `fmt` and
  -- booleans reading true/false. A hook that answered for everything would quietly become a second
  -- renderer — the exact duplication this adoption exists to remove.
  local n = chat(function() Sl:CliGet("settings.windowScale") end)[1]
  assertEqual(n, NS.PREFIX .. " " .. slashlib.FormatKV("settings.windowScale", "1.00x"))
  local b = chat(function() Sl:CliGet("settings.enabled") end)[1]
  assertEqual(b, NS.PREFIX .. " " .. slashlib.FormatKV("settings.enabled", "true"))
end)

test("LibKa0s-Slash: booleans are settable, because the schema says 'bool'", function()
  -- The library dispatches on "bool"; this schema said "boolean" until the adoption renamed it.
  -- Against the old spelling all six boolean rows answer "unknown setting type 'boolean'" and
  -- become un-settable from chat — over half the settings surface, silently.
  local saved = NS.Schema:Get("settings.trackMoney")
  chat(function() Sl:CliSet("settings.trackMoney off") end)
  assertEqual(NS.Schema:Get("settings.trackMoney"), false)
  chat(function() Sl:CliSet("settings.trackMoney yes") end)
  assertEqual(NS.Schema:Get("settings.trackMoney"), true)
  NS.Schema:Set("settings.trackMoney", saved)
end)

test("LibKa0s-Slash: a numeric dropdown now REFUSES a value outside its list", function()
  -- Gained with the row.options -> row.values rename: the library reads `values`, so enumList can
  -- finally see the list. Before the rename `/bl set settings.retentionDays 99` stored 99 and the
  -- panel had no label for it.
  local saved = NS.Schema:Get("settings.retentionDays")
  local out = joinLines(chat(function() Sl:CliSet("settings.retentionDays 99") end))
  assertTrue(out:find("allowed values:", 1, true) ~= nil, out)
  assertEqual(NS.Schema:Get("settings.retentionDays"), saved, "nothing was written")
end)

test("LibKa0s-Slash: a slider value out of range CLAMPS rather than storing what was typed",
  function()
    -- A behavior change, and an improvement: NS.Schema:Set validates nothing, so the old CLI wrote
    -- 9 into the row and the panel drew a slider pinned to its end with a value it could not
    -- represent.
    --
    -- The ceiling is 2 and no longer 1.6: Master scale is the canonical composed row now
    -- (options-ui-§15) and its range is the library's 0.5-2, not the 0.6-1.6 this addon picked for
    -- itself. Every stored value stays inside it, so no install is touched — what widened is what
    -- the slider will let you ask for.
    chat(function() Sl:CliSet("settings.windowScale 9") end)
    assertEqual(NS.Schema:Get("settings.windowScale"), 2)
    chat(function() Sl:CliReset("settings.windowScale") end)
  end)

test("LibKa0s-Slash: a set-typed row refuses a chat edit, and says where it CAN be edited",
  function()
    -- The host's `parse` override. Left to the library it answers "unknown setting type 'table'",
    -- which names an implementation detail rather than an action. Before the adoption this wrote a
    -- raw STRING into a table-typed setting the capture gate reads as a set — a live bug the
    -- refusal fixes.
    local saved = NS.Schema:Get("settings.excludedStores")
    local out = joinLines(chat(function() Sl:CliSet("settings.excludedStores BANK") end))
    assertTrue(out:find("settings panel", 1, true) ~= nil, out)
    assertEqual(type(NS.Schema:Get("settings.excludedStores")), "table", "nothing was written")
    NS.Schema:Set("settings.excludedStores", saved or {})
  end)

test("LibKa0s-Slash: CliResetAll is the host's wholesale reset, not the library's walk", function()
  -- The library's CliResetAll walks the schema and acknowledges; it cannot know about state that has
  -- no Schema row (the filter id-sets, the saved view, the recorded ledger). The host used to wrap
  -- that walk with the missing pieces. Now `/bl resetall` is the one global reset (options-ui-§12):
  -- the popup's Sl:ResetEverything, which empties db.global wholesale and so reaches all of it with
  -- no list to keep. The mock has no popup API, so the request runs the act directly.
  -- red under: Sl:CliResetAll calling cli:CliResetAll again (the library's line comes back).
  NS.Filters:AddBlacklist(2589)
  NS.db.global.savedView = { tab = "insights" }
  local out = chat(function() Sl:CliResetAll() end)
  assertEqual(NS.Filters:Count(NS.Filters:Blacklist()), 0, "the filter lists are cleared")
  assertTrue(NS.db.global.savedView == nil, "the saved ledger view is cleared")
  assertEqual(#out, 1, "still exactly one confirmation line")
  assertEqual(out[1], NS.PREFIX .. " this addon reset to defaults.")
end)

test("LibKa0s-Slash: the landing page and the chat help render the SAME rows", function()
  -- Convergence #2, adopted. The panel used to carry a second formatter for this data — doubled
  -- spaces around a white-wrapped em dash, description bare — and the two drifted. Now the only
  -- difference between them is the indent, which is the library's whole reason for having both.
  local landing = Sl:LandingRows()
  local helpRows = chat(function() Sl:PrintHelp() end)
  assertEqual(#landing, #NS.COMMANDS, "one landing row per verb")
  for i, row in ipairs(landing) do
    assertTrue(row:sub(1, 2) ~= "  ", "a landing row must not be indented: " .. row)
    -- helpRows[1] is the header, so the rows line up at i + 1, each behind the [BL] tag.
    assertEqual(helpRows[i + 1], NS.PREFIX .. " " .. "  " .. row,
      "the chat row is the landing row plus a two-space indent")
  end
  assertEqual(landing[1], slashlib.FormatRow("/bl show", "Open the ledger window"))
end)

test("LibKa0s-Slash: reset takes a PATH and resetall takes none — already converged", function()
  -- Convergence #1 needed no change: `/bl reset <path>` was already path-scoped and `/bl resetall`
  -- already existed, so there was no page-shaped form to remove and no confirmation to re-anchor.
  -- Asserted rather than assumed, because "not applicable" and "declined" are different states and
  -- only one of them is a finding.
  -- The library takes the first token, so a two-word page name arrives as "Keep" — and the point
  -- stands either way: it resolves as a PATH lookup and misses, rather than resetting a page.
  local out = joinLines(chat(function() Sl:CliReset("Interface tab") end))
  assertTrue(out:find("Setting not found: Interface", 1, true) ~= nil,
    "a page name must not resolve as a reset target: " .. out)
  local usage = joinLines(chat(function() Sl:CliReset("") end))
  assertTrue(usage:find("Usage: /bl reset <path>", 1, true) ~= nil, usage)
end)

test("LibKa0s-Slash: every user-visible string resolves to prose, not to its own key", function()
  -- The L trap. Slash is the second of the three majors that can express it, and it has by far the
  -- largest string surface — the help header, the list header, every usage line and seven error
  -- messages. All reached through real output rather than through a guard that could pass vacuously.
  --
  -- Color escapes and the [BL] tag are stripped first: `|cFFFFFF00` and `BL` are both
  -- SCREAMING_SNAKE-shaped and neither is prose the user reads as a word.
  --
  -- Two shapes are flagged, because the library's keys come in two. A WHOLE rendered value equal to
  -- its key catches the short ones (VERSION, NONE, INVALID); a single word carrying an underscore
  -- catches the rest (HELP_HEADER, USAGE_GET, ERR_BOOL) wherever it sits inside a longer line.
  local function assertProse(value, what)
    assertEqual(type(value), "string", what .. " is not a string")
    assertTrue(value ~= "", what .. " is empty")
    local bare = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      :gsub("%[BL%]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    assertTrue(bare:match("^[A-Z][A-Z0-9_]+$") == nil,
      what .. " rendered as a raw locale key: " .. value)
    for word in bare:gmatch("[%w_]+") do
      assertTrue(word:match("^[A-Z][A-Z0-9]*_[A-Z0-9_]*$") == nil,
        what .. " contains a raw locale key (" .. word .. "): " .. value)
    end
  end
  local help = chat(function() Sl:PrintHelp() end)
  assertProse(help[1], "the help header")
  assertProse(Sl:BuildListLines()[1], "the list header")
  assertProse(joinLines(chat(function() Sl:CliGet("") end)), "the get usage line")
  assertProse(joinLines(chat(function() Sl:CliSet("") end)), "the set usage line")
  assertProse(joinLines(chat(function() Sl:CliReset("") end)), "the reset usage line")
  assertProse(joinLines(chat(function() Sl:CliGet("nope.nope") end)), "the not-found line")
  assertProse(joinLines(chat(function() Sl:OnSlash("wibble") end)), "the unknown-command line")
end)

test("LibKa0s-Slash degraded: the verbs that never needed the library still work", function()
  local ns, m = loadDegraded()
  assertTrue(m.LibStub("LibKa0s-Slash-1.0", true) == nil, "the library is present after all")
  -- Dispatch survives: `show`, `hide`, `toggle`, `config`, `session`, `test`, `purge` and `debug`
  -- are host handlers that never touched this library, and losing them would break the addon rather
  -- than degrade it.
  local reached = false
  ns.COMMANDS[#ns.COMMANDS + 1] = { "probe", "probe", function() reached = true end }
  ns.Slash:OnSlash("probe")
  assertTrue(reached, "the fallback dispatcher must still reach a host verb")
  ns.COMMANDS[#ns.COMMANDS] = nil
end)

test("LibKa0s-Slash degraded: the disabled gate's live set is the library's LIVE_VERBS, written out",
  function()
    -- settings/Slash.lua's library-absent dispatcher keeps its own copy of lib.LIVE_VERBS, because
    -- there is no library to read it from. A literal copy does not inherit a verb the library adds
    -- (Slash minor 16 added `diagnostics`), so this case walks the LIVE library's set and proves
    -- the degraded gate lets each one through while the addon is off.
    --
    -- red under: a verb in lib.LIVE_VERBS that the degraded LIVE_VERBS table leaves out.
    assertTrue(slashlib ~= nil and type(slashlib.LIVE_VERBS) == "table", "no live set to compare with")
    local ns, m = loadDegraded()
    local savedDisabled = ns.IsDisabled
    ns.IsDisabled = function() return true end
    local ok, err = pcall(function()
      for _, verb in ipairs(slashlib.LIVE_VERBS) do
        local reached = false
        table.insert(ns.COMMANDS, 1, { verb, "probe", function() reached = true end })
        local out = captureChat(function() ns.Slash:OnSlash(verb) end, m)
        table.remove(ns.COMMANDS, 1)
        assertTrue(reached, "`/bl " .. verb .. "` was refused while disabled on the degraded arm: "
          .. table.concat(out, " / "))
      end
      -- And the gate is really armed: a feature verb is still refused.
      local reached = false
      table.insert(ns.COMMANDS, 1, { "probefeature", "probe", function() reached = true end })
      captureChat(function() ns.Slash:OnSlash("probefeature") end, m)
      table.remove(ns.COMMANDS, 1)
      assertTrue(not reached, "the degraded gate let a feature verb through while disabled")
    end)
    ns.IsDisabled = savedDisabled
    if not ok then error(err, 0) end
  end)

test("LibKa0s-Slash degraded: a bare /bl runs the config verb, as the library does", function()
  -- The stub mirrors Slash minor 11 (slash-commands-§4): bare and whitespace-only input run the
  -- host's `config` verb with "", and print nothing.
  local ns, m = loadDegraded()
  local cmd
  for _, c in ipairs(ns.COMMANDS) do if c[1] == "config" then cmd = c end end
  assertTrue(cmd ~= nil, "the degraded arm still registers a config verb")
  local orig, calls = cmd[3], {}
  cmd[3] = function(rest) calls[#calls + 1] = rest end
  local ok, out = pcall(captureChat, function()
    ns.Slash:OnSlash("")
    ns.Slash:OnSlash("  \t ")
  end, m)
  cmd[3] = orig
  if not ok then error(out, 0) end
  assertEqual(#calls, 2, "both a bare and a whitespace-only /bl must reach the config verb")
  assertEqual(calls[1], "")
  assertEqual(calls[2], "")
  assertEqual(#out, 0, "and print nothing: " .. table.concat(out, "\n"))
end)

test("LibKa0s-Slash degraded: with no config verb, a bare /bl falls back to help", function()
  local ns, m = loadDegraded()
  for i = #ns.COMMANDS, 1, -1 do
    if ns.COMMANDS[i][1] == "config" then table.remove(ns.COMMANDS, i) end
  end
  local out = captureChat(function() ns.Slash:OnSlash("") end, m)
  assertEqual(out[#out], "|cff00ffff[BL]|r The LibKa0s library is missing from this installation "
    .. "of Ka0s Bank Ledger (expected in libs/LibKa0s), so the slash help index and the settings "
    .. "CLI (list/get/set/reset) are unavailable.")
end)

test("LibKa0s-Slash degraded: the CLI explains itself through the SHARED cause clause", function()
  local ns, m = loadDegraded()
  local out = captureChat(function() ns.Slash:CliList() end, m)
  assertEqual(out[#out], "|cff00ffff[BL]|r The LibKa0s library is missing from this installation "
    .. "of Ka0s Bank Ledger (expected in libs/LibKa0s), so the slash help index and the settings "
    .. "CLI (list/get/set/reset) are unavailable.")
end)

test("LibKa0s-Slash degraded: resetall still WORKS rather than merely explaining itself", function()
  -- A reset that silently did nothing is worse than a missing help index. The degraded arm needs no
  -- library for it: `/bl resetall` is the same confirm-gated request as the live arm
  -- (options-ui-§12), and the popup's Yes is the host's own Sl:ResetEverything. Before
  -- BankLedger-A-02 this arm carried its own bracketed schema walk, which kept the ledger.
  -- red under: restoring the degraded walk (the ledger survives, the library-shaped line returns).
  local ns, m = loadDegraded()
  ns:InitDB()
  ns.Schema:Set("settings.qualityThreshold", 4)
  ns.db.global.ledger = {
    { ts = os.time(), kind = "ITEM", direction = "DEPOSIT", store = "BANK", itemID = 2589 },
  }
  local out = captureChat(function() ns.Slash:CliResetAll() end, m)
  assertEqual(ns.Schema:Get("settings.qualityThreshold"), 0)
  assertEqual(#ns.db.global.ledger, 0, "the degraded reset kept recorded history")
  assertEqual(out[#out], "|cff00ffff[BL]|r this addon reset to defaults.")
end)

test("LibKa0s-Slash degraded: resetall writes every changed row back, and logs its ONE [Set] line", function()
  -- The degraded schema runtime is settings/Schema.lua's log-silent stub, so a row walk through it
  -- would log nothing. The wholesale reset is not a walk: it logs its own one line, counted before
  -- the wipe (debug-logging-§10), on this arm as on the live one. The case installs a recorder in
  -- NS.Debug's place, because the degraded DebugLog stub discards every line. Before BankLedger-A-02
  -- the degraded walk logged nothing here, and the two raising-walk cases that followed it pinned a
  -- bracket this arm no longer opens; they went with the walk.
  -- red under: the reset writing nothing back, or logging per row.
  local ns, m = loadDegraded()
  ns:InitDB()
  captureChat(function() ns.Slash:CliResetAll() end, m)   -- baseline: every row at its default
  ns.Schema:Set("settings.qualityThreshold", 4)
  ns.Schema:Set("settings.trackItems", false)
  local lines = {}
  ns.Debug = function(tag, fmt, ...)
    if tag == "Set" then lines[#lines + 1] = ("[%s] " .. fmt):format(tag, ...) end
  end
  ns.State.debug = true
  captureChat(function() ns.Slash:CliResetAll() end, m)
  assertEqual(ns.Schema:Get("settings.qualityThreshold"), 0, "the reset still happened")
  assertEqual(ns.Schema:Get("settings.trackItems"), true, "every changed row was written back")
  assertEqual(#lines, 1, "one line for the one act, got:\n" .. table.concat(lines, "\n"))
  assertEqual(lines[1], "[Set] reset account-wide settings to defaults (2 rows)")
end)

test("LibKa0s-Slash: the seam loads after the schema it reads", function()
  loadsBefore("settings/Schema.lua", "settings/Slash.lua")
end)
