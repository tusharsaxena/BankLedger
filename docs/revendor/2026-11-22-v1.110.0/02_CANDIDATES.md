# 02 Candidates, LibKa0s v1.109.0 -> v1.110.0

Sources: `git -C ../LibKa0s log --oneline v1.109.0..v1.110.0`; LibKa0s CHANGELOG.md, the v1.110.0 block, and `docs/releasing.md`'s v1.110.0 *What a consumer owes*; `docs/api/Compat/version-6-docs.md` (the six new members, under *The container groups and the bank (minor 6)*, line 170 onward) diffed against `version-5-docs.md`.

**Class A, delivered on the copy alone**
- Test kit revision 60: the Retail and Forever profiles carry `Enum.BagIndex`, `Enum.BankType` and `C_Bank.CanViewBank` where the host's mock set and `_G` have none (CHANGELOG v1.110.0, *The test kit's client profiles carry the bank shape*). This addon's `tests/wow_mock.lua` builds its own, so nothing it asserts moves; both profiles stay green on the copy.
- Compat minor 6 keeps its seventeen members and their behavior exactly (`version-5-docs.md`, *Moving to version 6*), so this addon's `core/CompatClient.lua` seam reads the same.

**Class B, host change required** (LibKa0s#101's surfaces)
- `ContainerGroups()` and `CONTAINER_PATTERNS_BY_CLIENT` (version-6-docs.md, `### ContainerGroups() and the pattern table`, line 183): the per-client bag, bank and account-bank id groups. Replaces this addon's own container groups (`core/Compat.lua`, `core/Constants.lua`). Blast radius: **replaces** host-owned code. adopt: K101-BL-02.
- `CanViewCharacterBank()`, `NumPurchasedBankTabs(bankTypeName)`, `BankerKind(interactionType)` (version-6-docs.md, `### The bank readers`, line 227): the bank reads, BankLedger's rule for a nil `C_Bank.CanViewBank` answer. Replaces host reads in `core/Compat.lua`, `modules/Ledger.lua`. Blast radius: **replaces**. adopt: K101-BL-02.
- `UnreadyBankContainers(shape, memory, purchased)` (version-6-docs.md, `### The readiness helper`, line 250): the pure readiness check; the deadline (6 s) and the memory stay in this addon (lead's call 4). Replaces the readiness diff in `modules/Ledger.lua`. Blast radius: **replaces**. adopt: K101-BL-02.

No other host-change candidate is in this range: the release moved only `Compat.lua` and the kit.

**Class C, whole-module**: none new. Perf stays a settled structural decline (no combat path; `docs/performance.md`).

**Blockers (3g)**: none.
