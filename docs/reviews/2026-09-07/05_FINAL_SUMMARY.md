# Final summary — Ka0s Bank Ledger — 2026-09-07

> **Status: written ahead of implementation.** This document is the "what shipped" record for the
> cycle planned in `02_PROPOSED_CHANGES.md` and `04_EXECUTION_PLAN.md`, drafted on the assumption
> that every check in `03_SMOKE_TESTS.md` passes. Fill in the bracketed measurements and the
> sign-off pointer when the work lands; do not publish it with the placeholders intact.

---

## Headline

This cycle fixed two ways the addon could quietly stop doing its job, and neither of them announced
itself. First: resetting every setting from the settings panel left the recording engine running on
the settings you had *before* the reset — so a player who had capture switched off, reset to
defaults, and went to the bank recorded nothing, while the panel cheerfully showed capture as on.
Second: the addon's database-upgrade step could be skipped entirely, because the version number it
reads to decide whether to upgrade was declared in a place the Ace database library is allowed to
delete. Nothing is broken by that today, but every future upgrade of the stored format was
pre-disarmed by it. Alongside those, a disable/re-enable of the addon at runtime left it permanently
deaf, a test that was supposed to catch the second bug turned out to be unable to fail, and three
documents had drifted away from the code they describe.

Everything else the review looked at came back clean: no taint, no protected-API leakage, no
deprecated API, no `OnUpdate`, no chat output escaping the `[BL]` prefix, and a set of
library-degradation tests that genuinely load the addon with the library removed rather than
pretending to.

---

## Counts

`Critical fixed: 0, High fixed: 3, Medium fixed: 3, Low fixed: 4`

- **High:** `BANKLEDGER-R-01`, `BANKLEDGER-R-02`, `BANKLEDGER-R-03`.
- **Medium:** `BANKLEDGER-R-04`, `BANKLEDGER-R-06`; `BANKLEDGER-R-05` is **addressed by
  regeneration at release**, not by an edit in this cycle.
- **Low:** `BANKLEDGER-R-07`, `BANKLEDGER-R-08`, `BANKLEDGER-R-10`; `BANKLEDGER-R-09` lands
  **upstream in LibKa0s**, not here.

**Deferred, with reasons:**

| ID | Why deferred |
|---|---|
| `BANKLEDGER-R-05` | `docs/automated-tests/RESULTS.md` is generated. Its checkpoint is release — `/wow-addon:bump-version` regenerates the table and the narrative sections from a fresh run. Hand-editing 727 → 831 would make a measured document read as measured while being typed (`performance-§10`). |
| `BANKLEDGER-R-11` | `tests/test_ledger.lua` (1478) and `modules/Insights.lua` (992) are near `layout-§1` boundaries but over none. Splitting pre-emptively relocates decisions without removing any. Re-check at the next release run. |
| `BANKLEDGER-R-09` | Correct fix is in the LibKa0s repo. No LibStub minor bump and, expected, no re-vendor here — the file contents are byte-identical. |

---

## Changes by theme

### Theme A — a reset is a settings change, and must be announced like one

**What changed.** The confirm-gated "Reset all settings" button now tells the rest of the addon that
the settings moved. Before, it emptied and rebuilt the stored data silently, and the recording
engine — which caches the capture rules in fast local variables so it does not have to read the
database once per moved item — went on using the values and the *table objects* that the reset had
just thrown away. Capture state, quality threshold, muted stores and both item-id filter lists were
all affected, for the rest of the session, until any unrelated setting was changed or the UI
reloaded.

**Why it mattered.** The reset is the control a confused user reaches for, and it was the one
control that left the addon in a state the settings panel described incorrectly. It is also
impossible to report: a reload "fixes" it.

- **Finding IDs:** `BANKLEDGER-R-01`
- **Change IDs:** `C-1`
- **Files touched:** `settings/Slash.lua`, `tests/test_panel.lua`, `docs/test-cases.md`, `README.md`

The fix is one broadcast on the message bus the per-setting writes already use, not a list of things
to refresh — deliberately, because this function was rewritten once already to get *away* from an
enumeration that failed a release later when something new was stored beside the things it named.

### Theme B — the database version stamp stops being a default

**What changed.** The stored-format version number moved out of the declared defaults and is now
seeded by the upgrade runner itself, which also distinguishes a brand-new install (nothing to
upgrade) from a database written before the stamp existed (upgrade it).

