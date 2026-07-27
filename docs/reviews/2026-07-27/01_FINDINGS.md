# Ka0s Bank Ledger — Code Review Findings (2026-07-27)

**Verdict: minor issues.** The addon is well-structured, well-commented and ships green tests
(`531 passed, 0 failed`) and clean lint (`0 warnings / 0 errors in 22 files`). There is no taint
exposure, no deprecated-API leakage outside `core/Compat.lua`, and no protected-value handling. One
functional capture bug (phantom gold rows) and two UX defects are worth fixing before the next
release; the rest is design/perf hardening and cleanup.

**Standards cross-check: performed.** The Ka0s WoW Addon Standard was fetched successfully
(`STANDARDS.md` v2.11.0, 2026-07-26, plus all 23 section files discovered from its Sections list).
Every fix direction below has been checked against it; where a rule shaped or blocked a fix it is
cited as `filename-§N`.

**Scope note.** This is a review, not a compliance audit. Pre-existing standard deviations unrelated
to the findings below (e.g. `defaults/Global.lua` rather than `defaults/Profile.lua`,
savedvariables-§2; the English-only `NS.L` seam; README section inventory) are deliberately **not**
enumerated here — that is `wow-addon:standards-audit`'s job.

---

## Conventions detected (and therefore enforced in this review)

| Convention | Present | Notes |
|---|---|---|
| `NS.PREFIX` cyan chat tag + shared `NS.Print` | Yes | `core/Namespace.lua:10`, `core/Util.lua:151` |
| Shadowed `local print = NS.Print` per file | Yes | 5 of 6 emitting files |
| `NS.COMMANDS` dispatcher table | Yes | `settings/Schema.lua:198` |
| Single write path `NS.Schema:Set` | Yes | `settings/Schema.lua:148` |
| `settings/Schema.lua` flat-row schema with `tooltip` | Yes | one row lacks a tooltip (see F-019) |
| Protected-API safety doc (`docs/CLAUDE_SECRET_VALUES.md`) | No | not applicable |
| `.gitattributes` declaring CRLF | **No** | not applicable — no CRLF convention to enforce |

---

## High

### F-001 — A money change during any bank visit is recorded as a Warband Bank deposit `[logic]`
`modules/Ledger.lua:20` (`L.MONEY_STORES`), `modules/Ledger.lua:106-116` (`L.Diff` money block),
`modules/Ledger.lua:30-33` (`L.CONTEXT_STORES.BANK_FRAME`).

The money diff fires for **any** store in `L.MONEY_STORES` that the open frame can reach, with no
corroborating evidence that the coin actually went into that store. `BANK_FRAME` reaches
`WARBAND_BANK`, so every gold delta observed while the character-bank window is open is attributed
to the warband bank — buying a bank tab or bank slot (done *at* the bank frame), a repair, a mail
COD landing, a guild-bank tab purchase, an auction settling. Item movements are protected by the
"both sides must change" rule; money has no equivalent.

**Impact:** phantom `MONEY` rows in the persisted ledger, wrong `moneyIn`/`netMoney`/`Gold By Store`
figures, and a CSV export that misreports gold flow. The rows are indistinguishable from real ones
after the fact.

