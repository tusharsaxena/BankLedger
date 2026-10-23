Delta: LibKa0s v1.75.2 -> v1.76.0

# 01 — Delta (BankLedger)

Run: 2026-10-23, item BL-RV of the cross-repo run "sim auto-run, QC preview selector, mode strips,
MM/KCD simulators", on branch `feat/2026-10-23-sim-preview-mode-strips` (cut from `master` at
`8b93492`). Non-interactive: the run's owner scope pre-decides the icon declaration and every
adoption, so nothing is re-asked and no issue is filed.

Source: the sibling checkout `../LibKa0s`, **local annotated tag `v1.76.0` (commit `9949368`)**,
which is not pushed yet (`git -C ../LibKa0s ls-remote --tags origin v1.76.0` prints nothing). The
payloads were extracted with `git -C ../LibKa0s archive v1.76.0 LibKa0s testkit tools/prune-icons.lua
| tar -x -C <scratch>`, never from the library's working tree. `tools/prune-icons.lua` was extracted
only to run the prune and was not copied in.

## Base

`grep -n '[Bb]undles' CLAUDE.md` named **v1.75.2** at `CLAUDE.md:46`, and `CLAUDE.md:49` named kit
revision 41. The last payload commit, `git log -1 --format=%H -- libs/LibKa0s tests/_kit` =
`1db0583` ("Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)"), left the line at v1.75.2. `diff -rq` of
both payloads against `git archive v1.75.2` printed only the `Only in <scratch>/LibKa0s/media/icons`
lines of the undeclared icons, so claim and bytes agreed. **Base: v1.75.2** (commit `154599c`).

The newest single-tag bundle, `docs/revendor/2026-10-22-v1.75.0/`, states base v1.71.0, which is
what the provenance line named before its re-vendor (`7351d7c`). No base correction is needed.

**Span (3h):** v1.75.1 and v1.75.2 were vendored on 2026-10-23 (`14d2709`, `1db0583`) and left
unrecorded, so the consolidated span bundle `docs/revendor/2026-10-23-v1.75.1-v1.75.2/` is written
in this run.

`git -C ../LibKa0s log --oneline v1.75.2..v1.76.0`:

```
9949368 LK-90: address review — name tests/test_sim_panel.lua in the CLAUDE.md 1000-1500 band
82d76f6 LK-90: close v1.76.0 with its release record (20261023-150627)
f9ce82a LK-90 (1/2): release v1.76.0: version block, pointers, consumers
37e6b69 LK-25: add the preview and simulation re-look to the release checklist
d5fa6e9 LK-10: give W.TestStrip a simulation flavor (Widgets minor 14)
d728cc4 LK-01: play a simulation on its own and drop Run all (Sim 2.3.5)
05cb400 LK-00: open v1.76.0 with an unreleased CHANGELOG block
99fb662 Merge branch 'fix/2026-10-23-sim-picker-step-delay' (LibKa0s v1.75.2: SimPanel minor 4)
```

`git -C ../LibKa0s diff --stat v1.75.2 v1.76.0 -- LibKa0s testkit`: three files, 148 insertions and
53 deletions (`LibKa0s/SimPanel.lua`, `LibKa0s/SimTimeline.lua`, `LibKa0s/Widgets.lua`). The kit did
not move.

## Per-file minors (3b, 3c)

Step 3c's loop over the tag's `LibKa0s/LibKa0s.xml`; only the files whose minor moved (no file is
new, none was removed):

| File | Before (v1.75.2) | After (v1.76.0) |
|---|---|---|
| `Widgets.lua` | `LibKa0s-Widgets-1.0`, 13 | 14 |
| `SimTimeline.lua` | `TIMELINE_MINOR = 2` | 3 |
| `SimPanel.lua` | `SIM_PANEL_MINOR = 4` | 5 |

Every file is level with the tag after the copy; no cross-major skew. Version keys: Sim 2.2.4 ->
2.3.5, Widgets 13.1.4.3.2 -> 14.1.4.3.2.

## Both diffs (3d)

