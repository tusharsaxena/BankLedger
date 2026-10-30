# Architecture — Ka0s Bank Ledger

Engineer context for the addon, and the **hub** of its doc set: each section below summarizes and
links, it does not store (`documentation-§3`). Player-facing docs live in the root `README.md`; how to
verify it is `docs/testing.md`. The Ka0s WoW Addon Standard itself is the upstream repo linked from
`CLAUDE.md` — it is read there, never copied in here.

## At a glance

| | |
|---|---|
| Folder / TOC `Title` | `BankLedger` / `Ka0s Bank Ledger` |
| Scope | Retail (Mainline) only — a single `## Interface:` line, currently `120105` |
| SavedVariables | `BankLedgerDB`: the recorded ledger, its retention window (owner decision D6) and the Minimap button **account-wide** (`global`), every other setting **per AceDB profile** (`profile`, shared `Default` by default); see [profiles.md](profiles.md) |
| Slash | `/bl`, aliased `/bankledger` |
| Chat tag | `NS.PREFIX` — the cyan bracketed `[BL]` tag (`\|cff00ffff[BL]\|r`) |
| Layout | `core/ defaults/ locales/ modules/ settings/`, 44 source files |
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

44 source files across `core/ defaults/ locales/ modules/ settings/`. `core/` holds the bootstrap,
the Compat firewall, the AceDB layer and the ten LibKa0s seams; `defaults/` holds the account-wide
and the per-profile defaults; `modules/` holds the capture engine and every window; `settings/` holds
the schema, the slash seam and the settings pages (General and Profiles). The root `Bindings.xml`
(not in the TOC; the client reads it by name) declares the Show window key binding (`launcher-§6`),
which the General page's Keybindings tab also edits (`options-ui-§20`).
Five of the files are the in-game simulator (BankLedger#24, see **Simulator** below):
`core/SimSetup.lua` (the LibKa0s-Sim-1.0 seam over `NS.Compat`), `modules/SimWorld.lua` (the
simulated world and the seam's providers), `modules/SimDrivers.lua` (one event driver per client
action), `modules/Sim.lua` (the session host, `NS.Sim`, and its presentation fields) and
`modules/SimScenario.lua` (the four scenarios). Each has its row in module-map.md.

Load order is load-bearing in eleven places (the newest: `core/SkinSetup.lua` registers the skin
owner at file load and sits above every module and `settings/Schema.lua`, which read `NS.Skin` and
the Skin tab's option lists; see **Skins** below), and `tests/test_harness.lua`
guards the order the harness derives from the TOC. File-by-file table, load-order notes and the locale seam in
**[module-map.md](module-map.md)**; the API firewall in **[compat-layer.md](compat-layer.md)**.

## Settings Schema

**Twenty-four** schema rows in `settings/Schema.lua` — the single source for the panel widgets, the
`/bl get|set|list|reset` dispatch and the defaults reset. Every write to a schema-row path goes through
`NS.Schema:Set`, so a slash write and a panel widget take exactly the same path.

The runtime is `LibKa0s-Schema-1.0` (adopted at LibKa0s v1.55.0); without the library,
`settings/Schema.lua` builds the same instance from a runtime-completing, log-silent stub
(`options-ui-§1`). A bulk reset logs one line (`debug-logging-§10`), and every reset control reaches
the one confirm-gated global reset, `Sl:ResetEverything` (`options-ui-§12`). The rows live on the
tabbed **General** page (`options-ui-§13`): **Master controls** · **Capture** · **Filters** ·
**Interface** · **History** · **Skin**, then the library's **Keybindings** host tab. The seven Skin
rows (`settings.appearance.*`, group `Appearance`) are `skipRender`: the library's Skin tab draws
them through `core/SkinSetup.lua`'s read and write seams, which write through `NS.Schema:Set` like
every other row (see **Skins** below). The bulk bracket, the reset routes and the tab strip are in
`settings-panel.md`.

Every schema path resolves against the **active profile**, `NS.db.profile` (schema v3), except two
rows whose own `get`/`set` reach the account-wide store (`S.GLOBAL_ROWS`): the Minimap button row
and the retention window, `db.global.settings.retentionDays` (owner decision D6, schema v4). What is
stored outside the rows is named per `architecture-§5`:
- **One structural registry** — the filter id-sets, `db.profile.blacklist` and
  `db.profile.whitelist`, whose only runtime writer is `NS.Filters` (`modules/Filters.lua`). Two
  acts replace them wholesale without going through it: the load pass `NS.MIGRATIONS[3]`
  (`core/Database.lua`), which lifted them out of `db.global` once, and AceDB's own profile switch,
  copy and reset, after which `NS.OnProfileEvent` re-caches the capture gate and broadcasts
  `LedgerChanged` exactly as `NS.Filters` does.
- **The movement log is recorded data** — `db.global.ledger`, account-wide and in no profile,
  written only by `NS.Database` (`core/Database.lua`): `Add`, `Delete`, `DeleteAt`, `Purge` and
  `PruneOld`. One repair pass fills fields on rows that are already there: the login backfill,
  `NS.Backfill` (`modules/Backfill.lua`), writes an item row's **nil** name, quality, type,
  sub-type and link, never overwrites a present field and never adds or removes a row; it reports
  the change through `Database:FireLedgerChanged`, so Database stays the message's one sender.
- **The write sink and the dataset kinds** (BankLedger#24). Every write the capture path reaches
  goes through `Database:Sink()`: `NS.State.simLog` while a simulator runs, a session-only array
  that is never saved, otherwise `db.global.ledger`; `Database:Add` stamps a sim row `sim = true`.
  The read path, `Database:ActiveLedger()`, resolves sim, then test (`NS.State.testRecords`), then
  live, and `Database:DatasetKind()` names which in that precedence (`"sim"`, `"test"`, `"live"`).
  Every reader that must refuse a synthetic dataset asks `DatasetKind() ~= "live"`: the row menu's
  mutating actions, the default character scope, the tab baseline and the test strip. `Count`,
  `Delete`, `DeleteAt`, `Purge` and `PruneOld` always act on the real ledger, and the session window
  prunes against the sink, never the read path.
- **Named non-setting state** — four storage carve-outs written outside `NS.Schema:Set`, none with a
  `Documented deviations` row:
  - **Main window geometry**, `db.profile.settings.window`, owned by `NS.Browser`.
  - **Session window geometry**, `db.profile.settings.sessionWindow`, owned by `NS.SessionWindow`.
  - **Saved ledger views**, `db.profile.savedViews` (one per ledger-window tab, keyed `History` /
    `Insights`; schema v5 split the single `savedView` into it), owned by `NS.Browser`.
  - **Minimap button position**, `db.global.minimap.minimapPos`, written by LibDBIcon into the
    account-wide table `NS.Launcher` hands it; no profile event reaches it (`launcher-§3`, see
    **Launcher** below).

  The simulator's step panel adds no fifth: its position is session-only (OWNER_SCOPE C.11), held in
  the LibKa0s-Sim-1.0 instance's memory and forgotten on `/reload`, so a simulation writes nothing
  to SavedVariables.

The runtime and its stub, and every writer of each with the act that reaches it, are in
**[schema.md](schema.md#registry-recorded-data-and-named-state-writers)**.

## Profiles

AceDB profiles, since schema v3. A profile holds **everything a player configures** but the
retention window: every other schema row, both filter lists, the saved views (one per
ledger-window tab) and both windows' geometry. The **recorded ledger**, the **retention window** that governs it and LibDBIcon's table
stay **account-wide** in `db.global`, so switching profile never changes what was recorded or how
much of it is kept (owner decisions D5 and D6, 2026-09-29). Every character starts on the one shared
`Default` profile, which is where `NS.MIGRATIONS[3]` lifted the old account-wide settings;
`NS.MIGRATIONS[4]` takes the retention window back out of any profile an earlier build had put it in.

The **Profiles** page (`settings/Profiles.lua`, `options-ui-§3`) is AceDBOptions in a canvas
subcategory, registered after General, with no Defaults button. AceDB's three profile callbacks all
reach **`NS.OnProfileEvent`** (`core/Database.lua`), the one adopt path: the migration runner, the
enable latch, one `SettingsChanged("profile")` and one `LedgerChanged`, every setting's effect
re-applied (window geometry and chrome, each tab's saved view, visibility, the row tint), the panel
refreshed, and exactly one debug line for the act (`debug-logging-§10`). It never runs the retention
prune: no profile event deletes history (D6). The global reset is `db:ResetProfile()`
(`options-ui-§12`, the "addon with both" form), so it is the same act as the Profiles page's Reset
Profile and it never deletes history or moves the retention window; `/bl purge` deletes history,
separately confirmed. The Options descriptor's `skipRestoreAll` is the one named veto,
`S.VetoedFromResetAll` (`options-ui-§3`): the Profiles page and every stored row. Detail in
**[profiles.md](profiles.md)**.

## Simulator

`/bl sim` (BankLedger#24, LibKa0s#54) plays a scripted bank visit through the **real** capture
engine against an invented world, on `LibKa0s-Sim-1.0`. Nothing in it writes a row: every row is
the engine's own decision.

- **The seam.** `core/SimSetup.lua` wraps `NS.Compat` in place at load (`Sim:NewSeam`), straight
  after `core/Compat.lua`. While a session runs, the simulated world (`modules/SimWorld.lua`)
  answers the wrapped members; otherwise the live member does, at one boolean test per call. The
  drivers (`modules/SimDrivers.lua`) edit that world and fire the client's events through
  `NS.Sim:Fire` into `Ledger:Dispatch`, the one call every capture signal takes. Membership and
  the identity reads are in [compat-layer.md](compat-layer.md).
- **The sink and the dataset kinds.** The start sets `NS.State.simLog`, so `Database:Sink()` sends
  every recorded row there (stamped `sim = true`), and `Database:ActiveLedger()` reads it first.
  `Database:DatasetKind()` answers `"sim"`, which the ledger window's simulation strip, the session
  window's simulation strip and every reader that refuses a synthetic dataset ask (see **Settings Schema** above).
- **The stop is two-phase, with no final pass.** While the seam still answers, `OnStopGuarded`
  runs `Ledger:DropContext()`: the pending debounce, the settle window and the banking session go
  with **no** `Reconcile`, because a pass with the seam off would diff the simulated baseline
  against the real world and invent movements. With the seam off, `OnStop` releases the session
  log and the world, and the ledger window swaps back to the saved dataset.
- **What ends it.** `/bl sim stop`; a **real** bank or guild-bank frame opening or closing
  (`Ledger:Dispatch` stops the session before the real handler runs, so the real visit snapshots
  the real world); entering combat (`addon:OnCombatChanged`); the stand-down, whose first step it
  is; and `/reload`, because nothing was saved. A profile reset does **not** end it: it touches no
  state the session reads (OWNER_SCOPE C.13).
- **What refuses a start.** The addon stood down, test mode on, combat, a real bank or guild bank
  open, and General visibility keeping the ledger window shut, checked in that order, each with
  one line (`modules/Sim.lua`). Test mode refuses to start while a simulation runs.
- **Purge is refused during a simulation.** `Database:PurgeRefused()` prints `Stop the simulation
  first.` before any confirm opens, from `/bl purge` and the settings' *Purge history…* button alike, and
  `Database:Purge` re-checks it. `Delete`, `DeleteAt` and `PruneOld` act on the real ledger only.

The simulator is slash-only, with no launcher entry, no key binding and no schema row; its step
delay is a constant. The pipeline is in [data-flow.md](data-flow.md#a-simulated-visit), the strips
(one per mode, with the `TEST MODE` title badge only as the library-absent fallback) and the step
panel in [windows.md](windows.md), the verb in [slash-dispatch.md](slash-dispatch.md)
and the `[Sim]` lines in [debug.md](debug.md).

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
| Broker label | `Ka0s Bank Ledger` — the **brand name in plain text** (`launcher-§1`), which is what a broker display prints in its row beside the collection's other ten. Deliberately **not** the TOC's `## Title` (a Title may carry color escapes) and **not** the folder name (that is the registration name above). It read `Bank Ledger` until the v2.54.0 amendment. |
| Icon | `Interface\AddOns\BankLedger\media\logos\bankledger.logo.128.tga`, the same file `## IconTexture` names (`launcher-§4`, `layout-§4`): 128×128, uncompressed 32-bit |
| Left-click | Opens the settings panel (`openSettings`, `NS.Panel:Open`), always and in either state (`launcher-§2` as of standard v2.67.0; Launcher minor 4, LibKa0s v1.58.0). Until v1.58.0 this addon was **rung (a)** and its left click toggled the ledger; the rungs are retired and that toggle is the menu's *Show window*. |
| Right-click | Opens the **options menu**, the client's own context menu (`MenuUtil.CreateContextMenu`), built by the library and titled `Ka0s Bank Ledger`: **Enabled** (`isEnabled` / `setEnabled` → `/bl enable` or `/bl disable`, `Sl:CliEnabled`), **Locked** (`isLocked` / `toggleLock` → `/bl set settings.locked <bool>`, `Sl:CliSet`, since this addon has no `lock` verb), **Test mode** (`isTestMode` / `toggleTestMode` → `/bl test`, `LT:ToggleTestMode`) and **Show window** (`isWindowShown` / `toggleWindow` → `/bl toggle`, `B:Toggle`). Each toggle is looked up in `NS.COMMANDS` at click time and runs that verb's own handler, messages and refusals included. While disabled the library grays Locked, Test mode and Show window with `(enable the addon first)`; Enabled stays live. The entries match the row the standard's `ADDONS.md` records for this addon. On a client without `MenuUtil` the right click opens the settings panel. |
| Tooltip | **Drawn by the library** (Launcher minor 3, LibKa0s v1.57.0; `launcher-§1` as of standard v2.66.0), on every hover and **while disabled**: `Ka0s Bank Ledger  v<version>` (the TOC's, through `NS.Version`), `Enabled: Yes\|No` (from `isEnabled`), `Locked: Yes\|No` (from `isLocked`, the stored `settings.locked` the *Lock frame* row writes), `Test mode: On\|Off` (from `isTestMode`, `LT:IsTestMode`, the *Test mode* row's own `get`), then this addon's one extra line — the live movement count, the only thing its `onTooltipShow` draws — then `Left-click: Open settings` and `Right-click: Options menu`, fixed in both states since Launcher minor 4 (v1.57.0's `Left-click: Toggle ledger window` and its disabled hint are gone with the rungs). Every value is read on each show, never cached. Until v1.57.0 the host hook drew the whole tooltip, title and click hints included. |
| Visibility | The **Minimap button** row on General ▸ Master controls: CLI path `minimap.shown` (`/bl get minimap.shown`), stored at LibDBIcon's `db.global.minimap.hide` |
| Resets | **Neither reset reaches the row** (`launcher-§3`). Both did before the v2.54.0 amendment. |

**The row's sense is the inverse of the key's**, and that inversion lives in exactly one place:
`NS.Schema:Set` and `NS.Schema:Get`, the single write seam (`options-ui-§1`). The row says *shown*;
LibDBIcon's `hide` says hidden, and `hide` is the library's own field — it writes it itself from the
button's right-click menu, which is why there is one boolean and not a second one beside it
(`launcher-§3`). The button follows the row from the row's `onChange`, so a slash write, a panel
click and a reset all move it.

**The CLI path reads in the row's own sense** since standard v2.65.0 (`launcher-§3`):
`/bl set minimap.shown false` hides the button. The path is the name a player types and nothing
more — the stored key is still `db.global.minimap.hide`, so the rename moved no SavedVariables and
needed no migration, and nothing is ever stored at `minimap.shown` (a stored `shown` key would be the
second boolean anti-pattern #81 forbids). The old CLI path `minimap.hide` answers `Setting not found`.
`S:Register` resolves this one row against the declared `hide` default rather than a `shown` key.

### Show window key binding

`launcher-§6`: the root `Bindings.xml` declares one `CLICK BankLedgerToggleWindow:LeftButton`
binding in the addon's own category, `BINDING_HEADER_BANKLEDGER`, with **no `header=`** (the category
is the section title on Options → Keybindings, and a header inside it would draw a blank row), **no
default key** (the player picks one under Options → Keybindings → Ka0s Bank Ledger, or on General >
Keybindings) and no Lua; the TOC does not list it.
`core/LauncherSetup.lua` creates the button at load, above the degradation stub's early return so a
degraded install has it too: a plain, named, hidden, **non-secure** `Button` registered `AnyDown`, so
one press is one toggle and a press in combat taints nothing (the ledger window is non-secure). Its
`OnClick` runs `verb("toggle")`, the very call the descriptor's `toggleWindow` makes, so the key, the
menu's *Show window* and `/bl toggle` are one handler (`B:Toggle`). `verb` skips the dispatcher's
disabled gate and a key cannot be grayed, so while `NS.IsStoodDown()` the press prints
`NS.Slash:DisabledLine()`, the line `/bl toggle` answers with, and does nothing else. This addon takes
no `perf` hold (`performance-§12`), so that is the only refusal by hold a press can owe. The labels
are set beside the button: `BINDING_HEADER_BANKLEDGER = NS.BRAND_NAME` (the section title) and the
action label `Toggle ledger window` through `NS.L`, by `rawset`. So is **`NS.BINDINGS`**, the one
bindings table (`{ command, tooltip }` per `Bindings.xml` line, in file order, Show window first),
which `settings/Panel.lua` hands to `O.KeybindingsTab` for the General page's last tab
(`options-ui-§20`) and `tests/test_keybinds.lua` checks `Bindings.xml` against through
`Kit.assertBindingsXml`. **The button name is permanent**: the client stores a player's key against
the binding's name, which embeds it, so a rename unbinds every player's key; item 015 moved the
category and dropped the header and kept the name, so no key was lost.

### The button survives a reset, and that is a property of the setting

Whether the button is shown is a **per-installation display preference**, in the same class as the
angle the player dragged it to — which LibDBIcon keeps in the very same table, as
`minimap.minimapPos`, and which no reset in the collection touches. `launcher-§3` therefore requires
the row (`minimap.shown`, stored as `minimap.hide`) to survive **both** *Reset all settings* and a page-scoped **Defaults** button, and
neither may re-hide a shown one either.

Until standard v2.54.0 that section *derived* the conclusion — *Reset all settings* is a profile
reset, the table is global, so the reset cannot reach it. **Until schema v3 neither half of that
argument held here, and both of this addon's reset implementations reached the row.** Since
BankLedger-A-02 there is one global reset (`options-ui-§12`), and since schema v3 it is a profile
reset; the walk below survives as the library's, which no host route runs:

| Reset | Route | Why it reached the row | The carve-out |
|---|---|---|---|
| *Reset all settings*, **Defaults** and `/bl resetall` (all confirm-gated), and the Profiles page's Reset Profile | `Sl:ResetEverything` → `db:ResetProfile()` | **Until schema v3 this addon had no profile**, so the reset emptied `db.global` wholesale and merged the declared defaults back, and `minimap = { hide = false }` was one of them: a hidden button came back, at the default angle. | None needed since schema v3: the reset is a profile reset, and the `minimap` table is in `db.global`, which no profile event reaches. Until then the table was held and restored around the wipe. |
| The library's row walk (**Defaults** and `/bl resetall` until BankLedger-A-02; `O.RestoreDefaults` if ever called) | `applyDefault` over every schema row | The Minimap button row **is** a schema row — the Master controls composer emits it — and the walk rewrites every row carrying a `default`. This reaches the row even where the profile reasoning does hold, which is why the amended rule names it. | `NS.Schema.RESET_EXEMPT`, honored in `S:ApplyDefault`, the one seam the Slash and Options descriptors' `applyDefault` write through, so any library walk inherits the veto. |

The veto is **bracket-scoped**: it fires only while a bulk bracket is open, which a sweep opens and a
single-row reset does not. So a targeted `/bl reset minimap.shown` is still the player naming that
exact row and still works. The cases that pin all of it are in `tests/test_panel.lua` and
`tests/test_reset_routes.lua`, beside the other destructive-reset cases, and they read the stored byte back after running the real act.

`modules/Browser.lua` owned all of this until adoption (`B:SetupMinimap`, `B:SetMinimapHidden`);
both are gone, and `tests/test_launcher.lua` fails if either comes back.

## Message bus

Four messages. Three have one sending module each; `SettingsChanged` has several, listed in the
table below. Consumers **must** register on their own `NS.NewBusTarget()` target, never on the
shared bus-as-self: CallbackHandler keys callbacks by `(message, target)`, so
two consumers sharing a target silently clobber each other.

**Declared once, in `core/Constants.lua`, as `NS.MSG`** (`architecture-§4`). Every `SendMessage` and
`RegisterMessage` names the constant; the wire name is typed nowhere else in the addon
(`tests/test_bus.lua` gates it). The table goes through **`LibKa0s-Bus-1.0`'s `Catalog`**
(`docs/api/Bus/version-1-docs.md` in LibKa0s), which checks the `Ka0s_BankLedger_<PascalCase>` shape
at load and answers a strict copy: reading an undeclared key raises at the call site, for a publisher
as well as a subscriber. Only `Catalog` is adopted. The receivers keep this addon's own **untracked**
factory, `NS.NewBusTarget` in `core/BankLedger.lua`, and are torn down by the modules' own disable
paths (`## The stand-down`); nothing calls `Bus:New`. Without the library, the **untracked-target**
stub (`options-ui-§1`), verbatim from the Bus API document's *Worked example*, stands in: its
`Catalog` hands back the declared table itself, so the names, sends and receives are unchanged and
only the strictness is lost, and its `New`, `NewTarget`, `StandDown` and `StandUp` answer as that
shape names them. `tests/test_surface_parity.lua` holds it to the live major with no ignore list.

| Message (`NS.MSG` key) | Sender | Payload | Consumers |
|---|---|---|---|
| `Ka0s_BankLedger_EntryAdded` (`ENTRY_ADDED`) | `Database:Add` | `entry, index` | Browser, Insights, SessionWindow, Panel (storage stats) |
| `Ka0s_BankLedger_LedgerChanged` (`LEDGER_CHANGED`) | `Database` (delete / purge / prune / `FireLedgerChanged`) | — | Browser, Insights, SessionWindow (prunes deleted rows), Panel (storage stats + the Filters tab's id lists) |
| `Ka0s_BankLedger_SettingsChanged` (`SETTINGS_CHANGED`) | `Schema` row `onChange` handlers (the two row-tint rows send theirs through `Util.RefreshRowTint`), and `NS.OnProfileEvent` once per profile switch, copy or reset (the global reset among them) | a short reason string (`enabled`, `sessionWindow`, `windowScale`, `quality`, `trackItems`, `trackMoney`, `stores`, `rowTint`, `profile`) | Ledger (re-caches its gate upvalues), Browser, SessionWindow |
| `Ka0s_BankLedger_SessionChanged` (`SESSION_CHANGED`) | `Ledger` (`OpenContext` / `CloseContext` / the guild-bank self-disarm / the stand-down's `DropContext`) | `active` (boolean), `context` | SessionWindow |

`SessionChanged` exists so the session window rides the span the capture engine already arms
`openContext` for, instead of re-deriving it from the open/close events — which would have missed the
guild bank entirely, since that is armed by its frame's own `OnShow` rather than by an event, and
gets no close event either.

`NS.Filters` deliberately does **not** introduce a fourth sender: it calls
`Database:FireLedgerChanged()` so `Database` stays the sole emitter of that message.

## Slash Commands

`/bl`, aliased `/bankledger`, generated from `NS.COMMANDS` so `/bl help` and the settings landing
page read one table. Twenty verbs; `settings/Slash.lua` is the LibKa0s-Slash-1.0
seam. `/bl sim` is the simulator's one feature verb, handing its words to `NS.Sim:RunVerb`
(LibKa0s-Sim-1.0's grammar); the simulator is slash-only, with no launcher entry or key binding. A bare `/bl` runs `config`, which opens the settings panel on its landing page, and `/bl help`
prints the list (`slash-commands-§4`). `/bl profile` lists the profiles, and `/bl profile <name>`
switches to an existing one through the library's `CliProfile` (Slash minor 17); it stays live while
the addon is disabled, because the descriptor's `liveVerbs` is `lib.LIVE_VERBS` plus `profile`.
Verb table and the host/library split in **[slash-dispatch.md](slash-dispatch.md)**.

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

**Reset all settings re-runs the latch too, and so re-enables a disabled addon.** The global reset
(`Sl:ResetEverything`, behind every reset control) is `db:ResetProfile()`, which restores
`settings.enabled = true` behind the row's `onChange`. AceDB's `OnProfileReset` reaches
`NS.OnProfileEvent`, which runs `NS.ReevaluateEnabled` like every profile event does. That releases
the `disabled` hold only on a real edge: an enabled addon is untouched, a disabled one stands back up,
as a freshly created profile would be (`options-ui-§12`). A profile **switch** to a profile whose
`settings.enabled` is false stands the addon down the same way.

### What stands down, and what survives

`NS.StandDown` in `core/BankLedger.lua` is the **one** teardown body, reached from two arms — the
latch's edge, and AceAddon's own `OnDisable`. Two arms onto one body is not the parallel-lifecycle
anti-pattern; two bodies would be.

| Stood down | How |
|---|---|
| A running simulation, **first** | `NS.Sim:Stop("standDown")` is the body's first line (Sim-1.0 host contract H6): its guarded stop step drops the simulated capture context while the seam still answers, then the session log and the simulated world are released and the ledger window swaps back to the saved dataset (`modules/Sim.lua`, BankLedger#24). A no-op when none runs |
| Every timer | `addon:CancelAllTimers()`, plus each debouncing module's `CancelPending` — the handles are file locals AceTimer's cancel-all cannot reach, and a handle left behind is a debounce that never fires again. The retention prune is the addon object's own AceTimer, so the cancel-all takes it, and `NS.StandDown` drops `NS.State.cleanupPending` so the next `PLAYER_ENTERING_WORLD` re-arms it |
| Every event on the addon object | `addon:UnregisterAllEvents()` — the three below plus the capture engine's whole set, which is registered there too. Not a list to keep current |
| The four private bus targets | `UnregisterAllMessages` / `UnregisterAllEvents` on each, and the module's `_enabled` latch released with it |
| The capture gate's cached upvalues | `Ledger:RefreshUpvalues()`, before the target that carries the refresh is dropped |
| The capture context — the open context, its baseline snapshot, the settle window and the banking session | `Ledger:DropContext()`, before the bus targets are dropped so the session window still hears `SessionChanged(false)` and ends the session. Every other path that clears these fields (`CloseContext`, the guild-bank disarm) runs off an event the stand-down has just unregistered, so without it the stand-up would diff against a pre-disable baseline. No flush: nothing moved at the moment of disabling is captured |
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

Twelve registrations **while the addon is enabled**, plus two transient ones: one for the few
seconds the login backfill waits, one while the first-run skin picker waits out combat (below); **none** while it is disabled (see *The stand-down* above). **All of
them** go through one helper, `NS.RegisterEventSafely(target, event,
handler)` in `core/CoreSetup.lua`, over `LibKa0s-Core-1.0`'s `SafeRegisterEvent`
(`events-frames-taint-§1`, standard v2.65.0). Modern retail **raises** on an unknown event name, so a
bare registration turns one retired name into an aborted block: a silently deaf capture loop, or a
stand-up that never reaches the module Enables after it. The helper asks
`C_EventUtils.IsEventValid` first, so a name the client refuses never reaches `RegisterEvent` at all,
and `pcall`s what gets past that gate; without the library its degraded arm keeps the `pcall` alone.
Every outcome lands in one record, `NS.EventRecord` (`registered` / `unavailable`), which
`/bl debug scan` prints as `events registered` / `events UNAVAILABLE` and `NS.StandDown` empties
(see **[debug.md](debug.md)**).

**Seven** are the capture engine's (`modules/Ledger.lua`, `L:Enable`). The other five sit outside the
engine: `PLAYER_ENTERING_WORLD` on the AceEvent addon object (`NS.StandUp` in `core/BankLedger.lua`,
the one-shot retention prune), the combat pair `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` on the
same object (also `NS.StandUp`)
→ `addon:OnCombatChanged` → `NS.Util.ApplyVisibility`, the two edges the **General visibility** rule
answers on — without them a window opened out of combat would simply stay up through a pull; the
`PLAYER_REGEN_DISABLED` edge also ends test mode first, through `LT:SetTestMode(false)`, which opens
no window, per `options-ui-§15`), and
`PLAYER_LOGOUT` on each window's private bus target, the one `NS.NewBusTarget()` hands out
(`B.__ev` in `B:Enable`, `modules/Browser.lua`; `SW.__ev` in `SW:Enable`,
`modules/SessionWindow.lua`; geometry flush).

**One registration is transient.** The login backfill (`modules/Backfill.lua`, BankLedger#2) runs once
per session, right after the retention prune, and registers `GET_ITEM_INFO_RECEIVED` on the addon
object only while it waits for the client to answer about the item ids it asked to load: it lets go
when every id has answered or after `C.BACKFILL_TIMEOUT` (10s), and drops the name from
`NS.EventRecord` again. Being on the addon object, the stand-down's `UnregisterAllEvents` reaches
it, and the module's `CancelPending` drops the pass.

**So is the skin picker's.** A first-run skin picker due in combat (`NS.MaybeShowSkinPicker`,
`core/SkinSetup.lua`) registers `PLAYER_REGEN_ENABLED` on a private bus target of its own
(`NS.NewBusTarget()`, through `NS.RegisterEventSafely`) and drops it on the first edge, before it
shows the picker. `NS.HideSkinPicker` drops it too, and the stand-down calls that, so a disabled
addon still keeps no registration. The login delay before it is an AceTimer handle on the addon
object, which `NS.StandDown`'s `CancelAllTimers` cancels.

**One dispatch table.** The seven capture registrations share one handler shape: `L:Enable`
registers each name in `L.CLIENT_EVENTS` as `function(e, ...) L:Dispatch(e, ...) end`, and
`L:Dispatch(event, ...)` runs that event's one entry in `L.HANDLERS` (BankLedger#24). It answers `0`
while the module is not enabled or for an event with no handler, and `1` after running the handler.
`L.HANDLERS` also holds two **host-internal pseudo-events**, `GUILDBANK_FRAME_SHOWN` and
`GUILDBANK_FRAME_HIDDEN` (`L.PSEUDO_EVENTS`), which carry the guild bank's open and close. The client
never fires them and they are never registered with it, so they never reach `NS.EventRecord` or
`/bl debug scan`. Only `GuildBankFrame`'s `OnShow`/`OnHide` hooks dispatch them, after the hook's own
stand-down check (the one sanctioned gate, because a hook cannot be removed), and the simulator will
too. A simulator therefore delivers every capture signal through the same one call the client does.
`L:Dispatch` carries a marked seam where the simulator's real-frame auto-stop will go.

Change events are debounced into one reconcile pass per user action, and the baseline is held
whenever a pass sees a one-sided change.

The guild bank is the one store with no usable open **or** close event, so it registers none:
`GUILDBANKFRAME_OPENED` / `_CLOSED` never fire on 12.0.7 and were dropped, and `GuildBankFrame`'s
`OnShow`/`OnHide` hooks are its open and close. Full event table, the
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
  that have to be kept in step. On General that action is `P:RestoreDefaults()`, which only raises
  the confirm-gated `KA0S_BANKLEDGER_RESETALL` popup (`options-ui-§12`): Blizzard's un-gated footer
  control can therefore change nothing without the player's Yes.
- Opening the settings panel **refuses** under combat lockdown with a gray notice and never defers:
  `Settings.OpenToCategory` is protected, and calling it under lockdown taints the panel for the
  rest of the session. A page already on screen in combat is covered and refuses every write,
  Defaults and tab switch until `PLAYER_REGEN_ENABLED` — the library's combat lock (LibKa0s v1.46.1,
  `options-ui-§2`/`§13`), which never touches Blizzard's settings window in combat.
- Every chat and debug line funnels through one secret-safe printer, whose detector probes
  `table.concat` rather than `..` — the operator propagates secretness without raising, so a
  `..`-based probe would let a combat "secret" through to the real concat and crash.

## Frame layering

The addon follows `frame-layering` (standard v2.88.0). Its strata tiers and level offsets are
declared once, in `NS.Constants.LAYERS` (`core/Constants.lua`), whose header comment states the
whole stack; every `SetFrameStrata` and `SetFrameLevel` reads that table, and
`tests/test_layers.lua` pins each frame class through the kit's layer recorder. The tiers, in
short:

- **WINDOW (HIGH, toplevel):** the ledger window and the session window. A click raises either over
  the other and over Blizzard's Settings panel, their strata peer.
- **MODAL (DIALOG, toplevel):** the export dialog, beside the library's debug console and sim panel
  (toplevel from LibKa0s v1.77.0) and Blizzard's StaticPopups.
- **FULLSCREEN:** the library's CSV copy window, one strata above the export dialog that opens it.
- **POPUP (FULLSCREEN_DIALOG):** the ledger row context menu, and the library's dropdown menu,
  autocomplete and IdList suggestions. The row menu has no click catcher: a `GLOBAL_MOUSE_DOWN`
  listener, held only while it shows, closes it on a press outside it, and it closes with the
  ledger window.
- **Levels** are relative to the window; the resize grip sits at window + `LEVEL.GRIP` (10) on both
  the library and the degraded path.

## Skins

Bank Ledger wears the collection's skins (skinning-§3; Ka0sAddonsCommonTasks
`docs/2026-10-29-SKINNING_ROLLOUT/`, items BL-01 to BL-04). Every visual element paints through the
`LibKa0s-Skin-1.0` facade with this addon as its **owner**, on Ka0s Loot History's pattern, member
for member.

- **The seam.** `core/SkinSetup.lua` registers the owner `"BankLedger"` (the folder name) at file
  load with its read and write seams (`NS.SkinChoice`, `NS.WriteSkinChoice`, both through
  `NS.Schema`), publishes `NS.Skin` (the owner's facade) and the call-site helpers `NS.SkinColor`,
  `NS.SkinRGB`, `NS.SkinEscape`, `NS.SkinPanelEscape` (the same escape for settings-page markup,
  gated on `Skin:GetIgnore`), `NS.SkinBar` (a bar of data in the skin's bar texture),
  `NS.QualityColor`, `NS.SkinPaintAce` / `NS.SkinPaintAceTree` / `NS.SkinOnRelease`. Its degraded arm
  answers every facade name from `NS.SKIN_FALLBACK`, a host copy of the Ka0s Default tokens this
  addon reads, which `tests/test_surface_parity.lua` holds to the library's values. It also
  registers two **owner tokens** (`NS.SKIN_TOKENS`, skinning-§1), colors this addon drew under Ka0s
  Default that no library token holds exactly, each following the nearest library role token in
  every other skin: `bl.gold` (a gold movement's pale gold, follows `sem.gold`) and
  `bl.qualityUnknown` (the Insights fallback for a quality the client has no color for, follows
  `sem.unknown`). The close control has none: BL-A1 retired `bl.closeRest` (and the stock look it
  served, which LibKa0s v1.81.0 retired from the library too). The choice is seven profile
  keys under `settings.appearance` ([schema.md](schema.md)): `.source` and `.skin`; the Scope's
  `.ignorePanel` (**Ignore settings panel**, on in a new profile) and `.ignoreFonts`
  (**Ignore fonts**), applied through `NS.ApplySkinIgnore` (`Skin:SetIgnore`, live both ways); the
  Font and texture overrides `.font` and `.texture` (an LSM key each, `""` for the skin's own),
  applied through `NS.ApplySkinOverride` (`Skin:SetOverride`, live); and `.pickerSeen`, the first-run
  picker's memory. The library's Skin tab (key `Appearance`) on the General page, after History and
  before Keybindings, draws the first six ([settings-panel.md](settings-panel.md)).
- **The first-run skin picker.** `NS.MaybeShowSkinPicker` shows the library's picker
  (`O.SkinPicker`, LibKa0s OptionsSkinPicker 1) while the profile's `pickerSeen` is false (on every
  profile, old and new: the rollout's ruling O3): two seconds after login on an AceTimer handle the
  stand-down cancels, and after every profile event. Never while the addon stands down; in combat it
  waits on a one-shot `PLAYER_REGEN_ENABLED` registration (see **Event Subscriptions**). A pick only
  previews; **Apply** and the gear save it through `NS.WriteSkinChoice`, and the close control and
  Escape put the stored skin back. Its eye opens the ledger window in test mode
  (`LT:SetTestMode(true)`), so in combat it prints test mode's own refusal. `NS.HideSkinPicker` (the
  stand-down, and first on every profile event) takes it down without setting `pickerSeen`.
- **Repaint flow.** `NS.ApplySkinChoice` runs right after `NS:InitDB` (`addon:OnInitialize`) and on
  every profile event (`NS.OnProfileEvent`, `core/Database.lua`), applying the stored Scope and
  overrides with the stored skin, and from each Skin tab row with only its own half. It calls
  `Skin:SetChoice`, which resolves the skin, repaints every frame recorded for this owner and then
  fires `NS.Skin.OnLooksChanged`. What no primitive records subscribes there: the History table's
  cached cell, header and direction colors, its four tinted marks and the row tints' RGB, then a
  rebind of both pooled tables (`LT:Reskin`, which calls `SW:Reskin`); the ledger window's tab labels
  (`ReskinTabs`) and the filter bar's colored Direction and Quality option lists; Insights' palette and
  colors (`I:Reskin`). Nothing keys off `SETTINGS_CHANGED`. No reload, no OnUpdate, no events;
  `settings.alpha` stays whole-window opacity.
- **What paints what.** The three host windows (ledger, session, export modal) wear the skin's `Shell`
  with `noTopBar` and a `TitleBar` on their own bar, a `Divider`, `Button` on the flat buttons,
  `ScrollBar` on every scroll bar, `SortHeaderBar` on both tables' headers, `MenuFrame` (alt edge) on the
  row menu, and `Card` / `Panel` / `Divider` (`section.rule`) / `NS.SkinBar` in Insights. The row
  tints take `list.stripe` / `list.hover` RGB with the player's two slider alphas, so the sliders
  stay. Every tooltip line the addon writes takes a `gtip.*` token. The close control is the host's
  own button (`B:MakeCloseButton`, 24×24) handed to `S.CloseButton` the way every other Ka0s close
  control is, with no opts and no host hover scripts (BL-A1, the owner's ruling): in every
  skin, Ka0s Default included, it takes `close.rest` at rest and `close.hot` under the pointer (Ka0s
  Default's gray and red), and a skin switch repaints it.
- **The EllesmereUI provider.** The library's (`SkinEUI.lua`). With source `eui` and its gate holding
  (EllesmereUI's `RegisterSkin` and `EllesmereUIBlizzardSkin` loaded, third-party skins on, this
  addon not switched off in its list), EllesmereUI's facade paints the vocabulary it has; otherwise
  the addon wears its Ka0s skin and the Skin tab names the failing condition. Ka0s to EllesmereUI
  applies live; EllesmereUI back to Ka0s asks for a reload (the tab raises the library's popup; a
  profile event leaving an EllesmereUI that painted this session prints one `NS.L` line instead).
  The TOC's `OptionalDeps` names `EllesmereUI`, so it loads first when present. The read of
  `EllesmereUIDB` is the library's documented deviation, not this addon's.
- **Owners on every library surface.** Each LibKa0s factory is handed the owner in the form it reads:
  `opts.owner` for the filter-bar and export dropdowns (and the shared menu they open), the search
  box, its autocomplete list and both mode strips (`modules/Browser.lua`, `modules/SessionWindow.lua`);
  the descriptor's `addonName` for the debug console and its copy window (`core/DebugLogSetup.lua`)
  and the export copy window (`modules/Export.lua`); the Sim descriptor's `name` for the sim panel
  (`modules/Sim.lua`); the Options instance's `addonName` for the settings chrome. The console and
  the export copy window pass **no `applySkin`**, because a host hook owns the whole job and the
  library never paints over it. The settings page's own AceGUI acquisitions go through
  `NS.SkinPaintAce`, and the Profiles page's tree through `NS.SkinPaintAceTree`. The addon has no
  perf panel (`performance-§12`) and no HUD, so the rollout's one-time HUD style reset (O2) has
  nothing to reset here. `tests/test_skin_tools.lua` pins the tool surfaces.
- **The color gate.** `tests/test_skin_literals.lua` fails on a numeric literal in a color position
  (r, g or b) of `SetTextColor`, `SetColorTexture`, `SetVertexColor`, `SetBackdropColor`,
  `SetBackdropBorderColor`, `AddLine` and `AddDoubleLine`, and on any `|cff` escape in code, in every
  tracked file under `core/`, `modules/` and `settings/`, outside `core/SkinSetup.lua` and the
  allow-list below (anti-pattern #107). An allow-list entry that matches nothing also fails.

### Intentional exceptions

The gate's allow-list, each with its reason:

| File | What | Why it is not chrome |
|---|---|---|
| `core/Constants.lua` | `qualityHex(q)` in the Minimum quality option labels | An item quality's client color, passed through |
| `core/Namespace.lua` | `NS.PREFIX`, the cyan `[BL]` | Chat output; the chat frame is not a skinned surface |
| `settings/Slash.lua` | `\|cFFFFFF00` in the disabled-line fallback | Chat output; the fallback is the library's string, pinned byte for byte |

Outside the gate's reach, also on purpose:

- **Game-meaning colors** (the rollout's gap policy, rung 4): item quality (`q.*`, the client's values
  under Ka0s Default, byte for byte since LibKa0s v1.81.0), class colors on the Character column
  and the Insights per-character labels, and the coin and class art in text.
- **The store identity palette** `C.StoreRGB` (bank gold, warband cyan, guild magenta, bags gray):
  which store a row is, the same under every skin, the way DPS Race keeps its per-player colors. No
  token holds three of the four values (DECISIONS BankLedger D3, for the owner to overrule).
- **Alpha literals** over token components (`NS.SkinBar(fill, r, g, b, 0.95)` in the Insights bars):
  the surface's opacity, the same under every skin. The legend chips stay flat colors, not bars.
- **Fonts.** The skin's face reaches every text the addon shows: the primitives draw their own and
  the addon's `GameFont*` FontStrings take it through `S.Font`, face only, at sizes relative to Ka0s
  Default's. Ka0s Default's face is Oxanium, so the addon's strings no longer read in Friz Quadrata;
  with **Ignore fonts** on every string keeps its own face and size, the library's controls and tool
  windows included (their menus, strips, suggestion rows and labels; LibKa0s v1.81.0). The direction
  glyph keeps the mono face (`C.FONT_MONO`, for its ▲/▼, `debug-logging-§2`) under every skin; the
  close button's fallback × takes the skin's face like any other string (the skinning rollout's BL-02).
- **Blizzard's own frames stay stock** (skinning-§7): `GameTooltip`'s frame (only the lines are the
  addon's), the reset and purge `StaticPopup`s, the Settings window's chrome and footer Defaults
  button, the minimap button (LibDBIcon) and the resize grip's art (`Core.MakeResizable` takes no
  owner). The launcher tooltip's one host line, the record count, takes `gtip.subtle` (the 0.7 gray
  it drew).

## Known Limitations

- **Currency movements are not recorded, and are not planned.**
- **Guild-bank withdrawals by other players are invisible** — the addon sees only your own client.
- **The reagent bank and void storage are not stores** — Midnight removed both.
- **A store-to-store transfer is not recorded** — neither side is the bags.
- **A movement made while capture is off is lost**, not backfilled.
- **Pre-corroboration gold rows cannot be cleaned up retroactively** — nothing in a stored row
  distinguishes them.
- **An uncached item is skipped when a minimum quality is set.**
- **The login backfill resolves at most 40 item ids per login** (`C.BACKFILL_MAX_IDS`), so a large
  legacy ledger of `Item <id>` rows fills in over several logins. An id the client answers with
  `success = false` (an item that no longer exists) stays unfilled and is asked about again next login.
- **Rows recorded before the link-enrichment fix keep their base-item quality** — they were written
  from the itemID, so a bonus-upgraded drop was stored at the quality its base item has. Nothing
  re-resolves a field a stored row already has (the login backfill fills nil fields only), so those
  rows stay as recorded.
- **Two variants of one itemID in a single snapshot resolve to the same link** — the scan keeps the
  first hyperlink it sees per id and the counts map is keyed by id alone, so it cannot tell an
  upgraded copy from a base one when both are present.
- **The simulator covers bank visits only.** There is no simulation of mail, currencies, the login
  backfill or the retention prune; the four scenarios are a personal-bank visit, a warband
  transfer, a guild-bank visit and a one-sided change.
- **The simulated warband deposit's event list is unverified on 12.1.5.** `D.EVENTS` in
  `modules/SimDrivers.lua` is built from the best documented knowledge; the real sequence is an
  owner in-client check (`docs/smoke-tests.md` SIM-10), and a difference is a one-line data fix.

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
| `schema.md` | `BankLedgerDB`'s two scopes (account-wide and per profile), the entry fields, the Schema runtime and its stub, every registry, recorded-data and carve-out writer, migrations |
| `settings-panel.md` | The three pages, the seven-tab strip (the Skin tab and the first-run skin picker included), the twenty-four rows, the single `Schema:Set` write seam, the bulk bracket and the reset routes |
| `data-flow.md` | Snapshot → diff → corroborate → record, and the event choreography around it |
| `common-tasks.md` | Add a setting, a command, a store, a migration, a chart, an event |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `slash-dispatch.md` | Present | 20 verbs in `NS.COMMANDS` (threshold is 8) |
| `midnight-quirks.md` | Present | Client-version workarounds of the addon's own |
| `compat-layer.md` | Present | `core/Compat.lua` carries 15 addon-specific shims beyond LibKa0s |
| `message-bus.md` | Not applicable | Four messages; threshold is more than ten. The table lives in `ARCHITECTURE.md` → `## Message bus` |
| `profiles.md` | Present | AceDB profiles are user-visible: the Profiles page (`settings/Profiles.lua`) ships a profile control. What a profile holds, what stays account-wide (the ledger and its retention window), the v3 lift, the v4 return of the window and the v5 per-tab saved views, the profile events, the reset and the `/bl profile` verb |
| `debug.md` | Present | The trace's **Coverage** (every tag, what emits it and when, and the reconcile pass's quiet steady state, `debug-logging-§8`/`§9`); the diagnostics report, `/bl diagnostics` / `/bl debug diagnostics` (`debug-logging-§14`: its sections, caps and what it never reads or calls), and the two addon-owned topic dumps, `/bl debug scan` and `/bl debug panel`; which to paste with a bug report |
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
| `windows.md` | The two standalone windows, how they wear the skin, and the geometry-save contract |
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
| `performance-§12` | No performance harness is wired: no `core/PerfSetup.lua`, no `BankLedgerPerfDB`, no `perf` verb registration, no suspend/resume contract, no `tests/perf.lua`, no `docs/perf-analysis/`. | **The no-combat-path exemption, criterion (a) plus (b).** (a) — the whole-repo sweep of `RegisterEvent` / `SetScript("OnUpdate"` / `C_Timer` is committed at [`docs/performance.md`](./performance.md) with the per-event work named for every hit: no `OnUpdate` handler anywhere, no repeating ticker (every timer is a one-shot), and every event that *can* fire in combat is a row of that page's table with its work named: the three change events (`BAG_UPDATE_DELAYED`, `PLAYERBANKSLOTS_CHANGED`, `PLAYER_MONEY`) and `GUILDBANKBAGSLOTS_CHANGED` reach a single `NS.State.openContext` nil check and return, and the combat pair `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` also runs `NS.Util.ApplyVisibility` — bounded, allocation-free, once per combat edge. (b) — the capture protocol opens its windows on the player's combat state (`performance-§7`), and this addon's entire engine is gated on a bank frame being open, which is an out-of-combat NPC interaction; every declared bucket would read `0.000` by construction. Reasoned at length in closed issue [`LIBKA0S-17`](https://github.com/tusharsaxena/BankLedger/issues/9); ratified here. | 2026-08-05 | **The first `OnUpdate` handler, repeating ticker, or in-combat event handler doing real work re-arms the full `performance` wiring MUST.** Concretely: an event handler that stops checking `NS.State.openContext` first, or a scan moved off the bank-open gate onto a bag event. Re-checked 2026-09-23 (audit): trigger not fired. |
| `localization-§1` | This addon ships **English only**: the `NS.L` seam is exported and `locales/enUS.lua` ships, and every label, tooltip and message but seventy-nine is a hardcoded English literal. The seventy-nine route through `NS.L` and resolve to their English key through its fallback, with no override in `enUS.lua`: the `profile`, `debug` and `diagnostics` help lines in `NS.COMMANDS` (`settings/Schema.lua`), the library-absent `%s is unavailable: the LibKa0s library did not load.` line (`core/DebugLogSetup.lua`, `settings/Slash.lua`), the ledger window's red `TEST MODE` title badge, and the test-mode strip's line (`TEST MODE: a sample ledger, not your bank. Combat ends it.`) and its three tooltip lines (`modules/Browser.lua`, BankLedger#23), the Show window key binding's action label `Toggle ledger window` and its Keybindings-tab tooltip `Shows or hides the ledger window.` (`core/LauncherSetup.lua`, `launcher-§6`), the simulator-absent line `The simulator needs LibKa0s-Sim-1.0.` (`core/SimSetup.lua`), the simulated world's invented names, the alt character `Simbanker` and the unguilded player's `Simulated Guild` (`modules/SimWorld.lua`, BankLedger#24), the simulator's start line, its four start refusals (test mode, combat, a real bank visit, General visibility) and its three stop lines (`modules/Sim.lua`), the four scenarios' labels and their nineteen distinct step labels (`modules/SimScenario.lua`), the simulator gate's `Waiting for the ledger to settle.` (`modules/Sim.lua`), test mode's refusal while a simulation runs (`modules/LedgerTable_TestMode.lua`), the purge refusal `Stop the simulation first.` (`core/Database.lua`), the `sim` help line in `NS.COMMANDS` (`settings/Schema.lua`), the simulation step panel's twenty-five presentation strings (its step labels and tooltips and the Start and Stop tooltips, `modules/Sim.lua`), and the simulation marker's strip line `Simulation: %s - nothing here is saved.` (`modules/Sim.lua`) with its three tooltip lines (`modules/Browser.lua`), and the skin seam's `Reload your interface (/reload) to finish changing the skin.` (`core/SkinSetup.lua`). The launcher's `leftClickLabel` (`Toggle ledger window`) routed through it from M5 (2026-09-24) until Launcher minor 4 retired the field (M6, 2026-09-25); the menu's entry labels are the library's own `lib.STRINGS`. The one entry that briefly sat there was the disabled-verb refusal, added 2026-09-16 and **removed 2026-09-17**: `slash-commands-§7` makes that line the collection's wording, `LibKa0s-Slash-1.0` builds it from `lib.DISABLED_LINE_FORMAT`, and the standard says in as many words that the `L` override does not reach it. | `localization-§3` names this one of the routing SHOULD's **two terminal compliant states** — English-only, *recorded* — so the row is not a deferral, it is the compliant end state, and an audit reads it as accepted rather than re-filing the SHOULD. Both `localization` MUSTs are met unconditionally: the seam is exported with the key-returning metatable fallback (`locales/enUS.lua:6`) and `enUS.lua` ships carrying no dead keys. The wrapped string that briefly existed never narrowed the row, and its removal does not widen it: the row has always been about the SEAM being exported and ready, which it is. The argument was written at the head of `locales/enUS.lua` and tracked at [issue #3](https://github.com/tusharsaxena/BankLedger/issues/3), and a comment is exactly what `documentation-§3` says does not ratify a thing — which is why four consecutive audits re-filed it, most recently as `BL-04` in `docs/audits/2026-09-07/`. This row is the ratification the comment was standing in for. | 2026-07-31 | **The first non-English locale file added to `locales/`.** That change routes the strings and retires this row. Re-checked 2026-09-23 (audit): trigger not fired. |
| `standalone-windows` | The close control on this addon's **own** windows is the host's own factory — `B:MakeCloseButton` in `modules/Browser.lua`, 24×24 — rather than a one-line wrapper over `lib.MakeCloseButton`; since the owner's close-control ruling of 2026-10-29 it is painted through the skin's `CloseButton` exactly as the library's own control is (no opts, no host hover scripts), so every skin, Ka0s Default included, draws `close.rest` / `close.hot` on it, which `core/CoreSetup.lua` deliberately does not republish (its "`lib.MakeCloseButton` IS DELIBERATELY NOT REPUBLISHED" paragraph). | **A reasoned decline is a terminal compliant state, and this row is the fourth of the four conditions it costs.** (1) *Host windows only*: the ledger (`EnsureFrame` in `modules/Browser.lua`), the session window (`ensureFrame` in `modules/SessionWindow.lua`) and the export modal (`EnsureFrame` in `modules/Export.lua`) are this addon's, and those are the factory's three callers; the export **copy** window is `LibKa0s-Widgets-1.0`'s `CopyWindow` and wears the library's mark, as do the debug console and its copy box. (2) *The same shared mark*: `B:MakeCloseButton` resolves the catalog's `close` through `NS.Icon("close")`, inside `B:MakeCloseButton` itself, with the documented fallback ladder beneath it, so the two implementations agree on the art and the skin's rest and hover tints, and differ only in size. (3) *Exactly one host factory*: `grep -rn 'MakeCloseButton(' --include='*.lua' | grep -v '/libs/'` returns that factory, its three callers and no two-argument call to `lib.MakeCloseButton` anywhere — anti-pattern #65 does not apply. (4) This row. Adoption would change three visible controls a player already knows for no player benefit. Filed as `BL-28` in `docs/audits/2026-09-07/`; declined in closed issue [#5](https://github.com/tusharsaxena/BankLedger/issues/5) on 2026-08-06, unratified until now. | 2026-08-06 | **Any one of the four conditions ceasing to hold**: a second host close factory, a call to `lib.MakeCloseButton` from anywhere but a window the library owns, a private glyph replacing the catalog's `close`, or the host drawing its own control onto a library window. Re-check also if `standalone-windows` withdraws the decline. Re-checked 2026-09-23 (audit): trigger not fired. |

No other issue owes a row: the `state:will-not-do` issues #4, #6, #7, #8, #10, #15 and #20 decline
library adoptions or scope, not rules of the standard (#5 and #9 are cited by the rows above).

### Files over the 1500-line cap

`layout-§1` caps every authored `.lua` file this repo tracks at 1500 lines -- `tests/` included,
`libs/` and `tests/_kit/` carved out as vendored code. A file over the cap is listed here, one row
per file, with its terminal state: an open issue naming the seam a peel would follow, a ratified
deviation row above, or a scheduled peel.

Nothing is over the cap today. The largest authored file is `modules/Browser.lua`; read its
current size with `git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l |
sort -n`. This page carries no line figure on purpose (the live one is the watch list in
`docs/automated-tests/RESULTS.md`); `tests/_kit/test_layout_cap.lua` asserts membership
in both directions -- an over-cap file missing from this census, or a row here naming a file that
is no longer over the cap -- and a line count is not what it checks.
