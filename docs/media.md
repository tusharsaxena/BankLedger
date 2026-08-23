# Media

Where the mono face and the shared marks come from, and the logo art set — what ships, why, and
how to regenerate it.

## Mono font outside the debug console

JetBrains Mono is a sanctioned styling exception. Its primary scope is the debug console and its copy
boxes, but the History table's Direction column and the Direction filter dropdown also draw a ▲/▼
(U+25B2 / U+25BC) in it, because WoW's default font carries neither glyph and renders a box for both.

**THIS ADDON NO LONGER SHIPS THE FILE.** It used to, under `media/fonts/`, with its own `OFL.txt` and
its own `LSM:Register("font", "JetBrains Mono", …)` call in `core/BankLedger.lua`. Both are gone. The
bytes arrive inside the LibKa0s payload (`libs/LibKa0s/media/fonts/JetBrainsMono-Regular.ttf`,
v1.10.1), `core/MediaSetup.lua` publishes the `NS.MediaFont` seam that resolves the path, and
`C.FONT_MONO` is that resolution rather than a literal — falling back to the client's own
`STANDARD_TEXT_FONT` when the library is absent, because `SetFont` given a path to a missing file
draws nothing at all. The library makes the LibSharedMedia registration, once, so two Ka0s addons
registering the name agree on one set of bytes instead of colliding.

This is **not a deviation**: `debug-logging-§2` sanctions the vendored mono font for an individual
glyph the default font lacks, naming ▲/▼ direction markers in a table cell as the example, and states
that an audit must not flag it.

**This is the one arrow pair that stayed a character, and the reason is colour, not alignment.** The
History column-header sort arrows and the group-header expanders are TEXTURES now — the collection's
`sort-up` / `sort-down` and `chevron-right` / `chevron-down` marks, listed in the table below. The
direction glyph does not follow them because it sits inline in the cell and takes the direction's red
or green from the same `SetTextColor` call that paints the label beside it; a texture carries no tint
in the short `|T…|t` form and would need one kept in step by hand. The face is already in the
payload, so this costs no new asset. Scope is two glyphs; no body text anywhere uses the mono font
outside the console. See [midnight-quirks.md](midnight-quirks.md).

## The shared marks

The collection's icon set ships in the LibKa0s payload, under `libs/LibKa0s/media/icons/` — 113
white 64×64 TGAs, catalogued by name in `lib.ICONS`. `core/MediaSetup.lua` publishes `NS.Icon(name)`
over it and `NS.ICON_NAMES` lists the eight this addon actually draws.

| Mark | Where it draws | Replaces | The rung below it |
|---|---|---|---|
| `close` | `B:MakeCloseButton` — the ledger, session, export-modal and export-copy title bars | the 24pt `×` (U+00D7) | the `×`, unchanged |
| `chevron-down` | `MakeDropdown`'s affordance — every dropdown on the filter bar (eight today: Group by, plus the seven filters) and the export modal's Data Set | `Interface\Buttons\Arrow-Down-Up` | that texture |
| `chevron-down` / `chevron-right` | the History group header's expander, inline `\|T…\|t` | `UI-MinusButton-Up` / `UI-PlusButton-Up` | those textures |
| `sort-up` / `sort-down` | the History column-header sort arrow, inline `\|T…\|t` | `Arrow-Up-Up` / `Arrow-Down-Up` | those textures |
| `export` | the filter bar's **Export** button, and the modal's **Export to CSV** | nothing — it sits BESIDE the label | no art, label unmoved |
| `search` | the item-name search box | nothing — it sits BESIDE the placeholder | no art, inset unmoved |
| `confirm` | the tick on a chosen row of a multi-select filter menu, inline `\|T…\|t` | `UI-CheckBox-Check` | that texture |

Four rules govern every one of them, and each cost the collection something to learn:

- **The path is extensionless.** `NS.Icon("close")` answers `…\media\icons\close`, never `.tga`. The
  client appends the extension; a path that carries one draws nothing and raises nothing.
- **`nil` is a real answer, twice** — no library, or no such name — and the rung below always stays.
  Every mark here replaced art that still works, so a player without LibKa0s sees exactly the window
  they saw before. Nothing builds a path by concatenation to route around a nil.
