# 02 · Deviations — Ka0s Bank Ledger — 2026-09-07

Audited against the **Ka0s WoW Addon Standard v2.38.0 (2026-09-02)**.

Deviation IDs are stable per-addon (`BL-NN`). `BL-01`…`BL-05` come from 2026-07-26, `BL-06`…`BL-10`
from 2026-07-27, `BL-11`…`BL-24` from 2026-08-04, `BL-25`…`BL-27` from 2026-08-05. **`BL-28`…`BL-33`
are new this run.** A recurring deviation keeps its ID.

*Digest mapping (for the cross-repo consolidation only): `BANKLEDGER-A-01` = BL-04,
`-02` = BL-28, `-03` = BL-29, `-04` = BL-30, `-05` = BL-31, `-06` = BL-32, `-07` = BL-33.*

---

## Tally, with its basis stated

**Headline (roots only): 7.** **Total including `derived from` dependents: 7** — no dependent rows
this run; every open finding stands on its own cause.

| Grade | Roots | Total |
|---|---|---|
| High | 0 | 0 |
| Medium | 0 | 0 |
| Low | 7 | 7 |
| Info | — | 4 (recorded / advisory, excluded from the tally) |

**MUST failures: 6 of the 7 roots** (BL-04, BL-28, BL-29, BL-30, BL-32, BL-33). BL-31 fails a
SHOULD. Every one of the six is **doc-only or config-only and therefore graded Low** — the grade is
impact, the MUST is named in each entry, and neither reading cancels the other.

Nothing in this addon is reachable by a user as a defect today. The seven open items are a missing
register row, a structural close-button seam, one unignored dot-directory, a stale test record, two
missing write-ups, four unrenormalized files and one figure the vendored runner does not emit.

## Summary — open this run

