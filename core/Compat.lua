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

-- Guild-bank slot info for a tab. Guild bank keeps its own API family (not C_Container).
function Compat.GetGuildBankSlot(tab, slot)
  if type(GetGuildBankItemLink) ~= "function" then return nil end
  local link = GetGuildBankItemLink(tab, slot)
  if not link then return nil end
  local _, count = GetGuildBankItemInfo(tab, slot)
  local itemID = Compat.ItemIDFromLink(link)
  if not itemID then return nil end
  return { itemID = itemID, link = link, count = count or 1 }
end

function Compat.GetNumGuildBankTabs()
  if type(GetNumGuildBankTabs) == "function" then return GetNumGuildBankTabs() or 0 end
  return 0
end

function Compat.GuildBankTabSize()
  -- MAX_GUILDBANK_SLOTS_PER_TAB is a FrameXML constant (98); fall back to it literally when absent.
  return (type(MAX_GUILDBANK_SLOTS_PER_TAB) == "number" and MAX_GUILDBANK_SLOTS_PER_TAB) or 98
end

-- Void-storage slot info. Void storage is a flat 80-slot, stack-of-one store.
function Compat.GetVoidStorageSlot(page, slot)
  if type(GetVoidItemInfo) ~= "function" then return nil end
  local itemID = GetVoidItemInfo(page, slot)
  if not itemID then return nil end
  return { itemID = itemID, link = nil, count = 1 }
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

-- Display + valuation info for an item id (or link). Returns name, quality, itemType, itemSubType,
-- vendorPrice — each nil when the client hasn't cached the item yet.
function Compat.GetItemDetails(idOrLink)
  if not idOrLink then return nil end
  if not (C_Item and C_Item.GetItemInfo) then return nil end
  local name, link, quality, _, _, itemType, itemSubType, _, _, _, vendorPrice =
    C_Item.GetItemInfo(idOrLink)
  if not name then return nil end
  return name, quality, itemType, itemSubType, vendorPrice, link
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
