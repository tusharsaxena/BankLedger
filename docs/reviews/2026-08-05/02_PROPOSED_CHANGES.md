# Proposed changes — HLD + LLD, 2026-08-05

Derived from `01_FINDINGS.md`. Standard resolved: **Ka0s WoW Addon Standard v2.21.0 (2026-08-04)**,
fetched from the canonical raw URL and corroborated against `WowAddonStandards@2080a8d`. The
standards cross-check was **performed** — every change below is vetted against it, and each entry
names the rule that shaped it.

**No change in this document targets a path under `libs/` or `tests/_kit/`.** The one item that needs
library code is in the separate upstream change-set at the bottom and lands in the LibKa0s repo.

---

## HLD — themes

### Theme A — make a diagnostic that lies either tell the truth or stop claiming to

*Findings: F-001, F-005, F-002.*

Three defects share one shape: a surface that reports on the system is wrong, and nothing goes red.
`/bl debug panel` prints a LibStub minor it can never read (F-001), the comments around it describe a
library by the wrong name (F-005), and the vendor-sync gate reports green when it did not compare
anything (F-002). Each is invisible to the suite for the same reason — the assertions are on shape,
presence or nothing at all, never on the value.

The rationale for treating them as one theme rather than three tickets is that fixing the value
without fixing the *assertion* leaves the next regression equally invisible. So each change here
pairs a code fix with a case that can actually go red on it.

**Alternative considered and rejected:** deleting `reportAceGUI` entirely, since `/bl debug panel` is
a developer verb. Rejected — `debug-logging-§4` explicitly sanctions structured dump verbs, and this
one is the tool the repo's own comments (`settings/Panel.lua:365-370`) credit with finding the
options-header skinning race (anti-patterns #42). Removing the diagnostic to avoid fixing it is the
wrong direction.

**Trade-off:** C-002 changes the vendor-sync case *names*, which moves two lines in
`docs/test-cases.md`. That regeneration must land in the same commit (`testing-§5`) — see
*Regression pressure* below.

### Theme B — retire surface nothing calls, and stop the comments that vouch for it

*Findings: F-003.*

Six exported members have no production caller. Five carry test cases, so the inventory counts them as
coverage of shipped behavior. Three of the six carry comments asserting a caller that does not exist —
`Database:DeleteAt`'s *"(from the table's right-click menu)"* is flatly false, and it is the one most
likely to send a future author to the wrong function.

The direction is to delete the member **and** its cases together, not to keep the member "because it
is tested". A test over unreachable code is inventory, not coverage. `LT:CellText` is the one
exception: it is a thin, meaningful wrapper over the column model and its *comment* is the defect, so
it is retained with a corrected comment.

**Alternative considered and rejected:** wiring the dead helpers into their apparent call sites (e.g.
routing `L:GateReason` through `F:IsBlacklisted`). Rejected — the gate deliberately reads cached
hot-path upvalues (`modules/Ledger.lua:51-64`), and routing it through a function that re-reads
`NS.db` on every moved item would put an AceDB walk back into the per-item path, which is exactly what
`events-frames-taint-§7` and anti-patterns #43 warn against. The dead helpers are dead because the
faster design replaced them; deleting them records that.

### Theme C — do not do O(n) work to discover there was nothing to do

*Findings: F-004.*

`SW:PruneMissing` walks the whole ledger before checking whether it has anything to prune, and
`Database:PruneOld` broadcasts a change it did not make. Together they make every login pay a
full-ledger walk (plus a repaint, an aggregation and possibly a second walk) for zero rows removed.

Both fixes are guard clauses in the addon's own code. Neither adds an abstraction, a cache or a new
message — `architecture-§4`'s one-sender-per-message invariant is untouched.

**Alternative considered and rejected:** memoizing the presence set across calls. Rejected as a wrong
abstraction for the actual cost profile: the walk is only expensive because it happens when it should
not happen at all, and a cache would add an invalidation problem to a path that currently has none.

