# Manual smoke tests — in-client, 2026-08-05

Run **after** the changes in `02_PROPOSED_CHANGES.md` have been applied. Everything that runs headless
in a shell was already run in Step 0 and is recorded in `01_FINDINGS.md`; this document is only for
what needs a logged-in client.

## Pre-flight

1. **Headless gate first** (one line, not a per-change step). From the repo root:
   `luacheck . && lua tests/run.lua` — both must be clean before you log in. If C-003 landed, the pass
   count is expected to be **lower** than 726; confirm `docs/test-cases.md` and the `[Tests]` badge in
   `README.md` were regenerated in the same commit.
2. **Install.** Copy the working tree to `World of Warcraft/_retail_/Interface/AddOns/BankLedger/`.
   `## Interface: 120007` — a Midnight 12.0.7 retail client. No Classic flavor is supported.
3. **Character requirements.** A character with (a) access to a bank in a capital, (b) membership in a
   guild with at least one purchased guild-bank tab, and (c) at least one warband bank tab purchased.
   Two characters on the same account help for the cross-character checks.
4. **Make failures visible.** `/console scriptErrors 1`, then `/reload`. Keep `/etrace` handy for the
   bank open/close event checks.
5. **Baseline the data.** Before starting, note the current entry count from the settings panel's
   Storage section, and back up
   `WTF/Account/<ACCOUNT>/SavedVariables/BankLedger.lua` — several checks below delete rows.

---

## C-001 — `/bl debug panel` reports the real AceGUI minor

**Change covered:** C-001 — correct the LibStub major in `reportAceGUI`.

**Setup:** fresh login. Do **not** open the settings panel yet.

**Steps:**
1. `/bl debug panel`
2. Read the console's first line.
3. Close the console. `/bl config`, let the General page draw, close the Settings window.
4. `/bl debug panel` again; read the first two lines.

**Expected:**
- Step 2 first line reads `AceGUI=yes minor=<integer>` — a real integer, **not** `nil`. (Before the fix
  it read `minor=nil` always.)
- Step 4 additionally reports `Button widget registered=yes version=<integer>`, and — because a panel
  now exists — the dump continues past `defaultsBtn` into the frame, parent chain and art.
- No Lua error popup at any step.

**Pass / Fail:** PASS iff the `minor=` value is a non-`nil` integer in both step 2 and step 4.

**Bonus check (optional, worth doing once):** load another AceGUI-3.0 consumer alongside (any Ace3
addon) and confirm the reported minor is the *serving* copy's, which may differ from the vendored one —
that is the question the line exists to answer.

---

## C-002 — the vendor-sync gate says when it did not look

**Change covered:** C-002 — make the skip legible.

**This one is not in-client** and is listed here only so it is not forgotten: it is verified by running
`lua tests/run.lua` twice — once with `../LibKa0s` present and once with it renamed away — and reading
the case names and the printed reason. Do that at the pre-flight step, before installing.

**Expected:** with the sibling absent, both vendor-sync cases still print `PASS` (until U-001 lands
upstream), but the case **names** now carry `(skipped when ../LibKa0s is absent)` and one line names
the path that was looked for. With the sibling present, the cases compare bytes as before.

**Pass / Fail:** PASS iff a reader of the runner output can tell the two runs apart without reading
the test source.

---

## C-003 — nothing user-visible was removed with the dead code

**Change covered:** C-003 — delete the six dead exported members.

**Setup:** a ledger with at least 20 recorded movements across at least two stores, and at least one
item id on the blacklist and one on the whitelist. `/bl test` off.

**Steps:**
1. `/bl show`. Confirm the table paints and every column has content.
2. Right-click any row with an item. Confirm the menu shows **Link to chat**, **Blacklist item**,
   **Whitelist item**, **Delete**.
3. Click **Delete**. Confirm that row — and only that row — disappears.
4. Right-click a different row → **Blacklist item**. Confirm the chat line
   `[BL] blacklisted <name>. Manage in Settings ▸ Filters.`
5. `/bl config` → **Filters**. Confirm the id from step 4 is listed with its item name, and remove it.
6. Switch to the **Insights** tab. Confirm every ranked panel and every chart renders with data (this
   is what exercised the deleted `I.RankRows` / `I.BarFraction` neighbors).
7. `/bl test` on. Confirm the sample dataset paints, the test badge appears, and the row menu's
   **Blacklist/Whitelist/Delete** entries are **grayed out**. `/bl test` off again.
