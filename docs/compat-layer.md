# Compat layer

`core/Compat.lua` — the single file in the addon allowed to call a deprecated or patch-varying API.
Everything else calls `NS.Compat.X` and never the raw global.

`core/Compat.lua` is the single file allowed to call a deprecated or patch-varying API — 19 exports
in four groups. It shims **cross-patch** differences, never game flavors (Retail only; no
`WOW_PROJECT_ID` branching), and every reader returns **`nil` rather than a wrong answer**.

| Group | Exports |
|---|---|
| Metadata / player | `GetAddOnMetadata`, `GetPlayerMapID`, `GetZone`, `GetGuildName` |
| Money | `GetMoney` (the purse), `GetStoreMoney` (a store's **own** balance) |
| Containers | `GetContainerNumSlots`, `GetContainerSlot`, `GetGuildBankSlot`, `GetNumGuildBankTabs`, `QueryGuildBankTab`, `GetCurrentGuildBankTab`, `IsGuildBankVisible`, `GuildBankTabSize` |
| Items | `ItemIDFromLink`, `QualityLabel`, `GetItemDetails`, `ItemNameQuality`, `LoadItem` |

## Why every reader returns `nil` rather than a number

A reader that guesses is worse than one that declines, and the money readers are the case that proves
it. `GetGuildBankMoney()` returns **0**, not `nil`, when the guild bank frame is closed — a perfectly
plausible balance that would corroborate a purse change and write a fabricated gold row. So the guild
read is gated on `Compat.IsGuildBankVisible()`, and `GetStoreMoney(store)` answers `nil` whenever it
cannot answer honestly. A store whose balance cannot be read on both snapshots contributes no money
movement at all.

`IsGuildBankVisible()` is deliberately **three-valued**: `true`, `false`, and `nil` meaning *this
build cannot tell*. `disarmGuildBankIfGone` treats `nil` as "do not disarm", because disarming on an
unknown is how a live guild session ends itself halfway through.

## Cross-patch, never cross-flavor

The shims cover **patch-to-patch** differences. This is a Retail-only addon — a single
`## Interface:` line — and there is no `WOW_PROJECT_ID` branching anywhere. A capability is probed by
presence (`if C_Bank and C_Bank.FetchDepositedMoney then …`), never by asking which game this is.
