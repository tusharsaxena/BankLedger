# 02 · Deviations — Ka0s Bank Ledger — 2026-08-04

Audited against the **Ka0s WoW Addon Standard v2.17.1 (2026-08-03)**.

**Provenance.** `AUDIT.md`, `standards/STANDARDS.md` and all 24 section files were fetched from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` and verified
byte-identical against the clean local checkout at HEAD `2141229`. No rule in this document is
reconstructed from memory. Details in `01_CURRENT_STATE.md`.

Deviation IDs are stable per-addon (`BL-NN`). `BL-01`…`BL-05` come from the 2026-07-26 run,
`BL-06`…`BL-10` from 2026-07-27; `BL-11`…`BL-24` are new this run. A resolved deviation keeps its ID
and is recorded as closed rather than deleted.

---

## Summary — open this run

| ID | Section | Severity | Status | Summary |
|---|---|---|---|---|
| BL-07 | `savedvariables-§2` | MUST | **Accepted (documented)** | No `defaults/Profile.lua`; all defaults are account-wide in `defaults/Global.lua`. |
| BL-11 | `performance-§1` | MUST | Open (declined) | No `core/PerfSetup.lua`, no `NS.Perf` instance, no descriptor, no declared buckets, no bracket. |
| BL-12 | `toc-file-§2` / `savedvariables-§4` / `performance-§5` | MUST | Open (declined) | Only one SavedVariables global; `BankLedgerPerfDB` is not declared. |
| BL-13 | `slash-commands-§2` / `performance-§4` | MUST | Open (declined) | The reserved `perf` verb is absent from `NS.COMMANDS`. |
| BL-14 | `lint` | MUST | Open (declined) | `.luacheckrc` lacks `debugprofilestop` and `BankLedgerPerfDB`. |
| BL-15 | `documentation-§3` | MUST | Open (declined) | `docs/performance.md` and `docs/perf-runs/README.md` — two of the three required topic-detail docs — are missing. |
| BL-16 | `performance-§9` / `performance-§2` | MUST | Open (declined) | No `tests/perf.lua`, so the zero-overhead scenario that performance-§2 calls "required evidence" does not exist. |
| BL-17 | `performance-§6` | MUST | Open (declined) | No suspend/resume host contract. |
| BL-18 | `events-frames-taint-§8` / `slash-commands-§4` | MUST | Open | `modules/Browser.lua` calls the **global** `print()` at two sites, bypassing the shared secret-safe `[BL]` printer. |
| BL-19 | `standalone-windows-§2` | SHOULD | Open | `B:ApplySkin` restates the normative Ka0s edge values instead of delegating to `Core.ApplySkin`. |
| BL-20 | `documentation-§5` (with the index's referencing rule) | SHOULD | Open | Five malformed and three retired-notation standard references in code/doc comments. |
| BL-21 | `performance-§10` | SHOULD | Open | No `docs/complexity.md` lizard report. |
| BL-23 | `documentation-§4` (adjacent) | MAY | Advisory | `docs/pending/LEDGER.md`'s deferred rows function as a second backlog beside GitHub issues. |
| BL-24 | `layout-§1` | MAY | Advisory | `modules/Browser.lua` at 1306 LOC sits in the 1000–1500 "on notice" band. |

**Counts: MUST 9 · SHOULD 3 · MAY/advisory 2.**

Of the nine MUSTs, **seven (BL-11 … BL-17) are one decision** — the recorded decline of
`LibKa0s-Perf-1.0` — and **one (BL-07) is already accepted and documented**. The genuinely
unrecorded, unambiguous MUST failure this run is **BL-18**.

## Summary — closed since the last run

| ID | Section | Was | Now |
|---|---|---|---|
| BL-01 | `options-ui-§5` / `layout-§3` | MUST | **Resolved** (2026-07-27) — logo ships as `.tga` with sources beside it. |
| BL-02 | `documentation-§1` item 6 | SHOULD | **Resolved** — `README.md:49-71` ships seven captioned screenshots. |
| BL-03 | `toc-file-§1` | MUST (conditional) | **Resolved** — `## X-Curse-Project-ID: 1629058` (`BankLedger.toc:13`) plus the CurseForge version badge (`README.md:4`). |
| BL-04 | `localization-§3` | SHOULD | **Closed — accepted.** `localization-§3`'s MUST is met; the unused `NS.L` seam is a scope decision with its reason written in code (`locales/enUS.lua:8-16`), which is what a SHOULD departure requires. |
| BL-05 | *(process)* | — | **Resolved** (2026-07-27). |
| BL-06 | `options-ui-§1` | MUST | **Resolved** — the library's `CreatePanel` stamps all three (`libs/LibKa0s/Options.lua:219-231`, Options minor 5) and the host correctly parks `defaultsOnClick` instead of setting them (`settings/Panel.lua:52`). |
| BL-08 | `documentation-§3` / `§5` | SHOULD | **Resolved** — `docs/agent-context.md` is gone; `CLAUDE.md:36-51` records why it must never come back (anti-pattern #49). |
| BL-09 | `documentation-§5` / `debug-logging-§2` | SHOULD | **Resolved** — `docs/ARCHITECTURE.md:582-598` now restates the mono-font glyph as a **sanctioned exception**, not a deviation. |
| BL-10 | `slash-commands-§5` | SHOULD | **Resolved** — `CliReset` is now the library's (`settings/Slash.lua:221`), so the echo shares the one `key = value` formatter. |

---

## BL-07 · No `defaults/Profile.lua` — accepted, documented

**Section.** `savedvariables-§2` (with `layout-§1`) · **MUST** · **Status: Accepted (documented).**

**Rule.** *"MUST declare in `defaults/Profile.lua`. MUST be the **only** place a default value is
hardcoded."*

**State.** `defaults/` contains only `Global.lua`. `NS.defaults` carries a `global` table and no
`profile` table (`defaults/Global.lua:6-49`); every schema path resolves against `NS.db.global`
(`settings/Schema.lua:9`, `:194`, `:198`).

**Why it stands.** Bank Ledger is account-wide by construction — you deposit on one character and
withdraw on another — so a per-character profile would split the history the addon exists to join up.
Since the 2026-07-27 run the departure has been **recorded as an accepted deviation** at
`docs/ARCHITECTURE.md:567-580`, naming `savedvariables-§2`/`layout-§1`, the rationale, and why an
empty `Profile.lua` would be worse (it would stand up a second candidate home for a hardcoded
default, weakening the rule's real invariant). That is precisely what `CLAUDE.md:18-19` option (1)
asks for.

**Fix direction.** None in the addon. If the collection wants this closed rather than accepted, the
honest route is upstream: `savedvariables-§2` currently assumes a profile-scoped addon and has no
sanctioned shape for an account-wide one. Propose that it permit `defaults/Global.lua` as the sole
defaults file where the addon declares no profile tree.

---

## BL-11 · `LibKa0s-Perf-1.0` is vendored but not wired

**Section.** `performance-§1` (with `performance-§2`, `performance-§3`) · **MUST** ·
**Status: Open — declined with a written rationale.**

**Rule.** *"MUST vendor `LibKa0s-Perf-1.0` … MUST create one instance per addon at load, from a
descriptor, and stash it on the namespace … In its own core file (`core/PerfSetup.lua`) … MUST
degrade rather than error when the lib is absent."* Adoption strength is explicitly **MUST for the
wiring, SHOULD for coverage**.

**State.** The vendoring half is correct: `libs/LibKa0s/Perf.lua` and `libs/LibKa0s/PerfPanel.lua`
ship as part of the whole folder and are loaded by `libs\LibKa0s\LibKa0s.xml`
(`BankLedger.toc:29`) and by the test runner (`tests/run.lua:38-39`). The wiring half is absent
entirely — there is no `core/PerfSetup.lua` on disk, no `NS.Perf` anywhere in `core/`, `modules/` or
`settings/`, no descriptor, no `buckets` table, and no `Perf.on and debugprofilestop()` bracket.

**Recorded rationale.** `docs/pending/LEDGER.md:65` (LIBKA0S-17, 🔵 wont-do, 2026-08-01): the
harness opens its measurement windows on `UnitAffectingCombat("player")`, while this addon's whole
capture engine is gated on `NS.State.openContext` — set only by a bank or guild-bank frame, an
out-of-combat NPC interaction. The two conditions never overlap, so every declared bucket would read
`0.000` **by construction** — which `performance-§3` itself calls *"a lie in every report"*.

**Why it is still catalogued.** An audit measures against the standard as written. `performance-§1`
is a MUST on the wiring irrespective of what the buckets would read, and the rationale, however
sound, has not been ratified either as an accepted deviation in `docs/ARCHITECTURE.md` ▸ *Documented
deviations* or as a change to the standard. `CLAUDE.md:14-23` requires exactly that classification.

**Fix direction — the user picks one, and it applies to BL-11 … BL-17 as a set.**

1. **Adopt the wiring.** Add `core/PerfSetup.lua` (TOC-positioned before its consumers), a descriptor
   with `Stats` as the first declared bucket — yesterday's review names it as the obvious one
   (`docs/reviews/2026-08-03/02_PROPOSED_CHANGES.md:392-400`) — plus `Reconcile`, and a stub carrying
   every member the addon calls. This pulls BL-12 … BL-17 with it.
2. **Record it as an accepted deviation** in `docs/ARCHITECTURE.md` ▸ *Documented deviations*,
   citing `performance-§1` and the LIBKA0S-17 argument, so the next audit reads it as accepted rather
   than open. This is the low-cost route and matches how BL-07 was settled.
3. **Raise it upstream.** `performance`'s premise is a per-frame / combat-log hot path. An addon whose
   only work happens inside an out-of-combat modal frame has no arm the harness can measure. Propose
   either a non-combat window mode in the library, or a sanctioned N/A in `performance-§1` for addons
   with no combat-reachable code path.

---

## BL-12 · Only one SavedVariables global; `BankLedgerPerfDB` is not declared

**Section.** `toc-file-§2` (with `savedvariables-§4`, `performance-§5`) · **MUST** ·
**Status: Open — follows BL-11.**

**Rule.** *"MUST declare exactly **two** SavedVariables globals in the order above: `<Addon>DB` … and
`<Addon>PerfDB`."*

**State.** `BankLedger.toc:7` reads `## SavedVariables: BankLedgerDB` and nothing else. There is no
`BankLedgerPerfDB` anywhere in the repo.

**Note.** The rest of savedvariables is clean — one AceDB tree, `schemaVersion` from one source
(`core/Namespace.lua:13` → `defaults/Global.lua:14`), a migration runner, and no unsanctioned third
global.

**Fix direction.** With option 1 of BL-11: `## SavedVariables: BankLedgerDB, BankLedgerPerfDB`, and
hand the name to the Perf descriptor. With option 2 or 3: fold into the same accepted-deviation or
upstream record.

---

## BL-13 · The reserved `perf` verb is absent

**Section.** `slash-commands-§2` (with `performance-§4`) · **MUST** · **Status: Open — follows
BL-11.**

**Rule.** *"`help`, `get`, `set`, `list`, `reset`, `resetall`, `config`, `version`, `debug` and
**`perf`** are reserved across the collection and **MUST** mean the same thing in every addon."*
`performance-§4`: *"MUST make a bare `/<slash> perf` the entry point to a run."*

**State.** `NS.COMMANDS` (`settings/Schema.lua:226-286`) carries 15 verbs. All the other reserved
verbs are present; `perf` is not. The README's generated command table (`README.md:80-98`) matches,
so the two are consistent — the verb is simply absent from both.

**Fix direction.** With option 1 of BL-11, add
`{ "perf", "Measure performance — try /bl perf for the workflow", function(rest) … end }` dispatching
to the library's command entry point and printing the returned lines through `NS.Print`; regenerate
the README table in the same change. Otherwise fold into the BL-11 record.

---

## BL-14 · `.luacheckrc` is missing the two perf entries

**Section.** `lint` (with `performance-§2`, `performance-§5`) · **MUST** · **Status: Open — follows
BL-11.**

**Rule.** The house config's `read_globals` includes `debugprofilestop` *"— ms CPU clock behind the
perf brackets"*, and `globals` includes `<Addon>PerfDB` *"— the diagnostics capture ring"*.
`performance-§2` restates the first as a MUST; `performance-§5` restates the second.

**State.** `.luacheckrc:9-30` lists 40+ `read_globals` entries and **not** `debugprofilestop`;
`.luacheckrc:31-36` lists `BankLedgerDB` and `StaticPopupDialogs` and **not** `BankLedgerPerfDB`.
Both are consistent with there being no brackets and no ring today.

**Everything else in `lint` is compliant** — the config exists, excludes `libs/` and `tests/`, and
every `globals` entry carries a justifying comment. `luacheck .` is **0 warnings / 0 errors**.

**Fix direction.** Two lines, added in the same change as BL-11 option 1.

---

## BL-15 · `docs/performance.md` and `docs/perf-runs/README.md` are missing

**Section.** `documentation-§3` (with `performance-§8`) · **MUST** · **Status: Open — follows
BL-11.**

**Rule.** *"**Three** topic-detail docs are **required**, not optional: `docs/test-cases.md`,
`docs/performance.md`, `docs/perf-runs/README.md`."*

**State.** `docs/` holds `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`, `test-cases.md`,
`pending/`, `superpowers/`, `audits/`, `reviews/`. The canonical trio and `test-cases.md` are all
present and current; the other two required topic-detail docs do not exist, and neither does the
`docs/perf-runs/` directory.

**Fix direction.** With BL-11 option 1: `docs/performance.md` naming the bracketed paths and how to
run and read a capture, and `docs/perf-runs/README.md` documenting the naming convention with a
pointer to the library's canonical record contract. Otherwise fold into the BL-11 record.

---

## BL-16 · No `tests/perf.lua`, so the zero-overhead evidence does not exist

**Section.** `performance-§9` (with `performance-§2`, `testing-§7`) · **MUST** · **Status: Open —
follows BL-11.**

**Rule.** *"MUST live at `tests/perf.lua` … MUST ship a **zero-overhead scenario** … This is the
evidence performance-§2 requires; without it, 'free when off' is an unverified claim."*

**State.** `tests/` holds `run.lua`, `wow_mock.lua`, `_kit/` and 18 `test_*.lua` suites. There is no
`perf.lua`. Nothing is mis-counted as a result — the gate's 689 cases are all real test cases and
`testing-§7`'s "measurement runners are not test cases" rule is trivially satisfied.

**Fix direction.** With BL-11 option 1, add `tests/perf.lua` deriving its load list from the TOC per
`testing-§9`, asserting only call counts and bytes allocated, with the zero-overhead scenario over
`Database:Stats`. Keep it out of `tests/run.lua`.

---

## BL-17 · No suspend/resume host contract

**Section.** `performance-§6` · **MUST** · **Status: Open — follows BL-11.**

**Rule.** *"MUST make the addon **inert without a `/reload`** … MUST enforce visibility **at the
source** … MUST restore from **current state** on resume … MUST NOT persist the suspended flag …
MUST resume **before** saving or reporting."*

**State.** No suspend seam exists. `NS.Ledger:Enable()` (`modules/Ledger.lua:761`) is the addon's only
arming path and is not re-entrant, `NS.SessionWindow`'s show-decision ladder has no suspended check,
and `NS.State` (`core/State.lua`) declares no suspend flag. The LIBKA0S-17 note at
`docs/pending/LEDGER.md:65` costs this out explicitly — *"two new Ledger entry points … a carve-out
in the `SessionChanged` sole-sender invariant … an `SW:Enabled()` edit"*.

**Fix direction.** With BL-11 option 1, split `L:Enable` into an idempotent arm/disarm pair, add a
session-only `State.perfSuspended` consulted by `SW:Enabled()` and by the browser's show decision,
and rebuild registrations from current state on resume. Otherwise fold into the BL-11 record.

---

## BL-18 · `modules/Browser.lua` calls the global `print()`

**Section.** `events-frames-taint-§8` (with `slash-commands-§4`) · **MUST** · **Status: Open.**

**Rule.** *"call sites **MUST NOT**: call the global `print()` directly (it neither carries the
`NS.PREFIX` tag nor secret-stringifies its args) … Instead, each file does `local print = NS.Print`."*
And: *"Every line the addon prints to chat **MUST** carry a short bracketed tag."* The section adds
that such a call site is *"non-compliant even if it is never handed a secret today."*

**State.** `modules/Browser.lua` has **no** `local print = NS.Print` declaration — the file's only
occurrences of the identifier are the two call sites themselves:

- `modules/Browser.lua:855` — `print("view saved as your default.")`
- `modules/Browser.lua:864` — `if not silent then print("view reset to stock defaults.") end`

Both therefore resolve the Lua/WoW **global** `print`. Every other file that prints declares the
upvalue on its own line 4–5 (`modules/LedgerTable.lua:5`, `settings/Panel.lua:4`,
`settings/Schema.lua:5`, `settings/Slash.lua:4`, `settings/OptionsSetup.lua:20`).

**Why it matters.** Both lines are user-facing acknowledgements from the filter bar's *Save view* and
*Reset view* buttons, so a user sees two untagged, un-prefixed chat lines from an addon whose every
other line carries `[BL]`. They also sit outside the secret-safe seam. `luacheck` cannot see this —
`print` is a legitimate `lua51` global — and no test covers it, which is why it survived the
2026-08-03 review that raised it as **F-001 (High)**; the review's change-set did not land.

**Fix direction.** Add `local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer
(events-frames-taint-§8)` at the top of `modules/Browser.lua` beside the existing `local C =
NS.Constants`, and extend `tests/test_browser.lua` to assert both lines arrive through the mock's
captured chat sink carrying `NS.PREFIX`. One line of production code; the test is what stops it
regressing.

---

## BL-19 · `B:ApplySkin` restates the Ka0s edge instead of delegating to `Core.ApplySkin`

**Section.** `standalone-windows-§2` · **SHOULD** · **Status: Open.**

**Rule.** *"Where `LibKa0s-Core-1.0` is reachable, `ApplySkin` **SHOULD** be what draws it … A host
helper that skins the addon's own windows is **not** a deviation and is often necessary … it **MUST**
produce exactly the values above, and **SHOULD** delegate to `Core.ApplySkin` rather than restate
them."*

**State.** `modules/Browser.lua:20-33` declares a private `SKIN` table and `:67-89` a private
`B:ApplySkin` that builds the backdrop by hand. The values are **exactly** the normative ones —
bg `0.06, 0.06, 0.08, 0.92`; `WHITE8X8` edge at `edgeSize = 1` inset 1 tinted `0, 0, 0, 1`; a 1px
`BackdropTemplate` child inset one pixel on both axes at `0.24, 0.24, 0.27, 0.85`; title
`1.0, 0.82, 0.0`; divider `0.24, 0.24, 0.27, 0.85`. So the MUST is met and the two-line edge is
correct today. What is missing is the delegation the SHOULD asks for: `Core.SKIN` and
`Core.ApplySkin` are never reached, so the next change to the collection's edge — which the standard
says lands in `standalone-windows` first and `Core.SKIN` second — will not reach this addon's four
windows.

**Note.** The related close-control rule is handled correctly: `B:MakeCloseButton`
(`modules/Browser.lua:93-107`) draws the host's 24×24 class-colored ×, and
`core/DebugLogSetup.lua:111-116` deliberately does **not** pass it to the library's console, which
keeps Core's glyph on the library-drawn windows.

**Fix direction.** Have `B:ApplySkin` resolve `LibStub("LibKa0s-Core-1.0", true)` at call time and,
when present, delegate to `Core.ApplySkin(f)` after assigning `f.title` / `f.divider`, keeping the
current body only as the library-absent branch. Keep `B.SKIN`'s addon-specific fields (`tabActive`,
`tabIdle`, `titleBarH`, `defaultH`, …) — those are genuinely the host's — and drop the five that
restate `Core.SKIN`.

