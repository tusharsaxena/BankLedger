# Review findings: Ka0s Bank Ledger, 2026-10-07

**Verdict: minor issues.** No Critical or High defects. One function is now above CCN 15 (it blocks the next release tag), `modules/Browser.lua` sits 73 lines under the layout-§1 cap, and the rest are Low.

**Resolved scope:** `all`. This is the whole repository at `662221b` on `feat/2026-10-07-review-audit-remediation` with a clean tree. The review read the code changed since the 2026-09-23 review most closely: the per-tab filter views (`e8d264a`), search autocomplete (`e5cd620`), *Group: Type & SubType* (`5a78432`), schema v5, the login backfill (`dd3080a`) and the v3/v4 profile work. Earlier code was swept for regressions and was not re-litigated. Standard: **v2.76.1 (2026-10-07)**, fetched from `raw.githubusercontent.com` (the index, plus every section it links). The standards cross-check ran.

## Measurement run (re-run from scratch today)

Every run went through `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded`, and output went to the session scratchpad. This bundle is the only thing written into the repo.

| Suite | Result | Command (repo root) |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 87 files | `ka0s-bounded luacheck .` |
| Headless suite | **pass**: 1258 passed, 0 failed, 1 skipped, 1259 total. The skip is the kit's `diagnostics contract` opt-out case, which does not apply because this addon keeps `enablesLogging` at its default. | `ka0s-bounded lua tests/run.lua` |
| `--list` inventory | **ran**. After CR-normalization it is byte-identical to the committed `docs/test-cases.md` (Totals 1259). The README badge reads `1258/1258`, which agrees. | `ka0s-bounded lua tests/run.lua --list > $SCRATCH/list.md` |
| Offline perf runner | **not applicable**: there is no `tests/perf.lua`. This follows from the ratified `performance-§12` no-combat-path exemption (`docs/performance.md`). It is not a pass. | n/a |
| Complexity (sighted, kit 37) | **ran, 1 warning**: max CCN **16**, 22650 NLOC, 3628 functions, avg CCN 2.0. No blind files were reported. The warning is `LT.GroupEntries` (`modules/LedgerTable.lua:320`, CCN 16, NLOC 35); see F-001. | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`. The warned name came from the runner's own shadow step plus the fixed `lizard -l lua -L 1500 …` invocation, run in scratch. |
| `make test` | **not applicable**: no root `Makefile` | n/a |
| Vendor sync | **pass**: `diff -r libs/LibKa0s ../LibKa0s/LibKa0s` and `diff -r tests/_kit ../LibKa0s/testkit` are both silent. `git -C ../LibKa0s diff --stat v1.70.0 -- LibKa0s testkit` is empty, so the sibling worktree equals the tag the `CLAUDE.md` provenance line names (v1.70.0). | as stated |
| Cross-addon: slash tokens | **clean**: 22 roots across 11 addons, no duplicates, and no raw `SLASH_*` in any TOC-loaded file | the brief's two loops, scoped to each addon's TOC-derived load list, roster from `WowAddonStandards/standards/ADDONS.md` (11 rows) |
| Cross-addon: vendored minors | **clean**: one line for all 11, `Bus:2 Compat:1 Core:10 DebugLog:19 Env:1 Item:2 Launcher:5 Lifecycle:3 Media:4 Options:28 Perf:14 Pool:3 Schema:2 Slash:19 Widgets:12` | the brief's minors loop |
| Cross-addon: payload bytes | **clean**: `diff -rq AbsorbTracker/libs/LibKa0s <addon>/libs/LibKa0s` is silent for all 11 (159 files, reference AbsorbTracker) | as briefed |
| Cross-addon: `## Interface:` | **clean**: `120100`, uniform | as briefed |

**The cross-addon brief's baseline is stale, not drifting.** The library tag has moved from v1.56.0 to v1.70.0, so every library-derived figure differs. All four classes are still one line each, so there is no finding.

**Committed artifacts that disagree with today's run:**

