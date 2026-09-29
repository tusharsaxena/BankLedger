# Profiles

Bank Ledger keeps its settings in AceDB profiles and its history account-wide. This page says what a
profile holds, what stays outside every profile, how the addon reacts when the profile changes, and
how the old account-wide settings got into a profile. The stored shape is in
[schema.md](schema.md); the panel page is in [settings-panel.md](settings-panel.md).

## What a profile holds, and what it does not

| Scope | Where | What |
|---|---|---|
| **Profile** (`db.profile`) | `defaults/Profile.lua` | Every schema row but the two account-wide ones, retention and the Minimap button (`settings.*`: enabled, capture, visibility, scale, alpha, lock, row tints, the session window switch), both item-id filter lists (`blacklist`, `whitelist`), the saved ledger view (`savedView`), and both windows' stored geometry (`settings.window`, `settings.sessionWindow`) |
| **Account-wide** (`db.global`) | `defaults/Global.lua` | The recorded ledger (`ledger`), the retention window that governs it (`settings.retentionDays`, *Keep history for*), LibDBIcon's `minimap` table (whether the button is shown, and its angle), the `schemaVersion` stamp |
| **Session only** | `NS.State` | Test mode, the debug console window, the debug logging flag, the open banking session |

The split is the owner's decision D5 (2026-09-29): **settings only**. A ledger is a record of what
happened to the account, and a per-character history would split the very thing the addon exists to
join up, so the history is in no profile. Everything a player configures is, with one exception.

**Retention is account-wide** (owner decision D6, 2026-09-29). *Keep history for* decides how much
of the shared ledger is kept, so it is one value for the whole account, stored at
`db.global.settings.retentionDays`. Its schema row carries its own `get`/`set` onto that store, and
the Settings tooltip says the value is shared by every profile. No profile switch, copy or reset
changes it, and none of them prunes: the retention prune runs at login and when the row itself is
changed, and never on a profile event.

The db is created with `AceDB:New("BankLedgerDB", NS.defaults, true)`: the `true` puts every
character on one shared profile, `Default`, until the player picks another. So out of the box the
addon behaves exactly as it did when the settings were account-wide.

## The Profiles page

**Settings → AddOns → Ka0s Bank Ledger → Profiles** (`settings/Profiles.lua`, `options-ui-§3`) is
AceDBOptions' own control set: choose a profile, create one, copy another into the current one,
delete one, and reset the current one. It is drawn by AceConfigDialog into an AceGUI group inside a
canvas subcategory, registered after General so it is last in the tree, with **no Defaults button**.
It is the only AceConfig use in the addon. No slash verb switches profiles today; this page is the
control.

## One adopt path for every profile event

AceDB fires `OnProfileChanged` on a switch, `OnProfileCopied` on a copy and `OnProfileReset` on a
reset. All three reach **`NS.OnProfileEvent`** (`core/Database.lua`), and it does the same thing
for each, in this order:

1. **`NS:RunMigrations()`** — a no-op while the stamp is current (`savedvariables-§1`).
2. **`NS.ReevaluateEnabled()`** — `settings.enabled` belongs to the profile, so a switch to a profile
   where it is off **stands the addon down**, and back stands it up (`slash-commands-§7`). The
   latch fires only on a real edge.
3. **One `SettingsChanged("profile")`** — the capture gate re-caches its settings and both lists,
   and the windows re-apply their chrome.
4. **One `LedgerChanged`**, through `Database:FireLedgerChanged` — the new profile's filter lists
   decide what the History table, Insights, the session window and the Filters tab show.
5. **Every setting's effect re-applied** (`applyProfileEffects`): both windows re-anchored from the
   new profile's geometry, the ledger window put on the new profile's saved view (or stock), master
   scale, alpha and lock, visibility, and the row tint. **No retention prune**: the window is
   account-wide and a profile event never deletes history (D6).
6. **The open panel refreshed** (`options-ui-§11`).
7. **Exactly one debug line for the act** (`debug-logging-§10`), worded by the event:
   - a switch: `[Profile] switched to profile '<name>'` (no rows are rewritten, so it is not a
     `[Set]` line);
   - a copy: `[Set] copied profile '<source>' -> '<current>'`;
   - a reset: `[Set] reset profile '<name>' to defaults (N rows)`, N counted by
     `Sl:ResetEverything` before the reset; a reset from the Profiles page's own button logs the
     same line without the count.

   The one kind of line that can sit beside it does not restate the act: a view that is built
   repaints, as it does on any setting change, logging its one-per-pass render summary
   (`[Table] rendered …`, `[Insights] computed …`, `debug-logging-§9`). `tests/test_profiles.lua`
   counts every other line under the shipped 30-day retention, so neither a `[Prune]` line nor a
   per-row `[Set]` can come back unseen.

