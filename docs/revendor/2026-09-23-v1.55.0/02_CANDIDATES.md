# 02 — Candidates: LibKa0s v1.54.2 -> v1.55.0

Step 5 of `/wow-addon:revendor-libka0s`, run 2026-09-23 as Phase 6 of the 2026-09-22 suite sweep.
The interview (Step 6) is delegated by the owner (CP-6, `Ka0sAddonsCommonTasks/docs/2026-09-22-SUITE_STANDARDS_AND_LIBKA0S_SWEEP/00_PLAN.md:252`,
`:299`), so each candidate below is decided by the CP-6 rules and recorded in `03_DECISIONS.md`.

## Sources read

1. `git -C ../LibKa0s log --oneline v1.54.2..v1.55.0` -> 8 commits (listed in `01_DELTA.md`).
2. `../LibKa0s/CHANGELOG.md` block `## v1.55.0` (`:13`). No existing file's minor moved (`:15-17`),
   so there is no `Since` diff to read for a consumed major; the three new majors are the whole
   library delta.
3. The three API documents, each at its only version: `docs/api/Compat/version-1-docs.md`,
   `docs/api/Bus/version-1-docs.md`, `docs/api/Schema/version-1-docs.md`.
4. The three design specs' per-consumer adoption deltas, which name this repo with `file:line`:
   `3b-specs/compat.md` section 8.8 (`:542-547`), `3b-specs/bus.md` section 12 (`:538-546` common
   block, `:612-619` BankLedger), `3b-specs/schema.md` section 11 (`:465-482` common block,
   `:551-559` BankLedger).
5. This repo's recorded declines: `gh issue list --search "LibKa0s" --state all` (11 issues; none names
   Compat, Bus or Schema) and `docs/ARCHITECTURE.md` `## Documented deviations` (the Perf row only).

## Class A — reached the addon on the re-vendor alone (delivered, not offered)

- **Kit revision 25** (CHANGELOG `:101-391`, adoption steps `:440-467`): the suite inventory keyed by
  (basename, directory), `test_layout_cap`, the `.gitattributes` body case in `test_eol`, and the
  `Commit` / `Tree` cells in the automated-test record. All four were wired or took effect in Phase 5's
  vendor commit `4310368`; nothing further is owed. The prose gate's `Kit.prose.exempt` carve-out is
  unused here (this repo ships no generated data).
- **Nothing in any consumed major**: no existing `.lua` file changed (CHANGELOG `:15-17`).

## Class B — host change required on a consumed major

None. No consumed major moved.

## Class C — whole-module adoption (the three new majors)

Standard v2.64.0 `library-stack-§7` (`standards/standards/library-stack.md:104`) requires none of the
three and permits a host's own copy written before adoption. Each is therefore a choice, and the spec
delta is what CP-6 rule 1 tells this run to adopt.

### C1 — `LibKa0s-Bus-1.0`: `Catalog` over a declared `NS.MSG` table

- **What:** declare the four bus messages once, as `NS.MSG`, through `Bus.Catalog`, and replace every
  `"Ka0s_BankLedger_*"` literal in addon code with the constant.
- **Evidence:** `docs/api/Bus/version-1-docs.md:39-47` (the catalog), `:184-220` (`Catalog`'s checks and
  the strict copy), `:257-313` (worked example and the stub); spec `bus.md:612-619` ("owes the
  declare-once table (debt row 9+13)").
- **Recorded gap it closes:** `architecture-§4` (`standards/standards/architecture.md:93`) is a MUST:
  "declare every message name once as a constant, and use that constant at every `SendMessage` and
  `RegisterMessage` call site -- never the literal." Measured today:
  `grep -rn '"Ka0s_BankLedger_' core modules settings --include='*.lua' | wc -l` -> 25 lines in 9 files.
- **Files:** `core/Constants.lua` (the table's home where there is no `core/Bus.lua`, per
  `architecture-§4`), `core/Database.lua`, `core/Util.lua`, `modules/Browser.lua`,
  `modules/SessionWindow.lua`, `modules/Insights.lua`, `modules/Ledger.lua`, `settings/Schema.lua`,
  `settings/Slash.lua`, `settings/Panel.lua`; `tests/run.lua` (surface source map),
  `tests/test_surface_parity.lua`, a new `tests/test_bus.lua`; `docs/ARCHITECTURE.md` `## Message bus`.
- **Not in scope (spec):** the stand-down record. The untracked factory `core/BankLedger.lua:20-26` and
  the rebuild teardown stay; spec `bus.md:619`.
- **Recommendation:** adopt. It closes a live MUST breach with a mechanical, wire-identical change.
- **Blast radius:** replaces literals the addon owns, but the wire strings do not change, so every
  receiver and every test that names a literal keeps working. Smallest of the three.

### C2 — `LibKa0s-Schema-1.0`: full adopter

- **What:** `settings/Schema.lua` becomes the major's setup file. `lib:New{...}` over the host's rows,
  the host's public names (`S:Set`, `S:Get`, `S:Default`, `S:ApplyDefault`, `S:FindRow`, `S.BulkBegin`,
  `S.BulkEnd`, `S.SameValue`, `S:Register`) bound to instance members, the minimap inversion moved
  onto the row's own `set`, `S:Register` onto `S.Validate`, the head splice onto `AddRows`, and a
  write-completing, log-silent library-absent stub.
