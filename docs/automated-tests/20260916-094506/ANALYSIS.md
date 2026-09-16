# Analysis — 20260916-094506

- **Addon:** BankLedger 1.1.0
- **Verdict:** green
- **Commit:** `beaf599d1b059b757fb0565bb9c80a9715c276c9` (master), clean
- **Previous run:** `20260910-234511`

## Headline

Both gating suites pass: `luacheck` is clean over 61 files and the harness runs 913 cases with no
failure and no skip, up 64 cases from the previous run. `perf` is the same permanent skip this addon
has always recorded — it ships no `tests/perf.lua`, so this run says nothing about runtime cost.
The thing to act on is complexity, which is recorded and gates nothing here but gates the tag:
`Sl:ResetEverything` crossed to **CCN 17**, the first warned function since `20260804-233144`, and
two suite files crossed the `layout-§1` 1500-line cap. The CCN row alone is enough to make the next
`/wow-addon:bump-version` refuse, so it is owed a fix rather than an acceptance.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260910-234511` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 61 files | [`lint.txt`](lint.txt) | unchanged — 0/0 over the same 61 files |
| tests | pass | 913 passed, 0 skipped, 0 failed, 913 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +64 cases (849 → 913) |
| perf | skip | no `tests/perf.lua` — this addon ships no offline scenarios | none — nothing ran | unchanged; skipped on every run this record holds |
| complexity | pass | 1 warning (CCN 17); see below | [`complexity.txt`](complexity.txt) | first warned function since `20260804-233144` |

**Complexity is reported in full**, totals and averages both. Every value is
[`manifest.json`](manifest.json)'s `suites.complexity`, which is `lizard`'s own footer in
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 15821 |
| Functions | 2401 |
| Avg NLOC / function | 5.9 |
| Avg CCN | 2.0 |
| Max CCN | 17 |
| Avg tokens / function | 46.7 |
| Warnings (CCN > 15) | 1 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 2 |

**`perf` — a skip, not a pass.** `manifest.json` records
`skipReason: "no tests/perf.lua — this addon ships no offline scenarios"`. That is the first of
`automated-tests-§3`'s two sanctioned reasons — *nothing to run* — and **not** a ratified
`performance-§12` no-combat-path exemption, which this addon does not hold. Nothing in this bundle
says BankLedger is cheap; the question was not asked. At a release this suite is **NOT EVALUATED**
rather than passed, and the release notes have to say so out loud.

**`complexity` — a pass that carries a signal.** The suite passes because it never fails; the
warning is the content. `Sl` at `settings/Slash.lua:132-152` is `Sl:ResetEverything`, CCN 17.
Reading it against `performance-§10`: the function is a flat list of guarded teardown calls —
`if db and db.global`, `NS.defaults and NS.defaults.global or {}`,
`if LT and LT.IsTestMode and LT:IsTestMode()`, then four `if NS.X and NS.X.Y then` lines — with no
nesting at all. `lizard` scores every `and`/`or` as a decision, so this is dense **guarding**, not
tangled control flow, and it wants an extracted helper rather than a restructure. It is a
regression in the narrow sense that it crossed on the two commits since the previous run, and a
pre-existing shape in the sense that the function was already CCN 14 and merely gained three more
short-circuits.

## What moved

- **lint** — did not move. 0 warnings / 0 errors over 61 files at both runs
  ([`lint.txt`](lint.txt)), with the same `.luacheckrc` exclusions (`libs/`, `docs/audits/`,
  `docs/reviews/`, `_dev/`, `tests/_kit/`) out of scope at both.
- **tests** — **849 → 913**, +64, all passing, none skipped. The growth is the settings-panel and
  Master-controls work in commits `420af9b` and `beaf599`; `tests/test_panel.lua` alone carries most
  of it.
- **perf** — did not move and cannot: skipped on every run in [`../RESULTS.md`](../RESULTS.md).
- **complexity totals** — NLOC 14669 → 15821 (+1152), functions 2188 → 2401 (+213). The addon grew.
- **complexity averages** — avg NLOC/function 6.0 → **5.9**, avg CCN **2.0 → 2.0** (unchanged), avg
  tokens 47.5 → 46.7. This is the distinction the totals hide: the codebase got **bigger**, not
  **denser**. The average function is slightly shorter and no more branchy than a week ago.
- **max CCN** — 15 → **17**, warnings **0 → 1**. `Sl:ResetEverything` was CCN 14 at
  `20260910-234511`'s commit (`d4632ef`); it is 17 here.
- **file bands** — band files 3 → 2, over-cap files **0 → 2**. `tests/test_ledger.lua` left the
  on-notice band by going over the cap (1478 → 1539), and `tests/test_panel.lua` went 840 → 1580,
  skipping the band entirely.
- **Bundles without an analysis.** Noting this once, as `automated-tests-§5` asks and without
  backfilling: **2 of the 9** earlier bundles in this repo carry no `ANALYSIS.md`
  (`20260807-110442`, `20260825-103400`). Both are frozen and stay that way.

## Complexity watch list

Generated from this run's own `lizard` output; the dispositions are this analysis's, and the same
cells are authored into [`../RESULTS.md`](../RESULTS.md).

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `Sl` (`Sl:ResetEverything`) | 17 | `settings/Slash.lua:132-152` | **Peel next — release-gate blocker.** Dense guarding, not tangle; the trailing optional-subsystem resets lift into one helper. New this run. |

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1252 | Already tracked as `BL-24` (`docs/audits/2026-08-04/02_DEVIATIONS.md`); +1 since the previous run. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1132 | Accepted — carried forward; +36 since the previous run, still the test-data generator as the peel seam. |
| > 1500 (over cap) | `tests/test_ledger.lua` | 1539 | **Over cap — split by concern.** New here; the previous run's disposition predicted exactly this. |
| > 1500 (over cap) | `tests/test_panel.lua` | 1580 | **Over cap — split one file per page.** New here; 840 → 1580 in two commits, never on notice first. |

Two of the four rows are new this run and neither is owned by an existing deviation ID — `BL-24` is
the on-notice band entry for `modules/Browser.lua` and does not reach a file over the cap.

## Actions

1. **`settings/Slash.lua:132-152` — reduce `Sl:ResetEverything` below CCN 15.** Extract the trailing
   run of optional-subsystem resets (`NS.Browser`, `NS.SessionWindow`, `NS.Panel`, the Test-mode
   teardown) into one helper that iterates a table of `{ object, method }` pairs. This is the only
   item that blocks a tag: `automated-tests-§3`'s release gate is zero functions above CCN 15. New
   here — no deviation ID, no review finding owns it.
2. **`tests/test_panel.lua` (1580 LOC) — split.** Over the `layout-§1` cap by 80 lines. One file per
   settings page; the Master-controls cases are already contiguous. New here, untracked.
3. **`tests/test_ledger.lua` (1539 LOC) — split.** Over the cap by 39 lines, and the previous run's
   watch list already named the trigger. Split capture-arming from entry-shape cases. New here,
   untracked.
4. **Decide whether over-cap suite files want a deviation row or a fix.** `BL-24` covers the
   on-notice band only. If the split is not being scheduled, `docs/ARCHITECTURE.md`'s
   `## Documented deviations` register is where that decision belongs — this analysis does not make
   it.
