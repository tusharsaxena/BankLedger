# Ka0s Bank Ledger — Proposed Changes (HLD + LLD) — 2026-08-03

Derived from `01_FINDINGS.md`. Change IDs are `C-0NN`; each links back to the finding IDs it closes.

## Standards basis for this document

Resolved standard version: **v2.17.1 (2026-08-03)**.

The prescribed `curl` fetch from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` timed out after three
section files; the remainder was read from the canonical repository itself
(`/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards`, `master`, clean, HEAD `2141229
v2.17.1`) — the same bytes, not a memory reconstruction. **The conformance check below was
performed**, not skipped. Rules are cited as `filename-§N` where a change is shaped or constrained
by one.

This is a guardrail on remediation, **not** a compliance audit. Pre-existing deviations unrelated to
these changes are out of scope; the one noticed (`performance-§1` wiring) is recorded in
`01_FINDINGS.md` as a pointer to the next `wow-addon:standards-audit`, and no change below touches
it.

## Upstream change-set

**Empty.** No finding lands in a library repo. **No change in this document targets any path under
`libs/` or `tests/_kit/`.**

---

## HLD — themes

### Theme A — Close the two seams that leak past a shared surface

*Covers F-001, F-002.*

The addon's design rests on two seams being unbypassable: every chat line goes through `NS.Print`,
and every settings-panel widget belongs to the library's page registry. Both are honored almost
everywhere, and each has exactly one leak. `modules/Browser.lua` is the one user-facing file that
never took the `local print = NS.Print` upvalue, so two lines escape the `[BL]` tag. `renderStorage`
is the one place a bus handler holds a **widget** rather than reaching one through the registry, so
it survives the teardown that releases it.

The rationale for treating these together is that both are *the same class of mistake* — a local
shortcut around a shared seam — and both are invisible to the gates. Neither is a design change:
each is the file rejoining a convention its five siblings already follow.

**Alternatives considered.**

- *F-001: format the tag inline in Browser.* Rejected. `slash-commands-§4` makes the cyan bracketed
  tag mandatory and `architecture-§2` makes `NS.Print` / `NS.Util.print` the one object every
  upvalue capture must hold; a second formatter is anti-pattern #47's shape in miniature and is
  exactly the drift `core/CoreSetup.lua:5-10` was written to end.
- *F-002: re-register the bus handler on every render.* Rejected — it either leaks CallbackHandler
  registrations or needs an unregister dance nothing else in the addon does. Re-pointing a single
  stable handler at the current context is smaller and matches how `P.__evFilters`
  (`settings/Panel.lua:303-314`) already behaves: it captures **nothing** and calls a registry
  function.
- *F-002: hand-roll a per-page refresher registry in `Panel.lua`.* Rejected outright — anti-pattern
  #47 and `options-ui-§11`; the library already owns that registry and `O.RefreshScalars` already
  does the on-screen / mark-dirty split.

### Theme B — Make the enums and the event map say what they mean

*Covers F-005, F-006.*

`core/Constants.lua` deliberately separates "which frame is open" (`C.Context`) from "which store a
movement targets" (`C.Store`), and `modules/Ledger.lua` maps open events to contexts through
`OPEN_EVENTS`. Two spots cross the axes and one spot drops the context entirely. Both are latent
rather than live, and both are cheap to make explicit — the correct shape already exists a few lines
away in the same file (`L.CONTEXT_STORES`, and the guarded `OnHide` hook).

**Alternatives considered.** *Merge the two enums, since they share a value.* Rejected: the split is
load-bearing and documented (`core/Constants.lua:28-40`) — `C.Store` values are the persisted CSV
export contract, `C.Context` values are runtime-only, and `BANK_FRAME` was removed from `C.Store`
by an earlier finding (F-012 of the 2026-07-27 review) precisely to keep that true. Merging would
undo prior work.

### Theme C — Correct the three places where a comment or a constant lies

*Covers F-003, F-007, F-008, F-009.*

Four small corrections with one thing in common: the source **asserts** something that is not true —
a LibStub key that cannot resolve, a test file that does not exist, a doc that does not exist, and a
"we deliberately did not copy the library's constant" comment sitting on a copied (and wrong)
constant. In a codebase whose comments are this load-bearing, a comment that lies is a defect, not a
nit. Grouped because they are independent one-liners with no shared risk.

**Alternatives considered.** *Create `docs/data-model.md` to make F-008's pointer true.* Rejected:
`documentation-§3` pins the canonical `docs/` set as a **trio** (`ARCHITECTURE.md`, `testing.md`,
`smoke-tests.md`) plus named topic-detail docs; inventing a fourth doc to satisfy a stale
parenthetical adds a maintenance surface to fix a comment. Repoint at `ARCHITECTURE.md`.

### Theme D — Make truncation correct on non-English clients

*Covers F-004.*

`W.Truncate` is this addon's own primitive and its byte-based cut is wrong for the three label
sources that arrive localized. The fix is contained: one helper, one added guard, no caller change.

**Alternatives considered.** *Push a UTF-8-safe truncator into LibKa0s.* A reasonable future
direction — `library-stack-§7` makes additive library growth the compliant way to share a primitive
— but rejected **for this change-set**: nothing else in the collection is known to need it yet, and
a cross-repo bump + re-vendor commit for a three-line guard is disproportionate. Recorded as a
follow-up rather than done here, and the fix stays in the addon's own `modules/InsightsWidgets.lua`,
which is not a library file.

### Theme E — Housekeeping

*Covers F-010, F-011, F-012, F-013, F-014, F-016.* Independent, zero-risk tidying: delete the one
export with no caller anywhere, annotate the ones the suite pins as pure seams, fix the section
numbering, collapse the leftover whitespace and the duplicated paragraph, guard one cross-module
reach, clear one flag, and stop one spurious broadcast. F-015 is **deferred by design** — see below.

---

## LLD — change-set

### C-001 — Browser takes the shared printer upvalue

**Closes:** F-001 · **Files:** `modules/Browser.lua`

Before (`modules/Browser.lua:1-5`):

```lua
local addonName, NS = ...   -- luacheck: ignore addonName
NS.Browser = NS.Browser or {}
local B = NS.Browser
local C = NS.Constants
local frame
```

After:

```lua
local addonName, NS = ...   -- luacheck: ignore addonName
NS.Browser = NS.Browser or {}
local B = NS.Browser
local C = NS.Constants
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)
local frame
```

Also update the enumeration in `core/CoreSetup.lua:19-22` — it lists the five files that take the
printer as a file-scope upvalue and pins the seam's TOC position on that list. `modules/Browser.lua`
loads after `core/CoreSetup.lua` already (TOC `# Modules` block is below `# Core`), so no ordering
moves; the comment simply becomes true again and now names six files.

