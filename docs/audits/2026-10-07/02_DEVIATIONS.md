# 02 · Deviations — Ka0s Bank Ledger — 2026-10-07

Audited against the **Ka0s WoW Addon Standard v2.76.1 (2026-10-07)**. Repo kind: **addon**.

IDs are stable per addon (`BL-NN`). `BL-41`, `BL-45` and `BL-51` recur from earlier bundles;
**`BL-52` and `BL-53` are new this run.** No dependents were filed this run, so the `derived from`
column is empty.

---

## Tally, with its basis stated

**Headline (roots only): 4.** **Total including `derived from` dependents: 4** (no dependents this run).
Info rows are listed separately and excluded from both numbers.

| Grade | Roots | Total incl. dependents |
|---|---|---|
| High | 0 | 0 |
| Medium | 0 | 0 |
| Low | 4 | 4 |
| Info | — | `BL-51` plus the observation and accepted-row table below; excluded |

**MUST failures: 3 of the 4 roots** (`BL-41`, `BL-45`, `BL-53`), **3 including dependents**. All three
are Low because each is doc-, record- or generated-inventory-only; each entry still names the MUST it
fails. **`BL-52` is a release blocker, not yet a MUST failure**: `automated-tests-§3`'s release-gate MUST
binds the next tag, and no tag has been cut since the function crossed CCN 15 (2026-10-07). It is
counted as a root because the next release cannot be cut until it is resolved.

Nothing a player, their SavedVariables or their session can hit was found. The addon's runtime surface —
the stand-down, the slash surface, the launcher, the reset, the event isolation — measures compliant
against v2.76.1.

---

## Summary — open this run

| ID | Section | Strength | Grade | Summary | Fix direction |
|---|---|---|---|---|---|
| **BL-41** | `audit-review-history` (*A re-vendor commit implies a bundle*) | MUST | Low | LibKa0s `v1.69.0` (`b5e638b`) and `v1.70.0` (`2c87997`) were vendored with no `docs/revendor/` bundle and no register row. (Recurs; narrowed from 25 tags.) | One span bundle `docs/revendor/2026-10-07-v1.69.0-v1.70.0/`. |
| **BL-52** | `automated-tests-§3` (*The release gate*), `performance-§10` | MUST at the tag | Low | `LT.GroupEntries` (`modules/LedgerTable.lua:320-364`) measures CCN **16** in the sighted complexity suite; the `typesub` change (`5a78432`, today) took it from 15. The release gate wants zero functions above 15, and no sighted run has been recorded yet. | Lift the group comparator out to module level (two named comparators), or split the partition pass; re-measure; record a sighted run before the next tag. |
| **BL-53** | `testing-§5` | MUST | Low | `docs/test-cases.md`'s Totals reads **1259**, counting the kit's one declared skip, while the README badge reads **1258/1258**; the inventory's own header says the badge must agree with it. Root cause is the vendored kit's renderer (`tests/_kit/framework.lua:569`). | Fix upstream in `LibKa0s/testkit/framework.lua` (Totals counts passes-to-be, names the skips), re-vendor, regenerate. |
| **BL-45** | `documentation-§5` | MUST | Low | Stale prose and dangling pointers: the over-cap census says Browser is 1328 lines (it is 1427); two pointers to an `ARCHITECTURE ▸ Logo art` section that moved to `media.md` in 2026-08; a code comment calling the ▲/▼ mono glyph "an accepted, documented deviation" with a register row that does not exist. (Recurs, new sites.) | One sync sweep: refresh the figure, re-point both links at `media.md` ▸ Logo art, re-word the comment to cite `debug-logging-§2`'s sanctioned glyph use. |

## Summary — Info (excluded from both tallies)

