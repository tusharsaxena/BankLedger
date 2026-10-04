# Candidates (BankLedger)

Sources: `git -C ../LibKa0s log --oneline v1.68.0..v1.68.1` (7 commits, in `01_DELTA.md`), the
`CHANGELOG.md` v1.68.1 block (lines 13-53 at the tag), and `docs/api/testkit/version-36-docs.md` at
the tag. No major moved a minor (01_DELTA 3c), so there is no per-major API document to diff and no
`Since` marker in range.

Class A, delivered on the copy: kit revision 36. The runner prints `/dev-copilot:bump-version` in the
`RESULTS.md` lead-in where revision 35 printed `/wow-addon:bump-version`, and three runner comments
plus one `test_eol.lua` header comment name the `dev-copilot` commands and path (CHANGELOG v1.68.1,
lines 28-41; `version-36-docs.md:33-43`). This addon's next automated-test run rewrites that one
`RESULTS.md` line on its own. Nothing else in the runner's output, manifest or case list changes.

Class B, host change required: none. The release adds no member, row type, descriptor field or seam
(CHANGELOG v1.68.1, lines 15-19: "No LibStub minor moves, no `NEEDS_*` floor rises, no member is added
or removed").

Class C, whole-module adoption: none. No major is added. Perf's decline is settled under the ratified
`performance-§12` no-combat-path exemption, and v1.68.1 left Perf alone (key 14.1.1.6 unchanged), so
its premise is unmoved. Compat stays unconsumed and is unchanged.

**Zero adoption candidates.** The Step 6 interview has no items and was not held.
