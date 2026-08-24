# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below is the **authoritative pass count** — the README test
badge and any count quoted in the docs must agree with it.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_util.lua (31)

- Util.PlayerKey joins name and realm with spaces stripped
- Util.SplitPath splits a dotted settings path
- Util.SplitPath returns a single component for a bare key
- Util.FormatDate uses the locale-unambiguous DD-MMM-YYYY form
- Util.FormatClock renders HH:MM
- Util.PlainMoney always renders gold, silver and copper parts
- Util.PlainMoney renders zero rather than an empty string
- Util.PlainMoney renders nil as empty
- Util.FormatMoney is blank for nothing and compact for a real amount
- Util.EntryType is the stored item type for an item movement
- Util.EntryType is Gold for a gold movement, which stores no type
- Util.EntryType is blank for an uncached item and for nothing at all
- Util.ClassIconMarkup carries the class's slice of the icon sheet
- Util.ClassIconMarkup honors a requested size
- Util.ClassIconMarkup is empty for an unknown or missing class
- Util.FormatBytes steps through B, kB and MB
- Util.RangeFrom returns nil for the no-bound 'all' range
- Util.RangeFrom windows are ordered today > 7d > 30d
- NS.IsConcatSafe accepts an ordinary value
- NS.IsConcatSafe rejects a value table.concat would refuse
- NS.SafeToString substitutes a sentinel for an unconcatenable value
- NS.SafeToString passes nil and booleans through unmasked
- NS.Print prefixes the cyan [BL] tag and space-joins its arguments
- NS.Print never raises on a value that would break table.concat
- NS.Print survives the AceConsole embed (architecture-§2)
- Util.WowheadURL carries every bonus id from the item link
- Util.WowheadURL stops at the declared bonus count
- Util.WowheadURL omits the bonus query for an item that has none
- Util.WowheadURL falls back to the stored item id when there is no link
- Util.WowheadURL accepts a bare item string as well as a full hyperlink
- Util.WowheadURL returns nothing for a row with no item at all

### test_compat.lua (21)

- Compat.ItemIDFromLink pulls the id out of a full item link
- Compat.ItemIDFromLink accepts a bare itemString
- Compat.ItemIDFromLink returns nil for anything that is not a link
- Compat.QualityLabel maps a quality id to its English name
- Compat.QualityLabel defaults to Poor when given nothing
- Compat.GetItemDetails returns name, quality, type, subtype and vendor price
- Compat.GetItemDetails returns nil for an item the client has not cached
- Compat.ItemNameQuality resolves an id the client knows
- Compat.GetContainerNumSlots reports zero for an unreachable container
- Compat.GetContainerSlot returns a normalized triple for a filled slot
- Compat.GetContainerSlot returns nil for an empty slot
- Compat.GetZone returns the zone and subzone
- Compat.GetGuildName returns the player's guild
- Compat.GetMoney reads the carried balance
- Compat.GetStoreMoney reads the guild bank's own balance while the frame is open
- Compat.GetStoreMoney returns nil for the guild bank when the frame is closed
- Compat.GetStoreMoney reads the warband balance by BankType name, not by number
- Compat.GetStoreMoney returns nil for a store that holds no coin of its own
- Compat.GetStoreMoney returns nil when the build exposes no reader
- Compat.GetPlayerMapID returns the current map id
- Compat.GetAddOnMetadata degrades to nil when neither getter exists

### test_constants.lua (21)

- Constants: every Store enum member appears in the display order
- Constants: every Store enum member has a display label
- Constants: every Store enum value equals its key (the stable stored form)
- Constants: every Direction enum member has a label and a sign
- Constants: a deposit signs positive and a withdrawal negative
- Constants: every Kind has a label
- Constants: the bag id group covers the backpack, four bags and the reagent bag
- Constants: the bank group is exactly the six character-bank tabs
- Constants: the warband bank spans its five account tabs
- Constants: no container id belongs to two stores
- Constants: no group lists the same id twice
- Constants: the enum's type constants are never mistaken for containers
- Constants: every container-backed store resolves to a non-empty group
- Constants: the guild bank is NOT container-id scanned
- Constants: the store mute options exclude BAGS
- Constants: every quality option carries a numeric value and a label
- Constants: the retention presets offer an 'Always' (0) option
- Constants: every store has a display color
- Constants: every direction has a color and a glyph
- Constants: every open-frame context has a Ledger store list
- Constants: C.Context is its own axis, not a subset of C.Store

### test_filters.lua (15)

- Filters: an added id reads back as blacklisted
- Filters: adding the same id twice is a no-op the second time
- Filters: adding to one list removes the id from the other
- Filters: removing an id that is not on the list reports no change
- Filters: a removed id is no longer blacklisted
- Filters: a non-numeric id is rejected rather than stored
- Filters: an item link is accepted as an id
- Filters.ParseItemID accepts a bare number and rejects plain text
- Filters: a write never mutates the previously stored table in place
- Filters.SortedIDs returns the ids in ascending order
- Filters.ClearList empties one list and reports how many went
- Filters.ClearList on an empty list reports zero
- Filters.ClearList ignores an unknown list name
- Filters.ClearAll empties both lists in one go
- Filters: a list change re-caches the capture gate's upvalues

### test_ledger.lua (116)

