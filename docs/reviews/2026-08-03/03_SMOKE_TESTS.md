# Ka0s Bank Ledger — Smoke Tests (2026-08-03)

Run **after** the changes in `02_PROPOSED_CHANGES.md` are applied. Derived from that document; one
section per change ID. Fill in the sign-off table at the bottom.

## Pre-flight

1. **Headless gates first — both must be green before you log in.**
   - `cd <repo> && lua tests/run.lua` → expect `N passed, 0 failed` (baseline before this work:
     `689 passed, 0 failed`; C-004 and C-014 each add a case, so expect ≥ 691).
   - `cd <repo> && luacheck .` → expect `0 warnings / 0 errors in 24 files`.
2. **Install.** Copy/symlink the repo to `World of Warcraft/_retail_/Interface/AddOns/BankLedger`.
   Confirm `BankLedger.toc` still reads `## Interface: 120007` and `## SavedVariables: BankLedgerDB`.
3. **Client setup.** Retail only (the addon is single-Interface by design). Before logging in:
   - `/console scriptErrors 1` — a Lua error must be visible, not swallowed.
   - Keep `/etrace` handy for § C-006 (filter to `BANKFRAME_CLOSED`, `GUILDBANKFRAME_CLOSED`,
     `GUILDBANKBAGSLOTS_CHANGED`).
4. **Character requirements.** One character with (a) items in bags, (b) an accessible character
   bank **and** warband bank, and (c) guild-bank access with deposit/withdraw rights on at least one
   tab. A second character on the same account is useful for the character-filter checks.
5. **SavedVariables baseline.** Before the first run, copy your existing
   `WTF/Account/<ACCT>/SavedVariables/BankLedger.lua` aside so you can restore it; several tests
   below want a *populated* ledger and one wants a fresh one.
6. **Locale.** § C-004 requires a second pass on a non-enUS client — see **Localization sanity**.

---

## C-001 — Browser takes the shared printer upvalue

**Change covered:** C-001 — the ledger window's Save/Reset view messages carry the `[BL]` tag.

**Setup:** Any character. Ledger window closed. Chat frame visible.

**Steps:**
1. `/bl show`.
2. In the filter bar, set **Group by** to `Group: Store` and pick **Store → Character Bank**.
3. Click **Save**.
4. Click **Reset**.

**Expected:**
- Step 3 prints exactly: `[BL] view saved as your default.` — the `[BL]` rendered in **cyan**, in
  square brackets, at the start of the line.
- Step 4 prints exactly: `[BL] view reset to stock defaults.` with the same cyan tag.
- Both lines look identical in form to `/bl version` and to `/bl test`'s acknowledgment.

**Pass / Fail:** PASS only if **both** lines begin with the cyan `[BL]` tag. FAIL if either line
appears bare (that is the pre-change behavior).

---

## C-002 — The Storage panel refresher survives a re-render

**Change covered:** C-002 — the General page's storage line keeps live-updating after the settings
panel has re-rendered, and never writes into a released widget.

**Setup:** A ledger with at least 20 recorded movements (use `/bl test` if you have none — but note
the storage line reports the **stored** ledger, so test-mode rows will not change it; prefer a real
populated ledger). Settings panel closed.

**Steps:**
1. `/bl config`. Click **General**. Note the exact text of the storage line
   ("N movements recorded over M days. / Database size: ≈ …").
2. Click **Filters**. Add item id `2589` to the blacklist and press **Add**. (This fires
   `LedgerChanged` → `O.RefreshAllPanels()` — the re-render this test exists for.)
3. Click back to **General**. Confirm the storage line still shows the same figures.
4. Leave the settings window **open** on the **General** page. Alt-tab back to the game world, open
   your bank, and deposit one stack.
5. Return to the settings window without closing it.

**Expected:**
- Step 3: the storage line is present and correct — not blank, not showing another page's text.
- Step 5: the movement count has increased by one and the byte estimate has grown. It updates
  **without** closing and reopening the settings window.
- No Lua error at any point.

**Pass / Fail:** PASS if the line updates at step 5 after the step-2 re-render. FAIL if it is stale,
blank, or if any other label in the Settings window shows Bank Ledger's storage text.

---

## C-003 — `/bl debug panel` reports a real AceGUI minor

**Change covered:** C-003 — the LibStub registry key is `"AceGUI-3.0"` again.

**Setup:** Fresh login (so the panel has never been built).

**Steps:**
1. `/bl config` — this builds the panel and its Defaults button.
2. `/bl debug panel`.
3. Read the console's first `[Panel]` line.

