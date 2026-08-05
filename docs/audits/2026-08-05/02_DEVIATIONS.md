# 02 · Deviations — Ka0s Bank Ledger — 2026-08-05

Audited against the **Ka0s WoW Addon Standard v2.21.0 (2026-08-04)**.

Deviation IDs are stable per-addon (`BL-NN`). `BL-01`…`BL-05` come from the 2026-07-26 run,
`BL-06`…`BL-10` from 2026-07-27, `BL-11`…`BL-24` from 2026-08-04. **`BL-25`…`BL-27` are new this
run.** A resolved deviation keeps its ID and is recorded as closed rather than deleted.

---

## Summary — open this run

| ID | Section | Severity | Status | Summary |
|---|---|---|---|---|
| BL-07 | `savedvariables-§2` | MUST | **Accepted (documented)** | No `defaults/Profile.lua`; all defaults are account-wide in `defaults/Global.lua`. |
| BL-11 | `performance-§1` | MUST | Open (declined, unratified) | No `core/PerfSetup.lua`, no `NS.Perf` instance, no descriptor, no declared buckets, no bracket. |
| BL-12 | `toc-file-§2` / `savedvariables-§4` / `performance-§5` | MUST | Open (follows BL-11) | Only one SavedVariables global; `BankLedgerPerfDB` is not declared. |
| BL-13 | `slash-commands-§2` / `performance-§4` | MUST | Open (follows BL-11) | The reserved `perf` verb is absent from `NS.COMMANDS`. |
| BL-14 | `lint` | MUST | Open (follows BL-11) | `.luacheckrc` lacks `debugprofilestop` and `BankLedgerPerfDB`. |
| BL-15 | `documentation-§3` | MUST | Open (follows BL-11) | `docs/performance.md` and `docs/perf-runs/README.md` — two of the **five** required topic-detail docs — are missing. |
| BL-16 | `performance-§9` / `performance-§2` | MUST | Open (follows BL-11) | No `tests/perf.lua`, so the zero-overhead scenario `performance-§2` calls "required evidence" does not exist. |
| BL-17 | `performance-§6` | MUST | Open (follows BL-11) | No suspend/resume host contract. |
| BL-18 | `events-frames-taint-§8` / `slash-commands-§4` | MUST | Open (**second run**) | `modules/Browser.lua` calls the **global** `print()` at two sites, bypassing the shared secret-safe `[BL]` printer. |
| **BL-25** | `automated-tests-§3` (*The release gate*) / `documentation-§5` | MUST | **New** | The addon's docs state only the never-gates half of the rule; the v2.21.0 **release gate** (all four suites `pass` + `complexity.warnings == 0` at the tag, and a `skip` is not a pass) is stated nowhere. |
| **BL-27** | `testing-§12` (with `testing-§11`) | MUST | **New** | Both vendor-sync cases `return` and **PASS** when the sibling `../LibKa0s` checkout is absent — a gate that goes quiet when it cannot look. |
| BL-19 | `standalone-windows-§2` | SHOULD | Open | `B:ApplySkin` restates the normative Ka0s edge values instead of delegating to `Core.ApplySkin`. |
| BL-20 | `documentation-§5` (with the index's referencing rule) | SHOULD | Open | Nine malformed / retired-notation standard references in code and doc comments. |
| **BL-26** | `automated-tests-§2` | SHOULD | **New** | `tests/_kit/run-automated-tests.sh` is committed with git mode `100644` — not executable on a fresh checkout. |
| BL-23 | `documentation-§4` (adjacent) | MAY | Advisory | `docs/pending/LEDGER.md`'s `DOC-01` row is still 🟡 deferred with no tracking issue, and is stale. |
| BL-24 | `layout-§1` | MAY | Advisory | Four files now sit in the 1000–1500 on-notice band; none exceeds the 1500 cap. |

**Counts: MUST 11 (10 open, 1 accepted) · SHOULD 3 · MAY/advisory 2.**

Of the ten open MUSTs, **seven (BL-11 … BL-17) are one unratified decision** — the decline of
`LibKa0s-Perf-1.0`. The three that stand on their own are **BL-18** (a second run un-remediated),
**BL-25** and **BL-27**.

## Summary — closed since the last run

| ID | Section | Was | Now |
|---|---|---|---|
| BL-21 | `performance-§10` | SHOULD | **Closed — superseded.** `docs/complexity.md` was **retired** in standard v2.19.0 (`automated-tests-§7`). Its absence is now the compliant state; the report's raw output lives in each bundle's `complexity.txt` and its trend line in `docs/automated-tests/RESULTS.md`, both present, and `docs/testing.md:104-106` records the retirement explicitly. Re-raising this would be a false positive. |

`BL-01`…`BL-06`, `BL-08`…`BL-10` remain closed as recorded on 2026-08-04. `BL-22` was never issued.

---

## BL-07 · No `defaults/Profile.lua` — accepted, documented

**Section.** `savedvariables-§2` (with `layout-§1`) · **MUST** · **Status: Accepted (documented).**

**Rule.** *"MUST declare in `defaults/Profile.lua`. MUST be the **only** place a default value is
hardcoded."*

**State.** Unchanged. `defaults/` holds only `Global.lua`; `NS.defaults` carries a `global` table and
no `profile` table (`defaults/Global.lua:6-49`). The departure is recorded, with its rationale and
with the reason an empty `Profile.lua` would be worse, at `docs/ARCHITECTURE.md:568-581` — which is
exactly what `CLAUDE.md:18-19` option (1) asks for.

**Fix direction.** None in the addon. If the collection wants it closed rather than accepted, the
route is upstream: propose that `savedvariables-§2` permit `defaults/Global.lua` as the sole defaults
file where the addon declares no profile tree.

---

## BL-11 · `LibKa0s-Perf-1.0` is vendored but not wired

**Section.** `performance-§1` (with `performance-§2`, `performance-§3`) · **MUST** ·
**Status: Open — declined, and the decline is still unratified.**

**Rule.** *"MUST create one instance per addon at load, from a descriptor, and stash it on the
namespace … In its own core file (`core/PerfSetup.lua`) … MUST degrade rather than error when the lib
is absent."* Adoption strength is explicitly **MUST for the wiring, SHOULD for coverage**.

**State.** The vendoring half is correct and stays correct: `libs/LibKa0s/Perf.lua` and
`PerfPanel.lua` ship as part of the whole folder (`BankLedger.toc:29`, `tests/run.lua:38-39`) — that
is the ship-payload rule, not adoption. The wiring half is absent: no `core/PerfSetup.lua` on disk,
no `NS.Perf` anywhere under `core/`, `modules/` or `settings/`, no descriptor, no `buckets`, no
bracket.

**Recorded rationale.** `docs/pending/LEDGER.md:65` (LIBKA0S-17, 🔵 wont-do, 2026-08-01): the
harness opens its measurement windows on `UnitAffectingCombat("player")`, while this addon's capture
engine is gated on `NS.State.openContext` — set only by a bank or guild-bank frame, an
out-of-combat NPC interaction. The two never overlap, so every declared bucket would read `0.000`,
which `performance-§3` itself calls *"a lie in every report"*.

**Why it is still catalogued.** The rationale is sound and it is **still not ratified**. It sits in a
pending ledger, not in `docs/ARCHITECTURE.md` ▸ *Documented deviations*, which today carries BL-07
alone. `CLAUDE.md:14-23` requires that classification. This is the third audit to say so.

**Fix direction — one decision, applying to BL-11 … BL-17 as a set.**

1. **Adopt the wiring.** `core/PerfSetup.lua` TOC-positioned before its consumers, a descriptor with
   `Stats` and `Reconcile` as declared buckets, and a stub carrying every member the addon calls.
   Pulls BL-12 … BL-17 with it.
2. **Record it as an accepted deviation** in `docs/ARCHITECTURE.md` ▸ *Documented deviations*, citing
   `performance-§1` and the LIBKA0S-17 argument, so the next audit reads it as accepted. Low cost,
   and it is how BL-07 was settled. **This is the recommended route.**
3. **Raise it upstream.** Propose either a non-combat window mode in the library, or a sanctioned
   N/A in `performance-§1` for an addon with no combat-reachable code path.

---

## BL-12 · Only one SavedVariables global; `BankLedgerPerfDB` is not declared

**Section.** `toc-file-§2` (with `savedvariables-§4`, `performance-§5`) · **MUST** · **Open, follows
BL-11.**

**Rule.** *"MUST declare exactly **two** SavedVariables globals in the order above: `<Addon>DB` … and
`<Addon>PerfDB`."*

**State.** `BankLedger.toc:7` reads `## SavedVariables: BankLedgerDB` and nothing else. There is no
`BankLedgerPerfDB` anywhere in the repo. Everything else in `savedvariables` is clean: one AceDB
tree, one `schemaVersion` source, a real migration runner, no unsanctioned third global.

**Fix direction.** With BL-11 option 1: `## SavedVariables: BankLedgerDB, BankLedgerPerfDB`, and hand
the name to the Perf descriptor. With option 2 or 3, fold into the same record.

---

## BL-13 · The reserved `perf` verb is absent

**Section.** `slash-commands-§2` (with `performance-§4`) · **MUST** · **Open, follows BL-11.**

**Rule.** *"`help`, `get`, `set`, `list`, `reset`, `resetall`, `config`, `version`, `debug` and
**`perf`** are reserved across the collection and **MUST** mean the same thing in every addon."*

**State.** `NS.COMMANDS` (`settings/Schema.lua:226-286`) carries 15 verbs. Every other reserved verb
is present; `perf` is not. The README's command table (`README.md:80-98`) matches, so the two are
consistent — the verb is simply absent from both.

**Fix direction.** With BL-11 option 1, add a `perf` triple dispatching to the library's command
entry point and printing the returned lines through `NS.Print`; regenerate the README table in the
same change.

---

## BL-14 · `.luacheckrc` is missing the two perf entries

**Section.** `lint` (with `performance-§2`, `performance-§5`) · **MUST** · **Open, follows BL-11.**

**Rule.** The house config's `read_globals` includes `debugprofilestop`; `globals` includes
`<Addon>PerfDB`.

**State.** `.luacheckrc:9-30` lists 40+ `read_globals` and not `debugprofilestop`; `.luacheckrc:31-36`
lists `BankLedgerDB` and `StaticPopupDialogs` and not `BankLedgerPerfDB`. Both are consistent with
there being no brackets and no ring today. Everything else in `lint` is compliant, and `luacheck .`
is **0 warnings / 0 errors over 24 files**.

**Fix direction.** Two lines, in the same change as BL-11 option 1.

---

## BL-15 · `docs/performance.md` and `docs/perf-runs/README.md` are missing

**Section.** `documentation-§3` (with `performance-§8`) · **MUST** · **Open, follows BL-11.**

**Rule (restated at v2.19.0+).** **Five** topic-detail docs are required, not optional:
`docs/test-cases.md`, `docs/performance.md`, `docs/perf-runs/README.md`,
`docs/automated-tests/README.md`, `docs/automated-tests/RESULTS.md`.

**State.** Three of the five are present and current — `docs/test-cases.md`,
`docs/automated-tests/README.md`, `docs/automated-tests/RESULTS.md`. `docs/performance.md` does not
exist and neither does the `docs/perf-runs/` directory. (The 2026-08-04 run recorded this against the
then-current *three*-doc list; the requirement has since grown to five and the addon satisfies the two
that were added.)

**Fix direction.** With BL-11 option 1: `docs/performance.md` naming the bracketed paths and how to
run and read a capture, and `docs/perf-runs/README.md` documenting the naming convention with a
pointer to the library's canonical record contract and the note that offline runs live in
`docs/automated-tests/`.

---

## BL-16 · No `tests/perf.lua`, so the zero-overhead evidence does not exist

**Section.** `performance-§9` (with `performance-§2`, `testing-§7`) · **MUST** · **Open, follows
BL-11.**

**State.** `tests/` holds `run.lua`, `wow_mock.lua`, `_kit/` and 20 `test_*.lua` suites. There is no
`perf.lua`. Nothing is mis-counted as a result: the gate's 726 cases are all real test cases, so
`testing-§7`'s "measurement runners are not test cases" rule is trivially satisfied, and
`docs/automated-tests/RESULTS.md` correctly records `perf` as a **permanent skip with its reason**
rather than as a pass — which is `automated-tests-§3` handled exactly right.

**Fix direction.** With BL-11 option 1, add `tests/perf.lua` deriving its load list from the TOC per
`testing-§9`, asserting only call counts and bytes allocated, with the zero-overhead scenario over
`Database:Stats`. Keep it out of `tests/run.lua`.

---

## BL-17 · No suspend/resume host contract

**Section.** `performance-§6` · **MUST** · **Open, follows BL-11.**

**State.** No suspend seam exists. `NS.Ledger:Enable()` is the addon's only arming path and is not
re-entrant; `NS.SessionWindow`'s show-decision ladder has no suspended check; `core/State.lua`
declares no suspend flag. `docs/pending/LEDGER.md:65` costs the change out explicitly.

**Fix direction.** With BL-11 option 1, split `L:Enable` into an idempotent arm/disarm pair, add a
session-only `State.perfSuspended` consulted by `SW:Enabled()` and by the browser's show decision,
and rebuild registrations from current state on resume.

---

## BL-18 · `modules/Browser.lua` calls the global `print()`

**Section.** `events-frames-taint-§8` (with `slash-commands-§4`) · **MUST** · **Status: Open —
second consecutive run.**

**Rule.** *"call sites **MUST NOT**: call the global `print()` directly (it neither carries the
`NS.PREFIX` tag nor secret-stringifies its args) … Instead, each file does `local print = NS.Print`."*
The section adds that such a call site is *"non-compliant even if it is never handed a secret today."*

