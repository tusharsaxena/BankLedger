# Compat layer

`core/Compat.lua` — the single file in the addon allowed to call a deprecated or patch-varying API.
Everything else calls `NS.Compat.X` and never the raw global.

`core/Compat.lua` is the single file allowed to call a deprecated or patch-varying API — 15 exports
in four groups. It shims **cross-patch** differences, never game flavors (Retail only; no
`WOW_PROJECT_ID` branching), and every reader returns **`nil` rather than a wrong answer**.

The TOC-metadata, map-id and zone reads are **not** here: they were identical in every addon in the
collection, so they live in `LibKa0s-Env-1.0` and are reached through `core/EnvSetup.lua` as
`NS.Meta`, `NS.Version`, `NS.PlayerMapID` and `NS.Zone`. The five item **primitives** are not here
either — `ItemIDFromLink`, `QualityFromLink`, `QualityLabel`, `LoadItem` and `BonusIDsFromLink`
live in `LibKa0s-Item-1.0` and are reached through `core/ItemSetup.lua` as `NS.Item.X`.

What stays in `Compat` is what is genuinely this addon’s — the container and guild-bank readers, and
the item **resolver**. `GetItemDetails` and `ItemNameQuality` did not move on purpose: they refuse an
item the client has not cached, the capture gate records the skip as `uncached` and asks the client
to cache the id, and “cannot be judged” is not “passes” (F-006). LootHistory’s resolver guesses from
the link, equally on purpose; a shared resolver would have had to overturn one of the two.

| Group | Exports |
|---|---|
| Player | `GetGuildName`, `PlayerName` (name and normalized realm), `PlayerClass` (the classFile) |
| Money | `GetMoney` (the purse), `GetStoreMoney` (a store's **own** balance) |
| Containers | `GetContainerNumSlots`, `GetContainerSlot`, `GetGuildBankSlot`, `GetNumGuildBankTabs`, `QueryGuildBankTab`, `GetCurrentGuildBankTab`, `IsGuildBankVisible`, `GuildBankTabSize` |
| Items | `GetItemDetails`, `ItemNameQuality` — the **resolver** only; the primitives are `NS.Item.X` (see `core/ItemSetup.lua`) |

`PlayerName` and `PlayerClass` are not cross-patch shims; they are here for the in-game simulator
(OWNER_SCOPE C.13, BankLedger#24). Its seam must answer identity — every row's `char` and
`classFile`, and its alt character — and it can only stand in for a read that goes through a
`Compat` member **read at call time**. A raw `UnitName("player")` in `Util.PlayerKey`, or a raw
`UnitClass("player")` in `Ledger:BuildEntry` and the session preview, would be unanswerable. Both are
plain `function Compat.X` members, never cached at load. The one direct read left is the Browser
close-button tint (`B:MakeCloseButton`): cosmetic, applied once at build and never stored. A source
scan in `tests/test_compat.lua` holds the boundary.

## The simulator's seam wraps every member

`core/SimSetup.lua` loads straight after this file and wraps `NS.Compat` in place with
`LibKa0s-Sim-1.0`'s `Sim:NewSeam` (BankLedger#24). Every function member is wrapped but three, so
while a simulation runs the simulator answers it and otherwise the live member does, at one field
test per call:

- **Pure, never wrapped:** `GuildBankTabSize` (a constant), and `GetItemDetails` and `ItemNameQuality`
  (real facts about real cached items: the simulator's item pool comes from the player's own bags,
  so the client's answer is the right one).
- **Guarded:** `QueryGuildBankTab`, the addon's one outward request. While a session runs its live
  body never runs, inside `Live` included; the guarded answer marks the tab queried in the simulated
  world and fires the asynchronous `GUILDBANKBAGSLOTS_CHANGED` reply on the session timer.
- **Wrapped:** the other eleven, `PlayerName` and `PlayerClass` included. With the guarded member
  that makes the twelve of fifteen `docs/module-map.md` counts.

A member added after the seam is built, or one replaced by assignment, would escape it, and so would
a member captured as `local x = NS.Compat.X`. `tests/test_sim_seam.lua` asserts the seam's
`Unwrapped()` list is empty after the whole addon loads and scans the source for captured reads.

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
