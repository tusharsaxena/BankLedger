Delta: LibKa0s v1.56.0 -> v1.57.0

# 01 — Delta

Run: 2026-09-24, plan item M5-BL of the 2026-09-23 review and standards-audit remediation (milestone
M5, the always-on launcher status tooltip), written by hand by a workflow subagent the same way RV-BL
wrote `docs/revendor/2026-09-23-v1.56.0/`. Steps 0 and 2 to 4 of the local `revendor-libka0s.md` are
taken here. Steps 5 to 7 are replaced by the M5 row itself: the one adoption this release asks for
(the Launcher minor 3 descriptor fields) is fixed by the owner's ruling and lands in the same item.
Target: this repo, branch `feat/2026-09-23-review-audit-remediation` at `f349335` (BL-25). No push.

Source: the sibling checkout `../LibKa0s`, **tag `v1.57.0` (tag object `d03e836` -> commit
`aa37bc9`)**, extracted with `git -C ../LibKa0s archive v1.57.0 LibKa0s testkit | tar -x -C
<scratch>/`, never from the working tree (`git -C ../LibKa0s status --short | wc -l` -> `0`). The tag
is local and not pushed. `tests/test_vendor_sync.lua` compares against the tag the provenance line
names, so the local tag is enough.

```
git -C ../LibKa0s log --oneline v1.56.0..v1.57.0 | wc -l      -> 2
  281f26f LK-36: Launcher minor 3 — the library always draws the status tooltip
  aa37bc9 LK-36: record the v1.57.0 release run, its ANALYSIS.md and gate line
```

## Step 0 — Pre-flight on this addon's newest bundle

Newest single-tag bundle: `docs/revendor/2026-09-23-v1.56.0/`. Its line 1 names base `v1.55.0`. The
commit that vendored v1.56.0 is `2195126` (RV-BL), and `git show 2195126^:CLAUDE.md | grep -oE
'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+[0-9]'` gives `v1.55.0`. **ok**, so no base correction is owed.

## 3a — Claimed version, and the delta base

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:46`: Bundles
[LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.56.0** (MIT).

Cross-check: `git log -1 --format=%h -- libs/LibKa0s tests/_kit` -> `2195126`, whose `CLAUDE.md`
names v1.56.0. The payload before the copy matched the v1.56.0 tag exactly: `diff -rq
<v1.56.0>/LibKa0s libs/LibKa0s && diff -rq <v1.56.0>/testkit tests/_kit` printed
`payload-matches-v1.56.0`. **Base: v1.56.0.**

## 3b — Actual version, before the copy

The v1.56.0 block in the old column of 3c; kit revision 26 (`tests/_kit/framework.lua:20`). The line
and the bytes agreed.

## 3c — Per-file minor delta

The file list comes from the tag's `LibKa0s/LibKa0s.xml` (21 `<Script>` rows, unchanged).

| File | Constant | v1.56.0 | v1.57.0 |
|---|---|---|---|
| `Core.lua` | `MINOR` | 8 | 8 |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Compat.lua` | `MINOR` | 1 | 1 |
| `Lifecycle.lua` | `MINOR` | 2 | 2 |
| `Bus.lua` | `MINOR` | 2 | 2 |
| `Schema.lua` | `MINOR` | 2 | 2 |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 2 | 2 |
| `Media.lua` | `MINOR` | 4 | 4 |
| `Widgets.lua` | `MINOR` | 10 | 10 |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | 2 |
| `DebugLog.lua` | `MINOR` | 13 | 13 |
| `Slash.lua` | `MINOR` | 15 | 15 |
| `Launcher.lua` | `MINOR` | 2 | **3** |
| `Options.lua` | `MINOR` | 24 | 24 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 31 | 31 |
| `OptionsTabs.lua` | `TABS_MINOR` | 4 | 4 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 7 | 7 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 4 | 4 |
| `Perf.lua` | `MINOR` | 13 | 13 |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

One file moves. None is added or removed, so there is **no cross-major skew**. The library's
CHANGELOG says no `NEEDS_*` floor rises.

## 3d — Both diffs

Before the copy:

```
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   -> Launcher.lua differs
diff -rq <scratch>/LibKa0s libs/LibKa0s                        -> the same one line (bytes == content)
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit      -> empty
diff -rq <scratch>/testkit tests/_kit                          -> empty
```

No `Only in` line on either side. After the copy (`rm -rf` both folders, then `cp -r` from the
extracted tag), `diff -r <scratch>/LibKa0s libs/LibKa0s` and `diff -r <scratch>/testkit tests/_kit`
both print nothing, and `test -x tests/_kit/run-automated-tests.sh` holds. The kit folder was
replaced whole as the M5 row requires; its bytes are v1.56.0's, so git records no change there.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core settings modules
  core/Constants.lua:259         Bus
  core/CoreSetup.lua:58          Core
  core/DebugLogSetup.lua:21      DebugLog
  core/EnvSetup.lua:39           Env
  core/ItemSetup.lua:26          Item
  core/LauncherSetup.lua:67      Launcher
  core/LifecycleSetup.lua:41     Lifecycle
  core/MediaSetup.lua:45         Media
  core/PoolSetup.lua:20          Pool
  modules/Browser.lua:5          Widgets
  modules/Export.lua:14          Widgets
  settings/OptionsSetup.lua:26   Options
  settings/Schema.lua:452        Schema
  settings/Slash.lua:336         Slash
```

Thirteen majors consumed, as at v1.56.0. The one that moved, Launcher, is consumed.

## 3f — Kit revision, and the pairing rule

**26** at the tag and vendored. Both payloads are copied whole in one commit, so the pairing rule
holds by construction.

## 3g — Contract delta

| Major | Old -> new document | What moved |
|---|---|---|
| Launcher | `Launcher/version-2-docs.md` -> version 3 | The LDB object's `OnTooltipShow` is always the library's `drawTooltip`, on every host, enabled or disabled; `onTooltipShow` changes meaning from "the whole tooltip" to "lines appended between the status block and the click hints"; five optional descriptor fields (`version`, `isLocked`, `isTestMode`, `leftClickLabel`, `slash`); fourteen `TOOLTIP_*` keys in `lib.STRINGS` |

**Bound to what this addon hands over.** `onTooltipShow` is a host-supplied member whose contract
moved under an unchanged signature. At v1.56.0 this addon's hook drew the whole tooltip: a gold
`NS.BRAND_NAME` title, the movement count, a spacer, `Left-click: open the ledger` and
`Right-click: open settings`. Under minor 3 the library draws its own title and click hints around
it, so on the copy alone the hover shows **two titles and two pairs of click hints** (anti-pattern
#89). That is not a raise and no case went red (the old tooltip case only searched for substrings
both copies carry), but it is wrong on screen, so it is fixed in this same item: the hook is cut to
the movement count.

The fields the M5 row owes, and what this addon passes:

| Field | Passed | Why |
|---|---|---|
| `version` | `NS.Version()` | the TOC's `## Version`, `NS.version` only where the manifest cannot be read; the string `/bl version` prints |
| `isLocked` | `db.global.settings.locked == true` | the Master-controls *Lock frame* row's stored key, which `Util.ApplyMasterFrame` honors |
| `isTestMode` | `NS.LedgerTable:IsTestMode()` | the *Test mode* row's own `get` (`settings/Schema.lua`), the sample ledger `/bl test` drives |
| `leftClickLabel` | `NS.L["Toggle ledger window"]` | rung (a), "the ledger browser" in the standard's `ADDONS.md` |
| `slash` | not passed | the library reads `/bl` out of `disabledLine()`, which is `Sl:DisabledLine()` |

### Blockers

**None.** The `onTooltipShow` meaning change is the one contract move that reaches this addon, and
it is resolved in the same item rather than deferred.

**Suite after the copy alone** (before the host edit): `ka0s-bounded lua5.1 tests/run.lua` -> 1061
passed, 0 failed, 0 skipped, 1061 total.

## 3h — Tags this addon vendored and never recorded

None outstanding. The span v1.16.0 to v1.54.2 is recorded by BL-23's
`docs/revendor/2026-09-24-v1.16.0-v1.54.2/`, v1.55.0 and v1.56.0 by their own bundles, and v1.57.0
by this one.