- Ledger.Diff: stack leaving bags and arriving in the store is a DEPOSIT
- Ledger.Diff: stack leaving the store and arriving in bags is a WITHDRAW
- Ledger.Diff: a partial stack move records only the quantity that actually moved
- Ledger.Diff: quantity is the smaller of the two sides when they disagree
- Ledger.Diff: an item that only appears in bags is not a bank movement
- Ledger.Diff: an item that only appears in the store is not a movement
- Ledger.Diff: identical snapshots produce nothing
- Ledger.Diff: several items in one pass each get their own movement
- Ledger.Diff: movements come back in ascending itemID order (deterministic)
- Ledger.Diff: the store name is carried on every movement
- Ledger.Diff: money leaving the player and arriving at the store is a DEPOSIT
- Ledger.Diff: money leaving the store and arriving at the player is a WITHDRAW
- Ledger.Diff: a purse drop the store's balance does not mirror is NOT a deposit
- Ledger.Diff: a store balance change the purse does not mirror is not a movement
- Ledger.Diff: both balances falling together is not a movement
- Ledger.Diff: the recorded amount is the smaller of the two deltas
- Ledger.Diff: an unreadable store balance produces no money movement
- Ledger.Diff: a balance readable on only one side produces no money movement
- Ledger.Diff: money is ignored at a store that holds no gold
- Ledger.Diff: an unchanged balance produces no money movement
- Ledger.Diff: the money movement sorts after the item movements
- Ledger:ScanStore sums stacks across every container id of a store
- Ledger:ScanStore returns an empty map for a store with no reachable containers
- Ledger:Snapshot captures bags, every reachable store and the money balance
- Ledger:Snapshot carries each money-holding store's own balance
- Ledger:Snapshot omits a store balance this build cannot read
- Ledger:StoresFor: the bank frame reaches the character bank and the warband tabs
- Ledger:StoresFor drops a store this build has no container for
- Ledger:StoresFor: the guild bank frame reaches only itself
- Ledger:StoresFor: an unknown context reaches nothing
- Ledger:Reconcile records a bags-to-character-bank deposit
- Ledger:Reconcile records a warband move with no warband open event at all
- Ledger:Reconcile writes ONE row, not one per store the frame reaches
- Ledger:Reconcile records a withdrawal back out of the bank
- Ledger:Reconcile writes nothing when no frame is open
- Ledger:CloseContext reconciles once more, then disarms
- Ledger:GateReason allows an ordinary item move
- Ledger:GateReason blocks everything while capture is disabled
- Ledger:GateReason blocks an item below the minimum quality
- Ledger:GateReason lets a whitelisted item through the quality gate
- Ledger:GateReason skips an uncached item when a minimum quality is set
- Ledger:GateReason records an uncached item at the default threshold
- Ledger:GateReason lets a whitelisted uncached item through
- Ledger:GateReason asks the client to cache an item it had to skip
- Ledger:GateReason blocks a blacklisted item even when it would otherwise pass
- Ledger:GateReason blocks a muted store
- Ledger:GateReason blocks item moves when item tracking is off
- Ledger:GateReason blocks money moves when gold tracking is off
- Ledger:GateReason ignores the quality gate for a money move
- Ledger:BuildEntry stamps who, where and when onto an item movement
- Ledger:BuildEntry enriches an item movement from the item cache
- Ledger:BuildEntry names a money movement and leaves the item fields empty
- Ledger:BuildEntry stamps the guild name on a guild-bank movement only
- Ledger:Record appends a gated-in movement to the ledger
- Ledger:Record drops a gated-out movement and writes nothing
- Ledger.MoveSummary renders one line per pass, not one per item (debug-logging-§9)
- Ledger.DiffSummary reports both sides and the move count
- Ledger.CountKinds counts distinct ids, not stack sizes
- Ledger:Diagnose reports the open store and the resolved id groups
- Ledger:Diagnose lists the BagIndex members the client exposes
- Ledger:Diagnose probes containers and reports only the ones with slots
- Ledger:Diagnose never raises when no container is reachable
- Ledger:Enable registers every event on a build that has them all
- Ledger:Enable survives a retired event and still binds the rest
- Ledger:Enable binds the capture events even when several are retired
- Ledger:Enable never lets a rejected open event silence the others
- Ledger:RegisterEventSafely reports whether the binding took
- Ledger:Diagnose names the events this build rejected
- Ledger:ScheduleReconcile coalesces a burst of events into ONE pass
- Ledger: a movement whose halves arrive in separate events is still recorded
- Ledger: a withdrawal whose halves arrive separately is also recorded
- Ledger: two separate actions stay two separate rows
- Ledger:ScheduleReconcile does nothing when no frame is open
- Ledger:CloseContext runs the pending pass instead of waiting out the debounce
- Ledger.SnapshotsDiffer spots a change on any side
- Ledger: a movement whose halves are SECONDS apart is still recorded
- Ledger: gold spent at the bank window is not recorded as a warband deposit
- Ledger: a real gold deposit still records when the store balance lands a pass later
- Ledger: a one-sided change that never completes re-anchors after the timeout
- Ledger: a re-anchored loot does not pair with a later unrelated deposit
- Ledger: an unchanged world advances the baseline without waiting
- Ledger: a completed movement clears the settle wait
- Ledger: a deletion writes no row and arms ONE deadline, not a poll
- Ledger: the deadline is armed for the REMAINING window, not a fixed retry
- Ledger: the deadline never schedules a near-zero timer
- Ledger: firing the deadline re-anchors and stops waiting
- Ledger:ScanGuildBank sees nothing from a tab that was never queried
- Ledger:QueryGuildBankTabs asks for every tab
- Ledger:ScanGuildBank reads a tab once it has been queried
- Ledger:OpenContext queries the guild bank tabs on open
- Ledger:OpenContext does NOT query guild tabs for the bank frame
- Ledger: a guild-bank deposit is recorded
- Ledger:Diagnose reports the guild-bank API and per-tab contents
- Compat.GetGuildBankSlot survives a build with no guild-bank API
- Ledger:OnGuildBankData arms the guild bank when nothing else is open
- Ledger:OnGuildBankData queries the tabs when it arms
- Ledger:OnGuildBankData never steals the context from an open bank frame
- Ledger:OnGuildBankData re-arms without churning the baseline once armed
- Ledger: a guild-bank deposit is recorded with no open event at all
- Ledger: the guild bank disarms once its window has gone
- Ledger: hiding the guild-bank frame disarms it there and then, with no event
- Ledger: the guild-bank OnHide hook is installed once, not once per data event
- Ledger:Diagnose reports whether the guild-bank close hook is installed
- Ledger: hiding the guild-bank frame leaves an open BANK frame alone
- Ledger: an unknown window state does NOT disarm the guild bank
- Compat.IsGuildBankVisible is three-valued
- Ledger:ScanStore hands back the first hyperlink seen for each item
- Ledger:Snapshot carries a links table beside the counts
- Ledger.Diff attaches the observed link to a deposit
- Ledger.Diff attaches the observed link to a withdrawal
- Ledger.Diff leaves the link nil when neither snapshot observed one
- Ledger:BuildEntry keeps the scanned link over the one derived from the id
- Ledger:BuildEntry falls back to the item cache's link when the move carries none
- Ledger:BuildEntry takes the quality from the moved link, not the base item
- Ledger:BuildEntry still enriches from the id when the move carries no link
- Ledger:GateReason judges the quality gate on the moved link

