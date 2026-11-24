Delta: LibKa0s v1.112.0 -> v1.113.0 (span: v1.112.0 v1.113.0)

Written 2026-11-25 by SF-BL-01, beside `../2026-11-25-v1.114.0/`. A records-only back-fill: the two tags this addon vendored without a bundle. No code, library or kit file moved because of it.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-09-25
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.112.0
v1.113.0
```

- v1.112.0 was vendored by `580f775` ("FB-BL-01: Re-vendor LibKa0s v1.112.0", preview stand-in and FollowColor, disabled primary, companion header), base v1.110.0 (the provenance line at `580f775^`). v1.111.0 was never vendored here, so it is not on the span line.
- v1.113.0 was vendored by `9f4aaed` ("FB2-BL-01: Re-vendor LibKa0s v1.113.0") and re-copied from the re-cut tag by `b930d78` ("FB2-BL-02"), base v1.112.0. The kit stayed at revision 60 across both.
