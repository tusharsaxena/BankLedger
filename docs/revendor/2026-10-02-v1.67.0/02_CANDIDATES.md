# Candidates (BankLedger)

These are listed, not interviewed. The owner authorized all nine issues of the census-adoption
bundle on 2026-10-02, and `Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_CENSUS_ADOPTION/` already
assigns each new surface to its own item there. The table shows which item takes each one.

| Surface | Class | Taken by | Notes |
|---|---|---|---|
| Options 28 / OptionsIdList 3: the descriptor's `addonName` (LibKa0s#42) | B, additive | **CA-BL-NM** | `settings/OptionsSetup.lua`'s descriptor gains `addonName = addonName`, the folder name from the file's first vararg. This change is latent here. Neither id list in `settings/Panel.lua` carries `help`, so no mark resolves art today. The field is the collection-wide descriptor contract (design D2, standard v2.75.0's options-ui-§1 row). |
| Core 10 `MakeResizable` with `onResizeStop` (LibKa0s#41) | B, additive | **CA-BL-01** (BankLedger#21) | The ledger window (`modules/Browser.lua:1018-1024`, `:1102-1112`) and the session window (`modules/SessionWindow.lua:482-488`, `:558-568`) replace their hand-built grips with `Core.MakeResizable`. The save and refresh move into `onResizeStop`. The library-absent arm of `core/CoreSetup.lua` keeps today's grip as the fallback (design D3.2). |
| Core 10 `canResize` | B | none | Design D3.1: *Lock frame* stops only the drag here, and a locked window still resizes. The behavior is kept for parity. Gating it is the owner's call, recorded by the census bundle's smoke BL-4. |
| Core 10 `gripParent` | B | none | Both windows draw their grip on the frame they size. Only MultiMeters needs another parent. |

Class A, delivered on the copy: nothing behavioral. Options 28 changes only a docblock.
OptionsIdList 3's guard sits behind a help mark that this addon does not draw.
