Delta: LibKa0s v1.62.0 -> v1.63.0

# LibKa0s v1.62.0 -> v1.63.0: the delta (BankLedger)

Copied from the tag `v1.63.0` (`dd7a774`, an annotated local tag at the time of this copy), never from
a working tree: `git -C ../LibKa0s archive v1.63.0 LibKa0s testkit | tar -x -C <scratch>`.

## Base

`CLAUDE.md` named v1.62.0, and the payload before the copy matched that tag
(`diff -rq --strip-trailing-cr` of `v1.62.0`'s `LibKa0s/` and `testkit/` against `libs/LibKa0s` and
`tests/_kit`: empty). No tag this addon vendored is unrecorded, so no span bundle is written.

```
git -C ../LibKa0s log --oneline v1.62.0..v1.63.0
dd7a774 SP-LIB-01R: v1.63.0 release run re-taken on the final tree, so the tag has a record to sit on
ac61f37 SP-LIB-01R: pin the profile list's case-insensitive order with a name byte order would move
5568e7a SP-LIB-01R: v1.63.0 release run re-taken after the doc fix
626aec0 SP-LIB-01R: v1.63.0 migration docs name both stub members and the real parity mechanism
c53705c SP-LIB-01: v1.63.0 release run, analysis and gate line
576576e SP-LIB-01: Slash minor 17, the shared profile verb (CliProfile, ProfileSwitch, ProfileNames)
40886b6 README: plain-language pass for readers
8fd7498 Merge feat/2026-09-26-automated-tests-sweep: ...
95e6457 LK-ATS-SDR: Correct stale comment citations (owner-approved sync-docs follow-up)
662da79 LK-ATS-SD: Sync docs to the tree after the automated-tests sweep
d70c0c1 LK-ATS-99: Final automated-tests sweep run (20260926-193105)

git -C ../LibKa0s diff --stat v1.62.0 v1.63.0 -- LibKa0s testkit
 LibKa0s/Slash.lua | 131 +++++++++++++++++++++++++++++++++++++++++++++++++++++-
 1 file changed, 130 insertions(+), 1 deletion(-)
```

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/Slash.lua and libs/LibKa0s/Slash.lua differ
```

- `Slash.lua`: minor 16 -> 17. The shared `profile` verb: the descriptor field `profiles`, the
  instance members `CliProfile(rest)` and `ProfileSwitch(name)`, the lib-level
  `lib.ProfileNames(store)` and nine `PROFILE_*` keys in `lib.STRINGS`
  (`../LibKa0s/docs/api/Slash/version-17-docs.md`). The one removed line is the `MINOR` constant.
- `profile` is not added to `lib.LIVE_VERBS` and is not reserved. No `NEEDS_*` floor moves.

Nothing is `Only in libs/LibKa0s`, so nothing is deleted.

## tests/_kit

`testkit/` is identical at v1.62.0 and v1.63.0 (kit revision 31, both diffs empty before the copy).
The copy is still taken whole, so both payloads move together in one commit as the kit-pairing rule
asks.

## Majors this addon consumes

Bus, Compat, Core, DebugLog, Env, Item, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Slash,
Widgets. The only one whose file moved is Slash (`settings/Slash.lua:220`).

## Blockers (contract changes under an unchanged signature)

None. Every Slash hunk after the `MINOR` line is an insertion (`git diff -U0 libs/LibKa0s/Slash.lua`),
and version 17's Compatibility section states no runtime behavior moves for a host that passes no
`profiles` and registers no `profile` row.

The one gate the release can move is the kit's by-name `T.assertSurfaceParity(<stub>,
"LibKa0s-Slash-1.0", ignore)`, which compares a stub against the live dispatcher instance and goes red
when the stub lacks `CliProfile` and `ProfileSwitch`. BankLedger's Slash parity case uses the
four-argument form over two tables it builds itself (`tests/test_surface_parity.lua`), so the copy
alone leaves it green, as the library measured on 2026-09-29.
