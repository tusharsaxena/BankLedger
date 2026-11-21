local _, NS = ...
NS.Util = NS.Util or {}
local Util = NS.Util

-- The one record-key builder (WoW Forever port, "Identity"; BL-03): the key a row's `char` stores
-- for a character whose name and realm are the two parts Compat.PlayerName answers. `Name-Realm`
-- when there is a realm (Retail, unchanged); the name alone when there is none, which is the whole
-- "First Surname" on WoW Forever (regional names). modules/SimWorld.lua keys its characters with
-- it too, so the simulator's world and the rows it records always agree.
function Util.RecordKey(name, realm)
  if realm == nil then return name end
  return name .. "-" .. realm
end

-- The current player's record key: "Name-Realm" on Retail (realm normalized, spaces stripped),
-- "First Surname" on WoW Forever. The reads live in Compat.PlayerName, so a simulator can answer them.
function Util.PlayerKey()
  return Util.RecordKey(NS.Compat.PlayerName())
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

-- Format a copper amount for display, with the gold/silver/copper coin glyphs in game. "" for nil/0.
-- The order is the same on Retail and WoW Forever (R8): C_CurrencyInfo.GetCoinTextureString, the
-- documented API on both clients (it takes the glyph height); then GetMoneyString, the SharedXML
-- helper both clients ship (Forever has no bare GetCoinTextureString global); then "Ng Ns Nc" text
-- with only the non-zero parts, which is also what the headless suite sees.
function Util.FormatMoney(copper, coinHeight)
  copper = copper or 0
  if copper <= 0 then return "" end
  local currency = C_CurrencyInfo
  if currency and currency.GetCoinTextureString then
    if coinHeight then return currency.GetCoinTextureString(copper, coinHeight) end
    return currency.GetCoinTextureString(copper)
  end
  if GetMoneyString then
    return GetMoneyString(copper)
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
-- the URL carries them — https://www.wowhead.com/item=151300?bonus=12801:13440:6652 on Retail.
--
-- The bonuses come out of the stored hyperlink's item string through LibKa0s-Item's
-- BonusIDsFromLink (Item minor 3, LibKa0s#51), which owns the positional walk: field 13 declares
-- how many of the fields after it are bonus IDs, and whatever follows them (crafting modifiers) is
-- a different list and is not read. A bare item string works as well as a full hyperlink.
--
-- Returns "" for a row with no item at all (a gold movement, or an entry whose link never
-- resolved), and a plain item= URL when the link carries no bonuses — which is the honest answer
-- for a stackable trade good, since those have none.
--
-- The base is per client, picked ONCE at load by ClientKey() (WoW Forever port, owner ruling R7;
-- clients-§5): WoW Forever item ids are Forever's own, so its links go to Wowhead's forever path.
-- Retail is unchanged. Both rows are exposed read-only for tests/test_wowhead_client.lua.
Util.WOWHEAD_ITEM_URL_BY_CLIENT = {
  retail  = "https://www.wowhead.com/item=",
  forever = "https://www.wowhead.com/forever/item=",
}
local WOWHEAD_ITEM_URL = Util.WOWHEAD_ITEM_URL_BY_CLIENT[(NS.Compat and NS.Compat.ClientKey
  and NS.Compat.ClientKey()) or "retail"] or Util.WOWHEAD_ITEM_URL_BY_CLIENT.retail
Util.WOWHEAD_ITEM_URL = WOWHEAD_ITEM_URL

function Util.WowheadURL(entry)
  if type(entry) ~= "table" then return "" end
  local link = type(entry.itemLink) == "string" and entry.itemLink or nil

  -- The link's own id wins over the stored one: they agree, but the link is what the bonuses
  -- belong to.
  local itemID = NS.Item.ItemIDFromLink(link) or tonumber(entry.itemID)
  if not itemID then return "" end

  local bonuses = NS.Item.BonusIDsFromLink(link) or {}
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
  local g = NS.db and NS.db.profile and NS.db.profile.settings
  local v = g and g[key]
  if type(v) ~= "number" then return fallback end
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

-- The two tints: the skin's list.stripe and list.hover (core/SkinSetup.lua's NS.Skin), resolved
-- into these reused tables once per skin rather than per bind -- ApplyRowTint runs on every row of
-- every repaint. The RGB is always the skin's. The ALPHA is the skin's too while the setting's
-- companion is on, the default (SD-SK-BL.1, the owner's R-2 of 2026-11-20, which superseded the
-- rollout's D2 slider-only alpha), and the player's slider while it is off. Filled lazily on the
-- first tint (this file loads before the skin seam) and again by Util.ReskinRowTint on every skin
-- switch (modules/LedgerTable.lua's OnLooksChanged listener).
local STRIPE_RGB, HOVER_RGB = {}, {}
local tintResolved = false

-- Each slider's key -> the tint it sets the alpha of.
local TINT = { rowStripeAlpha = STRIPE_RGB, rowHoverAlpha = HOVER_RGB }

local function resolveTint(t, name)
  local r, g, b, a = NS.Skin.Color(name)
  t[1], t[2], t[3] = r or 1, g or 1, b or 1
  t[4] = type(a) == "number" and a or nil
end

--- Re-read the two tints' RGB from the live skin. Safe before the seam exists (no-op).
function Util.ReskinRowTint()
  if not (NS.Skin and NS.Skin.Color) then return end
  resolveTint(STRIPE_RGB, "list.stripe")
  resolveTint(HOVER_RGB, "list.hover")
  tintResolved = true
end

--- The skin's alpha for one tint slider's key ("rowStripeAlpha", "rowHoverAlpha"), or nil before the
--- seam exists or for a skin that states none. What the slider shows while its companion is on.
function Util.SkinRowTintAlpha(key)
  local t = TINT[key]
  if not t then return nil end
  if not tintResolved then Util.ReskinRowTint() end
  return t[4]
end

--- The skin's alpha while `<key>FromSkin` is on (absent reads as on, the default), nil while it is
--- off. The slider's `skinValue`: what it shows, disabled, while it follows the skin.
function Util.FollowedRowTintAlpha(key)
  local g = NS.db and NS.db.profile and NS.db.profile.settings
  if g and g[key .. "FromSkin"] == false then return nil end
  return Util.SkinRowTintAlpha(key)
end

--- The alpha one tint draws: the skin's while it follows, else the clamped slider. A skin that
--- states no alpha falls back to the slider.
function Util.RowAlpha(key, fallback)
  local a = Util.FollowedRowTintAlpha(key)
  if a ~= nil then return a end
  return Util.RowTintAlpha(key, fallback)
end

--- Paint one pooled row's stripe and hover textures from the current settings, and show or hide
--- the stripe. Called from BuildRow (so a row is correct the moment it exists) and from BindRow
--- (so a row recycled onto a different index, or drawn after the slider moved, re-reads).
function Util.ApplyRowTint(row, striped)
  if not row then return end
  if not tintResolved then Util.ReskinRowTint() end
  if row.stripe then
    row.stripe:SetColorTexture(STRIPE_RGB[1], STRIPE_RGB[2], STRIPE_RGB[3],
      Util.RowAlpha("rowStripeAlpha", 0.08))
    if striped ~= nil then row.stripe:SetShown(striped and true or false) end
  end
  if row.rowHover then
    row.rowHover:SetColorTexture(HOVER_RGB[1], HOVER_RGB[2], HOVER_RGB[3],
      Util.RowAlpha("rowHoverAlpha", 0.16))
  end
end

--- Repaint both tables after a tint slider moved. Direct calls rather than a bus message alone,
--- for the reason settings.windowScale's onChange gives: the direct call repaints the window the
--- player is looking at with no latency. The broadcast goes out beside it so anything added later
--- hears about it without this function growing a third line.
function Util.RefreshRowTint()
  if NS.LedgerTable and NS.LedgerTable.Bind then NS.LedgerTable:Bind() end
  if NS.SessionWindow and NS.SessionWindow.Bind then NS.SessionWindow:Bind() end
  if NS.bus then NS.bus:SendMessage(NS.MSG.SETTINGS_CHANGED, "rowTint") end
end

-- ── Master controls: the addon-wide chrome (options-ui-§15) ─────────────────────
--
-- Three settings the Master controls tab added, honored HERE rather than four times over: this
-- addon draws three movable frames (the ledger window, the session window and the export dialog)
-- and every one of them wants the same three answers. A per-window copy of these reads was the
-- shape the row-tint pair was in before it was promoted, and it drifted.

--- One window's masterable settings, read fresh and defaulted where the store is empty.
local function masterChrome()
  local g = (NS.db and NS.db.profile and NS.db.profile.settings) or {}
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
  -- A window whose header carries a lock mark (the ledger window, AF-HDR-BL) repaints it here, so the
  -- mark follows the lock by every route: the mark itself, the verbs, the checkbox, a profile switch.
  local paintLock = type(frame) == "table" and rawget(frame, "paintLockMark") or nil
  if type(paintLock) == "function" then paintLock(locked) end
end

-- The NS keys of the window owners each pass walks. Module-level NAME lists, resolved against NS at
-- call time (an owner module may not have loaded yet when this file runs), so neither pass builds a
-- table on each call: ApplyVisibility runs on every combat edge. Order is fixed: Browser first.
local CHROME_OWNERS = { "Browser", "SessionWindow", "Export" }
local VISIBILITY_OWNERS = { "Browser", "SessionWindow" }

--- Re-apply the master chrome to every window this addon owns. The write seam's onChange for
--- `settings.alpha` and `settings.locked`.
function Util.ApplyMasterChrome()
  for _, key in ipairs(CHROME_OWNERS) do
    local owner = NS[key]
    local frame = owner and owner.GetWindow and owner:GetWindow()
    if frame then Util.ApplyMasterFrame(frame) end
  end
end

--- Is this addon's display allowed on screen right now (`settings.visibility`)?
---
--- A dropdown and not a boolean, because a boolean can only ever answer two of the four. An
--- UNKNOWN stored string answers TRUE: a value nobody recognizes is a reason to show the addon and
--- let the player fix it, never a reason to hide every window with no way back.
function Util.VisibilityAllows()
  -- THE STAND-DOWN'S FIRST RUNG (slash-commands-§7). Held shut AT THE SOURCE rather than by
  -- imperatively hiding the frames and hoping: a hidden frame comes back on a combat transition, a
  -- target swap or a settings change, and the addon would then be visibly running while it claims
  -- to be off. Every Show in this addon consults this one function, so this is the whole ladder.
  --
  -- IsStoodDown, not "is the player's switch off": a perf-suspended addon draws nothing either,
  -- and the show ladder is about whether the addon is RUNNING rather than about why it is not.
  if NS.IsStoodDown and NS.IsStoodDown() then return false end
  local g = (NS.db and NS.db.profile and NS.db.profile.settings) or {}
  local mode = g.visibility or "always"
  if mode == "never" then return false end
  if mode == "always" then return true end
  local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
  if mode == "inCombat" then return inCombat end
  if mode == "outOfCombat" then return not inCombat end
  return true
end

--- Which guard VisibilityAllows answered no by, for a refusal's trace line (debug-logging-§8: the
--- line names the guard): `stood down`, or `visibility <mode>`. nil when the display is allowed.
function Util.VisibilityRefusal()
  if Util.VisibilityAllows() then return nil end
  if NS.IsStoodDown and NS.IsStoodDown() then return "stood down" end
  local g = (NS.db and NS.db.profile and NS.db.profile.settings) or {}
  return "visibility " .. tostring(g.visibility or "always")
end

--- Re-evaluate visibility across every window, on a settings change and on each combat transition.
---
--- A window hidden by this rule is REMEMBERED, so the transition back re-shows exactly the windows
--- the rule took and never one the player had closed themselves.
---
--- Answers how many windows the pass hid and how many it re-showed, for the combat edge's
--- `[Combat]` line (core/BankLedger.lua). Counting costs two integers, so it is not gated.
function Util.ApplyVisibility()
  local allowed = Util.VisibilityAllows()
  local hidden = NS.State.hiddenByVisibility
  local hid, shown = 0, 0
  for _, key in ipairs(VISIBILITY_OWNERS) do
    local owner = NS[key]
    local frame = owner and owner.GetWindow and owner:GetWindow()
    if not allowed then
      -- Only a window that is actually up is remembered, so the transition back cannot open one
      -- the player never had open.
      if frame and frame:IsShown() then hidden[key] = true; owner:Hide(); hid = hid + 1 end
    elseif hidden[key] then
      hidden[key] = nil
      owner:Show()
      shown = shown + 1
    end
  end
  return hid, shown
end

--- Re-center both persistent windows at their default size. The Master controls tab's "Reset
--- position" button and the General page's Defaults button share this one body — the button was
--- previously only ever reachable as a side effect of the second.
function Util.ResetWindowPositions()
  if NS.Browser and NS.Browser.ResetWindow then NS.Browser:ResetWindow() end
  if NS.SessionWindow and NS.SessionWindow.ResetWindow then NS.SessionWindow:ResetWindow() end
end

-- ── Tooltip placement (AD-92-BL, LibKa0s#92) ───────────────────────────────────────
-- Every tooltip this addon places itself goes through these three (standalone-windows, *Tooltip
-- placement*; the classification per surface is docs/ARCHITECTURE.md's ## Tooltip placement):
-- owned at ANCHOR_NONE, filled and shown by the caller, then placed by LibKa0s-Tooltip-1.0, read at
-- call time. A BODY element (a row, a column header, an Insights card, bar or swatch) opens beside
-- its window, right when it fits and otherwise left, top level with the element (PlaceBeside, which
-- also sets the comparison side for an item's Shift-compare). A CHROME element (a filter-bar button,
-- a mode strip) is attached above its control, centered (PlaceAttached). When nothing can be read,
-- or the library is absent, the tooltip is attached above the element by a relative point, as the
-- library's own sites do: never the cursor, never a corner.

local function tipLib()
  return LibStub and LibStub("LibKa0s-Tooltip-1.0", true) or nil
end

local function attachAbove(tip, el)
  local Tip = tipLib()
  local placed = Tip and Tip.PlaceAttached and Tip.PlaceAttached(tip, el)
  if placed then return placed end
  tip:ClearAllPoints()
  tip:SetPoint("BOTTOM", el, "TOP", 0, (Tip and Tip.TIP_GAP) or 2)
  return nil
end

--- Own `tip` (GameTooltip by default) for `el` at ANCHOR_NONE. Answers the tooltip, or nil when
--- there is none (the headless harness leaves GameTooltip nil).
function Util.TipOwn(el, tip)
  tip = tip or GameTooltip
  if not tip then return nil end
  local Tip = tipLib()
  if Tip and Tip.Own then Tip.Own(tip, el) else tip:SetOwner(el, "ANCHOR_NONE") end
  return tip
end

--- The body rule on a shown tooltip: beside `group` (the element's window; nil lets the library
--- find it). Answers where it went ("right", "left", "above", "below"), or nil when only the
--- relative fallback above the element could run.
function Util.TipBeside(tip, el, group)
  local Tip = tipLib()
  local side = Tip and Tip.PlaceBeside and Tip.PlaceBeside(tip, el, group)
  if side then return side end
  return attachAbove(tip, el)
end

--- The window group a body element's tooltip opens beside: the ledger window (nil before it is
--- built, and the library then finds the element's outermost frame itself). The History table and
--- every Insights widget sit in that window, so they share this one lookup.
function Util.TipWindowGroup()
  local B = NS.Browser
  return B and B.GetWindow and B:GetWindow() or nil
end

--- The chrome rule on a shown tooltip: centered above `el`, below only without room above.
--- Answers "above" or "below", or nil when only the relative fallback could run.
function Util.TipAttached(tip, el)
  return attachAbove(tip, el)
end

-- ── Secret-safe chat printer ────────────────────────────────────────────────────
-- Moved to core/CoreSetup.lua, which builds it from LibKa0s-Core-1.0 (library-stack). The guard
-- (NS.IsConcatSafe), the stringifier (NS.SafeToString) and the printer (NS.Print / NS.Util.print)
-- all still answer under exactly those names — every `local print = NS.Print` call site in the addon
-- is unchanged, and so is every rendered byte. The seam loads BEFORE this file, so nothing here has
-- to care which implementation is behind them.
