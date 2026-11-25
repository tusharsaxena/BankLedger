local addonName, NS = ...
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

-- ── Per-client features (clients-§4; WoW Forever port design, ruling R1) ─────────────────────
-- The Retail-only features, each declared with the clients it serves and its ForClient answer read
-- once at load (core/CompatClient.lua loads first). `warbandBank`: the Warband Bank store. WoW
-- Forever ships the account-bank API with the feature locked, and the standard names the warband
-- bank as one a Forever player never sees (clients.md), so there it is ABSENT, never hidden: no
-- store in the order, label, mute grid, container groups, bank-frame reach or coin stores, no
-- capture copy naming it, no test-mode or preview row and no simulator scenario or step. The C.Store
-- member and its C.StoreRGB swatch stay on both clients: the member is the stored key, and neither
-- is a surface. tests/test_warband_client.lua checks each gate on both kit profiles.
C.FEATURE_CLIENTS = {
  warbandBank = { "retail" },
  -- The vendor buy price on a row's item tooltip, read from the optional ForeverDB (clients-§11).
  vendorBuyPrice = { "forever" },
}
C.FEATURE = {}
for name, clients in pairs(C.FEATURE_CLIENTS) do C.FEATURE[name] = NS.Compat.ForClient(clients) end
local WARBAND = C.FEATURE.warbandBank

-- Display order for grouping, filters and the Insights breakdown (bags first, then the stores a
-- movement can target). Per client: the Warband Bank is Retail's alone (C.FEATURE above).
C.StoreOrder = WARBAND and {
  "BANK", "WARBAND_BANK", "GUILD_BANK", "BAGS",
} or {
  "BANK", "GUILD_BANK", "BAGS",
}

C.StoreLabel = {
  BAGS         = "Bags",
  BANK         = "Character Bank",
  WARBAND_BANK = WARBAND and "Warband Bank" or nil,
  GUILD_BANK   = "Guild Bank",
}

-- The banks that hold coin, as the capture copy names them (the Record gold tooltip, the Insights
-- gold cards): the character bank has no coin slot on either client.
C.COIN_BANKS_TEXT = WARBAND and "the guild and warband banks" or "the guild bank"

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
-- Sign the direction applies to a magnitude when totaling a store's net flow.
C.DirectionSign = { DEPOSIT = 1, WITHDRAW = -1 }

-- ── Entry kind ──────────────────────────────────────────────────────────────────
-- ITEM rows carry an itemID + a stack count; MONEY rows carry a copper amount in `quantity`.
-- These two are the whole enum. Currencies are deliberately not captured and no member is reserved
-- for them — see Known limitations in docs/ARCHITECTURE.md.
C.Kind = { ITEM = "ITEM", MONEY = "MONEY" }
C.KindLabel = { ITEM = "Item", MONEY = "Gold" }

-- ── Display palette ─────────────────────────────────────────────────────────────
-- Colors and glyphs shared by the History table and the filter dropdowns, so a store or a
-- direction looks the same everywhere it appears. Cosmetic only — never stored, never exported.

