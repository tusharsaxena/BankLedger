# Candidates (BankLedger), LibKa0s v1.89.0 -> v1.90.0

Sources: the `CHANGELOG.md` block v1.90.0 at `../LibKa0s` v1.90.0, and the documents
`docs/api/Core/version-16-docs.md`, `docs/api/Widgets/version-24.5.12.6.8.5-docs.md`,
`docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md` and
`docs/api/Options/version-37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4-docs.md`. No 3g blocker
exists, so none is excluded here.

## Class A: delivered on the copy (not offered)

- **One physical pixel (SF1-L1, Widgets 24 / WidgetsAutocomplete 8 / Core 16 / SkinPaint 19 /
  SkinPaintExtras 18).** BankLedger's `W.Dropdown` (`modules/Browser.lua:179`) and `W.SearchBox`
  (`modules/Browser.lua:200`), and the shared menu under the dropdown, now draw a one-physical-pixel
  edge at any UI scale and sub-pixel position, under every skin and with none. No host change
  (CHANGELOG v1.90.0, *One physical pixel*: "No member or option moves").
- **A copy leaves a keepScope host's Scope alone (OptionsAppearance 7).** The Skin tab's copy and
  Apply to all, run from BankLedger, now leave the Skin Tester's Scope alone; BankLedger itself is a
  plain target and is unaffected.

## Class B: host change required

- **`RegisterOwner(owner, { keepScope = true })` (Skin 17).** An opt-out for a host whose Scope is a
  documented deviation. BankLedger has no such deviation (its Scope follows the copy like every other
  addon's). **Not applicable**; the run's SF1 record assigns it to the Skin Tester only (`SF1-ST`).
  Blast radius would be additive.

## Class C: whole-module adoption

None new. Settled standing declines unchanged: IconBrowser (no icon chooser), Perf (capture engine
never runs in combat). Nothing in this range moves either premise.