**Fix direction:** require corroboration before crediting a money movement to a store — read the
store's own deposited-money balance and diff *that*, rather than the player's purse, so an
unrelated purse change cannot pair with a store that did not move. Every such call **MUST** be added
to `core/Compat.lua` and never called raw from `modules/Ledger.lua` (compat, anti-pattern #10).
*I am not certain of the exact retail API names for the account/warband bank balance* — candidates
are `C_Bank.FetchDepositedMoney(Enum.BankType.Account)` and `GetGuildBankMoney()` — so the first
task is to confirm them in-client with `/bl debug scan` extended to dump the money API surface,
exactly as `L:Diagnose` already does for containers. If no reliable warband-balance reader exists on
12.0.7, the compliant fallback is to drop `WARBAND_BANK` from `L.MONEY_STORES` and record only
guild-bank coin (which `GUILDBANK_UPDATE_MONEY` corroborates), documenting the narrowing in
`docs/ARCHITECTURE.md` ▸ Known limitations.

### F-002 — Test-mode row actions mutate real data `[ux]` `[logic]`
`modules/LedgerTable.lua:891-916` (`LT:ShowRowMenu`), `core/Database.lua:463-486`.

`Database:Delete` / `Database:DeleteAt` always operate on `NS.db.global.ledger`, while the table
renders `Database:ActiveLedger()` — the synthetic `NS.State.testRecords` set while `/bl test` is on.
Right-clicking a test row therefore:

* **Delete** — matches nothing, removes nothing, still fires `LedgerChanged`, and the row stays on
  screen. The user reads this as a broken feature.
* **Blacklist / Whitelist item** — writes the synthetic ids (`190001`–`190030`) straight into the
  real, persisted `db.global.blacklist` / `whitelist`, silently poisoning the live capture gate with
  ids for items that do not exist.

**Impact:** a user exploring the sample dataset corrupts their real filter configuration, and gets a
delete action that visibly does nothing.

**Fix direction:** gate the mutating menu entries on `LT.testMode` (disabled, with the existing
greyed-out treatment the menu already supports) rather than teaching `Database` about the test
dataset — `Database:Delete` operating on the persisted ledger is correct and must stay that way.

### F-003 — Window scale never reaches the session window `[ux]`
`settings/Schema.lua:52-59` (`settings.windowScale` row), `modules/SessionWindow.lua:636-640`
(`SW:OnSettingsChanged`).

The `windowScale` row's `onChange` calls `NS.Browser:SetScale(v)` directly and sends **no**
`Ka0s_BankLedger_SettingsChanged` message. `SW:OnSettingsChanged` — the only thing that applies the
scale to the session window — is wired exclusively to that message, so the session window keeps its
old scale until the next `/reload` (where `ensureFrame` reads `windowScale` at build time).

**Impact:** the one setting that visibly governs "how big are the addon's windows" applies to one of
the two windows. A user drags the slider and sees a half-applied change.

**Fix direction:** broadcast `Ka0s_BankLedger_SettingsChanged` from the row's `onChange` like every
other row does, and let both windows react through their existing subscriptions. Do **not** add a
second direct cross-module call from `Schema` into `SessionWindow` — cross-module direct table
access is anti-pattern #19, and the bus already exists for exactly this
(architecture-§4).

---

## Medium

### F-004 — Every search keystroke recomputes the whole Insights aggregation `[perf]`
`modules/Browser.lua:768-773` (`search:SetScript("OnTextChanged")`) → `ApplyFilter`
(`modules/Browser.lua:630-636`) → `NS.Insights:Refresh` → `NS.Database:Stats`.

With the Insights tab on screen, typing in the item-search box runs one full `Database:Stats` pass
per character: an O(n) accumulation over the filtered ledger plus roughly twenty `table.sort` calls
(six top-item rankings, three zone, three type/sub-type, three per store). There is no debounce and
no incremental path. The History tab pays a cheaper but still per-keystroke full filter+sort.

**Impact:** a visible hitch per keypress once the ledger reaches a few thousand entries — precisely
the size at which the search box becomes useful.

**Fix direction:** debounce the filter application (the codebase already owns this pattern —
`L.DEBOUNCE_SECONDS` / `L:ScheduleReconcile` in `modules/Ledger.lua:529-541`), so a burst of
keystrokes produces one recompute.

### F-005 — A bulk deposit fans N full view refreshes `[perf]`
`core/Database.lua:71-79` (`Database:Add` sends `EntryAdded` per entry), consumers at
`modules/Browser.lua:1104-1106`, `modules/Insights.lua:892-893`, `settings/Panel.lua:415-416`.

`L:Reconcile` already batches — it records every movement of one pass in a loop — but each
`Database:Add` fires its own `EntryAdded`. Depositing a 20-stack bag therefore triggers 20 ×
(`LedgerTable:Refresh` full query + sort, `Browser:UpdateDbSize` → `StorageStats` O(n) over the
whole persisted ledger, `Insights:Refresh` → full `Stats`) when the window is open.

**Impact:** an O(N·n) burst exactly when the user is interacting with the bank; the window is very
likely open, since that is what the addon is for.

**Fix direction:** coalesce on the **consumer** side (a one-frame `C_Timer.After(0, …)` or the
existing debounce helper), not by adding a second sender or a new "batch" message — one sender per
message is an architecture-§4 MUST and anti-pattern #17.

### F-006 — The quality gate silently passes uncached items, and the entry is never backfilled `[logic]`
`modules/Ledger.lua:324-325` (`GateReason`), `modules/Ledger.lua:334` (comment),
`modules/Ledger.lua:361-368` (`BuildEntry`).

`NS.Compat.ItemNameQuality(id)` returns `nil, nil` for an item the client has not cached. The gate
reads `if quality ~= nil and quality < DB_QUALITY` — so an uncached item bypasses the minimum-quality
threshold entirely and is recorded regardless of the user's setting. `BuildEntry` then stores it with
no `itemName`, `quality`, `itemType`, `itemSubType` or `itemLink`, and nothing ever fills those in.

The comment at line 334 — *"a later session fills in the name"* — describes a backfill that does not
exist anywhere in the codebase.

**Impact:** the quality filter leaks (most visibly on guild-bank items the player has never seen),
and the affected rows are permanently absent from the Type/Sub-type/Quality breakdowns, the filter
dropdowns and the item tooltips.

**Fix direction:** request the item and re-decide once it resolves — `NS.Compat.LoadItem(id, cb)`
already exists and is used by the Filters page (`settings/Panel.lua:438`). Either defer the gate
decision for an uncached id, or enrich the stored entry from the callback. Keep the API call in
`Compat` (compat) and correct the comment either way.

### F-007 — `/bl list` group order names a group that does not exist `[ux]` `[naming]`
`settings/Slash.lua:141`.

`local LIST_GROUP_ORDER = { "Capture", "Window" }` — the schema's two groups are `Master Controls`
and `Capture` (`settings/Schema.lua:18, 65`). `Window` is stale (it was renamed), and
`Master Controls` is missing, so the emit loop prints `[Capture]` first and `[Master Controls]`
second via the first-seen fallback — the reverse of the panel's own order.

**Impact:** `/bl list` groups read in a different order from the settings panel and from the schema
declaration; slash-commands-§5 requires "a stable, **declared** page order", and the declared order
here is silently not the one in force.

**Fix direction:** replace the stale constant with the real group names in schema order. Better: the
constant is a second source of truth for something the schema already encodes in row order — derive
it, or add a test asserting every declared group exists in `NS.Schema.Schema`.

### F-008 — `schemaVersion` default is one behind the migration target `[savedvariables]`
`defaults/Global.lua:8-11`, `core/Database.lua:14-31`.

The defaults declare `schemaVersion = 1` while `NS:RunMigrations` migrates 1 → 2. A brand-new
install therefore boots at v1, runs the v1→v2 migration over an empty ledger, and writes `2` back —
a pointless pass on every fresh profile. The comment ("0.1.0 ships the initial shape (1)") is stale.

**Impact:** cosmetic today; a real hazard once a v2→v3 migration lands and the default is still `1`,
because every fresh install will replay the entire migration chain.

**Fix direction:** set the default to the current schema version and update the comment. The
migration runner itself is correct and idempotent — leave the seam exactly as savedvariables-§1
requires.

### F-009 — Test mode has two sources of truth `[design]`
`core/State.lua:27` (`State.testRecords`), `modules/LedgerTable.lua:115` (`LT.testMode`),
`modules/LedgerTable.lua:472-482` (`ToggleTestMode`).

`ToggleTestMode` sets both in lockstep, but every reader picks one: `Database:ActiveLedger` reads
`State.testRecords`, `Browser:UpdateTestBadge` and `defaultCharSelection` read `LT.testMode`. Nothing
enforces the invariant, and F-002 is a direct consequence of one half of the state being invisible to
`Database`.

**Impact:** a maintenance trap — any future path that sets one without the other yields a table
showing test rows with no TEST MODE badge, or the reverse.

**Fix direction:** make `LT.testMode` a derived read (`NS.State.testRecords ~= nil`) so there is one
stored fact. `State` is already the declared home for session-only runtime state.

### F-010 — Bus-target fallback is unreachable and would break the anti-pattern it guards against `[design]`
`modules/Browser.lua:1103`.

`B.__ev = NS.NewBusTarget() or NS.bus` — `NewBusTarget` returns nil only when AceEvent-3.0 is
absent, in which case `NS.bus` (the AceAddon object, which embeds AceEvent) has no `RegisterMessage`
either, so the fallback errors on the next line. It is also precisely the shared-target registration
anti-pattern #32 forbids. The sibling modules do it correctly:
`modules/SessionWindow.lua:650-651` and `modules/Insights.lua:887-888` both `return` on nil.

**Impact:** dead defensive code that, if it ever ran, would either error or silently clobber another
consumer's handler.

**Fix direction:** match the siblings — `if not B.__ev then return end`.

### F-011 — Silent `pcall` swallows options-panel widget errors `[testability]`
`settings/Panel.lua:426` (`runRebuilders`), `settings/Panel.lua:698` (`P:Refresh`),
`settings/Panel.lua:779`.

Three `pcall(fn)` sites discard both the boolean and the error string. A refresher or rebuilder that
starts erroring — a schema path typo, a released widget — fails invisibly forever: the widget simply
stops updating, with nothing in chat, nothing in the console and nothing in a test.

**Impact:** an entire class of settings-panel breakage is undiagnosable, in an addon that otherwise
invests heavily in observability (`L:Diagnose`, `P:Diagnose`, the tagged console).

**Fix direction:** keep the `pcall` (one bad widget must not abort the loop) but route the failure to
the existing `NS.Debug` sink under a `[Panel]` tag. Chat is the wrong destination — this addon has a
main window, so debug output goes to the on-screen console (anti-pattern #18, debug-logging).

### F-012 — `State.openContext` mixes a frame token and a store token `[naming]`
`core/State.lua:8-16`, `modules/Ledger.lua:30-33`, `modules/Ledger.lua:506`,
`modules/Ledger.lua:573`.

The field's own documentation is emphatic that it holds a **frame**, not a store — *"This is a frame,
not a store, and the distinction is the whole point"* — yet its two values are `"BANK_FRAME"` (a
frame token) and `C.Store.GUILD_BANK` (a store token), and `Reconcile` compares it against
`C.Store.GUILD_BANK` directly.

**Impact:** the invariant the comment establishes is contradicted by the code three lines of context
later; a reader cannot tell whether comparing `openContext` to a `C.Store.*` value is intentional or
a bug. The values also collide conceptually with `L.CONTEXT_STORES` keys.

**Fix direction:** introduce a `C.Context = { BANK_FRAME = "BANK_FRAME", GUILD_BANK = "GUILD_BANK" }`
enum in `core/Constants.lua` beside the existing `C.Store` / `C.Direction` / `C.Kind` enums and use
it at every site. Values stay byte-identical, so nothing persisted or exported changes — this is a
naming fix, not a data change. (Constants is already the declared home for stable token tables.)

### F-013 — `LedgerTable.filter` aliases `Browser.activeFilter` `[design]`
`modules/Browser.lua:630-636` (`ApplyFilter` passes `B.activeFilter` by reference),
`modules/LedgerTable.lua:297-300` (`LT:SetFilter` stores it directly).

Insights is handed a **copy** via `B:CurrentFilter()` (`modules/Browser.lua:640-644`) precisely so it
cannot be mutated behind its back; the table gets the live table. Every subsequent
`B.activeFilter.text = …` / `.store = …` mutation silently rewrites `LT.filter` before `SetFilter`
is called.

**Impact:** it happens to work today because every mutation is immediately followed by
`ApplyFilter`, but the two consumers of the same value follow opposite ownership rules, and the
table's `self.filter` is not actually its own.

**Fix direction:** hand `LedgerTable` the same copy Insights gets — reuse `B:CurrentFilter()` in
`ApplyFilter`.

---

## Low

### F-014 — `NS.Browser:Unavailable` has zero callers `[dead-code]`
`modules/Browser.lua:1116-1120`. Verified by grep across `core/ defaults/ locales/ modules/
settings/` and `tests/` — no call site anywhere, including tests. Its docstring describes a
soft-fallback path ("used by the slash verbs when the UI libraries are unavailable") that the slash
verbs do not implement: `NS.COMMANDS` `show`/`hide`/`toggle` call `NS.Browser:Show()` unguarded
(`settings/Schema.lua:199-201`). Either wire it up or delete it.

### F-015 — `LedgerTable` bypasses the file-local printer alias `[convention]`
`modules/LedgerTable.lua:902, 908` call `NS.Print(...)` directly. Every other emitting file opens
with `local print = NS.Print` (`settings/Slash.lua:4`, `settings/Schema.lua:5`,
`settings/Panel.lua:4`, `modules/DebugLog.lua:5`, `modules/Browser.lua:6`), which is the convention
`core/Util.lua:147-149` states explicitly. Functionally identical, but it is the one file where a
future `print(...)` typo would reach the *global* print instead of the tagged one.

### F-016 — README command table drifts from `NS.COMMANDS` `[docs]`
`README.md:51-65` vs `settings/Schema.lua:198-258`. All fifteen verbs are present on both sides (no
missing entries in either direction), but `test` and `session` appear in opposite order, and the
`debug scan` / `debug panel` sub-verbs — first-class diagnostics with dedicated code paths
(`modules/Ledger.lua:222`, `settings/Panel.lua:614`) — are documented nowhere in the README. The
settings landing page generates its list from `NS.COMMANDS` (`settings/Panel.lua:599-604`), so the
README is the only hand-maintained copy.

### F-017 — Version is stored in two places `[naming]`
`core/Namespace.lua:5` (`NS.version = "0.1.0"`) vs the TOC's `## Version`. `/bl version` reads the
TOC via `Compat.GetAddOnMetadata` (`settings/Slash.lua:222-224`), while `/bl help` prints
`NS.version` (`settings/Slash.lua:105`). A version bump that misses one makes the two commands
disagree.

### F-018 — `P:Refresh()` runs the O(n) storage recompute even when the panel is hidden `[perf]`
`settings/Panel.lua:696-699`, `modules/DebugLog.lua:300-308` (`syncPanel`). `refreshStats`
(`settings/Panel.lua:391-407`) walks the whole persisted ledger to estimate byte size and is
registered as a plain refresher, so it runs on every `P:Refresh()` — including the one
`DebugLog:Show`/`Hide` fires on every `/bl debug`. The bus-driven path already guards with
`ctx.panel:IsShown()` (`settings/Panel.lua:414`); `P:Refresh` does not.

### F-019 — One schema row has no `tooltip` `[convention]`
`settings/Schema.lua:95-100` (`settings.excludedStores`). Every other row in the table carries a
`tooltip` field and the panel renders it via `attachTooltip`; this one — the per-store capture grid,
arguably the least self-explanatory control on the page, since it is rendered **inverted**
(`invert = true`, a ticked box means "record") — has none.

---

## Verified clean (no findings)

* **Taint / combat.** No protected API is called. `P:Open` correctly gates on `InCombatLockdown()`
  and refuses rather than deferring (`settings/Panel.lua:789-793`, options-ui-§2). Settings category
  registration is eager in `OnInitialize` (anti-pattern #22). No `:SetAttribute`, no secure
  templates, no `RegisterUnitWatch`, no `setmetatable` on a widget.
* **Secret values.** `NS.IsConcatSafe` probes `table.concat`, not `..` — the correct detector
  (events-frames-taint-§8, anti-pattern #35). `NS.Print` and `NS.Debug` both route every argument
  through `NS.SafeToString` before any format or concat.
* **Deprecated APIs.** Every varying API is behind `core/Compat.lua`; a grep for `GetItemInfo`,
  `GetContainer*`, `IsAddOnLoaded`, `UnitAura*`, `GetSpellInfo`, `InterfaceOptions_*` outside Compat
  returns only the `Compat.GetAddOnMetadata` *call site* in `settings/Slash.lua`. No
  `WOW_PROJECT_ID` branching (anti-pattern #9).
* **Events.** Registered in `OnEnable`, never `OnInitialize`. `BAG_UPDATE_DELAYED` is used rather
  than `BAG_UPDATE`. `L:RegisterEventSafely` isolates each registration so one retired event name
  cannot deafen the addon — an unusually good defence, and `/bl debug scan` reports the result.
  Re-entry guards (`self._enabled`) on all three `Enable` paths.
* **Frames.** No `OnUpdate` anywhere. Both tables pool rows; Insights pools every widget class.
  `ClearAllPoints` precedes every re-anchor. Anonymous frames are anonymous except the four that
  need `_G` names for `UISpecialFrames`.
* **Bus.** Every consumer registers on its own `NS.NewBusTarget()` target (anti-pattern #32), and
  the test harness models real `(message, target)` dispatch (anti-pattern #33). Documented in
  `docs/ARCHITECTURE.md:153-156`.
* **AceConsole clobber.** `NS.Print` is reclaimed immediately after `NewAddon`
  (`core/BankLedger.lua:13`), and a test asserts every chat line carries the cyan `[BL]` tag
  (anti-pattern #36, architecture-§2).
* **Options panel.** The Defaults button is created lazily in first `OnShow` with the callback
  parked on the panel (anti-pattern #42, options-ui-§5); refresh is in-place via `refreshers` with
  structural rebuilds scoped to the on-screen panel (anti-pattern #39, options-ui-§11); the
  scrollbar is always-shown-and-inert (anti-pattern #30).
* **File sizes.** Largest file is `modules/Browser.lua` at 1120 LOC — under the 1500 ceiling
  (anti-pattern #16), though `Browser` is the natural next split candidate if the filter bar grows.
