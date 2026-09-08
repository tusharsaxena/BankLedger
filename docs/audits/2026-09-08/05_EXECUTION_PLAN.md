# 05 · Execution plan — Ka0s Bank Ledger — 2026-09-08

Hand-off to the separate remediation engagement. **Five open roots**, `BL-35`…`BL-39`, plus the
`BL-40` Info observation folded into step 4. All Low; zero High, zero Medium. Nothing here changes a
code path.

Read this document together with `02_DEVIATIONS.md` — the two are one document, and every figure in
them is reconciled in `03_EVIDENCE.md` §18.

---

## Sprint 1 — the one thing a player can see (≈15 min)

| # | Step | Deviation | Done when |
|---|---|---|---|
| 1.1 | `settings/Panel.lua:678`: `recentre` → `recenter` in the `defaultsTooltip` string. Infinitive in a list, so `recenter`, **not** `recenters` — `:674`'s `recenters` is a finite verb in a different sentence and stays. | `BL-35` (the player-visible hit) | `grep -n recentre settings/Panel.lua` → no hits; `lua tests/run.lua` green; `luacheck .` 0/0 |

Kept as its own commit so the one line a player reads is not buried under 61 comment edits.

## Sprint 2 — the register and the issue store (≈10 min)

| # | Step | Deviation | Done when |
|---|---|---|---|
| 2.1 | `gh issue close 3 --comment "Landed: docs/ARCHITECTURE.md:232 carries the localization-§1 row, Decided 2026-07-31, added by M5-02 at 14c86de."` | `BL-39` | `gh issue view 3 --json state` → `CLOSED` |
| 2.2 | `gh issue edit 3 --add-label "state:done" --remove-label "state:triaged"` | `BL-39` | `gh issue list --state all --label "state:triaged"` no longer returns #3 |

Two API writes on one issue; space them if they are batched with anything else.

## Sprint 3 — the TOC annotation (≈10 min)

| # | Step | Deviation | Done when |
|---|---|---|---|
| 3.1 | Add the three-line load-bearing annotation above `modules\Insights.lua` in `BankLedger.toc`'s `# Modules` block, naming `NS.InsightsWidgets`, the file that publishes it (`modules/InsightsWidgets.lua:2`), the file-scope upvalue that consumes it (`modules/Insights.lua:5`), and what swapping the two would do. | `BL-36` | Every load-bearing position in the TOC carries a comment naming what resolves; the two conventional seams keep theirs; nothing else gains one |

**Do not** annotate `core\Constants.lua`, `core\Database.lua` or the module lines binding
`local C = NS.Constants`. Their positions are pinned by the annotated lines above them, which
`toc-file-§5`'s worked example calls compliant.

## Sprint 4 — the description sweep (≈45 min)

One commit; the nine edits are the same defect and split badly.

| # | Step | Deviation | Done when |
|---|---|---|---|
| 4.1 | `core/CoreSetup.lua:119` and `:126` — four → three, and name the export **copy** window as `LibKa0s-Widgets-1.0`'s | `BL-38` | |
| 4.2 | `core/MediaSetup.lua:86` — four → the three host title bars, noting the copy window's control is the library's and wears the same mark | `BL-38` | |
| 4.3 | `docs/media.md:46` — **split the cell**, do not blind-replace: the `close` **mark** is on all four windows, the `B:MakeCloseButton` **factory** is on three | `BL-38` | |
| 4.4 | `docs/module-map.md:14` — four → three; the cell's next sentence already says the library draws its own | `BL-38` | |
| 4.5 | `tests/test_marks.lua:71` banner and `:98-101` case name and comment — four → three, *"both export popups"* → *"the export modal"*. **Body unchanged**: the six-file `SetText("×")` scan is correct as written | `BL-38` | |
| 4.6 | `tests/test_libka0s.lua:63` — four → three | `BL-38` | |
| 4.7 | `settings/Panel.lua:661-664` — *"six tabs … Blacklist / Whitelist"* → five tabs ending in `Filters`, with both id-lists behind its secondary strip | `BL-40` | |

**Done when:** `grep -rn 'four title bars\|four of its title bars\|four of this addon' --include='*.lua' --include='*.md' . | grep -v '/docs/audits/' | grep -v '/docs/reviews/'` returns nothing, `grep -n 'six tabs' settings/Panel.lua` returns nothing, and every surviving sentence agrees with `docs/ARCHITECTURE.md:233`.

## Sprint 5 — the composed-gap case (≈45 min)

