# 04 · Technical design — Ka0s Bank Ledger — 2026-08-05

Remediation design for the deviations catalogued in `02_DEVIATIONS.md`, keyed to their IDs. This
document designs; `05_EXECUTION_PLAN.md` orders. Nothing here has been applied — the audit is
read-only.

**Two constraints govern every design below.**

1. **Nothing under `libs/` or `tests/_kit/` is edited.** A library or kit defect is a finding to fix
   in the `LibKa0s` repo and re-vendor whole-folder (library-stack-§7, testing-§1). BL-20 and BL-27
   each have an upstream half, and both are marked as such.
2. **A behavior change and a mechanical sweep never land in one commit** (performance-§11). BL-18 and
   BL-20 both touch `settings/` and `modules/`; they stay separate changes.

---

## D-1 · The perf decision (BL-11 … BL-17) — one decision, three routes

These seven MUSTs are one unratified decline, not seven defects. Two audits have now recorded them as
open for the same reason: the argument is written in a **pending ledger**
(`docs/pending/LEDGER.md:65`, LIBKA0S-17) rather than in the place `CLAUDE.md:14-23` names.

### Route A (recommended) — ratify it as an accepted deviation

**Files touched:** `docs/ARCHITECTURE.md` only. **Risk:** none. **Cost:** one paragraph.

Add a second entry to `docs/ARCHITECTURE.md` ▸ *Documented deviations*, beside the BL-07 entry it
already carries, in the same shape:

- name the sections declined — `performance-§1` (wiring), and by consequence `performance-§4`,
  `-§5`, `-§6`, `-§9`, `toc-file-§2`, `lint`, `documentation-§3`;
- state the argument as fact, not as a plan: the harness gates its measurement windows on
  `UnitAffectingCombat("player")` while this addon's capture engine is gated on
  `NS.State.openContext`, set only by a bank or guild-bank frame — an out-of-combat NPC interaction.
  The two conditions do not overlap, so every declared bucket would read `0.000`, which
  `performance-§3` itself calls *"a lie in every report"*;
- state what is **not** declined, so the entry cannot be read as a blanket opt-out: the **ship
  payload** stays whole (`Perf.lua`/`PerfPanel.lua` remain vendored and TOC-loaded, and the test
  runner loads them), and the moment a measurable code path exists the wiring is owed;
- cross-reference `docs/pending/LEDGER.md:65` so the two records point at each other rather than
  drifting.

Then update `docs/automated-tests/README.md`'s closing paragraph, which currently cites
`../audits/2026-08-04/02_DEVIATIONS.md` for `BL-13`/`BL-15`/`BL-16`, to cite this run's bundle **and**
the `ARCHITECTURE.md` record. A pointer into a frozen audit ages; a pointer into the living
architecture doc does not.

**What Route A does not do:** it does not make the addon compliant with `performance-§1`. It makes
the deviation *recorded*, which is the state `CLAUDE.md` option (1) defines and which BL-07 already
occupies. The next audit then reads BL-11 … BL-17 as **Accepted (documented)** rather than **Open**.

### Route B — adopt the wiring

Only worth doing if the buckets can read non-zero. Ordered, because the pieces have hard
dependencies:

1. `core/PerfSetup.lua` — `LibStub("LibKa0s-Perf-1.0", true)`, a descriptor with `dbName =
   "BankLedgerPerfDB"` and buckets `{ key = "stats" }`, `{ key = "reconcile" }`,
   `{ key = "snapshot" }`, and a stub answering **every** member the addon calls (`on`, `Note`, and
   whatever the slash layer and the show-decision ladder touch). TOC-positioned **before** any module
   taking `local Perf = NS.Perf` as a load-time upvalue (BL-11).
2. `BankLedger.toc` — `## SavedVariables: BankLedgerDB, BankLedgerPerfDB` and the new core file in
   `# Core` (BL-12).
3. `.luacheckrc` — `debugprofilestop` into `read_globals`, `BankLedgerPerfDB` into `globals` with a
   comment (BL-14).
4. Brackets at the real hot paths in the mandated shape — `local t0 = Perf.on and debugprofilestop()`
   … `if t0 then Perf.Note(key, debugprofilestop() - t0) end` — and **nowhere else**. Every declared
   bucket must be reached by a real bracket or it is a lie in every report (performance-§3).
5. `settings/Schema.lua` `NS.COMMANDS` — a `perf` triple dispatching to the library's command entry
   point, printing the returned lines through `NS.Print`; regenerate the README command table in the
   **same** change (BL-13).
