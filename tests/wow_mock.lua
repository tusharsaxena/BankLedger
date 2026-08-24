-- Ka0s Bank Ledger's half of the WoW-API mock, layered over the shared base in tests/_kit.
--
-- The base (tests/_kit/mock_base.lua) owns everything the whole collection touches: LibStub with a
-- REAL NewLibrary — which is what lets the vendored LibKa0s majors register headlessly exactly as
-- they do in the client — plus the Ace fakes, the settings-canvas registry, the timer queue and the
-- generic frame stub. This file owns what is genuinely Bank Ledger's: the bag/bank container model,
-- the guild bank, the item database, and the handful of base behaviors whose fidelity this addon
-- needs to be different.
--
-- Plain per-key overwrite, per the kit's README: the base builder hands back a fresh table on every
-- call, so there is no merge machinery to reason about.
--
-- ── THE OVERRIDES, AND WHY EACH ONE IS NOT A KIT GAP ──────────────────────────────────────────
--
-- Every override below replaces a base behavior with a STRICTER one that an existing Bank Ledger
-- suite depends on. None of them is the base being wrong — the base's own header states the policy
-- (single-consumer fidelity lives in the consumer's extender) — so none is a finding to take
-- upstream. They are listed here so a future re-vendor can tell an intentional divergence from a
-- drift:
--
--   1. stubFrame        — the base returns 0 from GetWidth/GetHeight and defines no SetPoint at all.
--                         Window geometry here round-trips through SavedVariables, so the position
--                         and size have to be real state or the persistence is untestable. The base
--                         also never fires OnHide, and "the session window closes with the bank
--                         frame" is exactly an OnHide assertion. It also RECORDS SetTexture,
--                         SetTextInsets and SetText/GetText, because a mark is a PATH beside a
--                         LABEL and a no-op setter makes the one failure mode that draws nothing
--                         and raises nothing unobservable.
--   2. __shown = true   — the base starts frames hidden; real frames start shown, and nine IsShown
--                         assertions in tests/test_sessionwindow.lua read the difference.
--   3. __fireTimers     — the base's returns nothing and its CancelTimer is a no-op. The capture
--                         engine's debounce is asserted as "three events, ONE reconcile pass" and
--                         "the pending timer was canceled", which needs both a count and honored
--                         cancellation.
--   4. AceAddon         — RegisterEvent must RAISE for a name in __badEvents. Modern retail rejects
--                         a retired event name outright, and that failure mode once unregistered
--                         this whole addon; a mock that accepted everything would hide it.
--   5. AceDB            — the base models profiles because its other consumers switch them. This is
--                         an account-wide addon created with defaultProfile = true, and its own
--                         suite asserts against a fixed "Default", so the simpler stub is kept.
--   6. __settingsPanels — the base splits the canvas registry into __mainPanel and __subcategories.
--                         tests/test_panel.lua reaches BOTH through one name-keyed table and calls
--                         GetID() on both returns.
--   7. DEFAULT_CHAT_FRAME — a plain table, not a frame stub. The four captureChat helpers save and
--                         restore `.AddMessage`; against a stub frame the saved value is a
--                         metatable-generated closure and restoring it rawsets a permanent field.
--   8. AceGUI           — TAKEN from the base, not overridden. It was an inert `Create -> nil`
--                         stub until LibKa0s-Options-1.0 was adopted; the base's real widget
--                         factory is what makes the schema -> widget -> write path drivable at all.
--                         Confirmed behavior-neutral before the swap: the addon called
--                         AceGUI:Create zero times during the suite, so no existing case changed.
--   9. StaticPopup_Show — the base defines it, which flips settings/Schema.lua's and
--                         settings/Panel.lua's `if type(StaticPopup_Show) == "function"` guards from
--                         the direct-call path to the popup path. That IS the in-game path and is
--                         worth taking, but it is a test-semantics change that belongs with the
--                         Slash/Options work rather than smuggled into a harness swap.
--  10. GameTooltip      — same argument: the base defines it and seven `if GameTooltip then` guards
--                         change branch. Left nil here so this swap is behavior-neutral.

local base = dofile("tests/_kit/mock_base.lua")

-- ── Override 1: the frame stub ────────────────────────────────────────────────────────────────
-- A universal frame stub: any method call is a no-op that returns the frame itself. WoW frame API
-- methods are always PascalCase (SetPoint, CreateTexture, HookScript, …), so only those keys get a
-- no-op function; any other (lowercase/custom) field access misses through to nil, letting addon
-- code do `if not f.someCustomField then f.someCustomField = ... end` safely.
--
-- VISIBILITY is the one piece of frame state the stub really models. A blanket no-op makes
-- IsShown() return the frame — permanently truthy — so "the window closed" is untestable and a
-- window that never hides looks identical to one that does. Real frames start shown, and Show /
-- Hide / SetShown flip that flag, so the stub does too.
-- GEOMETRY is the other piece of real state. Window position and size are persisted to
-- SavedVariables and restored on the next login, and a blanket no-op makes that round trip
-- untestable: GetPoint() would hand back the frame itself, so "we saved the position" and "we saved
-- a garbage table" look identical. SetPoint's overloads are modeled because addon code uses both
-- the (point, x, y) and (point, relativeTo, relativePoint, x, y) forms.
local function recordPoint(point, ...)
  local a, b, c, d = ...
  if type(a) == "number" or a == nil then
    -- (point) or (point, x, y)
    return { point = point, relativeTo = nil, relativePoint = point, x = a or 0, y = b or 0 }
  end
  -- (point, relativeTo, relativePoint[, x, y])
  return { point = point, relativeTo = a, relativePoint = b or point, x = c or 0, y = d or 0 }
end

-- Method name → a FACTORY that binds the method to one frame. Module-level, built once at load, so
-- the resolver is a single hash lookup rather than a chain of fourteen string comparisons. The
-- allocation is unchanged from the chain it replaces: one closure per property access.
--
-- Deliberately NOT memoized onto the frame: a suite that replaces a method on an instance would
-- otherwise see different behavior from one that does not, and several of them poke at these stubs
-- directly.
local FRAME_METHODS = {}

FRAME_METHODS.Show = function(f) return function() f.__shown = true; return f end end

FRAME_METHODS.Hide = function(f)
  return function()
    local was = f.__shown
    f.__shown = false
    -- Real frames run their OnHide when they actually go from shown to hidden.
    if was and f.__onHide then
      for _, fn in ipairs(f.__onHide) do fn(f) end
    end
    return f
  end
end

FRAME_METHODS.SetShown = function(f)
  return function(_, v) if v then f:Show() else f:Hide() end; return f end
end

-- IsShown and IsVisible share ONE factory, exactly as they shared one arm.
local isShownFactory = function(f) return function() return f.__shown end end
FRAME_METHODS.IsShown = isShownFactory
FRAME_METHODS.IsVisible = isShownFactory

-- Scripts are RECORDED and firable. They were not, until LibKa0s-Options-1.0 was adopted: the
-- library declares a page's body through `panel:SetScript("OnShow", ...)`, and a stub that
-- discarded the handler left every page body unreachable from the suite — which is exactly how
-- a settings panel ships blank and green. __onHide is kept alongside, because Hide() fires it
-- on a real shown->hidden transition and several session-window cases depend on that.
FRAME_METHODS.SetScript = function(f)
  return function(_, script, handler) f.__scripts[script] = handler; return f end
end

FRAME_METHODS.GetScript = function(f)
  return function(_, script) return f.__scripts[script] end
end

FRAME_METHODS.__fire = function(f)
  return function(_, script, ...)
    local fn = f.__scripts[script]
    if fn then return fn(f, ...) end
  end
end

FRAME_METHODS.HookScript = function(f)
  return function(_, script, handler)
    if script == "OnHide" then
      f.__onHide = f.__onHide or {}
      f.__onHide[#f.__onHide + 1] = handler
    end
    local prev = f.__scripts[script]
    f.__scripts[script] = function(...)
      if prev then prev(...) end
      return handler(...)
    end
    return f
  end
end

FRAME_METHODS.SetPoint = function(f)
  return function(_, point, ...) f.__points[#f.__points + 1] = recordPoint(point, ...); return f end
end

FRAME_METHODS.ClearAllPoints = function(f)
  return function() f.__points = {}; return f end
end

FRAME_METHODS.GetPoint = function(f)
  return function(_, i)
    local p = f.__points[i or 1]
    if not p then return nil end
    return p.point, p.relativeTo, p.relativePoint, p.x, p.y
  end
end

FRAME_METHODS.SetSize = function(f) return function(_, w, h) f.__w, f.__h = w, h; return f end end
FRAME_METHODS.SetWidth = function(f) return function(_, w) f.__w = w; return f end end
FRAME_METHODS.SetHeight = function(f) return function(_, h) f.__h = h; return f end end
FRAME_METHODS.GetWidth = function(f) return function() return f.__w end end
FRAME_METHODS.GetHeight = function(f) return function() return f.__h end end

-- Forward declaration: both CreateFontString and CreateTexture below mint one of these.
local stubFrame

-- A FONTSTRING IS ITS OWN WIDGET, and it carries the client's font rule. It used to resolve to the
-- frame itself through the catch-all, which was conceded in this comment's predecessor as "fine for
-- the geometry the tests exercise" and was not: a pooled menu row's LABEL and its GLYPH are two
-- FontStrings on one button, and answered with the button they were one object carrying one font —
-- so a glyph that never had a face of its own was indistinguishable from one that did, which is
-- exactly the defect LibKa0s-Widgets-1.0's glyphFont precondition is about. CreateTexture was given
-- its own stub for this same class of reason; see the note above it.
--
-- Its own object also means the client's SetText rule can exist at all (see FRAME_METHODS.SetText):
-- a FontString with no font raises, and that is the crash LibKa0s v1.11.0/v1.11.1 shipped.
--
-- The FONT TEMPLATE is still recorded ON THE PARENT, in creation order, because "every card shares
-- one headline template" is a real invariant that tests/test_insights.lua reads back — and it is
-- also recorded on the FontString itself, because a template IS a font as far as SetText cares.
--
-- ../LibKa0s/tests/test_widgets.lua's geomFrame is the reference implementation.
FRAME_METHODS.CreateFontString = function(f)
  return function(_, _, _, template)
    f.__fontTemplates = f.__fontTemplates or {}
    f.__fontTemplates[#f.__fontTemplates + 1] = template
    local fs = stubFrame()
    fs.__objectType = "FontString"
    fs.__template   = template
    return fs
  end
end

-- A TEXTURE IS ITS OWN WIDGET, not its parent under another name. The catch-all below would answer
-- CreateTexture with the frame itself, and that was harmless right up until a library sized a
-- button and then sized the ART INSIDE it: `b:SetSize(18,18)` followed by `tex:SetSize(12,12)`
-- left the BUTTON measuring 12, and every offset derived from `close:GetWidth()` came out wrong
-- while looking perfectly plausible. Geometry is modeled state here (see above), so a texture
-- gets its own stub and the arithmetic the library actually runs is the arithmetic measured.
-- A FontString gets its own stub for the same reason, one factory up.
FRAME_METHODS.CreateTexture = function() return function() return stubFrame() end end

-- A TEXTURE PATH IS THE WHOLE POINT OF A MARK, and a mark resolved to the wrong path draws nothing
-- and raises nothing — which is the one failure the mark suite exists to catch out of game. So
-- SetTexture is RECORDED rather than no-opped (fidelity rule 3): tests/test_marks.lua reads
-- `__texture` back to prove the shared art arrived, extensionless, and that an install without
-- LibKa0s still got the Blizzard rung it always had. SetTextInsets is recorded for the same reason:
-- the search box's left inset is what moves to make room for the magnifier, and it has to NOT move
-- when there is no magnifier.
FRAME_METHODS.SetTexture = function(f)
  return function(_, path) f.__texture = path; return f end
end
FRAME_METHODS.SetTextInsets = function(f)
  return function(_, l, r, t, b) f.__insets = { l, r, t, b }; return f end
end

-- THE WORDS ARE RECORDED FOR THE SAME REASON THE PATH IS (fidelity rule 3). A BESIDE button is a
-- mark AND a label, and the label is the half no other recorder can reach: the catch-all answered
-- `GetText` with the frame itself, so a call site that passed "" for its text was a wordless glyph
-- button — and, on an install without LibKa0s, a completely empty one — that every suite here read
-- as green. Real widgets answer GetText with the string, so this is the more faithful stub as well
-- as the useful one.
--
-- AND A FONTSTRING WITH NO FONT RAISES, exactly as the client does. A bare `CreateFontString()`
-- followed by `SetText` answers `FontString:SetText(): Font not set` in game and took a consuming
-- addon down at BuildFrame for two LibKa0s releases while every headless case passed, because a
-- recorder is happy to store a string. The check keys on `__font or __template`, because a
-- FontString built FROM a template already has a face — a bare one is the case worth catching.
FRAME_METHODS.SetText = function(f)
  return function(_, v)
    if f.__objectType == "FontString" and not (f.__font or f.__template) then
      error("FontString:SetText(): Font not set", 2)
    end
    f.__text = v
    return f
  end
end
FRAME_METHODS.GetText = function(f)
  return function() return f.__text end
end

-- The face a FontString was given, recorded — it is what rescues a bare one from the rule above,
-- and LibKa0s-Widgets-1.0 re-sets the glyph face on every paint precisely because the row pool is
-- shared across addons, so which face a glyph is wearing is a fact worth being able to read back.
FRAME_METHODS.SetFont = function(f)
  return function(_, path, size, flags) f.__font = { path, size, flags }; return f end
end

-- A PROPORTIONAL-ISH 6px a character, so width arithmetic has real numbers to run on. The catch-all
-- answered this with the frame, and LibKa0s-Widgets-1.0's menuWidth does
-- `(measure:GetStringWidth() or 0) + pad` — adding a number to a table. Same rule as geomFrame's.
FRAME_METHODS.GetStringWidth = function(f)
  return function() return #(f.__text or "") * 6 end
end

function stubFrame()
  local f = { __shown = true, __points = {}, __w = 0, __h = 0, __scripts = {} }
  setmetatable(f, { __index = function(_, k)
    -- The table lookup comes FIRST: a named method always wins over the catch-all, or IsShown would
    -- resolve to the no-op and be permanently truthy.
    local factory = FRAME_METHODS[k]
    if factory then return factory(f) end
    if type(k) == "string" and k:match("^%u") then
      return function() return f end
    end
    return nil
  end })
  return f
end

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepcopy(v) end
  return r
end

return function()
  local M = base()

  -- Overrides 1 and 2. __stubFrame is re-pointed too, so anything the addon's own suites build with
  -- it gets the geometry-modeling stub rather than the base's.
  M.__stubFrame = stubFrame
  M.UIParent    = stubFrame()
  M.CreateFrame = function() return stubFrame() end

  -- The client's own default font, which every Ka0s fallback ladder ends on. Absent from the kit's
  -- base because nothing needed it until core/Constants.lua stopped naming a font file of its own:
  -- FONT_MONO now resolves through the LibKa0s-Media seam and lands HERE when the library is not
  -- installed. A nil here would let a degraded install hand SetFont nothing while the suite that is
  -- supposed to notice reported the fallback working. The exact bytes are the real client's.
  --
  -- ON THIS TABLE ONLY, never on the real `_G`. Every reader in this addon spells the global BARE
  -- (core/Constants.lua, modules/Browser.lua's degraded close rung), which the loader's sandbox
  -- resolves through here — so writing it process-wide would leak one mock's font into every suite
  -- that runs after it, and a case built on mocks WITHOUT a client font would silently still see
  -- this value and report a pass. Same reason core/Compat.lua reads GuildBankFrame bare.
  M.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

  -- Override 10: left nil so the seven `if GameTooltip then` guards keep taking the headless path.
  M.GameTooltip = nil
  -- Override 9: left nil so the five `if type(StaticPopup_Show) == "function"` guards keep taking
  -- the direct-call path.
  M.StaticPopup_Show = nil

  -- time / misc. A FIXED clock, not the base's os.time: the ledger suites advance __now by hand and
  -- assert on exact retention windows, which a wall clock would make flaky.
  M.__now = 1770000000
  M.time = function() return M.__now end
  M.date = os.date
  M.GetTime = function() return M.__now end

  -- player / world
  M.UnitName = function() return "Mock" end
  M.UnitClass = function() return "Mage", "MAGE", 8 end
  M.GetRealmName = function() return "Realm" end
  M.GetNormalizedRealmName = function() return "Realm" end
  M.GetZoneText = function() return "Testville" end
  M.GetSubZoneText = function() return "The Vault" end
  M.InCombatLockdown = function() return false end
  M.C_Map = { GetBestMapForUnit = function() return 2657 end }
  M.GetGuildInfo = function() return "Ka0s" end

  -- Carried money, in copper. Tests set M.__money directly.
  M.__money = 1000000
  M.GetMoney = function() return M.__money end

  -- Bag index enum, reproduced VERBATIM from a live 12.0.7 client (all 20 members, exact ids).
  -- Mock fidelity is load-bearing here: the container groups are derived from these names, and an
  -- idealized enum would have hidden the real defect — that `AccountBankTab_1` is 12, one past the
  -- character-bank range, so a numeric guess put warband tab 1 inside the character bank.
  --
  -- Note `Characterbanktab` / `Accountbanktab`: those are *type* constants sharing the enum with
  -- the real container members, and they must never be matched as containers.
  M.Enum = {
    BagIndex = {
      Accountbanktab = -3, Characterbanktab = -2, Keyring = -1,
      Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5,
      CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, CharacterBankTab_3 = 8,
      CharacterBankTab_4 = 9, CharacterBankTab_5 = 10, CharacterBankTab_6 = 11,
      AccountBankTab_1 = 12, AccountBankTab_2 = 13, AccountBankTab_3 = 14,
      AccountBankTab_4 = 15, AccountBankTab_5 = 16,
    },
    -- Verbatim from the same live client. Account=2 is the warband bank; the ids are NOT sequential
    -- with any other enum here, so they must be read by name, never assumed.
    BankType = { Character = 0, Guild = 1, Account = 2 },
  }

  -- Fake container inventory: M.__containers[bagID] = { [slot] = { itemID, link, count } }.
  -- Tests write straight into it and call the scanner. An absent bag has 0 slots.
  M.__containers = {}
  M.C_Container = {
    GetContainerNumSlots = function(bagID)
      local bag = M.__containers[bagID]
      if not bag then return 0 end
      return bag.slots or #bag
    end,
    GetContainerItemInfo = function(bagID, slot)
      local bag = M.__containers[bagID]
      local s = bag and bag[slot]
      if not s then return nil end
      return { itemID = s.itemID, hyperlink = s.link, stackCount = s.count }
    end,
  }

  -- Guild bank. Tabs hold data only once QUERIED, exactly like the live API: an unqueried tab
  -- returns nil from GetGuildBankItemLink no matter what is in it. A mock that handed out contents
  -- unconditionally would hide the missing QueryGuildBankTab call entirely.
  M.__guildTabs = { [1] = { [1] = { itemID = 2589, count = 5 } } }
  M.__guildQueried = {}
  M.__guildQueryCount = 0
  M.GetNumGuildBankTabs = function() return 8 end
  M.GetCurrentGuildBankTab = function() return 1 end
  M.QueryGuildBankTab = function(tab)
    M.__guildQueried[tab] = true
    M.__guildQueryCount = M.__guildQueryCount + 1
  end
  M.GetGuildBankItemLink = function(tab, slot)
    if not M.__guildQueried[tab] then return nil end
    local s2 = M.__guildTabs[tab] and M.__guildTabs[tab][slot]
    if not s2 then return nil end
    return "|cffffffff|Hitem:" .. s2.itemID .. "::::::::::|h[Item]|h|r"
  end
  M.GetGuildBankItemInfo = function(tab, slot)
    local s2 = M.__guildTabs[tab] and M.__guildTabs[tab][slot]
    if not s2 then return nil end
    return "texture", s2.count
  end
  M.MAX_GUILDBANK_SLOTS_PER_TAB = 98
  -- The guild-bank window. Tests set __guildVisible to nil to model a build where the frame cannot
  -- be found at all, which must NOT be read as "hidden".
  --
  -- It accepts an OnHide hook, because that is the ONLY notice the client gives that the guild bank
  -- has closed: GUILDBANKFRAME_CLOSED registers fine and never fires on 12.0.7, the same as its
  -- _OPENED sibling. __closeGuildBank() closes it the way the client does — hide the frame, then run
  -- the hooks — so a test can prove the addon notices.
  M.__guildVisible = true
  M.__guildHideHooks = {}
  M.GuildBankFrame = setmetatable({
    HookScript = function(_, script, handler)
      if script == "OnHide" then M.__guildHideHooks[#M.__guildHideHooks + 1] = handler end
    end,
  }, { __index = function(_, k)
    if k == "IsVisible" then return function() return M.__guildVisible end end
    return nil
  end })
  M.__closeGuildBank = function()
    M.__guildVisible = false
    for _, fn in ipairs(M.__guildHideHooks) do fn(M.GuildBankFrame) end
  end

  -- Coin held BY a store. Reproduced from a live 12.0.7 `/bl debug scan` at a bank and at a guild
  -- bank, and the fidelity that matters is the FAILURE mode: with the guild bank closed
  -- GetGuildBankMoney() returns **0**, not nil. A mock that returned nil there would hide the whole
  -- defect — a closed-then-open transition would read as a 6,553g deposit appearing from nowhere.
  -- C_Bank.FetchDepositedMoney is not frame-bound: it reported the same figure in both sessions.
  M.__guildBankMoney = 65537936844
  M.GetGuildBankMoney = function()
    if not M.__guildVisible then return 0 end
    return M.__guildBankMoney
  end
  M.__warbandMoney = 16348260386
  M.__characterBankMoney = 0
  M.C_Bank = {
    FetchDepositedMoney = function(bankType)
      if bankType == M.Enum.BankType.Account then return M.__warbandMoney end
      if bankType == M.Enum.BankType.Character then return M.__characterBankMoney end
      return nil
    end,
  }

  -- Item database: M.__items[itemID] = { name, quality, itemType, itemSubType, vendorPrice }.
  M.__items = {
    [2589]  = { "Linen Cloth",      1, "Tradegoods", "Cloth",  20 },
    [171276]= { "Spectral Flask",   3, "Consumable", "Flask",  5000 },
    [4306]  = { "Silk Cloth",       1, "Tradegoods", "Cloth",  60 },
    [19019] = { "Thunderfury",      5, "Weapon",     "Swords", 250000 },
  }
  -- Bonus-ID variants: M.__itemVariants[<full link>] = { name, quality, itemType, itemSubType,
  -- vendorPrice }, in the same shape as __items. This is what makes the mock able to tell a LINK
  -- from the id inside it — the live client answers GetItemInfo(itemID) with the base item and
  -- GetItemInfo(link) with the variant the bonus IDs describe, so a mock that resolves both to the
  -- same row cannot fail a caller that re-derives from the id.
  M.__itemVariants = {}
  M.C_Item = {
    GetItemInfo = function(idOrLink)
      local variant = type(idOrLink) == "string" and M.__itemVariants[idOrLink]
      local id = tonumber(idOrLink) or tonumber(tostring(idOrLink):match("|?H?item:(%d+)") or "")
      local it = variant or (id and M.__items[id])
      if not it then return nil end
      -- A variant answers with the link it was asked about; a bare id can only build the base link.
      local link = variant and idOrLink
        or ("|cffffffff|Hitem:" .. id .. "::::::::::|h[" .. it[1] .. "]|h|r")
      return it[1], link, it[2], 1, 1, it[3], it[4], 1, "", 0, it[5]
    end,
    GetItemInfoInstant = function(idOrLink)
      local id = tonumber(idOrLink) or tonumber(tostring(idOrLink):match("|?H?item:(%d+)") or "")
      return id
    end,
    -- Records what was asked for. An addon that SKIPS an uncached item must also ask the client to
    -- cache it, or that id stays unjudgeable forever and is skipped again on every future move.
    RequestLoadItemDataByID = function(id) M.__loadRequests[id] = true end,
  }
  M.__loadRequests = {}

  -- strings / helpers
  M.ITEM_QUALITY_COLORS = setmetatable({}, {
    __index = function() return { r = 1, g = 1, b = 1, hex = "ffffffff" } end,
  })
  -- The base declines strsplit/strtrim on the grounds that no consumer calls them. This one does,
  -- and it is declared in .luacheckrc read_globals.
  M.strtrim = function(s) return (tostring(s):gsub("^%s*(.-)%s*$", "%1")) end
  -- Class-icon sheet slices (left, right, top, bottom as fractions), for Util.ClassIconMarkup. Two
  -- real classes are enough to prove the coordinate math and the unknown-class fallback.
  M.CLASS_ICON_TCOORDS = {
    MAGE  = { 0.25, 0.49609375, 0.25, 0.5 },
    ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
  }

  -- UI
  M.UISpecialFrames = {}
  -- FauxScrollFrame virtualizer. The pooled tables (History and the session window) call these on
  -- every bind, so a headless build that lacks them cannot render a row at all. Offset 0 = the top
  -- of the list, which is what a freshly-opened window shows.
  M.FauxScrollFrame_Update = function() end
  M.FauxScrollFrame_GetOffset = function() return 0 end
  M.FauxScrollFrame_OnVerticalScroll = function() end
  M.IsShiftKeyDown = function() return false end
  -- Override 7. Chat sink for NS.Print. No-op by default; tests override AddMessage to capture, and
  -- a plain table keeps that save/replace/restore idiom exactly idempotent.
  M.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
  -- Override 6. Every canvas frame handed to the Settings framework, keyed by the name it was
  -- registered under. options-ui-§1 makes the frame's OnCommit/OnDefault/OnRefresh a contract with
  -- Blizzard, and the only way to assert on a contract is to keep what was actually handed over.
  M.__settingsPanels = {}
  M.Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
      M.__settingsPanels[name] = panel
      return { GetID = function() return 1 end }
    end,
    RegisterCanvasLayoutSubcategory = function(_, panel, name)
      M.__settingsPanels[name] = panel
      return { GetID = function() return 2 end }
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
  }
  M.StaticPopupDialogs = {}

  -- Event names this fake client rejects, mirroring a build that has retired them.
  M.__badEvents = {}

  -- Override 3. Pending AceTimer callbacks. __fireTimers runs every timer that is still live and
  -- returns how many fired, so a test can prove that N rapid events produce exactly one reconcile
  -- pass. C_Timer.After is a no-op here: the retention-cleanup deferral must NOT run inside the
  -- suites, which seed history directly.
  M.__timers = {}
  M.__fireTimers = function()
    local due = M.__timers
    M.__timers = {}
    local fired = 0
    for _, handle in ipairs(due) do
      if not handle.canceled then
        fired = fired + 1
        handle.callback()
      end
    end
    return fired
  end
  M.C_Timer = { After = function() end }

  -- ── the Ace fakes ────────────────────────────────────────────────────────────────────────────
  -- Registered through M.__libs, the seam the base exposes for exactly this, so the base's LibStub
  -- (with its real NewLibrary and its strict silent flag) is kept intact.
  local libs = M.__libs

  -- Override 5. Account-wide addon: created in-game with defaultProfile = true, so the profile is
  -- always the fixed "Default". The base models a full profile surface for hosts that switch
  -- profiles; this one never does, and its suite asserts against that fixed name.
  libs["AceDB-3.0"] = {
    New = function(_, _name, defaults)
      return {
        global = deepcopy(defaults and defaults.global or {}),
        profile = deepcopy(defaults and defaults.profile or {}),
        GetCurrentProfile = function() return "Default" end,
      }
    end,
  }

  -- Override 11. AceGUI's container widgets carry SetTitle; the kit's widget mock does not model it,
  -- and its widgets have no metatable, so the call RAISES rather than no-opping. settings/Panel.lua
  -- titles the store grid's InlineGroup that way. Kept HERE rather than taken upstream because the
  -- kit's own policy is that an API only one addon calls belongs in that addon's extender — and a
  -- repo-wide grep says this is the only SetTitle in the collection.
  --
  -- Wrapped rather than replaced: the base's factory does the real work, and this adds the one
  -- member on top, so a widget kind the base grows later still arrives fully formed.
  -- Override 12. `LibStub.minors`, the PUBLIC major -> minor map the real LibStub keeps.
  -- settings/Panel.lua's `/bl debug panel` dump reads it to name which copy of AceGUI actually
  -- served the widgets. The kit's LibStub keeps its minors in a LOCAL and hands them back from
  -- GetLibrary, so the field itself does not exist there and the dump could only ever print nil
  -- headlessly — which is why that case could assert the line's SHAPE and never its value.
  -- Seeded with the fake AceGUI's minor, because the kit installs AceGUI into __libs directly
  -- rather than through NewLibrary, and kept current for every major that DOES register, so the
  -- field means here what it means in the client.
  M.ACEGUI_MINOR = 41
  M.LibStub.minors = { ["AceGUI-3.0"] = M.ACEGUI_MINOR }
  local baseNewLibrary = M.LibStub.NewLibrary
  M.LibStub.NewLibrary = function(self, major, minor)
    local lib, registered = baseNewLibrary(self, major, minor)
    if registered then M.LibStub.minors[major] = registered end
    return lib, registered
  end

  local baseCreate = libs["AceGUI-3.0"].Create
  libs["AceGUI-3.0"].Create = function(self, wtype)
    local w = baseCreate(self, wtype)
    if w and not w.SetTitle then
      function w:SetTitle(v) self.titleText = v; return self end
    end
    return w
  end

  -- Message bus modeled on CallbackHandler: callbacks keyed by (message, target). Registering the
  -- same message twice on ONE target overwrites (only the last survives); SendMessage fires to every
  -- distinct target. Mirroring the real semantics is what lets a test catch same-target clobbering
  -- (architecture-§4) — a bare no-op mock hides that whole bug class.
  local msgRegistry = {}
  M.__msgRegistry = msgRegistry
  local function embedBus(obj)
    obj.RegisterMessage = function(self, event, fn)
      msgRegistry[event] = msgRegistry[event] or {}
      msgRegistry[event][self] = fn
    end
    obj.UnregisterMessage = function(self, event)
      if msgRegistry[event] then msgRegistry[event][self] = nil end
    end
    obj.SendMessage = function(_, event, ...)
      local t = msgRegistry[event]
      if not t then return end
      for _, fn in pairs(t) do fn(event, ...) end
    end
    return obj
  end

  -- Override 4.
  libs["AceAddon-3.0"] = {
    NewAddon = function(_, target)
      target = target or {}
      local noop = function() end
      -- Modern retail RAISES on an unknown event name instead of ignoring it, which is what turned
      -- one retired event into a whole unregistered addon. Tests put names in M.__badEvents to
      -- reproduce that; a mock that silently accepted everything would hide the entire failure mode.
      target.RegisterEvent = function(_, event)
        if M.__badEvents[event] then
          error("Attempt to register unknown event: " .. tostring(event), 2)
        end
      end
      target.UnregisterEvent = noop
      target.RegisterChatCommand = noop
      -- A fireable timer queue. A no-op stub would have hidden the debounce entirely; tests fire
      -- M.__fireTimers() to advance time and assert that several events coalesce into ONE pass.
      target.ScheduleTimer = function(_, callback, delay)
        local handle = { callback = callback, delay = delay, canceled = false }
        M.__timers[#M.__timers + 1] = handle
        return handle
      end
      target.CancelTimer = function(_, handle)
        if type(handle) == "table" then handle.canceled = true end
      end
      -- AceConsole's :Print mixin, reproduced faithfully: embedding it CLOBBERS a same-named custom
      -- NS.Print, and renders "|cff33ff99<msg>|r:" (green, trailing colon, no cyan tag). The addon
      -- reclaims its own printer right after NewAddon; without this stamp the test suite would never
      -- exercise that reclaim (architecture-§2, anti-pattern #36).
      target.Print = function(self) return "|cff33ff99" .. tostring(self) .. "|r:" end
      return embedBus(target)
    end,
  }
  libs["AceEvent-3.0"] = {
    Embed = function(_, obj)
      obj.RegisterEvent = obj.RegisterEvent or function() end
      obj.UnregisterEvent = obj.UnregisterEvent or function() end
      return embedBus(obj)
    end,
  }

  return M
end
