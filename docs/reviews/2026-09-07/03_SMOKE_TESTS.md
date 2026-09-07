# Smoke tests — Ka0s Bank Ledger — 2026-09-07

In-client verification for the changes in `02_PROPOSED_CHANGES.md`. **Everything that runs headless
already ran in Step 0** and is recorded in `01_FINDINGS.md` ▸ Measurement run; this document is only
what needs a login.

**Pre-flight (one line, run before you log in):** from the repo root,
`luacheck . && lua5.1 tests/run.lua` — both must be green, and the test total must match the
`**Total**` row of `docs/test-cases.md` and the README `[Tests]` badge.

---

## Pre-flight — client setup

1. Retail only. `BankLedger.toc` declares `## Interface: 120007`; confirm the client's build matches
   (`/run print(select(4, GetBuildInfo()))`).
2. Install by copying the repo folder to `.../Interface/AddOns/BankLedger`. Confirm `libs/LibKa0s/`
   came across whole — 15 `.lua`/`.xml` files plus `media/`.
3. `/console scriptErrors 1` and `/reload`. Any Lua error popup during this checklist is a **fail**
   for the section it appears in, whatever else the section observes.
4. `/etrace` is useful for sections T-1 and T-4; leave it open, filtered to `BANKFRAME_OPENED`,
   `BAG_UPDATE_DELAYED` and `PLAYER_MONEY`.
5. **Character:** any level, must have a character bank. Sections T-4 and R-4 additionally need a
   guild with a guild bank you can open.
6. **Back up `WTF/Account/<ACCOUNT>/SavedVariables/BankLedger.lua` before starting.** T-2 and T-3
   deliberately manipulate and destroy it.

---

## T-1 — the global reset re-arms the capture engine

**Change covered:** C-1 — `Sl:ResetEverything` broadcasts `Ka0s_BankLedger_SettingsChanged`
(`BANKLEDGER-R-01`).

**Setup**
1. `/reload` with an existing SavedVariables file.
2. `/bl config` → General → Master controls. Confirm the **Reset all settings** button is present.
3. Go to General and switch **capture off** (the `enabled` row). Confirm with `/bl get enabled` →
   must print `false`.
4. `/bl debug on` so the `[Store]` and `[Filters]` traces are visible.

**Steps**
1. Visit a bank, open it, deposit one stack of anything, close the bank. Confirm **nothing** was
   recorded: `/bl show` → the History tab has no new row (capture is off — this establishes the gate
   is genuinely reading `false`).
2. `/bl config` → General → Master controls → **Reset all settings** → confirm **Yes** on the
   `Reset this addon to its defaults?` popup.
3. Do **not** `/reload`. Confirm the panel now reads capture **on** and `/bl get enabled` prints
   `true`.
4. Return to the bank, open it, deposit one stack, close the bank.

**Expected**
- Step 4 produces a new row in `/bl show` ▸ History, with the correct item, direction `Deposit`,
  store `Bank` and quantity.
- The debug console shows a `[Store]` open line and an entry line for the movement.

**Pass / Fail:** PASS if and only if the deposit in step 4 is recorded **without a `/reload`**
between the reset and the deposit. FAIL if the row is missing, or if it only appears after a reload
— that is the pre-fix behaviour exactly.

---

## T-2 — the global reset re-arms the filter lists (table identity, not just scalars)

**Change covered:** C-1 (`BANKLEDGER-R-01`), the half a scalar-only fix would miss.

**Setup**
1. `/reload`. Capture on (default).
2. Pick a cheap, stackable item you can move freely — note its item id, e.g. Linen Cloth `2589`.
3. `/bl config` → General → **Blacklist** tab → add that id. Confirm it appears in the list.
4. Visit a bank and deposit one of that item. Confirm **no row** appears in `/bl show` ▸ History
   (the blacklist is working).

**Steps**
1. Without reloading: `/bl config` → General → Master controls → **Reset all settings** → **Yes**.
2. Confirm the Blacklist tab is now empty.
3. Return to the bank and deposit one of that same item.

**Expected**
- The movement **is** recorded.

**Pass / Fail:** PASS if the deposit in step 3 appears in History with no `/reload`. FAIL if it is
still suppressed — that means the Ledger's `DB_BLACKLIST` upvalue is still pointing at the table the
wipe discarded, which is the identity half of `BANKLEDGER-R-01`.