**Risk:** None. `NS.Print` is live by the time `modules/Browser.lua` loads, and the object identity
guarantee (`core/CoreSetup.lua:92-97`) means the reclaim in `core/BankLedger.lua:13` still reaches
this capture.

**Standards conformance:** Required by `slash-commands-§4` (mandatory cyan tag) and
`architecture-§2` (the printer is one object, captured as an upvalue). The rejected alternative — an
inline tag in Browser — would have introduced anti-pattern #47's drift.

### C-002 — The Storage refresher stops holding a released widget

**Closes:** F-002 · **Files:** `settings/Panel.lua`

The handler must survive re-renders while the *thing it refreshes* must not. Two acceptable shapes;
prefer (a).

**(a) Preferred — let the library's registry carry it.** `refreshStats` is already pushed into
`ctx.refreshers` (`settings/Panel.lua:156`) on every render, and `P:Refresh` → `O.RefreshScalars()`
(`settings/Panel.lua:471`) runs the *current* pass's refreshers with the on-screen / mark-dirty
split already applied. So the private handler only needs to trigger that, never to close over a
widget:

```lua
-- settings/Panel.lua, inside renderStorage — replace the onChange closure
if not P.__ev then
  local ev = NS.NewBusTarget()
  if ev then
    -- Closes over NOTHING from this render pass. A structural re-render releases every widget
    -- built here (O.ClearScroll), so a handler that captured `statsLabel` would repaint a
    -- pool-recycled widget for the rest of the session. Delegate to the library's registry
    -- instead, which always runs the CURRENT pass's refreshers (options-ui-§11).
    local onChange = function() P:Refresh() end
    ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", onChange)
    ev:RegisterMessage("Ka0s_BankLedger_EntryAdded", onChange)
    P.__ev = ev
  end
end
```

**(b) Fallback, if (a) proves to under-refresh.** Keep a per-page indirection instead of a captured
local: store `P.general.refreshStorage = refreshStats` at the end of each render and have the
handler call `P.general and P.general.refreshStorage and P.general.refreshStorage()`. Still one
registration, still no captured widget.

**Risk:** Low. (a) routes the storage line through the same path a `/bl set` already takes, so it
cannot loop (`settings/Schema.lua:188-191` documents why re-syncing a widget does not re-fire
`OnValueChanged`). Watch for one behavior delta: `P:Refresh` early-returns while `bulkDepth > 0`
(`settings/Panel.lua:462`), so a bulk reset now repaints the storage line once at the end instead of
per row — which is the intended behavior of `P:Batch`, not a regression.

