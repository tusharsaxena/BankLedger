# Settings panel

Every user-facing option, the widget that renders it, and the one seam every write takes. The stored
shape behind these paths is [schema.md](schema.md).

## At a glance

The page-granularity summary, moved here out of the README when documentation-§1 made Usage prose
only. The finer tree is everything below it.

| Page | Tabs | Covers |
| --- | --- | ------ |
| General | Master controls · Capture · Filters · Interface · History · Skin · Keybindings | The whole addon, on one strip |
| Profiles | none | AceDBOptions' profile controls: choose, create, copy, delete and reset a profile ([profiles.md](profiles.md)) |

| Tab | Covers |
| --- | ------ |
| Master controls | The addon as a whole, and the same first tab in every Ka0s addon: turn Bank Ledger off, choose when its windows are shown at all, scale and fade them, lock them in place, open the debug console, put a sample ledger on screen (**Test mode**, the same switch as `/bl test`), put the windows back where they started, or return every setting to stock. |
| Capture | What actually gets recorded: **Record items** beside **Minimum quality** (items only; gold has no quality), **Record gold** under them, and which banks you care about, under the **Banks to record** heading. |
| Filters | Two lists of items by id, one per sub-tab. Blacklisted items are never recorded; whitelisted items are always recorded, even below your Minimum quality. Add an item by typing its id or its name, or by shift-clicking its link into the box. As you type, a list of matching items drops down under the box — click one (or pick it with Up/Down and Enter) to add it; an item made in several quality ranks shows one row for each rank you carry or your ledger or lists hold, and typing a name several of those ranks share and pressing Enter without picking adds nothing and asks you to pick. If only one rank is known here, Enter adds that rank: the game has no item-name search, so other ranks stay unknown until you carry them. Use the id to add any rank you want. A name works for an item you carry (or carried this session), one on either list, or one your ledger has recorded; for anything else use the id or shift-click a link. Each entry shows an **X** on the left, then the item's icon, name and id — click the X to remove it — and **Clear all…**, below the list, empties it after asking. Both lists only affect what happens from now on — nothing already in your ledger is ever hidden or removed by them. |
| Interface | What is on screen, under two headings. **Windows**: **Show session window** (whether the Current Banking Session window appears at a bank), then how strongly the tables band their rows and highlight the one under your cursor. **Simulator**: how long a playing simulation waits between steps (**Simulation step delay (seconds)**, 1 second by default). The minimap button is **not** here — it is a Master controls row (`launcher-§3`). |
| History | How much is kept — 30 days by default, for every profile at once — with a read-out of how many movements you have recorded and roughly how big the database is, and **Purge history…**, which empties the history after asking first. |
| Skin | The skin this addon wears: the skin source (Ka0s skins, or EllesmereUI when it can skin the addon), the nine Ka0s skins with their swatches, **Font and texture** (a **Font** and a **Texture** dropdown over the skin's own, the **Reset font** and **Reset texture** buttons, and the **Font outline** dropdown: All text, HUD text only (the default) or Off), the Scope (**Ignore settings panel**, **Ignore fonts**), **Copy to every Ka0s addon…**, and a note that skins change every visual element. Per profile, like every other setting. |
| Keybindings | The one key binding, **Toggle ledger window** (`options-ui-§20`). |

## Shape

**Three** pages registered with `LibKa0s-Options-1.0`, which owns the shell, the widget makers, the
flow engine and the render timing: the **landing page**, **General** and **Profiles**. `settings/Panel.lua` keeps
only what did **not** generalize: the inverted store grid, the History tab's storage read-out, the
Filters tab's secondary strip over the two item-id lists, the landing-page spec (logo, tagline, command rows — drawn by the library's
`O.BuildLandingPage`, which hides the logo when its pooled frame is released) and `P:Diagnose`.
It also carries `P:Batch`, a refresh coalescer that only `tests/test_panel.lua` calls: the global
reset is one `db:ResetProfile()` that walks no rows, and `NS.OnProfileEvent` refreshes the panel
once after it.

**Profiles** (`settings/Profiles.lua`, `options-ui-§3`) is AceDBOptions drawn by AceConfigDialog into
an AceGUI group inside the canvas, opened on first show and re-opened on every render so it reads the
current profile. `P:Register` registers it straight after General, so it is the last entry in the
Settings tree. It has **no Defaults button**: its own Reset Profile is the same act as the global
reset below, and nothing on it is a schema row. Without AceDBOptions, AceConfig, AceConfigDialog or
AceGUI the builder answers nil and the library skips the page.

The **Filters** sub-page is gone. It held no schema rows at all, so it was never a page's worth of
settings — its two lists are one **Filters** tab of General's own strip now, divided by a secondary
strip, and the registration was removed rather than left registered-and-empty.

`NS.Helpers` **is** the library instance (`options-ui-§1`), not a wrapper — `settings/Panel.lua`
decorates it in place, so a member added by the library is available without a re-export.

Opening **refuses** under combat lockdown with a gray notice and never defers:
`Settings.OpenToCategory` is protected, and calling it under lockdown taints the panel for the rest
of the session.

A page that is **already on screen** when combat starts, or is reached in combat through Blizzard's
AddOns sidebar, is **locked** by the library (LibKa0s v1.46.1, `options-ui-§2`/`§13`): a gray cover
reading *Settings are locked during combat.* goes over the whole canvas, every write, Defaults
click and tab switch is refused and put back, and chat gets one gray line per combat.
`PLAYER_REGEN_ENABLED` lifts the cover and re-renders or refreshes the page; nothing is re-opened,
and nothing touches Blizzard's settings window in combat. This addon keeps no combat guard of its own
on a page or the tab strip beside that one.

