local _, NS = ...   -- the addon FOLDER is not needed here; see the close-control note below
NS.Util = NS.Util or {}
local Util = NS.Util

-- core/CoreSetup.lua — wires the addon into LibKa0s-Core-1.0 (library-stack).
--
-- The secret-value guard, the concat-safe stringifier and the prefixed chat printer used to live at
-- the bottom of core/Util.lua. They are identical in every Ka0s addon and subtly wrong in several of
-- them, so they now live in libs/LibKa0s/Core.lua and this file is only the part that is OURS: which
-- tag the lines carry, and what happens when the library is not there.
--
-- WHERE THIS FILE SITS, and why each neighbor pins it (architecture-§2):
--   * AFTER core/Namespace.lua — that is where NS.PREFIX is defined. The `prefix` descriptor field
--     is passed as a FUNCTION anyway, so this constraint is belt-and-braces rather than load-bearing.
--   * BEFORE core/Util.lua — Util.lua's own body no longer defines a printer, but keeping the seam
--     above it keeps "the printer exists before anything else in core/ runs" true by position.
--   * BEFORE core/BankLedger.lua — the AceConsole embed there clobbers NS.Print and reclaims it from
--     NS.Util.print, so NS.Util.print must already hold the real printer by then.
--   * BEFORE modules/Browser.lua, modules/LedgerTable.lua, modules/DebugLog.lua, settings/Schema.lua,
--     settings/Slash.lua and settings/Panel.lua — all six take the printer as a
--     `local print = NS.Print` FILE-SCOPE UPVALUE. A seam that landed after any of them would swap the printer for a copy nobody reads,
--     and the change would appear to work while doing nothing.
-- tests/test_toc.lua pins every one of those orderings against the shipped TOC.

-- The one cause clause, shared by every seam that has to explain the same absence: this file,
-- core/DebugLogSetup.lua, settings/Slash.lua and settings/OptionsSetup.lua. Each appends its own
-- "so <what> is unavailable" and its own terminal punctuation, so a degraded install says the same
-- thing about WHY at every site and a different thing about WHAT at each one. Set OUTSIDE the branch
-- below because the later seams read it on both paths, and set HERE because core/CoreSetup.lua is
-- the first of the four the TOC loads.
NS.LIBKA0S_MISSING = "The LibKa0s library is missing from this installation of Ka0s Bank Ledger " ..
  "(expected in libs/LibKa0s)"

local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)

