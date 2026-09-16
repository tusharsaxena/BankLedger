# Settings panel

Every user-facing option, the widget that renders it, and the one seam every write takes. The stored
shape behind these paths is [schema.md](schema.md).

## At a glance

The page-granularity summary, moved here out of the README when documentation-§1 made Usage prose
only. The finer tree is everything below it.

| Page | Tabs | Covers |
| --- | --- | ------ |
| General | Master controls · Capture · Interface · History · Filters | The whole addon, on one strip |

| Tab | Covers |
| --- | ------ |
| Master controls | The addon as a whole, and the same first tab in every Ka0s addon: turn Bank Ledger off, choose when its windows are shown at all, scale and fade them, lock them in place, open the debug console, put a sample ledger on screen (**Test mode**, the same switch as `/bl test`), put the windows back where they started, or return every setting to stock. |
| Capture | What actually gets recorded: whether items and gold are tracked, a minimum item quality, and which banks you care about. |
| Interface | What is on screen: whether the Current Banking Session window appears at a bank, and how strongly the tables band their rows and highlight the one under your cursor. The minimap button is **not** here — it is a Master controls row (`launcher-§3`). |
| History | How much is kept — 30 days by default — with a read-out of how many movements you have recorded and roughly how big the database is, and **Purge ledger…**, which empties the history after asking first. |
| Filters | Two lists of items by id, one per sub-tab. Blacklisted items are never recorded; whitelisted items are always recorded, even below your minimum quality. Add an item by typing its id or its name, or by shift-clicking its link into the box. As you type, a list of matching items drops down under the box — click one (or pick it with Up/Down and Enter) to add it; an item made in several quality ranks shows one row for each rank you carry or your ledger or lists hold, and typing a name several of those ranks share and pressing Enter without picking adds nothing and asks you to pick. If only one rank is known here, Enter adds that rank: the game has no item-name search, so other ranks stay unknown until you carry them. Use the id to add any rank you want. A name works for an item you carry (or carried this session), one on either list, or one your ledger has recorded; for anything else use the id or shift-click a link. Each entry shows the item's icon, name and id with a **Remove** button, and **Clear all** empties the list after asking. Both lists only affect what happens from now on — nothing already in your ledger is ever hidden or removed by them. |

## Shape

**Two** pages registered with `LibKa0s-Options-1.0`, which owns the shell, the widget makers, the
flow engine and the render timing: the **landing page** and **General**. `settings/Panel.lua` keeps
only what did **not** generalize: the inverted store grid, the History tab's storage read-out, the
Filters tab's secondary strip over the two item-id lists, the landing-page body, `P:Diagnose` and
the `P:Batch` refresh coalescer.

The **Filters** sub-page is gone. It held no schema rows at all, so it was never a page's worth of
settings — its two lists are one **Filters** tab of General's own strip now, divided by a secondary
strip, and the registration was removed rather than left registered-and-empty.

`NS.Helpers` **is** the library instance (`options-ui-§1`), not a wrapper — `settings/Panel.lua`
decorates it in place, so a member added by the library is available without a re-export.

Opening **refuses** under combat lockdown with a gray notice and never defers:
`Settings.OpenToCategory` is protected, and calling it under lockdown taints the panel for the rest
of the session.

## The tab strip (`options-ui-§13`)

General is **tabbed**: a strip pinned in the page's chrome band, between the header and the scroll.
A tabbed page draws **no section headings** — the tab is the heading. A tab that mixes *kinds* of
control heads each kind with a **subsection** heading instead, declared by the row's `subgroup`, and
those are deliberately not suppressed (`options-ui-§7`).

