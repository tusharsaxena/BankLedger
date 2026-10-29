# Windows

Two standalone windows, both plain non-secure frames sharing one skin seam (`B:ApplySkin`) and one
close-button factory (`modules/Browser.lua`), each with its own persisted geometry carve-out.

**Both wear the player's skin** (skinning-§3; [ARCHITECTURE.md → Skins](ARCHITECTURE.md#skins)).
`B:ApplySkin` hands the frame to the owner's `Shell` (`NS.Skin.Shell`, LibKa0s-Skin-1.0) with
`noTopBar`, and each title bar paints its own fill and title through `NS.Skin.TitleBar`, its divider
through `NS.Skin.Divider`; the export modal does the same on its 26px bar. Under Ka0s Default that is
the edge these windows always wore (the 1px black border, the 1px light-gray line just inside it, the
gold title and the gray divider) plus the skin's faint `title.bg` band on the title bars and
`list.header.bg` on the table headers (DECISIONS BankLedger D6). Every frame is recorded for this
addon's owner, so a skin switch repaints it live; the pooled rows, the tab labels and the tinted marks
are redone by `NS.Skin.OnLooksChanged` listeners. Without the library the degraded facade's `Shell`
routes to `core/CoreSetup.lua`'s pre-library `NS.ApplySkin`, which draws the same Ka0s Default edge.
`B.SKIN` keeps only the layout heights; no color lives there.

The debug console and its copy box are a third and a fourth standalone frame, but they are the
**library's** — `LibKa0s-DebugLog-1.0` draws them, painted for this addon's skin owner because the
descriptor passes `addonName` and **no** `applySkin` (DebugLog minor 22). What it does not pass
either is a close-button factory: those two windows close with the library's own 18×18 control, not
the 24×24 one `B:MakeCloseButton` builds for the ledger and session windows. `standalone-windows`
draws the line there — the edge is the skin's on every Ka0s window, the close control on a
library-drawn window belongs to the library — and the point of it is that a user comparing two Ka0s
consoles side by side sees one collection's diagnostics surface, not five different ones.

Both factories now draw the **same mark**, from opposite directions. `LibKa0s-Media-1.0` ships the
collection's `close` icon; the library resolves it for its own windows once the descriptor passes
`addonName`, and `B:MakeCloseButton` resolves it through `NS.Icon` for these two. Neither deleted
what it drew before: without LibKa0s the library falls back to a multiplication sign and this addon
falls back to its own 24pt ×, and both windows still close. The sizes still differ on purpose — an
18×18 control on a 26px library title bar, 24×24 on this addon's 30px one. `B:MakeCloseButton` paints
through the skin's `CloseButton` with `stockDefault`: under Ka0s Default the host keeps its own 0.85
rest (`bl.closeRest`) and the player's class color on hover; under every other skin the primitive
draws `close.rest` and `close.hot` (DECISIONS BankLedger D1). See [media.md](media.md).

**Master scale, master alpha and `Lock frame` are one seam, not per-window settings.** Every movable
frame this addon builds — the ledger window, the session window and the export modal — calls
`NS.Util.ApplyMasterFrame(frame)` at construction, after its own `SetMovable(true)`, and
`NS.Util.ApplyMasterChrome()` re-applies all three across the set whenever one changes. `Lock frame`
*is* `SetMovable(false)`, which the client makes `StartMoving` a no-op against, so there is no second
guard in any drag handler to keep in step. Master opacity is clamped up to `NS.Constants.MASTER_ALPHA_MIN`
on the way in — a stored `0` would be an invisible window with no way back to the panel that set it.
See [settings-panel.md](settings-panel.md) → *Master controls*.

**When geometry is written matters as much as what is written**, and the obvious answer is wrong. The
natural call sites — the end of a drag, the end of a resize — fire at the end of an *interaction*,
and the resize one is easy to miss outright: releasing the grip a pixel outside a 16×16 button never
delivers its `OnMouseUp`. Miss it and the geometry lives only in the frame, which survives every
`Hide`/`Show` — so it looks perfectly persistent for a whole game session and is gone on the first
`/reload`. Worse, the in-memory frame masks the fault: the window keeps its place all session
*without SavedVariables ever being read back*, so the save path is never exercised and never seen to
be broken.

Both windows therefore anchor the save to moments that are **guaranteed**, through the same two
method names:

| Seam | Runs |
|---|---|
| `SaveGeometry()` | Every `OnHide`; `PLAYER_LOGOUT`; plus drag-stop and resize-stop, which keep the stored value current mid-session |
| `ApplyGeometry()` | Once, when the frame is built on first show |

