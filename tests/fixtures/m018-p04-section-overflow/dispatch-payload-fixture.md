# Dispatch Context -- T01 (Phase P04, Milestone M018-fixture)

## Manifest

| Section | Lines | Tokens |
|---------|-------|--------|
| Knowledge | 50 | 400 |

## Knowledge

This is the head of the Knowledge section. The first paragraph is the part most likely to be head-dropped because it sits at the highest byte offset of the section body. Tier 2 head-drop walks down from the naive cut byte until it finds a safe line boundary, then drops the head bytes above that boundary.

The second paragraph continues the section body with more plain prose. There are no multi-line preserved spans here — no frontmatter delimiter pairs, no four-tick code fences, no JSONL records. The boundary-refusal walker should never need to retreat from any line in this section because every body line carries the safe-flag.

The third paragraph keeps adding bytes to push the body token count past the configured 200-token budget for this fixture. Token estimation is char-quartile so roughly four bytes per token; 200 tokens is about 800 bytes. We need to comfortably exceed that so the head-drop fires; aim for roughly 400 tokens of body so the leading 70 percent gets snipped.

The fourth paragraph adds yet more boilerplate prose. The default protected_tail_ratio is 0.3 so the trailing 30 percent of section bytes will survive byte-identical at the tail of the post-snip section. The verifier reads the pre-snip body, computes the protected tail bytes, and asserts the prefix of those tail bytes appears in the post-snip output.

The fifth paragraph here is part of the protected tail. After head-drop, this prose should appear unchanged at the bottom of the rewritten section, immediately preceded by the previous paragraph and followed by anything below up to the next section heading.

The sixth paragraph is also part of the protected tail. It contains a marker token for the verifier to grep against — protected-tail-marker-line — that will land deep enough in the section body to definitely land inside the trailing 30 percent ratio. Tier 2 must preserve this verbatim.

The seventh paragraph closes the Knowledge section body. Tier 2 leaves the heading line above untouched, places the in-band tier2 marker right after the heading, drops a chunk of head bytes, and emits the surviving tail bytes. The receiving agent sees the section heading, the marker, and a trimmed body.

## Decisions

No decision entries in scope.

## Task Plan

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M018-fixture"
---

Stub task body for the M018/P04 fixture dispatch.