**Expected:** `AceGUI=yes minor=<number>` — a numeric minor (e.g. `minor=41`), **not** `minor=nil`.
The following lines (`Button widget registered=yes version=…`, `defaultsBtn type=table …`, the
parent chain, the region dump) all render as before.

**Pass / Fail:** PASS if `minor=` is followed by a number. FAIL on `minor=nil`.

---

## C-004 — UTF-8-safe truncation

**Change covered:** C-004 — Insights labels no longer cut mid-codepoint.

**Setup:** enUS client first (regression), then repeat on deDE or frFR (see **Localization sanity**).

**Steps (enUS — regression only):**
1. `/bl test` to load the sample ledger, then `/bl show` and click the **Insights** tab.
2. Scroll to **Movements By Item Type** and **Movements By Sub-type**.
3. Hover the longest bar label.

**Expected:** Labels look exactly as they did before the change — long ones end in a single `…`
ellipsis, short ones are untouched, and the hover tooltip shows the full untruncated name.

**Pass / Fail:** PASS if the enUS rendering is byte-identical to the pre-change build. The real test
for this change is the deDE/frFR pass below.

---

## C-005 — Guild bank still arms via the Context enum

**Change covered:** C-005 — `C.Context.GUILD_BANK` replaces `C.Store.GUILD_BANK` at the two
arming sites. Behavior must be **unchanged**.

**Setup:** Character with guild-bank access. `/bl debug on` so the console records the arming.
`/bl debug` to show the console.

**Steps:**
1. Walk to a guild bank and open it.
2. Watch the console.
3. Deposit one item into a guild tab. Wait ~2 seconds.
4. Close the guild bank window.

**Expected:**
- Step 2: a `[Store]` line reading `queried N guild bank tabs`, then
  `GUILD_BANK opened (baseline: bags N kinds; stores GUILD_BANK N)`, and
  `GUILD_BANK close hook installed`.
- Step 3: a `[Diff]` line for `GUILD_BANK` with `-> 1 moves`, then a `[Move]` line
  `GUILD_BANK: recorded 1, skipped 0`.
- Step 4: a `[Store]` line `GUILD_BANK closed`.
- `/bl show` → History lists the new row with Store = **Guild Bank**.

**Pass / Fail:** PASS if all four log lines appear and the row is recorded. FAIL if the guild bank
never arms (no `opened` line) — that is the regression this change could theoretically cause.

---

## C-006 — A close event only closes its own context

**Change covered:** C-006 — `BANKFRAME_CLOSED` no longer tears down a live guild-bank context.

**Setup:** `/bl debug on`, console shown. `/etrace` open, filtered to `BANKFRAME_CLOSED`,
`GUILDBANKFRAME_CLOSED`, `GUILDBANKBAGSLOTS_CHANGED`.

**Steps — part 1 (the ordinary path must still work):**
1. Open your character bank. Confirm the console logs `BANK_FRAME opened (baseline: …)` and the
   **Current Banking Session** window appears.
2. Deposit one stack; confirm it appears in the session window.
3. Close the bank.

**Expected part 1:** console logs `BANK_FRAME closed`; the session window hides; the row is in
`/bl show`.

**Steps — part 2 (the guarded path):**
4. Walk to a guild bank and open it. Confirm `GUILD_BANK opened` in the console and the session
   window appears.
5. **Without closing the guild bank**, watch `/etrace` — if a `BANKFRAME_CLOSED` fires at any point
   (some banker NPCs / UI transitions emit one), confirm the console does **not** log
   `GUILD_BANK closed` and the session window stays visible.
6. Deposit one item into the guild bank; confirm it still records.
7. Close the guild bank.

**Expected part 2:** `GUILD_BANK closed` appears only at step 7. The step-6 deposit records.

**Pass / Fail:** PASS if part 1 is unchanged **and** part 2 never shows a premature
`GUILD_BANK closed`. FAIL if the ordinary bank close stops ending the session (part 1 regression) —
that is the main risk of this change.

---

## C-007 / C-010 / C-011 — Comment and whitespace corrections

**Change covered:** C-007, C-010, C-011 — comment-only.

**Setup:** Repo checkout.

**Steps:**
1. `grep -rn "test_toc.lua\|data-model.md" core modules settings` → expect **no matches**.
2. `grep -n "O.AceGUI-3.0" settings/Panel.lua` → expect **no matches** (covers C-003 too).
3. `lua tests/run.lua` and `luacheck .`.

