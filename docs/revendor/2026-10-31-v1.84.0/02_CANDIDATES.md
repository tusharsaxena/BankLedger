# Candidates (BankLedger)

Sources: the `CHANGELOG.md` v1.84.0 block at the tag and the API documents at each new version
(`docs/api/Options/version-35.4.40.2.6.1.7.13.2.3.15.9.4.3.6.5.5.1.1.1-docs.md`,
`docs/api/Charts/version-1.1-docs.md`, `docs/api/Schema/version-3-docs.md`,
`docs/api/Widgets/version-17.3.10.5.5.2-docs.md`). The run's brief pre-decides the outcome: no named
adoption for this addon, every candidate beyond the brief recorded as declined, no issue filed, no
interview.

The `O.PositionBlock` stub is a blocker, not a candidate; `01_DELTA.md` records it.

## Class A: delivered on the copy

- `O.ClearScroll` keeps the band's refresher (Options 35). This addon's banner takes no `acts`, so
  it sees no change.
- The peels (`SkinOwnerTokens`, `SkinDefsOthers`, `SimPanelRender`, `OptionsSkinPickerRows`,
  `OptionsIdSuggest`, `OptionsFlow`, `OptionsTabbed`) are pure moves and arrive through
  `LibKa0s.xml`, which `tests/run.lua` derives its load list from.
- The identity header names Charts (DebugLogDiagnostics 6): smoke DIAG-32.
- WoW Default's Friz is measured and guarded; no size moves.

## Class B: host change

| Candidate | Evidence | Touches | Blast radius | Decision |
|---|---|---|---|---|
| `opts.beforeGroup` / `opts.afterSubgroup` | Options doc, *the flow seams* | `settings/Panel.lua` | additive | declined (run 2026-10-31): the page's `afterGroup` hooks cover it |
| `note` row | Options doc, *The `note` row*; Schema 3 | `settings/Schema.lua`, `R.AllRows` walkers | additive | declined (run 2026-10-31): no page needs a dim text row |
| `O.PositionBlock` | Options doc; OptionsCompose 15 | none | additive | declined (run 2026-10-31): no X and Y rows, windows move by title bar |
| `O.PageBanner{ acts }` | Options doc; OptionsTabs 13 | `settings/Panel.lua` | replaces `action` if used | declined (run 2026-10-31): no second banner act |

## Class C: whole-module adoption

| Candidate | Evidence | Decision |
|---|---|---|
| `LibKa0s-Charts-1.0` | `docs/api/Charts/version-1.1-docs.md` | declined (run 2026-10-31): outside the brief, since LibKa0s#66 and M2 step 4 require only LootHistory and DpsRace. The addon does draw charts: it keeps its private renderer (`modules/Insights_Render.lua`, `modules/InsightsWidgets.lua`), and LibKa0s#66 names it a likely consumer, so a later pass should weigh this again |
