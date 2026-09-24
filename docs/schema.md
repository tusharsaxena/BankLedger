# Schema

What Bank Ledger persists: the single account-wide saved variable, one entry per movement, the
storage-only carve-outs, the filter id-set registry, and the migration seam. The controls that write settings are
[settings-panel.md](settings-panel.md); how an entry comes to exist is [data-flow.md](data-flow.md).

## The saved variable

One SavedVariable, `BankLedgerDB`, **account-wide `global` scope only**. AceDB still creates the
profile namespace — the addon calls `AceDB:New("BankLedgerDB", NS.defaults, true)` — but it is
deliberately unused: you deposit on one character and withdraw on another, so a per-character profile
would split the very history the addon exists to join up. `defaults/Global.lua` is the single place a
default value is hardcoded, and there is deliberately no `defaults/Profile.lua` (a ratified deviation
— see `ARCHITECTURE.md` → `## Documented deviations`).

One ledger entry per movement, appended to `db.global.ledger` (oldest first):

| Field | Notes |
|---|---|
| `ts` | Epoch seconds. |
| `char`, `classFile` | `Name-Realm` and the class token, for the per-character views. |
| `kind` | `ITEM` or `MONEY`. Those two are the whole enum; currencies are not recorded. |
| `direction` | `DEPOSIT` (bags → store) or `WITHDRAW` (store → bags). |
| `store` | `BANK`, `WARBAND_BANK`, `GUILD_BANK`. |
| `guild` | Set on guild-bank rows only. |
| `itemID`, `itemLink`, `itemName`, `quality`, `itemType`, `itemSubType` | Item rows. An item the client has not cached yet stores its id alone. `itemLink` is the link the **scan** saw, so it carries the item's bonus IDs (see [Bonus IDs survive the scan](#bonus-ids-survive-the-scan)). |
| `quantity` | Stack size for an item row; copper for a `MONEY` row. |
| `zone`, `subzone`, `mapID` | Where the movement happened. |

Every stored enum **value** equals its key and is part of the CSV export contract — extend the
enums freely, never rename a member.

#### Retired stores

`REAGENT_BANK` and `VOID_STORAGE` were removed from `C.Store` outright rather than kept as dead
members, and the removal deliberately sits outside the rule above.

The rule protects rows that already exist: renaming a member orphans stored data that still carries
the old string. Neither of these could ever have produced one. The addon is Retail-only at Interface
120100, where Midnight has already removed both — void storage exposes no container or events at
all, and `REAGENT_BANK`'s container group resolved empty, so `StoresFor` dropped it from every scan
before a movement could be attributed to it. There is no installed base either: both were removed
before v1.0.0, the first published release, so no shipped build ever wrote a row against them. Zero
reachable rows, so nothing to orphan.

`StoresFor`'s empty-group guard stays regardless — it is what makes a retired container degrade to
"not on this build" instead of a permanently empty store in every debug line, and Blizzard will
retire another one. `tests/test_ledger.lua` drives it directly by emptying a live store's group.

If a store is ever retired *after* rows exist, the answer is the opposite one: keep the member,
drop it from `CONTEXT_STORES`, and let the history keep rendering.

#### Schema v2 — the value dimension is gone

`db.global.schemaVersion` is now **2**. Vendor price was a poor proxy for worth, so the addon stopped
deriving, capturing and persisting it entirely: `Util.EntryValue`/`Util.SignedValue` are deleted,
`Compat.GetItemDetails` returns 5 values (`name, quality, itemType, itemSubType, link`, no vendor
price), and a ledger entry never carries `vendorPrice`. Gold is unaffected — a `MONEY` row's amount
lives in `quantity` and was never vendor-priced.

The v1 → v2 step is `NS.MIGRATIONS[2]` in `core/Database.lua`: it walks `db.global.ledger` once,
sets `e.vendorPrice = nil` on every entry and returns the rows it touched. `NS:RunMigrations` runs it,
stamps `schemaVersion = 2`, and emits the standard `[Migrate]` debug line via `NS.MigrationSummary`.
It is idempotent — a v2 database is skipped entirely, and clearing an already-absent field on a
partially-migrated one is a no-op.

#### The SavedVariables stamp — declared as 0 (savedvariables-§1, standard v2.65.0)

`defaults/Global.lua` declares `schemaVersion = 0`, and **0 is never a real version**. That is the
point. AceDB's logout handler re-registers `nil` defaults, which strips every stored key still equal
to its default. Until `BANKLEDGER-R-02` the default read `NS.SCHEMA_VERSION`, so the stamp left the
file at logout and came back at the next login as the runner's own target, and the v1 → v2 ladder
never once ran on a player's store. A real stamp (1, 2, …) never equals 0, so the strip cannot remove
it. The 0 AceDB backfills onto a legacy, unstamped store reads as "unstamped" rather than hiding it.

`NS:RunMigrations` reads `tonumber(g.schemaVersion) or 0` and returns when it is already at or above
`NS.SCHEMA_VERSION` (a future version is never downgraded). It treats 0 and nil alike, as v1, and
then runs `NS.MIGRATIONS[target]` for each version above that, **stamping after each step returns**.
A step that raises propagates, and the stamp stays at the last completed version, so the next login
retries that step. Reading an unstamped store as v1 covers a legacy pre-stamp store (which is v1) and
a fresh install alike: every step over an empty ledger is a no-op, so a fresh install costs one loop
and ends stamped current.

`Sl:ResetEverything` runs the runner again after its wipe, because the merged-back defaults carry the
declared 0. Without that, a reset store would read v0 until the next login.

There is **no profile scope** to walk. `savedvariables-§1`'s per-profile rule has nothing to act on
here: this addon stores only `db.global` (the `savedvariables-§2` register row), so every step takes
`db.global`.

#### Accepted deviation — the CSV export contract broke

`core/Database.lua` and `modules/Export.lua` document the CSV column set as stable, and the schema-v2
bump breaks it — recorded here as an **accepted, deliberate deviation**, versioned by the schema
bump rather than left open-ended:

- The **ledger CSV** loses the `vendorPrice`, `value`, `valueRaw` and `net` columns.
- The **Insights CSV** loses the `Summary / Value moved` row and the whole `Top Items By Value`
  section; `Net by Store` now writes its movement count into the **Count** column instead of a
  value.

Keeping the columns and emitting blanks was considered and rejected: a `value` column with no value
behind it is a promise the data no longer keeps, and it would outlive everyone's memory of why the
column went empty. The break is one-time and tied to `schemaVersion`, not an open-ended contract
violation.

The later `wowhead` column is **not** part of that break: it is appended after `zone`, so every
existing column keeps its index and a sheet keyed on position is unaffected. Growth at the end is
what the stable-column-set promise allows.


## The runtime: `LibKa0s-Schema-1.0`

**The runtime is `LibKa0s-Schema-1.0`** (adopted at LibKa0s v1.55.0; its contract is LibKa0s
`docs/api/Schema/version-1-docs.md`). The rows are this addon's; the path walk, the row index, the
write seam, the bulk bracket and the load-time check are the library's. `settings/Schema.lua` builds
one instance, `NS.SchemaRuntime`, over `S.Schema`, and binds every name callers already used to it:
`S:Set`, `S:Get`, `S:Default`, `S:ApplyDefault`, `S:FindRow`, `S:ReadPath`, `S:WritePath`,
`S.SameValue`, `S.BulkBegin`, `S.BulkEnd` and `S:Register` (now the library's `Validate`). The
Options and Slash descriptors take the instance's members directly, as values; there is no gate in
front of the seam for that to bypass. The descriptor supplies what is ours: every stored path
resolves against `NS.db.global`, the post-write tail is the panel repaint (`options-ui-§11`), the
`[Set]` line goes to `NS.Debug` only while logging is on, the sweep veto is `S.RESET_EXEMPT`
(`launcher-§3`), and `L` keeps this addon's refusal wording (`unknown path: <path>`,
`invalid value`). Each write runs refuse unknown path, `validate`, store (a table value is copied
in), tally or log, `onChange`, repaint, in that order. The Minimap button row's inversion is the
row's own `set`, so no other code knows which way round its boolean is. `S:Register` now reports a
row whose path is missing from `defaults/Global.lua` even when the row carries a `default` of its own;
before the adoption that row passed, although AceDB would still have read it as nil.

## Without the library: the degradation stub and write-through

