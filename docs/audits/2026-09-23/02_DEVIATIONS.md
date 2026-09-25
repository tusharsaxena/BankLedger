# 02 · Deviations — Ka0s Bank Ledger — 2026-09-23

Audited against the **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**. Repo kind: **addon**.

IDs are stable per addon (`BL-NN`). `BL-01`…`BL-40` come from the 2026-07-26 … 2026-09-08 bundles;
**`BL-41`…`BL-51` are new this run.** A recurring deviation keeps its ID: `BL-34`, `BL-36`,
`BL-37`, `BL-38` and `BL-39` recur. Dependents carry their root's ID with a letter suffix.

---

## Tally, with its basis stated

**Headline (roots only): 15.** **Total including `derived from` dependents: 17** (two dependents:
`BL-34a`, `BL-46a`). Info rows are listed separately and excluded from both numbers.

| Grade | Roots | Total incl. dependents |
|---|---|---|
| High | 1 | 1 |
| Medium | 1 | 1 |
| Low | 13 | 15 |
| Info | — | 1 numbered (`BL-51`) plus the recorded-and-advisory table below; excluded |

**MUST failures: 13 of the 15 roots** (every root except `BL-39`, which fails no explicit MUST, and
`BL-50`, which fails a SHOULD) — **15 including dependents** (`BL-34a` fails
`audit-review-history`'s third register MUST; `BL-46a` fails `testing-§1`'s mock-fidelity MUST).
By grade the 13 MUST roots are **1 High, 1 Medium, 11 Low**: the Low ones are doc-, comment-,
config- or test-only, and every entry still names the MUST it fails.

