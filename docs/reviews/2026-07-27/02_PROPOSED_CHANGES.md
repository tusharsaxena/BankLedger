# Ka0s Bank Ledger — Proposed Changes (HLD + LLD), 2026-07-27

Derived from `01_FINDINGS.md`. Change IDs are `C-nnn`; each links back to its finding IDs.

**Standard resolved:** Ka0s WoW Addon Standard **v2.11.0 (2026-07-26)**, fetched from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md`
plus all 23 section files discovered from its Sections list. Every change below has been checked
against it and introduces **no new deviation**; rules that shaped or blocked a change are cited as
`filename-§N`.

---

## HLD — themes

### T1. Make money capture as evidence-driven as item capture
**Covers:** F-001.

Item capture rests on a strong invariant — *both sides must change, in opposite directions* — which
is what keeps a loot or a vendor buy out of the ledger. Money capture has no such invariant: it
watches only the player's purse and attributes the delta to whichever money-holding store the open
frame happens to reach. The fix is to give money the same corroboration requirement by diffing the
**store's own balance**, not the purse.

*Alternatives considered.*
(a) *Ignore money while a purchase-capable frame is open* — rejected: there is no event that says
"a purchase happened", and it would drop real warband deposits made in the same visit.
(b) *Heuristic: only accept a money delta in the same reconcile pass as an item movement* — rejected:
a pure gold deposit is a legitimate, common movement with no item beside it.
(c) *Narrow `L.MONEY_STORES` to the guild bank only* — kept as the **documented fallback** if no
warband-balance reader exists on 12.0.7 (see C-001b). Loses a real feature, so it is second choice.

*Trade-off.* (a)/(b) are cheap but lossy; the balance-diff is the only option that is both correct
and complete. It costs one new `Compat` reader and one extra value in the snapshot.

### T2. Make test mode a read-only sandbox
**Covers:** F-002, F-009.

`/bl test` publishes a synthetic dataset through the real render path — a good design that
deliberately exercises production code. The gap is that the *write* paths were never told about it,
so mutating row actions cross from the sandbox into real storage. Two moves: derive `LT.testMode`
from the single stored fact (`NS.State.testRecords`), and disable the mutating menu entries while it
is set.

*Alternative considered.* Teaching `Database:Delete`/`Filters` to operate on the active dataset —
rejected. It would make the persistence layer dataset-aware, spreading test-mode knowledge across
modules that have no business knowing about it, and "delete a synthetic row" is not a meaningful
operation. The menu is the right place to refuse.

### T3. Close the settings-propagation gaps
**Covers:** F-003, F-007, F-019.

`Schema` is the single source of truth for settings, and every consumer reacts through
`Ka0s_BankLedger_SettingsChanged`. One row (`windowScale`) opted out of the bus in favour of a
direct call and lost a consumer as a result; one CLI constant (`LIST_GROUP_ORDER`) drifted from the
group names it orders; one row lost its tooltip. All three are the same class of defect: a second,
hand-maintained copy of something the schema already knows.

*Alternative considered.* Adding a direct `Schema → SessionWindow:SetScale` call alongside the
Browser one — **rejected: it is anti-pattern #19** (cross-module direct table access) and would put
the same defect one module further along the next time a window is added.

### T4. Coalesce view refreshes
**Covers:** F-004, F-005, F-018.

Three independent paths recompute O(n) aggregates far more often than the data changes: per
keystroke, per recorded entry, and per debug-console toggle. None needs a new abstraction — the
addon already owns a debounce idiom (`L:ScheduleReconcile`) and an on-screen guard
(`ctx.panel:IsShown()`); they just are not applied here.

*Alternative considered.* Incremental/streaming stats (update the aggregate per entry instead of
re-scanning) — rejected as premature: it would fork `Database:Stats` into two implementations that
must agree, for a workload a debounce already flattens.

### T5. Truth in comments, names and defaults
**Covers:** F-006, F-008, F-012, F-013, F-014, F-015, F-016, F-017.

A cluster of small items where the code and its own documentation disagree: a comment promising a
backfill that does not exist, a defaults constant a version behind, a field whose comment insists on
an invariant the values break, a duplicated version string, a dead exported function. Individually
nits; together they are the thing that makes the next reader distrust the (otherwise excellent)
comments.

### T6. Make the settings panel debuggable
**Covers:** F-010, F-011.

Two defensive constructs that defend by hiding: a `pcall` that discards its error, and a fallback
that would break the invariant it exists to protect. Both are replaced by the pattern the sibling
modules already use.

---

## LLD — change-set

### C-001 — Corroborate money movements against the store's own balance
**Findings:** F-001 · **Risk:** high (touches the capture invariant) · **Tests:** extend
`tests/test_ledger.lua`

**Files:** `core/Compat.lua`, `modules/Ledger.lua`, `docs/ARCHITECTURE.md`

**Step 1 (investigation, C-001a).** Extend `L:Diagnose` with a money-API probe, so the live client
reports ground truth rather than us guessing:

```lua
add("money API: purse=%s guildBank=%s bankFetch=%s bankTypes=%s",
  type(GetMoney), type(GetGuildBankMoney),
  type(C_Bank and C_Bank.FetchDepositedMoney), tostring(Enum and Enum.BankType ~= nil))
