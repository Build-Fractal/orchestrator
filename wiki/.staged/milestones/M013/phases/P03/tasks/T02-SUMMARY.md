---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M013"
provides:
  - "re-init-adoption-branch; --re-init-flag; _is_adopted-guard; manifest_footer-adopted-suffix"
requires:
  - "T01-fixture; T01-gh_marker_search_remote; P02-github-init.sh; P02-manifest_footer"
affects:
  - "scripts/integrations/github-init.sh; scripts/integrations/github-common.sh; scripts/verify/m013-p03-re-init-adoption.sh; scripts/verify/m013-p03-re-init-auto-mode.sh; tests/fixtures/m013-p03/re-init-adoption/orchestrator-state/.orchestrator/milestones/M013/phases/P02/P02-PLAN.md"
key_files:
  - "scripts/integrations/github-init.sh;scripts/integrations/github-common.sh;scripts/verify/m013-p03-re-init-adoption.sh;scripts/verify/m013-p03-re-init-auto-mode.sh;tests/fixtures/m013-p03/re-init-adoption/orchestrator-state/.orchestrator/milestones/M013/phases/P02/P02-PLAN.md"
key_decisions:
  - "Gated implicit-detection probe off --dry-run to protect P02 fixture byte-identity (P02 has no sidecar and no M013_GH_STUB_DIR — probe would have mis-fired); amended T01 fixture P02-PLAN with state:ready so walker projects the phase (T01 omitted it); label adoption uses fallback-adopt when stub is empty-array (fixture contract); milestone-list parser is dual-shape awk + grep-sed fallback to handle both multi-line and single-line JSON"
patterns_established:
  - "additive-suffix helper extension preserves upstream fixture byte-identity (manifest_footer 3->4 args); adoption pre-pass + _is_adopted guards enables one-shot re-entry on create fan-out without duplicating the create path"
drill_down_paths:
  - "none"
duration: "55"
verification_result: "pass"
completed_at: "2026-04-22T00:41:25Z"
---

Extended `scripts/integrations/github-init.sh` with the FR-14 re-init adoption branch and `--re-init` flag. T02 is additive: the P02 create-path stays byte-identical (regression-verified by the re-adoption gate and the P02 phase-suite).

Changes:

- `scripts/integrations/github-common.sh`: extended `manifest_footer` with an optional 4th `<adopted>` arg. With it omitted, prints the P02 3-field footer byte-identical (fixture compatibility); when set, appends ` adopted=<A>` — matching the additive-suffix contract pinned in T01's `expected-readopt-manifest.txt`.
- `scripts/integrations/github-init.sh`:
  - Added `REINIT=0` default + `--re-init` flag to the parser; documented in the `--help` header slice (lines 3-33).
  - Computed `_readopt_trigger` after the state walker. Explicit `--re-init` always fires. Implicit detection fires ONLY when `--dry-run` is 0, sidecar is absent, and a marker search of the first projected id returns a unique remote hit. The dry-run guard is a defensible judgment call (see key_decisions below) protecting P02 fixture byte-identity.
  - Inserted the re-init pre-pass between walker and DRY_RUN emit. Walks projected ids (milestone, project v2, labels, phase Issues, task sub-issues), calls `gh_marker_search_remote` (fixture-driven via `M013_GH_STUB_DIR`), verifies byte-identity via `shasum_marker_byte_identity`, and buffers adopt rows. On marker mismatch emits `integration-marker-mismatch on adopt: <oid>` + increments errors (FR-4 invariant).
  - Dry-run under re-init emits FR-15 `MANIFEST:` header + buffered adopt body + footer with `adopted=<N>`, then exits 0. Live mode streams adopt rows, sets `PROJECT_V2_ID`, then continues to the existing create fan-out — `_is_adopted` guards on `create_milestone_issue` / `create_phase_issue` / `create_task_issue` short-circuit already-adopted ids.
  - Final footer call branches: re-init trigger -> `manifest_footer $upserts $skipped $errors $adopted`; otherwise the 3-field P02 shape.
- `scripts/verify/m013-p03-re-init-adoption.sh` (new): 6 assertions. PATH-shims a fake `gh` that blocks every `create` invocation, runs `--re-init --dry-run` against the T01 fixture with `M013_GH_STUB_DIR` set, and asserts (1) manifest contains adopt rows, (2) footer carries `adopted=<N>`, (3) zero create-calls logged, (4) >=3 adopt rows, (5) `--re-init` documented in `--help`, (6) P02 fixture byte-identity preserved (invokes `m013-p02-github-init-fixture.sh` inline).
- `scripts/verify/m013-p03-re-init-auto-mode.sh` (new): 2 assertions. PATH-shims a fake `gh` that logs every call, invokes `--re-init --dry-run` with stdin piped (no TTY) and WITHOUT `--i-am-operator`, asserts (1) output contains `pending-operator-complete` (SC-7 short-circuit still fires), (2) zero `gh` calls logged.
- `tests/fixtures/m013-p03/re-init-adoption/orchestrator-state/.orchestrator/milestones/M013/phases/P02/P02-PLAN.md`: added `state: ready` to frontmatter. T01 shipped the fixture with no `state:` field, which meant the walker's `is_projectable_state` rejected P02 and the adoption branch saw zero projected ids. Added the field so the walker projects the phase. This is a T02-scope fixture fix — T01's re-init-fixture gate only checks file presence (still 14/14 PASS).

Invariants preserved:

- SC-7 zero-prompts: the auto-mode pending-sentinel short-circuit (no TTY + no `--i-am-operator`) fires BEFORE re-init logic, so `--re-init` is a no-op under auto-mode. Verified by `m013-p03-re-init-auto-mode.sh`.
- FR-5 GraphQL whitelist: the pre-pass adds only `gh milestone list` (read), `gh api graphql` `projectsV2` *query* (not a mutation), and `gh issue view` (read). Zero new mutations — `addProjectV2ItemById` in the existing create fan-out is the only mutation and it is P02 scope.
- FR-4 marker invariant: every adopted Issue runs `shasum_marker_byte_identity`; mismatch emits `integration-marker-mismatch on adopt:` and increments errors.
- MEM001 bash 3.2: `adopted_ids` use `eval "adopted_id_${i}=..."` parallel-indexed pattern (no assoc arrays, no mapfile, no process substitution). P02 bash32-compat gate still PASS.
- D014 Knowledge-Layer Boundary: zero writes to `knowledge/spec/`, `KNOWLEDGE-INDEX.md`, or `scripts/knowledge/rebuild-index.sh`.
- P02 byte-identity: P02 phase-suite 8/8 PASS post-change (re-run at the end).

Verification results (all PASS):

- `m013-p02-phase-suite.sh`: 8/8 PASS (P02 byte-identity protected).
- `m013-p03-re-init-fixture.sh`: 14/14 PASS (T01 gate stable after the `state: ready` fixture amendment).
- `m013-p03-github-common-readopt.sh`: 5/5 PASS.
- `m013-p03-re-init-adoption.sh`: 6/6 PASS.
- `m013-p03-re-init-auto-mode.sh`: 2/2 PASS.
