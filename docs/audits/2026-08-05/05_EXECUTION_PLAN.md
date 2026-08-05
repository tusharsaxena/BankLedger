# 05 · Execution plan — Ka0s Bank Ledger — 2026-08-05

Ordered remediation for `02_DEVIATIONS.md`, designed in `04_TECHNICAL_DESIGN.md`. This is the
hand-off to a **separate** engagement; the audit itself changed no addon code.

**Standing rules for every step below.**

- Green gate before **every** commit: `lua tests/run.lua` (all green) **and** `luacheck .` (0/0)
  — testing-§4, versioning-git.
- **Never** edit anything under `libs/` or `tests/_kit/`. Two steps have upstream halves; both say so
  and neither is planned here.
- Trunk-based: commit directly to `master` unless the human asks for a branch.
- Do not bump the version and do not touch `CHANGELOG`/`## What's new` except where a step says to.

---

## Sprint 1 — Record what is already decided *(half a day)*

The cheapest sprint and the one that most changes what the next audit reads.

### S1.1 — Ratify the perf decline *(BL-11, BL-12, BL-13, BL-14, BL-15, BL-16, BL-17 · D-1 Route A)*

- [ ] Add a second entry to `docs/ARCHITECTURE.md` ▸ *Documented deviations*, beside the BL-07 entry,
      naming `performance-§1` and its consequences (`performance-§4/§5/§6/§9`, `toc-file-§2`, `lint`,
      `documentation-§3`), stating the `openContext`-vs-`UnitAffectingCombat` argument as fact, and
      stating explicitly that the **ship payload stays whole** and the wiring is owed the moment a
      measurable path exists.
- [ ] Cross-reference `docs/pending/LEDGER.md:65` (LIBKA0S-17) from the new entry, and the new entry
      from that row.
- [ ] Repoint `docs/automated-tests/README.md`'s closing paragraph at the living
      `docs/ARCHITECTURE.md` record rather than at the frozen `../audits/2026-08-04/02_DEVIATIONS.md`.
- **Done when:** the next audit can read BL-11 … BL-17 as *Accepted (documented)*.
- **Not done by:** adding an empty `core/PerfSetup.lua` or a stub `docs/performance.md`. A file
  nothing reads satisfies a filename and weakens the rule.

### S1.2 — Close `DOC-01` *(BL-23 · D-8)*

- [ ] In the same `docs/ARCHITECTURE.md` edit, land the one-paragraph record `DOC-01`
      (`docs/pending/LEDGER.md:32`) has been deferring, **or** give the row a tracking issue link the
      way `DOC-03`/`DOC-04` have.
- [ ] Expect `DOC-01`'s evidence hash to move; re-settle the row at the next
      `/wow-addon:pending-audit` rather than hand-editing its decision column.

**Sprint 1 checkpoint.** `docs/` only — no `.lua`, no `.toc`, no config. `luacheck .` and
`lua tests/run.lua` unchanged at 0/0 and 726/726.

---

## Sprint 2 — The three "the record claims more than it measured" fixes *(one day)*

All three are the same shape and all three are cheap. They are independent of each other and of
Sprint 1.

### S2.1 — State the release gate *(BL-25 · D-5)*

- [ ] `docs/testing.md` ▸ *Release checklist*: add the gate as its own checkbox — the release run's
      `manifest.json` at all four suites `pass` with `suites.complexity.warnings == 0` — and name the
      evaluator: `/wow-addon:bump-version`, **from the manifest**, never the runner's exit code.
- [ ] Same section: add this addon's standing exception — `perf` is a permanent skip because it ships
      no `tests/perf.lua`, which `automated-tests-§3` sanctions **only if the release notes say so**
      — and add that sentence to the release-notes step.
- [ ] Qualify both "never gates" sentences (`docs/testing.md:88-91`,
      `docs/automated-tests/README.md:26-32`) with the checkpoint they describe. **Keep** the existing
      text and its `--no-verify` rationale; it is correct about runs and commits.
- [ ] **Do not touch** `docs/automated-tests/RESULTS.md` — generated, never hand-edited
      (automated-tests-§4). If its header needs the same qualification, that is a `LibKa0s` finding.
- [ ] **Do not touch** `CLAUDE.md`'s green-gate line — blurring the two checkpoints is the defect
      being fixed.
