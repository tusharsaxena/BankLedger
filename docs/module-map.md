# Module map

Every non-vendored file, what it is responsible for, and the load order the TOC encodes. Vendored
libraries under `libs/` are not listed — they are consumed, not maintained here.

| File | Role |
|---|---|
| `core/Compat.lua` | The only caller of deprecated or patch-varying APIs. Container and guild-bank readers, the item **resolver** (`GetItemDetails`, `ItemNameQuality`), the player's purse **and each store's own coin balance** (`GetStoreMoney`), guild name. TOC metadata, the map id and the zone left for `core/EnvSetup.lua`; the four item primitives left for `core/ItemSetup.lua`. |
| `core/EnvSetup.lua` | The **LibKa0s-Env-1.0 seam**: publishes `NS.Meta(field)`, `NS.Version()`, `NS.PlayerMapID()` and `NS.Zone()` over the vendored library, passing this addon's own **folder name** (its first vararg) because a vendored copy cannot know which folder it sits in. It replaced three `core/Compat.lua` shims that were identical to every other addon's; `Compat` kept the readers that are genuinely this addon's. Every helper writes its **fallback out in full**, so an install missing LibKa0s reads its own TOC and stamps its own zone exactly as before — this is a seam, not a feature. `NS.Zone` answers **two strings and never nil**: `modules/Ledger.lua` buckets `""` with nil on purpose, in storage and in the zone filter. |
| `core/ItemSetup.lua` | The **LibKa0s-Item-1.0 seam**: publishes `NS.Item.ItemIDFromLink`, `NS.Item.QualityFromLink`, `NS.Item.QualityLabel` and `NS.Item.LoadItem` over the vendored library, with the same four written out in full as the degraded fallback. It replaced three `core/Compat.lua` shims and **added** `QualityFromLink`, which only LootHistory had — the colour fallback whose absence let an upgrade-track drop read back at its base quality. What it pointedly did **not** take is the **resolver**: `Compat.GetItemDetails` still refuses an uncached item and the gate still records `uncached`, because “cannot be judged” is not “passes” (F-006), while LootHistory’s resolver guesses from the link on purpose. The library carries primitives and holds no opinion, so neither policy had to be overturned. |
| `core/MediaSetup.lua` | The **LibKa0s-Media-1.0 seam**: publishes `NS.Icon(name)` and `NS.MediaFont(name)` over the vendored library, passing this addon's own **folder name** (its first vararg) so the library can build a texture path into a copy it cannot locate for itself. Makes the one `Media.RegisterLSM` call, at **file load** — the registration this addon used to make itself from `core/BankLedger.lua`'s `OnInitialize`, against its own copy of the face. Both answers are `nil` where the library is absent, which is a value a caller branches on and never a path to build around. Also publishes **`NS.ICON_NAMES`** — every mark this addon draws, by name, read by nothing at runtime and cross-checked against the library's catalog and against the source by `tests/test_marks.lua` and `tests/test_mediasetup.lua`. |
| `core/Constants.lua` | The `Store` / `Context` / `Direction` / `Kind` enums, their labels and display order, the container-id groups per store, settings option lists, the logo path, and `FONT_MONO` — resolved through the Media seam above, never a literal. |
| `core/Namespace.lua` | Bootstrap: `NS.name`, `NS.version`, `NS.SCHEMA_VERSION` (the one source for the shipped default and the migration target), the cyan `NS.PREFIX` chat tag. |
| `core/CoreSetup.lua` | The **LibKa0s-Core-1.0 seam**: builds the prefixed chat printer and republishes it as `NS.Print` / `NS.Util.print`, plus `NS.SafeToString` and `NS.IsConcatSafe`. Deliberately does **not** republish `lib.MakeCloseButton`: all four of this addon's title bars go through `modules/Browser.lua`'s own `B:MakeCloseButton` (24×24, class-coloured on hover), which resolves the same shared `close` mark through `NS.Icon`. A wrapper here would have had one caller — its own spy test — and would read as coverage of those four bars while covering nothing on screen. The library draws its own close control on the windows that are the library's, once `core/DebugLogSetup.lua` passes `addonName`. Also publishes **`NS.LIBKA0S_MISSING`**, the one cause clause every other LibKa0s seam appends its own consequence to — a cross-file contract, not an implementation detail of this file, and set on both the present and absent paths because the later seams read it either way. Degrades to equivalent built-in fallbacks, announcing the absence once. |
| `core/DebugLogSetup.lua` | The **LibKa0s-DebugLog-1.0 seam**: the on-screen console and the `NS.Debug` sink, published under the names `modules/DebugLog.lua` used before it was deleted. Supplies the descriptor's `applySkin`, resolved through `NS.Browser` at call time — which is what lets a `core/` file reach a `modules/` member without inverting the load order — so the console keeps tracking `modules/Browser.lua`'s own re-skin seam. It passes **`addonName`** beside `name` — two different questions answered with the same string: `name` seeds the frame globals, `addonName` is what the library builds texture paths from, so its own copy and clear controls draw the shared marks rather than two words. It passes **no** `makeCloseButton`: the window **edge** is shared across every Ka0s window now (`Core.SKIN` carries it, and this addon's `SKIN` agrees with it value for value), but the **close control on a library-drawn window is the library's**, so the console and the copy window wear Core's own 18×18 control while the ledger window keeps its 24×24 one. Since `addonName` arrives, both now draw the SAME `close` mark from opposite directions — the library resolves it for its windows, `B:MakeCloseButton` resolves it for this addon's — and the difference between them is size and hover tint, not kind (standalone-windows). Degrades to a stub answering every member `/bl debug` reaches. |
| `core/State.lua` | Runtime-only state: the open frame, the last snapshot, the session debug flag, the test dataset. Never persisted. |
| `core/Util.lua` | Player key, path splitting, date/money/byte formatting, the wowhead URL builder. The secret-safe chat printer moved to `core/CoreSetup.lua` when LibKa0s was adopted; every name it published is unchanged. |
| `core/BankLedger.lua` | AceAddon registration, the message bus, `NS.NewBusTarget`, `OnInitialize` / `OnEnable`. |
| `core/Database.lua` | AceDB init, the migration runner, ledger CRUD, `QueryList`, `Export`, `Stats`, retention prune, storage estimate. |
| `defaults/Global.lua` | The account-wide defaults table — the only place a default value is hardcoded. |
| `locales/enUS.lua` | The `NS.L` metatable-fallback locale seam. |
| `locales/PostLoad.lua` | Derived-key aliases (empty in v1.0.0). |
| `modules/Filters.lua` | The item blacklist / whitelist id-sets and their copy-on-write mutations. |
| `modules/Ledger.lua` | The capture engine: snapshot, diff, gate, build, record, plus the event shell. |
| `modules/Browser.lua` | The standalone window: skin, tabs, the shared filter bar, footer, minimap launcher. Owns `B:MakeCloseButton`, the single chokepoint through which all four of this addon's title bars draw the shared `close` mark (with the 24pt × kept as the rung below it). The flat dropdown itself is `LibKa0s-Widgets-1.0`'s; `B:MakeDropdown` is the thin forwarder that injects this addon's `chevron-down` mark, its `confirm` tick and its mono glyph face into the library's widget, because the library resolves no art of its own. Without the library the filter bar refuses to build at all rather than drawing controls that open nothing — the ledger table underneath still works. The filter bar is words-only — its **Export** button wore a mark BESIDE its word for a release and no longer does, because one marked button in a row of four read as an odd one out; Save · Reset · Clear are 51px and never had room for one. The search box keeps its magnifier, which sits beside a placeholder rather than beside a button label. See [media.md](media.md). |
| `modules/LedgerTable.lua` | The virtualized pooled-row History table, its grouping/sorting, the test dataset (`/bl test`), and the shared `Column` / `PaintCell` column seams. Its column-header sort arrows and its group-header expander are inline `|T…|t` markup resolved ONCE at load into named file-locals, so a degraded install appends the Blizzard string it always did rather than concatenating a nil into an escape. |
| `modules/SessionWindow.lua` | The live "Current Banking Session" window: its own slim pooled table over the movements of one bank visit. |
| `modules/InsightsWidgets.lua` | The Insights visual vocabulary — pooled cards, bars, back-to-back/ratio/stacked bars, strips, list panels, legends, dividers — plus the categorical palette and label math. Knows nothing about ledger entries. |
| `modules/Insights.lua` | The Insights tab: which breakdown is drawn, out of which `Database:Stats` key, in which color and order. |
| `modules/Export.lua` | Ledger CSV, Insights CSV, and the export modal. Its one wide action button keeps the words **Export to CSV** and gains the `export` mark beside them. **The addon's second `LibKa0s-Widgets-1.0` consumer**, after the filter bar: the modal's **Data set** control is the library's dropdown, reached through `B:MakeDropdown` — not looked up here — so the art and the mono face are injected once, in `modules/Browser.lua`, for both consumers. That factory answers `nil` with no library and this file guards it: no library means **no Data set control**, never a dead one, and the modal still hands over the CSV for the default data set. It *does* look the library up directly (`LibStub("LibKa0s-Widgets-1.0", true)`) for one thing a dropdown cannot do for itself — `W.CloseMenu()` from the modal's `OnHide`, because the popup menu is a process-wide singleton parented to `UIParent` that this modal's own `Hide()` cannot reach. In game the modal is unreachable without the library anyway: the **Export** button that opens it lives on the filter bar, which refuses to build. |
| `settings/Schema.lua` | The schema table (the single source for panel, slash and defaults) and `NS.COMMANDS`. `S:Set` is the **single write seam**: it validates, writes, emits the one debug trace, runs the row's `onChange`, and repaints an open settings panel (options-ui-§1, options-ui-§11) — so a slash write and a panel widget take exactly the same path. |
| `settings/Slash.lua` | The **LibKa0s-Slash-1.0 seam**, plus what stays the host's: AceConsole registration, the five confirm dialogs, `Sl:Version`, and the full reset. The dispatcher, the help renderer and the `list`/`get`/`set`/`reset`/`resetall` CLI are the library's. Supplies `groupKey` (this schema groups by `group`, not `page`), a `format` hook for the set-typed `excludedStores` row, and a `parse` override that refuses a chat edit of that row by name. Wraps `CliResetAll` so the two carve-outs with no Schema widget — the filter lists and the saved ledger view — are still reset. |
| `settings/OptionsSetup.lua` | The **LibKa0s-Options-1.0 seam**. `NS.Helpers` IS the library instance (options-ui-§1), not a wrapper — `settings/Panel.lua` decorates it in place. Supplies the schema seams through `NS.Schema:Set`, so a panel widget takes exactly the path `/bl set` takes. Degrades LOAD-COMPLETING rather than member-answering, with a measured load-time member set of zero. |
| `settings/Panel.lua` | What did **not** generalize: the inverted store grid, the Storage section, the whole Filters page, the landing-page body, `P:Diagnose` and the `P:Batch` refresh coalescer. Registers three pages with the library and lets it own the shell, the makers, the flow engine and the render timing. |

#### Load order is load-bearing

The TOC's file order is not cosmetic in four places, and the comments in `BankLedger.toc` say so at
each one:

- **`core/Compat.lua` loads first**, so every later file can shim through it.
- **`core/EnvSetup.lua` follows it**, before every file that reads a version, a zone or a map id.
  Nothing there resolves at load beyond the LibStub lookup, so unlike the Media seam below this
  position is conventional rather than load-bearing.
- **`core/ItemSetup.lua` sits before `core/Constants.lua`**, and that position is load-bearing:
  `C.QUALITY_OPTIONS` builds its threshold labels through `NS.Item.QualityLabel` at file load,
  so a `Constants` that ran first would index a nil `NS.Item` and raise on login.
- **`core/MediaSetup.lua` sits before `core/Constants.lua`**, and that position is load-bearing
  rather than conventional: `C.FONT_MONO` is *resolved* from `NS.MediaFont` at load, so a
  `Constants` that ran first would resolve the mono face to the client default in a perfectly
  healthy install — with nothing raised and no missing file to find.
- **`core/CoreSetup.lua` sits after `core/Namespace.lua`** (it needs `NS.PREFIX`) and **before every
  file that takes `NS.Print` as a load-time upvalue** — otherwise a module captures the built-in
  printer and never sees the library's.
- **`modules/Filters.lua` precedes `modules/Ledger.lua`**, because the capture gate reads the
  id-lists.
- **`settings/` loads last**, and `settings/OptionsSetup.lua` before `settings/Panel.lua`, which
  captures the library instance at file scope (options-ui-§1).

`tests/test_harness.lua` guards the order the harness derives from that same TOC, so a reshuffle that
breaks one of these is red rather than silent.

#### The `Compat` surface

`core/Compat.lua` is the single file allowed to call a deprecated or patch-varying API — 13 exports
in four groups. It shims **cross-patch** differences, never game flavors (Retail only; no
`WOW_PROJECT_ID` branching), and every reader returns **`nil` rather than a wrong answer**.

The TOC-metadata, map-id and zone reads are **not** here: they were identical in every addon in the
collection, so they live in `LibKa0s-Env-1.0` and are reached through `core/EnvSetup.lua` as
`NS.Meta`, `NS.Version`, `NS.PlayerMapID` and `NS.Zone`. The four item **primitives** are not here
either — `ItemIDFromLink`, `QualityFromLink`, `QualityLabel` and `LoadItem` live in
`LibKa0s-Item-1.0` and are reached through `core/ItemSetup.lua` as `NS.Item.X`.

What stays in `Compat` is what is genuinely this addon’s — the container and guild-bank readers, and
the item **resolver**. `GetItemDetails` and `ItemNameQuality` did not move on purpose: they refuse an
item the client has not cached, the capture gate records the skip as `uncached` and asks the client
to cache the id, and “cannot be judged” is not “passes” (F-006). LootHistory’s resolver guesses from
the link, equally on purpose; a shared resolver would have had to overturn one of the two.

| Group | Exports |
|---|---|
| Player | `GetGuildName` |
| Money | `GetMoney` (the purse), `GetStoreMoney` (a store's **own** balance) |
| Containers | `GetContainerNumSlots`, `GetContainerSlot`, `GetGuildBankSlot`, `GetNumGuildBankTabs`, `QueryGuildBankTab`, `GetCurrentGuildBankTab`, `IsGuildBankVisible`, `GuildBankTabSize` |
| Items | `GetItemDetails`, `ItemNameQuality` — the **resolver** only; the primitives are `NS.Item.X` (see `core/ItemSetup.lua`) |

#### Locale seam

`locales/enUS.lua` publishes `NS.L` with the metatable fallback that returns the key itself, so a
missing key never errors. v1.0.0 ships **English-only and unwrapped**: no user-facing string routes
through `NS.L` yet — every label, tooltip and message is hardcoded English, an accepted scope
decision rather than an oversight. The seam is kept so a later pass can wrap strings without touching
call sites, and there is deliberately no `local L` alias until the first string is wrapped, so the
file stays luacheck-clean.

Input side: the addon matches game data on **stable ids and tokens** — `itemID`, `classFile`,
`Enum.*` — never on a localized name. That is why every entry stores `classFile` rather than a class
name.
