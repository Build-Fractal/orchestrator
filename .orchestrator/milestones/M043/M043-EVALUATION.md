---
schema_version: "1.0"
type: evaluation
milestone: "M043"
feature_ref: "043-wiki-cloudflare-access-deploy-target"
feature_spec: "specs/043-wiki-cloudflare-access-deploy-target/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-06-04"
discuss_required: true
metrics_source: "raw_spec"
---

# M043 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: /orchestrator-discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 4 |
| Acceptance scenarios | 13 |
| Functional requirements | 14 |
| Estimated SDD flows | 2+ |

## Reasoning

M043 is a coherent multi-phase milestone, not a single-context task. It carries
four priority-tiered user stories (P1 × 2 — target switch + idempotent
provisioner; P2 — docs + safety warning; P3 — live/friendly-tester pass) with an
explicitly named minimal slice (US-1 + US-2). The 14 functional requirements
decompose into ~4 phases (config switch + Cloudflare workflow template →
idempotent provisioner with the access-before-deploy invariant → docs + the
status/doctor footgun warning → live validation), and the phases carry genuine
cross-phase coordination rather than independent units: the FR-3a pre-deploy
health-check invariant spans the US-1 emitted workflow and the US-2 provisioner,
and the three load-bearing plan-phase decisions (#Q-3 warning-detection branch,
#Q-5 health-check probe mechanism, #Q-6 Cloudflare API error envelope) each
ripple across multiple FRs and sections (FR-3a / FR-9 / FR-11 / Assumptions /
SC-5 / SC-6). That decision-coupling plus the security-adjacent blast radius
(confidential-corpus exposure) is the Tier C "roadmap decomposition + boundary
maps + cross-phase coordination" shape. The spec is gate-passed (Standard
advisory conversus PASS, 0 surviving disputes, 5 P0 amendments applied).

Tier B was considered and rejected: although the phases are largely sequential,
the cross-phase decision-coupling (a single probe-mechanism choice constraining
token scopes, workflow shape, and operator-facing docs at once) and the need for
a finalized discussion to bind those decisions before roadmap exceed the Tier B
"one SDD flow, developer-driven transitions" envelope.

## Complexity Factors

- Confidentiality/availability blast radius: the wiki surfaces confidential
  `.orchestrator/` content; a misconfigured deploy silently exposes or freezes it.
- Cross-phase decision-coupling: #Q-5 (probe mechanism) simultaneously determines
  FR-3a workflow shape, FR-11/Assumptions token scopes, and the SC-10 verifier.
- Two enforcement sites for the access-before-deploy invariant (provisioning-time
  setup script + every-CI-deploy health check) per CON-6.
- External dependency surface: Cloudflare Pages + Access (Zero Trust) APIs,
  `wrangler@4` via npx, operator-provisioned scoped token.
- Sequencing interaction with M041 (`scripts/wiki/` carve-out) affects how the new
  setup script distributes (#Q-4).
- Demand-driven by a live downstream incident (pbj-central, 2026-06-04) — real,
  not speculative.