- **Done when:** `grep -rn -i "release gate" docs/` finds the rule, and a reader running the release
  checklist cannot cut a tag without evaluating all four suites.

### S2.2 — Make the runner executable *(BL-26 · D-6)*

- [ ] `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`; commit. The blob is unchanged,
      so this is **not** an edit to `tests/_kit/` and the byte-identity gate is unaffected.
- [ ] Add `chmod +x tests/_kit/run-automated-tests.sh` to the re-vendor step in `docs/testing.md`'s
      vendor-gate section, where the re-vendor command already lives.
- [ ] Optionally set `core.fileMode = false` in this clone so `drvfs`'s blanket `777` stops fighting
      the index.
- **Verify:** `git ls-files -s tests/_kit/run-automated-tests.sh` reads `100755`.

### S2.3 — Make the vendor gate say when it could not look *(BL-27 · D-7)*

- [ ] Rename both cases in `tests/test_vendor_sync.lua:138,144` so the condition is **in the case
      name** — *"REQUIRES the sibling ../LibKa0s checkout"* — which is where the file's own header at
      `:105-109` already claims it is.
- [ ] Print one line before each `return` naming the path looked for and not found, so a green run
      states out loud that the gate did not look.
- [ ] Correct the header comment at `:105-109`, which currently asserts a property the code does not
      have.
