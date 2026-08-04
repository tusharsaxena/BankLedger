# 03 · Evidence — Ka0s Bank Ledger — 2026-08-04

Audited against the **Ka0s WoW Addon Standard v2.17.1 (2026-08-03)**. Every claim below is either a
`file:line` citation or the recorded output of a command that was actually run.

Addon HEAD: `95b7ae4b0f9cefcfe17577c80583b31866755eaf`.

---

## Part 1 — Mechanical checks (run, not reasoned about)

All commands were executed from the repo root
`/mnt/d/Profile/Users/Tushar/Documents/GIT/BankLedger` on 2026-08-04.

Toolchain: `Lua 5.1.5`, `Luacheck 1.2.0`.

### 1.1 Lint

```
$ luacheck .
Checking core/BankLedger.lua                      OK
Checking core/Compat.lua                          OK
Checking core/Constants.lua                       OK
Checking core/CoreSetup.lua                       OK
Checking core/Database.lua                        OK
Checking core/DebugLogSetup.lua                   OK
Checking core/Namespace.lua                       OK
Checking core/State.lua                           OK
Checking core/Util.lua                            OK
Checking defaults/Global.lua                      OK
Checking locales/PostLoad.lua                     OK
Checking locales/enUS.lua                         OK
Checking modules/Browser.lua                      OK
Checking modules/Export.lua                       OK
Checking modules/Filters.lua                      OK
Checking modules/Insights.lua                     OK
Checking modules/InsightsWidgets.lua              OK
Checking modules/Ledger.lua                       OK
Checking modules/LedgerTable.lua                  OK
Checking modules/SessionWindow.lua                OK
Checking settings/OptionsSetup.lua                OK
Checking settings/Panel.lua                       OK
Checking settings/Schema.lua                      OK
Checking settings/Slash.lua                       OK

Total: 0 warnings / 0 errors in 24 files
```

**Result: PASS** — the `lint` zero-error gate is met.

Note this is also the proof that BL-18 is invisible to lint: `print` is a legitimate `lua51` global,
so `modules/Browser.lua:855`/`:864` lint clean while calling the wrong function.

### 1.2 Headless suite

```
$ lua tests/run.lua
… 689 case lines …
689 passed, 0 failed, 689 total
$ echo $?
0
```

**Result: PASS**, exit **0** — `testing-§4`'s green gate is met.

Cross-check of the three places the count has to agree (`testing-§5`):

| Source | Value | Citation |
|---|---|---|
| Live run | 689 passed / 689 total | above |
| Generated inventory | `\| **Total** \| **689** \|` | `docs/test-cases.md:778` |
| README badge | `Tests-689%2F689_passing` | `README.md:7` |

All three agree.

### 1.3 Vendor-sync diff — `LibKa0s` ship payload

Source repo located as a sibling: `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s`, HEAD
`ac5d0f576eddeb375b982515e0e49e9faba5d881` *("docs: act on the 2026-08-02 adoption report")*, clean
tree. Confirmed to be the LibKa0s repo by its inner ship folder `LibKa0s/` and sibling `testkit/`.

```
$ diff -r /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/LibKa0s \
          /mnt/d/Profile/Users/Tushar/Documents/GIT/BankLedger/libs/LibKa0s
$ echo $?
0
```

**Result: EMPTY — PASS.** No anti-pattern #45 drift, and no anti-pattern #48 partial vendoring: all
ten ship-folder entries are present on the addon side — `Core.lua`, `DebugLog.lua`, `Slash.lua`,
`Options.lua`, `OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`, `PerfPanel.lua`, `LibKa0s.xml`,
`LICENSE` — **including the two Perf files the addon does not wire**, which is exactly what
`library-stack-§7`'s whole-folder rule requires.

### 1.4 Vendor-sync diff — the headless test kit

```
$ diff -r /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/testkit \
          /mnt/d/Profile/Users/Tushar/Documents/GIT/BankLedger/tests/_kit
$ echo $?
0
```

**Result: EMPTY — PASS.** The kit is vendored at `tests/_kit/` and **not** under `libs/`
(`testing-§1`), so `.pkgmeta`'s existing `- tests` entry already excludes it from the package.

The addon additionally gates this itself rather than relying on a remembered diff:
`tests/test_vendor_sync.lua` (150 lines) pins the vendored payload against the release the README
names, and both of its cases pass in the run above —
`PASS  libs/LibKa0s is the LibKa0s release the README says this addon bundles` and
`PASS  tests/_kit is the test kit that shipped with that release`.

