Delta: LibKa0s v1.113.0 -> v1.114.0

Recorded before the copy. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.114.0 LibKa0s testkit tools` (tag commit 2eaa8fc9, a local tag on the library's branch `feat/2026-11-25-seeds-foreverdb`, not on origin yet). Run under Ka0sAddonsCommonTasks `docs/2026-11-25-SEEDS_AND_FOREVERDB/`, item SF-BL-01 (its `03_SPEC.md` §8 and §9): no adoption interview and no issue filing. The run pre-decides this addon's one adoption, `LibKa0s-ForeverDB-1.0`'s `VendorPrice` (LibKa0s#105).

## Step 0 pre-flight
This addon's newest single-tag bundle is `2026-11-22-v1.110.0`, line 1 `Delta: LibKa0s v1.109.0 -> v1.110.0`; the provenance line before that re-vendor (`09ffff0^`) named v1.109.0. No correction owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` names v1.113.0 (CLAUDE.md:49).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit`, is `b930d78` (the v1.113.0 re-cut); its CLAUDE.md names v1.113.0. They agree.
- Payload before the copy equals the library at v1.113.0 (a8f7a70e): `diff -rq --strip-trailing-cr` of `libs/LibKa0s` against a v1.113.0 extract prints only `Only in <extract>/LibKa0s/media/...` lines (icons and sounds not declared), and of `tests/_kit` prints nothing (payload-matches).
- `git -C ../LibKa0s log --oneline v1.113.0..v1.114.0`: 8 commits (the merge of the 2026-11-24 feedback branch, SF-LK-01 twice, SF-LK-02 twice, SF-LK-REL three times). `git -C ../LibKa0s diff --stat v1.113.0 v1.114.0 -- LibKa0s testkit`: `LibKa0s/DebugLogDiagnostics.lua` (28), `LibKa0s/ForeverDB.lua` (+448, new), `LibKa0s/LibKa0s.xml` (+1), `testkit/README.md`, `testkit/client_globals_forever.lua` (88), `testkit/framework.lua`, `testkit/mock_foreverdb.lua` (+263, new).

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.114.0)
The constants this addon carried matched v1.113.0's, so the line and the bytes agreed.
```
ForeverDB.lua            old: (none)                 new: local MAJOR, MINOR = "LibKa0s-ForeverDB-1.0", 1
DebugLogDiagnostics.lua  old: local DIAG_MINOR = 11  new: local DIAG_MINOR = 12
```
(3c's loop over the tag's `LibKa0s.xml`, 87 files; every other file kept its minor.) One file is new (`ForeverDB.lua`, loaded after `Item.lua`), none is removed and no `NEEDS_*` floor rose. No cross-major skew.

## 3d Diffs
Before the copy, against the v1.114.0 extract: content and bytes differ in `LibKa0s/DebugLogDiagnostics.lua`, `LibKa0s/LibKa0s.xml`, `testkit/README.md`, `testkit/client_globals_forever.lua` and `testkit/framework.lua`; `Only in <extract>` for `LibKa0s/ForeverDB.lua` and `testkit/mock_foreverdb.lua`. Every other line is `Only in <extract>/LibKa0s/media/...` (icons and sounds not declared). No `Only in libs/LibKa0s` line: nothing removed upstream survives here. After the copy and before the prune, both diffs in both directions are empty.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' --include='*.lua'` outside `libs/` and `tests/`: Bus, Callout, Charts, Compat, Core, DebugLog, Env, IconBrowser, Item, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Sim, Skin, Slash, Tooltip, WaypointArrow and Widgets. Of the majors that moved, this addon looks up DebugLog (its diagnostics report). ForeverDB is new and unconsumed before SF-BL-01's feature commit.

## 3f Kit revision
```
old: tests/_kit/framework.lua:20:Kit.VERSION = 60
new: testkit/framework.lua:20:Kit.VERSION = 62
```
Both payloads copied whole in one commit, as the pairing rule requires; CLAUDE.md's kit sentence rolls 60 -> 62 with the provenance line. Revision 61 adds `mock_foreverdb.lua` (the invented ForeverDB fake); revision 62 regenerates `client_globals_forever.lua` at Ketho `forever` `e230342` (17 names added, 3 removed, none called by this addon).

## 3g Contract delta and Blockers
- `docs/api/DebugLog/version-23.11.1.5-docs.md` against `version-23.12.1.5-docs.md`: no member change. The report's `LibKa0s running:` line lists ForeverDB, and the identity section ends with one `ForeverDB: present=... loaded=...` line, which never loads the data addon. A host suite that pins `DebugLogDiagnostics 11` or the identity section's last line re-pins.
- `grep -rnE 'KIT_VERSION|DebugLogDiagnostics|DIAG_MINOR|LibKa0s running' tests` (outside `_kit`): no pin. `tests/test_surface_parity.lua:207` checks the DebugLog stub by name, and no member moved, so it stays green.
- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: none.

**Blockers: none.**

## 3h Span
`v1.112.0` and `v1.113.0` were vendored without a bundle; back-filled as `../2026-11-25-v1.112.0-v1.113.0/`.

## 3i Icons
`grep -n 'LibKa0s icons:' CLAUDE.md`: line 50, directly under the provenance line; kept unchanged (19 names). The ForeverDB feature draws no library icon. The owner's in-client smoke stays the backstop for a forgotten name.

## 3j Whole-folder icon tests
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests` (outside `_kit`): `tests/test_libka0s.lua:738` opens the declared `info.tga`, and `tests/test_mediasetup.lua:154` loops over declared names only. Neither is a blocker.