### test_database.lua (43)

- Database:Add appends and returns the new index
- Database:Add fires EntryAdded on the bus
- Database: two consumers of one message both receive it
- Database:QueryList with no filter returns everything
- Database:QueryList filters on a scalar store
- Database:QueryList filters on a store SET (multi-select)
- Database:QueryList filters on direction
- Database:QueryList filters on kind
- Database:QueryList filters on character
- Database:QueryList filters on item sub-type
- Database:QueryList filters on an item sub-type SET (multi-select)
- Database:QueryList filters gold movements under the type 'Gold'
- Database:QueryList mixes Gold with real item types in one set
- Database:QueryList filters on an exact quality
- Database:QueryList filters on a quality SET
- Database:QueryList filters on a from/to timestamp window, inclusive
- Database:QueryList text search is a case-insensitive substring on the item name
- Database:QueryList combines filters with AND
- Database:QueryList returns nothing when the filters exclude everything
- Database:Export returns plain copies, not the stored tables
- Database:DeleteAt removes one entry and compacts the array
- Database:DeleteAt rejects an out-of-range index
- Database:Delete removes every entry matching the predicate
- Database:Purge empties the ledger and reports the count
- Database:PruneOld drops entries past the retention window
- Database:PruneOld keeps everything when retention is Always (0)
- Database:PruneOld broadcasts LedgerChanged only when a row actually went
- Database:StorageStats reports count, span and an estimated size
- Database:StorageStats reports a zero span for an empty ledger
- Database:ActiveLedger prefers the test dataset when one is published
- RunMigrations stamps a schema version onto a fresh database
- RunMigrations is idempotent — running it twice changes nothing
- NS.MigrationSummary renders a readable one-liner
- NS.InitSummary identifies the build, schema, profile and size
- RunMigrations strips vendorPrice from every stored entry and bumps to v2
- RunMigrations is idempotent on an already-migrated database
- RunMigrations treats a database with no schemaVersion key at all as v1
- RunMigrations survives a database with no ledger at all
- RunMigrations never downgrades a future schema version
- Database:Export never emits a vendorPrice field
- Database: the shipped default matches the migration runner's target
- Database: a fresh database needs no migration
- Database: an older database is migrated up to the current version

### test_stats.lua (52)

- Stats: the entry total counts every movement in scope
- Stats: item quantities split by direction
- Stats: gold in, gold out and the net between them
- Stats: distinct items counts item ids, not movements
- Stats: distinct characters counts the players involved
- Stats: the first and last timestamps bracket the data
- Stats: active days counts distinct calendar days
- Stats: byStore counts movements per store
- Stats: byDirection counts deposits and withdrawals
- Stats: byKind separates item movements from gold movements
- Stats: byChar carries a per-character count
- Stats: charByStore is a per-character by-store matrix
- Stats: byItemType counts item movements only
- Stats: topItems ranks by number of moves, most first
- Stats: the busiest day is the one with the most movements
- Stats: a filter narrows every total, not just the count
- Stats: an empty result set produces zeroed totals rather than nil
- Stats: byItemSubType counts item rows by sub-type
- Stats: byQuality counts item rows by quality id
- Stats: byQuality ignores gold, which has no quality
- Stats: byZone counts movements by where they happened
- Stats: topZones ranks the banking spots, count-desc
- Stats: byHour and byWeekday bucket every movement exactly once
- Stats: byWeekday is keyed 0..6 with Sunday as 0
- Stats: moneyByStore totals gross coin per store
- Stats: moneyByDay totals coin per calendar day, items excluded
- Stats: totals.moneyMoved is gross coin, not net
- Stats: totals.netItems signs the item flow like netMoney signs gold
- Stats: charByDirection splits each character's movements in and out
- Stats: storeByDirection splits each store's movements in and out
- Stats: topItemsByQuantity ranks the item index by stack count
- Stats: the two top-item rankings share one record per item
- Stats: topItems still ranks by movement count, unchanged
- Stats: every new breakdown is empty rather than nil on an empty ledger
- Stats: the new breakdowns honor the filter like every other key
- Stats no longer reports any value figure
- Stats: netByStore counts movements, deposits positive
- Stats: itemsMoved totals every stack unit that crossed the line
- Stats: topStore names the store with the most movements
- Stats: topStore is nil on an empty slice
- Stats: qualityByDirection is keyed on the numeric quality id
- Stats: itemTypeByDirection and itemSubTypeByDirection split by direction
- Stats: the direction split always sums back to its parent breakdown
- Stats: item records split their moves and quantities by direction
- Stats: the In and Out item rankings sum back to the combined ranking
- Stats: byZone keeps its plain count-map shape for the CSV
- Stats: topZones records carry the in/out split
- Stats: topTypeSub ranks type and sub-type pairs with a display label
- Stats: topItemsByStore ranks each store's items independently
- Stats: per-store item records split moves by direction
- Stats: the per-store In and Out lists rank independently
- Stats: a store with no withdrawals has an empty per-store Out list

### test_ledgertable.lua (51)

