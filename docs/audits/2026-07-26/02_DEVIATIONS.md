# 02 · Deviations — 2026-07-26

Deviation IDs are stable per-addon (`BL-NN`) and are reused by later audit runs.

| ID | Section | Severity | Status | Summary |
|---|---|---|---|---|
| BL-01 | options-ui-§5 / layout-§3 | Medium | Open | The addon logo asset is not shipped. |
| BL-02 | documentation-§1 | Low | Open | No `## Screenshots` section — there is nothing to show yet. |
| BL-03 | toc-file-§1 | Low | Accepted (until publish) | No `X-Curse-Project-ID`. |
| BL-04 | localization-§3 | Low | Accepted | No user-facing string routes through `NS.L`. |
| BL-05 | *(process)* | Medium | Open | The addon's row is not yet in the collection roster. |

---

## BL-01 · The logo asset is missing

**Rule.** options-ui-§5 requires the settings landing page to render the addon logo, shipped as a
`.tga` (or `.blp`) under `media/logos/` with the editable source beside it; documentation-§1 item 3
requires the logo in the README.

**State.** `media/logos/` exists and is empty. `NS.Constants.LOGO_PATH` points at
`Interface\AddOns\BankLedger\media\logos\bankledger.logo.tga`, the landing page reserves its 300×300
slot, and the README references `media/logos/bankledger.logo.jpg`. Everything is wired; only the art
is absent, so the slot renders blank and the README image does not resolve.

**Fix.** Produce the logo (source art power-of-two, e.g. 512×512), save it as
`media/logos/bankledger.logo.tga` for runtime with the `.jpg` source beside it. No code change.

---

## BL-02 · No `## Screenshots` section

**Rule.** documentation-§1 item 6 is a SHOULD, and a MUST once published.

**State.** Omitted, because it would be empty — the standard explicitly permits omitting an optional
section only when it would be empty, and requires the relative order be preserved when it returns.
`media/screenshots/` is in place for when it does.

**Fix.** Capture the window, the Insights tab and the settings sub-panels before first publish, and
insert the section between `## What's new` and `## Usage`.

---

## BL-03 · No `X-Curse-Project-ID`

**Rule.** toc-file-§1 makes it a MUST **once published on CurseForge**.

**State.** Not published, so the line is correctly absent. `X-Wago-ID` and `X-WoWI-ID` are optional
and likewise absent.

**Fix.** Add the line — keeping the Curse → Wago → WoWI field order — in the same change as the
first publish, along with the README's CurseForge version badge.

---

## BL-04 · No strings route through `NS.L`

**Rule.** localization-§3 requires an `enUS.lua` at minimum; wrapping strings is not itself
mandatory, but the seam must exist and be used as the addon localizes.

**State.** `locales/enUS.lua` and `locales/PostLoad.lua` ship with the metatable fallback in place;
every label, tooltip and message is hardcoded English. **Accepted scope decision for v0.1.0**, not
an oversight — recorded in the locale file itself.

**Fix.** A later localization pass wraps call sites in `NS.L[...]` and adds locale-gated files. No
call site has to move, which is why the seam exists now.

---

## BL-05 · Not in the collection roster

**Rule.** The `NEW_ADDON.md` playbook, step 8: add the addon's row to
`WowAddonStandards/standards/ADDONS.md`. This is the one edit that brings the addon into scope for
the next standards refresh.

**State.** Not done. The edit lives in a **different repository**, so it could not be made from the
scaffold run.

**Fix.** Add the Bank Ledger row to `standards/ADDONS.md` in the `WowAddonStandards` repo.
