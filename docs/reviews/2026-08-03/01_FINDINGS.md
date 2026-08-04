# Ka0s Bank Ledger — Review Findings (2026-08-03)

**Verdict: minor issues.** The addon is coherent, well-layered and unusually well-commented; the
suite is green (689 passed, 0 failed) and `luacheck .` is clean (0 warnings / 0 errors in 24 files).
Nothing here blocks a ship. Two issues are worth fixing before the next release — one user-visible
chat line that escapes the mandated `[BL]` tag, and one settings-panel bus handler that keeps a
reference to a released AceGUI widget.

## Standards cross-check — how it was resolved

The Ka0s WoW Addon Standard **was** consulted, at **v2.17.1 (2026-08-03)**. The prescribed
`curl` fetch of `standards/STANDARDS.md` and its Sections list from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` **timed out** partway
through (3 of 24 section files retrieved). The remainder was read from the **canonical repository
itself**, which happened to be the working directory of this run
(`/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards`, branch `master`, working tree
clean, HEAD `2141229 v2.17.1`) — i.e. the same bytes the raw URL serves, not a reconstruction from
memory. Remediation in `02_PROPOSED_CHANGES.md` is therefore vetted normally; no rule was invented.

## Scope note — what is deliberately NOT raised here

This is a review, not a compliance audit (`wow-addon:standards-audit` owns that). One pre-existing
standard deviation was noticed and is **recorded here only as a pointer, not as a finding**, because
it is unrelated to any problem below: `libs/LibKa0s/Perf.lua` + `PerfPanel.lua` are vendored (whole
folder, correctly — anti-pattern #48) but nothing wires them. There is no `core/PerfSetup.lua`, no
`perf` verb in `NS.COMMANDS` (`settings/Schema.lua:226`), no second SavedVariables global in
`BankLedger.toc:7`, and no `docs/performance.md` / `docs/perf-runs/`. That is `performance-§1`'s
MUST and belongs in the next audit's deviation list, not in this review's change-set.

## Upstream findings

**None.** No defect was found in `libs/` or `tests/_kit/`. `tests/test_vendor_sync.lua` pins the
vendored LibKa0s payload to the release the README names and passes, and every library seam this
addon reaches behaved as its descriptor documents. Nothing in this review proposes an edit under
`libs/` or `tests/_kit/`.

---

## High

### F-001 · `[convention]` `[ux]` — two view messages bypass the shared `[BL]` printer

**Where:** `modules/Browser.lua:855`, `modules/Browser.lua:864`

**Problem:** `modules/Browser.lua` calls `print(...)` twice but never declares
`local print = NS.Print`; the calls therefore resolve to Blizzard's **global** `print`.

```lua
-- modules/Browser.lua:852-865
function B:SaveView()
  if not (NS.db and NS.db.global) then return end
  NS.db.global.savedView = self:CaptureView()
  print("view saved as your default.")        -- global print, no [BL] tag
end
...
  if not silent then print("view reset to stock defaults.") end   -- same
```

Every other user-facing file in the addon takes the upvalue — `modules/LedgerTable.lua:5`,
`settings/Schema.lua:5`, `settings/Slash.lua:4`, `settings/Panel.lua:4`,
`settings/OptionsSetup.lua:20` — and `core/CoreSetup.lua:20` enumerates exactly which files are
expected to. `modules/Browser.lua` is absent from that list and from the code.

**Impact:** Pressing **Save** or **Reset** on the ledger window's filter bar prints an untagged
line into chat. A user running several Ka0s addons cannot tell which one spoke, and the line skips
the secret-safe stringifier every other line goes through. This is invisible to both gates:
`luacheck` treats `print` as a `lua51` std global, and `tests/test_browser.lua:158-262` exercises
`SaveView`/`ResetView` without ever asserting on the output.

**Fix direction:** Add the file-scope `local print = NS.Print` upvalue that the other five files
already carry (`slash-commands-§4`, and the same reclaim contract `architecture-§2` describes).
Do **not** substitute a locally-formatted tag — the printer is the seam.

### F-002 · `[design]` `[bug]` — the Storage panel's bus handler outlives the widget it writes to

**Where:** `settings/Panel.lua:159-169` (registration), `settings/Panel.lua:141-157` (the captured
closure), `settings/Panel.lua:311` (the re-render trigger)

**Problem:** `renderStorage` registers its live-refresh handler behind a one-shot guard:

```lua
-- settings/Panel.lua:161-169
if not P.__ev then
  local ev = NS.NewBusTarget()
  if ev then
    local onChange = function() if ctx.panel:IsShown() then refreshStats() end end
    ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", onChange)
    ev:RegisterMessage("Ka0s_BankLedger_EntryAdded", onChange)
    P.__ev = ev
  end
