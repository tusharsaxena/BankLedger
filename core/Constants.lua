local addonName, NS = ...   -- luacheck: ignore addonName
NS.Constants = NS.Constants or {}
local C = NS.Constants

-- ── Storage enum ────────────────────────────────────────────────────────────────
-- Values are the stored string keys — STABLE. They are the CSV export contract, so never rename
-- one; adding a new store is additive and forward-compatible.
C.Store = {
  BAGS         = "BAGS",
  BANK         = "BANK",
  REAGENT_BANK = "REAGENT_BANK",
  WARBAND_BANK = "WARBAND_BANK",
  GUILD_BANK   = "GUILD_BANK",
  VOID_STORAGE = "VOID_STORAGE",
}

-- Display order for grouping, filters and the Insights breakdown (bags first, then the stores a
-- movement can target).
C.StoreOrder = {
  "BANK", "REAGENT_BANK", "WARBAND_BANK", "GUILD_BANK", "VOID_STORAGE", "BAGS",
}

C.StoreLabel = {
  BAGS         = "Bags",
  BANK         = "Character Bank",
  REAGENT_BANK = "Reagent Bank",
  WARBAND_BANK = "Warband Bank",
  GUILD_BANK   = "Guild Bank",
  VOID_STORAGE = "Void Storage",
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
-- CURRENCY is reserved for a later iteration — the enum is declared now so the export contract and
-- the stored `kind` field never have to change shape when it lands.
C.Kind = { ITEM = "ITEM", MONEY = "MONEY", CURRENCY = "CURRENCY" }
C.KindOrder = { "ITEM", "MONEY" }
C.KindLabel = { ITEM = "Item", MONEY = "Gold", CURRENCY = "Currency" }

-- ── Container id groups ─────────────────────────────────────────────────────────
-- Which numeric container ids belong to which store. Built from Enum.BagIndex where the client
-- exposes it and from the FrameXML constants otherwise, so a patch that renumbers a tab range is a
-- one-line change here and nowhere else. Ids the client doesn't know are simply absent — the
-- scanner skips them (Compat.GetContainerNumSlots returns 0).
local function bagIndex(name, fallback)
  local e = Enum and Enum.BagIndex
  local v = e and e[name]
  if type(v) == "number" then return v end
  return fallback
end

local function range(first, last)
  local out = {}
  if type(first) ~= "number" or type(last) ~= "number" then return out end
  for i = first, last do out[#out + 1] = i end
  return out
end

local function concatIDs(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, id in ipairs(list) do out[#out + 1] = id end
  end
  return out
end

-- Carried inventory: backpack + the four bag slots + the reagent bag.
C.BAG_IDS = concatIDs({ 0 }, range(1, 4), { bagIndex("ReagentBag", 5) })

-- Character bank: the classic bank container + its purchased bag slots, plus the modern
-- character-bank tab range where the client has it.
C.BANK_IDS = concatIDs(
  { bagIndex("Bank", -1) },
  range(bagIndex("BankBag_1", 6), bagIndex("BankBag_7", 12)),
  range(bagIndex("CharacterBankTab_1", 18), bagIndex("CharacterBankTab_6", 23))
)

-- Reagent bank is a single container id.
C.REAGENT_BANK_IDS = { bagIndex("Reagentbank", -3) }

-- Warband (account) bank tabs.
C.WARBAND_BANK_IDS = range(bagIndex("AccountBankTab_1", 13), bagIndex("AccountBankTab_5", 17))

-- Store → the container ids scanned for it. Guild bank and void storage have their own APIs and
-- are scanned through Compat rather than a container-id list, so they are absent here.
C.STORE_CONTAINERS = {
  BAGS         = C.BAG_IDS,
  BANK         = C.BANK_IDS,
  REAGENT_BANK = C.REAGENT_BANK_IDS,
  WARBAND_BANK = C.WARBAND_BANK_IDS,
}

-- ── Settings option lists ───────────────────────────────────────────────────────

-- Retention presets; 0 means "Always" (cleanup disabled).
C.RETENTION_OPTIONS = {
  { value = 7,   label = "7 days" },
  { value = 14,  label = "14 days" },
  { value = 30,  label = "30 days" },
  { value = 60,  label = "60 days" },
  { value = 90,  label = "90 days" },
  { value = 180, label = "180 days" },
  { value = 365, label = "365 days" },
  { value = 0,   label = "Always" },
}

-- Minimum-quality options for the item capture gate (WoW item-quality ids). Monotonic
-- "quality >= threshold". Only the quality name is quality-coloured; " and above" stays default.
-- rrggbb fallback for headless builds where ITEM_QUALITY_COLORS is absent (colour is cosmetic there).
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
    label = ("|cff%s%s|r and above"):format(qualityHex(q), NS.Compat.QualityLabel(q)),
  }
end

-- Per-store mute options for the settings panel, derived from the display order.
C.STORE_OPTIONS = {}
for _, s in ipairs(C.StoreOrder) do
  if s ~= "BAGS" then   -- BAGS is the counterparty of every movement, never a mutable target
    C.STORE_OPTIONS[#C.STORE_OPTIONS + 1] = { value = s, label = C.StoreLabel[s] }
  end
end

-- Vendored monospace font (JetBrains Mono, OFL) used by the debug console and the copy boxes. Path
-- is the in-game addon-relative form; the file lives at media/fonts/ in the repo. A sanctioned
-- styling exception — WoW ships no monospace font object (debug-logging-§2).
C.FONT_MONO = "Interface\\AddOns\\BankLedger\\media\\fonts\\JetBrainsMono-Regular.ttf"

-- Addon logo, shown on the settings landing page (options-ui-§5). WoW cannot load .jpg/.png at
-- runtime, so the shipped runtime asset is a .tga; a missing file simply renders nothing.
C.LOGO_PATH = "Interface\\AddOns\\BankLedger\\media\\logos\\bankledger.logo.tga"

-- Convenience aliases.
NS.Store = C.Store
NS.Direction = C.Direction
NS.Kind = C.Kind