---

## BL-20 · Malformed and retired standard references in comments and docs

**Section.** `documentation-§5` (docs in sync), with `STANDARDS.md`'s referencing rule ·
**SHOULD** · **Status: Open.**

**Rule.** *"Reference a whole section by its **bare filename** … reference a subsection as
`<filename>-§<n>` … This is the **only** cross-reference form — the old global `§N.M` numbering is
retired."*

**State.** Eight references do not resolve.

*Malformed subsection numbers* — `options-ui` has §1–§11:

- `settings/OptionsSetup.lua:43` — `options-ui-§41`
- `settings/Schema.lua:184` — `options-ui-§41`
- `docs/ARCHITECTURE.md:106` — `options-ui-§41`
- `settings/Panel.lua:58` — `options-ui-§190`
- `tests/test_panel.lua:175` — `options-ui-§189`

*Retired global `§N.M` notation:*

- `settings/OptionsSetup.lua:65` — "Ka0s standard §3.4"
- `settings/OptionsSetup.lua:74` — "Ka0s standard §3.1"
- `settings/Panel.lua:11` — "Ka0s standard §3.4"

Every other `filename-§N` reference in the repo resolves correctly (34 distinct forms checked).

**Why it matters.** These comments exist to let the next reader — human or agent — find the rule
being honored. A reference that cannot be looked up sends them to the index to guess, and the retired
form specifically invites a search against a numbering scheme that no longer exists anywhere.

