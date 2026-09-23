# 05 · Execution plan — Ka0s Bank Ledger — 2026-09-23

Ordered, checkable steps for the remediation engagement, keyed to `02_DEVIATIONS.md`. Upstream
(LibKa0s) work comes first; this repo takes it by a whole-folder re-vendor. Every step ends on the
green gate — `ka0s-bounded lua tests/run.lua` (today **1017/0/0**) and `ka0s-bounded luacheck .`
(today **0/0 in 71 files**) — and regenerates `docs/test-cases.md` plus the README `[tests]` badge in
the same commit whenever the case count moves (`testing-§5`).

**Headline this plan closes:** 15 roots (1 High, 1 Medium, 13 Low) and 2 dependents — 17 in total,
13 MUST roots / 15 MUST including dependents. The Info row (`BL-51`) is optional.

---

## Sprint 0 — upstream, in LibKa0s (before anything lands here)

- [ ] **S0-1 · `BL-48`.** In `LibKa0s/testkit/run-automated-tests.sh`, teach the `perf` suite
      `automated-tests-§3`'s second skip reason: detect a `performance-§12` row under
      `## Documented deviations` in `docs/ARCHITECTURE.md` (fallback: an explicit flag), write a
      `skipReason` naming `performance-§12`, and make `md_perf_section` say the addon holds the
      ratified exemption. Kit self-tests for both branches; kit revision bump; changelog entry.
- [ ] **S0-2 · release.** Tag the LibKa0s release carrying S0-1 (and whatever else the collection-wide
      plan batches into it).

## Sprint 1 — re-vendor and the record (this repo)

- [ ] **S1-1 · `BL-41`.** Write the consolidated bundle `docs/revendor/2026-09-23-v1.18.0-v1.53.0/`
      (`01_DELTA.md` whose first line names `LibKa0s v1.15.0 → v1.54.2`, `05_SUMMARY.md`), listing the
      36 vendoring commits and 25 unrecorded tags from `03_EVIDENCE.md` §E-01. Verify: the `AUDIT.md`
      re-vendor comparison prints nothing.
- [ ] **S1-2 · re-vendor.** Copy the **whole** `LibKa0s/` ship folder over `libs/LibKa0s/` and
      `testkit/` over `tests/_kit/` at the S0-2 tag; bump `CLAUDE.md:46` in the same commit;
      `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`. Write its own
      `docs/revendor/<date>-v<tag>/` bundle. Verify: `diff -r` against the tag empty,
      `tests/test_vendor_sync.lua` green.
- [ ] **S1-3 · `BL-48` consumer side.** Run the four suites once with the new runner; confirm
      `RESULTS.md`'s Perf section and the manifest's `skipReason` now name `performance-§12`, and that the
      new row carries the commit SHA and clean mark. Commit the bundle as generated.

## Sprint 2 — the one player-reachable finding (owner decision required)

- [ ] **S2-0 · decide `BL-34`.** Put Option A (unify up) and Option B (unify down) from
      `04_TECHNICAL_DESIGN.md` to the owner. Record the decision in the issue store
      (`gh issue create … --label state:triaged --label severity:medium`, then close `state:done` when
      S2-1 lands).
- [ ] **S2-1 · implement `BL-34` (Option A assumed).** Characterization tests first (`testing-§13`):
      pin today's `P:RestoreDefaults`, `/bl resetall` and *Reset all settings* outcomes. Then route all
      three through the confirm-gated `Sl:ResetEverything`; restore `state.debugConsole` and
      `state.testMode` in it; one `SettingsChanged`; update the blast-radius cases in
      `tests/test_panel.lua`; update README Usage (`:88-96`) and Troubleshooting (`:148`) through a de-AI
      pass (`documentation-§1`); add a `## Version History` line at the next release.
- [ ] **S2-2 · `BL-34a`.** Delete the `options-ui-§12` row (`docs/ARCHITECTURE.md:505`) in the S2-1
      commit — or, under Option B, replace it with a new row carrying a real trigger.

## Sprint 3 — lifecycle and events (code, Low)