```

Run `/bl debug scan` at a bank and at a guild bank and read the result. This mirrors the existing
container probe, which exists for exactly this reason.

**Step 2 (implementation).** If a warband/account balance reader exists, add it to `Compat` —
never called raw from `Ledger` (compat, anti-pattern #10):

```lua
-- core/Compat.lua
-- Coin held BY a store, not by the player. nil when the build exposes no reader for that store:
-- the caller must then decline to attribute a money movement rather than guess (see Ledger.Diff).
function Compat.GetStoreMoney(store)
  if store == "GUILD_BANK" and type(GetGuildBankMoney) == "function" then
    return GetGuildBankMoney()
  end
  if store == "WARBAND_BANK" and C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
    return C_Bank.FetchDepositedMoney(Enum.BankType.Account)
  end
  return nil
end
```

Carry it in the snapshot and diff it:

```lua
-- modules/Ledger.lua — L:Snapshot
  return {
    bags   = self:ScanStore(C.Store.BAGS),
    stores = stores,
    money  = NS.Compat.GetMoney(),
    storeMoney = storeMoney,          -- { [store] = copper | nil }
  }

-- modules/Ledger.lua — L.Diff, money block
-- BEFORE: any purse delta becomes a movement at this store.
-- AFTER:  the purse delta must be MIRRORED by the store's own balance, in the opposite direction —
--         the same "both sides must change" rule item movements already obey. A store whose balance
--         cannot be read (nil) contributes no money movement at all; a purchase made at the bank
--         window moves the purse and nothing else, so it produces no row.
  if L.MONEY_STORES[store] then
    local purseDelta = (after.money or 0) - (before.money or 0)
    local storeDelta = (after.storeMoney or 0) - (before.storeMoney or 0)
    if before.storeMoney and after.storeMoney and purseDelta ~= 0 and storeDelta ~= 0
       and (purseDelta < 0) ~= (storeDelta < 0) then
      local amount = math.min(math.abs(purseDelta), math.abs(storeDelta))
      ...
    end
  end
```

`storeView` gains `storeMoney = (snapshot.storeMoney or {})[store]` so `Diff` keeps its narrow,
pure `{ bags, store, money, storeMoney }` shape and stays unit-testable headlessly (testing).

**Fallback (C-001b), if step 1 finds no warband reader.** Remove `WARBAND_BANK` from
`L.MONEY_STORES`, keep the guild-bank balance diff, and record the narrowing under
`docs/ARCHITECTURE.md` ▸ *Known limitations* beside the existing store-to-store note. This is a
smaller change and still removes the false rows.

**Standards conformance.** New API calls live in `Compat` only (compat, anti-pattern #10); `Diff`
stays pure so the new rule is covered by headless tests (testing-§4 requires the failing test
first); no game-flavor branching (anti-pattern #9); the `MONEY` entry shape is unchanged, so no
schema bump and no export-contract break.

---

### C-002 — Make test mode read-only, from one stored fact
**Findings:** F-002, F-009 · **Risk:** low · **Tests:** `tests/test_ledgertable.lua`

**Files:** `modules/LedgerTable.lua`

```lua
-- BEFORE
LT.testMode = false
function LT:ToggleTestMode()
  self.testMode = not self.testMode
  NS.State.testRecords = self.testMode and self:BuildTestData() or nil
  ...
  return self.testMode
