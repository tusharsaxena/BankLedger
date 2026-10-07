# 04 · Technical design — Ka0s Bank Ledger — 2026-10-07

Remediation for the four open roots in `02_DEVIATIONS.md`. Nothing here changes what a player sees or
what is stored: one function is restructured with its behavior pinned, one record is written, a few
lines of prose are corrected, and one fix lands upstream in LibKa0s. Info rows are listed at the end with
the change, if any, that would retire them.

---

## BL-52 · Bring `LT.GroupEntries` back to CCN ≤ 15

**Files.** `modules/LedgerTable.lua` (the function at `:320-364`), `tests/test_ledgertable.lua`.

**Shape.** The function partitions sorted entries into groups, orders the groups, then flattens. Its CCN is
dense defaulting plus one comparator, not tangled flow, so the right cut is the comparator, which is also
a per-call closure:

```lua
-- module level, beside GROUP_PREFIX
local function groupLess(a, b)
  if a.sortKey ~= b.sortKey then return a.sortKey < b.sortKey end
  return a.key < b.key
end
local function groupGreater(a, b)
  if a.sortKey ~= b.sortKey then return a.sortKey > b.sortKey end
  return a.key < b.key
end
-- in LT:GroupEntries
table.sort(order, (self.groupAsc ~= false) and groupLess or groupGreater)
```

This removes the `asc` branch and the comparator's own decisions from the function, takes the closure
allocation out of every repaint, and leaves the tie-break (`a.key < b.key`, ascending in both directions)
exactly as it is today. If the sighted suite still reports 16 (lizard may already list the anonymous
comparator separately), the second cut is the partition loop: a named file-local
`partitionByGroup(groupBy, entries)` returning `order` — a block a reader can name, which satisfies
`performance-§11` and not anti-pattern #52.

**Constraints.** No `t.k = stored.k or D.k` over a user value is introduced (#54). No table built inside
the function (#43). The behavior is pinned before the move (`testing-§13`): the seven existing cases
(`docs/test-cases.md:392-398`) cover no-group, headers, labels, collapse, key namespacing, kind and
`typesub`; add one case for **descending** group order with equal `sortKey`s, which is the branch the
refactor rewrites.

**Then record a sighted run.** No bundle has `blindFiles` yet. Before the next `bump-version`, run the
release run (`bash tests/_kit/run-automated-tests.sh --release <v>`) so the manifest carries
`warnings: 0` and `blindFiles: 0`, and fill the watch list's blank dispositions for the two test files
that entered the band.

**Risk.** Low. The table is repainted on every filter change; the change only removes an allocation.

## BL-41 · Record the v1.69.0 – v1.70.0 re-vendors

**Files.** New `docs/revendor/2026-10-07-v1.69.0-v1.70.0/` with `01_DELTA.md` (line 1
`Delta: LibKa0s v1.69.0 -> v1.70.0 (span: v1.69.0 v1.70.0)`, base `v1.68.1` named in the body),
`02_CANDIDATES.md`, `03_DECISIONS.md`, `05_SUMMARY.md` — the same set `2026-10-04-v1.68.1/` carries.

**Content.** What arrived: `WidgetsLineChart.lua` (`LineChart`, `LINE_CHART`, `ChartMath`; one consumer
upstream, under LibKa0s's own ratified row) and `WidgetsAutocomplete.lua` (`Autocomplete`,
`AUTOCOMPLETE`); kit 37. What this addon adopted: `Autocomplete` under the search box
(`e5cd620`, `B:MakeAutocomplete`). What it declined and why: `LineChart` against `modules/InsightsWidgets.lua`'s
own chart primitives — a decision for the owner, written down either way. No code change.

**Check.** Re-run the E-04 loop; `UNRECORDED:` prints nothing.

## BL-53 · The inventory's Totals counts passes, not the registry (upstream)

**Where.** `LibKa0s/testkit/framework.lua`, `renderTotals` (vendored here at `tests/_kit/framework.lua:557-569`).

**Shape.** Count the declared skips while rendering (`t.skip ~= nil`), emit `| **Total** | **<n - skips>** |`
and, when skips exist, one more row `| Skipped (declared) | <skips> |`; keep each suite's row as it is. The
kit's `--list` already knows which cases are declared skips (`Kit.test(name, fn, skipReason)`,
`framework.lua:189-190`), so no case body runs. The kit's own suite gains a case: a registry with one
declared skip renders Total = registered − 1.

**In this repo.** Nothing until the fix ships. Then re-vendor (this owes its own re-vendor bundle,
`BL-41`'s convention), `lua tests/run.lua --list > docs/test-cases.md`, and confirm Total = 1258 =
the badge's numerator and denominator.

**Ordering.** File the upstream issue on `tusharsaxena/LibKa0s` first; every addon carrying a declared skip
has the same disagreement, so the change is collection-wide and belongs in one release.

## BL-45 · One documentation sync pass

| Site | Change |
|---|---|
| `docs/ARCHITECTURE.md:460` | Refresh to 1427, or drop the figure and keep only *"Nothing is over the cap today"* plus the command — the gate checks membership, so a dated number is a second thing to keep current. Dropping it is the more durable fix. |
| `core/Constants.lua:235` | `See docs/media.md ▸ Logo art.` |
| `docs/smoke-tests.md:113` | `(media.md ▸ Logo art)`. Smoke results are the owner's; this edits the step's pointer only, no result. |
| `modules/LedgerTable.lua:28-30` | Replace *"That is an accepted, documented deviation … See docs/ARCHITECTURE.md ▸ Documented deviations."* with a sentence citing `debug-logging-§2`'s second sanctioned use (a glyph the default font lacks). No register row. |

The code edits are comments only; `luacheck .` and `lua tests/run.lua` stay green. `tests/test_docs.lua`
does not check either pointer, so the sweep is verified by grep: `grep -rn 'ARCHITECTURE[^ ]* ▸ Logo art'`
returns nothing outside frozen stores.

## Info rows — optional, with the next touch

- **BL-51.** `modules/Browser.lua:901,915` — `print(lastTab, "view saved as your default.")` and the reset
  twin; `settings/Slash.lua:111,253,339` and `core/DebugLogSetup.lua:51` likewise pass the value as its own
  printer argument. A SHOULD NOT outside the trigger set; do it when each file is next edited, not as its
  own change.
- **BL-24.** `modules/Browser.lua` at 1427. The disposition already names the peel seam (skin/close
  factory and geometry persistence into a sibling file); schedule it before the next feature adds to the
  window. A peel moves `B:MakeCloseButton`, so the `standalone-windows` register row's condition (3) text
  must be re-read in the same change.
- **Hub length.** Moving `## Profiles`' body into `docs/profiles.md` (leaving a summary and one link)
  brings `docs/ARCHITECTURE.md` to roughly 445 lines; the *Launcher* and *stand-down* sections would carry
  the rest. Not owed.
