---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M034"
milestone: "M034"
provides:
  - "Cursor MCP review-gate renderer (FR-10): stdio elicitation/create server delegating to interactive-review.sh; non-clobbering .cursor/mcp.json registration (CON-6); RUNTIME-ASSUMPTIONS interactive-review rows (FR-14); byte-parity audit under ORCH_BACKEND=cursor (FR-15)"
requires:
  - "from:P02 what:interactive-review.sh stage + --probe-renderer seam + --test-responses/--policy writer paths"
affects:
  - "M009-Tier-B,M034-close"
key_files:
  - "scripts/lifecycle/review-gate-mcp-server.sh,scripts/lifecycle/merge-mcp-config.sh,scripts/dispatch/adapters/runtime/cursor.sh,packaging/install/install-cursor.sh,references/RUNTIME-ASSUMPTIONS.md,references/interactive-review-renderer.md"
key_decisions:
  - "D-P03-1 bash+jq server (not Python; CON-1/PrincipleXVI),D-P03-2 pure-transport delegate-to-interactive-review.sh (AD-1),D-P03-3 per-session spawn + filesystem-scoped state (#Q-5),D-P03-4 merge .cursor/mcp.json (CON-6),D-P03-5 ORCH_REVIEW_FIXED_TS byte-equality lever"
patterns_established:
  - "MCP stdio server as bash+jq sequential read/printf loop; renderer-as-transport delegating writes to the single producer; byte-parity via frozen-timestamp whole-file SHA"
drill_down_paths:
  - ".orchestrator/milestones/M034/phases/P03/P03-PLAN.md,.orchestrator/milestones/M034/phases/P03/P03-VERIFICATION.md"
duration: "1 session"
verification_result: "pass"
completed_at: "2026-06-07T01:42:36Z"
observability_surfaces:
  - "review-gate-mcp-server JSON-RPC tool-call results; pending_review/auto_accepted/refused_entry JSONL via the delegated interactive-review.sh path"
---

Final phase of M034. Adds the third renderer behind the P02 CON-7 seam: an orchestrator-owned stdio MCP review-gate server exposing review gates via elicitation/create. Interactive Cursor accept captures to REVIEW.md (delegated to interactive-review.sh --test-responses, byte-identical to CC); headless decline maps onto the declared auto-mode policy; elicitation-capability-absent degrades to QUESTIONS.md. Registered non-clobbering in .cursor/mcp.json via cursor.sh --mcp-config + merge-mcp-config.sh + install-cursor.sh Stage 3.6. Resolves PC-6 (stub JSON-RPC shape + injection + lifecycle) and #Q-5 (per-session spawn, filesystem-scoped state). Consolidates M009 FR-6->FR-10 and FR-8->FR-15. 4 tasks; phase-suite 4/4; check-must-haves 53 PASS/0 FAIL. M009 FR-7 cost rate-card stays deferred.