### 1.5 Standard-text provenance

```
$ curl -fsSL --max-time 15 -o AUDIT.md     .../master/AUDIT.md            → OK
$ curl -fsSL --max-time 15 -o STANDARDS.md .../master/standards/STANDARDS.md → OK
$ for f in <24 section names discovered from the STANDARDS.md Sections list>; do
    curl -fsSL --max-time 10 -o "sections/$f.md" ".../master/standards/standards/$f.md"; done
$ ls sections | wc -l
24
$ diff -r sections /mnt/.../WowAddonStandards/standards/standards && echo SECTIONS-IDENTICAL
SECTIONS-IDENTICAL
$ diff STANDARDS.md /mnt/.../WowAddonStandards/standards/STANDARDS.md && echo INDEX-IDENTICAL
INDEX-IDENTICAL
$ diff AUDIT.md /mnt/.../WowAddonStandards/AUDIT.md && echo AUDIT-IDENTICAL
AUDIT-IDENTICAL
```

24/24 sections fetched; all three diffs empty. The standards checkout was read only.

### 1.6 US English sweep (`localization-§5` / anti-pattern #46)

```
$ grep -rniE "\b(colour|coloured|colouring|grey|behaviour|centre|centred|cancelled|cancelling|
    analyse|catalogue|dialogue|defence|licence|favour|labelled|travelled|fulfil|initialise|
    normalise|serialise|organise|optimise|capitalisation)\b" \
    --exclude-dir=.git --exclude-dir=libs --exclude-dir=audits --exclude-dir=reviews \
    --exclude-dir=superpowers .
tests/_kit/README.md:119:5. **Model the awkward real behaviour, not the convenient one.** …
```

**One hit, and it is not this addon's text.** `tests/_kit/README.md` is the vendored LibKa0s kit,
byte-identical to source (§1.4), and `testing-§1` says *"MUST NOT edit `tests/_kit/` in a consumer."*
Fixing it here would break the byte-identity gate. It is a **LibKa0s finding**, recorded here for the
library's own audit and **not** raised as a Bank Ledger deviation.

Zero hits in any authored file: `core/`, `modules/`, `settings/`, `defaults/`, `locales/`, `tests/*`
(excluding `_kit/`), `README.md`, `CLAUDE.md`, `docs/*.md`.

### 1.7 Global-`print` sweep (`events-frames-taint-§8`) — the BL-18 proof

```
$ for f in modules/*.lua core/*.lua defaults/*.lua locales/*.lua; do
    if grep -qE "(^|[^.:_a-zA-Z])print\(" "$f" && ! grep -q "^local print = NS.Print" "$f"; then
      echo "SUSPECT: $f"; grep -nE "(^|[^.:_a-zA-Z])print\(" "$f"; fi; done
SUSPECT: modules/Browser.lua
855:  print("view saved as your default.")
864:  if not silent then print("view reset to stock defaults.") end
```

```
$ grep -n "print" modules/Browser.lua
497:-- The Character dropdown's "Current" sentinel. \001 is unprintable and illegal …
855:  print("view saved as your default.")
859:-- programmatic callers (Slash:CliResetAll prints its own single confirmation); …
864:  if not silent then print("view reset to stock defaults.") end
```

There is **no** `local print` binding anywhere in the file, so both calls resolve the global. Every
other printing file declares it:

| File | Line |
|---|---|
| `modules/LedgerTable.lua` | `:5` — `local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)` |
| `settings/Panel.lua` | `:4` |
| `settings/Schema.lua` | `:5` |
| `settings/Slash.lua` | `:4` |
| `settings/OptionsSetup.lua` | `:20` |

### 1.8 Standard-reference sweep — the BL-20 proof