end

-- AFTER — one stored fact (State.testRecords); testMode is a derived read, so the two can never
-- disagree and Database keeps its single, persistent write target.
function LT:IsTestMode() return NS.State.testRecords ~= nil end
function LT:ToggleTestMode()
  NS.State.testRecords = (not self:IsTestMode()) and self:BuildTestData() or nil
  ...
  return self:IsTestMode()
end
```

Update the three readers (`modules/Browser.lua:680` `defaultCharSelection`,
`modules/Browser.lua:722` `UpdateTestBadge`) to call `LT:IsTestMode()`.

In `LT:ShowRowMenu`, gate the mutating entries — the menu already renders a disabled entry greyed
out and click-inert, so no new UI is needed:

```lua
  local live = not LT:IsTestMode()
  { label = "Blacklist item", enabled = live and entry.itemID ~= nil, ... },
  { label = "Whitelist item", enabled = live and entry.itemID ~= nil, ... },
  { label = "|cffff5555Delete|r", enabled = live, ... },
```

"Link to chat" stays enabled — it mutates nothing.

**Standards conformance.** Keeps `Database:Delete` operating on the persisted ledger only (no
dataset-awareness pushed into the storage layer); `State` remains the declared home for session-only
runtime state; no new bus message, so architecture-§4's one-sender rule is untouched.

---

### C-003 — Broadcast the scale change on the bus
**Findings:** F-003 · **Risk:** low · **Tests:** `tests/test_schema.lua`

**Files:** `settings/Schema.lua`

```lua
-- BEFORE
    onChange = function(v)
      if NS.Browser and NS.Browser.SetScale then NS.Browser:SetScale(v) end
    end },

-- AFTER — both windows react through their existing SettingsChanged subscriptions; the direct call
-- stays for the immediate, no-latency repaint of the window the user is most likely looking at.
    onChange = function(v)
      if NS.Browser and NS.Browser.SetScale then NS.Browser:SetScale(v) end
      if NS.bus then NS.bus:SendMessage("Ka0s_BankLedger_SettingsChanged", "windowScale") end
    end },
```

`SW:OnSettingsChanged` and `B:OnSettingsChanged` already read `windowScale`; no consumer changes.

**Standards conformance.** Uses the existing closed bus rather than a second cross-module call
(anti-pattern #19, architecture-§4); `Schema` row `onChange` remains the documented single sender of
`SettingsChanged` (`docs/ARCHITECTURE.md:155`), so the one-sender-per-message MUST is preserved.
**Rejected alternative:** a direct `NS.SessionWindow:SetScale(v)` call from the schema row — it
would have been one line, but it is anti-pattern #19 and repeats the defect for the next window.

---

### C-004 — Fix `/bl list` group order (and add the missing tooltip)
**Findings:** F-007, F-019 · **Risk:** none · **Tests:** `tests/test_slash.lua`, `tests/test_schema.lua`

**Files:** `settings/Slash.lua`, `settings/Schema.lua`

```lua
-- settings/Slash.lua
-- BEFORE: "Window" is a group that no longer exists, and "Master Controls" is missing — so the
--         declared order silently isn't the one in force.
local LIST_GROUP_ORDER = { "Capture", "Window" }
-- AFTER: schema declaration order, which is also the panel's order.
local LIST_GROUP_ORDER = { "Master Controls", "Capture" }
```

Add a guard test asserting every name in `LIST_GROUP_ORDER` occurs as a `group` in
`NS.Schema.Schema`, so the constant cannot drift again, and a test asserting every schema row has a
non-empty `tooltip`. Add the missing tooltip to `settings.excludedStores`, calling out the inversion
explicitly:

```lua
    tooltip = "Tick a store to RECORD movements to and from it. Unticking mutes that store; "
      .. "capture for every other store is unaffected.",