-- A deposit is money/goods going IN (green); a withdrawal comes OUT (red, the skin's danger hue's
-- neighbor, so "leaving" reads consistently addon-wide). Each is a token of the player's skin
-- (core/SkinSetup.lua's NS.Skin): sem.good and sem.bad, the values these two drew before the skin
-- engine under Ka0s Default. The History table caches them per skin (modules/LedgerTable.lua);
-- everything else reads C.DirectionColor at call time.
C.DirectionToken = {
  DEPOSIT  = "sem.good",
  WITHDRAW = "sem.bad",
}

--- A direction's color as a fresh { r, g, b } from the live skin; nil for a direction it does not
--- know. Read at call time, so a skin switch reaches the next caller.
function C.DirectionColor(key)
  local token = C.DirectionToken[key]
  return token and NS.SkinRGB and NS.SkinRGB(token) or nil
end

-- ▲ out of the store, ▼ into it. These are TEXT glyphs: WoW's default font has neither and renders
-- a box, and neither do most skin faces, so anything drawing them must use the LibKa0s mono face
-- below (see FONT_MONO). The `glyph: mono` markers tell the kit's display-glyph guard
-- (tests/test_glyphs.lua) so; every consumer pins the mono face (LedgerTable, SessionWindow, the
-- Direction dropdown's glyphFont).
C.DirectionGlyph = {
  WITHDRAW = "\226\150\178",   -- ▲ U+25B2  glyph: mono
  DEPOSIT  = "\226\150\188",   -- ▼ U+25BC  glyph: mono
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

-- A value the palettes above do not cover (a store from a newer build, say) takes the skin's body
-- color, text.body, at the site that draws it.

-- ── Container id groups ─────────────────────────────────────────────────────────
-- Which numeric container ids belong to which store. LibKa0s-Compat-1.0's ContainerGroups answers
-- them (LibKa0s#101, routed by core/Compat.lua); this addon carried its own copy until the library
-- took the one copy three addons shared. Read ONCE here, at load.
--
-- The ids come **by member name** from Enum.BagIndex, never by hardcoded number. Blizzard renumbers
-- them between expansions, and a numeric guess lands on an unrelated container: an earlier version
-- of this file assumed `AccountBankTab_1 = 13` and `CharacterBankTab_1 = 18`, and on a live 12.0.7
-- client (where they are 12 and 6) that put warband tab 1 inside the *character bank* group and
-- listed ids 6-11 twice, double-counting every character-bank stack. The library's patterns are
-- anchored and case-sensitive, because the enum also carries the *type* constants
-- `Characterbanktab = -2` and `Accountbanktab = -3` beside the real tabs.
--
-- Per client, by the library's declaration (clients-§5): `ReagentBag` is the reagent BAG worn in the
-- inventory's fifth slot, a live container on both clients (the reagent BANK is what Midnight
-- removed). WoW Forever's bags add the keyring (`Keyring`, -1: Blizzard's KEYRING_CONTAINER, ruling
-- R5), so a key the player owns counts as carried and a key taken from the keyring into the bank is
-- a deposit rather than a one-sided change. Retail's enum names -1 too, but it was the legacy bank
-- container before 11.2 and nothing has shown what it answers today, so Retail never scans it. The
-- account bank is declared on Retail only (R1). With no Enum.BagIndex, or one that names no bag, the
-- bags are 0..5 (the backpack is id 0 on every build and predates the enum): without the bags side
-- there is no movement to detect at all. tests/test_constants.lua and tests/test_keyring_client.lua.
local GROUPS = NS.Compat.ContainerGroups()

C.BAG_IDS          = GROUPS.bags
C.BANK_IDS         = GROUPS.bank
-- Empty on a client without the Warband Bank (C.FEATURE): WoW Forever's AccountBankTab_1..9 (15..23)
-- exist in the enum, but nothing there scans them. The library declares the same; the gate stays so
-- the store and its ids answer one declaration.
C.WARBAND_BANK_IDS = WARBAND and GROUPS.accountBank or {}

-- Store → the container ids scanned for it. The guild bank has its own API family and is scanned
-- through Compat rather than a container-id list, so it is absent here.
-- The Warband Bank has no row on a client without it (C.FEATURE). C.CONTAINER_STORES is the
-- container-backed stores in the order the diagnostics report lists them.
C.STORE_CONTAINERS = {
  BAGS         = C.BAG_IDS,
  BANK         = C.BANK_IDS,
  WARBAND_BANK = WARBAND and C.WARBAND_BANK_IDS or nil,
}
C.CONTAINER_STORES = WARBAND and { "BAGS", "BANK", "WARBAND_BANK" } or { "BAGS", "BANK" }

-- ── Frame layering (frame-layering-§5) ──────────────────────────────────────────
-- The addon's one layers table: every SetFrameStrata and SetFrameLevel in core/, modules/ and
-- settings/ reads it, so no strata string and no bare level number sits at a call site. The keys
-- are the standard's tier keys (frame-layering-§1). The whole stack, bottom to top:
--
--   MEDIUM             LibDBIcon's minimap button (fixed, not ours). The hidden key-binding button
--                      sets no strata (T0, exempt).
--   HIGH        WINDOW the ledger window and the session window: on-demand browsers, toplevel, so
--                      the last one clicked is on top. Above the bags and the bank frames, below
--                      every dialog, and in the same strata as Blizzard's Settings panel (also
--                      toplevel), so a click raises either over the other.
--   DIALOG      MODAL  the export dialog, toplevel; the library's debug console and sim panel
--                      (toplevel from LibKa0s v1.77.0); Blizzard's StaticPopups.
--   FULLSCREEN         the library's CSV copy window, one strata above the export dialog that opens
--                      it (library-chosen, Widgets.lua).
--   FULLSCREEN_DIALOG
--               POPUP  the ledger row context menu (ours); the library's dropdown menu, search
--                      autocomplete and IdList suggestion list.
--   TOOLTIP            GameTooltip.
--
-- Levels inside a window are relative to the window (base W): chrome and panes W+1, table rows
-- W+3/W+4, the resize grip W+10 (LibKa0s-Core's GRIP_LEVEL, which the degraded grip in
-- core/CoreSetup.lua reproduces through LEVEL.GRIP). Content stays at or below W+8 so the grip
-- clears it. The library's combat cover over a settings page computes its own level.
C.LAYERS = {
  STRATA = {
    WINDOW = "HIGH",
    MODAL  = "DIALOG",
    POPUP  = "FULLSCREEN_DIALOG",
  },
  LEVEL = {
    GRIP = 10,
  },
}

-- ── Settings option lists ───────────────────────────────────────────────────────

-- The LOWEST master alpha the addon will draw at, and therefore the lowest the slider offers.
--
-- ONE number, read by both halves on purpose. `Util.ApplyMasterFrame` clamps up to this floor
-- because a stored 0 — hand-edited into SavedVariables, or arriving from an older build — is an
-- addon nobody can see and no way back to the panel that would fix it. The composer's canonical
-- Master alpha row offers min = 0, so the row is decorated with this same value (settings/
-- Schema.lua's MASTER_DECOR): a slider whose bottom two stops both draw at 0.1 is a control that
-- visibly does nothing, and a declared minimum the drawing code refuses is exactly the
-- declared-but-not-honored gap the standard forbids. Move this and both halves move together.
C.MASTER_ALPHA_MIN = 0.1

-- The login backfill (modules/Backfill.lua, BankLedger#2): at most this many distinct item ids are
-- resolved per login, and the pass waits this many seconds for the client's answers before it lets
-- go. A large legacy ledger drains over several logins rather than flooding the item cache in one.
C.BACKFILL_MAX_IDS = 40
C.BACKFILL_TIMEOUT = 10

-- The simulator's pace (BankLedger#24; the owner's 2026-10-23 ask): the range and grid of the
-- `settings.sim.stepDelay` slider, the seconds a playing simulation waits after a step before it
-- plays the next. Named once here because two places must agree on them: the schema row (settings/Schema.lua)
-- and the host's check (modules/Sim.lua's Host.ValidStepDelay), which Host.StepDelay uses to fall
-- back to the default on a stored value the row would refuse. The DEFAULT is not here: like every
-- default it is hardcoded once, in defaults/Profile.lua (savedvariables-§2).
C.SIM_STEP_DELAY_MIN  = 0.5
C.SIM_STEP_DELAY_MAX  = 10
C.SIM_STEP_DELAY_STEP = 0.5

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
--
-- BUILT AT EACH READ, never at file load (SD-SK-BL.2 of Ka0sAddonsCommonTasks
-- docs/2026-11-20-SKIN_DEFAULTS_AUDIT). C.QualityOptions is the Minimum quality row's `values`, which
-- the dropdown and the CLI call when they draw, so a skin switch or a Scope change, each of which
-- re-renders the page, reaches the labels. While the settings page wears the skin each name takes
-- the skin's q.* (NS.SkinPanelQualityHex, core/SkinSetup.lua, which loads after this file and is
-- read at call time); while it is stock (Ignore settings panel, the default) the client's color, as
-- every stock page draws it. rrggbb fallback for headless builds where ITEM_QUALITY_COLORS is absent.
local QUALITY_HEX_FALLBACK = {
  [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000",
}
local function qualityHex(q)
  local skinned = NS.SkinPanelQualityHex and NS.SkinPanelQualityHex(q)
  if skinned then return skinned end
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c and c.hex then return c.hex:sub(-6) end
  return QUALITY_HEX_FALLBACK[q]
end
C.QUALITY_LEVELS = { 0, 1, 2, 3, 4, 5 }
function C.QualityOptions()
  local out = {}
  for _, q in ipairs(C.QUALITY_LEVELS) do
    out[#out + 1] = {
      value = q,
      text  = ("|cff%s%s|r and above"):format(qualityHex(q), NS.Item.QualityLabel(q)),
    }
  end
  return out
end

-- Per-store mute options for the settings panel, derived from the display order.
C.STORE_OPTIONS = {}
for _, s in ipairs(C.StoreOrder) do
  if s ~= "BAGS" then   -- BAGS is the counterparty of every movement, never a mutable target
    C.STORE_OPTIONS[#C.STORE_OPTIONS + 1] = { value = s, text  = C.StoreLabel[s] }
  end
end

-- The monospace face, used by the debug console, the CSV copy box and the ▲/▼ direction glyphs. A
-- sanctioned styling exception — WoW ships no monospace font object (debug-logging-§2).
--
-- IT USED TO BE OURS. This addon shipped its own JetBrains Mono under media/fonts/ and named it
-- here as a bare string literal. The bytes live inside the LibKa0s payload now (v1.10.2,
-- `LibKa0s-Media-1.0`), so every Ka0s addon prints its columns in one face rather than in one copy
-- of it each — see core/MediaSetup.lua, which publishes this seam and registers the face with
-- LibSharedMedia. That is also why core/MediaSetup.lua must load BEFORE this file.
--
-- THE FALLBACK IS A REAL CLIENT FONT, NOT NIL AND NOT A PATH. A degraded install has no LibKa0s
-- and therefore no face. Every reader here hands this straight to SetFont, which accepts a path to
-- a file that is not there, fails to load it, and then simply does not draw the text — so a stale
-- path would be worse than no font at all. STANDARD_TEXT_FONT loses the monospace grid and the
-- direction glyphs (the client default renders ▲/▼ as a box) and keeps every number on screen.
C.FONT_MONO = (NS.MediaFont and NS.MediaFont("JetBrains Mono")) or STANDARD_TEXT_FONT

-- The LibSharedMedia key the face is registered under — by the LIBRARY, whose catalog spells it
-- this way (`LibKa0s-Media-1.0`'s `FONTS`). Kept beside the path so anything in this addon that
-- names the font by key cannot drift from what was actually registered.
C.FONT_MONO_NAME = "JetBrains Mono"

-- Addon logo, shown on the settings landing page at 300px (options-ui-§5). WoW cannot load
-- .jpg/.png at runtime, so the shipped runtime asset is a 512×512 24-bit RLE .tga — a power of two,
-- because the client rescales anything else and the master art is 1254×1254. A missing file renders
-- nothing and raises no error, which is exactly how this shipped blank for a while, so treat the
-- .tga as required rather than optional. See docs/media.md ▸ Logo art.
C.LOGO_PATH = "Interface\\AddOns\\BankLedger\\media\\logos\\bankledger.logo.tga"

-- Convenience aliases.
NS.Store = C.Store
NS.Direction = C.Direction
NS.Kind = C.Kind

-- ── The bus message catalog (architecture-§4) ───────────────────────────────────
--
-- Every bus message this addon sends, declared ONCE, here: every SendMessage and RegisterMessage in
-- the addon names the constant, never the literal. Here rather than in a core/Bus.lua because this
-- addon has no bus file -- the publisher is the addon object (core/BankLedger.lua) and each
-- receiver's private target comes from NS.NewBusTarget beside it. docs/ARCHITECTURE.md ▸ Message
-- bus carries the payloads and every consumer.
--
-- LibKa0s-Bus-1.0's Catalog (LibKa0s docs/api/Bus/version-1-docs.md) validates the names at load and hands
-- back a STRICT copy, so a mistyped key raises at the call site -- for a publisher too, whose
-- SendMessage(nil) would otherwise return quietly and send nothing. Only Catalog is adopted: the
-- receivers keep this addon's own untracked factory, so nothing here calls Bus:New.
--
-- Degraded (the payload missing): the untracked-target stub (options-ui-§1, library-stack-§7),
-- verbatim from the Bus API document's Worked example. Its Catalog hands back the declared table
-- itself: the names and every send and receive are unchanged; only the strictness is lost. Its New
-- answers a record whose NewTarget hands out a private AceEvent target, untracked, and answers nil
-- only when AceEvent-3.0 itself is absent; StandDown and StandUp answer 0 and 0, {}. It records
-- nothing, prints nothing and copies nothing of the library. No BankLedger path calls New today;
-- the stub carries it because the named shape does, and so that a later Bus:New adopter inherits a
-- degraded arm that already works. Published as NS.__busLib so tests/test_surface_parity.lua holds
-- the stub to the live major with no ignore list.
local Bus = LibStub and LibStub("LibKa0s-Bus-1.0", true)
if not Bus then
  Bus = {
    New = function(_, d)
      return {
        name = d and d.name,
        NewTarget = function()
          local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
          if not AceEvent then return nil end
          local t = {}; AceEvent:Embed(t); return t
        end,
        StandDown = function() return 0 end,
        StandUp   = function() return 0, {} end,
      }
    end,
    Catalog = function(_, messages) return messages end,
  }
end
NS.__busLib = Bus

NS.MSG = Bus.Catalog(addonName, {
  -- Sender: core/Database.lua (Database:Add). Payload: entry, index.
  ENTRY_ADDED      = "Ka0s_BankLedger_EntryAdded",
  -- Sender: core/Database.lua (delete, purge, prune, FireLedgerChanged). Payload: none.
  LEDGER_CHANGED   = "Ka0s_BankLedger_LedgerChanged",
  -- Sender: modules/Ledger.lua (OpenContext, CloseContext, the guild-bank disarm).
  -- Payload: active (boolean), context.
  SESSION_CHANGED  = "Ka0s_BankLedger_SessionChanged",
  -- Sender: the settings write path -- the settings/Schema.lua row reactions (core/Util.lua's
  -- row-tint refresh is one) and settings/Slash.lua's full reset. Payload: a short reason string.
  SETTINGS_CHANGED = "Ka0s_BankLedger_SettingsChanged",
})