- **`docs/automated-tests/RESULTS.md`** is stale. Its newest bundle, `20260927-031851` (sha `b97fd24`), is 67 commits behind HEAD according to the runner's own `record:` line. It records max CCN 15, 0 warned and 2920 functions. Today's run gives max CCN 16, 1 warned (F-001) and 3628 functions. Its band table gives `modules/Browser.lua` at 1221 LOC, where today's count is **1427** (F-002). It also lists neither of the two test files now in the band. Stale is not non-compliant: the record is regenerated at release (F-007).
- **`docs/test-cases.md`** agrees with the fresh `--list`.
- **`docs/performance.md`** is the exemption page. No figure in it was contradicted.

**LOC census.** Scope is the default: tracked, authored Lua, excluding `libs/` and `tests/_kit/`, with `tests/` included. Command: `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | tr '\n' '\0' | xargs -0 wc -l | awk '$2!="total" && $1>=1000'`. Result: 0 files over 1500. Four are in the 1000–1500 band: `modules/Browser.lua` 1427, `tests/test_browser.lua` 1059, `tests/test_profiles.lua` 1010 and `modules/Insights.lua` 1004.

**Line endings** (observation only, `line-endings-§2`). `.gitattributes` carries the CRLF pin, the `*.sh` carve-out and the binary set. `git ls-files --eol` shows 461 `w/crlf` files, 131 `w/-text` binaries and 1 `w/lf`. That LF file is `tests/_kit/run-automated-tests.sh`, which is the carve-out. No stragglers.

## Conventions detected (sweep)

- Chat prefix `NS.PREFIX` (`core/Namespace.lua`), and `NS.Print` reclaimed from AceConsole (`core/BankLedger.lua:13`). `NS.COMMANDS` is walked by LibKa0s-Slash, the single write seam is `NS.Schema:Set` (LibKa0s-Schema), and the schema is flat-row (`settings/Schema.lua`).
- LibKa0s v1.70.0 is vendored whole, and `tests/_kit/` is at kit revision 37. Wired seams: Core, DebugLog, Env, Item, Media, Pool, Launcher, Lifecycle, Slash, Options, Schema, Bus and Widgets (dropdown plus Autocomplete via `B:MakeAutocomplete`). Perf is declined under `performance-§12`.
- `tests/run.lua` derives its own load list from the TOC (`Loader.tocFiles`) and the library's from `LibKa0s.xml` (`Loader.xmlFiles`), as `testing-§9` requires. No `docs/CLAUDE_SECRET_VALUES.md` exists, and none is needed because the addon reads no secret-bearing API.
- English-only by a recorded scope decision (`locales/enUS.lua:8-12`). Unwrapped chat strings are therefore not findings.

---

Each finding carries a **Needs addressing** line. It is the reviewer's adversarial verdict and is input to the consolidation step.

## Medium

### F-001: `LT.GroupEntries` crossed CCN 15 when *Type & SubType* grouping landed `[complexity]`

- **Where:** `modules/LedgerTable.lua:320` `function LT:GroupEntries(entries)`. The decision that tipped it is at `:339`: `sortKey = sortFn and sortFn(e) or groupOrder or valueLabel }`.
- **Problem:** The fresh sighted run reports CCN **16** (NLOC 35). The committed record (`20260927-031851`) has no function above 15. `5a78432` added the `or groupOrder`, which is one more `and`/`or` decision in a defaulting chain. That is dense defaulting rather than tangled control flow.
- **Impact:** The release gate (`automated-tests-§3`, *The release gate*: all four suites pass and zero functions are above CCN 15) fails on the next `/dev-copilot:bump-version`. No runtime effect.
- **Reachability:** Nobody at runtime. The next release run reaches it, and that run refuses the tag.
- **Measured:** `lizard` warning line `./modules/LedgerTable.lua:320: warning: LT.GroupEntries has 35 NLOC, 16 CCN, 310 token, 2 PARAM, 45 length`.
- **Coverage:** `tests/test_ledgertable.lua` has *typesub* ordering cases (`+70` lines in the diff since `2c87997`). The decision is pinned, so a mechanical extraction is safe.
- **Needs addressing: Yes.** It is a hard release blocker, and the fix is one small helper.

