---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P03"
milestone: "M013"
provides:
  - "graphql-call-shape-lint; fr5-three-shape-whitelist; mutation-name-awk-extractor; t03-selftest-gate"
requires:
  - "P02-github-init.sh-mutations; T02-projectsV2-query-not-flagged; scripts/integrations-scope"
affects:
  - "scripts/verify/graphql-call-shape.sh; scripts/verify/m013-p03-graphql-call-shape-selftest.sh"
key_files:
  - "scripts/verify/graphql-call-shape.sh;scripts/verify/m013-p03-graphql-call-shape-selftest.sh"
key_decisions:
  - "awk regex anchored on literal mutation-lparen then walks past rparen-lbrace — forward-compatible with P04 assigned-variable/heredoc shapes without a P04-era edit; scope narrowed to scripts/integrations/github-star.sh with find -maxdepth 1 to exclude scripts/diagnostics/wiki-giscus-remap.sh updateDiscussion (M012 scope, not M013 FR-5); queries using query-lparen are skipped by the mutation-lparen anchor so T02 projectsV2 query is unconstrained; pre-whitelisted updateProjectV2ItemFieldValue so P04 passes on the day it lands without editing the lint"
patterns_established:
  - "scoped-glob lint (find -maxdepth 1 -name prefix-star.sh) + optional dollar-1 path override for tempdir fixture tests; forward-compatible whitelist lint anticipating downstream task call shapes"
drill_down_paths:
  - "none"
duration: "35"
verification_result: "pass"
completed_at: "2026-04-22T00:51:01Z"
---

Shipped `scripts/verify/graphql-call-shape.sh`: the FR-5 GraphQL call-shape CI lint. Scans `scripts/integrations/github-*.sh` for mutation invocations, extracts the top-level mutation name, and asserts membership in the three-shape whitelist (`createProjectV2`, `addProjectV2ItemById`, `updateProjectV2ItemFieldValue`). P04's `updateProjectV2ItemFieldValue` is pre-whitelisted so the lint passes on the day P04 lands.

Changes:

- `scripts/verify/graphql-call-shape.sh` (new, exec bit set): scoped scan via `find -maxdepth 1 -name 'github-*.sh'` — deliberately excludes `scripts/diagnostics/wiki-giscus-remap.sh`'s `updateDiscussion` ([M012](../../../../../milestones/M012/index.md) wiki scope, out of M013 FR-5). Accepts an optional `$1` path override so the selftest can point at a tempdir fixture. Mutation-name extraction is a pure awk pass anchored on `mutation\(` — queries (`query(`) are skipped by the anchor, so T02's `projectsV2` discovery query is correctly unconstrained. Emits one `SHAPE: <name>` diagnostic line per match (CI operator visibility), dedupes, asserts whitelist membership, fails with `FAIL: graphql-call-shape.sh unexpected shape: <name>` on any fourth shape or zero-mutation regression. PASS line includes shape count.
- `scripts/verify/m013-p03-graphql-call-shape-selftest.sh` (new, exec bit set): 5-assertion T03 gate. (1) Live repo lint exits 0. (1b) `SHAPE: createProjectV2` present. (1c) `SHAPE: addProjectV2ItemById` present. (2) Tempdir fixture with `github-evilrogue.sh` (injects `deleteProjectV2` mutation) + copy of real `github-init.sh` — assert the lint's stderr contains `unexpected shape: deleteProjectV2`. (3) Fixture run exits non-zero.

Invariants preserved:

- FR-5: exactly three mutation shapes whitelisted. Any fourth fails the lint.
- FR-12 Claude-Code-only v1: lint is a shell script invoked by bash — no runtime-specific coupling.
- D014 Knowledge-Layer Boundary: zero writes to `knowledge/spec/`, `KNOWLEDGE-INDEX.md`, or `scripts/knowledge/rebuild-index.sh`.
- MEM001 bash 3.2: no `declare -A`, no `mapfile`, no process substitution. Uses parallel IFS-newline loops and indexed arrays.
- MEM013 AD-19 `Check:` shape: gate commands are single-script-file invocations (`bash scripts/verify/graphql-call-shape.sh` and `bash scripts/verify/m013-p03-graphql-call-shape-selftest.sh`).
- Query scan-scope narrowing: planner decision locked in — FR-5 governs *mutations*, not queries; `scripts/diagnostics/wiki-giscus-remap.sh` is explicitly out of scope via the `github-*.sh` name glob.
- T01/T02 gates unmodified and still green.

Key judgment call: the awk regex anchors on the literal `mutation\(` and walks the substring after `){` to capture the identifier. This intentionally tolerates both the P02 single-line `--field query='mutation(...){<name>(...)}'` shape and the assigned-variable / heredoc shape anticipated for P04's sync mutations — the lint is forward-compatible without a P04-era edit.

Verification results (all PASS):

- `graphql-call-shape.sh` vs live repo: exit 0, `SHAPE: createProjectV2` + `SHAPE: addProjectV2ItemById` + `PASS: graphql-call-shape.sh 2 mutation shapes, all whitelisted`.
- `m013-p03-graphql-call-shape-selftest.sh`: 5/5 PASS.
- `m013-p02-phase-suite.sh`: 8/8 PASS (P02 byte-identity protected).
- `m013-p03-re-init-fixture.sh`: 14/14 PASS.
- `m013-p03-github-common-readopt.sh`: 5/5 PASS.
- `m013-p03-re-init-adoption.sh`: 6/6 PASS.
- `m013-p03-re-init-auto-mode.sh`: 2/2 PASS.