**About the one High.** `BL-41` is graded High because `AUDIT.md`'s re-vendor check fixes that grade
in terms (*"A tag vendored with no bundle naming it and no `## Documented deviations` row saying why
is a **High** finding"*). By the impact table alone it would be Low: no player, SavedVariables file or
session can reach a missing bundle. Both readings are stated so neither is mistaken for the other.
The single finding a player can actually reach is `BL-34` (Medium).

---

## Summary — open this run

| ID | Section | Strength | Grade | Summary | Fix direction |
|---|---|---|---|---|---|
| **BL-41** | `audit-review-history` (*A re-vendor commit implies a bundle*) | MUST | **High** (playbook-fixed) | 25 LibKa0s tags vendored since the store's first bundle (v1.18.0 … v1.53.0) have no `docs/revendor/` bundle and no register row. | One consolidated bundle naming the span v1.15.0 → v1.54.2 (or a register row saying why not). |
| **BL-34** | `options-ui-§12` | MUST | **Medium** | The global reset is still two acts behind three controls, and its register row's re-check trigger fired when `1.1.0-release` was tagged. | Decide the act; point *Defaults*, Blizzard's footer control and `/bl resetall` at the confirm-gated body, sweep the session-only rows it misses, delete the row. |
| ↳ BL-34a | `audit-review-history` (register, third MUST) | MUST | Low | *derived from BL-34* — the `options-ui-§12` row still reads as live though its trigger fired on 2026-09-11. | Retire or re-decide the row in the change that closes BL-34. |
| **BL-36** | `toc-file-§5` | MUST | Low | `modules\Insights.lua` takes `NS.InsightsWidgets` at file scope; its TOC line carries no annotation. (Recurs.) | One comment above `BankLedger.toc:85`. |
| **BL-42** | `toc-file-§5` | MUST | Low | `settings\Slash.lua` reads `NS.SchemaRuntime.*` at file load; its TOC line carries no annotation. New with the v1.55.0 Schema adoption. | One comment above `BankLedger.toc:90`. |
| **BL-37** | `options-ui-§1` (*When the missing content is COMPOSED*) | MUST | Low | No case pins the library-absent row count or the composed delta (now 16 / 8 / 8). (Recurs.) | One case beside `tests/test_schema.lua:236-297`. |
| **BL-38** | `documentation-§5` (with `standalone-windows`) | MUST | Low | Seven lines in six files still say the host close factory serves four title bars; it serves three. (Recurs, narrowed from seven sites.) | Four → three at each, naming the copy window as the library's. |
| **BL-39** | `audit-review-history` (issue store) | — | Low | Issue #3 is open `state:triaged` for a register row that exists. (Recurs.) | `gh issue close 3` with `state:done`. |
| **BL-43** | `documentation-§3` (hub spill rule) | MUST | Low | `## Settings Schema` runs 167 lines unspilled; the hub is 522 lines (SHOULD ≤ ~400). | Move the section's body to `schema.md` / `settings-panel.md`, leave a summary and one link. |
| **BL-44** | `documentation-§3` (Tier 2) | MUST | Low | `debug.md` is recorded *Not applicable* while its trigger has fired: `/bl debug scan` and `/bl debug panel` are debug surfaces beyond the LibKa0s console. | Write `docs/debug.md`; flip the row to *Present*. |
| **BL-45** | `documentation-§5` | MUST | Low | Stale `file:line` citations and prose: the `standalone-windows` and `performance-§12` register rows, `## Event Subscriptions`, `docs/performance.md:46`, `settings/Schema.lua:139,178,395-403` and `settings/Panel.lua:767`. | One sync sweep; cite symbols where a line number keeps rotting. |
| **BL-46** | `slash-commands-§7` (*What MUST stand down*) | MUST | Low | The retention `C_Timer.After(5)` survives the stand-down, gated rather than cancelled. | Arm it through AceTimer (or `C_Timer.NewTimer`) and cancel it in `NS.StandDown`. |
| ↳ BL-46a | `testing-§1` (mock fidelity), `testing-§12` | MUST | Low | *derived from BL-46* — `tests/wow_mock.lua:617` no-ops `C_Timer.After`, so `test_disabled`'s timer step cannot see this survivor or any future one. | Record instead of no-op; keep the retention deferral from running by not firing it. |
| **BL-47** | `events-frames-taint-§1` | MUST (+ SHOULD) | Low | Five registrations bypass the `pcall`ed helper; no `C_EventUtils.IsEventValid` front gate anywhere. | Route all five through one isolating helper; add the front gate. |
| **BL-48** | `automated-tests-§3` | MUST | Low | The generated record calls the perf skip *"nothing to run … rather than a ratified `performance-§12` exemption"* in an addon that holds that exemption. Root cause is the vendored runner. | Fix upstream in `LibKa0s/testkit/run-automated-tests.sh`, re-vendor, re-run. |
| **BL-49** | `architecture-§4` | MUST | Low | Twelve `(Send|Register)Message("Ka0s_…")` literals at call sites in six test files. | Use `NS.MSG.*` at drivers and receivers; keep `tests/test_bus.lua` as the one wire-name oracle. |
| **BL-50** | `documentation-§6` (*Citing the standard*) | SHOULD | Low | `.pkgmeta:17` and `:22` cite the standard as `packaging.md:28`, a line number that has already moved. | Cite `packaging` bare. |

## Summary — Info (excluded from both tallies)

| ID | Section | Basis |
|---|---|---|
| **BL-51** | `events-frames-taint-§8` (scope of the pre-formatting rule) | **SHOULD NOT, observation.** Eight printer call sites pre-format with `..` or `:format` (`modules/LedgerTable.lua:1074,1080`, `settings/Schema.lua:677,691`, `settings/Slash.lua:51,62,316,395`). None is in the trigger set (all format addon-owned counts, labels and verbs), so nothing is reachable; named so the SHOULD is not read as met. |
| BL-07 | `savedvariables-§2` | **Accepted.** Register row `docs/ARCHITECTURE.md:502`, decided 2026-07-27. Trigger (first per-profile setting) not fired. Rule unchanged in substance. |
| BL-11…BL-17 | `performance-§12` | **Accepted, as one row.** `docs/ARCHITECTURE.md:501`, decided 2026-08-05, evidence issue #9 (`LIBKA0S-17`, resolves). Trigger not fired: no `OnUpdate`, no repeating ticker; the combat-edge pair (`core/BankLedger.lua:91-92`) is bounded and named in the sweep (`docs/performance.md:46,55-60`). The row's *Why* sentence is stale — filed under `BL-45`, not here. |
| BL-04 | `localization-§1` | **Accepted.** `docs/ARCHITECTURE.md:503`, decided 2026-07-31; issue #3 and `BL-04` (2026-09-07) resolve. Trigger (first non-English locale) not fired: `locales/` holds `enUS.lua`, `PostLoad.lua`. |
| BL-28 | `standalone-windows` | **Accepted — terminal compliant decline, re-checked on all four conditions.** (1) host windows only; (2) the catalog `close` through `NS.Icon` (`modules/Browser.lua:101`); (3) one host factory (`modules/Browser.lua:95`) and three callers (`:1056`, `modules/SessionWindow.lua:485`, `modules/Export.lua:362`), no `lib.MakeCloseButton` call; (4) the row (`docs/ARCHITECTURE.md:504`). Trigger not fired. Its line numbers drifted — `BL-45`. |
| BL-24 | `layout-§1` | **Advisory.** Four files in the 1000–1500 band, **0** over the cap (authored scope). `modules/Insights.lua` (1002) entered the band after the newest bundle, so its disposition is owed at the next release run, not now. |
| — | `automated-tests-§4/§6` | **Observation.** The newest bundle `20260916-184426` is 37 commits behind HEAD. Drift: tests 943 → 1017, lint files 67 → 71, NLOC 16,380 → 17,397, functions 2,498 → 2,640, band 3 → 4, warnings 0 → 0. The checkpoint is release, so not a finding. No row has commit cells: all predate kit revision 25, which arrived today (`4310368`) — carried forward as *unknown*. |
| — | `audit-review-history` (issue store) | **Observation.** `state:will-not-do` issues #4, #6, #7, #8, #10, #15, #20 decline library adoptions, a scope item or an upstream change — no rule — so none owes a register row; #5 and #9 have theirs. |

## Summary — closed since 2026-09-08

| ID | Was | Now |
|---|---|---|
| BL-35 | `localization-§5`, 62 British spellings | **Closed.** The kit's `tests/_kit/test_prose.lua` (`{ name = "test_prose", dir = "tests/_kit/" }`, `tests/run.lua:36`) scans the whole tracked set with both canonical lists and is green in this run. |
| BL-40 | Info, `settings/Panel.lua` said six tabs | **Closed.** `settings/Panel.lua:736-741` now reads five tabs. (A different stale phrase at `:767` is under `BL-45`.) |

---

## BL-41 · 25 re-vendored LibKa0s tags have no bundle

**Section.** `audit-review-history`, *A re-vendor commit implies a bundle* · **MUST** · **High** (the
grade `AUDIT.md`'s re-vendor check assigns; impact alone would make it Low — see the tally).

**Rule.** *"every re-vendor commit in the repo's history has a `docs/revendor/` bundle naming the tag
that commit vendored, or the absence is a row in `## Documented deviations` saying why."* The trigger is
the commit touching `libs/LibKa0s/`; the horizon is the store's first bundle.

**State.** The store's first bundle is `docs/revendor/2026-08-25/` (its `01_DELTA.md` names
v1.15.0). Since then, 36 commits touched `libs/LibKa0s/`, vendoring 31 distinct tags read from the
`CLAUDE.md` provenance line at each commit. The store records 8 tags (bare-dated bundles read from
their `01_DELTA.md` first line). **25 are unrecorded**: v1.18.0, v1.18.1, v1.19.0, v1.23.0, v1.24.0,
v1.26.0 … v1.29.0, v1.35.0, v1.36.0 … v1.36.2, v1.37.0, v1.38.0, v1.39.0, v1.42.0, v1.44.0, v1.45.0,
v1.46.1, v1.47.0, v1.50.0 … v1.53.0. No register row covers the gap. Commands and outputs in
`03_EVIDENCE.md` §E-01.

**Fix.** One consolidated bundle is a compliant answer (the section says so). Write
`docs/revendor/2026-09-23-v1.18.0-v1.53.0/` (or a register row) naming the span, what arrived, and
that it was carried by sweeps. Do not back-fill a folder per tag.

---

## BL-34 · The global reset is two acts, and the row that recorded it has expired

**Section.** `options-ui-§12` · **MUST** · **Medium.**

**Rule.** The *Reset all settings* control, the header **Defaults** button and `/<slash> resetall`
**MUST** be the same act; for an addon with no profile the act empties the account-wide store
wholesale and merges defaults back; session-only rows **MUST** be restored row by row because a store
reset cannot reach them.

**State.** *Reset all settings* raises `KA0S_BANKLEDGER_RESETALL` → `Sl:ResetEverything`, a wholesale
wipe of `db.global` including the recorded ledger (`settings/Slash.lua:161-197`). The page's
**Defaults** button — and Blizzard's footer control, which forwards to it — and `/bl resetall` run
`Sl:CliResetAll`, a schema walk plus filter and saved-view clears that keeps the ledger
(`settings/Panel.lua:696-705`, `settings/Slash.lua:513-523`). `Sl:ResetEverything` ends test mode by
name (`:188-193`) but leaves the other session-only row, `state.debugConsole`, untouched. The code
itself says the three are not one implementation (`settings/Schema.lua:326-333`).

**Why it reopens.** The register row (`docs/ARCHITECTURE.md:505`, decided 2026-09-02) calls itself
*"a placeholder for a resolution, not an exemption"* with the trigger *"Re-check at the next
release"*. `1.1.0-release` was tagged on 2026-09-11 (`243dfab`), so the trigger fired and the row no
longer ratifies anything.

**Why Medium.** A player reaches both acts today. Pressing Blizzard's own footer *Defaults* or typing
`/bl resetall` does something narrower than the control named *Reset all settings*. The labels differ
and the destructive path is confirm-gated with the canonical warning, so nothing is lost without a
prompt; it is a degraded, not a broken, path.

**Fix.** The row names the resolution itself: point `P:RestoreDefaults` and the `resetall` verb at the
same confirm-gated body, extend `Sl:ResetEverything` to restore the session-only rows, then delete the
row. Unifying *down* instead leaves the addon without a §12-compliant wholesale reset. Either way
the choice changes what a player loses, so it is the owner's call; `04_TECHNICAL_DESIGN.md` lays out
both.

### BL-34a · The expired row still reads as live — *derived from BL-34*

**Section.** `audit-review-history` (*The deviation register is an input…*, third MUST) · **MUST** ·
**Low.** An audit **MUST** report a row whose trigger has already fired. This one did on 2026-09-11.
It stays a dependent: it disappears with whatever closes `BL-34`, and its grade is lower.

---

## BL-36 · `modules\Insights.lua`'s load-bearing position is unannotated (recurs)

**Section.** `toc-file-§5` · **MUST** · **Low.**

`modules/Insights.lua:5` is `local W = NS.InsightsWidgets`, a file-scope upvalue of the table
`modules/InsightsWidgets.lua:2` creates. `BankLedger.toc:84-85` carries no comment on either line, and
the `# Modules` group header (`:78`) names a different dependency. Swapping the two lines would leave
`W` nil for the session with no error at load. Denominator: the positions that resolve at file load
(`01_CURRENT_STATE.md`, TOC); five are annotated, this and `BL-42` are not.

**Fix.** A comment above `modules\Insights.lua` naming `NS.InsightsWidgets`, the file that creates it,
and what moving the line would silently do.

## BL-42 · `settings\Slash.lua`'s load-bearing position is unannotated (new)

**Section.** `toc-file-§5` · **MUST** · **Low.**

`settings/Slash.lua:438-454` hands `NS.SchemaRuntime.Get`, `.Set`, `.FindRow`, `.AllRows`,
`.ApplyDefault`, `.BulkBegin` and `.BulkEnd` to `lib:New` **at file load**; `NS.SchemaRuntime` is
created by `settings/Schema.lua:580`. The file's own comment says *"Direct references are safe because
the TOC loads settings/Schema.lua first"* (`:452`) — the TOC does not say so: `BankLedger.toc:89-90`
carry no comment, and the group header is the generic *"Settings (last …)"*. The sibling
`settings\OptionsSetup.lua` has exactly this annotation (`:91-92`). Arrived with the Schema adoption
(`0d9d1e6`, 2026-09-23). One row per position, so it does not fold into `BL-36`.

**Fix.** A comment above `settings\Slash.lua` naming `NS.SchemaRuntime` and `settings/Schema.lua`.

---

## BL-37 · No case pins the library-absent row count or the composed delta (recurs)

**Section.** `options-ui-§1`, *When the missing content is COMPOSED* · **MUST** · **Low.**

*"The suite MUST pin both counts and the delta between them … and the difference as a named figure
attributed to the composers it belongs to."* The hollow composers are correct
(`settings/OptionsSetup.lua:203-207`); `tests/test_schema.lua:236-297` pins the fully-loaded tab
counts; `tests/test_surface_parity.lua` pins the member set. Nothing pins the absent-arm count or the
difference. Today's figures, from the schema literal: **16** stored rows fully loaded (8 host rows at
`settings/Schema.lua:31-124` + 8 composed Master-controls rows), **8** on the library-absent arm,
delta **8**, all `H.MasterControls`'s — the delta grew from 6 at the 2026-09-08 audit when
`minimapPath` and `testModePath` joined the composer, and nothing noticed, which is exactly what the
MUST is for.

