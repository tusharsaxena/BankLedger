# BankLedger — Per-tab filter views Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.

**Goal (owner request 2026-10-07, same as LootHistory P11):** filter settings are per tab: History and Insights each keep their own live filter state and saved view; Save/Reset/Clear act on the active tab only.

**Rulings:** per-tab LIVE state (switching tabs loads that tab's state into the shared filter bar); storage `profile.savedViews = { History = view, Insights = view }`; the old `profile.savedView` migrated by a new schema step (copy into both slots, remove old key; walk stored profiles raw as BankLedger's existing profile steps do; idempotent; the stamp default stays 0 — BankLedger's BANKLEDGER-R-02 lesson). Save/Reset/Clear operate on the active tab. Document the change in BankLedger docs (browser/filter docs, schema.md, profiles doc if any, smoke-tests.md).

## Global Constraints
BankLedger's CLAUDE.md and the Ka0s WoW Addon Standard (any NEW deviation: STOP, BLOCKED). Owner explicitly asked for this change (commits on branch `feat/2026-10-07-autocomplete-typesubtype` are authorized; never push/merge). Gate via ka0s-bounded (`lua tests/run.lua`, `luacheck .` 0/0), regenerate docs/test-cases.md, CRLF restore after commits, files ≤ 1500 lines.

## Review Focus
1. Save/Reset/Clear on each tab touch only that tab. 2. Tab switching restores each tab's live state exactly. 3. Migration from savedView → both slots; none → nothing; idempotent.

### Task 1: Per-tab live state and saved views; migration; Save/Reset/Clear per tab
**Files:** `modules/Browser.lua` (TABS at ~200, SelectTab ~217, view save/reset/clear/apply ~606-680), `modules/LedgerTable.lua`, `modules/Insights.lua` (reads its own tab state), `core/Database.lua` (append a migration step), `defaults/Profile.lua` (~22 savedView comment/default), tests, docs. Requirements as Rulings; tests for every Review Focus item. Commit: `feat(browser): per-tab filter views; Save/Reset/Clear act on the active tab`.
