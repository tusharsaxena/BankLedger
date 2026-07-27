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

-- ── Class icon ──────────────────────────────────────────────────────────────────
-- Inline texture markup for a class's round icon, for prefixing a character name. The class icons
-- all live in one 256×256 sheet, so the markup carries the class's slice from CLASS_ICON_TCOORDS
-- (fractions of the sheet, converted to the pixel coordinates |T…|t wants). Markup rather than a
-- real Texture because — unlike the direction arrow — the icon is full-colour art that must NOT be
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

-- ── Secret-safe chat printer (events-frames-taint-§8) ────────────────────────────
-- In combat, retail protects combat-sensitive returns (unit absorb/health totals, threat, some aura
-- amounts) as "secret" values. A secret survives tostring() AND the `..` operator (which silently
-- propagates secretness), but RAISES the instant it reaches table.concat. Because every chat line
-- ends in a table.concat, an unguarded secret both spams a Lua error and — inside a repeating
-- ticker — can freeze the feature until /reload. Detection MUST probe the operation that actually
-- rejects a secret (table.concat), NOT `..`: a `..`-based probe reports a secret as safe.
local function probeConcat(v) return table.concat({ v }) end
function NS.IsConcatSafe(v)
  return (pcall(probeConcat, v))
end

-- Concat-safe stringifier used by every line the addon emits. Ordinary values → tostring(v); an
-- un-concatenable (secret) value → the sentinel "<secret>", so the surrounding table.concat can
-- never raise. nil and booleans are handled up front (table.concat rejects a boolean element too,
-- but booleans are never secret, so they must not be masked).
function NS.SafeToString(v)
  if v == nil then return "nil" end
  if type(v) == "boolean" then return tostring(v) end
  if NS.IsConcatSafe(v) then return tostring(v) end
  return "<secret>"
end

-- The single shared chat printer. Prepends the cyan NS.PREFIX tag (slash-commands-§4) and
-- space-joins each SafeToString'd arg, mirroring print(). Every file that emits chat does
-- `local print = NS.Print` so call sites stay `print("message")` — never the global print(), never
-- a hand-written tag, never raw `..`/tostring on an arg. The real name is NS.Util.print; NS.Print is
-- reclaimed from it after the AceConsole embed (core/BankLedger.lua, architecture-§2).
function NS.Print(...)
  local n = select("#", ...)
  local parts = { NS.PREFIX }
  for i = 1, n do parts[i + 1] = NS.SafeToString((select(i, ...))) end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
  end
end
Util.print = NS.Print
