# Common tasks

Recipes for the changes made most often in this addon. Each one names real files; where a step has a
trap, the trap is stated rather than implied.

## Add a setting

One row, three surfaces. A row in `settings/Schema.lua` drives the panel widget, the
`/bl get|set|list|reset` dispatch and the defaults reset at once — so never write a parallel mutator
for a path that already has a row.

1. Add the shipped value to `defaults/Global.lua`. That is the **only** place a default is hardcoded
   (`savedvariables-§2`); there is deliberately no `defaults/Profile.lua`.
2. Add the row to the schema table in `settings/Schema.lua`, at the position you want it to render —
   **rows render in schema order, so the table is also the panel layout.** `group` names the **tab**
   the row draws on (`options-ui-§13`), and the array's declaration order is the tab order, so a
   group's rows must stay **contiguous**: a row filed under a group the page has already left prints
   that tab a second time further down. Within a tab, consecutive rows pair **two to a line** —
   pair a mode with the thing it modes, and rest beside hover, so the reader goes across rather than
   down. `solo` breaks a row onto its own line; use it for a genuine pivot, not for spacing;
   `startsLine` flushes the pending line before a row, so a declared pair can never be split. Where
   a tab mixes **kinds** of control, every row on it carries a `subgroup` naming its kind — that
   heading is drawn inside the tab and is deliberately not suppressed (`options-ui-§7`).
   Then update the page → tab → count table (`PARTITION`) in `tests/test_schema.lua`; it is the case
   that catches a row drifting into the wrong tab.
3. **Do not hand-write a canonical block.** A font, border or bar group, a color swatch and its
   `Use class color` companion, or anything on the **Master controls** tab is *composed*
   (`H.FontGroup`, `H.BorderGroup`, `H.BarGroup`, `H.ColorPair`, `H.MasterControls`) — a hand-written
   copy is anti-pattern #73. Pass `keys` and `defaults` so the composer keeps this addon's stored
   paths and values; see `S.MASTER_SPEC` in `settings/Schema.lua` for the shape. Adding the first
   color row also means adding `colorDecode`/`colorEncode` to the descriptor in
   `settings/OptionsSetup.lua`, which has none today.
4. **A slider row must declare its `step`.** `LibKa0s-Options-1.0`'s `makeSlider` assumes `1` when the
   row omits it, which would snap a fractional range to its two endpoints and nothing in between.
   The two tint sliders declare `0.01`; the composed rows carry their own.
5. Give the row an `onChange` if anything must react. By convention it sends
   `Ka0s_BankLedger_SettingsChanged` with a short reason string — that is what makes `modules/Ledger.lua`
   re-cache its capture-gate upvalues.
6. Every write — panel widget or slash line — goes through `NS.Schema:Set`, which validates, writes,
   emits the one debug trace, runs `onChange` and repaints an open panel. Do not write `db.global`
   directly from a new code path.

If the value is a dynamic id-set, an ordered list or window geometry, it is a **carve-out**, not a
row — see [schema.md](schema.md) → *Storage carve-outs* — and it needs a line in
`Slash:CliResetAll`'s wrapper so a reset still reaches it.

If the row needs a **bespoke widget** beside it — a picker, a grid, a button pair — draw it from the
tab's `afterGroup` hook (`GENERAL_AFTER_TAB` in `settings/Panel.lua`), never from the page renderer
after the `RenderTabbedSchema` call. A tab click re-renders the schema and nothing else, so anything
the page body drew survives exactly one render and then vanishes the first time the player comes
back to the tab.

## Promote a hardcoded chrome value to a setting

1. **Ship the default as the number it replaced.** If it is not, every existing install is redrawn by
   an upgrade that promised to change nothing. `tests/test_schema.lua` asserts both tint defaults
   against their old literals for exactly that reason.
2. **Clamp it at the read**, not at the write: it arrives from SavedVariables, which a player can
   hand-edit. `NS.Util.RowTintAlpha` is the shape — out-of-range clamps, a non-number falls back to
   the shipped default rather than to zero.
3. **A pair of literals is usually a pair of settings.** A value at rest and a value on hover are two
   answers to two questions; do not collapse them into one slider.
4. **Do not promote a value `Core.SKIN` owns.** The shared skin carries the window edge, fill, border
   and title across every Ka0s window; a per-addon copy of one is the copy that goes stale.

## Add a slash command

Append one entry to `NS.COMMANDS` (`settings/Schema.lua:235`). `/bl help`, the settings landing page
and the README's command table all read from that table, so nothing else needs editing — regenerate
the README with `/wow-addon:sync-docs`. See [slash-dispatch.md](slash-dispatch.md) for what the
library owns versus what stays the host's.

## Add a tracked store