**Honesty note carried into every claim:** the addon ships no `tests/perf.lua` and no
`docs/perf-runs/`, so **there is no measured number for this** and none is asserted below. The
before/after evidence named in `03_SMOKE_TESTS.md` is an in-client `collectgarbage("count")` delta, not
a bucket figure, and it is labelled as such.

### Theme D — comments and strings that no longer describe the code

*Findings: F-006, F-007, F-008, F-009.*

Four independent small corrections: a constant addressed on the wrong axis, extraction debris and a
duplicated paragraph, a tooltip that under-describes what its button does, and a carve-out note
listing two of four carve-outs. Grouped because they are all zero-risk text edits in files other
changes already touch, and separating them would serialize tasks for no reason.

---

## LLD — change-set

Each change lists target file(s), the before → after shape where it is non-obvious, risk, and the
finding IDs it closes.

---

### C-001 — Correct the LibStub major in `reportAceGUI`, and assert on it

**Closes:** F-001 (and part of F-005)
**Files:** `settings/Panel.lua`, `tests/test_panel.lua`

**Before** — `settings/Panel.lua:405`:

```lua
local minor = LibStub and LibStub.minors and LibStub.minors["O.AceGUI-3.0"]
```

**After:**

```lua
-- The LibStub MAJOR, not the instance field: `O.AceGUI` is where this addon holds the resolved
-- library, but the registry is keyed on the library's own name.
local minor = LibStub and LibStub.minors and LibStub.minors["AceGUI-3.0"]
```

**Paired test change** — `tests/test_panel.lua:460` currently asserts the line by shape:

```lua
assertTrue(out[1]:find("^AceGUI=") ~= nil, "line 1 names the serving AceGUI: " .. out[1])
```

