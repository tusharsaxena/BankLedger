# 02 — Candidates: LibKa0s v1.32.0

Two surfaces arrive, one per moving file. Both are the same optional descriptor pair,
`bulkBegin(act, scope)` / `bulkEnd(act, scope, count, err, info)`, added so a host can log a bulk
reset through its settings helper as one `[Set]` line (`debug-logging-§10`, standard v2.44.0,
WowAddonStandards `7883278`).

Line numbers are at the tip of `fix/2026-09-12-triage`, after C1 was adopted, not the pre-adoption
numbering this evaluation was first written against.

| # | Surface | Reached here? | Evidence | Recommendation |
|---|---|---|---|---|
| C1 | Slash minor 8: bracket around `CliResetAll` | **Yes, on every non-destructive global reset.** | `/bl resetall` is `NS.COMMANDS` → `NS.Slash:CliResetAll` (`settings/Schema.lua:509`). The General page's Defaults and Blizzard's footer Defaults are `setDefaultsAction` → `P:RestoreDefaults` → `NS.Slash:CliResetAll` (`settings/Panel.lua:626`, `:687`). The host wrapper calls the library's `cli:CliResetAll()` (`settings/Slash.lua`), whose walk runs `applyDefault` → `NS.Schema:Set` per row, and the seam's per-row log line (`settings/Schema.lua:442`, gated on the bracket since C1) logged one `[Set] <path> = <value>` per row: fifteen lines per press. | **Adopt.** Required by `debug-logging-§10`; the rollout spec names this surface for BankLedger. |
| C2 | Options minor 16: bracket around `O.RestoreDefaults` / `O.RestoreAllDefaults` | **No.** | Neither function has a caller outside `libs/`. The page's Defaults action is replaced by `setDefaultsAction`, and `settings/OptionsSetup.lua:93` records why the library's `RestoreAllDefaults` is not used here (LIBKA0S-22, closed issue #10). The degraded stubs of both (`settings/OptionsSetup.lua:202-203`) are no-ops. | **Skip, unreached.** Wiring a pair nothing calls would be dead code. Re-check if a page ever adopts the library's Defaults. |

Two host acts the bracket does not cover were also examined, because the rollout spec names them:

- **The degraded fallback `CliResetAll`** (`settings/Slash.lua`, library absent). It is this addon's
  own walk through the same seam, so it logged per row too. Wrap it in the same bracket.
- **`Sl:ResetEverything`**, the confirm-gated *Reset all settings*. It empties `db.global` wholesale
  and merges the defaults back, so it does reset every stored setting row, but not through the seam,
  and so no per-row line needs muting. `debug-logging-§10` still wants the settings reset logged once,
  as the no-profile form of the profile handler's `reset profile '<name>' to defaults (N rows)`. Add
  one `[Set]` line beside its existing `[Data] reset-all wiped N ledger entries`.
