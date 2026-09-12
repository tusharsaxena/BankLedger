# 01 — Delta: LibKa0s v1.29.0 → v1.30.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.30.0 LibKa0s testkit | tar -x -C <scratch>/`. This addon's
`tests/test_vendor_sync.lua` resolves the tag its provenance line names and compares
both payloads against it file by file, so a copy from a dirty checkout passes a local
`diff -r` and then fails the gate. The tag is `e369e0f` on the library's
`fix/kit-27-30` branch. It is not merged to the library's `master`, which does not matter
here, because the gate compares against the tag.

```
git -C ../LibKa0s tag --sort=-v:refname | head -1      # v1.30.0
git -C ../LibKa0s log --oneline v1.29.0..v1.30.0
  e369e0f The v1.30.0 release record, re-taken on the review-fixed tree
  e5f6906 Kit 16 review: double release raises, the release wipe, RegisterEvent validates, a per-build event registry
  aaef20a The v1.30.0 release record
  7aaf1fe Kit 16: AceGUI:Release, AceEvent's event half on an embed, Printf, and the runner's mode in every consumer
```

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' BankLedger/CLAUDE.md
```

> 46: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.29.0** (MIT).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR|COMPOSE_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, `COMPOSE_MINOR` 3, `SCROLL_MINOR` 3,
`WIDGETS_MINOR` 14, Perf 10, `PANEL_MINOR` 5, Pool 3, Slash 7, Widgets 9. These are exactly the minors
the v1.29.0 changelog block names. The line and the bytes **agreed**. Nothing had been rolled without
its payload, in either direction.

## 3c — Per-file minor delta

Read from the tag's `LibKa0s/LibKa0s.xml` (14 files), not from a fixed table.

| File | Constant | v1.29.0 | v1.30.0 |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | 7 |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | 1 |
| `Media.lua` | `MINOR` | 3 | 3 |
| `Widgets.lua` | `MINOR` | 9 | 9 |
| `DebugLog.lua` | `MINOR` | 12 | 12 |
| `Slash.lua` | `MINOR` | 7 | 7 |
| `Options.lua` | `MINOR` | 15 | 15 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 14 | 14 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 3 | 3 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | 3 |
| `Perf.lua` | `MINOR` | 10 | 10 |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

**No file in `LibKa0s/` moved**, so LibStub sees no difference. **No cross-major skew.** The release
is kit revision 16 alone.

## 3d — Both diffs, both directions

```
diff -r --strip-trailing-cr <tag>/LibKa0s BankLedger/libs/LibKa0s   # empty
diff -rq                    <tag>/LibKa0s BankLedger/libs/LibKa0s   # empty
diff -rq --strip-trailing-cr <tag>/testkit BankLedger/tests/_kit    # 4 files differ
diff -rq                     <tag>/testkit BankLedger/tests/_kit    # the same 4 files
```

The kit's content diff, as changed-line counts (`diff --strip-trailing-cr | grep -c '^[<>]'`):

| File | Changed lines |
|---|---|
| `README.md` | 33 |
| `framework.lua` | 2 (`Kit.VERSION` 15 → 16) |
| `mock_base.lua` | 208 (#27 `AceGUI:Release`, #29 AceEvent event half on an embed, #30 `Printf`) |
| `vendor_sync.lua` | 52 (#28, the runner-mode case) |

Content is dirty on the kit, so this is a real update, not line-ending drift. There is no
`Only in BankLedger/...` line in either payload, so nothing was removed upstream.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

| Major | Lookup sites |
|---|---|
| Core | `core/CoreSetup.lua:37` |
| Env | `core/EnvSetup.lua:39` |
| Pool | `core/PoolSetup.lua:20` |
| Item | `core/ItemSetup.lua:26` |
| Media | `core/MediaSetup.lua:45` |
| DebugLog | `core/DebugLogSetup.lua:21` |
| Widgets | `modules/Browser.lua:5`, `modules/Export.lua:14` |
| Options | `settings/OptionsSetup.lua:26` |
| Slash | `settings/Slash.lua:133` |
| Perf | **none**. This is the settled decline: the `performance-§12` row in `docs/ARCHITECTURE.md` → Documented deviations. |

This release moved no major, so the map is the one the 2026-09-03 bundle recorded.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua BankLedger/tests/_kit/framework.lua
  <tag>/testkit/framework.lua:20:Kit.VERSION = 16
  tests/_kit/framework.lua:20:Kit.VERSION = 15
```

Kit revision **15 → 16**. The pairing rule (any LibKa0s ≥ v1.9.0 takes kit revision ≥ 11 in the
same commit) holds by construction, because both payloads are copied whole in one commit. Here the
kit is the **only** thing that moved.

Adoption note from the tag's `CHANGELOG.md`, which was measured on a fresh clone: BankLedger goes from
849 to 850, a single added case, `the automated-test runner is recorded executable (100755)`.
`git ls-files -s tests/_kit/run-automated-tests.sh` → `100755 f6cd8b0…`, so the new case should pass.
