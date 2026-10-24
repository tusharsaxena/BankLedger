Delta: LibKa0s v1.76.0 -> v1.77.0

# 01 — Delta (BankLedger)

Run: 2026-10-24, item BL-RV of the cross-repo run "keybindings (015), settings layout (020), frame
strata (030)", on branch `feat/2026-10-24-keybinds-layout-strata` (cut from `master` at `4c665cf`).
Non-interactive: the run's item spec pre-decides the icon declaration and the adoptions (BL-KB and
BL-ZS on this branch), so nothing is re-asked and no issue is filed.

Source: the sibling checkout `../LibKa0s`, **local annotated tag `v1.77.0` (commit `78240f7`)**,
which is not pushed yet (`git -C ../LibKa0s ls-remote --tags origin v1.77.0` prints nothing). The
payloads were extracted with `git -C ../LibKa0s archive v1.77.0 LibKa0s testkit tools | tar -x -C
<scratch>`, never from the library's working tree. `tools/` was extracted only to run
`prune-icons.lua` and was not copied in.

## Base (3a, Step 0)

`grep -n '[Bb]undles' CLAUDE.md` named **v1.76.0** at `CLAUDE.md:46`, and `CLAUDE.md:49` named kit
revision 41. The last payload commit, `git log -1 --format=%H -- libs/LibKa0s tests/_kit` =
`58c34f9` ("BL-RV2: Refresh vendored LibKa0s from the moved v1.76.0 tag (LK-91)"), left the line at
v1.76.0. `diff -rq` of both payloads against `git archive v1.76.0` printed only the
`Only in <scratch>/LibKa0s/media/icons` lines of the undeclared icons (`payload-matches`), so claim
and bytes agreed. **Base: v1.76.0** (commit `e692491`).

The newest single-tag bundle, `docs/revendor/2026-10-23-v1.76.0/`, states base v1.75.2, which is
what the provenance line named before its re-vendor. No base correction is needed.

**Span (3h):** the audit's walk (payload commits plus provenance rolls since the store's first
bundle) against the recorded bundles prints nothing. No span bundle is written.

`git -C ../LibKa0s log --oneline v1.76.0..v1.77.0`:

```
78240f7 LK-90: close v1.77.0 with its release record (20261024-074358)
3c2bb20 LK-90: split three functions over CCN 15 that the release run found
ea2cb09 LK-90: close v1.77.0: version block, pointers, consumers, band
0a5807d LK-13: Sync the Keybindings tab with Options -> Keybindings
9ab9d37 LK-12: Add the Keybindings tab, OptionsKeybinds minor 2
0b10ad3 LK-11: address review — refuse BUTTON1/BUTTON2 on the client chord route
88dfa8a LK-11: Add OptionsKeybinds.lua minor 1, the key binding model
66b7bd4 LK-20: Add O.StrataTooltip, the one shared strata-row tooltip
7de587b LK-04: Close the IdList suggestion list at the start of combat
f452d69 LK-03: Clamp the dropdown menu and the autocomplete list to the screen
dda3ff9 LK-02: Add DragHandle level offset, ApplyLevel and ignoreParentAlpha
665bf63 LK-01: Make the tool windows toplevel and re-raise shown StaticPopups
8173cdb LK-10: Kit revision 42: binding mock, layer recorder, Bindings.xml check
0a1683a LK-00: Open v1.77.0 with an unreleased CHANGELOG section
9df6df8 Merge branch 'feat/2026-10-23-sim-preview-mode-strips'
```

`git -C ../LibKa0s diff --shortstat v1.76.0 v1.77.0 -- LibKa0s testkit`: 18 files changed, 1672
insertions, 34 deletions. New files: `LibKa0s/OptionsKeybinds.lua`, `testkit/bindings_xml.lua`,
`testkit/mock_bindings.lua`, `testkit/mock_layers.lua`.

## Per-file minors (3b, 3c)

Step 3c's loop over the tag's `LibKa0s/LibKa0s.xml`; only the files whose minor moved (one file is
new, none was removed):