**State.** `modules/Browser.lua` declares no `local print = NS.Print`. Its only two occurrences of the
identifier are the call sites themselves:

- `modules/Browser.lua:917` — `print("view saved as your default.")`
- `modules/Browser.lua:926` — `if not silent then print("view reset to stock defaults.") end`

Both therefore resolve the Lua/WoW **global** `print`. Every other file that prints declares the
upvalue on its own line 4–5 (`modules/LedgerTable.lua:5`, `settings/Panel.lua:4`,
`settings/Schema.lua:5`, `settings/Slash.lua:4`, `settings/OptionsSetup.lua:20`) — and
`tests/test_libka0s.lua:340-349` even asserts that at least five such load-time captures exist and
that each loads after `core/CoreSetup.lua`. Browser is the one file the invariant does not reach.

**Why it matters.** Both lines are user-facing acknowledgements from the filter bar's *Save view* and
*Reset view* buttons, so a user sees two untagged lines from an addon whose every other line carries
`[BL]`, and both sit outside the secret-safe seam. `luacheck` cannot see it — `print` is a legitimate
`lua51` global — and no test covers it. It has now survived the 2026-08-03 review (as F-001) and the
2026-08-04 audit (as BL-18); the line numbers moved (855/864 → 917/926) but the defect did not.

