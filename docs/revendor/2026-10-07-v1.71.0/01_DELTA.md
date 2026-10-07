Delta: LibKa0s v1.70.0 -> v1.71.0

# 01 — Delta (BankLedger)

Run: 2026-10-07, item RV-BL of the 2026-10-07 review-and-standards-audit remediation, on branch
`feat/2026-10-07-review-audit-remediation`. Mechanical and non-interactive (the remediation's owner
scope, ruling 5: no interview, no issue filing).

Source: the sibling checkout `../LibKa0s`, **local tag `v1.71.0` (tag object `3bf1b97` -> commit
`cb274a4`, LK-12's release record)**. The payloads were extracted with
`git -C ../LibKa0s archive v1.71.0 LibKa0s testkit | tar -x -C <scratch>/new`, never from the
library's working tree, and copied whole over `libs/LibKa0s/` and `tests/_kit/`.

## Base

`CLAUDE.md:46` named **v1.70.0** and `CLAUDE.md:48` kit revision 37 before this run. The last payload
commit, `2c87997`, left them so. `diff -rq` of both payloads against `git archive v1.70.0` printed
nothing: claim and bytes agreed. **Base: v1.70.0.**

## Per-file minors

`git -C ../LibKa0s diff --stat v1.70.0 v1.71.0 -- LibKa0s testkit`: 10 files, 369 insertions, 140
deletions.

| File | Before | After | Major key after |
|---|---|---|---|
| `Env.lua` | 1 | **2** | Env 2 |
| `Slash.lua` | 19 | **20** | Slash 20.2 |
| `SlashParse.lua` | 1 | **2** | |
| `WidgetsLineChart.lua` | 2 | **3** | Widgets 12.1.4.3.2 |
| `WidgetsAutocomplete.lua` | 1 | **2** | |
| `OptionsIdList.lua` | 3 | **4** | Options 28.2.34.2.4.8.1.7.4.2 |

Every other file keeps its v1.70.0 minor (Core 10, Compat 1, Lifecycle 3, Bus 2, Schema 2, Pool 3,
Item 2, Media 4, Widgets 12, WidgetsReorder 1, WidgetsDragHandle 4, DebugLog key 19.2.1, Launcher 5,
the rest of Options, Perf key 14.1.1.6). No file or major is added or removed and no `NEEDS_*` floor
rises (CHANGELOG v1.71.0 at the tag).

## Kit revision

`Kit.VERSION` **37 -> 38**. Four kit files change: `framework.lua` (the version, the `--list`
renderer moved out, `secrets.lua` loaded), `inventory.lua` (the renderer, whose `## Totals` now count
only the cases that run, with a `| Skipped | N |` row), `README.md`, and the new `secrets.lua`. The
pairing rule is satisfied by construction: both payloads were copied whole in one commit.
`tests/_kit/run-automated-tests.sh` keeps mode `100755`.

## Consumption map

Outside `libs/` and `tests/`, this addon looks up thirteen majors: DebugLog, Media, Env, Launcher,
Bus, Pool, Item, Lifecycle, Core, Widgets (`modules/Browser.lua:5`, `modules/Export.lua:14`), Slash
(`settings/Slash.lua:226`), Options (`settings/OptionsSetup.lua:26`) and Schema. Perf and Compat are
not looked up. Moved and consumed: Env, Slash, Widgets, Options.

## Contract check

- **Autocomplete minor 2** (LK-04): the host must set the box's scripts before calling
  `lib.Autocomplete`, because a later `SetScript` on a hooked script drops the hooks. Satisfied:
  `modules/Browser.lua:1093-1100` sets `OnTextChanged`, `OnEscapePressed` and `OnEnterPressed`, and
  `:1105` then calls `self:MakeAutocomplete(search, ...)` (the seam at `:309`, which calls
  `W.Autocomplete`). No later `SetScript` on the search box exists in the addon. No code change.
- **WidgetsLineChart minor 3** (LK-03, `ChartMath.ClipSegment`, hover re-sync): BankLedger draws no
  line chart. Not a consumer change.
- **SlashParse minor 2** (`nan`/`inf` refused on a number row): owned by the library's
  `ParseValue`; this addon has no number-parsing path of its own. Not a consumer change.
- **Env minor 2** (no bare `GetAddOnMetadata` rung): the library side. The addon's own
  library-absent fallback in `core/EnvSetup.lua` (`NS.Meta`) is item BL-05 of the same plan, not
  this re-vendor.
- **OptionsIdList minor 4**: this addon builds no id-list row. Not a consumer change.

**No blockers.**

## Test inventory

`docs/test-cases.md` is regenerated in the same commit (CRLF). Kit 38 moves the diagnostics
contract's declared opt-out skip out of the `test_diagnostics_contract.lua` row (9 -> 8) onto a
`| Skipped | 1 |` row, and `| **Total** |` falls from 1259 to **1258**, which equals the README
badge (1258/1258). This closes `BL-A-03` with no local framework edit.
