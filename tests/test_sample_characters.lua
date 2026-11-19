-- tests/test_sample_characters.lua — the made-up people this addon shows, on the collection's one
-- set (LibKa0s-Sim-1.0's Sim.SAMPLE / Sim.Sample, preview-mode's sample-character convention,
-- LibKa0s#87, AD-87-BL).
--
-- Two places invent characters: test mode's sample ledger (modules/LedgerTable_TestMode.lua) and the
-- simulator's alt (modules/SimWorld.lua). Both read NS.SampleCharacters() (core/SimSetup.lua): the
-- library's rows for this client, or, without the library, the host copy NS.SAMPLE_FALLBACK, which
-- is held to the library's rows here so it cannot drift. Names are data, never localized; every
-- name starts Sample or Mock and every realm is Samplerealm or Mockrealm, never a real one.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue =
  T.test, T.assertEqual, T.assertTrue

local Env = dofile("tests/degraded_env.lua")
local Sim = mocks.LibStub("LibKa0s-Sim-1.0", true)

local FIELDS = { "name", "realm", "fullName", "classFile" }

--- A character key that follows the convention: a 2-12 letter name starting Sample or Mock, on one
--- of the two fixed fictional realms.
local function conventional(key)
  local name, realm = tostring(key):match("^(%a+)%-(%a+)$")
  if not name then return false end
  if not (name:find("^Sample") or name:find("^Mock")) then return false end
  if #name < 2 or #name > 12 then return false end
  return realm == "Samplerealm" or realm == "Mockrealm"
end

test("sample characters: NS.SampleCharacters answers the library's rows for this client", function()
  local rows, lib = NS.SampleCharacters(), Sim.Sample()
  assertEqual(#rows, #lib)
  for i, row in ipairs(lib) do
    for _, f in ipairs(FIELDS) do assertEqual(rows[i][f], row[f], ("row %d %s"):format(i, f)) end
  end
  rows[1].name = "changed"
  assertEqual(NS.SampleCharacters()[1].name, lib[1].name, "a caller's write reached the shared rows")
end)

test("sample characters: the library-absent copy matches the library's Retail rows field for field", function()
  -- A copy is what drifts: this goes red the release the library's rows move and the host copy does not.
  local copy, lib = NS.SAMPLE_FALLBACK, Sim.SAMPLE.retail
  assertEqual(#copy, #lib)
  for i, row in ipairs(lib) do
    for _, f in ipairs(FIELDS) do assertEqual(copy[i][f], row[f], ("row %d %s"):format(i, f)) end
  end
end)

test("sample characters: without the library NS.SampleCharacters answers a copy of the host rows", function()
  local ns = Env.loadDegraded()
  local rows = ns.SampleCharacters()
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
  for _, row in ipairs(Sim.Sample()) do
    if seen[row.fullName] ~= nil then
      assertEqual(classOf[row.fullName], row.classFile, row.fullName .. "'s class")
    end
  end
  for _, cls in ipairs({ "MAGE", "PALADIN", "PRIEST", "WARRIOR" }) do
    local shared
    for _, row in ipairs(Sim.Sample()) do if row.classFile == cls then shared = row.fullName end end
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
