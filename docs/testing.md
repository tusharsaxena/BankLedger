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
  line endings. Renormalise whichever side drifted. It is **never** an edit to `libs/`, and
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
- [ ] **Reconcile `docs/agent-context.md` whenever the Ka0s WoW Addon Standard's minor version
      moves.** The file started as the standard's context pack but is now **specialized to Bank
      Ledger** (a recorded deviation — see ARCHITECTURE ▸ *Documented deviations*), so it must
      **not** be re-dropped wholesale: that would erase the specialization. Instead `curl` the
      current `standards/NEW_ADDON_CONTEXT.md`, diff it against this file, and port the **changed
      rules** by hand, leaving the Bank Ledger specifics in place. This is the recurrence guard for
      audit deviation BL-08.

## Local toolchain

WoW runs Lua 5.1, so the harness targets 5.1.

```sh
sudo apt-get update && sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck
```

Syntax-check a single file with `luac -p path/to/file.lua`.

## How the harness works

```
tests/
  _kit/              -- VENDORED from LibKa0s (testkit/). Never edited here — see The vendor gate.
    framework.lua    --   the registry, the assertions, the runner and the --list renderer
    loader.lua       --   loadfile + setfenv over the mock env, and Loader.tocFiles
    mock_base.lua    --   the universal half of the WoW-API mock, shared across the collection
    README.md
  run.lua            -- the load list, the lifecycle kick and the suite list — nothing else
  wow_mock.lua       -- Bank Ledger's extender over _kit/mock_base.lua (a fresh env per run)
  test_<module>.lua  -- one suite per module
  test_harness.lua   -- the harness's own guard rail (suite list, TOC order)
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
  `_kit/mock_base.lua`, and **overrides ten of the base's behaviours** — each one documented in the
  file's header with the suite that depends on it. Those overrides are deliberate divergence, not
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

Test-first: write or extend a **failing** test that pins the intended behaviour, then implement
until it passes. Pure, testable logic — the snapshot diff, the capture gate, schema read/write,
filters, queries and aggregation, CSV serialization, the debug formatters and the slash output
shape — is exercised headlessly. Genuinely in-client behaviour (frame rendering, taint, drag and
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