end
```

`onChange` closes over `refreshStats`, which closes over `statsLabel` — an AceGUI `Label` created in
*this* render pass. Every renderer begins with `O.ClearScroll` (`settings/Panel.lua:538`,
`settings/Panel.lua:592`), which releases the pass's widgets back to AceGUI's pool; the file's own
comment at `settings/Panel.lua:507-509` states this. A structural re-render **does** happen: the
Filters page registers `ev:RegisterMessage("Ka0s_BankLedger_LedgerChanged", function()
O.RefreshAllPanels() end)` at `settings/Panel.lua:311`, and `O.RefreshAllPanels` re-runs each page's
renderer. After that first re-render, `P.__ev` is still holding the **old** closure.

**Impact:** Two failure modes, both silent. (1) The General page's "N movements recorded over M
days / Database size ≈ …" line stops live-updating, because the handler repaints a label that is no
longer on screen. (2) Worse, the released `Label` may already have been re-acquired by another
AceGUI consumer, in which case the handler writes Bank Ledger's storage summary into an unrelated
widget. Neither raises, and a `/reload` masks both.

**Fix direction:** Keep one bus target but stop pinning the *widget*. Either re-point the handler at
the page's current context on each render (the renderer already stores `P.general = ctx`), or drop
the private handler entirely and let the library's own refresher registry carry it — `refreshStats`
is already pushed into `ctx.refreshers` at `settings/Panel.lua:156`, and `P:Refresh` →
`O.RefreshScalars()` is the sanctioned path (`options-ui-§11`). Do **not** fix it by hand-rolling a
local refresh registry alongside the library's (anti-pattern #47).

---

## Medium

### F-003 · `[bug]` — a rename sweep caught a LibStub registry key

**Where:** `settings/Panel.lua:379`

**Problem:** `local minor = LibStub and LibStub.minors and LibStub.minors["O.AceGUI-3.0"]`. The
registry key is `"AceGUI-3.0"`; `"O.AceGUI-3.0"` is the local variable name `O.AceGUI` pasted into a
string literal by a find-and-replace. The same sweep left prose artifacts at `settings/Panel.lua:21`
("O.AceGUI Headings group them into sections"), `settings/Panel.lua:302` and
`settings/Panel.lua:309` ("every tab click paying an O.AceGUI teardown").

**Impact:** `/bl debug panel` — the diagnostic written specifically to catch the AceGUI load-order
skinning race (anti-pattern #42) — always reports `minor=nil`, so the one number that identifies
*which copy of AceGUI served the widget* is permanently missing from the dump.

**Fix direction:** Restore the literal `"AceGUI-3.0"`; sweep the three prose occurrences back to
"AceGUI".

### F-004 · `[locale]` — `W.Truncate` cuts UTF-8 on byte boundaries and its comment says that is safe

**Where:** `modules/InsightsWidgets.lua:80-85`; callers `modules/Insights.lua:63`,
`modules/Insights.lua:313`, `modules/Insights.lua:363`

**Problem:**

```lua
-- modules/InsightsWidgets.lua:76-85
-- Cap a label to a glyph count with a trailing ellipsis. English-only labels, so a byte-based sub is
-- safe. ...
  return text:sub(1, maxChars - 1) .. "\226\128\166", true
