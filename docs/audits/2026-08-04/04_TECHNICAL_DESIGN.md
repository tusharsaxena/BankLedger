# 04 · Technical design — remediation — Ka0s Bank Ledger — 2026-08-04

Designed against the **Ka0s WoW Addon Standard v2.17.1 (2026-08-03)**. Every section below is keyed
to the deviation IDs in `02_DEVIATIONS.md`. This document designs the change; it does not make it.

## Shape of the work

The fourteen findings sort into four genuinely independent tracks. Only track B has an ordering
constraint inside it, and nothing in one track blocks another.

| Track | IDs | Character | Blocked by |
|---|---|---|---|
| **A — the one-line correctness fix** | BL-18 | Production bug, user-visible, test-covered | nothing |
| **B — the perf decision** | BL-11 … BL-17 | One decision with seven downstream artifacts; needs a user ruling first | a user decision |
| **C — hygiene** | BL-19, BL-20, BL-21 | Mechanical, low risk, independently landable | nothing |
| **D — recorded, no code** | BL-07, BL-23, BL-24 | Already accepted / advisory | nothing |

---

## Track A — BL-18 · route `modules/Browser.lua` through the shared printer

### The change

`modules/Browser.lua` gains one line in its header block, beside the existing `local C =
NS.Constants` (currently `:4`):

```lua
local print = NS.Print   -- secret-safe, [BL]-prefixed shared printer (events-frames-taint-§8)
```

The two call sites (`:855`, `:864`) are then already correct and need no edit — which is the point of
the seam.

### Why this shape and not another

The alternative — rewriting the two sites as `NS.Print("…")` — resolves the printer at *call* time
rather than *load* time. That is the shape `core/DebugLogSetup.lua` deliberately uses for its
descriptor forwarders, and for a reason that does **not** apply here: those forwarders exist because
`NS.Print` is established *after* that file loads. `modules/Browser.lua` loads at
`BankLedger.toc:57`, long after `core/CoreSetup.lua` (`:41`) and after `core/BankLedger.lua` (`:48`)
has reclaimed the printer from AceConsole's embed. The load-time upvalue is therefore correct here,
is what the standard's own wording prescribes (*"each file does `local print = NS.Print`"*), and is
what every other printing file in the addon already does. Consistency across the five files is worth
more than a second idiom.

### Load-order safety

`core/CoreSetup.lua:97-98` makes `NS.Print` and `NS.Util.print` **the same function object**, and
`core/BankLedger.lua:13` repoints `NS.Print` at that same object after `NewAddon`. So a
`modules/`-level upvalue captured at load already holds the object the reclaim restores — the exact
invariant `tests/test_util.lua:143` asserts. Adding a sixth capture site does not weaken it.

### Test

`tests/test_browser.lua` gains two cases, and they must be capable of failing:

1. `B:SaveView()` emits exactly one chat line, and that line begins with `NS.PREFIX`.
2. `B:ResetView()` (no `silent`) does the same; `B:ResetView(true)` emits none.

The mock already captures chat through `DEFAULT_CHAT_FRAME:AddMessage`
(`core/CoreSetup.lua:86-87` documents that Core's default sink resolves there at call time, and
`tests/wow_mock.lua` captures it), so no mock change is needed. **Falsification:** delete the new
`local print` line and both cases must go red — record that mutation in a comment on the cases, per
`testing-§12`.

### Risk

Effectively nil. The behavior change is that two chat lines gain the `[BL]` tag and become
secret-safe. No API, no data, no saved variable, no frame.

---

## Track B — BL-11 … BL-17 · the performance decision

### This needs a ruling before any code

`CLAUDE.md:14-23` is explicit that a change which would deviate is classified by the **user** as (1)
an accepted deviation or (2) a change to the standard. The perf gap has been decided technically
(`docs/pending/LEDGER.md:65`) but never classified. All three options below are legitimate; they
differ in cost and in what they leave for the next audit.

#### Option 1 — adopt the wiring (closes BL-11 … BL-17)

The largest change, and the one that makes the next audit clean.

**B1 · `core/PerfSetup.lua`** — new file, TOC-positioned in `# Core` **after** `core/CoreSetup.lua`
(it needs `NS.LIBKA0S_MISSING` for the shared cause clause) and **before** every module that would
take `NS.Perf` as a load-time upvalue — i.e. before `modules/Ledger.lua` (`BankLedger.toc:56`) and
`core/Database.lua` (`:49`). The natural slot is immediately after `core/DebugLogSetup.lua`.

