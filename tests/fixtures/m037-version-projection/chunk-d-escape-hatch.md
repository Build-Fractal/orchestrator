---
schema_version: "1.0"
type: reference-chunk
chunk_id: "REF-CHUNK-D"
version: "Source-Side Title D (would be projected without escape hatch)"
topic_tags:
  - test
  - m037
  - escape-hatch
---

# REF-CHUNK-D

This is fixture chunk D. The companion pre-existing stub (staged into
`wiki/docs/<extra-dir>/chunk-d-escape-hatch.md` BEFORE the generator
runs) carries `auto_generated: false` and an operator-edited
`title: "Operator Custom Title"`. The generator MUST preserve that stub
byte-identical across re-runs (MIT-02 P0 escape hatch).