| ID | Section | Basis |
|---|---|---|
| **BL-51** | `events-frames-taint-§8` (pre-formatting, outside the trigger set) | **SHOULD NOT, observation; reopens with new sites.** Six printer calls pre-format with `:format` or `..`: `modules/Browser.lua:901`, `:915` (new today in `e8d264a`, which turned `print("view saved as your default.")` into `print(("%s view saved as your default."):format(lastTab))`), `settings/Slash.lua:111`, `:253`, `:339`, `core/DebugLogSetup.lua:51`. Every value formatted is addon-owned (a tab name, a profile name, a version, the player's own verb, a fixed verb), so none is in the MUST's trigger set and nothing is reachable. Named so the SHOULD is not read as met. Fix with the next touch of each file: pass the value as a printer argument, as `BL-17` (`17568e2`) did on 2026-09-24. |
| BL-24 | `layout-§1` | **Advisory, tracked.** `modules/Browser.lua` is **1427** lines — 73 under the cap — and grew by 206 since the watch list's disposition was written (1221 at `20260927-031851`); 204 of those lines arrived today: `e5cd620` +105, `5a78432` +1, `12d7ba7` +7, `e8d264a` +91 (1223 → 1427). The peel seam is named in the disposition (skin/close factory and geometry persistence into a sibling file). Not a finding until the cap; worth scheduling before the next feature touches the file. |
| — | `automated-tests-§4/§6` | **Observation.** Newest bundle `20260927-031851` measured `b97fd24`, 67 commits behind HEAD, and predates kit revision 35: its manifest carries no `suites.complexity.blindFiles`, so the record holds **no sighted measurement**. Drift: NLOC 19,210 → 22,650, functions 2,920 → 3,628, max CCN 15 → 16, warnings 0 → 1, band 2 → 4 (`tests/test_browser.lua`, `tests/test_profiles.lua` entered). The checkpoint is release, so not a finding; the next release run is the first sighted one and its watch list owes dispositions for the two new band files. `docs/automated-tests/RESULTS.md:15` still names `/wow-addon:bump-version`; the kit-37 runner emits `/dev-copilot:bump-version`, so the next run rewrites it. |
| — | `documentation-§3` (hub length) | **Observation.** `docs/ARCHITECTURE.md` is 464 lines against the ~400 SHOULD. Every mandated section is under ~60 lines; the length is carried by three non-mandated sections (*Profiles*, *Launcher*, *The stand-down*), and `profiles.md` already exists to take the first. Reported as shape, not filed. |
| BL-04 | `localization-§1` | **Accepted.** Register row decided 2026-07-31; issue #3 and `BL-04` (2026-09-07) resolve. Trigger (first non-English locale) not fired. `localization-§3` names English-only, recorded, as a terminal compliant state. |
| BL-11…BL-17 | `performance-§12` | **Accepted, as one row.** Decided 2026-08-05, evidence issue #9 (resolves). Trigger not fired: no `OnUpdate`, no repeating ticker; the new transient `GET_ITEM_INFO_RECEIVED` (`modules/Backfill.lua:182`) is registered only while its once-per-session pass waits and is named in the sweep (`docs/performance.md:48`). |
| BL-28 | `standalone-windows` | **Accepted — terminal compliant decline, re-checked on all four conditions** (`01_CURRENT_STATE.md`, register). Trigger not fired. |
| — | `audit-review-history` (issue store) | **Observation.** 21 issues, all labeled, no `[status]` prefixes; one open (#1, `state:triaged`). The `state:will-not-do` issues decline adoptions or scope, not rules. |

## Summary — closed since 2026-09-23

| ID | Was | Now |
|---|---|---|
| BL-34, BL-34a | Two reset acts; expired `options-ui-§12` row | **Closed.** One confirm-gated act behind every reset control (`82d8f51`); row removed. |
| BL-36, BL-42 | Two load-bearing TOC lines unannotated | **Closed.** `BankLedger.toc:98`, `:107` (`fabef7a`). |
| BL-37 | Absent-arm row count unpinned | **Closed.** `tests/test_schema.lua:276` pins both counts and the delta (`90c23e1`). |
| BL-38 | "Four title bars" in seven lines | **Closed.** The phrase no longer appears outside frozen stores (`000ef6a`). |
| BL-39 | Issue #3 open for an existing row | **Closed.** #3 closed `state:done`. |
| BL-43 | `## Settings Schema` 167 lines unspilled | **Closed.** 43 lines (`docs/ARCHITECTURE.md:46-88`, `f8ab038`). |
| BL-44 | `debug.md` N/A with a fired trigger | **Closed.** `docs/debug.md` present and registered (`54531d9`). |
| BL-46, BL-46a | Retention `C_Timer.After` survived; mock no-opped it | **Closed.** AceTimer handle cancelled by the stand-down (`core/BankLedger.lua:329`, `90c7fb0`); the mock records (`tests/wow_mock.lua:636`). |
| BL-47 | Five registrations bypassed the helper | **Closed.** All through `NS.RegisterEventSafely` → `lib.SafeRegisterEvent` (`23d30ce`). |
| BL-48 | Generated record denied the exemption | **Closed.** `RESULTS.md` now names the ratified `performance-§12` skip. |
| BL-49 | Wire-name literals in tests | **Closed.** Grep empty (`dfc3cf5`). |
| BL-50 | `.pkgmeta` cited a line number | **Closed.** Cites `packaging` bare. |
| BL-07 | `savedvariables-§2` row (no profile) | **Retired.** Settings moved into AceDB profiles with a Profiles page (`d72e356`); the row is gone because the deviation is. |

---

## BL-41 · Two re-vendored LibKa0s tags have no bundle (recurs, narrowed)

**Section.** `audit-review-history`, *A re-vendor commit implies a bundle* · **MUST** · **Low** (doc-only;
`AUDIT.md` step 5 grades it, no player can reach a missing bundle).

**Rule.** *"every re-vendor commit in the repo's history has a `docs/revendor/` bundle naming the tag
that commit vendored, or the absence is a row in `## Documented deviations` saying why."*

**State.** The payload walk from the store's horizon (`2026-08-25`) resolves 52 distinct tags; the
bundles record 50. Unrecorded: **`v1.69.0`** (`b5e638b`, 2026-10-06, *"re-vendor LibKa0s v1.69.0 (kit 37;
adds the line chart widget)"*) and **`v1.70.0`** (`2c87997`, 2026-10-07). No register row. The 25 tags
`BL-41` named on 2026-09-23 were recorded by the span bundle `2026-09-24-v1.16.0-v1.54.2` (`5215cc3`).
Commands and output in `03_EVIDENCE.md` §E-04.

**Fix.** One span bundle, `docs/revendor/2026-10-07-v1.69.0-v1.70.0/`, whose `01_DELTA.md` line 1 reads
`Delta: LibKa0s v1.69.0 -> v1.70.0 (span: v1.69.0 v1.70.0)` (the shape `2026-10-01-v1.64.0-v1.65.0/01_DELTA.md:1` already uses), with the base `v1.68.1` named in the body: what arrived (Widgets 4 and 5,
`LineChart` and `Autocomplete`; kit 37) and what this addon adopted (`Autocomplete` under the search box).

---

## BL-52 · `LT.GroupEntries` measures CCN 16 — the next release is blocked on it

**Section.** `automated-tests-§3` (*The release gate: all four, and it is not the commit gate*),
`performance-§10` · **MUST** at the tag · **Low.**

**Rule.** *"MUST NOT cut a release … unless the release run's `manifest.json` shows all four suites at
`pass` … and `complexity` pass with **no function above CCN 15** and **`blindFiles` at 0**."*

**State.** The sighted complexity suite reports one warning: `LT.GroupEntries@320-364`, NLOC 35,
**CCN 16**. Measured on the parent of `5a78432` (*"Group by Type & SubType on History"*) with the same
sanitizer and command, the function was **CCN 15**: the commit's only change to the function's logic is
`sortKey = sortFn and sortFn(e) or groupOrder or valueLabel` (`modules/LedgerTable.lua:339`), one more
`or`. So the CCN is **dense defaulting, not tangled control flow** (`performance-§10`): the decisions are
the `not groupBy or groupBy == "none"` guard, two `and`-chained lookups, the `or "?"` and `or false`
fallbacks, the three-way `or` at `:339`, three loops and the comparator's two branches. Nothing a player
can reach; the function has seven cases in `tests/test_ledgertable.lua` (listed `docs/test-cases.md:392-398`).

No sighted run has been recorded at all (the newest bundle predates kit 35; Info table), so the release
run that would show this has not happened. **No release has been cut, so the MUST is not breached** —
the function is a blocker the next tag must clear.

**Fix.** Move the group comparator to module level as two named comparators (`groupAscending`,
`groupDescending`) chosen by `self.groupAsc`, which drops the comparator's branches from the function's count and
removes the closure `table.sort` is handed on every call today.
Do **not** dump the body into an unnamed helper (#52). The existing seven cases are the characterization
set (`testing-§13`); add one asserting descending group order under `typesub`. Re-run the complexity suite
and record a sighted run (`blindFiles: 0`) before the next bump.

---

## BL-53 · The generated inventory counts a declared skip into its total

**Section.** `testing-§5` · **MUST** · **Low.** Root cause upstream (the vendored kit).

**Rule.** *"Both figures count passes. A case that registered as a skip … MUST be shown as a skip — in the
inventory, with its reason — and **MUST NOT** be folded into either the passed count or the total."*

**State.** The run reports `1258 passed, 0 failed, 1 skipped, 1259 total`. The README badge reads
`Tests-1258%2F1258_passing` (`README.md:7`) — correct. The inventory discloses the skip with its reason
(`docs/test-cases.md:1402`) — correct — but its Totals reads `| **Total** | **1259** |`
(`docs/test-cases.md:1472`), and its header calls that table *"the **authoritative pass count** — the
README test badge and any count quoted in the docs must agree with it"* (`:4-5`). The two disagree by
exactly the skip. The renderer counts the whole registry: `out(string.format("| **Total** | **%d** |",
#tests))` (`tests/_kit/framework.lua:569`), although the kit's own header says a skip is never folded
into what the badge and the inventory count (`:204-205`). The addon cannot edit the kit (`testing-§1`);
LibKa0s `HEAD` (`353f286`) carries the same line, and no LibKa0s issue tracks it.

**Why Low.** Generated documentation; nothing a player sees. It reaches every addon that carries a
declared skip, which is why the fix belongs upstream.

**Fix.** Upstream in `LibKa0s/testkit/framework.lua`'s `renderTotals`: total the non-skipped cases and add
a `Skipped` row naming the count, so the Totals table and the badge are one number. Re-vendor, regenerate
`docs/test-cases.md`.

---

## BL-45 · Stale prose and dangling pointers (recurs, new sites)

**Section.** `documentation-§5` (*MUST keep the doc set in sync with code*) · **MUST** · **Low.** One
rolled-up finding; the fix is one sweep.

| Site | Says | Tree says |
|---|---|---|
| `docs/ARCHITECTURE.md:460` | *"The largest authored file is `modules/Browser.lua` at 1328 lines, measured 2026-10-07"* | 1427. `e5cd620` wrote the figure when the file was 1328; `5a78432` (+1), `12d7ba7` (+7) and `e8d264a` (+91) followed the same day without touching it. The kit gate checks membership, not this number, which is why nothing went red. |
| `core/Constants.lua:235` | *"See docs/ARCHITECTURE.md ▸ Logo art."* | No such section in the hub; it is `docs/media.md:104` (`## Logo art`), moved out with the tier-model adoption (`a6b4c39`, 2026-08-06). |
| `docs/smoke-tests.md:113` | *"(ARCHITECTURE ▸ Logo art)"* | Same: `docs/media.md` ▸ Logo art. A human tester following the step finds nothing. |
| `modules/LedgerTable.lua:28-30` | *"That is an accepted, documented deviation … See docs/ARCHITECTURE.md ▸ Documented deviations."* | The register has three rows and none is this. None is owed: `debug-logging-§2`'s *Second sanctioned use* makes the mono face on an individual ▲/▼ glyph a **MAY**. The comment both points at nothing and calls a sanctioned use a deviation, which is the shape `audit-review-history`'s register rule exists to stop (a deviation asserted outside the register). |

**Fix.** Refresh the figure (or drop it — the rule only needs the "nothing is over the cap" sentence);
re-point both Logo-art references at `docs/media.md` ▸ *Logo art*; reword `modules/LedgerTable.lua:28-30` to
*"sanctioned by `debug-logging-§2` (a glyph the default font lacks)"* with no register pointer.