**Why it mattered.** AceDB deletes any stored value that equals its declared default when you log
out. Declaring the version stamp as a default therefore guaranteed that the stamp would be missing
from the saved file, and that on the next launch the runner would read the *new* default and
conclude there was nothing to do. The v1→v2 pass was already affected. More importantly, so was
every future one — a migration seam that cannot run is worse than no seam, because it looks like
one.

- **Finding IDs:** `BANKLEDGER-R-02`
- **Change IDs:** `C-2`
- **Files touched:** `defaults/Global.lua`, `core/Database.lua`, `tests/test_database.lua`,
  `docs/test-cases.md`, `README.md`

### Theme B′ — the harness can now see that failure

**What changed.** The addon's test mock stopped replacing the shared test kit's Ace-database fake
with a simpler one and now wraps it, pinning only the single per-addon fact it needed (a fixed
profile name).

**Why it mattered.** The replacement was a plain table with none of the real library's default
behaviour, so the case named *"a database with no schemaVersion key at all is treated as v1"* passed
regardless of whether the shipped code was correct. It read as coverage and provided none — which is
strictly worse than an absent test, because an absent test leaves a visible gap. This is the direct
reason Theme B's defect reached a release under a green gate.

- **Finding IDs:** `BANKLEDGER-R-03`
- **Change IDs:** `C-3`
- **Files touched:** `tests/wow_mock.lua`, and whichever suites the faithful fake exposed

### Theme C — a latch that is never cleared is not a lifecycle

**What changed.** The addon gained an `OnDisable` that clears the three "already enabled" latches on
the capture engine and the two windows.

**Why it mattered.** Ace unregisters every event when an addon is disabled, but the latches survived,
so a subsequent enable returned immediately and the eight bank events were never re-registered. The
addon silently recorded nothing until the next reload. Only reachable by a third-party addon manager
or a `/run` call, which is why it is Medium and not High.

- **Finding IDs:** `BANKLEDGER-R-04`
- **Change IDs:** `C-4`
- **Files touched:** `core/BankLedger.lua`, `tests/test_ledger.lua`, `docs/test-cases.md`,
  `README.md`

### Theme D — the standing evidence catches up with the code

**What changed.** `docs/performance.md`'s sweep table — the evidence behind this addon's ratified
"no combat-path work" exemption — now points at `core/ItemSetup.lua`, where the deferred item-load
timer actually lives, rather than at `core/Compat.lua`, which it left when the LibKa0s item seam was
adopted.

**Why it mattered.** That page instructs its reader to re-run its own grep and says the exemption is
over the moment a row appears it cannot explain. A row pointing at a file that no longer holds the
call site makes the instruction unfollowable.

- **Finding IDs:** `BANKLEDGER-R-06`
- **Change IDs:** `C-5`
- **Files touched:** `docs/performance.md`

### Theme E — comments and guards that overstate themselves

**What changed.** Two precision fixes: the `/bl test` verb no longer prints a confirmation for a
toggle that did not happen, and the options-setup stub's note about `MasterControls` no longer claims
the degraded path reaches a member it cannot reach.

**Why it mattered.** Small, but these are files whose comments carry load-order and contract
information the next reader is expected to trust. A wrong sentence in one of them costs a
re-derivation.

- **Finding IDs:** `BANKLEDGER-R-07`, `BANKLEDGER-R-10`
- **Change IDs:** `C-6`
- **Files touched:** `settings/Schema.lua`, `settings/OptionsSetup.lua`, `tests/test_slash.lua`

### Theme F — repository hygiene

**What changed.** Four files whose working-tree line endings disagreed with the repo's CRLF pin were
renormalised in an isolated commit.

- **Finding IDs:** `BANKLEDGER-R-08`
- **Change IDs:** `C-7`
- **Files touched:** `tests/test_marks.lua`, `docs/media.md`,
  `docs/revendor/2026-08-25/01_DELTA.md`, `docs/revendor/2026-08-25/05_SUMMARY.md`

---

## API / behavior changes

Externally observable:

- **Settings ▸ General ▸ Master controls ▸ Reset all settings** now takes effect immediately in the
  recording engine and both windows, with no `/reload`. Its blast radius is **unchanged** — still
  wholesale, still confirm-gated, still distinct from `/bl resetall`. The ratified `options-ui-§12`
  deviation row in `docs/ARCHITECTURE.md` is untouched and still accurate.
