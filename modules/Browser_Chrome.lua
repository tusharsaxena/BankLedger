local _, NS = ...
NS.Browser = NS.Browser or {}
local B = NS.Browser

-- The ledger window's chrome: the skin edge and the close control all three of this addon's windows
-- wear, and the ledger window's own position/size persistence. Peeled out of modules/Browser.lua on
-- the seam its watch-list row named (docs/automated-tests/RESULTS.md), when that file climbed to 1323
-- of layout-§1's 1500 lines. A MOVE, not a rewrite: every B method keeps its name and behavior. The
-- `frame` these read was Browser.lua's file local and comes through the public B:GetWindow().

-- Wear the skin's window edge: the skin's Shell (NS.Skin.Shell, LibKa0s-Skin-1.0), which on Ka0s
-- Default is the Core.ApplySkin call this made before the skin engine, object for object (the
-- WHITE8x8 backdrop, the fill, the black border, the inner rule, the title's gold), and the
-- player's skin otherwise. The frame is recorded for this addon's owner, so a skin switch repaints
-- it live. `opts` is Shell's: `noTopBar` for a window whose title bar paints its own fill (each
-- window here calls NS.Skin.TitleBar on its bar, the rollout's D6). Degraded, NS.Skin.Shell is
-- core/SkinSetup.lua's, which routes to core/CoreSetup.lua's pre-library NS.ApplySkin. Shared by the
-- ledger window, the session window and the export modal.
function B:ApplySkin(f, opts)
  if NS.Skin then NS.Skin.Shell(f, opts) elseif NS.ApplySkin then NS.ApplySkin(f) end
end

-- The close control every window this addon draws wears: the collection's `close` mark where the
-- shared art is there, and the thin × glyph it has always drawn where it is not. The skin's
-- close.rest at rest and close.hot on hover, either way (BL-A1). Shared by the ledger window (Browser.lua),
-- the session window (SessionWindow.lua) and the export modal (Export.lua); the export COPY window
-- is LibKa0s-Widgets-1.0's CopyWindow and wears the library's close. NOT by the debug
-- console: that is the LIBRARY's window and wears Core's own 18x18 close — the edge is shared
-- across every Ka0s window, but the close control on a library-drawn window is the library's
-- (standalone-windows). The library draws that one for itself, once core/DebugLogSetup.lua hands it
-- `addonName`; this addon publishes NO wrapper onto `lib.MakeCloseButton`, and the paragraph headed
-- "IS DELIBERATELY NOT REPUBLISHED" in core/CoreSetup.lua says why it must not grow one.
--
-- TWO RUNGS, AND THE LOWER ONE STAYS. NS.Icon answers nil twice over — no LibKa0s at all, or a
-- catalog that no longer carries "close" — and both mean the same thing here: draw the ×. A
-- degraded install keeps a close button that works and looks exactly as it did before the mark
-- existed. Nothing below builds a path by concatenation to route around the nil, because a
-- plausible path to art that is not there is a title bar with no visible way out of it.
--
-- The art ships WHITE so a multiply lands wherever the caller asks.
--
-- THE SKIN (BL-A1, the owner's ruling: one close control across every Ka0s addon and skin). The
-- button is handed to the skin's CloseButton primitive the way every other Ka0s close control is:
-- no opts, and no hover scripts of the host's own to fight it. The primitive tints the art
-- from `close.rest`, hooks the hover pair (`close.hot` under the pointer, `close.rest` after it) and
-- repaints on a skin switch, in every skin including Ka0s Default (its gray, and its red on hover).
-- What stays the host's is the 24x24 size and this addon's own art lookup (standalone-windows).
-- Degraded, core/SkinSetup.lua's facade draws the same pair from its host copy of Ka0s Default.
function B:MakeCloseButton(parent, onClick)
  local close = CreateFrame("Button", nil, parent)
  close:SetSize(24, 24)

  local path = NS.Icon and NS.Icon("close")
  if path then
    local art = close:CreateTexture(nil, "OVERLAY")
    art:SetPoint("CENTER")
    art:SetSize(12, 12)
    art:SetTexture(path)
    close.icon = art
  else
    local x = close:CreateFontString(nil, "OVERLAY")
    x:SetFont(STANDARD_TEXT_FONT, 24, "")
    -- The stock face and size first, then the skin's face over them (its size scaled from the 24),
    -- so even this fallback follows a skin switch rather than keeping a typed face.
    NS.Skin.Font(x)
    x:SetPoint("CENTER", close, "CENTER", 0, 2)   -- the × sits low in its font box; nudge it up
    x:SetText("\195\151")
    close.glyph = x
  end

  close:SetScript("OnClick", onClick)
  -- The art is in place first: the primitive reaches it through close.icon / close.glyph.
  NS.Skin.CloseButton(close)
  return close
end

-- ── Window position/size persistence ──────────────────────────────────────────
-- settings.window = { point, x, y, w, h } relative to UIParent. Window geometry is runtime view
-- state, deliberately NOT a Schema row — an architecture-§5 carve-out written directly here
-- (standalone-windows requires it be persisted; it has no place in the settings panel).

-- WHEN the save runs matters as much as what it writes, and the obvious answer is wrong. Saving only
-- at the end of a drag or a resize means the geometry can live purely in the frame — which outlives
-- every Hide/Show, so it looks perfectly persistent for a whole game session and is gone on the
-- first /reload. The resize case is the easy one to miss: releasing the grip a pixel outside a 16×16
-- button never delivers its OnMouseUp. So the save is also anchored to moments that are GUARANTEED —
-- every OnHide, and PLAYER_LOGOUT for a /reload with the window still on screen, where OnHide never
-- runs. The interaction handlers stay; they cost nothing and keep the stored value current.
-- modules/SessionWindow.lua does exactly the same, through the same two method names.

function B:SaveGeometry()
  local frame = B:GetWindow()
  if not frame then return false end
  local settings = NS.db and NS.db.profile and NS.db.profile.settings
  if not settings then return false end
  local point, _, _, x, y = frame:GetPoint(1)
  -- A frame with no anchor has nothing worth saving, and a point-less table would make
  -- ApplyGeometry fall through to the default and silently discard the real position.
  if not point then return false end
  settings.window = {
    point = point, x = x or 0, y = y or 0,
    w = frame:GetWidth(), h = frame:GetHeight(),
  }
  return true
end

function B:ApplyGeometry()
  local frame = B:GetWindow()
  if not frame then return end
  local w = NS.db and NS.db.profile.settings.window
  frame:ClearAllPoints()
  if w and w.point then
    frame:SetPoint(w.point, UIParent, w.point, w.x or 0, w.y or 0)
    -- Clamped on the way in as well as on the way out, so a size saved against an older column set
    -- (or a hand-edited SavedVariables) cannot reopen the window too small to read.
    if type(w.w) == "number" and type(w.h) == "number" then
      frame:SetSize(math.max(self._minW or 0, w.w), math.max(self._minH or 0, w.h))
    end
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

-- Persist at logout, the one teardown path that does not run OnHide.
function B:OnLogout()
  self:SaveGeometry()
end

-- Reset the persisted geometry and recenter the live frame. Three routes reach it: "Reset position"
-- and the General page's Defaults (both via NS.Util.ResetWindowPositions), and Sl:ResetEverything.
function B:ResetWindow()
  local frame = B:GetWindow()
  if NS.db and NS.db.profile and NS.db.profile.settings then
    NS.db.profile.settings.window = {}
  end
  if frame then
    frame:ClearAllPoints()
    self:ApplyGeometry()
  end
end
