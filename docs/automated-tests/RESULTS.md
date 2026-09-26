# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

The **Tests** cell reads `passed/skipped/total`.

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260926-193102`](20260926-193102/) | `d67564c` | clean | 1.1.0 | 0/0 | 76 | 1104/0/1104 | skip | 19199 | 2921 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260926-160240`](20260926-160240/) | `0851298` | clean | 1.1.0 | 0/0 | 75 | 1104/0/1104 | skip | 19172 | 2918 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260924-105040`](20260924-105040/) | `fff9780` | clean | 1.1.0 | 0/0 | 72 | 1061/0/1061 | skip | 18306 | 2765 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260916-184426`](20260916-184426/) | unknown | unknown | 1.1.0 | 0/0 | 67 | 943/0/943 | skip | 16380 | 2498 | 5.9 | 2.0 | 15 | 0 | **green** |
| [`20260916-094506`](20260916-094506/) | unknown | unknown | 1.1.0 | 0/0 | 61 | 913/0/913 | skip | 15821 | 2401 | 5.9 | 2.0 | 17 | 1 | **green** |
| [`20260910-234511`](20260910-234511/) | unknown | unknown | 1.0.0 → 1.1.0 | 0/0 | 61 | 849/0/849 | skip | 14669 | 2188 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260908-181253`](20260908-181253/) | unknown | unknown | 1.0.0 | 0/0 | 59 | 844/0/844 | skip | 14455 | 2181 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260825-103400`](20260825-103400/) | unknown | unknown | 1.0.0 | 0/0 | 28 | 791/791 | skip | 13409 | 2043 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260807-115101`](20260807-115101/) | unknown | unknown | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260807-110442`](20260807-110442/) | unknown | unknown | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260807-023005`](20260807-023005/) | unknown | unknown | 1.0.0 | 0/0 | 24 | 727/727 | skip | 12735 | 1942 | 6.0 | 2.0 | 15 | 0 | **green** |
| [`20260804-233144`](20260804-233144/) | unknown | unknown | 1.0.0 | 0/0 | 24 | 726/726 | skip | 12788 | 1946 | 6.0 | 2.1 | 15 | 0 | **green** |
| [`20260804-214843`](20260804-214843/) | unknown | unknown | 1.0.0 | 0/0 | 24 | 726/726 | skip | 12788 | 1946 | 6.0 | 2.1 | 0 | 0 | **green** |
| [`20260804-182039`](20260804-182039/) | unknown | unknown | 1.0.0 | 0/0 | 24 | 689/689 | skip | 12085 | 1773 | 6.2 | 2.2 | 33 | 15 | **green** |

## Test suite

**1104 cases** — 1104 passed, 0 failed, 0 skipped. The generated inventory
[`20260926-193102/test-cases.md`](20260926-193102/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Unchanged from the previous run at 1104 cases.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 76 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 5 path(s) from it — `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**This repo holds a ratified `performance-§12` no-combat-path exemption, so `perf` is a
permanent `skip`** — the second of `automated-tests-§3`'s two sanctioned reasons, read by
this runner from the `## Documented deviations` register in `docs/ARCHITECTURE.md`. The exemption, and the sweep behind it, are in
`docs/performance.md`: this record carries no scenario table because the addon has no
combat path for one to measure, not because the question was never asked.

## Complexity watch list

Current as of [`20260926-193102`](20260926-193102/) — **this run's measurement, not its diff.** Max CCN **15** across 2921
functions, **0** of them warned on; 4 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Browser.lua` | 1221 | **Accepted — already tracked as `BL-24`** (`docs/audits/2026-08-04/02_DEVIATIONS.md`), with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. 1221 at `20260926-193102`, unchanged since `20260924-105040`; avg CCN 3.1 over 101 functions ([`20260926-193102/complexity.txt`](20260926-193102/complexity.txt)). The 1208 → 1221 rise since `20260916-184426` (+12 of it the stand-down latch in `a769125`) withdrew the earlier *moving the right way* note, and it stays withdrawn. |
| 1000–1500 (on notice) | `modules/Insights.lua` | 1002 | **Accepted.** 1002 at `20260926-193102`, unchanged since it crossed at `20260924-105040` (992 → 1002, the stand-down latch in `a769125`, +10, not a new renderer). Avg CCN 3.6 over 65 functions ([`20260926-193102/complexity.txt`](20260926-193102/complexity.txt)): section renderers, not tangle; `I` at `:505` sits at CCN 15, on the line. Peel seam: `I:Layout` / `I:LayoutSections` and the `I:Render*` section renderers they drive lift into a sibling file. Re-check trigger: 1300 LOC, or a new section renderer. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1139 | **Accepted** — carried forward; 1139 at `20260926-193102`, unchanged since `20260924-105040` (1132 → 1139 since `20260916-184426`, the printer-argument change in `17568e2`). Avg CCN 3.0 over 101 functions ([`20260926-193102/complexity.txt`](20260926-193102/complexity.txt)); two `LT` closures (`:599`, `:905`) sit at CCN 15. The test-data generator (`makeTestEntry`/`seedCoverage`/`bulkMovements`/`goldMovements`) is a self-contained block and is still the peel seam if it grows. Shelf life: this record holds exactly **one** release run (`20260910-234511`), so the three-consecutive-releases rule has not been reached. |
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1028 | **Accepted — arriving, not drifting.** 1028 at `20260926-193102`, unchanged since it entered the band from **above** at `20260916-184426` (1539 and over the cap at `20260916-094506`, before `684107c` split it into `tests/test_ledger_settling.lua`). Case count, not tangle — avg CCN 1.1 over 135 functions ([`20260926-193102/complexity.txt`](20260926-193102/complexity.txt)). Re-check trigger: 1200 LOC, at which the settling/marks boundary is the next seam. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

