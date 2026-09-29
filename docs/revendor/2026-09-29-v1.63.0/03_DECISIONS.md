# Decisions (BankLedger)

- Adopted: only the Slash minor 17 profile surface, by SP-BL-02 in the commit after this re-vendor
  (`/bl profile` routed to `CliProfile`, `profiles = function() return NS.db end`, `profile` live
  while disabled, and the degraded stub carrying `CliProfile` and `ProfileSwitch`).
- No adoption interview was run and no GitHub issue was filed: the run's plan fixes the scope
  (`Ka0sAddonsCommonTasks/docs/2026-09-29-SMOKE_REWORK_AND_PROFILE_VERB/02_SPEC.md`, S3), and the
  release offers nothing else to adopt.
- No stub change in the re-vendor commit: the Slash parity case stays green on the copy alone.
