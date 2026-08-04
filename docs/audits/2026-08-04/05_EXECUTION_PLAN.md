# 05 · Execution plan — Ka0s Bank Ledger — 2026-08-04

Ordered hand-off to the remediation engagement. Keyed to the deviation IDs in `02_DEVIATIONS.md` and
the designs in `04_TECHNICAL_DESIGN.md`. Standard: **v2.17.1 (2026-08-03)**.

**Gate on every commit:** `lua tests/run.lua` green **and** `luacheck .` at 0 warnings / 0 errors
(`testing-§4`, `versioning-git`). Both are green at the start of this plan — 689/689, 0/0.

**Never touch** `libs/` or `tests/_kit/`. A defect in either is a LibKa0s finding and a re-vendor,
never a local patch (`library-stack-§7`, `testing-§1`).

---

## Sprint 0 — the decision (no code)

Nothing in Sprint 2 can start until this closes. Sprints 1 and 3 are not blocked by it.

- [ ] **S0.1 — Classify the performance gap.** *(BL-11, BL-12, BL-13, BL-14, BL-15, BL-16, BL-17)*
      Present the three options from `04_TECHNICAL_DESIGN.md` Track B to the user and get a ruling:
      **(1)** adopt the wiring, **(2)** record an accepted deviation, **(3)** raise it upstream.
      `CLAUDE.md:14-23` requires the user to make this call, not the implementer.
      **Done when:** the choice is written down.

- [ ] **S0.2 — If option 2 or 3: record it.** *(BL-11 … BL-17)*
      Add a *Documented deviations* entry to `docs/ARCHITECTURE.md` beside the existing BL-07 one
      (`:567-580`): the sections deviated from, the LIBKA0S-17 argument in the addon's own words, and
      the conditions that would reopen it. If option 3, also open the upstream proposal in
      `WowAddonStandards` and link it from the entry.
      **Verify:** the entry names `performance-§1` and its six siblings, and the next audit can find
      it without reading `docs/pending/LEDGER.md`.

---

## Sprint 1 — the correctness fix

Smallest, highest-value, blocked by nothing. Land it first and on its own.

- [ ] **S1.1 — Write the failing tests.** *(BL-18)*
      Add two cases to `tests/test_browser.lua`: `B:SaveView()` emits exactly one chat line carrying
      `NS.PREFIX`; `B:ResetView()` does the same and `B:ResetView(true)` emits none. They must be
      **red** before S1.2.
      **Verify:** `lua tests/run.lua` fails, and fails on these two cases specifically.

- [ ] **S1.2 — Bind the shared printer.** *(BL-18)*
      Add `local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer
      (events-frames-taint-§8)` to the header of `modules/Browser.lua`, beside `local C =
      NS.Constants` (`:4`). No other edit — `:855` and `:864` are already correct once the upvalue
      exists.
      **Verify:** both new cases pass; `luacheck .` still 0/0.

- [ ] **S1.3 — Prove the tests can fail.** *(BL-18, `testing-§12`)*
      `cp modules/Browser.lua /tmp/Browser.bak`, delete the new line, confirm both cases go red,
      restore from the **backup** (never `git checkout` — the standard warns this has cost a
      milestone's work in this collection). Add a one-line comment on each case naming the mutation.
      **Verify:** the comment reads `-- red under: drop the `local print = NS.Print` binding`.

- [ ] **S1.4 — Roll the visible artifacts forward.** *(BL-18, `testing-§5`, `documentation-§1`)*
      Regenerate `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`), update the
      README `[tests]` badge to the new X/Y, bump `## Version:` (patch), and roll `## What's new` and
      the top `## Version History` row forward — all in the **same** commit.
      **Verify:** the three counts agree (run, inventory, badge); `## What's new` names the new
      version.

- [ ] **S1.5 — Commit.** One commit, green gate checked first.

---

## Sprint 2 — performance (only if S0.1 chose option 1)

Skip entirely under options 2 and 3. Order inside this sprint is load-bearing: the host contract
lands before the instrument that depends on it, and the plumbing lands before the verb that drives it.

