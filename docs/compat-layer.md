# Compat layer

`core/Compat.lua` — the single file in the addon allowed to call a deprecated or patch-varying API.
Everything else calls `NS.Compat.X` and never the raw global.

`core/Compat.lua` is the single file allowed to call a deprecated or patch-varying API — 16 exports
in four groups. It shims **cross-patch** differences, and every reader returns **`nil` rather than a
wrong answer**. The addon ships on Retail and WoW Forever; which client this is, and who a character
is, are the eight members `core/CompatClient.lua` routes onto the same `NS.Compat` table (below), and
that file is the only one that reads a `WOW_PROJECT_*` constant (clients-§3).

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
| Player | `GetGuildName`, `PlayerName` (name and normalized realm on Retail; the whole "First Surname" and no realm on WoW Forever, joined by `Util.RecordKey` into the record key), `PlayerClass` (the classFile) |
| Money | `GetMoney` (the purse), `GetStoreMoney` (a store's **own** balance) |
| Containers | Routed from `LibKa0s-Compat-1.0` (minor 6, LibKa0s#101) with degraded stubs: `ContainerGroups` (the `bags` / `bank` / `accountBank` ids by `Enum.BagIndex` member name, read once by `core/Constants.lua`), `CONTAINER_PATTERNS_BY_CLIENT` (its pattern table), `CanViewCharacterBank` (`C_Bank.CanViewBank(Character)`; false at a warband-only banker, nil when the build cannot tell) and `UnreadyBankContainers` (the readiness judgment `L:CheckReady` asks). The addon's own: `GetContainerNumSlots`, `GetContainerSlot`, `GetGuildBankSlot`, `GetNumGuildBankTabs`, `QueryGuildBankTab`, `GetCurrentGuildBankTab`, `IsGuildBankVisible`, `GuildBankTabSize` |
| Items | `GetItemDetails`, `ItemNameQuality` — the **resolver** only; the primitives are `NS.Item.X` (see `core/ItemSetup.lua`) |

## The client and the character's name (`core/CompatClient.lua`)

`core/CompatClient.lua` loads straight after `core/Compat.lua` and routes eight members of the
vendored `LibKa0s-Compat-1.0`, each with a library-absent stub: `IsForever`, `IsRetail`,
`ClientKey` and `ForClient` (the client, clients-§3, §4), and `RegionalNames`, `UnitCharacterName`,
`CharacterKey` and `RealmKey` (the character's name, forever-quirks-§4). Every per-client table in
the addon is picked once at load by `ClientKey()`, and every declared feature (`C.FEATURE_CLIENTS`,
`core/Constants.lua`) by `ForClient`; the list is ARCHITECTURE.md's *Per-client features* table.
The eight are pure facts about the client, so the simulator's seam does not wrap them (`PURE` in
`core/SimSetup.lua`). Without the library, `CharacterKey` and `RealmKey` answer nil.

## The container groups and bank readiness (`core/Compat.lua`, LibKa0s#101)

The container groups and the bank-readiness reads are `LibKa0s-Compat-1.0` members (minor 6),
routed by `core/Compat.lua`. BankLedger, LootHistory and OutfitterReborn each carried a copy and the
copies drifted, so the library holds the one copy, and this addon's old one (the bag-pattern table,
`idsMatching` and the 0..5 fallback in `core/Constants.lua`, `CanViewCharacterBank`'s body here, and
`L.UnreadyContainers` in `modules/Ledger.lua`) is gone. The library's answers are the ones the addon
gave: ids by anchored, case-sensitive member name, the keyring (-1) in the bags on WoW Forever only
(R5), the account bank declared on Retail only (R1), the bags 0..5 when `Enum.BagIndex` names none,
and `CanViewCharacterBank` three-valued. What stays the addon's is the policy: `core/Constants.lua`
still gates the Warband Bank on `C.FEATURE`, and `modules/Ledger.lua` keeps the 6 s deadline
(`L.READY_TIMEOUT_SECONDS`) and the shape memory (`L:ShapeMemory`, `db.global.bankShape`), and asks
the judgment with no purchased-tab count, so a first visit takes its read as it finds it.

`ContainerGroups` and `UnreadyBankContainers` are pure (`PURE` in `core/SimSetup.lua`);
`CanViewCharacterBank` is wrapped, and the simulated world answers it. Without the library the stubs
degrade rather than copy: the groups are the library's no-enum answer (the bags 0..5, no bank),
`CanViewCharacterBank` answers nil and `UnreadyBankContainers` answers ready, so no bank container
is scanned and no bank row is written.

**The record key, per client.** On Retail (no regional names) `PlayerName` answers `UnitName`'s
name and the normalized realm, and `Util.RecordKey` joins them as `Name-Realm`, the key every stored
Retail row carries. On WoW Forever (`RegionalNames()` true) it answers the whole "First Surname"
(`CharacterKey()`, else `UnitCharacterName("player")`) and no realm, never
`GetNormalizedRealmName`, and `Util.RecordKey` keeps the name alone. No stored row moves: the WTF
folder is per client install.

`PlayerName` and `PlayerClass` are not cross-patch shims; they are here for the in-game simulator
(OWNER_SCOPE C.13, BankLedger#24). Its seam must answer identity — every row's `char` and
`classFile`, and its alt character — and it can only stand in for a read that goes through a
`Compat` member **read at call time**. That is why identity goes through `PlayerName` and never
through `CharacterKey` or `UnitCharacterName` directly: those are pure, so the simulator's alt is
answered only through `PlayerName`. A raw `UnitName("player")` in `Util.PlayerKey`, or a raw
`UnitClass("player")` in `Ledger:BuildEntry` and the session preview, would be unanswerable. Both are
plain `function Compat.X` members, never cached at load. No direct read is left: the Browser
close control's class-colored hover was one until BL-A1 made its hover the skin's `close.hot`. A
source scan in `tests/test_compat.lua` holds the boundary.

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
- **Wrapped:** the other twelve, `PlayerName` and `PlayerClass` included. With the guarded member
  that makes the thirteen of sixteen `docs/module-map.md` counts.

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

## Cross-patch here, the client in `CompatClient`

The shims in this file cover **patch-to-patch** differences. The addon ships on Retail and WoW
Forever (`## Interface: 120105, 16001`), and the client is asked through `NS.Compat.ClientKey()` and
`ForClient` alone, which `core/CompatClient.lua` routes; no other file reads `WOW_PROJECT_ID`
(`tests/test_compat_client.lua` scans for it). Inside a feature both clients have, a single API gap is
probed by presence (`if C_Bank and C_Bank.FetchDepositedMoney then …`); whether a whole feature exists
is a declaration, never a presence probe (clients-§3, §4). The WoW Forever client behaviors behind the
per-client tables are [forever-quirks.md](forever-quirks.md).