Without the library, `settings/Schema.lua` builds the same instance from a **runtime-completing,
log-silent** stub (`options-ui-§1`), the shape the major's document prescribes, trimmed to what this
addon calls: reads, writes, reactions, the repaint and the sweep veto work, so the host verbs keep
writing. It also honors the descriptor's `writeThrough` (`S.WRITE_THROUGH`, today `settings.enabled`
alone), so `/bl enable` and `/bl disable` keep working with the composed row absent
(below). It writes no `[Set]` line, keeps no tally and runs no check; the
degraded DebugLog stub would discard the line anyway. `tests/test_surface_parity.lua` holds the stub
to the live instance and the stub library to the major.

With `libs/LibKa0s` missing, `settings/Schema.lua` builds `NS.SchemaRuntime` from its
runtime-completing stub (the paragraph above says what it carries), and the composed
Master controls rows do not exist, because their composer is `LibKa0s-Options-1.0`. One of them is a
path a host verb writes: `settings.enabled`, written by `/bl enable` and `/bl disable`. So it is
listed in **`S.WRITE_THROUGH`** and handed to the seam as the descriptor's `writeThrough`
(`options-ui-§1` route (a)). A row-less listed path is stored raw (a copy), announced, and refused
only on a missing store; every other row-less path still answers `unknown path`. A path that has a
row always takes the row, so on a full load the checkbox's validate and `onChange` run as before.
The live `LibKa0s-Schema-1.0` minor 2 honors the same field on a partial load (Schema present,
Options absent). A write-through row runs no `onChange`, so both `/bl enable` and `/bl disable` re-run
the latch themselves (`NS.ReevaluateEnabled`; see [slash-dispatch.md](slash-dispatch.md)).
`settings.locked` is not listed because no verb writes it; test mode and the debug console are
session state switched through `LT:SetTestMode` and `NS.DebugLog`, never through the seam.

## Registry, recorded data and named-state writers

**One structural registry** (`architecture-§5`): the filter id-sets, which the player adds item ids
to and removes them from.
- **Storage keys.** `db.global.blacklist` and `db.global.whitelist`, both shipped empty in
  `defaults/Global.lua`.