```lua
local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)
if not lib then
  -- stub: the hot-path gate field, the sink, and whatever the slash layer touches
  NS.Perf = { on = false, Note = function() end, Command = function() return { UNAVAILABLE } end }
  return
end
NS.Perf = lib:New({ name = "BankLedger", savedVariable = "BankLedgerPerfDB", buckets = { … } })
```

The stub **must** answer every member the addon reaches — at minimum `on`, `Note`, and the command
entry point the `perf` verb calls. `performance-§1` is blunt that a stub missing one is *"a crash
moved to a rarer code path"*, and the addon already has four exemplary stubs to copy the shape from.

**B2 · Buckets.** `performance-§3` requires every declared bucket to be reached by a real bracket, and
the addon's own suite must pin that. This addon's honest bucket set is small — it has no per-frame or
combat-log path at all, which is the whole substance of the LIBKA0S-17 argument:

| Bucket | Bracket site | Why |
|---|---|---|
| `stats` | `core/Database.lua` `Database:Stats` | The 295-line single-pass aggregator; the addon's hottest read path and the one yesterday's review declined to refactor for want of evidence (`docs/reviews/2026-08-03/05_FINAL_SUMMARY.md:30-35`). |
| `reconcile` | `modules/Ledger.lua` `Reconcile` (~`:519`, `:532-536`) | The ~1600-slot rescan on a bank open. |
| `query`, `within = "stats"` | `core/Database.lua` `Database:Query` | The filtered slice `Stats` walks; nested, so `within` declares it and the totals must not be summed. |

Do **not** declare a bucket for anything that runs twice a session — `performance-§3` calls that *"a
row that will always read 0.000"*.

**B3 · `BankLedgerPerfDB`** (BL-12) — `BankLedger.toc:7` becomes
`## SavedVariables: BankLedgerDB, BankLedgerPerfDB`, in that order. The ring is the library's to
write; the addon only names it in the descriptor. It stays outside the AceDB tree by construction.

**B4 · `.luacheckrc`** (BL-14) — `debugprofilestop` into `read_globals` with the *"ms CPU clock behind
the perf brackets (performance-§2)"* comment, and `BankLedgerPerfDB` into `globals` with a comment
matching the existing `BankLedgerDB` one.

**B5 · The `perf` verb** (BL-13) — one row in `NS.COMMANDS`
(`settings/Schema.lua:226-286`), placed beside `debug`:

```lua
{ "perf", "Measure performance — try `/bl perf` for the workflow",
  function(rest) for _, line in ipairs(NS.Perf.Command(rest)) do print(line) end end },
```

The library returns lines; the host prints them through its own tagged printer
(`performance-§4`). Regenerate the README's command table in the **same** change — it is generated
from `NS.COMMANDS` and the two must not drift.

**B6 · Suspend / resume** (BL-17) — the sharpest piece, and the one with real design content.
`performance-§6` wants inertness **without a `/reload`**, enforced **at the source**:

- `modules/Ledger.lua`'s `L:Enable` (`:761`) is **not re-entrant** today. Split it into an idempotent
  `L:Arm()` / `L:Disarm()` pair over the event registrations, with `L:Enable` calling `L:Arm`.
- Add a **session-only** `State.perfSuspended` to `core/State.lua` (never persisted —
  `performance-§6` is explicit).
- Consult it **inside the show-decision ladder**, not by hiding frames: `SW:Enabled()` in
  `modules/SessionWindow.lua` and the browser's own show decision return false while suspended. The
  standard's reason is that *"hidden frames come back"* — a bank open would re-show the session window
  behind suspend's back and the suspended arm would then measure the addon still working.
- `fireSessionChanged` (`modules/Ledger.lua:477-481`) is documented as having exactly one sender
  (`:475`, architecture-§4). Suspend must **not** become a second sender; disarm should stop the
  events that lead to it rather than broadcast a synthetic session end.
- Resume rebuilds registrations from **current** state, so a setting changed while suspended comes
  back correctly.

**B7 · `tests/perf.lua`** (BL-16) — a new offline runner outside the green gate
(`testing-§7`: it must **not** be run by `tests/run.lua` and its scenarios must **not** be counted in
`--list` or the badge). It derives its load list from the TOC per `testing-§9`. Required scenario:
zero-overhead — the `stats` path with capture off allocating no more than the same path with the
instrumentation absent. Assert only call counts and bytes allocated; **never** wall-clock.

