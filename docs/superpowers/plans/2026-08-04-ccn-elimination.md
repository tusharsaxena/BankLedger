# CCN elimination — BankLedger

Branch `feat/fix-ccn`. Design: `LibKa0s/docs/superpowers/specs/2026-08-04-ccn-elimination-design.md`.

**14 functions** with `lizard` CCN > 15. Target: every one at CCN <= 15, behavior unchanged.

## Exit criteria

1. `luacheck . --quiet` — 0 warnings, 0 errors.
2. `lua5.1 tests/run.lua` — all pass, count >= baseline.
3. `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` — no CCN > 15.
4. No behavior change. No version bump, no CHANGELOG, no merge, no tag.

## Rules

- Preferred shapes, in order: table-driven dispatch; a named file-local helper for a
  self-contained block; a data table + loop replacing repeated defaulting; splitting a
  builder into N small builders.
- No dumping a body into one helper to game the metric. Every resulting function must be a
  unit a reader can name.
- Dispatch/defaults tables are **module-level**, built once at file load — never per call.
- `lizard` counts `and`/`or` as decisions. Prefer `== nil` over `or` wherever a stored
  `false` or `0` must survive.
- Hot paths must not gain a per-call allocation.
- Sixteen functions across the collection have no coverage; where this file says
  `Coverage: NONE`, write a characterization test pinning current behavior **before**
  refactoring.

## Functions

### `Database:QueryList (lizard: Database@90-149)` — CCN 33 → target 8

`core/Database.lua:90-128` · pattern `predicate-and-chain` · risk **low**

**What it does.** Filters an arbitrary entry array against an optional filter spec. Every field is optional and AND-combined; kind/direction/store/char/itemType/itemSubType accept a scalar or a membership set, quality accepts a number or a set, plus ts range and a case-insensitive itemName substring.

**Where the branches come from.** A nested `matches` closure (built per call); a 6-term `and` chain over the set-capable fields; then five sequential `if ok and <cond> then ok = false end` guards for quality-set, quality-exact, from, to and text, each carrying its own `or 0` / `and ... or` defaulting. lizard folds Query (131-133) and Export (137-149) into the same node, so a few of the 33 come from Export's loop, but QueryList alone is well over 15.

**Fix.** 1) Hoist the nested `matches` closure to a file-local `local function matchesSpec(spec, value)` — identical body, but built once at load instead of once per QueryList call. 2) Replace the 6-term `and` chain with a module-level constant spec table: `local SET_FIELDS = { { key = "kind", get = function(e) return e.kind end }, { key = "direction", ... }, { key = "store", ... }, { key = "char", ... }, { key = "itemType", get = NS.Util.EntryType }, { key = "itemSubType", get = NS.Util.EntrySubType } }` and loop `for _, f in ipairs(SET_FIELDS) do if not matchesSpec(filter[f.key], f.get(e)) then ok = false; break end end`. SET_FIELDS is module-level, so nothing is allocated per call or per entry. 3) Extract three file-local guards: `local function qualityOK(e, qIsSet, qExact, qSet)` (CCN 4), `local function rangeOK(ts, from, to)` (CCN 4), `local function textOK(name, text)` (CCN 3). QueryList's body becomes: default the filter, precompute qIsSet/qExact/from/to/text, then one `for _, e in ipairs(entries)` whose body is `local ok = allFieldsMatch(filter, e) and qualityOK(...) and rangeOK(...) and textOK(...)`. Behaviorally identical: matchesSpec, EntryType and EntrySubType are pure, so the loop's early `break` only skips work, never a side effect. Optional micro-win (safe, same reason): skip `f.get(e)` when `filter[f.key] == nil`.

**Must not change.** Set-vs-scalar semantics per field; itemType/itemSubType must keep matching the EFFECTIVE type (NS.Util.EntryType/EntrySubType), not the raw fields, so gold movements filter as "Gold". Quality: a table spec is membership, a number is exact against `e.quality or 0`, anything else is ignored. Range is inclusive on both ends against `e.ts or 0`. Empty/nil filter returns everything. Output order must stay input order.

**Coverage.** tests/test_database.lua (direct QueryList cases); also exercised transitively by test_browser.lua and test_insights.lua through Database:Query

---

### `P:Diagnose (lizard: P@371-447)` — CCN 31 → target 6

`settings/Panel.lua:371-447` · pattern `guard-stack` · risk **low**

**What it does.** `/bl debug panel` — a structured runtime dump of what the options header's Defaults button actually is: which AceGUI copy served it, the widget/frame types, the parent chain, and the button's art (normal/highlight/pushed textures, the full region tree including the NineSlice child frame, and the font string). It is the tool that found the load-order skinning race.

**Where the branches come from.** Three nested closures built per call (`add` with its `select("#", ...) > 0` branch, `describe` with five defensive `x and x() or default` chains, and the RECURSIVE `dumpRegions` with a region-type filter and a NineSlice recursion guard), plus a long defensive guard stack — every Blizzard/AceGUI accessor is called as `f.GetX and f:GetX() or "?"` because the whole point is to survive a broken widget — plus the bounded parent-chain while loop and two early returns.