**Fix.** One case: load both arms, count `S.Schema` (and `S:PageRows()`), assert 16 / 8 / 8 with the
delta attributed to `MasterControls` in the message.

---

## BL-38 · Seven lines still say the close factory serves four title bars (recurs, narrowed)

**Section.** `documentation-§5` (with `standalone-windows`) · **MUST** · **Low.**

The register row (`docs/ARCHITECTURE.md:504`) and `core/CoreSetup.lua:117-131` now say three host
title bars, with the export copy window the library's. Still asserting four (command in
`03_EVIDENCE.md` §E-09, frozen stores excluded):

| Site | Text |
|---|---|
| `core/MediaSetup.lua:86` | `B:MakeCloseButton — all four title bars` |
| `docs/media.md:46` | *the ledger, session, export-modal and export-copy title bars* |
| `docs/smoke-tests.md:598` | *All four wear the same mark, because all four go through `B:MakeCloseButton`* |
| `tests/test_libka0s.lua:63` | *all four of its title bars go through modules/Browser.lua's own B:MakeCloseButton* |
| `tests/test_marks.lua:71`, `:98` | section banner *one edit, four title bars*; case name *…reached all four title bars* |
| `docs/test-cases.md:941` | generated from the `:98` case name — fixed by renaming the case and regenerating |

