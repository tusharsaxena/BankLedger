local addonName, NS = ...   -- luacheck: ignore addonName
NS.Util = NS.Util or {}
local Util = NS.Util

-- "Name-Realm" of the current player (realm normalized, spaces stripped).
function Util.PlayerKey()
  local name = UnitName("player") or "Unknown"
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName())
    or (GetRealmName and GetRealmName()) or "Unknown"
  realm = tostring(realm):gsub("%s+", "")
  return name .. "-" .. realm
end

-- Split a dotted settings path ("settings.retentionDays") into components.
function Util.SplitPath(path)
  local parts = {}
  for p in tostring(path):gmatch("[^.]+") do
    parts[#parts + 1] = p
  end
  return parts
end

-- Clock-only (HH:MM) for the Time column.
function Util.FormatClock(ts)
  return date("%H:%M", ts or 0)
end

-- DD-MMM-YYYY (e.g. 11-Jul-2026) — unambiguous across locales (no US/EU MM/DD confusion).
function Util.FormatDate(ts)
  return date("%d-%b-%Y", ts or 0)
end

-- A date-range key → a `from` epoch timestamp (nil = no lower bound / "all"). "today" is the
-- current calendar day; "7d"/"30d" are rolling windows. Shared by the Browser date filter and the
-- Insights range selector so the two can't drift.
function Util.RangeFrom(range)
  local now = time()
  if range == "today" then
    local t = date("*t", now)
    return now - (t.hour * 3600 + t.min * 60 + t.sec)
  elseif range == "7d" then
    return now - 7 * 86400
  elseif range == "30d" then
    return now - 30 * 86400
  end
  return nil
end

-- Format a copper amount for display. In-game uses the gold/silver/copper coin glyphs
-- (GetCoinTextureString); headless falls back to "Ng Ns Nc" (only non-zero parts). "" for nil/0.
function Util.FormatMoney(copper, coinHeight)
  copper = copper or 0
  if copper <= 0 then return "" end
  if GetCoinTextureString then
    return GetCoinTextureString(copper, coinHeight)
  end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. "g" end
  if s > 0 then parts[#parts + 1] = s .. "s" end
  if c > 0 then parts[#parts + 1] = c .. "c" end
  return table.concat(parts, " ")
end

-- Plain-text money, always "Ng Ns Nc" and never the in-game coin markup. The CSV export and any
-- copy-to-clipboard surface use this so a pasted number stays readable outside the client.
function Util.PlainMoney(copper)
  if copper == nil then return "" end
  copper = tonumber(copper) or 0
  return string.format("%dg %ds %dc",
    math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100)
end

-- ── Effective item type ─────────────────────────────────────────────────────────
-- A gold movement has no itemType/itemSubType stored — its type IS that it is gold. These two
-- resolve an entry to the type the table SHOWS, so the Type/Sub-type column, the filter dropdowns,
-- the query and the grouping all read one definition and can never disagree about what "Gold"
-- means. No real item type or sub-type is called "Gold", so the label cannot collide with one.
function Util.EntryType(entry)
  if entry == nil then return "" end
  if entry.kind == "MONEY" then return NS.Constants.KindLabel.MONEY end
  return entry.itemType or ""
end

function Util.EntrySubType(entry)
  if entry == nil then return "" end
  if entry.kind == "MONEY" then return NS.Constants.KindLabel.MONEY end
  return entry.itemSubType or ""
end

-- ── Wowhead link ────────────────────────────────────────────────────────────────
-- A wowhead URL for the exact item variant a row moved rather than for its base item: everything
-- that makes a modern drop what it is (item level, tertiaries, sockets) lives in its bonus IDs, so
-- the URL carries them — https://www.wowhead.com/item=151300?bonus=12801:13440:6652.
--
-- The bonuses come out of the stored hyperlink's item string, which is positional:
--   item:id:ench:g1:g2:g3:g4:suffix:unique:level:spec:mask:context:numBonusIDs:bonus1..N:…
-- Field 13 declares how many of the fields after it are bonus IDs; whatever follows them (crafting
-- modifiers) is a different list and is not read here.
--
-- Returns "" for a row with no item at all (a gold movement, or an entry whose link never
-- resolved), and a plain item= URL when the link carries no bonuses — which is the honest answer
-- for a stackable trade good, since those have none.
local WOWHEAD_ITEM_URL = "https://www.wowhead.com/item="

-- Split an item string into its positional fields, keeping the empty ones: the whole scheme is
-- positional, so "item:2589::::" must come back as five fields, not one.
local function itemStringFields(s)
  local fields = {}
  for f in (s .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = f end
  return fields
end

function Util.WowheadURL(entry)
  if type(entry) ~= "table" then return "" end
  local link = type(entry.itemLink) == "string" and entry.itemLink or nil
  local itemString = link and (link:match("|Hitem:([^|]+)") or link:match("^item:([^|]+)"))
  local fields = itemString and itemStringFields(itemString) or {}

  -- The link's own id wins over the stored one: they agree, but the link is what the bonuses
  -- belong to.
  local itemID = tonumber(fields[1]) or tonumber(entry.itemID)
  if not itemID then return "" end

  local bonuses = {}
  for i = 14, 13 + (tonumber(fields[13]) or 0) do
    local id = tonumber(fields[i])
    if id then bonuses[#bonuses + 1] = id end
  end
  if #bonuses == 0 then return WOWHEAD_ITEM_URL .. itemID end
  return WOWHEAD_ITEM_URL .. itemID .. "?bonus=" .. table.concat(bonuses, ":")
end

-- ── Class icon ──────────────────────────────────────────────────────────────────
-- Inline texture markup for a class's round icon, for prefixing a character name. The class icons
-- all live in one 256×256 sheet, so the markup carries the class's slice from CLASS_ICON_TCOORDS
-- (fractions of the sheet, converted to the pixel coordinates |T…|t wants). Markup rather than a
-- real Texture because — unlike the direction arrow — the icon is full-color art that must NOT be
-- tinted with the surrounding text, and this way any FontString can carry one.
-- Returns "" for an unknown class or a build without the table (headless), so callers can always
-- concatenate the result unconditionally.
local CLASS_ICON_SHEET = "Interface\\TargetingFrame\\UI-Classes-Circles"
function Util.ClassIconMarkup(classFile, size)
  local t = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
  if type(t) ~= "table" then return "" end
  size = size or 12
  local function px(v) return math.floor((tonumber(v) or 0) * 256 + 0.5) end
  return ("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t "):format(
    CLASS_ICON_SHEET, size, size, px(t[1]), px(t[2]), px(t[3]), px(t[4]))
end

-- Human-readable byte size: "820 B", "12.4 kB", "3.1 MB". Uses 1024 steps.
function Util.FormatBytes(bytes)
  bytes = bytes or 0
  if bytes < 1024 then
    return string.format("%d B", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f kB", bytes / 1024)
  else
    return string.format("%.1f MB", bytes / (1024 * 1024))
  end
end

-- ── Secret-safe chat printer ────────────────────────────────────────────────────
-- Moved to core/CoreSetup.lua, which builds it from LibKa0s-Core-1.0 (library-stack). The guard
-- (NS.IsConcatSafe), the stringifier (NS.SafeToString) and the printer (NS.Print / NS.Util.print)
-- all still answer under exactly those names — every `local print = NS.Print` call site in the addon
-- is unchanged, and so is every rendered byte. The seam loads BEFORE this file, so nothing here has
-- to care which implementation is behind them.
