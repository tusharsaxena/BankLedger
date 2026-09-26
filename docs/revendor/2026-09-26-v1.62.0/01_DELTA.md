# LibKa0s v1.61.0 -> v1.62.0: the delta (BankLedger)

Copied from the tag `v1.62.0` (`5dc9f5d`, a local tag at the time of this copy), never from a working tree.

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
Files <tag>/LibKa0s/Options.lua and libs/LibKa0s/Options.lua differ
Only in <tag>/LibKa0s: OptionsCombat.lua
Only in <tag>/LibKa0s: OptionsIdList.lua
Only in <tag>/LibKa0s: OptionsIds.lua
Only in <tag>/LibKa0s: OptionsRegistry.lua
Files <tag>/LibKa0s/OptionsTabs.lua and libs/LibKa0s/OptionsTabs.lua differ
Files <tag>/LibKa0s/OptionsWidgets.lua and libs/LibKa0s/OptionsWidgets.lua differ
```

- `Options.lua`: minor 25 -> 26. The page registry and the registration park move out to `OptionsRegistry.lua`.
- `OptionsWidgets.lua`: minor 31 -> 32. The id surface moves out to `OptionsIds.lua` and `OptionsIdList.lua` (LibKa0s #32).
- `OptionsTabs.lua`: minor 5 -> 6. The combat lock's page chrome moves out to `OptionsCombat.lua`.
- New, each minor 1: `OptionsRegistry.lua`, `OptionsIds.lua`, `OptionsIdList.lua`, `OptionsCombat.lua`.
- `LibKa0s.xml`: loads the four new files beside the files they left.
- The Options major key moves to `26.1.32.1.1.6.1.7.4.1`. Every other file is unchanged.

Every move is a peel: no member, descriptor field or row field changes, and no `NEEDS_*` floor rises.
Nothing is `Only in libs/LibKa0s`, so nothing is deleted.

## tests/_kit

Kit revision 27 -> 31 (revisions 28 to 31, of which 28, 29 and 30 never shipped on their own):

```
Files <tag>/testkit/README.md and tests/_kit/README.md differ
Files <tag>/testkit/framework.lua and tests/_kit/framework.lua differ
Only in <tag>/testkit: inventory.lua
Only in <tag>/testkit: prose_coverage.lua
Only in <tag>/testkit: prose_selftests.lua
Files <tag>/testkit/run-automated-tests.sh and tests/_kit/run-automated-tests.sh differ
Files <tag>/testkit/test_layout_cap.lua and tests/_kit/test_layout_cap.lua differ
Files <tag>/testkit/test_prose.lua and tests/_kit/test_prose.lua differ
```

- 28: the suite inventory leaves `framework.lua` for `inventory.lua`.
- 29: the prose gate peels into `prose_coverage.lua` and `prose_selftests.lua` (cases register under `test_prose` with the same names).
- 30: an empty `RESULTS.md` watch-list table prints `None.` (ATS-20).
- 31: generated files that `Kit.layoutCap.exempt` covers leave the band table (ATS-21).

Both payloads move together in one commit, as the kit-pairing rule asks.

## Majors this addon consumes

Bus, Compat, Core, DebugLog, Env, Item, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Slash, Widgets.
The only one whose files moved is Options, and its members did not change.

## Blockers (contract changes under an unchanged signature)

None. The release moves code between files and changes no behavior (LibKa0s `CHANGELOG.md`, v1.62.0).
`tests/run.lua` derives the library load list from `libs/LibKa0s/LibKa0s.xml`, so the four new files load
with no host change, and the library-absent stubs owe no new member.