Two sites closed since 2026-09-08 (`core/CoreSetup.lua`, `docs/module-map.md`); `docs/smoke-tests.md`
was not in that bundle's list and is. The smoke step matters most: it tells a human tester the copy
window's close goes through the host factory, which it does not.

**Fix.** Four → three at each, naming the copy window as `LibKa0s-Widgets-1.0`'s; split
`docs/media.md:46`'s cell, since the `close` **mark** is on all four windows while the **factory** is on
three. Rename the case and regenerate `docs/test-cases.md`.

---

## BL-39 · Issue #3 is open for a row that exists (recurs)

**Section.** `audit-review-history` (issue store) · no explicit MUST · **Low.**

Issue #3 (*Record the BL-04 deviation in ARCHITECTURE's Documented deviations register*) is **OPEN**,
`state:triaged` / `severity:low`. The row it asks for is `docs/ARCHITECTURE.md:503`. The label gives a
wrong answer to the one question the store exists to answer. **Fix:** close #3 with `state:done`,
citing the row.

---

## BL-43 · The hub's `## Settings Schema` has not spilled

**Section.** `documentation-§3` (*`ARCHITECTURE.md` is a hub, and the spill rule keeps it one*) ·
**MUST** (spill) and **SHOULD** (file length) · **Low.**

