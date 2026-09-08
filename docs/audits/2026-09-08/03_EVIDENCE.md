# 03 · Evidence — Ka0s Bank Ledger — 2026-09-08

Every citation below was re-read at `40c4f86` before it was written here, and the cited text is
quoted beside it. Every count is the output of a recorded command, and each command's **scope** —
what it swept and what it did not — is stated with it. No figure in this bundle was carried over
from an earlier one.

---

## 0 · The standard was resolved before anything was measured

```
$ curl -fsSL "$RAW/standards/STANDARDS.md" -o STANDARDS.md && head -1 STANDARDS.md
# Ka0s WoW Addon Standard (v2.39.0, 2026-09-07)
```

All **26** files linked from `## Sections` were fetched with one `curl -fsSL --parallel` run and
read; `AUDIT.md` and `standards/ADDONS.md` with them. `standards/tiered-layout.md` 404s — it is a
historical name that appears only in the changelog, not in the Sections list.

**Which sections v2.39.0 actually changed**, diffed against a verbatim v2.38.0 copy of the same 26
files taken on 2026-09-07:

```
$ for f in *.md; do diff -q "$OLD/$f" "$f" >/dev/null && echo "SAME $f" || echo "CHANGED $f"; done
CHANGED: anti-patterns, audit-review-history, automated-tests, documentation, layout,
         library-stack, line-endings, lint, localization, open-evolutions, options-ui,
         packaging, slash-commands, standalone-windows, toc-file        (15)
SAME:    architecture, compat, debug-logging, events-frames-taint, naming-cheatsheet,
         performance, preview-mode, public-api, savedvariables, testing, versioning-git  (11)
```

Fifteen, as the changelog claims. This is the list the register's second MUST is resolved against
below.

---

## 1 · Lint — `luacheck .`

```
$ luacheck .
Total: 0 warnings / 0 errors in 61 files
```

**Scope, read off the config before the `0/0` was quoted.** `.luacheckrc:10`:

```lua
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }
```

That is **byte-identical to `lint`'s v2.39.0 template**, including the narrowing to `tests/_kit/`.
The test tree is **in** scope — 61 files, against 24 before `M4-11` — and the 33 files under
`tests/` are linted like any other. `tests/_kit/` is the one exclusion, and it is the vendored kit
linted in `LibKa0s` as source.

The harness global is in the stanza, not at the top level. `.luacheckrc:70-72`:

```lua
files["tests/"] = {
  globals = { "_G.BL_TEST" },
}
```

There is **no top-level `ignore`** (`.luacheckrc:12` says so in as many words: *"NO TOP-LEVEL
`ignore`, and none is coming back (lint-§1, `M4-11`)"*), and the 12 `files[...]` stanzas at
`:104-148` each name one file and one variable in luacheck's `<code>/<variable>` form. Nothing is
turned on behind a blanket.

Neither perf entry is present, which is what `lint`'s last bullet requires of an addon holding a
recorded `performance-§12` exemption: no `debugprofilestop` in `read_globals:34-55`, no
`BankLedgerPerfDB` in `globals:56-61`.

## 2 · Tests — `lua tests/run.lua`

```
$ lua tests/run.lua | tail -1
849 passed, 0 failed, 0 skipped, 849 total
```

**Zero skips**, which matters because `testing-§11`'s vendored-payload gate skips when the sibling
checkout is absent. It is present here, so both cases genuinely ran. Cases visible in the run tail
that this audit depends on:

```
PASS  every deviation id the register cites is assigned by a bundle in docs/audits/
PASS  LibKa0s-Options degraded: the stub carries the live surface the addon reaches
PASS  eol: every tracked file carries the terminator .gitattributes declares for it
```

`docs/test-cases.md` carries **849** entries (`grep -c '^- '`), and `README.md:7` reads
`![Tests](https://img.shields.io/badge/Tests-849%2F849_passing-green)`. Badge, inventory and run
agree (`testing-§5`).

Kit revision, at `tests/_kit/framework.lua:20`: `Kit.VERSION = 15`.

## 3 · Vendored Ka0s-owned library — the two diffs

Provenance, read from `CLAUDE.md:46`:

> `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT).`

Diffed against the **tag the line names**, not against the sibling's `HEAD`:

```
$ git -C ../LibKa0s archive v1.27.0 LibKa0s testkit | tar -x -C /tmp/lk
$ diff -r /tmp/lk/LibKa0s  ./libs/LibKa0s     # → empty
$ diff -r /tmp/lk/testkit  ./tests/_kit       # → empty
```

Both **empty**. Scope: whole folders, every module, not only the ones this addon wires. The sibling
repo is present at `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s` and `v1.27.0` resolves to
`bf97b65`, so neither check is a "not run".

`libs/LibKa0s/*.lua` counts **14** files — the corrected v2.39.0 inventory (ten majors across
fourteen files), `OptionsCompose.lua` included. The TOC lists the aggregate once:

> `BankLedger.toc` — `libs\LibKa0s\LibKa0s.xml`

and no individual `LibKa0s` `.lua`. Neither anti-pattern **#45** nor **#48** applies.

### The three provenance greps

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT).

