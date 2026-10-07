# In-client smoke tests: Ka0s Bank Ledger, 2026-10-07

These are run by the owner, and none of them is marked passed here. Headless suites are not repeated in this file.

## Pre-flight

- Re-run `lua tests/run.lua` (expect 1262 passing, 1 skip) and `luacheck .` (0/0) after the changes land.
- Retail `## Interface: 120100`, with the addon loaded from `GIT/BankLedger` via the symlink. `/console scriptErrors 1`. Use a character with some ledger history across at least two item types and two stores.

## Per-change checks

### C-01: *Group: Type & SubType* ordering unchanged (F-001)

- **Setup:** `/bl show`, History tab.
- **Steps:**
  1. Group: Type & SubType.
  2. Group: Quality.
  3. Click the Quality header.
- **Expected:**
  - Step 1: groups read `Type: Armor`, then `Type: Armor · Cloth`, and so on, and "Gold" stands alone.
  - Step 2: Poor→Legendary.
  - Step 3: the group order flips.
- **Pass:** all three orders are as expected, with no Lua error.

### C-02: ledger window behaves identically after the peel (F-002)

- **Steps:**
  1. `/reload`.
  2. `/bl show`.
  3. On History, set Store = Bank and press Save.
  4. Switch to Insights, set Date = 7 days and press Save.
  5. `/reload`, then `/bl show`.
  6. Check each tab, then press Reset on Insights.
- **Expected:**
  - Step 3 prints `History view saved as your default.`, and step 4 prints `Insights view saved as your default.`
  - After the reload each tab opens on its own saved view.
  - Step 6 prints `Insights view reset to stock defaults.`, and History keeps Store = Bank.
- **Pass:** every line and state is as expected, with no error.

### C-03: one repaint per switch (F-003)

- **Setup:** `/bl debug on`, then open the console.
- **Steps:**
  1. `/bl show`.
  2. Switch History → Insights → History.
  3. Press Clear.
- **Expected:** for each switch, one `[Insights] …` (or one `[Table] …`) render line, not two or three, and no further render line about 0.2 s later.
- **Pass:** each switch and each Clear produces exactly one render line for the tab on screen.

### C-04: search trims (F-004)

- **Steps:** type `linen ` (with a trailing space) in Search on an account with Linen Cloth in the ledger.
- **Expected:** the table keeps its Linen rows, and the suggestion list offers Linen Cloth.
- **Pass:** the table is not empty.

### C-05: PANEL-28 extended (F-005)

- **Steps:**
  1. Save a view on History and a different one on Insights.
  2. Settings → Reset all settings → Yes.
  3. Press Clear on each tab.
- **Expected:** both tabs land on stock. `BankLedger.lua` (after logout) holds no `savedViews` under the active profile.
- **Pass:** both tabs are stock and the key is absent.

## Regression

- `/reload` is clean. Login completes with no errors, and the login prune and backfill debug lines appear when logging is on.
- Enter and leave combat with the window open, under each visibility rule.
- Profile switch on the Profiles page: both tabs repaint to the new profile's views.
- Test mode on and off while on Insights: the sample opens unscoped, and leaving it restores the active tab's baseline.

## Cross-addon (in-client half)

- Type each of the eleven roots (`/at /am /bl /cm /kcd /lh /mm /pm /pfe /pc /wg`) and confirm each reaches its own addon.
- Settings → AddOns: each addon appears exactly once, and each multi-page addon's pages appear once each.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | | | |
| C-04 | | | |
| C-05 | | | |
| Regression | | | |
| Cross-addon | | | |
