# Proposed changes: Ka0s Bank Ledger, 2026-10-07

Standard resolved: **Ka0s WoW Addon Standard v2.76.1 (2026-10-07)**, fetched raw from `tusharsaxena/WowAddonStandards@master`. The standards cross-check ran.

## HLD

| Theme | Findings | Rationale | Alternatives rejected |
|---|---|---|---|
| T1. Bring `GroupEntries` back under the release gate | F-001 | The release gate (`automated-tests-§3`) refuses a tag while any function is above CCN 15. | **Pushing the defaulting into `groupOf`'s return.** It lands at CCN 15 exactly, and the next decision tips it again. **A disposition note instead of a fix.** The gate has no waiver. |
| T2. Cut Browser's named peel seam now, as a pure move | F-002 | `layout-§1`: the 1000–1500 band is on notice, and the next window feature crosses the cap. The seam is already named in `RESULTS.md` (BL-24). This proposes the cohesive per-tab view block instead, which is the code that grew. | **Peeling the skin/close factory only.** It is about 60 lines and leaves the file fragile. **Waiting until the cap is crossed.** The peel would then be done under feature pressure. |
| T3. One debounce owner for programmatic `SetText` | F-003 | `SetSearchText` already cancels the debounce `SetText` arms. `ApplyView` should do the same through one helper rather than a second copy. `SelectTab` should not repaint what `SwapTabState` just painted. | **Gating `OnTextChanged` on `userInput`.** `OnTextChanged` is also how the placeholder hides, and a paste fires with `userInput` true anyway. It is a riskier semantic change. |
| T4. Normalize search text once | F-004 | The filter and the suggestions should read the same text. | **Trimming in `Database.QueryList`.** That would be a database-layer change for a UI concern. |
| T5. Doc drift after schema v5 | F-005 | Prose that says one saved view misleads both readers and the smoke tester. | n/a |
| Not changed | F-006, F-007 | F-006 has effectively no reach, and F-007 is regenerated at release by rule. | n/a |

## Upstream change-set

None.

## LLD

### C-01 (F-001): extract the group sort-key choice from `LT:GroupEntries`

`modules/LedgerTable.lua`, above `LT:GroupEntries`:

```lua
-- The value a group is ordered by: the grouped column's own sort value when the mode has a column,
-- else the arm's explicit order (typesub), else the header label. Same precedence as before.
local function groupSortKey(sortFn, e, order, label)
  local k = sortFn and sortFn(e)
  if k ~= nil and k ~= false then return k end
  if order ~= nil then return order end
  return label
end
```

At `:339`, the line `sortKey = sortFn and sortFn(e) or groupOrder or valueLabel }` becomes `sortKey = groupSortKey(sortFn, e, groupOrder, valueLabel) }`.

