local _, NS = ...
NS.Compat = NS.Compat or {}
local Compat = NS.Compat

-- Ships on Retail and WoW Forever from one codebase (clients-§1). Which client this is, and the
-- character-name readers whose answers differ between the two, are core/CompatClient.lua's: it is the
-- one file that reads a WOW_PROJECT_* constant (clients-§3). Here every varying / deprecated API is
-- gated by a direct C_*/global presence check, so a shim degrades to nil/false when its API is
-- absent. Feature modules call NS.Compat.X, never the raw API.
--
-- What is here is what is genuinely THIS addon's: the container, guild-bank and item readers, and
-- the player-identity reads the in-game simulator must be able to answer (docs/compat-layer.md).
-- The TOC-metadata, map-id and zone reads left for LibKa0s-Env-1.0 and are reached through
-- core/EnvSetup.lua as NS.Meta / NS.Version / NS.PlayerMapID / NS.Zone. They went because every
-- addon in the collection had written the same ladders; these stayed because nobody else has them.
-- The container groups, CanViewCharacterBank and the bank-readiness judgment went the same way, to
-- LibKa0s-Compat-1.0 (LibKa0s#101): three addons carried them. They are routed below, by name.
--
-- The four item PRIMITIVES went the same way, to LibKa0s-Item-1.0 via core/ItemSetup.lua, and are
-- reached as NS.Item.ItemIDFromLink / QualityFromLink / QualityLabel / LoadItem. What stayed is
-- the RESOLVER: GetItemDetails and ItemNameQuality refuse an item the client has not cached, and
-- that refusal is this addon's policy ("cannot be judged" is not "passes", F-006). LootHistory's
-- resolver guesses from the link on purpose; a shared one would have had to overturn one of them.

-- ── World / player ──────────────────────────────────────────────────────────────

-- The player's guild name, or nil when unguilded / the API is absent. Used to stamp guild-bank
-- movements so a character who changes guild keeps its history straight.
function Compat.GetGuildName()
  if type(GetGuildInfo) ~= "function" then return nil end
  local name = GetGuildInfo("player")
  if name == "" then return nil end
  return name
end

-- The player's name and realm, the two parts of the record key Util.RecordKey joins (WoW Forever
-- port, "Identity"). Without regional names (Retail): UnitName's name and the realm, normalized and
-- whitespace stripped, each "Unknown" when the client cannot answer, so the key stays the
-- `Name-Realm` every stored Retail row carries. With regional names (WoW Forever, forever-quirks-§4):
-- the whole character key, "First Surname" (core/CompatClient.lua's CharacterKey, else the name
-- UnitCharacterName reads, else "Unknown"), and a nil realm, so two characters who share a first
-- name never share a key and no realm is ever read or joined. Always exactly two values. Read at
-- call time, never cached: a row's `char` is identity, and the in-game simulator answers identity
-- (its alt character) only through a Compat member it can stand in for, this one; the
-- CompatClient readers it calls are pure and never answer for the alt.
function Compat.PlayerName()
  if Compat.RegionalNames() then
    return Compat.CharacterKey() or Compat.UnitCharacterName("player") or "Unknown", nil
  end
  local name = UnitName("player") or "Unknown"
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName())
    or (GetRealmName and GetRealmName()) or "Unknown"
  realm = tostring(realm):gsub("%s+", "")
  return name, realm
end

-- The player's classFile (the uppercase token, UnitClass's second return) that tints a row's
-- character. Read at call time for the same reason as PlayerName.
function Compat.PlayerClass()
  local _, classFile = UnitClass("player")
  return classFile
end

-- Carried money in copper. Money is never a combat-protected "secret" value, but it still routes
-- through the shared printer/sink like everything else (events-frames-taint-§8).
function Compat.GetMoney()
  if type(GetMoney) == "function" then return GetMoney() or 0 end
  return 0
end

