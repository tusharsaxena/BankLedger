# Decisions (BankLedger)

Source: the run's brief for this repo (Ka0sAddonsCommonTasks
`docs/2026-10-31-FINDINGS_REMEDIATION/M2_LIBRARY_RELEASE.md`, step 7). No named adoption. Every
candidate in `02_CANDIDATES.md` is declined for this run; the brief files no GitHub issue and holds
no interview.

LibKa0s#67, checked: `settings/Schema.lua` and `settings/Panel.lua` carry no `disabledIf` and no
`shownWhen`. The three dropdowns (Minimum quality, Keep history for, Visibility) and the Banks to
record checks each set a value and pick no group of rows. The Filters sub-strip is tabs. None.

LibKa0s#68: the addon has no `DragHandle` and is not in the issue's host table (`grep -rn DragHandle
core modules settings`: no hit). Its windows drag by title bar. Not applicable.