- **`/bl test`** now reports "unavailable" rather than "off" when the ledger table module cannot be
  reached. No shipping configuration reaches that branch.
- **No** new, renamed or removed slash verbs. `NS.COMMANDS` and the README command table are
  unchanged and remain in agreement.
- **No** new or renamed locale keys — v1.0.0 still routes no user-facing string through `NS.L`, per
  the scope decision recorded in `locales/enUS.lua`.
- **No** new or removed schema rows, and no new defaults, other than the removal described below.

## Saved-variable / migration notes

- **`schemaVersion` is no longer a declared default.** Old shape: `NS.defaults.global.schemaVersion
  = NS.SCHEMA_VERSION`, read back by `NS:RunMigrations` via `g.schemaVersion or 1`. New shape: the
  key is absent from the defaults, and `NS:RunMigrations` seeds it when it is `nil` —
  `NS.SCHEMA_VERSION` if the ledger is empty (a fresh install has nothing to migrate),
  `1` otherwise (a pre-stamp database).
- **`SCHEMA_VERSION` itself does not change**; this cycle ships schema **v2**, as before.
- **Existing profiles auto-migrate.** A user whose stamp was stripped by an earlier logout and whose
  ledger holds entries is now correctly read as v1 and taken through the v1→v2 pass on the next
  login, which removes the residual `vendorPrice` field. No `/bl resetall` and no `/bl purge` is
  required, and no history is touched.
- **A fresh install is stamped at the current version** and does not replay v1→v2 over an empty
  ledger.
- Verified in-client by `03_SMOKE_TESTS.md` **T-3** and **T-4** — the only checks in the set that
  exercise AceDB's real `PLAYER_LOGOUT` default-strip, which no headless harness can reproduce.

## Deprecated-API migrations

**None.** The review found no deprecated or removed API anywhere in the addon's own code: every
legacy call is already behind `core/Compat.lua` on its modern `C_*` form
(`C_Container.GetContainerNumSlots`, `C_Container.GetContainerItemInfo`, `C_Item.GetItemInfo`), and
the settings panel reaches Blizzard's Settings system through `LibKa0s-Options-1.0` rather than the
removed `InterfaceOptions_AddCategory`. No table needed.

## Performance impact

**Omitted — no perf-tagged changes.** This addon holds a ratified `performance-§12` no-combat-path
exemption (`docs/ARCHITECTURE.md` ▸ Documented deviations, evidenced by `docs/performance.md`), ships
no `tests/perf.lua` and no `docs/perf-analysis/` bundles, and none of the changes above touches a
combat-path code site. The one bus broadcast added by `C-1` fires on a button click, not on any hot
path. `03_SMOKE_TESTS.md` **P-1** confirms the reset does not retain the discarded tables; that is a
leak check, not a cost measurement, and no number from it belongs here.

## Test and complexity movement

- **Pass count before:** `831 / 831` (measured 2026-09-07, `lua5.1 tests/run.lua`; matches the
  committed `docs/test-cases.md` and the README `[Tests]` badge exactly).
- **Pass count after:** `[fill in]`. Expected to rise by roughly six: two for `C-1`, three for
  `C-2`, one for `C-4`, plus whatever `C-3` and `C-6` add or adjust.
- `docs/test-cases.md` and the README `[Tests]` badge moved in the **same commits** as the changes
  that moved the count (commits 2, 5 and 6 of `04_EXECUTION_PLAN.md`), regenerated with
  `lua5.1 tests/run.lua --list`, never hand-edited (`testing-§7`).
- **Complexity, measured 2026-09-07:** 14174 NLOC, 2153 functions, avg CCN 2.0, **0 warnings**,
  highest CCN **15** on four functions — `I@505-551@modules/Insights.lua`,
  `accumulateItemTaxonomy@234-265@core/Database.lua`, `L@403-435@modules/Ledger.lua`,
  `LT@869-885@modules/LedgerTable.lua`.
- **Expected movement for the next release regeneration to confirm:** none of those four is touched
  by this cycle. `C-1` and `C-4` add short, low-CCN bodies in `settings/Slash.lua` and
  `core/BankLedger.lua`; `C-2` adds one branch to `NS:RunMigrations` (currently CCN well under the
  cap). **No function is expected to reach 15 that was not already there.**