```

The premise is wrong for three of the label sources. Item **type** and **sub-type** come from
`C_Item.GetItemInfo` via `NS.Compat.GetItemDetails` (`core/Compat.lua:209`) and are returned already
translated; zone names come from `GetZoneText` (`core/Compat.lua:33`); character names are whatever
the player named the alt. On a deDE / frFR / ruRU / koKR / zhCN client a truncation at
`maxChars - 1` bytes lands inside a multi-byte sequence.

**Impact:** Insights bar labels, stacked-bar labels and legend chips render a broken glyph (or a
missing one) on every non-enUS client, for exactly the categories the panel exists to break down.
Invisible to an English-speaking author and to the headless suite, whose fixtures are ASCII.

**Fix direction:** Make the cut codepoint-aware — walk UTF-8 continuation bytes (`0x80-0xBF`) back
from the cut index before slicing, or count codepoints rather than bytes. Keep it in
`InsightsWidgets` (it is this addon's own primitive, not a library one), and correct the comment:
the *markup* caveat it also carries is real and must survive.

### F-005 · `[design]` — a `Store` value is passed where a `Context` value is meant

**Where:** `modules/Ledger.lua:672`, `modules/Ledger.lua:702`

**Problem:** `core/Constants.lua:28-40` separates `C.Context` (which storage **frame** is open) from
`C.Store` (which **store** a movement targets) and documents in as many words that they are
different axes, sharing only the literal `"GUILD_BANK"` "on purpose". Two call sites cross the axes:

```lua
-- modules/Ledger.lua:672
  if context == C.Store.GUILD_BANK then      -- comparing a Context against a Store
-- modules/Ledger.lua:702
    self:OpenContext(C.Store.GUILD_BANK)     -- passing a Store as a Context
```

**Impact:** No behavior change today — the two constants evaluate equal. But the whole point of
`C.Context` is that a store key may be renamed independently; `C.Store` values are further pinned as
"the CSV export contract" (`core/Constants.lua:6`). If either side ever moves, the guild bank stops
arming and nothing errors: `L:OnGuildBankData` would simply set a context nothing routes.

**Fix direction:** Use `C.Context.GUILD_BANK` at both sites. `L.CONTEXT_STORES`
(`modules/Ledger.lua:30-33`) already keys off `C.Context` correctly and needs no change.

### F-006 · `[bug]` — a bank-frame close event disarms whatever context is armed

**Where:** `modules/Ledger.lua:727-730`, `modules/Ledger.lua:770-772`

**Problem:** Both close events register the same context-blind handler:

```lua
-- modules/Ledger.lua:727-730, 770-772
local CLOSE_EVENTS = { BANKFRAME_CLOSED = true, GUILDBANKFRAME_CLOSED = true }
...
for event in pairs(CLOSE_EVENTS) do
  self:RegisterEventSafely(addon, event, function() L:CloseContext() end)
