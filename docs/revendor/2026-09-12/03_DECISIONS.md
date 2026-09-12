# 03 — Decisions

This run was **non-interactive**. The owner gave the adoption rule up front, on 2026-09-12, for the
whole LibKa0s v1.30.0 rollout:

- **Adopt** means delete a local shim only where the kit now provides the same contract and the suite
  stays green, with a characterization run first.
- **Decline** means anything that needs a harness migration, such as a `wow_mock` that replaces the
  kit's `NewAddon` / AceEvent / LibStub wholesale so the kit fix cannot reach it.
- Declines are **not filed** as GitHub issues from this run. Each goes back to the owner as a proposed
  issue. The owner approved both afterwards, and they are filed as tusharsaxena/BankLedger#18 and
  tusharsaxena/BankLedger#19.

| Candidate | Decision | Why | Issue |
|---|---|---|---|
| B1 — #29 AceEvent event half on an embed | **decline (not now)** | `tests/wow_mock.lua:712` replaces the kit Embed wholesale, so kit 16's event half never runs here. Lines :714-716 are **not** redundant. Deleting them removes the headless event half: the characterization run stayed at 850/850, but only because the three production call sites are existence-guarded and skip silently. Adopting means wrapping `base`'s Embed, which is a harness migration. | tusharsaxena/BankLedger#18 (filed after the run) |
| B2 — #30 `Printf` beside `Print` | **decline (not now)** | `tests/wow_mock.lua:679` replaces the kit `NewAddon` wholesale for the `__badEvents` raise and the honored-cancel timers, so the kit's `Printf` stamp cannot reach. Nothing is exposed today, because the addon defines no `NS.Printf`. Adopting means wrapping `base.NewAddon`, which is a harness migration. | tusharsaxena/BankLedger#19 (filed after the run) |

Class A items (#27, #28) were delivered on the copy and were not offered.
