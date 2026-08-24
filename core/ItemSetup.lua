local _, NS = ...

-- core/ItemSetup.lua — wires the addon into LibKa0s-Item-1.0 (library-stack-§7).
--
-- ── WHAT MOVED, AND WHAT POINTEDLY DID NOT ───────────────────────────────────────────────────
--
-- Four primitives moved: ItemIDFromLink, QualityFromLink, QualityLabel, LoadItem. Two of them were
-- byte-identical to LootHistory's and two were written by only one of the two addons — this one had
-- ItemIDFromLink, that one had QualityFromLink, and the missing colour fallback is the primitive
-- whose absence once let an upgrade-track drop record at its base quality.
--
-- THE RESOLVER DID NOT MOVE, and that is a decision rather than an oversight. Compat.GetItemDetails
-- refuses an item the client has not cached: the capture gate records the skip as "uncached" and
-- asks the client to cache the id, because "cannot be judged" is not "passes" (F-006) and a row
-- that can never be classified is not one a quality threshold ever asked for. LootHistory's
-- resolver does the opposite on purpose — it guesses from the link, because a browsable capture log
-- would rather show an approximate row than lose the drop. A shared resolver would have had to pick
-- one, and picking would have silently overturned the other.
--
-- ── WHAT A DEGRADED INSTALL GETS ─────────────────────────────────────────────────────────────
--
-- The same four primitives, locally. They are short, pure and were here before; a caller that had
-- to branch on the library's presence would be a caller that renders differently on a broken
-- install.

local Item = LibStub and LibStub("LibKa0s-Item-1.0", true)

local QUALITY_LABEL_EN = {
  [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare",
  [4] = "Epic", [5] = "Legendary", [6] = "Artifact", [7] = "Heirloom", [8] = "WoW Token",
}

-- Built on first use, never at load: this file runs before the client has populated
-- ITEM_QUALITY_COLORS, and a map built here would be empty for the life of the session.
local qualityByHex

NS.Item = Item or {
  ItemIDFromLink = function(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("|?H?item:(%d+)"))
  end,

  QualityFromLink = function(link)
    if not link then return nil end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    if not hex then return nil end
    if not qualityByHex then
      qualityByHex = {}
      if type(ITEM_QUALITY_COLORS) == "table" then
        for q = 0, 8 do
          local c = ITEM_QUALITY_COLORS[q]
          if c and c.hex then qualityByHex[c.hex:sub(-6)] = q end
        end
      end
    end
    return qualityByHex[hex]
  end,

  QualityLabel = function(q)
    q = q or 0
    return _G["ITEM_QUALITY" .. q .. "_DESC"] or QUALITY_LABEL_EN[q] or tostring(q)
  end,

  LoadItem = function(id, cb)
    if not (id and C_Item and C_Item.RequestLoadItemDataByID) then return end
    C_Item.RequestLoadItemDataByID(id)
    if cb and C_Timer and C_Timer.After then C_Timer.After(0.4, cb) end
  end,
}