```
$ grep -rn -E "§[0-9]+\.[0-9]+|standard §[0-9]" --exclude-dir={.git,libs,audits,reviews} .
settings/Panel.lua:11:-- O.AceGUI is reached through `O.AceGUI` rather than a second LibStub call (Ka0s standard §3.4). It
settings/OptionsSetup.lua:65:  -- Ka0s standard §3.4: AceGUI is resolved once, by the library, and handed over rather than
settings/OptionsSetup.lua:74:  -- AceTimer through the addon object (Ka0s standard §3.1). The library takes it as a descriptor

$ grep -rn -E "\-§[0-9]{2,}" --exclude-dir={.git,libs,audits,reviews} . | grep -vE "\-§1[01][^0-9]"
docs/ARCHITECTURE.md:106: … repaints an open settings panel (options-ui-§41) …
settings/Panel.lua:58:-- SavedVariables size. Coalesced into one refresh at the end, which is also what options-ui-§190
settings/OptionsSetup.lua:43:  -- The schema seams. NS.Schema:Set is this addon's SINGLE write seam (options-ui-§41), so a panel
settings/Schema.lua:184:  -- where that belongs: this is "the same function /bl set calls" (options-ui-§41), so a slash
tests/test_panel.lua:175:  -- /reload recovers it (options-ui-§189 makes the same point about a re-entrancy guard).
```

`options-ui` numbers §1–§11, so §41, §189 and §190 do not exist. All 34 other distinct
`filename-§N` forms in the repo resolve.

### 1.9 Perf-wiring sweep — the BL-11 … BL-17 proof

```
$ grep -rn -E "Perf|debugprofilestop" . --exclude-dir={.git,libs,reviews,audits}
docs/pending/LEDGER.md:65:  | LIBKA0S-17 | … 🔵 wont-do | 2026-08-01 | **`LibKa0s-Perf-1.0` DECLINED …
tests/run.lua:38:  "libs/LibKa0s/Perf.lua",
tests/run.lua:39:  "libs/LibKa0s/PerfPanel.lua",
tests/_kit/README.md:69:  …            (vendored kit text)
tests/_kit/mock_base.lua:35,120,124,155,193                (vendored kit text)
```

No `core/PerfSetup.lua` on disk, no `NS.Perf`, no `buckets`, no bracket, no `perf` verb,
no `BankLedgerPerfDB`. The only addon-authored hits are the test runner's load list — which correctly
loads **all eight** LibKa0s files — and the recorded decline.

### 1.10 Not run / not applicable

- **`lizard` complexity report** — the tool is not installed on this machine and the report
  (`docs/complexity.md`) does not exist. `performance-§10` explicitly says absent tooling means the
  report is stale, not that the addon is non-compliant; recorded as SHOULD deviation BL-21.
- **Test falsifiability (`testing-§12`)** — verifying that a negative-asserting case actually reddens
  requires mutating the implementation, which leaves no artifact and is not mechanically auditable.
  The section says an audit **MUST NOT** record its absence as a deviation. Recorded here as
  **unverified**, not as a finding.
- **In-client behavior** — frame rendering, taint, and the live panel are covered by
  `docs/smoke-tests.md`, not by this audit.

---

## Part 2 — Evidence per deviation

### BL-07 · No `defaults/Profile.lua`

| Claim | Evidence |
|---|---|
| `defaults/` contains only `Global.lua` | repo tree; `defaults/Global.lua` is the sole file |
| `NS.defaults` has `global` and no `profile` | `defaults/Global.lua:6-7`, `:45-49` |
| Every path resolves against `NS.db.global` | `settings/Schema.lua:9`, `:165`, `:194`, `:198` |
| Account-wide by design, with the reason in code | `defaults/Global.lua:3-5` |
| **Recorded as an accepted deviation** | `docs/ARCHITECTURE.md:567-580` — names `savedvariables-§2` and `layout-§1`, the account-wide rationale, and why an empty `Profile.lua` would be worse |
| The rest of `savedvariables` is clean | `schemaVersion` from one source `core/Namespace.lua:13` → `defaults/Global.lua:14`; migration runner `core/Database.lua` `NS:RunMigrations`; session-only debug flag `core/State.lua:25-26` |

### BL-11 · Perf lib vendored, not wired

| Claim | Evidence |
|---|---|
| Perf files ship and load | `libs/LibKa0s/Perf.lua`, `libs/LibKa0s/PerfPanel.lua`; `BankLedger.toc:29` loads `libs\LibKa0s\LibKa0s.xml`; `tests/run.lua:38-39` |
| No `core/PerfSetup.lua` | absent from the repo tree and from `BankLedger.toc:35-49` |
| No `NS.Perf`, no descriptor, no bucket, no bracket | §1.9 sweep |
| The decline is recorded and reasoned | `docs/pending/LEDGER.md:65` (LIBKA0S-17, 🔵 wont-do, 2026-08-01) |
| Yesterday's review routed it here rather than acting | `docs/reviews/2026-08-03/01_FINDINGS.md:20-28`; `docs/reviews/2026-08-03/05_FINAL_SUMMARY.md:37-40`; `docs/reviews/2026-08-03/02_PROPOSED_CHANGES.md:392-400` |
| The rule is MUST-on-wiring | `performance` §Adoption strength; `performance-§1` |

