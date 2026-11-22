-- tests/test_compat_client.lua — the client and the character-name reads of the compat family
-- (core/CompatClient.lua; Forever port design "Client routing"; clients-§3, clients-§4,
-- forever-quirks-§4): IsForever, IsRetail, ClientKey and ForClient, then RegionalNames,
-- UnitCharacterName, CharacterKey and RealmKey, each routed from the vendored LibKa0s-Compat-1.0
-- with a library-absent stub. Every case runs on both kit profiles
-- (`KA0S_KIT_CLIENT=forever lua tests/run.lua`) and picks its expectation by the profile
-- (clients-§6). A case that needs regional names sets RegionalUniqueNamesEnabled on its own mocks,
-- so the answer it pins does not lean on what the shared mock set says about names.
--
-- Each arm is a fresh, isolated environment from tests/degraded_env.lua's loadUpTo, stopped at
-- core/CompatClient.lua: the live arm has the vendored library in front of it, the degraded arm
-- does not, so the stub is exercised by a real load rather than by a hand-stub after the fact.

local T = _G.BL_TEST
local Loader = T.Loader
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local Env = dofile("tests/degraded_env.lua")

local PROFILE = os.getenv("KA0S_KIT_CLIENT") or "retail"
local STOP = "core/CompatClient.lua"

--- NS.Compat and its mocks, with the library (`withLibrary`) or without it.
local function fresh(withLibrary)
  local ns, m = Env.loadUpTo(STOP, withLibrary)
  assertTrue(type(ns.Compat) == "table", "no NS.Compat in the isolated environment")
  return ns.Compat, m
end

--- Both arms, live first: `{ Compat, mocks, label }` each.
local function arms()
  local live, lm = fresh(true)
  local stub, sm = fresh(false)
  return { { live, lm, "library" }, { stub, sm, "stub" } }
end

-- ── the client (clients-§3, §4) ───────────────────────────────────────────────────────────────

test("compat client: ClientKey, IsForever and IsRetail answer the kit profile on both arms", function()
  for _, arm in ipairs(arms()) do
    local Compat, _, label = arm[1], arm[2], arm[3]
    assertEqual(Compat.ClientKey(), PROFILE, label)
    assertEqual(Compat.IsForever(), PROFILE == "forever", label)
    assertEqual(Compat.IsRetail(), PROFILE == "retail", label)
  end
end)

test("compat client: ForClient(nil) is true, a declared client only on that client, an unknown token raises", function()
  for _, arm in ipairs(arms()) do
    local Compat, label = arm[1], arm[3]
    assertTrue(Compat.ForClient(nil), label)
    assertTrue(Compat.ForClient("both"), label)
    assertTrue(Compat.ForClient({ "retail", "forever" }), label)
    assertEqual(Compat.ForClient({ "retail" }), PROFILE == "retail", label)
    assertEqual(Compat.ForClient({ "forever" }), PROFILE == "forever", label)
    assertFalse(pcall(Compat.ForClient, { "classic" }), label .. ": an unknown token raises")
    assertFalse(pcall(Compat.ForClient, "retail"), label .. ": a bare client string raises")
  end
end)

test("compat client: a client that is neither answers nil and serves undeclared features only", function()
  for _, arm in ipairs(arms()) do
    local Compat, m, label = arm[1], arm[2], arm[3]
    m.WOW_PROJECT_ID, m.WOW_PROJECT_CAMELOT = 2, nil
    assertNil(Compat.ClientKey(), label)
    assertFalse(Compat.IsForever(), label)
    assertFalse(Compat.IsRetail(), label)
    assertTrue(Compat.ForClient(nil), label)
    assertFalse(Compat.ForClient({ "retail" }), label)
    -- No constants at all must not read as Forever (nil == nil).
    m.WOW_PROJECT_ID, m.WOW_PROJECT_MAINLINE = nil, nil
    assertFalse(Compat.IsForever(), label .. ": no constants is not Forever")
    assertNil(Compat.ClientKey(), label)
  end
end)

-- ── names (forever-quirks-§4) ─────────────────────────────────────────────────────────────────

test("compat client: RegionalNames follows RegionalUniqueNamesEnabled, false where it is absent", function()
  for _, arm in ipairs(arms()) do
    local Compat, m, label = arm[1], arm[2], arm[3]
    m.RegionalUniqueNamesEnabled = nil
    assertFalse(Compat.RegionalNames(), label .. ": absent")
    m.RegionalUniqueNamesEnabled = function() return false end
    assertFalse(Compat.RegionalNames(), label .. ": off")
    m.RegionalUniqueNamesEnabled = function() return true end
    assertTrue(Compat.RegionalNames(), label .. ": on")
  end
end)

