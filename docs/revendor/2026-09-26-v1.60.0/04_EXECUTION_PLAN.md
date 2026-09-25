Execution plan: LibKa0s v1.58.0 -> v1.60.0

# 04 — Execution plan

Nothing is implemented from `03_DECISIONS.md` in this run. Both adoptions are the plan's item
DR-BL-03, which depends on this re-vendor (DR-BL-01) and carries its own characterization tests
(STD-19: the kit's `test_diagnostics_contract.lua` wired through `Kit.diagnostics`, plus the addon's
domain cases) and its own commit.

This run's one commit (DR-BL-01) carries the payloads, the provenance line and the two contract
fixes of `01_DELTA.md` 3g:

| File | Change | Proof |
|---|---|---|
| `core/DebugLogSetup.lua` | degraded stub gains `RunDiagnostics`, `BuildDiagnostics`, `DebugVerb` | `test_surface_parity.lua` DebugLog parity; new `test_libka0s.lua` case on the placeholder line, 0 count, empty build, no debug word claimed |
| `settings/Slash.lua` | degraded `LIVE_VERBS` gains `diagnostics` | new `test_libka0s.lua` case walking the live `lib.LIVE_VERBS` through the degraded gate while disabled, plus a feature verb still refused |
| `tests/run.lua` | declares `{ name = "test_diagnostics_contract", dir = "tests/_kit/" }` | the kit's suite-inventory check; the suite registers one declared skip until DR-BL-03 |
