# Test Cases

The full inventory of every headless test case, grouped by suite. This file is the
**authoritative pass count** for the addon.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`
whenever the suite changes (see [testing.md](testing.md)).

### test_util.lua (30)

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
- Util.ClassIconMarkup honours a requested size
- Util.ClassIconMarkup is empty for an unknown or missing class
- Util.FormatBytes steps through B, kB and MB
- Util.RangeFrom returns nil for the no-bound 'all' range
- Util.RangeFrom windows are ordered today > 7d > 30d
- Util.EntryValue is the amount itself for a gold movement
- Util.EntryValue is vendor price times stack for an item movement
- Util.EntryValue is zero for an unpriced item
- Util.EntryValue is zero for nothing at all
- Util.SignedValue makes a deposit positive and a withdrawal negative
- NS.IsConcatSafe accepts an ordinary value
- NS.IsConcatSafe rejects a value table.concat would refuse
- NS.SafeToString substitutes a sentinel for an unconcatenable value
- NS.SafeToString passes nil and booleans through unmasked
- NS.Print prefixes the cyan [BL] tag and space-joins its arguments
- NS.Print never raises on a value that would break table.concat
- NS.Print survives the AceConsole embed (architecture-§2)

### test_compat.lua (16)

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
- Compat.GetPlayerMapID returns the current map id
- Compat.GetAddOnMetadata degrades to nil when neither getter exists

### test_constants.lua (19)

- Constants: every Store enum member appears in the display order
- Constants: every Store enum member has a display label
- Constants: every Store enum value equals its key (the stable stored form)
- Constants: every Direction enum member has a label and a sign
- Constants: a deposit signs positive and a withdrawal negative
- Constants: every Kind has a label, including the reserved CURRENCY
- Constants: the bag id group covers the backpack, four bags and the reagent bag
- Constants: the bank group is exactly the six character-bank tabs
- Constants: the warband bank spans its five account tabs
- Constants: no container id belongs to two stores
- Constants: no group lists the same id twice
- Constants: the enum's type constants are never mistaken for containers
- Constants: a store absent from this build resolves to an empty group
- Constants: the guild bank and void storage are NOT container-id scanned
- Constants: the store mute options exclude BAGS
- Constants: every quality option carries a numeric value and a label
- Constants: the retention presets offer an 'Always' (0) option
- Constants: every store has a display colour
- Constants: every direction has a colour and a glyph

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

### test_ledger.lua (89)

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
- Ledger.Diff: money leaving the player at a money-holding store is a DEPOSIT
- Ledger.Diff: money arriving at a money-holding store is a WITHDRAW
- Ledger.Diff: money is ignored at a store that holds no gold
- Ledger.Diff: an unchanged balance produces no money movement
- Ledger.Diff: the money movement sorts after the item movements
- Ledger:ScanStore sums stacks across every container id of a store
- Ledger:ScanStore returns an empty map for a store with no reachable containers
- Ledger:Snapshot captures bags, every reachable store and the money balance
- Ledger:StoresFor: the bank frame reaches the character bank and the warband tabs
- Ledger:StoresFor drops a store this build has no container for
- Ledger:StoresFor: the guild bank frame reaches only itself
- Ledger: void storage is not a store at all (retired in 12.0.7)
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
- Ledger: an unknown window state does NOT disarm the guild bank
- Compat.IsGuildBankVisible is three-valued

### test_database.lua (33)

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
- Database:StorageStats reports count, span and an estimated size
- Database:StorageStats reports a zero span for an empty ledger
- Database:ActiveLedger prefers the preview dataset when one is published
- RunMigrations stamps a schema version onto a fresh database
- RunMigrations is idempotent — running it twice changes nothing
- NS.MigrationSummary renders a readable one-liner
- NS.InitSummary identifies the build, schema, profile and size

### test_stats.lua (49)

- Stats: the entry total counts every movement in scope
- Stats: item quantities split by direction
- Stats: gold in, gold out and the net between them
- Stats: total value sums item vendor value and gold amounts alike
- Stats: distinct items counts item ids, not movements
- Stats: distinct characters counts the players involved
- Stats: the first and last timestamps bracket the data
- Stats: active days counts distinct calendar days
- Stats: byStore counts movements per store
- Stats: byDirection counts deposits and withdrawals
- Stats: byKind separates item movements from gold movements
- Stats: netByStore applies the direction sign
- Stats: valueByStore is unsigned — it totals what passed through
- Stats: byChar carries a per-character count and value
- Stats: charByStore is a per-character by-store matrix
- Stats: byItemType counts item movements only
- Stats: topItems ranks by number of moves, most first
- Stats: the biggest single movement is the largest by value
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
- Stats: topItemsByValue ranks the item index by copper value
- Stats: topItemsByQuantity ranks the item index by stack count
- Stats: the three top-item rankings share one record per item
- Stats: topItems still ranks by movement count, unchanged
- Stats: every new breakdown is empty rather than nil on an empty ledger
- Stats: the new breakdowns honour the filter like every other key
- Insights.RankRows sorts by count descending
- Insights.RankRows breaks count ties on the label, so the order is stable
- Insights.RankRows applies the label mapper and the value map
- Insights.RankRows honours the row limit
- Insights.RankRows returns an empty array for an empty map
- Insights.BarFraction scales each bar against the largest count
- Insights.BarFraction is zero for an empty list or a missing row
- Insights.FormatNet colours a gain green and a loss red
- Insights.FormatNet renders zero as a neutral dash

### test_ledgertable.lua (38)

- LedgerTable:CellText renders the direction as a human label
- LedgerTable:Column exposes the spec behind a key, and nil for an unknown one
- LedgerTable:PaintCell writes the column's text into the cell
- LedgerTable:PaintCell drives the direction glyph only for the In/Out column
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
- LedgerTable:SortEntries honours the ascending direction
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
- LedgerTable:BuildPreviewData produces a non-trivial sample ledger
- LedgerTable:BuildPreviewData is deterministic across runs
- LedgerTable:BuildPreviewData covers every store
- LedgerTable:BuildPreviewData covers both directions and both kinds
- LedgerTable:BuildPreviewData only puts gold where gold can live
- LedgerTable:BuildPreviewData stamps the guild name only on guild-bank rows
- LedgerTable.RenderSummary is one line carrying the render's shape
- LedgerTable:MinFrameWidth is wide enough for every column

### test_browser.lua (12)

- Browser.ResolveCharFilter resolves the Current sentinel to the logged-in character
- Browser.ResolveCharFilter passes ordinary character keys through
- Browser.ResolveCharFilter mixes the sentinel with explicit names
- Browser.ResolveCharFilter collapses the sentinel onto the same name once
- Browser.ResolveCharFilter returns nil for an empty selection (no filter)
- Browser.ResolveCharFilter falls back to the live player key
- Browser.ResolveCharFilter copies the set rather than aliasing it
- Browser:ClearFilters defaults the Character filter to the current character
- Browser:ClearFilters leaves every other filter empty
- Browser:ClearFilters does not scope preview data to the real player
- Browser:MinWidth fits every table column and the whole toolbar
- Browser:ExportWidth leaves the Export button a usable width

### test_sessionwindow.lua (24)

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
- a recorded movement reaches the session window through EntryAdded
- the disable setting suppresses the window without suppressing collection
- settings.showSessionWindow defaults to enabled
- turning the setting off closes an open session window
- SessionWindow:PruneMissing drops rows deleted from the ledger
- a purge empties the session view
- SessionWindow:TogglePreview shows placeholder rows through the real render path
- SessionWindow:TogglePreview refuses to overwrite a real session
- a preview session is never pruned against the live ledger
- a real session replaces a preview session's rows
- SessionWindow:ResetWindow clears the persisted geometry carve-out
- the session window's geometry is a separate carve-out from the main window's

### test_insights.lua (55)

- InsightsWidgets.PaletteColor returns an rgb triple for rank 1
- InsightsWidgets.PaletteColor gives adjacent ranks different colours
- InsightsWidgets.PaletteColor cycles past the end of the palette
- InsightsWidgets.PaletteMap assigns colours by list position
- InsightsWidgets.PaletteMap of an empty list is empty
- InsightsWidgets.Truncate leaves a short label alone
- InsightsWidgets.Truncate cuts a long label to an ellipsis at the limit
- InsightsWidgets.Truncate handles nil as an empty label
- InsightsWidgets.ShortChar drops the realm from a Name-Realm key
- InsightsWidgets.FitFontSize keeps the base size when the string fits
- InsightsWidgets.FitFontSize shrinks proportionally when it overflows
- InsightsWidgets.FitFontSize never shrinks below the floor
- InsightsWidgets.FitFontSize treats a missing measurement as fitting
- InsightsWidgets.SignedMoney colours a gain green and a loss red
- InsightsWidgets.SignedMoney renders zero as a neutral dash
- InsightsWidgets.SignedCount signs a count the same way
- InsightsWidgets.Money renders nothing as a plain zero, not an empty cell
- InsightsWidgets.DivergingFill sends a gain right and a loss left
- InsightsWidgets.DivergingFill draws nothing for zero or no scale
- InsightsWidgets.DivergingFill shares one scale across both directions
- InsightsWidgets.DivergingFill clamps a magnitude past the scale
- InsightsWidgets.RatioShares splits proportionally and sums to one
- InsightsWidgets.RatioShares reads an empty split as balanced
- InsightsWidgets.RatioShares treats a negative side as zero
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
- InsightsWidgets.BuildStackRows tips each segment with its category and value
- InsightsWidgets.BuildStackRows of an empty matrix is empty
- InsightsWidgets pools reuse a released widget instead of building another
- Insights.CardValues renders every declared card
- Insights.CardValues shows a dash where there is genuinely nothing
- Insights.CardValues survives being handed nothing at all
- Insights.CardValues covers every card the panel declares
- Insights.SummaryLine names the scope and the count
- Insights:Attach and Refresh survive an empty ledger
- Insights:Refresh lays out every section against a populated ledger
- Insights:Refresh renders a slice with no gold at all

### test_export.lua (29)

- Export:CSV emits a header row even with no data
- Export:CSV emits one row per entry
- Export:CSV uses CRLF line endings (RFC 4180)
- Export:CSV writes the human direction and store labels
- Export:CSV keeps the raw store token beside its label
- Export:CSV pairs each human column with its raw sibling
- Export:CSV writes value as plain text and raw copper side by side
- Export:CSV signs the net column by direction
- Export:CSV renders a gold row's amount as its value
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
- Export:InsightsCSV includes both extra top-item rankings
- Export:InsightsCSV includes a per-day coin section
- Export:InsightsCSV emits a full 24-hour and 7-day grid
- Export:InsightsCSV keeps the original section headers unchanged
- Export:InsightsCSV survives an empty stats result
- Export:InsightsCSV survives being handed nothing at all

### test_debuglog.lua (18)

- DebugLog.FormatPlain renders '<ts> | [<tag>] <msg>' with no colour codes
- DebugLog.FormatPlain tolerates a missing tag
- DebugLog.FormatColored uses the mandated timestamp and tag colours
- DebugLog.FormatColored escapes the separator pipe so it renders literally
- DebugLog: the plain and coloured lines carry the same tag and message
- NS.Debug writes nothing while logging is off
- NS.Debug appends a line while logging is on
- NS.Debug formats its arguments into the message
- NS.Debug never raises on a value table.concat would reject
- DebugLog:Clear empties the copy buffer
- DebugLog:SetEnabled flips the session-only flag
- DebugLog:SetEnabled acks in chat with a colour-coded state word
- DebugLog:SetEnabled brackets BOTH transitions in the console
- DebugLog:SetEnabled emits an [Init] session summary on enable
- DebugLog:SetEnabled emits no [Init] summary on disable
- DebugLog: the enabled state is never written to SavedVariables
- DebugLog: the header toggle flips the same flag as the slash verb
- DebugLog:UpdateScrollBar is a clean no-op under a stub frame

### test_schema.lua (19)

- Schema: every row's path resolves against the defaults table
- Schema: every row declares a label, a widget and a group
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
- COMMANDS: every entry has a name, a description and a function
- COMMANDS: names are unique, so dispatch can never be ambiguous
- COMMANDS: the standard's required verbs are all present
- COMMANDS: a preview verb exists (preview-mode)

### test_slash.lua (31)

- Slash.FormatSchemaValue renders booleans as true/false
- Slash.FormatSchemaValue applies a row's number format
- Slash.FormatSchemaValue renders a set as a sorted brace list
- Slash.FormatSchemaValue renders an empty set as (none)
- Slash.FormatSchemaValue renders nil as nil
- Slash.FormatKV colours the key gold and the value white
- Slash.FormatKV carries no trailing colon (house style)
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
- Slash:CliSet prints usage when the value is missing
- Slash:CliReset restores one setting to its default
- Slash:CliReset echoes a table default through the shared formatter
- Slash:CliResetAll restores the schema AND clears the filter lists
- Slash: a bare /bl prints the help index
- Slash: the help index has one row per COMMANDS entry, plus the header
- Slash: the help header names both the short verb and its alias
- Slash: help rows are gold command, em-dash, white description
- Slash: an unknown verb says so and then prints the help index
- Slash: dispatch lower-cases only the verb, preserving the argument's case
- Slash:CliVersion prints a single tagged version line
- Slash: every chat line carries the cyan [BL] tag

## Totals

| Suite | Cases |
|-------|------:|
| test_util.lua | 30 |
| test_compat.lua | 16 |
| test_constants.lua | 19 |
| test_filters.lua | 15 |
| test_ledger.lua | 89 |
| test_database.lua | 33 |
| test_stats.lua | 49 |
| test_ledgertable.lua | 38 |
| test_browser.lua | 12 |
| test_sessionwindow.lua | 24 |
| test_insights.lua | 55 |
| test_export.lua | 29 |
| test_debuglog.lua | 18 |
| test_schema.lua | 19 |
| test_slash.lua | 31 |
| **Total** | **477** |