| File | Before (v1.76.0) | After (v1.77.0) |
|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0`, 11 | 12 |
| `DebugLog.lua` | `LibKa0s-DebugLog-1.0`, 20 | 21 |
| `PerfPanel.lua` | `PANEL_MINOR = 8` | 9 |
| `SimPanel.lua` | `SIM_PANEL_MINOR = 5` | 6 |
| `Widgets.lua` | `LibKa0s-Widgets-1.0`, 14 | 15 |
| `WidgetsDragHandle.lua` | `DRAG_MINOR = 4` | 5 |
| `WidgetsAutocomplete.lua` | `AUTOCOMPLETE_MINOR = 2` | 3 |
| `Options.lua` | `LibKa0s-Options-1.0`, 29 | 30 |
| `OptionsIds.lua` | `IDS_MINOR = 2` | 3 |
| `OptionsCombat.lua` | `COMBAT_MINOR = 1` | 2 |
| `OptionsCompose.lua` | `COMPOSE_MINOR = 7` | 8 |
| `OptionsKeybinds.lua` | (new) | `KEYBINDS_MINOR = 3` |

Every file is level with the tag after the copy; no cross-major skew. Version keys: Core 12,
DebugLog 21.3.1, Perf 15.1.1.9, Sim 2.3.6, Widgets 15.1.5.3.3, Options 30.2.34.3.5.9.2.8.4.2.1.3.

## Both diffs (3d)

Against the whole copy, before the prune: `diff -r --strip-trailing-cr` and `diff -rq` of
`<scratch>/LibKa0s` vs `libs/LibKa0s` and of `<scratch>/testkit` vs `tests/_kit` all printed
nothing. After the prune, `diff -rq <scratch>/LibKa0s libs/LibKa0s` prints only
`Only in <scratch>/LibKa0s/media/icons…` lines (the undeclared icons). No `Only in libs/LibKa0s`
line, so no file was deleted against the diffs.

## Consumption (3e)

Unchanged from v1.76.0: the addon looks up Bus, Core, DebugLog, Env, Item, Launcher, Lifecycle,
Media, Options, Pool, Schema, Sim, Slash and Widgets (`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0",
true\)'` outside `libs/` and `tests/`). Of the moved majors it consumes Core, DebugLog, Options, Sim
and Widgets; Perf (PerfPanel 9) is not consumed (BankLedger's ratified `performance-§12`
no-combat-path exemption).

## Kit revision (3f)

`Kit.VERSION = 42` in `<scratch>/testkit/framework.lua:20`; it was 41 in `tests/_kit/framework.lua:20`
before the copy and is 42 after. The pairing rule (v1.9.0+ takes kit 11 or newer in the same commit)
holds by construction: both payloads are copied whole together. `CLAUDE.md:49` rolls to revision 42
in the same commit.

## Contract delta (3g)

Read for the moved majors this addon consumes, from the tag's API documents against their
predecessors. `grep -rn '__Attach'` outside `libs/` and `_kit/` finds no host attach site.

- **Options 30.2.34.3.5.9.2.8.4.2.1.3: the degradation stub owes four instance members.**
  `docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md:61-63` (`O.KeybindingsTab`,
  `O.KeybindRows`, `O.KEYBINDS_UNCHANGED`) and `:86` (`O.StrataTooltip`); the CHANGELOG v1.77.0
  block's *What a consumer owes* says `Kit.assertSurfaceParity` is red at the re-vendor until the
  stub answers them. Measured: after the copy, `lua tests/run.lua` failed exactly one case,
  "LibKa0s-Options degraded: the stub carries the live surface the addon reaches"
  (`tests/_kit/asserts.lua:330`: "KEYBINDS_UNCHANGED is missing (live: string); KeybindRows is
  missing (live: function); KeybindingsTab is missing (live: function); StrataTooltip is missing
  (live: function)"). **A blocker, fixed in this commit**: `settings/OptionsSetup.lua:246-254` adds
  the four members as no-ops (`KeybindingsTab` and `KeybindRows` answer nil, the two strings are
  empty rather than the library's words, anti-pattern #47).
- **OptionsIds 3 / OptionsCombat 2: an id box's suggestion list closes at combat start.** Internal
  `__` members only; BankLedger's Filters tab draws two `O.IdList`s (`settings/Panel.lua`), which
  take the close on the copy. Not a blocker; class A.
- **Core 12 (`RaiseStaticPopups`), DebugLog 21, Sim 2.3.6:** additive member and toplevel tool
  windows (`docs/api/Core/version-12-docs.md:24`, `docs/api/DebugLog/version-21.3.1-docs.md:52`,
  `docs/api/Sim/version-2.3.6-docs.md:22`). No member a host supplies moved. Class A.
- **Widgets 15.1.5.3.3:** dropdown menu and autocomplete list clamped to screen (class A); the
  DragHandle `spec.level`, `spec.ignoreParentAlpha` and `handle:ApplyLevel()` are opt-in
  (`docs/api/Widgets/version-15.1.5.3.3-docs.md:39-49`). BankLedger builds no DragHandle.

**Blockers:** one, the Options stub parity above, fixed in this commit.

## Icon declaration (3i)

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `CLAUDE.md:47`, the next non-blank line after the provenance
line: `chevron-down, chevron-right, clear, close, confirm, copy, export, info, search, sort-down,
sort-up`. Kept as decided at v1.75.0 (`docs/revendor/2026-10-22-v1.75.0/01_DELTA.md`); this range
adds no library-drawn icon (the CHANGELOG v1.77.0 *What a consumer owes* names none). Hand lists
have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`);
the owner's in-client smoke is the backstop, since a pruned icon still resolves to a path and draws
blank.

## Tests that assume the whole icon folder (3j)

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds
`tests/test_libka0s.lua:729` (`info.tga`, declared) and `tests/test_mediasetup.lua:154,165`, which
already walk the declaration (fixed at v1.75.0). Nothing new.

## Dead stub mirrors

`grep -rn '__releaseChrome'` outside `libs/` and `_kit/` finds only the history comment at
`settings/OptionsSetup.lua:188`. Nothing to remove.
