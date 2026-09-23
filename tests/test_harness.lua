-- The harness's own guard rail.
--
-- Everything here exists because adopting the shared kit (tests/_kit) traded one failure mode for
-- another. The old runner `dofile`d each suite unconditionally, so a typo in the suite list RAISED.
-- The kit skips a listed suite whose file is missing (tests/_kit/framework.lua documents that as
-- deliberate — a suite can be listed while it is being written). That is a silently green run with
-- fewer cases, and nothing else in the gate can see it.
--
-- The TOC cases are here for the other half of the same problem: tests/run.lua no longer keeps a
-- hand-maintained addon load list, it derives one from the shipped TOC. That makes the TOC's ORDER
-- load-bearing for the suite as well as for the client, and several of the orderings below are
-- invariants that fail silently — a printer seam that lands after a `local print = NS.Print` upvalue
-- swaps a printer nobody reads, and the whole change looks like it worked.

local T = _G.BL_TEST
local test, assertTrue = T.test, T.assertTrue
local Loader = T.Loader

-- ── the suite list ───────────────────────────────────────────────────────────────────────────

-- The runner's suite list carries two entry shapes, and this file has to read both. A bare string
-- is a suite in tests/ by its basename. A `{ name = ..., dir = ... }` pair is a suite declared
-- against its own directory -- the shape testing-§9 prescribes for every suite the vendored kit
-- ships (tests/_kit/test_eol.lua and its siblings), because kit revision 25 keys the suite
-- inventory by (basename, directory) and reads a bare name as a claim on tests/. This file
-- understood only the bare form until 2026-09-23, so the kit's own remedy crashed it with
-- "attempt to concatenate local 'suite' (a table value)" before a single case could say why.
local OWN_DIR = "tests/"

--- The directory and the basename one suite-list entry declares.
local function entryParts(entry)
  if type(entry) == "table" then return entry.dir or OWN_DIR, tostring(entry.name) end
  return OWN_DIR, tostring(entry)
end

--- The file one suite-list entry names, as a repo-relative path.
local function entryPath(entry)
  local dir, name = entryParts(entry)
  return dir .. name .. ".lua"
end

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
    local path = entryPath(suite)
    local f = io.open(path, "r")
    assertTrue(f ~= nil, path .. " is listed in tests/run.lua but is not on disk — the kit SKIPS a "
      .. "missing suite, so this would be a green run with fewer cases")
    if f then f:close() end
  end
end)

test("Harness: every suite on disk is listed in the runner", function()
  -- Only entries declared against tests/ itself answer for a file in tests/: a pair naming
  -- tests/_kit/ is a claim on the kit's copy, and a same-named file here would be a second gate.
  local listed = {}
  for _, suite in ipairs(T.suites) do
    local dir, name = entryParts(suite)
    if dir == OWN_DIR then listed[name] = true end
  end
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
    local path = entryPath(suite)
    assertTrue(not seen[path], "duplicate suite in tests/run.lua: " .. path)
    seen[path] = true
  end
end)

test("Harness: the suite-list reader takes both entry shapes", function()
  assertTrue(entryPath("test_util") == "tests/test_util.lua", "a bare name must resolve under tests/")
  assertTrue(entryPath({ name = "test_eol", dir = "tests/_kit/" }) == "tests/_kit/test_eol.lua",
    "a { name, dir } pair must resolve under its own directory")
  local sawPair = false
  for _, suite in ipairs(T.suites) do
    if type(suite) == "table" then sawPair = true end
  end
  assertTrue(sawPair, "tests/run.lua declares no { name, dir } pair, so the kit's own suites are "
    .. "not in the list this file walks")
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

test("Harness: the settings files load last, and in order", function()
  loadsBefore("modules/Export.lua", "settings/Schema.lua")
  loadsBefore("settings/Schema.lua", "settings/Slash.lua")
  loadsBefore("settings/Slash.lua", "settings/Panel.lua")
end)