- [ ] **S2.1 — Make the capture engine arm/disarm cleanly.** *(BL-17)*
      Split `modules/Ledger.lua`'s `L:Enable` (`:761`) into an idempotent `L:Arm()` / `L:Disarm()`
      pair, `L:Enable` calling `L:Arm`. Add session-only `State.perfSuspended` to `core/State.lua`
      (never persisted). Consult it **inside** `SW:Enabled()` and the browser's show decision — never
      by hiding frames. Do **not** make suspend a second sender of
      `Ka0s_BankLedger_SessionChanged` (`modules/Ledger.lua:475-481` documents the sole-sender
      invariant).
      **Tests:** suspend leaves the addon genuinely inert — no event registrations, no queued work,
      the show ladder refusing; resume rebuilds from **current** state, so a setting changed while
      suspended comes back correctly.
      **Verify:** existing ledger and session-window suites still green — this touches the addon's
      reason for existing.
      **Commit on its own.**

- [ ] **S2.2 — Declare the plumbing.** *(BL-12, BL-14)*
      `BankLedger.toc:7` → `## SavedVariables: BankLedgerDB, BankLedgerPerfDB` (that order).
      `.luacheckrc`: `debugprofilestop` into `read_globals`, `BankLedgerPerfDB` into `globals`, each
      with a justifying comment matching the file's existing style.
      **Verify:** `luacheck .` 0/0; `tests/test_harness.lua`'s TOC assertions still pass.

- [ ] **S2.3 — Add `core/PerfSetup.lua`.** *(BL-11)*
      New file with the silent-then-guarded `LibStub("LibKa0s-Perf-1.0", true)` lookup, the descriptor
      (name, SV name, buckets `stats`, `reconcile`, `query within = "stats"`), and a stub answering
      **every** member the addon calls. TOC-position it in `# Core` after `core/DebugLogSetup.lua`
      and before `core/Database.lua` and `modules/Ledger.lua`.
      **Tests:** descriptor well-formed; the declared bucket set and nesting are what the addon means;
      **the degraded path verified by actually loading with `libs/LibKa0s/Perf.lua` dropped from
      `tests/run.lua`'s file list**, not by hand-stubbing `NS.Perf` (`testing-§8`) — copy the shape
      already used for the other three modules in `tests/test_libka0s.lua`.

- [ ] **S2.4 — Bracket the three paths.** *(BL-11, `performance-§2`/`§3`)*
      The exact gated shape, nothing else:
      `local t0 = Perf.on and debugprofilestop()` … `if t0 then Perf.Note(key, debugprofilestop() -
      t0) end`, with `local Perf = NS.Perf` as a **file-scope upvalue**. No allocation, concat, format
      or call inside a dormant bracket.
      **Tests:** **every declared bucket is reached by a real bracket**, driving each bucket's genuine
      entry point — `performance-§3` says a bucket no bracket reaches is *"a lie in every report"* and
      nothing else will catch it.

- [ ] **S2.5 — Wire the `perf` verb.** *(BL-13)*
      One positional triple in `NS.COMMANDS` (`settings/Schema.lua:226-286`), printing the lines the
      library returns through the host's tagged printer. A bare `/bl perf` must be the **entry point
      to a run**, not a status line. Regenerate the README command table in the **same** change.
      **Verify:** `/bl help`, the settings landing page and the README table all show the new row —
      they share one formatter and one source, so if any disagrees something else is wrong.

- [ ] **S2.6 — Add `tests/perf.lua`.** *(BL-16)*
      Offline scenario runner, load list derived from the TOC (`testing-§9`), **outside** the green
      gate and **not** invoked by `tests/run.lua`. Assert only call counts and bytes allocated —
      never wall-clock. Ship the **zero-overhead scenario** over the `stats` path: capture off must
      allocate no more than the same path with instrumentation absent.
      **Verify:** `lua tests/perf.lua` runs standalone; `lua tests/run.lua --list` count is unchanged
      by it (`testing-§7`).

- [ ] **S2.7 — Write the two required docs.** *(BL-15)*
      `docs/performance.md` — which paths are bracketed and why, how to run a capture, how to read the
      report, and **what the harness cannot resolve for this addon** (the combat-window caveat from
      LIBKA0S-17 belongs here, not in a ledger row). `docs/perf-runs/README.md` — naming convention,
      schema summary, pointer to the library's canonical contract.
      **Verify:** `documentation-§3`'s three required topic-detail docs all exist.

- [ ] **S2.8 — Smoke test and roll forward.** *(BL-11 … BL-17)*
      Add a `docs/smoke-tests.md` case for arm → suspend → resume → arm across a real bank open/close.
      Regenerate `docs/test-cases.md`, update the `[tests]` badge, bump the minor version, roll
      `## What's new` and Version History forward. Update `docs/ARCHITECTURE.md`'s module map and
      load-order section for the new file.

