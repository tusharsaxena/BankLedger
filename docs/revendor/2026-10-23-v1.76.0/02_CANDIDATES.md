# Candidates (BankLedger)

Sources: the `CHANGELOG.md` v1.76.0 block at the tag and the API documents
`docs/api/Sim/version-2.3.5-docs.md` and `docs/api/Widgets/version-14.1.4.3.2-docs.md`. The
adoptions are pre-decided by the run's owner scope
(`Ka0sAddonsCommonTasks/docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/inputs/OWNER_SCOPE.md`), so there is
no interview and no `03_DECISIONS.md` here, and no issue is filed. Each is a later item on the same
branch.

## Class A: delivered on the copy

- Sim 2.3.5: a typed `/bl sim start` (and the picker's START, the idle Start row, `restart`) plays
  the simulation at once at the `settings.sim.stepDelay` pace; a manual step or a click on a row
  holds the run; the panel's controls are Pause/Resume, Restart and Stop.
- `docs/releasing.md` step 5 at the tag (the preview and simulation re-look) is the library's half
  of standard v2.87.0's release rule; nothing for the addon to adopt in code.

## Class B: host change, accepted

| Candidate | Evidence | Touches | Item |
|---|---|---|---|
| Sim auto-run wording and typed-start suite cases | CHANGELOG v1.76.0 *SimTimeline minor 3 and SimPanel minor 5*; Sim 2.3.5 document | `settings/Schema.lua:114-124`, `core/Constants.lua:171`, `defaults/Profile.lua:68`, README and docs; `tests/test_sim_panel.lua` | BL-01 |
| `W.TestStrip(parent, { kind = "sim" })` (Widgets 14) | CHANGELOG v1.76.0 *Widgets minor 14*; Widgets 14.1.4.3.2 document | `modules/Browser.lua` (a sim strip beside the test strip), `modules/SessionWindow.lua` (its strip becomes kind sim) | BL-10 |

## Class C: declined

None.
