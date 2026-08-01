-- The harness's own guard rail.
--
-- Everything here exists because adopting the shared kit (tests/_kit) traded one failure mode for
-- another. The old runner `dofile`d each suite unconditionally, so a typo in the suite list RAISED.
-- The kit skips a listed suite whose file is missing (testkit/framework.lua documents that as
-- deliberate — a suite can be listed while it is being written). That is a silently green run with
-- fewer cases, and nothing else in the gate can see it.
--
-- The TOC cases are here for the other half of the same problem: tests/run.lua no longer keeps a
-- hand-maintained addon load list, it derives one from the shipped TOC. That makes the TOC's ORDER
-- load-bearing for the suite as well as for the client, and several of the orderings below are
-- invariants that fail silently — a printer seam that lands after a `local print = NS.Print` upvalue
-- swaps a printer nobody reads, and the whole change looks like it worked.

local T = _G.BL_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Loader = T.Loader

-- ── the suite list ───────────────────────────────────────────────────────────────────────────

-- `ls tests/test_*.lua`, portably enough for the two platforms this runs on.
local function suiteFilesOnDisk()
  local names = {}
  local pipe = io.popen('ls tests/test_*.lua 2>/dev/null')
  if not pipe then return names end
  for line in pipe:lines() do
    local base = line:match("([^/\\]+)%.lua%s*$")
    if base then names[#names + 1] = base end
  end
  pipe:close()
  return names
end

test("Harness: every suite the runner lists exists on disk", function()
  for _, suite in ipairs(T.suites) do
    local path = "tests/" .. suite .. ".lua"
    local f = io.open(path, "r")
    assertTrue(f ~= nil, path .. " is listed in tests/run.lua but is not on disk — the kit SKIPS a "
      .. "missing suite, so this would be a green run with fewer cases")
    if f then f:close() end
  end
end)

test("Harness: every suite on disk is listed in the runner", function()
  local listed = {}
  for _, suite in ipairs(T.suites) do listed[suite] = true end
  local disk = suiteFilesOnDisk()
  assertTrue(#disk > 0, "could not enumerate tests/test_*.lua")
  for _, base in ipairs(disk) do
    assertTrue(listed[base] == true, "tests/" .. base .. ".lua exists but tests/run.lua does not "
      .. "list it, so none of its cases ever run")
  end
end)

test("Harness: the runner's suite list has no duplicates", function()
  local seen = {}
  for _, suite in ipairs(T.suites) do
    assertTrue(not seen[suite], "duplicate suite in tests/run.lua: " .. suite)
    seen[suite] = true
  end
end)

-- ── the TOC ──────────────────────────────────────────────────────────────────────────────────

local toc = Loader.tocFiles("BankLedger.toc")

-- Position of a file in the TOC's own load order, or nil.
local function at(path)
  for i, p in ipairs(toc) do
    if p == path then return i end
  end
  return nil
end

local function loadsBefore(a, b)
  local ia, ib = at(a), at(b)
  assertTrue(ia ~= nil, a .. " is not in BankLedger.toc")
  assertTrue(ib ~= nil, b .. " is not in BankLedger.toc")
  assertTrue(ia < ib, a .. " must load before " .. b .. " (TOC positions " .. tostring(ia)
    .. " and " .. tostring(ib) .. ")")
end

test("Harness: the TOC is what the headless runner loads, and it is non-empty", function()
  assertTrue(#toc > 20, "expected the TOC to list the addon's own files; got " .. #toc)
  -- tocFiles must not leak the vendored library XML lines into the addon list.
  for _, p in ipairs(toc) do
    assertTrue(not p:lower():match("^libs/"), "tocFiles leaked a libs/ entry: " .. p)
    assertTrue(p:match("%.lua$") ~= nil, "tocFiles returned a non-Lua entry: " .. p)
  end
end)

test("Harness: Compat loads before everything else in core/", function()
  loadsBefore("core/Compat.lua", "core/Constants.lua")
  loadsBefore("core/Compat.lua", "core/BankLedger.lua")
end)

test("Harness: Filters loads before Ledger — the capture gate reads the lists", function()
  loadsBefore("modules/Filters.lua", "modules/Ledger.lua")
end)

test("Harness: the settings files load last", function()
  loadsBefore("modules/DebugLog.lua", "settings/Schema.lua")
  loadsBefore("settings/Schema.lua", "settings/Slash.lua")
  loadsBefore("settings/Slash.lua", "settings/Panel.lua")
end)
