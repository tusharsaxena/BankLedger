-- tests/test_sample_characters.lua — the made-up people this addon shows, on the collection's one
-- set (LibKa0s-Sim-1.0's Sim.SAMPLE / Sim.Sample, preview-mode's sample-character convention,
-- LibKa0s#87, AD-87-BL).
--
-- Two places invent characters: test mode's sample ledger (modules/LedgerTable_TestMode.lua) and the
-- simulator's alt (modules/SimWorld.lua). Both read core/SimSetup.lua: NS.SampleCharacters(), the
-- library's five protagonists for this client, and NS.SampleCrowdCharacterOf(), the library's seeded
-- crowd (Sim.SampleCrowd, LibKa0s v1.113.0) for a class the five lack. Since LibKa0s#104 (FB2-BL-01,
-- decision D1) every named sample person comes from the library: the addon keeps no list and no
-- copy, and without the library it draws no sample person at all. Names are data, never localized;
-- every name starts Sample or Mock and every realm is Samplerealm or Mockrealm, never a real one.
--
-- Per client (BL-02; clients-§5, §6): a character key follows the client's shape, "Name-Realm" on
-- Retail and "First Surname" on WoW Forever (forever-quirks-§4), so every case here runs on both
-- kit profiles.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue =
  T.test, T.assertEqual, T.assertTrue

local Env = dofile("tests/degraded_env.lua")
local Sim = mocks.LibStub("LibKa0s-Sim-1.0", true)

local FIELDS = { "name", "realm", "fullName", "classFile" }

