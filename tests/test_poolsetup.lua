-- tests/test_poolsetup.lua — the LibKa0s-Pool-1.0 seam.
--
-- The library's own suite covers the pool's semantics; duplicating them here is the consumer-side
-- copy testing-§8 forbids. What only this repo can assert is that the seam is wired, that the
-- fallback behaves the same when the library is absent, and — the case worth having — that the
-- addon's real render path recycles.

local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function counting()
  local made = 0
  return function()
    made = made + 1
    local o = { __shown = false }
    function o:Show() self.__shown = true end
    function o:Hide() self.__shown = false end
    return o
  end, function() return made end
end

test("PoolSetup: the seam is published", function()
  assertTrue(type(NS.Pool) == "table", "NS.Pool exists")
  assertTrue(type(NS.Pool.New) == "function")
  assertTrue(type(NS.Pool.Acquire) == "function")
  assertTrue(type(NS.Pool.ReleaseAll) == "function")
end)

test("PoolSetup: a released object is reused rather than rebuilt", function()
  local p = NS.Pool.New()
  local factory, made = counting()
  for _ = 1, 3 do NS.Pool.Acquire(p, factory) end
  NS.Pool.ReleaseAll(p)
  for _ = 1, 3 do NS.Pool.Acquire(p, factory) end
  assertEqual(made(), 3, "the second pass builds nothing")
end)

test("PoolSetup: a nested release empties both levels", function()
  -- This is the shape W.ReleasePanels had, expressed through the library's `before` hook. If the
  -- hook is not wired, the inner rows silently stop being recycled and only a heap profile says so.
  local panels = NS.Pool.New()
  local factory = counting()
  local panel = NS.Pool.Acquire(panels, factory)
  panel._rows = NS.Pool.New()
  NS.Pool.Acquire(panel._rows, factory)
  NS.Pool.ReleaseAll(panels, function(p) NS.Pool.ReleaseAll(p._rows) end)
  assertEqual(select(2, NS.Pool.Counts(panel._rows)), 0)
  assertEqual(select(1, NS.Pool.Counts(panel._rows)), 1, "the row went back on its own free list")
end)