- **`docs/automated-tests/RESULTS.md` will move on its own** at the next release run, which closes
  `BANKLEDGER-R-05` — its narrative sections currently quote 727 cases and name five CCN-15
  functions including `ensureFrame`, which now measures 13. That is a regeneration, not an edit.

## Known follow-ups

| Item | Why it is not in this cycle |
|---|---|
| `BANKLEDGER-R-05` — regenerate `docs/automated-tests/RESULTS.md` | Generated artifact; its checkpoint is release, via `/wow-addon:bump-version`. A hand-edit would read as measured. |
| `BANKLEDGER-R-11` — `tests/test_ledger.lua` at 1478 LOC, `modules/Insights.lua` at 992 | Neither is over a `layout-§1` threshold. Re-check at the next release run; the split seam for the test suite is already named in the watch list's disposition. |
| `BANKLEDGER-R-09` — LibKa0s working-tree line endings | Upstream, in the LibKa0s repo. No content change, no minor bump, expected no re-vendor here. |
| Possible LibKa0s testkit gap | If the kit's AceDB fake does not model the `PLAYER_LOGOUT` default strip, that is an additive upstream improvement plus a `tests/_kit/` re-vendor across all consumers — never a local re-fork of the fake. Recorded during `M2-T2`. |
| `options-ui-§12`: three reset routes over two implementations | Pre-existing, ratified deviation in `docs/ARCHITECTURE.md`. This cycle does not widen it and does not close it; closing it is its own piece of work with its own cost note already recorded. |

## Verification evidence

- Manual sign-off: `docs/reviews/2026-09-07/03_SMOKE_TESTS.md`, sign-off table completed.
- Commit range / PR: `[fill in]`.
- Headless evidence at review time: `01_FINDINGS.md` ▸ Measurement run — luacheck 0/0 over 28 files,
  831/831 tests, inventory identical to the committed copy, `lizard` 0 warnings, vendor-sync gate
  green against the sibling checkout.

---

## Suggested commit message / PR description

```
fix(reset,savedvariables): the reset re-arms capture, the migration seam re-arms itself

Two defects that both fail silently, plus the test that should have caught
the second one and could not.

BANKLEDGER-R-01: Sl:ResetEverything wiped and rebuilt db.global without
sending Ka0s_BankLedger_SettingsChanged, so the Ledger's hot-path upvalues
kept the pre-reset scalars AND kept aliasing the filter-list tables the wipe
discarded. Settings > General > Master controls > Reset all settings left the
capture gate reading the old settings for the rest of the session while the
panel showed the new ones. One broadcast on the bus the per-row writes
already use -- not an enumeration, which is the shape this function was
rewritten away from.

BANKLEDGER-R-02: schemaVersion was declared in NS.defaults.global. AceDB's
PLAYER_LOGOUT handler strips any stored value equal to its default, so the
stamp vanished from the saved file and the next launch read the NEW default
and skipped the upgrade. The v1->v2 pass was affected; every future migration
was pre-disarmed. The stamp now leaves the defaults and NS:RunMigrations
seeds it, using the ledger's emptiness to tell a fresh install from a
pre-stamp database.

BANKLEDGER-R-03: tests/test_database.lua's stamp-less-database case passed
only because tests/wow_mock.lua replaced the kit's AceDB fake with a plain
deepcopy that has no defaults metatable. Wrapped instead of replaced, pinning
only the fixed profile name -- the same rule the AceGUI override already
states.

BANKLEDGER-R-04: no OnDisable, so the _enabled latches survived an AceAddon
disable while AceEvent unregistered every bank event. Re-enable was a no-op
and the addon went permanently deaf.

Also: BANKLEDGER-R-06 (docs/performance.md's exemption sweep follows LoadItem
to core/ItemSetup.lua), BANKLEDGER-R-07 and -R-10 (two guards/comments that
overstated themselves), BANKLEDGER-R-08 (four line-ending stragglers,
isolated commit).

Not here: BANKLEDGER-R-05 (RESULTS.md is regenerated at release, never
hand-edited) and BANKLEDGER-R-09 (LibKa0s working-tree line endings -- fix
upstream, no minor bump, no re-vendor expected).

Review bundle: docs/reviews/2026-09-07/
```