test("compat client: UnitCharacterName is the whole name with regional names, name and realm without", function()
  for _, arm in ipairs(arms()) do
    local Compat, m, label = arm[1], arm[2], arm[3]
    m.UnitName = function(unit) if unit == "player" then return "Traxex", "Silentshot" end end
    m.RegionalUniqueNamesEnabled = function() return false end
    local name, realm = Compat.UnitCharacterName("player")
    assertEqual(name, "Traxex", label)
    assertEqual(realm, "Silentshot", label .. ": UnitName's second value is a realm without regional names")
    m.UnitName = function() return "Traxex", "" end
    name, realm = Compat.UnitCharacterName("player")
    assertEqual(name, "Traxex", label)
    assertNil(realm, label .. ": an empty realm is no realm")
    assertNil((Compat.UnitCharacterName(nil)), label .. ": no unit")
    m.UnitName = function() return nil end
    assertNil((Compat.UnitCharacterName("party4")), label .. ": no answer")
  end
  -- With regional names the second value is a SURNAME: the library joins it, and so does the stub
  -- (BL-REV), or two Forever characters who share a first name would share a record key on a
  -- degraded load.
  local live, lm = fresh(true)
  lm.RegionalUniqueNamesEnabled = function() return true end
  lm.UnitName = function() return "Traxex", "Silentshot" end
  local name, realm = live.UnitCharacterName("player")
  assertEqual(name, "Traxex Silentshot", "the whole name, never Traxex-Silentshot")
  assertNil(realm, "no realm with regional names")
  local stub, sm = fresh(false)
  sm.RegionalUniqueNamesEnabled = function() return true end
  sm.UnitName = function() return "Traxex", "Silentshot" end
  name, realm = stub.UnitCharacterName("player")
  assertEqual(name, "Traxex Silentshot", "library absent: the whole name, as the library answers")
  assertNil(realm, "library absent: a surname is never read as a realm")
  sm.UnitName = function() return "Traxex", "" end
  assertEqual((stub.UnitCharacterName("player")), "Traxex", "library absent: no surname, the first name")
end)

test("compat client: UnitCharacterName never answers a secret name", function()
  for _, arm in ipairs(arms()) do
    local Compat, m, label = arm[1], arm[2], arm[3]
    local secret = {}
    m.issecretvalue = function(v) return v == secret end
    m.UnitName = function() return secret, "Realm" end
    assertNil((Compat.UnitCharacterName("target")), label)
  end
end)

test("compat client: CharacterKey is this client's AceDB character key; nil without the library", function()
  local live, lm = fresh(true)
  lm.RegionalUniqueNamesEnabled = function() return false end
  assertEqual(live.CharacterKey(), "Mock - Realm")
  lm.RegionalUniqueNamesEnabled = function() return true end
  lm.UnitNameUnmodified = function() return "Traxex", "Silentshot" end
  assertEqual(live.CharacterKey(), "Traxex Silentshot")
  local stub = fresh(false)
  assertNil(stub.CharacterKey(), "library absent: no key")
end)

test("compat client: RealmKey is the realm without regional names, the ruleset with them; nil without the library", function()
  local live, lm = fresh(true)
  lm.RegionalUniqueNamesEnabled = function() return false end
  assertEqual(live.RealmKey(), "Realm")
  lm.RegionalUniqueNamesEnabled = function() return true end
  lm.Enum = setmetatable({ GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 } },
    { __index = lm.Enum })
  lm.C_GameRules = { IsGameRuleActive = function(rule) return rule == 3 end }
  assertEqual(live.RealmKey(), "PvP")
  local stub = fresh(false)
  assertNil(stub.RealmKey(), "library absent: no key")
end)

-- ── the boundary (clients-§3) ─────────────────────────────────────────────────────────────────

test("compat client: no shipped file but core/CompatClient.lua reads a project id or the regional-names switch", function()
  local offenders = {}
  for _, path in ipairs(Loader.tocFiles("BankLedger.toc")) do
    if not path:find("^libs/") and path ~= STOP and path:find("%.lua$") then
      local src = Loader.readFile(path)
      for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        local code = line:gsub("%-%-.*$", "")
        if code:find("WOW_PROJECT_", 1, true) or code:find("RegionalUniqueNamesEnabled", 1, true) then
          offenders[#offenders + 1] = path .. ": " .. line
        end
      end
    end
  end
  assertEqual(table.concat(offenders, " | "), "")
end)

test("compat client: core/CompatClient.lua loads straight after core/Compat.lua and before core/SimSetup.lua", function()
  local toc = Loader.tocFiles("BankLedger.toc")
  local at
  for i, p in ipairs(toc) do if p == "core/Compat.lua" then at = i end end
  assertTrue(at ~= nil, "core/Compat.lua is not in BankLedger.toc")
  assertEqual(toc[at + 1], STOP)
  assertEqual(toc[at + 2], "core/SimSetup.lua")
end)