if not lib then
  -- A missing vendored lib must degrade, not error at load. Silence is not an option the way it is
  -- for a diagnostics harness: six files do `local print = NS.Print` at load, so a nil printer
  -- takes the settings UI and the ledger window down with it, and a no-op one makes `/bl` answer
  -- nothing at all. So the fallbacks WORK — they are the pre-library implementations, kept short —
  -- and the honest "it is not installed" line is said ONCE, on the first line the addon prints,
  -- rather than stapled to every one of them.
  local function probeConcat(v) return table.concat({ v }) end
  function NS.IsConcatSafe(v)
    return (pcall(probeConcat, v))
  end

  function NS.SafeToString(v)
    if v == nil then return "nil" end
    if type(v) == "boolean" then return tostring(v) end
    if NS.IsConcatSafe(v) then return tostring(v) end
    return "<secret>"
  end

  local announced = false
  function NS.Print(...)
    -- Composed as `tag .. " " .. body`, NOT as a single concat over { PREFIX, ... }, so that this
    -- branch renders the SAME bytes as Core's printer does. The two differ on exactly one input —
    -- a zero-argument NS.Print(), where the old single-concat form emitted a bare tag and Core
    -- emits the tag plus its separator. Nothing in this addon calls it that way, but a degraded
    -- install that rendered differently from a working one is a bug report nobody can reproduce.
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = NS.SafeToString((select(i, ...))) end
    if not DEFAULT_CHAT_FRAME then return end
    if not announced then
      announced = true
      DEFAULT_CHAT_FRAME:AddMessage(NS.SafeToString(NS.PREFIX) .. " " ..
        NS.LIBKA0S_MISSING .. "; running on reduced built-in fallbacks.")
    end
    DEFAULT_CHAT_FRAME:AddMessage(NS.PREFIX .. " " .. table.concat(parts, " "))
  end
  -- The pre-library window edge, kept in THIS branch rather than in modules/Browser.lua. The live
  -- definition is Core.SKIN applied by Core.ApplySkin, and a host copy on the path where the
  -- library IS present is exactly the copy that drifts (standalone-windows). This one runs only
  -- when the library is absent, and it is byte-for-byte the skin modules/Browser.lua applied
  -- before the seam existed, so a degraded install's windows look like a working one's.
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  function NS.ApplySkin(f)
    if not (f and f.SetBackdrop) then return end
    f:SetBackdrop({
      bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    if type(f.innerBorder) ~= "table" and type(CreateFrame) == "function" then
      local inner = CreateFrame("Frame", nil, f, "BackdropTemplate")
      inner:SetPoint("TOPLEFT", 1, -1)
      inner:SetPoint("BOTTOMRIGHT", -1, 1)
      inner:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
      f.innerBorder = inner
    end
    if type(f.innerBorder) == "table" then
      f.innerBorder:SetBackdropBorderColor(0.24, 0.24, 0.27, 0.85)
    end
    if f.title then f.title:SetTextColor(1.0, 0.82, 0.0) end
    if f.divider then f.divider:SetColorTexture(0.24, 0.24, 0.27, 0.85) end
  end

  Util.print = NS.Print
  return
end

-- The shared Ka0s window edge (standalone-windows). modules/Browser.lua's ApplySkin seam — the
-- one every window in this addon reaches the edge through — delegates here rather than
-- restating Core.SKIN's values, so a re-skin lands on all five Ka0s windows at once. Published
-- as a flat NS member for the same reason NS.SafeToString is: the fallback branch owes the
-- caller the same name.
NS.ApplySkin = lib.ApplySkin

NS.IsConcatSafe = lib.IsConcatSafe
NS.SafeToString = lib.SafeToString

-- `lib.MakeCloseButton` IS DELIBERATELY NOT REPUBLISHED, and this paragraph is here so the next
-- reader does not add it back. This addon draws its own close control — modules/Browser.lua's
-- `B:MakeCloseButton`, 24x24, class-coloured on hover — and all four of its title bars (ledger,
-- session, export modal, export copy) go through that one factory. It resolves the SAME shared
-- `close` mark, through `NS.Icon`, which knows the folder because core/MediaSetup.lua was handed
-- the first vararg; so the two implementations agree on the art and differ only in size and hover
-- tint, which is the line standalone-windows draws.
--
-- A wrapper here would have had exactly one consumer — its own spy test — and a published, tested
-- seam that no window reaches reads as coverage of those four title bars while covering nothing a
-- player can see. The library's factory is still used, on the windows that are the LIBRARY's: the
-- debug console and its Copy box, whose controls it draws for itself once core/DebugLogSetup.lua
-- passes `addonName`. That is where the "tell the library which folder is asking" argument actually
-- ships, and tests/test_libka0s.lua asserts it on the descriptor rather than on a wrapper.

-- The prefix is passed as a FUNCTION rather than as the value of NS.PREFIX. It reads the same here,
-- where core/Namespace.lua has already run — but the printer is built ONCE at load, and the function
-- form is what keeps a later change to NS.PREFIX from being frozen out of every line.
--
-- No `sep`: NS.PREFIX is "|cff00ffff[BL]|r" with no trailing space of its own, so Core's default
-- single space is exactly what core/Util.lua's `table.concat(parts, " ")` produced.
--
-- No `sink`: Core's default is DEFAULT_CHAT_FRAME:AddMessage, resolved at call time, which is both
-- what the old printer did and what tests/wow_mock.lua captures.
local printer = lib:New({
  prefix = function() return NS.PREFIX end,
})

-- NS.Print and NS.Util.print MUST be the SAME function object, not two wrappers around one printer.
-- AceAddon:NewAddon(NS, …, "AceConsole-3.0") stamps AceConsole's :Print over NS.Print, and
-- core/BankLedger.lua reclaims it by repointing NS.Print at NS.Util.print — which only restores what
-- the five upvalue captures hold because it is the identical object. tests/test_util.lua asserts
-- that identity directly.
NS.Print = printer.Print
Util.print = NS.Print
