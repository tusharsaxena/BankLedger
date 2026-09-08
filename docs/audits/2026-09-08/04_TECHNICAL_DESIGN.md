# 04 · Technical design — Ka0s Bank Ledger — 2026-09-08

Remediation design for the five open roots in `02_DEVIATIONS.md`, plus the one Info observation that
rides along with `BL-38`. Every figure here is the one `03_EVIDENCE.md` measured; none is re-typed
from an earlier bundle.

**Nothing in this design touches a code path.** All five changes are to comments, docs, one string
literal, one TOC comment, one test file and one GitHub label. There is no runtime behavior change in
the whole plan, which is why the risk section is short and the ordering constraints are weak.

---

## BL-35 · US spelling across 21 files

### Shape of the change

Two commits, deliberately split, because they carry different risk.

**First, on its own: `settings/Panel.lua:678`.** `recentre` → `recenter`. It is the one
player-visible hit, it sits in the General page's Defaults tooltip, and the comment four lines above
it at `:674` already spells the word correctly — so the change is making the string agree with its
own comment. Kept separate so it is one line in a diff a reviewer can read without scrolling past 61
comment edits.

Note the grammatical detail: the surrounding sentence is *"Restore every … setting …, clear the item
blacklist and whitelist, and recentre the ledger and session windows"* — an infinitive in a list, so
the US form is **`recenter`**, not `recenters`. `:674`'s `recenters` is a finite verb in a different
sentence. Do not blind-replace.

**Second, the sweep: the remaining 61 hits, still across 21 files** — `settings/Panel.lua` keeps a second hit at `:277` (`labelled`). All are comments or `docs/` prose. The
substitutions, by frequency:

| British | US | Hits |
|---|---|---|
| `colour` / `coloured` / `colours` / `class-coloured` / `vertex-colour` | `color` family | 31 |
| `centre` / `centred` / `centres` / `off-centre` | `center` family | 18 |
| `labelled` / `relabelled` | `labeled` / `relabeled` | 6 |
| `recognises` | `recognizes` | 2 |
| `behaviour` | `behavior` | 2 |
| `normalises` | `normalizes` | 1 |
| `neighbour's` | `neighbor's` | 1 |
| `catalogued` | `cataloged` | 1 |

**One of them is not a free edit.** `tests/test_itemsetup.lua:51` is a **case name** —
`test("ItemSetup: this addon now HAS the colour fallback it lacked", …)` — and case names are the
generated inventory. Renaming it means regenerating `docs/test-cases.md`
(`lua tests/run.lua --list > docs/test-cases.md`) in the same commit, which is what clears the 62nd
hit at `docs/test-cases.md:914`. The badge figure does not move: 849 cases before and after.

**Nothing in `libs/` or `tests/_kit/` is touched.** `testing-§1` forbids editing the vendored kit,
and `localization-§5` excludes vendored code by name. Nothing in `docs/audits/`, `docs/reviews/`,
`docs/revendor/`, `docs/superpowers/` or the eight frozen `docs/automated-tests/<stamp>/` folders is
touched either — those are the record.

### The gate that stops the 63rd

`localization-§5` mandates that *"every mechanical gate **MUST** use it whole"*. This repo has no
gate at all (`grep -rn -i 'BRITISH' tests/*.lua` → nothing), which is why 62 hits accumulated
invisibly. Add `tests/test_prose.lua`:

- Both published lists, **copied whole** from `localization-§5`. Not a subset — the section spends a
  paragraph on why a private subset is a coverage claim nobody can check, and names two collection
  gates that shipped one.
- `ALLOWED` removed as **whole words** first (delimit on non-letters, drop matched tokens), then the
  `BRITISH` substrings scanned over what remains. Matching `ALLOWED` as a substring would swallow
  *analysed* inside the allowance for *analyses*.
- The four exclusions named **file by file / directory by directory in the gate itself**, as the
  section requires, so the list cannot quietly grow: `libs/`, `tests/_kit/`, the five frozen
  directories, and `tests/test_prose.lua`'s own copy of the lists.
- The failure message prints `file:line: <term>`, so a red run is actionable without a second tool.

**Risk.** The gate is the only part with a false-positive surface. It is bounded by `ALLOWED`, which
the standard supplies precisely for this, and the admissibility rule that a `BRITISH` entry must not
be a substring of a correct US word unless `ALLOWED` names it. If the gate reddens on a word that is
correct US English, the fix is an amendment upstream to `localization-§5`, **not** a local addition —
*"a private addition MUST NOT outlive the change that discovered it."*

