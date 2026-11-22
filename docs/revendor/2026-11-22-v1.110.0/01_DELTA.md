Delta: LibKa0s v1.109.0 -> v1.110.0

Recorded before the copy. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.110.0 LibKa0s testkit tools` (tag commit e97bf187, a local tag on the library's branch `feat/2026-11-22-libka0s-101`, not on origin yet: `git -C ../LibKa0s ls-remote --tags origin v1.110.0` prints nothing). Run under Ka0sAddonsCommonTasks `docs/2026-11-22-LIBKA0S_101_CONTAINER_READER/`, item K101-BL-01: copy and bundle only, no adoption interview and no issue filing. The run pre-decides this addon's adoption (LibKa0s#101's surfaces, item K101-BL-02).

## Step 0 pre-flight
Roster-wide, every addon's newest single-tag bundle is `2026-11-20-v1.108.0` with base v1.107.0, and every one matches the provenance line before its re-vendor (`ok` on all 19 rows). For this addon: line 1 `Delta: LibKa0s v1.107.0 -> v1.108.0`; the provenance line before that re-vendor (8071ca7^) named v1.107.0. No correction owed.

## 3a Base
- `grep -n '[Bb]undles' CLAUDE.md` names v1.109.0 (CLAUDE.md:49).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit`, is c38e2d6 ("FU-RV-BL: Re-copy Compat.lua (minor 5) and Sim.lua (minor 4) from the re-cut v1.109.0"); its CLAUDE.md names v1.109.0. They agree.
- Payload before the copy equals the library at v1.109.0 (d5b62f35): `diff -rq --strip-trailing-cr` of `libs/LibKa0s` against a v1.109.0 extract prints only `Only in <extract>/LibKa0s/media/icons` and `media/sounds` lines (names not declared), and of `tests/_kit` prints nothing (payload-matches).
- `git -C ../LibKa0s log --oneline v1.109.0..v1.110.0`: 6 commits (K101-LK-01, K101-LK-02, K101-LK-REV, K101-LK-REL twice, and the merge of the sync-followups branch that carried v1.109.0). `git -C ../LibKa0s diff --stat v1.109.0 v1.110.0`: in the payloads, `LibKa0s/Compat.lua` (227 lines), `testkit/framework.lua`, `testkit/mock_client.lua` (+79) and `testkit/README.md`.

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.110.0)
The constants this addon carried matched v1.109.0's, so the line and the bytes agreed.
```
Compat.lua   old: local MAJOR, MINOR = "LibKa0s-Compat-1.0", 5   new: local MAJOR, MINOR = "LibKa0s-Compat-1.0", 6
```
(3c's loop over the tag's `LibKa0s.xml`, 86 files; every other file kept its minor.) No file is new, no file is removed and no `NEEDS_*` floor rose. No cross-major skew.

## 3d Diffs
Before the copy, against the v1.110.0 extract: content (`diff -r --strip-trailing-cr`) differs in `LibKa0s/Compat.lua` only (the minor 6 additions), and in `testkit/framework.lua`, `testkit/mock_client.lua` and `testkit/README.md`; bytes (`diff -rq`) differ in the same files. Every other line is `Only in <extract>/LibKa0s/media/icons...` or `Only in <extract>/LibKa0s/media/sounds: callout` (names not declared). No `Only in libs/LibKa0s` line: nothing removed upstream survives here.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' --include='*.lua'` outside `libs/` and `tests/`: Launcher, Skin (`core/Database.lua`, `core/SkinSetup.lua`), Item, DebugLog, Env, Core, **Compat (`core/CompatClient.lua:26`)**, Lifecycle, Bus, Pool, Tooltip, Sim, Media, Widgets, Options, Schema and Slash. Of the majors that moved, this addon looks up Compat, through its one seam `core/CompatClient.lua`.

## 3f Kit revision
```
old: tests/_kit/framework.lua:20:Kit.VERSION = 59
new: testkit/framework.lua:20:Kit.VERSION = 60
```
Both payloads copied whole in one commit, as the pairing rule requires; CLAUDE.md's kit sentence rolls 59 -> 60 with the provenance line. Revision 60's client profiles install `Enum.BagIndex`, `Enum.BankType` and `C_Bank.CanViewBank` only where the host's mock set and `_G` have none, so this addon's own `tests/wow_mock.lua` build still wins.

## 3g Contract delta and Blockers
- `git -C ../LibKa0s diff v1.109.0 v1.110.0 -- docs/api/Compat/version-5-docs.md`: status and `Superseded by` rows only, plus a *Moving to version 6* section: "Additive; nothing this version has moves. Version 6 keeps these seventeen members and their behavior exactly".
- `docs/api/Compat/version-6-docs.md` (header, lines 1-20) adds `ContainerGroups`, `CONTAINER_PATTERNS_BY_CLIENT`, `CanViewCharacterBank`, `NumPurchasedBankTabs`, `BankerKind` and `UnreadyBankContainers`. No existing member's sentence changes.
- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: none.
- Pins: `grep -rnE 'KIT_VERSION|Compat.*MINOR|assertSurfaceParity' tests` (outside `_kit`) finds no `KIT_VERSION` 59 pin, no Compat minor 5 pin and no `assertSurfaceParity` on `LibKa0s-Compat-1.0`, so the release's *What a consumer owes* needs nothing here.

**Blockers: none.**

## 3h Unrecorded vendored tags
The re-vendor-bundle walk (horizon 2026-08-25; provenance tags at every payload commit and every CLAUDE.md roll since, against the tags the bundles in `docs/revendor/` name) prints `v1.109.0`: vendored by bccba40 and c38e2d6 (FU-RV-BL, the sync-followups run) with no bundle. Back-filled as the span bundle `../2026-11-22-v1.109.0-v1.109.0/`.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: line 50, directly under the provenance line, kept as written (19 names). The release adds no icon and no library-drawn name.
- No `LibKa0s sounds:` line: none ships, and the tag's `tools/prune-icons.lua` prunes the voice packs in the same run.

## 3j Tests that assume the whole icon folder
```
tests/test_libka0s.lua:738    io.open("libs/LibKa0s/media/icons/info.tga")   (a declared name)
tests/test_mediasetup.lua:154 io.open over the declared names only
```
No whole-catalog loop. Nothing to fix. `__releaseChrome` appears only in a history comment (`settings/OptionsSetup.lua:190`), not as a mirror.
