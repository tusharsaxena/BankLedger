# 03 — Decisions

Step 6 of `/wow-addon:revendor-libka0s`. The owner delegated the interview (CP-6: "use your best
judgement to take whatever decisions you need", `Ka0sAddonsCommonTasks/.../00_PLAN.md:252`, `:299`).
Each decision below was taken by the CP-6 rules, in the order `02_CANDIDATES.md` sets, and written
here as it landed. A decline is filed as a GitHub issue on this repo, labeled with exactly one
`state:` and one `severity:`.

## C1 — `LibKa0s-Bus-1.0` `Catalog`: **adopt**

- **Rule applied:** CP-6 rule 1. The spec prescribes it for this repo (`3b-specs/bus.md:612-619`), and
  it closes a recorded gap: `architecture-§4`'s declare-once MUST, breached today by 25 literal lines
  in 9 addon files (`grep -rn '"Ka0s_BankLedger_' core modules settings --include='*.lua' | wc -l`).
- **Scope, and one narrowing of the spec's common block.** The spec's common block
  (`bus.md:540-546`) is written for a record adopter and asks for the section 7 stub, which carries
  `New` (the untracked-target record) as well as `Catalog`. This repo adopts `Catalog` only; its
  untracked factory stays (`bus.md:619`), so nothing in the addon calls `Bus:New`. The stub therefore
  carries `Catalog` alone, and the parity case names `New` as live-only, with that reason, rather
  than shipping a `New` that no path reaches. This is not a standard deviation: `options-ui-§1`
  (`options-ui.md:64`, `:72`) and `library-stack-§7` (`library-stack.md:104`) name the
  untracked-target stub as a permitted shape, not a required one, and a pass-through `Catalog`
  copies nothing of the library.
- **Where the table lives:** `core/Constants.lua`, because this addon has no `core/Bus.lua`
  (`architecture-§4`: "`core/Bus.lua` where the addon has a bus file and `core/Constants.lua` where it
  does not").
- **Landed:** `f14c9df`, green (998 passed, 0 failed; lint 0/0 in 70 files).

## C3 — `LibKa0s-Compat-1.0`: **decline, never** (`state:will-not-do`, `severity:low`)

- **Rule applied:** CP-6 rule 2, "never" for a structural misfit the spec records. The spec says in
  as many words that no member is adopted here: "BankLedger's and PanelMaster's Compat are wholly
  addon-specific (section 5.3)" (`3b-specs/compat.md:544`), and section 5.3 lists BankLedger's
  members as single-consumer shapes the major deliberately leaves out (`compat.md:278`).
- **Measured:** `core/Compat.lua` has 13 members (`grep -n '^function' core/Compat.lua`): guild name,
  money, store money, the container and guild-bank readers and the item resolver. The major's nine
  (`docs/api/Compat/version-1-docs.md:43-60`) are the secret seam and the spell and specialization
  readers, and `grep -rn 'issecretvalue\|canaccessvalue\|GetSpellInfo\|GetSpecialization' core modules settings`
  returns nothing, so no call site in this addon would reach one.
- **Why "never" and not "not now":** nothing is deferred, because there is nothing to adopt. The
  decline is settled until its premise moves, and the issue names the premise: the first spell,
  specialization or secret-value reader this addon needs.
- **Filed:** https://github.com/tusharsaxena/BankLedger/issues/20 (`state:will-not-do`, `severity:low`), closed
  as not planned, the way this repo closes its other terminal declines (#5-#10).

## C2 — `LibKa0s-Schema-1.0`, full adopter: **adopt**

- **Rule applied:** CP-6 rule 1. The spec prescribes the full adoption for this repo
  (`3b-specs/schema.md:551-559`) and does not offer this repo a deferral (the "MAY defer" is written
  for the two partial adopters only, `schema.md:530`, `:544`, and the API document's "A host that keeps its
  own seam"). One honest attempt was made, with the characterization written first
  (`tests/test_schema_runtime.lua`, 13 cases, green against the host's own seam: 1011 passed, 0 failed).
- **Result of the attempt:** every live case stayed green, and every caller-visible property the
  characterization pins held: the order store, `[Set]` line, `onChange`, repaint; the answers and their
  arity; the refusals and what they leave behind; the inverted Minimap path into the table LibDBIcon
  holds; the bracket-scoped sweep veto; and the degraded writes. Three degraded cases went red, all
  three pinning a `[Set]` line on the library-less build.
- **Why those three do not trigger rule 2's decline:** the spec prescribes exactly that re-pin
  (`schema.md:480-482`: "A pin on a degraded debug line ... re-pins to 'the write landed, and the line
  is absent', because the degraded DebugLog stub discards it"), and so does the API document's
  adoption notes. No player sees those lines: on a library-less load `NS.Debug` is the DebugLog stub's
  no-op, and each case had to install its own recorder to see them. So the behavior they pinned is
  not one a player observes, and rule 2's condition is not met. They were re-pinned to what a player
  can observe: the rows are written back, the error is re-raised unchanged (a nil raise included), and
  the bracket closes on the raising path (probed through the sweep veto).
- **Two latent defects closed, each now pinned:** (a) the Options descriptor's `applyDefault`
  (`settings/OptionsSetup.lua:48`) bypassed `S.RESET_EXEMPT` and had no bracket; it is now the
  instance's `ApplyDefault` with the `BulkBegin`/`BulkEnd` pair, so `O.RestoreDefaults` would skip the
  Minimap row and log one line (proved red under the old descriptor). (b) `S:Register`'s dead
  `row.default == nil` conjunct is gone with the host check; the live schema still measures 0
  (`tests/test_schema.lua:12`).
- **Judgement calls, each recorded:**
  1. `S:Set` keeps its two-value refusal (`false, reason`) rather than passing on the library's
     optional third value. No caller reads a third, and rule 5 pins arity where the adoption moves code.
  2. The refusal wording stays this addon's (`unknown path: <path>`, `invalid value`) through the
     descriptor's `L`, as the API document's adoption notes offer, so `tests/test_schema.lua:95` and
     the characterization hold unchanged.
  3. The stub is trimmed to what this addon calls, as the API document allows ("A host copies it and
     trims what it does not call"). `BulkRun`, `BulkAdd`, `InBulk`, `Reindex` and the profile-reset
     count are named as live-only in the parity case, and this addon has no profile.
  4. The stub's `Validate` is silent. The API document's table suggests "one honest line"; the
     standard's runtime-completing class says logging does not complete (`options-ui.md:64`), and a
     line at every library-less login would be a second notice beside the shared cause clause
     `core/CoreSetup.lua` already prints once. This narrows the document's suggested stub. It is not
     a standard deviation.
  5. `core/Util.lua`'s `Util.SplitPath` had one caller, the host's own path walk, which the library
     replaced. It is deleted with its two `tests/test_util.lua` cases, not left as a dead export.
- **Landed:** `0d9d1e6`, green (1015 passed, 0 failed; lint 0/0 in 71 files).
