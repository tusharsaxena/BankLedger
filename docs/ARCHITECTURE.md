# Architecture — Ka0s Bank Ledger

Engineer context for the addon, and the **hub** of its doc set: each section below summarizes and
links, it does not store (`documentation-§3`). Player-facing docs live in the root `README.md`; how to
verify it is `docs/testing.md`. The Ka0s WoW Addon Standard itself is the upstream repo linked from
`CLAUDE.md` — it is read there, never copied in here.

## At a glance

| | |
|---|---|
| Folder / TOC `Title` | `BankLedger` / `Ka0s Bank Ledger` |
| Scope | Retail (Mainline) only — a single `## Interface:` line, currently `120100` |
| SavedVariables | `BankLedgerDB`, **account-wide `global` only** (see *Documented deviations*) |
| Slash | `/bl`, aliased `/bankledger` |
| Chat tag | `NS.PREFIX` — the cyan bracketed `[BL]` tag (`\|cff00ffff[BL]\|r`) |
| Layout | `core/ defaults/ locales/ modules/ settings/`, 30 source files |
| Substrate | Ace3 + vendored `LibKa0s`, all committed under `libs/` |

## Overview

Bank Ledger records **movements**, not inventory. It never stores "what is in your bank"; it stores
"what crossed the line between your bags and a bank, when, and which way".

WoW fires no "you deposited this" event, so a movement has to be derived: the addon snapshots the bags
plus every store the open frame can reach, diffs consecutive snapshots per store, and records only
what changed on **both** sides. Gold follows the same corroboration rule at the two stores that hold
it. Capture is completely inert outside an open storage frame, which is what keeps a vendor sale or a
quest turn-in out of the book.

Full pipeline — the corroboration rule, bonus-ID survival, frames-not-stores, and the event
choreography — in **[data-flow.md](data-flow.md)**. What is deliberately out of scope is
**[scope.md](scope.md)**.

## Module Map

30 source files across `core/ defaults/ locales/ modules/ settings/`. `core/` holds the bootstrap,
the Compat firewall, the AceDB layer and the eight LibKa0s seams; `modules/` holds the capture engine
and every window; `settings/` holds the schema and the two panel pages.

Load order is load-bearing in six places, and `tests/test_harness.lua` guards the order the harness
derives from the TOC. File-by-file table, load-order notes and the locale seam in
**[module-map.md](module-map.md)**; the API firewall in **[compat-layer.md](compat-layer.md)**.

## Settings Schema

**Sixteen** schema rows in `settings/Schema.lua` — the single source for the panel widgets, the
`/bl get|set|list|reset` dispatch and the defaults reset. Every write to a schema-row path goes through
`NS.Schema:Set`, so a slash write and a panel widget take exactly the same path.

**A bulk reset logs one line** (`debug-logging-§10`, standard v2.44.0). `NS.Schema:Set` logs one
`[Set] <path> = <value>` per write, except inside a bulk bracket: `S.BulkBegin` / `S.BulkEnd`, which
`settings/Slash.lua` hands to the Slash descriptor as `bulkBegin` / `bulkEnd` (LibKa0s Slash minor 8).
Inside the bracket the seam mutes that line, and it counts each write whose stored value actually
changes (`S.SameValue`, deep for the set-typed row). Validation and each row's `onChange` still run
per row.
- `/bl resetall` and both Defaults controls (`P:RestoreDefaults`) reach the library's `CliResetAll`,
  which logs exactly `[Set] reset all: N rows`. N is the rows whose value changed, so a press with
  every row already at its default logs `0 rows`. The library's own `count` is not used, because it
  includes rows already at their default.
- A walk that raises part-way still logs its one line, counting the rows changed before the raise,
  with ` (stopped by an error)` appended: `[Set] reset all: N rows (stopped by an error)`. The mute
  still clears and the error is re-raised unchanged. The library hands `bulkEnd` `err = nil` for a
  raise of nil or false (documented upstream), so that raise gets no marker.
- The degraded fallback `CliResetAll` brackets its own walk the same way. It owns its pcall, so it
  marks every caught error, a nil or false raise included.
- Nested brackets log once, for the outermost act, and a level reporting `info.profileReset` silences
  the line. `P:Batch` coalesces repaints and is not a bracket.
- The Options descriptor carries no pair, because nothing here calls `O.RestoreDefaults` or
  `O.RestoreAllDefaults`.
- `Sl:ResetEverything` is a wholesale wipe, not a walk through the seam. It logs one
  `[Set] reset account-wide settings to defaults (N rows)` line, N the stored rows that were not
  already at their default, beside its `[Data] reset-all wiped N ledger entries` line.

