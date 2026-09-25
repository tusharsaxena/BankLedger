# 05 — Summary: LibKa0s v1.56.0 -> v1.57.0

Plan item M5-BL, 2026-09-24, branch `feat/2026-09-23-review-audit-remediation`. Written by hand, in
the shape RV-BL used for `docs/revendor/2026-09-23-v1.56.0/`. Nothing pushed, and the addon version
is not bumped.

## The tag, and the per-file minors

`v1.56.0` -> `v1.57.0` (tag object `d03e836`, commit `aa37bc9`). The base comes from the `CLAUDE.md`
provenance line (v1.56.0), and the payload matched that tag byte for byte before the copy. One file
moves a minor: **Launcher 3**. No file is added or removed, there is no skew, and the kit stays at
revision 26. Detail in `01_DELTA.md`, sections 3c to 3f.

## Delivered on the re-vendor, with nothing asked for

- The minimap button and any broker display show the library's status tooltip on every hover,
  **including while the addon is disabled**: title and version, `Enabled`, the host's lines, and the
  two click hints (`launcher-§1`, standard v2.66.0).

## Contract blockers

None. `onTooltipShow` changed meaning under an unchanged signature, which on the copy alone would
have drawn this addon's title and click hints a second time (anti-pattern #89). Fixed in the same
item (`01_DELTA.md` 3g).

## Adopted

The M5 row's descriptor fields, in `core/LauncherSetup.lua`: `version` (`NS.Version`), `isLocked`
(the stored `settings.locked`), `isTestMode` (`LT:IsTestMode`), `leftClickLabel`
(`NS.L["Toggle ledger window"]`). The host hook now draws only the live movement count. No `slash`
field: the command is read out of `disabledLine()`.

Tests: three cases in `tests/test_launcher.lua` (the four fields are passed; the exact seven-line
tooltip in the enabled state; Locked and Test mode follow the panel's own switches on every show),
one in `tests/test_disabled.lua` (the disabled hover: `Enabled: No`, `Left-click: disabled — /bl
enable`, no chat and no store write). The brand-literal case now asserts the host hook draws no title.

## Gates at the M5-BL commit

| Suite | Result |
|---|---|
| `ka0s-bounded luacheck .` | 0 warnings / 0 errors in 72 files |
| `ka0s-bounded lua5.1 tests/run.lua` | 1064 passed, 0 failed, 0 skipped, 1064 total |
| `ka0s-bounded lizard` (libs and kit excluded, `-C 15 -w`) | no function above CCN 15 |
| authored `.lua` size | largest `modules/Browser.lua`, 1221 lines (cap 1500) |
| `diff -r` of both payloads against the tag | empty |

## Open

- The owner re-runs smoke #1 (minimap buttons) in-client after M5.
