Delta: LibKa0s v1.55.0 -> v1.56.0

# 01 — Delta

Run: 2026-09-24, plan item RV-BL of the 2026-09-23 review and standards-audit remediation, written by
hand by a workflow subagent. It follows the local `../wow-addon/commands/revendor-libka0s.md` as
amended by WA-01. The installed plugin does not carry WA-01 yet, so the command itself was not run.
Steps 0 and 2 to 4 are taken here. Steps 5 to 7 (candidates, interview, adoption) are **not**: every
adoption decision is one of this addon's M3 plan items (BL-03 to BL-24). The folder is dated for the
plan (2026-09-23), as the plan names it. Target: this repo, branch
`feat/2026-09-23-review-audit-remediation` at `4e97c71` (BL-02, after BL-01 at `90c7fb0`). No push.

Source: the sibling checkout `../LibKa0s`, **tag `v1.56.0` (tag object `4622018` -> commit
`514fc0a`)**, extracted with `git -C ../LibKa0s archive v1.56.0 LibKa0s testkit | tar -x -C
<scratch>/`, never from the working tree (`git -C ../LibKa0s status --short | wc -l` -> `0`). The tag
is local and not yet pushed. `tests/test_vendor_sync.lua` compares against the tag the provenance line
names, so the local tag is enough.

```
git -C ../LibKa0s log --oneline v1.55.0..v1.56.0 | wc -l      -> 53
```

## Step 0 — Pre-flight on this addon's newest bundle

Newest single-tag bundle: `docs/revendor/2026-09-23-v1.55.0/`. Its line 1 names base `v1.54.2`. The
commit that vendored v1.55.0 is `4310368` ("Re-vendor LibKa0s v1.55.0, and wire the kit's gates by
their directory"), and `git show 4310368^:CLAUDE.md | grep -oE 'Bundles \[LibKa0s\]\([^)]*\)
v[0-9.]+[0-9]'` gives `v1.54.2`. **ok**, so no base correction is owed.

That bundle's line 1 is a heading, `# 01 — Delta: LibKa0s v1.54.2 → v1.55.0`, not the bare form WA-01
now fixes. The audit reads the tags off it all the same, and a frozen bundle is never rewritten, so it
stays as written.

## 3a — Claimed version, and the delta base

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:46`: Bundles
[LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.55.0** (MIT).

Cross-check: `git log -1 --format=%h -- libs/LibKa0s tests/_kit` -> `4310368`, whose `CLAUDE.md`
names v1.55.0. The later `CLAUDE.md` commits (`24ede85` onwards) do not touch the line. The payload
before the copy matched the v1.55.0 tag exactly: `diff -rq <v1.55.0>/LibKa0s libs/LibKa0s && diff -rq
<v1.55.0>/testkit tests/_kit` printed `payload-matches`. **Base: v1.55.0.**

## 3b — Actual version, before the copy

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua`: the v1.55.0
block in the old column of 3c. Kit revision 25 (`grep -n 'Kit.VERSION' tests/_kit/framework.lua` ->
`:20`). The line and the bytes agreed.

## 3c — Per-file minor delta

The file list comes from the tag's `LibKa0s/LibKa0s.xml` (21 `<Script>` rows, unchanged from
v1.55.0).

| File | Constant | v1.55.0 | v1.56.0 |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | **8** |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Compat.lua` | `MINOR` | 1 | 1 |
| `Lifecycle.lua` | `MINOR` | 1 | **2** |
| `Bus.lua` | `MINOR` | 1 | **2** |
| `Schema.lua` | `MINOR` | 1 | **2** |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | **2** |
| `Media.lua` | `MINOR` | 3 | **4** |
| `Widgets.lua` | `MINOR` | 9 | **10** |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | 2 |
| `DebugLog.lua` | `MINOR` | 12 | **13** |
| `Slash.lua` | `MINOR` | 14 | **15** |
| `Launcher.lua` | `MINOR` | 1 | **2** |
| `Options.lua` | `MINOR` | 23 | **24** |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 30 | **31** |
| `OptionsTabs.lua` | `TABS_MINOR` | 3 | **4** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 7 | 7 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | **4** |
| `Perf.lua` | `MINOR` | 12 | **13** |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

No file is new and none is removed. Every file moves forward or stays put, so there is **no
cross-major skew** before or after. The library's CHANGELOG says no `NEEDS_*` floor rises.

## 3d — Both diffs

Before the copy:

```
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   -> 15 "differ" lines: Bus, Core, DebugLog,
    Item, Launcher, Lifecycle, Media, Options, OptionsScroll, OptionsTabs, OptionsWidgets, Perf, Schema,
    Slash, Widgets (.lua). No "Only in" line.
