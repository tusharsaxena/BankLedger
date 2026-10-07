# 05 · Execution plan — Ka0s Bank Ledger — 2026-10-07

The hand-off to the remediation engagement. Four roots, all Low; no step changes stored data or a
player-visible behavior. Each step names its deviation ID; one commit per step, subject starting
`<ID>: `. Green gate after every step: `ka0s-bounded lua tests/run.lua` (0 failed) and
`ka0s-bounded luacheck .` (0/0).

## Sprint 1 — in this repo, no dependencies

- [ ] **BL-52a** — Add the characterization case to `tests/test_ledgertable.lua`: `typesub` grouping with
      `groupAsc = false` and two groups sharing a `sortKey`, asserting header order. Regenerate
      `docs/test-cases.md`; update the README `[tests]` badge in the same commit (`testing-§5`).
- [ ] **BL-52b** — Hoist the group comparator to two module-level functions in `modules/LedgerTable.lua`
      (`04_TECHNICAL_DESIGN.md`). Re-run
      `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`: expect
      `0 warnings`, `max 15` or lower. If still 16, peel the partition loop into a named file-local and
      re-run. Suite unchanged in count.
- [ ] **BL-45** — The four prose fixes (`docs/ARCHITECTURE.md:460`, `core/Constants.lua:235`,
      `docs/smoke-tests.md:113`, `modules/LedgerTable.lua:28-30`). Check:
      `git ls-files | grep -vE '^docs/(audits|reviews|revendor|superpowers)/' | xargs grep -n 'ARCHITECTURE[^ ]* ▸ Logo art\|accepted, documented deviation'`
      returns nothing.
- [ ] **BL-41** — Write `docs/revendor/2026-10-07-v1.69.0-v1.70.0/` (four files). Check: the
      `03_EVIDENCE.md` §E-04 loop prints an empty `UNRECORDED:` list.

## Sprint 2 — upstream, then re-vendor

- [ ] **BL-53 (LibKa0s)** — Open an issue on `tusharsaxena/LibKa0s` (`renderTotals` folds declared skips
      into the inventory Total; `testing-§5`), then fix `testkit/framework.lua` with a kit self-test,
      under LibKa0s's own green gate and release process. Owner approval needed for the tag.
- [ ] **BL-53 (here)** — Re-vendor the tag carrying the fix (both payloads, provenance line in
      `CLAUDE.md`, one commit), write its `docs/revendor/` bundle, regenerate `docs/test-cases.md`.
      Check: Totals = README badge = passes (1258 at today's count plus whatever Sprint 1 added).

## Release checkpoint (when the owner calls for the next version)

- [ ] Run the release run (`bash tests/_kit/run-automated-tests.sh --release <version>` through
      `ka0s-bounded`). The manifest must show `suites.complexity.warnings: 0` and `blindFiles: 0` — the
      first **sighted** record this repo will hold (`BL-52`). Fill the blank watch-list dispositions for
      `tests/test_browser.lua` and `tests/test_profiles.lua`, and re-read `modules/Browser.lua`'s
      (`BL-24`, now 1427).

## Optional, with the next touch of each file (Info)

- [ ] **BL-51** — pass the formatted value as a printer argument at `modules/Browser.lua:901,915`,
      `settings/Slash.lua:111,253,339`, `core/DebugLogSetup.lua:51`.
- [ ] **BL-24** — peel `modules/Browser.lua` along the named seam before it reaches the cap; re-read the
      `standalone-windows` register row's condition (3) in the same change.

## Not in scope

Smoke checks are the owner's to run in game; nothing here changes in-game behavior except the comparator
refactor, whose smoke coverage is the existing History-tab grouping step in `docs/smoke-tests.md`
(*Group: Type & SubType*, `:406-409`).