They all live on the **General** page, which is **tabbed** (`options-ui-§13`): `group` names a tab,
the array's declaration order is the tab order, and the strip reads **Master controls** (8) ·
**Capture** (4) · **Interface** (3) · **History** (1) · **Filters**. The last carries no settings at
all — it is the retired **Filters** page's id-lists, drawn from an `afterGroup` hook under one
renderer-only row (`S.BespokeRows`) that exists to name a tab and nothing else, which is why
`NS.Schema:PageRows()` and not `NS.Schema.Schema` is what the strip partitions. Inside that tab a
**secondary** strip (`O.SubTabStrip`, `options-ui-§13`) divides Blacklist from Whitelist; its
selection is `ctx.activeSubTab["Filters"]`, session state and never persisted. Each list is one
LibKa0s `O.IdList` (`kind = "item"`, v1.35.0): the widget resolves an item id, a link or an item's
name and calls back into `NS.Filters`, which stays the lists' only writer. The client has no
item-name search (its name lookup answers only for items carried this session), so the list passes
`candidates`: both lists' ids plus every item id the ledger recorded, read from existing state. The
widget names them, suggests matches as the player types (one row per crafted-quality rank), and
refuses a shared name until one is picked. The lines are drawn **two to a row** (`columns = 2`,
LibKa0s v1.47.0): both lists are fed one id at a time out of a long ledger, so one entry per line
made a scroll re-read on every visit. It is a **maximum**, not a count -- since v1.50.0 the widget
measures the content width it has and falls back toward one column when two cannot be paid for, so
a narrow settings canvas returns the old layout with nothing here having to know its width. The
cost, taken knowingly: above one column word wrap goes off, so an entry too long for its column is
cut from the tail and loses its gray `(id)` rather than shortening it; the entry's tooltip still
carries the full name. That write fires
`LedgerChanged` synchronously, so the tab's own listener is held off for it (`filterWrite`'s
`ctx.__filterWrite`) and the widget's redraw goes through `ctx.rebuild` = `O.RefreshPanel(ctx, true)`:
one add or Remove repaints this page once, rather than twice across every rendered page.

Those five tab names and their order are **shared with Ka0s Loot History**, whose strip is the same
five with **AH Price** after Capture. The two addons keep the same shape of record and a player
compares their panels directly; one naming a subject *Capture* while the other called it *Collection*
was two names for one thing. A tab name is a `group`, never a stored path, so the convergence was a
rename and carried no migration (`options-ui-§15`).

The **Master controls** tab is composed by the library (`H.MasterControls`, `options-ui-§15`) and
spliced at the head of the array; `keys = { scale = "windowScale" }` is what keeps this addon's
stored paths. Three of its rows are new — `settings.visibility`, `settings.alpha` and
`settings.locked` — and each is honored in `NS.Util` rather than merely declared. Two other rows are
chrome literals promoted to settings in the tabbed-panel pass — `settings.rowStripeAlpha` and
`settings.rowHoverAlpha`, each defaulting to the number it replaced.

**One structural registry** (`architecture-§5`): the filter id-sets, which the player adds item ids
to and removes them from.
- **Storage keys.** `db.global.blacklist` and `db.global.whitelist`, both shipped empty in
  `defaults/Global.lua`.
- **Writer.** `NS.Filters` in `modules/Filters.lua`: `F:_move`, `F:_remove`, `F:ClearList` and
  `F:ClearAll`, with `AddBlacklist` / `AddWhitelist` / `RemoveBlacklist` / `RemoveWhitelist` over the
  first two. The Filters tab, the ledger's right-click menu, the two clear popups and
  `Sl:CliResetAll` call it, and nothing else writes either key.
- **Load pass.** There is none. AceDB supplies the empty defaults, and `NS:RunMigrations`
  (`core/Database.lua`), the only load-time pass, never touches them. `Sl:ResetEverything` empties the
  whole store, which is not a registry write.

**The movement log is recorded data**, `architecture-§5` named non-setting state. The addon records
every entry, and the player authors none, so it is not a registry, and naming it is the
compliance. It has no `Documented deviations` row.
- **Storage key.** `db.global.ledger`, an array of entries, shipped empty in `defaults/Global.lua`.
- **Owner.** `NS.Database` (`core/Database.lua`). Every runtime write is one of its five functions,
  and nothing outside it writes the key:
  - `Database:Add` appends each movement the capture engine derives (`modules/Ledger.lua`) and
    fires `EntryAdded`.
  - `Database:Delete` removes the entries a predicate matches, reached from the History table's
    right-click *Delete* (`modules/LedgerTable.lua`).
  - `Database:DeleteAt` removes one entry by index. It has no production caller; the tests use it
    as the index-delete seam.
  - `Database:Purge` wipes the log, reached from `/bl purge` and the History tab's *Purge ledger…*
    button through the confirm-gated `KA0S_BANKLEDGER_PURGE` popup.
  - `Database:PruneOld` drops entries older than the `settings.retentionDays` row allows. It runs
    from that row's `onChange` and once per session, five seconds after `PLAYER_ENTERING_WORLD`
    (`addon:OnEnterWorld`).
- **Why none of those is a player choice.** Deleting entries, purging the log and pruning it by the
  retention row are the owner's operations on recorded data. The rule allows all three.