diff -rq <scratch>/LibKa0s libs/LibKa0s                        -> the same 15 lines (bytes == content)
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit
    README.md, framework.lua, mock_base.lua, mock_record.lua, run-automated-tests.sh, test_eol.lua,
    test_layout_cap.lua, test_prose.lua differ
    Only in <scratch>/testkit: asserts.lua, mock_events.lua, prose_lists.lua
diff -rq <scratch>/testkit tests/_kit                          -> the same 11 lines
```

Content is dirty in both payloads for the expected reason, a newer tag. There is no `Only in
libs/LibKa0s` or `Only in tests/_kit` line, so nothing was removed upstream and nothing is deleted
here. There is no content-clean, bytes-dirty drift.

After the copy (`rm -rf` both folders, then `cp -r` from the extracted tag), `diff -r
<scratch>/LibKa0s libs/LibKa0s` and `diff -r <scratch>/testkit tests/_kit` both print nothing, and
`test -x tests/_kit/run-automated-tests.sh` holds.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'   (libs/ and tests/ rows dropped)
  core/CoreSetup.lua:37          Core
  core/EnvSetup.lua:39           Env
  core/Constants.lua:259         Bus      (NS.MSG's catalog)
  core/PoolSetup.lua:20          Pool
  core/ItemSetup.lua:26          Item
  core/MediaSetup.lua:45         Media
  core/DebugLogSetup.lua:21      DebugLog
  core/LifecycleSetup.lua:41     Lifecycle
  core/LauncherSetup.lua:67      Launcher
  modules/Browser.lua:5          Widgets
  modules/Export.lua:14          Widgets
  settings/OptionsSetup.lua:26   Options
  settings/Slash.lua:292         Slash
  settings/Schema.lua:441        Schema   (adopted at v1.55.0)
```

This addon consumes thirteen majors. Unadopted in the payload: Compat and Perf.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **26** at the tag,
**25** vendored before the copy. Both payloads are copied whole in one commit, so the pairing rule
(LibKa0s v1.9.0 or newer takes kit revision 11 or newer in the same commit) holds by construction.

## 3g — Contract delta

The majors that both moved a minor (3c) and are looked up here (3e): Core, Lifecycle, Bus, Schema,
Item, Media, Widgets, DebugLog, Slash, Launcher and Options. Each old document's `Superseded by` row,
read at the tag:

| Major | Old -> new document | What moved |
|---|---|---|
| Core | `Core/version-7-docs.md:15` -> version 8 | `Format` survives a secret in a numeric slot; the `SafeRegisterEvent` family is added |
| Lifecycle | `Lifecycle/version-1-docs.md:15` -> version 2 | documents and pins the nested-edge behavior; "the code is unchanged" |
| Bus | `Bus/version-1-docs.md:15` -> version 2 | the tracking wrappers are re-stamped at every edge after a newer AceEvent-3.0 re-embed |
| Schema | `Schema/version-1-docs.md:15` -> version 2 | `SetMany`, `row.normalize`, and the instance id reaching a row's `get` and `ApplyDefault` |
| Item | `Item/version-1-docs.md:15` -> version 2 | `QualityFromLink` reads the 11.1.5+ `\|cnIQ<n>` link color |
| Media | `Media/version-3-docs.md:15` -> version 4 | `RegisterLSM` flags the face western + ruRU and counts only what LSM holds |
| Widgets | `Widgets/version-9.2-docs.md:15` -> 10.2 | a `ReorderList` drag polls on the ghost and takes its line from a library free list |
| DebugLog | `DebugLog/version-12-docs.md:15` -> version 13 | the buffer trim is batched at the cap |
| Slash | `Slash/version-14-docs.md:15` -> version 15 | `CliSet` / `CliReset` print the write seam's refusal |
| Launcher | `Launcher/version-1-docs.md:15` -> version 2 | optional `isEnabled` / `disabledLine` left-click gate; the missing-library notices print once per instance, without the `[LibKa0s] ` prefix |
| Options | `Options/version-23.30.3.7.3-docs.md:16` -> 24.31.4.7.4 | `CreateOptionsPanel` parks in combat and replays at `PLAYER_REGEN_ENABLED`; `OpenOptionsPanel` answers a boolean; drag throttles keep their own armed flag (OptionsWidgets 31); `RenderTabbedSchema` moves to `OptionsTabs.lua` and takes `opts`; banner chrome is released per render |

