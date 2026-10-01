# Decisions (BankLedger)

- No adoption interview was run and no GitHub issue was filed: spec S4 of
  `Ka0sAddonsCommonTasks/docs/2026-10-01-GITHUB_ISSUE_PASS/02_SPEC.md` defers the candidates in
  `02_CANDIDATES.md` to GI-LK-13 (the consumer census).
- Adopted in the re-vendor commit, because the kit's adoption steps require it: `test_lizard_sighted`
  wired in `tests/run.lua`, and the complexity rows in `docs/testing.md`,
  `docs/automated-tests/README.md` and `DEPENDENCIES.md` pointed at the runner's sighted suite
  (lizard pinned at 1.24.0).
- `tests/test_panel.lua`: the reset-routes case's three function literals hoisted out of the
  `for ... in` header, the one blind file the sighted suite named (114 of 115 functions listed).
