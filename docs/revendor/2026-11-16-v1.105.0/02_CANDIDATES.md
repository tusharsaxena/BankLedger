# 02 Candidates, LibKa0s v1.93.0 -> v1.105.0

Sources: `git -C ../LibKa0s log --oneline v1.93.0..v1.105.0`; LibKa0s CHANGELOG.md, the v1.94.0 to v1.105.0 blocks and v1.105.0's *What a consumer owes*; the `docs/api/` documents of the majors 01_DELTA.md lists as moved; Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/03_ADOPTION_PLAN.md` and research notes R7 and R9 for this addon's site counts. Site counts are approximate until the adoption run re-checks them.

**Class A, delivered on the copy alone (smoke lines, not candidates)**
- The debug console, the copy window and the sim panel carry **extras · settings · close** on their title bands, the settings mark opening this addon's settings through the launcher's registry (#86). The skin picker's gear moves into its header.
- The console's status line is a 24 px Widgets footer, counter in `text.muted` (#90); Copy hands out plain text with no color codes (#79).
- Ka0s Default's rows read apart: stripe .08, hover .16, selection .26 (#84). Seven skins' `icon.hot` and Glass's and High Contrast's `icon.tint` moved (#82).
- The library's own tooltips are placed by `LibKa0s-Tooltip-1.0`: dropdown and context-menu entries and reorder handles beside their menu or window, the skin picker's toolbar tips below their control, the minimap tooltip toward the screen's center 2 px off the button (#92).
- Kit revision 57: a registered frame is held until it unregisters (#75).
- v1.94.0 to v1.104.0, carried by this sweep: Compat minor 4 members, Skin minor 18 `DefaultSkin` per client (no change on Retail), Widgets 27 `Footer` / `FOOTER` / `DockTestStrip`, OptionsWidgets 46, the Role, Callout and WaypointArrow majors (not looked up here).

**Class B, host change required: candidates owed in phase [3]** (not interviewed in this run; the tracker is the LibKa0s issue)
| Issue | Surface | What this addon would change | Blast radius |
|---|---|---|---|
| #92 | `LibKa0s-Tooltip-1.0` placers | about 12 `GameTooltip` owner sites in 4 files (modules/Browser.lua, modules/InsightsWidgets.lua, modules/LedgerTable.lua, modules/SessionWindow.lua), 4 `ANCHOR_RIGHT` and 1 `ANCHOR_NONE`, onto `PlaceBeside` / `PlaceAttached` | replaces anchors the addon owns; visible |
| #86 | `W.HeaderButtons` | the 3 title bars built through `B:MakeCloseButton` (modules/Browser.lua:992, modules/Export.lua:402, modules/SessionWindow.lua:572) move onto the strip, with a settings mark on each | replaces chrome the addon owns; visible |
| #89 | `W.Footer` 24 px | the Browser's hand-built 18 px footer (`FOOTER_H = 18`, modules/Browser.lua:1005-1046, plus `_dbFooter`) | replaces; window geometry |
| #88 | docked test/sim strip | the two undocked `W.TestStrip` sites (Browser under the filter bar, modules/Browser.lua:741; SessionWindow under its title bar, modules/SessionWindow.lua:486) take `dock = "title"`; do it with #89, one smoke per window | replaces; window geometry |
| #79 | `D:Report` / `D:Serialize` | the `session` report verb (confirm against its handler) | replaces a chat dump |
| #87 | `Sim.Sample(client)` | the addon's own sample characters, including the localized name, move onto the shared sets | replaces fixture data |

Not this addon's: #80 and #81 (Skill Master only), #85 (Callout consumers: DpsRace, DropWatcher, QuickComms, Skill Master).

**Class C, whole-module**: none new to offer. Unconsumed majors are listed in 01_DELTA.md 3e. Perf stays a settled structural decline (no combat path; docs/performance.md).

**Blockers (3g)**: none. The four contract changes 01_DELTA.md names were fixed in the re-vendor commit.