- LedgerTable:CellText renders the direction as a human label
- LedgerTable:Column exposes the spec behind a key, and nil for an unknown one
- LedgerTable:PaintCell writes the column's text into the cell
- LedgerTable:PaintCell drives the direction glyph only for the Direction column
- LedgerTable:PaintCell is a safe no-op for a missing cell or column
- LedgerTable:CellText renders the store as a human label
- LedgerTable:CellText falls back to 'Item <id>' for an uncached item
- LedgerTable:CellText shows a gold row's amount as money in the Qty column
- LedgerTable:CellText shows the stack size for an item row
- LedgerTable:CellText renders the quality label, and blank when unknown
- LedgerTable:CellText shows a dash for a gold row's quality
- LedgerTable:CellText renders the item type and sub-type, and blank when unknown
- LedgerTable:CellText types a gold row as Gold on both type columns
- LedgerTable:CellText returns empty for an unknown column key
- LedgerTable:SortEntries orders by the active column
- LedgerTable:SortEntries honors the ascending direction
- LedgerTable:SortEntries is stable across equal keys
- LedgerTable:SortEntries never mutates the array it is given
- LedgerTable:SortEntries sorts the Qty column on what the cell shows
- LedgerTable:GroupEntries with no grouping emits one row item each
- LedgerTable:GroupEntries inserts a header per group, with a count
- LedgerTable:GroupEntries labels a header with its column prefix and value
- LedgerTable:GroupEntries emits only the header for a collapsed group
- LedgerTable:GroupEntries namespaces group keys by mode, so they cannot collide
- LedgerTable:GroupEntries groups gold and items apart under 'kind'
- LedgerTable:GroupEntries groups by item type and sub-type
- LedgerTable:GroupEntries gathers gold under Gold when grouping by type
- LedgerTable:GroupEntries labels an untyped item group Unknown
- LedgerTable:GroupEntries orders quality groups Poor to Legendary
- LedgerTable:GroupEntries puts gold in its own quality group
- LedgerTable:GroupEntries emits the exact key and label for every group mode
- LedgerTable:GroupEntries defaults a missing group value rather than dropping the entry
- LedgerTable:BuildTestData produces a non-trivial sample ledger
- LedgerTable:BuildTestData is deterministic across runs
- LedgerTable:BuildTestData covers every store
- LedgerTable:BuildTestData covers both directions and both kinds
- LedgerTable:BuildTestData only puts gold where gold can live
- LedgerTable:BuildTestData stamps the guild name only on guild-bank rows
- LedgerTable.RenderSummary is one line carrying the render's shape
- LedgerTable:MinFrameWidth is wide enough for every column
- BuildTestData is byte-identical across two builds
- BuildTestData covers every store and both directions
- BuildTestData covers every item quality 0-5
- BuildTestData spans more than 14 days
- BuildTestData spreads across many characters and zones
- BuildTestData never carries vendor value
- LedgerTable:ToggleTestMode publishes and clears the dataset
- LedgerTable:IsTestMode is derived from the published dataset, not a second flag
- LedgerTable row menu offers the mutating actions on a real row
- LedgerTable row menu disables every mutating action in test mode
- LedgerTable row menu still disables item actions on a money row

### test_browser.lua (38)

- Browser.ResolveCharFilter resolves the Current sentinel to the logged-in character
- Browser.ResolveCharFilter passes ordinary character keys through
- Browser.ResolveCharFilter mixes the sentinel with explicit names
- Browser.ResolveCharFilter collapses the sentinel onto the same name once
- Browser.ResolveCharFilter returns nil for an empty selection (no filter)
- Browser.ResolveCharFilter falls back to the live player key
- Browser.ResolveCharFilter copies the set rather than aliasing it
- Browser:ClearFilters defaults the Character filter to the current character
- Browser:ClearFilters leaves every other filter empty
- Browser:ClearFilters does not scope test data to the real player
- Browser: with nothing saved, the baseline IS the stock view
- Browser: a corrupt saved view degrades to stock rather than erroring
- Browser:SaveView then ClearFilters returns to the SAVED view, not stock
- Browser:ResetView drops the saved view, and Clear then lands on stock
- Browser:CaptureView omits sortAsc entirely when the table module is not loaded
- Browser:CaptureView never captures the character scope
- Browser:ApplyView always scopes to the current character
- Browser:ApplyView with the 'all' scope drops the character filter entirely
- Browser:SaveView stores COPIES, so a later toggle cannot rewrite the saved view
- Browser: a saved date range is stored as the OPTION, not a resolved timestamp
- Browser:ApplyView tolerates a scalar filter value in a stored view
- Slash:CliResetAll also discards the saved view
- Browser:MinWidth fits every table column and the whole toolbar
- Browser:SaveGeometry writes the live position and size
- Browser:ApplyGeometry restores a saved position and size
- Browser:ApplyGeometry never restores a size below the window floor
- Browser:SaveGeometry refuses to write a point-less table
- the ledger window saves its geometry when it hides
- the ledger window closes an open dropdown menu when it hides
- the ledger window saves its geometry at logout
- Browser:ExportWidth leaves the Export button a usable width
- Browser: a burst of search keystrokes costs ONE filter application
- Browser: the debounced filter still applies when there is no timer library
- Browser: a 20-stack deposit repaints the window once, not twenty times
- Browser hands the table a filter COPY, not its own mutable one
- Browser: MakeDropdown injects this addon's chevron, tick and mono face
- Browser: MakeDropdown still hands back a working dropdown with no LibKa0s art
- Browser: the window still opens and the ledger table still populates with no Widgets library

### test_sessionwindow.lua (32)

- SessionWindow drops the Date, Time and Character columns
- SessionWindow keeps the seven data columns, in table order
- SessionWindow resolves every column key against the shared LedgerTable spec
- SessionWindow:MinFrameWidth covers every column plus the gutter and margins
- SessionWindow:ColumnLayout lays columns left to right with the Item column flexing
- SessionWindow:StartSession arms the session and clears the previous visit
- SessionWindow:EndSession disarms and drops the rows
- SessionWindow collects movements only while a session is open
- SessionWindow shows newest movement first
- SessionWindow:DisplayList never reorders the session list in place
- SessionChanged from the Ledger opens and closes a session
- Ledger:OpenContext and CloseContext drive the session window
- closing the guild bank closes the session window
- a recorded movement reaches the session window through EntryAdded
- the disable setting suppresses the window without suppressing collection
- the window stays shut while capture itself is off
- settings.showSessionWindow defaults to enabled
- turning the setting off closes an open session window
- SessionWindow:PruneMissing drops rows deleted from the ledger
- a purge empties the session view
- SessionWindow:TogglePreview shows placeholder rows through the real render path
- SessionWindow:TogglePreview refuses to overwrite a real session
- a preview session is never pruned against the live ledger
- a real session replaces a preview session's rows
- SessionWindow:SaveGeometry writes the live position and size
- SessionWindow:ApplyGeometry restores a saved position and size
- SessionWindow:ApplyGeometry never restores a size below the column minimum
- the session window saves its geometry when it hides
- the session window saves its geometry at logout
- a full save/reload round trip lands the window back where it was
- SessionWindow:ResetWindow clears the persisted geometry carve-out
- the session window's geometry is a separate carve-out from the main window's

