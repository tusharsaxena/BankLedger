local addonName, NS = ...   -- luacheck: ignore addonName
NS.Constants = NS.Constants or {}
local C = NS.Constants

-- ── Storage enum ────────────────────────────────────────────────────────────────
-- Values are the stored string keys — STABLE. They are the CSV export contract, so never rename
-- one; adding a new store is additive and forward-compatible.
C.Store = {
  BAGS         = "BAGS",
  BANK         = "BANK",
  WARBAND_BANK = "WARBAND_BANK",
  GUILD_BANK   = "GUILD_BANK",
}

-- Display order for grouping, filters and the Insights breakdown (bags first, then the stores a
-- movement can target).
C.StoreOrder = {
  "BANK", "WARBAND_BANK", "GUILD_BANK", "BAGS",
}

C.StoreLabel = {
  BAGS         = "Bags",
  BANK         = "Character Bank",
  WARBAND_BANK = "Warband Bank",
  GUILD_BANK   = "Guild Bank",
}

-- ── Open-frame context enum ─────────────────────────────────────────────────────
-- Which storage FRAME is open. Deliberately NOT a C.Store value: the retail bank frame reaches the
-- character bank AND the warband tabs at once behind a single BANKFRAME_OPENED, and switching
-- between them fires nothing — which is the whole reason this is a separate axis. It
-- was previously expressed with C.Store values, whose comment promises they are the stored export
-- keys; BANK_FRAME never was one (F-012).
--
-- Runtime-only: never persisted, never exported. GUILD_BANK is the one token that is legitimately
-- both a frame and a store, and shares its value with C.Store.GUILD_BANK on purpose.
C.Context = {
  BANK_FRAME = "BANK_FRAME",
  GUILD_BANK = "GUILD_BANK",
}

-- ── Direction enum ──────────────────────────────────────────────────────────────
-- A ledger entry is always written from the CHARACTER's point of view: DEPOSIT = it left your bags
-- for the store, WITHDRAW = it came out of the store into your bags. Stored keys are stable.
C.Direction = { DEPOSIT = "DEPOSIT", WITHDRAW = "WITHDRAW" }
C.DirectionOrder = { "DEPOSIT", "WITHDRAW" }
C.DirectionLabel = { DEPOSIT = "Deposit", WITHDRAW = "Withdraw" }
-- Sign the direction applies to a magnitude when totalling a store's net flow.
C.DirectionSign = { DEPOSIT = 1, WITHDRAW = -1 }

-- ── Entry kind ──────────────────────────────────────────────────────────────────
-- ITEM rows carry an itemID + a stack count; MONEY rows carry a copper amount in `quantity`.
-- These two are the whole enum. Currencies are deliberately not captured and no member is reserved
-- for them — see Known limitations in docs/ARCHITECTURE.md.
C.Kind = { ITEM = "ITEM", MONEY = "MONEY" }
C.KindOrder = { "ITEM", "MONEY" }
C.KindLabel = { ITEM = "Item", MONEY = "Gold" }

-- ── Display palette ─────────────────────────────────────────────────────────────
-- Colors and glyphs shared by the History table and the filter dropdowns, so a store or a
-- direction looks the same everywhere it appears. Cosmetic only — never stored, never exported.

-- A deposit is money/goods going IN (green); a withdrawal comes OUT (red — the same ff5555 the
-- destructive row-menu action uses, so "leaving" reads consistently addon-wide).
C.DirectionRGB = {
  DEPOSIT  = { 0.35, 0.80, 0.45 },
  WITHDRAW = { 1.00, 0.33, 0.33 },
}

-- ▲ out of the store, ▼ into it. These are TEXT glyphs: WoW's default font has neither and renders
-- a box, so anything drawing them must use the vendored mono font below (see FONT_MONO).
C.DirectionGlyph = {
  WITHDRAW = "\226\150\178",   -- ▲ U+25B2
  DEPOSIT  = "\226\150\188",   -- ▼ U+25BC
}

-- The character bank keeps the addon's gold; the warband bank takes the heirloom cyan (it is
-- account-wide, as heirlooms are); the guild bank a magenta. Bags stay muted — they are the
-- counterparty of a movement, not its subject.
C.StoreRGB = {
  BANK         = { 1.00, 0.82, 0.00 },
  WARBAND_BANK = { 0.00, 0.80, 1.00 },
  GUILD_BANK   = { 0.93, 0.45, 0.88 },
  BAGS         = { 0.75, 0.75, 0.78 },
}

-- Fallback for any value the palettes above do not cover (a store from a newer build, say).
C.NEUTRAL_RGB = { 0.90, 0.90, 0.90 }

