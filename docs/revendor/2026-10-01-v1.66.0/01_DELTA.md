Delta: LibKa0s v1.65.0 -> v1.66.0

# LibKa0s v1.65.0 -> v1.66.0: the delta (BankLedger)

Copied from the tag `v1.66.0` (annotated, local, object `178ee0b` on commit `e4c5ef7`), never from a
working tree: `git -C ../LibKa0s archive v1.66.0 LibKa0s testkit | tar -x -C <scratch>`. Plan item
GI-BL-RV of `Ka0sAddonsCommonTasks/docs/2026-10-01-GITHUB_ISSUE_PASS/` (spec S4), on branch
`feat/2026-10-01-github-issue-pass`.

## Base

`CLAUDE.md` named v1.65.0, and the payload before the copy matched that tag
(`diff -rq` of `v1.65.0`'s `LibKa0s/` and `testkit/` against `libs/LibKa0s` and `tests/_kit`: empty,
`payload-matches`). The last re-vendor commit is `477c782` (DG-BL-01), whose line names v1.65.0.

Two tags this addon vendored had no bundle: v1.64.0 (`2a3f637`, `99c348c`) and v1.65.0 (`477c782`).
The 3h listing printed exactly those two, so one consolidated span bundle is written beside this one,
`docs/revendor/2026-10-01-v1.64.0-v1.65.0/`. The newest single-tag bundle before this run,
`2026-09-29-v1.63.0`, states base v1.62.0, which is what the history shows: no base correction.

```
git -C ../LibKa0s log --oneline v1.65.0..v1.66.0
e4c5ef7 GI-LK-12: v1.66.0 release record (docs/automated-tests/20261001-133255/), its ANALYSIS.md, the release-gate line and DEPENDENCIES.md's verified-with pointer
a964c5a GI-LK-12: v1.66.0 built to standard v2.74.0; the CHANGELOG block carries the addendum's peels in what a consumer owes
c2836b1 GI-LK-10R: the runner passes lizard -L 1500, so the length threshold is the layout-§1 file cap (addendum A1)
d37d16b GI-LK-03R: peel the Slash parser to LibKa0s/SlashParse.lua, SlashParse minor 1, Slash.lua 1030 -> 877, out of the band (addendum A2)
c83ecd7 GI-LK-07R: peel the Perf capture to LibKa0s/PerfSampler.lua, PerfSampler minor 1, Perf.lua 1307 -> 975, out of the band (#7, addendum A2)
996c5c4 GI-LK-12: v1.66.0 release run refused on two length-only lizard warnings (docs/automated-tests/20261001-122702/), no tag
b68583a GI-LK-12: v1.66.0 release docs: CHANGELOG block with what a consumer owes, README MODULES and standards pointer (v2.73.0), releasing.md step-7 lines, consumers notes and the Options document's shipped-in
bc9d2d4 GI-LK-11R: Perf's resolveHooks comment sits back above noop, printLine and resolveHooks
4a9969b GI-LK-10R: the shadow renames `unless` after `.` too, and the header and doc say what S.renamed does
738f892 GI-LK-11: bring every function the sighted complexity gate reveals to CCN 15 or under, behavior unchanged (DebugLog minor 19)
c9bfcc0 GI-LK-11: characterization tests for the functions the sighted complexity gate reveals above CCN 15
a1e797a GI-LK-10: kit revision 35, the complexity suite measures a sighted shadow with function-count parity (WowAddonStandards#6, LibKa0s#17-20)
39f9204 GI-LK-07R: compat register cites P.Context's spec read by function, RESULTS.md band row for Perf.lua at 1292 after the #7 peel
975ca50 GI-LK-09: Perf report-only per-bucket budgets (msPerSec, maxMs) in descriptor, record and report (#1)
e907508 GI-LK-08: Perf BuildRecord emits every declared ancestor of a recorded bucket, zero counts if it never fired (#12)
a904e6a GI-LK-07: peel the Perf command surface to LibKa0s/PerfCommands.lua, Perf minor 14 + PerfCommands minor 1, resolveHooks at file level (#7)
63c19c3 GI-LK-06: OptionsTabs minor 8, RenderTabbedSchema's opt-in untabbedSkipRender, disabledReplaces (+ disabledNoticeFont) and rerender (AbsorbTracker#32)
0cc0d6e GI-LK-05: OptionsWidgets minor 34, RenderGrid(ctx, items, parent, opts) with opts.gap and the failed-item guard (KickCD#10)
8bf5c1f GI-LK-04: peel ReorderList to LibKa0s/WidgetsReorder.lua, Widgets minor 12 + WidgetsReorder minor 1 (#36)
bf4e00d GI-LK-03: Slash minor 19, the host's L reaches every parse refusal and the empty-string (none) (#40)
b06f0bb GI-LK-02: split tests/test_schema.lua by pipeline stage, the write stage onward to tests/test_schema_write.lua (#38)
cc7190d GI-LK-01: peel tests/test_options.lua's page registry and refresh tiers to tests/test_options_render.lua (#35)
512d2c8 Merge feat/2026-09-30-libka0s-debug-gaps: v1.65.0 — DebugLogGates (log-once / log-on-change gates and the at-enable queue), gated debug sinks on Slash, Lifecycle, Launcher and the Options combat lock, no duplicate edge lines
602ebad DG-LIB-01R: DEPENDENCIES.md's verified-with evidence points at the v1.65.0 release run (docs/automated-tests/20261001-001312/), the newest recorded run
```