- **Writer.** `NS.Filters` in `modules/Filters.lua`: `F:_move`, `F:_remove`, `F:ClearList` and
  `F:ClearAll`, with `AddBlacklist` / `AddWhitelist` / `RemoveBlacklist` / `RemoveWhitelist` over the
  first two. The Filters tab, the ledger's right-click menu and the two clear popups call it, and
  nothing else writes either key.
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
    (`addon:OnEnterWorld`), on an AceTimer the stand-down cancels. The session latch is set when
    the prune runs, so a disable inside those five seconds postpones it to the next
    `PLAYER_ENTERING_WORLD` rather than skipping it.
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
  `B:OnLogout`. `B:ResetWindow` empties it. Two routes reach that reset: `NS.Util.ResetWindowPositions`
  (the Master controls tab's *Reset position*), and `Sl:ResetEverything` once its wholesale reset is
  done — which is where *Reset all settings*, the General page's *Defaults* and `/bl resetall` all
  land after the confirm.
- **Session window geometry.** Storage key `db.global.settings.sessionWindow`, same shape. Owner
  `NS.SessionWindow` (`modules/SessionWindow.lua`). Writers: `SW:SaveGeometry`, on the same four
  occasions (drag-stop, grip mouse-up, `OnHide`, and `PLAYER_LOGOUT` through `SW:OnLogout`), and
  `SW:ResetWindow`, which empties it and is reached by the same two routes as `B:ResetWindow`.
- **Saved ledger view.** Storage key `db.global.savedView`, absent until the player saves. Owner
  `NS.Browser`. Writers: `B:SaveView`, from the filter bar's **Save** button, which stores the view on
  screen whole (`B:CaptureView`), and `B:ResetView`, which clears it. The bar's **Reset** button
  calls `B:ResetView`. `Sl:ResetEverything` empties the key with the rest of `db.global`, then calls
  `B:ResetView` silently so the view still painted on the bar goes back to stock too.
- **Minimap button position.** Storage key `db.global.minimap.minimapPos`. Owner **`NS.Launcher`**
  (`core/LauncherSetup.lua`), which hands `db.global.minimap` to LibDBIcon at `Register` time.
  Writer: LibDBIcon itself, when the player drags the button
  (`libs/LibDBIcon-1.0/LibDBIcon-1.0.lua:194`). The addon never writes the field. The same table
  holds `hide`, the Minimap button row's stored key (CLI path `minimap.shown`), so the addon never
  replaces the table whole either. AceDB supplies
  it from `defaults/Global.lua`, and the seam has no seed of its own. It was `NS.Browser`'s
  `B:SetupMinimap` until the launcher was adopted (`launcher-§1`).

`NS:RunMigrations` touches none of the four. `Sl:ResetEverything` empties `db.global` wholesale and
merges the defaults back, then re-runs `NS:RunMigrations` so the declared `schemaVersion = 0` is
re-stamped to the current version at once (the stamp is under *The SavedVariables stamp* above). The wipe
replaces the first three along with everything else; the standard
does not count a wholesale replacement as a writer to name. **The fourth is the exception**: the
whole `db.global.minimap` table is held across that wipe and put back, because both keys in it are
per-installation display preferences rather than settings (`launcher-§3` — see [ARCHITECTURE.md → Launcher](ARCHITECTURE.md#launcher)).

## Storage carve-outs

**Storage carve-outs** are `architecture-§5` **named non-setting state**. No control sets them and
no row addresses them, and each is written by its one owner module rather than through
`Schema:Set`:
- `settings.window`, the main window's geometry (owner `modules/Browser.lua`);
- `settings.sessionWindow`, the session window's geometry (owner `modules/SessionWindow.lua`);
- `db.global.savedView`, the filter bar's saved baseline (owner `modules/Browser.lua`).

`db.global.minimap.minimapPos` is the fourth, with a different writer: LibDBIcon stores the
button's position there on a drag, in the table **`NS.Launcher`** (`core/LauncherSetup.lua`) hands
it at `Register` time. That table also holds `hide`, the Minimap button row's stored key (CLI path
`minimap.shown`), so the addon never replaces it
whole — and it is the one part of `db.global` the wholesale *Reset all settings* holds back and
puts back, because both keys in it are per-installation display preferences rather than settings
(`launcher-§3`). It comes from the AceDB default, and the seam has no seed of its own. `B:SetupMinimap` did
this until the launcher was adopted (`launcher-§1`). [Registry, recorded data and named-state writers](#registry-recorded-data-and-named-state-writers)
names every writer of all four and the act that reaches each. That naming is what makes them
compliant, so none has a `Documented deviations` row. A new writer of any of them joins that list.

**The filter id-sets are a structural registry, not a carve-out** (`architecture-§5`).
`db.global.blacklist` and `db.global.whitelist` are item-id sets the player adds to and removes from,
and no row path names them. Their one writer is `NS.Filters` (`modules/Filters.lua`), which writes
copy-on-write, re-caches the capture gate and fires `LedgerChanged`. They have no load pass: AceDB
supplies the empty defaults, and `NS:RunMigrations` never writes them. See
[Registry, recorded data and named-state writers](#registry-recorded-data-and-named-state-writers).

**The saved view** — `db.global.savedView` holds the grouping, sort, date range, search text and the
five multi-select column filters, captured by the filter bar's **Save** button. It is *absent* until
the user saves: no key is what "nothing saved" means, so an empty table stays available to mean a
deliberately all-cleared save. **Clear** returns to it (or to `STOCK_VIEW` when absent); **Reset**
discards it, as does the global reset (`Sl:ResetEverything`, behind every reset control). The character
scope is deliberately *not* part of a view — it is a per-session default of Current that widens on
demand, so a stale save can never pin the window to one alt. Applied once, at frame build, so
closing and reopening the window mid-session keeps whatever you were working with.

**The movement log is recorded data, not a carve-out or a registry** (`architecture-§5` named
non-setting state). `db.global.ledger` is owned by `NS.Database`, and only its `Add`, `Delete`,
`DeleteAt`, `Purge` and `PruneOld` write it. `PruneOld` runs off the `settings.retentionDays` row.
[Registry, recorded data and named-state writers](#registry-recorded-data-and-named-state-writers) names the act that reaches each
writer.

**Not settings:** the debug *logging* flag is `NS.State.debug` — session-only, off at login, never
written to SavedVariables. The current banking session's movements are `NS.State.sessionEntries` —
references to already-stored entries, held only while a bank frame is open and never persisted.
The sample ledger is `NS.State.testRecords`, never persisted either. Its switch, `state.testMode`
(the Master controls **Test mode** box), is a schema row but a **session-only** one: it answers
through `LT:IsTestMode()` and writes nothing under `db.global`.
