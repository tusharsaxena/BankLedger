-- tests/test_vendor_sync.lua — the vendored-payload gate, now one line of adoption
-- instead of ~150 hand-copied ones. The implementation lives in the payload it
-- checks, at `tests/_kit/vendor_sync.lua`, so a local patch to the kit breaks the
-- kit's own byte-identity assertion — which is the right outcome, because the fix
-- for a kit problem is upstream and re-vendor, never a local edit.
--
-- WHAT IT CHECKS: that `libs/LibKa0s/` and `tests/_kit/` in this repo are exactly
-- what the LibKa0s repo published at the tag THIS REPO'S `CLAUDE.md` says it
-- bundles.
--
-- THE PROVENANCE LINE IS AN INPUT, NOT A CONSTANT. It is read out of `CLAUDE.md`
-- rather than hardcoded: a provenance line and a vendored payload that disagree
-- is precisely the drift this file exists to catch, so the claim has to be the
-- thing under test. Bump the line and the bytes in the same commit.
--
-- IT USED TO READ README.md. Kit revision 9 (LibKa0s v1.8.1) moved the input to
-- `CLAUDE.md` — a maintainer's fact on a maintainer's page — as the README shed
-- its bundled-library inventory. There is NO fallback: a line left in README.md
-- reads as no provenance line at all and fails. That revision also renamed the
-- first case ("the README says" → "CLAUDE.md says"), which is why
-- `docs/test-cases.md` moved with it.
--
-- ONE NORMALIZATION, AND ONLY ONE: `git show` hands back the stored blob, which
-- is LF, while the working tree is CRLF because `.gitattributes` pins
-- `* text=auto eol=crlf`. CR is stripped from the working-tree side so the file
-- is compared to the blob it round-trips to. Nothing else is normalized — a real
-- fork in content still fails.
--
-- A MISSING SIBLING CHECKOUT REPORTS A SKIP CARRYING ITS REASON, not a pass. The
-- copy this replaced returned early instead, which registered as PASS — "checked,
-- fine" for a comparison that never ran.
--
-- The case names came across from that copy unchanged, deliberately: they are what
-- `docs/test-cases.md` counts, and adopting the shared gate must not move them.
-- The one that has moved since is the rename above, which came with revision 9.

local VendorSync = dofile("tests/_kit/vendor_sync.lua")

VendorSync.register(_G.BL_TEST, {})
