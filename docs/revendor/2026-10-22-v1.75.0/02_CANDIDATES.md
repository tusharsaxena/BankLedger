# Candidates (BankLedger)

Sources: the `CHANGELOG.md` v1.72.0 to v1.75.0 blocks at the tag, and the API documents at the tag
for every consumed major whose minor moved:
`docs/api/Widgets/version-13.1.4.3.2-docs.md`, `docs/api/Item/version-3-docs.md`,
`docs/api/Options/version-29.2.34.2.5.9.1.7.4.2.1-docs.md`, `docs/api/Media/version-5.1-docs.md`,
`docs/api/Core/version-11-docs.md`, `docs/api/DebugLog/version-20.3.1-docs.md`, and
`docs/api/testkit/version-41-docs.md`. The adoptions are pre-decided by the run's owner scope
(`Ka0sAddonsCommonTasks/docs/2026-10-22-LIBKA0S_ISSUES_45_58/inputs/OWNER_SCOPE.md`), so there is no
interview and no `03_DECISIONS.md` here. Each adoption is a later item on the same branch.

## Class A: delivered on the copy

- Options minor 29: a structural refresh of a page on screen keeps its scroll offset.
- The corrected icon-fallback comments (Core 11, DebugLog 20, OptionsIdList 5) and the PerfPanel 7
  header comment. No behavior moves.
- DebugLogDiagnostics minor 3: `/bl diagnostics` names Glow and Sim in its `LibKa0s running:` line
  when a client runs them.
- Kit 39 `__fireUnconditional` reach, kit 40's declaration gate and kit 41's crashed complexity
  bucket, all through the kit copy.

## Class B: host change, accepted

| Candidate | Evidence | Touches | Items |
|---|---|---|---|
| `W.SearchBox(parent, width, opts)` (Widgets 13, LibKa0s#52) | CHANGELOG v1.75.0 *Widgets minor 13: W.SearchBox*; Widgets 13.1.4.3.2 document | `modules/Browser.lua`'s hand-built search box, through `B:MakeSearchBox` | BL-02 |
| `W.TestStrip(parent, opts)` (Widgets 13, LibKa0s#48), with the host's own `info` mark | CHANGELOG v1.75.0 *Widgets minor 13: W.TestStrip* | the test-mode mark under the filter bar | BL-03 |
| `Item.BonusIDsFromLink(link)` (Item 3, LibKa0s#51) | CHANGELOG v1.75.0 *Item minor 3* | `Util.WowheadURL`'s bonus-id walk (`itemStringFields`) | BL-01 |

All three are accepted by OWNER_SCOPE. The search box and the bonus-id reader replace code the addon
owns today (a hand-built box and a hand-written itemString walk), so each needs a characterization
test first. The TestStrip is additive: the red test-mode badge stays.

## Class C: whole-module adoption

| Candidate | Status | Items |
|---|---|---|
| `LibKa0s-Sim-1.0` (LibKa0s#54) | Accepted by OWNER_SCOPE: a new BankLedger sim on Sim-1.0, whose step panel ticks with the host-passed `confirm` and closes with `close`, both already declared | BL-05..BL-13 (prerequisites BL-05..BL-07, seam BL-08, panel BL-12) |
| `LibKa0s-Glow-1.0` (LibKa0s#56) | **Not applicable.** BankLedger draws no glow and has no LibCustomGlow host code to replace | none |

## Not applicable

- **Direct `W.StepPanel` use.** It is not public (LK-11 outcome B). The renderer is private to
  Sim-1.0, and BankLedger reaches it only through the Sim panel.
- **`O.Drawer`** (Options, v1.73.0). BankLedger's settings pages have no drawer, and no file calls
  it. It is ignored in the parity case (`01_DELTA.md` 4b), not adopted.
- **`Kit.assertLatchHoldOrder`** (kit 39). This is optional, and nothing requires it. The
  hand-written step-10 case in `tests/test_disabled.lua` stays.
- **Perf 15.** BankLedger wires no perf harness under its ratified `performance-§12` no-combat-path
  exemption, which is settled and unaffected by this release.

## Declines

None, so no GitHub issue is filed.
