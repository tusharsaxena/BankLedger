# 02 — Candidates: what v1.31.0 brought, and what this addon should do with it

Sources, in order: `git -C ../LibKa0s log --oneline v1.30.0..v1.31.0`; the tag's `CHANGELOG.md`
`## v1.31.0` block; `docs/api/Options/version-15.15.4.3-docs.md` and
`docs/api/testkit/version-17-docs.md` at the tag.

## Class A — reached this addon on the re-vendor alone (delivered, not offered)

| What | Evidence | Why it needs nothing here |
|---|---|---|
| `OptionsWidgets.lua` minor 15: a row with no `path` reads and writes through its own `get` / `set` | `CHANGELOG.md` v1.31.0, "`OptionsWidgets.lua` minor 15" | The gate is `path == nil`. Every one of this addon's fifteen rows carries a `path`, so every maker reads and writes through the descriptor exactly as at minor 14. |
| `OptionsCompose.lua` minor 4: `spec.bind`, the record-backed composer arm | `CHANGELOG.md` v1.31.0, "`OptionsCompose.lua` minor 4"; `tests/fixture_compose_golden.lua` upstream | Path-keyed callers are pinned byte-for-byte against minor 3's output. This addon calls no composer with `bind`, and it edits no registry records through a panel. |
| Kit revision 17 as a whole | `version-17-docs.md` → "For consumers: nothing moves" | Measured upstream at 850 → 850 for this repo. It reaches a harness only once the harness stops replacing the kit's fakes, which is the class-B row below. |

## Class B — host change required (candidates)

| # | Candidate | Evidence | Files it touches | Recommendation | Blast radius |
|---|---|---|---|---|---|
| B1 | Migrate `tests/wow_mock.lua` onto the kit's `AceEvent:Embed` and message bus (#18) | `version-17-docs.md` → "AceEvent: two CallbackHandler registries"; "For the six migrations" → BankLedger | `tests/wow_mock.lua`, one new case | **Adopt.** The owner already decided it (brief §3, harness declines → migrate onto the kit). | **Replaces** harness code the addon owned (`embedBus`, the local Embed). No production code. |
| B2 | Migrate `tests/wow_mock.lua` onto the kit's `NewAddon`, AceTimer and AceConsole (#19) | `version-17-docs.md` → "AceAddon: `NewAddon` honors its mixin list", "AceTimer, on the kit's one queue", "AceConsole"; the BankLedger paragraph, including the `reEnable` port | `tests/wow_mock.lua`, `tests/test_ledger.lua` (`reEnable`), one new case, `docs/testing.md` | **Adopt.** Owner-decided, as B1. | **Replaces** the local `NewAddon`, timer queue and `__badEvents`. Four `reEnable` cases move by construction (first-registrant rule), and the doc names that port. |

Nothing else in the release asks a host change of this addon. The `spec.bind` arm is for a page that
edits registry records, and this addon has no such page: its only structural registry is the filter
id-sets, which the Filters tab edits through `NS.Filters`, not through a composer.

## Class C — whole-module adoption

| Major | Status |
|---|---|
| Perf | **Settled decline**, not re-offered. The `performance-§12` row in `docs/ARCHITECTURE.md` → Documented deviations records it: the capture engine never runs in combat, so every bucket would read `0.000` by construction. v1.31.0 does not touch `Perf.lua` (minor 10 → 10) or `PerfPanel.lua` (5 → 5), so no premise moved. |

Every other major in the payload already has a lookup site (`01_DELTA.md` §3e).
