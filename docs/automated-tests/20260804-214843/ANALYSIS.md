# Analysis — 20260804-214843

- **Addon:** BankLedger 1.0.0
- **Verdict:** green
- **Commit:** fb54d6695091 (feat/fix-ccn), dirty
- **Started:** 2026-08-04T21:48:43+05:30
- **Previous run:** [`20260804-182039`](../20260804-182039/) (green)

## Headline

The run that closes `feat/fix-ccn`. Both gating suites are clean — `luacheck` reports 0 warnings /
0 errors across 24 files, and the headless harness passes 726 of 726 cases — and the number this
branch existed for is the complexity one: **`lizard` warns on nothing**, down from fifteen warned
functions in the previous run. The offline perf runner is still absent (see below), so this record
still says nothing about runtime cost.

The branch is behavior-identical to `master` by intent. The 37 new cases are the evidence for that
claim, not new features: each peeled function was pinned before it was cut, and `tests/test_mock.lua`
is new cover for the frame stub every UI suite stands on.

## Suites

| Suite | Status | Result | Artifact | Moved since previous run |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 24 files | [`lint.txt`](lint.txt) | unchanged — 0/0 over the same 24 files |
| tests | pass | 726 passed, 0 failed, 726 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | **+37 cases**, still 0 failed |
| perf | skip | — | — (not run) | unchanged — still no `tests/perf.lua` |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | **15 warnings → 0** |

### Complexity in full

Every field of `lizard`'s footer, plus the two derived file counts. The **averages** are what make
this run comparable to the previous one across a change in size: the tree grew by 703 NLOC and 173
functions, so a falling total would have been the surprise. What matters is that the averages fell
while the size rose — the addon got wider, not denser.

| Metric | Value | Previous (`20260804-182039`) |
|---|---|---|
| Total NLOC | 12788 | 12085 |
| Functions | 1946 | 1773 |
| Avg NLOC / function | 6.0 | 6.2 |
| Avg CCN | 2.1 | 2.2 |
| Max CCN | *not reported* — see below | 33 |
| Avg tokens / function | 48.0 | 50.2 |
| Warnings (CCN > 15) | **0** | 15 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.00 / 0.00 | 0.01 / 0.06 |
| Files in the 1000–1500 band | 4 | 2 |
| Files over the 1500 cap | 0 | 0 |

**On `Max CCN`.** `lizard`'s footer reports the maximum across *warned* functions only, so with no
warnings it reports nothing and the manifest records `0`. That is an artifact of the tool, not a
measurement: `0` there means "no function exceeded 15". Measured separately over the same scope, the
true maximum is **15**, in `accumulateItemTaxonomy` (`core/Database.lua:234`) — at the cap rather
than under it by any margin, which makes it the one function to watch next.

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured there.
That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run says
nothing about the addon's runtime cost.

## What moved

- **Complexity: 15 warned functions → 0.** The whole previous watch list is gone —
  `Database:QueryList` (33), `P:Diagnose` (31), `I:RenderDirectionSplit` (28), `menu:Populate` (26),
  `groupOf` (25), `L:Reconcile` (24), `L.Diff` (22), `I.CardValues` (21), `wow_mock`'s `__index`
  (21), `B:CaptureView` (20), `W.BuildStackRows` (19), `LT:OrderedFilteredEntries` (18),
  `LT:PaintCell` (17), `B:ApplyView` (16), `I:RenderStrip` (16). Each was peeled into named
  file-local helpers in its own file; none was split across files and none changed behavior.
- **Tests: 689 → 726.** `test_browser.lua` +11, `test_mock.lua` +19 (new file), `test_panel.lua` +3,
  `test_ledgertable.lua` +2, `test_insights.lua` +2.
- **Size: +703 NLOC, +173 functions.** That is the cost of the peel, and it is the expected shape:
  extracting a helper adds a signature and a call site, so branch count moves out of one function
  without leaving the tree. Two files crossed the `layout-§1` 1000-LOC on-notice line as a result
  (`modules/LedgerTable.lua`, `modules/Insights.lua`) and `modules/Browser.lua` gained 62 lines.
- **Lint: unchanged at 0/0.** Worth stating rather than skipping: a refactor this wide that left
  lint untouched is a refactor that introduced no unused local and no shadowed name.

## Complexity watch list

### Functions `lizard` warned on

**None.** This is the branch's purpose and its result. The previous run's fifteen dispositions are
deliberately **not** carried forward — an "Accepted" with no warning attached to it is noise — and
the frozen [`20260804-182039`](../20260804-182039/) bundle keeps them if the reasoning is ever
wanted.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1368 | **Already tracked as `BL-24`**, with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. Up 62 on the previous run. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1361 | **Accepted.** A suite grows with the cases it pins, and this one covers the addon's core mechanic. Unmoved by this branch. Split by concern if it passes 1500. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1052 | **New to the band.** Crossed 1000 when `groupOf`, `PaintCell` and `BuildTestData` were peeled into file-local helpers. Accepted for now; the test-data generator is a self-contained block and is the peel seam if it grows. |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1023 | **New to the band.** Crossed 1000 when `LayoutSections` was split into one `section*` helper per chart. Accepted: the file is seventeen chart sections and their layout. The ranked-panel grid is the natural sibling file if it grows. |

## Actions

- **Watch `accumulateItemTaxonomy` (`core/Database.lua:234`), CCN 15.** It sits exactly on the cap;
  one more taxonomy facet puts it over. It is the next peel if anything touches it.
- **Watch the two files new to the 1000–1500 band.** Neither is a finding today. Both moved because
  branch count was traded for line count in place, which is the trade this branch chose everywhere.
- **The `perf` skip is still standing.** Nothing here changes it, and nothing will until the addon
  ships `tests/perf.lua`.
