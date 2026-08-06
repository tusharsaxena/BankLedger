# Windows

Two standalone windows, both plain non-secure frames sharing one `SKIN` / `ApplySkin` seam and one
close-glyph factory (`modules/Browser.lua`), each with its own persisted geometry carve-out.

The debug console and its copy box are a third and a fourth standalone frame, but they are the
**library's** — `LibKa0s-DebugLog-1.0` draws them. They wear the same edge, because that edge is no
longer this addon's alone: `Core.SKIN` carries the flat 1px black border, the 1px light-gray line
synthesized just inside it, the gold title and the gray divider, and the `SKIN` table above agrees
with it value for value. The descriptor still passes `applySkin`, so the console follows
`modules/Browser.lua` if that skin is ever retuned. What it does **not** pass is a close-button
factory: those two windows close with Core's thin 18×18 ×, not the 24×24 class-colored glyph the
ledger and session windows use. `standalone-windows` draws the line there — the edge is shared
across every Ka0s window, the close control on a library-drawn window belongs to the library — and
the point of it is that a user comparing two Ka0s consoles side by side sees one collection's
diagnostics surface, not five different ones.

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

`SaveGeometry()` refuses to write a point-less table — one would make `ApplyGeometry()` fall through
to the default and silently discard a real position — and `ApplyGeometry()` clamps a restored size to
the window's floor on the way *in* as well as out, so a size saved against an older column set (or a
hand-edited SavedVariables) cannot reopen a window too small to read.

| Window | Frame | Opened by | Contents |
|---|---|---|---|
| Ledger | `BankLedgerWindow` | `/bl show`, the minimap button | History table + Insights, over one shared filter bar |
| Current Banking Session | `BankLedgerSessionWindow` | a bank frame opening (`SessionChanged`), or `/bl session` | One slim table of this visit's movements |

The session window is **not** a second `NS.LedgerTable` instance. That module is a stateful singleton
— one row pool, one display list, one sort/group/filter/collapse state — and the session table has
none of those, so a slim renderer is smaller than the refactor generalizing it would take. What the
two **do** share is the definition of a column: `LedgerTable:Column(key)` hands out the spec (label,
width, align, tooltip, `valueFn`) and `LedgerTable:PaintCell(fs, key, entry, glyph)` sets a cell's
text and color, so a column cannot read one way in one window and another way in the other.

Its column set is the History table's minus `date`, `time` and `char`: every row happened moments
ago, and capture only ever records the logged-in character's own movements, so all three columns
would carry the same value on every row.
