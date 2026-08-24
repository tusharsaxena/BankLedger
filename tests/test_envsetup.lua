-- tests/test_envsetup.lua — the LibKa0s-Env-1.0 seam.
--
-- What is asserted here is THE SEAM, not the library. The library's own suite covers the ladder
-- inside GetAddOnMetadata; a second copy of those cases here is exactly the consumer-side
-- duplication testing-§8 forbids. What only this repo can check is that this addon's helpers answer
-- what its deleted shims answered, that they ask about THIS addon, and that the shims are gone.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local Loader = T.Loader
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- Stand a TOC reader up for the duration of `fn`, recording what it was asked about.
--
-- The mock deliberately does NOT stub `C_AddOns` (tests/_kit/mock_base.lua:183 says why), so out of
-- game this addon has no manifest to read and every metadata call answers nil. That absence is what
-- makes the fallback cases below honest, and it is why the two cases that need a readable TOC build
-- one here rather than asserting a fixture that does not exist.
local function withTOC(version, fn)
  local askedName, askedField
  local saved = mocks.C_AddOns
  mocks.C_AddOns = { GetAddOnMetadata = function(name, field)
    askedName, askedField = name, field
    return field == "Version" and version or nil
  end }
  local ok, err = pcall(fn)
  mocks.C_AddOns = saved
  if not ok then error(err, 0) end
  return askedName, askedField
end

test("EnvSetup: NS.Meta asks about THIS addon's folder, not its title or its frame prefix", function()
  -- The one thing the library cannot get right on its own: LibKa0s is vendored, so the folder name
  -- has to come from the host. "BankLedger", "Ka0s Bank Ledger" and "BL" are all live strings in
  -- this repo and only the first is the folder; a wrong one reads another addon's manifest, or
  -- none, and answers nil without raising.
  local name, field = withTOC("9.9.9", function()
    assertEqual(NS.Meta("Version"), "9.9.9")
  end)
  assertEqual(name, "BankLedger")
  assertEqual(field, "Version")
end)

test("EnvSetup: NS.Meta degrades to nil when the client exposes no manifest reader", function()
  -- The behaviour the deleted Compat.GetAddOnMetadata was pinned on: nil, never a raise.
  assertEqual(NS.Meta("Version"), nil)
end)

test("EnvSetup: NS.Version prefers the TOC over this addon's own constant", function()
  -- A packaged addon whose TOC can be read must never report the constant somebody forgot to edit.
  withTOC("9.9.9", function()
    assertEqual(NS.Version(), "9.9.9")
  end)
end)

test("EnvSetup: NS.Version falls back to this addon's own constant", function()
  -- The fallback lives at the call site rather than in the library, because which constant this
  -- addon falls back to is genuinely its own business — so it is the seam's job to prove it works.
  -- No reader is stubbed here, which is what a client that cannot answer looks like.
  local v = NS.Version()
  assertEqual(v, NS.version)
  assertTrue(v ~= nil and v ~= "", "a version string, never nil — it goes straight into a banner")
end)

test("EnvSetup: NS.Zone answers two strings", function()
  local zone, sub = NS.Zone()
  assertEqual(zone, "Testville")
  assertEqual(sub, "The Vault")
  assertTrue(type(zone) == "string" and type(sub) == "string",
    "both are ALWAYS strings — storage and the zone filter bucket \"\" with nil deliberately")
end)

test("EnvSetup: NS.Zone answers \"\" rather than nil when the client has no zone text", function()
  -- modules/Ledger.lua:BuildEntry stores `zone ~= "" and zone or nil`, so "" and nil land in the
  -- same bucket by design. A seam that answered nil here would raise nothing and move nothing
  -- today, and would break the moment a caller compared the two.
  local savedZone, savedSub = mocks.GetZoneText, mocks.GetSubZoneText
  mocks.GetZoneText, mocks.GetSubZoneText = function() return nil end, function() return nil end
  local zone, sub = NS.Zone()
  mocks.GetZoneText, mocks.GetSubZoneText = savedZone, savedSub
  assertEqual(zone, "")
  assertEqual(sub, "")
end)

test("EnvSetup: NS.PlayerMapID answers the map id", function()
  assertEqual(NS.PlayerMapID(), 2657)
end)

-- Load a fresh, isolated copy of the TOC's files up to and including `stop`, WITHOUT the
-- vendored library — the same shape tests/test_mediasetup.lua uses, and for the same reason: the
-- degraded arm has to run the seam's REAL fallback branch rather than a hand-written stand-in.
local function loadDegraded(stop)
  local m = T.makeMocks()
  local ns = {}
  for _, path in ipairs(Loader.tocFiles("BankLedger.toc")) do
    Loader.load(path, ns, m)
    if path == stop then break end
  end
  return ns, m
end

test("EnvSetup degraded: an install with no LibKa0s still reads its TOC and stamps its zone",
  function()
    -- The case that earns the written-out fallbacks. Without LibKa0s the seam answers nil for
    -- everything unless it repeats the ladders the deleted shims ran, and nil is not an error a
    -- player would ever see reported: it is a blank version in the banner and rows stamped with no
    -- zone. Nothing here loads the library, so this runs the else-branch of every helper.
    local ns, m = loadDegraded("core\\EnvSetup.lua")
    m.C_AddOns = { GetAddOnMetadata = function(_, field)
      return field == "Version" and "9.9.9" or nil
    end }
    assertEqual(ns.Meta("Version"), "9.9.9")
    assertEqual(ns.Version(), "9.9.9")
    assertEqual(ns.PlayerMapID(), 2657)
    local zone, sub = ns.Zone()
    assertEqual(zone, "Testville")
    assertEqual(sub, "The Vault")
  end)

test("EnvSetup: the deleted shims are gone from Compat", function()
  -- A seam that leaves the old copy in place is a second answer nobody removed, and the next caller
  -- reaches for whichever one autocomplete offers first.
  assertEqual(NS.Compat.GetAddOnMetadata, nil)
  assertEqual(NS.Compat.GetPlayerMapID, nil)
  assertEqual(NS.Compat.GetZone, nil)
end)