- **A wide button keeps its label and gains a mark BESIDE it.** The word says what the action does,
  the mark says where it lands. Export and Export to CSV are wide enough for both; the Save · Reset ·
  Clear cluster is 51px a button, which is a centred label and no room, so those three stay words.
- **No mark carries a tooltip.** A mark that needs one is a label that should have stayed a label.

**The five inline `|T…|t` marks — the four in `modules/LedgerTable.lua` plus the multi-select tick
in `modules/Browser.lua` — draw at full white, and that is the intended look.** `close` wears
0.85 gray, the dropdown chevron and the search magnifier 0.7, both export marks 0.85 — the shared art
ships white by contract and every mark on a *widget* is toned down to the surface it sits on. The
sort arrows, the group expanders and the multi-select tick cannot be: short-form inline texture
markup carries no vertex colour, and the extended form that does would have to restate the texel
box by hand at all five call sites to tint them. They are marginally brighter than the game-font label
beside them. **This is a recorded decision, not a regression** — S-21 step 4 says so too, so the next
reviewer does not file it.

**The debug console's three marks are not in that table, and they are not this addon's to draw.**
The console and its **Copy** box are LibKa0s-DebugLog-1.0's windows, so the library builds its own
close / clear / copy controls. It can only do that once it knows which folder to build a texture
path from, which is why `core/DebugLogSetup.lua` passes `addonName` beside `name` — two different
questions answered with the same string. Without it the library falls back to the *words* `Copy` and
`Clear` and to a font `×`, and nothing errors: the give-away is geometry, since clear goes from 18
wide to 42 and copy's derived offset slides from `-54` to `-78`. `tests/test_libka0s.lua` pins that
offset for exactly this reason, and S-14 is where a human looks at it.

The settings panel is deliberately unmarked: its rows, page headers and Defaults button are
LibKa0s-Options-1.0 widgets, and marking them is this addon reaching into another repo's surface.
`tests/test_marks.lua` asserts all of the above out of game, both rungs, because the one way a mark
fails is the one nothing else notices — a texture that does not load draws nothing and raises nothing.

## Logo art

`media/logos/` holds one master and three derivatives. Only the `.tga` is loaded by the addon; WoW
cannot read `.png` or `.jpg` at runtime.

| File | Size | Role |
|---|---|---|
| `bankledger.logo.png` | 1254×1254 | The master. Never shipped to the client; every other file is derived from it. |
| `bankledger.logo.tga` | 512×512, 24-bit RLE | **The runtime asset** — `C.LOGO_PATH`, drawn on the settings landing page at 300px. |
| `bankledger.logo.jpg` | 1024×1024 | The README image. |
| `bankledger.logo.256.jpg` | 256×256 | The CurseForge project avatar. |

Three rules the derivatives have to follow, each of which has already gone wrong once:

- **The `.tga` must actually exist.** `C.LOGO_PATH` points at `media/logos/bankledger.logo.tga`, and
  a missing file draws nothing rather than erroring — so the settings landing page just renders
  blank and nobody notices. That silence is why the art was absent for a while without anything
  failing. The runtime asset ships now, so this is a fallback path rather than a live problem.
- **Power-of-two dimensions.** The master is 1254×1254, which is not one; a non-power-of-two texture
  is rescaled by the client and softens. 512 is the smallest power of two comfortably above the
  300px display size, and matches the sibling addons.
- **Downscale with Lanczos, and sharpen the 256.** This is dense artwork — a ledger page of tiny
  text, coin stacks, filigree borders — so it loses more than a flat logo would at small sizes. The
  256 avatar takes a light unsharp mask (radius 0.8, 60%, threshold 2) afterwards to hold the detail
  together; without it the fine work turns to mush.

Regenerate the derivatives from the master with:

```python
from PIL import Image, ImageFilter
src = Image.open("media/logos/bankledger.logo.png").convert("RGB")
src.resize((512, 512), Image.LANCZOS).save(
    "media/logos/bankledger.logo.tga", compression="tga_rle")
src.resize((1024, 1024), Image.LANCZOS).save(
    "media/logos/bankledger.logo.jpg", quality=95, subsampling=0, optimize=True)
src.resize((256, 256), Image.LANCZOS) \
   .filter(ImageFilter.UnsharpMask(radius=0.8, percent=60, threshold=2)) \
   .save("media/logos/bankledger.logo.256.jpg", quality=95, subsampling=0, optimize=True)
```
