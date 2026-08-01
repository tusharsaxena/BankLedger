-- Ka0s Bank Ledger's half of the WoW-API mock, layered over the shared base in tests/_kit.
--
-- The base (tests/_kit/mock_base.lua) owns everything the whole collection touches: LibStub with a
-- REAL NewLibrary — which is what lets the vendored LibKa0s majors register headlessly exactly as
-- they do in the client — plus the Ace fakes, the settings-canvas registry, the timer queue and the
-- generic frame stub. This file owns what is genuinely Bank Ledger's: the bag/bank container model,
-- the guild bank, the item database, and the handful of base behaviours whose fidelity this addon
-- needs to be different.
--
-- Plain per-key overwrite, per the kit's README: the base builder hands back a fresh table on every
-- call, so there is no merge machinery to reason about.
--
-- ── THE OVERRIDES, AND WHY EACH ONE IS NOT A KIT GAP ──────────────────────────────────────────
--
-- Every override below replaces a base behaviour with a STRICTER one that an existing Bank Ledger
-- suite depends on. None of them is the base being wrong — the base's own header states the policy
-- (single-consumer fidelity lives in the consumer's extender) — so none is a finding to take
-- upstream. They are listed here so a future re-vendor can tell an intentional divergence from a
-- drift:
--
--   1. stubFrame        — the base returns 0 from GetWidth/GetHeight and defines no SetPoint at all.
--                         Window geometry here round-trips through SavedVariables, so the position
--                         and size have to be real state or the persistence is untestable. The base
--                         also never fires OnHide, and "the session window closes with the bank
--                         frame" is exactly an OnHide assertion.
--   2. __shown = true   — the base starts frames hidden; real frames start shown, and nine IsShown
--                         assertions in tests/test_sessionwindow.lua read the difference.
--   3. __fireTimers     — the base's returns nothing and its CancelTimer is a no-op. The capture
--                         engine's debounce is asserted as "three events, ONE reconcile pass" and
--                         "the pending timer was cancelled", which needs both a count and honoured
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
--   8. AceGUI           — the base ships a full widget factory. Nothing here drives a widget yet
--                         (the panel bodies build lazily on a first OnShow that never fires
--                         headlessly), and taking the factory now would silently start building
--                         page bodies inside unrelated suites. Revisit when Options is adopted.
--   9. StaticPopup_Show — the base defines it, which flips settings/Schema.lua's and
--                         settings/Panel.lua's `if type(StaticPopup_Show) == "function"` guards from
--                         the direct-call path to the popup path. That IS the in-game path and is
--                         worth taking, but it is a test-semantics change that belongs with the
--                         Slash/Options work rather than smuggled into a harness swap.
--  10. GameTooltip      — same argument: the base defines it and seven `if GameTooltip then` guards
--                         change branch. Left nil here so this swap is behaviour-neutral.

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
-- a garbage table" look identical. SetPoint's overloads are modelled because addon code uses both
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

local function stubFrame()
  local f = { __shown = true, __points = {}, __w = 0, __h = 0 }
  setmetatable(f, { __index = function(_, k)
    if k == "Show" then return function() f.__shown = true; return f end end
    if k == "Hide" then
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
    if k == "SetShown" then
      return function(_, v) if v then f:Show() else f:Hide() end; return f end
    end
    if k == "IsShown" or k == "IsVisible" then return function() return f.__shown end end
    if k == "HookScript" then
      return function(_, script, handler)
        if script == "OnHide" then
          f.__onHide = f.__onHide or {}
          f.__onHide[#f.__onHide + 1] = handler
        end
        return f
      end
    end
    if k == "SetPoint" then
      return function(_, point, ...) f.__points[#f.__points + 1] = recordPoint(point, ...); return f end
    end
    if k == "ClearAllPoints" then
      return function() f.__points = {}; return f end
    end
    if k == "GetPoint" then
      return function(_, i)
        local p = f.__points[i or 1]
        if not p then return nil end
        return p.point, p.relativeTo, p.relativePoint, p.x, p.y
      end
    end
    if k == "SetSize" then return function(_, w, h) f.__w, f.__h = w, h; return f end end
    if k == "SetWidth" then return function(_, w) f.__w = w; return f end end
    if k == "SetHeight" then return function(_, h) f.__h = h; return f end end
    if k == "GetWidth" then return function() return f.__w end end
    if k == "GetHeight" then return function() return f.__h end end
    -- Font strings resolve to the frame itself (the catch-all below), which is fine for the
    -- geometry the tests exercise. What is NOT recoverable that way is which FONT TEMPLATE a
    -- widget asked for, and "every card shares one headline template" is a real invariant, so
    -- record the templates in creation order.
    if k == "CreateFontString" then
      return function(_, _, _, template)
        f.__fontTemplates = f.__fontTemplates or {}
        f.__fontTemplates[#f.__fontTemplates + 1] = template
        return f
      end
    end
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
  -- it gets the geometry-modelling stub rather than the base's.
  M.__stubFrame = stubFrame
  M.UIParent    = stubFrame()
  M.CreateFrame = function() return stubFrame() end

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
  -- idealised enum would have hidden the real defect — that `AccountBankTab_1` is 12, one past the
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
  M.C_Item = {
    GetItemInfo = function(idOrLink)
      local id = tonumber(idOrLink) or tonumber(tostring(idOrLink):match("|?H?item:(%d+)") or "")
      local it = id and M.__items[id]
      if not it then return nil end
      return it[1], "|cffffffff|Hitem:" .. id .. "::::::::::|h[" .. it[1] .. "]|h|r",
        it[2], 1, 1, it[3], it[4], 1, "", 0, it[5]
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
  -- real classes are enough to prove the coordinate maths and the unknown-class fallback.
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
      if not handle.cancelled then
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

  -- Override 8. AceGUI is present but hands back nothing: P:Register only needs the library to
  -- EXIST (the panel bodies are built lazily on first OnShow, which never fires headless), and every
  -- widget call site already guards on the create returning a usable widget. That is enough to
  -- exercise registration and the framework callback contract without modelling AceGUI's whole
  -- widget tree.
  libs["AceGUI-3.0"] = { Create = function() return nil end }

  -- Message bus modelled on CallbackHandler: callbacks keyed by (message, target). Registering the
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
        local handle = { callback = callback, delay = delay, cancelled = false }
        M.__timers[#M.__timers + 1] = handle
        return handle
      end
      target.CancelTimer = function(_, handle)
        if type(handle) == "table" then handle.cancelled = true end
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
