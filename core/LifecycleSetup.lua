local addonName, NS = ...

-- core/LifecycleSetup.lua — the stand-down latch (slash-commands-§7, LibKa0s-Lifecycle-1.0).
--
-- ── WHAT "DISABLED" MEANS HERE ────────────────────────────────────────────────────────────────
--
-- Not hidden, not quiet, not skipping a repaint — NOT RUNNING. A player who unticks *Enable Bank
-- Ledger* has asked for the same outcome they would get by unticking the addon in Blizzard's own
-- AddOns list, minus the /reload. So the transition to disabled unregisters every event this addon
-- owns, cancels every timer it armed, drops the four private bus targets and lets the show ladder
-- answer no at the source.
--
-- THIS ADDON USED TO SHIP THE DRAW GATE (anti-pattern #85). `settings.enabled` was one rung of a
-- show ladder and one rung of the capture gate: the windows went away, the Ledger's whole
-- bank/bag/mail event set stayed registered, and the client went on walking that registration list
-- and entering Lua on every `BAG_UPDATE_DELAYED` to run the comparison that decided to leave. An
-- early return is not a stand-down — the addon did not stop watching, it stopped reacting, and it
-- still paid the dispatch, which is precisely the cost a player switching it off is trying to stop
-- paying.
--
-- ── ONE LATCH, NAMED HOLDS ────────────────────────────────────────────────────────────────────
--
-- The teardown body is reached through the library's hold set rather than through a boolean, and
-- the difference is the state a boolean cannot represent: two reasons to be down at once, the
-- first released while the second still holds. `Release` there does NOT stand the addon up —
-- `standUp` runs only when the LAST hold goes. There is deliberately no `:StandUp()` member to
-- call, so a bare stand-up is not reachable by accident.
--
-- THIS ADDON TAKES ONE HOLD TODAY, `disabled`. It holds a recorded no-combat-path exemption
-- (performance-§12) and therefore registers no `perf` verb and runs no suspended arm, so
-- `LibKa0s-Perf-1.0` never takes `perf` here. That is a fact about which holds exist, not about
-- the mechanism: arming the harness later is a registration, and the latch already answers for it.
--
-- ── AND ON THE DEGRADED ARM ───────────────────────────────────────────────────────────────────
--
-- With LibKa0s absent there is no latch and no second reason to be down — no perf arm exists to
-- take a second hold — so `NS.SetDisabledHold` degrades to the one edge a single reason has, and
-- drives the SAME `NS.StandDown` / `NS.StandUp` bodies. It is a missing library's fallback, not a
-- parallel lifecycle: there is still exactly one way down and one way back up.

local Lifecycle = LibStub and LibStub("LibKa0s-Lifecycle-1.0", true)

-- Spelled from the library rather than typed, so this host and LibKa0s-Perf-1.0 can never disagree
-- about the key. The literal is the fallback for the arm where there is no library to ask.
NS.HOLD_DISABLED = (Lifecycle and Lifecycle.HOLD_DISABLED) or "disabled"

if Lifecycle then
  -- ONE INSTANCE, for the whole addon. A second instance is a second hold set, which is the
  -- parallel-lifecycle anti-pattern arriving by accident.
  --
  -- The two callbacks are resolved at CALL time through NS rather than captured here: core/
  -- BankLedger.lua defines them and the TOC loads this file beside it, so a load-time upvalue
  -- would pin whichever half the TOC happened to walk first.
  NS.Lifecycle = Lifecycle:New({
    name      = addonName,
    standDown = function() NS.StandDown() end,
    standUp   = function() NS.StandUp() end,
    print     = function(line) NS.Print(line) end,
  })
end

-- The degraded arm's single edge. Never read on the live arm.
local downWithoutLibrary = false

--- Take or release the `disabled` hold. THE ONE ENTRY POINT: the Master-controls checkbox's
--- onChange, `/bl enable`, `/bl disable`, `/bl set settings.enabled`, the load-time read and the
--- profile callbacks all land here, so no surface can drive the teardown by another route.
function NS.SetDisabledHold(held)
  held = held and true or false
  if NS.Lifecycle then return NS.Lifecycle:Set(NS.HOLD_DISABLED, held) end
  if held == downWithoutLibrary then return false end
  downWithoutLibrary = held
  if held then NS.StandDown() else NS.StandUp() end
  return true
end

--- Has the PLAYER switched the addon off? The question the slash gate and the launcher's left
--- click ask, and deliberately not `IsStoodDown` — a perf-suspended addon is inert but it is not
--- disabled, and the refusal line names `/bl enable`, which would be the wrong instruction.
function NS.IsDisabled()
  if NS.Lifecycle then return NS.Lifecycle:IsHeld(NS.HOLD_DISABLED) end
  return downWithoutLibrary
end

--- Is the addon stood down for ANY reason? The question the show ladder asks at its first rung.
function NS.IsStoodDown()
  if NS.Lifecycle then return NS.Lifecycle:IsDown() end
  return downWithoutLibrary
end

--- The stored master switch, read straight from the store rather than through the schema: this is
--- called from OnEnable, before the composed rows necessarily exist, and on the degraded arm where
--- there is no composed `settings.enabled` row at all. An absent store answers ENABLED — "no
--- answer" is not "off".
function NS.EnabledStored()
  local s = NS.db and NS.db.global and NS.db.global.settings
  if type(s) ~= "table" then return true end
  return s.enabled ~= false
end

--- Re-read the stored path and re-run the empty/non-empty decision.
---
--- For AceDB's profile callbacks (slash-commands-§7): a profile switch can flip the stored path
--- with no verb and no checkbox being touched, so the addon re-reads it and gets a stand-down or a
--- stand-up only if the new profile actually disagrees with the old one. `Reevaluate` fires a
--- callback only on a real edge, so calling this on every callback is free.
function NS.ReevaluateEnabled()
  NS.SetDisabledHold(not NS.EnabledStored())
  if NS.Lifecycle then NS.Lifecycle:Reevaluate() end
end
