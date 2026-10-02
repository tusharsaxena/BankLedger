# Decisions (BankLedger)

This run was non-interactive. The owner delegated every decision for plan
`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/` (item TP-BL-01): decide, and record the
reasoning. That plan names BankLedger among the seven addons that get a re-vendor only, because they
have no drag strip, and says a declined candidate is filed as an issue only when the reason is a
real gap.

| Candidate | Decision | Reasoning | Issue |
|---|---|---|---|
| WidgetsDragHandle 4 `tooltipPlace` / descriptor `place` | **declined: not applicable** | BankLedger builds no `lib.DragHandle` strip, so the hook has nothing to place. This is not a gap in the addon or the library, so no issue is filed. Should a strip ever be added, its tooltip placement is decided then. | none (not a gap) |

Adopted: none, so there is no `04_EXECUTION_PLAN.md`.
