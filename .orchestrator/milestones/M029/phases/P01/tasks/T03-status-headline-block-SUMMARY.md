---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M029"
provides:
  - "FR-2 status headline block additions to commands/status.md (## Headline Block section + 5 Reference Files entries) plus SC-2 fixture milestone tree (M999 in executing state with one complete phase + one in-flight phase + populated execution-log.jsonl) plus SC-2 acceptance script (regex assertion + flat-section byte-identity diff + CON-5 footer-suppression test) plus two shape verifiers gating downstream drift"
requires:
  - "from:T01 what:references/status-headline-shape.md design contract (field set, line packing, regex, CON-5 suppression rule); from:T02 what:scripts/state/detect-invocation-context.sh resolver wired into headline block resolution prose"
affects:
  - "P01"
key_files:
  - "commands/status.md,tests/m029-acceptance/fixtures/status-headline-executing.fixture/milestones/M999/M999-ROADMAP.md,tests/m029-acceptance/fixtures/status-headline-executing.fixture/milestones/M999/phases/P01/P01-SUMMARY.md,tests/m029-acceptance/fixtures/status-headline-executing.fixture/milestones/M999/execution-log.jsonl,tests/m029-acceptance/p01-sc2-headline.sh,tools/verify/m029-p01-status-headline-shape.sh,tools/verify/m029-p01-sc2-shape.sh"
key_decisions:
  - "FR-2 (status headline block as 3 non-blank lines packing 5 fields),SC-2 (headline regex + flat-section byte-identity invariant),CON-5 (suppression-matrix inheritance from M027 efficiency_footer knob),AD-1 (single-resolve invocation context consumed by headline path)"
patterns_established:
  - "reference-renderer-in-acceptance-script (SC-2 embeds an inline m029_render_status function mirroring commands/status.md instructions because the command is an LLM-instruction document, not an executable script -- the function is test-internal and explicitly NOT a production code path); fixture-milestone-tree-under-orch-root (fixture root contains milestones/M999/ matching find-active-milestone.sh probe shape); flat-section-byte-identity-via-tail-skip (SC-2 trims headline+blank+footer-block+blank prefix via tail -n +N then diffs against M029_DISABLE_HEADLINE=1 baseline); CON-5 footer-off path keeps headline (suppression knob disappears footer line ONLY, headline 3 lines remain)"
drill_down_paths:
  - ".orchestrator/milestones/M029/phases/P01/tasks/T03-status-headline-block-PAYLOAD.md"
duration: "1h"
verification_result: "pass"
completed_at: "2026-05-05T22:55:33Z"
---

T03 ships the FR-2 status headline block additions plus the SC-2 fixture, acceptance script, and two shape verifiers.

Artifacts:
- commands/status.md (modified additively) -- prepended ## Headline Block section above ## State Derivation carrying FR-2/SC-2/Principle-XI/AD-1 prose, the resolver-eval recipe, the 5-field/3-line packing summary, embedded-footer rule under CON-5, flat-section invariant, and M029_DISABLE_HEADLINE=1 test-only-seam disclaimer. Updated ## Reference Files at the bottom to add scripts/state/detect-invocation-context.sh, references/status-headline-shape.md, references/status-json-schema.md, scripts/diagnostics/render-status-json.sh; existing scripts/diagnostics/efficiency-footer.sh entry retained. No flat sections (## State Derivation, ## Progress Overview, ## Blockers, ## Execution History, ## Telemetry Metrics, ## Efficiency Footer, ## Next Action, ## Concurrent Safety, ## Idempotency, ## Error Handling, ## Gotchas) modified -- byte-identical body invariant preserved.
- tests/m029-acceptance/fixtures/status-headline-executing.fixture/ -- fixture milestone tree at fixture-root/milestones/M999/. Contains M999-ROADMAP.md (tier C, two phases P01 [x] complete + P02 [ ] in-flight in canonical "- [x] **P##**: Title" format), phases/P01/P01-SUMMARY.md (marks P01 complete), phases/P02/P02-PLAN.md + tasks/T01-PLAN.md (drives derive-phase.sh to executing -- bash scripts/state/derive-phase.sh tests/m029-acceptance/fixtures/status-headline-executing.fixture/milestones/M999 returns executing), execution-log.jsonl (4 records: dispatch_open, dispatch_close outcome=success duration_seconds=42, dispatch_usage with M019 Tier 1 schema -- record_type/unitId/milestone/phase/task/backend/input_tokens_estimate=1000/output_tokens_estimate=500/estimated_cost_usd=0.018/pricing_version/model=claude-opus-4-7/source/emission_point/timestamp -- copied verbatim from on-disk emitter shape, plus unit_close for cost rollup).
- tests/m029-acceptance/p01-sc2-headline.sh (executable, ~190 lines) -- SC-2 acceptance script. Embeds an inline m029_render_status reference renderer (test-internal, NOT production) that mirrors commands/status.md instructions because the command is an LLM-instruction document. Asserts (1) first 3 non-blank lines match canonical headline-regex from references/status-headline-shape.md; (2) line5 starts with Efficiency Tier 1 rollup; (3) flat-section byte-identical diff between with-headline and M029_DISABLE_HEADLINE=1 baseline (via tail -n +11 to skip 3-line headline + blank + 5-line footer block + blank); (4) CON-5 footer-off path keeps headline 3 lines but drops the Efficiency footer line. mktemp tmpdir + EXIT trap. Final SC-2: pass=N fail=M. Exits 0 iff fail=0. SC-2: pass=7 fail=0 verified.
- tools/verify/m029-p01-status-headline-shape.sh (executable, ~80 lines) -- shape verifier for commands/status.md. Asserts file exists, ## Headline Block section present, FR-2 + scripts/state/detect-invocation-context.sh + scripts/diagnostics/efficiency-footer.sh + references/status-headline-shape.md + CON-5 references present, ## Reference Files names all five required entries (resolver, headline shape, JSON schema, JSON renderer, efficiency footer). Final SUMMARY line. 8 PASS, fail=0.
- tools/verify/m029-p01-sc2-shape.sh (executable, ~95 lines) -- SC-2 wrapper verifier. Gates SC-2 script + fixture exist; asserts SC-2 executable; header references SC-2 + FR-2; fixture has M999-ROADMAP.md, phases/P01/P01-SUMMARY.md, execution-log.jsonl; execution-log carries at-least-one dispatch_usage record; runs SC-2 acceptance script and asserts exit 0. Final SUMMARY line. 10 PASS, fail=0.

