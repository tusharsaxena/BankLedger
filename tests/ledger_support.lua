-- tests/ledger_support.lua — the ledger suites' shared capture fixture.
--
-- Extracted when tests/test_ledger.lua crossed layout-§1's 1500-line cap and the reconcile-timing
-- cases peeled off into tests/test_ledger_settling.lua. `withContainers` is the only helper both
-- halves need, and it is a FIXTURE that mutates and restores the mock's container table — exactly
-- the kind of thing that must exist once. Two copies would drift on the next container id the game
-- adds, and the suite that was not updated would restore stale stock and fail somewhere else.
if rawget(_G, "__BL_LEDGER_SUPPORT") then return rawget(_G, "__BL_LEDGER_SUPPORT") end

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks

-- Drive a real capture: open the frame, move stock between two container ids, reconcile.
local BAG_ID, BANK_ID, WARBAND_ID = 0, 6, 12   -- the real 12.0.7 ids the mock reproduces

local function withContainers(setup, fn)
  local saved = {}
  for id in pairs(setup) do saved[id] = mocks.__containers[id] end
  for id, contents in pairs(setup) do mocks.__containers[id] = contents end
  local ok, err = pcall(fn)
  for id in pairs(setup) do mocks.__containers[id] = saved[id] end
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
  if not ok then error(err, 0) end
end

local M = {
  withContainers = withContainers,
  BAG_ID = BAG_ID, BANK_ID = BANK_ID, WARBAND_ID = WARBAND_ID,
}

rawset(_G, "__BL_LEDGER_SUPPORT", M)
return M
