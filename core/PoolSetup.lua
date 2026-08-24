local _, NS = ...

-- core/PoolSetup.lua — wires the addon into LibKa0s-Pool-1.0 (library-stack-§7).
--
-- ── WHAT THIS REPLACED ───────────────────────────────────────────────────────────────────────
--
-- Four hand-rolled pools: the generic one in modules/InsightsWidgets.lua and the inline row pools
-- in modules/LedgerTable.lua and modules/SessionWindow.lua. All three of this addon's were
-- correct. LootHistory's fourth copy was not — it hid its active widgets and never returned them
-- to the free list, so every re-render allocated a fresh frame per chart element, and frames are
-- never destroyed in WoW. Two addons wrote the same eleven lines and one of them got the second
-- half wrong; that is the whole case for the library.
--
-- ── WHAT A DEGRADED INSTALL GETS ─────────────────────────────────────────────────────────────
--
-- The same pool, locally. It is nine lines, it is the code that was here before, and writing it
-- out is cheaper than making every caller branch — a chart that cannot pool is a chart that
-- allocates, which is precisely the failure this module exists to end.

local Pool = LibStub and LibStub("LibKa0s-Pool-1.0", true)

NS.Pool = Pool or {
  New = function() return { free = {}, active = {} } end,

  Acquire = function(pool, factory)
    local o = table.remove(pool.free)
    if not o then o = factory() end
    pool.active[#pool.active + 1] = o
    o:Show()
    return o
  end,

  -- The `before` hook is not optional garnish in the fallback either: modules/Insights.lua
  -- releases a pool of list panels and each panel owns its own row pool.
  ReleaseAll = function(pool, before)
    local active = pool.active
    for i = 1, #active do
      local o = active[i]
      if before then before(o) end
      o:Hide()
      pool.free[#pool.free + 1] = o
    end
    for i = #active, 1, -1 do active[i] = nil end
  end,

  Counts = function(pool) return #pool.free, #pool.active end,
}