| # | Step | Deviation | Done when |
|---|---|---|---|
| 5.1 | Add the composed-gap case to `tests/test_schema.lua` beside `:276-297`, asserting **16** loaded / **10** library-absent / **6** delta, with the delta attributed to `H.MasterControls` in the message and a *dies-under* comment naming the three mutations | `BL-37` | The case passes; hand-breaking `settings/OptionsSetup.lua:192` to return one fake row turns it red |

Do **not** replace the existing case at `:276-297` — it defends the canonical row **order**, this one
defends the **gap**, and both are owed.

## Sprint 6 — the spelling sweep and its gate (≈2 h)

| # | Step | Deviation | Done when |
|---|---|---|---|
| 6.1 | The remaining **61** hits across the 21 files `03_EVIDENCE.md` §10 lists. `colour`→`color` 31, `centre`→`center` 18, `labelled`→`labeled` 6, `recognis`→`recogniz` 2, `behaviour`→`behavior` 2, `normalis`→`normaliz` 1, `neighbour`→`neighbor` 1, `catalogue`→`catalog` 1 | `BL-35` | |
| 6.2 | `tests/test_itemsetup.lua:51` is a **case name**; renaming it is what clears `docs/test-cases.md:914` | `BL-35` | |
| 6.3 | Add `tests/test_prose.lua`: both `localization-§5` lists **copied whole**, `ALLOWED` removed as whole words before the `BRITISH` substrings are scanned, the four exclusions named file-by-file in the gate itself, failure message printing `file:line: <term>` | `BL-35` | The gate is green over the swept tree and red if `colour` is reintroduced anywhere in it |

**Done when:** the gate reports **0** over the same 84-file scope `03_EVIDENCE.md` §10 states, and
nothing under `libs/`, `tests/_kit/` or the five frozen directories was touched.

## Sprint 7 — regenerate once, roll the badge once (≈10 min)

| # | Step | Deviation | Done when |
|---|---|---|---|
| 7.1 | `lua tests/run.lua --list > docs/test-cases.md` | `BL-35`, `BL-37`, `BL-38` | |
| 7.2 | Roll `README.md:7`'s `[tests]` badge to the new count — **850** if sprint 5 landed as one case | `testing-§5` keep-in-sync | Badge, `docs/test-cases.md` entry count and the runner's final line all agree |

This is the **only** regeneration in the plan, and it is last on purpose: three sprints move case
names or case counts, and `testing-§5` wants the badge rolled in the same change as the data it
mirrors, not three times over.

## Green gate, every commit

`lua tests/run.lua` and `luacheck .` at 0/0, per `testing-§4` and `CLAUDE.md:41`. Nothing in this
plan should move either number except sprint 5 (849 → 850) and sprint 6.3 (850 → 851 once the prose
gate lands, if it registers as a case).

---

## Not in this plan, and why

- **The automated-test bundle is not regenerated.** It is three commits stale — 844 → 849 tests,
  14 455 → 14 669 NLOC — and that is reported as **Info**, not a finding: `automated-tests-§6` puts
  the checkpoint at **release**, MUST NOTs gating commits on the bundle, and the last tag
  (`1.0.0-release`, `ad8ded7`, 2026-07-28) predates the section's adoption. The right moment is the
  next version bump, in the same change. Producing a release-less run to close a gap the standard
  does not open is the ritual without the point.
- **The `standalone-windows` decline is not revisited.** All four conditions hold, the register row
  exists at `docs/ARCHITECTURE.md:233`, and the amended section names this repository as the
  collection's only live decline. Sprint 4 fixes sentences, not controls: no player watches a close
  button change.
- **No register row is added or retired.** All five rows' triggers were evaluated against the tree
  and none has fired; all their evidence ids resolve. The one row whose cited rule changed
  (`standalone-windows`) is reported under `audit-review-history`'s second MUST and **stands**,
  because the change made its shape the compliant one rather than retiring it.
- **`defaults/Profile.lua`, the perf harness and the three reset routes stay as they are.** Three
  live register rows, none triggered.
- **Nothing under `libs/` or `tests/_kit/` is edited.** `testing-§1`. Both `diff -r` checks against
  `v1.27.0` are empty today and must stay empty.
- **No prior audit folder is touched.** `docs/audits/2026-09-07/` reports 4 EOL strays where this run
  measures 0, and 7 open roots where this run has 5. Both bundles are correct as of their own dates;
  a frozen run is never edited to match a later one.