$ grep -n 'Bundles \[LibKa0s\]' README.md                     # → no hits
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md
                                                              # → no hits
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

The badge is the **bare** form, not `[![Standard](…)](…)`. Anti-patterns **#58** and **#59** both
clear. `README.md` has no `## Credits` section at all, and its intro prose (`:11-19`) names no
library.

## 4 · Line endings

```
$ test -f .gitattributes && echo PRESENT
PRESENT
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes
26:* text=auto eol=crlf
$ grep -n '^\*\.sh text eol=lf$' .gitattributes
34:*.sh text eol=lf
$ grep -c ' binary$' .gitattributes
20
```

(b) is correct for a repo that ships Lua to the client: `BankLedger.toc` exists and `libs/` is a
client-bound payload. (c) is present, which is the carve-out mandatory in both kinds — and this
file is not the near-miss `line-endings-§1` names, because the pin sits above it.

**§5, as a diff and not a reading.** `wc -l .gitattributes` is **81**, the client-bound canonical
length:

```
$ diff <(head -n 81 .gitattributes | sed 's/\r$//') <canonical-client-bound-body>   # → empty
$ sed -n '82,200p' .gitattributes                                                   # → nothing
```

Body byte-identical, tail empty. No `# --- line-endings-§5 appendix ---`, and — correctly — no
register row written for one.

**(e), the one that fails in practice, run as written:**

```
$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
0
```

**0.** Scope: the **whole tracked set**, `libs/`, `tests/_kit/`, `media/` and every frozen bundle
under `docs/` included — `git ls-files` with no filter. Corroborated independently:

```
$ git ls-files --eol | grep -E 'w/(lf|mixed)' | grep -v '\.sh$' | wc -l
0
$ git ls-files --eol | grep '\.sh$'
i/lf    w/lf    attr/text eol=lf        tests/_kit/run-automated-tests.sh
```

**`BL-32` is closed.** The 2026-09-07 bundle reported **4** against the same command; that bundle is
frozen and is not edited to match. And (e) has an owner here: `line-endings-§7`'s vendored gate
`tests/_kit/test_eol.lua` exists at kit revision 15 and reports green in §2's run — so this is a
repo where the gate and the audit agree, not one where a green gate is hiding strays.

## 5 · Packaging

```
$ for e in .luacheckrc .pkgmeta .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
NOT IGNORED — .claude

$ for e in .[!.]*; do [ -e "$e" ] || continue
    grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .git
```

Both results are **compliant**. `.claude` prints from list (a) because that list is a fixed
enumeration and **no `.claude` directory exists at this root** — `ls -a` returns `.git`,
`.gitattributes`, `.luacheckrc`, `.pkgmeta`, `.superpowers` and nothing else. `.pkgmeta:22` says so
explicitly: *"There is deliberately no .claude line, because no such directory exists at this root,
and naming one that does not is how the identical filing was rejected in two sibling repos this
cycle."* `.git` is the one entry the packager never sees.

The two lines `BL-29` asked for are present. `.pkgmeta:9`:

> `  - .pkgmeta    # packager configuration: consumed before the zip is built, of no use inside it`

`.pkgmeta:22`:

> `  - .superpowers   # untracked; listed under packaging.md:28`

`grep -n externals .pkgmeta` returns only `:3`, a comment saying libs are vendored **not** fetched as
externals.

## 6 · Complexity — measured, with the standard's exact invocation

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
     14669       6.0     2.0       47.5     2188            0      0.00    0.00