- **Evidence:** `docs/api/Schema/version-1-docs.md:115-145` (instance surface), `:146-170` (the `Set`
  pipeline), `:171-187` (bracket), `:201-222` (`Validate`), `:284-359` (the degradation stub),
  `:385-406` (adoption notes); spec `schema.md:551-559` (BankLedger, full adopter) and `:465-482`
  (common block).
- **Files:** `settings/Schema.lua` (the seam body, about `:396-606`), `settings/OptionsSetup.lua:46-49`,
  `settings/Slash.lua:436-453`, `tests/test_schema.lua`, `tests/test_surface_parity.lua`,
  `tests/run.lua`, `docs/ARCHITECTURE.md` `## Settings Schema`.
- **Defects it would close:** both are latent, not live. (a) `settings/OptionsSetup.lua:48`'s
  `applyDefault` bypasses `S.RESET_EXEMPT`; it is reached only from `O.RestoreDefaults` /
  `O.RestoreAllDefaults`, which this addon never calls (`settings/OptionsSetup.lua:93-95`), and the
  Options descriptor carries no bracket, so the veto could not bind there anyway. (b) `S:Register`'s
  `row.default == nil` conjunct (`settings/Schema.lua:600`) hides a row whose default exists but whose
  defaults-table entry does not; measured today it reports 0 either way (`tests/test_schema.lua:12`).
- **Recommendation:** attempt, per CP-6 rule 1. It is the largest of the three and **replaces** code
  the addon owns and ships, so the characterization tests carry the weight; decline "not now" if it
  cannot land without a pinned or player-visible change.
- **Blast radius:** replacement. It deletes the host's walker, bracket, seam and deep copy (about 150
  lines) and adds a host stub of roughly the same size for the degraded path.

### C3 — `LibKa0s-Compat-1.0`

- **What:** replace members of `core/Compat.lua` with the major's readers and secret guards.
- **Evidence:** `docs/api/Compat/version-1-docs.md:43-60` (the nine members: `IsSecret`, `CanAccess`,
  `IsSafeKey`, `GetSpellInfo`, `GetSpellName`, `GetSpellTexture`, `GetSpellCooldown`,
  `GetSpecialization`, `GetSpecializationInfo`), `:280-288` (single-consumer shapes left out); spec
  `compat.md:542-547` ("No member adopted: BankLedger's ... Compat [is] wholly addon-specific
  (section 5.3)") and `:278` (BankLedger's members listed as single-consumer).
- **Measured:** `grep -n '^function' core/Compat.lua` -> 13 members (guild name, money, store money,
  container and guild-bank readers, item resolver), none of which the major carries; and
  `grep -rn 'issecretvalue\|canaccessvalue\|GetSpellInfo\|GetSpecialization' core modules settings`
  returns nothing, so the addon has no call site a Compat member would serve.
- **Recommendation:** decline, "never" -- a structural misfit the spec records.
- **Blast radius:** none; nothing would change.

## Order for Step 6 (CP-6 rule 4)

No candidate fixes a live defect (C2's two are latent, above). C1 closes a recorded gap
(`architecture-§4`, debt row 9+13) and goes first. C2 is new capability, largest blast radius. C3 is a
decline with no code.
