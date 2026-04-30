---
schema_version: "1.0"
type: roadmap
milestone: "{{milestone_id}}"
feature_ref: "{{feature_ref}}"
feature_spec: "{{feature_spec}}"
vision: "{{vision}}"
tier: "{{tier}}"
created_at: "{{created_at}}"
updated_at: "{{updated_at}}"
---

## Phases

- [ ] **{{phase_id}}**: {{phase_title}} — "{{demo_sentence}}"
  - Risk: {{risk}}
  - Depends: {{depends}}
  - Boundary Map:
    - Produces: {{produces}}
    - Consumes: {{consumes}}

<!-- Repeat the phase block above for each phase in the milestone.
     Mark completed phases with [x] instead of [ ].
     Phases are ordered by dependency + risk (high-risk first among satisfied deps).
     Never modify completed phase entries — append new phases at the bottom.

     Convention:
       - Depends:    phase IDs only (P01, P03, ...) — these gate scheduling.
                     read-roadmap.sh refuses to schedule a phase whose
                     Depends: list contains a malformed phase token (Pfoo,
                     P-1, P3a) — that's the load-bearing parser-bug catch.
       - Blocked by: external prerequisites (BG-### bug-gates, release-cut
                     markers, cross-milestone references). Tracked
                     separately; not enforced by the scheduler.
     Mixed `Depends:` lines like `Depends: P03, BG-002 closure` are tolerated
     (the BG-### token is silently skipped) but the canonical form is to put
     phase tokens in `Depends:` and external prerequisites in `Blocked by:`. -->

## Cross-Cutting Concerns

<!-- List concerns that span multiple phases. Each entry names the concern,
     the phase IDs it touches, and how consuming phases should handle it.
     Example:
     - **Error handling patterns** — P01, P03, P05. P01 establishes the pattern;
       P03 and P05 must conform to it. -->

## Dependency Graph

<!-- ASCII visualization of the phase DAG. Show phase IDs as nodes and
     dependency edges. Mark phases that can execute concurrently.
     Example:
     P01 → P02 → P04 → P06
              ↘        ↗
               P03 → P05
     -->

## Execution Order

<!-- Ordered list with rationale. Explicitly mark which phases can run
     in parallel once their dependencies are satisfied.
     Example:
     1. P01 — foundation, no dependencies
     2. P02, P03 — can execute concurrently (both depend only on P01)
     3. P04 — depends on P02
     4. P05 — depends on P03
     5. P06 — depends on P04 and P05 -->

## Validation

<!-- Record the results of the four consistency checks performed before
     writing this roadmap. Each check should show PASS or FAIL with details.
     - No conflicting producers: PASS/FAIL
     - All consumed items have producers: PASS/FAIL
     - DAG is acyclic: PASS/FAIL
     - Demo sentence coverage: PASS/FAIL -->