- [ ] Regenerate `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) and update the
      README `[tests]` badge in the **same** change if the count or any name moved (testing-§5).
- [ ] **Do not** add `Kit.skip` to `tests/_kit/framework.lua`. That is the real fix and it belongs in
      the `LibKa0s` repo as an additive kit change, a revision bump, and a whole-folder re-vendor as
      its own commit. Out of scope here.
- **Done when:** a checkout without `../LibKa0s` produces a green run whose output says, in the case
  name and on screen, that the vendor gate was not evaluated.

**Sprint 2 checkpoint.** Docs plus one test file plus one index mode. Suite green; regenerate the
inventory if any case name changed.

---

## Sprint 3 — The two code fixes *(one day)*

### S3.1 — Route the two Browser chat lines through the shared printer *(BL-18 · D-2)*

- [ ] Add `local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer
      (events-frames-taint-§8)` at the top of `modules/Browser.lua`, beside the existing
      `local C = NS.Constants`.
- [ ] Extend `tests/test_browser.lua` with two cases driving `B:SaveView()` and `B:ResetView()` and
      asserting the captured chat line **starts with `NS.PREFIX`** — not merely that a line was
      emitted, which passes against the global `print` too.
- [ ] Carry the falsification comment (testing-§12):
      `-- red under: delete the `local print` line at the top of modules/Browser.lua`. **Actually
      mutate and watch it go red**, then restore from a `cp` backup taken immediately before — never
      `git checkout <file>`, which destroys uncommitted work.
- [ ] Strengthen `tests/test_libka0s.lua:340-349` from *"at least five"* captures to: **every** TOC
      file containing a bare `print(` call also declares `local print = NS.Print`. That is the case
      that would have caught this when it was written, and it generalizes.
- [ ] Regenerate `docs/test-cases.md` and update the README `[tests]` badge in the same change.
- **Why it matters that this is step-shaped rather than a one-liner:** the one-liner has been the
  fix for three cycles (2026-08-03 review F-001, 2026-08-04 audit BL-18, this run) and has not
  landed. The test is what stops a fourth.

### S3.2 — Delegate the window skin to `Core.ApplySkin` *(BL-19 · D-3)*

- [ ] In `modules/Browser.lua:67-89`, resolve `LibStub("LibKa0s-Core-1.0", true)` **at call time**
      inside `B:ApplySkin` and delegate when present; keep the current body verbatim as the
      library-absent branch. Never hoist the lookup to a load-time local.
- [ ] Confirm each of the four call sites assigns `f.title` and `f.divider` **before** calling, since
      `Core.ApplySkin` tints them only when present.
- [ ] Grep for readers of `SKIN.bg`, `.border`, `.innerBorder`, `.divider`, `.title`; once the
      delegation lands and nothing else reads them, drop those five from `B.SKIN`
      (`modules/Browser.lua:19-36`). Keep `tabActive`, `tabIdle`, `titleBarH`, `tabStripH`,
      `contentGap`, `defaultH`, `minH` — those are genuinely the host's.
- [ ] **Do not touch** `B:MakeCloseButton`, and **do not** start passing `makeCloseButton` to the
      console. That split is correct and its reason is written at `core/DebugLogSetup.lua:111-116`.
- [ ] Smoke-test in client: the ledger window, the session window, both export popups and the debug
      console must all still show the **two-line** edge — hard black outer, lighter gray line just
      inside. A single-line edge of either color is the regression, and it is the one hardest to see
      in a screenshot taken on its own.

**Sprint 3 checkpoint.** Green gate, regenerated inventory, badge in step, and the smoke tests above
recorded.

---

## Sprint 4 — The reference sweep *(half a day, its own commit)*

### S4.1 — Fix the nine unresolvable standard references *(BL-20 · D-4)*

- [ ] Apply the nine substitutions in `04_TECHNICAL_DESIGN.md` D-4's table, across
      `settings/OptionsSetup.lua:43,65,74`, `settings/Panel.lua:11,58`, `settings/Schema.lua:184`,
      `tests/test_panel.lua:175`, `docs/ARCHITECTURE.md:106`, `docs/pending/LEDGER.md:63`.
- [ ] Land it as **its own commit**. A mechanical comment sweep mixed with a behavior change is
      unreviewable — the diff is all noise and the one line that matters looks like the rest of it
      (performance-§11).
- [ ] **Do not** edit `libs/LibKa0s/Options.lua:129,173,233`. Same defect, the library's text; raise
      it in the `LibKa0s` repo and pick it up at the next re-vendor.
- [ ] Add a guard case to `tests/test_harness.lua`: walk every tracked `.lua` and `.md` outside
      `libs/`, `docs/audits/`, `docs/reviews/` and `docs/automated-tests/` for `§[0-9]+\.[0-9]+` and
      for `-§` followed by two or more digits; fail naming the file and line. Both patterns are
      unambiguously wrong under the current scheme, so no false positives.
- [ ] Expect `docs/pending/LEDGER.md`'s `LIBKA0S-15` hash to move; re-settle at the next
      pending-audit.
- **Verify:** the sweep in `03_EVIDENCE.md` §1.8 returns nothing outside the legitimate `-§10`/`-§11`
  forms.

---

## Deferred — not scheduled

| Item | ID | Why deferred |
|---|---|---|
| Adopt the full Perf wiring | BL-11 … BL-17, D-1 Route B | Only worth doing if the buckets can read non-zero; S1.1 records the decision instead. Its own milestone if the premise changes. |
| Raise the perf N/A upstream | D-1 Route C | Standards-repo work, not addon work. Worth doing; does not block S1.1. |
| `Kit.skip(reason)` in the kit | BL-27 upstream half, D-7 | `LibKa0s` repo: additive kit change, revision bump, whole-folder re-vendor **as its own commit** in every consumer. |
| Malformed refs inside `libs/LibKa0s/Options.lua` | BL-20 upstream half | `LibKa0s` repo; a local patch here is reverted silently by the next re-vendor. |
| Peel `modules/Browser.lua` | BL-24 | 1368 LOC, under the 1500 cap. Seam already named in `RESULTS.md`. Revisit if it grows or if a band entry carries "Accepted" across three consecutive **release** runs (anti-pattern #53). |

---

## Verification checklist for the whole engagement

- [ ] `luacheck .` — 0 warnings / 0 errors.
- [ ] `lua tests/run.lua` — all green; case count reconciles with `docs/test-cases.md` and the README
      `[tests]` badge.
- [ ] `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` — run **verbatim**; no function above CCN 15
      and no new file in the 1000–1500 band. If either moved, record it with a disposition in
      `docs/automated-tests/RESULTS.md`'s watch list **in the change that caused it**.
- [ ] `git ls-files -s tests/_kit/run-automated-tests.sh` — `100755`.
- [ ] `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and `diff -r ../LibKa0s/testkit tests/_kit` — both
      empty. **This audit could not run either** (single-repo constraint, `03_EVIDENCE.md` §1.5);
      run them on a machine holding the sibling before the next release.
- [ ] `grep -rn -E "§[0-9]+\.[0-9]+|-§[0-9]{2,}"` outside `libs/` and the frozen bundles — empty.
- [ ] `docs/ARCHITECTURE.md` ▸ *Documented deviations* carries both BL-07 and the perf decline.
- [ ] `docs/testing.md` states the release gate **and** keeps the commit-gate rule intact.
- [ ] Smoke tests re-run for the window edge after S3.2.
