# 03 · Evidence — Ka0s Bank Ledger — 2026-09-07

Every command below was **run today**, from the repo root, on this machine (WSL2 / Ubuntu, Lua
5.1.5, Luacheck 1.2.0, lizard 1.23.0). Output is pasted verbatim, trimmed only where marked. Every
`file:line` was re-read before it was written here, and the cited text is quoted beside it.

**Scope of the sweeps in §7 and §8, stated once.** *Swept:* `core/`, `defaults/`, `locales/`,
`modules/`, `settings/`, `tests/` (excluding `tests/_kit/`), the repo root, and the **live** pages
under `docs/`. *Excluded:* `libs/` (vendored third-party and the LibKa0s payload), `tests/_kit/`
(vendored kit), and the frozen bundles `docs/audits/`, `docs/reviews/`, `docs/revendor/`,
`docs/automated-tests/<run>/`, `docs/superpowers/`.

---

## 1 · Lint

```
$ luacheck .
…
Checking settings/Panel.lua                       OK
Checking settings/Schema.lua                      OK
Checking settings/Slash.lua                       OK

Total: 0 warnings / 0 errors in 28 files
```

## 2 · Headless suite

```
$ lua tests/run.lua
…
  PASS  libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release
…
831 passed, 0 failed, 0 skipped, 831 total
```

Both vendored-payload cases **ran** rather than skipping — the sibling checkout is present — which
is what makes §5 meaningful and what closes BL-27.

## 3 · Complexity, and the drift against the record

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
…
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
==========================================================================================
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
------------------------------------------------------------------------------------------
     14174       6.0     2.0       47.3     2153            0      0.00    0.00
```

Invocation taken verbatim from `automated-tests` / the playbook — no extra flag, no narrowed path,
no re-tuned threshold, so the numbers are comparable with the committed report.

Against the newest bundle, `docs/automated-tests/20260825-103400/complexity.txt` (footer) and its
`manifest.json`:

| Figure | `20260825-103400` | Today | Drift |
|---|---|---|---|
| Total NLOC | 13409 | 14174 | +765 |
| Functions | 2043 | 2153 | +110 |
| Avg CCN | 2.0 | 2.0 | — |
| `lizard` warnings | 0 | 0 | — |
| Tests | 791/791 | 831/831 | +40 |
| Files linted | 28 | 28 | — |

**No function crossed a `lizard` threshold** and nothing entered or left `layout-§1`'s over-cap
band. What did move is the on-notice band's contents, measured today with `wc -l`:

```
$ find core modules settings tests locales defaults -name '*.lua' -not -path 'tests/_kit/*' | xargs wc -l | sort -rn | head -4
   21085 total
    1478 tests/test_ledger.lua
    1251 modules/Browser.lua
    1096 modules/LedgerTable.lua
