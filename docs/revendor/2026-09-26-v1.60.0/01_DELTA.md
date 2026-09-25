Delta: LibKa0s v1.58.0 -> v1.60.0

# 01 — Delta

Run: 2026-09-26, plan item DR-BL-01 of the 2026-09-25 diagnostics rollout
(`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/`, milestone M3), through
`/wow-addon:revendor-libka0s --tag v1.60.0`. Target: this repo, branch
`feat/2026-09-25-diagnostics-rollout`, cut from `master` at `ac04773`. No push.

Source: the sibling checkout `../LibKa0s`, **tag `v1.60.0` (tag object `ac59511` -> commit
`bed0eb1`)**, extracted with `git -C ../LibKa0s archive v1.60.0 LibKa0s testkit | tar -x -C
<scratch>/`, never from the working tree (`git -C ../LibKa0s status --short | wc -l` -> `0`).

```
git -C ../LibKa0s log --oneline v1.58.0..v1.60.0      -> 16 commits, among them
  e8faa5d B8-P8: WidgetsDragHandle minor 3 - an opt-in close mark beside the help mark
  58e3794 DR-LK-01: DebugLog minor 14: copy-timing flag, BUFFER_SLACK published
  43f062c DR-LK-04: Slash minor 16: diagnostics is live while disabled
  747ecfc DR-LK-03: DebugLogDiagnostics minor 1, the diagnostics report; kit revision 27
  0e80b4c DR-LK-02: MAX_BUFFER 1500 -> 3000, BUFFER_SLACK 64 -> 128; cases on the constants
```

v1.59.0 was never vendored here, so this delta spans two library releases.

## 3a — Claimed version

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:46`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
**v1.58.0** (MIT).

## 3b — Actual version, before the copy

The per-file minors (`grep -hoE 'local (MAJOR, )?(MINOR|[A-Z_]+_MINOR) ...' libs/LibKa0s/*.lua`) are
v1.58.0's, and the payload matched that tag byte for byte: `diff -rq <v1.58.0>/LibKa0s libs/LibKa0s
&& diff -rq <v1.58.0>/testkit tests/_kit` -> `payload-matches-v1.58.0`. Kit revision 26
(`tests/_kit/framework.lua:20`). The line and the bytes agreed.

## 3c — Per-file minor delta

The file list comes from the tag's `LibKa0s/LibKa0s.xml`: **22** `<Script>` rows (21 at v1.58.0).

| File | Constant | v1.58.0 | v1.60.0 |
|---|---|---|---|
| `DebugLog.lua` | `MINOR` | 13 | **14** |
| `DebugLogDiagnostics.lua` | `DIAG_MINOR` | — (new file) | **1** |
| `Slash.lua` | `MINOR` | 15 | **16** |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | **3** |
| every other file of the 22 | — | unchanged | unchanged |

Nothing is behind after the copy, so there is **no cross-major skew**. The library's CHANGELOG says
no `NEEDS_*` floor rises and no major is added (`DebugLogDiagnostics.lua` is a secondary file of the
DebugLog major, key 14.1).

## 3d — Both diffs, before the copy

`diff -rq [--strip-trailing-cr] <scratch>/LibKa0s libs/LibKa0s` (content and bytes agree):

```
Files .../DebugLog.lua and libs/LibKa0s/DebugLog.lua differ
Only in <scratch>/LibKa0s: DebugLogDiagnostics.lua
Files .../LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
Files .../Slash.lua and libs/LibKa0s/Slash.lua differ
Files .../WidgetsDragHandle.lua and libs/LibKa0s/WidgetsDragHandle.lua differ
```

`diff -rq [--strip-trailing-cr] <scratch>/testkit tests/_kit` (content and bytes agree):

```
Files .../README.md and tests/_kit/README.md differ
Files .../framework.lua and tests/_kit/framework.lua differ
Only in <scratch>/testkit: test_diagnostics_contract.lua
```

Content dirty = the release, not a fork. No `Only in libs/LibKa0s` or `Only in tests/_kit` line, so
nothing is deleted.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'`, authored files only:
Item (`core/ItemSetup.lua:26`), Core (`core/CoreSetup.lua:58`), Bus (`core/Constants.lua:259`),
**DebugLog** (`core/DebugLogSetup.lua:21`), Lifecycle (`core/LifecycleSetup.lua:41`), Launcher
(`core/LauncherSetup.lua:70`), Env (`core/EnvSetup.lua:39`), Media (`core/MediaSetup.lua:45`), Pool
(`core/PoolSetup.lua:20`), **Widgets** (`modules/Export.lua:14`, `modules/Browser.lua:5`), Options
(`settings/OptionsSetup.lua:26`), **Slash** (`settings/Slash.lua:336`), Schema
(`settings/Schema.lua:452`). Perf and Compat are not looked up (Perf: the settled `performance-§12`
exemption).

Moved majors this addon consumes: **DebugLog** and **Slash**. Widgets is consumed, but this addon
calls no DragHandle surface (`grep -rn DragHandle core modules settings` -> nothing), so the
WidgetsDragHandle move does not reach it.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION =' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **27** at the
tag, **26** here. Both payloads move together in one commit (the kit-11 pairing rule is satisfied by
construction). Revision 27 adds `test_diagnostics_contract.lua`, which registers one declared skip
until the host sets `Kit.diagnostics`; wiring it is DR-BL-03's.

## 3g — Contract delta, and blockers

Read against `docs/api/DebugLog/version-13-docs.md` (v1.58.0) -> `version-14.1-docs.md` (v1.60.0) and
`docs/api/Slash/version-15-docs.md` -> `version-16-docs.md`. No `__Attach*` site exists in this addon
(`grep -rn '__Attach' core modules settings` -> nothing).

### Blockers (fixed in the re-vendor commit)

1. **The library-absent DebugLog stub gains three members.** `version-14.1-docs.md` *Compatibility*
   (`:615-619` at the tag): "A host's library-absent DebugLog stub is an instance surface, so it gains
   `RunDiagnostics`, `BuildDiagnostics` and `DebugVerb` for its parity case", `RunDiagnostics`
   printing `"%s is unavailable: the LibKa0s library did not load."` with `/<slash> diagnostics`,
   writing nothing and returning 0. `tests/test_surface_parity.lua:138` ("LibKa0s-DebugLog degraded:
   the stub carries the live surface the addon reaches") compares the stub to the live instance and
   goes red at the copy. Fix: `core/DebugLogSetup.lua`'s degraded branch gains the three members;
   `BuildDiagnostics` answers the report's empty shape and `DebugVerb` answers `false`.
2. **The degraded Slash dispatcher's live list is a literal.** `version-16-docs.md:39-61`: "A host that
   passes a literal array does not [inherit `diagnostics`], and adds `"diagnostics"` to it". The live
   dispatcher here passes no `liveVerbs`, so it inherits the verb; the library-absent fallback in
   `settings/Slash.lua:404` is "lib.LIVE_VERBS written out" and would drift. Fix: `diagnostics` is
   added to that table, and its comment names thirteen verbs.

### Contract changes that need no host edit

- **Buffer 1500 -> 3000, slack 64 -> 128** (`version-14.1-docs.md`, *DebugLog.lua 14: the buffer is
  3000 lines*). `grep -rnE 'MAX_BUFFER|1500|\b64\b' tests/test_debuglog.lua tests/test_libka0s.lua`
  pins no buffer literal; every `1500` in this addon's tests is the layout-§1 file cap. Nothing
  re-pins.