**Expected:** No matches for steps 1-2; both gates green.

**Pass / Fail:** PASS on no matches + both gates green.

---

## C-008 — The degraded options stub

**Change covered:** C-008 — `BUTTON_PAIR_REL = 0` in the stub.

**Setup:** This exercises the **library-missing** path, so do it deliberately.

**Steps:**
1. Rename `Interface/AddOns/BankLedger/libs/LibKa0s` to `libs/LibKa0s_off`.
2. Log in (or `/reload`).
3. `/bl version`, then `/bl config`, then `/bl show`.
4. Restore the folder name and `/reload`.

**Expected:**
- Step 3: exactly one line explaining the library is missing, once, with the shared cause clause
  ("The LibKa0s library is missing from this installation of Ka0s Bank Ledger (expected in
  libs/LibKa0s)…"), and `/bl config` says the settings panel is unavailable rather than erroring.
- `/bl show` still opens the ledger window — capture and the main window do not depend on LibKa0s.
- **No Lua error** at any point.
- Step 4: everything back to normal.

**Pass / Fail:** PASS if the degraded run produces honest chat lines and zero Lua errors.

---

## C-009 — Dead-code sweep

**Change covered:** C-009 — `Compat.QualityFromLink` and its cache deleted; five seams annotated.

**Steps:**
1. `grep -rn "QualityFromLink\|qualityByHex\|buildQualityByHex" . --exclude-dir=libs
   --exclude-dir=.git` → expect **no matches** outside `docs/`.
2. `lua tests/run.lua` → green.
3. In game: `/bl show`, confirm the **Quality** column still shows Poor/Common/…/Legendary correctly
   (that path goes through `Compat.QualityLabel`, which is **not** being removed).

**Pass / Fail:** PASS on no matches, green suite, and a correct Quality column.

---

## C-012 — Export guard

**Change covered:** C-012 — the Browser reach in `Export.lua` is presence-guarded.

**Steps:**
1. `/bl show` → **History** tab → **Export** → set **Data set: Current View** → **Export to CSV**.
2. Confirm the copy window opens with CSV text and `Ctrl+C` copies it.
3. Switch to the **Insights** tab → **Export** → **Export to CSV**.

**Expected:** Both export modals open, the Data Set dropdown works on both, and the copy window
shows a header row + data. The Insights export's first line is `Section,Label,Count,Value`; the
History export's first line is the ledger column header ending in `wowhead`.

**Pass / Fail:** PASS if both exports open and produce text.

---

## C-013 — Preview flag cleared on session end

**Change covered:** C-013 — `SW.previewSession` resets in `EndSession`.

**Steps:**
1. Away from any bank: `/bl session`. Expect `[BL] session window sample on` and a window with six
   placeholder rows.
2. `/bl session` again. Expect `[BL] session window sample off` and the window hides.
3. `/bl session` (sample on), then **walk to a bank and open it** without turning the sample off.
4. Confirm the window now shows a **real, empty** session ("Nothing has moved yet this session.").
5. Deposit one item; confirm it appears.
6. Close the bank. Confirm the window hides.
7. `/bl session` once more.

**Expected:** Step 7 turns the sample **on** (`session window sample on`) — not off. Before the
change the flag could disagree with what is on screen.

**Pass / Fail:** PASS if step 7 says `on` and the placeholder rows appear.

---

## C-014 — `PruneOld` is quiet when it prunes nothing

**Change covered:** C-014 — no `LedgerChanged` broadcast on a zero-row prune.

**Setup:** `/bl debug on`, console shown. Set **Settings ▸ General ▸ Keep history for** to
`365 days` so nothing is old enough to prune. Have at least one ledger row.

**Steps:**
1. `/reload`. Wait ~10 seconds (retention runs 5 s after `PLAYER_ENTERING_WORLD`).
2. Read the console.
3. Open `/bl config` → **General** and note the storage line, then change **Keep history for** to
   `180 days` (still pruning nothing).

**Expected:**
- Step 2: a `[Prune]` line `retention 365d: removed 0 entries` — the log line stays (it is
  diagnostics, not a broadcast).
- The ledger window, if open, does **not** visibly repaint at step 1, and the storage line does not
  flicker at step 3.
- Now set retention to `7 days` on a ledger with older rows: a `[Prune]` line with a non-zero
  `removed`, **and** the History table and storage line both update immediately.

**Pass / Fail:** PASS if a zero-row prune logs but does not repaint, and a non-zero prune does both.