`## Settings Schema` runs from `docs/ARCHITECTURE.md:45` to `:211` — 167 lines against *"A mandated
section that exceeds roughly 60 lines MUST spill into its canonical topic doc, leaving behind a summary
and exactly one link"*. It carries the runtime adoption narrative, the bulk-bracket rules, the tab
list, the registry and recorded-data naming, and four named-state entries, and ends on two links
(`schema.md`, `settings-panel.md`). The file is **522** lines against the ~400 SHOULD. Reported as
shape, not arithmetic: the other nine mandated sections are within bounds.

**Fix.** Move the body to `docs/schema.md` (storage, registry, recorded data, named state) and
`docs/settings-panel.md` (tabs, reset routes), leave a short summary and one link. The architecture-§5
naming sentences must stay findable under *Settings Schema* — a one-line summary per registry and per
named state, pointing into `schema.md`, satisfies both rules.

---

## BL-44 · `debug.md` is recorded *Not applicable* while its trigger has fired

**Section.** `documentation-§3` (Tier 2) · **MUST** · **Low.**

Trigger: *"the addon ships debug surfaces **beyond** the `LibKa0s` default console."* The row
(`docs/ARCHITECTURE.md:467`) reads *"Not applicable | … no debug surface of the addon's own beyond
`/bl debug scan` and `/bl debug panel`"* — naming the two surfaces that fire it. `/bl debug scan`
dumps the client's container model through `NS.Ledger:Diagnose()` (`modules/Ledger.lua:279`) and
`/bl debug panel` dumps the Defaults button's region list through `NS.Panel:Diagnose()`
(`settings/Panel.lua:638`), both ungated (`settings/Schema.lua:708-721`). `AUDIT.md`: an absent doc
with a fired trigger *and* a Not-applicable row is worse than the bare omission, because the row
asserts something false. Still doc-only, so Low.