```

**Standards conformance.** Restores the "stable, declared page order" slash-commands-§5 requires;
the colour scheme, indents and no-trailing-colon rules are already correct and unchanged. Tests
added before the fix, per testing-§4.

---

### C-005 — Debounce filter application
**Findings:** F-004 · **Risk:** medium (UI responsiveness feel) · **Tests:** `tests/test_browser.lua`

**Files:** `modules/Browser.lua`

Introduce one small scheduler beside `ApplyFilter`, modelled on `L:ScheduleReconcile`:

```lua
-- Coalesce a burst of filter edits into ONE recompute. A search keystroke costs a full
-- Database:Query on the History tab and a full Database:Stats (≈20 sorts) on Insights, so typing
-- "linen" used to pay for five. Same idiom as modules/Ledger.lua's reconcile debounce.
local FILTER_DEBOUNCE = 0.20
local pendingFilterTimer
local function ScheduleApplyFilter()
  local addon = NS.addon
  if not (addon and addon.ScheduleTimer) then return ApplyFilter() end  -- headless: inline
  if pendingFilterTimer then addon:CancelTimer(pendingFilterTimer) end
  pendingFilterTimer = addon:ScheduleTimer(function()
    pendingFilterTimer = nil
    ApplyFilter()
  end, FILTER_DEBOUNCE)
end
```

Call it from the search box's `OnTextChanged` **only**. Dropdown selections stay on the immediate
`ApplyFilter` — they are single, deliberate acts and must feel instant.

**Standards conformance.** Uses the already-embedded AceTimer-3.0 (library-stack); no new library;
the headless-inline branch keeps the path testable without a timer mock (testing).

---

### C-006 — Coalesce per-entry view refreshes
**Findings:** F-005 · **Risk:** low · **Tests:** `tests/test_browser.lua`

**Files:** `modules/Browser.lua`, `modules/Insights.lua`

Consumers of `EntryAdded` schedule a next-frame refresh instead of refreshing synchronously:

```lua
-- modules/Browser.lua — B:Enable
-- A reconcile pass records one entry per moved stack, so a 20-slot deposit fans 20 EntryAdded
-- messages. Collapse them into one repaint on the next frame; the ledger is fully written by then.
  B.__ev:RegisterMessage("Ka0s_BankLedger_EntryAdded", function() B:ScheduleLedgerRefresh() end)
```

`B:ScheduleLedgerRefresh` sets a `_refreshQueued` flag and calls `C_Timer.After(0, …)`, clearing the
flag in the callback; the existing `B:OnLedgerChanged` body is untouched. Same treatment for
`I.__ev`'s `EntryAdded` handler. `LedgerChanged` stays synchronous — it is already one message per
bulk operation.

**Standards conformance.** No new bus message and no second sender (architecture-§4, anti-pattern
#17); the fix is entirely consumer-side.

---

### C-007 — Guard `P:Refresh` on visibility
**Findings:** F-018 · **Risk:** none · **Tests:** none required (pure guard)

**Files:** `settings/Panel.lua`

```lua
function P:Refresh()
  local ctx = P.general
  -- A hidden panel's widget values are re-synced by its own OnShow, and refreshStats walks the
  -- whole ledger — so refreshing off-screen is pure cost. Matches the guard the bus path already
  -- uses (options-ui-§11).
  if not (ctx and ctx.refreshers and ctx.panel and ctx.panel:IsShown()) then return end
  for _, fn in ipairs(ctx.refreshers) do ... end
