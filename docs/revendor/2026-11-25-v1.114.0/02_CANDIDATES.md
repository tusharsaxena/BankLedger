# 02 Candidates, LibKa0s v1.113.0 -> v1.114.0

Sources: `git -C ../LibKa0s log --oneline v1.113.0..v1.114.0`; LibKa0s CHANGELOG.md, the v1.114.0 block; `docs/api/ForeverDB/version-1-docs.md`; `docs/api/DebugLog/version-23.12.1.5-docs.md`; `docs/api/testkit/version-61-docs.md` and `version-62-docs.md`.

**Class A, delivered on the copy alone**
- DebugLogDiagnostics minor 12: the diagnostics report names ForeverDB and prints its status line, read without loading it (`version-23.12.1.5-docs.md`, *What changed at this version*).
- Kit revisions 61 and 62: the ForeverDB fake and the regenerated Forever name set. Both profiles stay green on the copy.

**Class B, host change required**
- `LibKa0s-ForeverDB-1.0` (`version-1-docs.md`, *Lib-level surface*): eleven functions reading the optional ForeverDB data addon on WoW Forever. This addon's use is `VendorPrice(itemID)`, the lowest price a vendor was seen asking, beside the client's own sell price in the ledger rows' item tooltip. Blast radius: **adds** (no host code replaced). adopt: SF-BL-01's feature commits.
- The other ten members (`NPC`, `Item`, `Quest`, `ItemSources`, `Spots`, `TrainerSpells`, `Meta` and the status reads): no feature in this addon asks for them. Not candidates.

**Class C, whole-module**: none new.

**Other new surfaces**: none. The release adds no member to any major this addon consumes.

**Blockers (3g)**: none.
