---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M013"
provides:
  - "scripts/integrations/github-status.sh,commands/github-status.md,scripts/verify/m013-p01-github-status.sh,scripts/verify/m013-p01-github-status-command.sh"
requires:
  - "from:M013/P01/T01 what:templates/github-integration-sidecar.json and scripts/integrations/sidecar-init-pending.sh"
affects:
  - "T03,T06,T07"
key_files:
  - "scripts/integrations/github-status.sh,commands/github-status.md,scripts/verify/m013-p01-github-status.sh,scripts/verify/m013-p01-github-status-command.sh"
key_decisions:
  - "FR-6 pending-sentinel semantics inherited from T01; swallow helper exit 2 on second --init-pending so github-status.sh stays a pure reader"
patterns_established:
  - "read-only STATUS reporter emitting three tri-state lines (absent/pending-operator-complete/configured); schema-mismatch detection via grep of required FR-6 field names; zero-gh-subprocess invariant enforced by gate"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P01/tasks/T02-PLAN.md"
duration: "unreported"
verification_result: "pass"
completed_at: "2026-04-21T18:00:41Z"
---

Shipped M013/P01/T02 read-only github-status scaffold. Created scripts/integrations/github-status.sh as a pure file-reader over .orchestrator/integrations/github.json: emits STATUS: absent when the sidecar is missing, STATUS: pending-operator-complete when any of repo_slug, project_v2_id, or sync_mode holds the literal pending sentinel (plus PENDING_FIELDS CSV), or STATUS: configured with REPO_SLUG / SYNC_MODE / LAST_SYNC / CACHE_ITEMS when populated. Schema-mismatch (missing required top-level FR-6 field) reports on stderr and exits 1; unknown flags exit 2; --help exits 0. The --init-pending flag delegates to T01 scripts/integrations/sidecar-init-pending.sh (fired only when the sidecar does not already exist, so the T01 clobber-refuse exit 2 is never propagated and github-status.sh always exits 0 on successful report). Zero gh subprocess calls and zero hard jq dependency; field extraction uses grep/sed per MEM001. Created commands/github-status.md per MEM012 structure with description frontmatter, Prerequisites/State Check, Core Workflow, Output (configured and absent examples), Idempotency, Error Handling, Referenced Scripts (names github-status.sh plus sidecar-init-pending.sh), and Referenced Templates. Shipped two AD-19 gate scripts: scripts/verify/m013-p01-github-status.sh (18 PASS lines covering absent/pending/configured transitions, PENDING_FIELDS enumeration, double-init idempotency, schema-mismatch exit 1, unknown-flag exit 2, help exit 0, zero-gh-invocation, no-hard-jq, clean teardown) and scripts/verify/m013-p01-github-status-command.sh (20 PASS lines verifying MEM012 section headings, description-mentions-read-only, STATUS-trio documentation, sidecar-path naming, --init-pending doc, exit-code doc). Both gates exit 0. Judgment calls: (a) github-status.sh guards the helper invocation with a not-exists test so repeated --init-pending calls are idempotent from the caller perspective — this intentionally hides T01 clobber-refuse exit 2 rather than surfacing it (gate asserts rc=0). (b) Schema-mismatch uses grep of field-name tokens rather than a full JSON parse; sufficient for P01 since the file is line-oriented JSON written by our own helper, and matches MEM001 no-hard-jq convention. (c) CACHE_ITEMS counter uses a grep pattern anchored to indented M-id cache keys — works for the empty-items case (returns 0) and for populated items blocks emitted by later phases; narrower than a full JSON walk but transparent to inspect. (d) Command markdown includes a short Example absent output block beyond the plan skeleton so operators see both non-error outcomes — kept surgical, no speculative sections.
