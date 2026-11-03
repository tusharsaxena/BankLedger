# Candidates (BankLedger)

Sources: the `CHANGELOG.md` v1.85.0 block and `docs/releasing.md` at the tag. The plan decides
adoption, so there was no interview, and nothing is declined or filed.

## Class A: delivered on the copy

- The launcher tooltip (L1), settings tooltips (L2), the settings chrome (L3), section headings (L4),
  command rows and id status lines (L5) and scroll bar step buttons (L7). No host change.
- Debug console and copy window title bars at 30 high (L9, library half).
- Steps title band at 30 high, `gtip.title` on an owned tooltip title and `icon.tint` on an owned
  strip's icon: the look moves on this addon's Sim panel and both strips, with no host change.

## Class B: host change, by the plan

| Candidate | Touches | Decision |
|---|---|---|
| `S.TitleBar`'s `opts.place` (L9) | the three title bars | adopted in FS-BL-FIX |
| `opts.owner` on `MakeResizable` (L8) | the two grips | adopted in FS-BL-FIX |
| `icon.arrow` on sort arrows (L8) | `modules/LedgerTable.lua` | adopted in FS-BL-FIX |
| `S.Tab` and `S.Footer` (A1) | `modules/Browser.lua` | adopted in FS-BL-FIX |

No D-cause row names this addon, so `Skin.FollowOnce`, `S.HudFont` and `S.BarGloss` have no call here.
