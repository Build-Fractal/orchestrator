---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M021"
provides:
  - "scripts/verify/m021-p02-linter-scope.sh gate asserting marker-opt-in scope boundary (specs/references/docs excluded unless <!-- agent-facing --> marker present), tests/fixtures/m021-p02/scope-excluded-spec.md + scope-opted-in-spec.md fixtures, Agent-Facing Marker Convention subsection in references/engine.md"
requires:
  - "from:T01 what:anti-pattern-lint.sh with marker-opt-in scope logic; from:T02 what:AP-004..AP-009 anchors in ANTIPATTERNS.md"
affects:
  - "P02"
key_files:
  - "scripts/verify/m021-p02-linter-scope.sh,tests/fixtures/m021-p02/scope-excluded-spec.md,tests/fixtures/m021-p02/scope-opted-in-spec.md,references/engine.md"
key_decisions:
  - "AD-19"
patterns_established:
  - "Marker-opt-in scope boundary (<!-- agent-facing --> HTML comment promotes a specs/references/docs file into the linter default sweep); synthetic tempdir tree for scope-gate tests (copy linter + fixtures into mktemp -d with specs/ references/ docs/ subdirs, let linter PROJECT_ROOT resolve to tempdir)"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P02/tasks/T04-PLAN.md,.orchestrator/milestones/M021/phases/P02/tasks/T04-PAYLOAD.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-17T19:05:14Z"
---

Shipped the scope-boundary gate and marker-convention documentation for the M021/P02 linter widening.

## What Was Built

- tests/fixtures/m021-p02/scope-excluded-spec.md — specs-style fixture with a Class-A triggering bash fence, NO marker.
- tests/fixtures/m021-p02/scope-opted-in-spec.md — same content plus a literal <!-- agent-facing --> marker above the fence.
- scripts/verify/m021-p02-linter-scope.sh — 10-assertion gate covering (a) fixture content is Class A under --fixture, (b) default sweep skips tests/fixtures/ unmarked files, (c) marker opts-in specs/, references/, and docs/ files in a synthetic tempdir tree, (d) unmarked specs/references/docs files in the same synthetic tree are excluded, (e) live repo sweep reports LINT PASS, (f) references/engine.md documents 'agent-facing' and contains the literal marker example.
- references/engine.md — appended 'Agent-Facing Marker Convention' subsection before Cross-References, documenting what the marker is, default-scanned vs opt-in directories, placement rules, when-to-add guidance, and a four-backtick-wrapped example so the linter fence-tracker does not descend into the sample bash fence.

## Key Decisions

- Synthetic tempdir technique (from plan Step 3): copy the linter into the tempdir's scripts/verify/ so its PROJECT_ROOT resolution lands on the tempdir. This exercises the default-sweep codepath while isolating scope to the fixture tree.
- Four-backtick outer fence in the engine.md Example block (per plan Constraints note): prevents the linter fence-tracker from entering the example bash fence if references/engine.md is ever later opted-in.

## Verification

- bash scripts/verify/m021-p02-linter-scope.sh exits 0 with PASS: m021-p02-linter-scope.sh. All 10 assertions pass after T04-SUMMARY.md is written (which causes the linter's active-PAYLOAD filter to skip T04-PAYLOAD, matching the T01 pattern documented in the T01 summary note).
- bash scripts/verify/anti-pattern-lint.sh exits 0 (LINT PASS) on the live repo.
- bash scripts/verify/m021-p02-linter-v2.sh continues to pass (no changes to fixture corpus or ANTIPATTERNS entries).