### test_insights.lua (76)

- InsightsWidgets.PaletteColor returns an rgb triple for rank 1
- InsightsWidgets.PaletteColor gives adjacent ranks different colors
- InsightsWidgets.PaletteColor cycles past the end of the palette
- InsightsWidgets.PaletteMap assigns colors by list position
- InsightsWidgets.PaletteMap of an empty list is empty
- InsightsWidgets.Truncate leaves a short label alone
- InsightsWidgets.Truncate cuts a long label to an ellipsis at the limit
- InsightsWidgets.Truncate handles nil as an empty label
- InsightsWidgets.ShortChar drops the realm from a Name-Realm key
- InsightsWidgets.FitFontSize keeps the base size when the string fits
- InsightsWidgets.FitFontSize shrinks proportionally when it overflows
- InsightsWidgets.FitFontSize never shrinks below the floor
- InsightsWidgets.FitFontSize treats a missing measurement as fitting
- InsightsWidgets.SignedMoney colors a gain green and a loss red
- InsightsWidgets.SignedMoney renders zero as a neutral dash
- InsightsWidgets.SignedCount signs a count the same way
- InsightsWidgets.Money renders nothing as a plain zero, not an empty cell
- InsightsWidgets.PeakShares fills the larger side and scales the smaller against it
- InsightsWidgets.PeakShares fills the larger side whichever side it is on
- InsightsWidgets.PeakShares gives an empty split two zero-width halves
- InsightsWidgets.PeakShares treats a negative side as zero
- InsightsWidgets.Percent rounds to a whole percentage
- InsightsWidgets.Percent is zero for an empty total, never a divide by zero
- InsightsWidgets.StripMetrics widens the bars when there are few buckets
- InsightsWidgets.StripMetrics keeps a minimum bar width when buckets are dense
- InsightsWidgets.StripMetrics thins the axis labels as the bars tighten
- InsightsWidgets.StripMetrics survives zero buckets
- InsightsWidgets.DayKeys covers every day inclusive of both ends
- InsightsWidgets.DayKeys includes the quiet days in between
- InsightsWidgets.DayKeys caps a long span to the most recent bars
- InsightsWidgets.DayKeys is empty without both ends, or when they are inverted
- InsightsWidgets.ShortDay compacts an ISO day key for the axis
- InsightsWidgets.SortedByCount ranks count-desc then key-asc
- InsightsWidgets.NormalizeFractions makes the largest bar fill its track
- InsightsWidgets.NormalizeFractions leaves an all-zero list alone
- InsightsWidgets.StackSegments orders segments by their global rank
- InsightsWidgets.StackSegments returns the row's total
- InsightsWidgets.StackSegments lumps the overflow into one Other segment, last
- InsightsWidgets.StackSegments drops zero and negative magnitudes
- InsightsWidgets.BuildStackRows scales every row against the biggest row
- InsightsWidgets.BuildStackRows breaks total ties on the label
- InsightsWidgets.BuildBackToBackRows scales both sides against one shared maximum
- InsightsWidgets.BuildBackToBackRows reports each side's raw magnitude and the total
- InsightsWidgets.BuildBackToBackRows gives a one-sided row a zero-width other half
- InsightsWidgets.BuildBackToBackRows breaks total ties on the label
- InsightsWidgets.BuildBackToBackRows survives an all-zero matrix
- InsightsWidgets.BuildBackToBackRows of an empty matrix is empty
- InsightsWidgets.BuildStackRows tips each segment with its category and value
- InsightsWidgets.BuildStackRows of an empty matrix is empty
- InsightsWidgets.BuildStackRows falls back to tostring and the neutral color
- InsightsWidgets pools reuse a released widget instead of building another
- Insights.CardValues renders every declared card
- Insights.CardValues shows a dash where there is genuinely nothing
- Insights.CardValues survives being handed nothing at all
- Insights.CardValues covers every card the panel declares
- Insights.CardValues no longer produces value or biggest-move cards
- Insights.CardValues reports items moved and the top store
- Insights.CardValues em-dashes the top store on an empty slice
- Insights.SummaryLine names the scope and the count
- Insights:Attach and Refresh survive an empty ledger
- Insights:Refresh lays out every section against a populated ledger
- Insights:Refresh renders a slice with no gold at all
- Insights: a negative moneyMoved hides the GOLD section rather than drawing it
- Insights: the four direction-split companions render without raising
- Insights.BarLabel truncates the name and leaves the icon escape intact
- Insights.BarLabel is a plain truncation when there is no icon
- Insights: character bars carry the icon out of band
- InsightsWidgets exports the split bar's two-part height
- InsightsWidgets pools list panels, each carrying its own row pool
- InsightsWidgets.MakeCard builds every headline on one base font template
- Insights: the reorganized list section renders every group
- Insights.ElementTip pairs the full label with the figure the element shows
- Insights.ElementTip falls back to the bare label when there is no value
- Insights: a bar's tip carries its untruncated label AND its value
- Insights: the headline split puts withdrawals left, deposits right, peak-scaled
- Insights: a back-to-back half's tip carries its count and its share of the row

### test_export.lua (34)

