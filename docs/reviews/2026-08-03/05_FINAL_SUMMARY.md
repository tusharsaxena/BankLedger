# Ka0s Bank Ledger — Final Summary (2026-08-03)

> **Status: written ahead of implementation.** This document is the "what shipped" record for the
> 2026-08-03 review cycle, written on the assumption that every change in
> `02_PROPOSED_CHANGES.md` has been applied and every test in `03_SMOKE_TESTS.md` has passed. Until
> the sign-off table in `03_SMOKE_TESTS.md` is filled in and the commit range below is real, treat
> this as the intended summary rather than as a completed one.

## Headline

A full-scope review of Ka0s Bank Ledger found the addon in good health — green suite, clean lint, a
coherent module layout, and library seams (LibKa0s Core / DebugLog / Options / Slash) wired the way
the standard describes. Sixteen findings came out of it, none critical. The work in this cycle
closes two real user-visible defects — two chat lines that escaped the addon's cyan `[BL]` tag, and
a settings-panel handler that kept writing into an AceGUI widget after that widget had been released
back to the pool — and then removes a set of smaller traps: a `Store` constant used where a
`Context` was meant, a bank-close event that could tear down a live guild-bank session, a label
truncator that cut UTF-8 on byte boundaries and would have rendered broken glyphs on every non-English
client, a diagnostic that always printed `nil` because a rename sweep caught a string literal, and
four places where a comment or a constant asserted something that was not true.

Nothing about the addon's architecture changed. Every fix is the code rejoining a convention it
already follows somewhere else in the same repository.

## Counts

`Critical fixed: 0, High fixed: 2, Medium fixed: 7, Low fixed: 6`

**Deliberately deferred:**

- **F-015** — `Database:Stats` is a 295-line single-pass aggregator and the addon's hottest read
  path. Left alone: the single pass is what guarantees every breakdown sees the same filtered set
  exactly once, and there is no measured evidence it is slow. The honest next step is wiring
  `LibKa0s-Perf-1.0` (already vendored, not yet wired) and declaring `Stats` as its first bucket —
  which is the next `wow-addon:standards-audit`'s work, not this review's.

**Noted but out of scope (routed to the next standards audit):** `performance-§1` is unadopted —
`libs/LibKa0s/Perf.lua` and `PerfPanel.lua` are correctly vendored as part of the whole folder, but
there is no `core/PerfSetup.lua`, no `perf` verb, no `BankLedgerPerfDB`, and no `docs/performance.md`
/ `docs/perf-runs/`. Recorded in `01_FINDINGS.md`; no change in this cycle touches it.

## Changes by theme

### Theme A — Close the two seams that leak past a shared surface

**What changed.** `modules/Browser.lua` now takes the same `local print = NS.Print` file-scope
upvalue its five siblings already carry, so the ledger window's **Save** and **Reset** view messages
print with the cyan `[BL]` tag and through the secret-safe stringifier like every other line the
addon emits. On the settings side, the General page's Storage refresher no longer registers a bus
handler that closes over a specific AceGUI `Label`; it delegates to the library's page registry, so
the live "N movements recorded over M days / Database size ≈ …" line keeps updating after the panel
has re-rendered instead of silently repainting a pool-recycled widget.

**Why it mattered.** Both were shortcuts around a shared seam, and both were invisible to every
gate the project runs. `luacheck` cannot see the printer leak (`print` is a `lua51` standard
global), and the suite exercised `SaveView`/`ResetView` without ever asserting on their output. The
panel leak was worse than a stale label: a released AceGUI widget goes back into a shared pool, so
after a structural re-render the handler could write Bank Ledger's storage summary into an unrelated
addon's label — with no error, masked by a `/reload`.

**Finding IDs covered:** F-001, F-002 · **Change IDs implemented:** C-001, C-002

**Files touched:**
- `modules/Browser.lua`
- `core/CoreSetup.lua`
- `settings/Panel.lua`
- `tests/test_browser.lua`
- `tests/test_panel.lua`

### Theme B — Make the enums and the event map say what they mean

**What changed.** The two sites in `modules/Ledger.lua` that compared or passed a `C.Store` value
where a `C.Context` value was meant now use `C.Context`. `CLOSE_EVENTS` became an event→context map,
mirroring `OPEN_EVENTS`, and its handler no-ops unless the armed context is the one the event
belongs to.

