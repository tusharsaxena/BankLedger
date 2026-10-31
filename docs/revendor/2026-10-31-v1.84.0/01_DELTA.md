Delta: LibKa0s v1.83.0 -> v1.84.0

Run 2026-10-31, item BL-RV of the findings remediation (Ka0sAddonsCommonTasks
`docs/2026-10-31-FINDINGS_REMEDIATION/M2_LIBRARY_RELEASE.md`), on branch
`feat/2026-10-31-findings-remediation`. Tag v1.84.0 is local (`e917ccd`, `ls-remote` prints nothing).

## Pre-flight (Step 0, this addon only)

The other addons belong to other agents in this run, so the roster table was not printed.

    newest single-tag bundle: 2026-10-24-v1.77.0, line 1 base v1.76.0
    provenance before the commit that rolled to v1.77.0 (f1d1a92): v1.76.0    ok

## 3a. Claimed version

    grep -n '[Bb]undles' CLAUDE.md   ->  Bundles [LibKa0s](...) v1.83.0 (MIT).
    c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   ->  ac7a3e8, whose line names v1.83.0

The two agree. The base is v1.83.0. Range: `git -C ../LibKa0s log --oneline v1.83.0..v1.84.0` (26
commits); `git diff --stat` 145 files.

## 3b. Actual version

`diff -rq --strip-trailing-cr` of the v1.83.0 extract against `libs/LibKa0s` and `tests/_kit`, less
the undeclared icons: no difference, in content or in bytes. The line and the minors agree.

## 3c. Per-file minor delta

Loop over `LibKa0s.xml` at v1.84.0, old and new constants; files that did not move are left out.

| File | Old | New |
|---|---|---|
| `Schema.lua` | 2 | 3 |
| `Charts.lua` | new | 1 |
| `ChartsRender.lua` | new | 1 |
| `Skin.lua` | 10 | 11 |
| `SkinOwnerTokens.lua` | new | 1 |
| `SkinDefs.lua` | 18 | 19 |
| `SkinDefsOthers.lua` | new | 1 |
| `WidgetsDragHandle.lua` | 8 | 10 |
| `DebugLogDiagnostics.lua` | 5 | 6 |
| `Slash.lua` | 20 | 21 |
| `Options.lua` | 34 | 35 |
| `OptionsWidgets.lua` | 38 | 40 |
| `OptionsFlow.lua` | new | 2 |
| `OptionsIds.lua` | 5 | 6 |
| `OptionsIdSuggest.lua` | new | 1 |
| `OptionsTabs.lua` | 11 | 13 |
| `OptionsTabbed.lua` | new | 2 |
| `OptionsCompose.lua` | 14 | 15 |
| `OptionsSkinPicker.lua` | 4 | 5 |
| `OptionsSkinPickerRows.lua` | new | 1 |
| `SimPanel.lua` | 8 | 9 |
| `SimPanelRender.lua` | new | 1 |

No file is behind another, so there is no cross-major skew. Nine files are new (`Charts`,
`ChartsRender`, `OptionsFlow`, `OptionsIdSuggest`, `OptionsSkinPickerRows`, `OptionsTabbed`,
`SimPanelRender`, `SkinDefsOthers`, `SkinOwnerTokens`). `git diff --name-status` shows no removal in
either payload.

## 3d. Both diffs

Clean before the copy apart from `Only in` lines under `media/icons`, the declaration at work.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside libs and tests: Core, DebugLog,
Launcher, Lifecycle, Item, Bus, Env, Pool, Skin, Sim, Media, Widgets, Options, Slash, Schema. Not
looked up: Charts (new), Compat (read through the seam the library's own files use), Perf (settled,
no combat path), Glow, Toast.

## 3f. Kit revision

46 -> 47 (`Kit.VERSION`, new `testkit/mock_ace.lua`). Both payloads move together, as the pairing
rule asks.

## 3g. Contract delta

Majors both moved and consumed: Options, Skin, Sim, Widgets, Schema, Slash, DebugLog. The API
documents at each new version were read against their `Supersedes` rows.

- Options 35.4.40.2.6.1.7.13.2.3.15.9.4.3.6.5.5.1.1.1: additive, plus pure moves. No sentence under
  an existing surface tightens. `grep -rn '__Attach' --exclude-dir=libs --exclude-dir=_kit` finds no
  host site. The one owed item is below.
- Skin 11.1.19.1.13.7.11.2.5, Sim 2.3.9.1: pure moves.
- Widgets 17.3.10.5.5.2: the fit changes reach `DragHandle` only. BankLedger has no DragHandle.
- Schema 3, Slash 21.2: a `note` row. BankLedger declares none.
- DebugLog 22.6.1.2: the identity header names Charts.

### Blockers

`O.PositionBlock` is a new public member of the Options instance, so the degradation stub in
`settings/OptionsSetup.lua` owes it (`docs/api/Options/version-35...-docs.md`, "What changed at this
version"; `tests/test_surface_parity.lua` enforces it). Fixed in the re-vendor commit, beside the
other unreached composers. Nothing here needs a decision.

## 3h. Tags vendored and unrecorded

The listing from the skill prints nothing, so no span bundle is written.

## 3i. Icon declaration

Kept: `chevron-down, chevron-right, clear, close, confirm, copy, export, eye, info, search, settings,
sort-down, sort-up`. Nothing in this range draws a new name in this addon. No provenance split is
needed. As before, the gate cannot see a name the host forgot to declare; the owner's smoke is the
backstop.

## 3j. Tests that assume the whole icon folder

`tests/test_mediasetup.lua:154` and `tests/test_libka0s.lua:733` open declared names only. No blocker.