**Fix direction.** Add `local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer
(events-frames-taint-§8)` at the top of `modules/Browser.lua` beside the existing `local C =
NS.Constants`, and extend `tests/test_browser.lua` to assert both lines arrive through the mock's
captured chat sink carrying `NS.PREFIX`. One line of production code; the test is what stops it
regressing a fourth time.

---

## BL-19 · `B:ApplySkin` restates the Ka0s edge instead of delegating to `Core.ApplySkin`

**Section.** `standalone-windows-§2` · **SHOULD** · **Status: Open.**

**Rule.** *"Where `LibKa0s-Core-1.0` is reachable, `ApplySkin` **SHOULD** be what draws it … A host
helper that skins the addon's own windows is **not** a deviation and is often necessary … it **MUST**
produce exactly the values above, and **SHOULD** delegate to `Core.ApplySkin` rather than restate
them."*

**State.** `modules/Browser.lua:19-36` declares a private `SKIN` table and `:67-89` a private
`B:ApplySkin` that builds the backdrop by hand. The values are **exactly** the normative ones —
bg `0.06, 0.06, 0.08, 0.92`; `WHITE8X8` edge at `edgeSize = 1` inset 1 tinted `0, 0, 0, 1`; a 1px
`BackdropTemplate` child inset one pixel on both axes at `0.24, 0.24, 0.27, 0.85`; title
`1.0, 0.82, 0.0`; divider `0.24, 0.24, 0.27, 0.85`. So the MUST is met and the two-line edge is
correct today. What is missing is the delegation the SHOULD asks for: `Core.SKIN` and
`Core.ApplySkin` are never reached, so the next change to the collection's edge will not reach this
addon's four windows.

