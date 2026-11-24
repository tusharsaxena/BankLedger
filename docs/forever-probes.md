# Forever probes — Ka0s Bank Ledger

The in-game facts the WoW Forever port leaves open (port design ruling R4 and the research synthesis's
probes P1-P12, in `Ka0sAddonsCommonTasks/docs/2026-11-22-LOOTHISTORY_BANKLEDGER_FOREVER_PORT/`),
de-duplicated into one sheet with the questions the port's later items added. Each probe says what to do,
what to read, and **what the code assumes today**, so a different answer is a finding and not a surprise.
Run them on the WoW Forever client unless a probe says Retail too, and record the answer on its
`Result:` line with the date and the client build. These are the owner's to run; an agent never fills
a result. A result that contradicts a default becomes a follow-up item (ruling R3); the build does not
wait for them.

## The probe verbs

Most probes need no typing beyond these four. The record goes into the addon's own SavedVariables,
`BankLedgerDB.global.probe`, never a new SavedVariables global (`modules/Probe.lua`,
[schema.md](schema.md#storage-carve-outs)).

| Verb | What it does |
|---|---|
| `/bl debug probe start` | Stamps the client and build, records the **start facts** and listens. Refused while the addon is disabled. A started probe keeps recording across logins and reloads until it is stopped, and records the start facts again at each login or reload |
| `/bl debug probe stop` | Stops listening and stamps the stop. The record stays |
| `/bl debug probe status` | One chat line: on or off, entries kept of the cap (200, the oldest dropped first, except the newest `start` entry, which is never dropped), entries dropped, client and build |
| `/bl debug probe clear` | Empties the entries; a running probe keeps running |

**The session.** `/bl debug probe start`; visit a banker (open the bank, wait five seconds, move one
item in and out, close it); visit a guild vault the same way; open the bank once more right after a
`/reload`; then `/bl debug probe stop` and log out. The lead reads
`_forever_/WTF/Account/<account>/SavedVariables/BankLedger.lua` (the `probe` table under `global`).
Run the same session on Retail for the probes that say "both clients".

**What one entry holds.** Every entry has `kind` and `at` (a `time()` stamp), oldest first:

| `kind` | When | Fields |
|---|---|---|
| `start` | `start` | `bareCoinTexture` (the bare `GetCoinTextureString`'s type; it is never called), `currencyCoinTexture` and `moneyString` (the two helpers on 123456 copper), `instance` (every `GetInstanceInfo` return), `mapID`, `regionalNames`, `characterKey`, `realmKey`, `defaultSkin`, `keyringSlots`, `keyring` |
| `bank` | a bank open, then +1 s and +3 s (`phase` 0, 1, 3) | `containers` (`id=slots` for every id -3..23 that reports slots), `shape` (the character bank group's ids, zeros included), `canView`, `purchasedTabs`, `maxTabs`, `deposited` (each per `Enum.BankType` member), `useBags`, `keyringSlots`, `keyring`, `socketSlots`, `sockets`, and the ledger's own `context`, `waiting`, `unready` and `sim` beside them |
| `guild` | a guild vault open, then +1 s and +3 s | `shown`, `tabs`, `money`, `current`, `tabInfo`, `filled` (slots of the current tab that read an item) |
| `interaction` | `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` | `type` (the number) and `name` (its `Enum.PlayerInteractionType` member) |
| `event` | `BANKFRAME_OPENED`, `GUILDBANKFRAME_OPENED`, `BAG_CONTAINER_UPDATE`, `BANK_TABS_CHANGED` | `event`, `args`, `sinceOpen` (seconds since the last bank open) |

A reader a build lacks records `absent`; one that raised records `ERROR <message>`. The probe reads
the client raw, never through the simulator's seam, and changes nothing the ledger records.

## The bank

**P1. The banker's interaction type, and whether the bank loads late.** From the probe: the
`interaction` entry's `name` at a banker, and the `bank` entries' `shape` at phase 0, 1 and 3, on the
first visit and on the visit right after a `/reload`. Read `Banker` (8), `CharacterBanker` or
`AccountBanker`, whether any tab id reads 0 at the open and slots later, and the `sinceOpen` of the
`BAG_CONTAINER_UPDATE` and `BANK_TABS_CHANGED` events. Fallback: `/run local f=CreateFrame("Frame")
f:RegisterEvent("BANKFRAME_OPENED") f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
f:SetScript("OnEvent",function(_,e,a) local function s() local n=0 for i=6,14 do
n=n+C_Container.GetContainerNumSlots(i) end return n end print(e,a,s()) C_Timer.After(1,function()
print("+1s",s()) end) end)`. **Assumes:** the per-container readiness guard (`modules/Ledger.lua`,
R8) waits for a tab that read slots before and reads 0 now, and accepts the shape after
`L.READY_TIMEOUT_SECONDS` (6 s); the cue events re-read it. Both clients. Result:

**P2. The bank model's answers.** From the probe: a `bank` entry's `canView`, `purchasedTabs`,
`maxTabs`, `deposited`, `useBags` and `containers`. Fallback: `/run
print(C_Bank.ShouldUsePlayerBagsInBank(), C_Bank.CanViewBank(0), C_Bank.CanViewBank(2),
C_Bank.FetchNumPurchasedBankTabs(0), C_Bank.FetchNumPurchasedBankTabs(2), C_Bank.FetchMaxNumBankTabs(0),
C_Bank.FetchDepositedMoney(2))` and `/run for i=-3,23 do local n=C_Container.GetContainerNumSlots(i)
if n>0 then print(i,n) end end`. **Assumes:** `CanViewBank(Character)` is true at a normal banker on
both clients (false would leave the character bank unread); `CanViewBank(Account)` is false on Forever,
so the Warband Bank's Retail-only declaration matches the client (R1); the character bank is ids 6..14
by member name. Also read the base tab's slot count (id 6): the simulator's Forever bank tab is 24
slots (`SW.BANK_TAB_SLOTS_BY_CLIENT`). On Retail, read whether the bank is 6+5 tabs (12.0.7) or 9+9.
Both clients. Result:

**P3. The keyring.** From the probe: the `start` and `bank` entries' `keyringSlots` and `keyring`;
then try to drag a key from the keyring into the bank and read the ledger. Fallback: `/run
print(C_ActionBar.ShouldShowKeyring(), HasKey and HasKey(), C_Container.GetContainerNumSlots(-1)) for
i=1,C_Container.GetContainerNumSlots(-1) do local x=C_Container.GetContainerItemInfo(-1,i) if x then
print(i,x.hyperlink,x.stackCount) end end`. **Assumes:** the keyring (-1) is in the bags group on
Forever only (R5, LibKa0s-Compat-1.0's `CONTAINER_PATTERNS_BY_CLIENT`), so a key moved into the bank, if the client allows it,
records a Character Bank deposit, and a key moved to the bags records nothing. Read whether the
keyring reads 0 slots right after login (the first snapshot would miss keys). On Retail, read what -1
answers at a banker: Retail never scans it. Both clients. Result: WoW Forever: the game lets a key go
into the bank (owner, 2026-11-24), so the move is the Character Bank deposit the build assumes (FOREVER-6).

**P10. The socketed bank bags (-2).** With a bag socketed into a bank tab, from the probe: a `bank`
entry's `socketSlots` and `sockets` (`<slot> loc=<ItemLocation read> info=<GetContainerItemInfo read>`).
Fallback: `/run for i=1,9 do local l=ItemLocation:CreateFromBagAndSlot(-2,i) if C_Item.DoesItemExist(l)
then print(i,C_Item.GetItemLink(l)) end end` and `/run for i=1,9 do local
x=C_Container.GetContainerItemInfo(-2,i) print(i,x and x.hyperlink) end`. **Assumes:** sockets are not
scanned (R6), so socketing a bag into the bank records nothing. Result:

## The guild vault

**P6. The guild vault exists and reads.** At a guild vault, from the probe: the `interaction` entry
(`GuildBanker`, 10), whether a `GUILDBANKFRAME_OPENED` `event` entry appears (on Retail 12.0.7 it
registers and never fires), and the `guild` entries' `shown`, `tabs`, `money`, `current`, `tabInfo`
and `filled` at phase 0, 1 and 3. Fallback: `/run print(GuildBankFrame and GuildBankFrame:IsShown(),
GetNumGuildBankTabs(), GetGuildBankMoney(), GetCurrentGuildBankTab())`. **Assumes:** the guild bank is
kept on both clients (D7) and arms on `GuildBankFrame`'s `OnShow`; a tab's items read once its query
lands. Both clients. Result:

## Money, names and the world

**P9. The money text.** From the probe: the `start` entry's `bareCoinTexture`, `currencyCoinTexture`
and `moneyString`. Fallback: `/run print(GetCoinTextureString, C_CurrencyInfo.GetCoinTextureString and
C_CurrencyInfo.GetCoinTextureString(123456), GetMoneyString and GetMoneyString(123456))`. **Assumes:**
`Util.FormatMoney` tries `C_CurrencyInfo.GetCoinTextureString`, then `GetMoneyString`, then
"Ng Ns Nc" text (R8), and never reads the bare global, which Forever lacks. Both clients. Result:

**P-NAME. The character key.** From the probe: the `start` entry's `regionalNames`, `characterKey` and
`realmKey`, and the `char` of the first row a bank visit records. **Assumes:** on Forever
`regionalNames` is true and `characterKey` answers "First Surname" (D6), not nil, by the time a
movement is recorded; `realmKey` answers the ruleset. Also note the longest "First Surname" you see:
the Character dropdown is 180 px and the Character column 144 px on Forever. Result:

**P-SKIN. The default skin.** From the probe: the `start` entry's `defaultSkin`. **Assumes:**
`forever` on WoW Forever, `ka0s` on Retail (`NS.DEFAULT_SKIN`, read once at file load). Both clients.
Result:

**P11. The instance and the map.** From the probe, once in a capital and once inside a dungeon: the
`start` entry's `instance` and `mapID` (start a probe in each place). **Assumes:** difficulty is stored
raw; the Forever test mode's capitals are uiMapIDs 1453-1458 (does Stormwind answer 1453, or 84?).
Result:

**P-WOWHEAD. The Forever item link.** Open a CSV export row's `wowhead` cell
(`https://www.wowhead.com/forever/item=<id>`, R7) for an item with bonus ids, if any Forever link
carries them. **Assumes:** Wowhead's forever path shows the item and ignores or honors `?bonus=`.
Result:

**P12. The port loads clean.** On the Forever install, `/bl diagnostics`, and `/bl debug scan` at a
banker. Read no Lua error, no `events UNAVAILABLE` beyond the expected, and the group lines. Result:
