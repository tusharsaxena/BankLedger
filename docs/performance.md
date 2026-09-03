# Performance — Ka0s Bank Ledger

**This addon brackets nothing, and holds a recorded `performance-§12` no-combat-path exemption.**
The register row is in [`ARCHITECTURE.md` ▸ Documented deviations](./ARCHITECTURE.md#documented-deviations);
this page is the evidence behind it.

So the answer to *how much does this addon cost?* is **nothing measurable while you are fighting**,
and the rest of this page is why we know that rather than assume it.

## What the exemption means here

`performance`'s wiring — `core/PerfSetup.lua`, a `BankLedgerPerfDB` SavedVariables global, a `perf`
verb, the suspend/resume contract, `tests/perf.lua` and `docs/perf-analysis/` — is **not** shipped.
The capture protocol opens its measurement windows on the player's **combat state**
(`performance-§7`), and this addon runs no code in that window: every declared bucket would read
`0.000` by construction, which `performance-§3` itself calls *a lie in every report*. That is
criterion **(b)**.

What the exemption does **not** suspend, and what this repo therefore still does:

- `libs/LibKa0s/` is vendored **whole**, `Perf.lua` and `PerfPanel.lua` included (`library-stack-§7`,
  anti-pattern #48). Dropping the two files this addon does not wire is partial vendoring.
- **`perf` stays a reserved verb** (`slash-commands-§2`). It is not registered here, and it may never
  come to mean anything else.
- The release notes still say `perf: skip` out loud (`automated-tests-§3`) — a skip is never a pass,
  and the reason to name is *this exemption*, not the bare absence of `tests/perf.lua`.

## The sweep — criterion (a), whole repo

`grep -rn 'RegisterEvent\|SetScript("OnUpdate"\|C_Timer' core modules settings defaults locales BankLedger.toc`,
with the per-hit work named. Re-run it: the moment it grows a row this page cannot explain, the
exemption is over.

| Site | What it is | Work while in combat |
|---|---|---|
| `core/BankLedger.lua` `OnEnable` | `PLAYER_ENTERING_WORLD` -> `OnEnterWorld` | One boolean check. Latched by `NS.State.cleanupDone`, so it does its work once per session. |
| `core/BankLedger.lua` `OnEnable` | `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` -> `OnCombatChanged` -> `NS.Util.ApplyVisibility` | **On the combat EDGE, twice a fight, never inside one.** One `settings.visibility` read, at most one `InCombatLockdown()` call, then a fixed two-entry loop over `NS.Browser` / `NS.SessionWindow` that hides or re-shows a window the rule itself took (`core/State.lua`'s `hiddenByVisibility`). No allocation, no scan, no timer. On the shipped default `always`, `Util.VisibilityAllows` answers before it reads the combat state and the loop finds nothing to do. |
| `core/BankLedger.lua` `OnEnterWorld` | `C_Timer.After(5, …)` -> `Database:PruneOld` | **One-shot**, not a ticker. Fires five seconds after the first login/zone, off the boot spike. |
| `core/Compat.lua` `LoadItem` | `C_Timer.After(0.4, cb)` | **One-shot** per item that had to be fetched from the server, and only on a path reached from a bank scan. |
| `modules/Ledger.lua` — `OPEN_EVENTS` / `CLOSE_EVENTS` | `BANKFRAME_OPENED`, `GUILDBANKFRAME_OPENED`, and their `…_CLOSED` pair | **Cannot fire in combat**: a bank or guild-bank frame is an out-of-combat NPC interaction. These are what set `NS.State.openContext`, the gate everything else reads. |
| `modules/Ledger.lua` — `CHANGE_EVENTS` | `BAG_UPDATE_DELAYED`, `PLAYERBANKSLOTS_CHANGED`, `PLAYER_MONEY` -> `ScheduleReconcile` | These **do** fire in combat — looting money, a bag update. `L:ScheduleReconcile` opens with `if not NS.State.openContext then return end`, so in combat each one is a single nil check and nothing more. With a bank open it debounces onto **one** AceTimer one-shot (`L.DEBOUNCE_SECONDS`), replacing any pending one. |
| `modules/Ledger.lua` — `GUILD_DATA_EVENTS` | `GUILDBANKBAGSLOTS_CHANGED` -> `OnGuildBankData` | **Can** fire in combat: the server pushes tab contents on reload sync and whenever another guild member moves something (issue #12). The handler is an already-hooked short-circuit, one three-valued visibility read and `ScheduleReconcile`, which opens with the `openContext` nil check — so away from a vault it is a handful of comparisons. |
| `modules/Ledger.lua` — `ADDON_LOADED` | `OnAddonLoaded` -> `HookGuildBankFrame` | Fires once per addon that loads. Latched by `L._guildHooked` and gated on one string compare, so every firing after the guild bank UI lands is two comparisons. |
| `modules/Browser.lua`, `modules/SessionWindow.lua` | `PLAYER_LOGOUT` on each window's own event frame | Saves the window's view state. Fires once, at logout. |

The combat pair is the one row that arrived *after* this exemption was ratified — the **General
visibility** rule (`options-ui-§15`) needs both edges or its two combat modes are declared and never
honored. It was assessed against the register row's own re-check trigger and does **not** trip it:
the trigger is an in-combat handler *doing real work*, and this one is bounded, allocation-free,
fires twice per fight rather than per frame or per event, and does nothing at all on the default
setting. It is named here rather than left for the next sweep to find.

**No `OnUpdate` handler exists in this repo** — `grep -rn "OnUpdate" core modules settings` returns
nothing — and **no repeating ticker**: no `C_Timer.NewTicker`, no `ScheduleRepeatingTimer`. Every
timer above is a one-shot.

The whole capture engine hangs off one gate: `NS.State.openContext`, set only by a bank or
guild-bank frame opening. The reasoning was first written up in closed issue
[**LIBKA0S-17**](https://github.com/tusharsaxena/BankLedger/issues/9), when `LibKa0s-Perf-1.0`
was declined; that issue is the argument, and the register row is the ratification.

## What ends this

**The first `OnUpdate` handler, repeating ticker, or in-combat event handler doing real work re-arms
the full `performance` wiring MUST.** In this addon the likeliest shape of that change is an event
handler that stops checking `NS.State.openContext` first, or a scan moved off the bank-open gate onto
a bag event. If you write one, delete the register row and wire the harness — the exemption is
conditional on the sweep above still being true, and this is the change nobody would re-read the
standard during.

## Where the numbers still come from

Nothing here says the addon is unmeasured. The **offline** record — lint, the headless suite and
lizard complexity, every run — lives in [`automated-tests/`](./automated-tests/) with `RESULTS.md` as
the trend line. Complexity is the standing cost signal for this repo: no function above CCN 15, read
at every release. What is missing is only the **in-game, in-combat** capture, because there is no
in-combat path to capture.
