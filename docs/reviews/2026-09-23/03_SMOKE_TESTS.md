# In-client smoke tests: Ka0s Bank Ledger, 2026-09-23

This covers what only the game client can verify, after the changes in `02_PROPOSED_CHANGES.md` land. The headless suites were measured in `01_FINDINGS.md`'s Step 0. Re-run them once as pre-flight:

```
~/.claude/wow-addon/bin/ka0s-bounded luacheck .            # expect 0 / 0
~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua  # expect 1022/1022 if C-01, C-02 and C-07 all land
```

## Pre-flight

1. Retail client on `## Interface: 120100` (12.1.x). Install the branch build into `Interface\AddOns\BankLedger`.
2. Use a character with access to a **character bank**, the **warband bank** and a **guild bank** where you have deposit and withdraw rights on at least one tab. Keep a few stacks of a cheap tradeskill item, for example Linen Cloth, plus some gold.
3. Run `/console scriptErrors 1`, then `/reload`. Keep BugSack or the default error frame visible.
4. Run `/bl debug on` and open the console with `/bl debug`. Every step below reads its `[Store]` / `[Diff]` / `[Move]` / `[Session]` lines.
5. Note the entry count from the minimap tooltip. Run `/bl version` and confirm it prints the branch version.

---

## C-01: The stand-down drops the capture context

**Setup:** addon enabled, at a character-bank NPC.

**Steps (case A: re-enable at the same visit):**

1. Open the bank. The console shows `[Store] BANK_FRAME opened (baseline …)` and the session window appears.
2. Type `/bl disable`. The chat shows `settings.enabled = false`. The session window closes.
3. Deposit **one** stack of Linen Cloth into the character bank.
4. Type `/bl enable`, with the bank still open.
5. Move any item in your bags, so that `BAG_UPDATE_DELAYED` fires.

**Expected:** there is **no** new History row for the Linen Cloth deposit, and the minimap tooltip count is unchanged from step 1. The console shows no `[Move]` line for that deposit. Capture stays unarmed until the next bank open. That is the documented conservative outcome.

**Steps (case B: re-enable away from the bank):**

1. Open the bank, then `/bl disable`, then close the bank. Walk away.
2. Type `/bl enable`.
3. Loot anything, or move items between bags. Enter combat with a training dummy and loot money if you can.

**Expected:** `/bl debug scan` reports `openContext=nil snapshot=no`. The console shows **no** `[Diff]` lines on bag updates away from the bank, including in combat.

**Pass/Fail:** pass if both cases produce zero rows for the disabled period, and case B shows `openContext=nil` with no `[Diff]` traffic away from the bank.

---

## C-02: `ResetEverything` re-runs the latch and announces the wiped ledger

**Setup:** at least 3 recorded rows, made with `/bl test` off, using real deposits. **Export first** if you want to keep them, because this step deletes history.

**Steps:**

1. Open the ledger window (`/bl show`) on the History tab, and open the Insights tab once so it is built. Leave the window open.
2. Type `/bl disable`. The ledger window closes. Reopen the settings with `/bl config`.
3. In **Master controls**, click **Reset all settings**. Read the confirm text, then click **Yes**.
4. Look at the Master controls **Enable Bank Ledger** checkbox. Type `/bl get settings.enabled`.
5. Type `/bl show`.
6. Open a bank and deposit one item.

**Expected:**

- Step 3: the popup text reads exactly *"Reset this addon to its defaults? Everything you have configured or recorded is discarded, for every character on this account — this cannot be undone."* The chat shows `[BL] this addon reset to defaults.`
- Step 4: the checkbox is **ticked** and `/bl get` prints `true`.
- Step 5: the window **opens**, with no disabled refusal line. History is **empty**, and the Insights tab shows the empty-state figures rather than the old totals.
- Step 6: a new row appears and the session window lists it.

**Pass/Fail:** pass if the addon is running after a reset made while it was disabled, and no window shows pre-reset rows.

---

## C-03: Retention disclosure

**Steps:** read the README on the repo or the CurseForge page, and open **Settings ▸ History**.

**Expected:** the README FAQ has a row saying that movements older than 30 days are removed by default, or "never" if the owner changed the default. That row names *Settings ▸ History ▸ Keep history for*. The dropdown default matches the README.

**Pass/Fail:** pass if the README and the dropdown agree.

---

## C-04: Allocation-free visibility pass

**Setup:** in **Settings ▸ Master controls**, set **Visibility** to *Only out of combat*.

**Steps:**

