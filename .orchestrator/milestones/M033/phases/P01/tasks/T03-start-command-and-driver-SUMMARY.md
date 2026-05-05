---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M033"
provides:
  - "commands/start.md (orchestrator:start command doc) + scripts/lifecycle/start.sh (FR-1 flag set + FR-2 ordered branch detection + idempotent init invocation + four sub-flow stubs + US-1 AS-5 + MIT-006/RISK-006 disambiguation question) + 5 T03 verifiers"
requires:
  - "from:M033/P01/T01 what:tests/fixtures/m033-pbj-materials-fixture; from:M033/P01/T02 what:references/branch-detection.md SSOT pattern strings"
affects:
  - "P02,P03,P04,P05,P06"
key_files:
  - "commands/start.md,scripts/lifecycle/start.sh,tools/verify/m033-p01-start-md-shape.sh,tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh,tools/verify/m033-p01-branch-detection-rules.sh,tools/verify/m033-p01-subflow-stubs-shape.sh,tools/verify/m033-p01-disambiguation-question-shape.sh"
key_decisions:
  - "branch-detection patterns byte-match SSOT via grep -F parity; sub-flow stubs deliberately vacuous (printf would-execute only); disambiguation prompt inline via read -r (grilling-shell.sh is P02); --branch override is silent unless detection differs (then branch-override: stderr diagnostic)"
patterns_established:
  - "SSOT-and-impl byte-match via grep -F parity verifier (T02 ssot-parity verifier transitions skip=1 to skip=0 on T03 land); vacuous-stub pattern for cross-phase scope-guarding (P01 stubs print would-execute: only, P02-P05 replace with real logic); load-bearing token tripwire convention (init already complete, branch:, would-execute:, disambiguation:, recommended:, MIT-006, branch-override: are all literal-grep tokens for downstream SC verification)"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P01/tasks/T03-start-command-and-driver-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-04T03:01:36Z"
---

T03 ships the load-bearing P01 deliverables for M033 — orchestrator:start. Five new verifiers all PASS (start-md-shape pass=14; start-sh-flags-and-init-invocation pass=10; branch-detection-rules pass=17; subflow-stubs-shape pass=5; disambiguation-question-shape pass=6). T02 SSOT parity verifier re-run after T03 land: pass=28 fail=0 skip=0 (transitions from skip=1 to skip=0). Functional sanity: greenfield-empty + greenfield-with-materials branch routing both confirmed via /tmp probe (init-skip diagnostic + branch line + would-execute stub line all firing). One verifier deviation: m033-p01-branch-detection-rules.sh originally checked for literal git rev-list --count HEAD but actual call is git -C "$proj" rev-list --count HEAD; verifier updated to match the rev-list --count HEAD substring (semantically equivalent — the git -C $proj prefix is the same load-bearing invocation, parity verifier independently asserts the SSOT pattern strings byte-match). SC-1 acceptance assertions (P05 deliverable) will exercise this skeleton: branch:, would-execute:, init already complete, branch-override:, disambiguation:, recommended:, MIT-006 are all the load-bearing token tripwires.
