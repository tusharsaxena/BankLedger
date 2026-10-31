Delta: LibKa0s v1.77.0 -> v1.83.0 (span: v1.80.0 v1.81.0 v1.82.0 v1.83.0)

# 01 — Delta, consolidated span (BankLedger)

Written 2026-10-31 by item FX-BL-DOCS of the cross-repo findings remediation
(Ka0sAddonsCommonTasks `docs/2026-10-31-FINDINGS_REMEDIATION/`). Four tags were vendored by the
skinning runs inside their own items, and none got a bundle:

- v1.80.0, vendored by `d66414f` "BL-RV: Re-vendor LibKa0s v1.80.0 and meet what a consumer owes"
  (kit revision 44; v1.78.0 and v1.79.0 were never vendored here, their changes arrive with this tag);
- v1.81.0, vendored by `374a315` "BL-RV: Re-vendor LibKa0s v1.81.0 and meet what a consumer owes"
  (kit revision 44);
- v1.82.0, vendored by `e5deb64` "BL-01: Re-vendor LibKa0s v1.82.0 from the local tag" (kit
  revision 45);
- v1.83.0, vendored by `9d2374a` "BL-F01: Re-vendor LibKa0s v1.83.0 and take its faces and outline
  default" (kit revision 46), then taken again at its re-cuts by `5d93251` and `ac7a3e8`.

## The listing (the re-vendor check of `AUDIT.md`, Step 3h of `/dev-copilot:wow-revendor-libka0s`)

```sh
git log --format=%h -G'Bundles \[LibKa0s' -- CLAUDE.md      # the provenance line at each roll
ls -1 docs/revendor                                         # the tags each bundle names
```

Vendored tags with no bundle, before this one:

```
v1.80.0
v1.81.0
v1.82.0
v1.83.0
```

```sh
git -C ../LibKa0s diff --stat v1.77.0 v1.83.0 -- LibKa0s testkit | tail -1
```

```
99 files changed, 16652 insertions(+), 972 deletions(-)
```

New files in the two payloads across the span, from `git diff --name-status 81d2e73 ac7a3e8 -- libs/LibKa0s tests/_kit`:
`DebugLogWindow.lua`, `OptionsAppearance.lua`, `OptionsMedia.lua`, `OptionsSkinPicker.lua`,
`OptionsSwitch.lua`, `Skin.lua`, `SkinAce.lua`, `SkinDefs.lua`, `SkinEUI.lua`, `SkinPaint.lua`,
`SkinPaintControls.lua`, `SkinPaintExtras.lua`, `Toast.lua` and `WidgetsCopyWindow.lua` under
`libs/LibKa0s/`, and `glyphs.lua` and `mock_paint.lua` under `tests/_kit/`. Each commit message
above carries its own per-module minors.
