# 05 · Execution plan — 2026-07-26

Ordered, each step independently committable on a green gate.

| # | Deviation | Action | Repo | Blocks release? |
|---|---|---|---|---|
| 1 | BL-05 | Add the Bank Ledger row to `standards/ADDONS.md` | WowAddonStandards | No — but it keeps the addon out of the next standards refresh until done |
| 2 | BL-01 | Author and ship `media/logos/bankledger.logo.tga` + `.jpg` | BankLedger | Yes, for publishing |
| 3 | BL-02 | Capture screenshots, add `## Screenshots` to the README | BankLedger | Yes, for publishing |
| 4 | BL-03 | Add `X-Curse-Project-ID` + the version badge | BankLedger | Publish-time, same change as the upload |
| 5 | BL-04 | Localization pass | BankLedger | No — accepted for v0.1.0 |

## Sequencing notes

- **1 first, and it is cheap.** Until the roster row exists, Bank Ledger is invisible to the next
  collection-wide standards refresh, so every later audit misses it.
- **2 before 3.** The screenshots of the settings landing page should show the logo, so shooting
  them first would mean reshooting.
- **4 is publish-coupled by definition** — the project id does not exist until the first upload. Do
  the TOC line and the README badge in that same change, never as a follow-up.
- **5 is open-ended** and deliberately deferred; it touches every call site and is best done as one
  sweep rather than piecemeal.

## Gate for every step

```sh
lua tests/run.lua     # 277/277
luacheck .            # 0/0
```

If a step changes the suite, regenerate the inventory and move the README badge **in the same
change** (testing-§5):

```sh
lua tests/run.lua --list > docs/test-cases.md
```

## Re-audit

Run `/wow-addon:standards-audit` after step 3 and again before the first tagged release. A re-run
writes a **new** dated folder under `docs/audits/`; this one is frozen and is never edited.