- **Load pass.** `NS:RunMigrations` may rewrite entries in place, as its v1 → v2 step does when it
  strips `vendorPrice`, and is not a writer to name. `Sl:ResetEverything` empties `db.global`
  wholesale, ledger included, which is not a writer either. Test mode reads `NS.State.testRecords`
  and never writes the log.

**Named non-setting state** (`architecture-§5`): four **storage carve-outs** that no control sets
and no row addresses. Each is written outside `NS.Schema:Set` by the writers named below. That
naming is what makes them compliant, so none has a `Documented deviations` row. A reset below only
empties the state or puts back the shipped default, and *Save* captures what is on screen, so
neither chooses a value. The Master controls tab's *Reset position* is one of those resets.
- **Main window geometry.** Storage key `db.global.settings.window` (`point`, `x`, `y`, `w`, `h`).
  Owner `NS.Browser` (`modules/Browser.lua`). Writers: `B:SaveGeometry`, on the title bar's
  drag-stop, on the resize grip's mouse-up, on every `OnHide`, and at `PLAYER_LOGOUT` through
  `B:OnLogout`. `B:ResetWindow` empties it. Three routes reach that reset: `NS.Util.ResetWindowPositions`
  (the Master controls tab's *Reset position*, and the General page's *Defaults* button through
  `P:RestoreDefaults`), and `Sl:ResetEverything` once its wholesale reset is done.
- **Session window geometry.** Storage key `db.global.settings.sessionWindow`, same shape. Owner
  `NS.SessionWindow` (`modules/SessionWindow.lua`). Writers: `SW:SaveGeometry`, on the same four
  occasions (drag-stop, grip mouse-up, `OnHide`, and `PLAYER_LOGOUT` through `SW:OnLogout`), and
  `SW:ResetWindow`, which empties it and is reached by the same three routes as `B:ResetWindow`.
- **Saved ledger view.** Storage key `db.global.savedView`, absent until the player saves. Owner
  `NS.Browser`. Writers: `B:SaveView`, from the filter bar's **Save** button, which stores the view on
  screen whole (`B:CaptureView`), and `B:ResetView`, which clears it. The bar's **Reset** button
  calls `B:ResetView`, and so does `Sl:CliResetAll`, which is `/bl resetall` and the *Defaults*
  button.
- **Minimap button position.** Storage key `db.global.minimap.minimapPos`. Owner **`NS.Launcher`**
  (`core/LauncherSetup.lua`), which hands `db.global.minimap` to LibDBIcon at `Register` time.
  Writer: LibDBIcon itself, when the player drags the button
  (`libs/LibDBIcon-1.0/LibDBIcon-1.0.lua:194`). The addon never writes the field. The same table
  holds the `minimap.hide` row, so the addon never replaces the table whole either. AceDB supplies
  it from `defaults/Global.lua`, and the seam has no seed of its own. It was `NS.Browser`'s
  `B:SetupMinimap` until the launcher was adopted (`launcher-§1`).

`NS:RunMigrations` touches none of the four. `Sl:ResetEverything` empties `db.global` wholesale and
merges the defaults back, which replaces the first three along with everything else; the standard
does not count a wholesale replacement as a writer to name. **The fourth is the exception**: the
whole `db.global.minimap` table is held across that wipe and put back, because both keys in it are
per-installation display preferences rather than settings (`launcher-§3` — see **Launcher** below). Row table and panel structure are in
**[settings-panel.md](settings-panel.md)**; the stored shape and the carve-out rules are in
**[schema.md](schema.md)**.

## Launcher

One object, registered twice (`launcher-§1`). `core/LauncherSetup.lua` is the
**LibKa0s-Launcher-1.0 seam**: it builds a single LibDataBroker-1.1 launcher object and hands it to
LibDBIcon-1.0, so the minimap button and any broker display the player runs draw from the same
object with the same `OnClick`, the same icon and the same name. Owner **`NS.Launcher`**; registered
once from `addon:OnEnable` (`core/BankLedger.lua`), idempotently, because the disable/enable cycle
re-enters it.

| | |
|---|---|
| Registration name | `BankLedger` — the **folder** name, for both registrations. LibDBIcon and a broker display key the identity by it. It was `Ka0s Bank Ledger` before adoption. |
| Broker label | `Ka0s Bank Ledger` — the **brand name in plain text** (`launcher-§1`), which is what a broker display prints in its row beside the collection's other ten. Deliberately **not** the TOC's `## Title` (a Title may carry colour escapes) and **not** the folder name (that is the registration name above). It read `Bank Ledger` until the v2.54.0 amendment. |
| Icon | `Interface\AddOns\BankLedger\media\logos\bankledger.logo.128.tga`, the same file `## IconTexture` names (`launcher-§4`, `layout-§4`): 128×128, uncompressed 32-bit |
| Left-click | **Rung (a)** — toggles the ledger window, through `B:Toggle`, the same act `/bl toggle` runs. The rung is recorded against this addon in the standard's `ADDONS.md`. |
| Right-click | Opens the settings panel, always, whatever the left button does |
| Tooltip | The live movement count, and both click verbs |
| Visibility | The **Minimap button** row on General ▸ Master controls, stored at `db.global.minimap.hide` |
| Resets | **Neither reset reaches the row** (`launcher-§3`). Both did before the v2.54.0 amendment. |