## BL-36 · One TOC comment

### Shape of the change

Three comment lines above `modules\Insights.lua` in `BankLedger.toc`'s `# Modules` block, in the
form `toc-file-§5`'s worked example uses — name the symbol, the seam it comes from, and what moving
the line would silently do:

```
# BEFORE this line, modules\InsightsWidgets.lua publishes NS.InsightsWidgets, which modules/
# Insights.lua:5 takes as a FILE-SCOPE upvalue — so this position is load-bearing, not
# conventional: swap the two and `W` is nil for the session and every draw in the tab raises.
```

The other seven load-bearing positions in the file are already annotated and are not touched. The
`# Modules` group comment — *"Filters before Ledger — the capture gate reads the lists"* — stays: it
describes a real, different dependency.

**Not in scope, and deliberately so.** `core\Constants.lua`, `core\Database.lua` and the module lines
that bind `local C = NS.Constants` at file scope get **no** comment. `toc-file-§5`'s worked example
settles this — a position pinned by an annotated line above it is compliant, and *"a rule that made
every line restate its neighbor's comment would be noise the next reader learns to skip."* Adding
eight more comments here would trade a MUST failure for the noise the same rule forbids.

**Risk.** None. A comment in a TOC file listing; the client ignores `#` lines.

## BL-37 · One test case

### Shape of the change

One case in `tests/test_schema.lua`, beside the existing block-order case at `:276-297`, pinning the
three figures `options-ui-§1` names:

```lua
test("Schema: the composed rows are the whole gap between the loaded and library-absent arms", function()
  -- options-ui-§1's hollow-composer MUST. The stub answers an EMPTY row list
  -- (settings/OptionsSetup.lua:192), which is the compliant shape — so what this case defends is
  -- the GAP, not the count. 6 rows, all H.MasterControls's, spliced at settings/Schema.lua:252.
  --
  -- Dies under: a composer that stops being hollow (the delta falls below 6), a page file that
  -- starts declaring rows the composer used to (the library-absent count rises), or a host copy of
  -- a composed block appearing in the stub (anti-pattern #73 — the delta falls to 0).
  local loaded   = #NS.Schema:PageRows()
  local degraded = #loadDegraded().Schema:PageRows()
  assertEqual(loaded,   16, "the fully-loaded General page draws 16 rows")
  assertEqual(degraded, 10, "the library-absent arm draws the 10 rows this addon declares itself")
  assertEqual(loaded - degraded, 6, "the gap is H.MasterControls's six composed rows, and nothing else")
end)
```

The three numbers are the measured ones: **16** fully loaded (6 · 4 · 4 · 1 · 1 across the strip),
**10** on the library-absent arm (9 `path`-bearing rows in `settings/Schema.lua` plus the one
renderer-only `Filters` row), delta **6**.

`loadDegraded()` is already the suite's idiom — 22 sites use it — so no harness change is needed. The
existing case at `:276-297` stays exactly as it is; this one sits beside it rather than replacing it,
because the two defend different things: that one defends the canonical **order**, this one the
**gap**.