**Note.** The related close-control rule is handled correctly and deliberately:
`modules/Browser.lua:93-107` draws the host's 24×24 class-colored ×, and `core/DebugLogSetup.lua:111-116`
passes **no** `makeCloseButton`, keeping Core's glyph on the library-drawn windows — with the reason
written at the site.

**Fix direction.** Have `B:ApplySkin` resolve `LibStub("LibKa0s-Core-1.0", true)` at call time and,
when present, delegate to `Core.ApplySkin(f)` after assigning `f.title` / `f.divider`, keeping the
current body only as the library-absent branch. Keep `B.SKIN`'s genuinely host-specific fields
(`tabActive`, `tabIdle`, `titleBarH`, `defaultH`, …) and drop the five that restate `Core.SKIN`.

---

## BL-20 · Malformed and retired standard references in comments and docs

**Section.** `documentation-§5`, with `STANDARDS.md`'s referencing rule · **SHOULD** ·
**Status: Open — unchanged.**

**Rule.** *"Reference a whole section by its **bare filename** … a subsection as `<filename>-§<n>` …
This is the **only** cross-reference form — the old global `§N.M` numbering is retired."*

**State.** Nine references in this repo's own files do not resolve.

*Malformed subsection numbers* — `options-ui` has §1–§11:

- `settings/OptionsSetup.lua:43` — `options-ui-§41`
- `settings/Schema.lua:184` — `options-ui-§41`
- `docs/ARCHITECTURE.md:106` — `options-ui-§41`
- `docs/pending/LEDGER.md:63` — "`standards/options-ui.md` §11 and §41"
- `settings/Panel.lua:58` — `options-ui-§190`
- `tests/test_panel.lua:175` — `options-ui-§189`

