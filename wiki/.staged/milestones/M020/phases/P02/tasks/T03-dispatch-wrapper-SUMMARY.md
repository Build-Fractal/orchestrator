---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M020"
provides:
  - "scripts/dispatch/dispatch-interface.sh --query subcommand passthrough (OQ-4 closure); 12-line early-exit block exec-bridges to scripts/knowledge/query.sh with byte-equivalent stdout/stderr/exit-code; scripts/verify/m020-p02-dispatch-query-wrapper.sh contract verifier (5 cases: ids byte-equiv, json byte-equiv, exit-code propagation on invalid --state, knowledge-tree non-perturbation)"
requires:
  - "from:P02/T01 what:scripts/knowledge/query.sh contract-stable surface (--topic --state --format ids|json), from:P02/T02 what:JSON document + side-effect-free invariant"
affects:
  - "P02"
key_files:
  - "scripts/dispatch/dispatch-interface.sh;scripts/verify/m020-p02-dispatch-query-wrapper.sh"
key_decisions:
  - "none-new"
patterns_established:
  - "dispatch early-exit-passthrough pattern: insert minimal POSIX bracket-shape guard before main argument loop, exec bash to delegate fully (preserves exit/stdout/stderr byte-equivalent) and bypasses dispatch-usage JSONL emitter for read-only knowledge queries (FR-8/CON-1); CON-4 surface preservation via unreachable-block construction (when first arg is not --query, inserted block is dead code so existing 13 surface flags + 4 backend paths byte-equivalent by inspection, not asserted as Tier-1 verifier)"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P02/tasks/T03-dispatch-wrapper-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-25T12:30:26Z"
---

T03 closes OQ-4 (planning payload outstanding question on whether dispatch should know about query). Solution: surgical 12-line insertion in scripts/dispatch/dispatch-interface.sh between the BACKEND initializer and the existing while-loop argument parser. The block fires only when the FIRST argument is --query; it shifts the token off, locates query.sh via the existing SCRIPT_DIR variable, pre-flight checks executability, then exec bash query_script with all forwarded args. The exec-out happens AFTER scripts/lib/pricing.sh sourcing (lines 38-43) -- harmless because pricing.sh is sourced-guard idempotent and side-effect-free at source time -- but BEFORE the dispatch_usage JSONL emitter, satisfying FR-8 + CON-1: query is a side-effect-free knowledge-layer read and must not generate JSONL records. Bash 3.2 native: parameter default expansion, POSIX brackets, shift, exec; no double-bracket regex, no triple-less-than here-strings. CON-4 honored: zero existing lines removed or rewritten; the diff is exactly the inserted block. Verifier ships under scripts/verify/m020-p02-dispatch-query-wrapper.sh and uses PROJECT_ROOT-isolated tmpdir fixture (two MEM entries: topic-match + tag-match); asserts (1) ids byte-equivalence, (2) json byte-equivalence, (3) exit-code propagation on invalid --state (both must be non-zero AND equal), (4) knowledge-tree non-perturbation post-invocation. PASS observed on first run. Cross-task invariants (T01 + T02 verifiers) deferred to phase-completion per phase plan.