-- Coin held BY a store, not by the player — the corroborating side of a money movement. Returns nil
-- for a store that holds no coin of its own, and for one whose balance this build cannot read; the
-- caller must then decline to attribute the movement rather than guess (see Ledger.Diff).
--
-- Returning nil rather than 0 is the whole point. `GetGuildBankMoney()` answers **0** when the guild
-- bank frame is closed, not nil — verified on 12.0.7 via `/bl debug scan`, which read 0 at a bank
-- and 65537936844 at the guild bank moments later. Passing that 0 through as a balance would make
-- the next open look like a six-thousand-gold deposit, so the read is gated on the frame being up.
-- `C_Bank.FetchDepositedMoney` has no such frame dependency: it reported the same warband figure in
-- both sessions. `Enum.BankType.Account` is read BY NAME — the ids (Character=0, Guild=1, Account=2)
-- share no ordering with any other enum here and must never be assumed numerically.
--
-- Constants is resolved at call time, not as an upvalue: Compat loads first (TOC), so C.Store does
-- not exist yet at this file's load.
function Compat.GetStoreMoney(store)
  local Store = NS.Constants and NS.Constants.Store
  if not (Store and store) then return nil end
  if store == Store.GUILD_BANK then
    if type(GetGuildBankMoney) ~= "function" then return nil end
    if not Compat.IsGuildBankVisible() then return nil end
    return GetGuildBankMoney()
  end
  if store == Store.WARBAND_BANK then
    local fn = C_Bank and C_Bank.FetchDepositedMoney
    local bankType = Enum and Enum.BankType and Enum.BankType.Account
    if type(fn) ~= "function" or bankType == nil then return nil end
    return fn(bankType)
  end
  return nil
end

-- ── Container groups and bank readiness: LibKa0s-Compat-1.0's (LibKa0s#101) ──────
--
-- Which container ids make up the bags, the character bank and the warband bank, whether the
-- character bank can be viewed at this banker, and which bank containers are still loading are
-- LibKa0s-Compat-1.0 members (minor 6, vendored in libs/LibKa0s/Compat.lua). BankLedger, LootHistory
-- and OutfitterReborn each carried a copy and the copies drifted, so this addon routes the one copy
-- rather than keeping its own. The library's bodies are the ones this file used to carry: ids by
-- anchored, case-sensitive Enum.BagIndex member NAME, the keyring (-1) in the bags on WoW Forever
-- only (R5), the account bank declared on Retail only (R1), the bags falling back to 0..5 when the
-- enum names none, and CanViewBank(Character) three-valued.
--
-- What stays here is the addon's policy around them: core/Constants.lua gates the Warband Bank on
-- C.FEATURE as before, and modules/Ledger.lua keeps the readiness deadline and the shape memory.
--
-- LIBRARY ABSENT (a partial install). Degraded stubs, never a second copy of the bodies: the groups
-- are the library's no-enum answer (the bags 0..5 and no bank at all), so with no bank group there is
-- no bank container to judge, the readiness stub answers ready, and CanViewCharacterBank answers nil
-- (cannot tell). With no bank container scanned, no bank row is written: the addon errs toward
-- recording nothing, as the readiness guard does.
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

local function containerGroupsStub()
  return { bags = { 0, 1, 2, 3, 4, 5 }, bank = {}, accountBank = {} }
end

--- The container ids of each group on this client: `{ bags = {...}, bank = {...}, accountBank = {...} }`,
--- sorted and de-duplicated, fresh tables on every call. Pure (a fact of the install).
Compat.ContainerGroups = CompatLib and CompatLib.ContainerGroups or containerGroupsStub

--- The library's pattern table, one row per client (`bags`, `bank`, `accountBank`), for the suite to
--- pin. Empty with the library absent.
Compat.CONTAINER_PATTERNS_BY_CLIENT = CompatLib and CompatLib.CONTAINER_PATTERNS_BY_CLIENT or {}

-- Can the character bank be viewed at the banker the player is talking to? A warband-only banker
-- (Enum.PlayerInteractionType.AccountBanker) opens the bank frame on the Warband Bank alone, and the
-- character bank's containers are not the player's to read there (BagSync v20.41 stops saving it
-- for this reason). Three-valued, like IsGuildBankVisible: true or false from
-- C_Bank.CanViewBank(Enum.BankType.Character), present on both clients, and nil when this build
-- cannot tell (or answers a secret), which the caller must read as "readable". The bank type is read
-- BY NAME. Wrapped by the simulator's seam: the simulated world answers it.
Compat.CanViewCharacterBank = CompatLib and CompatLib.CanViewCharacterBank or function() return nil end

--- The bank containers not ready yet, or nil when the bank is ready: the sorted ids of `shape`
--- ({ [id] = slots now }) that read 0 after reporting slots in `memory` ({ [id] = slots at the last
--- ready read }). Pure. With no memory and no `purchased` it answers nil, so a first visit takes its
--- read as it finds it. The caller keeps the memory and the deadline.
Compat.UnreadyBankContainers = CompatLib and CompatLib.UnreadyBankContainers or function() return nil end

-- ── Container (bag / bank) inventory ────────────────────────────────────────────

-- Number of slots in a container id, 0 when the id isn't accessible right now.
function Compat.GetContainerNumSlots(bagID)
  local fn = C_Container and C_Container.GetContainerNumSlots
  if fn then return fn(bagID) or 0 end
  return 0
end

