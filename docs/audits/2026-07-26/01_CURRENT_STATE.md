# 01 · Current state — 2026-07-26

**Run type:** scaffold audit at birth. Ka0s Bank Ledger was created by `/wow-addon:new-addon`
against the Ka0s WoW Addon Standard **v2.10.0** and the context pack **v2.6.0**, both fetched at
scaffold time. This bundle is the frozen record of what shipped as v0.1.0 and what was left open.

## Identity

| Field | Value |
|---|---|
| Folder | `BankLedger/` (PascalCase) |
| TOC Title | `Ka0s Bank Ledger` |
| Author | add1kted2ka0s |
| Version | 0.1.0 |
| Interface | `120007` (single latest-Retail line) |
| SavedVariables | `BankLedgerDB` |
| Slash | `/bl`, alias `/bankledger` |
| Chat tag | `\|cff00ffff[BL]\|r` |
| License | MIT |
| Substrate | Ace3 |

## Layout

The single modular layout, as required — `core/ defaults/ settings/ locales/ modules/`, plus
`libs/ media/ tests/ docs/`. Twenty first-party Lua files, none over 700 LOC (the cap is ~1500).

```
BankLedger.toc  README.md  CLAUDE.md  LICENSE  .luacheckrc  .pkgmeta
core/     Compat · Constants · Namespace · State · Util · BankLedger · Database
defaults/ Global
locales/  enUS · PostLoad
modules/  Filters · Ledger · Browser · LedgerTable · Insights · Export · DebugLog
settings/ Schema · Slash · Panel
libs/     11 vendored libraries, committed
media/    fonts/ (JetBrains Mono + OFL) · logos/ · screenshots/
tests/    run · loader · wow_mock · 12 suites
docs/     agent-context · ARCHITECTURE · testing · smoke-tests · test-cases · audits/
```

## Verification at time of writing

| Gate | Result |
|---|---|
| `lua tests/run.lua` | **277 passed, 0 failed, 277 total** |
| `luacheck .` | **0 warnings, 0 errors in 20 files** |
| `docs/test-cases.md` | Generated from `--list`, in sync at 277 |
| README `[tests]` badge | `277/277`, in lockstep with the inventory |
| README `[wow]` badge | `Midnight_12.0.7`, in lockstep with the TOC Interface |

## Standards reference (documentation-§6)

All four places present:

1. TOC `## X-Standard:` → the standards repo.
2. README standard badge, linked.
3. `CLAUDE.md` → `## Standards compliance (read first)`.
4. `docs/agent-context.md` → the conform rule as the first `## Hard rules` bullet, pointing back to
   the `CLAUDE.md` section.