1. Add the member to `C.Store` in `core/Constants.lua`, plus its label and display order. **The stored
   value equals the key and is part of the CSV export contract** — extend freely, never rename.
2. Add its container-id group, and map it into `L.CONTEXT_STORES` for every frame that can reach it.
   The unit the addon tracks is the open **frame**, not the store — see
   [data-flow.md](data-flow.md) → *Frames, not stores*.
3. If it holds gold, teach `Compat.GetStoreMoney` to read its balance — and make sure the reader
   returns `nil` rather than a number when it cannot answer honestly. A reader that returns `0` for
   "closed" fabricates gold rows; that is exactly the `GetGuildBankMoney()` trap
   ([compat-layer.md](compat-layer.md)).
4. `StoresFor`'s empty-group guard means a store whose containers are absent on this build degrades to
   "not on this build" rather than showing up permanently empty. `tests/test_ledger.lua` drives that
   path directly by emptying a live store's group.

## Retire a store

Which answer is right depends entirely on whether rows exist:

- **No shipped build ever wrote a row against it** — remove the member outright. That is what happened
  to `REAGENT_BANK` and `VOID_STORAGE`; zero reachable rows means nothing to orphan.
- **Rows exist** — the opposite. **Keep the member**, drop it from `CONTEXT_STORES`, and let the
  history keep rendering. Renaming or deleting it orphans stored data that still carries the string.

## Add a migration

1. Bump `NS.SCHEMA_VERSION` in `core/Namespace.lua` — the one source for both the shipped default and
   the migration target.
2. Add the step to `NS:RunMigrations` in `core/Database.lua`, gated on the *current* version, and make
   it idempotent: a database already at the new version must be skipped entirely, and re-running a
   partially applied step must be a no-op.
3. Emit the standard `[Migrate]` line via `NS.MigrationSummary`.
4. If the migration changes what the CSV emits, that is a **contract break** and it is recorded as a
   dated, accepted deviation tied to the schema bump — see the schema-v2 precedent in
   [schema.md](schema.md). Do not keep a column and emit blanks: a column with no value behind it is a
   promise the data no longer keeps, and it outlives everyone's memory of why it went empty.

## Add a chart to Insights

1. Add the accumulator to `Database:Stats` as a plain extra pass-through in the **same single O(n)
   loop**. Every breakdown is computed in one pass, which is why the panel got richer without the
   aggregation getting slower.
2. End every comparator on a stable tiebreak (`itemID`, the label, the store key) so a tie cannot
   reorder run to run.
3. Draw it with an existing primitive from `modules/InsightsWidgets.lua` — that file knows nothing
   about ledger entries, which is what keeps its geometry math headlessly testable. Put the "which
   breakdown, which color, which order" decision in `modules/Insights.lua`.
4. Follow the three house rules in [insights.md](insights.md): deposit/withdrawal charts are **back to
   back, never stacked**; color is never decorative; empty is drawn, missing is not.

## Add a locale string

`locales/enUS.lua` publishes `NS.L` with a metatable fallback returning the key itself, so a missing
key never errors. v1.0.0 ships **English-only and unwrapped** — every label is hardcoded English, an
accepted scope decision. There is deliberately no `local L` alias until the first string is wrapped,
so the file stays luacheck-clean. Wrapping the first string means adding the alias in the same change.

Match game data on **stable ids and tokens** — `itemID`, `classFile`, `Enum.*` — never on a localized
name. That is why every entry stores `classFile` rather than a class name.

## Register a new event

Use `Ledger:RegisterEventSafely`, never a bare `RegisterEvent` loop. Modern retail **raises** on an
unknown event name rather than ignoring it, so one retired name in a bare loop leaves every event
after it unbound — a silently deaf addon with no visible error unless script errors are on. Names
this build rejected land in `Ledger.unavailableEvents` and are reported by `/bl debug scan`.

## Add a window

Both existing windows are plain non-secure frames sharing one `SKIN` / `ApplySkin` seam and one
close-control factory — `B:MakeCloseButton`, which draws the collection's shared `close` mark and
keeps a 24pt × as the rung below it. Reach for that factory rather than a fourth hand-rolled ×. Anchor geometry persistence to the **guaranteed** moments —
`SaveGeometry()` on every `OnHide` and on `PLAYER_LOGOUT`, `ApplyGeometry()` once at frame build.
Drag-stop and resize-stop are conveniences on top, not the contract: releasing a resize grip a pixel
outside a 16×16 button never delivers its `OnMouseUp`, and the in-memory frame then masks the fault
for a whole session. See [windows.md](windows.md).

## Before committing

`lua tests/run.lua` green **and** `luacheck .` clean. Full instructions in [testing.md](testing.md).
