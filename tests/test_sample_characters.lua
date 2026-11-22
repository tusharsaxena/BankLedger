-- tests/test_sample_characters.lua — the made-up people this addon shows, on the collection's one
-- set (LibKa0s-Sim-1.0's Sim.SAMPLE / Sim.Sample, preview-mode's sample-character convention,
-- LibKa0s#87, AD-87-BL).
--
-- Two places invent characters: test mode's sample ledger (modules/LedgerTable_TestMode.lua) and the
-- simulator's alt (modules/SimWorld.lua). Both read NS.SampleCharacters() (core/SimSetup.lua): the
-- library's rows for this client, or, without the library, the host copy NS.SAMPLE_FALLBACK, which
-- is held to the library's rows here so it cannot drift. Names are data, never localized; every
-- name starts Sample or Mock and every realm is Samplerealm or Mockrealm, never a real one.
--
-- Per client (BL-02; clients-§5, §6): both twins in NS.SAMPLE_FALLBACKS are held to the library,
-- and a character key follows the client's shape, "Name-Realm" on Retail and "First Surname" on
-- WoW Forever (forever-quirks-§4), so every case here runs on both kit profiles.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue =
  T.test, T.assertEqual, T.assertTrue

local Env = dofile("tests/degraded_env.lua")
local Sim = mocks.LibStub("LibKa0s-Sim-1.0", true)

local FIELDS = { "name", "realm", "fullName", "classFile" }

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

test("sample characters: each library-absent twin matches the library's rows for its client", function()
  -- A copy is what drifts: this goes red the release the library's rows move and the host copy does not.
  for _, client in ipairs({ "retail", "forever" }) do
    local copy, lib = NS.SAMPLE_FALLBACKS[client], Sim.SAMPLE[client]
    assertEqual(#copy, #lib, client)
    for i, row in ipairs(lib) do
      for _, f in ipairs(FIELDS) do assertEqual(copy[i][f], row[f], ("%s row %d %s"):format(client, i, f)) end
    end
  end
  assertTrue(NS.SAMPLE_FALLBACK == NS.SAMPLE_FALLBACKS[NS.SAMPLE_CLIENT], "the fallback is not this client's twin")
end)

test("sample characters: the rows are in this client's shape, Name-Realm on Retail, First Surname on Forever", function()
  for _, row in ipairs(NS.SampleCharacters()) do
    assertTrue(conventional(row.fullName), "an unconventional sample character: " .. row.fullName)
    assertEqual(row.fullName:find(" ", 1, true) ~= nil, FOREVER, row.fullName .. "'s shape")
  end
end)

test("sample characters: without the library NS.SampleCharacters answers a copy of the host rows", function()
  local ns = Env.loadDegraded()
  local rows = ns.SampleCharacters()
  assertTrue(ns.SAMPLE_FALLBACK == ns.SAMPLE_FALLBACKS[FOREVER and "forever" or "retail"],
    "the degraded fallback is not this client's twin")
  assertEqual(#rows, #ns.SAMPLE_FALLBACK)
  assertEqual(rows[1].fullName, ns.SAMPLE_FALLBACK[1].fullName)
  rows[1].fullName = "changed"
  assertTrue(ns.SAMPLE_FALLBACK[1].fullName ~= "changed", "a caller's write reached the host copy")
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

test("sample characters: without the library test mode draws the same characters", function()
  local ns = Env.loadDegraded()
  local live, degraded = testModeChars(NS.LedgerTable), testModeChars(ns.LedgerTable)
  for key in pairs(live) do assertTrue(degraded[key], "the degraded sample ledger lost " .. key) end
  for key in pairs(degraded) do assertTrue(live[key], "the degraded sample ledger invented " .. key) end
end)