Add a case that stubs `LibStub.minors["AceGUI-3.0"]` to a known integer and asserts the rendered line
carries it — so the major name is falsifiable. This is an **added** case; the existing shape assertion
stays (it still guards the line's position in the dump).

**Risk:** none to gameplay — the read is inside a diagnostics-only path, already guarded for
`LibStub` and `LibStub.minors` being absent. The new case must not assume a real AceGUI is loaded
headlessly; it sets the registry entry itself and restores it.

**Standards conformance:** keeps the structured dump verb `debug-logging-§4` sanctions, reports the
*serving* instance rather than the vendored one (`library-stack`). Adding a falsifiable assertion is
`testing-§12`; the case carries a `-- red under:` comment naming the mutation (restore the `"O."`
prefix), as `testing-§12` recommends. Rejected alternative — deleting the verb — would have removed a
`debug-logging-§4` surface.

---

### C-002 — Make the vendor-sync skip legible in the case name

**Closes:** F-002 (addon's half; the runner's half is **U-001** below)
**Files:** `tests/test_vendor_sync.lua`

Two edits, neither of which changes a result:

1. **Case names carry the condition.** `"libs/LibKa0s is the LibKa0s release the README says this
   addon bundles"` → `"libs/LibKa0s matches the LibKa0s tag the README names (skipped when
   ../LibKa0s is absent)"`, and the same for the `tests/_kit` case. The inventory then says what it
   means, so a reader of `docs/test-cases.md` can no longer mistake a conditional check for an
   unconditional one (`testing-§5`).
2. **Correct the false comment** at `tests/test_vendor_sync.lua:105-108`, which currently claims the
   condition *"is said in the case name rather than hidden"*. After edit 1 it will be true; until then
   it is a comment vouching for something that is not there.

Additionally, emit one line through the existing print path when the sibling is absent, naming the
path it looked for (`../LibKa0s`) — so a green run is self-explaining in the terminal as well as in
the inventory.

**Explicitly NOT done here:** turning the early return into a hard failure. A consumer clone without
the sibling repo beside it is a legitimate state — this addon is distributed to users, not only to the
author — and reddening the commit gate for it teaches `--no-verify`, which `testing-§4` and
anti-patterns #51 both name as the failure mode a threshold-on-every-commit produces. The honest fix
is a real *skip* status, which is the kit's to provide: see **U-001**.

**Risk:** the pass count is unchanged (726) but two case **names** move, so `docs/test-cases.md`
regenerates. See *Regression pressure*.

**Standards conformance:** `testing-§11`'s *"MUST fail, not pass, when the gate cannot run"* is the
rule this finding is anchored on; C-002 is the compliant partial remedy available inside this repo,
and U-001 is the part that satisfies it fully. `testing-§5` requires the inventory to be honest about
what exists. Never edit `tests/_kit/` (`library-stack-§7`, anti-patterns #47) — C-002 does not.

---

### C-003 — Delete the dead exported members and their cases

**Closes:** F-003
**Files:** `core/Compat.lua`, `core/Database.lua`, `modules/Filters.lua`, `modules/Insights.lua`,
`modules/LedgerTable.lua`, `tests/test_database.lua`, `tests/test_ledger.lua`,
`tests/test_filters.lua`, `tests/test_stats.lua`, `docs/ARCHITECTURE.md`

| Member | Action |
|---|---|
| `Compat.QualityFromLink` + its private `qualityByHex` / `buildQualityByHex` (`core/Compat.lua:172-190`) | **Delete.** No caller, no test. Remove from the Items row of `docs/ARCHITECTURE.md:139` in the same change |
| `Database:DeleteAt` (`core/Database.lua:550-561`) | **Delete**, with its three cases (`tests/test_database.lua:168,176`; `tests/test_ledger.lua:572`). The row menu's real path (`Database:Delete` by identity) is already covered |
| `F:IsBlacklisted` / `F:IsWhitelisted` (`modules/Filters.lua:40-48`) | **Delete**, with their cases in `tests/test_filters.lua` |
| `I.RankRows` / `I.BarFraction` (`modules/Insights.lua:28-58`) | **Delete**, with their cases in `tests/test_stats.lua`. Drop the now-wrong section heading *"Pure ranking helpers (unit-tested)"* at `modules/Insights.lua:26` |
| `LT:CellText` (`modules/LedgerTable.lua:97-102`) | **KEEP.** Fix only the comment: it claims *"the UI binds through the same path"*; the UI binds `col.valueFn` via `LT:Column`. Reword to *"a convenience over the column model; the UI reads `valueFn` off `LT:Column` directly"* |

**Risk:** the deletions are mechanical and grep-verified, but the sweep must be re-run *after* the
edits, because a member removed from one file can be the last caller of another. The pass count drops
by the number of deleted cases — that is the intended outcome, not a regression, and it must be
recorded rather than back-filled with new cases written to hold the number.

**This is the one change that lowers the pass count. It must never be "compensated for".** Writing
replacement cases to keep the badge at 726 would be the inventory-integrity failure `testing-§5` and
`testing-§12` exist to prevent.

**Standards conformance:** deleting unreachable exported surface is straightforwardly compliant;
`public-api` treats the addon-table surface as something to keep small and intentional. The rejected
alternative — routing `L:GateReason` through `F:IsBlacklisted` to "make it live" — would have put an
AceDB read back on the per-item capture path, which anti-patterns #43 and `events-frames-taint-§7`
forbid. **Not** proposed: hand-editing `docs/test-cases.md`; it is regenerated by the runner's
non-executing `--list` mode (`testing-§5`).

---

### C-004 — Two guard clauses: prune nothing cheaply, and do not announce a no-op

**Closes:** F-004
**Files:** `modules/SessionWindow.lua`, `core/Database.lua`

**C-004a** — `modules/SessionWindow.lua:158`:

```lua
function SW:PruneMissing()
  if SW.previewSession then return 0 end
+ -- Nothing to prune, and the presence set below is a walk of the WHOLE ledger plus one table.
+ -- The common case is no bank open at all, which is exactly when LedgerChanged fires most.
+ local entries = self:Entries()
+ if #entries == 0 then return 0 end
  local present = {}
```

**C-004b** — `core/Database.lua:620-636`, `Database:PruneOld`:

```lua
  local removed = #ledger - #kept
  NS.db.global.ledger = kept
- fireLedgerChanged()
+ -- Only when something actually left. A LedgerChanged with nothing behind it costs every consumer
+ -- a repaint, an aggregation and (in SessionWindow) a full-ledger walk — and this runs 5s after
+ -- every login, where the usual answer is zero.
+ if removed > 0 then fireLedgerChanged() end
```

and correct the header comment at `core/Database.lua:619` from *"Fires LedgerChanged when it actually
runs"* to *"Fires LedgerChanged only when it actually removed something"*.

**Risk — the one to watch.** Some consumer might be relying on the unconditional `LedgerChanged` as a
generic "recheck yourself" nudge at login. Grep of the three registrations
(`modules/Browser.lua:1361`, `modules/Insights.lua:1021`, `modules/SessionWindow.lua:658`,
`settings/Panel.lua:165,311`) shows each handler is a pure repaint/re-query of current state, so a
suppressed no-op message changes nothing observable. This must be re-verified before the change lands
and is called out as a checkpoint in `04_EXECUTION_PLAN.md`.

**Test note:** `tests/test_database.lua` should gain a case asserting `PruneOld` with a retention
window that matches nothing emits **no** `LedgerChanged` — and because that is a *negative*
assertion, `testing-§12` requires it carry a `-- red under:` comment naming the mutation that reddens
it (make the fire unconditional again). Without that comment it is exactly the unfalsifiable shape the
rule was written for.

**Standards conformance:** `architecture-§4` — no new sender, no new message, the one-sender-per-message
invariant is untouched. The rejected alternative (memoizing the presence set) would have added
invalidation state to a path that has none, which is a wrong abstraction rather than a fix.

---

### C-005 — Comment, string and naming corrections

**Closes:** F-005, F-006, F-007, F-008, F-009
**Files:** `settings/Panel.lua`, `modules/Ledger.lua`, `settings/Schema.lua`

| Sub | Where | Change |
|---|---|---|
| C-005a | `settings/Panel.lua:11,13,21,23,402` | `O.AceGUI` → `AceGUI` **in prose only**. The identifier `O.AceGUI` is correct everywhere it is code; only the sentences describing the library are wrong |
| C-005b | `modules/Ledger.lua:713,743` | `C.Store.GUILD_BANK` → `C.Context.GUILD_BANK`. Pure rename; the values are equal by design (`core/Constants.lua:37-40`), so no behavior moves |
| C-005c | `settings/Panel.lua:39-42,62-67,78-80,119-120,172-173` | Collapse the blank-line runs to one |
| C-005d | `settings/Panel.lua:469-477` | Delete the duplicated paragraph; move the surviving `P:Refresh` doc comment down to sit directly above `P:Refresh` at `:479`, leaving `P.__pagesForTest` with its own one-line comment |
| C-005e | `settings/Panel.lua:547-549` | Extend the General Defaults tooltip: *"…Your recorded history is never touched. Both windows return to their default position and size."* |
| C-005f | `settings/Schema.lua:124-125` | Extend the carve-out note to all four: `settings.window`, `settings.sessionWindow`, `savedView`, and the blacklist/whitelist id-sets |

**Risk:** C-005b is the only one that touches executable code, and it is a rename between two constants
the standard's own file documents as equal. C-005e changes a user-visible string; there is no
`locales/` entry to move because v1.0.0 routes no string through `NS.L` (`locales/enUS.lua:8-13`) — a
documented scope decision, so this introduces no new localization deviation.

**Standards conformance:** `localization-§5` (US English — the added tooltip clause uses `size`,
`position`, no British forms); `architecture-§5` (C-005f makes the carve-out list complete, which is
what the rule asks the code to be legible about). No new deviation is introduced by any sub-change.

---

## Regression pressure on the test inventory and the badge

`testing-§5` requires `docs/test-cases.md` and the README `[Tests]` badge to move **in the same change**
that moves the count — never as a follow-up.

| Change | Effect on the inventory |
|---|---|
| C-001 | **+1 case** (the falsifiable minor assertion) |
| C-002 | count unchanged; **2 case names change**, so the inventory still regenerates |
| C-003 | **−N cases** (the cases over the deleted members). This is the intended outcome — do not back-fill |
| C-004 | **+1 case** (the negative `PruneOld` assertion, with its `-- red under:` comment) |
| C-005 | none |

Every commit that changes the count or a name must regenerate with
`lua tests/run.lua --list > docs/test-cases.md` and update the badge at `README.md:7` in the same
commit. **Never hand-edit either.**

## Expected movement in the next release's complexity regeneration

Nothing here crosses a threshold in either direction, and today's `lizard` run already shows zero
functions above CCN 15. Two notes for whoever regenerates at release (`/wow-addon:bump-version`), not
tasks to run the tool now:

- C-003 removes whole functions from `core/Compat.lua`, `core/Database.lua`, `modules/Filters.lua`,
  `modules/Insights.lua` — expect small nloc and function-count drops. `modules/Insights.lua` (1023) may
  drop back under `layout-§1`'s 1000-line on-notice threshold, which would retire a band entry.
- C-004a adds one branch to `SW:PruneMissing` (currently well under the cap) — no watch-list movement
  expected.

---

## Upstream change-set (does NOT land in this repo)

### U-001 — `LibKa0s` test kit: a real skip status

**Repo:** the LibKa0s repository (whichever ref this addon's README provenance line names).
**File within the library:** `testkit/framework.lua` (its vendored twin here is `tests/_kit/framework.lua`,
currently `Kit.VERSION = 6`).
**Raised by:** F-002.

**The defect:** the kit has no way for a case to report *"I could not run"*. `Kit` exposes only
`assertEqual`, `assertTrue`, `assertFalse`, `assertNil`, `assertNear`, `assertError`, so a case whose
precondition is absent has exactly two options — assert something false (fail for a reason that is not
a defect) or return quietly (pass while comparing nothing). Every consumer that vendors this kit and
carries a conditional gate inherits the second, which is what `testing-§11` names as worse than no
gate. This addon's `tests/test_vendor_sync.lua` is the instance found here; the rule's own text says
the failure has already shipped once in this collection.

**The fix, additively:** add `Kit.skip(reason)` — records the case as `SKIP` with its reason, counts it
separately from passes and failures, prints it distinctly in the run summary, and renders it in the
`--list` inventory as a conditional case. Additive: no existing case changes behavior, no signature
moves, so every consumer keeps working at the old call sites (`library-stack-§7`'s additive-only rule).

**Then:** bump `testkit/framework.lua`'s revision (`Kit.VERSION` 6 → 7), cut a LibKa0s release,
**re-vendor the whole `testkit/` folder into `tests/_kit/` in every consumer as its own commit**, and
update each consumer's README provenance line in that same commit. This addon's
`tests/test_vendor_sync.lua` will refuse the vendor until the provenance line and the bytes agree,
which is the check working as designed.

**This is explicitly NOT a local edit.** Patching `tests/_kit/framework.lua` here would be reverted by
the next whole-folder copy, and the behavior would come back as a regression with no cause anywhere in
this addon's history — the change that reverted it being a file copy, not a commit anyone will find by
reading the log (`library-stack-§7`, anti-patterns #45 and #47).

**Sequencing:** C-002 does not depend on U-001 and should not wait for it. C-002 makes the current
behavior legible; U-001 makes it correct. When U-001 is vendored, the case names from C-002 can be
simplified because the runner will say `SKIP` itself.