**Fix.** Write `docs/debug.md` (the two verbs, what each prints, when to use them, the `[Scan]`/`[Panel]`
tags, the raw-append rule) and flip the row to *Present*.

---

## BL-45 · Stale citations and prose that describe the tree as it was

**Section.** `documentation-§5` (*MUST keep the doc set in sync with code*) · **MUST** · **Low.**
One rolled-up finding; the fix is one sweep.

| Site | Says | Tree says |
|---|---|---|
| `docs/ARCHITECTURE.md:504` (register, `standalone-windows`) | factory `modules/Browser.lua:98`; `NS.Icon` at `:104`; ledger caller `:1047` | `:95`; `:101`; `:1056` |
| `docs/ARCHITECTURE.md:501` (register, `performance-§12`) | *"the three events that can fire in combat do a single `NS.State.openContext` nil check and return"* | the combat pair also fires in combat and runs `ApplyVisibility` (`core/BankLedger.lua:206-213`); the sweep it cites (`docs/performance.md:46,55-60`) already says so |
| `docs/ARCHITECTURE.md:378-384` (`## Event Subscriptions`) | `core/BankLedger.lua:45`; `:49-50`; `modules/Browser.lua:1206` | `:87`; `:91-92`; `:1218` |
| `docs/performance.md:46` | the combat pair is registered in `OnEnable` | `NS.StandUp` (`core/BankLedger.lua:85-98`) |
| `settings/Schema.lua:139` | `modules/Browser.lua:1123 and :1165` | `:1132`, `:1179` |
| `settings/Schema.lua:178`, `tests/test_schema.lua:278` | `modules/Browser.lua:1007` calls `SetMovable(true)` | `:1016` |
| `settings/Schema.lua:396-401` | `B:SaveGeometry` `:147`, grip `:1099`, `B:ResetWindow` `:185`, `B:SaveView` `:748`, `B:ResetView` `:757` | `:144`, `:1108`, `:182`, `:757`, `:766` |
| `settings/Schema.lua:402-403` | `minimapPos` table handed over by `B:SetupMinimap` | `B:SetupMinimap` was deleted; `core/LauncherSetup.lua` hands it over, and `tests/test_launcher.lua` fails if it returns |
| `settings/Panel.lua:767` | *"adds the two host-drawn filter tabs"* | one `Filters` tab with a secondary strip |

The register rows are the costliest: `audit-review-history` asks an audit to resolve what a row cites,
and a row whose line numbers point at the wrong code reads as evidence and leads elsewhere.

**Fix.** Correct each; where a line number has rotted twice, cite the symbol (`B:MakeCloseButton`)
instead of the line.

---

## BL-46 · One timer outlives the stand-down