**The row's sense is the inverse of the key's**, and that inversion lives in exactly one place:
`NS.Schema:Set` and `NS.Schema:Get`, the single write seam (`options-ui-§1`). The row says *shown*;
LibDBIcon's `hide` says hidden, and `hide` is the library's own field — it writes it itself from the
button's right-click menu, which is why there is one boolean and not a second one beside it
(`launcher-§3`). The button follows the row from the row's `onChange`, so a slash write, a panel
click and a reset all move it.

### The button survives a reset, and that is a property of the setting

Whether the button is shown is a **per-installation display preference**, in the same class as the
angle the player dragged it to — which LibDBIcon keeps in the very same table, as
`minimap.minimapPos`, and which no reset in the collection touches. `launcher-§3` therefore requires
`minimap.hide` to survive **both** *Reset all settings* and a page-scoped **Defaults** button, and
neither may re-hide a shown one either.

Until standard v2.54.0 that section *derived* the conclusion — *Reset all settings* is a profile
reset, the table is global, so the reset cannot reach it. **Neither half of that argument holds
here, and both of this addon's resets reached the row:**

| Reset | Route | Why it reached the row | The carve-out |
|---|---|---|---|
| *Reset all settings* (Master controls, confirm-gated) | `Sl:ResetEverything` | **This addon has no profile.** Everything it stores is `db.global`, so the rule's second form applies: empty the account-wide store wholesale and merge the declared defaults back — and `minimap = { hide = false }` is one of the declared defaults. A hidden button came back, at the default angle. | The `minimap` table is held and restored around the wipe. The **table**, not the `hide` key, so `minimapPos` rides with it and a future key in it needs no second edit. |
| **Defaults** (the General page's own button, and `/bl resetall`) | `P:RestoreDefaults` → `Sl:CliResetAll` → the library's row walk | The Minimap button row **is** a schema row — the Master controls composer emits it — and the walk rewrites every row carrying a `default`. This reaches the row even where the profile reasoning does hold, which is why the amended rule names it. | `NS.Schema.RESET_EXEMPT`, honored in `S:ApplyDefault`, the one seam both the descriptor's `applyDefault` and the degraded arm's walk write through. |

The veto is **bracket-scoped**: it fires only while a bulk bracket is open, which a sweep opens and a
single-row reset does not. So a targeted `/bl reset minimap.hide` is still the player naming that
exact row and still works. The three cases that pin all of it are in `tests/test_panel.lua`, beside
the other destructive-reset cases, and they read the stored byte back after running the real act.

`modules/Browser.lua` owned all of this until adoption (`B:SetupMinimap`, `B:SetMinimapHidden`);
both are gone, and `tests/test_launcher.lua` fails if either comes back.

## Message bus

Four messages, one sender each. Consumers **must** register on their own `NS.NewBusTarget()`
target, never on the shared bus-as-self: CallbackHandler keys callbacks by `(message, target)`, so
two consumers sharing a target silently clobber each other.

| Message | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_BankLedger_EntryAdded` | `Database:Add` | `entry, index` | Browser, Insights, SessionWindow, Panel (storage stats) |
| `Ka0s_BankLedger_LedgerChanged` | `Database` (delete / purge / prune / `FireLedgerChanged`) | — | Browser, Insights, SessionWindow (prunes deleted rows), Panel (storage stats + the Filters tab's id lists) |
| `Ka0s_BankLedger_SettingsChanged` | `Schema` row `onChange` handlers, and `Slash:ResetEverything` once at the end of the confirm-gated full reset | a short reason string (`enabled`, `sessionWindow`, `windowScale`, `quality`, `trackItems`, `trackMoney`, `stores`, `rowTint`, `reset`) | Ledger (re-caches its gate upvalues), Browser, SessionWindow |
| `Ka0s_BankLedger_SessionChanged` | `Ledger` (`OpenContext` / `CloseContext` / the guild-bank self-disarm) | `active` (boolean), `context` | SessionWindow |

`SessionChanged` exists so the session window rides the span the capture engine already arms
`openContext` for, instead of re-deriving it from the open/close events — which would have missed the
guild bank entirely, since that is armed by its frame's own `OnShow` rather than by an event, and
gets no close event either.

`NS.Filters` deliberately does **not** introduce a fourth sender: it calls
`Database:FireLedgerChanged()` so `Database` stays the sole emitter of that message.

## Slash Commands

`/bl`, aliased `/bankledger`, generated from `NS.COMMANDS` so `/bl help` and the settings landing
page read one table. Seventeen verbs; `settings/Slash.lua` is the LibKa0s-Slash-1.0
seam. A bare `/bl` runs `config`, which opens the settings panel on its landing page, and `/bl help`
prints the list (`slash-commands-§4`). Verb table and the host/library split in
**[slash-dispatch.md](slash-dispatch.md)**.

## The stand-down — what *disabled* means

**Disabled means the addon is not running.** Not hidden, not quiet, not skipping a repaint
(`slash-commands-§7`). A player who unticks *Enable Bank Ledger* has asked for the same outcome they
would get by unticking the addon in Blizzard's own AddOns list, minus the `/reload`.

**This addon used to ship the draw gate** (anti-pattern #85), and the correction is recent.
`settings.enabled` was one rung of the show ladder and one rung of `Ledger:GateReason`: the windows
went away, every one of the registrations below stayed registered, and the client went on walking
that list and entering Lua on each bag update to run the comparison that decided to leave. An early
return is not a stand-down — the addon did not stop watching, it stopped **reacting**, and it still
paid the dispatch, which is precisely the cost a player switching it off is trying to stop paying.

### One latch, named holds

`core/LifecycleSetup.lua` builds a single `LibKa0s-Lifecycle-1.0` instance. The addon is stood down
whenever **at least one hold** is taken and stood up only when the **last** one is released, so
releasing one hold can never resurrect an addon another is still holding down. There is deliberately
no `:StandUp()` member to call: the only route out is releasing the hold that put it down.

| Hold | Taken from | Lifetime |
|---|---|---|
| `disabled` | the stored `settings.enabled` path | persisted — surviving a `/reload` is the whole point of the setting |
| `perf` | `LibKa0s-Perf-1.0`'s suspended arm | session-only — **never taken here**: this addon holds the `performance-§12` no-combat-path exemption and runs no harness |

`NS.SetDisabledHold` is the one entry point. The Master-controls checkbox's `onChange`,
`/bl enable`, `/bl disable`, `/bl set settings.enabled`, the load-time read in `addon:OnEnable` and
AceDB's three profile callbacks all land there, so no surface can drive the teardown by another
route and none of them holds a state of its own.

### What stands down, and what survives

`NS.StandDown` in `core/BankLedger.lua` is the **one** teardown body, reached from two arms — the
latch's edge, and AceAddon's own `OnDisable`. Two arms onto one body is not the parallel-lifecycle
anti-pattern; two bodies would be.

| Stood down | How |
|---|---|
| Every timer | `addon:CancelAllTimers()`, plus each debouncing module's `CancelPending` — the handles are file locals AceTimer's cancel-all cannot reach, and a handle left behind is a debounce that never fires again |
| Every event on the addon object | `addon:UnregisterAllEvents()` — the three below plus the capture engine's whole set, which is registered there too. Not a list to keep current |
| The four private bus targets | `UnregisterAllMessages` / `UnregisterAllEvents` on each, and the module's `_enabled` latch released with it |
| The capture gate's cached upvalues | `Ledger:RefreshUpvalues()`, before the target that carries the refresh is dropped |
| Both windows | hidden, and held shut **at the source**: `NS.Util.VisibilityAllows` answers no while the latch is down, and every `Show` in this addon consults it. A hidden frame otherwise comes back on a combat transition or a settings change |

**What survives, because it is setup and not a feature**: the chat command registration, the
dispatcher and `NS.COMMANDS`; the settings category and the panel body, including its own two
live-refresh bus targets; the AceDB handle, the single write seam and the profile callbacks; the
launcher's registration. See [slash-dispatch.md](slash-dispatch.md) for what the command surface
answers while the addon is off — **every reserved verb**, and the bare `/bl` opens the panel.

**The guild-bank frame hooks are the one sanctioned gate.** `HookScript` has no un-hook, so those
two bodies check the latch and return (`modules/Ledger.lua`). The carve-out exists because the API
is one-way and does not generalize to anything with a real unregister.

**No secure work is deferred**, and the absence is a fact about this addon rather than an omission:
it registers no state driver, writes no secure attribute and owns no protected frame, so nothing
here can be refused under combat lockdown. That is also why a disabled Bank Ledger keeps **no**
event registration at all — the `PLAYER_REGEN_ENABLED` a disabled addon is permitted to keep exists
to finish pending secure work, and there is none to finish.

`tests/test_disabled.lua` is the conformance suite (`slash-commands-§7`). Every assertion in it
reads the kit's recording registry — registrations, timers, shown frames, SavedVariables writes,
printed lines — and none reads a handler's return value, because an early return is exactly what a
draw gate does.

## Event Subscriptions

Fourteen registrations **while the addon is enabled**; **none** while it is disabled (see *The
stand-down* above). **Nine** are the capture engine's and all go through
`Ledger:RegisterEventSafely` — modern retail **raises** on an unknown event name, so a bare loop turns
one retired event into a silently deaf addon. The other five sit outside the engine and outside that
guard, because none of their names can go away under it: `PLAYER_ENTERING_WORLD` on the AceEvent addon
object (`core/BankLedger.lua:45`, the one-shot retention prune), the combat pair
`PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` on the same object (`core/BankLedger.lua:49-50`
→ `addon:OnCombatChanged` → `NS.Util.ApplyVisibility`, the two edges the **General visibility** rule
answers on — without them a window opened out of combat would simply stay up through a pull; the
`PLAYER_REGEN_DISABLED` edge also ends test mode first, through `LT:SetTestMode(false)`, which opens
no window, per `options-ui-§15`), and
`PLAYER_LOGOUT` on each window's own event frame (`modules/Browser.lua:1206`,
`modules/SessionWindow.lua:673`, geometry flush).

Change events are debounced into one reconcile pass per user action, and the baseline is held
whenever a pass sees a one-sided change.

The guild bank is the one store with no usable open **or** close event. Full event table, the
debounce/settle contract and the guild-bank arrangement in **[data-flow.md](data-flow.md)**; the
client behavior behind each workaround in **[midnight-quirks.md](midnight-quirks.md)**.

## Taint notes

- The ledger window, the session window and the debug console are plain **non-secure** frames, so they
  touch nothing protected and need no combat gate. All three are registered in `UISpecialFrames` for
  ESC. That the session window opens off a game event is safe for the same reason: it shows a frame
  nobody protected, and it never calls a protected API.
- The settings **category** is registered eagerly at load — that never taints. Each panel **body**
  is built lazily on its first `OnShow`, as is the header's Defaults button.
- Every registered canvas frame carries `OnCommit`, `OnDefault` and `OnRefresh`, so Blizzard's
  Settings window never calls into a missing method — **stamped by `LibKa0s-Options-1.0`'s
  `CreatePanel`** (Options minor 5), not by this addon, which is what options-ui-§1 now requires.
  `OnCommit` and `OnRefresh` are inert by design — writes land immediately through `NS.Schema:Set`
  (nothing is staged), and the library's renderer already owns re-show. `OnDefault` **forwards** to
  whatever the page parked as `defaultsOnClick` (`setDefaultsAction`), so the framework's footer
  control and the addon's own header button are one implementation by construction rather than two
  that have to be kept in step. On General that action is `P:RestoreDefaults()`, which is
  non-destructive — settings and window geometry only; wiping the ledger stays behind the
  confirm-gated `KA0S_BANKLEDGER_RESETALL` popup, which Blizzard's un-gated control never reaches.
- Opening the settings panel **refuses** under combat lockdown with a gray notice and never defers:
  `Settings.OpenToCategory` is protected, and calling it under lockdown taints the panel for the
  rest of the session. A page already on screen in combat is covered and refuses every write,
  Defaults and tab switch until `PLAYER_REGEN_ENABLED` — the library's combat lock (LibKa0s v1.46.1,
  `options-ui-§2`/`§13`), which never touches Blizzard's settings window in combat.
- Every chat and debug line funnels through one secret-safe printer, whose detector probes
  `table.concat` rather than `..` — the operator propagates secretness without raising, so a
  `..`-based probe would let a combat "secret" through to the real concat and crash.

## Known Limitations

- **Currency movements are not recorded, and are not planned.**
- **Guild-bank withdrawals by other players are invisible** — the addon sees only your own client.
- **The reagent bank and void storage are not stores** — Midnight removed both.
- **A store-to-store transfer is not recorded** — neither side is the bags.
- **A movement made while capture is off is lost**, not backfilled.
- **Pre-corroboration gold rows cannot be cleaned up retroactively** — nothing in a stored row
  distinguishes them.
- **An uncached item is skipped when a minimum quality is set**, and there is no name backfill.
- **Rows recorded before the link-enrichment fix keep their base-item quality** — they were written
  from the itemID, so a bonus-upgraded drop was stored at the quality its base item has. Nothing
  re-resolves a stored row, so those rows stay as recorded.
- **Two variants of one itemID in a single snapshot resolve to the same link** — the scan keeps the
  first hyperlink it sees per id and the counts map is keyed by id alone, so it cannot tell an
  upgraded copy from a base one when both are present.

Each of these is a decision with its reasoning; see **[scope.md](scope.md)**.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`). Frozen and
generated directories are named once each and never enumerated per run: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/`, `docs/revendor/`, `docs/superpowers/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `ARCHITECTURE.md` | This file — the hub: at-a-glance facts, module map, schema, bus, slash, events, deviations |
| `scope.md` | What the ledger records, and the movements it deliberately does not |
| `module-map.md` | Every non-vendored file, its responsibility, and the TOC's load order |
| `schema.md` | `BankLedgerDB`'s account-wide shape, the entry fields, carve-outs, migrations |
| `settings-panel.md` | The two pages, the five-tab strip, the sixteen rows, and the single `Schema:Set` write seam |
| `data-flow.md` | Snapshot → diff → corroborate → record, and the event choreography around it |
| `common-tasks.md` | Add a setting, a command, a store, a migration, a chart, an event |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `slash-dispatch.md` | Present | 17 verbs in `NS.COMMANDS` (threshold is 8) |
| `midnight-quirks.md` | Present | Client-version workarounds of the addon's own |
| `compat-layer.md` | Present | `core/Compat.lua` carries 13 addon-specific shims beyond LibKa0s |
| `message-bus.md` | Not applicable | Four messages; threshold is more than ten. The table lives in `ARCHITECTURE.md` → `## Message bus` |
| `profiles.md` | Not applicable | No AceDB profiles are user-visible — the addon is account-wide by design and the profile namespace is unused |
| `debug.md` | Not applicable | The console is `LibKa0s-DebugLog-1.0`'s, with no debug surface of the addon's own beyond `/bl debug scan` and `/bl debug panel` |
| `perf-analysis/README.md` | Not applicable | The `performance-§12` no-combat-path exemption is held — see `## Documented deviations` |

