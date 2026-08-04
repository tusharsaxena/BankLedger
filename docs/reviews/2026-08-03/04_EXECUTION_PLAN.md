# Ka0s Bank Ledger — Execution Plan (2026-08-03)

Implements `02_PROPOSED_CHANGES.md`. Every milestone exits on **green `lua tests/run.lua` + clean
`luacheck .`** (`testing`, anti-pattern #23), and every task is TDD-first where it changes behavior
(anti-pattern #24).

**No upstream milestone.** This review raised no `[upstream]` finding, so nothing here touches
`libs/` or `tests/_kit/` and no re-vendor commit is required.

**Trunk-based.** Work directly on `master`; do not create a branch unless the user asks
(`versioning-git`, anti-pattern #21). Do not push.

---

## Milestone M1 — Seam leaks (the two that matter)

**Done when:** the ledger window's Save/Reset lines carry the cyan `[BL]` tag, the settings panel's
storage line survives a structural re-render, both gates are green, and smoke tests C-001 and C-002
pass in-client.

| Task | Owner-agent role | Implements | Files touched |
| --- | --- | --- | --- |
| **T1.1** Add `local print = NS.Print` to `modules/Browser.lua`; update the file list in `core/CoreSetup.lua`'s seam comment from five files to six | lua-refactorer | C-001 / F-001 | `modules/Browser.lua`, `core/CoreSetup.lua` |
| **T1.2** Test first: extend `tests/test_browser.lua` to assert `SaveView` / `ResetView(false)` emit a line carrying `NS.PREFIX`, using the mock's print capture (mirror the assertion style in `tests/test_libka0s.lua`'s "every printed line still carries the [BL] tag") | test-author | C-001 / F-001 | `tests/test_browser.lua` |
| **T1.3** Re-point the Storage bus handler so it captures no widget (shape (a): `local onChange = function() P:Refresh() end`) | lua-refactorer | C-002 / F-002 | `settings/Panel.lua` |
| **T1.4** Test first: add a case in `tests/test_panel.lua` proving the `LedgerChanged` handler still refreshes after a second render pass — assert it does **not** hold a reference to the first pass's widget (e.g. render twice through the page registry and check the handler updates the second label) | test-author | C-002 / F-002 | `tests/test_panel.lua` |

**Order within M1:** T1.2 before T1.1; T1.4 before T1.3 (red → green).
**Concurrency:** T1.1/T1.2 and T1.3/T1.4 touch **disjoint** files — **parallelizable** as two pairs.

**Checkpoint CP-1 (human).** Before moving on: run smoke tests C-001 and C-002 in-client, plus
regression R-8 (toggle every option) and the C-002 memory spot-check. C-002 is the only change in
the whole set that alters when a refresh runs; confirm the storage line updates on a real deposit
with the panel open.

---

## Milestone M2 — Ledger enum + event correctness

**Done when:** the guild bank arms and disarms exactly as before, a bank-frame close cannot tear
down a guild-bank context, both gates green, smoke tests C-005 and C-006 pass.

| Task | Owner-agent role | Implements | Files touched |
| --- | --- | --- | --- |
| **T2.1** Swap `C.Store.GUILD_BANK` → `C.Context.GUILD_BANK` at `modules/Ledger.lua:672` and `:702` | lua-refactorer | C-005 / F-005 | `modules/Ledger.lua` |
| **T2.2** Test first: add a case to `tests/test_ledger.lua` pinning that `OpenContext` is called with a `C.Context` value and that arming still works if `C.Store.GUILD_BANK` were given a different literal (i.e. the two are no longer interchangeable by accident) | test-author | C-005 / F-005 | `tests/test_ledger.lua` |
| **T2.3** Convert `CLOSE_EVENTS` to an event→context map and guard the handler on the armed context | wow-api-migrator | C-006 / F-006 | `modules/Ledger.lua` |
| **T2.4** Test first: cases for (a) `BANKFRAME_CLOSED` while `openContext == BANK_FRAME` still closes and still fires `SessionChanged(false)`, and (b) `BANKFRAME_CLOSED` while `openContext == GUILD_BANK` is a **no-op** | test-author | C-006 / F-006 | `tests/test_ledger.lua` |

**Concurrency:** T2.1 and T2.3 both edit `modules/Ledger.lua`; T2.2 and T2.4 both edit
`tests/test_ledger.lua`. **Must serialize** — run T2.2 → T2.1 → T2.4 → T2.3.
Also note T2.x edits `modules/Ledger.lua`, which **no** other milestone touches, so M2 as a whole is
parallelizable with M3 and M4 if two agents are available.

**Checkpoint CP-2 (human).** C-006 is the only behavioral change in the set. Run smoke test C-006
part 1 **and** part 2 in-client before continuing — a regression here silently stops the character
bank ending a session, which no headless test can catch as convincingly as a live bank visit.

---

## Milestone M3 — Truthfulness: constants, comments, localization

**Done when:** no comment names a nonexistent file, the LibStub key resolves, the stub carries no
copied library constant, truncation is codepoint-aware, both gates green.

| Task | Owner-agent role | Implements | Files touched |
| --- | --- | --- | --- |
| **T3.1** Restore `LibStub.minors["AceGUI-3.0"]`; sweep the three `O.AceGUI` prose artifacts | lua-refactorer | C-003 / F-003 | `settings/Panel.lua` |
| **T3.2** Test first: add a multi-byte-label case to `tests/test_insights.lua` asserting `W.Truncate` returns valid UTF-8 within budget; then make `W.Truncate` codepoint-aware and rewrite its "English-only" comment | test-author → lua-refactorer | C-004 / F-004 | `tests/test_insights.lua`, `modules/InsightsWidgets.lua` |
| **T3.3** Comment corrections: `test_toc.lua` → `test_libka0s.lua`; `docs/data-model.md` → `docs/ARCHITECTURE.md` | docs-cleanup | C-007 / F-007, F-008 | `core/CoreSetup.lua`, `core/Database.lua` |
| **T3.4** `BUTTON_PAIR_REL = 0.5` → `0` in the degradation stub | lua-refactorer | C-008 / F-009 | `settings/OptionsSetup.lua` |

**Concurrency:** T3.1 touches `settings/Panel.lua`, which **T1.3 also touches** → M3 must not run
T3.1 concurrently with M1's T1.3; sequence M1 before M3, or serialize on that file. T3.2, T3.3 and
T3.4 have disjoint file sets from each other and from T3.1 — **parallelizable**.

**Checkpoint CP-3 (human).** Run smoke test C-008 (rename `libs/LibKa0s` aside, `/reload`, confirm
one honest chat line and zero Lua errors, restore). This is the only exercise of the degraded path
and it is easy to forget.

---

## Milestone M4 — Housekeeping

**Done when:** the one caller-less export is gone, the five test-pinned seams are annotated,
comments and whitespace are tidy, the Export guard is in, the preview flag resets, `PruneOld` is
quiet on a no-op, both gates green.

| Task | Owner-agent role | Implements | Files touched |
| --- | --- | --- | --- |
| **T4.1** Delete `Compat.QualityFromLink` + `qualityByHex` + `buildQualityByHex`; re-grep to confirm zero references | lua-refactorer | C-009 / F-010 | `core/Compat.lua` |
| **T4.2** Annotate the five test-pinned pure seams with a one-line "why this has no in-addon caller" | docs-cleanup | C-009 / F-010 | `modules/Filters.lua`, `modules/LedgerTable.lua`, `modules/Insights.lua`, `settings/Slash.lua` |
| **T4.3** Renumber the `LayoutSections` section comments | docs-cleanup | C-010 / F-011 | `modules/Insights.lua` |
| **T4.4** Collapse the blank runs; delete the duplicated "Test seam over the … registry" paragraph | docs-cleanup | C-011 / F-012 | `settings/Panel.lua` |
| **T4.5** Guard the `NS.Browser:MakeDropdown` reach | lua-refactorer | C-012 / F-013 | `modules/Export.lua` |
| **T4.6** Clear `SW.previewSession` in `EndSession` (+ a `tests/test_sessionwindow.lua` case) | lua-refactorer | C-013 / F-014 | `modules/SessionWindow.lua`, `tests/test_sessionwindow.lua` |
| **T4.7** Gate `fireLedgerChanged()` on `removed > 0` in `PruneOld`; check `tests/test_database.lua` for a case asserting the old behavior and invert it with a note | lua-refactorer | C-014 / F-016 | `core/Database.lua`, `tests/test_database.lua` |

**Concurrency:**
- T4.2 and T4.3 both touch `modules/Insights.lua` → **must serialize** (T4.3 after T4.2, or merge
  them into one pass over the file).
- T4.4 touches `settings/Panel.lua`, also touched by T1.3 and T3.1 → **must serialize after both**.
- T4.1, T4.5, T4.6, T4.7 have pairwise disjoint file sets — **parallelizable**.

**Checkpoint CP-4 (human).** Full regression suite R-1…R-15 plus smoke tests C-009, C-012, C-013,
C-014.

---

## Milestone M5 — Localization pass

**Done when:** the Insights panel renders cleanly on a non-enUS client.

| Task | Owner-agent role | Implements | Files touched |
| --- | --- | --- | --- |
| **T5.1** Run the **Localization sanity** section of `03_SMOKE_TESTS.md` on a deDE (or frFR) client | qa | verifies C-004 / F-004 | none |

**Checkpoint CP-5 (human, final).** Fill in the `03_SMOKE_TESTS.md` sign-off table, then write
`05_FINAL_SUMMARY.md`'s verification section from it.

---

## Critical-path / concurrency map

```
M1 ──► CP-1 ──► M2 ──► CP-2 ─┐
                             ├──► M4 ──► CP-4 ──► M5 ──► CP-5
        M3 ──► CP-3 ─────────┘
```

- **`settings/Panel.lua` is the contended file**: T1.3 (M1), T3.1 (M3) and T4.4 (M4) all edit it.
  Serialize in that order; never run two of them concurrently.
- **`modules/Ledger.lua` is M2-exclusive** — M2 can run in parallel with M3 on a second agent.
- **`modules/Insights.lua`**: T4.2 and T4.3 collide; treat them as one edit.
- **`core/Database.lua`**: T3.3 (comment) and T4.7 (logic) collide; serialize.
- **`core/CoreSetup.lua`**: T1.1 (file list) and T3.3 (test-file name) collide; serialize, or fold
  both edits into T1.1.

## Incremental commit strategy

One commit per task, or one per milestone where a milestone's tasks are a single coherent change.
Commit **only on green** (`versioning-git`; anti-pattern #23). Commit only if the user asks.

Suggested messages:

```
fix(browser): route the view Save/Reset lines through the shared [BL] printer (F-001)
fix(panel): stop the Storage bus handler from holding a released AceGUI widget (F-002)
fix(ledger): close only the context the close event belongs to (F-006)
refactor(ledger): use C.Context where a context is meant, not C.Store (F-005)
fix(insights): truncate on codepoint boundaries, not bytes (F-004)
fix(panel): restore the AceGUI-3.0 LibStub registry key in /bl debug panel (F-003)
docs: correct two comments that named files which do not exist (F-007, F-008)
fix(options): the degraded stub carries no copied library constant (F-009)
chore: drop Compat.QualityFromLink, annotate the test-pinned pure seams (F-010)
chore(panel,insights): tidy leftover whitespace, duplicate comment, section numbering (F-011, F-012)
fix(database): PruneOld broadcasts only when it actually pruned (F-016)
chore(sessionwindow,export): clear previewSession on end; guard the Browser reach (F-013, F-014)
```

No version bump is proposed: none of these changes is user-facing enough to warrant one on its own.
If the maintainer chooses to ship them as `1.0.1`, `versioning-git` and anti-pattern #40 require the
README's `## What's new` heading and the top `## Version History` row to roll forward **in the same
commit** as the `## Version:` bump.
</content>