*Retired global `§N.M` notation:*

- `settings/OptionsSetup.lua:65` — "Ka0s standard §3.4"
- `settings/OptionsSetup.lua:74` — "Ka0s standard §3.1"
- `settings/Panel.lua:11` — "Ka0s standard §3.4"

Every other `filename-§N` reference in the repo resolves. Two occurrences inside
`libs/LibKa0s/Options.lua` are the **library's**, are excluded from this finding, and must be fixed
upstream and re-vendored — never edited here (library-stack-§7).

**Fix direction.** The `options-ui-§41` uses all mean *the single write seam* → `options-ui-§1`.
`options-ui-§190` and `options-ui-§189` both describe panel refresh and re-entrancy →
`options-ui-§11`. The `§3.4` uses (AceGUI resolved once and handed over) → `library-stack-§4`;
`§3.1` (AceTimer through the addon object) → `library-stack-§1`. Sweep with
`grep -rn -E "§[0-9]+\.[0-9]+|-§[0-9]{2,}"` excluding `libs/`, `docs/audits/`, `docs/reviews/` and
`docs/automated-tests/`.

---

## BL-25 · The release gate is stated nowhere; only its "never gates" half is

**Section.** `automated-tests-§3` (*The release gate*), with `automated-tests-§6` and
`documentation-§5` · **MUST** · **Status: New.**