end
```

The `OnShow` handler already calls `P:Refresh()` after building, so a hidden panel is still correct
on next open.

**Standards conformance.** This *is* the options-ui-§11 rule (scope work to the on-screen
subcategory) applied to the scalar-refresh path.

---

### C-008 — Resolve uncached items before gating, and fix the comment
**Findings:** F-006 · **Risk:** medium (touches the capture gate) · **Tests:** `tests/test_ledger.lua`

**Files:** `modules/Ledger.lua`

```lua
-- modules/Ledger.lua — GateReason
-- BEFORE: an uncached item has nil quality, so the threshold comparison is skipped and the item is
--         recorded whatever the user's minimum-quality setting says.
    local _, quality = NS.Compat.ItemNameQuality(id)
    if quality ~= nil and quality < DB_QUALITY then return "quality" end

-- AFTER: an id the client has not cached yet cannot be judged. Ask for it and report the skip
-- reason honestly, so the console says "uncached" instead of the row silently appearing.
    local _, quality = NS.Compat.ItemNameQuality(id)
    if quality == nil then
      if DB_QUALITY > 0 then NS.Compat.LoadItem(id); return "uncached" end
    elseif quality < DB_QUALITY then
      return "quality"
    end
```

Note the asymmetry that keeps this safe: at the default `qualityThreshold = 0` **nothing changes** —
every quality passes, so an uncached item is still recorded, exactly as today. The new skip only
applies when the user has actually asked for a threshold, which is the case the current code
violates.

Correct the stale comment at `modules/Ledger.lua:334`:

```lua
-- BEFORE: "…the table shows "Item <id>" and a later session fills in the name."
-- AFTER:  "…the table shows "Item <id>". There is no backfill: the stored row keeps only its id,
--          so an uncached item is invisible to the Type/Sub-type/Quality breakdowns for good."
```

**Standards conformance.** `LoadItem` is already a `Compat` shim (compat); the skip reason joins the
existing `disabled/kind/store/blacklist/quality` vocabulary the console logs, satisfying
debug-logging-§8's "log the not-recorded decisions too". **Rejected alternative:** recording the row
and mutating it later from the `LoadItem` callback — it would write to a persisted entry from an
async callback with no ownership story, and `Database` is the only writer of the ledger.

---

### C-009 — `C.Context` enum for the open-frame token
**Findings:** F-012 · **Risk:** low (pure rename; values unchanged) · **Tests:** `tests/test_constants.lua`

**Files:** `core/Constants.lua`, `core/State.lua`, `modules/Ledger.lua`

```lua
-- core/Constants.lua, beside C.Store / C.Direction / C.Kind
-- Which storage FRAME is open. Deliberately NOT a C.Store value: the retail bank frame reaches
-- three stores at once, which is the whole reason this is a separate axis. Runtime-only — never
-- persisted, never exported — but a stable token table like its neighbours.
C.Context = { BANK_FRAME = "BANK_FRAME", GUILD_BANK = "GUILD_BANK" }
```

Replace the string literals in `L.CONTEXT_STORES`, `OPEN_EVENTS`, and the two `C.Store.GUILD_BANK`
comparisons at `modules/Ledger.lua:506` and `:573` with `C.Context.*`. Values are byte-identical, so
nothing persisted, exported or messaged changes.

**Standards conformance.** `Constants` is the declared home for token tables; no localized display
string is being matched (anti-pattern #37) — these are internal tokens, which is the *correct* form.

---

### C-010 — Hand `LedgerTable` a filter copy
**Findings:** F-013 · **Risk:** low · **Tests:** `tests/test_browser.lua`

**Files:** `modules/Browser.lua`

```lua
-- BEFORE: the table holds a live reference to Browser's mutable filter; Insights gets a copy.
  if NS.LedgerTable then NS.LedgerTable:SetFilter(B.activeFilter) end
-- AFTER: both consumers get the same ownership guarantee.
  if NS.LedgerTable then NS.LedgerTable:SetFilter(B:CurrentFilter()) end