end
```

`L:CloseContext` (`modules/Ledger.lua:707`) closes `NS.State.openContext` unconditionally. The
frame's own OnHide hook gets the same problem right — `modules/Ledger.lua:661` guards with
`if NS.State.openContext == C.Context.GUILD_BANK then` and its comment explains precisely why
("closing the character bank's context on that basis would throw away a baseline that is still in
use") — but the event path has no such guard.

**Impact:** A `BANKFRAME_CLOSED` arriving while the guild-bank context is armed (the guild bank is
armed by **data arrival**, not by an open event — `modules/Ledger.lua:699-705` — so the two can
interleave in ways the open events cannot) tears down a live guild-bank baseline and fires
`SessionChanged(false)`, closing the session window mid-visit and losing any in-flight movement.
Narrow, but real, and the mirror-image guard already exists eight lines away.

**Fix direction:** Give each close event the context it belongs to, exactly as `OPEN_EVENTS`
(`modules/Ledger.lua:723-726`) already maps event → context, and have the handler no-op when the
armed context is not the event's.

### F-007 · `[docs]` — a comment names a test file that does not exist

**Where:** `core/CoreSetup.lua:23`

**Problem:** "tests/test_toc.lua pins every one of those orderings against the shipped TOC." There
is no `tests/test_toc.lua`. The assertions do exist — `tests/test_libka0s.lua:310-345` reads the TOC
and asserts the seam ordering — so the guard is real and the pointer is wrong.

**Impact:** A maintainer looking for the guard does not find it, concludes the ordering is unpinned,
and either re-writes it or moves a seam believing nothing will catch it.

**Fix direction:** Point the comment at `tests/test_libka0s.lua`.

### F-008 · `[docs]` — a comment names a design doc that does not exist

**Where:** `core/Database.lua:136`

**Problem:** "Plain, metatable-free copy of the (optionally filtered) ledger — the
forward-compatible export contract (see docs/data-model.md)." `docs/` holds `ARCHITECTURE.md`,
`testing.md`, `smoke-tests.md`, `test-cases.md` and the frozen `audits/` + `reviews/` bundles. There
is no `data-model.md`.

**Impact:** The stated *contract* for the export shape has no referent, which matters because
`Database:Export` (`core/Database.lua:137-149`) is the field list a user's spreadsheet is keyed on.

**Fix direction:** Point at wherever the shape is actually documented (`docs/ARCHITECTURE.md`) or
drop the parenthetical. Note that `documentation-§3` pins the canonical `docs/` **trio**
(`ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`) — adding a fourth doc purely to satisfy this
comment is the wrong direction.

### F-009 · `[design]` — the options stub copies a library constant, and copies it wrong

**Where:** `settings/OptionsSetup.lua:157-160`

**Problem:**

```lua
-- settings/OptionsSetup.lua:157-160
-- The layout constants a host page reads off the instance. Zero rather than a copied number:
-- anti-pattern #47 forbids carrying the library's values into a stub, and a spacer of zero on a
-- panel that cannot be drawn costs nothing.
ROW_VSPACER = 0, SECTION_HEADING_H = 0, BUTTON_PAIR_REL = 0.5,
```

Two of the three follow the comment; the third does not. And `0.5` is not merely *a* copy — it is
the specific value anti-pattern #31 calls out as wrong (the library's is `0.492`, the inset that
keeps a paired button's right border clear of the `ScrollFrame` clip).

**Impact:** Harmless today, because the stub only runs when no panel can be drawn at all. It is a
latent trap: `makePairButton` (`settings/Panel.lua:70-76`) reads `O.BUTTON_PAIR_REL`, so if the
degraded surface ever grows a drawn widget, the addon ships the exact defect #31 names — and the
comment beside the line asserts the opposite is true.

**Fix direction:** `BUTTON_PAIR_REL = 0`, matching its two neighbors and the comment.

---

## Low

### F-010 · `[dead-code]` — six exported members with no in-addon callers

**Where / evidence** (each verified by `grep -rn <name> core modules settings` returning only the
definition):

| Member | Defined | In-addon callers | Test callers |
| --- | --- | --- | --- |
| `NS.Filters:IsBlacklisted` | `modules/Filters.lua:40` | 0 | 3 |
| `NS.Filters:IsWhitelisted` | `modules/Filters.lua:45` | 0 | 1 |
| `NS.LedgerTable:CellText` | `modules/LedgerTable.lua:98` | 0 | 26 |
| `NS.Insights.BarFraction` | `modules/Insights.lua:52` | 0 | 6 |
| `NS.Slash:BuildListLines` | `settings/Slash.lua:217` (+ stub `:119`) | 0 | 9 |
| `NS.Compat.QualityFromLink` | `core/Compat.lua:184` | 0 | 0 |

The capture gate reads the cached `DB_BLACKLIST` / `DB_WHITELIST` upvalues
(`modules/Ledger.lua:391-392`) rather than the `Is*` predicates; the table binds through
`LT:PaintCell` rather than `LT:CellText`; `RenderBars` normalizes through `W.NormalizeFractions`
rather than `I.BarFraction`.

**Impact:** Surface that looks load-bearing and is not. `NS.Compat.QualityFromLink` is the notable
one — it has no caller at all, not even a test, and it carries a lazily-built module-level cache
(`core/Compat.lua:173-190`) that nothing populates.

**Fix direction:** Keep the ones the tests genuinely pin as *pure-function seams* and say so in a
one-line comment; delete `NS.Compat.QualityFromLink` and its `qualityByHex` cache, which nothing
anywhere reaches. Note the addon exposes no `NS.API.v1` (`public-api` does not apply), so none of
these is a published surface.

### F-011 · `[naming]` — the Insights section numbering in comments is wrong

**Where:** `modules/Insights.lua:600, 628, 640, 662, 682, 689, 708, 732, 743, 752`

The `LayoutSections` walkthrough numbers its sections `1, 2, 3, 5, 5, 7, 8/9, 10, 11, 12` — `4` and
`6` never appear and `5` appears twice. The prose is otherwise the clearest in the file, which is
what makes the counting a live source of confusion when a section is added or moved.

### F-012 · `[naming]` — leftover whitespace and a duplicated comment in `Panel.lua`

**Where:** `settings/Panel.lua:40-42`, `:62-67`, `:78-80`, `:119-120`, `:171-173`, and
`settings/Panel.lua:451-458`

Runs of three to seven blank lines mark where code was removed during the LibKa0s-Options adoption.
At `:451-458` the same explanation is written twice back to back ("Test seam over the private
registry. The page bodies are lazy…" / "Test seam over the library's page registry. The page bodies
are lazy…") — the first is the pre-adoption wording.

### F-013 · `[design]` — one unguarded cross-module reach in `Export.lua`

**Where:** `modules/Export.lua:331`

`local ds = NS.Browser:MakeDropdown(frame, 148)` is unguarded, while every other Browser reach in
the same file is presence-guarded (`modules/Export.lua:242`, `:258`, `:326`, `:350`). The TOC
guarantees `modules/Browser.lua` loads first, so this cannot fire today — but the file's own
convention says otherwise on four other lines.

### F-014 · `[design]` — `EndSession` does not clear `previewSession`

**Where:** `modules/SessionWindow.lua:136-144`

`SW:EndSession` resets `NS.State.sessionActive`, `SW.context` and `NS.State.sessionEntries`, but
leaves `SW.previewSession` as it found it. `SW:StartSession` (`modules/SessionWindow.lua:128`) does
clear it, and today every `EndSession` is preceded by a `StartSession`, so the flag cannot actually
go stale. It is an unasserted invariant in a two-flag state machine where `SW:TogglePreview`
(`modules/SessionWindow.lua:218-230`) and `SW:PruneMissing` (`modules/SessionWindow.lua:159`) both
branch on it.

### F-015 · `[perf]` `[design]` — `Database:Stats` is a 295-line single pass

**Where:** `core/Database.lua:206-500`

One function accumulates 25+ breakdown maps and runs roughly fifteen `table.sort` calls, and it is
the addon's hottest read path: every Insights refresh (`modules/Insights.lua:214`), every filter
apply while the Insights tab is up (`modules/Browser.lua:639-641`), and both Insights export
providers (`modules/Browser.lua:1035-1036`) call it. The single-pass design is deliberate and
correct, and the file is under the 1500-LOC ceiling (`anti-patterns` #16) at 549 lines — this is
recorded as the addon's most likely future perf hotspot and its least-splittable unit, not as a
defect. It is also the natural first `Perf` bucket if and when `performance-§1` is adopted.

### F-016 · `[perf]` — `PruneOld` broadcasts a change even when it changed nothing

**Where:** `core/Database.lua:533-549`

The header says "Fires LedgerChanged when it actually runs", but `fireLedgerChanged()` is called
unconditionally after the rebuild-and-swap, including when `removed == 0`. `PruneOld` runs on every
login (`core/BankLedger.lua:52-59`, five seconds after `PLAYER_ENTERING_WORLD`) and on every
`retentionDays` change (`settings/Schema.lua:86-88`), so a typical session pays one spurious
full-window repaint plus, if the settings panel is open, one whole-ledger `StorageStats` walk
(`settings/Panel.lua:142`) for a prune that dropped nothing.

---

## Areas checked and found clean

Stated explicitly so the absence of findings reads as a result rather than as an omission.

- **Taint / combat lockdown.** No protected API is called anywhere. Every window is a plain
  non-secure `CreateFrame` on `UIParent` with no attributes and no secure templates, so
  `standalone-windows` correctly imposes no combat gate. `Settings.RegisterCanvasLayoutSubcategory`
  is reached only through `NS.Panel:Register` at `OnInitialize` (`core/BankLedger.lua:36`), and
  `P:Open` delegates the in-combat refusal to `O.OpenOptionsPanel` (`settings/Panel.lua:603-608`)
  rather than duplicating it. `L:HookGuildBankFrame` uses `HookScript` on a non-secure frame.
- **Secret values.** No protected-API return is bound and re-read. Every chat path except F-001
  routes through `NS.Print` → `LibKa0s-Core-1.0`'s secret-safe stringifier, and `core/Compat.lua:47`
  documents why money is safe.
- **Event registration.** All registration happens in `OnEnable` (`core/BankLedger.lua:39-49` →
  `L:Enable`, `B:Enable`, `SW:Enable`), each guarded by an `_enabled` latch.
  `L:RegisterEventSafely` (`modules/Ledger.lua:753-758`) isolates each `RegisterEvent` in a `pcall`
  so one retired name cannot deafen the addon, and records both lists for `/bl debug scan`.
  `BAG_UPDATE_DELAYED` is used, not `BAG_UPDATE`.
- **Deprecated APIs.** Every varying call is behind `core/Compat.lua`: `C_AddOns.GetAddOnMetadata`,
  `C_Container.GetContainerNumSlots` / `GetContainerItemInfo`, `C_Item.GetItemInfo`,
  `C_Bank.FetchDepositedMoney`, `C_Map.GetBestMapForUnit`. No `GetSpellInfo`, no `UnitAura`, no
  `IsAddOnLoaded`, no `InterfaceOptions_AddCategory`. Every `SetBackdrop` target is created with
  `"BackdropTemplate"` (verified across all 15 `SetBackdrop` call sites).
- **Frames and pooling.** Both tables and every Insights primitive are pooled
  (`modules/LedgerTable.lua:533`, `modules/SessionWindow.lua:297`,
  `modules/InsightsWidgets.lua:331-347`); `W.ReleasePanels` correctly drains each panel's own row
  pool. Only the five windows carry global names; every other frame is anonymous. No `setmetatable`
  on a widget.
- **SavedVariables.** One AceDB global tree, one shipped defaults table, `NS.SCHEMA_VERSION`
  (`core/Namespace.lua:13`) as the single source for both the default and the migration target, and
  an idempotent `NS:RunMigrations` invoked before any ledger read (`core/Database.lua:5-32`). The
  write seam is honored: every settings mutation goes through `NS.Schema:Set`, and the three
  carve-outs (window geometry, the id-lists, `savedView`) are documented as such at
  `defaults/Global.lua:18-30` and mutated only by their owning module.
- **Bus discipline.** Every receiver owns a private `NS.NewBusTarget()` target — never
  `NS.bus`-as-self — at `modules/Ledger.lua:785`, `modules/Browser.lua:1296`,
  `modules/SessionWindow.lua:650`, `modules/Insights.lua:906`, `settings/Panel.lua:162` and `:304`
  (anti-pattern #32). One sender per message: `Ka0s_BankLedger_LedgerChanged` funnels through
  `Database:FireLedgerChanged` (`core/Database.lua:456-461`) even for `NS.Filters`'s own writes.
- **Slash surface.** `NS.COMMANDS` (`settings/Schema.lua:226-286`) and the README's command table
  (`README.md:82-98`) match one for one, in both directions, including the `debug scan` /
  `debug panel` sub-verbs. Every degradation-stub member in `settings/Slash.lua:118-153` answers a
  real call site, and `CliResetAll` correctly *works* rather than merely explaining itself.
- **Localization.** `NS.L` is a metatable-fallback table (`locales/enUS.lua:6`), and the file states
  plainly that v1.0.0 ships English-only with no string routed through it yet — a scope decision,
  not a broken locale. No `L[...]` key is referenced anywhere, so no key can be missing. No game
  data is matched against a localized display string (anti-pattern #37): quality resolves by id
  (`core/Compat.lua:198-201`), containers by `Enum.BagIndex` **member name**
  (`core/Constants.lua:106-134`), bank type by `Enum.BankType.Account` read by name
  (`core/Compat.lua:78`). US-English spelling holds throughout the authored text I read
  (anti-pattern #46). F-004 is the one localization defect found, and it is a byte-handling bug
  rather than a string-sourcing one.
- **Gates.** `lua tests/run.lua` → **689 passed, 0 failed**. `luacheck .` → **0 warnings, 0 errors
  in 24 files**. `.gitattributes` declares CRLF for `.lua`/`.xml`/`.toc`/`.md`. `.pkgmeta` has no
  `externals:` and ignores `docs`, `tests` and the non-shippable art.
</content>
</invoke>