---

## T-3 — the schema-version stamp survives a real logout/login cycle

**Change covered:** C-2 — the stamp leaves the AceDB defaults (`BANKLEDGER-R-02`). **This is the only
check in this document that the headless suite structurally cannot make**, because it needs AceDB's
real `PLAYER_LOGOUT` handler.

**Setup**
1. Restore or create a SavedVariables file with recorded history — at least ten entries. Get there by
   playing normally, or by restoring the backup from Pre-flight step 6.
2. **Fully exit the client** (not `/reload` — the strip runs on `PLAYER_LOGOUT`, which a reload does
   fire, but a clean exit is the unambiguous case).
3. Open `WTF/Account/<ACCOUNT>/SavedVariables/BankLedger.lua` in a text editor.

**Steps**
1. In the file, confirm `["schemaVersion"] = 2,` is **present** under `["global"]`. Record whether it
   is there.
2. If it is present: log in, `/reload`, exit fully again, and re-check. It must **still** be present.
3. Now simulate the pre-fix state deliberately: with the client closed, **delete** the
   `["schemaVersion"] = 2,` line (leave the ledger entries alone). Save.
4. Log in. `/bl debug on`, then `/reload` and read the console for a `[Migrate]` line.
5. Exit fully and re-open the file.

**Expected**
- Step 1 and step 2: `schemaVersion` is present in the saved file after every logout. Under the
  pre-fix code it is **absent** — that absence is the bug, and seeing it here on an unpatched build
  is the confirmation of `BANKLEDGER-R-02`.
- Step 4: the addon treats the stamp-less store as v1 (it has entries) and runs the v1→v2 pass. The
  `[Migrate]` line reads `v1 -> v2, N rows touched`.
- Step 5: `["schemaVersion"] = 2,` is back in the file.

**Pass / Fail:** PASS if the stamp persists across a real logout (steps 1-2) **and** a stamp-less
store with entries migrates (step 4). FAIL if the key vanishes from the saved file, or if step 4
produces no `[Migrate]` line.

**Then restore your backup.**

---

## T-4 — a stamp-less EMPTY store is stamped current, not replayed

**Change covered:** C-2's discriminator branch (`BANKLEDGER-R-02`).

**Setup**
1. Client closed. Move `BankLedger.lua` aside entirely (fresh install).

**Steps**
1. Log in. `/bl debug on`. `/reload`.
2. Read the console.
3. `/bl show` and confirm the History tab is empty with its "No bank movements recorded yet" text.
4. Exit fully; open the saved file.

**Expected**
- **No** `[Migrate]` line on a fresh install — there is nothing to migrate.
- The saved file carries `["schemaVersion"] = 2,`.

**Pass / Fail:** PASS if no migration line appears and the stamp is written. FAIL if a
`v1 -> v2, 0 rows touched` line appears — that is the wasted replay `defaults/Global.lua`'s original
comment was written to avoid.

---

## T-5 — disable / re-enable re-arms the capture engine

**Change covered:** C-4 — `addon:OnDisable` clears the enable latches (`BANKLEDGER-R-04`).

**Setup**
1. `/reload`. Capture on. `/bl debug on`.

**Steps**
1. `/run LibStub("AceAddon-3.0"):DisableAddon("BankLedger")`
2. `/run LibStub("AceAddon-3.0"):EnableAddon("BankLedger")`
3. Without reloading, visit a bank, open it, deposit one stack, close it.
4. `/bl debug scan` and read the console's registered-event list.

**Expected**
- Step 3 records a row in `/bl show` ▸ History.
- Step 4's `[Scan]` dump shows the bank events registered.

**Pass / Fail:** PASS if the deposit is recorded after the disable/enable round trip. FAIL if
nothing is recorded — that is the latch never clearing.

---

## T-6 — the `test` verb and the settings panel after the comment/guard changes

**Change covered:** C-6 (`BANKLEDGER-R-07`, `BANKLEDGER-R-10`).

**Steps**
1. `/bl test` → expect `[BL] test mode on`. `/bl show` shows the sample ledger.
2. `/bl test` again → expect `[BL] test mode off`, and the sample ledger is gone.
3. `/bl config` → General. Confirm the **Master controls** tab is the **first** tab and that the tab
   strip renders every section without truncation.