**Rule (v2.21.0).** *"**MUST NOT** cut a release — bump the version, roll `## What's new`, tag —
unless the release run's `manifest.json` shows **all four** suites at `pass`, and
`suites.complexity.warnings` at **0** … **MUST** treat a **skip** as a gate that did **not** pass …
The one narrow exception is `perf` skipped because the addon **ships no `tests/perf.lua`** … and it
**MUST** be stated as such in the release notes."* `automated-tests-§6` adds: *"The release itself IS
gated on all four … The two checkpoints are deliberately different."*

**State.** The addon's two places that describe this both carry **only the commit-side half**:

- `docs/testing.md:88-91` — *"**`perf` and `complexity` never fail a run.** … They contribute
  `amber`, which is a signal rather than a stop."* and `:97-99` — *"**At release, not at commit.** A
  full bundle is produced as part of every version bump, before the tag … Commits are gated on lint +
  tests only."* The bundle is required; **nothing says the bundle's contents gate the tag.**
- `docs/testing.md:41-53` — the *Release checklist* lists the green gate, the regenerated inventory
  and "a full automated-test bundle produced and its diff read". It does **not** require all four
  suites at `pass`, and does not require `suites.complexity.warnings == 0`.
- `docs/automated-tests/README.md:26-35` — *"`perf` and `complexity` are **measured, recorded and
  diffed — never used to fail a run.**"* and *"A missing tool is a skip, not a failure"* — with no
  release-gate counterpart at all.

A grep for `release gate`, `CCN > 15` or `all four` across `README.md`, `CLAUDE.md`,
`DEPENDENCIES.md` and every file under `docs/` (excluding the frozen audit and review bundles)
returns **nothing** on the rule.

**Why it matters here specifically, and why it is a MUST rather than a nicety.** This is the exact
shape the standard warns against — restating "perf and complexity never gate" without naming *which
checkpoint*. And this addon is the case where it bites: its `perf` suite is a **permanent skip**
(BL-16), so the very next version bump runs headlong into the rule that *a skip is a gate that did
not pass*, plus the one narrow exception that saves it — and that exception is only usable if
somebody knows to state it in the release notes. Nothing in the repo tells them. A release cut from
these instructions would either be blocked by a rule nobody documented, or shipped past it silently.

**Fix direction.**

1. In `docs/testing.md`'s *Release checklist*, add the gate as its own checkbox: the release run's
   `manifest.json` must show `lint`, `tests`, `perf` and `complexity` all at `pass` with
   `suites.complexity.warnings == 0` — and state that the gate is evaluated by
   `/wow-addon:bump-version` from the manifest, **not** by the runner's exit code.
2. In the same place, record this addon's standing exception: `perf` is skipped because it ships no
   `tests/perf.lua`, which `automated-tests-§3` sanctions **provided the release notes say so** —
   and add that sentence to the release-notes step, so the exception travels with the release rather
   than living in an audit.
3. In `docs/testing.md` and `docs/automated-tests/README.md`, qualify both "never gates" sentences
   with *"— at a **run** or a **commit**; the **tag** is gated on all four plus zero CCN > 15
   (`automated-tests-§3`)."* Do not delete the existing sentences: they are correct about the
   checkpoint they describe, and the `--no-verify` rationale behind them is still normative.
