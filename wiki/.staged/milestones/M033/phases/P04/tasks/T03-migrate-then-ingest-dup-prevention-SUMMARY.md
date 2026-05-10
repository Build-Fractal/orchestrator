---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P04"
milestone: "M033"
provides:
  - "FR-12 migrate-then-ingest dup-prevention sentinel handling in scripts/lifecycle/ingest-codebase.sh; is_migrate_derived_mem helper; skip-duplicate-from-migrate diagnostic; fenced SSOT block; commands/ingest-codebase.md FR-12 Edge Case paragraph; tools/verify/m033-p04-migrate-then-ingest-shape.sh (15-check shape verifier with positive+negative functional smoke)"
requires:
  - "from:P03/T03+T04 what:scripts/lifecycle/ingest-codebase.sh emit functions and stable_id helper; from:M015 what:scripts/migrate/migrate.sh assumed-pre-existing derived_from_migrate frontmatter sentinel (one-way READ contract not modified by T03)"
affects:
  - "P04/T04,P04/T05"
key_files:
  - "scripts/lifecycle/ingest-codebase.sh,commands/ingest-codebase.md,tools/verify/m033-p04-migrate-then-ingest-shape.sh"
key_decisions:
  - "one-way-READ-contract-no-M015-modification;is_migrate_derived_mem-helper-uses-plain-grep-qF-no-process-substitution;dup-prevention-check-fires-after-stable-id-computation-and-before-printf-emit-block;sentinel-grep-functional-smoke-shapes-NOT-emit-function-end-to-end-test-deferred-to-T05-SC-6"
patterns_established:
  - "fenced-SSOT-block-naming-convention-dup-prevention-sentinel;additive-extension-with-zero-behavior-change-for-projects-without-migrate-derived-MEMs;helper-call-count-asserted-at-3-occurrences-as-emit-function-coverage-tripwire;synthetic-MEM-sentinel-presence-grep-as-functional-shape-smoke-without-sourcing-target-script"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P04/tasks/T03-migrate-then-ingest-dup-prevention-PAYLOAD.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-05-04T14:27:57Z"
---

T03 implements FR-12 / US-6 AS-3 / brief #Q-10 by extending scripts/lifecycle/ingest-codebase.sh additively so the three emit functions (emit_architecture_mem, emit_convention_mem, emit_decision_mem) skip the write when a pre-existing on-disk MEM at the candidate stable-ID path carries derived_from_migrate: true frontmatter. The skip surfaces a skip-duplicate-from-migrate: <stable-id> diagnostic to stdout. The contract is one-way: ingest-codebase READS the sentinel; migrate.sh ([M015](../../../../../milestones/M015/index.md) closed) is the assumed writer and is NOT modified by this task.

What landed:
- scripts/lifecycle/ingest-codebase.sh: new fenced SSOT block (# >>> dup-prevention-sentinel >>> ... # <<< dup-prevention-sentinel <<<) sited immediately after the existing ingest-signal-sources block; new is_migrate_derived_mem helper sited just before the per-category emit functions; three identical FR-12 dup-prevention check insertions inside emit_architecture_mem / emit_convention_mem / emit_decision_mem (after stable-ID computation and before the printf emit block). All additions are bash 3.2 compatible (plain grep -qF, no process substitution, no command substitution containing pipes per MEM001).
- commands/ingest-codebase.md: new ## Edge Case: migrate-then-ingest duplicate-MEM prevention (FR-12) section sited between Idempotency and Determinism sections. Documents the contract for future operators without requiring them to read the script.
- tools/verify/m033-p04-migrate-then-ingest-shape.sh: 15-check shape verifier covering file presence, executable bit, fenced SSOT block markers, load-bearing tokens (derived_from_migrate: true / skip-duplicate-from-migrate: / is_migrate_derived_mem / FR-12), helper-call-count >=3 (one per emit function), command-doc tokens, and a positive+negative functional shape smoke that stages two synthetic MEMs in a mktemp-d tree (one with the sentinel, one without) and runs the same grep -qF check the helper performs.

Verification:
- bash tools/verify/m033-p04-migrate-then-ingest-shape.sh: pass=15 fail=0 (rc=0)
- bash tests/m033-acceptance/p03-ingest-codebase.sh (P03 SC-3 cross-phase regression): pass=29 fail=0 (rc=0); confirms additive-extension discipline — projects without migrate-derived MEMs see zero behavior change
- bash scripts/diagnostics/check-plans.sh: rc=0 (advisory check per MEM015/MEM006; warnings are all pre-existing M002-[M005](../../../../../milestones/M005/index.md) historical plans, none about M033 or T03)

Deviations: none. The task plan called for ~30 net lines added to ingest-codebase.sh and ~12 net lines added to ingest-codebase.md; actual additions are slightly larger (helper + 3 check insertions + SSOT block totals ~35 lines; doc paragraph ~13 lines including the section heading and trailing one-way-contract sentence). All within additive-extension discipline.

Notes / forward-looking:
- The T03 verifier is shape-only as the plan specifies. The functional end-to-end test that asserts post-migrate MEMs are NOT overwritten by post-migrate ingest lives in T05's SC-6 acceptance script. That script is expected to inject synthetic sentinel-bearing MEMs into a staging fixture and assert (a) the migrate-derived MEMs survive untouched and (b) all OTHER stable-ID slots get populated by the codebase-ingest pass.
- If M015's migrate.sh emitted MEMs do NOT today carry derived_from_migrate: true, the orchestrator-spec contract implemented by T03 is still correct; the gap surfaces in T05's SC-6 and is resolved either by (a) fixture-injected synthetic sentinel MEMs (preserving the orchestrator-spec contract, documenting the M015 gap as a follow-up D-row) or (b) a small follow-up extending migrate.sh to write the sentinel.
- T04 depends on T03: T04's start.sh migrating-branch real implementation invokes ingest-codebase.sh post-migrate (when src/ is present), and the dup-prevention contract from T03 is what makes that invocation safe.
