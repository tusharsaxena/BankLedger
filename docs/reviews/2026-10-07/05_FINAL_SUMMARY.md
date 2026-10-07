# Final summary (to be confirmed after implementation): Ka0s Bank Ledger, 2026-10-07

## Headline

This cycle brings the ledger table's grouping function back under the release gate's complexity limit, so the next release can be tagged. It peels the ledger window's per-tab view code into its own file before that file reaches the 1500-line cap. It stops each tab switch and Clear from recomputing the window two or three times, and makes the search filter ignore stray leading and trailing spaces the way its suggestions already did. It also updates the docs that still describe a single saved view.

## Counts

Critical fixed: 0, High fixed: 0, Medium fixed: 2 (F-001, F-002), Low fixed: 3 (F-003, F-004, F-005). Deferred: F-006 (no practical reach, record only) and F-007 (regenerated at release by rule).

## Changes by theme

- **T1 Release gate (F-001; C-01).** `LT.GroupEntries` takes its group sort key from a named helper with the same precedence. Without the fix the release run refuses the tag. Files: `modules/LedgerTable.lua`, `tests/test_ledgertable.lua`.
- **T2 Peel (F-002; C-02).** The per-tab view machinery moves to `modules/Browser_Views.lua`. `Browser.lua` was 73 lines under the `layout-§1` cap. Files: `modules/Browser.lua`, `modules/Browser_Views.lua`, `BankLedger.toc`, `docs/module-map.md`, `docs/ARCHITECTURE.md`.
- **T3 Debounce (F-003; C-03).** `ApplyView` drops the typing debounce that its own `SetText` arms, and `SelectTab` no longer repaints what the tab swap already painted. Files: `modules/Browser.lua`, `tests/test_browser.lua`.
- **T4 Search trim (F-004; C-04).** The filter applies the trimmed text. Files: `modules/Browser.lua`, `tests/test_browser.lua`.
- **T5 Docs (F-005; C-05).** "Saved view" prose is now per tab, and PANEL-28 checks both tabs. Files: `docs/ARCHITECTURE.md`, `docs/debug.md`, `docs/settings-panel.md`, `docs/slash-dispatch.md`, `docs/smoke-tests.md`.

## API and behavior changes

- Search ignores leading and trailing spaces.
- No slash, setting, schema or SavedVariables change. `NS.SCHEMA_VERSION` stays at 5.

## Saved-variable and migration notes

None.

## Deprecated-API migrations

None.

## Test and complexity movement

- Tests go from 1258 to 1262 passing (+4 cases). `docs/test-cases.md` and the README badge move in the same commits.
- The next release run should show 0 functions above CCN 15, `modules/Browser.lua` below 1300 LOC, and `modules/Browser_Views.lua` as a new small file.

## Known follow-ups

- F-006: the backfill could rotate past unresolvable ids if they ever accumulate. Not worth the complexity today.
- F-007: `RESULTS.md` is regenerated at the next `/dev-copilot:bump-version`.

## Verification evidence

The completed sign-off table in `03_SMOKE_TESTS.md`, and the commit range on `feat/2026-10-07-review-audit-remediation`.

## Suggested PR description

```
BankLedger: review 2026-10-07 remediation

- F-001: LT.GroupEntries back under CCN 15 (named sort-key helper; release gate)
- F-002: per-tab view machinery peeled to modules/Browser_Views.lua (Browser.lua was 1427/1500)
- F-003: ApplyView drops the debounce its SetText arms; SelectTab repaints once
- F-004: search filter trims its text, matching its suggestions
- F-005: docs describe per-tab saved views
Tests 1258 -> 1262. Deferred: F-006 (record only), F-007 (release regenerates).
```
