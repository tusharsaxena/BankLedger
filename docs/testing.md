# Testing — Ka0s Bank Ledger

How to verify the addon. This is the contributor-facing page; the player-facing `README.md`
deliberately carries none of it, only the `[tests]` badge.

## The green gate

Both of these must pass **before every commit**. A commit with red tests or lint errors is
forbidden, and a logic change without a covering test is not done.

```sh
lua tests/run.lua     # all suites green; exits non-zero on any failure
luacheck .            # 0 errors, 0 warnings
```

### What that 0/0 is worth — the suppression gate

`luacheck .` at 0/0 only means something if the configuration is not buying the number. Until
`M4c-06` this repo's `.luacheckrc` carried `ignore = { "212/self", "212/event" }` at the top level.
It *looked* narrow -- both entries already name the variable, which is the form the rule steers
towards -- and that is exactly why it survived so long. The problem is scope, not spelling: a
top-level `ignore` reaches all 60 files however precisely it is written. `212/event` matched
**nothing at all** in this tree, so the addon was carrying a live suppression for a warning it did
not have, and the first handler to drop its event argument would have landed green.

Removing the two lines reported **119** findings, every one of them `212/self`, in 12 of the 60
files. Eighteen further suppressions were sitting inline, one per file --
`local addonName, NS = ...   -- luacheck: ignore addonName`, over a folder name the file never read.
All eighteen were fixed at source rather than moved somewhere narrower: seventeen files now open
`local _, NS = ...` (which `core/CoreSetup.lua`, `core/ItemSetup.lua` and `core/PoolSetup.lua`
already did, and why they never needed a pragma), and `locales/PostLoad.lua` -- a documented empty
seam whose body is entirely comment, reading *neither* name -- lost the header outright. **There is
now no `luacheck:` directive anywhere in this addon's own Lua.**

The 119 that remain are one shape, and it is forced rather than chosen. Every module publishes
itself as `NS.X = NS.X or {}` / `local X = NS.X` and defines its surface as `function X:Method()`;
the bodies reach the module through that file-local upvalue and through `NS`, never through the
receiver. The receiver is still load-bearing, because every call site is a colon call through the
namespace (`NS.Browser:Show()`, `NS.Schema:Set(path, v)`) -- roughly 900 of them across the addon
and the suites -- so deleting it would shift every argument one place to the left at all of them.
Each of the 12 files therefore carries a `files[...]` stanza naming that one file and that one
variable, with a comment saying which convention forces it.

That the narrowing is real was **measured, not assumed**: a method with an unread `self` added to
`core/Util.lua` and an unread `event` parameter added to `core/Compat.lua` -- two files with no
stanza -- both report under the current config, and the same tree re-linted under the old blanket
came back 0 warnings / 0 errors.

`tests/test_lintconfig.lua` is what keeps the blanket from re-entering, since re-adding one line is
trivial and noticing it is not. Four cases, all four watched red in the working tree before they
landed:

| # | The case | What it refuses |
|---|----------|-----------------|
| 1 | no top-level `ignore` | the blanket itself, however narrowly its entries are spelled |
| 2 | no wholesale class switch | `unused_args = false` and eight relatives -- the same blanket as a switch |
| 3 | every `files[...]` ignore is narrow | a stanza keyed on a *directory* whose entry names no variable |
| 4 | no bare inline `-- luacheck: ignore` | the blanket at line scope, with no code named |

It reads `.luacheckrc` **as Lua**, under a sandbox that auto-creates tables the way luacheck's own
config loader does, so it inspects the table luacheck obeys rather than text that a different
spelling would slip past. And it **fails rather than skips** when it cannot look -- no config, an
unreadable one, a chunk that will not compile, no `io.popen`, no git -- the same bargain
`test_docs.lua` and `_kit/test_eol.lua` strike. A gate that goes quiet when blinded reports success,
which is worse than not existing.

## The vendor gate

