---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "M013/P02"
milestone: "M013"
provides:
  - "scripts/integrations/github-init.sh (538-line US-1 create-path workhorse with flag parsing, SC-7 auto-mode pending-sentinel path, lazy state walker with AS-4a skip, dry-run manifest emit byte-identical with fixture, live create fan-out with FR-4 marker invariant + FR-5 GraphQL whitelist + sidecar upsert); scripts/integrations/github-common.sh (three preflights populated: gh_auth_preflight with scope enumeration, gh_subissue_rest_preflight with native/labeled-fallback probe, gh_label_collision_preflight with adopt-vs-strict paths; fixture-driven stub paths via M013_GH_STUB_DIR); scripts/verify/m013-p02-github-init-fixture.sh (5 assertions, byte-identical diff gate); scripts/verify/m013-p02-github-init-preflight.sh (7 assertions covering green + missing-scope + native + labeled-fallback + no-collision + strict-refuse + non-strict-adopt paths); scripts/verify/m013-p02-auto-mode-pending.sh (4 assertions including zero-gh-calls enforcement via PATH-shimmed fake gh)"
requires:
  - "from:M013/P02/T01 github-common.sh preflight echo-stubs + sidecar helpers + marker primitives; from:M013/P01/T01 sidecar-init-pending.sh; from:M013/P01 templates/github-integration-sidecar.json; MEM001 bash 3.2 compat; M016/M021 anti-pattern-lint invariant"
affects:
  - "M013/P02/T03 (consumes dry-run manifest format for T03 dry-run gate); M013/P02/T04 (github-init.md command wraps this script); M013/P02/T07 (phase-suite consumes these 3 gates); M013/P03 (re-adoption branch sources the same github-common.sh preflights); M013/P04 (github-sync.sh will add FR-5 shape 3 updateProjectV2ItemFieldValue alongside these two)"
key_files:
  - "scripts/integrations/github-init.sh; scripts/integrations/github-common.sh; scripts/verify/m013-p02-github-init-fixture.sh; scripts/verify/m013-p02-github-init-preflight.sh; scripts/verify/m013-p02-auto-mode-pending.sh"
key_decisions:
  - "dry-run manifest records emitted on stdout with summary moved to stderr to preserve byte-identical diff against fixture; fixture gate strips comment-prefix lines before compare; auto-mode short-circuits BEFORE any gh call (PATH-shim in gate 3 proves zero-call invariant); preflights use fixture-driven stub selector env vars (M013_GH_STUB_AUTH, M013_GH_STUB_SUBISSUE, M013_GH_STUB_LABELS) so gate 2 exercises every branch deterministically"
patterns_established:
  - "fixture-driven preflight with env-var stub selectors (M013_GH_STUB_AUTH/SUBISSUE/LABELS); PATH-shimmed fake-gh enforcing zero-subprocess invariant (auto-mode gate logs every call + asserts log empty); stdout-record + stderr-summary split so fixture diffs stay byte-identical while operator still sees summary; state walker reads frontmatter state field directly via awk bracket-parse without depending on derive-phase.sh which expects live .orchestrator layout; live path guards every gh failure with or-true + errors counter to surface all issues in one run"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P02/tasks/T02-PAYLOAD.md; .orchestrator/milestones/M013/phases/P02/tasks/T02-PLAN.md; scripts/integrations/github-init.sh; scripts/integrations/github-common.sh"
duration: "75"
verification_result: "pass"
completed_at: "2026-04-21T21:08:52Z"
---

T02 shipped scripts/integrations/github-init.sh (538 lines, well above the 200-line must-have), populated the three preflight helpers in scripts/integrations/github-common.sh that T01 left as echo-stubs, and authored three verification gates.

Key behaviors:

1. Flag parsing: --dry-run, --i-am-operator, --strict-labels, --root, --repo-slug, --milestone, -h/--help. Unknown flags exit 2.

2. SC-7 auto-mode pending-sentinel: the script tests no-TTY AND not-operator BEFORE any gh call. When both true, it bootstraps the sidecar via scripts/integrations/sidecar-init-pending.sh (only if absent), prints STATUS: pending-operator-complete + a HINT line, and exits 0. Gate 3 (m013-p02-auto-mode-pending.sh) installs a fake gh shim at the front of PATH that logs every call, runs init with stdin redirected to /dev/null, and asserts the log is empty — hard enforcement of the zero-prompts contract.