1. Open the ledger window. Enter combat with a training dummy.
2. Leave combat.
3. Repeat with *Only in combat*, and with *Always*.

**Expected:** out-of-combat mode hides the window on the pull and re-shows it after. In-combat mode does the inverse. *Always* changes nothing. There are no Lua errors. `/bl test` (sample ledger) is ended by the pull, with the chat line `test mode off — combat started.`

**Pass/Fail:** pass if the behavior is identical to the pre-change build. This is a pure refactor.

---

## C-05: Doc citations (desk check)

Open `docs/ARCHITECTURE.md` ▸ *Event Subscriptions* and *Documented deviations*. Follow every citation, and confirm each one names a symbol that exists in the cited file. **Pass** if every one resolves.

---

## C-06: One brand spelling

**Steps:** hover the minimap button. Open **Esc ▸ Options ▸ AddOns**.

**Expected:** the tooltip's first line reads `Ka0s Bank Ledger` in gold, and the category is listed as `Ka0s Bank Ledger`, **once**.

**Pass/Fail:** pass if both strings are unchanged from the pre-change build.

---

## C-07: The prune postpones, and does not cancel

**Setup:** set **Keep history for** to the shortest option. Have at least one row older than that window. Use a test character or a `/bl test`-free export backup.

**Steps:**

1. `/reload`, then type `/bl disable` **within 5 seconds**.
2. Wait 10 seconds. Type `/bl enable`.
3. Take any portal or hearthstone, so that a loading screen fires `PLAYER_ENTERING_WORLD`.

**Expected:** no `[Prune]` line appears during step 2, and nothing is deleted while disabled. After step 3, about 5 seconds past the loading screen, a `[Prune] retention …d: removed N entries` line appears.

**Pass/Fail:** pass if the prune runs after the re-enable plus loading screen, and never while disabled.

---

## C-08: Guild-bank open/close events (verification that decides the change)

**Steps:**

1. Run `/etrace`. Filter it to `GUILDBANK` and `PLAYER_INTERACTION`.
2. Open the guild vault, switch two tabs, and close it.

**Record:**

- Did `GUILDBANKFRAME_OPENED` or `_CLOSED` fire?
- Did `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` or `_HIDE` fire, and with which argument? Compare it with `/dump Enum.PlayerInteractionType.GuildBanker`.

**After the change:** depositing one item into the guild bank records one `GUILD_BANK` row, and closing the vault ends the session window. The console shows `[Store] GUILD_BANK closed`.

**Pass/Fail:** pass if a guild deposit and withdraw each record exactly one row, and the session closes with the vault.

---

## Regression suite

1. **Cold login.** Start with SavedVariables deleted (`WTF\Account\<acct>\SavedVariables\BankLedger.lua`), then log in. There are no errors. `/bl list` shows every default. The minimap button is visible.
2. **Load sequence.** `/reload` three times. There are no errors across ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD.
3. **Every store captures.**
   - Character bank deposit and withdraw: one row each, store `BANK`.
   - Warband tab deposit and withdraw: store `WARBAND_BANK`.
   - Warband gold deposit and withdraw: one `MONEY` row each.
   - Guild bank item: one row, store `GUILD_BANK`.
   - Buying a bank tab while the bank frame is open: **no** money row.
4. **Stand-down conformance.** `/bl disable`, then loot, zone and enter and leave combat. `/bl debug scan` lists 0 registered events. Left-click the minimap button: one line appears, `[BL] Ka0s Bank Ledger is disabled — enable it with /bl enable`, and nothing opens. Right-click opens settings. Every schema verb (`list`, `get`, `set`, `reset`) answers normally.
5. **Settings panel.** Toggle every control on every tab once. There are no errors, and every change is reflected immediately.
6. **Defaults button** (General page). It recenters both windows and clears the filter lists. History is untouched.
7. **Purge.** `/bl purge`, then **No**: nothing is deleted. Then `/bl purge`, then **Yes**: History is empty and Insights is empty.
8. **Export.** Export All Data and Current View from both tabs. The CSV opens in the copy window, and an item name containing a comma survives quoting.
9. **Cross-addon** (run with several Ka0s addons loaded). Type each of `/at /bl /cm /kcd /lh /mm /pm /pc /wg` plus `/am` if AuraMaster is loaded. Each one reaches its own addon. **Settings ▸ AddOns** lists each addon exactly once, and each multi-page addon's pages appear once each.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | | | |
| C-04 | | | |
| C-05 | | | |
| C-06 | | | |
| C-07 | | | |
| C-08 | | | |
| Regression 1–9 | | | |
