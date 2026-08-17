---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M046"
provides:
  - "scripts/intake/auto-entry.sh unified classify-first entry driver: Tier-C dir/empty front-route (AUTO:ROUTE tier=c mode=loop, hands off to unchanged loop flow, never runs the loop itself), one-shot four-branch classify for descriptions (AUTO:ROUTE tier=a|a_plus|b mode=one-shot), and a --ambiguity-mode block|prompt below-floor fork (block=AUTO:BLOCK_AMBIGUITY, prompt=legacy interactive low-conf prompt); tools/verify/m046-p03-routing-fixture.sh three-way routing verifier"
requires:
  - "scripts/intake/do-entry.sh (verbatim routing source), scripts/intake/shape-detect.sh, scripts/intake/route-to-dispatch.sh, scripts/dispatch/build-context.sh (all reused by path, byte-unchanged per FR-2/CON-2)"
affects:
  - "T02 (do-entry.sh becomes a shim forwarding to auto-entry.sh), T03 (auto.md documents this entry), T05 (parity + routing verifiers)"
key_files:
  - "scripts/intake/auto-entry.sh, tools/verify/m046-p03-routing-fixture.sh"
key_decisions:
  - "Branch helpers + resolve_floor + classifier invocation + high->1.0/low->0.5 mapping + branch-table order moved VERBATIM from do-entry.sh (moved-not-reimplemented) so SC-2 byte-parity is structural; --ambiguity-mode is the ONLY behavioral fork and only affects the below-floor branch (inert on the high-confidence Tier-A path); AUTO:ROUTE and AUTO:BLOCK_AMBIGUITY surfaced as stderr lines; JSONL unit_close kept byte-identical (source=do-entry, unitId=do-entry/lowconf, ORCH_DO_ENTRY_LOG default) for shim parity; auto-loop.sh untouched, referenced only in must-not-touch comments"
patterns_established:
  - "classify-first entry driver with a dir/empty front-route ahead of the M024 classifier; routing decisions surfaced as AUTO:ROUTE/AUTO:BLOCK_AMBIGUITY stderr contract lines; routing verifier snapshots+restores the git-tracked .orchestrator/direct-mode-execution-log.jsonl to stay hermetic while exercising the real build-context degenerate path"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P03/"
duration: "1080s"
verification_result: "pass"
completed_at: "2026-07-13T21:39:44Z"
---

Created scripts/intake/auto-entry.sh by generalizing do-entry.sh: a Tier-C dir/empty front-route emits AUTO:ROUTE tier=c mode=loop and hands control back to the unchanged auto.md loop flow, task descriptions run the verbatim M024 classify + four-branch one-shot routing (AUTO:ROUTE tier=a|a_plus|b mode=one-shot forwarding all six do-entry flags), and below-floor args take the new --ambiguity-mode fork (default block=AUTO:BLOCK_AMBIGUITY exit-without-dispatch; prompt=legacy interactive low-conf prompt); shape-detect.sh, route-to-dispatch.sh, build-context.sh and auto-loop.sh are all reused byte-unchanged; tools/verify/m046-p03-routing-fixture.sh asserts the three-way routing (9/9 pass, all exit 0) with direct-mode-log snapshot/restore for tree hygiene.
