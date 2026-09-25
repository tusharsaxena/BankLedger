Delta: LibKa0s v1.57.0 -> v1.58.0

# 01 — Delta

Run: 2026-09-25, plan item M6-BL of the 2026-09-23 review and standards-audit remediation (milestone
M6, launcher left-click opens settings and right-click opens a context menu), written by hand by a
workflow subagent the same way M5-BL wrote `docs/revendor/2026-09-24-v1.57.0/`. Steps 0 and 2 to 4
of the local `revendor-libka0s.md` are taken here. Steps 5 to 7 are replaced by the M6 row itself:
the one adoption this release asks for (the Launcher minor 4 menu pairs) is fixed by the owner's
ruling and lands in the same item. Target: this repo, branch
`feat/2026-09-23-review-audit-remediation` at `9b0c35b` (M5-BL). No push.

Source: the sibling checkout `../LibKa0s`, **tag `v1.58.0` (tag object `93cf3ad` -> commit
`34931c9`)**, extracted with `git -C ../LibKa0s archive v1.58.0 LibKa0s testkit | tar -x -C
<scratch>/`, never from the working tree (`git -C ../LibKa0s status --short | wc -l` -> `0`). The tag
is local and not pushed. `tests/test_vendor_sync.lua` compares against the tag the provenance line
names, so the local tag is enough.

```
git -C ../LibKa0s log --oneline v1.57.0..v1.58.0 | wc -l      -> 2
  02999d0 LK-37: Launcher minor 4 — left-click settings, right-click options menu
  34931c9 LK-37: record the v1.58.0 release run, its ANALYSIS.md and gate line
```

## Step 0 — Pre-flight on this addon's newest bundle

Newest single-tag bundle: `docs/revendor/2026-09-24-v1.57.0/`. Its line 1 names base `v1.56.0`. The
commit that vendored v1.57.0 is `9b0c35b` (M5-BL), and `git show 9b0c35b^:CLAUDE.md` names
`v1.56.0`. **ok**, so no base correction is owed.

## 3a — Claimed version, and the delta base

`CLAUDE.md:46`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.57.0** (MIT).

Cross-check: the payload before the copy matched the v1.57.0 tag exactly: `diff -rq
<v1.57.0>/LibKa0s libs/LibKa0s && diff -rq <v1.57.0>/testkit tests/_kit` printed
`payload-matches-v1.57.0`. **Base: v1.57.0.**

## 3b — Actual version, before the copy

v1.57.0's block (the new column of the v1.57.0 bundle's 3c); kit revision 26
(`tests/_kit/framework.lua:20`). The line and the bytes agreed.

## 3c — Per-file minor delta

The file list comes from the tag's `LibKa0s/LibKa0s.xml` (21 `<Script>` rows, unchanged). Only one
file differs between the two tags, so every other row keeps its v1.57.0 minor.

| File | Constant | v1.57.0 | v1.58.0 |
|---|---|---|---|
| `Launcher.lua` | `MINOR` | 3 | **4** |
| every other file of the 21 | — | unchanged | unchanged |

None is added or removed, so there is **no cross-major skew**. The library's CHANGELOG says no
`NEEDS_*` floor rises and no major is added.

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
replaced whole as the M6 row requires; its bytes are v1.57.0's, so git records no kit change.

## 3e — Consumption map

The same fourteen `LibStub("LibKa0s-…-1.0", true)` sites as at v1.57.0 (thirteen majors). The one
that moved, Launcher, is consumed at `core/LauncherSetup.lua`.

## 3f — Kit revision, and the pairing rule

**26** at the tag and vendored. Both payloads are copied whole in one commit, so the pairing rule
holds by construction.

## 3g — Contract delta

| Major | Old -> new document | What moved |
|---|---|---|
| Launcher | `Launcher/version-3-docs.md` -> version 4 | Left-click always calls `openSettings`; right-click opens `MenuUtil.CreateContextMenu` built from four optional accessor-and-toggle pairs (`isEnabled`/`setEnabled`, `isLocked`/`toggleLock`, `isTestMode`/`toggleTestMode`, `isWindowShown`/`toggleWindow`), grayed but for Enabled while disabled; `onClick`, `leftClickLabel`, `disabledLine` and `slash` retired (ignored if passed); the tooltip's hints fixed at `Left-click: Open settings` / `Right-click: Options menu`; `lib.STRINGS` gains `TOOLTIP_OPTIONS_MENU` and seven `MENU_*` keys |

**Bound to what this addon hands over.** Three contract moves under unchanged signatures reach this
addon, none a raise:

- `onClick` stops running. On the copy alone the left click opens the panel, and the ledger toggle
  it ran (rung (a)) was reachable from the button by nothing.
- `disabledLine` stops being read, so the disabled left-click refusal is gone.
- With `isEnabled` passed but no `setEnabled`, the right click has no entry to draw and falls back to
  the panel, so on the copy alone both buttons opened the settings panel under a `Right-click:
  Options menu` hint.

**Suite after the copy alone** (before the host edit): `ka0s-bounded lua5.1 tests/run.lua` -> 1059
passed, 5 failed, 0 skipped, 1064 total. The five were the rung (a) left-click case, the raising
left-click case, the exact tooltip case (hints), and the two disabled launcher cases (left-click
refusal and disabled hint). All five are rewritten for minor 4 in the same item, as the M6 row asks.

The fields the M6 row owes, and what this addon passes:

| Field | Passed | Why |
|---|---|---|
| `setEnabled(on)` | `NS.COMMANDS` `enable` / `disable` -> `Sl:CliEnabled(on)` | the reserved pair's own handler |
| `toggleLock` | `NS.COMMANDS` `set` with `settings.locked <not isLocked()>` -> `Sl:CliSet` | this addon has **no** `lock` / `unlock` verb; `/bl set settings.locked` is the only verb that writes the *Lock frame* row |
| `toggleTestMode` | `NS.COMMANDS` `test` -> `LT:ToggleTestMode` | `/bl test`'s handler, with its three outcomes |
| `isWindowShown` | `NS.Browser:GetWindow():IsShown()` | the ledger browser, the primary window `ADDONS.md` names |
| `toggleWindow` | `NS.COMMANDS` `toggle` -> `B:Toggle` | `/bl toggle`'s handler |
| `isEnabled`, `isLocked`, `isTestMode`, `version` | kept from M5 | also the tooltip's lines |
| `onClick`, `leftClickLabel`, `disabledLine` | removed | retired at minor 4 |

### Blockers

**None.**

## 3h — Tags this addon vendored and never recorded

None outstanding. v1.57.0 is recorded by `docs/revendor/2026-09-24-v1.57.0/`, and v1.58.0 by this
one.