4. Leave `docs/automated-tests/RESULTS.md` alone — it is **generated** by the vendored runner and
   never hand-edited. If its header text needs the same qualification, that is a `LibKa0s` finding,
   not a Bank Ledger one.

---

## BL-26 · The vendored runner is committed non-executable

**Section.** `automated-tests-§2` · **SHOULD** · **Status: New.**

**Rule.** *"`cp` also does not reliably carry the executable bit, so re-vendoring ends with
`chmod +x tests/_kit/run-automated-tests.sh`."*

**State.** The file exists and is the vendored copy, and the CRLF half of the rule is handled
correctly — `.gitattributes:38` carries `*.sh   text eol=lf` with the full reason written above it,
which is the part of `automated-tests-§2` that is a MUST. But the **mode committed to git is
`100644`**:

```
$ git ls-files -s tests/_kit/run-automated-tests.sh
100644 30da7c0713a07740c7d91828f07fe0adb04205d4 0	tests/_kit/run-automated-tests.sh
```

The working-tree `rwxrwxrwx` is a WSL `drvfs` artifact — every file under `/mnt/d` reports it — so it
says nothing about the mode a clone would get. On a fresh checkout on Linux or macOS the script is
**not executable**, and the invocation both `docs/testing.md:64-66` and
`docs/automated-tests/README.md:10-12` document — `tests/_kit/run-automated-tests.sh` — fails with
*permission denied*. The reader's next move is to conclude the vendored script is broken, which is
precisely the misattribution the neighboring CRLF rule exists to prevent.

**Fix direction.** `git update-index --chmod=+x tests/_kit/run-automated-tests.sh` and commit, then
add `chmod +x tests/_kit/run-automated-tests.sh` to the re-vendor step wherever that step is written
down. Optionally set `core.fileMode = false` in this repo so the drvfs mode never fights the index.

---

## BL-27 · Both vendor-sync cases pass when the gate cannot run

**Section.** `testing-§12` (with `testing-§11` and `library-stack-§7`) · **MUST** ·
**Status: New.**

**Rule.** `testing-§12`: *"A test that passes no matter what the implementation does still prints
`PASS`, still counts in the `--list` inventory and still moves the badge — so it **reads as
coverage** while providing none. That is strictly worse than an absent test."* `testing-§11`, on the
byte-identity gate this file implements: *"**MUST** fail, not pass, when the gate **cannot run**. If
the directory listing yields nothing, the check could not look — and a gate that goes quiet when it
cannot look is worse than no gate."*

