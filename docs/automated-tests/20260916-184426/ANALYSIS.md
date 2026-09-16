# Analysis — 20260916-184426

- **Addon:** BankLedger 1.1.0
- **Verdict:** green
- **Commit:** `076f674c282607fa31a9b5bf28f7250af7ac1244` (master), clean
- **Previous run:** `20260916-094506`

## Headline

Both gating suites pass: `luacheck` is clean over 67 files and the harness runs 943 cases with no
failure and no skip, up 30 from this morning's run. Every one of the previous run's four actions
landed in the eight commits since: `Sl:ResetEverything` is back under the ceiling, both over-cap
suite files were split, and the complexity suite now reports **max CCN 15, zero warnings, zero
files over the `layout-§1` cap** — the first run since `20260910-234511` that would clear the
release gate on all four counts. `perf` remains the same permanent skip this addon has always
recorded: it ships no `tests/perf.lua`, so this run is silent about runtime cost and is **NOT
EVALUATED** rather than passed at a tag. The one cell owed a ruling is `tests/test_ledger.lua`,
which re-entered the 1000–1500 on-notice band on its way down from over the cap.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260916-094506` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 67 files | [`lint.txt`](lint.txt) | 0/0 unchanged; scope widened 61 → 67 files |
| tests | pass | 943 passed, 0 skipped, 0 failed, 943 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +30 cases (913 → 943) |
| perf | skip | no `tests/perf.lua` — this addon ships no offline scenarios | none — nothing ran | unchanged; skipped on every run this record holds |
| complexity | pass | 0 warnings, max CCN 15; see below | [`complexity.txt`](complexity.txt) | 1 → 0 warnings; the warned function is gone |

**Complexity is reported in full**, totals and averages both. Every value below is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 16380 |
| Functions | 2498 |
| Avg NLOC / function | 5.9 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 46.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

**`perf` — a skip, not a pass.** [`manifest.json`](manifest.json) records
`skipReason: "no tests/perf.lua — this addon ships no offline scenarios"`. That is the first of
`automated-tests-§3`'s two sanctioned reasons — *nothing to run* — and **not** a ratified
`performance-§12` no-combat-path exemption, which this addon does not hold. Nothing in this bundle
says BankLedger is cheap or expensive; the question was not asked. At a release this suite is
**NOT EVALUATED** rather than passed, and release notes have to say so out loud.

**`complexity` — a pass with nothing left in it.** `lizard`'s threshold banner in
[`complexity.txt`](complexity.txt) reads `No thresholds exceeded`. `Sl:ResetEverything`, CCN 17 at
the previous run, is the fix in `6592b51` and `a37da68`; `settings/Slash.lua` now measures avg CCN
3.1 over 50 functions with nothing warned. This is the one suite that changed verdict-shape since
this morning, and it changed in the right direction.

## What moved

Eight commits separate this run from the previous one (`beaf599` → `076f674`), and they are the
reason every figure below moved.

- **lint** — figure did not move, **scope did**: 0 warnings / 0 errors at both runs, but over
  **61 → 67** files. The six new authored files are `core/LauncherSetup.lua`,
  `tests/ledger_support.lua`, `tests/panel_support.lua`, `tests/test_launcher.lua`,
  `tests/test_ledger_settling.lua` and `tests/test_panel_filters.lua` — the launcher adoption plus
  the two peels. The `.luacheckrc` exclusions are unchanged at both runs, so the widened scope is a
  real widening and not a config change.
- **tests** — **913 → 943**, +30, all passing, none skipped ([`tests.txt`](tests.txt)). The growth
  is `tests/test_launcher.lua` (new, 53 functions) and the `/bl enable` / `/bl disable` cases in
  `tests/test_slash.lua`. The two peels moved cases between files without changing their count.
- **perf** — did not move and cannot: skipped on every run in [`../RESULTS.md`](../RESULTS.md).
- **complexity totals** — NLOC 15821 → **16380** (+559), functions 2401 → **2498** (+97). The addon
  grew: a launcher module, two slash aliases and a Filters tab strip. `libs/` is out of `lizard`'s
  scope, so the LibKa0s v1.39.0 re-vendor in `08c14b6` contributes none of this.
- **complexity averages** — avg NLOC/function **5.9 → 5.9** (unchanged), avg CCN **2.0 → 2.0**
  (unchanged), avg tokens 46.7 → **46.6**. This is the distinction the totals hide: the codebase
  got **bigger**, not **denser**. The average function is the same length and the same branchiness
  it was this morning, and marginally cheaper in tokens.
- **max CCN** — **17 → 15**, warnings **1 → 0**. The previous run's Action 1 is done.
- **file bands** — band files 2 → **3**, over-cap files **2 → 0**. `tests/test_panel.lua` left the
  record entirely (1580 → 783, peeled into `tests/test_panel_filters.lua`);
  `tests/test_ledger.lua` came down from over the cap into the on-notice band (1539 → **1028**,
  peeled into `tests/test_ledger_settling.lua`). Both peels are commit `684107c`. The previous
  run's Actions 2 and 3 are done, and Action 4 — whether over-cap suite files want a deviation row
  — is moot, because no file is over the cap.
- **`modules/Browser.lua`** — 1252 → **1208**, −44, from the Filters-page fold in `e66cbd9` and
  the surrounding 1.1.0 panel work. Still in the band, still `BL-24`.
- **`modules/LedgerTable.lua`** — **1132 → 1132**, did not move at all. Saying so explicitly:
  silence on a figure reads as "not checked".
- **The commit that is only comments.** `076f674`, this run's HEAD, is comment-only and moves no
  measured figure. It corrected two comments that named a tree that had moved:
  `tests/test_lifecycle.lua:18` cited `modules/Browser.lua:1229` after that file shrank to 1208
  lines — a citation past end of file — and `settings/Panel.lua:715` still called the General strip
  six tabs after Blacklist and Whitelist folded behind one Filters tab in 1.1.0. Both were found by
  the finalize doc sync. They are the tail of the same tree movement the band table records above,
  which is why the file counts in this run and the comments in that commit tell the same story.
- **Bundles without an analysis.** Noting it again without backfilling, as `automated-tests-§5`
  asks: **2 of the 10** earlier bundles in this repo carry no `ANALYSIS.md`
  (`20260807-110442`, `20260825-103400`). Both are frozen and stay that way.

## Complexity watch list

Generated from this run's own `lizard` output; the dispositions are this analysis's, and the same
cells are authored into [`../RESULTS.md`](../RESULTS.md).

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|
| — | — | — | None. |

None. `lizard`'s footer records **0 warnings over 2498 functions**, and its threshold banner reads
`No thresholds exceeded`. The single entry this table carried at the previous run,
`Sl:ResetEverything` at CCN 17, was dense **guarding** rather than tangled control flow — a flat
run of `if X and X.Y then` teardown lines, each scored as a decision by `lizard` — and it was
fixed the way that reading implied, by lifting the optional-subsystem resets out, not by
restructuring any control flow. An empty table here is a **result**: on the complexity half of the
release gate, this commit would pass.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1208 | **Already tracked as `BL-24`** (`docs/audits/2026-08-04/02_DEVIATIONS.md`), with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. Carried forward; −44 this run, moving the right way under its own ID. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1132 | **Accepted** — carried forward unchanged, and the entry itself did not move a line this run. The test-data generator (`makeTestEntry`/`seedCoverage`/`bulkMovements`/`goldMovements`) is a self-contained block and is still the peel seam if it grows. Shelf life: this record holds exactly **one** release run (`20260910-234511`), so the three-consecutive-releases rule has not been reached. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1028 | **Accepted — arriving, not drifting.** New in this table, but it entered the band from **above**: 1539 and over the cap at the previous run, split in `684107c` into `tests/test_ledger_settling.lua`. Case count, not tangle — avg CCN 1.1 over 135 functions ([`complexity.txt`](complexity.txt)). Re-check trigger: 1200 LOC, at which the settling/marks boundary is the next seam. |

`tests/test_panel.lua` left this table entirely (1580 → 783) and needs no disposition.

## Actions

None. All four actions from [`../20260916-094506/ANALYSIS.md`](../20260916-094506/ANALYSIS.md) are
closed by the commits between the two runs: the CCN 17 function is at 15 or below, both over-cap
files are split, and the fourth — deciding whether over-cap suite files wanted a deviation row —
is answered by there being none. The standing gap is not an action item but a stated absence:
**this addon still ships no `tests/perf.lua`**, so `performance-§9`'s zero-overhead evidence does
not exist for it and every run in this record is silent about runtime cost. Adding one is a
scheduling decision for the addon, not a finding of this run.