## Per-file minors (old -> new; every file not listed is unchanged)

| File | Old | New |
|---|---|---|
| `Widgets.lua` | 11 | 12 |
| `WidgetsReorder.lua` | (new) | `REORDER_MINOR` 1 |
| `DebugLog.lua` | 18 | 19 |
| `Slash.lua` | 18 | 19 |
| `SlashParse.lua` | (new) | `PARSE_MINOR` 1 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` 33 | 34 |
| `OptionsTabs.lua` | `TABS_MINOR` 7 | 8 |
| `Perf.lua` | 13 | 14 |
| `PerfSampler.lua` | (new) | `SAMPLER_MINOR` 1 |
| `PerfCommands.lua` | (new) | `COMMANDS_MINOR` 1 |

No consumer file was behind before the copy (no cross-major skew). The four new files are loaded by
`LibKa0s.xml`; this addon's TOC loads the library through `libs\LibKa0s\LibKa0s.xml` and
`tests/run.lua` derives its list from the same XML (`Loader.xmlFiles`), so neither needs a new line.

## Diffs before the copy (`diff -rq --strip-trailing-cr` against the tag)

libs/LibKa0s: `DebugLog.lua`, `LibKa0s.xml`, `OptionsTabs.lua`, `OptionsWidgets.lua`, `Perf.lua`,
`Slash.lua`, `Widgets.lua` differ; only in the tag: `PerfCommands.lua`, `PerfSampler.lua`,
`SlashParse.lua`, `WidgetsReorder.lua`.

tests/_kit: `README.md`, `asserts.lua`, `framework.lua`, `inventory.lua`, `mock_base.lua`,
`run-automated-tests.sh`, `test_eol.lua` differ; only in the tag: `lizard_sighted.lua`,
`test_lizard_sighted.lua`.

Nothing was only in the addon, so nothing was deleted. After the copy, `diff -r` (bytes, not just
content) of both payloads against the tag is empty.

## Kit revision

`Kit.VERSION` 34 -> 35. Both payloads move together, as always.

## Consumption map (3e)

Host lookups: Core, Env, Item, Media, DebugLog, Lifecycle, Pool, Launcher, Bus, Schema, Slash,
Options, Widgets (`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and
`tests/`). Perf is not consumed (the ratified `performance-§12` no-combat-path exemption).

## Contract delta (3g) — no blocker

Read for the majors that moved and that this addon consumes: Slash, DebugLog, Options (Widgets,
Tabs), Widgets.

- **Slash 19**: `ParseValue` / `FormatValue` take an optional third argument, and a host `parse`
  receives the resolver as its third. `settings/Slash.lua:443` declares `parse = function(row, text)`
  and calls `lib.ParseValue(row, text)` — two arguments, which the CHANGELOG states answers as
  before. Not a blocker; threading the resolver through is a candidate (`02_CANDIDATES.md`).
- **DebugLog 19**: `lib:New`'s hook resolution hoisted to file level (GI-LK-11), defaults unchanged.
- **OptionsWidgets 34**: `RenderGrid(ctx, items)` unchanged for a two-argument call; this addon
  calls it only through the degradation stub (`settings/OptionsSetup.lua:178`).
- **OptionsTabs 8**: three opt-in fields, all off by default; the CHANGELOG names this addon's
  all-`skipRender` Filters group as drawing what it drew.
- **Widgets 12 / WidgetsReorder 1**: `ReorderList` moved file; this addon draws no reorderable list.

The headless suite stayed green on the copy alone (1178 -> 1186 passed, the eight new cases being
the kit's `test_lizard_sighted`), so no host fix rides the re-vendor commit.