**Bound to what this addon hands over.** `grep -rn '__Attach[A-Za-z]*' . --include='*.lua'
--exclude-dir=libs --exclude-dir=_kit` -> no hit. The host-supplied members the moved contracts can
reach:

- **Launcher notices.** `core/BankLedger.lua:64` calls `NS.Launcher:Register()` from `OnInitialize`.
  The harness ships neither broker library, so that boot call now spends the once-per-instance
  `NO_BROKER` notice, and the second `Register` in `tests/test_launcher.lua:102` prints nothing. That
  case goes red (see below). The `isEnabled` / `disabledLine` gate is an opt-in; the host's hand gate
  (`NS.Slash:RefuseIfDisabled()` in `core/LauncherSetup.lua`) still works under minor 2. Both are
  **BL-08**'s.
- **Options `scheduleTimer`.** `settings/OptionsSetup.lua:94` hands AceTimer through the addon object,
  which returns a handle, so OptionsWidgets 31 changes nothing here.
- **Options `CreateOptionsPanel`.** `settings/Panel.lua:778` calls it with no park of its own, so
  nothing needs deleting (a host MUST NOT add its own park). `P:Open` (`:785`) does not read
  `OpenOptionsPanel`'s new boolean.
- **Options `RenderTabbedSchema`.** `settings/Panel.lua:771` passes three arguments and no `opts`.
  The library-absent stub at `settings/OptionsSetup.lua:175` keeps its shape.
- **Schema.** BL-02 (`4e97c71`) gave the degradation stub `SetMany` ahead of this copy, so the two
  arms stay at parity. `writeThrough` is **BL-10**'s.
- **Slash `set`.** `/bl set` echoes through `Sl:CliSet`; minor 15 may now print the seam's refusal
  line. The echo cases are **BL-09**'s to re-pin; none went red.
- **Core `SafeRegisterEvent`.** Additive; adoption is **BL-06**.

### Blockers

**None.** No host-supplied member's call site moved in a way that breaks the addon in game.

**Suite at the RV commit.** The RV commit is copy-only: it carries the payload, the provenance line
and this bundle, and nothing else (spec Part B).

- `ka0s-bounded lua5.1 tests/run.lua` -> **1019 passed, 1 failed, 0 skipped, 1020 total**. The one
  red, caused by the stricter library (Launcher minor 2):
  `Launcher: a host with neither broker library reports it and does NOT raise`
  (`tests/test_launcher.lua:115`, "the absence is reported on one line rather than swallowed: "
  with empty output). The notice was already spent by the boot-time `Register`. **BL-08** re-pins
  the case as "the missing-broker notice prints once across two Register calls, without a
  [LibKa0s] tag".
- `ka0s-bounded luacheck .` -> 0 warnings / 0 errors in 71 files.
- `ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` -> no thresholds exceeded; no
  function above CCN 15.

## 3h — Tags this addon vendored and never recorded

Vendored tags since the horizon `2026-08-25`, read from the provenance line of every commit that
touched `libs/LibKa0s` or `tests/_kit`, less every tag on line 1 of a `docs/revendor/*/01_DELTA.md`,
prints **26** tags:

```
v1.16.0 v1.17.0 v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.26.0 v1.27.0 v1.28.0 v1.35.0 v1.36.0 v1.36.1
v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.43.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0
v1.52.0 v1.53.0
```

**Not written here.** The consolidated span bundle is plan item **BL-23**, and this commit may touch
only `docs/revendor/2026-09-23-v1.56.0/` (spec Part B). BL-23's item text lists 25 tags; this listing
adds v1.16.0, v1.17.0 and v1.43.0 and does not count v1.24.0 or v1.29.0 (already on line 1 of
`docs/revendor/2026-09-03/` and `docs/revendor/2026-09-12/`). BL-23 should re-derive its tag list rather than trust the count.
v1.56.0 is recorded by this bundle.