- Export:CSV emits a header row even with no data
- Export:CSV emits one row per entry
- Export:CSV uses CRLF line endings (RFC 4180)
- Export:CSV writes the human direction and store labels
- Export:CSV keeps the raw store token beside its label
- Export:CSV pairs each human column with its raw sibling
- Export:CSV renders a gold row's kind label
- Export:CSV quotes a field containing a comma and doubles embedded quotes
- Export:CSV leaves an absent field empty rather than writing nil
- Export:CSV never emits the item link (a raw link is unusable in a spreadsheet)
- Export:InsightsCSV starts with the four-column header
- Export:InsightsCSV carries the summary card values
- Export:InsightsCSV includes a per-store breakdown
- Export:InsightsCSV includes the signed net-by-store rows
- Export:InsightsCSV includes the direction and kind breakdowns
- Export:InsightsCSV includes the top-items ranking
- Export:InsightsCSV carries the two new summary figures
- Export:InsightsCSV includes the sub-type breakdown
- Export:InsightsCSV includes the quality breakdown, in quality order
- Export:InsightsCSV includes the zone breakdown
- Export:InsightsCSV includes the gross coin per store
- Export:InsightsCSV includes the extra top-item ranking
- Export:InsightsCSV includes a per-day coin section
- Export:InsightsCSV emits a full 24-hour and 7-day grid
- Export:InsightsCSV keeps the original section headers unchanged
- Export:InsightsCSV survives an empty stats result
- Export:InsightsCSV survives being handed nothing at all
- Export: the ledger CSV carries no value columns
- Export: the insights CSV drops the value summary and the value ranking
- Export: net by store is written as a count, not a coin string
- Export:CSV ends with the wowhead column
- Export:CSV writes a wowhead URL carrying the item's bonus ids
- Export:CSV writes a bare item URL when the row has no link
- Export:CSV leaves the wowhead cell empty for a gold row

### test_debuglog.lua (18)

- DebugLog.FormatPlain renders '<ts> | [<tag>] <msg>' with no color codes
- DebugLog.FormatPlain tolerates a missing tag
- DebugLog.FormatColored uses the mandated timestamp and tag colors
- DebugLog.FormatColored escapes the separator pipe so it renders literally
- DebugLog: the plain and colored lines carry the same tag and message
- NS.Debug writes nothing while logging is off
- NS.Debug appends a line while logging is on
- NS.Debug formats its arguments into the message
- NS.Debug never raises on a value table.concat would reject
- DebugLog:Clear empties the copy buffer
- DebugLog:SetEnabled flips the session-only flag
- DebugLog:SetEnabled acks in chat with a color-coded state word
- DebugLog:SetEnabled brackets BOTH transitions in the console
- DebugLog:SetEnabled emits an [Init] session summary on enable
- DebugLog:SetEnabled emits no [Init] summary on disable
- DebugLog: the enabled state is never written to SavedVariables
- DebugLog: the header toggle flips the same flag as the slash verb
- DebugLog:UpdateScrollBar is a clean no-op under a stub frame

### test_schema.lua (26)

- Schema: every row's path resolves against the defaults table
- Schema: every row declares a label, a widget and a group
- Schema: changing the window scale broadcasts it so every window rescales
- Schema: every row declares a default
- Schema: dropdown rows carry their option list
- Schema:FindRow finds a declared path and rejects an unknown one
- Schema:Get reads the stored value
- Schema:Set writes through the single seam and reads back
- Schema:Set rejects an unknown path with a reason
- Schema:Set writes a nested path, creating intermediate tables
- Schema:Set fires the row's onChange
- Schema:Set deep-copies a table value so the default can't be aliased
- Schema:Default returns a fresh copy each time
- Schema: a session-only row never touches SavedVariables
- Schema: the session-only row reads through its own getter
- Schema: the debug LOGGING flag is deliberately not a schema row
- COMMANDS: every entry is a { name, description, handler } triple
- COMMANDS: names are unique, so dispatch can never be ambiguous
- COMMANDS: the standard's required verbs are all present
- COMMANDS: a test verb exists (test-mode)
- Schema: the four Master Controls switches pair into two full rows
- Schema: every row carries a tooltip
- Schema: settings.windowScale declares its own step
- Schema: a row the library cannot draw is marked skipRender, not left to vanish
- Schema: no row uses the pre-library field spellings
- Schema: a numeric row carrying values is an enum the panel must draw as a dropdown

### test_slash.lua (33)

- Slash: a set renders as a sorted brace list, through the format hook
- Slash: an empty set renders as (none), not as an empty brace pair
- Slash: a number row keeps its declared fmt
- Slash: a boolean row still reads true/false
- Slash: the key = value line carries no trailing colon (house style)
- Slash:BuildListLines opens with the green 'Available settings' header
- Slash:BuildListLines has no trailing colon on any line
- Slash:BuildListLines indents group headers by two and rows by four
- Slash:BuildListLines emits one row for every schema row
- Slash:BuildListLines groups the rows under their declared page order
- Slash:CliGet prints the single-line path = value form
- Slash:CliGet reports an unknown path rather than printing nil
- Slash:CliGet prints a usage line when given nothing
- Slash:CliSet writes a boolean from a human word
- Slash:CliSet writes a number and echoes the STORED value back
- Slash:CliSet rejects a non-numeric value for a number setting
- Slash:CliSet reports an unknown path
- Slash:CliSet refuses a value-less set and says why
- Slash:CliReset restores one setting to its default
- Slash:CliReset echoes a table default through the shared formatter
- Slash:CliReset echoes the colored key = value shape, like get and set
- Slash:CliReset echoes the stored value, not the requested one
- Slash:CliResetAll restores the schema AND clears the filter lists
- Slash: a bare /bl prints the help index
- Slash: the help index has one row per COMMANDS entry, plus the header
- Slash: the help header names both the short verb and its alias
- Slash: help rows are gold command, em-dash, white description, indented
- Slash: an unknown verb says so and then prints the help index
- Slash: dispatch lower-cases only the verb, preserving the argument's case
- Slash:CliVersion prints a single tagged version line
- Slash: every chat line carries the cyan [BL] tag
- Slash: /bl list groups in schema declaration order, matching the panel
- Slash: /bl version and the help header report the same version

### test_panel.lua (26)