### Verification and record

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The `performance-§12` exemption and the committed sweep behind it |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated, never hand-edited |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `windows.md` | The two standalone windows, the shared skin seam, and the geometry-save contract |
| `insights.md` | The Insights tab: `Database:Stats` keys, section order, and the three drawing rules |
| `media.md` | Where the mono face and the shared marks come from, which surfaces draw which mark and what each falls back to, and the logo art set with its regeneration recipe |

## Documented deviations

Accepted, deliberate departures from the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards).

**This table is the register, and it is the only place a deviation is ratified.** A departure that
is argued for somewhere else — a code comment, a GitHub issue on this repo — but has no row here is
*not* ratified, and an audit is right to file it. Every row names the rule it departs from as a
`filename-§N` reference, the date it was decided, and the **condition that ends it**: a deviation
with no re-check trigger is a permanent exemption granted by accident.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `performance-§12` | No performance harness is wired: no `core/PerfSetup.lua`, no `BankLedgerPerfDB`, no `perf` verb registration, no suspend/resume contract, no `tests/perf.lua`, no `docs/perf-analysis/`. | **The no-combat-path exemption, criterion (a) plus (b).** (a) — the whole-repo sweep of `RegisterEvent` / `SetScript("OnUpdate"` / `C_Timer` is committed at [`docs/performance.md`](./performance.md) with the per-event work named for every hit: no `OnUpdate` handler anywhere, no repeating ticker (every timer is a one-shot), and the three events that *can* fire in combat do a single `NS.State.openContext` nil check and return. (b) — the capture protocol opens its windows on the player's combat state (`performance-§7`), and this addon's entire engine is gated on a bank frame being open, which is an out-of-combat NPC interaction; every declared bucket would read `0.000` by construction. Reasoned at length in closed issue [`LIBKA0S-17`](https://github.com/tusharsaxena/BankLedger/issues/9); ratified here. | 2026-08-05 | **The first `OnUpdate` handler, repeating ticker, or in-combat event handler doing real work re-arms the full `performance` wiring MUST.** Concretely: an event handler that stops checking `NS.State.openContext` first, or a scan moved off the bank-open gate onto a bag event. |
| `savedvariables-§2` | All defaults live in `defaults/Global.lua`; **`defaults/Profile.lua` is not created**, and `layout-§1`'s tree therefore has a file missing. | Bank Ledger is **account-wide by design** — you deposit on one character and withdraw on another, so a per-character profile would split the very history the addon exists to join up. `NS.defaults` carries a `global` table only and every schema path resolves against `NS.db.global`. An empty `Profile.lua` would satisfy the filename while weakening the rule's real invariant — that there is exactly *one* place a default value is hardcoded — by standing up a second candidate home for it. | 2026-07-27 | **The first per-profile setting.** The moment one default belongs to a character rather than to the account, `defaults/Profile.lua` is created and this row is deleted. |
| `localization-§1` | This addon ships **English only**: the `NS.L` seam is exported and `locales/enUS.lua` ships, and **no** user-facing string routes through `NS.L` — every label, tooltip and message is a hardcoded English literal. The one entry that briefly sat there was the disabled-verb refusal, added 2026-09-16 and **removed 2026-09-17**: `slash-commands-§7` makes that line the collection's wording, `LibKa0s-Slash-1.0` builds it from `lib.DISABLED_LINE_FORMAT`, and the standard says in as many words that the `L` override does not reach it. | `localization-§3` names this one of the routing SHOULD's **two terminal compliant states** — English-only, *recorded* — so the row is not a deferral, it is the compliant end state, and an audit reads it as accepted rather than re-filing the SHOULD. Both `localization` MUSTs are met unconditionally: the seam is exported with the key-returning metatable fallback (`locales/enUS.lua:6`) and `enUS.lua` ships carrying no dead keys. The wrapped string that briefly existed never narrowed the row, and its removal does not widen it: the row has always been about the SEAM being exported and ready, which it is. The argument was written at the head of `locales/enUS.lua` and tracked at [issue #3](https://github.com/tusharsaxena/BankLedger/issues/3), and a comment is exactly what `documentation-§3` says does not ratify a thing — which is why four consecutive audits re-filed it, most recently as `BL-04` in `docs/audits/2026-09-07/`. This row is the ratification the comment was standing in for. | 2026-07-31 | **The first non-English locale file added to `locales/`.** That change routes the strings and retires this row. |
| `standalone-windows` | The close control on this addon's **own** windows is the host's own factory — `modules/Browser.lua:98`'s `B:MakeCloseButton`, 24×24, class-colored on hover — rather than a one-line wrapper over `lib.MakeCloseButton`, which `core/CoreSetup.lua:117-129` deliberately does not republish. | **A reasoned decline is a terminal compliant state, and this row is the fourth of the four conditions it costs.** (1) *Host windows only*: the ledger (`modules/Browser.lua:1047`), the session window (`modules/SessionWindow.lua:485`) and the export modal (`modules/Export.lua:362`) are this addon's; the export **copy** window is `LibKa0s-Widgets-1.0`'s `CopyWindow` and wears the library's mark, as do the debug console and its copy box. (2) *The same shared mark*: `B:MakeCloseButton` resolves the catalog's `close` through `NS.Icon` (`modules/Browser.lua:104`) with the documented fallback ladder beneath it, so the two implementations agree on the art and differ only in size and hover tint. (3) *Exactly one host factory*: `grep -rn 'MakeCloseButton(' --include='*.lua' | grep -v '/libs/'` returns that factory, its three callers and no two-argument call to `lib.MakeCloseButton` anywhere — anti-pattern #65 does not apply. (4) This row. Adoption would change four visible controls a player already knows for no player benefit. Filed as `BL-28` in `docs/audits/2026-09-07/`; declined in closed issue [#5](https://github.com/tusharsaxena/BankLedger/issues/5) on 2026-08-06, unratified until now. | 2026-08-06 | **Any one of the four conditions ceasing to hold**: a second host close factory, a call to `lib.MakeCloseButton` from anywhere but a window the library owns, a private glyph replacing the catalog's `close`, or the host drawing its own control onto a library window. Re-check also if `standalone-windows` withdraws the decline. |
| `options-ui-§12` | The global reset is **three routes over two implementations**, not one act. The General page's **Reset all settings** button raises the confirm-gated `KA0S_BANKLEDGER_RESETALL` popup, whose `OnAccept` runs `Sl:ResetEverything` — `db.global` emptied wholesale, **including the recorded ledger**. The header/footer **Defaults** button (`P:RestoreDefaults`) and `/bl resetall` both run `Sl:CliResetAll`, which clears the two filter lists, resets the saved view and defers to the library's schema walk, leaving the ledger alone. §12 requires all three behind **one** implementation, and requires the account-wide form to empty the store wholesale rather than enumerate it — so the *non-destructive* pair is the half that diverges. | **Not argued for — recorded because it is shipping and was not ratified.** The split predates the settings revamp; that pass only moved the destructive button onto the Master controls tab and, in doing so, gave it §12's canonical *name*. Closing it means choosing which act wins, and both choices are user-visible: unifying **up** makes `/bl resetall` and Blizzard's own **Defaults** control destroy a player's entire recorded history (§12 accepts this — its second canonical wording already says *"or recorded"* — but it is a data-loss change no case in `tests/` covers today); unifying **down** leaves the addon with no §12-compliant wholesale reset at all. That is a maintainer's call, not an implementer's, so the divergence is **reported and named** rather than silently widened. What this pass *did* do is stop the two acts sharing a label: the button is *Reset all settings*, `/bl resetall` is *Reset every setting to defaults* (`slash-commands-§3`'s reference wording), so today a player is at least not told two different blast radii have one name. **A second cost surfaced on 2026-09-16**: `launcher-§3` exempts `minimap.hide` from every reset, and because the two acts are two implementations the carve-out had to be made twice — `NS.Schema.RESET_EXEMPT` honored in `S:ApplyDefault` for the schema walk, and the held-and-restored `minimap` table in `Sl:ResetEverything`. Unified, it would be one. | 2026-09-02 | **The decision itself — this row is a placeholder for a resolution, not an exemption.** Re-check at the next release, or the moment a player reports losing history to *Reset all settings*, whichever comes first. Closing it means pointing `P:RestoreDefaults` and the `resetall` verb at the same confirm-gated body as the button (and extending `Sl:ResetEverything` to sweep the session-only rows a store wipe cannot reach, per §12), then deleting this row. |

Detail the table cannot hold, for the `savedvariables-§2` row: AceDB still creates the profile
namespace — the addon calls `AceDB:New("BankLedgerDB", NS.defaults, true)` — it is simply unused, so
the switch to a per-profile setting is a defaults-file addition rather than a database migration.
