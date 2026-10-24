# Candidates (BankLedger)

Sources: the `CHANGELOG.md` v1.77.0 block at the tag and the API documents
`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md`,
`docs/api/Widgets/version-15.1.5.3.3-docs.md`, `docs/api/Core/version-12-docs.md`,
`docs/api/DebugLog/version-21.3.1-docs.md`, `docs/api/Sim/version-2.3.6-docs.md` and
`docs/api/testkit/version-42-docs.md`. The run's item spec pre-decides the adoptions
(`Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/plan-data/items.json`, BL-RV): the
ones this run needs are the BL-KB and BL-ZS items on the same branch, and every other candidate is
recorded as **deferred (run 2026-10-24)**. There is no interview and no `03_DECISIONS.md` here, and
no issue is filed.

The Options stub parity (four new no-op members) is a blocker, not a candidate; `01_DELTA.md`
records it and this item's commit fixes it.

## Class A: delivered on the copy

- The debug console and the sim step panel are toplevel and re-raise a shown StaticPopup on show
  (DebugLog 21, SimPanel 6, Core 12's `RaiseStaticPopups`).
- The shared dropdown menu and the autocomplete list are clamped to the screen (Widgets 15,
  WidgetsAutocomplete 3).
- The suggestion list of the Filters tab's two `O.IdList`s closes at combat start (OptionsIds 3,
  OptionsCombat 2).

## Class B: host change

| Candidate | Evidence | Touches | Decision |
|---|---|---|---|
| Keybindings tab: `O.KeybindingsTab` / `O.KeybindRows` / `O.KEYBINDS_UNCHANGED`, with `Bindings.xml` on the per-addon category | Options doc `:61-71`; CHANGELOG v1.77.0 *OptionsKeybinds minor 2* | `Bindings.xml`, `settings/Panel.lua`, the window module, tests | adopted in BL-KB (this branch) |
| Kit `mock_bindings.lua`, `T.assertBindingsXml`, `T.keybindThroughTab` | testkit doc `:26-37`; CHANGELOG *Test kit revision 42* | `tests/` | adopted in BL-KB (this branch) |
| Kit `mock_layers.lua`, a frame-layering table, `Core.RaiseStaticPopups` from the host windows' `OnShow` | testkit doc `:82-89`; Core doc `:24-35` | `modules/Browser.lua`, `modules/SessionWindow.lua`, tests | per `plan-data/accepted.json`, in BL-ZS (this branch, held for the owner) |
| `O.StrataTooltip(values, strings)` | Options doc `:86-92` | none today: BankLedger has no player strata row | deferred (run 2026-10-24) |
| DragHandle `spec.level`, `spec.ignoreParentAlpha`, `handle:ApplyLevel()` | Widgets doc `:39-49` | none today: BankLedger builds no DragHandle | deferred (run 2026-10-24) |

## Class C: whole-module adoption

- Perf (PerfPanel 9 moved): settled, not re-litigated. BankLedger's capture engine never runs in
  combat, the ratified `performance-§12` no-combat-path exemption (`docs/performance.md`); this
  release changes nothing about that premise.
