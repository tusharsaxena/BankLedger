# 02 · Deviations — Ka0s Bank Ledger — 2026-09-08

Audited against the **Ka0s WoW Addon Standard v2.39.0 (2026-09-07)**.

Deviation IDs are stable per-addon (`BL-NN`). `BL-01`…`BL-05` come from 2026-07-26, `BL-06`…`BL-10`
from 2026-07-27, `BL-11`…`BL-24` from 2026-08-04, `BL-25`…`BL-27` from 2026-08-05,
`BL-28`…`BL-34` from 2026-09-07. **`BL-35`…`BL-40` are new this run.** A recurring deviation keeps
its ID.

---

## Tally, with its basis stated

**Headline (roots only): 5.** **Total including `derived from` dependents: 5** — no dependent rows
this run; every open finding stands on its own cause.

| Grade | Roots | Total |
|---|---|---|
| High | 0 | 0 |
| Medium | 0 | 0 |
| Low | 5 | 5 |
| Info | — | 9 (the recorded-and-advisory table below; excluded from the tally) |

**MUST failures: 4 of the 5 roots** (`BL-35`, `BL-36`, `BL-37`, `BL-38`). `BL-39` fails no explicit
MUST — it is a hygiene gap in the issue store. Every one of the four is **doc-, comment-, config- or
test-only and therefore graded Low**: the grade is impact, the MUST is named in each entry, and
neither reading cancels the other.

The nine Info rows are: one observation with an id (`BL-40`), five register-backed entries
(`BL-07`, the `BL-11`…`BL-17` cluster, `BL-04`, `BL-28`, `BL-34`), one advisory (`BL-24`) and two
unnumbered measurements. `BL-04` and `BL-28` appear in both the Info table and the closed table
because they closed **by being ratified** — the register row is what ended them.

Nothing in this addon is reachable by a user as a defect today. The single player-reachable
observation in the whole bundle is one British-spelled word in a tooltip (`BL-35`), and a dialect
variant is a spelling, not a wrong value.

**Four of the five are visible only against the amended v2.39.0 text** — `BL-35` (the canonical
British list, published for the first time), `BL-36` (the annotation MUST's denominator, stated for
the first time), `BL-37` (the hollow-composer suite MUST, written for the first time) and `BL-38`
(the four conditions behind a ratified close-button decline). That is the amendments doing the job
they were written for.

## Summary — open this run

