# 05 — Summary: LibKa0s span v1.16.0 -> v1.54.2 (base v1.15.0)

Plan item BL-23, 2026-09-24, branch `feat/2026-09-23-review-audit-remediation`. Records the 29 tags
this addon vendored after its store's first bundle and never recorded (finding BankLedger-A-01). No
code changes, nothing is re-vendored, nothing is pushed, and the addon version is not bumped. The
commit list, the base and how the span was derived are in `01_DELTA.md`.

## One line per tag

"Carried by sweep, nothing adopted" means the bytes arrived and this addon's own code took no new
surface from that tag. Anything the library fixed still reached the player through the carry.

- **v1.16.0** — carried by sweep, nothing adopted (`4455ea6`: Pool 2, Widgets 7, DebugLog 12, kit 13).
- **v1.17.0** — `8bde943`: the `core/PoolSetup.lua` degraded fallback flipped to Pool 3's backward
  release order, in the re-vendor commit itself.
- **v1.18.0** — carried inside `4077fb1` (options-ui-§12 wholesale reset), nothing adopted. Options
  9's `resetProfile` is not used: this addon has no profile, so its reset empties the account-wide
  store itself.
- **v1.18.1** — carried by sweep, nothing adopted (the landing logo texture fix arrives with the bytes).
- **v1.19.0** — carried by sweep, nothing adopted (`Widgets.ReorderList` is unused here).
- **v1.23.0** — `abed21a`: both settings pages become tab strips through `RenderTabbedSchema`
  (options-ui-13).
- **v1.24.0** — `ab62071`: the composed Master controls tab and the settings-revamp-v2 page shape, in
  the same commit as the copy.
- **v1.26.0** — carried by sweep, nothing adopted (`92df67f`; the tab strip leak fix arrives with the bytes).
- **v1.27.0** — `c9ac140`: the kit's `test_eol.lua` gate wired into `tests/run.lua`, and `O.__print`
  added to the parity case's ignore list.
- **v1.28.0** — carried by sweep, nothing adopted (Perf only; this addon holds the performance-§12
  exemption and wires no perf verb).
- **v1.29.0** — carried by sweep, nothing adopted (Perf only, as above).
- **v1.35.0** — `6bc8d37`: the Blacklist and Whitelist editors adopt `O.IdList`. `2df0dee`: the
  add box suggests names from the ledger. Four re-cuts of the tag followed (`a91c384`, `f2164c9`,
  `710fa93`, `958e2b6`); the degradation stub gained the new members for surface parity only.
- **v1.36.0** — carried by sweep, nothing adopted (the stub gained `SelectTab` for parity; nothing
  calls it).
- **v1.36.1** — carried by sweep, nothing adopted (the pooled CheckBox color fix arrives with the bytes).
- **v1.36.2** — carried by sweep, nothing adopted.
- **v1.37.0** — `420af9b`: the Master controls Test mode checkbox through `testModePath`. The
  re-vendor commit `c2391e5` had said nothing would use it; the next commit did.
- **v1.38.0** — `beaf599`: a bare `/bl` opens the settings panel (Slash 11), with the library-absent
  stub and tests, in the re-vendor commit itself.
- **v1.39.0** — `0b556b7`: the launcher. `core/LauncherSetup.lua` replaces the hand-built minimap
  button with `LibKa0s-Launcher-1.0`.
- **v1.42.0** — `a769125`: the Lifecycle latch. Disabling the addon stands it down through
  `NS.SetDisabledHold`, and the slash refusal moves onto the library. The copy rode in this commit.
- **v1.43.0** — carried by sweep, nothing adopted (kit revision 23 only; the library bytes did not move).
- **v1.44.0** — `5669471`: `removeStyle = "icon"` on the Filters tab's `O.IdList`.
- **v1.45.0** — carried by sweep, nothing adopted (`shownWhen` is unused here).
- **v1.46.1** — carried by sweep, nothing adopted. The settings panel's combat lock arrives with the
  bytes and needs no host code. `a52b2ed` documents it and adds the smoke step.
- **v1.47.0** — `7eaa588`: `O.IdList` `columns` on both filter lists. The re-vendor commit
  `f5ed237` had declined it; `7eaa588` reversed that once v1.50.0 fitted the column count to the
  canvas.
- **v1.50.0** — `7eaa588`: the same adoption depends on OptionsWidgets 27's fitted column count.
- **v1.51.0** — carried by sweep, nothing adopted (the optional `O.IdList` help fields are unused here).
- **v1.52.0** — carried by sweep, nothing adopted.
- **v1.53.0** — carried by sweep, nothing adopted (the Add button height fix arrives with the bytes).
- **v1.54.2** — `6b12edf`: the kit's US-English prose gate replaces this repo's own copy. The copy
  rode in this commit.

## Declined

The only explicit decline in the span, v1.47.0's `columns` (`f5ed237`), was reversed by `7eaa588`.
No other candidate was formulated at the time, so nothing else counts as declined and no issue is
filed.

## Open

- The frozen bundles are not edited. `docs/revendor/2026-09-03/` and `docs/revendor/2026-09-12/`
  keep their heading-style line 1. The audit reads only the last tag from each, which is why v1.24.0
  and v1.29.0 are in this span.
- From here, every re-vendor writes its own `docs/revendor/<YYYY-MM-DD>-v<tag>/` bundle, as
  `2026-09-23-v1.55.0/` and `2026-09-23-v1.56.0/` already do.