**State.** `tests/test_vendor_sync.lua` is this addon's mechanical substitute for the manual
`diff -r ../LibKa0s/LibKa0s libs/LibKa0s` — and it is the **only** thing in the repo that can catch
vendored drift, because both suites stay green through it (anti-pattern #45). Both of its cases bail
out silently:

```lua
110  local function siblingTag()
111      if not gitShow("HEAD:LibKa0s/Core.lua") then return nil end
...
138  test("libs/LibKa0s is the LibKa0s release the README says this addon bundles", function()
139      local tag = siblingTag()
140      if not tag then return end        -- absent sibling -> PASS
...
144  test("tests/_kit is the test kit that shipped with that release", function()
145      local tag = siblingTag()
146      if not tag then return end        -- absent sibling -> PASS
```

With `../LibKa0s` absent — a fresh clone, a CI-less contributor machine, any checkout that is not
this one — both cases print `PASS`, both count toward the `726/726` badge, and **nothing** has been
compared. The file's own header claims otherwise at `:105-109`: *"A missing sibling is the ONE case
where this pair may go quiet, and it is said in the case name rather than hidden."* It is **not** in
either case name — neither name mentions the sibling, the tag, or a skip.

This is a MUST failure in its own right, and it is the reason this audit's `diff -r` evidence
(`03_EVIDENCE.md` §1.5) has to be recorded as **not run** rather than leaning on the green suite.

**Note — upstream, and it does not land here.** The vendored kit
(`tests/_kit/framework.lua`, `Kit.VERSION = 6`) has **no skip status**, which is what forces the
choice between "pass silently" and "fail on every machine without the sibling". The clean fix is an
additive `Kit.skip(reason)` in the **LibKa0s** repo, a kit revision bump, and a whole-folder
re-vendor as its own commit. **No edit under `tests/_kit/` or `libs/` is proposed anywhere in this
bundle** (library-stack-§7, testing-§1).

**Fix direction (in this repo, without waiting on the kit).**

1. Make the absence **loud in the case name**, not in a comment: rename both cases to carry the
   condition, e.g. *"…bundles (requires the sibling ../LibKa0s checkout)"*, and print one line naming
   the path that was looked for and not found — so a green run says out loud that this gate did not
   look.
2. Better, once `Kit.skip` exists upstream: report the case as **skipped**, so the `--list` inventory
   and the `[tests]` badge stop counting an unchecked gate as coverage.
3. Either way, add the falsification comment `testing-§12` asks for
   (`-- red under: flip one byte in libs/LibKa0s/Core.lua`) so the next author can re-run the proof
   rather than re-derive it.

---

## BL-23 · `docs/pending/LEDGER.md`'s deferred rows are a second backlog

**Section.** `documentation-§4` (by extension) · **MAY / advisory** · **Status: Advisory,
unchanged.**

**State.** There is no `TODO.md`, so the letter of the rule is met, and `docs/pending/LEDGER.md` is a
**decision ledger** — a legitimate topic-detail doc. But `DOC-01` (`docs/pending/LEDGER.md:32`) is
still 🟡 `deferred` with **no** tracking issue, where `DOC-03` and `DOC-04` both carry one (#1, #2).
It defers recording BL-04's rationale in `docs/ARCHITECTURE.md` ▸ *Documented deviations*, and that
section still carries BL-07 alone — so the row is both outstanding and untracked.

**Fix direction.** Either give every 🟡 row a tracking issue link the way `DOC-03`/`DOC-04` have, or
land the one-paragraph `ARCHITECTURE.md` record `DOC-01` is waiting on. Note that BL-11's fix
direction option 2 wants an entry in the *same* section, so the two land together cheaply.

---

## BL-24 · Four files in the on-notice size band

**Section.** `layout-§1` · **MAY / advisory** · **Status: Advisory, updated.**

**Rule.** *"MUST cap any single `.lua` file at 1500 LOC. Files in the 1000–1500 band are on notice; a
>1500 file is a bug — peel it."*

**State.** No file exceeds the cap. Four are in the band, and `docs/automated-tests/RESULTS.md`
already carries all four in its band table with dispositions:

| File | LOC | Band entry since | Disposition in `RESULTS.md` |
|---|---|---|---|
| `modules/Browser.lua` | 1368 | pre-adoption | already tracked as `BL-24`, peel seam named |
| `tests/test_ledger.lua` | 1361 | `20260804-182039` | accepted |
| `modules/LedgerTable.lua` | 1052 | `20260804-214843` | accepted, peel seam named |
| `modules/Insights.lua` | 1023 | `20260804-214843` | accepted, watch |

**Watch-list hygiene (anti-pattern #53).** The warned-**function** list is genuinely empty and says
so as a result. Three of the four **file** entries read "Accepted". None has yet been carried across
three consecutive **release** runs — no bundle to date has a non-null `release` field — so the
shelf-life rule has not yet been breached. It will be if the next three releases regenerate these
rows unchanged; convert one of them into a tracked deviation or peel it before then.

**Fix direction.** No action required now. The named seam for `Browser.lua` — the skin/close-button
factory and the geometry persistence at `:19-107` and `:110-180` — lifts cleanly into a sibling, and
`layout-§1` explicitly sanctions a 2–3-file peel in the same folder.