6. `modules/Ledger.lua` / `modules/SessionWindow.lua` — split `L:Enable` into an idempotent
   arm/disarm pair, add session-only `State.perfSuspended` consulted by `SW:Enabled()` and the
   browser's show decision, rebuild registrations from **current** state on resume, never persist the
   flag (BL-17).
7. `tests/perf.lua` — load list derived from the TOC per `testing-§9`, assertions on **call counts
   and bytes allocated only**, never wall clock, with the zero-overhead scenario over
   `Database:Stats`. Kept out of `tests/run.lua` (BL-16).
8. `docs/performance.md` and `docs/perf-runs/README.md` (BL-15).

**Risk.** Step 6 is the dangerous one: it edits the arming path that the entire capture engine hangs
off, and `docs/pending/LEDGER.md:65` already costs it out as *"two new Ledger entry points … a
carve-out in the `SessionChanged` sole-sender invariant … an `SW:Enabled()` edit"*. `L:Enable` has
coverage in `tests/test_ledger.lua`, but the sole-sender invariant does not, so testing-§13 requires
a **characterization test run against the unrefactored code first**.

### Route C — upstream

Propose in `WowAddonStandards` either a non-combat window mode for the harness, or a sanctioned
`N/A` in `performance-§1` for an addon whose only code path is inside an out-of-combat modal frame.
This is the honest general fix — Bank Ledger is unlikely to be the only such addon — but it is slower
than Route A and does not block it.

**Recommendation: Route A now, Route C when convenient, Route B only if the premise changes.**

---

## D-2 · The global `print()` (BL-18) — one line of production code and the test that pins it

**File:** `modules/Browser.lua`. **Risk:** none. **Third time this has been raised.**

At the top of the file, beside the existing `local C = NS.Constants`:

```lua
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)
```

`core/CoreSetup.lua` loads before every `modules/` file, so `NS.Print` is live at
`modules/Browser.lua`'s file scope; the capture is the identical function object `NS.Util.print`
holds, so `core/BankLedger.lua:13`'s reclaim from the AceConsole embed is already accounted for.

**The test is the load-bearing half.** Fixing the two lines without pinning them is what let this
recur across two reviews and two audits. Extend `tests/test_browser.lua` with two cases driving
`B:SaveView()` and `B:ResetView()` and asserting the captured chat line **starts with `NS.PREFIX`**
— not merely that a line was emitted, which passes just as happily against the global `print`.
Assert on the prefix, and carry a `-- red under: drop the `local print` line at the top of
modules/Browser.lua` comment (testing-§12).

**Also strengthen the invariant that missed it.** `tests/test_libka0s.lua:340-349` asserts *at least
five* load-time printer captures — a floor, which is why Browser slipped through. Change it to
iterate the TOC and assert that **every** file containing a bare `print(` call also declares
`local print = NS.Print`. That is the case that would have caught this on the day it was written, and
it generalizes to the next file.

---

## D-3 · `B:ApplySkin` delegation (BL-19)

**File:** `modules/Browser.lua:19-36, 67-89`. **Risk:** low; visual, and covered by smoke tests.

Resolve Core at **call** time inside `B:ApplySkin` — never at load, which would reintroduce an
ordering hazard between `modules/` and `libs/`:

```lua
function B:ApplySkin(f)
  local Core = LibStub and LibStub("LibKa0s-Core-1.0", true)
  if Core and Core.ApplySkin then return Core.ApplySkin(f) end
  -- library-absent branch: the current body, unchanged
  ...
end
```

`Core.ApplySkin` tints `frame.title` and `frame.divider` when they exist, so assign both **before**
the call at each of the four call sites — which the current body already relies on (`:87-88`).

**Prune `B.SKIN` to what is genuinely the host's.** Drop the five fields that restate `Core.SKIN` —
`bg`, `border`, `innerBorder`, `divider`, `title` — from the table *once the delegation lands*, and
keep `tabActive`, `tabIdle`, `titleBarH`, `tabStripH`, `contentGap`, `defaultH`, `minH`. Leaving both
copies is the drift the section exists to end. Grep for readers of the five before removing them.

**Do not touch** `B:MakeCloseButton` or `core/DebugLogSetup.lua`'s deliberate omission of
`makeCloseButton` — that split is correct and its reason is written at the site.

---

## D-4 · The standard-reference sweep (BL-20)

