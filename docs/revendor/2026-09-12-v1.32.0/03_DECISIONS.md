# 03 — Decisions: LibKa0s v1.32.0

Taken non-interactively under the orchestrator's rollout instruction (the owner's `debug-logging-§10`
ruling, 2026-09-12). No issue was filed and nothing was pushed.

| # | Candidate | Decision | Commit |
|---|---|---|---|
| C1 | Slash minor 8 bracket around `CliResetAll` | **Adopted**, plus the fallback `CliResetAll` and the `Sl:ResetEverything` settings line | `81588be` |
| C2 | Options minor 16 bracket | **Skipped, unreached**: no caller of `O.RestoreDefaults` / `O.RestoreAllDefaults` | — |

## Rulings applied during adoption

A correction from the orchestrator, after the LibKa0s v1.32.0 review, arrived before the adoption
commit and is folded into `81588be`:

1. **N is the rows whose stored value changed, not the library's `count`.** `count` counts every row
   whose `applyDefault` returned, rows already at their default included. The muted seam tallies a
   write only when the new value differs from the stored one (`S.SameValue`, deep for the set-typed
   `settings.excludedStores`). `S.BulkEnd` ignores the library's `count` and logs that tally.
2. **Nested brackets log once.** A depth counter sums the tally across levels and emits only as the
   depth returns to 0, under the outermost act and scope. Any level reporting `info.profileReset`
   silences the line. `P:Batch`, which wraps the library call, coalesces repaints and is not a bracket,
   so the Defaults path emits exactly one line.
3. **The hooks are a pair.** `bulkBegin` and `bulkEnd` are always supplied together. `S.BulkEnd`
   ignores an unpaired close.

**A reset that changes nothing still logs its line, as `0 rows`.** Either choice was acceptable
provided no per-row line appears. Emitting keeps the act visible in the log, and the `0` says it
changed nothing.

**`Sl:ResetEverything` wording:** `[Set] reset account-wide settings to defaults (N rows)`. It is the
no-profile form of the profile handler's line. N is the stored rows not already at their default,
read before the wipe. It avoids the word `reset-all`, so the existing
`tests/test_panel.lua` case ("traces the recorded entries it wiped, once"), which counts lines
containing `reset-all`, stays valid unchanged.
