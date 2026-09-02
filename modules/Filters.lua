local addonName, NS = ...   -- luacheck: ignore addonName
NS.Filters = NS.Filters or {}
local F = NS.Filters

-- Item-id blacklist / whitelist.
--
--   * Blacklist — ids that must NOT be recorded even when they pass the capture gates.
--   * Whitelist — ids that must ALWAYS be recorded, bypassing the quality gate.
--
-- Both are point-in-time: a list decides FUTURE captures, it never hides, deletes or resurrects an
-- entry already written. (Delete unwanted rows from the ledger table if you want them gone.)
--
-- The lists are stored account-wide in NS.db.global.{blacklist,whitelist} — NOT under settings, and
-- NOT as Schema rows. Like `settings.window` they are an architecture-§5 carve-out, mutated here
-- rather than through Schema:Set, because a dynamic id-set has no Schema widget to drive.
--
-- An id can be on at most ONE list (adding to one drops it from the other), so the capture gate's
-- whitelist/blacklist checks can never contradict.
--
-- Every mutation writes a FRESH table back to NS.db.global (copy-on-write) so it never mutates an
-- AceDB shared-default table in place, then propagates the change WITHOUT adding a second bus
-- sender (architecture-§4's one-sender-per-message invariant): it re-caches the Ledger's list
-- upvalues by a direct call, and broadcasts LedgerChanged through Database's own emitter so the
-- browser and the Filters panel re-query.

local function currentSet(key)
  return (NS.db and NS.db.global and NS.db.global[key]) or {}
end

-- Shallow copy of a set, so a write never aliases the stored (or AceDB default) table.
local function setCopy(t)
  local c = {}
  if type(t) == "table" then for k, v in pairs(t) do c[k] = v end end
  return c
end

function F:Blacklist() return currentSet("blacklist") end
function F:Whitelist() return currentSet("whitelist") end

-- Membership predicates. No production caller — the capture path reads the cached list upvalues in
-- modules/Ledger.lua rather than querying per id. Exported as the tested seam for a list's meaning
-- (tests/test_filters.lua:14, :29, :30, :44), and the read half of the Add*/Remove* API.
function F:IsBlacklisted(id)
  id = tonumber(id)
  return id ~= nil and currentSet("blacklist")[id] == true
end

-- No production caller; see F:IsBlacklisted above (tests/test_filters.lua:29).
function F:IsWhitelisted(id)
  id = tonumber(id)
  return id ~= nil and currentSet("whitelist")[id] == true
end

-- Number of ids in a set (also used by the [Filters] debug trace).
function F:Count(set)
  local n = 0
  for _ in pairs(set or {}) do n = n + 1 end
  return n
end

-- Propagate a list change: re-cache the Ledger's list upvalues by a direct cross-module call (not a
-- bus message — the lists aren't schema settings, and the Ledger is the only capture-side consumer),
-- then broadcast LedgerChanged through Database's sole emitter so the views refresh.
function F:_notify()
  if NS.Ledger and NS.Ledger.RefreshUpvalues then NS.Ledger:RefreshUpvalues() end
  if NS.Database and NS.Database.FireLedgerChanged then NS.Database:FireLedgerChanged() end
  if NS.State and NS.State.debug and NS.Debug then
    NS.Debug("Filters", "blacklist=%s whitelist=%s",
      self:Count(self:Blacklist()), self:Count(self:Whitelist()))
  end
end

-- Move `id` onto `listKey`, dropping it from the sibling list. Returns true when the store actually
-- changed. No-op (false) for a non-numeric id or one already on the target list alone.
function F:_move(listKey, id)
  id = tonumber(id)
  if not id then return false end
  local siblingKey = (listKey == "blacklist") and "whitelist" or "blacklist"
  local target, sibling = currentSet(listKey), currentSet(siblingKey)
  if target[id] and not sibling[id] then return false end
  local t = setCopy(target); t[id] = true; NS.db.global[listKey] = t
  if sibling[id] then
    local s = setCopy(sibling); s[id] = nil; NS.db.global[siblingKey] = s
  end
  self:_notify()
  return true
end

-- Remove `id` from `listKey`. Returns true when it was present.
function F:_remove(listKey, id)
  id = tonumber(id)
  if not id then return false end
  local target = currentSet(listKey)
  if not target[id] then return false end
  local t = setCopy(target); t[id] = nil; NS.db.global[listKey] = t
  self:_notify()
  return true
end

function F:AddBlacklist(id)    return self:_move("blacklist", id) end
function F:AddWhitelist(id)    return self:_move("whitelist", id) end
function F:RemoveBlacklist(id) return self:_remove("blacklist", id) end
function F:RemoveWhitelist(id) return self:_remove("whitelist", id) end

-- Empty one list in a single copy-on-write write, then propagate exactly like a per-id change.
-- Returns the number of ids removed; an unknown key or an already-empty list returns 0 without
-- firing _notify.
function F:ClearList(listKey)
  if listKey ~= "blacklist" and listKey ~= "whitelist" then return 0 end
  local removed = self:Count(currentSet(listKey))
  if removed == 0 then return 0 end
  NS.db.global[listKey] = {}
  self:_notify()
  return removed
end

-- Empty BOTH lists with a single _notify. Returns the total ids removed. Used by the settings
-- reset paths (Slash:CliResetAll, which the General page's Defaults button goes through).
function F:ClearAll()
  local removed = self:Count(self:Blacklist()) + self:Count(self:Whitelist())
  if removed == 0 then return 0 end
  NS.db.global.blacklist = {}
  NS.db.global.whitelist = {}
  self:_notify()
  return removed
end

-- Sorted array of the ids on a list, for a stable management-UI order.
function F:SortedIDs(set)
  local ids = {}
  for id in pairs(set or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

-- Extract an item id from free-form input: a bare number, or an item link / itemString the user
-- shift-clicked into the field. Returns a number, or nil when nothing parses.
function F:ParseItemID(input)
  if type(input) == "number" then return input end
  if type(input) ~= "string" then return nil end
  input = input:match("^%s*(.-)%s*$")
  local fromLink = input:match("|Hitem:(%d+)") or input:match("^item:(%d+)")
  if fromLink then return tonumber(fromLink) end
  return tonumber(input)
end