**B8 · Docs** (BL-15) — `docs/performance.md` (which paths are bracketed and why, how to run
`/bl perf`, how to read the report, and what the harness can and cannot resolve here — the
combat-window caveat from LIBKA0S-17 belongs in this doc) and `docs/perf-runs/README.md` (naming
convention `<YYYY-MM-DD>-<source>-<label>.json`, schema summary, pointer to the library's canonical
contract).

**B9 · Integration tests** (`testing-§8`) — the descriptor is well-formed; **every declared bucket is
reached by a real bracket**, driving each bucket's genuine entry point; suspend genuinely makes the
addon inert; and the degraded path verified by **actually loading with `Perf.lua` absent** from the
runner's file list, not by hand-stubbing `NS.Perf`. The addon already does exactly this for the other
three modules in `tests/test_libka0s.lua`, so the pattern is in the repo.

**Risk.** Moderate, and concentrated in B6. Splitting `L:Enable` touches the capture engine — the
addon's reason for existing — and a mistake there loses ledger entries silently. B6 should land as
its own commit with its own tests, ahead of the bracket work, and `docs/smoke-tests.md` should gain a
bank-open/close case exercising arm → suspend → resume → arm.

#### Option 2 — record it as an accepted deviation (closes nothing, settles everything)

Add one entry to `docs/ARCHITECTURE.md` ▸ *Documented deviations*, in the same shape as the BL-07
entry already there (`:567-580`): name `performance-§1` and the six sibling MUSTs, restate the
LIBKA0S-17 argument in the addon's own words, and say what would reopen it (the library growing a
non-combat window mode, or the addon acquiring a per-frame or combat-log path). Cost: one doc edit.
The next audit then reads it as accepted rather than open, exactly as BL-07 now does.

This is the option most consistent with how this repo has settled its other departures, and it does
not preclude Option 1 later.

#### Option 3 — raise it upstream

`performance`'s premise is a per-frame or combat-log hot path measured across a combat-gated A/B.
Bank Ledger has neither: there is no `OnUpdate` anywhere in the addon and its capture engine cannot
run while `UnitAffectingCombat("player")` is true. A standard whose MUST produces a report of
structural zeros for a whole class of addon is a standard with a missing case. Two shapes worth
proposing:

- a **bank-session window mode** in `LibKa0s-Perf-1.0` — an arm bounded by an addon-supplied predicate
  rather than by the player's combat state; or
- a sanctioned **N/A** in `performance-§1` for an addon that can demonstrate no combat-reachable code
  path, with the demonstration itself being the evidence.

Cost: a change in `WowAddonStandards`, and possibly in `LibKa0s`. Highest leverage across the
collection, slowest to land.

### Recommendation

**Option 2 now, Option 3 in parallel, Option 1 only if a real performance question appears.** The
adoption cost is concentrated in B6, which touches the capture engine for a report that the addon's
own analysis says would read zeros — and `performance-§3` is itself the rule that calls such a bucket
*"a lie in every report."* Recording the deviation costs one paragraph and makes the position
explicit rather than implicit-in-a-ledger-row.

---

## Track C — hygiene

### C1 · BL-19 — delegate the skin to `Core.ApplySkin`

`modules/Browser.lua:67-89` keeps its signature and its role as the addon's single re-skin seam —
`standalone-windows-§2` explicitly sanctions a host helper — but delegates its body:

```lua
function B:ApplySkin(f)
  if f.title then f.title:SetTextColor(unpack(SKIN.title)) end
  if f.divider then f.divider:SetColorTexture(unpack(SKIN.divider)) end
  local core = LibStub and LibStub("LibKa0s-Core-1.0", true)
  if core and core.ApplySkin then return core.ApplySkin(f) end
  -- library-absent fallback: the current body, unchanged
  …
end
```

Two details matter. **Resolve Core at call time**, not at load: `core/DebugLogSetup.lua:102-106`
already documents why a `core/`-or-`modules/` cross-reference must be a closure, and `ApplySkin`
first runs during a lazy window build, long after load. **Assign `frame.title` / `frame.divider`
before delegating** — `standalone-windows-§2` says `ApplySkin` tints them only if they are already
there and silently skips otherwise.

Trim `SKIN` to the fields that are genuinely the host's — `tabActive`, `tabIdle`, `titleBarH`,
`tabStripH`, `contentGap`, `defaultH`, `minH` — and drop the five (`bg`, `border`, `innerBorder`,
`divider`, `title`) that restate `Core.SKIN`, reading them off Core in the fallback branch only.