```

**Standards conformance.** Reinforces module boundaries (anti-pattern #19's spirit); no API change.

---

### C-011 — Panel error visibility + bus-target fallback
**Findings:** F-010, F-011 · **Risk:** none · **Tests:** none required

**Files:** `settings/Panel.lua`, `modules/Browser.lua`

```lua
-- settings/Panel.lua — one shared helper, used by runRebuilders, P:Refresh and the Filters OnShow.
-- Keep the pcall (one bad widget must not abort the loop) but never swallow the reason: a refresher
-- that starts failing otherwise stops updating forever with nothing anywhere to say so.
local function safeRun(fn, tag)
  local ok, err = pcall(fn)
  if not ok and NS.State and NS.State.debug and NS.Debug then
    NS.Debug("Panel", "%s failed: %s", tostring(tag), tostring(err))
  end
end
```

```lua
-- modules/Browser.lua — match the SessionWindow/Insights pattern.
-- BEFORE: B.__ev = NS.NewBusTarget() or NS.bus   -- unreachable, and registering on the shared bus
--         is exactly the receiver-clobber the factory exists to prevent.
  B.__ev = NS.NewBusTarget()
  if not B.__ev then return end
```

**Standards conformance.** Debug output goes to the on-screen console, not chat (anti-pattern #18,
debug-logging); removing the shared-bus fallback removes a latent anti-pattern #32 violation.

---

### C-012 — Defaults, version, dead code, printer alias, README
**Findings:** F-008, F-014, F-015, F-016, F-017 · **Risk:** none · **Tests:** `tests/test_database.lua`

**Files:** `defaults/Global.lua`, `core/Namespace.lua`, `modules/Browser.lua`,
`modules/LedgerTable.lua`, `README.md`

* `defaults/Global.lua` — `schemaVersion = 2`, comment updated to "0.1.0 ships schema v2"; add a test
  asserting the default equals the migration runner's target so the two cannot drift again.
* `core/Namespace.lua` — keep `NS.version` as the fallback (it is what `/bl version` degrades to
  headlessly) but make `Sl:PrintHelp` read the same resolved value `Sl:CliVersion` uses, via a small
  shared `Sl:Version()`; the two commands then cannot disagree.
* `modules/Browser.lua` — delete `B:Unavailable` (zero callers, and the soft-fallback it documents
  is not implemented). If the fallback is wanted instead, wire it into the `show`/`hide`/`toggle`
  entries in `NS.COMMANDS`; do not leave it half-built.
* `modules/LedgerTable.lua` — add `local print = NS.Print` at the top and switch the two `NS.Print`
  call sites, matching the other five emitting files.
* `README.md` — reorder the command table to match `NS.COMMANDS`, and document `debug scan` /
  `debug panel` as sub-verbs of `/bl debug`.

**Standards conformance.** `NS.PREFIX`-tagged printing preserved (slash-commands-§4); the README
command table stays a documented surface generated-in-spirit from `NS.COMMANDS`, and the section
order is untouched (anti-pattern #28, documentation-§1). The version bump itself is **not** part of
this change — versioning-git forbids bumping without an explicit instruction.

---

## Change → finding matrix

| Change | Findings | Files | Risk |
|---|---|---|---|
| C-001 | F-001 | Compat, Ledger, ARCHITECTURE | High |
| C-002 | F-002, F-009 | LedgerTable, Browser | Low |
| C-003 | F-003 | Schema | Low |
| C-004 | F-007, F-019 | Slash, Schema | None |
| C-005 | F-004 | Browser | Medium |
| C-006 | F-005 | Browser, Insights | Low |
| C-007 | F-018 | Panel | None |
| C-008 | F-006 | Ledger | Medium |
| C-009 | F-012 | Constants, State, Ledger | Low |
| C-010 | F-013 | Browser | Low |
| C-011 | F-010, F-011 | Panel, Browser | None |
| C-012 | F-008, F-014, F-015, F-016, F-017 | Global, Namespace, Browser, LedgerTable, README | None |
