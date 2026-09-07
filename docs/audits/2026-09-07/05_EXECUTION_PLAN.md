# 05 · Execution plan — Ka0s Bank Ledger — 2026-09-07

Hand-off to the separate remediation engagement. Keyed to `02_DEVIATIONS.md`; designed in
`04_TECHNICAL_DESIGN.md`. **7 open roots, 0 dependents; 0 High, 0 Medium, 7 Low; 6 of the 7 fail a
MUST.** Figures here are the same ones those two documents carry — 4 straggler files, 3 band files,
831/831 tests, 14 174 NLOC / 2 153 functions.

Three sprints. Sprint 1 is an hour of documentation. Sprint 2 needs one decision from the
maintainer. Sprint 3 crosses a repo boundary. Nothing here is urgent, because nothing here is
reachable by a user.

---

## Sprint 1 — the paperwork (BL-04, BL-29)

Self-contained, no decision required, no code touched.

| # | Step | Closes | Done when |
|---|---|---|---|
| 1.1 | Add the `localization-§1` row to `docs/ARCHITECTURE.md`'s register: What differs = *no user-facing string routes through `NS.L`*; Why = `locales/enUS.lua:8-13` + issue #3; Decided = **2026-07-31**; Re-check = *the first non-English locale file added to `locales/`*. | **BL-04** | The row is present with a `filename-§N` Rule, a date and a trigger. |
| 1.2 | Close issue #3 with `state:done`, commenting the register line the row landed on. | **BL-04** | `gh issue view 3` shows `state:done`. |
| 1.3 | Add `  - .superpowers` and `  - .pkgmeta` to `.pkgmeta`'s ignore list. | **BL-29** | The dot-entry sweep in `03_EVIDENCE.md` §9 prints only `UNACCOUNTED — .git`. |
| 1.4 | Green gate: `lua tests/run.lua` and `luacheck .`. | — | 831/831, 0/0. |

**Commit.** `docs: ratify the English-only decision, and stop shipping .superpowers`

## Sprint 2 — the close control (BL-28)

**Blocked on one maintainer decision.** Do not start until it is made.

| # | Step | Closes | Done when |
|---|---|---|---|
| 2.0 | **Decide**: ratify (recommended), adopt, or upstream. `04_TECHNICAL_DESIGN.md` states the cost of each. | — | A decision is recorded in issue #5 as a comment. |
| 2.1a | *(if ratify)* Add the `standalone-windows` register row per `04_TECHNICAL_DESIGN.md`'s draft, with the re-check trigger. | **BL-28** | The row is present; a re-audit reads it as accepted. |
| 2.1b | *(if adopt)* Publish `NS.MakeCloseButton` in `core/CoreSetup.lua` beside `NS.ApplySkin` (`:112`) plus a degraded twin; delete the factory at `modules/Browser.lua:98`; repoint `modules/Browser.lua:1047`, `modules/SessionWindow.lua:485`, `modules/Export.lua:362`; rewrite `tests/test_marks.lua:74-91` and `:473`; add a smoke-test row for the four title bars. | **BL-28** | `grep -rn 'MakeCloseButton(' --include='*.lua' . \| grep -v '/libs/' \| grep -v '/tests/'` returns the wrapper and three calls. |
| 2.2 | Either way: file the upstream issue on `WowAddonStandards` about the MAY/MUST tension in `standalone-windows`, referencing BL-28. | — | The issue exists and is linked from issue #5. |
| 2.3 | Green gate. | — | 831/831 (or the new total, if 2.1b), 0/0. |

**Commit.** `docs: ratify the host close-control factory` — or, under 2.1b,
`feat(windows): every close control through the LibKa0s wrapper`

## Sprint 3 — the record, and the upstream figure (BL-30, BL-31, BL-33)

Runs **after** sprints 1 and 2, so the bundle it freezes is the remediated tree.

| # | Step | Closes | Done when |
|---|---|---|---|
| 3.1 | File the `LibKa0s` issue for the missing `skipped` figure: regex at `run-automated-tests.sh:195`, `"skipped"` in the manifest's `tests` object (`:369`), the `RESULTS.md` column and its generated lead-in. | **BL-33** (upstream half) | The issue exists, labelled `state:triaged`. |
| 3.2 | **Either** wait for the kit fix and re-vendor first, **or** take the bundle now — never across a re-vendor. | — | The order is chosen and stated in the commit message. |
| 3.3 | `tests/_kit/run-automated-tests.sh` — all four suites. | **BL-30** (table half) | A new dated bundle exists; its `manifest.json` matches today's measured 14 174 NLOC / 2 153 functions ± the sprint's edits. |
| 3.4 | Hand-write the new bundle's `ANALYSIS.md`, saying what moved since `20260825-103400` (+765 NLOC, +110 functions, +40 tests) and why. | **BL-31** | The file exists and follows the root `AUTOMATED_TESTS.md` prompt. Do **not** back-fill the two older bundles. |
| 3.5 | Roll `RESULTS.md`'s four standing sections and both watch tables forward from `20260807-115101` to the new run; re-read the three band LOC figures. | **BL-30** | No sentence in the file names a run older than the newest row at `:23`. |
| 3.6 | If the kit was re-vendored at 3.2: update `CLAUDE.md:46`'s tag **in the same commit as the bytes**, regenerate `docs/test-cases.md`, re-run the green gate. | **BL-33** (local half) | `tests/test_vendor_sync.lua` passes against the new tag; `RESULTS.md`'s `Tests` column carries a skipped figure. |

**Commit.** `automated-tests: record run <stamp>, and roll the standing sections forward`

## Sprint 4 — the whitespace commit (BL-32)

**Last, and alone.**

| # | Step | Closes | Done when |
|---|---|---|---|
| 4.1 | `git add .gitattributes && git add --renormalize . && git status` — review, then delete and re-check-out any file still wrong on disk. | **BL-32** | The `line-endings-§7` command in `03_EVIDENCE.md` §7 prints `0`. |
| 4.2 | Green gate, then commit **nothing else** in this commit. | — | The diff is whitespace only. |

**Commit.** `chore: renormalize the working tree against the CRLF pin`

---

## Verification — the whole plan is done when

```sh
luacheck .                                            # 0 warnings / 0 errors
lua tests/run.lua                                     # all pass, 0 skipped
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .     # no thresholds exceeded
```

and:

- `docs/ARCHITECTURE.md`'s register carries **five** rows — the three from today plus
  `localization-§1` and, if ratified, `standalone-windows`;
- the dot-entry sweep prints only `UNACCOUNTED — .git`;
- the `line-endings-§7` count is `0`;
- `docs/automated-tests/RESULTS.md`'s newest row and every standing section name the **same** run,
  and its figures match a fresh `lizard`;
- issue #3 is `state:done` and issue #5 carries the decision.

## Deliberately not in this plan

BL-07, BL-11…BL-17 and BL-34 are register rows, not work items — the first two accepted, the third
a maintainer decision with `the next release` as its own trigger. BL-24's three on-notice files are
under the cap with current dispositions and a release clock that has not started. `libs/LibKa0s/`
is audited in its own repo and has not drifted from the v1.25.0 tag `CLAUDE.md:46` names.
