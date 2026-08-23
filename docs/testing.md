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

## The vendor gate

Neither green gate above can see a **stale vendored copy**. This addon carries two folders copied
verbatim out of the sibling [LibKa0s](https://github.com/tusharsaxena/LibKa0s) repo — `libs/LibKa0s/`
(the shipped library) and `tests/_kit/` (the shared test harness) — and a stale copy still passes
its own suite and still passes ours. The library's suite proves the library; ours proves the addon
against whatever copy happens to be sitting in `libs/`. Nothing compares the two but this:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s    # content — MUST be empty
diff -r ../LibKa0s/LibKa0s libs/LibKa0s                        # bytes  — SHOULD be empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit      # content — MUST be empty
diff -r ../LibKa0s/testkit tests/_kit                          # bytes  — SHOULD be empty
```

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
  test_<module>.lua        -- one suite per module
  test_harness.lua         -- the harness's own guard rail (suite list, TOC order)
  test_marks.lua           -- the shared LibKa0s-Media marks on this addon's own windows: the PATH
                           --   and the ARGUMENT, never the appearance, and BOTH rungs of every
                           --   fallback ladder — a texture that does not load draws nothing and
                           --   raises nothing, so no other suite would notice
  test_vendor_sync.lua     -- one line of adoption over _kit/vendor_sync.lua; the case names are
                           --   unchanged, so docs/test-cases.md counts the same two cases
```

- `run.lua` builds the addon environment once by loading every source **in TOC order** — derived
  from the shipped `BankLedger.toc` through `Loader.tocFiles`, never from a second list maintained
  by hand — then calls `NS:InitDB()`, `NS.Schema:Register()` and `NS.Ledger:Enable()` to mirror the
  in-game `OnInitialize` / `OnEnable` lifecycle. It exposes `NS`, the mocks and the assertion helpers
  to the suites through `_G.BL_TEST` (built by `Kit.expose`, so no suite file changed when the kit
  was adopted), runs each case under `pcall`, and exits non-zero on any failure.
- `_kit/loader.lua` reproduces the `local addonName, NS = ...` header by calling each chunk as
  `chunk("BankLedger", NS)` under an environment where WoW globals resolve to the mock table first
  and fall back to real `_G`. It also provides `Loader.tocFiles`, which is what removed the
  hand-maintained load list. `libs\` lines are skipped — it cannot see inside an XML — so a vendored
  library the suites need must be spelled out in `run.lua`.
- `_kit/framework.lua` **skips** a listed suite whose file is missing rather than raising, which is
  the opposite of the old runner. `test_harness.lua` closes that hole: it asserts the suite list and
  `tests/test_*.lua` agree in both directions, so a typo is red rather than a green run with fewer
  cases.
- `wow_mock.lua` layers Bank Ledger's own container, guild-bank, item and money model over
  `_kit/mock_base.lua`, and **overrides ten of the base's behaviors** — the first ten decisions are numbered in the
  file's header with the suite that depends on each — number 8, AceGUI, being a deliberate
  *non*-override, taken from the base as it stands — and the eleventh, the AceGUI `SetTitle`
  wrapper, is documented at its own site. Those overrides are deliberate divergence, not
  drift: read the header before "simplifying" one away. The base contributes the piece that matters
  most here, a real `LibStub` with `NewLibrary`, so the vendored LibKa0s majors register headlessly
  exactly as they do in the client. Pieces of mock **fidelity** that are load-bearing:
  - the AceAddon mock stamps AceConsole's colliding `:Print` mixin, so the tests exercise the real
    printer-reclaim path;
  - the message bus keys callbacks by `(message, target)` and fans `SendMessage` out to every
    target, so a test can catch two receivers clobbering each other on a shared target;
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
