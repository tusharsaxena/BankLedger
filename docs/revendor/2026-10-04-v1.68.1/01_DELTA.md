Delta: LibKa0s v1.68.0 -> v1.68.1

# 01 — Delta (BankLedger)

Run: 2026-10-04, an orchestrated session running `/dev-copilot:wow-revendor-libka0s BankLedger
--tag v1.68.1` non-interactively. The owner pre-authorized the run and was not available for an
interview; the run was told to stop on any genuine decision (an adoption candidate, a contract
change, red unrelated to the re-vendor). None arose. Target: this repo, branch
`feat/2026-10-04-revendor-libka0s-v1.68.1`, cut from `master` @ `181a1ff`, which equalled
`origin/master` after `git fetch` with a clean tree.

Source: the sibling checkout `../LibKa0s`, **local tag `v1.68.1` (tag object `9fb7956` -> commit
`9000cbd`)**, which is also `git -C ../LibKa0s tag --sort=-v:refname | head -1`. The payloads were
extracted with `git -C ../LibKa0s archive v1.68.1 LibKa0s testkit | tar -x -C <scratch>/new`, never a
branch tip. `git -C ../LibKa0s log --oneline v1.68.0..v1.68.1` lists 7 commits: DC-REN-01 (kit
revision 36, the rename), DC-REN-02 to DC-REN-05 (release record and doc follow-ups), SD-FIN-01 (a
library test comment) and the `feat/2026-10-02-drag-attach` merge. `git -C ../LibKa0s diff --stat
v1.68.0 v1.68.1 -- LibKa0s testkit` names three files, all under `testkit/`: `framework.lua` (1 line),
`run-automated-tests.sh` (4 lines) and `test_eol.lua` (1 line).

This is the library's rename-only release: the kit names `/dev-copilot:*` commands where it named
`/wow-addon:*` (CHANGELOG v1.68.1, lines 13-53 at the tag).

## Step 0 — Base pre-flight (roster-wide, report only)

All eleven roster addons report `ok`: each newest single-tag bundle is `2026-10-02-v1.68.0` with base
v1.67.0, which matches the provenance line before its re-vendor commit (BankLedger's is `ccefbec`).
No misstated base, so no correction paragraph.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `46: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.68.0 (MIT).` The last payload commit, `git log -1 --format=%H -- libs/LibKa0s tests/_kit` ->
`ccefbec`, left the line at v1.68.0, so the two agree, and `git log --format='%h %s' ccefbec..HEAD --
CLAUDE.md` is empty. Payload check against the claimed tag: `diff -rq <v1.68.0>/LibKa0s libs/LibKa0s &&
diff -rq <v1.68.0>/testkit tests/_kit` printed `payload-matches`. `CLAUDE.md:48` names the kit revision
that tag carries and moves with it (3f). `README.md` has no provenance line.

**Base: v1.68.0.**

## 3b — Actual version, before this run

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` returns 32
constants, v1.68.0's, and `Kit.VERSION` is 35. Claim and bytes agree.

## 3c — Per-file minor delta

`git -C ../LibKa0s diff --quiet v1.68.0 v1.68.1 -- LibKa0s` exits 0: **the library payload is
byte-identical between the two tags**, the XML included. Walking the tag's 32 `LibKa0s.xml` rows with
the playbook's loop, every file reports the same constant on both sides: Core 10, Env 1, Compat 1,
Lifecycle 3, Bus 2, Schema 2, Pool 3, Item 2, Media 4, Widgets 12 (WidgetsReorder 1,
WidgetsDragHandle 4), DebugLog 19 (DebugLogDiagnostics 2, DebugLogGates 1), Slash 19 (SlashParse 1),
Launcher 5, Options 28 (OptionsRegistry 2, OptionsWidgets 34, OptionsIds 2, OptionsIdList 3,
OptionsTabs 8, OptionsCombat 1, OptionsCompose 7, OptionsScroll 4, OptionsNav 2), Perf 14
(PerfSampler 1, PerfCommands 1, PerfPanel 6).

No file moves a minor, no file or major is added, and no `NEEDS_*` floor rises. The consumer is behind
on no file (no cross-major skew).

## 3d — Both diffs

Before the copy:

- `libs/LibKa0s`: `diff -r --strip-trailing-cr` and `diff -rq` against `<scratch>/new/LibKa0s` are both
  empty (exit 0). No `Only in` line.
- `tests/_kit`: three files differ, `framework.lua`, `run-automated-tests.sh` and `test_eol.lua`. No
  `Only in` line on either side.

Nothing is deleted.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'`, outside `libs/` and
`tests/`: DebugLog (`core/DebugLogSetup.lua:21`), Media (`core/MediaSetup.lua:45`), Env
(`core/EnvSetup.lua:39`), Launcher (`core/LauncherSetup.lua:70`), Bus (`core/Constants.lua:265`), Pool
(`core/PoolSetup.lua:20`), Item (`core/ItemSetup.lua:26`), Lifecycle (`core/LifecycleSetup.lua:41`),
Core (`core/CoreSetup.lua:58`), Widgets (`modules/Export.lua:14`, `modules/Browser.lua:5`), Slash
(`settings/Slash.lua:226`), Options (`settings/OptionsSetup.lua:26`) and Schema
(`settings/Schema.lua:515`): thirteen majors. Perf and Compat are not looked up, as at v1.68.0. No
major moved, so nothing here feeds 3g or Step 5.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION =' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua` -> **35 -> 36**.
The pairing rule (a consumer on v1.9.0 or newer takes kit revision 11 or newer in the same commit) is
satisfied by construction: both payloads are copied whole, and they move together for that reason.
The kit's revision-36 document (`docs/api/testkit/version-36-docs.md:19-23` at the tag) states that no
file is added, no public member, kit case or mock changes, and the runner's manifest is unchanged. Its
one visible effect is one runner-printed line in `RESULTS.md` on the next run (`:40-43`). A
consumer's own prose naming the revision it holds moves to 36 (`:59-60`): here that is `CLAUDE.md:48`
("That tag carries test-kit revision 35"). The other `kit revision 35` mentions outside the payload
and the frozen bundles (`DEPENDENCIES.md:97`, `docs/testing.md:231`, `tests/run.lua:41`,
`tests/test_panel.lua:808`) date the sighted complexity gate to the revision that introduced it, and
stay.

## 3g — Contract delta

No major moved a minor (3c), so the set of majors to read (moved, intersected with consumed) is
empty. `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs
--exclude-dir=_kit` finds no site. The kit change is comment- and string-only (3f), and no case or
member contract moves.

**No blockers.**

## 3h — Tags vendored and never recorded

Running the playbook's listing from horizon `2026-08-25` gives 49 vendored tags and 49 recorded, and
`grep -vxF -f recorded.txt vendored.txt` is empty. Every tag this addon vendored has a bundle, so there
is no span bundle.
