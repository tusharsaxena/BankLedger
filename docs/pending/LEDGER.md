# Pending-decision ledger — Ka0s Bank Ledger

The record of what `/wow-addon:pending-audit` has already asked you about, and what you decided.

The command sweeps this repo for everything still hanging — code markers, unexecuted audit and
review plan steps, doc open questions, open GitHub issues, recorded-but-unacted memory — and
interviews you one item at a time. This file is what stops it asking twice. Each row is matched on
its **ID plus its evidence hash** (the first 8 characters of `sha1` over the verbatim evidence
text), so a settled item stays settled, while an item whose underlying evidence has since *changed*
correctly comes back for a fresh decision.

Do not hand-edit the decision column to silence an item. If something needs re-opening, change the
thing itself; the hash will move and the item will surface on its own.

## Notation

| Marker | Value | Meaning | Re-surfaces? |
|---|---|---|---|
| 🟢 | `done` | Implemented this run | No — closed |
| 🔵 | `wont-do` | Decided it will never be done | No — closed |
| 🟡 | `deferred` | Not now; still on the books | Yes, as a collapsed count |

There is deliberately no red: nothing in this file is an error state. Green is resolved, blue is a
settled and deliberate close, and yellow is the only row type still asking for attention — so a
column of yellow is the file telling you what is left.

## Decisions

| ID | Evidence hash | Source | Decision | Date | Rationale |
|---|---|---|---|---|---|
| PLAN-01 | `63dc637d` | `docs/reviews/2026-07-27/05_FINAL_SUMMARY.md` | 🟢 done | 2026-07-31 | "This is done" — the in-client smoke tests were run and passed before v1.0.0 shipped; the bundle had simply never been filled in. Sign-off table completed and the status line corrected. |
| DOC-01 | `a7d0808f` | `docs/audits/2026-07-27/02_DEVIATIONS.md:16` (BL-04) | 🟡 deferred | 2026-07-31 | Not now. The rationale is already written in `locales/enUS.lua:8-12`; only the ARCHITECTURE ▸ *Documented deviations* record is missing, so the next standards-audit will re-raise BL-04 until it lands. |
| PLAN-02 | `a3a7777e` | `docs/audits/2026-07-27/05_EXECUTION_PLAN.md` Sprint 2 (BL-08) | 🟢 done | 2026-07-31 | Added to `docs/testing.md` as a new *Release checklist* section, so the re-drop rule sits where a release is actually run from. |
| DOC-02 | `39e646d7` | `docs/ARCHITECTURE.md` ▸ Known limitations | 🔵 wont-do | 2026-07-31 | Currencies are out of scope permanently — "remove references from existing docs and code". The reserved `Kind.CURRENCY` member, its label, the ARCHITECTURE field note and the README FAQ answer were all removed or rewritten so nothing implies the feature is coming. |
| DOC-03 | `9ca683ce` | `docs/ARCHITECTURE.md` ▸ Known limitations | 🟡 deferred | 2026-07-31 | "Defer, and create a GitHub issue" — tracked as [#1](https://github.com/tusharsaxena/BankLedger/issues/1). A store-vs-store pairing rule needs its own design pass; the bags-must-move invariant is what keeps phantom rows out. |
| DOC-04 | `c079f94b` | `docs/ARCHITECTURE.md` ▸ Known limitations | 🟡 deferred | 2026-07-31 | Deferred with a tracking issue, [#2](https://github.com/tusharsaxena/BankLedger/issues/2). Backfilling names means rewriting stored rows on the saved-variable write path, which wants a design pass of its own. |
| DOC-05 | `a39ce651` | `docs/ARCHITECTURE.md` ▸ Known limitations | 🟢 done | 2026-07-31 | The entry disowned itself ("a fallback rather than a live limitation"). Folded into the *Logo art* section's "the `.tga` must actually exist" rule, where the silent-failure behaviour is genuinely useful, and dropped from Known limitations. |
| DOC-06 | `ed4c3c2b` | `docs/superpowers/plans/` + `docs/superpowers/specs/` | 🟢 done | 2026-07-31 | Both artifacts described shipped work as pending. Stamped with a status line naming the delivering commits; the 21 step checkboxes were left unticked deliberately, since the header now removes the ambiguity. |

## LibKa0s adoption

One row per module, written when the call was made rather than at the end. `../LibKa0s/docs/adoption-prompt.md`
is the brief; `../LibKa0s/docs/adoption-report.md` is the audit these rows answer to. A **declined**
part of the library is recorded here on purpose — an unrecorded decision is indistinguishable from
an oversight, and the next consistency sweep will "fix" it.

| ID | Evidence hash | Source | Decision | Date | Rationale |
|---|---|---|---|---|---|
| LIBKA0S-01 | `48867ab5` | `../LibKa0s/docs/adoption-prompt.md` step 2 (vendor the test kit) | 🟢 done | 2026-08-01 | The kit is vendored to `tests/_kit/` and `tests/run.lua` / `tests/wow_mock.lua` are rebuilt on it; `tests/loader.lua` is deleted in favour of `_kit/loader.lua`. Taken FIRST, before any library module, because the kit's `mock_base.lua` is the only source of a `LibStub` with a real `NewLibrary` — without it no LibKa0s major can register headlessly and no seam is testable at all. The swap is behaviour-neutral: all sixteen pre-existing suites kept their exact case counts (603), and the seven new cases are `tests/test_harness.lua`. |
| LIBKA0S-02 | `1a7f0b3e` | `tests/_kit/framework.lua:79-96` (a listed suite with no file is SKIPPED) | 🟢 done | 2026-08-01 | Accepted, with a guard rather than a fork. The old runner raised on a missing suite; the kit skips it, which turns a typo into a green run with fewer cases. `tests/test_harness.lua` asserts the suite list and `tests/test_*.lua` agree in **both** directions, and both assertions were mutation-verified. Editing `tests/_kit/` to restore the raise was never an option. |
| LIBKA0S-03 | `6c2d94af` | `tests/_kit/mock_base.lua` vs the pre-adoption `tests/wow_mock.lua` | 🟢 done | 2026-08-01 | Ten base behaviours are deliberately overridden in the extender rather than adopted, each named in that file's header with the suite that needs it — the geometry-modelling frame stub, frames starting shown, OnHide firing, counting/cancelling timers, the raising `RegisterEvent`, the fixed-profile AceDB, the one-table settings-canvas registry, the plain-table chat sink, the inert AceGUI, and leaving `GameTooltip`/`StaticPopup_Show` nil. None is a kit gap: `mock_base.lua`'s own header states that single-consumer fidelity belongs in the consumer's extender. The `GameTooltip` / `StaticPopup_Show` pair is the one to revisit — taking the base's definitions flips eleven guarded production branches to their in-game path, which is more faithful but is a test-semantics change that does not belong in a harness swap. |
