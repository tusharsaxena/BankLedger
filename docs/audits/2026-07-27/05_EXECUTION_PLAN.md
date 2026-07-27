# 05 · Execution plan — 2026-07-27

Ordered, checkable remediation steps for the open deviations in `02_DEVIATIONS.md`, designed against
`04_TECHNICAL_DESIGN.md`. This is the hand-off to the separate remediation engagement — **the audit
itself applied none of it.**

**Standing gate for every sprint:** `lua tests/run.lua` green and `luacheck .` at 0/0 before any
commit (`testing-§4`). Whenever the case count moves, regenerate `docs/test-cases.md`
(`lua tests/run.lua --list > docs/test-cases.md`) and update the README `[tests]` badge **in the same
change** (`testing-§5`). Work trunk-based on `main`; do not tag, bump the version, or push unless
asked.

---

## Sprint 0 — Decision (blocking, no code)

Put BL-07 to the user before anything else; it determines what Sprint 3 writes.

- [ ] **BL-07** — present the two options from `04_TECHNICAL_DESIGN.md`:
      **(A)** record "all defaults in `defaults/Global.lua`, no `defaults/Profile.lua`" as an accepted
      deviation in `docs/ARCHITECTURE.md` ▸ *Documented deviations*, with the account-wide rationale;
      or **(B)** raise it upstream so `savedvariables-§2` permits `defaults/Global.lua` as the sole
      defaults file for an account-wide addon. Option C (an empty `Profile.lua`) is explicitly off
      the table.
- [ ] Record the decision in the sprint's commit message so the next audit can see which route was
      taken.

**Done when:** the user has chosen A or B.

---

## Sprint 1 — Code compliance (BL-06, BL-10)

Two contained code changes, test-first per `testing-§4`.

### BL-06 · Settings canvas callbacks

- [ ] Write the failing tests first: assert that each panel registered through the mock `Settings`
      exposes `OnCommit`, `OnRefresh` and `OnDefault` as functions.
- [ ] In `settings/Panel.lua` `createPanel` (`:114-131`), set inert `OnCommit` and `OnRefresh`, and
      an inert `OnDefault` placeholder.
- [ ] Add the `setDefaultsAction(panel, fn)` helper that sets `panel.defaultsOnClick` **and**
      `panel.OnDefault` from one argument, and use it at both registration sites
      (`settings/Panel.lua:752` General → `P:RestoreDefaults`; `:782-788` Filters → the confirm-gated
      clear-both-lists).
- [ ] Add the second test: `panel.OnDefault` and `panel.defaultsOnClick` are the *same* function
      object on both subcategories, so the framework path and the header button cannot diverge.
- [ ] Confirm the landing page's `OnDefault` stays inert (it manages nothing).
- [ ] Green gate; regenerate `docs/test-cases.md`; update the README `[tests]` badge.

### BL-10 · `reset` echo through the shared formatter

- [ ] Extend `tests/test_slash.lua` with a failing case: the `/bl reset` echo carries `|cffffff00`
      on the key and `|cffffffff` on the value.
- [ ] Rewrite `Sl:CliReset`'s echo (`settings/Slash.lua:247`) as
      `print(Sl.FormatKV(path, Sl.FormatSchemaValue(row, NS.Schema:Get(path))))`, reading back after
      the `Set`.
- [ ] Add a case pinning that a table-valued reset still renders `(none)`.
- [ ] Green gate; regenerate `docs/test-cases.md`; update the badge.

**Done when:** both deviations are closed, tests are green, lint is 0/0, and the inventory and badge
match the new count.

---

## Sprint 2 — Brief resync (BL-08)

- [ ] `curl -fsSL` the current `standards/NEW_ADDON_CONTEXT.md` from the standards repo — verbatim,
      no summarizing fetch.
- [ ] Replace the body of `docs/agent-context.md` below the existing HTML comment header
      (`:1-12`), preserving that header exactly.
- [ ] Verify the new body's `## Hard rules` block still opens with the conform-to-the-standard bullet
      pointing back to `../CLAUDE.md` (`documentation-§6` item 4 — one of the four mandated reference
      sites).