---

## Sprint 3 — hygiene

Independent of Sprints 0–2. Each step is separately landable.

- [ ] **S3.1 — Fix the eight unresolvable standard references.** *(BL-20)*
      Apply the mapping table in `04_TECHNICAL_DESIGN.md` C2 across
      `settings/OptionsSetup.lua`, `settings/Schema.lua`, `settings/Panel.lua`,
      `docs/ARCHITECTURE.md`, `tests/test_panel.lua`.
      **Verify:** `grep -rn -E "§[0-9]+\.[0-9]+|-§[0-9]{2,}" --exclude-dir={.git,libs,audits,reviews} .`
      returns nothing outside the `-§10`/`-§11` forms that legitimately exist.
      **Then:** add that sweep to `docs/testing.md`'s *Release checklist* (`:44-56`) so it does not
      come back.

- [ ] **S3.2 — Delegate the window skin to `Core.ApplySkin`.** *(BL-19)*
      Rework `modules/Browser.lua:67-89` per `04_TECHNICAL_DESIGN.md` C1: assign `f.title` /
      `f.divider` first, resolve `LibKa0s-Core-1.0` **at call time**, delegate when present, keep the
      current body only as the library-absent branch. Trim the five `SKIN` fields that restate
      `Core.SKIN`; keep the addon-specific ones.
      **Tests:** with Core present the helper delegates; with Core absent the fallback still produces
      the five normative values.
      **Smoke test:** open the ledger window, session window, an export popup and the debug console
      together and confirm the two-line edge — hard black outer, lighter gray inner — reads identically
      on all four. This is the one step in the plan with a visual regression surface, and it reaches
      the debug console too (`core/DebugLogSetup.lua:107-109`).

- [ ] **S3.3 — Generate `docs/complexity.md`.** *(BL-21, BL-24)*
      `lizard core modules settings defaults locales -x "libs/*" > docs/complexity.md`, with a header
      stating it is generated, the command, and that it is report-only and never a gate. If `lizard`
      is not installed locally, record the step as **not run** rather than faking a report —
      `performance-§10` says absent tooling means the report is stale, not that the addon is
      non-compliant.
      **Then:** read the `modules/Browser.lua` numbers before deciding anything about BL-24.

- [ ] **S3.4 — Tidy the pending ledger.** *(BL-23)*
      Either give `DOC-01` a tracking-issue link the way `DOC-03`/`DOC-04` have, or re-run
      `/wow-addon:pending-audit` so `DOC-01` closes against the ARCHITECTURE entry that has since
      landed (`docs/ARCHITECTURE.md:567-580`). Do **not** hand-edit the decision column — the file
      says so at `:12-13`.

---

## Not scheduled

| ID | Why |
|---|---|
| **BL-07** | Accepted and documented (`docs/ARCHITECTURE.md:567-580`). Reopen only if the user prefers the upstream route. |
| **BL-24** | Advisory only; nothing exceeds the 1500-LOC cap. Revisit after S3.3 produces numbers. |
| `tests/_kit/README.md:119` "behaviour" | A **LibKa0s** finding. Fixing it here breaks `tests/test_vendor_sync.lua` and would be silently reverted by the next re-vendor. Raise it in the library repo. |
| Test falsifiability (`testing-§12`) | Not mechanically auditable; the standard forbids recording its absence as a deviation. Recorded as **unverified** in `03_EVIDENCE.md` §1.10. |

---

## Definition of done for this remediation

- [ ] `lua tests/run.lua` green; `luacheck .` 0 warnings / 0 errors.
- [ ] `docs/test-cases.md`, the README `[tests]` badge and the live run all report the same X/Y.
- [ ] `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and `diff -r ../LibKa0s/testkit tests/_kit` both still
      empty; nothing under `libs/` or `tests/_kit/` was edited.
- [ ] Every standard reference in the repo resolves (`filename-§N`, no `§N.M`).
- [ ] `modules/Browser.lua` has no bare `print(` call — every chat line carries `[BL]`.
- [ ] Every remaining deviation is either fixed or has a *Documented deviations* entry in
      `docs/ARCHITECTURE.md` naming the section and the reason.
- [ ] `## What's new`, `## Version History` and `## Version:` all agree and name the current release.
- [ ] This audit folder is untouched — a re-audit writes a new dated folder beside it.