**Test.** Pin that with Core present the host helper delegates (spy on `core.ApplySkin`), and that
with Core absent the fallback still produces the five normative values. `tests/test_browser.lua`
already builds frames against the mock, so the surface exists.

**Risk.** Low but **visual**, and it touches all four windows plus the debug console (which routes
through this same seam at `core/DebugLogSetup.lua:107-109`). `docs/smoke-tests.md` should gain a case:
open the ledger window, the session window, an export popup and the debug console side by side and
confirm the two-line edge — hard black outer, lighter gray inner — reads identically on all four.

### C2 · BL-20 — fix the eight unresolvable references

Pure comment edits, no behavior. The mapping (see `02_DEVIATIONS.md` BL-20 for the reasoning):

| Site | Now | Becomes |
|---|---|---|
| `settings/OptionsSetup.lua:43` | `options-ui-§41` | `options-ui-§1` |
| `settings/Schema.lua:184` | `options-ui-§41` | `options-ui-§1` |
| `docs/ARCHITECTURE.md:106` | `options-ui-§41` | `options-ui-§1` |
| `settings/Panel.lua:58` | `options-ui-§190` | `options-ui-§11` |
| `tests/test_panel.lua:175` | `options-ui-§189` | `options-ui-§11` |
| `settings/OptionsSetup.lua:65` | `Ka0s standard §3.4` | `library-stack-§4` |
| `settings/Panel.lua:11` | `Ka0s standard §3.4` | `library-stack-§4` |
| `settings/OptionsSetup.lua:74` | `Ka0s standard §3.1` | `library-stack-§1` |

Guard against recurrence with the sweep in `03_EVIDENCE.md` §1.8; consider adding it to
`docs/testing.md`'s *Release checklist* (`:44-56`) beside the existing vendor-gate step.

**Risk.** None — comments only.

### C3 · BL-21 — generate `docs/complexity.md`

```sh
lizard core modules settings defaults locales -x "libs/*" > docs/complexity.md
```

Prepend a two-line header stating the file is generated, the exact command, and that it is
**report-only and never a gate** (`performance-§10`). `lizard` is an optional local dev tool; if it is
not installed, this stays open and is recorded as such rather than faked.

**Value here specifically.** It is the cheapest way to get a defensible answer on `modules/Browser.lua`
(BL-24) and on `Database:Stats`, both of which are currently argued about without numbers.

**Risk.** None — a new report file, ignored by `.pkgmeta`'s `- docs`.

---

## Track D — recorded, no code

- **BL-07** — already accepted and documented at `docs/ARCHITECTURE.md:567-580`. No action unless the
  user prefers Option 3 (upstream), in which case propose that `savedvariables-§2` sanction
  `defaults/Global.lua` as the sole defaults file for an addon that declares no profile tree.
- **BL-23** — either give `DOC-01` a tracking-issue link the way `DOC-03`/`DOC-04` have, or re-run
  `/wow-addon:pending-audit` so `DOC-01` closes against the ARCHITECTURE entry that has since landed.
- **BL-24** — no action. If `modules/Browser.lua` grows past ~1400, the natural peel is the
  skin/close-button factory plus the geometry persistence (`:20-107`, `:110-180`) into a sibling
  `modules/BrowserChrome.lua`, which `layout-§1` explicitly sanctions.

---

## Cross-cutting constraints

- **The green gate binds every commit.** `lua tests/run.lua` green and `luacheck .` at 0/0 before each
  one (`testing-§4`, `versioning-git`). Both are green today, so any red is this work's.
- **Whenever the suite moves, three things move together** — the suite, `docs/test-cases.md`
  (regenerated by `--list`), and the README `[tests]` badge (`testing-§5`). Never deferred.
- **`libs/` and `tests/_kit/` are read-only.** Any defect found in either is a finding to fix in the
  LibKa0s repo and re-vendor (`library-stack-§7`, `testing-§1`). The `behaviour` spelling at
  `tests/_kit/README.md:119` is exactly such a finding and **must not** be fixed here — doing so
  breaks `tests/test_vendor_sync.lua`.
- **Trunk-based.** Commit to `master`; no branch unless the user asks (`versioning-git`).
- **Version bump.** Track A is user-visible (two chat lines gain the `[BL]` tag) and Track B option 1
  is a feature, so both warrant a `## Version:` bump with a `## What's new` and Version History roll
  forward in the same change (`documentation-§1` item 5, `versioning-git`). Track C is internal and
  does not.
