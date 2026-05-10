---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P00"
milestone: "M031"
provides:
  - "FR-18 empirical-baseline harness + AD-12/SC-13 ordering verifier (Option B preferred / Option A fallback) + AD-14 frozen pre-m031-baseline.jsonl (20 records) + SC13-OPTION.md + 4 P00 verifiers + p00-phase-suite.sh aggregating all 9 P00 gates"
requires:
  - "from:P00/T01 what:specs/034-right-sized-entry/spec.md folded AD-1..AD-20 + SC-13/14/15; from:P00/T02 what:CORPUS-MANIFEST.md + 20 task-*.txt fixtures + pre-m031-stub.sh; from:disk what:git repo with .git/ for AD-12 Option B detection"
affects:
  - "P01 (T03-frozen pre-m031-baseline.jsonl is the comparand for P01-first-task post-m031-baseline.jsonl capture against build-context.sh --profile=quick); P04 (acceptance battery aggregator runs --compare for SC-11 verdict); future P00 maintainers (must add new verifiers to p00-phase-suite.sh + bump expected pass=N)"
key_files:
  - "tests/m031-acceptance/empirical-baseline.sh,tests/m031-acceptance/verify-baseline-ordering.sh,tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl,tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md,tools/verify/p00-baseline-harness-shape.sh,tools/verify/p00-ordering-verifier-shape.sh,tools/verify/p00-pre-baseline-jsonl-population.sh,tools/verify/p00-phase-suite.sh"
key_decisions:
  - "SC-13 Option A selected (corpus path uncommitted at T03-execution time, git log returns empty for the corpus path so Option B has no defined LHS; SC-14 effective N=14; operators may re-run after T03+P01 commits land to upgrade to Option B); harness median uses lower-middle for even-N to avoid bash 3.2 floating-point math (stable for inequality-based SC-11 verdict); pass-rate fixed-point integer comparison sidesteps shell FP entirely"
patterns_established:
  - "AD-14 single-window harness pattern (--post-m031-emitter seam = empty default emits 'capture pending' on stderr + exit 0, P01 first task supplies real emitter to satisfy 'simultaneously while both code paths are live'); harness re-runnability via deterministic stub + truncate-on-capture (idempotent re-runs produce identical pre-m031-baseline.jsonl bytes); phase-suite straight-line nine-gate aggregation (no array loops, AD-19 compliant) with per-gate OK:/FAIL: + final SUMMARY: pass=N fail=M"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P00/tasks/T03-harness-and-suite-PLAN.md"
duration: "70m"
verification_result: "pass"
completed_at: "2026-05-01T16:43:04Z"
---

Authored the FR-18 empirical-baseline.sh harness (255 lines, bash 3.2, capture + --compare modes, --post-m031-emitter seam empty by default) and the AD-12/SC-13 verify-baseline-ordering.sh ordering verifier (101 lines, Option B preferred via git log --diff-filter=AM --reverse --format=%ct, Option A protocol-note fallback). Ran the harness once at T03-close to capture the AD-14 frozen pre-m031-baseline.jsonl: 20 JSONL records (one per task-NN.txt fixture, all carrying path=pre-m031 + knowledge_section_tokens=0 + verifier_pass=true), stderr 'POST-M031 CAPTURE PENDING — supply --post-m031-emitter at P01 first task', stdout 'BASELINE: pre=20 post=pending', exit 0. Detected via the ordering verifier that git log returns empty stdout for the corpus path (the corpus directory is created and populated within this same uncommitted working tree, so Option B has no defined LHS); recorded Option A selection in SC13-OPTION.md (36 lines) with rationale + effective N=14 for SC-14. Authored four new P00 verifiers under tools/verify/: p00-baseline-harness-shape.sh (106 lines / 6 checks), p00-ordering-verifier-shape.sh (96 lines / 5 checks), p00-pre-baseline-jsonl-population.sh (88 lines / 4 checks per-line while-read scan against the JSONL file, no process substitution), and replaced the M030-era p00-phase-suite.sh with the M031 nine-gate aggregator (110 lines, straight-line invocation per AD-19). All four new verifiers exit 0; the phase suite emits 'SUMMARY: p00-phase-suite.sh pass=9 fail=0' aggregating all nine T01+T02+T03 P00 gates. NO P01 surfaces touched (scripts/dispatch/build-context.sh, commands/dispatch.md, commands/evaluate.md, references/tier-definitions.md preserved per AD-14 single-window discipline + SC-12 scope-guard requirement). T03 closes P00 of M031.