| ID | Section | Rule strength | Grade | Summary |
|---|---|---|---|---|
| **BL-35** | `localization-§5` (anti-pattern #46) | MUST | Low | 62 British spellings across 21 authored files, measured with the canonical `BRITISH`/`ALLOWED` lists v2.39.0 publishes; one of them is a player-visible tooltip. |
| **BL-36** | `toc-file-§5` | MUST | Low | One load-bearing TOC position is unannotated: `modules\Insights.lua` takes `NS.InsightsWidgets` as a file-scope upvalue and nothing in the TOC says so. |
| **BL-37** | `options-ui-§1` (hollow composer) | MUST | Low | The suite pins the fully-loaded composed row count but neither the library-absent count nor the delta as a named figure. |
| **BL-38** | `documentation-§3` (with `standalone-windows`) | MUST | Low | Seven live sites — two of them `docs/` pages — say the host close factory serves "all four title bars", contradicting the register row added earlier today and `standalone-windows` condition 1. |
| **BL-39** | `audit-review-history` (issue store) | — | Low | Issue #3, `state:triaged` and open, asks for the register row that now exists; its own closure instruction was not executed. |

## Summary — recorded and advisory (Info; excluded from the tally)

| ID | Section | Basis |
|---|---|---|
| **BL-40** | — | **Observation.** `settings/Panel.lua:661-664` describes the General page as "six tabs" ending in "Blacklist / Whitelist"; the same file renders five, with the two lists merged behind one `Filters` tab. No user reach, no doc carries the error, no MUST names it. |
| BL-07 | `savedvariables-§2` | **Accepted.** Register row, `docs/ARCHITECTURE.md:231`, Decided 2026-07-27. `savedvariables.md` is byte-identical between v2.38.0 and v2.39.0, so the cited rule is unchanged and the row is live. Trigger — the first per-profile setting — has not fired. |
| BL-11…BL-17 | `performance-§12` | **Accepted, as one row.** `docs/ARCHITECTURE.md:230`, Decided 2026-08-05, citing issue #9. `performance.md` is unchanged in v2.39.0. Trigger has not fired: no `SetScript("OnUpdate"` anywhere, both `C_Timer.After` sites one-shot, the in-combat handlers still gated on `NS.State.openContext`. |
| BL-04 | `localization-§1` | **Closed and ratified.** `docs/ARCHITECTURE.md:232`, Decided 2026-07-31 — the row four consecutive audits asked for. Trigger — the first non-English locale file — has not fired. |
| BL-28 | `standalone-windows` | **Closed and ratified.** `docs/ARCHITECTURE.md:233`, Decided 2026-08-06. **This is the one row whose cited rule the standard has since changed**, reported under `audit-review-history`'s second MUST: v2.39.0 rewrote the section so a reasoned decline is a terminal compliant state on four conditions. The change *ratifies* the row's shape rather than retiring it — the amendment names this repo as the collection's only live decline — so the row stands. |
| BL-34 | `options-ui-§12` | **Recorded, decision open.** `docs/ARCHITECTURE.md:234`, Decided 2026-09-02. `options-ui.md` changed in v2.39.0 at §1 and §16 only; §12 is unchanged. Trigger — "re-check at the next release" — has not fired: the last tag, `1.0.0-release`, predates the row. |
| BL-24 | `layout-§1` | **Advisory.** Three files in the 1000–1500 on-notice band; **0** over the 1500 cap, measured over the scope v2.39.0 states (authored `.lua`, `tests/` included). |
| — | `automated-tests-§6` | **Observation.** The newest run bundle is three commits behind HEAD: 844 → **849** tests, 14 455 → **14 669** NLOC, 2 181 → **2 188** functions, 59 → **61** lint files. Not a finding: `automated-tests-§6` puts the checkpoint at **release**, explicitly MUST NOTs gating commits on the bundle, and no release has occurred since the section was adopted. |
| — | `automated-tests-§4` (anti-pattern #53) | **Observation.** The watch list holds 3 entries, 2 of them **Accepted**, carried across 6 consecutive *runs*. #53's counter is **release** runs, and all 8 manifests read `"release": null`, so the three-release clock has not started. |

## Summary — closed since 2026-09-07

| ID | Was | Now |
|---|---|---|
| BL-04 | MUST, open | **Closed — ratified.** The `localization-§1` register row exists (`M5-02`). |
| BL-28 | MUST, open | **Closed — ratified.** The `standalone-windows` register row exists (`M5-02`), and v2.39.0 made the decline a terminal compliant state on four conditions, all four of which hold. |
| BL-29 | MUST | **Closed.** `.pkgmeta:9` ignores `.pkgmeta` and `:22` ignores `.superpowers`, each with the reason written beside it. The dot-entry sweep prints only `UNACCOUNTED — .git`, which needs no row. |
| BL-30 | MUST | **Closed.** `docs/automated-tests/20260908-181253/` regenerated the whole record, standing prose and watch list included (`M5-01`). |
| BL-31 | SHOULD | **Closed forward, as `automated-tests-§5` requires.** `20260908-181253/ANALYSIS.md:73-77` notes once that three of eight bundles carry none; the frozen bundles were correctly not back-filled. |
| BL-32 | MUST | **Closed.** `line-endings-§7`'s command reports **0**, and `git ls-files --eol` agrees: no `w/lf` or `w/mixed` outside the one `attr eol=lf` script. |
| BL-33 | MUST | **Closed upstream and re-vendored.** `tests/_kit/run-automated-tests.sh:226` now captures `skipped`; `RESULTS.md:26` reads `844/0/844` and the manifest carries `"skipped": 0`. |

---

## BL-35 · 62 British spellings in authored text

**Section.** `localization-§5` (anti-pattern **#46**) · **MUST** · **Low.**

**Rule.** `localization-§5`: *"Every English word a Ka0s addon **authors MUST use US English
spelling** — never British,"* across locale keys, everything the player reads, prose in `README.md`
and every file under `docs/`, and **code: comments, and identifiers**. v2.39.0 publishes the
canonical `BRITISH` and `ALLOWED` lists for the first time, precisely so this stops being a matter
of whose private subset ran.

**State.** A gate implementing `localization-§5` exactly as written — both lists copied whole,
`ALLOWED` removed as whole words before the `BRITISH` substrings are scanned — reports **62 hits in
21 files** over 84 authored files. The scope is stated in `03_EVIDENCE.md`; the four exclusions
`localization-§5` names are honored file-by-file. By term: `colour` 31, `centre` 18, `labelled` 6,
`recognis` 2, `behaviour` 2, `normalis` 1, `neighbour` 1, `catalogue` 1.

**One of them is player-visible.** `settings/Panel.lua:678` — the General page's Defaults tooltip —
reads *"…and recentre the ledger and session windows at their default size."* The comment four
lines above it, at `:674`, spells the same word **`recenters`**, US-correct, which is exactly the
mixed-dialect state the rule's first stated reason is about.

**Why it is Low.** 61 of the 62 are comments and `docs/` prose that no player can reach. The 62nd is
a dialect variant of a correctly-spelled word in a tooltip — cosmetic, not a wrong value, so it does
not reach Medium's *"wrong or missing message"*. The MUST is named here so the grade never reads as
the rule being optional.

**Why it appears now.** Every previous audit read the prose table and none of them ran it, because
until v2.39.0 there was nothing to run: the section said *"enforced by review and by
`/wow-addon:standards-audit`"* and published no list. This is the amendment doing its job on the
first pass after it landed.

**Fix.** One sweep, US spelling for all 62. Do `settings/Panel.lua:678` first and on its own, since
it is the only one a player sees. Then vendor the two lists into a `tests/test_prose.lua` gate —
**whole, both of them**, with the four exclusions named file by file — so the 63rd never lands.

---

## BL-36 · One load-bearing TOC position is unannotated

**Section.** `toc-file-§5` · **MUST** · **Low.**

**Rule.** `toc-file-§5`: every line whose position is **load-bearing** — *"a library major taken as
an upvalue at file scope, a constant resolved from an earlier seam at file load"* — MUST carry a
comment at the line naming what resolves. v2.39.0 adds the grading: *"A load-bearing position with
no comment … one **MUST** row, one row per position."*

**State.** `modules/Insights.lua:5` is `local W = NS.InsightsWidgets`, a file-scope upvalue of a
table `modules/InsightsWidgets.lua:2` creates. If the two lines swapped in the TOC, `W` would be
`nil` for the process and every draw call in the Insights tab would raise. The `# Modules` group
comment names a **different** dependency — *"Filters before Ledger — the capture gate reads the
lists"* — and says nothing about this one, and neither line carries a comment of its own.

**The denominator, stated.** This is measured against the load-bearing positions, not the TOC's 81
lines. Eight positions in this file are annotated and correct; this is the ninth and it is the only
miss. `core\Constants.lua`, `core\Database.lua` and the module lines that take `NS.Constants` are
**compliant** under the same rule's worked example — their positions are already pinned by the
annotated lines above them, and a rule that made every line restate its neighbour's comment would be
noise.

**Why it is Low.** The order is correct today, so nothing is reachable. It is a latent risk of
exactly the kind the annotation MUST exists to make visible: the next person to reorder the
`# Modules` block has nothing to read.

**Fix.** One comment above `modules\Insights.lua`, in the shape the section's worked example uses:
name the symbol (`NS.InsightsWidgets`), the file it comes from, and what moving the line would
silently do.

---

## BL-37 · The suite pins no library-absent row count, and no delta

**Section.** `options-ui-§1` (*When the missing content is COMPOSED*) · **MUST** · **Low.**

**Rule.** New in v2.39.0: *"**The suite MUST pin both counts and the delta between them.** … Pin the
fully-loaded count, the library-absent count, and the difference as a named figure attributed to the
composers it belongs to. The day a composer stops being hollow, or a page file starts declaring rows
a composer used to, the case says so instead of staying green."*

**State.** The hollow composer itself is **correct** — `settings/OptionsSetup.lua:192` answers
`MasterControls` with `return {}, function() end`, four sibling composers are stubbed beside it, and
`tests/test_surface_parity.lua:197` pins the member set by name against the live surface. What is
missing is the count case. `tests/test_schema.lua:276-297` (count assert at `:294`) pins the **fully-loaded** Master controls
block at 6 rows in canonical order; nothing anywhere pins the library-absent arm, and no test names
the difference.

The figures the case would carry, measured today: **16** rows fully loaded (6 · 4 · 4 · 1 · 1 across
the strip), **10** on the library-absent arm (9 `path`-bearing rows declared in
`settings/Schema.lua` plus the one renderer-only `Filters` row), and a delta of **6**, every one of
them `H.MasterControls`'s.

**Why it is Low.** No user can reach a missing test. The gap it leaves is real but latent: the day
LibKa0s ships composers that load without the Options major, the hollow arm stops being hollow and
nothing in this repo notices.

**Fix.** One case in `tests/test_schema.lua`, beside the block-order case at `:276-297`: load the
degraded arm with `loadDegraded()`, count `S:PageRows()` on both, and assert 16 / 10 / 6 with the
delta attributed to `H.MasterControls` in the message. It dies under a composer that stops being
hollow and under a page file that starts declaring rows the composer used to.

---

## BL-38 · Seven live sites say the close factory serves four title bars; it serves three

**Section.** `documentation-§3` (with `standalone-windows`) · **MUST** · **Low.**

**Rule.** `documentation-§3` makes `## Documented deviations` the single home of a ratified
decision, and `standalone-windows`'s first decline condition is *"The host's own windows only. A
window a **library** draws — the debug console, its copy window, the perf panel — is never the
exception."* `AUDIT.md` states the measured case in as many words: *"BankLedger: three host title
bars behind `modules/Browser.lua:98`, and a fourth close control on a copy window the library draws,
which is the library's under condition 1 and not part of the decline."*

**State.** The register row added yesterday gets this exactly right — it says the export **copy**
window *"is `LibKa0s-Widgets-1.0`'s `CopyWindow` and wears the library's mark."* The code agrees:
`modules/Export.lua:252-263` builds it through `W.CopyWindow` and passes **no** `makeCloseButton`, so
the control is Core's own. But **seven** live sites still assert the pre-ratification count of four:

| Site | What it claims |
|---|---|
| `core/CoreSetup.lua:119` | *"all four of its title bars (ledger, session, export modal, export copy)"* |
| `core/CoreSetup.lua:126` | *"coverage of those four title bars"* |
| `core/MediaSetup.lua:86` | *"`B:MakeCloseButton` — all four title bars"* |
| `docs/media.md:46` | *"the ledger, session, export-modal and **export-copy** title bars"* |
| `docs/module-map.md:14` | *"all four of this addon's title bars go through … `B:MakeCloseButton`"* — then contradicts itself two sentences later |
| `tests/test_marks.lua:71`, `:98-101` | the section banner, the case name, and *"both export popups all reach the close control through `B:MakeCloseButton`"* |
| `tests/test_libka0s.lua:63` | *"all four of its title bars go through modules/Browser.lua's own B:MakeCloseButton"* |

**Why the grep does not catch it.** `grep -rn 'MakeCloseButton('` returns the one factory and its
**three** callers — the count is right in the code and wrong in every sentence describing it. The
test at `tests/test_marks.lua:98` is still a good check (it scans six module files for a hand-rolled
`SetText("×")`), so it passes and will go on passing; only its name and its comment are false.

**Why it is Low.** Nothing a player can reach. Two of the seven sites are `docs/` pages the tier
model governs, which is what makes it a `documentation-§3` MUST rather than a note: a reader who
takes `docs/media.md:46` at face value believes the host draws a control the library draws, and the
register — the one document whose whole purpose is to be trusted — says the opposite.

**Fix.** One sweep: four → three at all seven sites, naming the copy window as the library's in the
same breath. `docs/media.md:46` needs its *Where it draws* cell split, because the `close` mark is
genuinely on all four windows — it is the **factory** that is on three.

---

## BL-39 · An open `state:triaged` issue for a register row that now exists

**Section.** `audit-review-history` (*Pending-audit decisions live in GitHub issues*) · **Low.**

**State.** Issue **#3** — *"Record the BL-04 deviation in ARCHITECTURE's Documented deviations
register"* — is **OPEN**, labelled `state:triaged` / `severity:low`. The row it asks for is
`docs/ARCHITECTURE.md:232`, added in `M5-02` at commit `14c86de`. `BL-04`'s own fix direction in the
2026-09-07 bundle read *"Then close issue #3 `state:done`"*, and that half of the instruction was not
executed.

**Rule strength.** No explicit MUST names this case; `audit-review-history` says the store is where
status lives, and a `state:triaged` label on landed work is the store giving a wrong answer to the
one question it exists to answer. It is the same shape anti-pattern **#62** names — a second, stale
answer to *"what is the status of this item"* — one layer over.

**Why it is Low.** A label is not reachable by a player, and every other issue in the store is
correctly labelled: 15 issues, all carrying both a `state:` and a `severity:` label, none carrying a
`[status]` title prefix.

**Fix.** `gh issue close 3` with a `state:done` label, citing `docs/ARCHITECTURE.md:232`.

---

## BL-40 · `settings/Panel.lua` describes six tabs where it renders five

**Grade: Info.** An observation, filed so it is not re-derived next cycle.

`settings/Panel.lua:661-664` reads *"General = the whole panel now, on six tabs: Master controls …,
Capture …, Interface …, History …, and Blacklist / Whitelist (the item-id lists that were their own
page until R3)."* Counting what it lists gives six. The strip renders **five**:
`settings/Schema.lua:258-265` says in as many words *"ONE ROW, NOT TWO. The blacklist and the
whitelist were a primary tab each until the convergence…"*, and both `docs/ARCHITECTURE.md:52-53`
and `docs/settings-panel.md:35` correctly read five with the two lists behind a secondary strip
inside `Filters`.

No user reach, no `docs/` page carries the error, and no MUST in the standard names a stale code
comment — which is why this is Info and not a fifth Low. It is worth one line in the `BL-38` sweep,
since both are the same shape: a sentence that describes the tree as it was.
