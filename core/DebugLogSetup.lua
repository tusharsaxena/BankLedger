local addonName, NS = ...

-- core/DebugLogSetup.lua — wires the addon into LibKa0s-DebugLog-1.0 (debug-logging).
--
-- This replaced modules/DebugLog.lua, which was 357 lines of window, buffer, scrollbar, copy box and
-- enable seam. The two formatters there were already byte-identical to the library's, and the frame
-- globals the descriptor derives from `name` — BankLedgerDebugWindow, BankLedgerDebugCopyWindow —
-- are exactly the names that file hardcoded, so no saved layout and no /framestack habit moves.
--
-- WHAT IS OURS, and it is only ever the CONTENT: which flag says logging is on, what the [Init]
-- summary says, where the chat acknowledgement goes, what the window looks like, and what happens
-- when the library is not installed.
--
-- WHERE THIS FILE SITS: after core/Constants.lua (FONT_MONO is read at :New time) and after
-- core/CoreSetup.lua (NS.LIBKA0S_MISSING). Everything else it touches — NS.Browser's skin and close
-- button, NS.InitSummary, NS.State, NS.Panel — is reached through a CLOSURE and therefore resolved
-- at call time, which is what lets the console move out of modules/ without inverting the dependency
-- it used to have on modules/Browser.lua. tests/test_libka0s.lua pins both orderings.

local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)

if not lib then
  -- Degrade, do not error. The console is a diagnostics harness: the addon's actual job — recording
  -- what moves between your bags and your banks — is completely unaffected by its absence, so every
  -- member the addon calls has to answer, and `/bl debug` has to say something honest rather than
  -- raise. The cause clause is the shared one from core/CoreSetup.lua; only the consequence is ours.
  local UNAVAILABLE = NS.LIBKA0S_MISSING .. ", so the debug console window is unavailable."

  local D = { buffer = {} }
  local function unavailable() NS.Print(UNAVAILABLE) end

  -- Every member reached from settings/Schema.lua's `/bl debug` verb and its state.debugConsole row.
  function D:IsShown() return false end
  function D:Show() unavailable() end
  function D:Hide() end
  function D:Toggle() unavailable() end
  function D:Add() end
  function D:Clear() end
  function D:UpdateScrollBar() end
  function D:UpdateStatus() end
  function D:RefreshHeader() end
  function D:ShowCopy() unavailable() end
  function D:IsEnabled() return not not (NS.State and NS.State.debug) end

  -- The flag still flips. It gates more than the console — settings/Schema.lua's write seam checks
  -- it before tracing — so silently refusing to set it would be a second, invisible behaviour change
  -- on top of a missing window.
  function D:SetEnabled(on)
    on = not not on
    if NS.State then NS.State.debug = on end
    unavailable()
  end

  NS.DebugLog = D
  NS.Debug = function() end
  return
end

NS.DebugLog = lib:New({
  name  = addonName,          -- seeds BankLedgerDebugWindow / …CopyWindow / …CopyScroll
  title = "Bank Ledger",      -- the library appends its own " — Debug"
  font  = NS.Constants.FONT_MONO,

  -- The logging flag is SESSION-ONLY and lives on NS.State, never in SavedVariables: it is off at
  -- every login by design (debug-logging-§5). The library never stores it; it reads and writes it
  -- through this pair, so the slash verb, the settings panel and the window's own header toggle can
  -- never disagree about what it is.
  --
  -- The nil-guard on NS.State has to live HERE. The library's D:IsEnabled is a bare
  -- `not not d.isEnabled()`, so a bare `NS.State.debug` would raise on any call reaching it before
  -- core/State.lua had run.
  isEnabled  = function() return NS.State and NS.State.debug end,
  setEnabled = function(on) if NS.State then NS.State.debug = on end end,

  -- Closures, not captured values, for everything defined in a file that loads after this one.
  -- NS.InitSummary is core/Database.lua's and would be nil at load; NS.Print is already live by now
  -- but is reached the same way so the two read alike.
  print       = function(line) NS.Print(line) end,
  initSummary = function() return NS.InitSummary and NS.InitSummary() end,
  slash       = "/bl",        -- composes the console checkbox tooltip's "/bl debug" reference

  -- Keeps the settings panel's `state.debugConsole` checkbox in step with the window.
  --
  -- The library fires this from the frame's own OnShow/OnHide rather than from D:Show/D:Hide, and
  -- that is a real fix rather than a translation: this window is registered in UISpecialFrames, so
  -- Esc hides it WITHOUT going through D:Hide — and the checkbox has been going stale on every Esc
  -- close since the console was written. P:Refresh already returns early on a panel that is not on
  -- screen, so the one extra callback the library fires during the frame's build-time Hide costs a
  -- table read.
  onVisibilityChanged = function()
    if NS.Panel and NS.Panel.Refresh then NS.Panel:Refresh() end
  end,

  -- ── the chrome ─────────────────────────────────────────────────────────────────────────────
  --
  -- Both of these exist because this addon DECLINES Core's window chrome (docs/pending/LEDGER.md,
  -- LIBKA0S-05): Core.SKIN is a 12px UI-Tooltip-Border where every Bank Ledger window wears a flat
  -- 1px WHITE8X8 double border with a synthesised inner border, a gold title and a grey divider, and
  -- Core.MakeCloseButton is an 18×18 fixed-red × where ours is 24×24 and takes the player's CLASS
  -- COLOUR on hover. Taking either would leave the console as the one window in the addon that looks
  -- like a different addon.
  --
  -- `skin` — a table — reaches only the backdrop, its colour and its border colour. The inner-border
  -- child frame, the title tint and the divider tint are calls, so they need a function. Both fields
  -- were added upstream at DebugLog minor 4 for exactly this; they are not local workarounds.
  --
  -- Resolved through NS.Browser at CALL time. Both fire during the console's lazy first build, long
  -- after every file has loaded, which is the only reason a core/ file may reach a modules/ member —
  -- hoisting either lookup to a load-time local would reintroduce the ordering hazard and silently
  -- leave the console unskinned.
  applySkin = function(frame)
    if NS.Browser and NS.Browser.ApplySkin then NS.Browser:ApplySkin(frame) end
  end,

  makeCloseButton = function(parent, onClick)
    if NS.Browser and NS.Browser.MakeCloseButton then
      return NS.Browser:MakeCloseButton(parent, onClick)
    end
    -- Nil is a legitimate answer — Core's own factory returns it where CreateFrame is unavailable,
    -- and the library builds the title bar without an × rather than failing.
    return nil
  end,

  -- No `L`. This addon translates none of the console's strings, and handing a descriptor an
  -- addon-wide locale table is the one mistake that renders every label as its own key at once.
  -- No `safeToString` either: Core's is already what NS.SafeToString is.
})

-- The global debug sink, republished under the name all 29 call sites already use. A plain dot
-- function on the instance, so it needs no self and binds bare.
NS.Debug = NS.DebugLog.Debug
