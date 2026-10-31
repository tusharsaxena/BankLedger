# Refresh 2: LibKa0s v1.84.0 re-cut

Run 2026-11-01, item M4-RV of the findings remediation. The tag was moved locally on the owner's ruling
of 2026-11-01 that `__PatchLSM30Border` goes with no stub, before any push:
`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing.

- Old `v1.84.0^{commit}`: `7a8bc0f133ed118d2c79c7c5288b97964e24fae5`.
- New `v1.84.0^{commit}`: `b5229b876e803768322fb4d8c66be69f01c8e4a1`.
- Kit revision: 47 on both; `tests/_kit/` did not change.

| File | Old | New |
|---|---|---|
| Options.lua | MINOR 36 | 37 |
| OptionsDrawer.lua | DRAWER_MINOR 3 | 4 |
| OptionsMedia.lua | MEDIA_MINOR 2 | 3 |

Content diffs were empty before the prune, and no file was deleted against them. Prune: 13 icons
declared, kept 14 files, removed 5826. Icon line unchanged.

What the consumer owed: nothing in code. `grep -rn __PatchLSM30Border . --exclude-dir=.git` finds no call
in authored code or tests. Before this copy the name appeared only in the payload and in Refresh 1.
No test existed for it, no stub or guard was added, and no surface or pinned minor needed moving.

One citation moved: `tests/test_surface_parity.lua`, the `Options.lua` line for `__print` (470 to 462).

Gate before the commit: `ka0s-bounded lua tests/run.lua` 1534 passed, 0 failed, 1 skipped (1535);
`ka0s-bounded luacheck .` 0 / 0 in 117 files. The count did not move, so the README badge and
`docs/test-cases.md` are unchanged.
