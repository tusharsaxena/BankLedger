# Summary (BankLedger), LibKa0s v1.85.0 -> v1.89.0

- **Tag moved** v1.85.0 -> v1.89.0. Base from the provenance line (`CLAUDE.md:48`), cross-checked
  against the last payload commit `572205b` and the v1.85.0 payload; Step 0 row `ok`, no base correction.
- **Minors:** Toast 3 -> 4, Widgets 22 -> 23, DebugLogDiagnostics 6 -> 7, and the new major
  `LibKa0s-IconBrowser-1.0` (IconBrowserSources 1, IconBrowserWindow 1, IconBrowser 1). Kit 50 -> 51,
  copied in the same commit (pairing rule). No skew, no `NEEDS_*` floor rose.
- **Span bundle:** none (3h printed nothing: 64 vendored, 64 recorded).
- **Delivered free (class A):** the diagnostics header names IconBrowser; flat menus and `W.Dropdown`
  unchanged under Widgets 23; kit 51's CallbackHandler unregister guard.
- **Contract blockers (3g, 3j):** none. No `__Attach*` site; no Toast stub to extend; no test assumes
  the whole icon folder.
- **Icons:** `LibKa0s icons:` line kept as is (17 names). The tag's `tools/prune-icons.lua` printed
  `17 icon(s) declared; kept 18 file(s), removed 5822` (Open Iconic 207, Phosphor 1435, Game-icons 4180;
  the 18th kept file is `LICENSE-open-iconic.txt`). After the prune, `media/icons/` is byte-identical to
  what v1.85.0 left. No provenance split.
- **README credits:** unchanged (the shipped set is still Open Iconic only). No dead stub mirror
  (`__releaseChrome` appears only in a history comment, `settings/OptionsSetup.lua:190`).
- **Adopted:** nothing in this repo (the plan names no `V89A-*` for BankLedger).
- **Declined / filed:** nothing filed. Cascading-menu fields not applicable (no `W.ContextMenu` site),
  Toast 4 not applicable (no Toast host), IconBrowser settled (no icon chooser), Perf settled earlier.
- **Unreached:** none.
- **Gate** (both through `~/.claude/dev-copilot/bin/ka0s-bounded`): `luacheck .` 0 warnings / 0 errors
  in 121 files (`.luacheckrc` excludes `libs/` and `tests/_kit/`; the seams are in `core/`, `modules/`,
  `settings/`, all checked). `lua tests/run.lua` 1657 passed, 0 failed, 1 skipped, 1658 total; the
  skip is the diagnostics opt-out case, which this addon does not take. `test_vendor_sync` passes both
  payload cases. Largest own file `modules/Browser.lua` 1199 lines (cap 1500).