-- ── Container id groups ─────────────────────────────────────────────────────────
-- Which numeric container ids belong to which store, derived **by member name** from
-- Enum.BagIndex — never by hardcoded number.
--
-- This is not fussiness. Blizzard renumbers these between expansions, and a numeric guess for a
-- member the build doesn't expose lands on a completely unrelated container: an earlier version of
-- this file assumed `AccountBankTab_1 = 13` and `CharacterBankTab_1 = 18`, and on a live 12.0.7
-- client (where they are 12 and 6) that put warband tab 1 inside the *character bank* group and
-- listed ids 6–11 twice, double-counting every character-bank stack. Matching on the name means a
-- member that moves is followed automatically, and a member that does not exist contributes
-- nothing instead of colliding with its neighbor.
--
-- The patterns are anchored and case-sensitive on purpose. `Enum.BagIndex` also carries *type*
-- constants that look deceptively similar to container ids — on 12.0.7, `Characterbanktab = -2` and
-- `Accountbanktab = -3` sit alongside the real `CharacterBankTab_1..6` and `AccountBankTab_1..5`.
-- A loose match would scoop those up and scan a container that does not exist.
local GROUP_PATTERNS = {
  -- `ReagentBag` is the reagent BAG worn in the inventory's fifth slot — a live container, and not
  -- to be confused with the reagent BANK, which Midnight removed. Do not strip it.
  BAGS         = { "^Backpack$", "^Bag_%d+$", "^ReagentBag$" },
  -- `Bank` / `BankBag_N` are the pre-tab character bank; `CharacterBankTab_N` is the modern form.
  BANK         = { "^Bank$", "^BankBag_%d+$", "^CharacterBankTab_%d+$" },
  WARBAND_BANK = { "^AccountBankTab_%d+$" },
}

-- Every id whose Enum.BagIndex member name matches one of `patterns`, sorted and de-duplicated.
local function idsMatching(patterns)
  local seen, ids = {}, {}
  local members = Enum and Enum.BagIndex
  if type(members) == "table" then
    for name, value in pairs(members) do
      if type(value) == "number" then
        for _, pattern in ipairs(patterns) do
          if name:match(pattern) and not seen[value] then
            seen[value] = true
            ids[#ids + 1] = value
            break
          end
        end
      end
    end
  end
  table.sort(ids)
  return ids
end

C.BAG_IDS          = idsMatching(GROUP_PATTERNS.BAGS)
C.BANK_IDS         = idsMatching(GROUP_PATTERNS.BANK)
C.WARBAND_BANK_IDS = idsMatching(GROUP_PATTERNS.WARBAND_BANK)

-- The backpack is id 0 on every build and predates the enum, so guarantee it rather than depend on
-- `Backpack` being present. Without the bags side there is no movement to detect at all.
if #C.BAG_IDS == 0 then C.BAG_IDS = { 0, 1, 2, 3, 4, 5 } end

-- Store → the container ids scanned for it. The guild bank has its own API family and is scanned
-- through Compat rather than a container-id list, so it is absent here.
C.STORE_CONTAINERS = {
  BAGS         = C.BAG_IDS,
  BANK         = C.BANK_IDS,
  WARBAND_BANK = C.WARBAND_BANK_IDS,
}

-- ── Settings option lists ───────────────────────────────────────────────────────

-- Retention presets; 0 means "Always" (cleanup disabled).
C.RETENTION_OPTIONS = {
  { value = 7,   text  = "7 days" },
  { value = 14,  text  = "14 days" },
  { value = 30,  text  = "30 days" },
  { value = 60,  text  = "60 days" },
  { value = 90,  text  = "90 days" },
  { value = 180, text  = "180 days" },
  { value = 365, text  = "365 days" },
  { value = 0,   text  = "Always" },
}

-- Minimum-quality options for the item capture gate (WoW item-quality ids). Monotonic
-- "quality >= threshold". Only the quality name is quality-colored; " and above" stays default.
-- rrggbb fallback for headless builds where ITEM_QUALITY_COLORS is absent (color is cosmetic there).
local QUALITY_HEX_FALLBACK = {
  [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000",
}
local function qualityHex(q)
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c and c.hex then return c.hex:sub(-6) end
  return QUALITY_HEX_FALLBACK[q]
end
C.QUALITY_OPTIONS = {}
for _, q in ipairs({ 0, 1, 2, 3, 4, 5 }) do
  C.QUALITY_OPTIONS[#C.QUALITY_OPTIONS + 1] = {
    value = q,
    text  = ("|cff%s%s|r and above"):format(qualityHex(q), NS.Compat.QualityLabel(q)),
  }
end

-- Per-store mute options for the settings panel, derived from the display order.
C.STORE_OPTIONS = {}
for _, s in ipairs(C.StoreOrder) do
  if s ~= "BAGS" then   -- BAGS is the counterparty of every movement, never a mutable target
    C.STORE_OPTIONS[#C.STORE_OPTIONS + 1] = { value = s, text  = C.StoreLabel[s] }
  end
end

-- Vendored monospace font (JetBrains Mono, OFL) used by the debug console and the copy boxes. Path
-- is the in-game addon-relative form; the file lives at media/fonts/ in the repo. A sanctioned
-- styling exception — WoW ships no monospace font object (debug-logging-§2).
C.FONT_MONO = "Interface\\AddOns\\BankLedger\\media\\fonts\\JetBrainsMono-Regular.ttf"

-- Addon logo, shown on the settings landing page at 300px (options-ui-§5). WoW cannot load
-- .jpg/.png at runtime, so the shipped runtime asset is a 512×512 24-bit RLE .tga — a power of two,
-- because the client rescales anything else and the master art is 1254×1254. A missing file renders
-- nothing and raises no error, which is exactly how this shipped blank for a while, so treat the
-- .tga as required rather than optional. See docs/ARCHITECTURE.md ▸ Logo art.
C.LOGO_PATH = "Interface\\AddOns\\BankLedger\\media\\logos\\bankledger.logo.tga"

-- Convenience aliases.
NS.Store = C.Store
NS.Direction = C.Direction
NS.Kind = C.Kind