**Fix.** Keep `add` as the per-call sink closure (it must capture `out`, and this is a slash-command diagnostic, not a hot path), but hoist everything else to file-locals that take `add` as their first parameter: `local function describeTexture(add, tex, label)` (CCN 5); `local function dumpRegions(add, frame, tag)` — stays recursive, unchanged (CCN 5); `local function reportAceGUI(add)` — the LibStub minor / WidgetVersions / WidgetRegistry block (CCN 5); `local function reportFrame(add, f)` — objectType/shown/size plus the bounded parent-chain loop (CCN 6); `local function reportArt(add, f)` — the three describeTexture calls, dumpRegions(f, "btn") and the font-string block (CCN 4). P:Diagnose then reads: build `out` and `add`, reportAceGUI(add), resolve `btn` with its early return, `add` the type line, resolve `f` with its early return, reportFrame(add, f), reportArt(add, f), return out. CCN ~5.

**Must not change.** The OUTPUT LINES ARE THE PRODUCT — this is read by a human debugging a skinning race, so line order, wording and the format specifiers (%.0fx%.0f for size, %.2f/%.2f/%.2f/%.2f for vertex color, %q for the label) must not drift. It must NEVER raise: every accessor stays guarded (`tex.GetAtlas and tex:GetAtlas()`, `f.GetObjectType and ...`), because it is invoked precisely when the widget is broken. The two early returns are real terminations, not skips: a nil button returns after the "defaultsBtn=NIL" line, a nil frame after "defaultsBtn.frame=NIL". The parent chain stays capped at depth 6. dumpRegions must keep recursing into frame.NineSlice (it is a child FRAME, so it is absent from GetRegions) and must keep filtering to GetObjectType() == "Texture".

**Coverage.** NONE — tests/test_panel.lua never calls P:Diagnose (the Diagnose coverage in tests/test_ledger.lua is Ledger:Diagnose, a different function). Add a characterization test that builds the options panel under wow_mock and asserts P:Diagnose returns a non-empty table, never raises with a missing button, and emits the expected line prefixes — before refactoring.

---

### `I:LayoutSections (lizard: I@559-749 and I@373-760 — two overlapping rows for the same body)` — CCN 28 → target 8

`modules/Insights.lua:594-881` · pattern `layout-pipeline-monolith` · risk **medium**

**What it does.** Lays out the entire Insights pane below the cards: the deposits/withdrawals split bar, then bar charts and direction-split companions for store, character, quality, item type and sub-type; the character x store stacked chart with its legend; the per-day/per-hour strips and the weekday chart; the optional GOLD section; and the whole 'Top Of The List' triptych block of ranked lists.

**Where the branches come from.** A 288-line straight-line builder with ~12 numbered sections, each contributing its own loops, `or {}` defaults, sort comparators and empty-slice guards, plus three nested closures (`paletteRows`, `itemRows`, `countRows`) and the `anyStore` first-time-header flag in the per-store loop. lizard's Lua parser is confused by the nested closures and emits two overlapping nodes (I@373-760 nloc 64 ccn 16 and I@559-749 nloc 102 ccn 28); both resolve to this one function — RenderStrip, RenderList, RenderSubHead, RenderListRow, Layout, placeDivider and RenderDirectionSplit are each individually under 15.

**Fix.** Split by the section boundaries the comments already draw, into file-local builders that take `self` explicitly (keeps the module's public surface unchanged) and return the new `y`: `sectionSplit(self, y, w, innerW, stats, total)` (CCN 3); `sectionStores(self, y, w, stats, total)` (CCN 3); `sectionChars(self, y, w, stats)` returning `y, classOf` (CCN 7 — owns the charRows build and its count-desc/name-asc comparator, hoisted to a module-level `local function byCountThenChar(a, b)`); `sectionCharStore(self, y, w, stats, classOf)` (CCN 5); `sectionQuality(self, y, w, stats)` (CCN 4); `sectionTypes(self, y, w, stats, total)` (CCN 4 — takes today's `paletteRows` closure with it, hoisted to a file-local `local function paletteRows(self, map, poolKey, headerKey, legendKey, y, w, total)`); `sectionTime(self, y, w, stats, totals, dayKeys)` (blocks 10/11/12, CCN 6); `sectionGold(self, y, w, stats, totals, dayKeys)` including the else-branch hides (CCN 8, with its comparator hoisted too); `sectionTopLists(self, y, innerW, stats)` (CCN 8 — `itemRows`, `countRows` and `moves` hoisted to file-locals). LayoutSections then reads as a linear pipeline: placeDivider, the section calls in order, `local dayKeys = W.DayKeys(totals.firstTs, totals.lastTs)` computed once and threaded to sectionTime and sectionGold, `local y, classOf = sectionChars(...)` threading classOf to sectionCharStore and the character direction-split, and `return y - W.SECTION_GAP`. CCN ~2.

