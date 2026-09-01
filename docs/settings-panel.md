# Settings panel

Every user-facing option, the widget that renders it, and the one seam every write takes. The stored
shape behind these paths is [schema.md](schema.md).

## Shape

Three pages registered with `LibKa0s-Options-1.0`, which owns the shell, the widget makers, the flow
engine and the render timing. `settings/Panel.lua` keeps only what did **not** generalize: the
inverted store grid, the History tab's storage read-out, the Filters page's two id lists, the
landing-page body, `P:Diagnose` and the `P:Batch` refresh coalescer.

`NS.Helpers` **is** the library instance (`options-ui-§1`), not a wrapper — `settings/Panel.lua`
decorates it in place, so a member added by the library is available without a re-export.

Opening **refuses** under combat lockdown with a gray notice and never defers:
`Settings.OpenToCategory` is protected, and calling it under lockdown taints the panel for the rest
of the session.

## The tab strips (`options-ui-§13`)

Both settings pages are **tabbed**: a strip pinned in the page's chrome band, between the header and
the scroll. A tabbed page draws **no section headings** — the tab is the heading.

| Page | Tab strip, in order | Rows per tab |
|---|---|---|
| General | **Capture** · **Interface** · **History** | 5 · 6 · 1 |
| Filters | **Blacklist** · **Whitelist** | 0 · 0 (no schema rows) |

**General** partitions on the schema's own `group` field through `H.RenderTabbedSchema`. The
partition is by `group` **in declaration order**, so `settings/Schema.lua`'s array order *is* the
tab order and a group's rows must stay **contiguous** — a row filed under a group the page has
already left prints that tab a second time further down. `tests/test_schema.lua` holds the
page → tab → count table that catches both.

**Filters** has no schema rows at all — both id-lists are storage carve-outs mutated through
`NS.Filters` — so it drives the same `H.TabStrip` by hand, keeping the active tab in the same
`ctx.activeTab` the library reads. Inventing a second piece of state for "which tab is showing"
would go stale the first time the page was marked dirty while hidden.

**History holds one stored row and is exempt by name** from "a tab with fewer than two controls is
not a subject": `settings.retentionDays` sits beside bespoke controls that have no path and cannot
be counted — the live storage read-out, **Purge ledger…** and **Reset all…**. The exemption is
`THIN_TAB_EXEMPT` in `tests/test_schema.lua`, named rather than a loosened rule.

### The bespoke blocks are `afterGroup` hooks, not page-body calls

`H.RenderTabbedSchema` re-renders **the schema and nothing else** on a tab click: it clears the
scroll and calls itself. Anything the page renderer drew after it would be on the page exactly once,
and gone the moment the player clicked another tab and came back. So both bespoke blocks hang off
the library's `afterGroup` table instead:

| Tab | Hook | Draws |
|---|---|---|
| Capture | `renderStoreGrid` | The inverted per-store checkbox grid (`settings.excludedStores`, `skipRender`) |
| History | `renderStorage` | The live storage read-out, then `H.InlineButtonPair` — **Purge ledger…** and **Reset all…** |

There is no *before*-group hook; `afterGroup` fires after the group's last row, which is the right
shape for a tail anyway.

## Rows

`settings/Schema.lua` is the single source: it drives the panel widgets, the slash `get`/`set`/
`list`/`reset` dispatch, and the defaults reset. Every write goes through `NS.Schema:Set`.

Rows render in schema order, so this table is also the panel's layout — tab by tab, and two rows to
a line within a tab unless a row declares `solo` or `wide`.

A slider row **must declare its `step`**: `LibKa0s-Options-1.0`'s `makeSlider` assumes 1 when the row
omits it, which would snap `settings.windowScale`'s 0.6–1.6 range to its two endpoints and nothing
in between. It is declared at `0.05`, never defaulted. The two tint sliders declare `0.01`.

| Path | Type | Default | Tab | Layout |
|---|---|---|---|---|
| `settings.enabled` | bool | `true` | Capture | `solo` — the switch every other Capture row is conditional on |
| `settings.trackItems` | bool | `true` | Capture | pairs with `trackMoney` |
| `settings.trackMoney` | bool | `true` | Capture | |
| `settings.qualityThreshold` | number | `0` | Capture | |
| `settings.excludedStores` | table (muted set) | `{}` | Capture | `wide`, `skipRender` — drawn by `renderStoreGrid` |
| `settings.windowScale` | number | `1.0` | Interface | pairs with `minimap.hide` |
| `minimap.hide` | bool | `false` | Interface | |
| `settings.showSessionWindow` | bool | `true` | Interface | pairs with `state.debugConsole` |
| `state.debugConsole` | bool (session-only) | `false` | Interface | |
| `settings.rowStripeAlpha` | number | `0.03` | Interface | pairs with `rowHoverAlpha` — rest beside hover, read across the line |
| `settings.rowHoverAlpha` | number | `0.10` | Interface | |
| `settings.retentionDays` | number | `30` | History | |

### The promoted chrome literals

`settings.rowStripeAlpha` and `settings.rowHoverAlpha` were hardcoded in **two files each** —
`modules/LedgerTable.lua` and `modules/SessionWindow.lua` both built every pooled row with
`1,1,1,0.03` behind the even rows and `1,0.82,0,0.10` under the cursor. They are two answers to two
questions (rest and hover), so they are two sliders and not one "row emphasis".

- **Each default IS the literal it replaced**, so an install that touches neither slider is drawn
  exactly as it was.
- **Both are clamped at the read**, in `NS.Util.RowTintAlpha`. These arrive from SavedVariables,
  where a hand-edited `5` is not an error — it is a table drawn opaque white, which reads as the
  slider not working. A non-number falls back to the shipped default, not to zero.
- Neither is the **shared skin's**: `Core.SKIN` owns the window edge, fill, border and title, and
  `modules/Browser.lua`'s `B:ApplySkin` note lists them byte for byte. The table interior is this
  addon's own.
- `NS.Util.ApplyRowTint` is the single read, called from `BuildRow` (so a row is right the moment it
  exists) and from `BindRow` (so a recycled row re-reads after the slider moved).
  `NS.Util.RefreshRowTint` is the `onChange`: it rebinds both tables directly and broadcasts
  `SettingsChanged` beside it, the same shape `settings.windowScale` uses.

**Defaults is non-destructive.** On General, `OnDefault` forwards to whatever the page parked as
`defaultsOnClick`, so Blizzard's footer control and the addon's own header button are one
implementation rather than two kept in step. That action is `P:RestoreDefaults()` — settings and
window geometry only. Wiping the ledger stays behind the confirm-gated `KA0S_BANKLEDGER_RESETALL`
popup, which Blizzard's un-gated control never reaches.

**Reset all moved.** It used to be a `pairWith` companion sitting to the right of the **Window
scale** slider. A button that wipes the whole ledger has no business one pixel from the slider a
player drags to size the window, and the page now has a destructive corner: the History tab, beside
**Purge ledger…** and under the read-out that says how much there is to lose. Both remain
confirm-gated — the buttons only raise a `StaticPopup`.
