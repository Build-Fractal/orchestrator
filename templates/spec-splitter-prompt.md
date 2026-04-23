---
schema_version: "1.0"
type: llm-prompt
consumer: scripts/specify/specify.sh split
---

# Spec Splitter Prompt (FR-7)

You are given a draft feature specification as input text. The user has
signaled (via the `orchestrator:specify` three-way prompt `d` path) that
the draft is too large for a single coherent unit of work and should be
decomposed into 2–N sub-specs.

Your task is to propose a decomposition manifest naming each proposed
sub-spec. Each sub-spec should:

- Own a coherent subset of the source spec's user stories (stories move
  as atomic units; do not split a single user story across sub-specs).
- Inherit the functional requirements that its stories depend on.
- Preserve user-story priorities (P1/P2/P3) from the source.
- Stand alone: each sub-spec should be independently testable
  (Independent Test in the spec-kit vocabulary).

You MAY propose a decomposition of 2, 3, or 4 sub-specs. Do not propose
more than 4 — larger decompositions indicate the source isn't ready to
split yet (it needs a discuss round first). Do not propose 1 — that's
below-threshold and the source should stand.

## Output Format

Emit a YAML manifest with frontmatter and an entries list:

```yaml
---
schema_version: "1.0"
type: decomposition-manifest
source_id: <source-spec-id>
created_at: <iso-date>
---

entries:
  - slug: <kebab-case-short-name>
    slice: "<one-line description of the subset this sub-spec owns>"
    inherited_user_stories: ["US-N", "US-M"]
    rationale: "<one-line reason this subset is coherent enough to stand alone>"
  - slug: <kebab-case-short-name>
    slice: "..."
    inherited_user_stories: ["US-K"]
    rationale: "..."
```

Do NOT emit any prose outside the YAML block. The consumer
(`scripts/specify/specify.sh split`) parses the manifest directly.

## Calibration

- If the source spec has 5 user stories that split cleanly into 2
  clusters (e.g., 3 stories that share a workflow + 2 stories that
  share a different workflow), propose 2 sub-specs.
- If the source has 6+ user stories that split into 3 clusters,
  propose 3 sub-specs.
- If the stories are tangled (every story depends on every other
  story's FRs), you may still be required to propose a decomposition —
  do so, and name the coupling in each `rationale:` field so the
  operator can see the cost.