The badge and inventory move by one: 849 → 850. Regenerate `docs/test-cases.md` and roll
`README.md:7` in the same commit (`testing-§5`'s keep-in-sync rule).

**Risk.** Low, and it is a good risk: the case is designed to go red the day the library ships
composers that load without the Options major, which is exactly the event `options-ui-§1` says ends
the hollow exemption. That is the case working, not breaking.

## BL-38 (+ BL-40) · Four → three, in one sweep

### Shape of the change

Eight lines across seven sites, plus `BL-40`'s one, in a single commit — they are the same defect
(a sentence describing the tree as it was) and splitting them buys nothing.

| Site | Change |
|---|---|
| `core/CoreSetup.lua:119` | *"all four of its title bars (ledger, session, export modal, export copy)"* → *"all three of its title bars (ledger, session, export modal)"*, and add the half-sentence that the export **copy** window is `LibKa0s-Widgets-1.0`'s and wears the library's control |
| `core/CoreSetup.lua:126` | *"those four title bars"* → *"those three title bars"* |
| `core/MediaSetup.lua:86` | *"— all four title bars"* → *"— the three host title bars; the copy window's is the library's, same mark"* |
| `docs/media.md:46` | Split the *Where it draws* cell: the **mark** is on all four windows, the **factory** is on three. `B:MakeCloseButton` — ledger, session, export modal; `lib.MakeCloseButton` — export copy, drawn by `W.CopyWindow` |
| `docs/module-map.md:14` | *"all four of this addon's title bars"* → *"all three"*; the cell's next sentence already says the library draws its own, so the contradiction disappears without adding text |
| `tests/test_marks.lua:71` | banner *"one edit, four title bars"* → *"one edit, three title bars"* |
| `tests/test_marks.lua:98-101` | case **name** four → three; comment *"both export popups"* → *"the export modal"*, naming the copy window as the library's. The case **body** is unchanged — it scans six module files for a hand-rolled `SetText("×")` and that check is correct as written |
| `tests/test_libka0s.lua:63` | *"all four of its title bars"* → *"all three of its title bars"* |
| **`settings/Panel.lua:661-664`** (`BL-40`) | *"on six tabs: … and Blacklist / Whitelist"* → *"on five tabs: Master controls, Capture, Interface, History and Filters — the last carrying both id-lists behind a secondary strip"*, which is what `settings/Schema.lua:258-265`, `docs/ARCHITECTURE.md:52-53` and `docs/settings-panel.md:35` already say |

**The register row is the reference, not a thing to edit.** `docs/ARCHITECTURE.md:233` already states
the correct split and is the ratified home of the decision; every edit above is bringing a
description into line with it, not re-deciding anything.

**Two case names move, so the inventory moves.** `tests/test_marks.lua:98`'s rename means another
`docs/test-cases.md` regeneration. Sequence this after `BL-35` and `BL-37` so the inventory is
regenerated once at the end rather than three times.

**Risk.** None to behavior — every edit is a comment, a doc cell or a case name. The one thing to get
right is `docs/media.md:46`: the `close` **mark** genuinely is on all four windows, so a blind
four → three there would replace one wrong sentence with another.

## BL-39 · One label

```
$ gh issue close 3 --comment "Landed: docs/ARCHITECTURE.md:232 carries the localization-§1 row, Decided 2026-07-31, added by M5-02 at 14c86de."
$ gh issue edit 3 --add-label "state:done" --remove-label "state:triaged"
```

Per the collection memory on GitHub API writes, these are two calls on one issue and need no
throttling; if they are batched with anything else, space them.

**Risk.** None. The register row the issue asks for is verified present at
`docs/ARCHITECTURE.md:232`, and the suite case *"every deviation id the register cites is assigned by
a bundle in docs/audits/"* passes over it.

---

## Ordering constraints

Only two, and both are about regenerating `docs/test-cases.md` once:

1. `BL-35`'s case-name edit (`tests/test_itemsetup.lua:51`), `BL-37`'s new case and `BL-38`'s case
   rename (`tests/test_marks.lua:98`) all move the generated inventory. Do the three source changes
   first, then one `lua tests/run.lua --list > docs/test-cases.md` and one `README.md:7` badge roll
   at the end.
2. `BL-37` is the only change that moves the **count** (849 → 850). Land it before the regeneration
   so the badge is rolled once with the final number.

Everything else is independent. `BL-36` and `BL-39` can land in any order, before or after the rest.

## What this design deliberately does not do

- **It does not touch the `standalone-windows` decline.** All four conditions hold and the register
  row exists; the amended section names this repository as the collection's only live decline. The
  wrapper is not adopted, the three close controls are not redrawn, and `BL-38` is a description
  problem, not a design one.
- **It does not regenerate the automated-test bundle.** The record is three commits stale, which is
  measured and reported as Info — but `automated-tests-§6` puts the checkpoint at **release** and
  MUST NOTs gating commits on the bundle. The right moment is the next version bump, in the same
  change, and manufacturing a release-less run to close a gap the standard does not open would be
  the ritual without the point.
- **It does not add `defaults/Profile.lua`, wire the perf harness, or unify the three reset routes.**
  Those are the three live register rows, and none of their triggers has fired.
- **It does not annotate the conventional TOC positions beyond the two already marked.** That is the
  SHOULD, it is already satisfied for both seams whose positions are free, and blanket-annotating the
  rest is the noise `toc-file-§5` names.
