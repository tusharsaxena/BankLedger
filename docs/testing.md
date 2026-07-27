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
  run.lua            -- the runner + micro-framework; also the --list inventory mode
  loader.lua         -- loads each source with loadfile + setfenv over the mock env
  wow_mock.lua       -- the WoW API mock builder (a fresh env per run)
  test_<module>.lua  -- one suite per module
```

- `run.lua` builds the addon environment once by loading every source **in TOC order**, then calls
  `NS:InitDB()`, `NS.Schema:Register()` and `NS.Ledger:Enable()` to mirror the in-game
  `OnInitialize` / `OnEnable` lifecycle. It exposes `NS`, the mocks and the assertion helpers to the
  suites through `_G.BL_TEST`, runs each case under `pcall`, and exits non-zero on any failure.
- `loader.lua` reproduces the `local addonName, NS = ...` header by calling each chunk as
  `chunk("BankLedger", NS)` under an environment where WoW globals resolve to the mock table first
  and fall back to real `_G`.
- `wow_mock.lua` stubs time, player, world, container, item and money APIs, plus a universal
  self-returning no-op frame. Two pieces of mock **fidelity** are load-bearing and must not be
  simplified away:
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
