# Candidates (BankLedger)

Sources: `git -C ../LibKa0s log --oneline v1.67.0..v1.68.0` (in `01_DELTA.md`), the CHANGELOG block
`../LibKa0s/CHANGELOG.md:13-21` (v1.68.0: WidgetsDragHandle minor 4 only, kit 35, no floor rises, no
major or file added), and the Since-4 markers of `../LibKa0s/docs/api/Widgets/version-12.1.4-docs.md`
against `version-12.1.3-docs.md`.

| Surface | Class | Evidence | Files it would touch | Recommendation | Blast radius |
|---|---|---|---|---|---|
| `tooltipPlace(tip, frame)` on the drag-handle spec, and `place` on a tooltip descriptor (Since 4) | B, a host change | `version-12.1.4-docs.md:20-48`, `:692`, `:725-756` | none: the addon builds no drag handle | **Decline, not applicable.** The hook places the tooltip of a `lib.DragHandle` strip. BankLedger looks up Widgets only for `W.Dropdown`, `W.CloseMenu` and `W.CopyWindow` (`modules/Browser.lua:5`, `modules/Export.lua:14`), and its ledger and session windows drag by their own title regions. There is no strip whose tooltip could be placed. | additive, if it ever applied |

Class A, delivered on the copy: nothing behavioral. With no hook set, minor 4 makes minor 3's calls in
minor 3's order (`version-12.1.4-docs.md:44-45`), and this addon reaches no drag handle in any case.

Class C, whole-module adoption: no major moved that this addon leaves unconsumed. Perf's decline is
settled under the ratified `performance-§12` no-combat-path exemption, and v1.68.0 left Perf alone
(key 14.1.1.6 unchanged), so its premise is unmoved.
