# Settings panel

Every user-facing option, the widget that renders it, and the one seam every write takes. The stored
shape behind these paths is [schema.md](schema.md).

## Shape

Three pages registered with `LibKa0s-Options-1.0`, which owns the shell, the widget makers, the flow
engine and the render timing. `settings/Panel.lua` keeps only what did **not** generalize: the
inverted store grid, the Storage section, the whole Filters page, the landing-page body, `P:Diagnose`
and the `P:Batch` refresh coalescer.

`NS.Helpers` **is** the library instance (`options-ui-§1`), not a wrapper — `settings/Panel.lua`
decorates it in place, so a member added by the library is available without a re-export.

Opening **refuses** under combat lockdown with a gray notice and never defers:
`Settings.OpenToCategory` is protected, and calling it under lockdown taints the panel for the rest
of the session.

## Rows

`settings/Schema.lua` is the single source: it drives the panel widgets, the slash `get`/`set`/
`list`/`reset` dispatch, and the defaults reset. Every write goes through `NS.Schema:Set`.

Rows render in schema order, so this table is also the panel's layout, top to bottom.

A slider row **must declare its `step`**: `LibKa0s-Options-1.0`'s `makeSlider` assumes 1 when the row
omits it, which would snap `settings.windowScale`'s 0.6–1.6 range to its two endpoints and nothing
in between. It is declared at `0.05`, never defaulted.

| Path | Type | Default | Group |
|---|---|---|---|
| `settings.enabled` | bool | `true` | Master Controls |
| `minimap.hide` | bool | `false` | Master Controls |
| `settings.showSessionWindow` | bool | `true` | Master Controls |
| `state.debugConsole` | bool (session-only) | `false` | Master Controls |
| `settings.windowScale` | number | `1.0` | Master Controls |
| `settings.qualityThreshold` | number | `0` | Capture |
| `settings.retentionDays` | number | `30` | Capture |
| `settings.trackItems` | bool | `true` | Capture |
| `settings.trackMoney` | bool | `true` | Capture |
| `settings.excludedStores` | table (muted set) | `{}` | Capture |

**Defaults is non-destructive.** On General, `OnDefault` forwards to whatever the page parked as
`defaultsOnClick`, so Blizzard's footer control and the addon's own header button are one
implementation rather than two kept in step. That action is `P:RestoreDefaults()` — settings and
window geometry only. Wiping the ledger stays behind the confirm-gated `KA0S_BANKLEDGER_RESETALL`
popup, which Blizzard's un-gated control never reaches.
