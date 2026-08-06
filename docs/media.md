# Media

The vendored mono font and the logo art set — what ships, why, and how to regenerate it.

## Mono font outside the debug console

`media/fonts/JetBrainsMono-Regular.ttf` ships as a sanctioned styling exception. Its primary scope is
the debug console and its copy boxes, but the History table's Direction column and the Direction
filter dropdown also draw a ▲/▼ (U+25B2 / U+25BC) in it, because WoW's default font carries neither
glyph and renders a box for both.

This is **not a deviation**: `debug-logging-§2` sanctions the vendored mono font for an individual
glyph the default font lacks, naming ▲/▼ direction markers in a table cell as the example, and states
that an audit must not flag it.

The reason the standard settled there is the reason this addon needs it: the alternative is a
texture, and Blizzard's arrow art carries uneven padding — the up arrow sits low in its canvas, the
down arrow high — so a texture pair visibly misaligns against the row text. A text glyph sits on the
label's own baseline, so it is centered by construction and takes the direction's color from the same
`SetTextColor` call as the label. The font is already shipped, so this costs no new asset. Scope is
two glyphs; no body text anywhere uses the mono font outside the console.

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
