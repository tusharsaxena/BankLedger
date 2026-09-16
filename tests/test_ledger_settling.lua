-- tests/test_ledger_settling.lua — WHEN a reconcile actually runs: registration resilience against
-- a retired event name, the debounce, the settle wait for halves that arrive seconds apart, and the
-- guarantee that the wait does not poll.
--
-- Peeled out of tests/test_ledger.lua, which had reached 1539 lines against layout-§1's 1500-line
-- cap. These four sections are one subject and nothing outside them reads their helpers — `reEnable`
-- and `listHas` are used by these cases alone and came across whole. Not one assertion changed.

local T = _G.BL_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local S = dofile("tests/ledger_support.lua")
local withContainers = S.withContainers
local BAG_ID, BANK_ID, WARBAND_ID = S.BAG_ID, S.BANK_ID, S.WARBAND_ID

-- ── Event registration resilience ──────────────────────────────────────────────
-- The second fault behind "nothing is tracked": on modern retail RegisterEvent RAISES on a retired
-- event name, so a bare registration loop aborts and leaves every later event unbound. The addon
-- then hears one event and goes deaf, with no error unless script errors are switched on.

-- Unregisters the LEDGER'S events first, and only those. The kit (revision 17) raises for a name in
-- __badEvents where the client raises: from AceEvent's OnUsed, which runs only for an event's FIRST
-- registrant. The runner's own NS.Ledger:Enable() has already registered every capture event on
-- NS.addon, so a re-registration would not raise, and the retired-event cases would pass a build
-- that never refused anything. Clearing the Ledger's events makes each registration below a first
-- one again.
--
-- Not UnregisterAllEvents: that also strips the addon's own PLAYER_ENTERING_WORLD and PLAYER_REGEN_*
-- registrations from OnEnable, which nothing here re-registers, so every later case would run
-- against a deaf addon object. Both of the Ledger's lists are walked, because a refused
-- registration still leaves its callback behind (CallbackHandler stores it before OnUsed raises),
-- and a leftover would turn the next refusal of that name into a silent re-registration.
local function reEnable(badEvents)
  local L = NS.Ledger
  for _, list in ipairs({ L.registeredEvents, L.unavailableEvents }) do
    for _, event in ipairs(list) do NS.addon:UnregisterEvent(event) end
  end
  mocks.__badEvents = badEvents or {}
  NS.Ledger._enabled = nil
  NS.Ledger:Enable()
  mocks.__badEvents = {}
end

