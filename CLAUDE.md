# CLAUDE.md — Ka0s Bank Ledger

**Ka0s WoW addon.** Adheres to the **Ka0s WoW Addon Standard** —
https://github.com/tusharsaxena/WowAddonStandards

## Standards compliance (read first)

This repo is built to the **Ka0s WoW Addon Standard**
(https://github.com/tusharsaxena/WowAddonStandards). All development here — features, refactors,
doc changes — MUST conform to it. The standard is the source of truth for layout, TOC shape, the
Ace substrate, schema-driven settings, slash/prefix conventions, locales, Compat, tests/lint, and
doc structure.

**If a change would deviate from the standard, STOP and flag the deviation explicitly.** Do not
silently deviate and do not silently "fix" to match. Surface it and let the user decide which of
two things it is:

1. **An accepted deviation** — this addon intentionally differs; record it as a row in
   `docs/ARCHITECTURE.md` → `## Documented deviations`, shaped
   `| Rule | What differs | Why | Decided | Re-check trigger |`, where Rule is the `filename-§N`
   reference. That register is the single home: the reasoning may live in the issue-audit GitHub
   issue or an audit bundle and the row cites it, but a deviation not in the register is not ratified.
2. **A change to the standard itself** — the standard's definition should evolve; the update
   belongs upstream in the WowAddonStandards repo, after which this addon conforms to the new rule.

When in doubt, treat standard conformance as a hard requirement and ask.

Start here, then read the docs:

- **`docs/ARCHITECTURE.md`** — what this addon is: the at-a-glance facts, module map, load order,
  data model, settings schema, message bus, slash surface, event wiring, windows, taint notes,
  documented deviations, known limitations.
- **`docs/testing.md`** — how to verify: the headless harness, lint, the green commit gate, and the
  release-time complexity checkpoint.
- **`DEPENDENCIES.md`** (root) — what to install to build, run, test or release this addon, with
  WSL2/Ubuntu commands and a verification line per tool (documentation-§7).
- **`docs/performance.md`** — what this addon costs, and why it wires no performance harness: the
  committed sweep behind its ratified `performance-§12` no-combat-path exemption.
- Topic detail in `docs/` — **Tier 1 is always present**: `scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`, `data-flow.md`, `common-tasks.md`. Conditional and addon-specific docs vary; `docs/ARCHITECTURE.md` → `## Documentation map` lists every page under `docs/` and says which conditional ones do not apply here (`documentation-§3`).

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0). Never auto-stage/commit/
push and never bump the version without an explicit instruction.

## Vendored LibKa0s — the provenance line

Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.25.0 (MIT).

That line is the single answer to "which LibKa0s does this build carry?", and it is machine-read:
`tests/test_vendor_sync.lua` greps it out of **this file** (kit revision 9 moved it here from
`README.md`, which is player-facing and no longer carries a library inventory) and compares both
vendored payloads — `libs/LibKa0s/` and `tests/_kit/` — against that tag in the sibling LibKa0s
checkout. There is no fallback to `README.md`.

So the tag named above **moves in the same commit as the vendored bytes**, never before and never
after. Re-vendor, edit this line, regenerate `docs/test-cases.md`, then run the green gate.

## The `docs/` set — there is no `agent-context.md`

The canonical `docs/` set is exactly three files: **`ARCHITECTURE.md`** (what this addon is),
**`testing.md`** (how to verify) and **`smoke-tests.md`** (in-game checks) — plus the generated
`test-cases.md` and the topic-detail docs.

**`docs/agent-context.md` does not exist in this repo and MUST NOT be created.** The standard
deleted it in **v2.17.0**; shipping it is **anti-pattern #49**. It held `NEW_ADDON_CONTEXT.md` —
the scaffolding pack — which is fetched at runtime and never stored: a copy in the repo describes
the addon on the day it was born, forever, and because it loads as *working context* a stale copy
does not go quiet, it gets **followed** (documentation-§3). This root `CLAUDE.md` is the repo's
only agent brief.

Older audit bundles, review bundles and plans under `docs/` predate v2.17.0 and still
name the file, and some describe a four-file or a pre-v2.3.0 `agent-context.md`-based set. Those
are **frozen history** — never treat them as a live requirement, and never "restore" the file.