- [ ] **S3-1 · `BL-46a`.** `tests/wow_mock.lua:614-617`: stop no-opping `C_Timer.After`; keep the prune
      from running in suites without hiding the timer from `mocks.__timers()`. Extend
      `tests/test_disabled.lua:184-203` to drive `OnEnterWorld` before `disable()`; **watch it go red**.
- [ ] **S3-2 · `BL-46`.** `core/BankLedger.lua:216-229`: schedule the prune through AceTimer so
      `NS.StandDown` cancels it; keep the latch belt; the S3-1 case goes green. Falsification comment on
      the case. Update `docs/performance.md:47`.
- [ ] **S3-3 · `BL-47`.** Shared `NS.RegisterEventSafely` with a `C_EventUtils.IsEventValid` front gate;
      route `core/BankLedger.lua:87,91,92`, `modules/Browser.lua:1218`, `modules/SessionWindow.lua:673`
      through it; a case that a bad name in the stand-up block does not stop `Ledger:Enable`; update
      `docs/ARCHITECTURE.md` `## Event Subscriptions`.

## Sprint 4 — tests and TOC (Low)

- [ ] **S4-1 · `BL-37`.** Composed-delta case in `tests/test_schema.lua`: 16 / 8 / 8, attributed to
      `MasterControls`, with its mutation named.
- [ ] **S4-2 · `BL-49`.** `NS.MSG.*` at the 8 addon-message call sites in `tests/test_database.lua`,
      `test_lifecycle.lua`, `test_panel.lua`, `test_schema.lua`, `test_sessionwindow.lua`; a local constant
      for `tests/test_mock.lua`'s scratch name. Re-run the `AUDIT.md` literal grep: only
      `tests/test_bus.lua`'s oracle table may remain.
- [ ] **S4-3 · `BL-36`, `BL-42`.** Annotate `BankLedger.toc:85` (`modules\Insights.lua`) and `:90`
      (`settings\Slash.lua`), each naming what resolves at load.

## Sprint 5 — documentation (Low)

- [ ] **S5-1 · `BL-43`.** Spill `## Settings Schema` (`docs/ARCHITECTURE.md:45-211`) into `schema.md` and
      `settings-panel.md`, keeping a ≤ 60-line summary with one-sentence architecture-§5 namings and one
      link; aim the hub at ≤ ~400 lines. `tests/test_docs.lua` green.
- [ ] **S5-2 · `BL-44`.** Write `docs/debug.md`; flip `docs/ARCHITECTURE.md:467` to *Present*.
- [ ] **S5-3 · `BL-38`.** Four → three at the 7 lines in 6 files (`03_EVIDENCE.md` §E-05); rename the
      `tests/test_marks.lua:98` case; regenerate `docs/test-cases.md`. Re-run the census grep: nothing.
- [ ] **S5-4 · `BL-45`.** Citation sweep over the register rows, `## Event Subscriptions`,
      `docs/performance.md:46`, `settings/Schema.lua:139,178,395-403`, `tests/test_schema.lua:278`,
      `settings/Panel.lua:767` — after S5-1 so each is corrected where it finally lives.
- [ ] **S5-5 · `BL-50`.** `.pkgmeta:17,22` → cite `packaging`.

## Sprint 6 — store hygiene

- [ ] **S6-1 · `BL-39`.** `gh issue close 3` with a comment citing `docs/ARCHITECTURE.md` →
      `localization-§1`; swap `state:triaged` → `state:done`.

## Optional

- [ ] **O-1 · `BL-51`.** Replace the 8 pre-formatted printer calls with argument lists when those files
      are next edited.

## At the next release (not now)

- [ ] **R-1 · `BL-24`.** In the release run's `RESULTS.md` band table, disposition `modules/Insights.lua`
      (1002). Release gate: all four suites `pass` (perf's skip naming `performance-§12`), zero CCN > 15.

## Definition of done

Re-running this audit's checks yields: the re-vendor comparison empty; no `options-ui-§12` row, and one
reset act behind all three controls; `test_disabled`'s timer step red under a `C_Timer.After` prune;
both TOC positions annotated; the delta case present; the four-title-bars census and the stale-citation
table empty; `docs/debug.md` present; issue #3 closed; `RESULTS.md` naming the exemption; the literal
grep returning only the oracle; green gate at the new case count.