### BL-12 · One SavedVariables global

| Claim | Evidence |
|---|---|
| Only `BankLedgerDB` is declared | `BankLedger.toc:7` — `## SavedVariables: BankLedgerDB` |
| No `BankLedgerPerfDB` anywhere | §1.9 sweep |
| Rule requires exactly two, in order | `toc-file-§2`; `savedvariables-§4`; `performance-§5` |

### BL-13 · No `perf` verb

| Claim | Evidence |
|---|---|
| `NS.COMMANDS` holds 15 verbs, none of them `perf` | `settings/Schema.lua:226-286` |
| Every *other* reserved verb is present | `help` `:285`, `config` `:230`, `version` `:233`, `get` `:234`, `set` `:235`, `list` `:236`, `reset` `:237`, `resetall` `:238`, `debug` `:263` |
| README table matches (also has no `perf` row) | `README.md:80-98` |
| Rule | `slash-commands-§2` (reserved set); `performance-§4` |

### BL-14 · `.luacheckrc` missing the two perf entries

| Claim | Evidence |
|---|---|
| `read_globals` has no `debugprofilestop` | `.luacheckrc:9-30` |
| `globals` has `BankLedgerDB`, `StaticPopupDialogs`, not `BankLedgerPerfDB` | `.luacheckrc:31-36` |
| Every `globals` entry does carry a justifying comment (this part is compliant) | `.luacheckrc:32`, `:33-35` |
| Config is otherwise the house shape | `.luacheckrc:1-8` — `std = "lua51"`, `codes = true`, `exclude_files` includes `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/` |

### BL-15 · Missing required topic-detail docs

| Claim | Evidence |
|---|---|
| `docs/` listing | `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`, `test-cases.md`, `pending/`, `superpowers/`, `audits/`, `reviews/` |
| Canonical trio present and current | `docs/ARCHITECTURE.md:1`, `docs/testing.md:1`, `docs/smoke-tests.md` |
| `docs/test-cases.md` present and generated | `docs/testing.md:135-141` documents the `--list` generation; `docs/test-cases.md:778` |
| `docs/performance.md` and `docs/perf-runs/README.md` absent | repo tree |
| Rule names all three as required | `documentation-§3` |

### BL-16 · No `tests/perf.lua`

| Claim | Evidence |
|---|---|
| `tests/` contents | `_kit/`, `run.lua`, `wow_mock.lua`, 18 `test_*.lua`; no `perf.lua` |
| The gate does not accidentally include a measurement runner | `tests/run.lua:18-24` suite list is 19 names, all `test_*` |
| Rule | `performance-§9`; the zero-overhead scenario is `performance-§2`'s "required evidence"; `testing-§7` |

### BL-17 · No suspend/resume contract

| Claim | Evidence |
|---|---|
| No suspend flag in runtime state | `core/State.lua:16-36` declares `openContext`, `lastSnapshot`, `cleanupDone`, `debug`, `testRecords`, `sessionEntries`, `sessionActive` — no suspend |
| `L:Enable` is the only arming path and is not re-entrant | `modules/Ledger.lua:761` |
| Show-decision ladder has no suspended check | `modules/SessionWindow.lua` `SW:Enabled()` |
| The decline note costs the work out explicitly | `docs/pending/LEDGER.md:65` |
| Rule | `performance-§6` |

### BL-18 · Global `print()` in `modules/Browser.lua`

| Claim | Evidence |
|---|---|
| Two call sites | `modules/Browser.lua:855`, `modules/Browser.lua:864` |
| No `local print` binding in the file | §1.7 — `grep -n "print" modules/Browser.lua` returns only those two plus two prose comments |
| Every other printing file binds it | `modules/LedgerTable.lua:5`, `settings/Panel.lua:4`, `settings/Schema.lua:5`, `settings/Slash.lua:4`, `settings/OptionsSetup.lua:20` |
| The shared printer exists and is correct | `core/CoreSetup.lua:88-98`; `NS.PREFIX` at `core/Namespace.lua:18` |
| Both lines are user-facing | `B:SaveView` `modules/Browser.lua:853-857`, `B:ResetView` `:862-866` — the filter bar's Save/Reset buttons |
| Lint cannot see it | §1.1 — 0 warnings, `print` is a `lua51` global |
| Raised as F-001 (High) in the 2026-08-03 review and not yet fixed | `docs/reviews/2026-08-03/01_FINDINGS.md:40-45` |
| Rule | `events-frames-taint-§8` ("call sites MUST NOT call the global `print()` directly"); `slash-commands-§4` (mandated `NS.PREFIX` tag on every line) |

