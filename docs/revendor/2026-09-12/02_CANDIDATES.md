# 02 — Candidates: LibKa0s v1.29.0 → v1.30.0

Sources, in the order the procedure requires. None of this is from memory:

```
git -C ../LibKa0s log --oneline v1.29.0..v1.30.0             # 4 commits, all kit revision 16
git -C ../LibKa0s show v1.30.0:CHANGELOG.md                  # the v1.30.0 block
git -C ../LibKa0s show v1.30.0:docs/api/testkit/version-16-docs.md
```

No major's minor moved (01_DELTA §3c), so there is no `docs/api/<Major>/` surface to diff. The
release is four kit changes. Each is classified below.

## A — Reached this addon on the re-vendor alone (delivered, not offered)

| Item | Evidence | Why it needs no host change |
|---|---|---|
| **#28 — the runner-mode case** | CHANGELOG v1.30.0, "Kit revision 16, `vendor_sync.lua`" | `tests/test_vendor_sync.lua:37` is the one-line `VendorSync.register(_G.BL_TEST, {})`, so the new case `the automated-test runner is recorded executable (100755)` registers on its own. It **passes**: `git ls-files -s tests/_kit/run-automated-tests.sh` → `100755`. The total moves 849 → 850, which matches the changelog's measured figure for BankLedger. There was no local runner-mode case to delete. |
| **#27 — `AceGUI:Release`** | CHANGELOG v1.30.0, "Kit revision 16, `mock_base.lua` — `AceGUI:Release`" | `tests/wow_mock.lua:641-648` wraps the kit's AceGUI `Create` to add `SetTitle` and keeps the kit factory underneath, so the new `Release` / `widget:Release()` is present headlessly. Nothing here calls it: `grep -rn ':Release(' core modules settings` returns nothing. There was no local shim to delete. |

## B — Host change required (candidates)

### B1 — #29: AceEvent's event half on an embed

- **What.** Kit 16 stamps recorded `RegisterEvent` / `UnregisterEvent` / `UnregisterAllEvents` onto
  every `AceEvent:Embed` target, over `obj.__events`, with real-Ace3 validation and a per-build
  registry.
- **Evidence.** CHANGELOG v1.30.0, "Kit revision 16, `mock_base.lua` — AceEvent's event half on an
  embed". Local side: `tests/wow_mock.lua:712-719`.
- **What the local code is.** It is a **wholesale replacement**, not a wrapper:
  `libs["AceEvent-3.0"] = { Embed = function(_, obj) ... end }` (:712). The kit's Embed is never
  called. Lines :714-716 stamp the event half as unrecorded no-ops (`obj.X = obj.X or function() end`).
  The same Embed routes through the local `embedBus` (:654-676), which carries
  `UnregisterAllMessages` (:667-669) and `M.__msgRegistry` (:655). The kit Embed has neither.
  `addon:OnDisable` (`core/BankLedger.lua:84`), `tests/test_mock.lua:308-319` and
  `tests/test_lifecycle.lua:57-68` depend on those two.
- **Are :714-716 now redundant?** **No.** Because the kit Embed never runs, kit 16's event half cannot
  reach this harness. Deleting the three lines deletes the event half rather than handing it to the
  kit. A characterization run with them deleted was still green, 850/850. The reason is that all three
  production call sites are existence-guarded (`core/BankLedger.lua:85`, `modules/Browser.lua:1248`,
  `modules/SessionWindow.lua:672`), so the calls are skipped silently. That is lost coverage, not
  equivalence.
- **What adoption would take.** A harness migration: make the local Embed wrap `base`'s Embed and keep
  only `UnregisterAllMessages` and the registry exposure on top. Alternatively, move
  `UnregisterAllMessages` upstream into the kit first.
- **Blast radius.** Replacement. It rewires the mock surface every lifecycle and bus test runs on.
- **Recommendation.** **Decline (not now)** under the owner's standing rule: harness migrations are
  declined in this rollout.

### B2 — #30: `Printf` beside `Print`

- **What.** Kit 16's `NewAddon` stamps an AceConsole-shaped `Printf` beside `Print`, so an addon that
  forgets to reclaim `NS.Printf` fails a suite.
- **Evidence.** CHANGELOG v1.30.0, "Kit revision 16, `mock_base.lua` — `Printf` beside `Print`". Local
  side: `tests/wow_mock.lua:678-711`.
- **What the local code is.** `libs["AceAddon-3.0"] = { NewAddon = ... }` (:679) replaces the kit's
  `NewAddon` wholesale. It stamps a `Print` of its own shape (:708), which returns the string and
  never calls `AddMessage`, and it stamps no `Printf`. The replacement exists for behaviour the kit
  does not model: `RegisterEvent` raising on `M.__badEvents` (:686-690, which `tests/test_ledger.lua:639-694`
  depends on), and the honored-cancel timer queue (:696-703).
- **Is anything exposed today?** No. The addon defines no `NS.Printf` (`grep -rn 'Printf' core modules
  settings locales` returns nothing), so there is no reclaim to miss. The kit guard only matters once
  a `Printf` exists.
- **What adoption would take.** The same harness migration as B1: wrap `base.NewAddon` and override
  only `RegisterEvent`, `ScheduleTimer` / `CancelTimer`, and possibly `Print`, on top.
- **Blast radius.** Replacement. Every test that builds the addon goes through `NewAddon`.
- **Recommendation.** **Decline (not now)**, as for B1.

## C — Whole-module adoption

None new. This release added no major. The one unconsumed major, Perf, is the **settled** decline in
`docs/ARCHITECTURE.md` → Documented deviations (`performance-§12`). It rests on the addon's capture
engine never running in combat, and v1.30.0 changes nothing in `Perf.lua` (minor 10 → 10), so the
premise has not moved.