-- Per-slot item info as a plain { itemID, link, count } triple, or nil for an empty slot. Wraps the
-- Retail C_Container table return so the diff engine never touches the raw API shape.
function Compat.GetContainerSlot(bagID, slot)
  local fn = C_Container and C_Container.GetContainerItemInfo
  if not fn then return nil end
  local info = fn(bagID, slot)
  if not info or not info.itemID then return nil end
  return { itemID = info.itemID, link = info.hyperlink, count = info.stackCount or 1 }
end

-- Guild-bank slot info for a tab. The guild bank keeps its own API family (not C_Container), and
-- both getters are guarded independently — a build that keeps one and retires the other must
-- degrade to "no data", never raise mid-scan.
function Compat.GetGuildBankSlot(tab, slot)
  if type(GetGuildBankItemLink) ~= "function" then return nil end
  local link = GetGuildBankItemLink(tab, slot)
  if not link then return nil end
  local count = 1
  if type(GetGuildBankItemInfo) == "function" then
    local _, n = GetGuildBankItemInfo(tab, slot)
    count = n or 1
  end
  local itemID = NS.Item.ItemIDFromLink(link)
  if not itemID then return nil end
  return { itemID = itemID, link = link, count = count }
end

function Compat.GetNumGuildBankTabs()
  if type(GetNumGuildBankTabs) == "function" then return GetNumGuildBankTabs() or 0 end
  return 0
end

-- Ask the server for a tab's contents.
--
-- This is not optional: the guild bank only holds data for tabs that have been **queried**, so
-- `GetGuildBankItemLink` returns nil for every tab the player has not looked at. Without this the
-- scan sees an almost-empty guild bank no matter what is really in it. The reply is asynchronous
-- and arrives as GUILDBANKBAGSLOTS_CHANGED, which the addon already reconciles on.
function Compat.QueryGuildBankTab(tab)
  if type(QueryGuildBankTab) == "function" then QueryGuildBankTab(tab) end
end

-- The tab the guild-bank UI is currently showing (nil when unavailable). Only this one is
-- guaranteed to hold data before any query.
function Compat.GetCurrentGuildBankTab()
  if type(GetCurrentGuildBankTab) == "function" then return GetCurrentGuildBankTab() end
  return nil
end

-- Is the guild-bank window on screen?
--
-- Three-valued on purpose: **nil means "cannot tell on this build"**, which is different from
-- false. The guild bank is armed by data arriving rather than by a frame-open event (that event
-- registers fine but never fires on 12.0.7), so something has to say when it is gone — but a build
-- without this frame must leave the addon armed rather than disarm it on a false negative.
-- Read the frame as a bare global, NOT as `_G.GuildBankFrame`: the headless loader resolves globals
-- through a mock environment, and an explicit `_G` lookup steps around it straight into the real
-- global table — where nothing WoW-shaped exists. The bare name is also what the live client sees,
-- so this is the form that is testable and correct at once.
function Compat.IsGuildBankVisible()
  local frame = GuildBankFrame
  if not (frame and type(frame.IsVisible) == "function") then return nil end
  return frame:IsVisible() and true or false
end

function Compat.GuildBankTabSize()
  -- MAX_GUILDBANK_SLOTS_PER_TAB is a FrameXML constant (98); fall back to it literally when absent.
  return (type(MAX_GUILDBANK_SLOTS_PER_TAB) == "number" and MAX_GUILDBANK_SLOTS_PER_TAB) or 98
end

-- ── Item identity / display ─────────────────────────────────────────────────────

-- Display info for an item id (or link). Returns name, quality, itemType, itemSubType, link --
-- each nil when the client hasn't cached the item yet. Vendor price is deliberately NOT read: the
-- addon does not derive or persist item value (schema v2).
function Compat.GetItemDetails(idOrLink)
  if not idOrLink then return nil end
  if not (C_Item and C_Item.GetItemInfo) then return nil end
  local name, link, quality, _, _, itemType, itemSubType = C_Item.GetItemInfo(idOrLink)
  if not name then return nil end
  return name, quality, itemType, itemSubType, link
end

-- Resolve an item to a display name + quality. Returns (name, quality); name is nil when the item
-- is not yet cached (the caller shows a placeholder).
--
-- Pass a LINK whenever one was observed. An id alone can only ever answer with the base item, so a
-- drop upgraded by its bonus IDs reads back at its base quality — the filter-management UI has no
-- link to offer (the user typed an id), but the capture gate does, and there it decides whether a
-- row is kept at all.
function Compat.ItemNameQuality(idOrLink)
  if not idOrLink then return nil end
  if C_Item and C_Item.GetItemInfo then
    local name, _, quality = C_Item.GetItemInfo(idOrLink)
    return name, quality
  end
  return nil
end