### BL-19 · Skin restated rather than delegated

| Claim | Evidence |
|---|---|
| Private `SKIN` table | `modules/Browser.lua:20-34` |
| Private `B:ApplySkin` builds the backdrop by hand | `modules/Browser.lua:67-89` |
| Values match the normative edge exactly | bg `0.06, 0.06, 0.08, 0.92` (`:22`, `:73`); `WHITE8X8` edge `edgeSize = 1`, insets 1 (`:68-71`), tinted `0, 0, 0, 1` (`:23`, `:74`); 1px `BackdropTemplate` child inset one pixel (`:76-82`) at `0.24, 0.24, 0.27, 0.85` (`:24`, `:83`); title `1.0, 0.82, 0.0` (`:26`, `:85`); divider `0.24, 0.24, 0.27, 0.85` (`:25`, `:86`) — compare `standalone-windows-§2`'s table |
| `Core.ApplySkin` / `Core.SKIN` are never reached | `grep "LibKa0s-Core"` in `core/`, `modules/`, `settings/` returns only `core/CoreSetup.lua:34` |
| The console correctly routes through the host seam | `core/DebugLogSetup.lua:107-109` |
| …and correctly does **not** push the host's close glyph | `core/DebugLogSetup.lua:111-116`; the host glyph is `modules/Browser.lua:93-107` |
| Rule | `standalone-windows-§2` — MUST on the values (met), SHOULD on the delegation (not met) |

### BL-20 · Unresolvable standard references

Full listing in §1.8. Eight sites: `settings/OptionsSetup.lua:43`, `:65`, `:74`;
`settings/Schema.lua:184`; `settings/Panel.lua:11`, `:58`; `docs/ARCHITECTURE.md:106`;
`tests/test_panel.lua:175`.

### BL-21 · No complexity report

| Claim | Evidence |
|---|---|
| `docs/complexity.md` absent | repo tree |
| The two places it would be read | `modules/Browser.lua` 1306 LOC; `core/Database.lua:Stats` left unrefactored for want of measured evidence — `docs/reviews/2026-08-03/05_FINAL_SUMMARY.md:30-35` |
| Rule, and its "absent tooling ≠ non-compliant" carve-out | `performance-§10` |

### BL-23 · Deferred rows in `docs/pending/LEDGER.md`

| Claim | Evidence |
|---|---|
| No `TODO.md` anywhere | repo tree — root and `docs/` both clean |
| The file is a decision ledger, and says so | `docs/pending/LEDGER.md:1-13` |
| Three 🟡 `deferred` rows | `DOC-01`, `DOC-03`, `DOC-04` in the Decisions table |
| `DOC-03`/`DOC-04` carry issue links; `DOC-01` does not | Decisions table rows |
| `DOC-01`'s deferred item has since been done | it asks for the BL-07 record in ARCHITECTURE, which now exists at `docs/ARCHITECTURE.md:567-580` |
| Rule's rationale | `documentation-§4` |

### BL-24 · File size

```
$ wc -l core/*.lua defaults/*.lua locales/*.lua modules/*.lua settings/*.lua | sort -n | tail -6
   608 settings/Panel.lua
   665 modules/SessionWindow.lua
   789 modules/Ledger.lua
   832 modules/InsightsWidgets.lua
   916 modules/Insights.lua
   972 modules/LedgerTable.lua
  1306 modules/Browser.lua
```

Cap is 1500 (`layout-§1`); nothing exceeds it. `modules/Browser.lua` is in the 1000–1500 on-notice
band.

---

## Part 3 — Evidence for the compliance claims

These are the findings the audit records as **met**, each sourced the same way.

### Shared subsystems — consumed from the library, not hand-rolled

`anti-patterns #47` is the rule; the evidence is the descriptor and the stub, never the behavior.