| Page | Tab strip, in order | Rows per tab |
|---|---|---|
| Landing page | — (exempt: the host's own `buildMain`, `options-ui-§13`) | — |
| General | **Master controls** · **Capture** · **Interface** · **History** · **Filters** | 7 · 4 · 4 · 1 · 1 |

Inside **Filters** a **secondary** strip (`O.SubTabStrip`, `options-ui-§13`) divides **Blacklist**
from **Whitelist**. Its selection is `ctx.activeSubTab["Filters"]` — a table keyed by the primary
tab, so leaving Filters and coming back returns to the list you were on — and it is session state,
never persisted, exactly like `ctx.activeTab`. A stale pointer heals to the first list rather than
rendering blank.

The partition is by `group` **in declaration order**, so the row array's order *is* the tab order and
a group's rows must stay **contiguous** — a row filed under a group the page has already left prints
that tab a second time further down. `tests/test_schema.lua` holds the page → tab → count table that
catches both.

**What the strip partitions is `NS.Schema:PageRows()`, not `NS.Schema.Schema`.** One of the five tabs
has no settings behind it: `S.BespokeRows` declares a single **renderer-only** row for Filters, which
carries a `group` (so the tab is drawn) and `skipRender` (so the flow engine walks past it) and
nothing else. It is deliberately not a setting — the lists are an `architecture-§5` structural
registry whose one writer is `NS.Filters`' copy-on-write, which re-caches the capture gate and fires
`LedgerChanged`; a schema row over the same key would hand `/bl set`, `/bl reset` and the reset sweep
a second writer that skips all of that. `allRows` still answers `S.Schema` alone, so the CLI and
every reset see exactly the settings.

**Two tabs hold one declared row and are exempt by name** from "a tab with fewer than two controls
is not a subject": each sits beside bespoke controls that have no path and cannot be counted — the
storage read-out and **Purge ledger…** on History, and the secondary strip plus the selected list's
**Clear all** and its LibKa0s `IdList` (the add box and the live id list) on Filters. The exemption is `THIN_TAB_EXEMPT` in
`tests/test_schema.lua`, named rather than a loosened rule.

### The bespoke blocks are `afterGroup` hooks, not page-body calls

`H.RenderTabbedSchema` re-renders **the schema and nothing else** on a tab click: it clears the
scroll and calls itself. Anything the page renderer drew after it would be on the page exactly once,
and gone the moment the player clicked another tab and came back. So every bespoke block hangs off
the library's `afterGroup` table instead:

| Tab | Hook | Draws |
|---|---|---|
| Master controls | `NS.Schema.masterTail` | The composer's own closing `InlineButtonPair` — **Reset position** and **Reset all settings** |
| Capture | `renderStoreGrid` | The inverted per-store checkbox grid (`settings.excludedStores`, `skipRender`) |
| History | `renderStorage` | The live storage read-out, then **Purge ledger…** alone |
| Filters | `buildFiltersTab` | The **Blacklist · Whitelist** secondary strip, then the selected list alone via `makeFilterSection` — its blurb, **Clear all** (a host button behind a confirm), and one `O.IdList` (`kind = "item"`, LibKa0s v1.35.0) whose add box takes an id, a link or a name. A name resolves through the client's lookup (items carried this session) or against `candidates = filterCandidates`: both lists' ids, then every item id the live ledger recorded, newest first, each once, read from `NS.Filters` and `NS.Database:Ledger()` with no new stored state. That list is memoized (`candidateMemo`) until the ledger or either list is a different table, the ledger's length moves (`Add` fires `EntryAdded`, not `LedgerChanged`), or any `LedgerChanged` bumps its version in the tab's listener; with no bus target the memo stays off. The library's dropdown lists matches as the player types, one row per crafted-quality rank that the bags or the candidates hold (there is no client name search, so a rank nothing here has seen is not listed). It refuses a name two of those ids share (candidates or bag items) until one is picked; a name with one known rank adds that rank. Its refusal ends with `ITEM_NAME_HINT` (`strings.nameHint`), which the box's tooltip repeats. Its add and Remove call `NS.Filters`' own writers through `filterWrite`, which holds the tab's `LedgerChanged` repaint off so one click redraws the page once, via `ctx.rebuild` (this page only) |

The **group name is the hook key**, which is also why the Master controls group must keep exactly
that name: rename it and the closing button pair silently detaches, with nothing raising.

There is no *before*-group hook; `afterGroup` fires after the group's last row, which is the right
shape for a tail anyway.

## Master controls (`options-ui-§15`)

The **first** tab of the General page in every Ka0s addon, under that exact name, holding the
controls that govern the addon as a whole. It is **composed, not typed out** — `H.MasterControls`
emits the canonical set from one declaration, so nine addons cannot drift into nine orders.

| | |
|---|---|
| Enable Bank Ledger | General visibility |
| Master scale | Master alpha |
| Lock frame | Debug console |
| Minimap button | Test mode |
| Reset position | Reset all settings |

Bank Ledger draws three movable frames — the ledger window (`modules/Browser.lua`), the session
window (`modules/SessionWindow.lua`) and the export dialog (`modules/Export.lua`) — so it is **not
frameless** and every frame-only row applies.

- **`settings/Schema.lua`** declares the spec (`S.MASTER_SPEC`) and the reactions (`S.MASTER_DECOR`);
  **`settings/OptionsSetup.lua`** hands it the composer through `S:ComposeMaster(NS.Helpers)` and the
  rows are spliced at the **head** of `S.Schema`, which is what makes this the first tab. It happens
  there rather than in the schema file because the composer lives on the library **instance**, and
  the TOC loads the schema first — deliberately, so the descriptor has a schema and a write seam to
  read.
- **`keys = { scale = "windowScale" }`** is what keeps the stored path. The composer must never
  change what is stored, and every existing install keeps its scale under `settings.windowScale`.
- **Master scale is a promotion, not a new setting.** `settings.windowScale` was already addon-wide:
  `modules/Browser.lua` and `modules/SessionWindow.lua` both read that one key. Only the tab it sat
  on suggested otherwise. Its declared range widened to the canonical `0.5–2` (from this addon's own
  `0.6–1.6`); every stored value is inside the new range, so no install is touched.
- **Three rows are genuinely new** and each is honored by drawing code rather than merely declared:

  | Row | Path | Honored by |
  |---|---|---|
  | General visibility | `settings.visibility` | `NS.Util.VisibilityAllows`, consulted by `B:Show` and `SW:Show`; `NS.Util.ApplyVisibility` re-evaluates it on each combat edge, from `addon:OnCombatChanged` |
  | Master alpha | `settings.alpha` | `NS.Util.ApplyMasterFrame` → `frame:SetAlpha`, at construction and on every settings change |
  | Lock frame | `settings.locked` | `NS.Util.ApplyMasterFrame` → `frame:SetMovable(not locked)`; every drag handler calls `StartMoving`, which the client makes a no-op on an unmovable frame |

- **General visibility is a dropdown, not a boolean** — `Always` / `Only in combat` / `Only out of
  combat` / `Never`. This addon never shipped a *show only in combat* checkbox, so there is **no
  stored value to migrate** and `SCHEMA_VERSION` is unmoved. A window the rule takes off screen is
  remembered in `NS.State.hiddenByVisibility`, so the transition back re-shows exactly what the rule
  took and never a window the player had closed themselves.
- **Debug console** is the session-only row it always was (`state.debugConsole`, verbatim and
  unprefixed); what changed is only where it is declared. It moved off the Interface tab.
- **Minimap button** (`minimap.hide`, stored, first column of the fourth line; LibKa0s v1.39.0,
  compose minor 7) is the launcher's visibility row, emitted from `minimapPath`. Every addon has a
  minimap button and only some have a test mode, so the always-present row takes column 1 and the
  optional one pairs beside it. Its sense is inverted at the write seam — see the note under the
  row table — and the button it drives is `NS.Launcher`'s
  ([ARCHITECTURE.md ▸ Launcher](ARCHITECTURE.md#launcher)). It REPLACED the Interface tab's *Hide
  minimap button*, on the same stored path.
- **Test mode** (`state.testMode`, session-only, pairing beside *Minimap button*; standard v2.47.0) is the one switch
  for the **sample ledger**, the same as `/bl test`. It does not touch the session-window preview:
  `/bl session` stays its own verb, which was the owner's call. The composer emits it from
  `testModePath` with no default, so `S.MASTER_SPEC.defaults.testMode = false` is what lets a reset
  end it. `S.MASTER_DECOR` binds `get` to `LT:IsTestMode()` and a `set` that acts only when the
  value differs, and overrides the generic tooltip with this addon's own. Every start and stop runs
  through `LT:SetTestMode`, which repaints an open panel, so the box follows `/bl test` and the
  combat ending as well as its own clicks.
  - **Ticking it** loads the sample and opens the ledger window. The start is **refused** in combat,
    and when General visibility would keep the window shut. Either way one chat line says why and
    the box goes back to unticked.
  - **Combat ends it.** `addon:OnCombatChanged` stops it on `PLAYER_REGEN_DISABLED` and prints
    `test mode off — combat started.`. A stop never opens the ledger window.
  - **Both global resets end it.** `/bl resetall` and **Defaults** reach it through the row walk;
    **Reset all settings** empties `db.global`, which test mode was never in, so
    `Sl:ResetEverything` ends it by name.
- **Reset position** is a real button now. The act existed only as a side effect folded into
  `P:RestoreDefaults`; both routes call `NS.Util.ResetWindowPositions()`, which is the one body.
- **Reset all settings** raises the confirm-gated `KA0S_BANKLEDGER_RESETALL` popup, whose text is
  `options-ui-§12`'s second canonical wording byte for byte (the one for an addon with no profile).
  `OnAccept` runs `NS.Slash:ResetEverything`, which empties `db.global` **wholesale** — every
  setting, both filter lists, both windows' geometry **and the recorded ledger** — then merges
  `NS.defaults.global` back and re-anchors the windows. It used to be the right half of History's
  button pair and **moved rather than being duplicated**.

  **It is NOT the act `/bl resetall` takes.** That verb runs `NS.Slash:CliResetAll`, which clears the
  two filter lists, resets the saved view and defers to the library's schema walk; your history
  survives it. The header/footer **Defaults** button is the same non-destructive body, through
  `P:RestoreDefaults`. So this addon has **three routes over two implementations**, where
  `options-ui-§12` requires one — a **MUST divergence** that predates this pass, ratified as a row
  in [`ARCHITECTURE.md` ▸ Documented deviations](ARCHITECTURE.md#documented-deviations). Until that
  row is closed the two acts deliberately do **not** share a label: the button is *Reset all
  settings*, and `/bl resetall` is described as *Reset every setting to defaults*
  (`slash-commands-§3`'s own reference wording).

  With logging on, each act writes one settings line (`debug-logging-§10`), never a line per row.
  **Defaults** and `/bl resetall` log `[Set] reset all: N rows`, N the rows whose value changed. A
  reset that raises part-way logs `[Set] reset all: N rows (stopped by an error)`, still once, and
  re-raises the error.
  *Reset all settings* logs `[Set] reset account-wide settings to defaults (N rows)` beside its
  `[Data] reset-all wiped N ledger entries` line.

## Rows

`settings/Schema.lua` is the single source: it drives the panel widgets, the slash `get`/`set`/
`list`/`reset` dispatch, and the defaults reset. Every write to a schema-row path goes through
`NS.Schema:Set`.

Rows render in schema order, so this table is also the panel's layout — tab by tab, and two rows to
a line within a tab unless a row declares `solo`, `wide` or `startsLine`, or a `subgroup` boundary
flushes the line.

A slider row **must declare its `step`**: `LibKa0s-Options-1.0`'s `makeSlider` assumes 1 when the row
omits it, which would snap a fractional range to its two endpoints and nothing in between. The
composed rows carry their own; the two tint sliders declare `0.01`.

| Path | Type | Default | Tab | Subsection | Layout |
|---|---|---|---|---|---|
| `settings.enabled` | bool | `true` | Master controls | — | `startsLine`, pairs with `visibility` |
| `settings.visibility` | string | `"always"` | Master controls | — | |
| `settings.windowScale` | number | `1.0` | Master controls | — | `startsLine`, pairs with `alpha` |
| `settings.alpha` | number | `1.0` | Master controls | — | `min` narrowed to `0.1`, the honored floor |
| `settings.locked` | bool | `false` | Master controls | — | `startsLine`, pairs with `debugConsole` |
| `state.debugConsole` | bool (session-only) | `false` | Master controls | — | |
| `minimap.hide` | bool | `false` (the row reads **shown**, so the box ships ticked) | Master controls | — | `startsLine`, pairs with `testMode` |
| `state.testMode` | bool (session-only) | `false` | Master controls | — | pairs beside `minimap.hide` |
| `settings.trackItems` | bool | `true` | Capture | — | pairs with `trackMoney` |
| `settings.trackMoney` | bool | `true` | Capture | — | |
| `settings.qualityThreshold` | number | `0` | Capture | — | |
| `settings.excludedStores` | table (muted set) | `{}` | Capture | — | `wide`, `skipRender` — drawn by `renderStoreGrid` |
| `settings.showSessionWindow` | bool | `true` | Interface | Windows | alone under its heading |
| `settings.rowStripeAlpha` | number | `0.03` | Interface | Table rows | pairs with `rowHoverAlpha` — rest beside hover, read across the line |
| `settings.rowHoverAlpha` | number | `0.10` | Interface | Table rows | |
| `settings.retentionDays` | number | `30` | History | — | |

**The `minimap.hide` row reads backwards, and that is deliberate.** Its label says *Minimap
button* — ticked means SHOWN — while the stored boolean is LibDBIcon's own `hide`. The key is the
library's: it writes that same field itself when the player hides the button from its right-click
menu, so a second boolean beside it would be a copy free to disagree (`launcher-§3`,
anti-pattern #81). The inversion lives in **one** place, `NS.Schema:Set` / `NS.Schema:Get`, and the
button is moved from the row's `onChange` through `NS.Launcher:SetShown`. This row REPLACED the
Interface tab's *Hide minimap button*, which said the opposite on the same path; nobody's stored
choice moved.

**And it is the one row no reset on this page reaches.** A player's minimap-button choice is a
per-installation display preference, like the angle they dragged the button to, so `launcher-§3`
requires it to survive both *Reset all settings* and this page's own **Defaults** button — and both
reached it here until the standard's v2.54.0 amendment. `NS.Schema.RESET_EXEMPT` names the row once
and `S:ApplyDefault` honors it; the wholesale reset holds the `minimap` table across its wipe.
A targeted `/bl reset minimap.hide` is not a sweep and still works. See
[ARCHITECTURE.md → Launcher](ARCHITECTURE.md#launcher).

**No color rows.** Nothing here is `type = "color"`, so `options-ui-§17`'s class-color companion has
nothing to attach to and `settings/OptionsSetup.lua`'s descriptor carries no
`colorDecode`/`colorEncode`. Adding a swatch means adding both, and reaching for `H.ColorPair` rather
than hand-writing the pair. `tests/test_schema.lua` pins the emptiness so the companion loop beside
it is a guard rather than a vacuous one.

**No font, border or bar group, and no reorder list.** This addon paints no status bar, exposes no
font picker and stores no list whose *order* is a setting, so `options-ui-§16` and `§18` have nothing
to compose here.

### The promoted chrome literals

`settings.rowStripeAlpha` and `settings.rowHoverAlpha` were hardcoded in **two files each** —
`modules/LedgerTable.lua` and `modules/SessionWindow.lua` both built every pooled row with
`1,1,1,0.03` behind the even rows and `1,0.82,0,0.10` under the cursor. They are two answers to two
questions (rest and hover), so they are two sliders and not one "row emphasis".

- **Each default IS the literal it replaced**, so an install that touches neither slider is drawn
  exactly as it was.
- **Both are clamped at the read**, in `NS.Util.RowTintAlpha`. These arrive from SavedVariables,
  where a hand-edited `5` is not an error — it is a table drawn opaque white, which reads as the
  slider not working. A non-number falls back to the shipped default, not to zero. **Master alpha**
  is clamped the same way, in `NS.Util.ApplyMasterFrame`, with a floor of `NS.Constants.MASTER_ALPHA_MIN`
  (`0.1`): a stored `0` would be an invisible addon with no way back to the panel that set it.
  That floor is also the **row's declared `min`** — `S.MASTER_DECOR["settings.alpha"]` narrows the
  composer's canonical `0` to the same constant, so the slider cannot offer a stop the drawing code
  refuses. Left at `0`, its two lowest positions would both render at `0.1` and be indistinguishable:
  a declared setting that is not honored (`STEP 4.3`). The clamp stays regardless, because
  SavedVariables is hand-editable and the slider is not the only way a value gets in. Contrast the
  two tint sliders, whose clamps stay *inside* their declared `0`–`0.3` range and so need no such
  narrowing.
- Neither is the **shared skin's**: `Core.SKIN` owns the window edge, fill, border and title, and
  `modules/Browser.lua`'s `B:ApplySkin` note lists them byte for byte. The table interior is this
  addon's own.
- `NS.Util.ApplyRowTint` is the single read, called from `BuildRow` (so a row is right the moment it
  exists) and from `BindRow` (so a recycled row re-reads after the slider moved).
  `NS.Util.RefreshRowTint` is the `onChange`: it rebinds both tables directly and broadcasts
  `SettingsChanged` beside it, the same shape `settings.windowScale` uses.

**Defaults is non-destructive.** On General, `OnDefault` forwards to whatever the page parked as
`defaultsOnClick`, so Blizzard's footer control and the addon's own header button are one
implementation rather than two kept in step. That action is `P:RestoreDefaults()` — settings, the two
id-lists, the saved view and window geometry, never the ledger. Wiping recorded history stays behind
the confirm-gated `KA0S_BANKLEDGER_RESETALL` popup, which Blizzard's un-gated control never reaches.

## In a degraded install

Where `libs/LibKa0s` is missing entirely, `settings/OptionsSetup.lua` takes its load-completing stub
branch and there is no settings panel at all — which is the documented degradation. One consequence
is worth stating because it is not obvious: the **Master controls rows are composed by the library**,
so on that path they are absent from `NS.Schema.Schema` and `/bl list`, `/bl set` and `/bl reset`
cannot reach those seven paths. `/bl get` still can — `Schema:Get` falls through to the stored value —
and every stored one is still read and honored by the drawing code, because the defaults live in
`defaults/Global.lua`. The two session-only ones keep their verbs: `/bl debug` and `/bl test`. The alternative would be a host copy of the canonical block in the stub, which
is exactly the drift the composer exists to end (anti-pattern #73).