**Why it mattered.** `core/Constants.lua` deliberately keeps "which frame is open" and "which store
a movement targets" as separate axes — `C.Store` values are the persisted CSV export contract,
`C.Context` values are runtime-only — and says so in as many words. The two happened to share the
literal `"GUILD_BANK"`, so the crossed uses worked by coincidence; a rename on either side would
have stopped the guild bank arming with no error at all. The close-event change is the one with a
live consequence: the guild bank is armed by tab **data arriving**, not by an open event, so it can
be live when a `BANKFRAME_CLOSED` fires — and the old handler would have torn down that baseline
mid-visit, closing the session window and losing any in-flight movement. The correctly guarded
version of this logic already existed eight lines away, on the frame's own `OnHide` hook.

**Finding IDs covered:** F-005, F-006 · **Change IDs implemented:** C-005, C-006

**Files touched:**
- `modules/Ledger.lua`
- `tests/test_ledger.lua`

### Theme C — Correct the places where a comment or a constant lied

**What changed.** `/bl debug panel` reads the real LibStub registry key `"AceGUI-3.0"` again (a
rename sweep had turned it into `"O.AceGUI-3.0"`, which can never resolve), and the same sweep's
three prose artifacts are back to plain "AceGUI". Two comments that named files which do not exist
now point at the real ones — the TOC-ordering assertions are in `tests/test_libka0s.lua`, not a
`tests/test_toc.lua`, and the export shape is described in `docs/ARCHITECTURE.md`, not a
`docs/data-model.md`. The LibKa0s-Options degradation stub's `BUTTON_PAIR_REL` is `0` like its two
neighbors, matching the comment directly above it.

