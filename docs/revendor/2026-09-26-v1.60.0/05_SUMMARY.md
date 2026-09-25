# 05 — Summary: LibKa0s v1.58.0 -> v1.60.0

Plan item DR-BL-01 of the 2026-09-25 diagnostics rollout, 2026-09-26, branch
`feat/2026-09-25-diagnostics-rollout`. Nothing pushed, and the addon version is not bumped.

## The tag, and the per-file minors

`v1.58.0` -> `v1.60.0` (tag object `ac59511`, commit `bed0eb1`), across the unvendored v1.59.0. The
base comes from the `CLAUDE.md` provenance line, and the payload matched v1.58.0 byte for byte before
the copy. Four files move: **DebugLog 14**, **DebugLogDiagnostics 1** (new file, 22 in the XML),
**Slash 16**, **WidgetsDragHandle 3**. No file is removed, there is no skew, and the kit moves from
revision 26 to **27** in the same commit. Detail in `01_DELTA.md`.

## Delivered on the re-vendor, with nothing asked for

- The debug console keeps **3000** lines (was 1500), and the Copy box with it.
- The hand-set copy-timing switch `lib.TIME_COPY`.
- `diagnostics` in the library's live set, inherited by the live dispatcher (no `liveVerbs` passed).

## Contract blockers, fixed in this commit

1. The library-absent DebugLog stub gains `RunDiagnostics` (the collection's placeholder
   `/bl diagnostics is unavailable: the LibKa0s library did not load.`, nothing written, returns 0),
   `BuildDiagnostics` (the empty report shape) and `DebugVerb` (claims no word). Without them the
   DebugLog surface-parity case goes red at the copy (`version-14.1-docs.md` *Compatibility*).
2. The degraded Slash dispatcher's literal live list (`settings/Slash.lua`) gains `diagnostics`
   (`version-16-docs.md`: a literal array does not inherit the verb).
3. The runner declares the kit's new `test_diagnostics_contract` suite, which the kit's inventory
   check requires; it registers one declared skip until DR-BL-03 sets `Kit.diagnostics`.

New cases in `tests/test_libka0s.lua`: the stub's placeholder, count, empty build and debug word;
and the degraded gate letting every verb of the live `lib.LIVE_VERBS` through while disabled, with a
feature verb still refused.

## Adopted

Nothing in this commit. The diagnostics helper and the `diagnostics` verb are adopted in DR-BL-03
(`03_DECISIONS.md`).

## Declined

Nothing. No issue filed (the plan decides every candidate).

## Gates at the DR-BL-01 commit

| Suite | Result |
|---|---|
| `ka0s-bounded luacheck .` | 0 warnings / 0 errors in 73 files |
| `ka0s-bounded lua5.1 tests/run.lua` | 1070 passed, 0 failed, 1 skipped, 1071 total (the skip is the kit's diagnostics contract, declared until DR-BL-03) |
| `ka0s-bounded lizard` (libs and kit excluded, `-C 15 -w`) | no function above CCN 15 |
| authored `.lua` size | largest `modules/Browser.lua`, 1221 lines (cap 1500); `tests/test_libka0s.lua` now 1020 |
| `diff -r` of both payloads against the tag | empty |

## Left for later items

- `docs/smoke-tests.md:391`'s `N / 1500 lines` counter and the other buffer lines are DR-BL-05's.
- The README badge counts passes (testing-§5): 1070/1070.
