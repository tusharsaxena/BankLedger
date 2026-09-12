# 04 — Execution plan

Fences held throughout: `libs/` and `tests/_kit/` were written only by the whole-folder copy in
`843c6d8`. No production file changed for either candidate, and no close control was touched.

## B1 — AceEvent Embed and the message bus (#18)

- **Touches:** `tests/wow_mock.lua` (delete `embedBus` and the local `libs["AceEvent-3.0"]`; the
  local `NewAddon` embeds the kit's AceEvent first and keeps its own event stamps on top, because
  the addon's event half is B2's), `tests/test_lifecycle.lua`.
- **Characterization first:** the swap, then the full suite, before any new case. Result: 852/852,
  so nothing that already existed moved.
- **The assertion that proves it:** a new case. The Browser and SessionWindow bus targets record
  `PLAYER_LOGOUT` in `__events` as a function, and `addon:OnDisable` clears it and each target's
  `LedgerChanged` subscription in `M.__msgRegistry`. Red against the pre-swap harness ("did not
  record PLAYER_LOGOUT"), green after.
- **Commit boundary:** `b2df58c`, 853/853, luacheck 0/0.

## B2 — NewAddon, AceTimer and AceConsole (#19)

One library at a time, with the full suite after each swap:

| Step | Swap | Suite |
|---|---|---|
| B2.1 | AceTimer: the local `ScheduleTimer`/`CancelTimer` stamps and the local `__timers`/`__fireTimers` give way to the kit's. `C_Timer.After` stays a no-op, set on the kit's table instead of replacing it. | 853/853 |
| B2.2 | AceConsole: the local no-op `RegisterChatCommand` and the `Print` that returned a string give way to the kit's Embed (`Print` and `Printf`, both clobbering `NS.Print`, as the real one does). | 853/853 |
| B2.3 | The addon object's event half: the local `RegisterEvent` raiser and no-op unregisters give way to the kit's. The local `M.__badEvents` goes too, since the kit publishes it. | **849/853**: four `reEnable` cases red, as the version-17 document predicts |
| B2.3a | `tests/test_ledger.lua`'s `reEnable` unregisters the addon's events first, so each re-registration is a first registrant again | 853/853 |
| B2.4 | The local `NewAddon` is deleted, so the kit builds the addon object | 854/854, with the new case |

- **The assertion that proves it:** a new case. `NS.addon.Printf` is the kit's AceConsole mixin,
  `NS.Print` is still `NS.Util.print`, the addon records `PLAYER_ENTERING_WORLD` → `OnEnterWorld`
  and both `PLAYER_REGEN_*` → `OnCombatChanged`, and the kit names the object and serves it from
  `GetAddon`. Red against the pre-B2 harness ("the AceConsole embed stamped no Printf"), green
  after.
- **Commit boundary:** `aef3e6a`, 854/854, luacheck 0/0. It also carries the wow_mock header's
  override list and `docs/testing.md`'s harness paragraph.

## What stays local, per the version-17 document

The frame stub (real geometry, OnHide, recorded `SetTexture`/`SetText`), frames shown by default,
the `defaultedStore` AceDB, `__settingsPanels`, the plain-table `DEFAULT_CHAT_FRAME`, the nil
`GameTooltip` and `StaticPopup_Show`, the `SetTitle` wrap on AceGUI, `LibStub.minors`, the no-op
`C_Timer.After` and the fixed clock. All are still in `tests/wow_mock.lua`, and nothing else is.
