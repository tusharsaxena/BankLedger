# Candidates (BankLedger)

Listed, not interviewed: spec S4 of the 2026-10-01 issue pass defers every adoption to GI-LK-13's
consumer census. Nothing here is implemented or filed in this cycle.

1. **Slash 19, the resolver in the host `parse`** (class B, additive). `settings/Slash.lua:443`
   could take `(row, text, textOf)` and pass `textOf` to `lib.ParseValue`, so a host `L` carrying
   `ERR_*` keys would reach the refusal. Evidence: LibKa0s `CHANGELOG.md` v1.66.0, *Slash minor 19*;
   `docs/api/Slash/version-19.1-docs.md`. This addon's locale carries none of those keys today, so
   the change is behaviorally invisible. Recommendation: adopt for parity with the library seam, low
   value.
2. **OptionsTabs 8 `opts.rerender` / `untabbedSkipRender` / `disabledReplaces`** (class B). This addon
   draws General through `RenderTabbedSchema` with an `afterGroup` hook for Filters, which already
   works. Recommendation: no adoption; nothing it fixes here.
3. **OptionsWidgets 34 `RenderGrid` `parent` / `opts.gap`** (class B). No grid is drawn by this
   addon. Recommendation: none.
4. **Perf** (class C, whole module). Settled: the `performance-§12` no-combat-path exemption in
   `docs/ARCHITECTURE.md` ▸ Documented deviations. Peeling the command surface does not move that
   premise.

Class A, delivered on the copy: DebugLog 19's and Slash 19's lower-complexity `lib:New` (no
behavior change), and kit 35's sighted complexity suite.