Neither green gate above can see a **stale vendored copy**. This addon carries two folders copied
verbatim out of the sibling [LibKa0s](https://github.com/tusharsaxena/LibKa0s) repo — `libs/LibKa0s/`
(the shipped library) and `tests/_kit/` (the shared test harness) — and a stale copy still passes
its own suite and still passes ours. The library's suite proves the library; ours proves the addon
against whatever copy happens to be sitting in `libs/`. Nothing compares the two but this:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s    # content — empty vs the CLAIMED tag
diff -r ../LibKa0s/LibKa0s libs/LibKa0s                        # bytes  — SHOULD be empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit      # content — empty vs the CLAIMED tag
diff -r ../LibKa0s/testkit tests/_kit                          # bytes  — SHOULD be empty
```

### When these diffs are supposed to be non-empty

They compare against the sibling checkout's **working tree** — whatever `../LibKa0s` happens to have
checked out — which is a different question from *"is the vendored payload the release this addon
claims?"*. The two questions give the same answer only while the library has tagged nothing newer
than the tag this addon has taken.

Between a library release and the re-vendor that carries it they disagree, and that disagreement is
the normal state rather than a defect — re-vendoring to quiet it would be the actual mistake, since
it would pull an untested library release for the sake of a clean diff.

It is **not** the state as this is written. `../LibKa0s` sits on **v1.31.0**,
[`CLAUDE.md`](../CLAUDE.md) names **v1.31.0**, and all four commands above come back empty, because
this addon has taken the newest tag the library has published. The next library release puts the
two back out of step, and the working-tree diffs stay non-empty until the re-vendor that carries it
lands.

**The authoritative comparison is against the tag `CLAUDE.md` names**, and that one must be empty at
every commit:

```sh
tag=$(grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' CLAUDE.md \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
rm -rf "/tmp/libka0s-$tag" && mkdir -p "/tmp/libka0s-$tag"
git -C ../LibKa0s archive "$tag" | tar -x -C "/tmp/libka0s-$tag"
diff -r --strip-trailing-cr "/tmp/libka0s-$tag/LibKa0s" libs/LibKa0s   # MUST be empty
diff -r --strip-trailing-cr "/tmp/libka0s-$tag/testkit" tests/_kit     # MUST be empty
```

`tests/test_vendor_sync.lua` asks exactly this question inside the suite — it greps the tag out of
`CLAUDE.md` and reads that blob out of git — so **a green suite has already answered it**, and the
block above is only the by-eye version for when you want to see the hunks. Which leaves the
working-tree diffs above answering a real but different question: *how far behind the library is
this addon?* That is release planning, not a gate.


**Run both of each pair and read the difference between them.**

- **Content differs** — a copy has genuinely forked. That is the forbidden state. The fix is to
  re-vendor whole-folder (`cp -r ../LibKa0s/LibKa0s/. libs/LibKa0s/`), never to edit `libs/`.
- **Content identical, bytes differ** — nothing has forked; the two checkouts merely disagree about
  line endings. Renormalize whichever side drifted. It is **never** an edit to `libs/`, and
  re-vendoring will not converge it either — that just moves the wrong endings downstream.
- **Both empty** — the vendored copies are current.

Never edit anything under `libs/` or `tests/_kit/`. A library or kit problem is a finding to fix in
`../LibKa0s` and re-vendor back; a local patch is a fork nobody knows about, and the next re-vendor
reverts it silently.

## Release checklist

Run through this before a version bump, on top of the green gate:

- [ ] `lua tests/run.lua` green and `luacheck .` at 0/0.
- [ ] `docs/test-cases.md` regenerated (`lua tests/run.lua --list > docs/test-cases.md`) and the
      README `[tests]` badge updated in the **same** change.
- [ ] **A full automated-test bundle produced and its diff read** — see below.
- [ ] **Re-read the Ka0s WoW Addon Standard whenever its minor version moves**, straight from
      [the upstream repo](https://github.com/tusharsaxena/WowAddonStandards), and fold any changed
      rule into the code and `docs/`. The standard is never copied into this repo — a stored copy
      goes stale silently and is then followed as working context (documentation-§3,
      anti-pattern #49).

## Automated test records — the consolidated run

All four out-of-game suites go through one vendored runner, and every run is recorded
(`automated-tests`):

```sh
tests/_kit/run-automated-tests.sh                            # all four, writes a bundle
tests/_kit/run-automated-tests.sh --suite complexity          # a subset
tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle   # the green gate; writes nothing
```

| Suite | Command | Gates the run and the commit? | Gates the tag? |
|---|---|---|---|
| `lint` | `luacheck .` | **yes** (`testing-§4`) | **yes** |
| `tests` | `lua tests/run.lua` | **yes** (`testing-§4`) | **yes** |
| `perf` | `lua tests/perf.lua` | no — recorded only | **yes** |
| `complexity` | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | no — recorded only | **yes**, plus zero functions above CCN 15 |

**This addon has no `tests/perf.lua`**, and that is ratified, not missing: the `performance-§12`
no-combat-path exemption in [ARCHITECTURE.md ▸ Documented deviations](ARCHITECTURE.md#documented-deviations).
The runner records the suite as a **skip with its reason**, which is not a pass — see the paragraph
below.

**There are two checkpoints, and a suite's answer differs between them** — a verdict quoted without
its checkpoint is the half-truth this table exists to end (`automated-tests-§3`, *The release gate*;
`testing-§6`).

**`perf` and `complexity` never fail a run and never block a commit.** They are measured, recorded
and diffed — a threshold that fails a run teaches everyone to reach for `--no-verify`, after which
the gate protects nothing and the habit remains. They contribute `amber`, which is a signal rather
than a stop. **A missing tool is a skip recorded with its reason**, never a pass.

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**, evaluated by
`/wow-addon:bump-version` from the release run's `manifest.json` — not by the runner, whose exit code
is unchanged. A `skip` there is **not evaluated** rather than passed: install the tool and re-run.

The runner is **vendored** from `LibKa0s`'s `testkit/`; never edit `tests/_kit/`. A kit fix goes
upstream and is re-vendored.

**At release, not at commit.** A full bundle is produced as part of every version bump, before the
tag, with an `ANALYSIS.md` write-up. **Commits** are gated on lint + tests only; the **tag** is
gated on all four, which is the whole reason the release run produces a bundle.

Results live in [`automated-tests/`](./automated-tests/): `RESULTS.md` is one row per run across all
four suites plus the current complexity watch list — **one file, overwritten in place**, so its git
history is the trend line — and each `<YYYYMMDD-HHMMSS>/` is a frozen bundle of that run's raw
output. Bundles are never edited and never pruned.

`docs/complexity.md` was this addon's standalone complexity report through standard v2.18.0; it is
**retired** — its raw output is each bundle's `complexity.txt` and its trend line is `RESULTS.md`.

## Local toolchain

WoW runs Lua 5.1, so the harness targets 5.1 — `tests/_kit/loader.lua` swaps each chunk's
environment with `setfenv`, which Lua 5.2 removed, so a newer interpreter cannot run this suite.

```sh
sudo apt-get update && sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck
```

Syntax-check a single file with `luac -p path/to/file.lua`.

The full toolchain — `lizard` (which does **not** install with `pip` on Ubuntu 24.04), `git` and the
POSIX `ls` two suites shell out to, and the Python/Pillow the logo art needs — is listed with
install and verification commands in the root [`DEPENDENCIES.md`](../DEPENDENCIES.md)
(documentation-§7).

## How the harness works

```
tests/
  _kit/                    -- VENDORED from LibKa0s (testkit/). Never edited here — see The vendor gate.
    framework.lua          --   the registry, the assertions, the runner and the --list renderer
    loader.lua             --   loadfile + setfenv over the mock env, and Loader.tocFiles
    mock_base.lua          --   the universal half of the WoW-API mock, shared across the collection
    vendor_sync.lua        --   the shared vendored-payload gate, adopted by test_vendor_sync.lua
    run-automated-tests.sh --   the consolidated four-suite runner and bundle writer
    README.md
  run.lua                  -- the load list, the lifecycle kick and the suite list — nothing else
  wow_mock.lua             -- Bank Ledger's extender over _kit/mock_base.lua (a fresh env per run)
  degraded_env.lua         -- builds a SECOND environment with libs/LibKa0s left out of the load
                           --   list, so the degradation stubs are exercised as a LOAD rather than
                           --   hand-stubbed. Not a suite, so run.lua does not list it
  test_<module>.lua        -- one suite per module
  test_harness.lua         -- the harness's own guard rail (suite list, TOC order)
  test_lifecycle.lua       -- core/BankLedger.lua's enable/disable cycle, which belongs to no
                           --   one module: the four _enabled latches released together, and
                           --   the private bus targets torn down with them
  test_marks.lua           -- the shared LibKa0s-Media marks on this addon's own windows: the PATH
                           --   and the ARGUMENT, never the appearance, and BOTH rungs of every
                           --   fallback ladder — a texture that does not load draws nothing and
                           --   raises nothing, so no other suite would notice
  test_vendor_sync.lua     -- one line of adoption over _kit/vendor_sync.lua; docs/test-cases.md
                           --   counts three cases: the two payload cases, plus the runner-mode
                           --   case kit revision 16 adds with no host change
  test_surface_parity.lua  -- the four degradation stubs against the surfaces they stand in for,
                           --   collected in one file so a fifth seam growing a stub with no case
                           --   beside it is an obvious hole (M4-09)
```

- `run.lua` builds the addon environment once by loading every source **in TOC order** — derived
  from the shipped `BankLedger.toc` through `Loader.tocFiles`, never from a second list maintained
  by hand — then calls `NS:InitDB()`, `NS.Schema:Register()` and `NS.Ledger:Enable()` to mirror the
  in-game `OnInitialize` / `OnEnable` lifecycle. It exposes `NS`, the mocks and the assertion helpers
  to the suites through `_G.BL_TEST` (built by `Kit.expose`, so no suite file changed when the kit
  was adopted), runs each case under `pcall`, and exits non-zero on any failure.
- `run.lua` also calls `Kit.setSurfaceSource` **before** `Kit.expose`, naming the live
  `LibKa0s-Options-1.0` and `LibKa0s-DebugLog-1.0` instances for `assertSurfaceParity`'s by-name
  form. `Kit.expose` would otherwise auto-wire the mock's `LibStub`, which answers the library's
  MODULE table for those names; both of this addon's by-name stubs mirror the object
  `lib:New(descriptor)` returned, so the auto-wired source reports six divergences that are all
  correct omissions. `expose` registers a source only when none is registered yet, which is what
  makes the earlier line stick.
- `_kit/loader.lua` reproduces the addon's two-vararg header by calling each chunk as
  `chunk("BankLedger", NS)` under an environment where WoW globals resolve to the mock table first
  and fall back to real `_G`. It also provides `Loader.tocFiles`, which is what removed the
  hand-maintained load list. `libs\` lines are skipped — it cannot see inside an XML — so a vendored
  library the suites need must be spelled out in `run.lua`.
  Both varargs are passed to every file; only the **seven** that actually need the addon FOLDER
  name bind the first one as `addonName` -- `core/Namespace.lua` (`NS.name`), `core/EnvSetup.lua`,
  `core/MediaSetup.lua`, `core/Database.lua` (the AceDB store name), `core/DebugLogSetup.lua`,
  `core/BankLedger.lua` (the AceAddon name) and `modules/Export.lua`. Every other file opens
  `local _, NS = ...` (`M4c-06`).
- `_kit/framework.lua` **skips** a listed suite whose file is missing rather than raising, which is
  the opposite of the old runner. `test_harness.lua` closes that hole: it asserts the suite list and
  `tests/test_*.lua` agree in both directions, so a typo is red rather than a green run with fewer
  cases.
- `wow_mock.lua` layers Bank Ledger's own container, guild-bank, item and money model over
  `_kit/mock_base.lua`, plus a short list of decisions of its own, numbered in the file's header
  with the suite that depends on each: the frame stub, frames shown by default, the no-op
  `C_Timer.After`, the defaulted-store AceDB, `__settingsPanels`, the plain-table
  `DEFAULT_CHAT_FRAME`, and the nil `StaticPopup_Show` and `GameTooltip`. Two more are documented at
  their own sites: the AceGUI `SetTitle` wrap and `LibStub.minors`. Those are deliberate
  divergence, not drift: read the header before "simplifying" one away. **The Ace fakes are the
  kit's**: AceAddon, AceEvent, AceTimer, AceConsole and AceGUI are taken from the base as they stand
  (kit revision 17; #18, #19), and nothing is layered on the addon object. The base contributes the
  piece that matters most here, a real `LibStub` with `NewLibrary`, so the vendored LibKa0s majors
  register headlessly exactly as they do in the client. Pieces of mock **fidelity** that are
  load-bearing:
  - the kit's `NewAddon` embeds exactly the three libraries `core/BankLedger.lua` lists, so
    AceConsole's `:Print` and `:Printf` clobber `NS.Print` as the real embed does and the tests
    exercise the real printer-reclaim path;
  - the kit's event half raises for a name in `mocks.__badEvents` on the event's **first**
    registrant, where retail raises, so a case that re-registers must unregister first
    (`test_ledger.lua`'s `reEnable`);
  - the kit's message bus keys callbacks by `(message, target)` and fans `SendMessage` out to every
    target, so a test can catch two receivers clobbering each other on a shared target;
  - the kit's timer queue skips a canceled entry and `mocks.__fireTimers()` answers how many ran, so
    the capture debounce is asserted as "three events, one reconcile pass";
  - the `Settings.RegisterCanvasLayout(Sub)category` fakes keep each frame they are handed in
    `mocks.__settingsPanels`, so `test_panel.lua` can assert the `OnCommit` / `OnDefault` /
    `OnRefresh` contract on what the framework actually received (options-ui-§1).

A suite reads:

```lua
local T = _G.BL_TEST
local NS = T.NS
local test, assertEqual = T.test, T.assertEqual

test("Ledger.Diff: ...", function()
  assertEqual(#NS.Ledger.Diff(before, after, "BANK"), 1)
end)
```

## Writing tests

Test-first: write or extend a **failing** test that pins the intended behavior, then implement
until it passes. Pure, testable logic — the snapshot diff, the capture gate, schema read/write,
filters, queries and aggregation, CSV serialization, the debug formatters and the slash output
shape — is exercised headlessly. Genuinely in-client behavior (frame rendering, taint, drag and
resize) belongs in [`smoke-tests.md`](smoke-tests.md), which complements rather than replaces the
unit suites.

## The case inventory

[`test-cases.md`](test-cases.md) is the **generated**, authoritative enumeration of every case and
the addon's authoritative pass count. Never hand-edit it. Whenever a case is added, removed or
renamed — or the count moves — regenerate it and update the README's `[tests]` badge **in the same
change**:

```sh
lua tests/run.lua --list > docs/test-cases.md
```

There is no CI. This is deliberately local and hand-run.
