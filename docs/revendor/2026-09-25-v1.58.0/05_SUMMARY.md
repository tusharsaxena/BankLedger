# 05 — Summary: LibKa0s v1.57.0 -> v1.58.0

Plan item M6-BL, 2026-09-25, branch `feat/2026-09-23-review-audit-remediation`. Written by hand, in
the shape M5-BL used for `docs/revendor/2026-09-24-v1.57.0/`. Nothing pushed, and the addon version
is not bumped.

## The tag, and the per-file minors

`v1.57.0` -> `v1.58.0` (tag object `93cf3ad`, commit `34931c9`). The base comes from the `CLAUDE.md`
provenance line (v1.57.0), and the payload matched that tag byte for byte before the copy. One file
moves a minor: **Launcher 4**. No file is added or removed, there is no skew, and the kit stays at
revision 26. Detail in `01_DELTA.md`, sections 3c to 3f.

## Delivered on the re-vendor, with nothing asked for

- Left-click on the minimap button (or a broker display's row) opens the settings panel, in either
  state (`launcher-§2`, standard v2.67.0).
- The tooltip's hints read `Left-click: Open settings` and `Right-click: Options menu`.

## Contract blockers

None. `onClick` and `disabledLine` stop being read under an unchanged `New` signature, which on the
copy alone left the ledger toggle unreachable from the button and both buttons opening the panel.
Fixed in the same item (`01_DELTA.md` 3g).

## Adopted

The M6 row's descriptor pairs, in `core/LauncherSetup.lua`, each toggle the `NS.COMMANDS` handler
of a slash verb, looked up at click time: `setEnabled` (`/bl enable` / `/bl disable`), `toggleLock`
(`/bl set settings.locked <bool>`, since there is no `lock` verb), `toggleTestMode` (`/bl test`),
`toggleWindow` (`/bl toggle`), plus `isWindowShown`. `onClick`, `leftClickLabel` and `disabledLine`
are removed. The menu reads Enabled, Locked, Test mode, Show window, which is the row the standard's
`ADDONS.md` records for this addon.

Tests, through `tests/menu_mock.lua` (a fake `MenuUtil` modeled on the library's repo-local
`tests/mock_menu.lua`): in `tests/test_launcher.lua`, left-click opens the panel only; the menu's
title and four entries; the no-`MenuUtil` fallback to the panel; each entry and its slash verb reach
one spy; the Locked entry really stores `settings.locked`; the checkmarks read live state; a raising
handler is reported; the descriptor passes every pair and no retired field. In
`tests/test_disabled.lua`: while disabled the left click opens the panel and prints nothing, the menu
grays Locked / Test mode / Show window with `(enable the addon first)`, a forced click on a grayed
entry reaches no handler and writes nothing, and Enabled re-enables; the disabled tooltip shows the
fixed hints.

## Gates at the M6-BL commit

| Suite | Result |
|---|---|
| `ka0s-bounded luacheck .` | 0 warnings / 0 errors in 73 files |
| `ka0s-bounded lua5.1 tests/run.lua` | 1068 passed, 0 failed, 0 skipped, 1068 total |
| `ka0s-bounded lizard` (libs and kit excluded, `-C 15 -w`) | no function above CCN 15 |
| authored `.lua` size | largest `modules/Browser.lua`, 1221 lines (cap 1500) |
| `diff -r` of both payloads against the tag | empty |

## Open

- The owner re-checks the minimap buttons in-client after M6 (smoke S-1 steps 4 to 7, and the
  disabled-state step 5 of the stand-down section).
