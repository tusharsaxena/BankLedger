# Refresh 1: LibKa0s v1.84.0 re-cut

Run 2026-11-01, items M3-RV and M3-MEDIA of the findings remediation. The tag was moved locally on the
owner's ruling of 2026-11-01 that `Ka0sMedia_*` is the only media picker (LibKa0s#73), before any push:
`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing.

- Old `v1.84.0^{commit}`: `e917ccd`.
- New `v1.84.0^{commit}`: `7a8bc0f133ed118d2c79c7c5288b97964e24fae5`.
- Kit revision: 47 on both; `tests/_kit/` did not change.

| File | Old | New |
|---|---|---|
| SkinAce.lua | ACE_MINOR 5 | 6 |
| Options.lua | MINOR 35 | 36 |
| OptionsWidgets.lua | WIDGETS_MINOR 40 | 41 |
| OptionsCompose.lua | COMPOSE_MINOR 15 | 16 |
| OptionsScroll.lua | SCROLL_MINOR 9 | 10 |
| OptionsMedia.lua | MEDIA_MINOR 1 | 2 |

Content diffs were empty before the prune, and no file was deleted against them. Prune: 13 icons
declared, kept 14 files, removed 5826. Icon line unchanged.

What the consumer owed: nothing in code. A repo-wide grep found no `LSM30_*` name, no
`AceGUIWidgetLSMlists` and no `__PatchLSM30Border` in authored code or tests, and no
AceGUI-3.0-SharedMediaWidgets folder, `.toc` line, `.pkgmeta` external or `DEPENDENCIES.md` entry.
The matches left are frozen bundles (`docs/audits/`, `docs/revendor/2026-09-12-v1.33.0/`).
LibSharedMedia-3.0 stays; the pickers read it. The Skin tab's two rows take their type from
`lib.__MediaWidgetType`. The panel has no border row, so SKIN-34 checks Font and Texture.

One citation moved: `tests/test_surface_parity.lua`, the `Options.lua` line for `__print`.

Gate before the commit: `lua tests/run.lua` 1534 passed, 0 failed, 1 skipped (1535);
`ka0s-bounded luacheck .` 0 / 0 in 117 files. The count did not move, so the README badge and
`docs/test-cases.md` are unchanged.
