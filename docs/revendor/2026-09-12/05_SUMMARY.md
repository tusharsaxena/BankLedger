# 05 — Summary: LibKa0s v1.29.0 → v1.30.0

## The move

| | |
|---|---|
| From | v1.29.0 |
| To | **v1.30.0** (tag `e369e0f`) |
| Files that moved in `libs/LibKa0s/` | **none**. Every minor is the one v1.29.0 shipped (01_DELTA §3c). |
| Kit revision | **15 → 16**: `framework.lua`, `mock_base.lua`, `vendor_sync.lua`, `README.md` |
| Files removed upstream | none |
| Cross-major skew found | none |

## What reached this addon for free

- **#28:** the vendored-payload gate now also asserts that `tests/_kit/run-automated-tests.sh` is
  recorded `100755` (`automated-tests-§2`). It passes. That case is the whole 849 → 850 move, and
  `docs/test-cases.md` and the README `[tests]` badge moved with it in this commit.
- **#27:** the kit's AceGUI factory can now `Release` a widget. It reaches this harness because
  `tests/wow_mock.lua` wraps the kit's `Create` instead of replacing it. Nothing calls it yet.

## What was adopted

Nothing. No local shim was a duplicate of a kit 16 contract that the kit can actually reach here.
There is no `04_EXECUTION_PLAN.md` in this bundle because nothing was implemented.

## What was declined

Both are **not now**, both for the same reason, and neither was filed. They go back to the owner as
proposed issues (03_DECISIONS).

- **#29:** the event half on an embed. The local AceEvent Embed (`tests/wow_mock.lua:712-719`)
  replaces the kit's wholesale, so its no-op event lines (:714-716) are not redundant with kit 16.
- **#30:** `Printf`. The local `NewAddon` (`tests/wow_mock.lua:678-711`) replaces the kit's
  wholesale, so the kit's `Printf` stamp cannot reach. There is no `NS.Printf` in the addon, so nothing
  is exposed today.

## Skipped or unreached

Nothing.

## Gates

| Gate | Result |
|---|---|
| `luacheck .` | **0 warnings / 0 errors** in 61 files |
| `lua tests/run.lua` | **850 passed, 0 failed, 0 skipped**, 850 total (baseline on master: 849/849) |
| `tests/test_vendor_sync.lua` | green, 3 cases, including the new runner-mode case. It resolves the tag named in `CLAUDE.md` and compares **both** payloads against it. |
| `tests/_kit/test_eol.lua` | green, after the LF files the copy wrote were re-checked-out through the CRLF filter |

`luacheck`'s figure is scoped by `.luacheckrc`'s `exclude_files`, which excludes `libs/` and
`tests/_kit/`. So a clean run says the **host** (including `tests/wow_mock.lua`) is clean, not that the
payload was checked. The payload's own gate is upstream.

## Not pushed

Committed only, on `chore/libka0s-1.30.0-arch5`. Pushing is `/wow-addon:finalize`'s job.