- Panel: every registered canvas frame is handed to the Settings framework
- Panel: each canvas frame defines OnCommit, OnDefault and OnRefresh
- Panel: the landing page's OnDefault is inert — it manages no settings
- Panel: OnDefault runs the same action as the header Defaults button
- Panel: the General defaults action resets settings but never the ledger
- Panel: OnCommit and OnRefresh are inert — writes land immediately and OnShow refreshes
- Panel: a schema write refreshes an open page
- Panel: a schema write does NOT refresh a hidden page
- Panel: Refresh walks EVERY registered page, not just General
- Panel: a bulk reset coalesces into exactly ONE refresh
- Panel: Batch unwinds its depth on the error path
- Panel: /bl resetall repaints, and only once
- Panel: a refresher that raises does not stop the others
- Panel: the General page renders without the library reporting a failure
- Panel: every renderable schema row reaches the page as a labeled widget
- Panel: a boolean row is a CheckBox and a range row is a Slider
- Panel: a numeric ENUM row is a Dropdown, not a slider over its indices
- Panel: a checkbox write goes through the single write seam
- Panel: the Reset all button is paired into the Window scale row
- Panel: the store grid renders as an inverted checkbox set, host-drawn
- Panel: the Storage section renders under the schema rows
- Panel: the Filters page renders its two id lists
- Panel: re-rendering a page releases the previous widgets and their refreshers
- Panel:Diagnose says so and stops when no defaults button was ever built
- Panel:Diagnose stops at a button with no frame
- Panel:Diagnose dumps the frame, its parent chain and every scrap of its art

### test_harness.lua (7)

- Harness: every suite the runner lists exists on disk
- Harness: every suite on disk is listed in the runner
- Harness: the runner's suite list has no duplicates
- Harness: the TOC is what the headless runner loads, and it is non-empty
- Harness: Compat loads before everything else in core/
- Harness: Filters loads before Ledger — the capture gate reads the lists
- Harness: the settings files load last, and in order

### test_mock.lua (26)

- Mock frame: a stub starts SHOWN, as a real frame does
- Mock frame: Show, Hide and SetShown flip the one piece of state the stub models
- Mock frame: Show and Hide return the frame, so calls chain
- Mock frame: OnHide fires only on a real shown->hidden transition
- Mock frame: OnHide handlers are called with the frame, in hook order
- Mock frame: SetScript RECORDS the handler and GetScript hands it back
- Mock frame: __fire replays a recorded script with the frame and the extra args
- Mock frame: __fire on a script nobody set is a silent no-op
- Mock frame: HookScript chains the PREVIOUS handler before the new one
- Mock frame: HookScript on a bare frame still installs a callable script
- Mock frame: SetPoint records the (point, x, y) form
- Mock frame: SetPoint records the (point, relativeTo, relativePoint, x, y) form
- Mock frame: a bare SetPoint defaults its offsets to zero
- Mock frame: points accumulate, ClearAllPoints drops them, GetPoint misses to nil
- Mock frame: size is real state through SetSize, SetWidth and SetHeight
- Mock frame: CreateFontString answers with its OWN object, not the frame
- Mock frame: sizing a FontString does not resize its parent
- Mock frame: CreateFontString still records the templates it was asked for, in order
- Mock frame: a FontString with NO font raises on SetText, exactly as the client does
- Mock frame: a FontString built FROM A TEMPLATE has a font and accepts SetText
- Mock frame: SetFont is what rescues a bare FontString, and it is recorded
- Mock frame: the FONT rule is a FontString rule, not a frame rule
- Mock frame: a FontString measures its text rather than answering with a frame
- Mock frame: any other PascalCase key is a chainable no-op
- Mock frame: a named method always beats the catch-all
- Mock frame: lowercase and non-string keys miss through to nil

### test_mediasetup.lua (13)

- LibKa0s-Media: the vendored major registered and the seam is published
- LibKa0s-Media: NS.Icon answers the vendored path, EXTENSIONLESS
- LibKa0s-Media: an icon the library does not ship answers nil
- LibKa0s-Media: NS.MediaFont answers the vendored face, and an unknown face answers nil
- LibKa0s-Media: C.FONT_MONO resolves through the seam, not to a literal under media/fonts/
- LibKa0s-Media: the addon's own media/fonts/ is gone from disk
- LibKa0s-Media: the font name this addon stores is a key of the library's FONTS
- LibKa0s-Media: this addon no longer registers the face with LibSharedMedia itself
- LibKa0s-Media: every name the library ships has a file in the vendored copy
- LibKa0s-Media: every icon name this addon asks for is one the library ships
- LibKa0s-Media: the seam loads BEFORE core/Constants.lua, which resolves the font from it
- LibKa0s-Media degraded: with no library there is no art, and that is not an error
- LibKa0s-Media degraded: FONT_MONO falls back to a REAL CLIENT FONT, never nil and never a path

### test_marks.lua (22)

- marks: the close control on every window this addon draws is the collection's close
- marks: the close path is EXTENSIONLESS, which is the half that fails silently
- marks degraded: with no library the close button is still the × it always was
- marks: the × is DRAWN in exactly one place, so one edit reached all four title bars
- marks: every filter dropdown wears chevron-down, through the shared factory
- marks degraded: MakeDropdown answers nil rather than a half-built widget, with no library
- marks: a chosen row of a multi-select menu wears the collection's tick
- marks: the column-header sort arrow is the collection's, at the site that draws it
- marks: every inline header mark is TINTED to the gold of the word it sits beside
- marks: the group header's expander is a chevron, at the site that draws it
- marks degraded: every inline mark falls back to the exact art it used to be
- marks: the filter bar is WORDS ONLY — its Export button carries no mark
- marks: the export modal's action button carries its mark BESIDE the words
- marks: BESIDE means beside — the modal's button keeps the width its mark was sized for
- marks: both button factories still draw the label unconditionally
- marks: the search box wears a magnifier, and its words step aside for it
- marks degraded: with no magnifier the search box's inset does not move
- marks: every name this addon draws is spelled in NS.ICON_NAMES
- marks: every icon name reaches NS.Icon as a LITERAL, where the scan above can read it
- marks: no mark carries a tooltip of its own
- marks: nothing under settings/ resolves a mark — that panel is the Options library's
- marks: the art that is NOT a mark was left alone