**Fix direction.** The three `options-ui-§41` uses all mean *the single write seam* → `options-ui-§1`.
`options-ui-§190` and `options-ui-§189` both describe panel refresh and re-entrancy → `options-ui-§11`.
The `§3.4` uses (AceGUI resolved once and handed over) → `library-stack-§4`; `§3.1` (AceTimer through
the addon object) → `library-stack-§1`. Sweep with
`grep -rn -E "§[0-9]+\.[0-9]+|-§[0-9]{2,}"` excluding `libs/`, `docs/audits/` and `docs/reviews/`.

---

## BL-21 · No `docs/complexity.md`

**Section.** `performance-§10` (with `documentation-§3`) · **SHOULD** · **Status: Open.**

**Rule.** *"**SHOULD** run `lizard` over the addon's own source, **excluding `libs/`**, and commit the
report as `docs/complexity.md`."* Explicitly report-only and never a gate; *"absent tooling means the
report is stale, not that the addon is non-compliant."*

**State.** No `docs/complexity.md`. This is the one rule where the report would actually be read here:
`modules/Browser.lua` is 1306 LOC (BL-24) and `core/Database.lua:Stats` is a 295-line single-pass
aggregator that yesterday's review deliberately left alone for want of evidence
(`docs/reviews/2026-08-03/05_FINAL_SUMMARY.md:30-35`).

