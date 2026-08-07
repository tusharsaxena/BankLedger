# Automated test records

Every run of the four out-of-game suites, recorded. The normative rules are the standard's
[`automated-tests`](https://github.com/tusharsaxena/WowAddonStandards/blob/master/standards/standards/automated-tests.md)
section; this file is the local how-to.

## Running

```sh
tests/_kit/run-automated-tests.sh                            # all four, writes a bundle
tests/_kit/run-automated-tests.sh --suite complexity          # a subset
tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle   # the green gate; writes nothing
```

The runner is **vendored** from `LibKa0s`'s `testkit/` and is byte-identical in every Ka0s addon.
Never edit `tests/_kit/` — a kit fix goes upstream and is re-vendored, and a local patch is reverted
silently by the next re-vendor.

## What gates, and what only records

There are **two checkpoints**, and a suite's answer differs between them. A verdict quoted without
its checkpoint reads as "this one gates nothing", which is false of the tag.

| Suite | Command | Gates the run and the commit? | Gates the tag? |
|---|---|---|---|
| `lint` | `luacheck .` | **yes** (`testing-§4`) | **yes** |
| `tests` | `lua tests/run.lua` | **yes** (`testing-§4`) | **yes** |
| `perf` | `lua tests/perf.lua` | no — recorded only | **yes** |
| `complexity` | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | no — recorded only | **yes**, plus zero functions above CCN 15 |

`perf` and `complexity` are **measured, recorded and diffed — never used to fail a run and never
used to block a commit.** A threshold that fails a run teaches everyone to reach for `--no-verify`,
after which the gate protects nothing and the habit remains. They contribute `amber`, which is a
signal rather than a stop.

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
`manifest.json` the release run writes — not by this runner, whose exit code is unchanged. At that
checkpoint a `skip` is **NOT EVALUATED** rather than a pass.

**A missing tool is a skip, not a failure**, and the skip is recorded with its reason — so a green
run that measured nothing cannot be mistaken for a green run that measured everything.

## What is here

- **`RESULTS.md`** — one row per run across all four suites, plus the current complexity watch list.
  **One file, overwritten in place**: the git history of that single path is the trend line.
- **`<YYYYMMDD-HHMMSS>/`** — one frozen bundle per run: `manifest.json`, one file per suite that
  actually ran, and `ANALYSIS.md` (the write-up). A skipped suite leaves no artifact, so today's
  bundles carry no `perf.txt`. Bundles are **never edited** once written and **never pruned**.

Offline perf records live in the bundle with the run that produced them. **In-game** captures cannot
be produced by a script — a human runs the `perf` verb in a live client and exports the record — so
they keep their own standing store at `docs/perf-analysis/`. **BankLedger ships neither, and that is a
ratified state rather than a gap**: it holds a recorded `performance-§12` no-combat-path exemption
(the register row is in [`../ARCHITECTURE.md`](../ARCHITECTURE.md#documented-deviations), the sweep
that earns it is [`../performance.md`](../performance.md)), so there is no `tests/perf.lua`, no
`perf` verb registration and no `docs/perf-analysis/` — which is why every `perf` cell in `RESULTS.md`
reads `skip`. The skip is still said out loud, in the release notes as well as here: a skip is never
a pass, and the reason to name is the exemption, not the bare absence of the file.

**A known limit of the vendored runner, recorded rather than patched:** it writes the first of
`automated-tests-§3`'s two sanctioned `perf` skip reasons — "no `tests/perf.lua`" — and has no way to
write the second, the `performance-§12` exemption, which is the more informative one and the one that
applies here. `tests/_kit/` is vendored and is never edited in an addon repo; the fix belongs
upstream in LibKa0s's `testkit/`.