**Must not change.** This is pure geometry: the returned `y` must decrease by exactly the same amount at every step or every section below it shifts. Section ORDER is the product (split, store, store-split, char, char-store + legend, char-split, quality, quality-split, type, type-split, subtype, subtype-split, per-day, hour, weekday, [gold], top lists). Two cross-section data dependencies must be threaded, not recomputed: `classOf` (built in the char section, used again by the char x store stack's labelColorOf and the char direction split) and `dayKeys` (used by both the per-day strip and the gold-per-day strip — recomputing is functionally equal but wasteful). The GOLD else-branch must keep hiding dividers.gold, headers.goldDay, headers.goldStore and strips.goldDay, or stale chrome from a previous slice stays on screen. `anyStore` must still emit the "BY STORE" sub-head exactly once and only when at least one store has items. Pool acquisition order determines widget reuse — do not reorder Acquire calls within a section.

**Coverage.** tests/test_insights.lua (drives Layout/LayoutSections under wow_mock and asserts section presence, header shown-state and geometry)

---

### `menu:Populate (lizard: menu@266-353)` — CCN 26 → target 6

`modules/Browser.lua:266-353` · pattern `widget-builder-monolith` · risk **medium**

**What it does.** Rebuilds the shared dropdown menu frame for a given dropdown: measures the widest row, lazily creates/reuses row buttons, sets each row's tick/label/glyph/color from its selection state, wires its OnClick (toggle for multi-select, set-and-close for single), and sizes the menu.

**Where the branches come from.** Four concerns interleaved in one body: (a) the width-measure loop with `dd.multi and CHECK_MARKUP or ""`, `opt.label or ""`, `opt.glyph and 38 or 24`, `math.max/math.min` and a lazy `self.measure` guard; (b) a large `if not b then ... end` widget-construction block; (c) selection resolution — `dd.multi` branch with `(opt.value == "all") and (not next(dd._selected)) or (dd._selected[opt.value] or false)`; (d) row painting with a three-way color chain plus glyph guards; (e) the OnClick closure with its own multi/single branch and two optional-callback guards.

**Fix.** Split into five file-locals above MakeDropdown, each a real unit: `local function menuWidth(menu, dd, opts)` — lazy measure FontString + the measure loop, returns w (CCN ~6); `local function makeMenuRow(menu)` — the whole `if not b then` construction block, returns a new button (CCN ~1); `local function rowSelected(dd, opt)` — the multi/single selection test, returns boolean (CCN ~4); `local function paintMenuRow(b, dd, opt, selected, w)` — width/tick/label anchors/glyph/color (CCN ~6); `local function rowOnClick(menu, dd, opt)` — returns the handler closure (CCN ~4). Populate becomes: hide existing buttons, `local w = menuWidth(self, dd, opts)`, then one loop `local b = self.buttons[i]; if not b then b = makeMenuRow(self); self.buttons[i] = b end; b:ClearAllPoints(); b:SetPoint(...); paintMenuRow(b, dd, opt, rowSelected(dd, opt), w); b:SetScript("OnClick", rowOnClick(menu, dd, opt)); b:Show()`, then `self:SetSize(...)`. CCN ~5. Not a hot path (runs only when a dropdown is opened or a multi-select row is toggled), and the per-row OnClick closure count is unchanged from today.

**Must not change.** Row buttons are POOLED on `menu.buttons` and reused across dropdowns — makeMenuRow must only ever run for an index that has no button, and the reused button must be fully repainted (text, glyph, glyph shown-state, both fs anchors, color) every pass or a stale glyph/color leaks from the previous dropdown. Multi-select keeps the menu open and re-Populates in place; single-select hides it. The "all" sentinel is shown as selected exactly when `dd._selected` is empty. The mono-font glyph FontString and the 22px vs 8px text indent are deliberate (mirrors the Direction column). The 320px width cap and the 90px floor must survive.

**Coverage.** NONE — tests/test_browser.lua substitutes fake dropdown tables (_selected/_value/SetSelected/SelectValue) and never builds the real shared menu. Write a characterization test that drives menu:Populate under wow_mock and asserts row count, size, per-row text (tick markup present/absent) and glyph shown-state before refactoring.

---

### `groupOf (file-local)` — CCN 25 → target 3

`modules/LedgerTable.lua:138-168` · pattern `elseif-dispatch` · risk **low**

**What it does.** Returns the namespaced group key and the display label for one entry under the active group-by mode. The key is prefixed with the mode plus a \001 separator so the collapsed-state map can never collide across modes.

**Where the branches come from.** A textbook eight-arm if/elseif chain (store, direction, kind, type/subtype, quality, char, day, else) where every arm carries its own `or` defaulting — `C.StoreLabel[e.store] or e.store or "Unknown"`, `e.direction or "?"` twice, the `groupBy == "type" and ... or ...` inner ternary, the `label == ""` fixup, and the quality nil branch.

**Fix.** Table-driven dispatch. Add a module-level `local GROUP_OF = { store = function(e) return C.StoreLabel[e.store] or e.store or "Unknown", e.store or "?" end, direction = function(e) ... end, kind = function(e) ... end, type = function(e) return typeGroup(NS.Util.EntryType(e)) end, subtype = function(e) return typeGroup(NS.Util.EntrySubType(e)) end, quality = function(e) ... end, char = function(e) local c = e.char or "Unknown"; return c, c end, day = function(e) return NS.Util.FormatDate(e.ts or 0), date("%Y-%m-%d", e.ts or 0) end }` where each arm returns `label, raw`, plus a shared `local function typeGroup(v) if v == "" then v = "Unknown" end; return v, v end` (CCN 2) that collapses today's type/subtype double-arm. groupOf then reads: `local fn = GROUP_OF[groupBy]; local label, raw; if fn then label, raw = fn(e) else label, raw = "?", "?" end; return groupBy .. "\001" .. raw, label`. CCN 2; the fattest arm (store, quality) is CCN 3. HOT PATH — groupOf runs once per entry inside BuildDisplayList, over a ledger that can be thousands of rows. The dispatch table and its arm closures are built ONCE at file load, so this allocates nothing per call and replaces up to eight string comparisons with one hash lookup: strictly faster than today. Do not build the table inside the function.

**Must not change.** The returned key must stay exactly `groupBy .. "\001" .. raw` — the collapsed-state map in SavedVariables is keyed on it, so any change silently resets every user's collapsed groups. type/subtype must use the EFFECTIVE type (NS.Util.EntryType/EntrySubType) so gold gathers under "Gold", and an empty string becomes "Unknown". Quality keys on the numeric id as a string (so groups sort Poor->Legendary, not alphabetically) and nil quality gets its own "none"/"None" group rather than falling into Poor. The day key stays ISO %Y-%m-%d while the label goes through NS.Util.FormatDate. An unknown mode returns "?"/"?", never nil.

**Coverage.** NONE directly. tests/test_ledgertable.lua exercises group modes indirectly through BuildDisplayList (around lines 172-175 and 220). Add a characterization test asserting the (key, label) pair for all eight modes plus the fallback — including nil quality, empty item type, and nil store/char — BEFORE refactoring.

---

### `L:Reconcile` — CCN 24 → target 6

`modules/Ledger.lua:532-602` · pattern `guard-stack` · risk **medium**

**What it does.** Re-snapshots against the baseline and records what moved for every store the open frame reaches; then decides whether the world is settled (advance the baseline) or a transaction is in flight (hold the baseline and re-arm the settle deadline); finally disarms the guild bank if its window has vanished. Returns the number of entries written.

**Where the branches come from.** Two entry guards; a per-store loop containing two `NS.State.debug and NS.Debug` debug gates, an `if #moves > 0` block and an inner record/skip loop with its own if/else; then a four-level settle-state tree (settled vs held, timeout expired vs re-arm, each with its own debug gate and a math.max/math.min deadline computation); then the guild-bank disarm block with a three-term condition and another debug gate.

**Fix.** Four extractions, three of them file-local, one a method (it needs L's settle state): `local function recordMoves(self, moves)` — the inner loop, returns recorded, skipped (CCN 3); `local function reconcileStore(self, before, after, store)` — storeView/Diff, the Diff debug line, recordMoves, the Move debug line; returns recorded (CCN 5); `local function settleBaseline(self, before, after, totalRecorded, now)` — the whole advance-or-hold tree including the timeout re-anchor and the ScheduleReconcile re-arm (CCN 6); `local function disarmGuildBankIfGone(self, context)` — the trailing block including fireSessionChanged (CCN 5). Reconcile's body becomes: the two guards, `local totalRecorded = 0; for _, store in ipairs(self:StoresFor(context)) do totalRecorded = totalRecorded + reconcileStore(self, before, after, store) end`, `settleBaseline(self, before, after, totalRecorded, (GetTime and GetTime()) or 0)`, `disarmGuildBankIfGone(self, context)`, `return totalRecorded`. CCN ~5. Consider also collapsing the four `NS.State.debug and NS.Debug and NS.Debug(...)` gates into one file-local `local function dbg(tag, fmt, ...)` — that alone removes 8 short-circuits across the file.

**Must not change.** The baseline advance rule is the F-warband fix: NS.State.lastSnapshot advances ONLY when totalRecorded > 0 or SnapshotsDiffer is false. A one-sided change HOLDS the old baseline and re-arms via ScheduleReconcile with the REMAINDER of the window (math.max(SETTLE_MIN_RECHECK_SECONDS, SETTLE_TIMEOUT_SECONDS - elapsed)), not a fixed interval — re-arming on the remainder is what keeps the deadline alive across event-driven rescheduling. `L._settleSince` must be set on first hold and cleared on both settle and timeout re-anchor. The Diff debug line is emitted BEFORE the `#moves > 0` skip, deliberately: a store that found nothing must still say so. Guild-bank disarm requires an EXPLICIT `false` from IsGuildBankVisible (nil means 'this build cannot tell' and must NOT disarm), must clear openContext/lastSnapshot/_settleSince together, and must fire fireSessionChanged(false, context). It must run AFTER the settle logic.

**Coverage.** tests/test_ledger.lua (Reconcile cases: settle/hold, the one-sided-change timeout, baseline advance, and the guild-bank disarm path)

---

### `L.Diff` — CCN 22 → target 6

`modules/Ledger.lua:78-135` · pattern `guard-stack` · risk **low**

**What it does.** The pure heart of the addon: diffs two inventory snapshots for one store and returns the ledger movements. An item movement requires BOTH sides to change in opposite directions, with the quantity being the smaller delta; the money movement follows the same rule against the store's own balance and is emitted last.

**Where the branches come from.** Eight snapshot-field defaults (`before or {}`, `after or {}`, `.bags or {}`, `.store or {}`, `.links or {}` x2, `.storeMoney`), the id-union double loop with its `if not seen[id]` dedupe, four `or 0` deltas plus `linksAfter[id] or linksBefore[id]` per id, the deposit/withdraw if/elseif pair, and the money block's three-term `and` guard followed by a 3-condition test including the sign-XOR `(purseDelta < 0) ~= (storeDelta < 0)` and a `and ... or` direction pick.

**Fix.** Four file-local extractions above L.Diff: `local function snapMaps(s)` — `s = s or {}; return s.bags or {}, s.store or {}, s.links or {}` (CCN 4); `local function unionIDs(maps)` — the seen/ids gather plus table.sort, returns the sorted id array (CCN 4); `local function itemMove(id, bagDelta, storeDelta, store, link)` — the if/elseif pair, returns a move table or nil (CCN 3); `local function moneyMove(before, after, store)` — the entire MONEY_STORES block, returns a move table or nil (CCN 6). L.Diff becomes: `local bagsBefore, storeBefore, linksBefore = snapMaps(before)`, same for after, `local ids = unionIDs({ bagsBefore, bagsAfter, storeBefore, storeAfter })`, one loop computing the two deltas and doing `local m = itemMove(...); if m then moves[#moves + 1] = m end`, then `local mm = moneyMove(before, after, store); if mm then moves[#moves + 1] = mm end`, return moves. CCN ~5. Note moneyMove still needs the raw `before`/`after` (for .money/.storeMoney), so pass those, not the snapMaps outputs.

**Must not change.** DETERMINISM IS ASSERTED BY TESTS BY INDEX: item movements come back in ascending itemID order (unionIDs must keep table.sort) and the money movement, when present, is ALWAYS last. Both halves of a movement must change in opposite directions — a one-sided change is not a movement (this is regression F-001: the purse alone proves nothing, so `L.MONEY_STORES[store] and before.storeMoney and after.storeMoney` must all hold, and a nil storeMoney on EITHER snapshot contributes nothing). Quantity is math.min of the two magnitudes. `link` is passed through from either snapshot (after wins), never derived. No item names and no timestamps are added here — that is BuildEntry's job.

**Coverage.** tests/test_ledger.lua — extensive direct coverage (deposit, withdraw, partial stack, disagreeing sides, bags-only, store-only, identical snapshots, multi-item, ascending-order determinism, and the money/F-001 cases)

---

### `I.CardValues (lizard: I.CardValues@226-250)` — CCN 21 → target 7

`modules/Insights.lua:226-250` · pattern `field-defaulting` · risk **low**

**What it does.** Turns a totals table into the display string for every summary card — counts, signed counts, money, signed money, the top-store label, the date-range span and the busiest day. Pure, so the formatting rules are testable apart from the layout.

**Where the branches come from.** Fourteen `t.x or 0` defaulting expressions in one table constructor, plus `t.firstTs and t.lastTs`, `t.topStore and (C.StoreLabel[...] or t.topStore.store) or EM_DASH` (3 short-circuits) and `t.busiestDay and (...) or EM_DASH`. Almost every point of complexity is a defaulting `or`, not a decision.

**Fix.** Replace the repeated defaulting with two module-level constant maps plus three tiny named helpers. `local COUNT_CARDS = { movements = "entries", itemsIn = "itemsDeposited", itemsOut = "itemsWithdrawn", distinctItems = "distinctItems", chars = "distinctChars", activeDays = "activeDays" }` and `local MONEY_CARDS = { goldIn = "moneyIn", goldOut = "moneyOut" }`. Then file-locals `local function spanText(t)` (firstTs/lastTs → en-dash range or EM_DASH, CCN 3), `local function topStoreText(t)` (CCN 3), `local function busiestText(t)` (CCN 2). CardValues becomes: `local t = totals or {}; local v = {}; for k, f in pairs(COUNT_CARDS) do v[k] = tostring(t[f] or 0) end; for k, f in pairs(MONEY_CARDS) do v[k] = W.Money(t[f] or 0) end; v.netItems = W.SignedCount(t.netItems or 0); v.netGold = W.SignedMoney(t.netMoney or 0); v.itemsMoved = tostring((t.itemsDeposited or 0) + (t.itemsWithdrawn or 0)); v.topStore = topStoreText(t); v.span = spanText(t); v.busiest = busiestText(t); return v`. CCN ~7. Both maps are module-level constants; CardValues runs once per Layout, not per frame.

**Must not change.** Every count card is a STRING (tostring), not a number — the card widget sets text. netItems/netGold go through the SIGNED formatters, goldIn/goldOut through the plain one. Missing/zero values render as "0", never as the em-dash; the em-dash is reserved for topStore/span/busiest when the underlying fact does not exist. The span separator is the en-dash \226\128\147 with a space either side; busiest is "<day>  (<count>)" with two spaces. Returned key set must remain exactly the CARD_DEFS key set — Layout indexes it by def.key and a missing key renders a blank card.

**Coverage.** tests/test_insights.lua (direct I.CardValues cases)

---

### `stubFrame's __index metamethod (lizard: __index@86-165)` — CCN 21 → target 4

`tests/wow_mock.lua:86-165` · pattern `mock-index-dispatch` · risk **medium**

**What it does.** The headless WoW frame stub's property resolver. Serves fourteen recognized frame methods (Show/Hide/SetShown/IsShown/IsVisible, SetScript/GetScript/__fire/HookScript, SetPoint/ClearAllPoints/GetPoint, SetSize/SetWidth/SetHeight/GetWidth/GetHeight, CreateFontString) and falls back to a no-op chainable stub for any other capitalized name.

**Where the branches come from.** Fourteen sequential `if k == "..."` arms in one metamethod, several of which contain their own branches (Hide's shown->hidden OnHide transition, SetShown's if/else, HookScript's OnHide bookkeeping plus the prev-handler chain, GetPoint's nil check, __fire's fn guard), finished by the `type(k) == "string" and k:match("^%u")` catch-all.

**Fix.** Replace the arm chain with ONE module-level table of method FACTORIES, each taking the frame and returning the bound method: `local FRAME_METHODS = { Show = function(f) return function() f.__shown = true; return f end end, Hide = function(f) return function() ... end end, SetShown = ..., IsShown = isShownFactory, IsVisible = isShownFactory, SetScript = ..., GetScript = ..., __fire = ..., HookScript = ..., SetPoint = ..., ClearAllPoints = ..., GetPoint = ..., SetSize = ..., SetWidth = ..., SetHeight = ..., GetWidth = ..., GetHeight = ..., CreateFontString = ... }`. The metamethod becomes: `local factory = FRAME_METHODS[k]; if factory then return factory(f) end; if type(k) == "string" and k:match("^%u") then return function() return f end end; return nil`. CCN 4; the fattest factory (Hide, HookScript) is CCN 3. Note IsShown and IsVisible must reference the SAME factory local, mirroring today's shared arm. Allocation is unchanged (one closure per property access, exactly as now). Do NOT 'optimize' by memoizing the resolved method onto `f` — a test that later replaces a method on the instance would then see different behavior, and several suites poke at these stubs directly.

**Must not change.** This mock underpins every headless suite, so any drift breaks everything at once. Hide() must fire __onHide handlers ONLY on a real shown->hidden transition (the `was` check). SetScript RECORDS the handler (a discarding stub is what made LibKa0s-Options page bodies unreachable from the suite) and __fire replays it. HookScript must both append to __onHide when the script is OnHide AND chain the previous handler before the new one. CreateFontString returns the frame itself but must keep recording the template name into __fontTemplates in creation order (the 'every card shares one headline template' invariant depends on it). The catch-all must fire only AFTER the table lookup (a named method always wins) and only for capitalized string keys — lowercase and non-string keys must still return nil, or every `f.foo` truthiness test in the suites flips.

**Coverage.** NONE directly — wow_mock.lua is test infrastructure with no self-test. It is exercised indirectly by every suite (test_panel.lua, test_sessionwindow.lua, test_insights.lua, test_ledgertable.lua, test_browser.lua). Add a small tests/test_mock.lua characterization suite covering Hide/OnHide transition, HookScript chaining, __fire, GetPoint and the uppercase catch-all before refactoring; running the whole battery green is otherwise the only signal.

---

### `B:CaptureView (lizard: B@777-791)` — CCN 20 → target 6

`modules/Browser.lua:777-791` · pattern `field-defaulting` · risk **low**

**What it does.** Snapshots the browser's on-screen state into a plain view table: the table's group/sort, the five multi-select filter sets (copied, never aliased), the date range and the search text.

**Where the branches come from.** Pure defaulting: three `LT and LT.x or <default>` lines and five `setToFilter(dd and dd.X._selected) or {}` lines plus two more `(dd and ...) or <default>` lines — 10 `and`/`or` short-circuits in a 12-line table constructor.

**Fix.** Add one module-level constant near STOCK_VIEW: `local VIEW_SETS = { { view = "direction", dd = "direction" }, { view = "store", dd = "store" }, { view = "quality", dd = "quality" }, { view = "itemType", dd = "type" }, { view = "itemSubType", dd = "subtype" } }` (an ordered array, so both CaptureView and ApplyView iterate deterministically). Extract `local function tableViewState(LT)` returning `groupBy, sortKey, sortAsc` with today's three defaults (CCN 4). CaptureView becomes: `local dd, LT = self._dd, NS.LedgerTable; local groupBy, sortKey, sortAsc = tableViewState(LT); local v = { groupBy = groupBy, sortKey = sortKey, sortAsc = sortAsc, date = (dd and dd.date._value) or "all", search = (self._search and self._search:GetText()) or "" }; for _, f in ipairs(VIEW_SETS) do v[f.view] = setToFilter(dd and dd[f.dd]._selected) or {} end; return v`. CCN ~6. VIEW_SETS is module-level, so no per-call allocation beyond the view table itself.

**Must not change.** Every set in the returned view must be setToFilter's FRESH table, never an alias of a live dropdown's `_selected` — that aliasing is regression F-013. A nil dropdown bar must still yield a complete, fully defaulted view ({} per set, "all" date, "" search, "none"/"date" table state). `sortAsc` is a strict `== true` normalization, not a truthiness pass-through. With NS.LedgerTable absent, master's `sortAsc = LT and LT.sortAsc == true` evaluates to nil, which leaves the `sortAsc` KEY ABSENT from the returned table — and CaptureView's return is written verbatim to SavedVariables, so `tableViewState` must return nil, not false, in that branch. An absent key and a stored `false` are different facts on disk.

**Coverage.** tests/test_browser.lua (CaptureView cases, incl. the F-013 aliasing regression around line 424)

---

### `W.BuildStackRows` — CCN 19 → target 5

`modules/InsightsWidgets.lua:246-283` · pattern `options-builder` · risk **low**

**What it does.** Builds stacked-bar rows from a { rowKey -> { category -> magnitude } } matrix. Row width is the row's share of the biggest row's total; each segment is that category's share of the same scale. Rows sort total-desc then label-asc.

**Where the branches come from.** Five `opts.x or <default>` lines at the top (one of which allocates a default closure, though only on the fallback path — see the Fix), two full `pairs(matrix or {})` passes each with their own `or {}` default, an inner segment loop carrying `isOther and W.NEUTRAL or (colorOf(s.key) or W.NEUTRAL)` and a second `isOther and "Other" or catLabelOf(s.key)` (4 short-circuits), the `colorOfLabel and colorOfLabel(key) or nil` line, and a per-call sort comparator closure with its own two-key compare.

**Fix.** (a) Hoist only the default color function to module level as `local function neutralColor() return W.NEUTRAL end`, and keep the five `opts.x or <default>` reads as scalar locals. This is a readability move, not a performance one, and it must not be recorded as one: the inline closure sat on the `or` fallback, so it was allocated only when a caller omitted `colorOf`, and the one production call site (`sectionCharStore` in `modules/Insights.lua`) always passes `colorOf` — in the shipping addon it was minted zero times. The other three defaults are `tostring`, already one shared global. A `withDefaults(opts, defaults)` bag was tried and reverted — it trades one closure for one table plus two `pairs` traversals per call, and turns every formatter read into a hash lookup, so it costs more than the line it removed. `labelColorOf` legitimately has no default and is read directly. (b) Extract `local function stackTotals(matrix, catOrder)` returning `totals, rowMax` — the first pass (CCN 3). (c) Extract `local function buildSegments(segs, rowMax, colorOf, catLabelOf, valueFmt)` — the inner segment loop with its __OTHER__ handling (CCN 4). The formatters go in as arguments, not as an options bag: they are read once per segment, so locals keep them upvalue reads. (d) Hoist the sort comparator to a module-level `local function byTotalThenLabel(a, b)` (CCN 3) — also removes a per-call closure allocation. BuildStackRows body then: the five default reads, stackTotals, one `pairs` loop calling W.StackSegments + buildSegments and appending the row, table.sort, return. CCN ~5.

**Must not change.** Both passes call W.StackSegments with the SAME (mags, catOrder), and the second pass must recompute segments rather than cache from the first (StackSegments' __OTHER__ bucketing depends on catOrder). `rowMax` starts at 1, not 0 — that is the divide-by-zero guard and the reason an all-empty matrix yields zero-width rather than NaN segments. The "__OTHER__" sentinel forces both W.NEUTRAL color and the literal tooltip name "Other", bypassing colorOf/catLabelOf. Sort is total-DESC then tostring(label)-ASC; the tostring() in the comparator is what keeps mixed-type keys (numeric quality ids vs strings) from raising. `labelColor` stays nil when labelColorOf is absent — a nil there means 'use the widget default', not white.

**Coverage.** tests/test_insights.lua (BuildStackRows cases). Note what is and is not pinned: the four formatter defaults, falsy overrides included, are pinned and each one fails the suite when broken. The `withDefaults` revert is **not** pinned and cannot be — the bag produced identical output for every input, so no behavioral test can tell the two apart. It was reverted for allocation and lookup cost. The guard against it returning is this paragraph and the comment above `neutralColor`, not a test case; an earlier commit message claimed a test pinned it, and that claim was wrong.

---

### `LT:BuildTestData (lizard: LT@304-468)` — CCN 18 → target 5

`modules/LedgerTable.lua:401-468` · pattern `builder-with-nested-closure` · risk **high**

**What it does.** Generates the synthetic test-mode ledger: a coverage seed pass guaranteeing every store, both directions, all six qualities and every class appear across a >14-day span, a weighted bulk pass of 220 movements, and 30 gold movements at the two coin-holding stores. Deterministic via a fixed-seed Park-Miller LCG.

**Where the branches come from.** Most of it lives in the nested `make` closure: `isGear = (ty == "Armor" or ty == "Weapon")`, the `(rng(100) <= 45) and rng(...) or (...)` hot-item pick, `(store == "GUILD_BANK") and "Ka0s" or nil`, and the nested `quantity = isGear and 1 or ((quality <= 1) and (1 + rng(60)) or (1 + rng(8)))`. Then three loops with their own modulo-cycling arms, `(i % 2 == 0) and DEPOSIT or WITHDRAW` twice, `(rng(10) <= 6)`, `(rng(3) == 1)` and a duplicated char-name/guild/zone block in the gold pass. lizard folds OrderedFilteredEntries and the test-data constants into the same node; BuildTestData alone is the offender.

**Fix.** Hoist `make` out as a file-local `local function makeTestEntry(out, rng, now, store, dir, quality, cls, dayOffset)` (it closes over nothing but out/rng/now, all now parameters), and strip its arithmetic into four one-liner file-locals: `local function testCharName(cls)` (CCN 1), `local function testGuild(store)` (CCN 2), `local function testItemID(rng)` (the 45%-hot pick, CCN 2), `local function testQuantity(rng, isGear, quality)` (CCN 3). makeTestEntry then lands at CCN ~4. Split the three phases into file-locals sharing those helpers: `local function seedCoverage(out, rng, now)` (CCN 3), `local function bulkMovements(out, rng, now)` (CCN 4), `local function goldMovements(out, rng, now)` (CCN 5 — reuses testCharName/testGuild, killing today's duplication). BuildTestData becomes five lines: now, rng, out, the three phase calls, return out. CCN 1.

**Must not change.** THE RNG CALL SEQUENCE IS THE CONTRACT. The dataset is asserted byte-identical run to run, so every extraction must preserve the exact ORDER and COUNT of rng() calls: inside make that is zone -> type -> idBase -> secInto -> quantity, and in the gold pass store -> class -> zone -> ts-day -> ts-seconds -> direction -> quantity. Extracting testQuantity is safe only because it is called at the same point in the stream; do NOT hoist a `local q = testQuantity(...)` above the secInto computation, and do NOT rely on Lua argument evaluation order to sequence two rng-consuming helpers in one call. The seed must stay 0x0BA17ED9 and the LCG must stay Park-Miller (products below 2^46 so double arithmetic is exact on every platform). seedN = math.max(#stores, #TEST_CLASSES, 6, TEST_SPAN_DAYS) guarantees the coverage invariants; the bulk count 220 and gold count 30 are part of the asserted shape. Verify by diffing the full generated table before and after.

**Coverage.** tests/test_ledgertable.lua (BuildTestData coverage-invariant and determinism cases). Before refactoring, dump the generated table to a fixture and assert byte-equality after.

---

### `LT:PaintCell (lizard: LT@503-531)` — CCN 17 → target 4

`modules/LedgerTable.lua:503-531` · pattern `elseif-dispatch` · risk **low**

**What it does.** Paints one table cell: sets its text from the column's valueFn and its color from the shared palette. The single definition of 'what color is this cell', shared by the History table and the session window's slim table. For the direction column it also drives the row's separate glyph FontString.

**Where the branches come from.** A five-arm elseif chain keyed on colKey, each arm carrying its own defaulting: the item/quality arm's money-vs-quality branch, the direction arm's `C.DirectionRGB[...] or C.NEUTRAL_RGB` plus a glyphFS guard plus `glyph or ""` plus `glyph ~= nil`, the store arm's `or C.NEUTRAL_RGB`, the char arm's three-term `RAID_CLASS_COLORS and entry.classFile and RAID_CLASS_COLORS[...]` plus if/else, and the trailing else. Plus the compound entry guard.

**Fix.** Module-level dispatch table of painters, each a file-local `function(fs, entry, glyphFS)`: `local function paintQualityCell(fs, entry)` (money vs quality color, CCN 2); `local function paintDirectionCell(fs, entry, glyphFS)` (rgb default + the glyph block, CCN 4); `local function paintStoreCell(fs, entry)` (CCN 2); `local function paintCharCell(fs, entry)` (CCN 4); then `local CELL_PAINT = { item = paintQualityCell, quality = paintQualityCell, direction = paintDirectionCell, store = paintStoreCell, char = paintCharCell }`. PaintCell becomes: `local col = COLUMN_BY_KEY[colKey]; if not (fs and col and entry) then return end; fs:SetText(col.valueFn(entry)); local paint = CELL_PAINT[colKey]; if paint then paint(fs, entry, glyphFS) else fs:SetTextColor(0.9, 0.9, 0.9) end`. CCN 3. HOT PATH — PaintCell runs once per visible cell per repaint (roughly 7 columns x ~30 visible rows, on every scroll tick and every filter change). CELL_PAINT and its painters are module-level, so this adds zero allocation per call and swaps a five-way string-compare chain for one hash lookup; it is a net win. Never construct the table inside the function.

**Must not change.** `item` and `quality` must share ONE painter (they are the same rule), and a MONEY-kind entry in either column must get MONEY_RGB, not a quality color. The direction painter is the only one that touches glyphFS, and it must set text, color AND shown-state (a stale glyph on a reused pooled row is the failure mode); glyphFS is optional and any other column must ignore it. The store/direction RGB fall back to C.NEUTRAL_RGB, and the char color falls back to (0.9, 0.9, 0.9) when RAID_CLASS_COLORS is absent or classFile is nil — RAID_CLASS_COLORS must stay guarded because it does not exist under the headless mock. Every other column gets the flat 0.9 gray. The text always comes from col.valueFn, and the whole function is a no-op when fs, col or entry is missing.

**Coverage.** tests/test_ledgertable.lua (PaintCell cases across columns, including the money-vs-quality color rule and the direction glyph)

---

### `B:ApplyView (lizard: B@797-840)` — CCN 16 → target 7

`modules/Browser.lua:797-840` · pattern `options-builder` · risk **medium**

**What it does.** Paints a saved view back onto the browser: the table's group/sort, all seven dropdowns, the search box, and the resolved activeFilter, finishing with a single ApplyFilterNow so a view swap costs one query.

**Where the branches come from.** Four defaulting/guard clusters in one body: the `if NS.LedgerTable then` block with three `view.x or default` lines; five asSet() calls plus two more `or` defaults; the `if dd then` block of eight setter calls; the `if self._search` guard; and the activeFilter constructor with `(date ~= "all") and NS.Util.RangeFrom(date) or nil` and `(search ~= "") and search or nil`.

**Fix.** Reuse the same module-level VIEW_SETS array introduced for CaptureView, and split into four file-locals: `local function applyTableState(view)` — the NS.LedgerTable block with its three defaults (CCN 5); `local function viewSets(view)` — `local s = {}; for _, f in ipairs(VIEW_SETS) do s[f.view] = asSet(view[f.view]) end; return s` (CCN 2); `local function paintDropdowns(dd, view, sets, date, chars)` — the whole `if dd then` block, looping VIEW_SETS for the five multi-selects and handling group/date/char explicitly (CCN 3); `local function buildActiveFilter(chars, sets, date, search)` — the activeFilter table (CCN 5). ApplyView becomes seven lines: default the view, compute chars, applyTableState, sets = viewSets, paintDropdowns, SetText, assign self.activeFilter = buildActiveFilter(...), ApplyFilterNow. CCN ~5.

**Must not change.** ORDER IS LOad-BEARING: the search box must be SetText BEFORE activeFilter is rebuilt, because OnTextChanged fires on SetText and writes activeFilter.text itself — swapping them lets the widget clobber the resolved value. Exactly ONE ApplyFilterNow at the end (a view swap is one query, not nine). Character scope is NOT part of the view — it comes from the `scope` argument via defaultCharSelection(). `char` in activeFilter goes through B.ResolveCharFilter(chars). date == "all" means no `from` at all (nil, not 0); search == "" means no `text`.

**Coverage.** tests/test_browser.lua (ApplyView / round-trip capture-then-apply cases, and the stock-view Clear path)

---
