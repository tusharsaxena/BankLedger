local addonName, NS = ...   -- luacheck: ignore addonName
NS.Compat = NS.Compat or {}
local Compat = NS.Compat

-- Retail-only addon: no game-flavor branching (compat). Every varying / deprecated API is gated by
-- a direct C_*/global presence check here, so a shim degrades to nil/false when its API is absent —
-- never by reading a game-flavor project id. Feature modules call NS.Compat.X, never the raw API.

-- ── Addon metadata ──────────────────────────────────────────────────────────────

-- TOC metadata field (e.g. "Version"), read from the packaged manifest so `/bl version` can't drift
-- from the TOC. Retail moved the getter to C_AddOns; falls back to the bare global, then nil.
function Compat.GetAddOnMetadata(name, field)
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(name, field)
  end
  if type(GetAddOnMetadata) == "function" then
    return GetAddOnMetadata(name, field)
  end
  return nil
end

-- ── World / player ──────────────────────────────────────────────────────────────

function Compat.GetPlayerMapID()
  if C_Map and C_Map.GetBestMapForUnit then
    return C_Map.GetBestMapForUnit("player")
  end
  return nil
end

function Compat.GetZone()
  local zone = (GetZoneText and GetZoneText()) or ""
  local subzone = (GetSubZoneText and GetSubZoneText()) or ""
  return zone, subzone
end

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
  local itemID = Compat.ItemIDFromLink(link)
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

-- itemID parsed from an item link or itemString. Locale-independent; nil when absent.
function Compat.ItemIDFromLink(link)
  if type(link) ~= "string" then return nil end
  return tonumber(link:match("|?H?item:(%d+)"))
end

-- Reverse map of item-quality colour hex (rrggbb) → quality id, for the uncached fallback.
local qualityByHex
local function buildQualityByHex()
  qualityByHex = {}
  if type(ITEM_QUALITY_COLORS) == "table" then
    for q = 0, 8 do
      local c = ITEM_QUALITY_COLORS[q]
      if c and c.hex then qualityByHex[c.hex:sub(-6)] = q end
    end
  end
end

function Compat.QualityFromLink(link)
  if type(link) ~= "string" then return nil end
  local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
  if not hex then return nil end
  if not qualityByHex then buildQualityByHex() end
  return qualityByHex[hex]
end

-- Localized quality label (Poor/Common/…). Falls back to a static English map headlessly and for
-- unknown ids. Matches on the *id*, never a localized string (localization-§4).
local QUALITY_LABEL_EN = {
  [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare",
  [4] = "Epic", [5] = "Legendary", [6] = "Artifact", [7] = "Heirloom", [8] = "WoW Token",
}
function Compat.QualityLabel(q)
  q = q or 0
  return _G["ITEM_QUALITY" .. q .. "_DESC"] or QUALITY_LABEL_EN[q] or tostring(q)
end

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

-- Resolve an item id to a display name + quality for the filter-management UI. Returns
-- (name, quality); name is nil when the item is not yet cached (the caller shows a placeholder).
function Compat.ItemNameQuality(id)
  if not id then return nil end
  if C_Item and C_Item.GetItemInfo then
    local name, _, quality = C_Item.GetItemInfo(id)
    return name, quality
  end
  return nil
end

-- Ask the server to cache an item id so a later ItemNameQuality resolves; `cb` fires once loaded.
function Compat.LoadItem(id, cb)
  if not (id and C_Item and C_Item.RequestLoadItemDataByID) then return end
  C_Item.RequestLoadItemDataByID(id)
  if cb and C_Timer and C_Timer.After then C_Timer.After(0.4, cb) end
end
