# 03 Decisions

No interview. The run's items for this addon are pre-decided in Ka0sAddonsCommonTasks `docs/2026-11-22-LIBKA0S_101_CONTAINER_READER/` (`plan-data/items.tsv`): K101-BL-01 (this re-vendor) and K101-BL-02 (the adoption).

| Candidate | Decision | Source |
|---|---|---|
| `ContainerGroups()`, `CONTAINER_PATTERNS_BY_CLIENT` | adopt: K101-BL-02 | items.tsv K101-BL-02; 00_PLAN.md call 8 |
| `CanViewCharacterBank()`, `NumPurchasedBankTabs()`, `BankerKind()` | adopt: K101-BL-02 | items.tsv K101-BL-02; 00_PLAN.md calls 3 and 8 |
| `UnreadyBankContainers()` | adopt: K101-BL-02 | items.tsv K101-BL-02; 00_PLAN.md calls 4 and 8 |

No other candidate is in this range, so nothing is deferred. No GitHub issue was filed (the run files none).
