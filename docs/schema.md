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

`NS:RunMigrations` is no longer a bare seam: the v1 → v2 step walks `db.global.ledger` once, sets
`e.vendorPrice = nil` on every entry, bumps `schemaVersion` to 2, and emits the standard `[Migrate]`
debug line via `NS.MigrationSummary`. It is idempotent — a v2 database is skipped entirely, and
clearing an already-absent field on a partially-migrated one is a no-op.

**The stamp is not an AceDB default, and must never become one again.** It was one until
`BANKLEDGER-R-02`, and that is why the ladder above had never actually run on a player's store:
AceDB's logout handler re-registers `nil` defaults, which strips every stored key still equal to its
default, so the stamp left the file at logout and came back at the next login as whatever the current
default said. The runner read its own target and the `< NS.SCHEMA_VERSION` arm was never true. The
stamp is now seeded by `NS:RunMigrations` as an ordinary stored value. An unstamped store is a fresh
install when its ledger is empty (or absent) and a pre-stamp v1 database when it is not — the ledger
is the discriminator, and it is a safe one, because a migration over an empty ledger is a no-op
whichever way it is read.

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


## Storage carve-outs

**Storage carve-outs** are `architecture-§5` **named non-setting state**. No control sets them and
no row addresses them, and each is written by its one owner module rather than through
`Schema:Set`:
- `settings.window`, the main window's geometry (owner `modules/Browser.lua`);
- `settings.sessionWindow`, the session window's geometry (owner `modules/SessionWindow.lua`);
- `db.global.savedView`, the filter bar's saved baseline (owner `modules/Browser.lua`).

`db.global.minimap.minimapPos` is the fourth, with a different writer: LibDBIcon stores the
button's position there on a drag, in the table `B:SetupMinimap` hands it. That table also holds
the `minimap.hide` row, so the addon never replaces it whole. It comes from the AceDB default, and
`B:SetupMinimap` has no seed of its own. [ARCHITECTURE.md → Settings Schema](ARCHITECTURE.md#settings-schema)
names every writer of all four and the act that reaches each. That naming is what makes them
compliant, so none has a `Documented deviations` row. A new writer of any of them joins that list.

**The filter id-sets are a structural registry, not a carve-out** (`architecture-§5`).
`db.global.blacklist` and `db.global.whitelist` are item-id sets the player adds to and removes from,
and no row path names them. Their one writer is `NS.Filters` (`modules/Filters.lua`), which writes
copy-on-write, re-caches the capture gate and fires `LedgerChanged`. They have no load pass: AceDB
supplies the empty defaults, and `NS:RunMigrations` never writes them. See
[ARCHITECTURE.md → Settings Schema](ARCHITECTURE.md#settings-schema).

**The saved view** — `db.global.savedView` holds the grouping, sort, date range, search text and the
five multi-select column filters, captured by the filter bar's **Save** button. It is *absent* until
the user saves: no key is what "nothing saved" means, so an empty table stays available to mean a
deliberately all-cleared save. **Clear** returns to it (or to `STOCK_VIEW` when absent); **Reset**
discards it, as does `Slash:CliResetAll` and therefore the Panel's Defaults button. The character
scope is deliberately *not* part of a view — it is a per-session default of Current that widens on
demand, so a stale save can never pin the window to one alt. Applied once, at frame build, so
closing and reopening the window mid-session keeps whatever you were working with.

**The movement log is recorded data, not a carve-out or a registry** (`architecture-§5` named
non-setting state). `db.global.ledger` is owned by `NS.Database`, and only its `Add`, `Delete`,
`DeleteAt`, `Purge` and `PruneOld` write it. `PruneOld` runs off the `settings.retentionDays` row.
[ARCHITECTURE.md → Settings Schema](ARCHITECTURE.md#settings-schema) names the act that reaches each
writer.

**Not settings:** the debug *logging* flag is `NS.State.debug` — session-only, off at login, never
written to SavedVariables. The current banking session's movements are `NS.State.sessionEntries` —
references to already-stored entries, held only while a bank frame is open and never persisted.