| ID | Section | Rule strength | Grade | Summary |
|---|---|---|---|---|
| BL-04 | `localization-§3` (with `documentation-§3`) | MUST | Low | The English-only decision is recorded in a code comment and a triaged issue, not as a `## Documented deviations` row — so `localization-§3`'s terminal state 2 is not reached. |
| **BL-28** | `standalone-windows` (with `documentation-§3`) | MUST | Low | No one-line `MakeCloseButton` wrapper in `core/CoreSetup.lua`; the addon builds its own factory, and the decline (`state:will-not-do` #5) has no register row. |
| **BL-29** | `packaging` | MUST | Low | `.superpowers/` is a root dot-directory with no `.pkgmeta` ignore row — agent tooling inside the packaged AddOn. |
| **BL-30** | `automated-tests-§4`/`§6` (anti-pattern #51) | MUST | Low | The automated-test record is stale: newest bundle is 13 409 NLOC / 2 043 fn / 791 tests against today's 14 174 / 2 153 / 831, and the standing prose still reads "as of `20260807-115101`". |
| **BL-31** | `automated-tests-§5` | SHOULD | Low | `20260807-110442/` and `20260825-103400/` carry no `ANALYSIS.md`, and both were runs whose numbers moved. |
| **BL-32** | `line-endings-§1`/`§7` | MUST | Low | 4 tracked files disagree with the declared CRLF pin. |
| **BL-33** | `automated-tests-§4` | MUST | Low | The `Tests` column and `manifest.json` carry passed/total with **no `skipped` figure**; the vendored runner never emits one. |

## Summary — recorded and advisory (Info; excluded from the tally)

| ID | Section | Basis |
|---|---|---|
| BL-07 | `savedvariables-§2` | **Accepted.** Register row, `docs/ARCHITECTURE.md:231`, Decided 2026-07-27. Rule text unchanged in v2.38.0, so the row is still live rather than a graveyard entry. |
| BL-11…BL-17 | `performance-§12` | **Accepted, as one row.** `docs/ARCHITECTURE.md:230`, Decided 2026-08-05, citing issue #9. `savedvariables-§4` now states explicitly that an exempt addon **MUST NOT** declare `<Addon>PerfDB`, which retires BL-12 outright. |
| BL-34 | `options-ui-§12` | **Recorded, decision open.** `docs/ARCHITECTURE.md:232`, Decided 2026-09-02. Its own trigger — "re-check at the next release" — is the thing to watch. |
| BL-24 | `layout-§1` | **Advisory.** Three files in the 1000–1500 on-notice band; none over the 1500 cap. |

## Summary — closed since 2026-08-05

| ID | Was | Now |
|---|---|---|
| BL-11…BL-17 | MUST, open/unratified | **Closed — ratified.** The `performance-§12` register row now exists. |
| BL-18 | MUST | **Closed.** `modules/Browser.lua:6` and `modules/LedgerTable.lua:5` bind `local print = NS.Print`; no global-`print` site survives in `core/`, `modules/` or `settings/`. |
| BL-19 | SHOULD | **Closed.** `modules/Browser.lua:74-76` delegates to `NS.ApplySkin`, which is `lib.ApplySkin` (`core/CoreSetup.lua:112`); the restated values survive only in the library-absent branch, where they belong. |
| BL-20 | SHOULD | **Closed.** Retired `§N.M` notation sweep over live source and live docs returns **0** hits. |
| BL-23 | MAY | **Closed.** `docs/pending/LEDGER.md` is gone; its rows are GitHub issues with `state:` labels. |
| BL-25 | MUST | **Closed.** The release gate is stated in `docs/automated-tests/RESULTS.md:9-14` and `docs/testing.md:69-98`. |
| BL-26 | SHOULD | **Closed.** `tests/_kit/run-automated-tests.sh` is committed `100755`. |
| BL-27 | MUST | **Closed.** The kit's `vendor_sync.lua` now uses `T.skip` rather than a bare `return`; both cases genuinely ran and passed today against the present sibling checkout. |

---

## BL-04 · The English-only decision has no register row

**Section.** `localization-§3` (terminal state 2), with `documentation-§3` · **MUST** · **Low.**

**Rule.** `localization-§3`: an addon shipping English only is *"compliant, and the matter is
closed"* when *"that decision is a row in its `## Documented deviations` register citing
`localization-§1`, with a re-check trigger: the first non-English locale file added to
`locales/`."* `documentation-§3`: *"a deviation not in the register is not ratified."*

**State.** Both `localization-§3` MUSTs are met — `NS.L` is exported (`locales/enUS.lua:6`) and
`enUS.lua` ships. The routing decline is reasoned at `locales/enUS.lua:8-13` and tracked as open
issue #3 (`state:triaged`, `severity:low`), which says in as many words that *"the next
standards-audit will re-raise BL-04 until it lands."* `docs/ARCHITECTURE.md:230-232` carries three
rows and none of them is `localization-§1`.

**Why it is Low.** No user can reach a heading. It is nonetheless a MUST, and it is the fourth
consecutive audit to say so — which is exactly the cost `documentation-§3` describes.

**Fix.** One row: `` | `localization-§1` | No user-facing string routes through `NS.L` … | … |
2026-07-31 | The first non-English locale file added to `locales/` | ``. Then close issue #3
`state:done`.

---

## BL-28 · No `LibKa0s-Core-1.0` close-button wrapper, and the decline is unratified

**Section.** `standalone-windows` (*One wrapper, and every close control goes through it*), with
`documentation-§3` · **MUST** · **Low.**

**Rule.** *"An addon **MUST** wrap the seam exactly once, in its `LibKa0s-Core-1.0` setup file — a
one-line passthrough that supplies `addonName` from the file's own first vararg — and every close
control it builds, on any window, **MUST** be built through that wrapper."*

**State.** `core/CoreSetup.lua:117-129` states, deliberately, that `lib.MakeCloseButton` **is not
republished**. `modules/Browser.lua:98` defines the addon's own 24×24 class-colour-hover factory,
and all four title bars go through it (`modules/Browser.lua:1047`, `modules/SessionWindow.lua:485`,
`modules/Export.lua:362`). The decline is closed issue #5 (`state:will-not-do`). There is **no
register row** for it.

**What is *not* wrong here.** The grep returns the addon's own factory and its callers and nothing
else — there is **no** two-argument `lib.MakeCloseButton(...)` call anywhere outside `libs/`, so
**anti-pattern #65 does not apply**. The mark itself is the shared catalog's, resolved through
`NS.Icon` (`modules/Browser.lua:104`), with the documented fallback ladder beneath it. The library's
own windows keep the library's control. So no window in this addon draws `×` beside one drawing the
mark, which is the harm the MUST exists to prevent.

**The standard is in tension with itself here, and that is part of the finding.**
`standalone-windows` says both *"a host **MAY** draw a different one on **its own** windows where
the design calls for it"* and *"every close control it builds, on any window, **MUST** be built
through that wrapper"*. A host that exercises the MAY cannot satisfy the MUST as written, because
the mandated wrapper is a passthrough to an 18×18 fixed-red-hover control. Raise this upstream
alongside whichever local route is chosen.

**Fix — pick one.**
1. **Ratify.** Add the register row citing `standalone-windows`, Why citing issue #5 and
   `core/CoreSetup.lua:117-129`, with a re-check trigger (*the library's factory gains a size/hover
   descriptor*). Lowest cost, and it is how BL-07 and the `performance-§12` cluster were settled.
2. **Adopt.** Publish the one-line wrapper and route `B:MakeCloseButton` through it — a design
   change to two visible controls.
3. **Upstream.** Propose that `standalone-windows` say what a host exercising the shape MAY owes:
   most plausibly *one* host factory, named and greppable, rather than a passthrough.

---

## BL-29 · `.superpowers/` is not in the package ignore list

**Section.** `packaging` · **MUST** · **Low.**

**State.** The playbook's dot-entry sweep over the repo root prints `UNACCOUNTED — .superpowers`
and `UNACCOUNTED — .pkgmeta` (`.git` needs no row). `.superpowers/sdd/.gitignore` is on disk, so
the directory is real and the packager will carry it into the shipped AddOn. `.pkgmeta` is the
packager's own manifest and is the cheap second line.

**Why it is Low.** A stray directory inside the AddOn folder is not something a player can hit as a
defect — but it is the concrete, player-facing consequence the check was added for after five
addons shipped one.

**Fix.** Two lines after `.pkgmeta:8`: `  - .superpowers` and `  - .pkgmeta`.

---

## BL-30 · The automated-test record is stale against the tree

**Section.** `automated-tests-§4` and `§6` (anti-pattern #51) · **MUST** · **Low.**

**State.** The newest run is `20260825-103400`, recorded at `docs/automated-tests/RESULTS.md:23` as
791/791 tests, 13 409 NLOC, 2 043 functions, 28 files. Measured today: 831/831, 14 174 NLOC, 2 153
functions. The whole settings revamp (`abed21a`…`0aec078`, including the LibKa0s v1.25.0 carry)
landed after that run.

Worse than the table, the **standing prose and the watch list were never rolled forward past the
run before last**: `RESULTS.md:41-42` and `:97-98` both say *"current state as of
`20260807-115101`"*, and the band table at `:127-129` cites `tests/test_ledger.lua` 1402,
`modules/Browser.lua` 1358 and `modules/LedgerTable.lua` 1052 against today's **1478**, **1251** and
**1096**. Two of the three moved by more than 50 lines and one crossed in the opposite direction to
its recorded disposition.

**Not a finding.** The addon is not required to gate *commits* on the bundle — `automated-tests-§6`
puts the checkpoint at **release**. This is a finding about the release process and about a record
read as measured.

**Fix.** `tests/_kit/run-automated-tests.sh` with all four suites, then hand-write the standing
sections against the run it produced. Do it in the same change as the next version bump.

---

## BL-31 · Two run bundles carry no `ANALYSIS.md`

**Section.** `automated-tests-§5` · **SHOULD** · **Low.**

**State.** `20260807-110442/` and `20260825-103400/` have `complexity.txt`, `lint.txt`,
`manifest.json`, `test-cases.md` and `tests.txt` but no `ANALYSIS.md`; the other five bundles have
one. `§5` makes the write-up a MUST at a **release** run and a SHOULD *"for any run whose verdict is
not green or whose numbers moved"* — `20260825-103400` moved every number it reports (727 → 791
tests, 12 735 → 13 409 NLOC, 24 → 28 files). Both manifests read `"release": null`, so neither
triggers the MUST.

**Fix.** A bundle is frozen evidence; do not back-fill it. Write the analysis for the **next** run,
and say there what the 20260825 jump was.

---

## BL-32 · Four tracked files disagree with the declared CRLF pin

**Section.** `line-endings-§1` (with `§7`) · **MUST** · **Low.**

**State.** `.gitattributes` is correct and byte-identical to the canonical client-bound body, but
the working tree has not been renormalized against it: the `line-endings-§7` command reports **4**.
Reported as one rolled-up finding by the section's own instruction; the files are **not**
enumerated, because the fix is one action.

**Expect this number to be lower than a pre-v2.28.1 bundle's** for the same repo — the old command
counted binaries and JSON as strays. Prior audit folders are frozen and are not edited to match.

**Fix.** `git add .gitattributes && git add --renormalize . && git status`, then delete and
re-check-out any file still wrong on disk.

---

## BL-33 · The tests figure carries no `skipped` count

**Section.** `automated-tests-§4` · **MUST** · **Low** · **Upstream: `LibKa0s` test kit.**

**Rule.** *"The `tests` column **MUST** carry the **skipped** figure alongside passed and total, and
**MUST NOT** fold a skip into either."*

**State.** `docs/automated-tests/RESULTS.md:23` reads `791/791`, and the manifest carries
`"passed"`, `"failed"`, `"total"` and no `skipped`. The addon's own runner **does** print it —
today's line is `831 passed, 0 failed, 0 skipped, 831 total` — but
`tests/_kit/run-automated-tests.sh:195` matches only
`[0-9]+ passed, [0-9]+ failed(, [0-9]+ total)?`, so the figure is discarded before it reaches either
artifact.

**Why the addon cannot fix it.** `testing-§1` forbids editing `tests/_kit/` in a consumer, and
`automated-tests-§4` says so of this exact class: *"because the lead-in is runner-generated, one
addon cannot fix its own copy."* The fix lands in the kit and reaches every repo on re-vendor.

**Why it matters even at 0 skipped.** `testing-§11`'s vendored-payload gate skips when the sibling
checkout is absent. On a machine without `../LibKa0s` this record would report `829/829` and claim
coverage two cases never exercised.

**Fix.** File an issue on `LibKa0s`: widen the regex to capture `skipped`, add `"skipped"` to the
manifest's `tests` object and a skipped figure to the `RESULTS.md` column. Re-vendor here.