| Module | LibStub lookup | Descriptor | Degradation stub | Instance published |
|---|---|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua:34` (`LibStub("LibKa0s-Core-1.0", true)`) | `:88-90` (`prefix` as a **function**) | `:36-73` — the sanctioned second copy of the stringifier/printer, with the honest line said once at `:65-69` | `NS.IsConcatSafe`/`NS.SafeToString` `:76-77`; `NS.Print` + `NS.Util.print` as the **same object** `:97-98` |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua:20` (silent + guarded) | `:59-121` — `name`, `title`, `font`, `isEnabled`, `setEnabled`, plus `print`/`initSummary` as **call-time forwarders** `:78-79` | `:22-57` | `NS.DebugLog` `:54`/`:59`; sink bound bare as `NS.Debug` `:125` |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua:99` | `:174-213` over the host's `NS.COMMANDS` | `:109-155` | `cli` + republished verbs `:215-228` |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua:26` | `:36-94` | `:115-163` (**load-completing**, per `options-ui-§1`'s documented exception) | `NS.Helpers = lib:New(descriptor)` `:166` — the instance **is** the member |
| `testkit` | n/a (vendored files) | `tests/run.lua:8-10` | n/a | `_G.BL_TEST = Kit.expose{…}` `tests/run.lua:48-51` |

There is **no** `modules/DebugLog.lua`, no widget-maker file, no addon-local dispatcher/parser, and no
hand-written test framework — the absence is the compliance.

### Stub coverage — every member the addon reaches is answered

**DebugLog** (`core/DebugLogSetup.lua:22-57`). Members the addon calls on `NS.DebugLog`, and where:

| Member | Call site | Answered by the stub |
|---|---|---|
| `IsShown` | `settings/Schema.lua:47` | `:33` |
| `Show` | `settings/Schema.lua:50`; `settings/Schema.lua:272`, `:281` | `:34` |
| `Hide` | `settings/Schema.lua:50` | `:35` |
| `Toggle` | `settings/Schema.lua:283` | `:36` |
| `Add` | `settings/Schema.lua:274`, `:276`, `:282` | `:37` |
| `SetEnabled` | `settings/Schema.lua:267`, `:268` (guard at `:266`) | `:48-52` — **still flips the flag**, because it gates more than the window |
| `IsEnabled` | via `Debug` gating | `:43` |
| `Clear` / `UpdateScrollBar` / `UpdateStatus` / `RefreshHeader` / `ShowCopy` | library-facing; kept for a future call site | `:38-42` |
| `buffer` | raw field | `:29` |
| `NS.Debug` sink | 23 sites | `:55` — no-op |

Complete; nothing the addon reaches is missing.

**Slash** (`settings/Slash.lua:109-155`). `OnSlash` `:143`, `PrintHelp` `:118`, `BuildListLines`
`:119`, `CliList/Get/Set/Reset` `:120-123`, `CliVersion` `:124`, `LandingRows` `:125`, `CliResetAll`
`:130-140`. `CliResetAll` is deliberately kept **working** rather than merely explanatory, and the
comment at `:127-129` says why. No copied row formatter, parser or `key = value` shape — every
degraded line is the shared cause clause plus a consequence.

**Options** (`settings/OptionsSetup.lua:115-163`). This one is **load-completing rather than
member-answering**, which is `options-ui-§1`'s one documented exception. The comment at `:98-114`
records that the load-time member set was determined by **measurement** and, for this addon, is
**zero** — no schema-row literal calls a helper. Layout constants are published as `0`/`0.5`
(`:160`) rather than copied from the library (`anti-patterns #47`). **This is correct and is not a
finding.**

**Core** (`core/CoreSetup.lua:36-73`) is the sanctioned exception in the other direction: the
fallbacks genuinely *work* rather than answering "not installed", because five files capture the
printer as a load-time upvalue and a no-op printer would silence the addon
(`events-frames-taint-§8`).

### Whole-folder vendoring and the TOC

| Claim | Evidence |
|---|---|
| TOC lists the single aggregate XML, once, after Ace3 | `BankLedger.toc:29` — `libs\LibKa0s\LibKa0s.xml`, last in the `# Libraries` block that starts `:15` |
| No individual module `.lua` in the TOC | `BankLedger.toc:15-29` |
| Whole ship folder present, including unwired Perf | §1.3 |
| The comment records why LibKa0s is last | `BankLedger.toc:27-28` |
| The runner loads all eight lib files, not just the wired ones | `tests/run.lua:31-40` with the reason at `:26-30` |

### The AceConsole `:Print` clobber (architecture-§2 / anti-pattern #36)

| Claim | Evidence |
|---|---|
| `NewAddon(NS, …, "AceConsole-3.0")` | `core/BankLedger.lua:3-4` |
| Reclaimed immediately after | `core/BankLedger.lua:13` — `if NS.Util and NS.Util.print then NS.Print = NS.Util.print end` |
| The reclaim works because the two are one object | `core/CoreSetup.lua:92-98` and its comment |
| The mock reproduces the embed, so a test can see it | `tests/wow_mock.lua:493` |
| Asserted | `tests/test_util.lua:143` |

### Message bus (architecture-§4 / anti-patterns #32, #33)

| Message | Sender | Receivers, each on a private target |
|---|---|---|
| `Ka0s_BankLedger_EntryAdded` | `core/Database.lua:76-78` | `modules/SessionWindow.lua:655`, `modules/Browser.lua:1300`, `modules/Insights.lua:915`, `settings/Panel.lua:166` |
| `Ka0s_BankLedger_LedgerChanged` | `core/Database.lua:451-453` | `modules/SessionWindow.lua:658`, `modules/Browser.lua:1299`, `modules/Insights.lua:914`, `settings/Panel.lua:165`, `:311` |
| `Ka0s_BankLedger_SessionChanged` | `modules/Ledger.lua:477-481` (sole sender, stated at `:475`) | `modules/SessionWindow.lua:652` |
| `Ka0s_BankLedger_SettingsChanged` | `settings/Schema.lua` (7 rows, one producer file) | `modules/Ledger.lua:787`, `modules/SessionWindow.lua:659`, `modules/Browser.lua:1298` |

Target factory: `core/BankLedger.lua:20-26`. No receiver registers on `NS.bus`/`NS.addon` as `self`.
All messages are documented in `docs/ARCHITECTURE.md:269-289`.

### Options UI

| Rule | Evidence |
|---|---|
| Instance **is** the namespace member, decorated in place | `settings/OptionsSetup.lua:166`, `:11-15` |
| `OnCommit`/`OnDefault`/`OnRefresh` come from the library (Options minor 5) and the host does not set them | `libs/LibKa0s/Options.lua:24` (`MINOR = 5`), `:219-231`; host parks `defaultsOnClick` at `settings/Panel.lua:51-53`, with the reason at `:47-50` |
| Category registered **eagerly** at load | `core/BankLedger.lua:36` → `settings/Panel.lua:511`, `:600` (`O.CreateOptionsPanel()`) |
| Bodies lazy; Defaults button built in first `OnShow` | `settings/Panel.lua:524`, `:572` page builders; `ensureDefaultsButton` diagnostics at `:371` |
| Combat gate is the library's, no second open path | `settings/Panel.lua:603-607` |
| Landing page order and command list from one formatter | `settings/Panel.lua:317-361`; rows from `NS.Slash:LandingRows()` `:357` |
| Single write seam shared by panel and slash | `settings/OptionsSetup.lua:46-48` and `settings/Slash.lua:184-188` both route to `NS.Schema` |
| No AceConfig vendored | `libs/` listing |

### Slash surface

| Rule | Evidence |
|---|---|
| AceConsole registration, both verbs | `settings/Slash.lua:81-84` |
| `COMMANDS` stays the host's, positional triples | `settings/Schema.lua:226-286` |
| Cyan mandated tag as one constant | `core/Namespace.lua:15-18` |
| Printer passed as descriptor `print` | `settings/Slash.lua:178` |
| Host `format`/`parse` overrides at the sanctioned seam only | `settings/Slash.lua:198-212`, with `lib.FormatValue`/`lib.ParseValue` as the fall-through |
| `reset` takes a path | `settings/Schema.lua:237` |
| `version` reads TOC metadata with the constant as fallback | `settings/Slash.lua:104-107` |

### Debug console coverage (debug-logging-§8/§9/§10)

23 gated `NS.Debug` sites. Lifecycle: `core/Database.lua` `Migrate`, `Prune`. Core capture flow
including no-op decisions: `modules/Ledger.lua` `Store`×4, `Skip`, `Diff`×2, `Move`. Data mutations:
`core/Database.lua` `Data`×2. View open/recompute: `modules/Browser.lua` `UI`×3,
`modules/LedgerTable.lua` `Table`, `modules/SessionWindow.lua` `Session`×2,
`modules/Insights.lua` `Insights`, `modules/Filters.lua` `Filters`. Settings: exactly **one** line at
the write seam, `settings/Schema.lua:177-179`, tagged `Set`.

Ungated raw append is used only where the standard sanctions it — the two explicit user-initiated
dump verbs `/bl debug scan` and `/bl debug panel` (`settings/Schema.lua:269-282`).

### Windows, pooling, taint

| Rule | Evidence |
|---|---|
| `UISpecialFrames` on all four windows | `modules/Browser.lua:1186-1187`, `modules/SessionWindow.lua:554-555`, `modules/Export.lua:262-263`, `:352-353` |
| Geometry persisted and restored | `modules/Browser.lua:123-137` (`SaveGeometry`) and `:138-...` (`ApplyGeometry`), with the comment at `:114-122` explaining the `OnHide` + `PLAYER_LOGOUT` anchoring |
| Scale setting applied via `SetScale` | `settings/Schema.lua:57-71` → `NS.Browser:SetScale` |
| Row pooling for the history table | `modules/LedgerTable.lua:533-535`, `:673-679`, `:712`, with the rule cited at `:7-9` |
| No secure frames, no `OnUpdate` | no `SetAttribute`, no `OnUpdate` anywhere in `core/`, `modules/`, `settings/` |
| AceEvent only | `core/BankLedger.lua:40`; private targets at `modules/Browser.lua:1304`, `modules/SessionWindow.lua:663` |

### Localization (localization-§4)

| Claim | Evidence |
|---|---|
| Class matched on the **token**, never the display name | `modules/Ledger.lua:422`, `modules/SessionWindow.lua:194`, `modules/Browser.lua:101` — all `local _, classFile = UnitClass("player")` |
| Map matched on `uiMapID` | `core/Compat.lua:25-30` (`C_Map.GetBestMapForUnit`) |
| `GetZoneText`/`GetSubZoneText` used as a **display stamp only**, never compared to a literal | `core/Compat.lua:32-36`; consumed at `modules/Ledger.lua:421`, `:431-432`; downstream uses are grouping/sorting/export/search over stored values (`core/Database.lua:197-199`, `:349`, `:506`; `modules/Export.lua:44`), never an English-literal branch |
| `enUS.lua` ships with the metatable fallback | `locales/enUS.lua:6` |
| `PostLoad.lua` alias seam ships | `locales/PostLoad.lua:1-9` |

### Documentation

| Rule | Evidence |
|---|---|
| Badge row, exact template order, `_` not `%20` | `README.md:3-7` |
| `## What's new` immediately above `## Screenshots`, agreeing with the top Version History row | `README.md:36`, `:49`, `:176-180` |
| Slash table generated from `NS.COMMANDS` | `README.md:80-98` vs `settings/Schema.lua:226-286` |
| No angle-bracket placeholders in shipped prose | §Part 1 sweep — only a `<br>` inside a table cell, which is real HTML the rule exempts |
| `CLAUDE.md` is a stub with the verbatim-in-substance compliance section | `CLAUDE.md:1-4`, `:6-23`, `:25-34` |
| Three-place standards reference | `BankLedger.toc:12`; `README.md:6`; `CLAUDE.md:6` |
| No `docs/agent-context.md`, with the ban recorded | repo tree; `CLAUDE.md:36-51` |
| `docs/ARCHITECTURE.md` carries every required section | `:19` Overview, `:82` Module map, `:154` Data model, `:226` Settings schema, `:269` Message bus, `:290` Slash surface, `:316` Event subscriptions, `:380` Windows, `:542` Taint notes, `:567` Documented deviations, `:640` Known limitations |
| `docs/testing.md` is the verify-how-to and points at both companions | `:6` green gate, `:16` vendor gate, `:44` release checklist, `:57` toolchain, `:130` → `smoke-tests.md`, `:135` → `test-cases.md` |
| Audit/review history retained, untouched | `docs/audits/2026-07-26/`, `docs/audits/2026-07-27/`, `docs/reviews/2026-07-27/`, `docs/reviews/2026-08-03/` |

### Packaging, versioning, git

| Rule | Evidence |
|---|---|
| `.pkgmeta` with no `externals:`, ignoring `docs`/`tests`/`_dev` | `.pkgmeta:1-18` |
| Libraries committed to git | `libs/` is tracked |
| Semver in TOC, code fallback and README | `BankLedger.toc:5`; `core/Namespace.lua:7`; `README.md:180` |
| Trunk-based, one release tag | branch `master`; `git tag` → `1.0.0-release` |
| Green-gate discipline documented | `CLAUDE.md:33-34`; `docs/testing.md:6-15`, `:44-56` |