No thresholds exceeded (cyclomatic_complexity > 15 …)
```

Max CCN, extracted from the same run: **15**, at
`accumulateItemTaxonomy@247-278@./core/Database.lua`. Re-read at `core/Database.lua:247`:

> `local function accumulateItemTaxonomy(A, e, dir)`

`lizard` counts every `and`/`or` short-circuit as a decision; this function's 15 is dense
**defaulting and bucketing** over an entry's fields, not tangled control flow, so it warns on nothing
and sits exactly at the release gate's ceiling rather than over it.

**Drift against the latest bundle.** `docs/automated-tests/RESULTS.md:26` is the newest row:

> `| [`20260908-181253`](20260908-181253/) | 1.0.0 | 0/0 | 59 | 844/0/844 | skip | 14455 | 2181 | 6.0 | 2.0 | 15 | 0 | **green** |`

| Figure | Recorded `20260908-181253` | Measured today | Δ |
|---|---|---|---|
| Tests | 844 / 0 / 844 | 849 / 0 / 849 | +5 |
| NLOC | 14 455 | 14 669 | +214 |
| Functions | 2 181 | 2 188 | +7 |
| Lint files | 59 | 61 | +2 |
| Max CCN | 15 | 15 | — |
| CCN warnings | 0 | 0 | — |

**How stale the stamp dates it.** The bundle's manifest records
`"sha": "14c86de9c028a88d61e1155db2b95bd4d70f111f"`; `git log` puts three commits after it —
`2242ac9` (`M5-08`), `de47bb9` (`M4c-06`) and the merge `40c4f86`. `M4c-06` is where the +2 lint
files and most of the +5 cases came from. **This is not filed as a deviation**: `automated-tests-§6`
puts the checkpoint at **release** and MUST NOTs gating commits on the bundle, and
`git tag` shows one tag, `1.0.0-release`, at `ad8ded7` (2026-07-28) — before this section was
adopted at `6f5a843`. No release has happened since, so nothing is overdue.

**Band drift: none.** The three on-notice files measured today are exactly the three the watch list
records, at exactly the recorded line counts:

```
$ for f in $(git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/'); do
    n=$(wc -l < "$f"); [ "$n" -ge 1000 ] && echo "$n $f"; done | sort -rn
1478 tests/test_ledger.lua
1251 modules/Browser.lua
1096 modules/LedgerTable.lua
```

Scope: **every authored `.lua` the repository tracks**, `tests/` included — the scope `layout-§1`
now states — with `libs/` and `tests/_kit/` the two carve-outs. **0 over the 1500 cap.**

**Artifact audit.** `tests/_kit/run-automated-tests.sh` is committed `100755`
(`git ls-files -s` → `100755 f6cd8b0 0`). `docs/automated-tests/README.md` and `RESULTS.md` both
exist. **No `docs/complexity.md`** (retired v2.19.0) and **no `docs/perf-runs/`** (retired v2.29.0).

## 7 · The watch list read as a decision record

```
$ grep -h '"release"' docs/automated-tests/*/manifest.json | sort | uniq -c
      8   "release": null,
$ for c in $(git log --format=%h -- docs/automated-tests/RESULTS.md); do
    echo "$c $(git show $c:docs/automated-tests/RESULTS.md | grep -c '\*\*Accepted')"; done
55d4a36 2 | 66d5edf 2 | 49bfe22 2 | b19f8ec 2 | d0b47c6 2 | b85652e 2 | e1c82df 1 | …
```

Three entries in the band table, two of them **Accepted** (`modules/LedgerTable.lua`,
`tests/test_ledger.lua`), one **already tracked as `BL-24`** (`modules/Browser.lua`) — which is one
of the three dispositions `automated-tests-§4` sanctions, and its citation
`docs/audits/2026-08-04/02_DEVIATIONS.md` resolves.

The two Accepted entries have carried that disposition across **6 consecutive runs**. Anti-pattern
**#53**'s counter is *"three consecutive **release** runs"*, and all eight manifests read
`"release": null` — **zero** release runs — so the clock has not started. Not filed. The list is
three rows long and readable in one pass, and not every entry reads "accepted", so neither collective
failure shape applies either.

## 8 · The recorded-deviation register — all three `audit-review-history` MUSTs

`docs/ARCHITECTURE.md:218` — `## Documented deviations`. Five rows, at `:230`–`:234`.

### MUST 1 — read first, record matches as accepted

Done before anything was filed. `BL-07`, `BL-11`…`BL-17`, `BL-04`, `BL-28` and `BL-34` are recorded
as accepted in `02_DEVIATIONS.md` and are **not** in the MUST tally.

### MUST 2 — report any row whose cited rule the standard has since changed

Resolved mechanically against the §0 diff:

| Row | Rule file | Changed in v2.39.0? | Verdict |
|---|---|---|---|
| `:230` | `performance-§12` | **No** — `performance.md` byte-identical | Row live, unchanged |
| `:231` | `savedvariables-§2` | **No** — `savedvariables.md` byte-identical | Row live, unchanged |
| `:232` | `localization-§1` | File changed, but **only at §5** (headers at `:11/:36/:41/:71/:118`; the diff hunk starts at `:169`) | §1 and §3 untouched; row live |
| `:233` | `standalone-windows` | **Yes** | **Reported — see below** |
| `:234` | `options-ui-§12` | File changed, but **only at §1 and §16** (diff hunks at `:53-61` and `:364-370`; §12 begins at `:237`) | §12 untouched; row live |

**The one reportable row is `:233`.** v2.39.0 rewrote `standalone-windows` so that a reasoned decline
of the close-button wrapper is a **terminal compliant state on four conditions**, where v2.38.0 had
one bullet MUSTing the wrapper and the next bullet MAYing a host control. The change makes the
behavior the row records **permitted outright** — which is exactly the case this MUST exists to
surface. The row is **not** retired, for two reasons: the fourth of the four conditions is *"A row in
the addon's `docs/ARCHITECTURE.md` deviation register"*, so the row is now part of what compliance
consists of rather than a record of non-compliance; and the amended section names this repository by
path — *"`BankLedger/modules/Brows…`"* in condition 3, and *"BankLedger holds the only live decline
in the collection"* — so retiring it would remove the one artifact the standard points at.

### MUST 3 — evaluate every trigger against the tree, resolve every evidence id

| Row | Trigger | Evaluated against the tree | Fired? |
|---|---|---|---|
| `performance-§12` | first `OnUpdate`, repeating ticker, or in-combat handler doing real work | `grep -rn 'SetScript("OnUpdate"' core modules settings locales defaults` → **0 hits**. `grep -rn 'C_Timer' …` → 2 hits, both `C_Timer.After` one-shots (`core/ItemSetup.lua:67`, `core/BankLedger.lua:103-104`); no `NewTicker`, no `ScheduleRepeatingTimer`. | **No** |
| `savedvariables-§2` | the first per-profile setting | `defaults/` holds `Global.lua` only; the sole `profile` mention in it is `:5`, a comment. | **No** |
| `localization-§1` | the first non-English locale file in `locales/` | `ls locales/` → `enUS.lua`, `PostLoad.lua`. | **No** |
| `standalone-windows` | any of the four conditions ceasing to hold | All four re-verified — see §9. | **No** |
| `options-ui-§12` | re-check at the next release, or a player report | `git tag` → `1.0.0-release` only, at `ad8ded7` (2026-07-28), which **predates** the row's 2026-09-02 decision. | **No** |

**Evidence ids, resolved one by one:**

| Cited | Resolves to |
|---|---|
| `docs/performance.md` (`:230`) | Exists; `:38-39` name both `C_Timer.After` sites, and `:39` cites `core/ItemSetup.lua:67` — the file the timer is **actually** in, corrected by `M4-24`. |
| issue **#9** (`:230`) | `gh issue list` → CLOSED, `state:will-not-do`, *"Adopt `LibKa0s-Perf-1.0` and wire a performance harness"*. |
| `locales/enUS.lua:6` (`:232`) | `NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })` — the key-returning fallback the row claims. |
| `locales/enUS.lua:8-13` (`:232`) | `:8` — *"v1.0.0 ships English-only: no user-facing string routes through NS.L yet…"*; block ends `:13`. |
| issue **#3** (`:232`) | OPEN, `state:triaged` — **and that is `BL-39`**: the row it asks for now exists. |
| `BL-04` in `docs/audits/2026-09-07/` (`:232`) | `02_DEVIATIONS.md` of that bundle assigns it. |
| `core/CoreSetup.lua:117-129` (`:233`) | `:117` — *"`lib.MakeCloseButton` IS DELIBERATELY NOT REPUBLISHED, and this paragraph is here so the next"*; `:129` — *"passes `addonName`. That is where the \"tell the library which folder is asking\" argument actually"*. The paragraph runs one line past the cited range (it ends `:130`), which is a range end, not a wrong line. |
| `modules/Browser.lua:98` (`:233`) | `function B:MakeCloseButton(parent, onClick)` |
| `modules/Browser.lua:104` (`:233`) | `local path = NS.Icon and NS.Icon("close")` |
| `modules/Browser.lua:1047` (`:233`) | `local close = B:MakeCloseButton(titleBar, function() B:Hide() end)` |
| `modules/SessionWindow.lua:485` (`:233`) | `local close = NS.Browser:MakeCloseButton(titleBar, function() SW:Hide() end)` |
| `modules/Export.lua:362` (`:233`) | `local close = NS.Browser:MakeCloseButton(tbar, function() frame:Hide() end)` |
| issue **#5** (`:233`) | CLOSED, `state:will-not-do`, *"Adopt LibKa0s-Core-1.0 window chrome (`SKIN`, `ApplySkin`, `MakeCloseButton`)"*. |
| `BL-28` in `docs/audits/2026-09-07/` (`:233`) | Assigned there. |

Every id resolves. The suite pins this too:
`PASS  every deviation id the register cites is assigned by a bundle in docs/audits/`.

### The inverse rule — a decline with no register row

Every closed `state:will-not-do` issue was read for a declined **standard rule** with no row:

```
$ gh issue list --state all --limit 200 --json number,title,state,labels
```

15 issues; 7 closed `state:will-not-do`. Two of them — **#5** and **#9** — decline a standard rule and
**both now have rows**. The other five decline a *feature* or a *library surface*, not a rule:
**#4** (currencies out of scope), **#6** (`D:ConsoleCheckbox()` — the label/tooltip would change a
user-visible string and bypass the `sessionOnly` schema row), **#7** (`LIST_GROUP_ORDER` deleted
rather than ported), **#8** (which concludes *"neither the standard nor the library has a gap here …
BankLedger was simply not conforming"* — and the code was fixed), **#10** (three library surfaces
declined on design grounds). None of those five is a deviation from a MUST or a SHOULD, so none owes
a register row. **Nothing is filed under the inverse rule this run.**

`docs/pending/LEDGER.md` does not exist, and neither does `docs/pending/`. No issue title carries a
`[status]` prefix (anti-pattern **#62** clear); every one of the 15 carries a `state:` label and a
`severity:` label.

---

## 9 · `BL-38` — the close-button count

**The grep, run as `AUDIT.md` writes it:**

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
modules/Export.lua:362:    local close = NS.Browser:MakeCloseButton(tbar, function() frame:Hide() end)
modules/Browser.lua:98:function B:MakeCloseButton(parent, onClick)
modules/Browser.lua:1047:  local close = B:MakeCloseButton(titleBar, function() B:Hide() end)
modules/SessionWindow.lua:485:    local close = NS.Browser:MakeCloseButton(titleBar, function() SW:Hide() end)
```

**One host factory, three callers.** No two-argument `lib.MakeCloseButton(...)`, no
`Core.MakeCloseButton(...)`, no `NS.DebugLog.MakeCloseButton(...)` outside `libs/` — anti-pattern
**#65** does not apply. The four `libs/` hits are the library's own (`Core.lua:234`,
`DebugLog.lua:75-76`, `PerfPanel.lua:191`), and the four `tests/` hits exercise the host factory.

**The fourth window is the library's.** `modules/Export.lua:252-263`:

```lua
copyWindow = W.CopyWindow({
  addonName = addonName,
  name      = "BankLedgerExportCopyWindow",
  ...
})
```

No `makeCloseButton` key is passed, and `libs/LibKa0s/Widgets.lua:475-480` shows the field is optional
and *"Defaults to Core's x"*. So the copy window's close is Core's, drawn with this addon's folder
name — the library's control on the library's window, condition 1 exactly.

**The four decline conditions, each verified:** (1) host windows only — the three above; (2) the same
catalog mark — `modules/Browser.lua:104`, `local path = NS.Icon and NS.Icon("close")`, with the
fallback ladder beneath it, and `tests/test_marks.lua:76` asserts `btn.icon.__texture == ICONS ..
"close"`; (3) exactly one host factory — the grep; (4) the register row — `docs/ARCHITECTURE.md:233`.
**Nothing is filed against the decline.**

**The seven sites that contradict it**, each re-read and quoted:

| Site | Quoted |
|---|---|
| `core/CoreSetup.lua:119` | `` -- `B:MakeCloseButton`, 24x24, class-coloured on hover — and all four of its title bars (ledger, `` |
| `core/CoreSetup.lua:126` | `-- seam that no window reaches reads as coverage of those four title bars while covering nothing a` |
| `core/MediaSetup.lua:86` | `` ---   close          modules/Browser.lua  B:MakeCloseButton — all four title bars `` |
| `docs/media.md:46` | `` \| `close` \| `B:MakeCloseButton` — the ledger, session, export-modal and export-copy title bars \| … `` |
| `docs/module-map.md:14` | ``…all four of this addon's title bars go through `modules/Browser.lua`'s own `B:MakeCloseButton`…`` — then, in the same cell, *"The library draws its own close control on the windows that are the library's"* |
| `tests/test_marks.lua:71` | `-- ── the close control: one edit, four title bars ──…` |
| `tests/test_marks.lua:98-101` | case name *"…so one edit reached all four title bars"*; `:99-100` — *"The ledger window, the session window and **both export popups** all reach the close control through B:MakeCloseButton."* |
| `tests/test_libka0s.lua:63` | `-- factory: all four of its title bars go through modules/Browser.lua's own B:MakeCloseButton,` |

Eight lines across seven sites; `core/CoreSetup.lua` carries two and `tests/test_marks.lua` carries
two, which is why the row says seven sites and this table lists eight rows.

## 10 · `BL-35` — the British-spelling gate

The gate is `localization-§5`'s two published lists, **copied whole**, with `ALLOWED` removed as
whole words before the `BRITISH` substrings are scanned — the order the section mandates.

**Scope, stated.** The file set is:

```
$ git ls-files '*.lua' '*.md' '*.toc' \
  | grep -v '^libs/' | grep -v '^tests/_kit/' \
  | grep -v '^docs/audits/' | grep -v '^docs/reviews/' \
  | grep -v '^docs/revendor/' | grep -v '^docs/superpowers/' \
  | grep -vE '^docs/automated-tests/[0-9]{8}-'
84
```

**84 files swept.** Excluded, each named as `localization-§5` requires rather than inferred from a
pattern: vendored code (`libs/`, `tests/_kit/`), which this repo MUST NOT edit; and the frozen dated
bundles (`docs/audits/`, `docs/reviews/`, `docs/revendor/`, `docs/superpowers/`, and the eight
`docs/automated-tests/<stamp>/` run folders), which are the record and are not rewritten. There is
no `locales/enGB.lua` to exclude, and no file in this repo whose subject is this rule.

**Result: 62 hits in 21 files.**

```
16 docs/smoke-tests.md      11 tests/test_marks.lua        6 docs/media.md
 3 modules/LedgerTable.lua   3 modules/Export.lua          2 tests/wow_mock.lua
 2 tests/test_panel.lua      2 settings/Panel.lua          2 modules/Browser.lua
 2 docs/module-map.md        2 docs/midnight-quirks.md     2 core/Util.lua
 1 each: tests/test_util.lua, tests/test_mock.lua, tests/test_itemsetup.lua,
         tests/test_envsetup.lua, tests/test_browser.lua, modules/SessionWindow.lua,
         docs/test-cases.md, core/ItemSetup.lua, core/CoreSetup.lua
```

By term: `colour` 31, `centre` 18, `labelled` 6, `recognis` 2, `behaviour` 2, `normalis` 1,
`neighbour` 1, `catalogue` 1. No hit is a Blizzard symbol, a quoted external string or a published
proper noun, so none falls under `localization-§5`'s four exceptions.

**The one player-visible hit**, re-read in place. `settings/Panel.lua:677-679`:

```lua
      defaultsTooltip = "Restore every Bank Ledger setting to its default, clear the item "
        .. "blacklist and whitelist, and recentre the ledger and session windows at their default "
        .. "size. Your recorded history is never touched.",
```

and four lines above it, `settings/Panel.lua:674`:

> `-- windows (a storage carve-out, not a schema row) and recenters them. A tooltip that promised`

The comment spells it US-correct and the string a player reads does not. Every other hit is a comment
or `docs/` prose.

**No gate exists in this repo to have caught it**: `grep -rn -i 'BRITISH' tests/*.lua` returns
nothing.

## 11 · `BL-36` — the unannotated load-bearing position

The dependency, both ends re-read:

- `modules/InsightsWidgets.lua:2` — `NS.InsightsWidgets = NS.InsightsWidgets or {}`
- `modules/Insights.lua:5` — `local W = NS.InsightsWidgets`

A file-scope upvalue of a table an earlier file creates, which is `toc-file-§5`'s own definition of a
load-bearing position. The TOC's `# Modules` block, quoted whole:

```
# Modules (Filters before Ledger — the capture gate reads the lists)
modules\Filters.lua
modules\Ledger.lua
modules\Browser.lua
modules\LedgerTable.lua
modules\SessionWindow.lua
modules\InsightsWidgets.lua
modules\Insights.lua
modules\Export.lua
```

The group comment names a different pair and neither of these two lines carries one.

**The denominator, enumerated.** File-scope `local … = NS.*` / `LibStub(…)` bindings across all 28
authored source files were listed and each traced to the file that publishes it. The load-bearing
positions and their annotations:

| Position | Annotated? |
|---|---|
| `libs\LibKa0s\LibKa0s.xml` | Yes — *"every module but Core resolves LibKa0s-Core-1.0 through LibStub before it registers…"* |
| `core\ItemSetup.lua` | Yes — *"BEFORE core\Constants.lua, which builds the quality-threshold labels at file load through NS.Item.QualityLabel — so this position is load-bearing, not conventional."* |
| `core\MediaSetup.lua` | Yes — *"C.FONT_MONO is RESOLVED from NS.MediaFont at load…"* |
| `core\CoreSetup.lua` | Yes — *"before every file that takes NS.Print as a load-time upvalue…"* (6 such files: `modules/Browser.lua:6`, `modules/LedgerTable.lua:5`, `settings/Schema.lua:5`, `settings/Slash.lua:4`, `settings/OptionsSetup.lua:20`, `settings/Panel.lua:4`) |
| `core\DebugLogSetup.lua` | Yes — *"After Constants (FONT_MONO…) and after CoreSetup (NS.LIBKA0S_MISSING)."* |
| `settings\OptionsSetup.lua` | Yes — *"BEFORE settings/Panel.lua, which captures the instance at file scope"* (`settings/Panel.lua:14`, `local O = NS.Helpers`) |
| `modules\Insights.lua` after `modules\InsightsWidgets.lua` | **No** |

Two conventional positions are also marked, which satisfies the SHOULD: `core\EnvSetup.lua`
(*"Nothing here resolves at load beyond the LibStub lookup, so … this position is conventional"*) and
`core\PoolSetup.lua` (*"…take NS.Pool at call time, so this is conventional rather than
load-bearing"*).

**Not filed:** `core\Constants.lua`, `core\Database.lua` and the module lines binding
`local C = NS.Constants` at file scope. Their positions are pinned by the annotated lines above them
and by the `#`-section ordering, which is exactly the shape `toc-file-§5`'s worked example calls
compliant — *"a rule that made every line restate its neighbor's comment would be noise the next
reader learns to skip."*

## 12 · `BL-37` — the composer counts

The stub, re-read at `settings/OptionsSetup.lua:192`:

> `    MasterControls = function() return {}, function() end end,`

Hollow, as `options-ui-§1` now requires; `:181-182` explains that four sibling composers are
unreached on that arm and stubbed anyway. `tests/test_surface_parity.lua:197` —
`T.assertSurfaceParity(degraded.Helpers, "LibKa0s-Options-1.0", IGNORE)` — pins the member set by
name against the live surface.

The counts the missing case would carry:

```
$ grep -cE '^\s*\{ *path *= *"' settings/Schema.lua
9
```

9 host-declared `path`-bearing rows, plus the one renderer-only `Filters` row
(`settings/Schema.lua:258-265`, *"ONE ROW, NOT TWO"*) = **10** on the library-absent arm.
`docs/settings-panel.md:35` records the fully-loaded strip:

> `| General | **Master controls** · **Capture** · **Interface** · **History** · **Filters** | 6 · 4 · 4 · 1 · 1 |`

= **16**, so the delta is **6**, all of them `H.MasterControls`'s, spliced at
`settings/Schema.lua:248-252`.

What the suite pins today is the fully-loaded arm only —
`tests/test_schema.lua:276` (*"Schema: Master controls is the FIRST tab, and holds exactly the
canonical rows"*), with `:294` asserting `#got == #want` over the six canonical paths at `:284-288`.
`grep -rn 'loadDegraded' tests/*.lua` returns 22 sites, none of them counting schema rows.

**The fall-together property holds**, which is what bounds the exemption: the load that loses
`LibKa0s-Options-1.0` loses `LibKa0s-Slash-1.0` in the same breath (both come from the one vendored
`LibKa0s.xml`), so there is no path from which a composed row is addressable-but-missing. And
`settings/Schema.lua:250` merges `S.MASTER_DECOR` onto the composed rows while
`defaults/Global.lua:49-62` carries every composed default in the addon's own defaults table —
`:50-51` says why: *"a composed row with no default here is a path that reads nil forever."* Profile
defaults are not read off the schema.

## 13 · The `docs/` tier model, measured

**(a) Tier 1 — all six present**, under exactly the canonical names:
`docs/{scope,module-map,schema,settings-panel,data-flow,common-tasks}.md`.

**(b) Tier 2 — every trigger evaluated against the code:**

| Doc | Trigger, measured | State |
|---|---|---|
| `slash-dispatch.md` | `NS.COMMANDS` at `settings/Schema.lua:407` holds **15** verbs (threshold 8) | Present |
| `midnight-quirks.md` | `core/Compat.lua` carries client-version workarounds | Present |
| `compat-layer.md` | `grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` → **13** (new threshold: 3) | Present |
| `message-bus.md` | `grep -rhoE 'SendMessage\("[^"]+"' … \| sort -u \| wc -l` → **4** (threshold >10) | *Not applicable* row, trigger stated |
| `profiles.md` | no profile control ships; `options-ui-§3` is a MAY | *Not applicable* row |
| `debug.md` | `/bl debug`, `on`, `off`, `panel`, `scan` all route through `NS.DebugLog` | *Not applicable* row |
| `perf-analysis/README.md` | the ratified `performance-§12` exemption | *Not applicable* row, in `### Conditional` |

The `compat-layer.md` count is exactly the figure `documentation-§3` itself quotes for this repo —
*"`BankLedger/core/Compat.lua` (175 lines, 13 shims)"* — and `wc -l core/Compat.lua` is **175**.

**(c) `## Documentation map`** at `docs/ARCHITECTURE.md:169`, four tables in order: `### Required` at
`:175`, `### Conditional` at `:187`, `### Verification and record` at `:199`, `### Addon-specific` at
`:210`. The fourth holds exactly six rows — `testing.md`, `smoke-tests.md`, `test-cases.md`,
`performance.md`, `automated-tests/README.md`, `automated-tests/RESULTS.md` — and
`perf-analysis/README.md` is **not** among them; it sits in `### Conditional`, correctly.

Coverage, counted both ways:

```
$ git ls-files 'docs/*.md' | grep -vE '^docs/(audits|reviews|revendor|superpowers)/' \
  | grep -vE '^docs/automated-tests/[0-9]{8}-' | wc -l
19
```

19 live `.md` files; the four tables hold 7 + 3-present + 6 + 3 = 19 rows for existing files, plus
four *Not applicable* rows. No orphan, no dangling row. `grep -rn -i 'three tables\|fourth table'
docs/*.md` returns nothing, so there is no stale justification note to delete. The hub's self-row is
present and is **not filed in either direction**, per the v2.39.0 MAY.

**(d) Non-canonical filenames:** none. `windows.md`, `insights.md` and `media.md` are genuinely Tier
3 addon-specific and are registered as such. No `data-model.md`, `saved-variables.md`, `pipeline.md`,
`settings-system.md`, `wow-quirks.md`, `slash-commands.md` or `debug-console.md`.

**(e) Retired docs:** `ls docs/file-index.md docs/conventions.md docs/complexity.md docs/perf-runs`
→ four *No such file or directory*.

**(f) Hub shape:** `wc -l docs/ARCHITECTURE.md` → **238**. Longest mandated section, measured by
`awk` over the `## ` headings: `## Documentation map` at 48 lines. Nothing near either guide.

## 14 · Retired `§N.M` notation

```
$ while IFS= read -r f; do grep -HoE '§[0-9]+\.[0-9]+' "$f"; done < <the 84-file live set> | wc -l
0
```

Scope: the same 84 live authored files as §10 — **including every live `docs/` page**, which is the
sweep an earlier collection audit under-reported by omitting. Frozen bundles are excluded by design
and are not edited.

## 15 · The remaining `options-ui` content checks

- **(a) tab strip per page** — one registered page (`settings/Panel.lua:666`), rendered through
  `O.RenderTabbedSchema` at `:695`. The landing page is `O.SetMainBuilder` at `:655`, which
  `options-ui-§13` exempts by name. No Profiles page. **Pass.**
- **(b) `Master controls` first** — `tests/test_schema.lua:293`: `assertEqual(S:PageRows()[1].group,
  "Master controls", "Master controls must be the FIRST tab")`, and `:284-288` pins the canonical
  order `settings.enabled`, `settings.visibility`, `settings.windowScale`, `settings.alpha`,
  `settings.locked`, `state.debugConsole`, with reset-position and reset-all in the composer's
  closing tail. The frame-only rows apply because `SetMovable(true)` is called at three sites, named
  at `tests/test_schema.lua:278`. **The migration question is answered in place**, at
  `defaults/Global.lua:53-55`: *"`visibility` is a DROPDOWN, not a boolean, and it starts life as
  one: this addon never shipped a 'show only in combat' checkbox, so there is no stored value to
  migrate and SCHEMA_VERSION is unmoved."* **Pass, nothing owed.**
- **(c)/(d) color rows** — `grep -n 'type *= *"color"' settings/*.lua` → no hits;
  `grep -n 'disabledIf' settings/*.lua` → no hits. `settings/OptionsSetup.lua:87` records the absence
  deliberately. **Inapplicable, not deviant.**
- **(e) reorder** — `grep -rn 'ScrollUp-Up\|ScrollDown-Up\|MoveUp\|MoveDown' settings/ modules/` → no
  hits. **Inapplicable.**
- **(f) media groups** — `grep -rn 'LSM30_Font\|LSM30_Border\|LSM30_Statusbar' settings/ modules/
  core/` → no hits, so the finder finds nothing and there is no hand-written block and no broadcast
  meta row to audit against §16's five bounds. **Inapplicable.**
- **(g) chrome block** — the only `InlineGroup` under `settings/` is `settings/Panel.lua:74`, the
  store-grid control **inside the scroll**, not a box around band controls. Anti-pattern **#72** does
  not apply. No page-wide control is declared inside a `group`; there is no instance picker, because
  there is one page. **Pass.**
- **(h) wrapped-strip geometry** — this lives in the vendored library and the vendored copy is
  byte-identical to `v1.27.0`, so it is the `LibKa0s` repo's to audit. Read anyway:
  `libs/LibKa0s/OptionsWidgets.lua:411` — *"So the pitch is measured ONCE, from the INACTIVE cap
  atlas, on a throwaway texture"* — and `:436-455` returns it cached, which is the shape
  `options-ui-§13` requires. `:634` notes the same rule for the wrap index. **No addon-side finding.**
- **(i) secondary strip** — `docs/settings-panel.md:37-40` records it and the code agrees: a
  secondary strip inside `Filters`, selection kept as `ctx.activeSubTab["Filters"]` — per primary
  tab — and session-only, never written to the profile. No third level. **Pass.**

## 16 · Degradation stubs

Eight seams, each a silent `LibStub(…, true)` lookup with a library-absent branch:

```
core/CoreSetup.lua:37       LibStub("LibKa0s-Core-1.0", true)
core/DebugLogSetup.lua:21   LibStub("LibKa0s-DebugLog-1.0", true)
core/EnvSetup.lua:39        LibStub("LibKa0s-Env-1.0", true)
core/ItemSetup.lua:26       LibStub("LibKa0s-Item-1.0", true)
core/MediaSetup.lua:45      LibStub("LibKa0s-Media-1.0", true)
core/PoolSetup.lua:20       LibStub("LibKa0s-Pool-1.0", true)
settings/OptionsSetup.lua:26 LibStub("LibKa0s-Options-1.0", true)
settings/Slash.lua:133      LibStub("LibKa0s-Slash-1.0", true)
```

Four stub-parity cases run green in §2, one per member-answering stub. The **Options** stub is the
documented exception — load-completing rather than member-answering — and is **not** flagged.
`settings/OptionsSetup.lua:181-182` writes the reason down for the members it deliberately omits,
which `AUDIT.md` says to read before raising: *"`S:ComposeMaster` is the only caller, and it runs…"*.

## 17 · Shared media

- **No private copy.** `media/` holds `logos/` and `screenshots/` only. `core/MediaSetup.lua:9-15`
  records that the JetBrains Mono copy and its OFL were deleted when the payload arrived.
  Anti-pattern **#63**'s first shape clear.
- **No one-off marks.** `grep -rn 'SetAtlas' core modules settings` → no hits. The `Interface\`
  paths that remain are Blizzard stock — `Buttons\WHITE8X8` (3 sites),
  `ChatFrame\UI-ChatIM-SizeGrabber-*` (2 windows), `Icons\inv_misc_bag_15` (the minimap button,
  matching the TOC's `IconTexture`) — plus `core/Constants.lua:230`'s own logo `.tga`. No catalog
  entry is being re-drawn locally.
- **The seam is fed the folder name.** `core/MediaSetup.lua:109` —
  `if Media then Media.RegisterLSM(addonName) end` — one call, using the file's **own first
  vararg** (`:1`, `local addonName, NS = ...`), not a constant that happens to match. It loads before
  `core\Constants.lua`, annotated in the TOC.
- **The console was told.** `core/DebugLogSetup.lua:74` — `addonName = addonName,` — with `:61`
  carrying `name = addonName` for the frame names. `debug-logging-§13` satisfied.
- **No perf panel decorate hook** to audit: the harness is unwired under the exemption.

## 18 · Reconciled figures

Every number that appears in more than one artifact of this bundle, checked to agree:

| Figure | Value | Appears in |
|---|---|---|
| Headline roots | 5 | `02` tally, `02` summary table, `05` step count |
| Total incl. dependents | 5 | `02` tally |
| MUST failures | 4 | `02` tally, `05` |
| British hits / files | 62 / 21 | `02` BL-35, `03` §10, `04`, `05` |
| BL-38 sites / lines | 7 / 8 | `02` BL-38, `03` §9, `04`, `05` |
| Composed delta | 16 / 10 / 6 | `02` BL-37, `03` §12, `04`, `05` |
| EOL strays | 0 | `01`, `02` BL-32, `03` §4 |
| Tests | 849 | `01`, `03` §2, badge, inventory |
| NLOC / functions | 14 669 / 2 188 | `01`, `03` §6 |
| Register rows | 5 | `01`, `02`, `03` §8 |