**Section.** `slash-commands-§7` (*What MUST stand down*: *"Every timer, ticker and `OnUpdate` is
canceled … not left armed to wake up and find a flag"*) · **MUST** · **Low.**

`addon:OnEnterWorld` arms `C_Timer.After(5, …)` for the once-per-session retention prune
(`core/BankLedger.lua:216-229`). `C_Timer.After` cannot be cancelled, so a disable inside those five
seconds leaves it armed; its body checks `NS.IsStoodDown()` and returns (`:221-225`). That is the
shape the rule names — armed, then finding a flag — although the comment knows the hazard. Every other
timer goes through AceTimer and `NS.StandDown` cancels it (`:151-155`).

**Why Low.** Reachable only by a disable in the first five seconds of a session, and its only effect is
one early-returning callback: no write, no chat line, no frame.

**Fix.** Schedule it with `NS.addon:ScheduleTimer` (cancelled by `CancelAllTimers`) or keep the handle
from `C_Timer.NewTimer` and cancel it in `NS.StandDown`; keep the latch check as a belt.

### BL-46a · The mock no-ops `C_Timer.After`, so the suite cannot see it — *derived from BL-46*

**Section.** `testing-§1` (mock fidelity: *"anything a test needs to observe is recorded rather than
no-opped"*), `testing-§12` · **MUST** · **Low.**

`tests/wow_mock.lua:614-617` replaces the kit's recording `C_Timer.After` with `function() end` so the
prune never runs in suites. `tests/test_disabled.lua:184-203` then asserts `#mocks.__timers() == 0`,
which cannot count a `C_Timer.After` survivor. Stays a dependent: it has no user reach and closes with
the same change set.

**Fix.** Let the kit record the call and simply not fire the retention timer, or filter it by its
delay when firing; then the timer step would have gone red on `BL-46`.

---

## BL-47 · Five event registrations bypass the isolating helper

**Section.** `events-frames-taint-§1` (*An unknown event name raises…*) · **MUST** (isolation) and
**SHOULD** (`C_EventUtils.IsEventValid`) · **Low.**

*"Registration is isolated per event: every `RegisterEvent` goes through a single `pcall`ed helper."*
The capture engine does (`modules/Ledger.lua:849-854`). These do not: `core/BankLedger.lua:87`, `:91`,
`:92` (a block of three in `NS.StandUp`, where a raise on the first would also abort `Ledger:Enable`,
`Browser:Enable` and `SessionWindow:Enable` below it), `modules/Browser.lua:1218` and
`modules/SessionWindow.lua:673`. `docs/ARCHITECTURE.md:376-377` argues that none of these names can
retire; an argument in prose is not the helper. No `C_EventUtils.IsEventValid` anywhere.

**Why Low.** `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_*` and `PLAYER_LOGOUT` are foundational; nothing
fails today. Latent.

**Fix.** Route all five through `L:RegisterEventSafely` (or a shared `NS.RegisterEventSafely`) so a
rejected name lands in the same `/bl debug scan` record; front-gate with `C_EventUtils.IsEventValid`
where the API exists.

---

## BL-48 · The generated record denies the addon's own exemption

**Section.** `automated-tests-§3` · **MUST** · **Low.** Root cause upstream.

*"Exactly two `skipReason` values are sanctioned for `perf` … (2) the addon holds a recorded
no-combat-path exemption … which **MUST** be recorded when it applies, naming `performance-§12`."*
This addon holds it (`docs/ARCHITECTURE.md:501`). The newest manifest records `"skipReason": "no
tests/perf.lua — this addon ships no offline scenarios"`, and `docs/automated-tests/RESULTS.md:59-63`
says *"the first of … two sanctioned reasons, nothing to run, rather than a ratified `performance-§12`
no-combat-path exemption. The record is therefore silent about runtime cost"* — false here. The vendored
runner only knows reason (1): `tests/_kit/run-automated-tests.sh:343-344` and `:838-843`. The addon
cannot edit the kit (`testing-§1`), so the fix lands in LibKa0s.

**Fix.** Upstream: teach the runner reason (2) — read a `performance-§12` row in the register, or take
an explicit opt — and emit the exemption sentence. Re-vendor; the next run rewrites `RESULTS.md`.

---

## BL-49 · Wire-name literals at message call sites in tests

**Section.** `architecture-§4` (*"use that constant at every `SendMessage` and `RegisterMessage` call
site — never the literal"*) · **MUST** · **Low.**

`AUDIT.md`'s grep (vendored trees excluded, `tests/` included) returns 12 call-site literals in six test
files: `tests/test_database.lua:40,53,54`, `tests/test_lifecycle.lua:64`, `tests/test_mock.lua:312,313,315,320`
(a fake `Ka0s_Scratch_Ping` exercising the mock's dispatch), `tests/test_panel.lua:614`,
`tests/test_schema.lua:36`, `tests/test_sessionwindow.lua:143,145`. Shipped code has none; the wire
strings are declared once in `core/Constants.lua:281-289`. A mistyped literal in a driver sends a
message nobody receives and the case then asserts on silence.

**Fix.** Use `NS.MSG.*` at every driver and receiver; keep one deliberate wire-name oracle
(`tests/test_bus.lua:19-22` already pins all four strings).

---

## BL-50 · `.pkgmeta` cites the standard by line number

**Section.** `documentation-§6` (*Citing the standard*) · **SHOULD** · **Low.**

`.pkgmeta:17` (*"packaging.md:28 MUSTs every root dot-entry…"*) and `:22` (*"listed under
packaging.md:28"*). `packaging` has no numbered subsections and is cited bare; a line number into
another repo is already wrong (the strong-form MUST is not on line 28 of the fetched v2.64.0 file).
**Fix:** cite `packaging` (its strong-form ignore rule).

---

## BL-51 · Eight pre-formatted printer calls (Info)

**Section.** `events-frames-taint-§8` · **SHOULD NOT** outside the trigger set · **Info.** Listed in the
Info table. The sites format only addon-owned values, so no secret can reach them; they are the drift
the SHOULD names, not a defect.