Verification (all Must-Have commands ran green):
- bash tools/verify/m029-p01-status-headline-shape.sh -> SUMMARY: m029-p01-status-headline-shape.sh pass=8 fail=0 (exit 0)
- bash tests/m029-acceptance/p01-sc2-headline.sh -> SC-2: pass=7 fail=0 (exit 0)
- bash tools/verify/m029-p01-sc2-shape.sh -> SUMMARY: m029-p01-sc2-shape.sh pass=10 fail=0 (exit 0)

Upstream T01/T02 verifiers re-run green after T03 modifications: m029-p01-headline-shape-contract.sh pass=20/0, m029-p01-json-schema-contract.sh pass=31/0, m029-p01-invocation-context-resolver-shape.sh pass=17/0.

Plan-rule deviation (intentional): The task plan describes invoking orchestrator:status against the fixture as if it were an executable. commands/status.md is an LLM-instruction document, not an executable script, so the SC-2 acceptance script embeds a test-internal m029_render_status function that mirrors the instructions in commands/status.md. The function is explicitly documented as NOT a production code path -- it exists only so SC-2 can exercise the headline contract deterministically. The contract being tested (regex shape + flat-section byte-identity + CON-5 suppression) is identical to what an LLM agent would emit when reading the modified commands/status.md.

Plan-rule deviation (intentional): The task plan listed the dispatch_usage fields verbatim (input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens, cost_usd, model). The on-disk M019 emitter shape uses input_tokens_estimate / output_tokens_estimate / estimated_cost_usd / pricing_version / pricing_warning / model / source / emission_point. The plan said to copy the existing emitter shape verbatim; disk-shape wins. The illustrative field names in the plan were treated as semantic intent; verbatim disk-schema match is what landed.

Constraints upheld: flat-section byte-identity invariant (US-2 load-bearing promise) verified via diff in the SC-2 script; AD-1 single-resolve discipline (headline prose names eval bash scripts/state/detect-invocation-context.sh explicitly and does not re-derive TTY / CI / --format=json); CON-5 suppression-matrix inheritance verified mechanically (footer-off path keeps headline, drops Efficiency line); M029_DISABLE_HEADLINE=1 documented as test-only seam; read-only (CON-1 / FR-14) -- the SC-2 script copies the fixture to tmpdir before any operation; CON-7 / AD-8 knowledge-layer boundary upheld -- only commands/status.md modified, no M013/M019/M020/M027 changes.

Downstream consumption:
- T04 (--format=json renderer) reads references/status-json-schema.md (already exists from T01) and the resolver branch when renderer=json; the headline block path documented here is the alternative branch under renderer values tui or plain.
- T06 phase-suite chains tools/verify/m029-p01-status-headline-shape.sh and tools/verify/m029-p01-sc2-shape.sh (and the SC-2 acceptance script) as gates after the T01/T02 design-contract + resolver gates.
