# Decisions (BankLedger)

Source: the workflow dispatch that launched this re-vendor, not the bundle. "The brief" in this
bundle means that dispatch. Step 7 of Ka0sAddonsCommonTasks
`docs/2026-10-31-FINDINGS_REMEDIATION/M2_LIBRARY_RELEASE.md` orders the re-vendor, gates, review,
recorded runs and push, and says only "Close no issue before merge"; it is silent on interviews and
declines. Step 4 names the Charts adopters: LootHistory and DpsRace. No named adoption here. Every
candidate in `02_CANDIDATES.md` is declined for this run. The bundle holds no owner ruling on these
declines and no GitHub issue was filed, so none is tracked outside this folder. That includes
`LibKa0s-Charts-1.0`, which this addon, with its private Insights renderer, could still adopt.

LibKa0s#67, checked: `settings/Schema.lua` and `settings/Panel.lua` carry no `disabledIf` and no
`shownWhen`. The three dropdowns (Minimum quality, Keep history for, Visibility) and the Banks to
record checks each set a value and pick no group of rows. The Filters sub-strip is tabs. None.

LibKa0s#68: the addon has no `DragHandle` and is not in the issue's host table (`grep -rn DragHandle
core modules settings`: no hit). Its windows drag by title bar. Not applicable.