```

against `docs/automated-tests/RESULTS.md:127-129`, which still records **1402**, **1358** and
**1052**. Staleness of the record itself:

```
$ ls docs/automated-tests | tail -3
20260807-115101
20260825-103400
README.md
$ git log -1 --format=%ci
2026-09-03 18:27:07 +0530
```

`docs/automated-tests/RESULTS.md:41-42` — *"The four sections below describe the **current** state,
as of the newest run [`20260807-115101`]"* — and `:97-98` — *"current state as of
[`20260807-115101`]"* — both name the run **before** the newest row at `:23`. That is BL-30.

## 4 · The watch list, read as a decision record

`docs/automated-tests/RESULTS.md:101-104`: the warned-function table is a single `— | — | None.`
row. **Zero** functions are warned, so **zero** entries carry an *Accepted* disposition on that
table and anti-pattern #53's three-release clock cannot have started.

The band table (`:127-129`) carries three entries: one **Accepted**, one **Accepted for now**, one
**Already tracked as `BL-24`**. `RESULTS.md:136-141` states the clock's basis explicitly — *"every
manifest under `docs/automated-tests/` has `"release": null`"* — which is true:

```
$ grep -h '"release"' docs/automated-tests/*/manifest.json | sort -u
  "label": null, "release": null,
```

So **no disposition here has spent a release, let alone three.** Not a deviation.

On the five functions the record names at CCN 15 (`RESULTS.md:112-116`): `lizard` counts every
`and`/`or` short-circuit as a decision, and all five — `ensureFrame`, `I:Layout`,
`accumulateItemTaxonomy`, `LT:UpdateHeaderArrows`, `L:GateReason` — are dense **defaulting and
guarding**, not tangled control flow. The record says so itself and this run agrees.

## 5 · Vendored Ka0s-owned library drift

Provenance line, read from the one file the gate reads:

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md README.md
CLAUDE.md:46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.25.0 (MIT).
```

Exactly one hit, in `CLAUDE.md`; **none** in `README.md`. Diffed against **that tag**, not the
sibling's `HEAD`:

```
$ git -C ../LibKa0s archive v1.25.0 | tar -x -C /tmp/lk25
$ diff -r /tmp/lk25/LibKa0s ./libs/LibKa0s        # ship payload
$ diff -r /tmp/lk25/testkit ./tests/_kit          # vendored harness
```

**Both empty.** No anti-pattern #45 drift, no #48 partial vendoring. The harness is under `tests/`,
never `libs/`. `BankLedger.toc:29` — `libs\LibKa0s\LibKa0s.xml` — lists the single aggregate once,
last in the `# Libraries` block; no individual LibKa0s `.lua` file appears in the TOC.

## 6 · The three README / `CLAUDE.md` greps

```
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries|Credits)' README.md
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

No bundled-library inventory heading and none in the intro prose (`README.md:11-14` is a
player-facing description of what the addon records). The badge is the **bare** `![Standard](…)`
form, not wrapped in a link. Compliant on all three (`documentation-§1`, anti-patterns #58/#59).

## 7 · Line endings

```
$ test -f .gitattributes && echo present
present
$ grep -n '^\* text=auto eol=\(crlf\|lf\)' .gitattributes
26:* text=auto eol=crlf
$ grep -n '^\*\.sh text eol=lf' .gitattributes
34:*.sh text eol=lf
$ grep -c ' binary$' .gitattributes
20
```

The repo ships a `.toc`, so it is **client-bound** and CRLF is the right pin. Body compared as a
diff, not a reading — the canonical client-bound block was extracted from `line-endings-§5` and
compared against the file with its CRs stripped:

```
$ diff /tmp/canon.gitattributes /tmp/repo.gitattributes && echo IDENTICAL
IDENTICAL
```

Working-tree agreement, the `line-endings-§7` command run **as written**:

```
$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
4
```

**4** — the whole of BL-32, rolled up and not enumerated. Scope: every tracked file in the repo,
including `libs/` and the frozen bundles, since `git ls-files` is unfiltered; binaries are excluded
by the `text=unset` guard, which is what keeps this number from being the pre-v2.28.1 inflation.

## 8 · Retired `§N.M` notation

```
$ grep -rnE '§[0-9]+\.[0-9]+' --include='*.lua' --include='*.md' --include='*.toc' \
    core modules settings locales defaults tests docs *.md *.toc \
  | grep -vE '^docs/(audits|reviews|revendor|automated-tests|superpowers)/' \
  | grep -v '^tests/_kit/' | wc -l
0
```

Scope as stated at the head of this file. **Zero** hits across live source **and** live docs — the
2026-08-05 run's BL-20 (nine sites) is closed. The frozen bundles still contain the notation and
are correctly excluded; a frozen bundle is never edited.

## 9 · Packaging

```
$ for e in .luacheckrc .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
NOT IGNORED — .claude
NOT IGNORED — .superpowers
$ for e in .[!.]*; do [ -e "$e" ] || continue; grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .git
UNACCOUNTED — .pkgmeta
UNACCOUNTED — .superpowers
```

`.claude` does not exist in this repo, so its absence from the list is not a finding. `.git` needs
no row. `.superpowers` **does** exist — `.superpowers/sdd/.gitignore` is tracked — and `.pkgmeta`
is the packager's own manifest. That pair is BL-29. `.pkgmeta:5-18` is the ignore list as it
stands.

## 10 · The deviation register and the issue store

`docs/ARCHITECTURE.md:218` — `## Documented deviations`, present, with `documentation-§3`'s exact
five-column shape at `:228`. Three rows:

| Line | Rule | Decided | Read as |
|---|---|---|---|
| `:230` | `performance-§12` | 2026-08-05 | **Accepted.** Cites the committed sweep at `docs/performance.md` and issue #9. Rule unchanged in v2.38.0; `savedvariables-§4` now *forbids* declaring `BankLedgerPerfDB` under this exemption, so the row has grown stronger, not stale. |
| `:231` | `savedvariables-§2` | 2026-07-27 | **Accepted.** `savedvariables-§2` still reads *"MUST declare in `defaults/Profile.lua`"* in v2.38.0, so the row is still live. |
| `:232` | `options-ui-§12` | 2026-09-02 | **Recorded, decision open.** Its own Why says *"Not argued for — recorded because it is shipping and was not ratified."* Trigger: *"the next release, or the moment a player reports losing history."* |

No register row has a rule the standard has since changed or retired — the `audit-review-history`
graveyard check passes.

```
$ gh issue list --state all --limit 200 --json number,title,state,labels
```

12 issues, every one carrying a `state:` **and** a `severity:` label, no `[status]` title prefix
(anti-pattern #62 clean), and `docs/pending/LEDGER.md` does not exist.

| # | State | Labels | Register row? |
|---|---|---|---|
| 1, 2 | OPEN | `state:triaged`, `severity:medium` | Enhancements, not deviations — none owed |
| 3 | OPEN | `state:triaged`, `severity:low` | **This is BL-04.** Body: *"only the ARCHITECTURE ▸ Documented deviations record is missing, so the next standards-audit will re-raise BL-04 until it lands."* |
| 4 | CLOSED | `state:will-not-do` | A feature decline (currencies) — not a standard rule; none owed |
| **5** | CLOSED | `state:will-not-do` | **None, and one is owed.** Declines `MakeCloseButton`, a `standalone-windows` MUST → BL-28 |
| 6, 10 | CLOSED | `state:will-not-do` | Decline optional **library convenience surfaces** (`ConsoleCheckbox`, `RestoreAllDefaults`, `InlineButtonPair`), not standard rules — none owed |
| 7 | CLOSED | `state:will-not-do` | A defect deleted rather than ported — none owed |
| 8 | CLOSED | `state:will-not-do` | Concluded *"neither the standard nor the library has a gap"* and the addon then conformed — none owed |
| 9 | CLOSED | `state:will-not-do` | **Ratified** at `docs/ARCHITECTURE.md:230` |
| 11, 12 | CLOSED | `state:done` | Terminal |

So the inverse rule produces exactly **one** finding: issue #5. Issue #3 is the addon already
holding the other one open against itself.

## 11 · The shared subsystems — descriptors, not implementations

| Claim | Citation | Quoted |
|---|---|---|
| Core seam | `core/CoreSetup.lua:141` | `local printer = lib:New({` |
| Core skin published from the library | `core/CoreSetup.lua:112` | `NS.ApplySkin = lib.ApplySkin` |
| DebugLog descriptor | `core/DebugLogSetup.lua:60`, `:61`, `:74` | `NS.DebugLog = lib:New({` · `name  = addonName,` · `addonName = addonName,` |
| Slash descriptor | `settings/Slash.lua:197`, `:200` | `local cli = lib:New({` · `commands     = NS.COMMANDS,` |
| Command table stays the host's | `settings/Schema.lua:407` | `NS.COMMANDS = {` |
| Options: one adoption line | `settings/Panel.lua:695` | `O.RenderTabbedSchema(c, "general", GENERAL_AFTER_TAB)` |
| Landing page is the host's `buildMain` | `settings/Panel.lua:435` | `local function buildMainContent(ctx)` |
| Pool/Item/Env/Media seams | `core/PoolSetup.lua`, `ItemSetup.lua`, `EnvSetup.lua`, `MediaSetup.lua` | one `LibStub(…, true)` lookup each |

**Stub coverage is proven mechanically rather than by reading.** `tests/test_libka0s.lua:213`,
`:575`, `:904` and the Options case each load the seam file **twice** — once with the vendored
library in front of it and once without — and compare the two namespaces with
`T.assertSurfaceParity`, so the degraded arm is the branch that actually runs and never a
hand-written table. `tests/test_libka0s.lua:443-444` additionally asserts the **live** instance
carries members the stub deliberately does not (`CopyText`, `ConsoleCheckbox`), which is the
"naming members only the real instance has" check. The Options stub is load-completing rather than
member-answering, which is the documented exception and is not flagged.

No hand-rolled console, widget-maker, dispatcher or test framework exists in `core/`, `modules/` or
`settings/`; `libs/LibKa0s/` is unpatched (§5). Anti-patterns #47 and #48 are clean.

## 12 · Media

```
$ find media -type f
media/logos/bankledger.logo.256.jpg
media/logos/bankledger.logo.jpg
media/logos/bankledger.logo.png
media/logos/bankledger.logo.tga
media/screenshots/…  (7 files)
```

Logo and screenshots only — no `fonts/`, `icons/` or `textures/` duplicating
`libs/LibKa0s/media/`. Anti-pattern #63 clean; the JetBrains Mono copy the seam file's header
describes as removed (`core/MediaSetup.lua:9-14`) is indeed gone.

`core/MediaSetup.lua:1` — `local addonName, NS = ...` — and the file passes that **first vararg**,
not a frame prefix, a `## Title` or a literal, exactly as `library-stack-§8` requires; its header
at `:17-25` says why. The seam loads before `core/Constants.lua`, whose `C.FONT_MONO` resolves at
load, and `BankLedger.toc` annotates that position as load-bearing.

The close-button grep, run as written:

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
modules/Export.lua:362:    local close = NS.Browser:MakeCloseButton(tbar, function() frame:Hide() end)
modules/Browser.lua:98:function B:MakeCloseButton(parent, onClick)
modules/Browser.lua:1047:  local close = B:MakeCloseButton(titleBar, function() B:Hide() end)
modules/SessionWindow.lua:485:    local close = NS.Browser:MakeCloseButton(titleBar, function() SW:Hide() end)
```

One factory and three calls to it — **no** direct `lib.MakeCloseButton(...)`, no
`Core.MakeCloseButton(...)`, no `NS.DebugLog.MakeCloseButton(...)`. Anti-pattern #65 does **not**
apply. The factory is the addon's own rather than the mandated wrapper, and
`core/CoreSetup.lua:117` — *"`lib.MakeCloseButton` IS DELIBERATELY NOT REPUBLISHED"* — is the
decision, made in a code comment and issue #5 and nowhere in the register. That is BL-28.

There is no perf panel `decorate` hook in this addon, so that check is inapplicable.

## 13 · Options panel content — the nine checks

| Check | Result | Evidence |
|---|---|---|
| (a) every page draws a strip | **Pass** | `settings/Panel.lua:695` renders General through `O.RenderTabbedSchema`; the only other page is the landing page (`:435`, `O.SetMainBuilder`), which `options-ui-§5` mandates in exactly that shape and which is exempt. No untabbed-renderer fallback and no early return past the strip. |
| (b) first tab is `Master controls`, rows canonical | **Pass** | `settings/Schema.lua:150-256`: `S.MASTER_SPEC` is handed to `O.MasterControls`, which emits the canonical set and splices it at the head of `S.Schema` (`:250`). Not frameless — `SetMovable(true)` at `modules/Browser.lua:1007`, `modules/SessionWindow.lua:449`, `modules/Export.lua:347` — so every frame row applies and none is legitimately omitted. |
| (b′) the visibility migration | **Not owed** | `defaults/Global.lua:45-48`: *"`visibility` is a DROPDOWN … this addon never shipped a 'show only in combat' checkbox, so there is no stored value to migrate and SCHEMA_VERSION is unmoved."* No boolean ever occupied that path, so `NS.SCHEMA_VERSION` correctly does not move. |
| (c) class-colour companion | **Inapplicable** | `grep -rn 'widget = "Color"\|ColorPicker\|classColorSource' settings/ modules/ core/` → no hits. No color row exists. |
| (d) `disabledIf` on a color row | **Pass** | `grep -rn 'disabledIf' settings/` → no hits. |
| (e) ordering is a drag | **Inapplicable** | `grep -rn 'ScrollUp-Up\|ScrollDown-Up\|MoveUp\|MoveDown' settings/ modules/ core/` → no hits. No user-ordered stored array. |
| (f) shared-media composers | **Inapplicable** | `grep -rn 'LSM30_' settings/ modules/ core/` → no hits. No font/border/bar group ships. Tabs mixing control types carry `subgroup` headings (`settings/Schema.lua:81`, `:88`, `:107`, `:114`). |
| (g) one chrome block, not boxed twice | **Pass** | The General page declares no page-wide control inside a `group`; the Defaults button is the host's footer control (`settings/Panel.lua:670`, `defaultsButton = true,`). The `InlineGroup` at `:74` and the `SimpleGroup`s at `:250`/`:287`/`:290`/`:315`/`:385` are all **scroll** content inside a tab, never a second band around the chrome. |
| (h) wrapped-strip geometry | **Not verifiable here** | The number is the vendored library's, and re-auditing `libs/LibKa0s/` is out of scope for this repo — it is audited in its own. Recorded as **not run**, not as a pass. No page in this addon currently wraps: six tabs on one strip. |
| (i) secondary strip | **Pass** | `settings/Panel.lua:360-400`: the Filters sub-strip is an ordinary scroll child (`scroll:AddChild(host)`), its selection is `ctx.activeSubTab[FILTERS_TAB]` — **session state, never persisted** — kept per primary tab and healed when stale. No third level: no strip inside a secondary tab, and `subgroup` is used for headings within a tab, not to fake one. |

## 14 · Documentation shape, measured

```
$ ls docs/*.md
docs/ARCHITECTURE.md   docs/common-tasks.md  docs/compat-layer.md  docs/data-flow.md
docs/insights.md       docs/media.md         docs/midnight-quirks.md docs/module-map.md
docs/performance.md    docs/schema.md        docs/scope.md         docs/settings-panel.md
docs/slash-dispatch.md docs/smoke-tests.md   docs/test-cases.md    docs/testing.md
docs/windows.md
```

(a) **Tier 1** — all six present under exactly the canonical names. (b) **Tier 2** — three present
with fired triggers, four carrying a *Not applicable* row with its trigger at
`docs/ARCHITECTURE.md:194-197`; each row's assertion was checked against the code: 4 distinct
messages (threshold >10), the profile namespace unused, no debug surface beyond the library console
plus two `/bl debug` verbs, and the ratified `performance-§12` exemption. **No false "Not
applicable"**. (c) `## Documentation map` at `:169` covers all 17 live `.md` files in exactly one
of four tables, with the five frozen directories named once each; **no orphan, no dangling row**.
(d) **No non-canonical filename holds Tier 1/2 content** — `windows.md`, `insights.md` and
`media.md` are genuine Tier 3 subjects, filed as such at `docs/ARCHITECTURE.md:210-216`; `testing.md`,
`smoke-tests.md`, `test-cases.md` and `performance.md` are the trio's and the
verification-and-record members' own mandated names. (e) **No retired doc**: no `file-index.md`, no
`conventions.md`, no `complexity.md`, no `docs/perf-runs/`. (f) **Hub shape** — 236 lines, all ten
mandated sections present, the largest (`## Settings Schema`, `:45-77`) is 33 lines and has spilled
to `schema.md`.

## 15 · TOC field order and position annotations

`BankLedger.toc:1-14` matches `toc-file-§1`'s block in order, field for field. `X-Curse-Project-ID:
1629058` is a real published id (`README.md:4` renders the CurseForge version badge against the
same project), so `toc-file-§1`'s unpublished carve-out does not apply and the field is correctly
present.

Position annotations in `# Core`, checked against the seam files rather than trusted: `ItemSetup`
(`core/Constants.lua` builds quality labels through `NS.Item.QualityLabel` at load) and
`MediaSetup` (`C.FONT_MONO` resolved from `NS.MediaFont` at load) are annotated **load-bearing and
say what resolves**; `CoreSetup` names `NS.PREFIX` and the file-scope `local print = NS.Print`
upvalues; `OptionsSetup` names `settings/Panel.lua`'s file-scope capture. `EnvSetup` and
`PoolSetup` are annotated as **conventional**, and reading them confirms it — nothing resolves at
load beyond the `LibStub` lookup. Both halves of `toc-file-§5` are met.
