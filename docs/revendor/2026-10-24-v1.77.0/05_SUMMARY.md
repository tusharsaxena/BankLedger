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
