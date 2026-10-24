# Summary: LibKa0s v1.76.0 -> v1.77.0 (BankLedger)

Run 2026-10-24, item BL-RV of the "keybindings (015), settings layout (020), frame strata (030)"
run, on branch `feat/2026-10-24-keybinds-layout-strata`. The addon version was not bumped and
nothing was pushed.

- **Re-vendored**: `libs/LibKa0s/` and `tests/_kit/` were replaced whole from the local tag v1.77.0
  (`78240f7`). The base is v1.76.0, read from the provenance line and confirmed against the
  payload. Core 11 -> 12, DebugLog 20 -> 21, PerfPanel 8 -> 9, SimPanel 5 -> 6, Widgets 14 -> 15,
  WidgetsDragHandle 4 -> 5, WidgetsAutocomplete 2 -> 3, Options 29 -> 30, OptionsIds 2 -> 3,
  OptionsCombat 1 -> 2, OptionsCompose 7 -> 8, and the new `OptionsKeybinds.lua` at 3; kit revision
  41 -> 42 (new `bindings_xml.lua`, `mock_bindings.lua`, `mock_layers.lua`). Both content diffs were
  empty before the prune; no file was deleted against the diffs.
- **Span bundle**: none needed; every vendored tag has a bundle.
- **Icon declaration**: unchanged (eleven Open Iconic names). Prune: `11 icon(s) declared; kept 12
  file(s), removed 5828`. README credits unchanged (Open Iconic is still the only set that ships).
- **Blocker, fixed in this commit**: the Options degradation stub in `settings/OptionsSetup.lua`
  gains `KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED` and `StrataTooltip` as no-ops. The
  surface parity case was red on the copy alone (1 failed) and is green with the stub.
- **Delivered for free**: toplevel debug console and sim panel that re-raise a shown StaticPopup;
  clamped dropdown menu and autocomplete list; the Filters tab's suggestion lists close at combat
  start.
- **Adopted in this commit**: nothing. The Keybindings tab and the kit's binding checks are BL-KB;
  the layering table, `mock_layers.lua` and the accepted strata changes are BL-ZS. `O.StrataTooltip`
  and the DragHandle fields are deferred (run 2026-10-24): BankLedger has no strata row and no
  DragHandle.
- **Declined**: nothing; no issue filed.
- **Gate**: `luacheck .` 0 warnings / 0 errors in 103 files; `lua tests/run.lua` 1428 passed,
  0 failed, 1 skipped (1429); `docs/test-cases.md` regenerated with no change; no authored `.lua`
  file above 1500 lines (largest `tests/test_browser.lua`, 1442).

## Standards reference (same item)

The installed `/dev-copilot:wow-revendor-standards` (dev-copilot 2.4.0) was run for this repo
against standard **v2.88.0, 2026-10-24**, read from the local `../WowAddonStandards` checkout on
`feat/2026-10-24-keybinds-layout-strata` (v2.88.0 is not on the remote yet). Inventory:

- Three-place reference (`documentation-§6`): TOC `## X-Standard:` at `BankLedger.toc:12`, the bare
  README badge at `README.md:6` and `CLAUDE.md`'s `## Standards compliance (read first)` with the
  stop-and-flag directive and the two-way classification. All three present and correct; no edit.
- Retired `§N.M` notation (`grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=.git --exclude-dir=libs
  --exclude-dir=_kit --exclude-dir=audits --exclude-dir=reviews --exclude-dir=automated-tests`): 0.
