local addonName, NS = ...   -- luacheck: ignore addonName

-- settings/OptionsSetup.lua — wires the addon into LibKa0s-Options-1.0 (options-ui).
--
-- The settings-canvas shell, the header and breadcrumb, the always-shown scrollbar, the lazy
-- Defaults button, the schema-row → AceGUI widget makers and the two-column flow engine all live in
-- libs/LibKa0s/{Options,OptionsWidgets,OptionsScroll}.lua and are shared across every Ka0s addon.
-- This file is only the part that is ours: where a value lives, which rows a page shows, and what a
-- global reset has to clear that no schema row owns.
--
-- `NS.Helpers` IS the library instance, not a wrapper around it (options-ui-§1). settings/Panel.lua
-- decorates it in place with the pieces that did not generalize — the store grid, the Storage
-- section, the whole Filters page — so a host page helper can call `O.RenderRows` like any other
-- page does, and a suite that swaps a member out to spy on it is swapping the one the library's own
-- callers see. A copy-across would hand the test a member nobody calls.
--
-- Loads AFTER settings/Schema.lua and settings/Slash.lua (it reads the schema and the write seam)
-- and BEFORE settings/Panel.lua, which captures the instance at file scope.

local print = NS.Print

-- The brand. Reaches the library as descriptor.parentTitle, which builds both the main page's title
-- and every sub-page's "Ka0s Bank Ledger ▸ <page>" breadcrumb.
local PARENT_TITLE = "Ka0s Bank Ledger"

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

-- The landing page's body lives in settings/Panel.lua, which loads AFTER this file — so the
-- descriptor below cannot capture it. It is read through this upvalue at CALL time instead, which
-- is the main panel's first OnShow and therefore long after every file has loaded. Nil just means
-- an empty landing page rather than a raise.
local buildMainBody

-- ── the descriptor ───────────────────────────────────────────────────────────────────────────

local descriptor = {
  parentTitle   = PARENT_TITLE,
  mainPanelName = "BankLedgerMainPanel",

  print = function(line) print(line) end,
  debug = function(tag, fmt, ...) if NS.Debug then NS.Debug(tag, fmt, ...) end end,

  -- The schema seams. NS.Schema:Set is this addon's SINGLE write seam (options-ui-§1), so a panel
  -- widget takes exactly the path `/bl set` takes: the same validation, the same [Set] debug line,
  -- the same row onChange, and the same panel repaint.
  get          = function(path) return NS.Schema:Get(path) end,
  set          = function(path, value) NS.Schema:Set(path, value) end,
  applyDefault = function(row) NS.Schema:Set(row.path, NS.Schema:Default(row.path)) end,
  allRows      = function() return NS.Schema.Schema end,

  -- Every schema row lives on the General page. `filter` is ctx.unit, which this addon never sets —
  -- it has no per-unit pages — so it is ignored rather than threaded through.
  rowsForPage = function(pageKey)
    if pageKey ~= "general" then return {} end
    return NS.Schema.Schema
  end,

  -- The landing page's body. settings/Panel.lua owns what it draws; the library owns WHEN, which is
  -- the main panel's first OnShow — the same deferral every sub-page gets, and for the same reason
  -- (AceGUI lays out against a width that is zero before the panel is first shown).
  buildMain = function(ctx)
    if buildMainBody then return buildMainBody(ctx) end
  end,

  -- library-stack-§4: AceGUI is resolved once, by the library, and handed over rather than
  -- re-resolved per file. settings/Panel.lua's bespoke widgets read NS.AceGUI.
  onAceGUI = function(AceGUI) NS.AceGUI = AceGUI end,

  -- Runs once, before the page builders. NS.Schema:Register is this addon's own schema-shape check
  -- (every path must resolve against the defaults table), and running it here as well as at
  -- OnInitialize costs one walk and means a panel build can never draw a row whose path is a typo.
  validate = function() if NS.Schema.Register then NS.Schema:Register() end end,

  -- AceTimer through the addon object (library-stack-§1). The library takes it as a descriptor
  -- field rather than embedding AceTimer, which would be its second dependency-budget breach.
  -- Nothing in this addon's schema is a color row today, so this backs nothing yet — it is wired
  -- because the alternative is discovering it is missing from inside a drag.
  scheduleTimer = function(fn, delay)
    if NS.addon and NS.addon.ScheduleTimer then return NS.addon:ScheduleTimer(fn, delay) end
  end,

  -- No `colorDecode`/`colorEncode`: no schema row is `type = "color"`. Adding one means adding
  -- these, because this addon has no stored color shape for the library to default to.
  --
  -- No `skipRestoreAll`: every row here is a plain setting and a global reset should touch all of
  -- them. This addon has no profiles page whose rows are user data.
  --
  -- No `afterRestoreAll` and no use of the library's RestoreAllDefaults — see settings/Panel.lua's
  -- P:RestoreDefaults, and LIBKA0S-22 in docs/pending/LEDGER.md, for why the reset stays one
  -- host-owned implementation shared with `/bl resetall`.
  --
  -- No `getLSM`: no row is LSM-backed. The vendored console font is a Constants path, not a media
  -- picker.
}