### F-002: `modules/Browser.lua` is at 1427 of 1500 lines, and its named peel seam was never cut `[design]`

- **Where:** `modules/Browser.lua` (1427 LOC). The census command is in the measurement block.
- **Problem:** The file grew by 206 lines since the record's 1221. The growth was per-tab view state (`SwapTabState`, `ClearAllTabs`, `savedSlots`) and the search-suggestion provider (`SuggestNames`, `_rankSuggestions`, `SetSearchText`). The band row in `RESULTS.md` accepts the file as **`BL-24`**, with the peel seam named ("the skin/close-button factory and the geometry persistence lift into a sibling file"), but that row was written at 1221. The file now has 73 lines of headroom. `tests/test_browser.lua` (1059) and `tests/test_profiles.lua` (1010) have newly entered the band.
- **Impact:** The next feature added to the ledger window takes the file over the `layout-§1` cap, which "is a bug — peel it". The peel would then be forced under feature pressure rather than done as a pure move.
- **Reachability:** Maintainers only. No runtime effect.
- **Needs addressing: Yes, as a pure move, but schedulable.** It is not a defect today. The cheapest moment to cut it is now, while it is a no-behavior-change move with a green suite behind it.

## Low

### F-003: Every `ApplyView` (each tab switch, Clear, Reset and profile event) recomputes the window two or three times `[perf]`