local function listHas(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

-- The helper's own guard rail. reEnable used to clear EVERY event on NS.addon, which took the
-- addon's own OnEnable registrations with it and left each later case running against an addon
-- that no longer heard a zone change or a combat transition. The runner's lifecycle kick enables the
-- Ledger alone, so those registrations exist only once a case has run addon:OnEnable: the leak was
-- latent in today's suite order, and bit whichever case came after one. So the case arms them
-- itself, through the real OnEnable with the two window arms held off (the Ledger's own guard makes
-- its arm a no-op), and hands the build back as it found it. Asserted both ways: the registrations
-- are still recorded, and the kit's dispatch still reaches the method they name.
test("reEnable leaves the addon's own event registrations standing", function()
  local own = {
    PLAYER_ENTERING_WORLD = "OnEnterWorld",
    PLAYER_REGEN_DISABLED = "OnCombatChanged",
    PLAYER_REGEN_ENABLED  = "OnCombatChanged",
  }
  local before = {}
  for event in pairs(own) do before[event] = NS.addon.__events[event] end
  local browserEnable, sessionEnable = NS.Browser.Enable, NS.SessionWindow.Enable
  NS.Browser.Enable, NS.SessionWindow.Enable = nil, nil
  local armed, armErr = pcall(NS.addon.OnEnable, NS.addon)
  NS.Browser.Enable, NS.SessionWindow.Enable = browserEnable, sessionEnable
  assertTrue(armed, armErr)
  for event, method in pairs(own) do
    assertEqual(NS.addon.__events[event], method, event .. " was not registered before reEnable")
  end

  reEnable({ PLAYERBANKSLOTS_CHANGED = true })
  reEnable(nil)

  local survived = {}
  for event in pairs(own) do survived[event] = NS.addon.__events[event] end
  local original, calls = NS.addon.OnCombatChanged, 0
  NS.addon.OnCombatChanged = function() calls = calls + 1 end
  local ok, err = pcall(mocks.__fireEvent, "PLAYER_REGEN_DISABLED")
  NS.addon.OnCombatChanged = original
  for event in pairs(own) do
    if before[event] == nil then NS.addon:UnregisterEvent(event) end
  end

  assertTrue(ok, err)
  for event, method in pairs(own) do
    assertEqual(survived[event], method, event .. " did not survive reEnable")
  end
  assertEqual(calls, 1, "PLAYER_REGEN_DISABLED no longer reaches the addon after reEnable")
end)

test("Ledger:Enable registers every event on a build that has them all", function()
  reEnable(nil)
  assertEqual(#NS.Ledger.unavailableEvents, 0, "nothing rejected")
  assertTrue(listHas(NS.Ledger.registeredEvents, "BAG_UPDATE_DELAYED"))
  assertTrue(listHas(NS.Ledger.registeredEvents, "BANKFRAME_OPENED"))
end)

test("Ledger:Enable survives a retired event and still binds the rest", function()
  -- The regression, in its general form: Blizzard retires an event name the addon still asks for,
  -- and modern retail RAISES on the unknown name instead of ignoring it. Before this fix that abort
  -- took the rest of the loop with it — BAG_UPDATE_DELAYED never bound, so no bag change ever
  -- reached Reconcile and not one movement was recorded. (The original offender was the reagent
  -- bank's own event, retired with the reagent bank itself; any name can be next.)
  reEnable({ PLAYERBANKSLOTS_CHANGED = true })
  assertTrue(listHas(NS.Ledger.unavailableEvents, "PLAYERBANKSLOTS_CHANGED"),
    "the retired event is recorded, not fatal")
  assertTrue(listHas(NS.Ledger.registeredEvents, "BAG_UPDATE_DELAYED"),
    "the event capture actually depends on still bound")
end)

test("Ledger:Enable binds the capture events even when several are retired", function()
  reEnable({
    PLAYERBANKSLOTS_CHANGED = true,
    GUILDBANKBAGSLOTS_CHANGED = true,
    GUILDBANKFRAME_CLOSED = true,
  })
  assertEqual(#NS.Ledger.unavailableEvents, 3)
  assertTrue(listHas(NS.Ledger.registeredEvents, "BAG_UPDATE_DELAYED"))
  assertTrue(listHas(NS.Ledger.registeredEvents, "PLAYER_MONEY"))
  assertTrue(listHas(NS.Ledger.registeredEvents, "BANKFRAME_OPENED"))
end)

test("Ledger:Enable never lets a rejected open event silence the others", function()
  reEnable({ GUILDBANKFRAME_OPENED = true })
  assertTrue(listHas(NS.Ledger.registeredEvents, "BANKFRAME_OPENED"))
  assertTrue(listHas(NS.Ledger.unavailableEvents, "GUILDBANKFRAME_OPENED"))
end)

test("Ledger:RegisterEventSafely reports whether the binding took", function()
  mocks.__badEvents = { NONESUCH_EVENT = true }
  NS.Ledger.registeredEvents, NS.Ledger.unavailableEvents = {}, {}
  assertTrue(NS.Ledger:RegisterEventSafely(NS.addon, "BAG_UPDATE_DELAYED", function() end))
  assertFalse(NS.Ledger:RegisterEventSafely(NS.addon, "NONESUCH_EVENT", function() end))
  mocks.__badEvents = {}
  reEnable(nil)
end)

test("Ledger:Diagnose names the events this build rejected", function()
  reEnable({ PLAYERBANKSLOTS_CHANGED = true })
  local text = table.concat(NS.Ledger:Diagnose(), "\n")
  assertTrue(text:find("events UNAVAILABLE (1)", 1, true) ~= nil)
  assertTrue(text:find("PLAYERBANKSLOTS_CHANGED", 1, true) ~= nil)
  reEnable(nil)
end)

-- ── Debounced reconcile ────────────────────────────────────────────────────────
-- The third fault behind "warband movements are never recorded": one deposit reports itself through
-- several events that do NOT arrive together. Reconciling per event split a single movement across
-- two passes — the first saw bags -1 with the store unchanged, the second saw store +1 with the bags
-- unchanged — and the "both sides must change" rule correctly rejected both halves.

test("Ledger:ScheduleReconcile coalesces a burst of events into ONE pass", function()
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = 171276, count = 1 } },
    [WARBAND_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    NS.Ledger:ScheduleReconcile()
    NS.Ledger:ScheduleReconcile()
    NS.Ledger:ScheduleReconcile()
    assertEqual(mocks.__fireTimers(), 1, "three events, one reconcile pass")
  end)
end)

test("Ledger: a movement whose halves arrive in separate events is still recorded", function()
  -- The exact live repro: BAG_UPDATE_DELAYED lands with the bags already changed while the warband
  -- tabs are still stale, and the warband update follows on its own beat. Both must land in one pass.
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = 171276, count = 6 } },
    [WARBAND_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}

    -- Event 1: the bags have dropped the stack; the warband tab has not caught up yet.
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:ScheduleReconcile()

    -- Event 2, moments later: the warband tab now shows it.
    mocks.__containers[WARBAND_ID][1] = { itemID = 171276, count = 6 }
    NS.Ledger:ScheduleReconcile()

    mocks.__fireTimers()
    assertEqual(NS.Database:Count(), before + 1, "one warband row, not zero")
    local e = NS.Database:Ledger()[NS.Database:Count()]
    assertEqual(e.store, "WARBAND_BANK")
    assertEqual(e.direction, "DEPOSIT")
    assertEqual(e.quantity, 6)
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger: a withdrawal whose halves arrive separately is also recorded", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]     = { slots = 1 },
    [WARBAND_ID] = { slots = 1, [1] = { itemID = 171276, count = 2 } },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[WARBAND_ID][1] = nil
    NS.Ledger:ScheduleReconcile()
    mocks.__containers[BAG_ID][1] = { itemID = 171276, count = 2 }
    NS.Ledger:ScheduleReconcile()
    mocks.__fireTimers()
    assertEqual(NS.Database:Ledger()[NS.Database:Count()].direction, "WITHDRAW")
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger: two separate actions stay two separate rows", function()
  -- Debouncing must group by user action, not merge everything: a second deposit after the first
  -- pass has settled is its own movement.
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 2, [1] = { itemID = 171276, count = 1 },
                             [2] = { itemID = 2589, count = 1 } },
    [BANK_ID] = { slots = 2 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = 171276, count = 1 }
    NS.Ledger:ScheduleReconcile()
    mocks.__fireTimers()

    mocks.__containers[BAG_ID][2] = nil
    mocks.__containers[BANK_ID][2] = { itemID = 2589, count = 1 }
    NS.Ledger:ScheduleReconcile()
    mocks.__fireTimers()
    assertEqual(NS.Database:Count(), before + 2)
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 or e.itemID == 2589 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger:ScheduleReconcile does nothing when no frame is open", function()
  NS.Ledger:CancelPendingReconcile()
  NS.State.openContext, NS.State.lastSnapshot = nil, nil
  mocks.__timers = {}
  NS.Ledger:ScheduleReconcile()
  assertEqual(#mocks.__timers, 0, "no timer armed outside a bank")
end)

