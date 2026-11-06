# Candidates (BankLedger), LibKa0s v1.85.0 -> v1.89.0

Sources: the `CHANGELOG.md` blocks v1.86.0..v1.89.0 at `../LibKa0s` v1.89.0, and the `Since`
markers in `docs/api/Widgets/version-23.5.12.6.7.5-docs.md`, `docs/api/DebugLog/version-22.7.1.4-docs.md`,
`docs/api/Toast/` and `docs/api/IconBrowser/` at the tag. No 3g blocker exists, so none is excluded here.

## Class A: delivered on the copy (not offered)

- **DebugLogDiagnostics 6 -> 7.** The diagnostics report's `LibKa0s running:` line names
  `IconBrowser` when the winning copy carries it (DebugLog `version-22.7.1.4-docs.md`, "No member
  change"). BankLedger's `/bl diag` report picks it up with no host change.
- **Widgets 22 -> 23 for flat menus.** "Every single-level menu, a dropdown's and a host's, is
  unchanged" (Widgets `version-23.5.12.6.7.5-docs.md`, *What changed at this version*). BankLedger's
  `W.Dropdown` (`modules/Browser.lua:179`) draws what minor 22 drew.
- **Kit 50 -> 51.** The CallbackHandler unregister guard in `tests/_kit/mock_ace.lua` (`367a9f1`), a
  flake fix the suite takes on the copy.

## Class B: host change required

- **Widgets 23 `submenu` / `radio` / `selected` / `opts.check` on `W.ContextMenu` rows.** BankLedger
  opens no `W.ContextMenu` (`grep -rn ContextMenu core modules settings` is empty; the only hit in the
  tree is `tests/menu_mock.lua`, the Launcher's `MenuUtil` mock). **Not applicable**: there is no use
  site to adopt it at. Blast radius would be nil.
- **Toast 4 stack (`SetStack`, `Visible`, `FrameFor`, opt-in stack descriptor).** BankLedger has no
  Toast lookup and no Toast stub. **Not applicable**: the stack is a field on a host that already
  toasts. Whole-module Toast adoption is not new in this range (Toast shipped before v1.85.0) and no
  BankLedger surface raises toasts.

## Class C: whole-module adoption

- **`LibKa0s-IconBrowser-1.0` (new at v1.86.0, three files at 1).** A host-configured icon chooser
  window. BankLedger's UI offers the player no icon choice (`grep -rniE 'icon ?(chooser|picker|browser)'
  core modules settings` is empty), so it has nothing to browse for. Recommendation: settled, per the
  owner's ruling for every addon without an icon chooser. Blast radius would be additive.

Prior settled decline still standing: **Perf** (the capture engine never runs in combat, so every
bucket would read `0.000` by construction). Nothing in this range moves that premise.