- **Risk:** none intended, because the precedence is identical. The helper is module level and allocates nothing (anti-pattern #52: a named helper with a real name, not a relocated body).
- **Tests:** the existing `typesub` and grouping cases in `tests/test_ledgertable.lua` are the characterization. Add one case asserting that a column-grouped mode (for example `quality`) still orders by the column's sort value, so that the precedence is pinned. That is **+1 case**, so `docs/test-cases.md` and the README badge move in the same commit (1258 → 1259 passing).
- **Watch list:** the next release run should show `GroupEntries` at or below CCN 15 and no warned functions.

### C-02 (F-002): peel the per-tab view machinery into `modules/Browser_Views.lua`

- **Move,** with no behavior change: `STOCK_VIEW`, `savedSlots`, `savedViewOrStock`, `CaptureView`, `applyTableState`, `viewSets`, `paintDropdowns`, `buildActiveFilter`, `B:ApplyView`, `B:ClearFilters`, `B:SaveView`, `B:ResetView`, `tabLive`, `applyBaseline`, `forgetTabStates`, `B:SwapTabState`, `B:ClearAllTabs` and their test seams (`B._savedViewOrStock`, …).
- **What the new file needs from Browser:** `lastTab`, `setToFilter`, `asSet`, `VIEW_SETS`, `defaultCharSelection`, `CURRENT_CHAR` and `tableViewState`. Browser publishes them on `B` as private members, or as read-through accessors where the value changes (`B:ActiveTab()` already exists for `lastTab`).
- **TOC:** `modules\Browser_Views.lua` goes directly after `modules\Browser.lua`, with a one-line LOAD-ORDER comment. It is conventional, because every caller reaches `B:*` at run time.
- **Risk:** this file's upvalue references to `lastTab` become `B:ActiveTab()` calls. Keep `ApplyFilter` in Browser and reach it through `B:ApplyFilterNow()`.
- **Watch list:** Browser should fall to roughly 1200 lines, and the new file should be roughly 250. Update `docs/module-map.md` and the `docs/ARCHITECTURE.md` load-order list in the same commit (`documentation-§3`). The test count does not move.
- **Standards:** `layout-§1` (peel before the cap) and `architecture` (one file per cohesive concern). File naming follows the existing `Ledger_Diagnose.lua` / `LedgerTable_TestMode.lua` peel precedent.

### C-03 (F-003): one debounce owner; `SelectTab` does not repaint twice

In `modules/Browser.lua`:

```lua
-- Drop a pending typing debounce. A programmatic SetText fires OnTextChanged in the client, which
-- arms one; whoever applies the filter immediately right after owns cancelling it.
local function dropFilterDebounce()
  local addon = NS.addon
  if pendingFilterTimer and addon and addon.CancelTimer then addon:CancelTimer(pendingFilterTimer) end
  pendingFilterTimer = nil
end
```

- `B:SetSearchText` uses the helper (replacing `:671`–`:673`). `B:ApplyView` calls it immediately before `B:ApplyFilterNow()` (`:882`).
- `B:SelectTab`: when `prev ~= name`, `SwapTabState` has already repainted the incoming tab through `ApplyFilter`, so only the History-side `RefreshFilterOptions()` stays unconditional. The `LedgerTable:Refresh()` / `Insights:Refresh()` pair runs only when `prev == name` (a window reopen).
- **Tests:** add a case in `tests/test_browser.lua` where `B:ScheduleApplyFilter()` is followed by `B:ApplyView(...)` and then `mocks.__fireTimers()`, asserting that `LedgerTable.SetFilter` was called exactly once. It is red under the current code. Add a second case where a History→Insights switch calls `NS.Insights.Refresh` exactly once on a built pane. That is **+2 cases**, and `docs/test-cases.md` and the badge move in the same commit.
- **Perf evidence:** this is a call count pinned by the headless cases. There is no perf runner (`performance-§12`).

### C-04 (F-004): trim the search text where the filter takes it

`modules/Browser.lua`: put one local `searchClause(t)` next to `trimLower`. It returns the trimmed text, or nil when the trimmed text is empty. The three writers of `activeFilter.text` use it: the `OnTextChanged` handler (`:1096`), `SetSearchText` and `buildActiveFilter`. The box keeps what the player typed. Add **+1 case**: `"linen "` matches Linen Cloth. The inventory and badge move in the same commit.

### C-05 (F-005): saved-views prose

- Pluralize, and say "one per tab" where it matters: `docs/ARCHITECTURE.md:92` and `:103`, `docs/settings-panel.md:200`, `docs/slash-dispatch.md:141`.
- Change `docs/debug.md:89` to "Window geometry and the saved views are written outside the seam; the active tab is session-only and never stored."
- Extend PANEL-28's expected result in `docs/smoke-tests.md:202` to "both tabs' saved views discarded (Clear lands on stock on History and on Insights)".

## Standards conformance (per change)

- **C-01:** removes a decision rather than relocating it behind a nameless helper (anti-pattern #52). There is no table built inside a hot function.
- **C-02:** satisfies `layout-§1` and follows the established peel naming. The TOC position is commented (`toc-file`). No library code is copied, and the Widgets seams stay in Browser.
- **C-03 / C-04:** local to the addon. They add no event registration and do not touch the latch (`slash-commands-§7`).
- **C-05:** prose only. It never edits a frozen bundle under `docs/reviews/`, `docs/audits/` or `docs/revendor/`, and it never hand-edits `docs/test-cases.md`.
- **Test movement:** C-01 +1, C-03 +2, C-04 +1, for 1262 passing. `docs/test-cases.md` is regenerated by `lua tests/run.lua --list`, and the README badge moves in the same commits (`testing-§7`).