**Why it mattered.** In a codebase whose comments carry this much of the design rationale, a comment
that lies costs more than a missing one: a maintainer who looks for `tests/test_toc.lua`, fails to
find it, and concludes the load-order seams are unpinned will move one. The stub constant was worse
than a stale copy — `0.5` is the specific value the standard names as the wrong paired-button width
(the library's is `0.492`), sitting two lines under a comment explaining why library constants must
never be copied into a stub. And the diagnostic written specifically to catch the AceGUI
load-order skinning race was reporting `nil` for the one number that identifies which copy of AceGUI
actually served the widget.

**Finding IDs covered:** F-003, F-007, F-008, F-009 · **Change IDs implemented:** C-003, C-007,
C-008

**Files touched:**
- `settings/Panel.lua`
- `core/CoreSetup.lua`
- `core/Database.lua`
- `settings/OptionsSetup.lua`

### Theme D — Make truncation correct on non-English clients

**What changed.** `W.Truncate` walks back off any UTF-8 continuation byte before slicing, so an
Insights label is cut on a codepoint boundary. Its comment no longer claims the labels are
English-only; the separate (and still correct) caveat about never concatenating texture markup
before truncating survives.

**Why it mattered.** Three of the label sources arrive **localized** from the client — item type and
sub-type via `C_Item.GetItemInfo`, zone names via `GetZoneText`, and character names as the player
named them. On a deDE / frFR / ruRU / koKR / zhCN client the old byte-based cut landed inside a
multi-byte sequence and rendered a broken glyph, in exactly the charts the Insights panel exists to
present. It was invisible to an English-speaking author and to a headless suite whose fixtures are
ASCII.

**Finding IDs covered:** F-004 · **Change IDs implemented:** C-004

**Files touched:**
- `modules/InsightsWidgets.lua`
- `tests/test_insights.lua`

### Theme E — Housekeeping

**What changed.** `Compat.QualityFromLink` — an exported function with no caller anywhere in the
addon or its tests, carrying a lazily-built module-level cache nothing populated — is gone, along
with that cache. Five other exports with no in-addon callers are kept and annotated as what they
actually are: pure seams the suite pins so a behavior can be asserted without a client. The
`LayoutSections` walkthrough comments are numbered consecutively (they skipped 4 and 6 and used 5
twice). Leftover blank runs and one duplicated paragraph in `settings/Panel.lua` are collapsed. The
one unguarded `NS.Browser` reach in `modules/Export.lua` is presence-guarded like the four beside
it. `SW:EndSession` clears `previewSession`, so the session window's two-flag state machine resets
on every transition rather than most of them. And `Database:PruneOld` broadcasts `LedgerChanged`
only when it actually pruned something — which its own header comment already claimed.

**Why it mattered.** None of these was hurting a user today; together they are the difference
between a codebase whose surface means what it says and one where a reader has to check. The
`PruneOld` change is the one with a measurable effect: it runs on every login and previously paid a
full window repaint — plus, with the settings panel open, a whole-ledger byte-size walk — for a
prune that dropped nothing.

**Finding IDs covered:** F-010, F-011, F-012, F-013, F-014, F-016 · **Change IDs implemented:**
C-009, C-010, C-011, C-012, C-013, C-014

**Files touched:**
- `core/Compat.lua`
- `core/Database.lua`
- `modules/Filters.lua`
- `modules/LedgerTable.lua`
- `modules/Insights.lua`
- `modules/Export.lua`
- `modules/SessionWindow.lua`
- `settings/Slash.lua`
- `settings/Panel.lua`
- `tests/test_sessionwindow.lua`
- `tests/test_database.lua`

## API / behavior changes

Externally observable, in full:

| Change | Before | After |
| --- | --- | --- |
| Ledger window **Save** button | `view saved as your default.` (untagged) | `[BL] view saved as your default.` (cyan tag) |
| Ledger window **Reset** button | `view reset to stock defaults.` (untagged) | `[BL] view reset to stock defaults.` (cyan tag) |
| `/bl debug panel` first line | `AceGUI=yes minor=nil` (always) | `AceGUI=yes minor=<number>` |
| Settings ▸ General storage line | stopped live-updating after a Filters-page edit | keeps live-updating for the session |
| `BANKFRAME_CLOSED` while a guild-bank session is armed | closed the guild-bank session | ignored; only the guild bank's own close ends it |
| Login retention pass that prunes 0 rows | broadcast `LedgerChanged` (full repaint) | silent; the `[Prune]` debug line is unchanged |
| Insights labels on non-enUS clients | could end in a broken glyph | cut cleanly on a codepoint boundary |

**Not changed:** no slash subcommand added, renamed or removed (`NS.COMMANDS` and the README's
command table already matched one for one, in both directions, and still do). No new setting, no
removed setting, no changed default. No locale key added or renamed — v1.0.0 still routes no
user-facing string through `NS.L`, which remains a deliberate scope decision documented in
`locales/enUS.lua`.

## SavedVariables / migration notes

**None.** No change in this cycle touches the persisted shape. `NS.SCHEMA_VERSION` stays at `2`
(`core/Namespace.lua:13`), `NS:RunMigrations` is unchanged, and no existing profile needs migrating
or resetting. `/bl resetall` is not required after applying these changes.

## Deprecated-API migrations

**None.** The sweep found no deprecated or removed API in use. Every varying call already routes
through `core/Compat.lua`, and the modern forms are already in place:

| Old API | In use here? | Modern form already used | File |
| --- | --- | --- | --- |
| `GetAddOnMetadata` | fallback only, guarded | `C_AddOns.GetAddOnMetadata` | `core/Compat.lua:13-21` |
| `GetContainerNumSlots` / `GetContainerItemInfo` | no | `C_Container.*` | `core/Compat.lua:88-102` |
| `GetItemInfo` | no | `C_Item.GetItemInfo` | `core/Compat.lua:206-223` |
| `GetSpellInfo`, `UnitAura*`, `IsAddOnLoaded`, `InterfaceOptions_AddCategory` | not referenced anywhere | — | — |
| `SetBackdrop` without `BackdropTemplate` | no — all 15 call sites create with the template | — | verified across `modules/`, `settings/` |

The one deletion (`Compat.QualityFromLink`) is dead-code removal, not an API migration.

## Performance impact

Two small, both in the "stopped doing unnecessary work" direction; fill in from the spot-checks in
`03_SMOKE_TESTS.md`:

| Measurement | Before | After |
| --- | --- | --- |
| `GetAddOnCPUUsage("BankLedger")` 15 s after login, retention `365 days`, ledger unchanged (C-014) | _fill in_ | _fill in_ |
| `collectgarbage("count")` delta over ten General↔Filters page switches with the panel open (C-002) | _fill in_ | _fill in_ |

No hot-path algorithm changed. `Database:Stats` is untouched (see the deferral above).

## Known follow-ups

1. **F-015 — `Database:Stats` instrumentation.** Deferred because splitting a deliberate single-pass
   aggregator on suspicion trades correctness for readability. Wire `LibKa0s-Perf-1.0` first and let
   a measurement decide.
2. **`performance-§1` adoption.** The library is vendored and unwired; no `core/PerfSetup.lua`, no
   `perf` verb, no `BankLedgerPerfDB`, no `docs/performance.md` / `docs/perf-runs/`. Deferred
   because it is a standards-compliance item for `wow-addon:standards-audit`, not a review fix — and
   because it is a multi-part adoption (descriptor, stub, reserved verb, SV global, integration
   suite, two docs), not a one-line change.
3. **A UTF-8-safe truncator in LibKa0s.** C-004 fixes the cut in this addon's own
   `modules/InsightsWidgets.lua`. If a second Ka0s addon ever needs the same primitive, the
   compliant move is to push it **upstream** as an additive library member and re-vendor, never to
   copy it across. Deferred because nothing else is known to need it yet and a cross-repo bump for
   a three-line guard is disproportionate today.
4. **Localization pass.** v1.0.0 ships English-only with the `NS.L` seam in place and unused. Not a
   defect — an accepted scope decision recorded in `locales/enUS.lua` — but the seam exists to be
   filled, and C-004 is the first fix this cycle that only matters once it is.

## Verification evidence

- **Smoke tests:** `docs/reviews/2026-08-03/03_SMOKE_TESTS.md`, sign-off table filled in — 14 change
  IDs, 15 regression checks, one deDE/frFR localization pass, two perf spot-checks.
- **Headless gates:** `lua tests/run.lua` green (baseline `689 passed, 0 failed`; expect ≥ 691 after
  the cases added by C-002, C-004, C-005, C-006, C-013, C-014). `luacheck .` clean —
  `0 warnings / 0 errors in 24 files`.
- **Commit range:** _fill in_ · **PR:** _fill in_

## Suggested commit message / PR description

```
review(2026-08-03): close two seam leaks and eight correctness traps

Full-scope review of Ka0s Bank Ledger. No critical findings; suite and lint
were green throughout. Sixteen findings raised, fifteen fixed, one deferred.

High
  F-001  modules/Browser.lua never took the `local print = NS.Print` upvalue,
         so the filter bar's Save/Reset lines printed untagged through
         Blizzard's global print — bypassing the mandated cyan [BL] tag and
         the secret-safe stringifier. luacheck cannot see this (print is a
         lua51 std global) and no test asserted on the output.
  F-002  settings/Panel.lua's Storage bus handler was registered once and
         closed over that render's AceGUI Label. O.ClearScroll releases those
         widgets on every structural re-render, so after the first re-render
         the handler repainted a pool-recycled widget: the storage line went
         stale, and another addon's label could be overwritten. Now delegates
         to the library's page registry and captures nothing.

Medium
  F-003  /bl debug panel read LibStub.minors["O.AceGUI-3.0"] — a rename sweep
         had caught the registry key, so it always reported minor=nil.
  F-004  W.Truncate cut on bytes and claimed English-only labels; item types,
         sub-types, zone names and character names all arrive localized, so
         non-enUS clients got broken glyphs. Now codepoint-aware.
  F-005  C.Store.GUILD_BANK was used where a C.Context value was meant. Worked
         only because the two enums coincidentally share the literal.
  F-006  BANKFRAME_CLOSED disarmed whatever context was armed, including a
         live guild-bank session (which arms on data arrival, not on an open
         event). Close events now carry their own context, matching the guard
         the frame's own OnHide hook already had.
  F-007  A comment named tests/test_toc.lua; the assertions are in
         tests/test_libka0s.lua.
  F-008  A comment named docs/data-model.md, which does not exist.
  F-009  The options degradation stub carried BUTTON_PAIR_REL = 0.5 — both a
         copied library constant and the value the standard names as wrong —
         under a comment saying constants are deliberately not copied.

Low
  F-010  Dropped Compat.QualityFromLink (no caller anywhere, not even a test)
         and its unused cache; annotated five test-pinned pure seams.
  F-011  Insights section comments numbered 1,2,3,5,5,7,8/9,10,11,12.
  F-012  Leftover blank runs and one duplicated paragraph in Panel.lua.
  F-013  One unguarded NS.Browser reach in Export.lua among four guarded ones.
  F-014  SW:EndSession left previewSession set.
  F-016  PruneOld broadcast LedgerChanged even when it pruned nothing, paying
         a full repaint on every login.

Deferred
  F-015  Database:Stats (295 lines, the hottest read path). Instrument it via
         LibKa0s-Perf before restructuring it on suspicion.

No SavedVariables change, no schema bump, no slash-command change, no
deprecated-API migration (none were in use). Full write-up in
docs/reviews/2026-08-03/.
```
</content>
