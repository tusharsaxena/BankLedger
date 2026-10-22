local _, NS = ...
-- modules/SimScenario.lua — the simulator's scenarios (BankLedger#24, req-bl-sim §7).
--
-- Filled IN PLACE into NS.SimHost.SCENARIOS, the table modules/Sim.lua hands the library as
-- `d.scenarios`; LibKa0s-Sim-1.0 reads it at call time (Sim minor 2), so this file loading after
-- modules/Sim.lua is conventional rather than load-bearing.
--
-- A scenario is { label, timeline = fn(def, opts) -> steps }. Every timeline is PURE: it builds
-- fresh step tables and reads no world, no setting and no saved data, so composing a preview or a
-- session plays nothing. A step is one driver call (modules/SimDrivers.lua): `kind` names the
-- driver and the rest are its arguments, with `item` a pool index (or "bonus") resolved against the
-- simulated world when the step plays. `settle`, when present, raises the pause `run` takes after
-- the step (modules/Sim.lua's stepDelay).
--
-- Expected rows assume DEFAULT gate settings. A quality threshold, an excluded store or a Track
-- toggle legitimately changes them, and that difference is itself a valid observation.

local Host = NS.SimHost
local L = NS.L
local Store = NS.Constants.Store

-- bank: the personal bank. Expect 3 BANK rows: 2 deposits and 1 withdrawal, the second deposit's row
-- keeping the observed (bonus-id) link when the pool has one.
local function bankTimeline()
  return {
    { kind = "OpenBank", label = L["Open the bank"] },
    { kind = "Deposit", store = Store.BANK, item = 1, n = 20, label = L["Deposit 20 of item A to the bank"] },
    { kind = "Deposit", store = Store.BANK, item = "bonus", n = 1, label = L["Deposit 1 of item B to the bank"] },
    { kind = "Withdraw", store = Store.BANK, item = 2, n = 5, label = L["Withdraw 5 of item C from the bank"] },
    { kind = "CloseBank", label = L["Close the bank"] },
  }
end

local DEFS = {
  { "bank", { label = L["Personal bank"], timeline = bankTimeline } },
}

local scenarios = Host.SCENARIOS
for _, row in ipairs(DEFS) do
  local name, def = row[1], row[2]
  if not scenarios.defs[name] then scenarios.names[#scenarios.names + 1] = name end
  scenarios.defs[name] = def
end