**The resize grip is LibKa0s-Core's.** Both windows call `NS.MakeResizable(frame, { minWidth, minHeight,
onResizeStop })`, the `core/CoreSetup.lua` seam over `Core.MakeResizable`. It makes the frame
resizable, bounds it at the window's floor and draws the grip in the bottom-right corner, 1px inside
the edge. *Resize-stop* above is the grip's `onResizeStop`, which runs once per release and runs
`SaveGeometry()` and then the table refresh. Neither window passes `onResize`: it also runs on every
`OnSizeChanged`, so a save there would write on every drag tick and make `ApplyGeometry()` and
*Reset position* write geometry. The tables re-flow live through their scroll frames' own
`OnSizeChanged`. *Lock frame* gates only the drag, so a locked window still resizes. With the library
absent, the seam's fallback is the pre-library grip (2px inset, no pressed art), and it still saves
on release.

`SaveGeometry()` refuses to write a point-less table — one would make `ApplyGeometry()` fall through
to the default and silently discard a real position — and `ApplyGeometry()` clamps a restored size to
the window's floor on the way *in* as well as out, so a size saved against an older column set (or a
hand-edited SavedVariables) cannot reopen a window too small to read.

| Window | Frame | Opened by | Contents |
|---|---|---|---|
| Ledger | `BankLedgerWindow` | `/bl show`, the minimap button | History table + Insights, over one filter bar; each tab keeps its own filter state and saved view |
| Current Banking Session | `BankLedgerSessionWindow` | a bank frame opening (`SessionChanged`), or `/bl session` | One slim table of this visit's movements |

**One strip per mode on the ledger window, and the badge only where no strip was built**
(BankLedger#23, #24). `LibKa0s-Widgets-1.0`'s `TestStrip` (LibKa0s#48; the `kind` flavor since
minor 14) is built twice by one local, `buildModeStrip(filterHost, kind, text)`, and both hang 2px
under the filter bar: `frame.testStrip`, the amber test flavor with the `info` mark and *TEST MODE: a
sample ledger, not your bank. Combat ends it.*, and `frame.simStrip`, the cyan simulation flavor.
Their texts go through `NS.L`. The library publishes the strip's height (`W.TEST_STRIP.HEIGHT`, 18)
and deliberately no reserve, so `modules/Browser.lua` computes its own: `HEIGHT + 2 * STRIP_GAP`
(22) while either strip shows, 0 otherwise or with no Widgets library. `anchorPanes()` hangs both the
History and the Insights pane from the filter bar's bottom plus that reserve, and
`B:UpdateTestStrip()` (from `B:Show` and `B:OnDatasetChanged`, so `/bl test`, the Master controls
box, the launcher menu and the combat ending all reach it) shows the dataset's strip, hides the
other, and re-anchors the panes. Each strip's mouse is on for one plain `GameTooltip`: *Test mode*,
what it shows, and what ends it. The red `TEST MODE` title badge is the **degraded fallback only**:
it shows in test mode when no strip was built (no Widgets library, so no shift either), and never
beside a strip.

**A simulation is marked by the simulation strip, never the badge** (BankLedger#24, `preview-mode`,
`LibKa0s-Sim-1.0` host contract H8). While `Database:DatasetKind()` is `"sim"`, `B:UpdateTestStrip()`
sets `frame.simStrip`'s text to *Simulation: &lt;scenario&gt; - nothing here is saved.* (the running
scenario's label, `NS.SimHost.MarkerText()`) and shows it with the same 22px reserve; the test strip
and the badge stay hidden. Its tooltip (`B.StripTipLines()`) says *Simulation*, what it
shows and what ends it (`/bl sim stop`, combat, a real bank window). The **session window** draws the
simulated rows too, so it gets its own `TestStrip` in the simulation flavor (`kind = "sim"`,
`f.simStrip`) with the same line while the dataset is `"sim"`,
anchored 2px under its title bar, its pane moved down by `HEIGHT + 4` (`SW:UpdateTestStrip()`, also
run on every `SW:Show`). Test mode never marks the session window: its session rows are real. Both
strips read the one predicate, and a session listener (`NS.Sim:AddListener` in `modules/Sim.lua`)
repaints both when a simulation starts and when it stops.

**The simulation step panel** (`BankLedgerSimPanel`) is `LibKa0s-Sim-1.0`'s, not this addon's: its
rows, states, run controls, scenario picker, click-ahead and placement are the library's.
`modules/Sim.lua` passes only the presentation fields (`NS.SimHost.PANEL`): the title
*Ka0s Bank Ledger - Simulation*, each step's label built from the real item (*Deposit 20 × Linen
Cloth to Warband Bank*, with *(N recorded)* once the engine has recorded rows for it), its tooltip
(what it moves, a lagged warband half, the client events it fires, and once played what it did and
how many rows it recorded), the Start and Stop tooltips, and the `confirm` tick. A start opens it
(from `prepare`, after the ledger window), as does a bare `/bl sim`; `/bl sim panel` toggles it. It
**docks** right of the ledger window (8px, top edges aligned), or left when the right has no room, and
floats when the ledger window is shut (`NS.SimHost.PanelAnchor()` answers the window only while it is
shown). **Its position is session-only** (OWNER_SCOPE C.11, host contract H10): a dragged point is
held in the library instance's memory and nowhere else, so it is **not** window state, has no schema
row and no default, and a `/reload` forgets it; `NS.Sim:ResetPanelPosition()` redocks it. Nothing a
simulation does writes to SavedVariables. A stand-down stop hides it.

The session window is **not** a second `NS.LedgerTable` instance. That module is a stateful singleton
— one row pool, one display list, one sort/group/filter/collapse state — and the session table has
none of those, so a slim renderer is smaller than the refactor generalizing it would take. What the
two **do** share is the definition of a column: `LedgerTable:Column(key)` hands out the spec (label,
width, align, tooltip, `valueFn`) and `LedgerTable:PaintCell(fs, key, entry, glyph)` sets a cell's
text and color, so a column cannot read one way in one window and another way in the other.

Its column set is the History table's minus `date`, `time` and `char`: every row happened moments
ago, and capture only ever records the logged-in character's own movements, so all three columns
would carry the same value on every row.
