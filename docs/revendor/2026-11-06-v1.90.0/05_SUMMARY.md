# Summary (BankLedger), LibKa0s v1.89.0 -> v1.90.0

- **Tag moved** v1.89.0 -> v1.90.0 (local tag `b2fce60`, not pushed; a new re-vendor, not a refresh).
  Base from the provenance line (`CLAUDE.md:48`), cross-checked against the last payload commit
  `da7b75a` and the v1.89.0 payload; Step 0 row `ok`, no base correction.
- **Minors:** Core 15 -> 16, Skin 16 -> 17, SkinPaint 18 -> 19, SkinPaintExtras 17 -> 18, Widgets
  23 -> 24, WidgetsAutocomplete 7 -> 8, OptionsAppearance 6 -> 7. Kit 51 -> 51 (copied in the same
  commit, pairing rule). No skew, no `NEEDS_*` floor rose, no file removed upstream.
- **Span bundle:** none (3h printed nothing).
- **Delivered free (class A):** the one-physical-pixel edge on `W.Dropdown` (`modules/Browser.lua:179`),
  `W.SearchBox` (`modules/Browser.lua:200`) and the shared menu (SF1-L1); a Skin-tab copy or Apply to
  all run from BankLedger now leaves a `keepScope` host's Scope alone (SF1-L2).
- **Contract blockers (3g, 3j):** none. No `__Attach*` site, no stub owes a new member, no test pins
  an old minor or an edge size, no test assumes the whole icon folder.
- **Icons:** `LibKa0s icons:` line kept as is (17 names). The tag's `tools/prune-icons.lua` printed
  `17 icon(s) declared; kept 18 file(s), removed 5822`; `media/icons/` is byte-identical to what
  v1.89.0 left. No provenance split.
- **README credits:** unchanged (Open Iconic only, still). No dead stub mirror.
- **Adopted:** nothing (`keepScope` is the Skin Tester's alone, per SF1).
- **Declined / filed:** nothing filed. `keepScope` not applicable; IconBrowser and Perf settled.
- **Unreached:** none.
- **Gate** (both through `~/.claude/dev-copilot/bin/ka0s-bounded`): `luacheck .` 0 warnings / 0 errors
  in 121 files (`.luacheckrc` excludes `libs/` and `tests/_kit/`; the seams in `core/`, `modules/`,
  `settings/` are checked). `lua tests/run.lua` 1657 passed, 0 failed, 1 skipped, 1658 total (the skip
  is the diagnostics opt-out case this addon does not take); `test_vendor_sync` passes. No own code
  changed, so the 1500-line cap and CCN 15 stand as at v1.89.0.
- **SF1 header ruling:** BankLedger's two column-header rows (`modules/LedgerTable.lua:706`,
  `modules/SessionWindow.lua:593`) are `NS.Skin.SortHeaderBar(header)` alone, the same call
  LootHistory makes (`modules/BrowserTable.lua:672`), with no divider directly above or below. No
  `SF1-BL-HDR` fix is owed.