8. Export: filter bar → **Export** → **All Data** → CSV. Confirm the quality column shows labels
   (`Rare`, `Epic`, …) — this is `Compat.QualityLabel`, which stays; `QualityFromLink`, which went, was
   never on this path.

**Expected:** every step behaves exactly as before the change. No Lua error popup at any point.

**Pass / Fail:** PASS iff steps 1–8 all behave as described **and** `/console scriptErrors 1` produced
no error window during the whole sequence.

---

## C-004 — login and prune no longer repaint for nothing

**Change covered:** C-004a (`SW:PruneMissing` early return) and C-004b (`PruneOld` fires only when it
removed something).

### C-004-1 — the login no-op path

**Setup:** retention set to a window that matches **everything** you have recorded (e.g. `/bl set
settings.retentionDays 365` with only recent data), so the login prune will remove **zero** rows.
Enable logging so the decision is visible: `/bl debug on`, then `/bl debug` to show the console.

**Steps:**
1. `/reload`.
2. Wait 10 seconds (the prune is scheduled 5 s after `PLAYER_ENTERING_WORLD`).
3. Read the console.

**Expected:** a `[Prune]` line reading `retention 365d: removed 0 entries`, and **no** repaint cascade
behind it — the ledger window (if open) does not flicker, and the Insights tab does not re-aggregate.

**Pass / Fail:** PASS iff the prune line reports 0 removed and no consumer visibly repaints.

### C-004-2 — the prune that does remove something still notifies everyone

**Setup:** with logging still on, and the ledger window open on the History tab, set retention to a
window that **does** cut rows: `/bl set settings.retentionDays 7` on a ledger holding entries older
than 7 days.

**Steps:**
1. Watch the ledger window as you issue the `set`.
2. Read the console and the window footer's count.
3. Switch to **Insights** and confirm the totals moved.
4. Open `/bl config` → General → Storage and confirm the movement count and estimated size dropped.

**Expected:** the table repaints immediately, the `[Prune]` line reports a non-zero removal, and the
footer, Insights and the Storage section all agree on the new count.

**Pass / Fail:** PASS iff a *real* prune still reaches all four surfaces. This is the regression risk
C-004b carries — if any surface goes stale here, C-004b is wrong.

### C-004-3 — the session window still drops deleted rows

**Setup:** stand at a bank. Deposit three distinct items so the session window lists three rows. Leave
the bank frame **open**.

**Steps:**
1. In another window, `/bl show` and right-click one of those three rows → **Delete**.
2. Look at the session window.

**Expected:** the deleted movement disappears from the session window too (this is `SW:PruneMissing`
doing its actual job — the early return must not have broken it, because `#entries > 0` here).

**Pass / Fail:** PASS iff the session window drops exactly the deleted row and keeps the other two.

### C-004-4 — memory spot-check (perf evidence)

There is **no offline perf harness in this repo** (`tests/perf.lua` is absent, `docs/perf-runs/` does
not exist), so no bucket figure can be cited for this change and none is claimed. The available
in-client evidence is a garbage-collection delta, which is coarse — record it as such.

**Steps:**
1. Build up a sizeable ledger (`/bl test` will not do — it is synthetic and not on this path; use real
   data, or a `.lua` SavedVariables file with several thousand entries).
2. `/run collectgarbage("collect"); print(collectgarbage("count"))` — note the number.
3. `/reload`, wait 10 s past login, then repeat the measurement.
4. Compare against the same sequence taken on the pre-change build.

**Expected:** the post-login allocation is no higher, and on a large ledger measurably lower.

**Pass / Fail:** informational only — record the two numbers in the sign-off table. Do **not** treat a
small delta as proof either way; the honest statement is that this change removes work that provably
had no effect, not that a specific number moved.

---

## C-005 — comment, naming and string corrections

**Change covered:** C-005a–f. Only C-005b and C-005e are observable in-client.

### C-005b — the guild bank still arms and disarms

**Setup:** a guild with at least one purchased tab holding items. Logging on.

**Steps:**
1. Open the guild bank. Watch the console.
2. Deposit one stack of something.
3. Withdraw a different stack.
4. Close the guild bank window with **Esc**.
5. Re-open it, then close it by clicking the banker away / walking off.
6. `/bl show` and confirm both movements are in the table with store **Guild Bank** and your guild name.