- [ ] Confirm the pack header now reads v2.7.0 (or later) and that the v2.11.0 rules — the lazy
      `OnShow` Defaults button and the second sanctioned mono-font glyph use — are present in the
      text.
- [ ] Add "re-drop the context pack when the standard's minor version moves" to the release
      checklist in `docs/testing.md` or the sync-docs routine, so this stops recurring.

**Done when:** the brief matches the standard the code is already built to.

---

## Sprint 3 — Documentation truth (BL-07 outcome, BL-09)

One change touching `docs/ARCHITECTURE.md` ▸ *Documented deviations*, so the section ends coherent.

- [ ] **BL-09** — remove the mono-font-glyph entry from *Documented deviations*; it is no longer a
      deviation (`debug-logging-§2`, second sanctioned use). Keep the rationale as a plain note beside
      the glyph/media discussion, citing the sanctioning rule.
- [ ] **BL-07 (if Option A)** — add the `defaults/Global.lua` entry with the account-wide rationale,
      naming `savedvariables-§2` and `layout-§1`.
- [ ] **BL-07 (if Option B)** — instead, open the upstream change in `WowAddonStandards` against
      `savedvariables-§2` and link it from `docs/ARCHITECTURE.md` ▸ *Known limitations* until it
      lands.
- [ ] Re-read the section end to end: every entry must be a live, deliberate departure from the
      **current** standard, each with a reason.

**Done when:** *Documented deviations* lists exactly the departures that are real today.

---

## Sprint 4 — Pre-publish (BL-02, then BL-03)

Gated on the first release; BL-02 must be done before BL-03.

### BL-02 · Screenshots

- [ ] `/bl test` to publish the synthetic dataset (no real character data in the images).
- [ ] Capture five images at 1920×1080, default UI scale: History tab with filters, Insights tab,
      the Current Banking Session window at an open bank, Settings ▸ General, Settings ▸ Filters.
- [ ] `/bl test` off.
- [ ] Save as PNGs (≤ ~400 kB each) under `media/screenshots/` with descriptive lowercase names.
- [ ] Insert a captioned `## Screenshots` section **between `## What's new in 0.1.0` and `## Usage`**
      — the position `documentation-§1` fixes.

### BL-03 · Publish metadata (one change, at first publish)

- [ ] `BankLedger.toc` — add `## X-Curse-Project-ID: <id>` immediately after `## X-Standard:`,
      preserving Curse → Wago → WoWI order. Omit `X-Wago-ID` / `X-WoWI-ID` unless actually listed
      there.
- [ ] `README.md` — add the live badge `![CurseForge Version](https://img.shields.io/curseforge/v/<projectId>)`
      as badge **#2**, between `[wow]` and `[license]`.
- [ ] Confirm `## Screenshots` exists (now a MUST).
- [ ] Green gate; then the version bump / tag / publish flow separately, on explicit instruction.

**Done when:** the packaged addon carries its project id and the README shows both the live version
badge and the screenshots.

---

## Verification checklist (run at the end)

- [ ] `lua tests/run.lua` — all green.
- [ ] `luacheck .` — 0 warnings / 0 errors.
- [ ] `docs/test-cases.md` regenerated; README `[tests]` badge matches its total.
- [ ] `docs/agent-context.md` pack version ≥ v2.7.0.
- [ ] `docs/ARCHITECTURE.md` ▸ *Documented deviations* contains only live deviations.
- [ ] Settings ▸ Ka0s Bank Ledger opens; General and Filters both render; the header Defaults button
      renders in the standard dark/gold look (`/bl debug panel` shows more than the bare 5-region
      `130828` set if a skin is installed).
- [ ] Blizzard's own defaults control on the General page resets settings and leaves the ledger
      intact.
- [ ] `/bl list`, `/bl get`, `/bl set`, `/bl reset` all print the same gold-key / white-value shape.
- [ ] Re-run `/wow-addon:standards-audit` — it should land a new dated folder with BL-06, BL-08,
      BL-09 and BL-10 closed, BL-07 recorded (or upstreamed), and BL-02/BL-03 the only remaining
      pre-publish items.
