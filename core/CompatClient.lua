local _, NS = ...
-- core/CompatClient.lua — the client and the character's name (WoW Forever port design, "Client
-- routing" and "Identity"; clients-§3, clients-§4, forever-quirks-§4): the reads that answer
-- differently on Retail and WoW Forever about which game this is and who a character is.
--
-- WHY HERE. The client questions (IsForever, IsRetail, ClientKey, ForClient) and the character-name
-- readers (RegionalNames, UnitCharacterName, CharacterKey, RealmKey) are LibKa0s-Compat-1.0 members
-- (vendored in libs/LibKa0s/Compat.lua, loaded by LibKa0s.xml), so this file routes them, each with
-- its library-absent stub, rather than re-implementing them. It is a sibling of core/Compat.lua
-- rather than a block inside it so the container, guild-bank and item readers stay one topic there.
--
-- THE RULE (clients-§3). This is the ONE file in the addon that reads a WOW_PROJECT_* constant or
-- RegionalUniqueNamesEnabled; every other file asks NS.Compat. Feature presence on a client is a
-- declaration through ForClient (clients-§4), never feature detection.
--
-- THE STUBS are the library's bodies, globals read bare at call time, so an install missing
-- LibKa0s answers the client questions exactly as one with it. The character keys (CharacterKey,
-- RealmKey) answer nil without the library: they mirror AceDB-3.0's key block, and a second copy of
-- it here would be one more place for the two to drift. A secret part is never answered or joined.
--
-- LOAD-BEARING POSITION: straight after core/Compat.lua and before core/SimSetup.lua, which wraps
-- every NS.Compat function member at load (Sim-1.0 host contract H2). Read inside functions only.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

--- True when `v` is a 12.0 secret value: the library's guard, else the same one-rung body.
local isSecret = CompatLib and CompatLib.IsSecret or function(v)
  return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- A plain (non-secret) string, or nil.
local function plainString(v)
  if isSecret(v) or type(v) ~= "string" then return nil end
  return v
end

-- ── The client: LibKa0s-Compat-1.0's, with the stub arm (clients-§3) ──────────────────────────
-- The nil guard keeps a client with neither constant from reading as Forever (nil == nil).

local function isForeverStub()
  return WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

local function isRetailStub()
  return WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and not isForeverStub()
end

local function clientKeyStub()
  if isForeverStub() then return "forever" end
  if isRetailStub() then return "retail" end
  return nil
end

local CLIENT_TOKENS = { retail = true, forever = true, both = true }

local function forClientStub(clients)
  if clients == nil or clients == "both" then return true end
  if type(clients) ~= "table" then error('ForClient: unknown client "' .. tostring(clients) .. '"', 2) end
  local key, hit = clientKeyStub(), false
  for _, token in ipairs(clients) do
    if not CLIENT_TOKENS[token] then error('ForClient: unknown client "' .. tostring(token) .. '"', 2) end
    hit = hit or token == "both" or token == key
  end
  return hit
end

--- Whether this is a WoW Forever client. Exactly one boolean.
Compat.IsForever = CompatLib and CompatLib.IsForever or isForeverStub

--- Whether this is a Retail client (the mainline project id and NOT Forever). Exactly one boolean.
Compat.IsRetail = CompatLib and CompatLib.IsRetail or isRetailStub

--- The client's key: "retail", "forever", or nil when the project constants say neither. The key a
--- per-client table is seeded by, once (clients-§5).
Compat.ClientKey = CompatLib and CompatLib.ClientKey or clientKeyStub

--- Whether a `clients` declaration (nil, "both", or an array of "retail" / "forever" / "both")
--- includes this client; nil means both (clients-§4). An unknown token raises on any client.
Compat.ForClient = CompatLib and CompatLib.ForClient or forClientStub

-- ── The character's name (forever-quirks-§4) ──────────────────────────────────────────────────

--- Whether character names are unique per region (true on WoW Forever, where a character is its
--- first name and surname together and carries no realm). False where the switch is absent.
--- @return boolean
Compat.RegionalNames = CompatLib and CompatLib.RegionalNames or function()
  return RegionalUniqueNamesEnabled ~= nil and RegionalUniqueNamesEnabled() == true
end

--- A unit's whole character name and its realm: "Traxex Silentshot" and a nil realm with regional
--- names (WoW Forever); UnitName's name and realm otherwise (the realm nil on the player's own).
--- With the library absent, the library's own answer from UnitName: with regional names its second
--- value is the SURNAME, joined into the name and never read as a realm (BL-REV: dropping it gave
--- two Forever characters who share a first name one record key). The name is nil for no unit, a
--- secret or ""; the realm nil for a secret or "".
--- @param unit string
--- @return string|nil name, string|nil realm
function Compat.UnitCharacterName(unit)
  local read = CompatLib and CompatLib.UnitCharacterName or UnitName
  if not (unit and read) then return nil end
  local name, realm = read(unit)
  name = plainString(name)
  if not name or name == "" then return nil end
  realm = plainString(realm)
  if realm == "" then realm = nil end
  if not CompatLib and Compat.RegionalNames() then
    if realm then name = name .. " " .. realm end
    realm = nil
  end
  return name, realm
end

--- The player's character key, AceDB-3.0's: "First Surname" with regional names, "Name - Realm"
--- otherwise. Nil until the client can answer, for a secret, and with the library absent.
--- @return string|nil
function Compat.CharacterKey()
  if not (CompatLib and CompatLib.CharacterKey) then return nil end
  return plainString(CompatLib.CharacterKey())
end

--- The player's realm key, AceDB-3.0's: the ruleset ("Hardcore", "RP-PvP", "RP", "PvP", "PvE")
--- with regional names, GetRealmName() otherwise. Nil until the client can answer, for a secret,
--- and with the library absent.
--- @return string|nil
function Compat.RealmKey()
  if not (CompatLib and CompatLib.RealmKey) then return nil end
  return plainString(CompatLib.RealmKey())
end
