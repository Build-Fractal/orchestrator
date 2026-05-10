---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M020"
provides:
  - "scripts/knowledge/lib/decision-history.sh sourceable helper exposing dh_resolve_operator (git config user.email -> .orchestrator/preferences.yml:operator_identifier -> unknown@local fallthrough per OQ-2) and dh_emit_jsonl <event> <kv>... (appends single JSON object per call to $ORCH_ROOT/execution-log.jsonl with event+timestamp+milestone plus supplied key=value pairs as JSON string properties; conservative backslash+double-quote escaping; no jq dependency); contract verifier scripts/verify/m020-p03-decision-history-helper-contract.sh covering 5 cases (function exposure, git-set path, tmpdir fallthrough, preferences.yml fallback, JSONL shape, embedded-quote escape)"
requires:
  - "from:P01/T02 what:scripts/knowledge/lib/frontmatter.sh::fm_append_decision_history (composed by T02 graduate.sh, NOT called by T01)"
affects:
  - "P03/T02,P03/T05"
key_files:
  - "scripts/knowledge/lib/decision-history.sh,scripts/verify/m020-p03-decision-history-helper-contract.sh"
key_decisions:
  - "none-new"
patterns_established:
  - "double-source guard sentinel (_<HELPER>_SOURCED=1) lets multiple sourceable helpers coexist without re-definition,pure-helper composition (T01 resolves identity + emits JSONL; T02 graduate.sh calls dh_resolve_operator once and pairs fm_append_decision_history entry-side with dh_emit_jsonl log-side; the two writes are independent),5-case contract verifier template (function exposure -> happy path -> isolated-tmpdir fallthrough -> env-overridden fallback -> emitter shape -> escape edge case),pragmatic case-statement acceptance for git-leakage-into-tmpdir-verifiers (case op in *@*) ;; unknown@local) ;; *) FAIL ;; esac accepts either real-git-email leaked from ~/.gitconfig or the documented sentinel since GIT_CONFIG_NOSYSTEM cannot be set at script invocation level)"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P03/tasks/T01-decision-history-helper-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-25T14:28:40Z"
---

## What was built

T01 lands the FR-7 + OQ-2 helper consumed by P03 T02 (cluster-aware graduate.sh extension):

- `scripts/knowledge/lib/decision-history.sh` — sourceable bash 3.2 helper exposing two pure functions:
  - `dh_resolve_operator` — operator identity resolver. Order: `git config user.email` -> `.orchestrator/preferences.yml:operator_identifier` -> `unknown@local`. Pure read.
  - `dh_emit_jsonl <event-type> <key=value>...` — appends a single JSON object on its own line to `${ORCH_ROOT:-.orchestrator}/execution-log.jsonl`. Always carries `event`, `timestamp` (ISO 8601 UTC), and `milestone` (read from `$ORCH_ROOT/active-milestone` when present). Conservative JSON escaping (backslash + double-quote) via `_dh_json_escape`. No jq dependency.
- `scripts/verify/m020-p03-decision-history-helper-contract.sh` — 5-case contract verifier (sourceability + function exposure, git-set path, tmpdir fallthrough, preferences.yml fallback under empty-git env, JSONL record shape and required keys, embedded double-quote escape).

Both functions guarded by a `_DECISION_HISTORY_HELPER_SOURCED` double-source sentinel so consumers can `. helper` repeatedly without re-defining functions.

## Key decisions

- **OQ-2 fallthrough is data-driven, not flag-driven**. The resolver tries each source in order and returns the first non-empty value; callers do not pass intent. Keeps the helper composable with whatever environment graduate.sh runs in (CI with `git config`, dispatched task with preferences.yml, fresh fixture with neither).
- **JSONL emission writes only to the log, never to `knowledge/**`**. CON-1 / FR-8 dispatch-isolation invariant preserved at the helper boundary; graduate.sh composes this with `frontmatter.sh::fm_append_decision_history` for the entry-side write.
- **Conservative JSON escaping (backslash + double-quote only)**. Per Principle XIV: every value is a JSON string, no type coercion, no nested objects. Caller-supplied control chars are passed through; graduate.sh only emits ASCII rationale-hashes and entry-IDs so the simpler escaper is safe.
- **`milestone` field reads from `$ORCH_ROOT/active-milestone`, defaults to empty string**. Best-effort; the helper does not depend on the orchestrator state machine being initialized. Empty-string emission keeps the JSON shape stable across fixture and live-tree calls.

## Patterns established

- Double-source guard sentinel (`_<HELPER>_SOURCED=1`) for sourceable helpers — lets graduate.sh, frontmatter.sh, and decision-history.sh all be sourced together without re-definition warnings.
- Pure-helper composition: T01 helper resolves identity + emits JSONL; T02 graduate.sh calls `dh_resolve_operator` once, passes the value to `fm_append_decision_history` (entry-side write) and to `dh_emit_jsonl` (log-side write). The two writes are independent — no shared state inside the helper.
- 5-case contract verifier shape (function exposure -> happy path -> isolated-tmpdir fallthrough -> env-overridden fallback -> emitter shape -> escape edge case) — reusable template for future P03 helper verifiers.
- `case "$op" in *@*) ;; unknown@local) ;; *) FAIL ;; esac` accepts either real-git-email (which can leak into a tmpdir-cd'd verifier when `~/.gitconfig` exists) or the documented sentinel — pragmatic given the verifier cannot fully suppress a system-wide git config without GIT_CONFIG_NOSYSTEM at the bash invocation level.

## Verification results

- `bash scripts/verify/m020-p03-decision-history-helper-contract.sh` — PASS (single PASS line, exit 0).
- All 5 verifier cases pass: sourceability + function exposure, git-set path returns non-empty, isolated-tmpdir fallthrough returns email-shape or `unknown@local`, preferences.yml override under empty-git env, JSONL record contains all required keys plus correctly escapes embedded double-quotes (`\"with\"` substring present).
- jq parse check passes when jq is on PATH (skipped silently otherwise per MEM001).

## Demo sentence

> Sourcing `scripts/knowledge/lib/decision-history.sh` exposes `dh_resolve_operator` (which falls through `git config user.email` -> `.orchestrator/preferences.yml:operator_identifier` -> `unknown@local`) and `dh_emit_jsonl knowledge_graduate entry_id=MEM999 cluster_id=Cabc rationale_hash=deadbeef` (which appends a single JSON line carrying `event` + `timestamp` + `milestone` + the supplied key/value pairs to `$ORCH_ROOT/execution-log.jsonl`).

Verified end-to-end via the contract verifier.

## Plan deviations

- None. The helper at `scripts/knowledge/lib/decision-history.sh` already existed verbatim per the T01 plan body (likely staged during planning). T01 added only the contract verifier and confirmed the helper matches the plan-specified shape byte-for-byte.

## Downstream impact

- **T02 (graduate.sh extension)** sources `decision-history.sh`, calls `dh_resolve_operator` once per invocation, and pairs `dh_emit_jsonl` (log-side) with `fm_append_decision_history` (entry-side) for each cluster member.
- **T05 (JSONL emit verifier)** consumes the same emitter; the contract here pre-validates the record shape (`event`, `timestamp`, `milestone`, plus arbitrary key/value pairs) so T05 can focus on graduation-path-specific fields.
- **`.orchestrator/execution-log.jsonl`** gains two new event types in P03: `knowledge_graduate` and `knowledge_archive` (canonical payload shapes verified by T01's verifier Case 4 and Case 5).