**Pass / Fail:** PASS if both toggles report the state they actually produced, and the General page's
Master controls tab is present and first. (The `BANKLEDGER-R-10` half is comment-only and has no
in-client observable — it is verified by reading the file.)

---

## Regression suite

Run after all changes are in, regardless of which sections above were touched.

| # | Check | Expected |
|---|---|---|
| R-1 | `/reload` from a fully loaded UI | No Lua error, `/bl show` reopens with the same view |
| R-2 | Cold login on a fresh SavedVariables | Defaults populate; `/bl list` prints every setting at its default; no error at `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` |
| R-3 | Open character bank, deposit + withdraw one stack each | One `Deposit` and one `Withdrawal` row, correct store and quantity |
| R-4 | Open **guild** bank, deposit one stack, then deposit gold | An item row at store `Guild Bank`, and a gold row. Gold at the character bank must **not** produce a row (the corroboration rule) |
| R-5 | Warband tab: deposit via the Warband tab of the retail bank frame | Row at store `Warband Bank`, not `Bank` |
| R-6 | Enter and leave combat with both windows open | Windows behave per Settings ▸ General ▸ visibility; no error on either edge |
| R-7 | `/bl config` → open **every** tab on General, toggle **every** control once, then reset with the header Defaults button | Every control returns to its default; no error; the recorded ledger is **kept** (that is `CliResetAll`, not `ResetEverything`) |
| R-8 | `/bl purge` → confirm Yes | History empties; `[BL] ledger purged.` |
| R-9 | `/bl debug` → window opens; press **Esc** to close it; reopen `/bl config` → General → Master controls | The debug-console checkbox correctly reads **off** after the Esc close (the `onVisibilityChanged` seam) |
| R-10 | `/bl export` flow: open the export modal, press Copy | Copy window opens with the export text selected; both windows wear the addon's own 24x24 close control |
| R-11 | Drag and resize both the ledger window and the session window, then `/reload` | Geometry is restored |
| R-12 | `/bl help` | Lists all 16 verbs, matching the README table |

---

## Taint checks

The review raised **no taint findings** — this addon touches no protected API, registers no
`OnUpdate`, and reaches the Settings panel only through `LibKa0s-Options-1.0`. Two confirmations
are worth keeping anyway, because C-1 changes what runs during a settings reset:

| # | Check | Expected |
|---|---|---|
| X-1 | Enter combat with a target dummy, then click several action bar slots | No `Interface action failed because of an AddOn` red text |
| X-2 | Open the settings panel from `/bl config` **and** from Esc → Options → AddOns → Ka0s Bank Ledger | Both routes land on the same page; no taint message; in combat, `/bl config` refuses cleanly (per `README.md:170`) rather than erroring |

---

## Localization

The review raised no locale findings. `locales/enUS.lua` records that v1.0.0 ships English-only as a
scope decision and that no string routes through `NS.L` yet, so a locale switch changes nothing this
review touched. **Skipped, deliberately.**

---

## Performance spot-checks

This addon holds a ratified `performance-§12` no-combat-path exemption and ships **no** perf
harness — there is no `/bl perf` verb, no `BankLedgerPerfDB`, no `tests/perf.lua`. The two-arm
capture protocol therefore does not apply and **must not** be improvised.

One check stands in its place, because C-1 adds a bus broadcast to a user-facing action:

| # | Check | Expected |
|---|---|---|
| P-1 | `/run collectgarbage("collect"); local a = collectgarbage("count")` → run Master controls ▸ Reset all settings → `/run print(collectgarbage("count") - a)` | A one-off allocation on the order of the defaults table, not a growing figure. Repeat the reset three times; the per-reset delta must not climb — a climbing figure means a subscriber is retaining the discarded tables |

Do **not** run the `/wow-addon:perf-analysis` capture protocol here, and do not create a
`docs/perf-analysis/` bundle: the exemption is the reason both are absent, and a capture whose every
bucket reads `0.000` is the report `performance-§3` forbids.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| T-1 | | | |
| T-2 | | | |
| T-3 | | | |
| T-4 | | | |
| T-5 | | | |
| T-6 | | | |
| R-1 … R-12 | | | |
| X-1 | | | |
| X-2 | | | |
| P-1 | | | |
