# Analysis — 20260807-115101

- **Addon:** BankLedger 1.0.0
- **Verdict:** green
- **Commit:** d888c217f3e6b2e9445fd588584e019c8bac4e4a (master)
- **Previous run:** [`20260807-110442`](../20260807-110442/)

## Headline

Green, and every figure is byte-for-byte what the previous run measured — same tree, same 727 cases,
same 12735 NLOC over 1942 functions, zero lint findings and zero complexity warnings. Nothing moved
because nothing in the addon changed between the two runs; the only commits since are the
`.gitattributes` re-sync and the LibKa0s v1.8.2 re-vendor, neither of which touches shipped source.
There is nothing to act on. What this run *does* carry that its predecessor could not is the
end-to-end confirmation of the kit revision 10 `normalize_eol` pass — see *What moved*.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since `20260807-110442` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 24 files | [`lint.txt`](lint.txt) | No change (0/0 over 24 files) |
| tests | pass | 727 passed, 0 skipped, 0 failed, 727 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | No change (727/0/727) |
| perf | skip | 0 scenarios — no `tests/perf.lua` | — (nothing produced) | No change — a standing skip, not a new one |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | No change on any of the eight footer fields |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is from [`manifest.json`](manifest.json)'s `suites.complexity`, which records
all eight of `lizard`'s footer fields; the footer itself is at the end of
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 12735 |
| Functions | 1942 |
| Avg NLOC / function | 6.0 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 48.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

Totals and averages tell the same story here, which is the uninteresting case and worth saying so
explicitly: the total did not rise, so there is no "the addon grew" reading to separate from a "the
addon got denser" one. Both are flat.

**`perf` — the one suite that is not a clean pass.** It is a `skip`, and a **standing** one rather
than a tooling gap: the addon ships no `tests/perf.lua`, so there was nothing to run. That absence is
ratified — BankLedger holds a recorded `performance-§12` no-combat-path exemption, registered in
[`../../ARCHITECTURE.md`](../../ARCHITECTURE.md) and evidenced by the whole-repo sweep in
[`../../performance.md`](../../performance.md). Two consequences follow and neither is news: this run
says **nothing** about the addon's in-combat runtime cost, and `performance-§9`'s zero-overhead
evidence does not exist for this addon. A skip is not a pass, and at the release gate it is NOT
EVALUATED (`automated-tests-§3`).

One recording detail worth leaving for the next reader: the manifest's `skipReason` reads
`no tests/perf.lua — this addon ships no offline scenarios`, which is §3's sanctioned reason **(1)**,
while the truer fact about this addon is reason **(2)** — the ratified `performance-§12` exemption
that is *why* it ships no `tests/perf.lua`, and which §3 calls the more informative of the two. The
runner cannot know about the exemption; it sees only an absent file. So the exemption is named here
and in `RESULTS.md`'s `## Perf` section rather than in the manifest, and nothing in the bundle is
hand-corrected for it.

## What moved

Nothing measurable, and that is a real reading rather than a missing one:

- **lint** — 0 warnings / 0 errors over 24 files, unchanged. The same 24 shipped files in scope.
- **tests** — 727 passed / 0 skipped / 727 total, unchanged. No case added or removed, and no case
  reported a skip.
- **perf** — `skip` with the same `skipReason`, unchanged. Permanent by design.
- **complexity** — all eight footer fields identical: 12735 NLOC, 1942 functions, avg NLOC 6.0, avg
  CCN 2.0, max CCN 15, avg tokens 48.0, 0 warnings, both warning rates 0.00. `bandFiles` stays 3 and
  `overCapFiles` stays 0. The same five functions sit at CCN 15; none moved.

The one thing that **did** move sits outside the numbers. This is the first bundle in this repo
written by **LibKa0s v1.8.2 / test-kit revision 10**, whose `normalize_eol` pass writes each artifact
with the line ending `.gitattributes` declares instead of unconditionally LF. This repo is
CRLF-pinned (`* text=auto eol=crlf`), and every file in this bundle came off the runner with matched
CR and LF byte counts — `complexity.txt` 2002/2002, `tests.txt` 729/729, `test-cases.md` 820/820,
`lint.txt` 26/26, `manifest.json` 19/19 — as did `RESULTS.md` at 133/133. Counted with
`tr -dc '\r' < f | wc -c` against `tr -dc '\n' < f | wc -c`, not `file(1)`, which reports nothing
about terminators for JSON or for a one-line file and so passes files it never examined
(`line-endings-§7`). Earlier bundles read CRLF on disk too, but they are committed, so their bytes
are a checkout artifact and prove nothing about the writer; this bundle was untracked when it was
measured, which is what makes it evidence.

Also worth recording against the previous row: [`20260807-110442`](../20260807-110442/) carries **no
`ANALYSIS.md`**. It is frozen and stays that way (`automated-tests-§1`); this is the first write-up
since [`20260807-023005`](../20260807-023005/ANALYSIS.md), and the figures it would have reported are
identical to these.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| — | — | — | **None.** |

Zero warned functions, for the fourth consecutive run. That is the result, not an empty section.

The highest CCN anywhere in the tree is **15** — at the cap, not under it with room — and **five**
functions sit there, unchanged from the previous run: `accumulateItemTaxonomy`
(`core/Database.lua:234`), `I:Layout` (`modules/Insights.lua:505`), `L:GateReason`
(`modules/Ledger.lua:402`), `LT:UpdateHeaderArrows` (`modules/LedgerTable.lua:827`) and `ensureFrame`
(`modules/SessionWindow.lua:441`). All five are dense **defaulting and guarding**, not tangled control
flow: `lizard` scores every `and`/`or` short-circuit as a decision, so a run of Lua guard clauses
reads high with no visible branching. None is a warning and none is over the cap, but with no headroom
left, the next edit to any of the five is the one that would trip the release gate.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_ledger.lua` | 1402 | **Accepted.** A suite grows with the cases it pins, and this one covers the addon's core mechanic. Unchanged this run. Split by concern if it passes 1500. |
| 1000–1500 (on notice) | `modules/Browser.lua` | 1358 | **Already tracked as `BL-24`** (`docs/audits/2026-08-04/02_DEVIATIONS.md`), with the peel seam named: the skin/close-button factory and the geometry persistence lift into a sibling file. Unchanged this run. |
| 1000–1500 (on notice) | `modules/LedgerTable.lua` | 1052 | **Accepted for now.** Entered the band at `20260804-214843` and unmoved since. The test-data generator (`makeTestEntry`/`seedCoverage`/`bulkMovements`/`goldMovements`) is a self-contained block and is the peel seam if it grows. |

Nothing newly crossed a band or a CCN threshold this run, and nothing is over the 1500-LOC cap.

On shelf life (`automated-tests-§4`, anti-pattern #53): the clock for a carried "Accepted" runs in
**release** runs, and every manifest under `docs/automated-tests/` still records `"release": null` —
including this one. No disposition here has spent a single release, so none is stale.
`tests/test_ledger.lua` and `modules/LedgerTable.lua` are the two whose clocks start when the first
release run lands; `modules/Browser.lua` points at a tracked ID and is not subject to the clock.

## Actions

None. No suite regressed, nothing newly crossed a threshold, and no disposition is owed a fix or a
deviation ID. The two standing facts that persist — the `perf` skip under the `performance-§12`
exemption, and the five functions parked at CCN 15 with no headroom — are already recorded in
`RESULTS.md` and need no new work from this run.
