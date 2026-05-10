---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M030"
provides:
  - "dispatch-interface.sh shadow hook (M030_SHADOW_MODE+CLAUDECODE gated classifier+routing-table emit), 4 additive JSONL fields (model_routed, model_used, partial_flip_active, withheld_classes), tools/verify/p02-shadow-emit.sh, tools/verify/p02-con3-closure.sh, tools/verify/p02-append-only.sh"
requires:
  - "from:M030/P02/T01 what:tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl;from:M030/P02/T01 what:tests/fixtures/m030-p02/round-trip-stage/;from:M030/P02/T01 what:tools/verify/p02-additive-schema.sh;from:M030/P02/T01 what:tools/verify/p02-fixture-shape.sh;from:M030/P01/T02 what:scripts/dispatch/classify-task.sh;from:M030/P01/T03 what:templates/model-routing.yml"
affects:
  - "M030/P02/T03,M030/P02/T04"
key_files:
  - "scripts/dispatch/dispatch-interface.sh,tools/verify/p02-shadow-emit.sh,tools/verify/p02-con3-closure.sh,tools/verify/p02-append-only.sh"
key_decisions:
  - "dual-printf-branch-per-emit-side preserves SC-11 byte-equality mechanically;awk-section-walker (P01 pattern) extracts routing+resolution at dispatch time;CC-only short-circuit gated by CLAUDECODE=1 AND M030_SHADOW_MODE=1;partial_flip_active=false / withheld_classes=empty as P03/P04 schema reservation"
patterns_established:
  - "dual-format-string emit branches (shadow-on adds 4 trailing fields; shadow-off byte-identical to pre-amendment);CON-3 closure verifier compares HEAD-vs-working-tree per-pattern grep counts (no new provider model-ID literals);append-only verifier asserts inode + first-N-lines + line-count delta = +1"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P02/tasks/T02-dispatch-shadow-hook-PLAN.md"
duration: "60m"
verification_result: "pass"
completed_at: "2026-04-30T14:06:51Z"
---

T02 amends scripts/dispatch/dispatch-interface.sh _di_emit_dispatch_usage to invoke the P01 classifier and resolve a routing-table choice when M030_SHADOW_MODE=1 AND CLAUDECODE=1. Four new fields (model_routed, model_used, partial_flip_active, withheld_classes) are appended after timestamp via a dedicated shadow-on printf branch; the shadow-off branch retains the pre-P02 format string verbatim. Two parallel branches per emit-side (happy-path + degradation), four printf invocations total. The awk section-walker reads templates/model-routing.yml at every shadow-on dispatch (sub-millisecond on the ~100-line YAML) — zero hardcoded provider model IDs in dispatch-interface.sh. Note: the awk regex required a 2-space-indent anchor (^  [a-z_]+:$ for class keys, ^    claude-code: for runtime keys) because YAML class keys are indented under routing:/resolution: — the payload's example regex (^[a-z_]+:$) only matches top-level keys. Fix verified inline. All four T02 verifiers exit 0: p02-additive-schema.sh pass=6 fail=0 (shadow-off byte-equality re-confirmed against amended emitter); p02-shadow-emit.sh pass=14 fail=0 (3 scenarios: shadow-on+CC-on tokens present; shadow-off+CC-on tokens absent; shadow-on+CC-off tokens absent); p02-con3-closure.sh pass=7 fail=0 (HEAD-vs-WT per-pattern grep count comparison for claude-haiku-/claude-sonnet-/claude-opus-/gpt-/o1-/o3-/gemini-); p02-append-only.sh pass=4 fail=0 (inode unchanged, first-5-lines bit-identical, line-count delta=+1). MEM004 emitter-internal carve-out covers the awk blocks. Bash 3.2 safe; verifiers use tmp-file intermediates per AP-009. P03 will consume the four shadow fields for shadow-compare verdicts.
