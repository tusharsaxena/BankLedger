# Windows

Two standalone windows, both plain non-secure frames sharing one skin seam (`B:ApplySkin`) and one
close-button factory (`modules/Browser_Chrome.lua`), each with its own persisted geometry carve-out.

**Both wear the player's skin** (skinning-§3; [ARCHITECTURE.md → Skins](ARCHITECTURE.md#skins)).
`B:ApplySkin` hands the frame to the owner's `Shell` (`NS.Skin.Shell`, LibKa0s-Skin-1.0) with
`noTopBar`, and each title bar paints its own fill and title through `NS.Skin.TitleBar`; the export
modal does the same. No window draws a line under its title band (R4-SEP, as the Skin Tester's
showroom): the ledger and session windows keep a 1px `dividerBar` frame under the bar, with nothing
drawn on it, because the ledger's tab strip anchors to it. Each then hands its header to
`NS.Skin.Header` (R5-WIN of the smoke round 5): the bar takes the band's rect (`S.Band`, Shell's own
inset and `title.height`, so no body color shows between the edge and the band in any skin), and the
title (by `title.align`) and the close are anchored to the band at y 0, its middle. Under Ka0s Default that is
the edge these windows always wore (the 1px black border, the 1px light-gray line just inside it and
the gold title) plus the skin's `title.bg` band on the title bars (a dark gold gradient) and
`list.header.bg` on the table headers (DECISIONS BankLedger D6). The ledger window also takes the
skin's `Tab` on its tabs, and its footer is `LibKa0s-Widgets-1.0`'s `Footer` (below), painted for
this owner. Every frame is recorded for this
addon's owner, so a skin switch repaints it live; the pooled rows and the tinted marks are redone by
`NS.Skin.OnLooksChanged` listeners. Without the library the degraded facade's `Shell`
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
18×18 control on a 30px library title bar, 24×24 on this addon's 30px one. `B:MakeCloseButton` hands
its button to the skin's `CloseButton` the way the library's own control does, with no opts
and no host hover scripts (BL-A1, the owner's ruling): in every skin, Ka0s Default included, the
primitive draws `close.rest` at rest and `close.hot` under the pointer, so the colors match too. See
[media.md](media.md).

**Master scale, master alpha and `Lock frame` are one seam, not per-window settings.** Every movable
frame this addon builds — the ledger window, the session window and the export modal — calls
`NS.Util.ApplyMasterFrame(frame)` at construction, after its own `SetMovable(true)`, and
`NS.Util.ApplyMasterChrome()` re-applies all three across the set whenever one changes. `Lock frame`
*is* `SetMovable(false)`, which the client makes `StartMoving` a no-op against, so there is no second
guard in any drag handler to keep in step. Master opacity is clamped up to `NS.Constants.MASTER_ALPHA_MIN`
on the way in — a stored `0` would be an invisible window with no way back to the panel that set it.
The ledger window's title bar carries a lock mark onto the same stored value (`lock` art while
locked, `unlock` while not; its click is `Sl:ToggleLock`), which `ApplyMasterFrame` repaints whenever
it re-applies the chrome; `/bl lock` and `/bl unlock` write it too (AF-HDR-BL, see
[ARCHITECTURE.md](ARCHITECTURE.md) ▸ *The title-bar marks*).
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
the edge. The ledger window also passes `gripParent = frame.footer`, so its grip is built on the
footer, in the footer's corner, which is the window's (LibKa0s#89). *Resize-stop* above is the grip's `onResizeStop`, which runs once per release and runs
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

**The ledger window's chrome stacks in the standard's order** (`standalone-windows`, *Window chrome
geometry*): the title bar (30), the mode strip while one shows (`TEST_STRIP.HEIGHT`, 18), the tab
strip, the filter bar, both panes, and the footer (`FOOTER.HEIGHT`, 24).

**One strip per mode on the ledger window, and the badge only where no strip was built**
(BankLedger#23, #24, LibKa0s#88). `LibKa0s-Widgets-1.0`'s `TestStrip` (LibKa0s#48; the `kind`
flavor since minor 14) is built twice by one local, `buildModeStrip(kind, text)`, and both are
**docked by the library directly under the title bar** (`dock = "title"`, `titleBar`, `window`,
Widgets minor 27; `preview-mode`, *Where the strip sits*), full width inside the window's edge; the
host never anchors them. `frame.testStrip` is the amber test flavor with the `info` mark and *TEST
MODE: a sample ledger, not your bank. Combat ends it.*, and `frame.simStrip` the cyan simulation
flavor. Their texts go through `NS.L`. While either shows, `anchorPanes()` moves everything below
the title bar (the tab strip, the filter bar and the History and Insights panes) down by that
strip's `strip:BodyOffset()`, its height, and by 0 otherwise or with no Widgets library; the strip's
`onOffset` and `B:UpdateTestStrip()` (from `B:Show` and `B:OnDatasetChanged`, so `/bl test`, the
Master controls box, the launcher menu and the combat ending all reach it) both run it.
`B:UpdateTestStrip()` shows the dataset's strip and hides the other. Until LibKa0s#88 the strips hung
2px under the filter bar with a host reserve of 22. Each strip's mouse is on for one plain `GameTooltip`, centered above the
strip (the chrome rule, AD-92-BL; ARCHITECTURE.md *Tooltip placement*): *Test mode*,
what it shows, and what ends it. The red `TEST MODE` title badge is the **degraded fallback only**:
it shows in test mode when no strip was built (no Widgets library, so no shift either), and never
beside a strip.

**A simulation is marked by the simulation strip, never the badge** (BankLedger#24, `preview-mode`,
`LibKa0s-Sim-1.0` host contract H8). While `Database:DatasetKind()` is `"sim"`, `B:UpdateTestStrip()`
sets `frame.simStrip`'s text to *Simulation: &lt;scenario&gt; - nothing here is saved.* (the running
scenario's label, `NS.SimHost.MarkerText()`) and shows it with the same body offset; the test strip
and the badge stay hidden. Its tooltip (`B.StripTipLines()`) says *Simulation*, what it
shows and what ends it (`/bl sim stop`, combat, a real bank window). The **session window** draws the
simulated rows too, so it gets its own `TestStrip` in the simulation flavor (`kind = "sim"`,
`f.simStrip`) with the same line while the dataset is `"sim"`,
docked by the library directly under its title bar (`dock = "title"`, LibKa0s#88; it was 5px in and
2px down), its pane moved down by the strip's `strip:BodyOffset()`, 18 (`SW:UpdateTestStrip()`, also
run on every `SW:Show`, and the strip's `onOffset`). Test mode never marks the session window: its session rows are real. Both
strips read the one predicate, and a session listener (`NS.Sim:AddListener` in `modules/Sim.lua`)
repaints both when a simulation starts and when it stops.

**The ledger window's footer is the library's** (LibKa0s#89; `standalone-windows`, *The footer*).
`EnsureFrame` builds it with `W.Footer(frame, { owner, grip = true })`: `FOOTER.HEIGHT` (24) tall
along the window's bottom edge, with no fill of its own, a hairline in the skin's `divider` along its
top, *Showing n of N* on its left line (`B:UpdateFooter`, `foot:SetLeft`) and *Database ~size* on its
right (`B:UpdateDbSize`, `foot:SetRight`), both in `text.muted`; `grip` insets the right line by
`FOOTER.GRIP` (22) to clear the resize grip in its corner. Both panes end `FOOTER.HEIGHT` above the
window's bottom edge, over the hairline. Without the Widgets library `B.BareFooter` builds a frame of
the same height with the same two lines and setters and no hairline. It replaced an 18px band on the
skin's `foot.bg` (`S.Footer`) with its two strings in `text.disabled`.

**The simulation step panel** (`BankLedgerSimPanel`) is `LibKa0s-Sim-1.0`'s, not this addon's: its
rows, states, run controls, scenario picker, click-ahead and placement are the library's.
`modules/Sim.lua` passes only the presentation fields (`NS.SimHost.PANEL`): the title
*Ka0s Bank Ledger - Simulation*, each step's label built from the real item (*Deposit 20 × Linen
Cloth to Warband Bank*, with *(N recorded)* once the engine has recorded rows for it), its tooltip
(what it moves, a lagged warband half, the client events it fires, and once played what it did and
how many rows it recorded), the Start and Stop tooltips, and the `confirm` tick. A start opens it
(from `prepare`, after the ledger window), as does a bare `/bl sim`; `/bl sim panel` toggles it. While
it is shown the Master controls *Sim mode* box reads ticked, and its `OnShow` and `OnHide` repaint an
open settings page (`NS.SimHost.WatchPanel()`, R7-SIM). It
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
