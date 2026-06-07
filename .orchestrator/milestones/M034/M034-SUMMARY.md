---
schema_version: "1.0"
type: milestone-summary
id: "M034"
parent: "orchestrator"
milestone: "M034"
provides:
  - "First-class interactive review gate: one versioned decision-packet schema, three runtime renderers (CC AskUserQuestion / Cursor MCP elicitation / headless QUESTIONS.md) routed via dispatch-interface.sh, optional conversus producer, REVIEW.md->SIGNOFF.md audit, auto-mode policies (defer/accept-with-audit/refuse-entry), boundary_translation packet type"
requires:
  - "from:M025 what:dispatch-interface.sh runtime seam; from:M009-TierA what:cursor-agent backend + .cursor install path + MCP-elicit probe harness; from:M011/P07 what:conversus adapter"
affects:
  - "M009-TierB,M038,M040"
key_files:
  - "templates/decisions-packet.md,scripts/knowledge/write-decisions.sh,scripts/knowledge/read-decisions.sh,scripts/lifecycle/interactive-review.sh,scripts/lifecycle/review-gate-mcp-server.sh,scripts/lifecycle/merge-mcp-config.sh,references/interactive-review-renderer.md,references/RUNTIME-ASSUMPTIONS.md"
key_decisions:
  - "AD-1 one schema/three renderers/one producer,AD-3 two-layer dispatch,AD-4 auto default defer,D-P03-1 bash+jq MCP server not Python,D-P03-2 renderer-as-pure-transport delegating to interactive-review.sh,D-P03-4 merge .cursor/mcp.json (CON-6)"
patterns_established:
  - "decision-packet schema as clean input to M038/M040; renderer-as-transport delegating writes to a single producer; byte-parity via frozen-timestamp whole-file SHA; MCP stdio server as bash+jq sequential loop"
drill_down_paths:
  - ".orchestrator/milestones/M034/M034-ROADMAP.md,.orchestrator/milestones/M034/M034-CONTEXT.md,specs/044-interactive-review-gates/spec.md"
duration: "four-phase spec-to-close"
verification_result: "pass"
completed_at: "2026-06-07T01:46:48Z"
observability_surfaces:
  - "unreviewed_decisions count in status/doctor (FR-4); pending_review/auto_accepted/refused_entry/review_resumed JSONL; review-gate-mcp-server tool-call results"
---

M034 ships the interactive review gate between artifact authoring and SIGNOFF.md population. P00 baseline + PC-1/PC-2; P01 decision-packet schema+writer+conversus producer+surfacing (US1/US5); P02 interactive walkthrough + REVIEW/SIGNOFF + auto-mode policies + headless fallback + boundary_translation (US2/US3/US6); P03 Cursor MCP review-gate renderer + RUNTIME-ASSUMPTIONS rows + byte-parity audit (US4/FR-14/FR-15), consolidating M009 FR-6->FR-10 and FR-8->FR-15. validate-milestone PASS 29/29; all phase suites green; SC-1..SC-9 verified. Knowledge-layer boundary held: M034 writes only project artifacts under .orchestrator/milestones/, no knowledge/** chunks (M038/M040 territory). M009 FR-7 Cursor cost rate-card deferred. PR opened at milestone close per the standing decision.
