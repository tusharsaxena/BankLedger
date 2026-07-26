-- Minimal WoW-API mock set for the headless unit tests. Returns a builder so each run gets a fresh,
-- isolated environment. Only what the addon touches at load/test time is stubbed.

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepcopy(v) end
  return r
end

-- A universal frame stub: any method call is a no-op that returns the frame itself. WoW frame API
-- methods are always PascalCase (SetPoint, CreateTexture, HookScript, …), so only those keys get a
-- no-op function; any other (lowercase/custom) field access misses through to nil, letting addon
-- code do `if not f.someCustomField then f.someCustomField = ... end` safely.
local function stubFrame()
  local f = {}
  setmetatable(f, { __index = function(_, k)
    if type(k) == "string" and k:match("^%u") then
      return function() return f end
    end
    return nil
  end })
  return f
end

return function()
  local M = {}

  -- time / misc
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
  M.C_Timer = { After = function() end }
  M.GetGuildInfo = function() return "Ka0s" end

  -- Carried money, in copper. Tests set M.__money directly.
  M.__money = 1000000
  M.GetMoney = function() return M.__money end

  -- Bag index enum (the ids Constants derives its container groups from).
  M.Enum = {
    BagIndex = {
      Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5,
      Bank = -1, Reagentbank = -3,
      BankBag_1 = 6, BankBag_7 = 12,
      AccountBankTab_1 = 13, AccountBankTab_5 = 17,
      CharacterBankTab_1 = 18, CharacterBankTab_6 = 23,
    },
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
    RequestLoadItemDataByID = function() end,
  }

  -- strings / helpers
  M.ITEM_QUALITY_COLORS = setmetatable({}, {
    __index = function() return { r = 1, g = 1, b = 1, hex = "ffffffff" } end,
  })
  M.strtrim = function(s) return (tostring(s):gsub("^%s*(.-)%s*$", "%1")) end

  -- UI
  M.UIParent = stubFrame()
  M.CreateFrame = function() return stubFrame() end
  M.UISpecialFrames = {}
  -- Chat sink for NS.Print (core/Util.lua). No-op by default; tests override AddMessage to capture.
  M.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
  M.Settings = {
    RegisterCanvasLayoutCategory = function() return { GetID = function() return 1 end } end,
    RegisterCanvasLayoutSubcategory = function() return { GetID = function() return 2 end } end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
  }
  M.StaticPopupDialogs = {}

  -- LibStub + Ace library mocks
  local libs = {}
  libs["AceDB-3.0"] = {
    New = function(_, _name, defaults)
      return {
        global = deepcopy(defaults and defaults.global or {}),
        profile = deepcopy(defaults and defaults.profile or {}),
        -- Account-wide addon: created in-game with defaultProfile=true, so the profile is always the
        -- fixed "Default". Mirror that here so the [Init] summary renders a real profile name.
        GetCurrentProfile = function() return "Default" end,
      }
    end,
  }

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

  libs["AceAddon-3.0"] = {
    NewAddon = function(_, target)
      target = target or {}
      local noop = function() end
      target.RegisterEvent = noop
      target.UnregisterEvent = noop
      target.RegisterChatCommand = noop
      target.ScheduleTimer = function() return {} end
      target.CancelTimer = noop
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
  M.LibStub = setmetatable(
    { GetLibrary = function(_, n) return libs[n] end },
    { __call = function(_, n) return libs[n] end }
  )

  return M
end
