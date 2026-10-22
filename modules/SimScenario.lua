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
-- simulated world when the step plays. The pool holds at least four items (SimWorld.POOL_MIN), so
-- the letters below are pool indexes 1 to 4: A = 1, C = 2, D = 3, E = 4, and B the bonus-link item.
--
-- Two optional step fields are the host's, never the library's:
--   settle  raises the pause `run` takes after the step (modules/Sim.lua's stepDelay);
--   holdOK  lets the host gate open on a held baseline before this step (modules/Sim.lua's
--           Host.Gate): closing the bank on a live hold is the point of the `onesided` scenario.
-- When a step plays, modules/Sim.lua's play stamps `rowsBefore` on it, so Host.Recorded(step) can
-- say how many rows the engine recorded for it.
--
-- EXPECTED COUNTS ASSUME DEFAULT GATE SETTINGS. A quality threshold, an excluded store or a Track
-- toggle legitimately changes them, and that difference is itself a valid observation.

local Host = NS.SimHost
local L = NS.L
local Store = NS.Constants.Store

local GOLD = 10000   -- copper per gold

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

-- warband: a warband transfer between characters. Expect 4 WARBAND_BANK rows: main's item and gold
-- deposits, then the alt's item and gold withdrawals, stamped with the alt's key
-- (Simbanker-<realm>) and class. The lagged store half runs the held-baseline path: [Diff]
-- "one-sided change: baseline held", then "held change settled".
local function warbandTimeline()
  return {
    { kind = "OpenBank", label = L["Open the bank"] },
    { kind = "Deposit", store = Store.WARBAND_BANK, item = 1, n = 20, lag = 1.5, settle = 3,
      label = L["Deposit 20 of item A to the warband bank (its half lands 1.5 s later)"] },
    { kind = "Money", store = Store.WARBAND_BANK, dir = "deposit", copper = 1000 * GOLD,
      label = L["Deposit 1,000 gold to the warband bank"] },
    { kind = "CloseBank", label = L["Close the bank"] },
    { kind = "Switch", to = "alt", label = L["Switch to the alt"] },
    { kind = "OpenBank", label = L["Open the bank"] },
    { kind = "Withdraw", store = Store.WARBAND_BANK, item = 1, n = 10,
      label = L["Withdraw 10 of item A from the warband bank"] },
    { kind = "Money", store = Store.WARBAND_BANK, dir = "withdraw", copper = 500 * GOLD,
      label = L["Withdraw 500 gold from the warband bank"] },
    { kind = "CloseBank", label = L["Close the bank"] },
  }
end

-- guild: the guild bank. Another member's deposit while the player is away must not arm a context
-- (issue #12): 0 rows and no context after the first step. Then 3 GUILD_BANK rows stamped with the
-- guild: the item withdrawal, the item deposit and the gold withdrawal.
local function guildTimeline()
  return {
    { kind = "GuildDataAway", item = 2, n = 2, label = L["Guild bank data arrives while you are away"] },
    { kind = "OpenGuild", label = L["Open the guild bank"] },
    { kind = "Withdraw", store = Store.GUILD_BANK, item = 3, n = 5,
      label = L["Withdraw 5 of item D from the guild bank"] },
    { kind = "Deposit", store = Store.GUILD_BANK, item = 1, n = 3, label = L["Deposit 3 of item A to the guild bank"] },
    { kind = "Money", store = Store.GUILD_BANK, dir = "withdraw", copper = 200 * GOLD,
      label = L["Withdraw 200 gold from the guild bank"] },
    { kind = "CloseGuild", label = L["Close the guild bank"] },
  }
end

-- onesided: a session closed mid-change. Expect 0 rows. A loot into the bags is one-sided and is
-- re-anchored after the settle window (settle 6.5); a repair moves the purse alone, which is no money
-- row (F-001); a warband deposit whose store half never lands is still held when the bank closes,
-- and CloseContext's final pass drops it ([Store] "closed, held change dropped").
local function onesidedTimeline()
  return {
    { kind = "OpenBank", label = L["Open the bank"] },
    { kind = "Loot", item = 4, n = 2, settle = 6.5, label = L["Loot 2 of item E into the bags"] },
    { kind = "Spend", copper = 25 * GOLD, label = L["Repair for 25 gold"] },
    { kind = "Deposit", store = Store.WARBAND_BANK, item = 1, n = 5, lag = "never",
      label = L["Deposit 5 of item A to the warband bank (its half never lands)"] },
    { kind = "CloseBank", holdOK = true, label = L["Close the bank"] },
  }
end

local DEFS = {
  { "bank", { label = L["Personal bank"], timeline = bankTimeline } },
  { "warband", { label = L["Warband transfer"], timeline = warbandTimeline } },
  { "guild", { label = L["Guild bank"], timeline = guildTimeline } },
  { "onesided", { label = L["One-sided change"], timeline = onesidedTimeline } },
}

local scenarios = Host.SCENARIOS
for _, row in ipairs(DEFS) do
  local name, def = row[1], row[2]
  if not scenarios.defs[name] then scenarios.names[#scenarios.names + 1] = name end
  scenarios.defs[name] = def
end