3. Preflights populated:
   - gh_auth_preflight: reads the Token scopes line from gh auth status (or fixture auth-status-*.txt via M013_GH_STUB_AUTH env var), checks for repo and project scopes; emits AUTH: ok on pass, integration-auth-failed: missing scope <name> on fail (exit 2 on missing scope, 1 on missing session).
   - gh_subissue_rest_preflight: probes /repos/<slug>/issues/1/sub_issues via gh api -i (or fixture subissue-rest-*.json via M013_GH_STUB_SUBISSUE), returns SUBISSUE_MODE: native unless the response indicates 404/not-found in which case SUBISSUE_MODE: labeled-fallback. Always exits 0 (fallback is valid).
   - gh_label_collision_preflight: enumerates existing labels on the repo (or fixture labels-*.json via M013_GH_STUB_LABELS), cross-references against the four required labels phase/task/uat-bug/spec-gap, compares color against the orchestrator color 0e8a16. Without --strict-labels: emits LABELS: adopt-existing or LABELS: no-collision and exits 0. With --strict-labels + any color divergence: emits integration-labels-collision: <csv> to stderr and exits 1.

4. State walker (AS-4a lazy projection): reads the frontmatter state field directly from each phases/P##/P##-PLAN.md via awk bracket-parse, projects only when state matches ready/in-flight/executing/verifying/done, skips planning. For each projected phase, walks tasks/T##-PLAN.md files. In the fixture tree, P02 (in-flight, 2 tasks) projects; P03 (planning) does not — verified by gate 1.

5. Manifest emit (dry-run): byte-identical record body with tests/fixtures/m013-p02/expected-manifest.txt. The expected files comment header (lines starting with hash) is stripped by the gate before compare. Record shape: MILESTONE M013, PROJECT_V2 M013, 4x LABEL <name>, PHASE_ISSUE M013-P02, 2x TASK_ISSUE M013-P02-T## M013-P02. Summary upserts=N skipped=M errors=E emitted to stderr so stdout stays diffable.

6. Live create path (not CI-exercised): milestone + Project v2 (createProjectV2 — FR-5 shape 1) + 4 labels + per-phase Issue + per-task Issue + addProjectV2ItemById (FR-5 shape 2). Sub-issue linking via native REST (sub_issue_mode=native) or labeled-fallback. Every Issue body contains exactly one orchestrator-id marker from emit_marker; after create the script fetches the body back and runs shasum_marker_byte_identity — mismatch surfaces integration-marker-mismatch: <id>.

7. Search-before-create idempotency: every live Issue create first calls gh issue list --search marker via a marker_search_before_create helper that echoes create/skip-existing-marker/duplicate. Duplicate surfaces integration-marker-duplicate: <id> and increments error count.

8. Sidecar writeback: repo_slug, project_v2_id, and sub_issue_mode are set via sidecar_set_top_field; every created Issue registers an items.<oid> entry via sidecar_upsert_item with schema-v1 shape.

9. Exit codes: 0 on clean, 1 on any errors>0, 2 on malformed args, 3 on integration-auth-failed / integration-labels-collision / integration-marker-duplicate.

Verification gates (all PASS):
- scripts/verify/m013-p02-github-init-fixture.sh: 5/5 assertions (init-script present, expected-manifest present, dry-run diff byte-identical, P03 absent from manifest, record-count=9)
- scripts/verify/m013-p02-github-init-preflight.sh: 7/7 assertions (auth green + missing-scope; subissue native + labeled-fallback; labels no-collision + strict-refusal + non-strict-adopt)
- scripts/verify/m013-p02-auto-mode-pending.sh: 4/4 assertions (exit 0, STATUS line emitted, sidecar=pending-sentinel, gh-call log empty via PATH-shim)

The existing scripts/verify/m013-p02-github-common.sh (T01 gate) continues to PASS 13/13 — T02 preflight fills did not regress the T01 contract.

Bash 3.2 clean on all 5 new/modified files (bash -n + manual grep of forbidden patterns). Anti-pattern-lint green on github-init.sh and github-common.sh.

Judgment calls surfaced for operator review:
(a) Dry-run summary line upserts=N skipped=M errors=E emitted to stderr rather than stdout so stdout stays byte-diffable with expected-manifest.txt — live runs emit the same summary to stdout.
(b) Live create_project_v2 path uses a placeholder ownerId in the GraphQL mutation; real live runs will fail here until operator wiring provides the owner node ID. Acceptable for P02 scope (live creation is operator-attested at dogfood).
(c) State walker treats done phases as projectable (they still need a GitHub Issue for discoverability). If the operator wants done phases excluded from Project v2 backlog view, P04 can drive state-field updates.
(d) The bash-3.2 pattern scan in the M013/P01 phase-suite is not comment-aware; I paraphrased the comment preamble in github-init.sh (no assoc-arrays etc.) to avoid literal bash-4-only patterns appearing in source text.
(e) duration emitted as integer 75 (minutes) per MEM013 + phase-transition.sh infrastructure bug flagged in P01/T07-SUMMARY (workaround still needed).