### test_libka0s.lua (64)

- LibKa0s-Core: the vendored major registered and the addon is running on it
- LibKa0s-Core: this addon does NOT republish the library's close factory
- LibKa0s-Media: the folder name the seam passes is the FIRST VARARG, not a hand-typed literal
- LibKa0s-Core: the sentinel is the library's, not a hand-copied literal
- LibKa0s-Core: the seam publishes ONE object to NS.Print and NS.Util.print
- LibKa0s-Core: the reclaim in core/BankLedger.lua survives the AceConsole embed
- LibKa0s-Core: a printed line is byte-identical to the pre-library printer
- LibKa0s-Core: a bare NS.Print() emits the tag and its separator
- LibKa0s-Core: the degraded fallback renders the SAME bytes as the library on every input
- LibKa0s-Core: an unconcatenable argument renders as the sentinel, never raising
- LibKa0s-Core: nil and booleans are not masked by the secret guard
- LibKa0s-Core: the prefix is re-read on every call, so a later change lands
- LibKa0s-Core degraded: the addon loads with no library at all
- LibKa0s-Core degraded: the fallback carries the whole live seam surface
- LibKa0s-Core degraded: the fallback printer renders the same bytes
- LibKa0s-Core degraded: the notice is said exactly ONCE, on the first line printed
- LibKa0s: the shared cause clause is set on BOTH paths, word for word
- LibKa0s-Core tripwire: Core ships no STRINGS and reads no descriptor L
- LibKa0s-Options tripwire: Options reads no descriptor L
- LibKa0s: no seam file hands a descriptor the addon-wide locale table
- LibKa0s: the locale-descriptor matcher catches all three spellings
- LibKa0s-Widgets: the vendored major registered
- LibKa0s: the harness loads every file LibKa0s.xml declares, in XML order
- LibKa0s: the vendored folder carries the license it ships under
- LibKa0s-Core: the seam loads after core/Namespace.lua, which defines NS.PREFIX
- LibKa0s-Core: the seam loads before the AceConsole reclaim in core/BankLedger.lua
- LibKa0s-Core: the seam loads before every file that captures NS.Print at load
- LibKa0s-DebugLog: the vendored major registered and the console is running on it
- LibKa0s-DebugLog: the module needs the minor that carries the chrome hooks
- LibKa0s-DebugLog: NS.Debug is bound and still gates on the session-only flag
- LibKa0s-DebugLog: the enable seam reads and writes NS.State.debug, never SavedVariables
- LibKa0s-DebugLog: the window title composes to exactly what the old console rendered
- LibKa0s-DebugLog: the console wears THIS addon's chrome, not Core's
- LibKa0s-DebugLog: the console's title bar is the library's, at the pitch the ART gives it
- LibKa0s-DebugLog: every user-visible string resolves to prose, not to its own key
- LibKa0s-DebugLog degraded: the console degrades to an honest stub, not an error
- LibKa0s-DebugLog degraded: the stub carries the live surface the addon reaches
- LibKa0s-DebugLog degraded: the consequence is appended to the SHARED cause clause
- LibKa0s-DebugLog degraded: the session flag still flips, because it gates more than the window
- LibKa0s-DebugLog: the library is told the FOLDER name, not just the frame name
- LibKa0s-DebugLog: the seam loads after Constants (FONT_MONO) and after the Core seam
- LibKa0s-DebugLog: modules/DebugLog.lua is gone from the TOC and from disk
- LibKa0s-DebugLog: the chat acknowledgment still carries the [BL] tag
- LibKa0s-DebugLog: hiding the console repaints the settings panel
- LibKa0s-Slash: the vendored major registered and the CLI is running on it
- LibKa0s-Slash: the module needs the minor that carries the format hook
- LibKa0s-Slash: every printed line still carries the [BL] tag
- LibKa0s-Slash: /bl list keeps its section headings
- LibKa0s-Slash: a set-typed row renders as a set, never as the secret sentinel
- LibKa0s-Slash: the format hook defers to the library for every OTHER row type
- LibKa0s-Slash: booleans are settable, because the schema says 'bool'
- LibKa0s-Slash: a numeric dropdown now REFUSES a value outside its list
- LibKa0s-Slash: a slider value out of range CLAMPS rather than storing what was typed
- LibKa0s-Slash: a set-typed row refuses a chat edit, and says where it CAN be edited
- LibKa0s-Slash: CliResetAll keeps this addon's two carve-outs
- LibKa0s-Slash: the landing page and the chat help render the SAME rows
- LibKa0s-Slash: reset takes a PATH and resetall takes none — already converged
- LibKa0s-Slash: every user-visible string resolves to prose, not to its own key
- LibKa0s-Slash degraded: the verbs that never needed the library still work
- LibKa0s-Slash degraded: the stub carries the whole live surface
- LibKa0s-Slash degraded: the CLI explains itself through the SHARED cause clause
- LibKa0s-Slash degraded: resetall still WORKS rather than merely explaining itself
- LibKa0s-Slash: the seam loads after the schema it reads
- LibKa0s-Options degraded: the stub carries the live surface the addon reaches

### test_vendor_sync.lua (2)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release

## Totals

| Suite | Cases |
|-------|------:|
| test_util.lua | 31 |
| test_compat.lua | 21 |
| test_constants.lua | 21 |
| test_filters.lua | 15 |
| test_ledger.lua | 116 |
| test_database.lua | 43 |
| test_stats.lua | 52 |
| test_ledgertable.lua | 51 |
| test_browser.lua | 38 |
| test_sessionwindow.lua | 32 |
| test_insights.lua | 76 |
| test_export.lua | 34 |
| test_debuglog.lua | 18 |
| test_schema.lua | 26 |
| test_slash.lua | 33 |
| test_panel.lua | 26 |
| test_harness.lua | 7 |
| test_mock.lua | 26 |
| test_mediasetup.lua | 13 |
| test_marks.lua | 22 |
| test_libka0s.lua | 64 |
| test_vendor_sync.lua | 2 |
| **Total** | **767** |