--- The classes test mode draws beyond the protagonists' (this client's seed row).
local function LT_CLASSES()
  local protagonists, out = {}, {}
  for _, row in ipairs(Sim.Sample(NS.SAMPLE_CLIENT)) do protagonists[row.classFile] = true end
  for _, cls in ipairs(NS.LedgerTable.TEST_SEEDS.classes) do
    if not protagonists[cls] then out[#out + 1] = cls end
  end
  return out
end

local FOREVER = NS.Compat.ClientKey() == "forever"

--- One word of the convention: 2-12 letters, capitalized, starting Sample or Mock.
local function sampleWord(word)
  if not (word:find("^Sample") or word:find("^Mock")) then return false end
  return #word >= 2 and #word <= 12
end

--- A character key that follows the convention for this client: on Retail a sample name on one of
--- the two fixed fictional realms ("Name-Realm"); on WoW Forever a sample name and a sample surname
--- with no realm ("First Surname").
local function conventional(key)
  if FOREVER then
    local name, surname = tostring(key):match("^(%a+) (%a+)$")
    return name ~= nil and sampleWord(name) and sampleWord(surname)
  end
  local name, realm = tostring(key):match("^(%a+)%-(%a+)$")
  if not name then return false end
  if not sampleWord(name) then return false end
  return realm == "Samplerealm" or realm == "Mockrealm"
end

test("sample characters: NS.SampleCharacters answers the library's rows for this client", function()
  assertEqual(NS.SAMPLE_CLIENT, FOREVER and "forever" or "retail", "the seeded client key")
  local rows, lib = NS.SampleCharacters(), Sim.Sample(NS.SAMPLE_CLIENT)
  assertEqual(#rows, #lib)
  for i, row in ipairs(lib) do
    for _, f in ipairs(FIELDS) do assertEqual(rows[i][f], row[f], ("row %d %s"):format(i, f)) end
  end
  rows[1].name = "changed"
  assertEqual(NS.SampleCharacters()[1].name, lib[1].name, "a caller's write reached the shared rows")
end)

test("sample characters: the addon keeps no copy of the library's rows (LibKa0s#104)", function()
  -- red under: a host twin of Sim.SAMPLE left in core/SimSetup.lua, the hand-kept list D1 retires.
  assertEqual(NS.SAMPLE_FALLBACKS, nil, "NS.SAMPLE_FALLBACKS is a hand-kept copy of the library's rows")
  assertEqual(NS.SAMPLE_FALLBACK, nil, "NS.SAMPLE_FALLBACK is a hand-kept copy of the library's rows")
end)

test("sample characters: a crowd character is the library's seeded crowd row of that class", function()
  for _, cls in ipairs(LT_CLASSES()) do
    local row = NS.SampleCrowdCharacterOf(cls, NS.LedgerTable.TEST_CROWD_SEED)
    local want
    for _, c in ipairs(Sim.SampleCrowd(NS.SAMPLE_CLIENT, Sim.CROWD_MAX, NS.LedgerTable.TEST_CROWD_SEED)) do
      if c.classFile == cls then want = c break end
    end
    assertTrue(want ~= nil, cls .. ": the library's crowd holds no " .. cls)
    assertTrue(row ~= nil, cls .. ": NS.SampleCrowdCharacterOf answered nothing")
    for _, f in ipairs(FIELDS) do assertEqual(row[f], want[f], cls .. " " .. f) end
    assertTrue(conventional(row.fullName), "an unconventional crowd character: " .. row.fullName)
  end
  -- The same seed answers the same person; the caller owns its copy.
  local a = NS.SampleCrowdCharacterOf("ROGUE", 7)
  a.fullName = "changed"
  assertTrue(NS.SampleCrowdCharacterOf("ROGUE", 7).fullName ~= "changed", "a caller's write reached the crowd")
end)

test("sample characters: the rows are in this client's shape, Name-Realm on Retail, First Surname on Forever", function()
  for _, row in ipairs(NS.SampleCharacters()) do
    assertTrue(conventional(row.fullName), "an unconventional sample character: " .. row.fullName)
    assertEqual(row.fullName:find(" ", 1, true) ~= nil, FOREVER, row.fullName .. "'s shape")
  end
end)

test("sample characters: without the library there is no sample person to draw", function()
  local ns = Env.loadDegraded()
  assertEqual(#ns.SampleCharacters(), 0, "the degraded build drew protagonists from somewhere")
  assertEqual(ns.SampleCharacterOf("MAGE"), nil)
  assertEqual(ns.SampleCrowdCharacterOf("ROGUE", 1), nil)
end)

local function testModeChars(lt)
  local seen, classOf = {}, {}
  for _, x in ipairs(lt:BuildTestData()) do
    seen[x.char] = true
    classOf[x.char] = x.classFile
  end
  return seen, classOf
end

test("sample characters: every test-mode character follows the convention, none on a real realm", function()
  local seen = testModeChars(NS.LedgerTable)
  local n = 0
  for key in pairs(seen) do
    n = n + 1
    assertTrue(conventional(key), "an unconventional test-mode character: " .. key)
  end
  assertEqual(n, 8, "the sample ledger's eight characters")
end)

test("sample characters: test mode's protagonists are the shared rows, by class", function()
  local seen, classOf = testModeChars(NS.LedgerTable)
  for _, row in ipairs(Sim.Sample(NS.SAMPLE_CLIENT)) do
    if seen[row.fullName] ~= nil then
      assertEqual(classOf[row.fullName], row.classFile, row.fullName .. "'s class")
    end
  end
  for _, cls in ipairs({ "MAGE", "PALADIN", "PRIEST", "WARRIOR" }) do
    local shared
    for _, row in ipairs(Sim.Sample(NS.SAMPLE_CLIENT)) do if row.classFile == cls then shared = row.fullName end end
    assertTrue(seen[shared], cls .. " is not the shared " .. tostring(shared))
  end
end)

test("sample characters: test mode's guild-bank rows carry the sample guild", function()
  local n = 0
  for _, x in ipairs(NS.LedgerTable:BuildTestData()) do
    if x.store == "GUILD_BANK" then
      n = n + 1
      assertEqual(x.guild, "Sample Company")
    end
  end
  assertTrue(n > 0, "no guild-bank rows")
end)

test("sample characters: without the library test mode keys each row by its class, naming nobody", function()
  -- No library, no sample person (D1): the rows still build, each character the class token.
  local ns = Env.loadDegraded()
  local seen, classOf = testModeChars(ns.LedgerTable)
  local n = 0
  for key in pairs(seen) do
    n = n + 1
    assertEqual(key, classOf[key], "a degraded row named a person: " .. key)
  end
  assertEqual(n, 8, "the degraded sample ledger's eight classes")
end)

test("sample characters: test mode's other classes are the library's seeded crowd", function()
  local seen, classOf = testModeChars(NS.LedgerTable)
  local protagonists = {}
  for _, row in ipairs(Sim.Sample(NS.SAMPLE_CLIENT)) do protagonists[row.classFile] = true end
  local crowd = 0
  for key, cls in pairs(classOf) do
    if not protagonists[cls] then
      crowd = crowd + 1
      assertEqual(key, NS.SampleCrowdCharacterOf(cls, NS.LedgerTable.TEST_CROWD_SEED).fullName, cls)
    end
  end
  assertEqual(crowd, 4, "four classes beyond the five protagonists' (Rogue, Druid, Shaman, Evoker or Warlock)")
  assertTrue(next(seen) ~= nil)
end)

-- ── no name literal outside tests/ (LibKa0s#104, decision D1) ───────────────────────────────
--
-- A sample person's name in the addon's own source is a hand-kept list waiting to drift from the
-- library's. The scan reads every shipped .lua and .xml file outside libs/ and tests/ with its
-- comments stripped, and refuses any word of the convention: Sample or Mock followed by lowercase
-- letters (Samplehunter, Mockrealm). A guild ("Sample Company") is not a person and is not one word,
-- so the scan does not see it; identifiers (SampleCharacters, mocks) do not match either.

--- Every shipped source file outside libs/ and tests/ (and docs/, which is prose).
local function shippedSources()
  local out = {}
  local p = io.popen([[find . -type f \( -name '*.lua' -o -name '*.xml' \) -not -path './libs/*' ]]
    .. [[-not -path './tests/*' -not -path './docs/*' -not -path './.git/*' | sort]])
  for line in p:lines() do out[#out + 1] = line end
  p:close()
  return out
end

--- `src` with Lua comments removed: long comments first, then each line from its `--` on.
local function stripComments(src)
  src = src:gsub("%-%-%[(=*)%[.-%]%1%]", "")
  src = src:gsub("<!%-%-.-%-%->", "")
  return (src:gsub("%-%-[^\n]*", ""))
end

test("sample characters: no Sample or Mock name literal lives in the shipped source (LibKa0s#104)", function()
  local files = shippedSources()
  assertTrue(#files > 20, "the scan found too few files: " .. #files)
  local hits = {}
  for _, path in ipairs(files) do
    local fh = assert(io.open(path, "rb"))
    local code = stripComments(fh:read("*a"))
    fh:close()
    for word in code:gmatch("%f[%a](%u%l+)%f[%A]") do
      if word:find("^Sample%l") or word:find("^Mock%l") then hits[#hits + 1] = path .. ": " .. word end
    end
  end
  assertEqual(table.concat(hits, "; "), "", "a sample name kept by hand")
end)

test("sample characters: the literal scan is falsifiable, a planted name is found", function()
  local planted = 'local x = "Mockshade-Samplerealm" -- Mockcomment\n--[[ Samplelong ]]\nlocal y = "Sample Company"'
  local seen = {}
  for word in stripComments(planted):gmatch("%f[%a](%u%l+)%f[%A]") do
    if word:find("^Sample%l") or word:find("^Mock%l") then seen[#seen + 1] = word end
  end
  assertEqual(table.concat(seen, ","), "Mockshade,Samplerealm", "the scan must see code, not comments or a guild")
end)
