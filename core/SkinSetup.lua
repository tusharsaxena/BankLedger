local addonName, NS = ...

-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§3).
--
-- Ka0s Loot History's seam of the same name is the pattern (LibKa0s docs/api/CONSUMERS.md cites
-- that file): the same members, the same degraded arm, the same one-half-at-a-time writes. What is
-- this addon's own is where the choice lives (settings.appearance, beside every other setting the
-- profile holds), the brand the Skin tab prints, and the owner tokens below.
--
-- ── WHAT IT PUBLISHES ────────────────────────────────────────────────────────────────────────
--
--   NS.Skin                 the owner's facade, `Skin:For("BankLedger")`: the painting vocabulary
--                           (Shell, TitleBar, Button, ...) and Token / Color / Resolve /
--                           OnLooksChanged. Every surface that draws reads its colors here.
--   NS.SKIN_TOKENS          this addon's owner tokens (LibKa0s-Skin-1.0 minor 7, skinning-§1):
--                           the colors it draws under Ka0s Default that no library token holds
--                           exactly. Registered with the owner; the degraded facade answers each
--                           one's `default`.
--   NS.SkinChoice()         the stored (source, skin) pair, read through NS.Schema:Get; "ka0s",
--                           "ka0s" before NS:InitDB has built the profile store.
--   NS.WriteSkinChoice(s,k,i,m) the write seam: both halves through NS.Schema:Set, the one seam
--                           `/bl set` and the panel already write through (architecture-§5); `i`,
--                           the Scope's `{ panel, fonts }`, writes the two exceptions, and `m`, the
--                           Font and texture section's `{ font, texture }`, writes the two
--                           overrides, "" for false (the skin's own).
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions: `Skin:SetIgnore`, live; no argument
--                           applies the stored pair, a nil half keeps that half.
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for the
--                           skin's own; false, false before NS:InitDB.
--   NS.ApplySkinOverride(f,t) moves the applied overrides: `Skin:SetOverride`, live; no argument
--                           applies the stored pair, a nil half keeps that half, false or "" clears.
--   NS.ApplySkinChoice(s,k) moves the applied skin: `Skin:SetChoice`, which resolves, repaints
--                           every frame recorded for this owner and THEN fires OnLooksChanged. No
--                           argument applies the stored pair (addon:OnInitialize, the profile
--                           events), and with it the stored exceptions and overrides; a nil half
--                           keeps that half (each Skin tab row's onChange).
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/Schema.lua reads both.
--   NS.SKIN_FALLBACK        the host copy of the Ka0s Default library tokens the degraded facade
--                           answers.
--   NS.SkinColor(name)      a color token as a call site writes it (three components when opaque),
--                           so a literal that became a token keeps its arity on Ka0s Default.
--   NS.SkinRGB(name)        a color token as a fresh { r, g, b } triple (the shape the Insights
--                           widgets hand their painters).
--   NS.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte, so markup
--                           written as a literal keeps its bytes on Ka0s Default (|cff808080).
--   NS.SkinBar(t, r,g,b,a)  a bar of data (an Insights fill, a stacked segment, a strip bar): the
--                           owner's bar texture tinted r, g, b, a through `S.BarTexture`, recorded,
--                           so a skin switch or a Texture override re-applies it; SetColorTexture,
--                           the flat look, without it.
--   NS.QualityColor(q)      an item quality's r, g, b: the skin's q.* token where it sets one (a
--                           legibility override), else the client's ITEM_QUALITY_COLORS; nil for none.
--   NS.SkinPaintAce(w)      an AceGUI widget this addon acquired itself, painted for this owner:
--   NS.SkinPaintAceTree(c)  `Skin:PaintAce` / `Skin:PaintAceTree` with the owner bound (the facade
--                           carries neither). Nothing while the owner ignores its settings panel;
--                           release restores stock.
--   NS.SkinOnRelease(w, fn) host release work chained onto the widget's own OnRelease
--                           (`Skin:OnRelease`), so it and the skin's restore both run.
--
-- ── WHERE IT LOADS ───────────────────────────────────────────────────────────────────────────
--
-- After core/CoreSetup.lua, whose NS.ApplySkin the degraded facade's Shell routes to, and after
-- core/LauncherSetup.lua, whose NS.BRAND_NAME labels the owner (the Skin tab's copy confirmation), and before
-- every module that builds a frame, so NS.Skin exists for all of them. settings/Schema.lua reads
-- NS.SKIN_OPTIONS at file load and is far below. Nothing here reads the profile at load:
-- RegisterOwner calls `get` once, before AceDB exists, and it answers Ka0s Default; the profile's
-- pair is applied by NS.ApplySkinChoice right after NS:InitDB (core/BankLedger.lua). It registers
-- at FILE LOAD, never at PLAYER_LOGIN, so the EllesmereUI provider can offer the owner to
-- EllesmereUI before EllesmereUI dispatches its skins (skinning-§1, §5).
--
-- ── WHY A ROW'S onChange PASSES ONE HALF ─────────────────────────────────────────────────────
--
-- The Skin tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice
-- FIRST and write the store after, one half at a time. A row reaction that re-applied the whole
-- stored pair would apply the half-written one in between: a second repaint, to a skin the player
-- never picked. Applying only the row's own half against the applied choice makes each write a
-- no-op (SetChoice is idempotent), so a pick is ONE effective SetChoice and one repaint, while a
-- bare `/bl set settings.appearance.skin obsidian` still repaints.
--
-- Nothing skin-related keys off SETTINGS_CHANGED. A surface that has to rebuild on a skin change
-- (markup built once, a pooled row) subscribes to NS.Skin.OnLooksChanged, which fires after the
-- new skin is resolved and the recorded frames are repainted.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "settings.appearance.source", "settings.appearance.skin"
local PANEL_PATH, FONTS_PATH = "settings.appearance.ignorePanel", "settings.appearance.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "settings.appearance.font", "settings.appearance.texture"
local DEFAULT = "ka0s"

-- The owner tokens (skinning-§1; the rollout's decisions X1, X2 and X12). Each is a color this
-- addon draws under Ka0s Default whose exact value no library token holds, so it is declared here
-- rather than snapped to the nearest token, which would move a Ka0s Default pixel. `default` is
-- the literal the call site drew before it adopted, exactly; `follow` is the nearest library ROLE
-- token, whose value it takes in every other skin and under EllesmereUI. The namespace is `bl.`,
-- never a library family (the library refuses those). Read like any token: S.Color("bl.gold").
NS.SKIN_TOKENS = {
  -- The pale gold of a gold movement (BL-G1, DECISIONS BankLedger D4): a gold row's Item and
  -- Quality cells and its tooltip title, the session window's copy, the search suggestion. A
  -- meaning color: the row is money, not an item, so it has no quality. sem.gold is
  -- {1, 0.86, 0.55}, 0.05 off in green.
  ["bl.gold"]           = { default = { 1, 0.91, 0.55, 1 }, follow = "sem.gold" },
  -- (No token for the Insights legend swatch's tooltip line, BL-G2: the rollout's inventory ruled it
  -- rung 1. It is text.value, the legend label's own token, which is 0.80/0.80/0.82 under Ka0s
  -- Default and which no skin darkens.)
  --
  -- The Insights widgets' unknown-quality fallback (D9, ruled by X1 to stay exact): a quality id
  -- the client has no color for. sem.unknown is {0.6, 0.6, 0.6}, 0.02 off in blue.
  ["bl.qualityUnknown"] = { default = { 0.60, 0.60, 0.62, 1 }, follow = "sem.unknown" },
}

-- The Ka0s Default LIBRARY tokens the DEGRADED facade answers, copied from the library and limited
-- to the ones this addon reads. Today they are the window edge core/CoreSetup.lua's pre-library
-- NS.ApplySkin draws. Both arms publish the table, so tests/test_surface_parity.lua can hold each
-- entry to the live library's Ka0s Default value: a copy that drifts goes red there. A surface
-- converted to a token adds the token here in the same change.
NS.SKIN_FALLBACK = {
  ["win.bg"]     = { 0.06, 0.06, 0.08, 0.92 },
  ["win.border"] = { 0, 0, 0, 1 },
  ["win.inner"]  = { 0.24, 0.24, 0.27, 0.85 },
  ["title.text"] = { 1, 0.82, 0, 1 },
  ["divider"]    = { 0.24, 0.24, 0.27, 0.85 },
}

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g, b,
--- a otherwise (the library's own text and vertex rule), so a site that passed three components
--- before it read a token still passes three on Ka0s Default. nil for a token the skin leaves alone.
--- Read through NS.Skin at call time, so it answers the live skin, or the host copy degraded.
function NS.SkinColor(name)
  local r, g, b, a = NS.Skin.Color(name)
  if r == nil then return nil end
  if a == nil or a == 1 then return r, g, b end
  return r, g, b, a
end

--- A color token as a fresh { r, g, b } triple (nil for a token the skin leaves alone).
function NS.SkinRGB(name)
  local r, g, b = NS.Skin.Color(name)
  if r == nil then return nil end
  return { r, g, b }
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte (1/3 is 55,
--- .5 is 80), so markup a call site wrote as a literal keeps its bytes on Ka0s Default. nil for a
--- token the skin leaves alone.
function NS.SkinEscape(name)
  local r, g, b = NS.Skin.Color(name)
  if r == nil then return nil end
  local function byte(v) return math.floor(v * 255 + 0.5) end
  return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

--- A bar of data in the owner's bar texture, tinted r, g, b, a. Never a track, a rule, an axis, a
--- swatch chip, a stripe or a highlight: those stay flat colors. Read through NS.Skin at call time.
--- A facade without BarTexture, or a target that is neither a Texture nor a StatusBar (which the
--- primitive leaves alone), paints today's flat color, so no bar ever goes unpainted.
function NS.SkinBar(tex, r, g, b, a)
  if type(tex) ~= "table" then return end
  local paint = NS.Skin and NS.Skin.BarTexture
  local kind = type(tex.GetObjectType) == "function" and tex:GetObjectType() or nil
  if type(paint) == "function" and (kind == "Texture" or kind == "StatusBar") then
    return paint(tex, r, g, b, a)
  end
  if type(tex.SetColorTexture) == "function" then tex:SetColorTexture(r, g, b, a) end
end

-- The six qualities the skin schema names (q.poor .. q.legendary); every other quality (artifact,
-- heirloom, token) is the client's color under every skin.
local QUALITY_TOKEN = { [0] = "q.poor", "q.common", "q.uncommon", "q.rare", "q.epic", "q.legendary" }

--- An item quality's r, g, b. The q.* tokens: Ka0s Default writes the client's own colors out, a
--- skin may override them for legibility (never re-hue them: skinning-§4). nil for a quality the
--- client has no color for, so a caller keeps its own fallback.
function NS.QualityColor(q)
  local name = QUALITY_TOKEN[q]
  if name then
    local r, g, b = NS.Skin.Color(name)
    if r ~= nil then return r, g, b end
  end
  local c = ITEM_QUALITY_COLORS and q ~= nil and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
  return nil
end

NS.SKIN_SOURCE_OPTIONS = {
  { value = "ka0s", text = "Ka0s skins" },
  { value = "eui",  text = "EllesmereUI" },
}

-- The skin row's values: every registered skin, Ka0s Default first. Without the library the one
-- skin the degraded facade can draw.
NS.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
  for _, def in ipairs(Skin:Skins()) do
    NS.SKIN_OPTIONS[#NS.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
  end
end
if #NS.SKIN_OPTIONS == 0 then NS.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function NS.SkinChoice()
  local S = NS.Schema
  if not (NS.db and S and S.Get) then return DEFAULT, DEFAULT end
  return S:Get(SOURCE_PATH) or DEFAULT, S:Get(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own (false, nil, "").
local function storedKey(v)
  if type(v) == "string" and v ~= "" then return v end
  return ""
end

--- The write seam: every half through NS.Schema:Set (validate, store, the [Set] line, onChange).
--- `media` is `{ font = key|false, texture = key|false }`: the Skin tab's Font and texture pick and
--- another addon's copy both hand it here, after Skin:SetOverride moved the applied pair, so each
--- row's onChange re-applies its own half as a no-op.
function NS.WriteSkinChoice(source, skin, ignore, media)
  local S = NS.Schema
  if not (NS.db and S and S.Set) then return end
  if source ~= nil then S:Set(SOURCE_PATH, source) end
  if skin ~= nil then S:Set(SKIN_PATH, skin) end
  if type(ignore) == "table" then
    S:Set(PANEL_PATH, ignore.panel == true)
    S:Set(FONTS_PATH, ignore.fonts == true)
  end
  if type(media) == "table" then
    S:Set(FONT_PATH, storedKey(media.font))
    S:Set(TEXTURE_PATH, storedKey(media.texture))
  end
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own; false, false
--- until the profile store exists.
function NS.SkinOverride()
  local S = NS.Schema
  if not (NS.db and S and S.Get) then return false, false end
  local font, texture = storedKey(S:Get(FONT_PATH)), storedKey(S:Get(TEXTURE_PATH))
  return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely: false, false until the profile store exists.
local function storedIgnore()
  local S = NS.Schema
  if not (NS.db and S and S.Get) then return false, false end
  return S:Get(PANEL_PATH) == true, S:Get(FONTS_PATH) == true
end

-- AceGUI keeps ONE callback per event name (options-ui-§19). Without the library's chain there is
-- no skin restore to share the release with, so the host's work takes the callback, as it did
-- before the skin engine.
local function releaseByCallback(widget, fn)
  if type(widget) ~= "table" or type(fn) ~= "function" or type(widget.SetCallback) ~= "function" then
    return nil
  end
  widget:SetCallback("OnRelease", function(w) fn(w) end)
  return fn
end

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

if not Skin then
  local function color(name)
    local c = NS.SKIN_FALLBACK[name]
    local t = NS.SKIN_TOKENS[name]
    if not c and t then c = t.default end
    if c then return c[1], c[2], c[3], c[4] or 1 end
  end
  local function noop() end
  local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
  -- Every vocabulary name answers, and a primitive with no host meaning is a no-op that never
  -- raises (Shell, TitleBar, Divider, Text and BarTexture draw today's look from the host copy).
  -- The list is LibKa0s-Skin-1.0's VOCAB; tests/test_surface_parity.lua holds this table to the
  -- live facade key for key.
  for _, name in ipairs({
    "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
    "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
    "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
    "GetAccentColor", "GetPanelColor", "GetFont",
    "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
    "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
    "BarTexture",
  }) do S[name] = noop end

  S.Token = function(name)
    local t = NS.SKIN_TOKENS[name]
    return NS.SKIN_FALLBACK[name] or (t and t.default)
  end
  S.Color = color
  S.Resolve = function(kind, value, fromSkin)
    if fromSkin or value == S.FROM_SKIN then return S.Token(kind) end
    return value
  end
  S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
  S.IsEnabled = function() return false end
  S.GetStyle = function() return "ka0s:" .. DEFAULT end

  -- The window edge is CoreSetup's pre-library skin, byte for byte what a working install draws.
  S.Shell = function(frame) if NS.ApplySkin then NS.ApplySkin(frame) end end
  -- A title bar's text in the title color, the one NS.ApplySkin gives a shelled frame's `title`.
  S.TitleBar = function(bar, opts)
    local fs = (type(opts) == "table" and opts.text) or (bar and (bar.title or bar.text))
    if fs and fs.SetTextColor then fs:SetTextColor(color("title.text")) end
  end
  -- A role ("heading", "disabled") or, as the live S.Text takes since SkinPaintExtras minor 5, a
  -- token's own name.
  S.Text = function(fs, role)
    local name = role == "title" and "title.text" or tostring(role)
    if not (NS.SKIN_FALLBACK[name] or NS.SKIN_TOKENS[name]) then name = "text." .. tostring(role) end
    local r, g, b, a = color(name)
    if r and fs and fs.SetTextColor then fs:SetTextColor(r, g, b, a) end
  end
  -- A rule: a texture colored in place, or a frame given one texture filling it (made once).
  local rules = setmetatable({}, { __mode = "k" })
  S.Divider = function(target, opts)
    if type(target) ~= "table" then return end
    local r, g, b, a = color(type(opts) == "table" and opts.token or "divider")
    if not r then return end
    local tex = target
    if type(target.GetObjectType) == "function" and target:GetObjectType() ~= "Texture" then
      tex = rules[target]
      if not tex and type(target.CreateTexture) == "function" then
        tex = target:CreateTexture(nil, "ARTWORK")
        if type(tex) == "table" and tex.SetAllPoints then tex:SetAllPoints(target) end
        rules[target] = tex
      end
    end
    if type(tex) == "table" and type(tex.SetColorTexture) == "function" then tex:SetColorTexture(r, g, b, a) end
  end
  -- A bar of data as it was drawn before the skin engine: the flat color, no texture.
  S.BarTexture = function(tex, r, g, b, a)
    if type(tex) == "table" and type(tex.SetColorTexture) == "function" then tex:SetColorTexture(r, g, b, a) end
  end
  S.GetPanelColor = function() return color("win.bg") end
  S.GetFont = function() return STANDARD_TEXT_FONT end
  S.ChartStyle = function() return {} end
  S.BarStyle = function() return {} end

  NS.Skin = S
  function NS.ApplySkinChoice() return false, false end
  function NS.ApplySkinIgnore() return false, false end
  function NS.ApplySkinOverride() return false end
  -- Nothing to paint an AceGUI row with: stock AceGUI, as the client draws it.
  function NS.SkinPaintAce() return false end
  function NS.SkinPaintAceTree() return 0 end
  NS.SkinOnRelease = releaseByCallback
  return
end

-- ── the live seam ────────────────────────────────────────────────────────────────────────────

NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
  label = NS.BRAND_NAME,
  get = NS.SkinChoice,
  set = NS.WriteSkinChoice,
  tokens = NS.SKIN_TOKENS,
})

-- The one line a reload request earns on the path that has no popup of its own (a profile event
-- leaving an EllesmereUI that painted this session). The Skin tab raises the library's popup
-- for its own picks.
local RELOAD_LINE = NS.L["Reload your interface (/reload) to finish changing the skin."]

-- The AceGUI rows (SkinAce.lua). The Options instance's AceGUI is the owner proxy, which paints on
-- Create already; PaintAce for the same owner repaints in place, so a host call after it is
-- harmless, and it is what paints a widget acquired any other way (AceConfigDialog's, on the
-- Profiles page). Each guards on the member, so a copy whose SkinAce secondary did not attach
-- paints nothing.
function NS.SkinPaintAce(widget)
  if type(Skin.PaintAce) ~= "function" then return false end
  return Skin:PaintAce(addonName, widget)
end

function NS.SkinPaintAceTree(container)
  if type(Skin.PaintAceTree) ~= "function" then return 0 end
  return Skin:PaintAceTree(addonName, container)
end

function NS.SkinOnRelease(widget, fn)
  if type(Skin.OnRelease) ~= "function" then return releaseByCallback(widget, fn) end
  return Skin:OnRelease(widget, fn)
end

function NS.ApplySkinIgnore(panel, fonts)
  if type(Skin.SetIgnore) ~= "function" then return false, false end
  if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
  local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
  if reload and NS.Print then NS.Print(RELOAD_LINE) end
  return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it
--- (the skin's own). A copy without SetOverride moves nothing.
function NS.ApplySkinOverride(font, texture)
  if type(Skin.SetOverride) ~= "function" then return false end
  if font == nil and texture == nil then font, texture = NS.SkinOverride() end
  return Skin:SetOverride(addonName, font, texture)
end

--- No argument applies the stored pair AND the stored exceptions and overrides (addon:OnInitialize,
--- the profile events); a nil half keeps that half and leaves the rest alone (each Skin tab row).
function NS.ApplySkinChoice(source, skin)
  local whole = source == nil and skin == nil
  if whole then source, skin = NS.SkinChoice() end
  local changed, reload = Skin:SetChoice(addonName, source, skin)
  if reload and NS.Print then NS.Print(RELOAD_LINE) end
  if whole then
    NS.ApplySkinIgnore()
    NS.ApplySkinOverride()
  end
  return changed, reload
end