---

## Regression suite

Not tied to any one change; these cover what the change-set could plausibly break.

| # | Check | Expected |
| --- | --- | --- |
| R-1 | `/reload` with every window closed | No Lua error; `/bl show` still opens |
| R-2 | `/reload` with the ledger window, session window and settings panel all **open** | No error; the ledger window reopens at the same position and size (geometry is saved on `PLAYER_LOGOUT`) |
| R-3 | First-time defaults: move `BankLedger.lua` out of `SavedVariables`, log in | No error; `/bl list` shows every setting at its default; `db.global.schemaVersion == 2` on next logout |
| R-4 | `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` | No error at any stage with `scriptErrors 1` |
| R-5 | Enter and leave combat with the ledger window, session window and debug console all visible | All three stay visible and interactive; no taint message |
| R-6 | `/bl config` **while in combat** | Refuses with a chat line; does **not** queue and pop open when combat ends |
| R-7 | Esc → Options → AddOns → Ka0s Bank Ledger → General, then Filters, then back | Both bodies render; the always-shown scrollbar is present on both; the header Defaults button is **not** the red stone button |
| R-8 | Toggle every option on the General page once, then `/bl list` | Each printed value matches what the widget shows |
| R-9 | Blizzard's own footer **Defaults** control on the General subcategory | Resets settings, prints one acknowledgment line, does **not** delete history |
| R-10 | `/bl resetall` → confirm | One acknowledgment line; settings + filter lists + saved view reset; history **is** deleted (this one is the destructive path) |
| R-11 | `/bl test` on, then off | Window shows the TEST MODE badge, filters repopulate from the sample data, and the badge clears on the way back |
| R-12 | `/bl purge` → confirm on a populated ledger | One `[BL] ledger purged.` line; History empty; Insights shows the empty-state text; storage line reads "No movements recorded yet." |
| R-13 | Right-click a History row in **test mode** | Blacklist / Whitelist / Delete are grayed out; "Link to chat" still works |
| R-14 | Right-click a History row on **live** data → Blacklist | One `[BL] blacklisted <name>. Manage in Settings ▸ Filters.` line; the id appears on the Filters page |
| R-15 | Minimap button: left-click, right-click, then Settings ▸ "Hide minimap button" | Left toggles the window, right opens Settings, the checkbox hides/shows the icon and survives `/reload` |

## Localization sanity (required — C-004 touched a text path)

Switch the client to **deDE** (or frFR) and repeat:

1. Log in on a character with a populated ledger (item types/sub-types will now be German).
2. `/bl show` → **Insights** tab.
3. Inspect **Movements By Item Type**, **Movements By Sub-type**, **Movements By Character** and the
   legend chips under the type/sub-type charts.

**Expected:** Every truncated label ends in a clean `…` with no replacement glyph, no black diamond
and no stray box before the ellipsis. Hovering any bar shows the **full** untruncated German name.
Character bar labels with umlauts truncate cleanly.

**Pass / Fail:** PASS if no broken glyph appears anywhere in the Insights panel. FAIL on any
mid-character cut — that is the exact defect C-004 fixes.

## Performance spot-checks (C-002 and C-014 are perf-adjacent)

1. **Memory around a panel re-render (C-002).** With the settings panel open on **General**:
   `/run collectgarbage("collect"); print(collectgarbage("count"))` → note the KB. Click
   Filters → General → Filters → General ten times. Re-run the command. Expect the second reading
   within a few hundred KB of the first — a steadily climbing number would suggest the released
   widgets are being retained.
2. **Repaints on a quiet prune (C-014).** `/console scriptProfile 1` → `/reload` → wait 15 s →
   `/run UpdateAddOnCPUUsage(); print(GetAddOnCPUUsage("BankLedger"))`. Compare the pre-change and
   post-change builds on the same character with the same ledger and retention set to `365 days`.
   Expect the post-change figure to be equal or lower. Turn profiling back off (`scriptProfile 0`)
   afterwards.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
| --- | --- | --- | --- |
| C-001 | | | |
| C-002 | | | |
| C-003 | | | |
| C-004 | | | |
| C-005 | | | |
| C-006 | | | |
| C-007 | | | |
| C-008 | | | |
| C-009 | | | |
| C-010 | | | |
| C-011 | | | |
| C-012 | | | |
| C-013 | | | |
| C-014 | | | |
| Regression R-1…R-15 | | | |
| Localization (deDE/frFR) | | | |
| Perf spot-checks | | | |
</content>