-- ── degradation ──────────────────────────────────────────────────────────────────────────────
--
-- LOAD-COMPLETING rather than member-answering, which is options-ui-§1's one documented exception
-- to the stub shape every other Ka0s setup file uses. The reason is WHEN the missing code is
-- reached: in an addon whose page files evaluate a helper inside a schema-row literal at FILE LOAD,
-- a nil member makes that file raise, its rows never register, and a third of the schema silently
-- disappears — taking `list`, `get`, `set` and `reset` with it. That is a half-load, not a
-- degradation.
--
-- The set of members a page file needs AT LOAD is determined by MEASUREMENT, not by reading, and
-- for this addon it measures out to ZERO: settings/Panel.lua captures the instance at file scope
-- but calls nothing on it until a panel is registered or rendered, and no schema row literal in
-- settings/Schema.lua calls a helper. tests/test_libka0s.lua pins both that member set and the
-- resulting schema row count, because those cases are the only thing standing between this stub and
-- a silent half-load if a future page file grows a load-time call.
--
-- So everything below is call-time, and every one of them is a no-op or one honest line. NOT a copy
-- of any widget maker, any layout constant or the flow engine (anti-pattern #47): a host copy of a
-- library constant is the copy that goes stale.
if not lib then
  local UNAVAILABLE = NS.LIBKA0S_MISSING .. ", so the settings panel is unavailable."
  local announced = false
  local function unavailable()
    if announced then return end
    announced = true
    print(UNAVAILABLE)
  end

  NS.Helpers = {
    __degraded = true,

    -- The page-registration and panel-open surface: a single honest line, once.
    RegisterOptionsPage = function() end,
    CreateOptionsPanel  = unavailable,
    OpenOptionsPanel    = unavailable,

    -- Everything a renderer would have called. None of these is reachable without a panel, but the
    -- stub answers them so a future call site fails as a no-op rather than as a nil index.
    CreatePanel = function() return nil end,
    EnsureScroll = function() return nil end,
    ClearScroll = function() end,
    EnsureDefaultsButton = function() end,
    Section = function() end,
    AddSpacer = function() end,
    AttachTooltip = function() end,
    RenderField = function() return nil end,
    RenderRows = function() end,
    RenderSchema = function() end,
    RenderGrid = function() end,
    SetRenderer = function() end,
    InlineButtonPair = function() end,
    SessionCheckbox = function() return nil end,
    RefreshAllPanels = function() end,
    RefreshScalars = function() end,
    RestoreDefaults = function() end,
    RestoreAllDefaults = function() end,
    __panels = function() return {} end,
    __panelFor = function() return nil end,
    __pages = function() return {} end,
    SetMainBuilder = function() end,

    -- The layout constants a host page reads off the instance. Zero rather than a copied number:
    -- anti-pattern #47 forbids carrying the library's values into a stub, and a spacer of zero on a
    -- panel that cannot be drawn costs nothing.
    ROW_VSPACER = 0, SECTION_HEADING_H = 0, BUTTON_PAIR_REL = 0.5,
    AceGUI = nil,
  }
  return
end

NS.Helpers = lib:New(descriptor)

-- settings/Panel.lua hands its landing-page body over here.
function NS.Helpers.SetMainBuilder(fn) buildMainBody = fn end