Against the whole copy, before the prune: `diff -r --strip-trailing-cr` and `diff -rq` of
`<scratch>/LibKa0s` vs `libs/LibKa0s` and of `<scratch>/testkit` vs `tests/_kit` all printed
nothing. After the prune, `diff -rq <scratch>/LibKa0s libs/LibKa0s` prints only
`Only in <scratch>/LibKa0s/media/icons…` lines (the undeclared icons). No `Only in libs/LibKa0s`
line, so no file was deleted against the diffs.

## Consumption (3e)

Unchanged from v1.75.0: the addon looks up Bus, Core, DebugLog, Env, Item, Launcher, Lifecycle,
Media, Options, Pool, Schema, Sim, Slash and Widgets (`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0",
true\)'` outside `libs/` and `tests/`). Of the moved majors it consumes both: Sim (`core/SimSetup.lua:32`,
`modules/Sim.lua:378`) and Widgets (`modules/Browser.lua:5`, `modules/Export.lua:14`,
`modules/SessionWindow.lua:482`).

## Kit revision (3f)

`Kit.VERSION = 41` in both `<scratch>/testkit/framework.lua:20` and `tests/_kit/framework.lua:20`.
The pairing rule (v1.9.0+ takes kit 11 or newer in the same commit) holds by construction: both
payloads are copied whole together.

## Contract delta (3g)

Read for the two moved majors this addon consumes, from `docs/api/Sim/version-2.3.5-docs.md` and
`docs/api/Widgets/version-14.1.4.3.2-docs.md` at the tag against their predecessors (2.2.4,
13.1.4.3.2). `grep -rn '__Attach'` outside `libs/` and `_kit/` finds no host attach site.

- **Sim 2.3.5 (SimTimeline 3, SimPanel 5): a simulation plays on its own.** A typed `/bl sim start`,
  the picker's START, the idle Start row, a typed `restart` and RESTART now arm the run; Run all and
  `Sim.STRINGS.RUN_ALL` are gone; the controls are Pause/Resume, Restart and Stop. `sim:Start{}` and
  `sim:Restart()` (the members) arm nothing, and no member, descriptor field or option moved;
  `stepDelay` keeps its meaning (the pause after a step), so BankLedger's descriptor
  (`modules/Sim.lua:392`, `Host.DelayAfter`) still holds. BankLedger names no `RUN_ALL` string and
  its suites start sessions through the member, so the gate stays green on the copy. What goes
  stale is wording: the `settings.sim.stepDelay` tooltip (`settings/Schema.lua:124`, player
  visible) and the comments at `settings/Schema.lua:114-115`, `core/Constants.lua:171` and
  `defaults/Profile.lua:68` still say "Run all". **Not a blocker in this commit:** the run's item
  BL-01 (same branch, depends on BL-RV) owns that fallout and its typed-start suite cases, and the
  item spec allows leaving it there while the gate stays green.
- **Widgets 14: `W.TestStrip` gains `opts.kind` and `strip.kind`.** Additive: no member added,
  every existing call unchanged, and a call with no `kind` still draws the amber test strip. Both
  BankLedger strips (`modules/Browser.lua:1072`, `modules/SessionWindow.lua:484`) pass no `kind`,
  so they draw exactly as before. A candidate, not a blocker (BL-10).

**Blockers:** none.

## Icon declaration (3i)

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `CLAUDE.md:47`, the next non-blank line after the provenance
line: `chevron-down, chevron-right, clear, close, confirm, copy, export, info, search, sort-down,
sort-up`. Kept as decided at v1.75.0 (`docs/revendor/2026-10-22-v1.75.0/01_DELTA.md`); this range
adds no library-drawn icon. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`,
WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop, since a
pruned icon still resolves to a path and draws blank.

## Tests that assume the whole icon folder (3j)

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds
`tests/test_libka0s.lua:729` (`info.tga`, declared) and `tests/test_mediasetup.lua:154,165`, which
already walk the declaration (fixed at v1.75.0). Nothing new.

## Dead stub mirrors

`grep -rn '__releaseChrome'` outside `libs/` and `_kit/` finds only the history comment at
`settings/OptionsSetup.lua:188`. Nothing to remove.
