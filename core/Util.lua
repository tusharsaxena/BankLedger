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

-- ── Pooled-row tint ─────────────────────────────────────────────────────────────
--
-- The zebra band behind every second row and the gold wash under the cursor, for BOTH pooled
-- tables (modules/LedgerTable.lua and modules/SessionWindow.lua). Both were hardcoded in both
-- files — `1,1,1,0.03` and `1,0.82,0,0.10` — and both are now settings, so the read lives here
-- once rather than being spelled out four times.
--
-- CLAMPED, not trusted. These come out of SavedVariables, which a player can hand-edit and another
-- addon can write: an alpha of 5 or of -1 is not an error the client reports, it is a table drawn
-- opaque white or with the band silently missing, which reads as the slider not working. Anything
-- that is not a number falls back to the shipped default rather than to zero, so a corrupt key
-- degrades to the stock look instead of to no look at all.
function Util.RowTintAlpha(key, fallback)
  local g = NS.db and NS.db.global and NS.db.global.settings
  local v = g and g[key]
  if type(v) ~= "number" then return fallback end
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

--- Paint one pooled row's stripe and hover textures from the current settings, and show or hide
--- the stripe. Called from BuildRow (so a row is correct the moment it exists) and from BindRow
--- (so a row recycled onto a different index, or drawn after the slider moved, re-reads).
function Util.ApplyRowTint(row, striped)
  if not row then return end
  if row.stripe then
    row.stripe:SetColorTexture(1, 1, 1, Util.RowTintAlpha("rowStripeAlpha", 0.03))
    if striped ~= nil then row.stripe:SetShown(striped and true or false) end
  end
  if row.rowHover then
    row.rowHover:SetColorTexture(1, 0.82, 0, Util.RowTintAlpha("rowHoverAlpha", 0.10))
  end
end

--- Repaint both tables after a tint slider moved. Direct calls rather than a bus message alone,
--- for the reason settings.windowScale's onChange gives: the direct call repaints the window the
--- player is looking at with no latency. The broadcast goes out beside it so anything added later
--- hears about it without this function growing a third line.
function Util.RefreshRowTint()
  if NS.LedgerTable and NS.LedgerTable.Bind then NS.LedgerTable:Bind() end
  if NS.SessionWindow and NS.SessionWindow.Bind then NS.SessionWindow:Bind() end
  if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "rowTint") end
end

-- ── Master controls: the addon-wide chrome (options-ui-§15) ─────────────────────
--
-- Three settings the Master controls tab added, honored HERE rather than four times over: this
-- addon draws three movable frames (the ledger window, the session window and the export dialog)
-- and every one of them wants the same three answers. A per-window copy of these reads was the
-- shape the row-tint pair was in before it was promoted, and it drifted.

--- One window's masterable settings, read fresh and defaulted where the store is empty.
local function masterChrome()
  local g = (NS.db and NS.db.global and NS.db.global.settings) or {}
  local scale = tonumber(g.windowScale) or 1.0
  local alpha = tonumber(g.alpha)
  if type(alpha) ~= "number" then alpha = 1.0 end
  -- Clamped for the same reason RowTintAlpha is: these arrive from SavedVariables, and an alpha of
  -- 5 is not an error the client reports — it is a window that never fades and reads as a broken
  -- slider, while a 0 stored by accident would be an invisible addon with no way back to the panel.
  -- The floor is NS.Constants.MASTER_ALPHA_MIN, which is also the Master alpha row's declared
  -- minimum, so the slider cannot offer a stop this refuses to draw.
  local floor = NS.Constants.MASTER_ALPHA_MIN
  if alpha < floor then alpha = floor elseif alpha > 1 then alpha = 1 end
  return scale, alpha, g.locked and true or false
end

--- Apply master scale, master alpha and Lock frame to ONE frame. Called at frame construction and
--- again whenever one of the three changes, so a window built after a change is not the odd one out.
function Util.ApplyMasterFrame(frame)
  if not frame then return end
  local scale, alpha, locked = masterChrome()
  if frame.SetScale then frame:SetScale(scale) end
  if frame.SetAlpha then frame:SetAlpha(alpha) end
  -- The drag handlers all call StartMoving, which the client makes a no-op on an unmovable frame —
  -- so this is the whole of "Lock frame" and there is no second guard to keep in step.
  if frame.SetMovable then frame:SetMovable(not locked) end
end

--- Re-apply the master chrome to every window this addon owns. The write seam's onChange for
--- `settings.alpha` and `settings.locked`.
function Util.ApplyMasterChrome()
  for _, owner in ipairs({ NS.Browser, NS.SessionWindow, NS.Export }) do
    local frame = owner and owner.GetWindow and owner:GetWindow()
    if frame then Util.ApplyMasterFrame(frame) end
  end
end

--- Is this addon's display allowed on screen right now (`settings.visibility`)?
---
--- A dropdown and not a boolean, because a boolean can only ever answer two of the four. An
--- UNKNOWN stored string answers TRUE: a value nobody recognises is a reason to show the addon and
--- let the player fix it, never a reason to hide every window with no way back.
function Util.VisibilityAllows()
  local g = (NS.db and NS.db.global and NS.db.global.settings) or {}
  local mode = g.visibility or "always"
  if mode == "never" then return false end
  if mode == "always" then return true end
  local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
  if mode == "inCombat" then return inCombat end
  if mode == "outOfCombat" then return not inCombat end
  return true
end

--- Re-evaluate visibility across every window, on a settings change and on each combat transition.
---
--- A window hidden by this rule is REMEMBERED, so the transition back re-shows exactly the windows
--- the rule took and never one the player had closed themselves.
function Util.ApplyVisibility()
  local allowed = Util.VisibilityAllows()
  local hidden = NS.State.hiddenByVisibility
  for key, owner in pairs({ Browser = NS.Browser, SessionWindow = NS.SessionWindow }) do
    local frame = owner and owner.GetWindow and owner:GetWindow()
    if not allowed then
      -- Only a window that is actually up is remembered, so the transition back cannot open one
      -- the player never had open.
      if frame and frame:IsShown() then hidden[key] = true; owner:Hide() end
    elseif hidden[key] then
      hidden[key] = nil
      owner:Show()
    end
  end
end

--- Re-centre both persistent windows at their default size. The Master controls tab's "Reset
--- position" button and the General page's Defaults button share this one body — the button was
--- previously only ever reachable as a side effect of the second.
function Util.ResetWindowPositions()
  if NS.Browser and NS.Browser.ResetWindow then NS.Browser:ResetWindow() end
  if NS.SessionWindow and NS.SessionWindow.ResetWindow then NS.SessionWindow:ResetWindow() end
end

-- ── Secret-safe chat printer ────────────────────────────────────────────────────
-- Moved to core/CoreSetup.lua, which builds it from LibKa0s-Core-1.0 (library-stack). The guard
-- (NS.IsConcatSafe), the stringifier (NS.SafeToString) and the printer (NS.Print / NS.Util.print)
-- all still answer under exactly those names — every `local print = NS.Print` call site in the addon
-- is unchanged, and so is every rendered byte. The seam loads BEFORE this file, so nothing here has
-- to care which implementation is behind them.