**Files:** `settings/OptionsSetup.lua:43,65,74`, `settings/Panel.lua:11,58`, `settings/Schema.lua:184`,
`tests/test_panel.lua:175`, `docs/ARCHITECTURE.md:106`, `docs/pending/LEDGER.md:63`.
**Risk:** none — comments and prose only. **Its own commit**, because a mechanical sweep mixed with a
behavior change is unreviewable (performance-§11).

| Site | Reads | Should read | Why |
|---|---|---|---|
| `settings/OptionsSetup.lua:43` | `options-ui-§41` | `options-ui-§1` | the single write seam |
| `settings/Schema.lua:184` | `options-ui-§41` | `options-ui-§1` | same |
| `docs/ARCHITECTURE.md:106` | `options-ui-§41` | `options-ui-§1` | same |
| `docs/pending/LEDGER.md:63` | `options-ui.md` §11 and §41 | `options-ui-§11` and `options-ui-§1` | same, plus the retired file-and-§ form |
| `settings/Panel.lua:58` | `options-ui-§190` | `options-ui-§11` | panel refresh |
| `tests/test_panel.lua:175` | `options-ui-§189` | `options-ui-§11` | re-entrancy guard |
| `settings/OptionsSetup.lua:65` | `Ka0s standard §3.4` | `library-stack-§4` | AceGUI resolved once and handed over |
| `settings/Panel.lua:11` | `Ka0s standard §3.4` | `library-stack-§4` | same |
| `settings/OptionsSetup.lua:74` | `Ka0s standard §3.1` | `library-stack-§1` | AceTimer through the addon object |

**`docs/pending/LEDGER.md` is hash-matched.** Editing row `LIBKA0S-15`'s text moves its evidence hash
and the item resurfaces at the next `/wow-addon:pending-audit`. That is the file behaving correctly;
just expect it, and re-settle the row in the same pass.

**Upstream half, not landed here.** `libs/LibKa0s/Options.lua:129,173,233` carry the same malformed
forms. They are the library's text and **MUST NOT** be edited in this repo — a local patch is
reverted silently by the next re-vendor. Raise it in the `LibKa0s` repo.

**Guard against recurrence.** Add a case to `tests/test_harness.lua` walking every tracked `.lua` and
`.md` outside `libs/`, `docs/audits/`, `docs/reviews/` and `docs/automated-tests/` for
`§[0-9]+\.[0-9]+` and for `-§` followed by two or more digits, failing with the file and line. Both
patterns are exactly wrong under the current scheme, so the case cannot produce a false positive.

---

## D-5 · The release gate (BL-25)

**Files:** `docs/testing.md`, `docs/automated-tests/README.md`. **Risk:** none — documentation.
**Explicitly NOT touched:** `docs/automated-tests/RESULTS.md`, which is generated by the vendored
runner and never hand-edited (automated-tests-§4).

The rule has two halves and the repo currently states one. The fix is to state the other **without
weakening the first**, because the `--no-verify` argument behind "perf and complexity never gate" is
still normative for runs and commits.

**1 — `docs/testing.md`, the *Release checklist*.** Add a checkbox:

> - [ ] **The release run's `manifest.json` shows all four suites at `pass`, with
>   `suites.complexity.warnings` at `0`** (no function above CCN 15). This gate is evaluated by
>   `/wow-addon:bump-version` **from the manifest**, not by the runner's exit code — the runner is
>   also the commit gate, so a threshold inside it would land on every commit
>   (`automated-tests-§3`, *The release gate*).

**2 — the same section, this addon's standing exception.** Add, as its own bullet under that
checkbox:

> A **skip is not a pass**. Bank Ledger's `perf` suite is a permanent skip because it ships no
> `tests/perf.lua` — the one narrow exception `automated-tests-§3` sanctions — and the exception is
> only valid if the **release notes say so**. State it there, every release, until `tests/perf.lua`
> exists (BL-16).

**3 — both "never gates" sentences.** `docs/testing.md:88-91` and
`docs/automated-tests/README.md:26-32` each get the checkpoint named, e.g.:

> **`perf` and `complexity` never fail a **run** and never gate a **commit**.** … At the **tag** they
> do gate: a release requires all four suites at `pass` plus zero CCN > 15, evaluated by the release
> command from the run's manifest (`automated-tests-§3`).

**4 — `CLAUDE.md`.** Its green-gate line is correct and stays as it is (`lua tests/run.lua` +
`luacheck .`). Adding the release gate there would blur the two checkpoints, which is the defect
being fixed.

