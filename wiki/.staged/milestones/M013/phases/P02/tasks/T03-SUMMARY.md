---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M013"
provides:
  - "FR-15 --dry-run manifest format pinned in scripts/integrations/github-common.sh helpers (manifest_header/manifest_upsert_line/manifest_footer); github-init.sh refactored to emit pinned MANIFEST/UPSERT/footer contract on both dry-run and live; expected-manifest.txt + expected-manifest-noop.txt fixture SSOTs; scripts/verify/m013-p02-dry-run-manifest.sh gate with 5 PASS assertions"
requires:
  - "from:T01 what:orchestrator-state+gh-stub fixture tree; from:T02 what:github-init.sh create-path walker"
affects:
  - "P03 (re-init dry-run consumes same format); P04 (sync --dry-run consumes same format); T07 (phase suite diff-gates against fixture SSOTs)"
key_files:
  - "scripts/integrations/github-common.sh; scripts/integrations/github-init.sh; scripts/verify/m013-p02-dry-run-manifest.sh; scripts/verify/m013-p02-github-init-fixture.sh; tests/fixtures/m013-p02/expected-manifest.txt; tests/fixtures/m013-p02/expected-manifest-noop.txt"
key_decisions:
  - "footer-on-live: footer line promoted to pinned-format stdout on both dry-run and live (reconciling T02 which emitted footer to stderr); SCRIPT_DIR-vs-PROJECT_ROOT: source helpers from SCRIPT_DIR not PROJECT_ROOT so --root can point at fixture trees without scripts/"
patterns_established:
  - "buffered-manifest-body pattern — mktemp tempfile collects UPSERT lines during walker iteration, counts are finalized before header emission; sidecar-state-driven reason resolution — dry-run inspects sidecar repo_slug/project_v2_id + items.<oid> to emit create vs skip-existing-marker without any gh calls; FORMAT STABILITY CONTRACT doc-block at helper definition site pins shape for downstream P03/P04 consumers"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P02/tasks/T03-PLAN.md; tests/fixtures/m013-p02/; scripts/verify/m013-p02-dry-run-manifest.sh"
duration: "45"
verification_result: "pass"
completed_at: "2026-04-21T21:17:24Z"
---

T03 pins the FR-15 --dry-run manifest format as a load-bearing contract reused by P03 re-init and P04 sync. Three manifest helpers appended to github-common.sh (manifest_header, manifest_upsert_line, manifest_footer) with a FORMAT STABILITY CONTRACT comment block above them. github-init.sh dry-run path refactored to buffer UPSERT body lines in mktemp, count upserts/skipped from per-resource reason resolution, then emit header + buffered body + footer in walker order (milestone, project-v2, labels, phase-issues, task-subissues, project-v2-items). Live-run path also refactored to use manifest_upsert_line + manifest_footer (no inline printfs left).

Reason resolution in dry-run reads the sidecar: if repo_slug != pending AND project_v2_id != pending, milestone/project-v2/labels resolve to skip-existing-marker; if items.<oid> exists in the sidecar, that phase/task/project-v2-item resolves to skip-existing-marker. Zero gh calls. Two fixture SSOTs written verbatim from the refactored script output: expected-manifest.txt (12 create upserts) and expected-manifest-noop.txt (12 skip-existing-marker skipped).

Incidental fix: the T02 github-init.sh had a bug where --root override made it look for github-common.sh relative to the fixture tree (which lacks scripts/). Split PROJECT_ROOT (orchestrator-state root) from SCRIPT_DIR-derived REPO_ROOT (for sourcing helpers + sidecar-init-pending.sh). T02 fixture gate was already failing (record count mismatch) prior to T03; now passes with updated line-count expectation (14 = header + 12 UPSERT + footer).

Verification: 5/5 PASS on scripts/verify/m013-p02-dry-run-manifest.sh. T02 regression gates also green: github-init-fixture (5/5), github-init-preflight (7/7 + summary), auto-mode-pending (4/4 + summary), github-common (13/13 + summary). Anti-pattern-lint clean on github-common.sh, github-init.sh, and the new T03 gate. Bash -n clean.

Operator-review items: (a) the FORMAT STABILITY CONTRACT comment block is placed at the helper definition site in github-common.sh — T05 is expected to cross-reference this block from references/github-integration.md rather than duplicating the spec; (b) the dry-run reason resolution currently treats 'all four labels cached' as a single bit tied to project_v2_id!=pending — finer-grained per-label caching would require a schema extension (deferred to P04 or a schema-version bump).
