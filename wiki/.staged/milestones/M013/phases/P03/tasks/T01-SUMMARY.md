---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M013"
provides:
  - "tests/fixtures/m013-p03/re-init-adoption/ fixture tree; gh_marker_search_remote helper in scripts/integrations/github-common.sh; scripts/verify/m013-p03-re-init-fixture.sh gate; scripts/verify/m013-p03-github-common-readopt.sh gate"
requires:
  - "scripts/integrations/github-common.sh from M013/P02/T01 (emit_marker helper); tests/fixtures/m013-p02/ shape precedent; M013_GH_STUB_DIR env-var stub-selector pattern from P02"
affects:
  - "scripts/integrations/github-common.sh (additive: one new public function + one line in usage-hint echo list)"
key_files:
  - "tests/fixtures/m013-p03/re-init-adoption/orchestrator-state/.orchestrator/milestones/M013/M013-ROADMAP.md;tests/fixtures/m013-p03/re-init-adoption/orchestrator-state/.orchestrator/milestones/M013/phases/P02/P02-PLAN.md;tests/fixtures/m013-p03/re-init-adoption/orchestrator-state/.orchestrator/milestones/M013/phases/P02/tasks/T01-PLAN.md;tests/fixtures/m013-p03/re-init-adoption/orchestrator-state/.orchestrator/milestones/M013/phases/P02/tasks/T02-PLAN.md;tests/fixtures/m013-p03/re-init-adoption/expected-readopt-manifest.txt;tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/auth-status-green.txt;tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/subissue-rest-available.json;tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/labels-no-collision.json;tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/issue-list-M013-P02.json;tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/issue-list-M013-P02-T01.json;tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/issue-list-M013-P02-T02.json;tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/project-v2-node-query.json;tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/issue-view-body-M013-P02.txt;tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/issue-view-body-M013-P02-T01.txt;tests/fixtures/m013-p03/re-init-adoption/gh-stub-responses/issue-view-body-M013-P02-T02.txt;scripts/integrations/github-common.sh;scripts/verify/m013-p03-re-init-fixture.sh;scripts/verify/m013-p03-github-common-readopt.sh"
key_decisions:
  - "Gate scripts use explicit if/then/else blocks instead of X && pass || fail short-circuit chains for set -u safety; plan-text otherwise followed verbatim"
patterns_established:
  - "M013_GH_STUB_DIR env-var stub-selector pattern extended from preflights to marker-search family; awk-based JSON count + first-scalar extraction keeps integration helpers jq-optional"
drill_down_paths:
  - "none"
duration: "45"
verification_result: "pass"
completed_at: "2026-04-22T00:31:36Z"
---

## What Shipped

Two artifacts land in this task, both additive and decoupled:

1. **Re-init fixture tree** at `tests/fixtures/m013-p03/re-init-adoption/` — mirrors P02's fixture shape but with three key differences: (a) sidecar is genuinely absent (no `integrations/github.json` nor pending sentinel), (b) the `gh-stub-responses/` canned outputs simulate a pre-existing remote GitHub state where every projected orchestrator-id already exists as a marker-bearing Issue (one per phase id, one per task id) with a pre-existing Project v2 attached, (c) `expected-readopt-manifest.txt` is a pinned 10-line snapshot where every resource row is `reason=adopt` and the footer reads `upserts=0 skipped=0 errors=0 adopted=9`.

2. **Additive helper `gh_marker_search_remote`** appended to `scripts/integrations/github-common.sh`. Signature: `gh_marker_search_remote <repo-slug> <orchestrator-id>`. Returns Issue number on stdout + exit 0 for a unique marker hit, empty stdout + exit 1 for zero matches, empty stdout + exit 2 for duplicate matches. Fixture-driven via the P02-established `M013_GH_STUB_DIR` env-var pattern: when set, reads `issue-list-<oid>.json` from that dir; when unset, invokes `gh issue list --state all --search` against the remote. Uses awk for count + first-number extraction so there is no jq hard-dep.

## Verification

Both T01 gates pass:

- `scripts/verify/m013-p03-re-init-fixture.sh`: 14/14 assertions PASS.
- `scripts/verify/m013-p03-github-common-readopt.sh`: 5/5 assertions PASS (function defined, `bash -n` clean, M013-P02 -> 201, M013-P02-T01 -> 202, zero-match exit 1).

P02 byte-identity preserved: `scripts/verify/m013-p02-phase-suite.sh` still 8/8 PASS. P02 bash-3.2 compat scan still green across all P02 files + `github-common.sh`.

## Boundary Discipline

- T01 does NOT modify `scripts/integrations/github-init.sh`. T02 owns the re-init adoption branch wired to both of T01's artifacts.
- T01 does NOT touch any `SPEC-*` frontmatter, `KNOWLEDGE-INDEX.md`, `scripts/knowledge/rebuild-index.sh`, or any `wiki/` file — Knowledge-Layer Boundary (FR-9 + D014).
- The existing 12 P02-authored public functions in `github-common.sh` keep byte-identical bodies; the change is strictly additive (new function inserted immediately before the direct-execution self-check block, plus one extra line in the usage-hint echo list).

## Patterns Reinforced

- P02's `M013_GH_STUB_DIR` env-var stub-selector pattern now serves a second family of helpers (the marker-search path, not just the preflights). The convention: gate scripts export `M013_GH_STUB_DIR=<fixture>`, helpers check `[ -n "${M013_GH_STUB_DIR:-}" ]` and read `*-<key>.json` or similar deterministic filenames.
- Awk-based JSON count + first-scalar extraction (no jq hard-dep) matches the M013 design constraint of keeping integration helpers POSIX-friendly.
