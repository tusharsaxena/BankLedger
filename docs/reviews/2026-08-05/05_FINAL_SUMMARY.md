# Final summary — 2026-08-05 review cycle

> **Written ahead of implementation.** This document assumes every change in
> `02_PROPOSED_CHANGES.md` landed and every check in `03_SMOKE_TESTS.md` passed. Fields marked
> **`<fill at completion>`** are the ones that can only be known once the work is done — fill them,
> do not estimate them.

## Headline

This cycle fixed a diagnostic that had been quietly lying, made a gate admit when it could not run,
deleted six pieces of addon surface that nothing called, and stopped the addon doing a full-ledger
walk at every login to discover there was nothing to do. Nothing a user asked for changed, and that is
the point: every item here is something that looked correct — a green test, a printed diagnostic line,
a tidy helper with unit coverage — while being wrong or inert. The addon that comes out the other side
is the same addon, with less surface, fewer lies in its comments, and two fewer places where "it's
green" meant nothing.

## Counts

- **Critical fixed: 0** (none were found)
- **High fixed: 2** — F-001, F-002
- **Medium fixed: 3** — F-003, F-004, F-005
- **Low fixed: 4** — F-006, F-007, F-008, F-009

**Deliberately deferred / routed elsewhere:**

- **U-001** (the shared test kit's missing skip status) is **upstream in the LibKa0s repo**, not here.
  F-002's local half (C-002) shipped; its correct half needs a kit change, a minor bump and a
  re-vendor commit. Tracked as milestone M0 in `04_EXECUTION_PLAN.md`. Deferred because it is
  cross-repo work that must not block a correct local improvement.
- **`tests/perf.lua` and `docs/perf-runs/`** remain absent. That is a pre-existing compliance matter
  already tracked as `BL-15`/`BL-16` in `docs/audits/2026-08-04/02_DEVIATIONS.md`, not a finding of
  this review — but it is why F-004 carries no measured number, and why the perf section below cites
  a GC delta rather than a bucket figure.
- **`modules/Browser.lua` (1368 LOC)** stays in `layout-§1`'s on-notice band. Already tracked as
  `BL-24` with its peel seam named; out of scope for a review cycle whose theme was correctness of
  inert surface, not a structural split.

## Changes by theme

### Theme A — make a diagnostic that lies either tell the truth or stop claiming to

**What changed.** `/bl debug panel` now reports the real AceGUI-3.0 LibStub minor instead of `nil`, and
`tests/test_panel.lua` gained a case that asserts the value rather than the line's shape. The two
vendor-sync cases now carry their precondition in their names, so `docs/test-cases.md` no longer
presents a conditional check as an unconditional one, and a quiet run names the path it looked for.

**Why it mattered.** The dump verb's whole job is to say *which* AceGUI copy served the widget when
several addons are loaded — the exact question that made the options-header skinning race
(anti-patterns #42) diagnosable. It had not been able to answer it since a rename swept a string
literal, and the one case over that line was matching by shape, so nothing went red. The vendor-sync
gate had the same disease one level up: `testing-§11` says a gate that goes quiet when it cannot look
is worse than no gate, and this one did, while a comment in the same file asserted it did not.

**Findings covered:** F-001, F-002, F-005 (partly). **Changes implemented:** C-001, C-002, C-005a.

**Files touched:**
- `settings/Panel.lua`
- `tests/test_panel.lua`
- `tests/test_vendor_sync.lua`
- `docs/test-cases.md`, `README.md` (badge)

### Theme B — retire surface nothing calls, and stop the comments that vouch for it

**What changed.** Six exported members with zero production callers were deleted along with the cases
that "covered" them: `Compat.QualityFromLink`, `Database:DeleteAt`, `Filters:IsBlacklisted`,
`Filters:IsWhitelisted`, `Insights.RankRows`, `Insights.BarFraction`. `LedgerTable:CellText` was kept
and its comment corrected. `docs/ARCHITECTURE.md` no longer lists a removed function as live API.

**Why it mattered.** Three of those members carried comments naming a caller that did not exist —
`Database:DeleteAt`'s *"(from the table's right-click menu)"* most damagingly, since the row menu
actually deletes by identity through `Database:Delete`. A future author reading that comment would
have changed the wrong function. The cases over them counted toward the badge while exercising code no
user path reaches, so the inventory was overstating coverage of shipped behavior.

**Findings covered:** F-003. **Changes implemented:** C-003.

**Files touched:**
- `core/Compat.lua`
- `core/Database.lua`
- `modules/Filters.lua`
- `modules/Insights.lua`
- `modules/LedgerTable.lua` (comment only)
- `tests/test_database.lua`, `tests/test_ledger.lua`, `tests/test_filters.lua`, `tests/test_stats.lua`
- `docs/ARCHITECTURE.md`, `docs/test-cases.md`, `README.md` (badge)

### Theme C — do not do O(n) work to discover there was nothing to do

**What changed.** `SessionWindow:PruneMissing` returns immediately when there are no session rows,
instead of first building a presence set over the entire ledger. `Database:PruneOld` broadcasts
`LedgerChanged` only when it actually removed something, and its header comment now says so.

**Why it mattered.** `PruneOld` runs five seconds after every `PLAYER_ENTERING_WORLD`. For the common
case — a user whose history is all inside the retention window — it removed zero rows and still
announced a change, which cost a full-ledger walk in the session window, a browser repaint, an
Insights re-aggregation, and (with the panel open) a second full-ledger walk for the storage estimate.
Every login paid for it, for nothing.

**Findings covered:** F-004. **Changes implemented:** C-004a, C-004b.

**Files touched:**
- `modules/SessionWindow.lua`
- `core/Database.lua`
- `tests/test_database.lua`
- `docs/test-cases.md`, `README.md` (badge)

### Theme D — comments and strings that no longer describe the code

**What changed.** The guild-bank frame context is addressed with `C.Context.GUILD_BANK` at both sites
that used `C.Store.GUILD_BANK`; five prose comments in `settings/Panel.lua` name AceGUI rather than
`O.AceGUI`; extraction debris and a duplicated doc paragraph were cleaned up; the General page's
Defaults tooltip now says it also resets both windows' position and size; the schema carve-out note
lists all four carve-outs instead of two.

**Why it mattered.** None of these was a bug the user could hit, but each one misdirects the next
person reading the file — and the carve-out note in particular is the thing a maintainer checks before
asking "may I write this key directly?" The tooltip was the one user-facing item: a player who had
carefully placed the ledger window had no warning that "Defaults" would move it.

**Findings covered:** F-005, F-006, F-007, F-008, F-009. **Changes implemented:** C-005a–f.

**Files touched:**
- `modules/Ledger.lua`
- `settings/Panel.lua`
- `settings/Schema.lua`

## API / behavior changes

| Change | Detail |
|---|---|
| Removed addon-table surface | `NS.Compat.QualityFromLink`, `NS.Database:DeleteAt`, `NS.Filters:IsBlacklisted`, `NS.Filters:IsWhitelisted`, `NS.Insights.RankRows`, `NS.Insights.BarFraction`. None was called by the addon; none is a documented public API |
| `/bl debug panel` output | First line now carries a real integer minor instead of `nil`. Line order, count and format specifiers are unchanged |
| Settings ▸ General ▸ Defaults tooltip | Gained one sentence: both windows return to their default position and size. Behavior unchanged — the string now describes what already happened |
| `Ka0s_BankLedger_LedgerChanged` | No longer emitted by `Database:PruneOld` when zero rows were removed. Message name, arguments and sender are unchanged (`architecture-§4`'s one-sender invariant intact) |
| Slash grammar | **No change.** All 15 verbs and both `debug` sub-verbs behave exactly as before |
| Locale keys | **None added or renamed.** v1.0.0 routes no user-facing string through `NS.L` by documented scope decision (`locales/enUS.lua:8-13`), so the new tooltip clause is hardcoded English like its neighbors |

## Saved-variable / migration notes

**No schema bump. No migration.** `NS.SCHEMA_VERSION` stays at **2**, `defaults/Global.lua` is
unchanged, and nothing in this cycle reads, writes or reshapes a persisted key. Existing profiles need
no action and `/bl reset` is not required. The one deleted function that touched persisted data —
`Database:DeleteAt` — was never reachable from any UI, so no stored row was ever created or destroyed
through it.

## Deprecated-API migrations

**None.** The sweep found no deprecated or removed API in the addon's own code: every varying API is
already behind `core/Compat.lua` with a presence check, container reads are `C_Container.*`, item reads
are `C_Item.GetItemInfo` (return positions verified correct), metadata is `C_AddOns.GetAddOnMetadata`
with a fallback, and all 13 `SetBackdrop` call sites target `BackdropTemplate` frames. This section is
retained deliberately, empty, so a future reviewer knows the sweep was done rather than skipped.

## Performance impact

**No measured before/after numbers exist for this cycle, and none are asserted.** The addon ships no
`tests/perf.lua` and no `docs/perf-runs/`, so there is no offline scenario and no committed capture to
cite; `docs/automated-tests/RESULTS.md` records `perf: skip` as a permanent state with its deviation
IDs. What C-004 removes is provable by reading — a full-ledger walk and a four-consumer repaint cascade
on a path where nothing changed — not by a bucket figure.

The only evidence collected is the coarse in-client GC delta from `03_SMOKE_TESTS.md` **C-004-4**:

| Measurement | Value |
|---|---|
| `collectgarbage("count")` 10 s post-login, pre-change, ledger of `<fill: N>` entries | `<fill at completion>` kB |
| Same, post-change | `<fill at completion>` kB |
| Record | `03_SMOKE_TESTS.md` sign-off row C-004-4 |

Read it as an interpretation, not a measurement of the change: a GC snapshot cannot isolate this path.
Adding `tests/perf.lua` scenarios — which would make a real claim possible here — remains `BL-16`.

## Test and complexity movement

| | Before | After |
|---|---|---|
| Pass count | **726** (verified fresh on 2026-08-05: `726 passed, 0 failed, 726 total`) | `<fill at completion>` |
| `docs/test-cases.md` | current — byte-identical to a fresh `--list` | regenerated in the same commits that moved the count/names |
| README `[Tests]` badge | 726/726 | moved with the inventory, same commit |
| `lizard` warnings (CCN > 15) | **0** (fresh run, 1946 functions, nloc 12788, avg CCN 2.1, peak 15) | expected 0 |

**Net case delta:** +1 (C-001) +1 (C-004) −N (C-003, the cases over the deleted members) =
`<fill at completion>`. **The count going down is the intended outcome of C-003** and must not be
back-filled with replacement cases to hold the badge at 726.

**Complexity entries these changes are expected to move** — for the *next release's* regeneration to
confirm (`/wow-addon:bump-version`), never regenerated as part of this work:

- C-003 removes whole functions from four files; `modules/Insights.lua` (1023 LOC) may drop back under
  `layout-§1`'s 1000-line on-notice threshold, retiring a band entry in `RESULTS.md`.
- C-004a adds one branch to `SW:PruneMissing`, which sits well under the cap. No watch-list movement
  expected.
- The four functions at CCN 15 — `ensureFrame`, `accumulateItemTaxonomy`, `LT:UpdateHeaderArrows`,
  `I:Layout` — are untouched by this cycle and stay at 15.

## Known follow-ups

| Item | Why it was left |
|---|---|
| **U-001** — `Kit.skip(reason)` in the LibKa0s test kit | Cross-repo. Needs a kit change, a `Kit.VERSION` bump, a release and a re-vendor commit in every consumer. C-002 makes the current behavior legible in the meantime; U-001 is what makes it correct |
| **`tests/perf.lua` + `docs/perf-runs/`** (`BL-15`, `BL-16`) | Pre-existing compliance work, not a review finding. Until it exists, no perf claim about this addon can cite a number — including this cycle's |
| **`modules/Browser.lua` split** (`BL-24`) | 1368 LOC, on notice, seam already named (skin/close-button factory and geometry persistence into a sibling file). A structural change deserves its own cycle, not a ride-along on a correctness pass |
| **Localization** | No string routes through `NS.L` at v1.0.0 — a documented scope decision, and the seam is in place. Wrapping strings is a deliberate future pass, not a defect |

## Verification evidence

- **Smoke tests:** `docs/reviews/2026-08-05/03_SMOKE_TESTS.md`, sign-off table completed —
  `<fill at completion: date, tester, all rows Pass>`
- **Headless gate at completion:** `luacheck .` → `<fill>`; `lua tests/run.lua` → `<fill>`
- **Commit range / PR:** `<fill at completion>`
- **Findings this summary closes:** `docs/reviews/2026-08-05/01_FINDINGS.md` F-001 … F-009
- **Upstream work:** U-001, in the LibKa0s repo — `<fill: tag and commit>`

## Suggested commit message / PR description

```
Review 2026-08-05: fix a lying diagnostic, a gate that passes when blind,
and work done to discover there was nothing to do

Nine findings from docs/reviews/2026-08-05/. No Critical. No schema change,
no migration, no slash-grammar change.

High
  F-001  /bl debug panel read LibStub.minors["O.AceGUI-3.0"] — never a real
         major — so it reported minor=nil forever, defeating the one question
         the verb exists to answer. The case over that line asserted its shape,
         not its value, so nothing went red. Fixed and made falsifiable.
  F-002  tests/test_vendor_sync.lua returned early and PASSED when the sibling
         LibKa0s checkout was absent, and a comment in the same file claimed
         the condition was in the case name. It was not. Case names now carry
         it; a real skip status is upstream work (U-001, LibKa0s repo).

Medium
  F-003  Six exported members had zero production callers; five carried test
         cases and three carried comments naming a caller that did not exist.
         Deleted, with their cases. The pass count drops on purpose.
  F-004  PruneOld announced a change it had not made, five seconds after every
         login, and PruneMissing walked the whole ledger before checking it had
         anything to prune. Two guard clauses.
  F-005  A rename swept five prose comments into nonsense — the visible trail
         of F-001's cause.

Low
  F-006  Guild-bank context addressed with C.Store instead of C.Context.
  F-007  Extraction debris and a doc paragraph written twice in Panel.lua.
  F-008  The Defaults tooltip did not mention that it also moves both windows.
  F-009  The schema carve-out note listed two of four carve-outs.

Measured fresh on 2026-08-05 before any change: luacheck 0/0 over 24 files,
726/726 tests, lizard 0 functions over CCN 15 (peak 15), and every committed
artifact — test-cases.md, RESULTS.md, complexity.txt, the tests badge — in
exact agreement with the fresh run. No perf numbers are claimed: this addon
ships no tests/perf.lua (BL-16).

docs/test-cases.md and the README [Tests] badge move in the same commits that
move the count.
```