## The tab strip (`options-ui-§13`)

General is **tabbed**: a strip pinned in the page's chrome band, between the header and the scroll.
A tabbed page draws **no section headings** — the tab is the heading. A tab that mixes *kinds* of
control heads each kind with a **subsection** heading instead, declared by the row's `subgroup`, and
those are deliberately not suppressed (`options-ui-§7`).

| Page | Tab strip, in order | Rows per tab |
|---|---|---|
| Landing page | — (exempt: the host's own `buildMain`, `options-ui-§13`) | — |
| General | **Master controls** · **Capture** · **Filters** · **Interface** · **History** · **Skin** · **Keybindings** | 8 · 4 · 1 · 4 · 1 · 7 · 0 |

Inside **Filters** a **secondary** strip (`O.SubTabStrip`, `options-ui-§13`) divides **Blacklist**
from **Whitelist**. Its selection is `ctx.activeSubTab["Filters"]` — a table keyed by the primary
tab, so leaving Filters and coming back returns to the list you were on — and it is session state,
never persisted, exactly like `ctx.activeTab`. A stale pointer heals to the first list rather than
rendering blank.

The partition is by `group` **in declaration order**, so the row array's order *is* the tab order and
a group's rows must stay **contiguous** — a row filed under a group the page has already left prints
that tab a second time further down. `tests/test_schema.lua` holds the page → tab → count table that
catches both. The array the page partitions is `NS.Schema:PageRows()`, which differs from
`S.Schema` in two places, both since item 020 and both presentation only: the Capture rows come in
`S.CAPTURE_PAGE_ORDER` (Record items, Minimum quality, Record gold, the store grid), and the
Filters row is spliced in straight after them, so Filters is third. `S.Schema`'s own order is what
`/bl list` prints, and it is unchanged; `tests/test_schema.lua` pins it with every path, default and
range ("the stored paths, defaults, types, ranges and CLI order are unchanged").

**The Keybindings tab is the strip's last** (`options-ui-§20`, LibKa0s v1.77.0). It is a **host
tab**, not a schema group: `settings/Panel.lua` hands `O.RenderTabbedSchema` one `opts.tabs` entry,
`O.KeybindingsTab({ bindings = NS.BINDINGS })`, with no `before`, so the library puts it after every
schema tab. The library draws all of it: its fixed intro line, one row per `NS.BINDINGS` entry (today
one, **Toggle ledger window**, the client's `BINDING_NAME_` text) with one **key button** and
**Clear**, then the set line (*Saved for: all characters* or *this character only*) and the outcome
line (OptionsKeybinds minor 4). The key button binds the action's first key and shows it; the
client keeps a second, set on Options → Keybindings, and when the action holds one the button reads
`<key> +1` and its tooltip names every key and says where the others were set. Right-click on the
button removes the first key; **Clear** removes every key. It edits the client's own binding store, saved to the set in force, so a key set here shows on
Options → Keybindings → Ka0s Bank Ledger and the other way round; it repaints on `UPDATE_BINDINGS`
and on show, and refuses every write in combat. A key is not a setting: the page's Defaults,
*Reset all settings* and `/bl reset` never reach one.

**The Skin tab sits after History and before Keybindings, and it is the library's** (skinning-§3).
Its key is `Appearance` and its label "Skin". `settings/Panel.lua` hands `O.RenderTabbedSchema` a
second `opts.tabs` entry, `O.AppearanceTab({ owner, get = NS.SkinChoice, set = NS.WriteSkinChoice })`,
ahead of Keybindings; its key is the group of the eight `skipRender` Appearance rows, declared last in
`settings/Schema.lua`, so the entry takes that group's place. Its body is the library's: the skin
source (two radio choices, *EllesmereUI* disabled with the failing gate conditions listed while it
cannot skin this addon), **Look** (the note, then the nine skins three to a line with their
swatches), **Font and texture** (a **Font** and a **Texture** dropdown side by side, each listing
"Skin's default (<key>)" first and then every LibSharedMedia font or status bar, each previewed in
its own face or with its bar (the library's `Ka0sMedia_*` pickers, LibKa0s v1.83.0; the descriptor's
`getLSM` feeds them and the panel's font preload); under them **Reset
font** and **Reset texture**, each disabled while its half is the skin's own; under those the
**Font outline**, *All text*, *HUD text only*, the default, or *Off*, LibKa0s v1.82.0), the Scope (**Ignore
settings panel** and **Ignore fonts**, side by side), and under its own heading **Other Ka0s addons**,
**Copy to every Ka0s addon…** (a confirmation naming the other loaded owners; it copies the Scope,
the font and texture and the outline too). Picking another skin that draws a different look clears
both overrides (LibKa0s v1.82.0, ruling D-10); `/bl set settings.appearance.skin` stays a raw write
that keeps them. A font override
replaces the skin's body and title face (the mono face and every size stay the skin's); a texture
override replaces the bar texture every bar of data is drawn in (`NS.SkinBar`: Insights' ranked,
stacked, split and back-to-back bars and its day and hour strips); **Ignore fonts** wins over a font
override. `get` and `set` are `core/SkinSetup.lua`'s read and write seams, so a pick is an ordinary
`NS.Schema:Set` write, `/bl get|set` reaches the same values, and every reset puts them back on Ka0s
Default with the settings panel ignored and the fonts skinned (the new-profile defaults). A pick calls
`Skin:SetChoice` (or, for a font or texture, `Skin:SetOverride`; for the outline, `Skin:SetOutline`) first, the live repaint with no
reload, then the write; each row's `onChange` applies only its own half and finds it applied, so one
pick is one repaint. Leaving EllesmereUI after it painted this session asks for a reload (the
library's popup). A profile switch, copy or reset applies the new profile's skin, Scope, overrides and outline
(`NS.OnProfileEvent`). Without LibKa0s there is no settings panel at all (below), and the Options stub's
`AppearanceTab` answers nil, so `settings/Panel.lua` appends no entry.

**The first-run skin picker** (LibKa0s OptionsSkinPicker 1; the layout of OptionsSkinPicker 2, LibKa0s
v1.81.0). A small window titled **Choose a skin**, with the addon's name, **Ka0s Bank Ledger**, on its
own line above the dropdown, never cut off (the window widens to fit it): a dropdown of the skins (three swatches and each name in that skin's own face), an eye
button and a gear beside it, and **Apply**, with **Apply to all Ka0s addons** shown only while another
Ka0s addon that uses skins is loaded. `NS.MaybeShowSkinPicker` (`core/SkinSetup.lua`) shows it while the
profile's `settings.appearance.pickerSeen` is false: two seconds after login (`addon:OnEnterWorld`,
once per session), on an addon that stands up, and after every profile switch, copy or reset (a new
or reset profile starts from `false`). Every profile, existing ones included, starts unseen (the
rollout's ruling O3). Never while the addon stands down, and in combat a start waits for
`PLAYER_REGEN_ENABLED`. A pick **previews**: the skin is worn at once but not saved. **Apply** saves it
through `NS.WriteSkinChoice` and closes the picker; **Apply to all Ka0s addons** does that and gives
every other Ka0s addon that uses skins the same skin source and skin. The close control and Escape put
back the skin the profile stores and save nothing. The eye turns test mode on (`LT:SetTestMode(true)`),
which opens the ledger window with the sample ledger, so the skin shows on this addon's own frames; in
combat test mode refuses and says so. The gear saves the pending pick, opens the settings panel on the
General page itself and selects its Skin tab, then closes the picker. Closing it by Apply, the gear,
its close control or Escape sets `pickerSeen`, so it does not show again on that profile. One picker
is up at a time across Ka0s addons; while another's is up this one waits in the library's queue. A
stand-down, or a profile event (first, before the new profile's skin is applied), takes it down, or
out of the queue, without setting it.

**This addon's own widgets wear the skin too.** Every AceGUI widget `settings/Panel.lua` acquires
itself goes through its `acquire` (`O.AceGUI:Create`, then `NS.SkinPaintAce`): the store grid's
inline group and check boxes, the Filters tab's description, its **Clear all…** row and button, and
the Filters sub-strip host. The Profiles page's renderer calls `NS.SkinPaintAceTree(container)` after
`AceConfigDialog:Open`, because AceConfigDialog acquires from AceGUI itself. Each painted widget goes
back to AceGUI's shared pool stock on release (the library chains its restore onto the widget's
`OnRelease`; no widget here sets a host `OnRelease`), and nothing is painted while **Ignore settings
panel** is on, a new profile's default. The library's own page chrome follows the same switch
(since LibKa0s v1.81.0 the id list's suggestion rows and its id gray too): it wears the skin while
the panel is skinned and goes back to the client's look while it is ignored. An empty id list reads *(none)* in the skin's `text.disabled` while the
page is skinned and in the page's own `|cff808080` while it is ignored (`NS.SkinPanelEscape`, which
gates on `Skin:GetIgnore`, decision D-03 of the skin library follow-ups; `|cff808080` on Ka0s Default
either way), built on every render so a skin switch or a Scope change reaches it with the page's
re-render.

**What the strip partitions is `NS.Schema:PageRows()`, not `NS.Schema.Schema`.** One of the six schema tabs
has no settings behind it: `S.BespokeRows` declares a single **renderer-only** row for Filters, which
carries a `group` (so the tab is drawn) and `skipRender` (so the flow engine walks past it) and
nothing else. It is deliberately not a setting — the lists are an `architecture-§5` structural
registry whose one writer is `NS.Filters`' copy-on-write, which re-caches the capture gate and fires
`LedgerChanged`; a schema row over the same key would hand `/bl set`, `/bl reset` and the reset sweep
a second writer that skips all of that. `allRows` still answers `S.Schema` alone, so the CLI and
every reset see exactly the settings.

**Two tabs hold one declared row and are exempt by name** from "a tab with fewer than two controls
is not a subject": each sits beside bespoke controls that have no path and cannot be counted — the
storage read-out and **Purge history…** on History, and the secondary strip plus the selected list's
**Clear all…** and its LibKa0s `IdList` (the add box and the live id list) on Filters. The exemption is `THIN_TAB_EXEMPT` in
`tests/test_schema.lua`, named rather than a loosened rule.

### The bespoke blocks are `afterGroup` hooks, not page-body calls

`H.RenderTabbedSchema` re-renders **the schema and nothing else** on a tab click: it clears the
scroll and calls itself. Anything the page renderer drew after it would be on the page exactly once,
and gone the moment the player clicked another tab and came back. So every bespoke block hangs off
the library's `afterGroup` table instead:

| Tab | Hook | Draws |
|---|---|---|
| Master controls | `NS.Schema.masterTail` | The composer's own closing `InlineButtonPair` — **Reset position** and **Reset all settings** |
| Capture | `renderStoreGrid` | The inverted per-store checkbox grid (`settings.excludedStores`, `skipRender`): a title-less Flow `SimpleGroup` under the row's own `subgroup` heading, **Banks to record**, which the flow engine draws for a `skipRender` row too, so no builder draws a heading (`options-ui-§7`) |
| History | `renderStorage` | The live storage read-out ("N movements recorded over D days." / "Database size: ~X"), then **Purge history…** alone; while a simulation runs its click is refused before the confirm opens (`Database:PurgeRefused`) |
| Filters | `buildFiltersTab` | The **Blacklist · Whitelist** secondary strip, then the selected list alone via `makeFilterSection` — its blurb, one `O.IdList` (`kind = "item"`, `removeStyle = "icon"` since LibKa0s v1.44.0 — each entry draws an X on the left in place of a right-hand Remove button; `columns = 2` since LibKa0s v1.47.0, a **maximum** the widget falls back from when the canvas is too narrow to pay for two, and the price of packing is that word wrap goes off and a long name loses its trailing id to truncation) whose add box takes an id, a link or a name. A name resolves through the client's lookup (items carried this session) or against `candidates = filterCandidates`: both lists' ids, then every item id the live ledger recorded, newest first, each once, read from `NS.Filters` and `NS.Database:Ledger()` with no new stored state. That list is memoized (`candidateMemo`) until the ledger or either list is a different table, the ledger's length moves (`Add` fires `EntryAdded`, not `LedgerChanged`), or any `LedgerChanged` bumps its version in the tab's listener; with no bus target the memo stays off. The library's dropdown lists matches as the player types, one row per crafted-quality rank that the bags or the candidates hold (there is no client name search, so a rank nothing here has seen is not listed). It refuses a name two of those ids share (candidates or bag items) until one is picked; a name with one known rank adds that rank. Its refusal ends with `ITEM_NAME_HINT` (`strings.nameHint`), which the box's tooltip repeats. Its add and Remove call `NS.Filters`' own writers through `filterWrite`, which holds the tab's `LedgerChanged` repaint off so one click redraws the page once, via `ctx.rebuild` (this page only); then, last and on its own line, **Clear all…** (a host button behind a confirm). Both blurbs close with the two sentences Ka0s Loot History's close with: *Applies to future movements only; rows already recorded stay. An item can be on one list only; adding it here takes it off the other.* |

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
| Master scale | Master opacity |
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
  | Master opacity | `settings.alpha` | `NS.Util.ApplyMasterFrame` → `frame:SetAlpha`, at construction and on every settings change |
  | Lock frame | `settings.locked` | `NS.Util.ApplyMasterFrame` → `frame:SetMovable(not locked)`; every drag handler calls `StartMoving`, which the client makes a no-op on an unmovable frame |

  *Lock frame*'s tooltip is the composer's, then `S.MASTER_SPEC.notes.locked`: *Covers the ledger,
  session and export windows.* (compose minor 9, item 020).

- **General visibility is a dropdown, not a boolean** — `Always` / `Only in combat` / `Only out of
  combat` / `Never`. This addon never shipped a *show only in combat* checkbox, so there is **no
  stored value to migrate** and `SCHEMA_VERSION` is unmoved. A window the rule takes off screen is
  remembered in `NS.State.hiddenByVisibility`, so the transition back re-shows exactly what the rule
  took and never a window the player had closed themselves.
- **Debug console** is the session-only row it always was (`state.debugConsole`, verbatim and
  unprefixed); what changed is only where it is declared. It moved off the Interface tab.
- **Minimap button** (`minimap.shown`, stored as LibDBIcon's `minimap.hide`, first column of the fourth line; LibKa0s v1.39.0,
  compose minor 7) is the launcher's visibility row, emitted from `minimapPath`. Every addon has a
  minimap button and only some have a test mode, so the always-present row takes column 1 and the
  optional one pairs beside it. Its sense is inverted at the write seam — see the note under the
  row table — and the button it drives is `NS.Launcher`'s
  ([ARCHITECTURE.md ▸ Launcher](ARCHITECTURE.md#launcher)). It REPLACED the Interface tab's *Hide
  minimap button*, on the same stored path. The button's hover tooltip (drawn by LibKa0s-Launcher
  minor 3, enabled or disabled) reports this block's states back: `Enabled` from the *Enable* row's
  latch, `Locked` from *Lock frame*'s stored `settings.locked`, and `Test mode` from the *Test mode*
  row's own `get`, each read on every hover. The button's **left** click opens this panel, and its
  **right** click opens the options menu (LibKa0s-Launcher minor 4, standard v2.67.0), whose checkboxes
  are three of this block's rows plus the ledger window: *Enabled* runs `/bl enable|disable` (the
  *Enable* row's path), *Locked* runs `/bl set settings.locked` (the *Lock frame* row), *Test mode*
  runs `/bl test` (the *Test mode* row's switch), and *Show window* runs `/bl toggle`. While the addon
  is disabled only *Enabled* is live. Beside *Show window* sits its **key binding** (`launcher-§6`):
  **Toggle ledger window**, set under Options → Keybindings → Ka0s Bank Ledger or on General >
  Keybindings in this addon's settings (`options-ui-§20`), with no default key, which clicks a hidden button running that same `/bl toggle` handler and, while the addon is
  disabled, answers with `/bl toggle`'s refusal line instead.
- **Test mode** (`state.testMode`, session-only, pairing beside *Minimap button*; standard v2.47.0) is the one switch
  for the **sample ledger**, the same as `/bl test`. It does not touch the session-window preview:
  `/bl session` stays its own verb, which was the owner's call. The composer emits it from
  `testModePath` with no default, so `S.MASTER_SPEC.defaults.testMode = false` is what lets a reset
  end it. `S.MASTER_DECOR` binds `get` to `LT:IsTestMode()` and a `set` that acts only when the
  value differs. Its tooltip is the composer's, then this addon's note, `S.MASTER_SPEC.notes.testMode`
  (compose minor 9): what it shows here, that it is `/bl test`, and *To place the session window,
  use /bl session.* A host never rewrites a composed tooltip; `notes` is the one way to extend it. Every start and stop runs
  through `LT:SetTestMode`, which repaints an open panel, so the box follows `/bl test` and the
  combat ending as well as its own clicks.
  - **Ticking it** loads the sample and opens the ledger window. The start is **refused** in combat,
    and when General visibility would keep the window shut. Either way one chat line says why and
    the box goes back to unticked.
  - **Combat ends it.** `addon:OnCombatChanged` stops it on `PLAYER_REGEN_DISABLED` and prints
    `test mode off — combat started.`. A stop never opens the ledger window.
  - **The global reset ends it.** Test mode lives in `NS.State`, never in the profile, so the
    profile reset cannot reach it; the profile handler (`NS.OnProfileEvent`) ends it by name on
    every reset, and closes the debug console the same way (`state.debugConsole` defaults to
    false).
- **Reset position** is a real button now. The act existed only as a side effect folded into
  `P:RestoreDefaults`; it calls `NS.Util.ResetWindowPositions()`, which is the one body.
- **Reset all settings** raises the confirm-gated `KA0S_BANKLEDGER_RESETALL` popup, whose text is
  `options-ui-§12`'s first canonical wording byte for byte (the one for an addon with a profile).
  `OnAccept` runs `NS.Slash:ResetEverything`, which calls `db:ResetProfile()`: the **active
  profile** is emptied and its defaults merged back — every setting, both filter lists, the saved views (one per tab) and both windows' geometry. The **recorded ledger**,
  the retention window that governs it and LibDBIcon's `minimap` table are account-wide and are
  **kept**, and so are the other profiles.
  AceDB's `OnProfileReset` reaches `NS.OnProfileEvent`, which ends the session-only rows by name,
  re-applies everything and re-anchors the windows. Since schema v3 this is the "addon with both"
  form of `options-ui-§12`; until then it emptied `db.global` wholesale, history included. It used to be the right half of History's button
  pair and **moved rather than being duplicated**.

  **It is the ONE global reset (`options-ui-§12`).** The header **Defaults** button, Blizzard's
  footer **Defaults** (which forwards to it) and `/bl resetall` all reach the same popup through
  `NS.Slash:RequestResetAll`, the single entry point; with no popup API it runs the reset directly.
  The Profiles page's **Reset Profile** is the same act without the popup, because AceDBOptions asks
  nothing. Nothing changes before the player says Yes, and no route deletes recorded history:
  `/bl purge` is that act, confirmed separately. The `resetall` verb is described as *Reset this
  profile's settings to defaults; history is kept (asks first)*. Until BankLedger-A-02 the Defaults
  pair and `/bl resetall` ran a non-destructive schema walk instead — three routes over two
  implementations, carried as a register row that is now closed.

  **The header Defaults carries this button's own words** (`options-ui-§12`, LibKa0s v1.77.0,
  item 020): its `defaultsTooltip` is `O.ResetAllTooltip(O.KEYBINDS_UNCHANGED)`, the library's
  *Reset all settings* tooltip read from the descriptor the way the composer reads it, then
  *Key bindings are not changed.* The host writes no wording around it, so the two controls for one
  act cannot describe it two ways.

  With logging on, the profile handler writes one line (`debug-logging-§10`), never a line per row:
  `[Set] reset profile '<name>' to defaults (N rows)`, N the stored rows that changed, counted by
  `Sl:ResetEverything` before the reset. A reset from the Profiles page logs the same line without
  the count.

## Rows

`settings/Schema.lua` is the single source: it drives the panel widgets, the slash `get`/`set`/
`list`/`reset` dispatch, and the defaults reset. Every write to a schema-row path goes through
`NS.Schema:Set`.

Rows render in schema order (except Capture, drawn in `S.CAPTURE_PAGE_ORDER`, and the Filters tab
spliced in after it; see the tab strip above), so this table is also the panel's layout — tab by tab, and two rows to
a line within a tab unless a row declares `solo`, `wide` or `startsLine`, or a `subgroup` boundary
flushes the line.

A slider row **must declare its `step`**: `LibKa0s-Options-1.0`'s `makeSlider` assumes 1 when the row
omits it, which would snap a fractional range to its two endpoints and nothing in between. The
composed rows carry their own; the two tint sliders declare `0.01` and the simulator's step delay
`0.5`.

| Path | Type | Default | Tab | Subsection | Layout |
|---|---|---|---|---|---|
| `settings.enabled` | bool | `true` | Master controls | — | `startsLine`, pairs with `visibility`. **The master switch.** Its `onChange` drives the `disabled` hold on the lifecycle latch (`core/LifecycleSetup.lua`), so unticking it actually stands the addon down — every registration unregistered, every timer canceled, both windows down — rather than hiding it (`slash-commands-§7`). `/bl enable` and `/bl disable` are aliases onto this same write. |
| `settings.visibility` | string | `"always"` | Master controls | — | |
| `settings.windowScale` | number | `1.0` | Master controls | — | `startsLine`, pairs with `alpha` |
| `settings.alpha` | number | `1.0` | Master controls | — | `min` narrowed to `0.1`, the honored floor |
| `settings.locked` | bool | `false` | Master controls | — | `startsLine`, pairs with `debugConsole` |
| `state.debugConsole` | bool (session-only) | `false` | Master controls | — | |
| `minimap.shown` | bool | `true` (stored inverted as `minimap.hide = false`, so the box ships ticked) | Master controls | — | `startsLine`, pairs with `testMode` |
| `state.testMode` | bool (session-only) | `false` | Master controls | — | pairs beside `minimap.shown` |
| `settings.trackItems` | bool | `true` | Capture | — | *Record items*; on the page pairs with `qualityThreshold` |
| `settings.trackMoney` | bool | `true` | Capture | — | *Record gold*; on the page alone on the second line |
| `settings.qualityThreshold` | number | `0` | Capture | — | *Minimum quality*; drawn beside `trackItems` (`S.CAPTURE_PAGE_ORDER`) |
| `settings.excludedStores` | table (muted set) | `{}` | Capture | Banks to record | `wide`, `skipRender` — drawn by `renderStoreGrid` |
| `settings.showSessionWindow` | bool | `true` | Interface | Windows | *Show session window*; `solo`, a line of its own above the tint pair |
| `settings.rowStripeAlpha` | number | `0.03` | Interface | Windows | pairs with `rowHoverAlpha` — rest beside hover, read across the line |
| `settings.rowHoverAlpha` | number | `0.10` | Interface | Windows | |
| `settings.sim.stepDelay` | number | `1` | Interface | Simulator | *Simulation step delay (seconds)*, its tooltip opening "Paces /bl sim: "; alone under its heading; slider 0.5–10 s in 0.5 s steps, with a `validate` (`NS.SimHost.ValidStepDelay`) |
| `settings.retentionDays` | number | `30` | History | — | **Account-wide**: stored in `db.global.settings`, not the profile (owner decision D6), through the row's own `get`/`set`; the tooltip says so |
| `settings.appearance.source` | string | `"ka0s"` | Skin (key `Appearance`) | — | `skipRender`: the library's Skin tab draws it. `ka0s` or `eui` (`NS.SKIN_SOURCE_OPTIONS`); `onChange` applies only the source half |
| `settings.appearance.skin` | string | `"ka0s"` | Skin | — | `skipRender`. One of the nine registered skins (`NS.SKIN_OPTIONS`), so `/bl set` refuses a key no skin has; `ka0s` is Ka0s Default |
| `settings.appearance.ignorePanel` | bool | `true` | Skin | — | `skipRender`. **Ignore settings panel**: this addon's settings pages stay the client's; its windows still wear the skin |
| `settings.appearance.ignoreFonts` | bool | `false` | Skin | — | `skipRender`. **Ignore fonts**: every string keeps its own face and size, the library's controls and tool windows included; wins over a font override |
| `settings.appearance.font` | string | `""` | Skin | — | `skipRender`. **Font**: an LSM font key over the skin's face, `""` for the skin's own; free text, so a media pack's later key is accepted |
| `settings.appearance.texture` | string | `""` | Skin | — | `skipRender`. **Texture**: an LSM status bar key for every bar of data, `""` for the skin's own |
| `settings.appearance.outline` | string | `"hud"` | Skin | — | `skipRender`. **Font outline** (LibKa0s v1.82.0): `all` text, `hud` text only or `off` (`NS.SKIN_OUTLINE_OPTIONS`, the library's modes), so `/bl set` refuses any other; `onChange` applies it with `Skin:SetOutline`. Ignore fonts grays it out and wins |
| `settings.appearance.pickerSeen` | bool | `false` | Skin | — | `skipRender`, drawn by nothing: the first-run skin picker was closed on this profile |

**The `settings.retentionDays` row is the one setting outside the profile.** It decides how much of
the shared ledger is kept, so every profile reads the one value (`db.global.settings.retentionDays`,
[profiles.md](profiles.md)), and its tooltip opens *Account-wide: shared by every profile.*
(`options-ui-§21`); the label carries no suffix. No profile switch, copy or reset changes it, so none of them
can prune history. It is on `NS.Schema.RESET_EXEMPT` beside the minimap row, so a row sweep skips it
(a sweep putting *Always* back to 30 days would prune); a targeted
`/bl reset settings.retentionDays` still applies.

**The `settings.sim.stepDelay` row is the simulator's pace.** It is how many seconds a playing
simulation waits after a step before it plays the next; the
default is 1 s (until the owner's 2026-10-23 ask it was a fixed 1.5 s constant, never a row). It has
no `onChange`: `modules/Sim.lua`'s `Host.StepDelay` reads the stored value at every step, so a change
lands on the next step, a running session included. A step's own `settle` still raises the pause above
it (`Host.DelayAfter`, the descriptor's `stepDelay`), and a stored value the row would refuse — off the
0.5 s grid, outside 0.5–10, or not a number — reads as the 1 s default. The row's `validate` is that
same check, so the slider and `/bl set` refuse an off-grid value (the slash library clamps an
out-of-range number to the range first). The default is hardcoded once, in `defaults/Profile.lua`;
the range and grid are `NS.Constants.SIM_STEP_DELAY_MIN` / `_MAX` / `_STEP`.

**The `minimap.shown` row is stored backwards, and that is deliberate.** Its label and its CLI
path say SHOWN — ticked, or `/bl set minimap.shown true`, means the button is on the minimap —
while the stored boolean is LibDBIcon's own `hide`. The key is the
library's: it writes that same field itself when the player hides the button from its right-click
menu, so a second boolean beside it would be a copy free to disagree (`launcher-§3`,
anti-pattern #81). The inversion lives in **one** place, `NS.Schema:Set` / `NS.Schema:Get`, and the
button is moved from the row's `onChange` through `NS.Launcher:SetShown`. This row REPLACED the
Interface tab's *Hide minimap button*, which said the opposite over the same key; nobody's stored
choice moved. The CLI path was `minimap.hide` until standard v2.65.0 renamed it to read in the
row's own sense (`launcher-§3`); the stored key did not move, so there was no SavedVariables change
and no migration, and the old path now answers `Setting not found`.

**And it is the one row no reset on this page reaches.** A player's minimap-button choice is a
per-installation display preference, like the angle they dragged the button to, so `launcher-§3`
requires it to survive both *Reset all settings* and this page's own **Defaults** button — and both
reached it here until the standard's v2.54.0 amendment. `NS.Schema.RESET_EXEMPT` names the row once
and `S:ApplyDefault` honors it. The global reset needs nothing more: since schema v3 it is
`db:ResetProfile()`, and the `minimap` table lives in `db.global`, which no profile event reaches
(until then the reset emptied `db.global` wholesale and held the table across the wipe).
A targeted `/bl reset minimap.shown` is not a sweep and still works. See
[ARCHITECTURE.md → Launcher](ARCHITECTURE.md#launcher).

**No color rows.** Nothing here is `type = "color"`, so `options-ui-§17`'s class-color companion has
nothing to attach to and `settings/OptionsSetup.lua`'s descriptor carries no
`colorDecode`/`colorEncode`. Adding a swatch means adding both, and reaching for `H.ColorPair` rather
than hand-writing the pair. `tests/test_schema.lua` pins the emptiness so the companion loop beside
it is a guard rather than a vacuous one.

**No font, border or bar group, and no reorder list.** This addon paints no status bar, exposes no
font picker of its own (the Skin tab's **Font** and **Texture** are the library's) and stores no list
whose *order* is a setting, so `options-ui-§16` and `§18` have nothing
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
  slider not working. A non-number falls back to the shipped default, not to zero. **Master opacity**
  is clamped the same way, in `NS.Util.ApplyMasterFrame`, with a floor of `NS.Constants.MASTER_ALPHA_MIN`
  (`0.1`): a stored `0` would be an invisible addon with no way back to the panel that set it.
  That floor is also the **row's declared `min`** — `S.MASTER_DECOR["settings.alpha"]` narrows the
  composer's canonical `0` to the same constant, so the slider cannot offer a stop the drawing code
  refuses. Left at `0`, its two lowest positions would both render at `0.1` and be indistinguishable:
  a declared setting that is not honored (`STEP 4.3`). The clamp stays regardless, because
  SavedVariables is hand-editable and the slider is not the only way a value gets in. Contrast the
  two tint sliders, whose clamps stay *inside* their declared `0`–`0.3` range and so need no such
  narrowing.
- The **alpha** is the player's, the **color** the skin's: the stripe takes `list.stripe`'s RGB and
  the hover `list.hover`'s (white and gold under Ka0s Default, the values these rows always drew), so
  each skin bands its rows in its own colors while the two sliders keep their meaning and defaults
  (DECISIONS BankLedger D2). `NS.Util.ReskinRowTint` re-reads the RGB on a skin switch.
- `NS.Util.ApplyRowTint` is the single read, called from `BuildRow` (so a row is right the moment it
  exists) and from `BindRow` (so a recycled row re-reads after the slider moved).
  `NS.Util.RefreshRowTint` is the `onChange`: it rebinds both tables directly and broadcasts
  `SettingsChanged` beside it, the same shape `settings.windowScale` uses.

**Defaults asks first.** On General, `OnDefault` forwards to whatever the page parked as
`defaultsOnClick`, so Blizzard's footer control and the addon's own header button are one
implementation rather than two kept in step. That action is `P:RestoreDefaults()`, which only calls
`NS.Slash:RequestResetAll()` — the confirm-gated `KA0S_BANKLEDGER_RESETALL` popup, the same one
*Reset all settings* raises (`options-ui-§12`). Blizzard's un-gated footer control therefore changes
nothing without the player's Yes, and Yes is the profile reset (`db:ResetProfile()`): the active
profile's settings, both filter lists and the saved views (one per tab) go back to their defaults,
and the recorded ledger, which is account-wide, is kept. `/bl purge` is the act that deletes history.

## The General page's tabs and the Filters tab

The twenty-five schema rows all live on the **General** page, which is **tabbed** (`options-ui-§13`): `group` names a tab,
the array's declaration order is the tab order, and the strip reads **Master controls** (8) ·
**Capture** (4) · **Filters** · **Interface** (4) · **History** (1) · **Skin** (8, the Appearance group,
drawn by the library's entry), then the library's host tab **Keybindings** (`options-ui-§20`, above). Filters carries no settings at
all — it is the retired **Filters** page's id-lists, drawn from an `afterGroup` hook under one
renderer-only row (`S.BespokeRows`) that exists to name a tab and nothing else, which is why
`NS.Schema:PageRows()` and not `NS.Schema.Schema` is what the strip partitions. Inside that tab a
**secondary** strip (`O.SubTabStrip`, `options-ui-§13`) divides Blacklist from Whitelist; its
selection is `ctx.activeSubTab["Filters"]`, session state and never persisted. Each list is one
LibKa0s `O.IdList` (`kind = "item"`, v1.35.0): the widget resolves an item id, a link or an item's
name and calls back into `NS.Filters`, which stays the lists' only writer. The client has no
item-name search (its name lookup answers only for items carried this session), so the list passes
`candidates`: both lists' ids plus every item id the ledger recorded, read from existing state. The
widget names them, suggests matches as the player types (one row per crafted-quality rank), and
refuses a shared name until one is picked. The lines are drawn **two to a row** (`columns = 2`,
LibKa0s v1.47.0): both lists are fed one id at a time out of a long ledger, so one entry per line
made a scroll re-read on every visit. It is a **maximum**, not a count -- since v1.50.0 the widget
measures the content width it has and falls back toward one column when two cannot be paid for, so
a narrow settings canvas returns the old layout with nothing here having to know its width. The
cost, taken knowingly: above one column word wrap goes off, so an entry too long for its column is
cut from the tail and loses its gray `(id)` rather than shortening it; the entry's tooltip still
carries the full name. That write fires
`LedgerChanged` synchronously, so the tab's own listener is held off for it (`filterWrite`'s
`ctx.__filterWrite`) and the widget's redraw goes through `ctx.rebuild` = `O.RefreshPanel(ctx, true)`:
one add or Remove repaints this page once, rather than twice across every rendered page.

Those tab names and their order are **shared with Ka0s Loot History**, whose strip is the same plus
**AH price** (its item 020 change LOO-L08 moves its Filters to the same third place). The two addons keep the same shape of record and a player
compares their panels directly; one naming a subject *Capture* while the other called it *Collection*
was two names for one thing. A tab name is a `group`, never a stored path, so the convergence was a
rename and carried no migration (`options-ui-§15`).

The **Master controls** tab is composed by the library (`H.MasterControls`, `options-ui-§15`) and
spliced at the head of the array; `keys = { scale = "windowScale" }` is what keeps this addon's
stored paths. Three of its rows are new — `settings.visibility`, `settings.alpha` and
`settings.locked` — and each is honored in `NS.Util` rather than merely declared. Two other rows are
chrome literals promoted to settings in the tabbed-panel pass — `settings.rowStripeAlpha` and
`settings.rowHoverAlpha`, each defaulting to the number it replaced, under the Interface tab's
**Windows** subsection beside the session window's switch. Its second subsection, **Simulator**,
holds the simulator's step delay (`settings.sim.stepDelay`).

## Bulk writes and the reset routes

**A bulk reset logs one line** (`debug-logging-§10`, standard v2.44.0). The seam logs one
`[Set] <path> = <value>` per write, except inside a bulk bracket: `S.BulkBegin` / `S.BulkEnd`, the
instance's pair, which both descriptors take as `bulkBegin` / `bulkEnd` (LibKa0s Slash minor 8).
Inside the bracket the seam mutes that line, and it counts each write whose read-back value actually
changes (`S.SameValue`, deep for the set-typed row). Validation and each row's `onChange` still run
per row.
- The library's own `CliResetAll` walk logs exactly `[Set] reset all: N rows`. N is the rows whose
  value changed, so a walk with every row already at its default logs `0 rows`. The library's own
  `count` is not used, because it includes rows already at their default. **No host route runs that
  walk any more**: `/bl resetall` and both Defaults controls are the one global reset below
  (`options-ui-§12`). The Slash descriptor still hands the library the pair, and
  `tests/test_slash.lua` drives the walk on an instance built from the same seam members.
- A walk that raises part-way still logs its one line, counting the rows changed before the raise,
  with ` (stopped by an error)` appended: `[Set] reset all: N rows (stopped by an error)`. The mute
  still clears and the error is re-raised unchanged. The library hands `bulkEnd` `err = nil` for a
  raise of nil or false (documented upstream), so that raise gets no marker.
- Nested brackets log once, for the outermost act, and a level reporting `info.profileReset` silences
  the line. `P:Batch` is not a bracket either. It only coalesces repaints, and only tests call it.
- The Options descriptor carries the same pair and `applyDefault`, so `O.RestoreDefaults` would skip
  the Minimap button row and log `[Set] reset general: N rows`. Nothing here calls it or
  `O.RestoreAllDefaults` today; before LibKa0s v1.55.0 that field wrote `S:Set(path, S:Default(path))`
  with no bracket and would have swept the Minimap row.
- `Sl:ResetEverything`, the one global reset that Reset all settings, both Defaults controls and
  `/bl resetall` reach through `Sl:RequestResetAll`, is `db:ResetProfile()`, not a walk through the
  seam. The profile handler logs one `[Set] reset profile '<name>' to defaults (N rows)` line, N the
  stored rows that were not already at their default.

## In a degraded install

Where `libs/LibKa0s` is missing entirely, `settings/OptionsSetup.lua` takes its load-completing stub
branch and there is no settings panel at all — which is the documented degradation. One consequence
is worth stating because it is not obvious: the **Master controls rows are composed by the library**,
so on that path they are absent from `NS.Schema.Schema` and `/bl list`, `/bl set` and `/bl reset`
cannot reach those eight paths. `/bl get` still can — `Schema:Get` falls through to the stored value —
and every stored one is still read and honored by the drawing code, because the defaults live in
`defaults/Global.lua`. The two session-only ones keep their verbs: `/bl debug` and `/bl test`. The alternative would be a host copy of the canonical block in the stub, which
is exactly the drift the composer exists to end (anti-pattern #73).