**Expected:**
- Step 1: `[Store] GUILD_BANK opened (baseline: …)` and `[Store] queried N guild bank tabs`, plus
  `[Store] GUILD_BANK close hook installed`.
- Steps 2–3: a `[Diff]` line and a `[Move]` line per action; the session window lists both.
- Steps 4 and 5: `[Store] GUILD_BANK closed` (via the OnHide hook) — **not** `disarmed (window gone)`,
  which is the backstop and should not be the path taken.
- Step 6: both rows present, correctly directed, guild stamped.

**Pass / Fail:** PASS iff arming, both movements, and the close all behave exactly as before C-005b.
This is the one rename that touches executable code, and this test is why it is here.

### C-005e — the Defaults tooltip now tells the truth

**Setup:** move and resize **both** the ledger window (`/bl show`) and the session window (`/bl session`
to get a preview one on screen) to distinctive, off-center positions. `/reload` and confirm both
reopen where you left them.

**Steps:**
1. `/bl config` → **General**. Hover the **Defaults** button in the header.
2. Read the tooltip.
3. Click **Defaults**.
4. `/bl show` and `/bl session`.

**Expected:**
- Step 2 tooltip ends with a sentence saying both windows return to their default position and size.
- Step 3 prints one — and only one — `[BL] All settings reset to defaults` line.
- Step 4: both windows are back at their default positions and sizes, and every setting on the General
  page reads its default value.

**Pass / Fail:** PASS iff the tooltip warns about the window reset **and** the reset actually does it
(the string must describe the behavior, not the other way round).

---

## Regression suite

Not tied to a specific change; these cover what the changes could plausibly break.

| # | Check | Expected |
|---|---|---|
| R-1 | `/reload` with the ledger window open | Window reopens at the same position and size; no error popup |
| R-2 | Fresh install: delete `BankLedger.lua` from SavedVariables, log in | Defaults populate; `/bl list` shows every row at its default; `schemaVersion` is 2 |
| R-3 | Login sequence `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` | No Lua errors; `/bl debug scan` shows every capture event in the **registered** list and `none` unavailable |
| R-4 | Enter and leave combat with the ledger window, session window and console all on screen | Nothing hides, nothing errors, no `Interface action failed because of an AddOn` |
| R-5 | Open Settings from **Esc → Options → AddOns → Ka0s Bank Ledger** (not `/bl config`) | Landing page draws with logo, tagline and the slash-command list; both subcategories render |
| R-6 | `/bl config` **while in combat** | Refuses with a message; the panel does **not** pop open when combat ends |
| R-7 | Toggle every option on the General page once, then `/bl list` | Each toggle takes effect immediately and `/bl list` agrees with the widgets |
| R-8 | `/bl set settings.windowScale 1.4` with the ledger window open | Window rescales immediately; the slider in an open panel moves to match |
| R-9 | Character bank: deposit 2 stacks, withdraw 1 | Exactly 3 rows, correctly directed; the session window matches |
| R-10 | Warband bank: deposit an item and 100g | Item row **and** gold row recorded, both attributed to Warband Bank |
| R-11 | Loot an item into your bags while a bank frame is open, then close the bank | **No** ledger row for the loot (the one-sided change must re-anchor, not pair) |
| R-12 | `/bl resetall` | One confirmation line only; settings back to defaults; **ledger untouched**; filter lists cleared |
| R-13 | `/bl purge` → confirm | All history gone; every view empties; Storage section reads "No movements recorded yet." |
| R-14 | `/bl` with no argument, and `/bl badverb` | Help index renders with section headings; the bad verb reports itself then prints help |
| R-15 | Rename `libs/LibKa0s` away, `/reload` | Addon still loads; one honest "LibKa0s library is missing…" line on the first print; `/bl show`, `/bl toggle` and `/bl resetall` still work; `/bl config` and `/bl debug` explain themselves. Restore the folder afterwards |

**Not required:** no taint findings and no locale findings were raised in this review, so the
taint-specific and localization sections are deliberately absent. (The addon routes no string through
`NS.L` at v1.0.0 by documented scope decision, so a locale switch has nothing to exercise.)

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-001 | | | |
| C-002 | | | |
| C-003 | | | |
| C-004-1 | | | |
| C-004-2 | | | |
| C-004-3 | | | |
| C-004-4 | | | kB before / after: |
| C-005b | | | |
| C-005e | | | |
| R-1 … R-15 | | | |
