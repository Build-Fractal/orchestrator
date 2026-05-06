---
schema_version: "1.0"
type: reference-chunk
chunk_id: "REF-CHUNK-C"
topic_tags:
  - test
  - m037
  - no-version
---

# REF-CHUNK-C

This is fixture chunk C. Source carries NO `version:` field — the
projected stub `title:` MUST fall back to the chunk-id slug
(`chunk-c` per the basename).

The generator should also emit a debug-level diagnostic when
`WIKI_DEBUG=1` is set; the test does not assert on stderr but the
fallback path is exercised.