- **Where:** `modules/Browser.lua:879` `if self._search then self._search:SetText(search) end`, then `:882` `B:ApplyFilterNow()`. On a tab switch, `B:SelectTab` then refreshes again at `:238`–`:242` (`NS.LedgerTable:Refresh()` / `NS.Insights:Refresh()`), after `:235` `B:SwapTabState(prev, name)` has already repainted through `ApplyFilter` (`:530` `NS.LedgerTable:SetFilter(...)`, `:533` `NS.Insights:Refresh()`).
- **Problem:** The search box's `OnTextChanged` (`:1093`–`:1097`) arms `B:ScheduleApplyFilter()` whatever `userInput` is. The addon's own comment at `:664`–`:666` says the client fires it on `SetText`, so `ApplyView` leaves a 0.20 s debounced re-apply armed behind its immediate one. `SetSearchText` cancels exactly this debounce (`:672`), but `ApplyView` does not. A History→Insights switch therefore costs two `Database:Stats` passes (three on Insights' first visit, because `I:Attach` refreshes), plus a third through the debounce. Each also runs a hidden History table rebuild.
- **Impact:** Redundant full queries and Stats passes (the file's own note at `:544` puts Stats at "roughly twenty sorts") on every view change. The results are correct.
- **Reachability:** Any player who uses the ledger window and switches tabs or presses Clear/Reset. This is out of combat, under the ratified `performance-§12` no-combat-path exemption.
- **Unverified cost:** there is no offline perf runner (exempt), and the headless mock's `EditBox:SetText` does not fire `OnTextChanged` (`tests/wow_mock.lua:261`), so no case can observe the debounced third pass. Whether the client fires `OnTextChanged` on an identical `SetText` is also unverified. The count above relies on the addon's own documented client behavior.
- **Needs addressing: Optional, but cheap.** One shared "drop the filter debounce" helper and one guard in `SelectTab`. Skip it if the owner prefers not to touch the view path again this cycle.

### F-004: The search filter matches untrimmed text while its suggestions trim it `[ux]`

- **Where:** `modules/Browser.lua:607`–`:608` `trimLower` (suggestions), against `:1096` `B.activeFilter.text = (t ~= "") and t or nil` and `core/Database.lua:476` `local text = filter.text and filter.text:lower() or nil` (the filter has no trim).
- **Problem:** Typing `linen ` (with a trailing space) empties the table, but the list under the box still offers **Linen Cloth**.
- **Impact:** A momentarily confusing empty table. A pick or a backspace recovers.
- **Reachability:** Any player who types a leading or trailing space in Search.
- **Needs addressing: Optional.** It is a one-line normalization, and item names never carry edge whitespace. Acceptable to decline.

### F-005: Seven prose lines still describe a single saved view, and `debug.md` calls the session-only tab "written" `[docs]`

- **Where:** `docs/ARCHITECTURE.md:92` ("both filter lists, the saved view and both windows'"), `:103` ("the saved view, visibility, the row tint"), `docs/debug.md:89` ("Window geometry, the saved view and the remembered tab are written"), `docs/settings-panel.md:200`, `docs/slash-dispatch.md:141`, and `docs/smoke-tests.md:202` (PANEL-28: "the saved view discarded (Clear lands on stock)", which checks one tab only).
- **Problem:** Since schema v5 there is one saved view per tab (`savedViews[History|Insights]`). The remembered tab is the file local `local lastTab = "History"   -- remembered within a session` (`modules/Browser.lua:202`) and is never written to SavedVariables.
- **Impact:** A reader believes there is one baseline, and a tester running PANEL-28 does not check that the other tab's view was discarded too.
- **Reachability:** Documentation only. No runtime effect.
- **Needs addressing: Yes.** These are cheap prose edits, and PANEL-28 is a smoke check the owner runs.

### F-006: The login backfill always spends its 40-id budget on the oldest ids, so permanently unresolvable ids could starve it `[design]`

- **Where:** `modules/Backfill.lua:171` `Backfill.Collect(ledger, C.BACKFILL_MAX_IDS)` walks the ledger in order (`:43`) and takes the first `core/Constants.lua:168` `C.BACKFILL_MAX_IDS = 40` distinct ids that `needsFill` (`:31`) accepts.
- **Problem:** An id the client can never resolve (a removed item) stays `needsFill` forever and is collected first on every login. Forty of them would block every newer uncached row from being backfilled.
- **Impact:** Newer rows keep showing "Item <id>".
- **Reachability:** Practically nobody. It needs 40 distinct unresolvable ids in the retained history. The 30-day retention prunes old rows on the default profile, which self-heals it unless retention is off.
- **Needs addressing: No.** Record it only. The design comment already accepts multi-login drains, and a rotation cursor would be speculative complexity.

### F-007: The committed complexity record describes a tree 67 commits old `[complexity]`

- **Where:** `docs/automated-tests/RESULTS.md`, newest bundle `20260927-031851`.
- **Problem / Impact:** As stated in the measurement block, it misses F-001's warning, Browser's 1427 lines and the two test files that are new to the band.
- **Reachability:** Readers of the record. No runtime effect.
- **Needs addressing: No, by rule.** It is regenerated at release (`/dev-copilot:bump-version`) and never hand-edited (`automated-tests-§4`).

## Upstream

None. The vendor sync and all four cross-addon classes are clean, and nothing under `libs/` or `tests/_kit/` was implicated.

## Not findings (checked and clean)

- **Schema v5 migration** (`core/Database.lua:195`–`215`). It is idempotent, gives each slot its own copy, drops a scalar, and leaves a profile that never saved a view without a `savedViews` key. A v2 store takes v3 and then v5, and `tests/test_profiles.lua` pins all of it.
- **Per-tab state.** It is dropped on a profile event (`ClearAllTabs`) and on a dataset swap (`OnDatasetChanged`). Reopening the window keeps the tab's state (`SwapTabState` is a no-op when `from == to`). The autocomplete list closes on a tab switch and on `B:Hide`, so the stand-down closes it too, and its stand-down case is falsifiable because the kit's `C_Timer.After` records.
- **Search text matching** uses plain `find(…, 1, true)` in both the filter and the suggestions, so there is no pattern injection.
- **Disabled state.** The stand-down unregisters everything on the addon object, every bus target and every timer, and drops the backfill pass (anti-pattern #85 does not apply).
