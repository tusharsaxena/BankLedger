# 05 Summary

- Tag moved v1.106.0 -> v1.107.0, base taken from the CLAUDE.md provenance line (payload matched v1.106.0). Kit revision 57, unchanged. Two files moved a minor: WidgetsDragHandle 14 -> 15, WidgetsDragHandleTip 1 -> 2.
- Span bundle: `2026-11-19-v1.106.0-v1.106.0` (one tag, v1.106.0, vendored by f37cc1d without a bundle). Base correction: none.
- Delivered for free (class A): nothing visible; the strip changes reach only a `DragHandle`, and this addon builds none.
- Contract changes: none under anything this addon supplies. Blockers: none.
- LibKa0s icons: line kept (17 names, `settings` among them). The prune cut the re-copied icon folder back to those 17 plus the Open Iconic license, and removed 362 sound files. No provenance split.
- README: the Tests badge rolled 1681 -> 1695 to match `docs/test-cases.md` (stale before this run); credits unchanged (Open Iconic only). Dead stub mirrors: none.
- Adopted: nothing. Declined: nothing.
- Gate (Retail-only addon, one client): `ka0s-bounded lua tests/run.lua` 1695 passed, 0 failed, 1 skipped, 1696 total (the same before the copy); `ka0s-bounded luacheck .` 0 warnings / 0 errors in 125 files.
