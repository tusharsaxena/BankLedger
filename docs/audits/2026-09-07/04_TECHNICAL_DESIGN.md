# 04 · Technical design — remediation — Ka0s Bank Ledger — 2026-09-07

Keyed to the deviation IDs in `02_DEVIATIONS.md`. **Seven roots, zero dependents, zero High, zero
Medium.** This is not a repair engagement; it is a bookkeeping one plus a single design decision.

Every figure quoted here is the one `02_DEVIATIONS.md` and `03_EVIDENCE.md` carry: **4** straggler
files, **3** band files, **831/831** tests, **14 174** NLOC over **2 153** functions, **7** open
roots, **6** MUST failures.

---

## The one thing that is a decision rather than a chore — BL-28

Everything else in this plan is a line in a file. BL-28 asks the maintainer which of three things
the addon's close control is, and the answer changes nothing a player sees under options 1 and 3.

**Recommended: option 1, ratify.** The reasons the standard gives for the wrapper MUST are (i) that
a two-argument call draws `×` beside a window drawing the mark and (ii) that the omission is
invisible to every gate. Neither obtains here: `03_EVIDENCE.md` §12's grep shows one factory and
three calls, the factory resolves the catalog's `close` through `NS.Icon`
(`modules/Browser.lua:104`) with a fallback ladder, and the library's own windows keep the
library's control. What the addon actually deviates from is the *shape* of the seam, not its
effect — and `standalone-windows` itself blesses a host drawing a different close control on its
own windows. The register row is the honest record of a deliberate, argued, currently-harmless
divergence.

**The row to write**, in `docs/ARCHITECTURE.md`'s five-column shape:

- **Rule** — `standalone-windows`
- **What differs** — no one-line `MakeCloseButton` wrapper in `core/CoreSetup.lua`; the addon's own
  24×24 class-colour-hover factory at `modules/Browser.lua:98` serves all four of its title bars,
  while the library's windows keep the library's 18×18 control.
- **Why** — cite closed issue #5 and `core/CoreSetup.lua:117-129`; note that the catalog mark is
  still what is drawn, and that the grep returns only this factory and its callers, so
  anti-pattern #65 does not apply.
- **Decided** — the date the row is written.
- **Re-check trigger** — *the library's factory gains a size or hover-tint descriptor, or a second
  Ka0s addon draws a non-library close control* — either of which makes the wrapper adoptable
  without a visible change.

**Then raise the upstream half.** `standalone-windows` currently says both *"a host MAY draw a
different one on its own windows"* and *"every close control it builds, on any window, MUST be
built through that wrapper"*. Those cannot both hold for a host exercising the MAY. Propose that
the MUST be stated as *one named, greppable host factory* rather than *a passthrough* — which
preserves the whole point of the rule (the grep) while allowing the shape the section explicitly
permits. File it on `WowAddonStandards`, referencing BL-28.

If instead the maintainer wants **option 2 (adopt)**: publish
`NS.MakeCloseButton = function(parent, onClick) return lib.MakeCloseButton(parent, onClick, addonName) end`
in `core/CoreSetup.lua` beside `NS.ApplySkin` (`:112`), give it a degraded twin in the
library-absent branch, delete the factory at `modules/Browser.lua:98`, and repoint the three call sites. That
is a **visible** change to four title bars (24×24 class-colour hover → 18×18 red hover) and needs a
smoke-test row in `docs/smoke-tests.md`; the parity case in `tests/test_marks.lua:74-91` and `:473`
pins the current behavior and would need rewriting. Do not take this route casually — the current
behavior is tested, and the tests are the reason it is safe to leave alone.

## The register rows — BL-04 and BL-28

Both land in the same table (`docs/ARCHITECTURE.md:228-232`), in the same edit, and both are pure
documentation. BL-04's row is already fully drafted by the addon itself: the rationale is
`locales/enUS.lua:8-13`, the trigger is named by `localization-§3` verbatim (*the first non-English
locale file added to `locales/`*), and the Decided date is the one issue #3 records, **2026-07-31**.
Write the row, then close issue #3 with `state:done`.

**Risk: none.** No code path reads the register. The only failure mode is writing a row whose Rule
is a paraphrase rather than a `filename-§N` reference, which the existing three rows already model
correctly.

## Packaging — BL-29

Two lines in `.pkgmeta` after `:8`:

```yaml
  - .superpowers      # agent tooling, never shipped
  - .pkgmeta          # the packager's own manifest
```

**Risk: none**, and it is worth noting *why* the enumerated check in the playbook did not catch
this on earlier runs: `.superpowers/` post-dates the named list. The dot-entry sweep in
`03_EVIDENCE.md` §9 is the one that cannot go stale, and it should be the one run next time.

## The automated-test record — BL-30, BL-31, BL-33

**BL-30 is a single command plus a hand-write, and its ordering matters:** run the bundle *after*
BL-04/BL-28/BL-29 have landed, so the run it freezes is the post-remediation tree and the record
does not go stale again in the same sprint.

```sh
tests/_kit/run-automated-tests.sh          # all four suites, writes a new dated bundle
```

Then, by hand, roll `docs/automated-tests/RESULTS.md`'s four standing sections and the two watch
tables forward from `20260807-115101` to the run just produced. The band table's three rows need
their LOC re-read (today: `tests/test_ledger.lua` 1478, `modules/Browser.lua` 1251,
`modules/LedgerTable.lua` 1096) and `test_ledger.lua`'s disposition needs a sentence about the +76
lines the settings revamp's cases added.

**BL-31 is deliberately *not* back-filled.** A bundle is frozen evidence and a hand-added
`ANALYSIS.md` dated today would read as measured then. Write the analysis for the new run, and let
it say what the 20260825 jump was — that is `automated-tests-§5`'s own model of how a mis-read is
corrected.

**BL-33 cannot be fixed here at all.** `testing-§1` forbids editing `tests/_kit/`. The design is an
upstream one, on `LibKa0s`:

- widen `run-automated-tests.sh:195`'s regex to `[0-9]+ passed, [0-9]+ failed(, [0-9]+ skipped)?(, [0-9]+ total)?`
  and capture the third group into a `TESTS_SKIP` defaulting to `0`;
- add `"skipped": $TESTS_SKIP` to the manifest's `tests` object beside `passed`/`failed`/`total`
  (`:369`);
- change the `RESULTS.md` `Tests` column to `passed/skipped/total` and say so in the generated
  lead-in.

Then re-vendor here and re-run. **Ordering constraint:** the re-vendor moves `tests/_kit/`, so it
**must not** be interleaved with the BL-30 bundle run — take the bundle first, or take it after the
re-vendor, never across it, or the record's own provenance is ambiguous.

## Line endings — BL-32

```sh
git add .gitattributes
git add --renormalize .
git status                 # review
```

`--renormalize` rewrites the **index**, not files already on disk; any file still wrong in the
working tree is deleted and re-checked-out. `.gitattributes` itself needs no change — it is
byte-identical to the canonical client-bound body (`03_EVIDENCE.md` §7).

**Risk: the diff is large and content-free.** Take it as its **own commit**, with nothing else in
it, so the next reader — and the next `git blame` — can see it is a whitespace normalization. Do it
**last**, after every other edit in this plan, or those edits land inside the renormalization diff
and become invisible.

## What is explicitly out of scope

- **The `performance-§12` cluster (BL-11…BL-17).** Ratified. `savedvariables-§4` now *forbids*
  declaring `BankLedgerPerfDB` under this exemption, so the row is stronger than when it was
  written. Nothing to do; do not re-open.
- **BL-07.** Ratified, and the rule text is unchanged in v2.38.0.
- **BL-34 (`options-ui-§12`).** A maintainer's decision, not an implementer's, and its own re-check
  trigger is *the next release*. When that release is planned, the choice is: unify **up** (all
  three routes destroy recorded history, which `options-ui-§12`'s second canonical wording accepts
  but no case in `tests/` covers) or unify **down** (no §12-compliant wholesale reset survives).
  Whichever is chosen, `tests/test_slash.lua` and `tests/test_panel.lua` need the characterization
  cases first — `testing-§13` — because the current three-route behavior is not pinned.
- **BL-24 / the on-notice band.** Three files, none over the cap, dispositions current and the
  release clock not started. `modules/Browser.lua`'s named peel seam — the skin/close-button
  factory and the geometry persistence — would be closed *by* BL-28 option 2 and is another reason
  not to pick that option for its own sake.
- **`libs/LibKa0s/`.** Audited in its own repo. This run only proved it has not drifted from
  v1.25.0.
