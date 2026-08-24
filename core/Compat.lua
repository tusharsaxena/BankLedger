local addonName, NS = ...   -- luacheck: ignore addonName
NS.Compat = NS.Compat or {}
local Compat = NS.Compat

-- Retail-only addon: no game-flavor branching (compat). Every varying / deprecated API is gated by
-- a direct C_*/global presence check here, so a shim degrades to nil/false when its API is absent —
-- never by reading a game-flavor project id. Feature modules call NS.Compat.X, never the raw API.
--
-- What is here is what is genuinely THIS addon's: the container, guild-bank and item readers.
-- The TOC-metadata, map-id and zone reads left for LibKa0s-Env-1.0 and are reached through
-- core/EnvSetup.lua as NS.Meta / NS.Version / NS.PlayerMapID / NS.Zone. They went because every
-- addon in the collection had written the same ladders; these stayed because nobody else has them.
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