test("Ledger:CloseContext runs the pending pass instead of waiting out the debounce", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 171276, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = 171276, count = 1 }
    NS.Ledger:ScheduleReconcile()
    NS.Ledger:CloseContext()   -- the frame closes before the timer would have fired
    assertEqual(NS.Database:Count(), before + 1, "the in-flight movement was not lost")
    assertEqual(mocks.__fireTimers(), 0, "and the pending timer was canceled, not left to double-fire")
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
end)

-- ── Settling: halves that arrive SECONDS apart ─────────────────────────────────
-- Debouncing groups events that arrive together. It cannot help when the two sides of one movement
-- are a server round-trip apart — the live warband bank took over a second. So the baseline is held
-- whenever a pass sees a one-sided change, instead of advancing past a transaction still in flight.

test("Ledger.SnapshotsDiffer spots a change on any side", function()
  local base = { bags = { [1] = 1 }, stores = { BANK = { [2] = 1 } }, money = 5 }
  assertFalse(NS.Ledger.SnapshotsDiffer(base, base), "identical")
  assertTrue(NS.Ledger.SnapshotsDiffer(base,
    { bags = {}, stores = { BANK = { [2] = 1 } }, money = 5 }), "bags changed")
  assertTrue(NS.Ledger.SnapshotsDiffer(base,
    { bags = { [1] = 1 }, stores = { BANK = {} }, money = 5 }), "a store changed")
  assertTrue(NS.Ledger.SnapshotsDiffer(base,
    { bags = { [1] = 1 }, stores = { BANK = { [2] = 1 } }, money = 9 }), "money changed")
end)