**Standards conformance:** `options-ui-§11` (refresh scalars in place; scope structural rebuilds to
the on-screen subcategory) and anti-pattern #39. Explicitly does **not** add a second refresh
registry (anti-pattern #47).

### C-003 — Restore the LibStub registry key and sweep the rename artifacts

**Closes:** F-003 · **Files:** `settings/Panel.lua`

```lua
-- settings/Panel.lua:379   before
local minor = LibStub and LibStub.minors and LibStub.minors["O.AceGUI-3.0"]
-- after
local minor = LibStub and LibStub.minors and LibStub.minors["AceGUI-3.0"]
```

Plus prose at `settings/Panel.lua:21`, `:302`, `:309`: "O.AceGUI Headings" → "AceGUI Headings",
"an O.AceGUI teardown" → "an AceGUI teardown" (twice).

**Risk:** None — the value is read only by `/bl debug panel`.

### C-004 — UTF-8-safe truncation

**Closes:** F-004 · **Files:** `modules/InsightsWidgets.lua`

```lua
-- modules/InsightsWidgets.lua — W.Truncate, after the length test
-- Walk back off any UTF-8 continuation byte (0x80-0xBF) before slicing. The labels this cuts are
-- item types, sub-types, zone names and character names — all of which the client returns
-- LOCALIZED, so on a deDE/frFR/ruRU client a byte-boundary cut lands mid-codepoint and renders a
-- broken glyph (localization). Markup still must NOT be concatenated in before the cut: a |T...|t
-- escape is ASCII and would survive this guard while still being sliced in half.
local cut = maxChars - 1
while cut > 0 do
  local b = text:byte(cut + 1)
  if not b or b < 0x80 or b > 0xBF then break end
  cut = cut - 1
end
return text:sub(1, cut) .. "\226\128\166", true
```

The existing markup caveat in the header comment stays; only the "English-only labels, so a
byte-based sub is safe" sentence is replaced.

**Risk:** Low. Behavior on pure-ASCII input is byte-identical, so every existing case in
`tests/test_insights.lua` holds. Add one case with a multi-byte label asserting the result is valid
UTF-8 and no longer than the budget.

**Standards conformance:** `localization` (correct handling of client-returned localized text).
Rejected alternative — pushing the helper upstream into LibKa0s — is the compliant *long-term*
direction under `library-stack-§7` and is recorded as a follow-up, not done here.

### C-005 — Use the Context enum where a context is meant

**Closes:** F-005 · **Files:** `modules/Ledger.lua`

```lua
-- modules/Ledger.lua:672   before → after
if context == C.Store.GUILD_BANK then      →   if context == C.Context.GUILD_BANK then
-- modules/Ledger.lua:702   before → after
self:OpenContext(C.Store.GUILD_BANK)       →   self:OpenContext(C.Context.GUILD_BANK)
```

**Risk:** None — the two constants are equal today, so this is a no-op at runtime and a rename-safety
fix in intent. `tests/test_ledger.lua` exercises both paths and must stay green unchanged.

### C-006 — Close events carry their own context

**Closes:** F-006 · **Files:** `modules/Ledger.lua`

```lua
-- before (modules/Ledger.lua:727-730, 770-772)
local CLOSE_EVENTS = { BANKFRAME_CLOSED = true, GUILDBANKFRAME_CLOSED = true }
...
for event in pairs(CLOSE_EVENTS) do
  self:RegisterEventSafely(addon, event, function() L:CloseContext() end)
end

-- after — mirrors OPEN_EVENTS, which already maps event → context
local CLOSE_EVENTS = {
  BANKFRAME_CLOSED      = C.Context.BANK_FRAME,
  GUILDBANKFRAME_CLOSED = C.Context.GUILD_BANK,
}
...
for event, context in pairs(CLOSE_EVENTS) do
  -- Only ever closes the context the event BELONGS to. The guild bank is armed by data arrival
  -- rather than by an open event (L:OnGuildBankData), so a bank-frame close can reach us while a
  -- guild-bank baseline is live — and tearing that down loses the visit. Same guard, and the same
  -- reasoning, as L:HookGuildBankFrame's OnHide hook.
  self:RegisterEventSafely(addon, event, function()
    if NS.State.openContext == context then L:CloseContext() end
  end)
end
```

**Risk:** Low, but this is the one behavioral change in the set — it stops a close event that
previously disarmed. Verify the ordinary bank-close path still ends the session (smoke test
`03_SMOKE_TESTS.md` § C-006) and that the guild-bank `OnHide` close is unaffected.

### C-007 — Comment corrections

**Closes:** F-007, F-008 · **Files:** `core/CoreSetup.lua`, `core/Database.lua`

- `core/CoreSetup.lua:23`: `tests/test_toc.lua` → `tests/test_libka0s.lua` (the assertions are at
  its lines 310-345).
- `core/Database.lua:136`: `(see docs/data-model.md)` → `(see docs/ARCHITECTURE.md)`, or drop the
  parenthetical. **Do not create a new doc** — `documentation-§3` pins the `docs/` trio.

**Risk:** None.

### C-008 — The options stub stops copying a library constant

**Closes:** F-009 · **Files:** `settings/OptionsSetup.lua`

```lua
-- settings/OptionsSetup.lua:160   before → after
ROW_VSPACER = 0, SECTION_HEADING_H = 0, BUTTON_PAIR_REL = 0.5,
ROW_VSPACER = 0, SECTION_HEADING_H = 0, BUTTON_PAIR_REL = 0,
```

**Risk:** None — the stub only runs when no panel is drawn.

**Standards conformance:** anti-pattern #47 (no library constants copied into a stub) and
anti-pattern #31 (`0.5` is specifically the wrong paired-button width; the library's is `0.492`).
The compliant remedy is zero, **not** copying `0.492` across.

### C-009 — Dead-code sweep

**Closes:** F-010 · **Files:** `core/Compat.lua`, `modules/Filters.lua`, `modules/LedgerTable.lua`,
`modules/Insights.lua`, `settings/Slash.lua`

1. **Delete** `Compat.QualityFromLink` (`core/Compat.lua:184-190`) together with the `qualityByHex`
   upvalue and `buildQualityByHex` (`core/Compat.lua:172-182`) it exists solely to feed. Zero
   callers in `core/ modules/ settings/` **and** zero in `tests/`. Confirm with
   `grep -rn QualityFromLink .` (excluding `libs/`) before deleting.
2. **Keep and annotate** the other five. Each is a pure function the suite pins as a seam; add one
   line above each saying so, e.g. above `LT:CellText`:
   `-- Pure seam: the UI binds through LT:PaintCell; this is the text half, kept addressable so
   tests/test_ledgertable.lua can assert a cell's text without a client.`
   Same for `F:IsBlacklisted` / `F:IsWhitelisted`, `I.BarFraction`, `Sl:BuildListLines`.

**Risk:** Low. The delete is the only removal; run `lua tests/run.lua` immediately after.

### C-010 — Insights section renumbering

**Closes:** F-011 · **Files:** `modules/Insights.lua`

Renumber the `LayoutSections` walkthrough comments consecutively (`1`…`12` as they actually appear,
`4` and `6` filled, the duplicate `5` resolved). Comment-only.

### C-011 — Panel whitespace + duplicated paragraph

**Closes:** F-012 · **Files:** `settings/Panel.lua`

Collapse the blank runs at `:40-42`, `:62-67`, `:78-80`, `:119-120`, `:171-173` to a single blank
line; delete the earlier of the two duplicated "Test seam over the … registry" paragraphs
(`:451-455`), keeping the one that says "the library's page registry".

### C-012 — Guard the Export → Browser reach

**Closes:** F-013 · **Files:** `modules/Export.lua`

```lua
-- modules/Export.lua:331   before
local ds = NS.Browser:MakeDropdown(frame, 148)
-- after — matches the four other Browser reaches in this file
if not (NS.Browser and NS.Browser.MakeDropdown) then return frame end
local ds = NS.Browser:MakeDropdown(frame, 148)
```

**Risk:** None; unreachable today given the TOC order.

### C-013 — `EndSession` clears the preview flag

**Closes:** F-014 · **Files:** `modules/SessionWindow.lua`

Add `SW.previewSession = false` alongside the other resets in `SW:EndSession`
(`modules/SessionWindow.lua:136-144`), with a one-line note that the two flags are one state machine
and every transition resets both.

### C-014 — `PruneOld` broadcasts only when it pruned

**Closes:** F-016 · **Files:** `core/Database.lua`

```lua
-- core/Database.lua, in Database:PruneOld — before
NS.db.global.ledger = kept
fireLedgerChanged()
-- after — the header already claims this ("Fires LedgerChanged when it actually runs")
NS.db.global.ledger = kept
if removed > 0 then fireLedgerChanged() end
```

**Risk:** Low. Check `tests/test_database.lua` for a case asserting the message fires on a zero-row
prune; if one exists it is asserting the bug and should be inverted with a note.

---

## Deferred

- **F-015 (`Database:Stats` size / hotness).** Not changed. Splitting a deliberate single-pass
  aggregator into several passes trades the property that makes it correct (every breakdown sees the
  same filtered set exactly once) for readability, and there is no measured evidence it is a
  problem. The compliant way to get that evidence is `performance-§1`'s harness — which this addon
  has vendored but not wired — so the honest next step is the `PerfSetup` adoption the next
  `standards-audit` will raise, with `Stats` as its first declared bucket. Recorded, not actioned.
</content>