**Fix direction.** `lizard core modules settings defaults locales -x "libs/*" > docs/complexity.md`,
with a header line stating it is generated and how. Independent of BL-11 — this needs no library.

---

## BL-23 · `docs/pending/LEDGER.md`'s deferred rows are a second backlog

**Section.** `documentation-§4` (by extension) · **MAY / advisory** · **Status: Advisory.**

**Rule.** `documentation-§4` bans a `TODO.md` because *"two backlogs drift. A checked-in `TODO.md`
competes with the issue tracker, goes stale, and hides work from anyone not reading the repo."*

**State.** There is no `TODO.md`, so the letter of the rule is met. `docs/pending/LEDGER.md` is a
decision ledger — a record of what has already been asked and answered — which is a legitimate
topic-detail doc under `documentation-§3`. But three of its rows are 🟡 `deferred`, i.e. outstanding
work: `DOC-03` and `DOC-04` correctly carry GitHub issue links (#1, #2), while **`DOC-01` does not** —
it defers the very *"record BL-07 in ARCHITECTURE"* item that has since been done, so the ledger is
now also stale on that row.

**Fix direction.** Not a change to the file's existence. Either give every 🟡 row a tracking issue
link the way `DOC-03`/`DOC-04` have, or re-run `/wow-addon:pending-audit` so `DOC-01` closes against
the work that landed. Flagged so the drift the ban exists to prevent is noticed early.

---

## BL-24 · `modules/Browser.lua` is in the on-notice size band

**Section.** `layout-§1` · **MAY / advisory** · **Status: Advisory.**

**Rule.** *"MUST cap any single `.lua` file at 1500 LOC. Files in the 1000–1500 band are on notice; a
>1500 file is a bug — peel it."*

**State.** `modules/Browser.lua` is **1306** lines. No file exceeds the cap, so no MUST is broken.
Next largest: `modules/LedgerTable.lua` 972, `modules/Insights.lua` 916,
`modules/InsightsWidgets.lua` 832, `tests/test_ledger.lua` 1361 (tests are source too, though the
band is about maintainability rather than lint).

**Fix direction.** No action required now. The natural seam if it grows: the skin/close-button
factory and the geometry persistence (`:20-107`, `:110-180`) peel cleanly into a sibling, and
`layout-§1` explicitly sanctions a 2–3-file peel in the same folder.