test("Ledger: a movement whose halves are SECONDS apart is still recorded", function()
  -- The live repro that debouncing alone could not reach: the bags update, a whole second passes
  -- with several reconcile passes in between, and only then does the warband tab catch up.
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]     = { slots = 1, [1] = { itemID = 171276, count = 9 } },
    [WARBAND_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")

    -- The bags drop the stack. Several passes fire while the warband tab is still stale.
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:Reconcile()
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "nothing recorded yet — only one side has moved")

    -- A second later the warband tab reflects it.
    mocks.__now = mocks.__now + 1
    mocks.__containers[WARBAND_ID][1] = { itemID = 171276, count = 9 }
    NS.Ledger:Reconcile()

    assertEqual(NS.Database:Count(), before + 1, "the held baseline still saw the bags half")
    local e = NS.Database:Ledger()[NS.Database:Count()]
    assertEqual(e.store, "WARBAND_BANK")
    assertEqual(e.direction, "DEPOSIT")
    assertEqual(e.quantity, 9)
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
  assertEqual(NS.Database:Count(), before)
end)

-- Money end-to-end, through the real reconcile path. The Diff tests prove the rule; these two prove
-- the rule survives the settle machinery, which is where a corroborated movement could still be
-- lost (the store's balance lands a pass later than the purse).

test("Ledger: gold spent at the bank window is not recorded as a warband deposit", function()
  -- F-001, end to end: buying a bank tab. The purse falls by 1000g and the warband bank receives
  -- nothing. Before C-001 this wrote a permanent "1000g deposited to the Warband Bank" row.
  local before = NS.Database:Count()
  local savedMoney, savedWarband = mocks.__money, mocks.__warbandMoney
  withContainers({ [BAG_ID] = { slots = 1 }, [WARBAND_ID] = { slots = 1 } }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__money = mocks.__money - 10000000
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "the purse moved alone — nothing is provable")

    -- And it must not sit in the held baseline waiting to pair with something later either.
    mocks.__now = mocks.__now + NS.Ledger.SETTLE_TIMEOUT_SECONDS + 1
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "still no phantom row after the baseline re-anchors")
  end)
  mocks.__money, mocks.__warbandMoney = savedMoney, savedWarband
end)

test("Ledger: a real gold deposit still records when the store balance lands a pass later", function()
  -- The corroboration must not cost real rows. The purse updates on PLAYER_MONEY; the store's own
  -- balance can lag. The held baseline is what carries the purse half across to the pass that sees
  -- the other half — the same mechanism the item path already relies on.
  local before = NS.Database:Count()
  local savedMoney, savedWarband = mocks.__money, mocks.__warbandMoney
  withContainers({ [BAG_ID] = { slots = 1 }, [WARBAND_ID] = { slots = 1 } }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__money = mocks.__money - 500000
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "nothing recorded yet — the balance has not landed")

    mocks.__now = mocks.__now + 1
    mocks.__warbandMoney = mocks.__warbandMoney + 500000
    NS.Ledger:Reconcile()

    assertEqual(NS.Database:Count(), before + 1, "the held baseline still saw the purse half")
    local e = NS.Database:Ledger()[NS.Database:Count()]
    assertEqual(e.kind, "MONEY")
    assertEqual(e.store, "WARBAND_BANK")
    assertEqual(e.direction, "DEPOSIT")
    assertEqual(e.quantity, 500000)
  end)
  mocks.__money, mocks.__warbandMoney = savedMoney, savedWarband
  NS.Database:Delete(function(e) return e.kind == "MONEY" and e.quantity == 500000 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger: a one-sided change that never completes re-anchors after the timeout", function()
  -- Loot landing in the bags while the bank is open never balances. The baseline must not stay
  -- pinned for the rest of the session, or a stale delta would eventually pair with something
  -- unrelated and invent a movement.
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1 },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = { itemID = 19019, count = 1 }   -- looted, not withdrawn
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "not a movement")

    mocks.__now = mocks.__now + NS.Ledger.SETTLE_TIMEOUT_SECONDS + 1
    NS.Ledger:Reconcile()

    -- The baseline has re-anchored, so the loot is now part of the accepted state.
    assertFalse(NS.Ledger.SnapshotsDiffer(NS.State.lastSnapshot,
      NS.Ledger:Snapshot("BANK_FRAME")), "baseline caught up")
    assertEqual(NS.Database:Count(), before, "and still no phantom row")
  end)
end)

