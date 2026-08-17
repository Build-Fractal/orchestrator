---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M046"
provides:
  - "Hardened self-continue driver: FR-15 charset allowlist on milestone-dir + argv-array run_child (no sh -c re-parse) + FR-14 deterministic CHILD_ABORT wrapper truth table + continue-class marker mapping (rotation/planning/phase_complete/validating -> CONTEXT:ROTATE) + distinct SELF_CONTINUE:CHILD_ABORT terminal + atomic child_abort marker write + ORCHESTRATOR_SELF_CONTINUE_MARKER=1 env-gate export to the child"
requires:
  - "T01 marker vocabulary (continue-class rotation/planning/phase_complete/validating; error terminals error/unexpected_state/planning_failed; driver-owned child_abort); M045 driver at scripts/lifecycle/self-continue-drive.sh; self-continue-branch.sh consumed unchanged"
affects:
  - "T03 (battery drives the hardened driver), P04 (envelope wraps run_child)"
key_files:
  - "scripts/lifecycle/self-continue-drive.sh,tools/verify/m046-p02-injection-reject.sh,tools/verify/m046-p02-driver-continue-class.sh"
key_decisions:
  - "--auto-cmd semantic change: whitespace-split verbatim with globbing disabled, no shell evaluation (documented in header); AUTO_CMD string default removed — default claude spawn built as argv with milestone-dir inside one pre-validated element; charset allowlist rejects empty/leading-dash/dot-dot/non-[A-Za-z0-9_./-] with exit 2 before any command line; CHILD_ABORT truth table: rc>=128 overwrite, 1..127 no-marker write child_abort, 1..127 with-marker keep, rc=0 no-marker preserves M045 STALLED"
patterns_established:
  - "Argv-array child spawn in POSIX sh via set -f; set -- $CMD; set +f inside a function; driver-owned abort marker written atomically via tmp.$$ + mv -f in same directory"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P02/"
duration: "600s"
verification_result: "pass"
completed_at: "2026-07-13T16:14:02Z"
---

Hardened scripts/lifecycle/self-continue-drive.sh per M046 FR-15 + FR-14: a strict charset allowlist rejects metacharacter-bearing milestone-dir arguments (exit 2, SELF_CONTINUE:REJECT) before the value reaches any command line; the sh -c string spawn was replaced by run_child(), which whitespace-splits --auto-cmd into an argv array with globbing disabled (or builds the default claude -p argv with the pre-validated dir in one element), exports ORCHESTRATOR_SELF_CONTINUE_MARKER=1 to activate T01's deterministic writer, and captures the real child exit status previously discarded by || true; the CHILD_ABORT truth table writes an atomic child_abort marker for signal-killed (rc>=128, overwriting stale markers) and crashed-silent (rc 1..127, no marker) children while preserving the M045 rc=0-no-marker STALLED path; continue-class outcomes rotation/planning/phase_complete/validating all map to CONTEXT:ROTATE re-spawn and child_abort surfaces the distinct SELF_CONTINUE:CHILD_ABORT terminal line plus a self_continue_child_abort log event. New verifiers m046-p02-injection-reject.sh (6 attack shapes + positive control) and m046-p02-driver-continue-class.sh (4 continue-class + 3 error-terminal + synthetic child_abort legs) pass, and all four M045 regressions (driver-terminal, driver-cap, stall, legacy-golden) stay green.
