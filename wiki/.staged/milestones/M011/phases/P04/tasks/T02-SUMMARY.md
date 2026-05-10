---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M011"
provides:
  - "handle_spec_context in section-handlers.sh; spec_context recipe section at order 35; build-context.sh omit-empty staging-file dispatch loop; spec_context rows in _bc_display_order/name/priority; three dispatch-* verify scripts; tightened bash32-compat scan over build-context.sh + section-handlers.sh"
requires:
  - "T01: scope-filter.sh --spec-scope-tags; scripts/knowledge/rebuild-index.sh knowledge.db + KNOWLEDGE-INDEX.md; templates/context-recipe.yaml section schema"
affects:
  - "dispatch payload shape (new optional ## Spec Context section); build-context.sh loop contract (staging + omit-empty); context-recipe.yaml default section count"
key_files:
  - "scripts/dispatch/lib/section-handlers.sh, scripts/dispatch/build-context.sh, templates/context-recipe.yaml, scripts/verify/m011-p04-dispatch-includes-spec-context.sh, scripts/verify/m011-p04-dispatch-omits-spec-context-when-unused.sh, scripts/verify/m011-p04-dispatch-excludes-out-of-scope.sh, scripts/verify/m011-p04-bash32-compat.sh"
key_decisions:
  - "AD-T02-1 derive knowledge root from orch_root (not PROJECT_ROOT env) because build-context.sh clobbers PROJECT_ROOT at startup; AD-T02-2 resolve bodies directly in handler (one- and two-level knowledge walk) because resolve-entries.sh only scans one-level and is locked for this task; AD-T02-3 omit-empty is spec_context-only to preserve other handlers' always-emit contract"
patterns_established:
  - "staging-file + mv-on-commit for omit-empty sections preserving contiguous s${idx}.txt naming; orch_root-derived knowledge-root resolution shim for subprocess calls under build-context.sh's PROJECT_ROOT clobber; top-level section-dispatch loop uses plain assignments (no local) under set -euo pipefail"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P04/tasks/T02-body.txt, .orchestrator/milestones/M011/phases/P04/tasks/T02-PLAN.md, .orchestrator/milestones/M011/phases/P04/tasks/T02-PAYLOAD.md"
duration: "55m"
verification_result: "pass"
completed_at: "2026-04-17T02:34:22Z"
---

Wired build-context.sh to emit a scope-filtered ## Spec Context section from task-plan spec/* scope_tags, with omit-empty semantics that skip the section entirely (no manifest row) when no spec tags are present. Core work spanned three files plus four verify scripts. Key gotcha: build-context.sh reassigns PROJECT_ROOT at startup, so the handler now derives the knowledge root from the passed-in orch_root and exports PROJECT_ROOT for the scope-filter subprocess. resolve-entries.sh is locked for this task and only scans one-level knowledge/*/ID.md, so the handler walks both one- and two-level layouts directly. All 9 m011-p04-*.sh verify scripts pass; tests/test-s04-core-commands.sh remains 74/74.