test("Ledger: a re-anchored loot does not pair with a later unrelated deposit", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 2, [1] = { itemID = 2589, count = 1 } },
    [BANK_ID] = { slots = 2 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    -- Loot arrives in the bags and never balances; let it time out.
    mocks.__containers[BAG_ID][2] = { itemID = 19019, count = 1 }
    NS.Ledger:Reconcile()
    mocks.__now = mocks.__now + NS.Ledger.SETTLE_TIMEOUT_SECONDS + 1
    NS.Ledger:Reconcile()

    -- Now genuinely deposit the OTHER item.
    mocks.__containers[BAG_ID][1] = nil
    mocks.__containers[BANK_ID][1] = { itemID = 2589, count = 1 }
    NS.Ledger:Reconcile()

    assertEqual(NS.Database:Count(), before + 1, "exactly one row, for the real deposit")
    assertEqual(NS.Database:Ledger()[NS.Database:Count()].itemID, 2589)
  end)
  NS.Database:Delete(function(e) return e.itemID == 2589 end)
  assertEqual(NS.Database:Count(), before)
end)

test("Ledger: an unchanged world advances the baseline without waiting", function()
  withContainers({ [BAG_ID] = { slots = 1 }, [BANK_ID] = { slots = 1 } }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    NS.Ledger:Reconcile()
    assertEqual(NS.Ledger._settleSince, nil, "nothing in flight, nothing to wait for")
  end)
end)

test("Ledger: a completed movement clears the settle wait", function()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 171276, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:Reconcile()                       -- one-sided: starts waiting
    assertTrue(NS.Ledger._settleSince ~= nil, "waiting for the other half")
    mocks.__containers[BANK_ID][1] = { itemID = 171276, count = 1 }
    NS.Ledger:Reconcile()                       -- completes
    assertEqual(NS.Ledger._settleSince, nil, "wait cleared")
  end)
  NS.Database:Delete(function(e) return e.itemID == 171276 end)
end)

-- ── The settle wait must not poll ──────────────────────────────────────────────
-- Deleting an item with the bank open is a one-sided change that will never balance. Waiting it out
-- is correct; rescanning every half-second for the whole window is not — each pass walks the bags,
-- six bank tabs and five warband tabs. The other half of a real movement always arrives with an
-- event, so the timer is a give-up deadline rather than a poll.

test("Ledger: a deletion writes no row and arms ONE deadline, not a poll", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 19019, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[BAG_ID][1] = nil          -- deleted, not deposited
    NS.Ledger:Reconcile()
    assertEqual(NS.Database:Count(), before, "a deletion is not a movement")
    assertEqual(#mocks.__timers, 1, "one deadline armed")
  end)
end)

test("Ledger: the deadline is armed for the REMAINING window, not a fixed retry", function()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 19019, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:Reconcile()
    assertEqual(mocks.__timers[1].delay, NS.Ledger.SETTLE_TIMEOUT_SECONDS,
      "the first wait covers the whole window")

    -- An event arrives partway through and re-checks; the deadline must survive, shortened.
    mocks.__now = mocks.__now + 4
    mocks.__timers = {}
    NS.Ledger:Reconcile()
    assertEqual(mocks.__timers[1].delay, NS.Ledger.SETTLE_TIMEOUT_SECONDS - 4,
      "re-armed on what is left, so the deadline cannot be pushed out forever")
  end)
end)

test("Ledger: the deadline never schedules a near-zero timer", function()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 19019, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:Reconcile()
    mocks.__now = mocks.__now + NS.Ledger.SETTLE_TIMEOUT_SECONDS - 0.1
    mocks.__timers = {}
    NS.Ledger:Reconcile()
    assertTrue(mocks.__timers[1].delay >= NS.Ledger.SETTLE_MIN_RECHECK_SECONDS,
      "floored, got " .. tostring(mocks.__timers[1].delay))
  end)
end)

test("Ledger: firing the deadline re-anchors and stops waiting", function()
  local before = NS.Database:Count()
  withContainers({
    [BAG_ID]  = { slots = 1, [1] = { itemID = 19019, count = 1 } },
    [BANK_ID] = { slots = 1 },
  }, function()
    NS.Ledger:OpenContext("BANK_FRAME")
    mocks.__timers = {}
    mocks.__containers[BAG_ID][1] = nil
    NS.Ledger:Reconcile()

    mocks.__now = mocks.__now + NS.Ledger.SETTLE_TIMEOUT_SECONDS
    mocks.__fireTimers()

    assertEqual(NS.Ledger._settleSince, nil, "no longer waiting")
    assertEqual(NS.Database:Count(), before, "and still no phantom row")
    assertEqual(#mocks.__timers, 0, "nothing left armed")
  end)
end)