**Why this is worth a MUST-severity fix in a documentation-only change.** The addon's next version
bump runs into a rule the repo does not describe, in the one configuration where the rule has a
non-obvious escape hatch. Either the bump is blocked by something nobody wrote down, or it is shipped
past silently. Both outcomes are worse than the two paragraphs above.

---

## D-6 · The runner's executable bit (BL-26)

**File:** the git index entry for `tests/_kit/run-automated-tests.sh` — **not** its contents.

```sh
git update-index --chmod=+x tests/_kit/run-automated-tests.sh
```

Then commit. Setting the bit in the index is **not** an edit to `tests/_kit/` — the blob hash does
not change, so the byte-identity gate (§BL-27's file, and the library's own `test_kitsync`) is
unaffected.

Add `chmod +x tests/_kit/run-automated-tests.sh` to the re-vendor step wherever it is written down —
`docs/testing.md`'s vendor-gate section is the natural home, since that is where the re-vendor command
already lives. Optionally set `core.fileMode = false` locally so `drvfs`'s blanket `777` never fights
the index.

---

## D-7 · The vendor-sync gate that goes quiet (BL-27)

**File:** `tests/test_vendor_sync.lua`. **Upstream half:** `LibKa0s`'s `testkit/framework.lua`.

The right answer needs a **skip status** the vendored kit does not have (`Kit.VERSION = 6`). Until it
does, there are two honest options and one forbidden one.

**Forbidden:** editing `tests/_kit/framework.lua` to add `Kit.skip` here. It is a fork nobody knows
about, the next re-vendor reverts it silently, and the byte-identity gate would redden against the
tag (testing-§1, library-stack-§7).

**Landing now, in this repo — make the absence loud.** Two changes to
`tests/test_vendor_sync.lua`, neither touching the kit:

1. **Put the condition in the case name**, where the file's own header already claims it is
   (`:105-109`, a claim that is currently false):
   `"libs/LibKa0s matches the release the README names — REQUIRES the sibling ../LibKa0s checkout"`.
   A reader scanning `docs/test-cases.md` then sees that the gate is conditional.
2. **Say so at run time.** Before the `return`, print one line naming the path that was looked for and
   not found, so a green run states out loud that this gate did not look. `Kit.run` prints case names
   already; one extra line is cheap and is the difference between "checked" and "could not check".
   Fix the header comment at `:105-109` in the same change — a comment asserting a property the code
   does not have is worse than no comment.

Regenerate `docs/test-cases.md` and update the README `[tests]` badge in the same change if the count
moves (testing-§5).

**Landing upstream — the real fix.** In the `LibKa0s` repo, add an **additive** `Kit.skip(reason)`
that records a case as skipped rather than passed, bump the kit revision, and re-vendor `testkit/`
whole-folder into every consumer **as its own commit** (library-stack-§7). Then this file reports
*skipped, sibling absent* and stops inflating the `[tests]` badge with a gate that measured nothing.
That work does not belong in this bundle and is not planned in `05_EXECUTION_PLAN.md`.

**Interaction with BL-25 and BL-26.** All three are the same underlying shape — the record claiming
more than it measured — and all three are cheap. They belong in one sprint.

---

## D-8 · The advisories (BL-23, BL-24)

**BL-23.** Either give `docs/pending/LEDGER.md:32`'s `DOC-01` a tracking issue link the way
`DOC-03`/`DOC-04` have, or land the one paragraph it is waiting on. Note that D-1 Route A wants an
entry in the **same** `docs/ARCHITECTURE.md` ▸ *Documented deviations* section, so both land in one
edit.

**BL-24.** No action. If `modules/Browser.lua` grows, the seam is already named in
`docs/automated-tests/RESULTS.md`: the skin/close-button factory and the geometry persistence
(`:19-107`, `:110-180`) lift into a sibling in the same folder, which `layout-§1` explicitly
sanctions. Watch the three "Accepted" file-band entries: once three consecutive **release** runs carry
one unchanged, anti-pattern #53 requires it be fixed or converted into a tracked deviation with an
owner.

---

## Ordering constraints

- **D-2 before D-4.** Both touch `settings/` and `modules/`; the behavior fix should not arrive
  inside a mechanical comment sweep.
- **D-1 Route A before anything else** — it is one paragraph and it removes seven rows from the next
  audit's open list, which is what makes that list readable.
- **D-5, D-6, D-7 are independent** of everything else and of each other.
- **D-3 after D-2**, only because both edit `modules/Browser.lua` and a smaller diff is easier to
  smoke-test.
- **D-1 Route B, if ever taken, comes last** and is its own milestone, not a step.
