---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M037"
provides:
  - "OUT-OF-SCOPE diagnostic-budget collapse in scripts/diagnostics/wiki-link-check.sh (THRESHOLD=5 high-fanout collapse + BUDGET=5 small-fanout per-occurrence cap + (collapsed)/(collapsed,budget) markers + --verbose escape hatch),wiki-deploy.sh --verbose passthrough to gate-3 wiki-link-check.sh,SC-16 acceptance test tests/m037-acceptance/p01-out-of-scope-collapse.sh (14 assertions across 4 cases: 178-page collapse + verbose-restores-per-occurrence + mixed-targets fanout split + zero-OOS silent-on-empty),tools/verify/m037-p02-out-of-scope-collapse.sh (8 assertions: code-marker greps + acceptance-test exit-code propagation)"
requires:
  - "from:P02/T03 what:dispatch-sequencing-only"
affects:
  - "M037/P02/T05 phase-suite aggregator"
key_files:
  - "scripts/diagnostics/wiki-link-check.sh,scripts/wiki/wiki-deploy.sh,tests/m037-acceptance/p01-out-of-scope-collapse.sh,tools/verify/m037-p02-out-of-scope-collapse.sh"
key_decisions:
  - "FR-22a,US-13,SC-16,AD-19"
patterns_established:
  - "Two-pass temp-file collapse: walker writes findings to FINDINGS_FILE then post-pass splits into OOS-vs-non-OOS via grep + per-target tally + emit-or-collapse via awk; matches surrounding-code shape (no process substitution per AD-19),Per-target diagnostic-budget collapse with two markers: (collapsed) for high-fanout above THRESHOLD and (collapsed, budget) for small-fanout above BUDGET — preserves the diagnostic distinction so operators can tell why a target was collapsed,--verbose escape hatch as the bypass-mechanism: cat-the-buffer-verbatim path under --verbose preserves the full per-occurrence diagnostic when an operator needs full detail, defaults stay clean for production deploys"
drill_down_paths:
  - ".orchestrator/milestones/M037/phases/P02/tasks/T04-out-of-scope-collapse-PLAN.md"
duration: "1h"
verification_result: "pass"
completed_at: "2026-05-07T16:03:11Z"
---

Lands FR-22a per US-13 / SC-16. PBJ-central deploys were emitting 178 OUT-OF-SCOPE lines all pointing at the same giscus URL, drowning the actionable diagnostic signal. Added a two-pass collapse layer to scripts/diagnostics/wiki-link-check.sh: walker phase writes findings to FINDINGS_FILE as before; new post-pass block splits sorted-unique findings into OOS-vs-non-OOS via grep, then either cats the OOS buffer verbatim (--verbose) or runs awk to tally per-href-target occurrences and emit either a per-occurrence-within-budget block (small-fanout, BUDGET=5 unique targets) or a collapsed summary line (high-fanout, THRESHOLD=5 occurrences). Two distinct collapse markers preserve operator diagnostic distinction: (collapsed) for high-fanout above THRESHOLD; (collapsed, budget) for small-fanout that exhausted the budget. Zero-OOS fixture stays silent (NO summary, NO per-occurrence). wiki-deploy.sh gains a --verbose flag that forwards to gate-3 wiki-link-check.sh. Acceptance test p01-out-of-scope-collapse.sh builds three synthetic fixtures at runtime (178-pages-same-target / mixed-targets / zero-oos) under mktemp -d and asserts 14 properties; verifier m037-p02-out-of-scope-collapse.sh greps the four code markers (--verbose / (collapsed) / THRESHOLD in wiki-link-check.sh; --verbose in wiki-deploy.sh) and propagates the acceptance-test exit code. Verified live against the project's own wiki/site (2219 pages, 6657 OOS): output collapses cleanly, --verbose path emits zero (collapsed) markers; the unrelated pre-existing 2 broken in-scope links FAIL state is preserved (T04 did not regress link-classification logic). All 14 acceptance assertions pass; all 8 verifier assertions pass; full m037 acceptance battery now reports BATTERY: pass=7 skip=0 fail=0 with the new test integrated.