- `filename-§N` range check against the v2.88.0 section files' `### N.` headings: no unknown file
  and no out-of-range number (the two `filename-§N` hits, `CLAUDE.md:20` and
  `docs/ARCHITECTURE.md:538`, are the template's own placeholder).
- Doc set, gate-statement checkpoints (`docs/testing.md`, `docs/automated-tests/README.md`) and
  `.gitattributes` (CRLF pin, both carve-outs, binaries marked; 0 working-tree stragglers): no
  drift. The `RESULTS.md` lead-in is runner-generated and was not touched. The standard carries no
  quirks catalog section, so there is no vendored block to refresh.

The procedure writes no standard version into a repo file (its Step 5 rule): the reference points
at the live standard, so "to v2.88.0" is this refresh's reading date, recorded here, not a stamp.

## Re-vendor after the tag moved (M3)

Item BL-RV2 of the same run. LK-95 moved the local annotated tag v1.77.0 in `../LibKa0s` to carry
the M3 settings-layout surface, so the payload above was taken again from the moved tag. No new
bundle: this section is the record.

- **Tag**: old target `78240f7b2d69df27b74fc9280cbfbf7b95dd4f1f` (the commit BL-RV vendored), new
  target `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10` (`git -C ../LibKa0s rev-parse v1.77.0^{}`).
  `git -C ../LibKa0s diff --stat 78240f7 afae2f7 -- LibKa0s testkit` names one file.
- **Minors that moved**: OptionsCompose 8 -> 11 (minor 9: MasterControls `notes`,
  `resetPositionTooltip`, `lockIsPreview`, and the alpha row relabeled *Master opacity* with its
  stored leaf unchanged; minor 10: `tooltips` beside `labels` on the group composers; minor 11:
  `O.ResetAllTooltip(tail)`). Every other file's minor is unchanged; test-kit revision stays 42, so
  the CLAUDE.md provenance line (v1.77.0, kit 42) and the icon declaration are unchanged.
- **Copy**: `libs/LibKa0s/` and `tests/_kit/` replaced whole from `git -C ../LibKa0s archive v1.77.0
  LibKa0s testkit tools`; both content diffs empty before the prune; nothing deleted against the
  diffs. Prune: `11 icon(s) declared; kept 12 file(s), removed 5828`. README credits unchanged.
- **Blockers, fixed in this commit**: (1) the kit's surface parity case was red on the copy alone
  (`ResetAllTooltip is missing`); the Options degradation stub in `settings/OptionsSetup.lua` gains
  `ResetAllTooltip` answering an empty string. (2) The relabel is delivered on the copy, so
  `tests/test_panel_filters.lua` asserted a label the composer no longer draws; it now looks up
  *Master opacity*, and `docs/settings-panel.md` names the row by its new label. The owner-marked
  smoke records (PANEL-5, PANEL-18, PANEL-19) keep the words they were passed under.
- **Adopted**: nothing. `notes`, `resetPositionTooltip`, `lockIsPreview`, `tooltips` and
  `O.ResetAllTooltip` are BL-LY's.
- **Standards half**: the `filename-§N` range check over every cite in the repo (80 distinct)
  against the run branch's section files after WS-95 found no drift; retired `§N.M` notation: 0.
  No edit.
- **Gate**: `luacheck .` 0 warnings / 0 errors in 105 files; `lua tests/run.lua` 1446 passed,
  0 failed, 1 skipped (1447); `docs/test-cases.md` regenerated with no change; no authored `.lua`
  file above 1500 lines (largest `tests/test_browser.lua`, 1442).

## Re-vendor after the tag moved again (one key button)

Item BL-RV3 of the same run. LK-96 moved the local annotated tag v1.77.0 in `../LibKa0s` again, to
carry the owner's follow-up to item 015: one key button and Clear per row on the in-addon
Keybindings tab (Options -> Keybindings is untouched). No new bundle: this section is the record.

- **Tag**: old target `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10` (the commit BL-RV2 vendored), new
  target `2f2b2e22b4c9219cd8a4101d7e894681c7aea16e` (`git -C ../LibKa0s rev-parse v1.77.0^{}`); the
  tag object moved from `b2b8ee2` to `e9b126d961c2970e5b14d0566480f7c1d8b5e5e8`.
  `git -C ../LibKa0s diff --stat afae2f7 2f2b2e2 -- LibKa0s testkit` names three files.
- **Minors that moved**: OptionsKeybinds 3 -> 4 (the row is one key button and Clear; the button
  binds and right-click clears slot 1, reads `<first key> +N` when the action holds more, and its
  tooltip names every key; strings `KEY1` / `KEY2` gone, `KEY`, `KEY_MORE`, `KEYS_ALL` and
  `KEYS_OTHER` new, `CLEAR_TIP` reworded). Every other library file's minor is unchanged. The test
  kit's `bindings_xml.lua` and its README row changed (`Kit.keybindThroughTab` slot 2 on a one-button
  row is the client page's second key); kit revision stays 42, so the CLAUDE.md provenance line
  (v1.77.0, kit 42) and the icon declaration are unchanged.
- **Copy**: `libs/LibKa0s/` and `tests/_kit/` replaced whole from `git -C ../LibKa0s archive v1.77.0
  LibKa0s testkit tools`; nothing left behind to delete. Prune: `11 icon(s) declared; kept 12
  file(s), removed 5828`. README credits unchanged.
- **Surface parity**: no new public Options member (the minor's additions are row internals and
  `lib.KEYBIND_STRINGS` keys), so the degradation stub in `settings/OptionsSetup.lua` is unchanged
  and the kit's parity case stays green.
- **Blocker, fixed in this commit**: `tests/test_keybinds.lua` asserted two key slots per row; it
  now asserts one key button and a Clear, and a new case binds two keys the way the client's page
  does and checks the button reads `F7 +1`. No addon test drove slot 2 through the tab.
- **Docs**: `docs/settings-panel.md` describes the row as one key button and Clear with the `+1`
  count and tooltip; `docs/smoke-tests.md` SLASH-9 (now also SM-BL-RV3) and SLASH-10 rewritten for
  the one button, Result left blank and listed under Pending sign-off. `Bindings.xml`,
  `NS.BINDINGS` and the labels are untouched.
- **Adopted**: nothing; the row arrives with the copy.
- **Gate**: `luacheck .` 0 warnings / 0 errors in 105 files; `lua tests/run.lua` 1451 passed,
  0 failed, 1 skipped (1452); `docs/test-cases.md` regenerated (Total 1451) and the README badge
  reads 1451/1451; no authored `.lua` file above 1500 lines (largest `tests/test_browser.lua`, 1442);
  `diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s` empty apart from the pruned icons.
