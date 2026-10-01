local _, NS = ...
NS.Ledger = NS.Ledger or {}
local L = NS.Ledger
local C = NS.Constants

-- The capture engine's `/bl debug scan` dump, L:Diagnose. Peeled out of modules/Ledger.lua, which sat
-- at 997 lines, three short of layout-§1's 1000-1500 band, so the split that brings L:Diagnose below
-- CCN 15 (GI-BL-02) does not push it in. A MOVE, not a rewrite: the block reached into none of that
-- file's locals, only NS, C, NS.Compat, the client globals and L._guildHooked, which it reads through
-- the shared NS.Ledger table. Load order is conventional: modules/Diagnostics.lua and the debug verb
-- reach it at run time, never at file load.

-- ── Diagnostics (`/bl debug scan`) ──────────────────────────────────────────────
-- A structured dump verb, which debug-logging-§4 explicitly sanctions. Its whole job is to replace
-- guesswork about the client's container model with ground truth: which `Enum.BagIndex` members
-- this build actually exposes and at what numeric ids, which ids report slots right now, and what
-- the addon's own id groups resolved to. Run it with a bank window open.
--
-- Returns an array of plain lines so it is testable and can be routed to the console or to chat.
local PROBE_MIN, PROBE_MAX = -8, 40

function L:Diagnose()
  local out = {}
  local function add(fmt, ...)
    out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
  end

  add("openContext=%s snapshot=%s", tostring(NS.State.openContext),
    NS.State.lastSnapshot and "yes" or "no")

  -- Which BagIndex members this build exposes, sorted by id — the values the id groups are built
  -- from. A member that is absent here is one this addon must not assume.
  local members = {}
  if Enum and Enum.BagIndex then
    for name, value in pairs(Enum.BagIndex) do
      if type(value) == "number" then members[#members + 1] = { name = name, value = value } end
    end
  end
  table.sort(members, function(a, b)
    if a.value ~= b.value then return a.value < b.value end
    return a.name < b.name
  end)
  add("Enum.BagIndex has %s members", #members)
  for _, m in ipairs(members) do add("  BagIndex.%s = %s", m.name, m.value) end

  -- What this addon's own groups resolved to, so a wrong group is visible beside the truth above.
  for _, store in ipairs({ "BAGS", "BANK", "WARBAND_BANK" }) do
    local ids = C.STORE_CONTAINERS[store] or {}
    local parts = {}
    for i, id in ipairs(ids) do parts[i] = tostring(id) end
    add("group %s = [%s]", store, table.concat(parts, ", "))
  end

  -- Probe every plausible container id for slots and contents, whatever group it belongs to. This
  -- is the line that says where the bank actually lives on this client.
  add("container probe (id: slots / filled / distinct ids)")
  for id = PROBE_MIN, PROBE_MAX do
    local slots = NS.Compat.GetContainerNumSlots(id)
    if slots and slots > 0 then
      local filled, seen, kinds = 0, {}, 0
      for slot = 1, slots do
        local info = NS.Compat.GetContainerSlot(id, slot)
        if info then
          filled = filled + 1
          if not seen[info.itemID] then seen[info.itemID] = true; kinds = kinds + 1 end
        end
      end
      add("  %s: %s / %s / %s", id, slots, filled, kinds)
    end
  end

  add("money=%s", NS.Compat.GetMoney())

  -- Money capture rests on being able to read a STORE's own coin balance, not just the purse: a
  -- purse delta alone cannot tell a warband deposit apart from a bank-tab purchase. This line says
  -- which balance readers this build exposes, and what each one actually returns right now.
  add("money API: purse=%s guildBank=%s bankFetch=%s bankTypes=%s",
    type(GetMoney), type(GetGuildBankMoney),
    type(C_Bank and C_Bank.FetchDepositedMoney), tostring(Enum and Enum.BankType ~= nil))
  if Enum and Enum.BankType then
    local names = {}
    for name, value in pairs(Enum.BankType) do
      if type(value) == "number" then names[#names + 1] = ("%s=%s"):format(name, value) end
    end
    table.sort(names)
    add("  Enum.BankType: %s", table.concat(names, ", "))
  end
  -- Read each candidate behind a pcall: a reader that exists but errors off its own frame is no
  -- more usable than one that is absent, and this is the line that tells the two apart.
  local function probeMoney(label, fn)
    if type(fn) ~= "function" then return add("  %s: absent", label) end
    local ok, value = pcall(fn)
    add("  %s: %s", label, ok and tostring(value) or ("ERROR " .. tostring(value)))
  end
  probeMoney("GetGuildBankMoney()", GetGuildBankMoney)
  if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
    if Enum.BankType.Account then
      probeMoney("C_Bank.FetchDepositedMoney(Account)",
        function() return C_Bank.FetchDepositedMoney(Enum.BankType.Account) end)
    end
    if Enum.BankType.Character then
      probeMoney("C_Bank.FetchDepositedMoney(Character)",
        function() return C_Bank.FetchDepositedMoney(Enum.BankType.Character) end)
    end
  end

  -- Guild bank: which API globals this build exposes, and what each tab actually reports. A tab
  -- showing 0 filled when you can see items in it means the query has not landed yet.
  add("guild bank API: link=%s info=%s query=%s numTabs=%s current=%s visible=%s",
    type(GetGuildBankItemLink), type(GetGuildBankItemInfo), type(QueryGuildBankTab),
    type(GetNumGuildBankTabs), tostring(NS.Compat.GetCurrentGuildBankTab()),
    tostring(NS.Compat.IsGuildBankVisible()))
  -- The guild bank fires neither an open nor a close event, so these hooks ARE both paths: OnShow
  -- opens the session and OnHide closes it. NOT INSTALLED means the load-on-demand UI has never
  -- arrived, so no guild visit can be noticed at all and no session can end on its own.
  add("guild bank frame hooks: %s (frame=%s)",
    L._guildHooked and "installed" or "NOT INSTALLED", type(GuildBankFrame))
  local tabs = NS.Compat.GetNumGuildBankTabs()
  add("guild bank tabs=%s (tab: filled / distinct ids)", tabs)
  local tabSize = NS.Compat.GuildBankTabSize()
  for tab = 1, tabs do
    local filled, seen, kinds = 0, {}, 0
    for slot = 1, tabSize do
      local info = NS.Compat.GetGuildBankSlot(tab, slot)
      if info then
        filled = filled + 1
        if not seen[info.itemID] then seen[info.itemID] = true; kinds = kinds + 1 end
      end
    end
    add("  tab %s: %s / %s", tab, filled, kinds)
  end

  -- Which events this build actually accepted. An event in the unavailable list is one Blizzard has
  -- retired; if a capture-critical one is in there, that is why nothing is being recorded.
  -- The record is the whole addon's (NS.EventRecord, core/CoreSetup.lua), not only this engine's.
  local rec = NS.EventRecord
  add("events registered (%s): %s", #rec.registered, table.concat(rec.registered, ", "))
  add("events UNAVAILABLE (%s): %s", #rec.unavailable,
    #rec.unavailable > 0 and table.concat(rec.unavailable, ", ") or "none")
  return out
end