No row's `onChange` runs on a profile event: AceDB replaces the whole profile, which is not a write
through the seam. A setting whose effect is more than the bus message has to be in
`applyProfileEffects` (see [common-tasks.md](common-tasks.md) → *Add a setting*).

**No profile event prunes history.** An earlier build of this branch kept *Keep history for* in the
profile and ran the prune on every profile event, so switching to a profile with a shorter window
deleted history every other profile still showed. D6 moved the window back to `db.global` and took
the prune out of the adopt path.

## The global reset is a profile reset

*Reset all settings*, the General page's **Defaults**, Blizzard's footer **Defaults** and
`/bl resetall` all raise the one confirm popup, `KA0S_BANKLEDGER_RESETALL`, whose text is
`options-ui-§12`'s first canonical wording. **Yes** runs `Sl:ResetEverything`, which counts the rows
it will change and calls **`db:ResetProfile()`**. The Profiles page's **Reset Profile** is the same
act, without the popup: on `OnProfileReset` the adopt path also ends the session-only rows a profile
reset cannot reach (test mode, the debug console) by name, whichever control raised it.

It resets the **active profile only**: the other profiles and the profile list are untouched. It
**never deletes history**: this addon has both a profile and an account-wide store, and
`options-ui-§12` keeps the account-wide store out of a settings reset. Deleting history is
`/bl purge`, which asks separately. The retention window is account-wide too, so the reset leaves
*Keep history for* as it is and cannot trigger a prune (D6). LibDBIcon's table is account-wide as
well, so the reset leaves the minimap button where it is (`launcher-§3`).

**The row veto is named once**, as `S.VetoedFromResetAll` in `settings/Schema.lua`, and the Options
descriptor passes it to the library as `skipRestoreAll` (`options-ui-§3`, `options-ui-§12`): the
Profiles page (`S.PROFILES_PAGE`, the page's own key) and every stored row, profile or account-wide,
are vetoed, so a row walk (the library's `O.RestoreAllDefaults`) reaches only the session-only rows.
This addon's own reset walks no rows at all; the veto states the exclusion for the library's walk,
the same shape KickCD, WhatGroup, PrettyChat and Loot History ship. The retention row and the
Minimap button row are also on `S.RESET_EXEMPT`, so the Slash library's sweep skips both, while
`/bl reset settings.retentionDays` (the player naming the row) still applies.

## Schema v3 and v4: how the settings got into the profile

Until schema v3 every setting, both filter lists and the saved view lived in `db.global`.
`NS.MIGRATIONS[3]` moves each stored value of `settings`, `blacklist`, `whitelist` and `savedView`
from `db.global` into the raw `Default` profile (`db.sv.profiles.Default`, created if absent) and
clears it from `db.global`, except the account-wide settings keys (`NS.GLOBAL_SETTINGS`, today
`retentionDays` alone), which stay in `db.global.settings`. The runner runs straight after
`AceDB:New`, before anything reads `db.profile`, so the profile AceDB then builds is built over the
lifted values. A second run finds nothing left in `db.global` and moves nothing. The ledger and the
`minimap` table stay where they are.

`NS.MIGRATIONS[4]` repairs a store an earlier build of v3 wrote, which lifted `retentionDays` into
the profile with everything else. It walks every stored profile raw and takes the key out of each.
The value kept in `db.global` is a player choice already there (one off the declared default), else
the `Default` profile's; no other profile's value is ever promoted. A `Default` profile without the
key holds that build's 30-day profile default (AceDB's logout strip drops a stored default), so a
shorter window in another profile never becomes the account's. A second run finds no key in any
profile, and a v2 upgrade (whose v3 never lifted the key) has nothing to move. Detail in
[schema.md](schema.md) → *Schema v3*.

## Tests

`tests/test_profiles.lua` pins the split, the v3 lift (values land in `Default`, `db.global` is
cleared, the retention window stays, the ledger is untouched, a second run is a no-op, reads resolve
against the profile), the v4 return of the window (the `Default` profile's value wins, its implicit 30 included, a
global choice is kept, every profile is cleared, a second run is a no-op), the account-wide window (a write
lands in `db.global`, every profile and the prune read the one value, a stale profile copy is
ignored, the tooltip says so), the adopt path (a switch re-reads settings, re-caches the gate, drives
the latch, re-applies chrome and geometry, sends one message of each kind and logs one line; a copy
and a page-driven reset log theirs; a reset from the page ends test mode and closes the console;
no switch, copy, profile reset or global reset prunes history or moves the window), the reset veto
(what it vetoes, its `skipRestoreAll` wiring, and the library's walk over it) and the Profiles
page's registration. The reset's blast radius (`options-ui-§12`: the active profile only, the profile list,
the other profiles and the ledger untouched) is pinned there too, and the reset routes in
`tests/test_reset_routes.lua` and `tests/test_panel.lua`.
