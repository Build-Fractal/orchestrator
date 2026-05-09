---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P06"
milestone: "M035"
provides:
  - "update_run JSONL emission for non-rollback dispatch (scripts/lifecycle/run-update.sh: emit_update_run_event helper + resolve_target_version helper + --no-emit-jsonl flag + emission calls in npm/homebrew/git-fall-through arms; appends one event per dispatch attempt to .orchestrator/observability/<YYYY-MM-DD>.jsonl per M027 convention; honors 5-condition suppression matrix per D013) + D013 decision (5-condition suppression matrix + JSONL event schema + FR-16 no-new-suppression-knob discipline + best-effort emission contract) + task-grain verifier (m035-p06-update-run-jsonl-emission-shape.sh BATTERY pass=12)"
requires:
  - "from:M035/P06-T01 what:D012-heading-shape-precedent-for-D013-row from:M035/P06-T02 what:multi-source-dispatch-arms-and-T03-hook-comment-markers-in-npm-and-homebrew from:M035/P05-T02 what:rollback-path-printf-jsonl-idiom-mirrored-for-non-rollback-paths"
affects:
  - "P06/T04 (consumes D013 + emission surface for commands/update.md doc),P06/T05 (consumes the suppression matrix for acceptance-battery cross-condition coverage),P06/T06 (phase-grain rollup absorbs the 12-assertion verifier into the suite)"
key_files:
  - "scripts/lifecycle/run-update.sh,.orchestrator/DECISIONS.md,tools/verify/m035-p06-update-run-jsonl-emission-shape.sh"
key_decisions:
  - "D013 (update_run JSONL emission 5-condition suppression matrix: --no-emit-jsonl flag + ORCHESTRATOR_AUTO env var + update_source=none defensive guard + efficiency_footer.enabled carve-out + structural post-dispatch carve-out; emits one event per dispatch attempt with result=success|failure; emission failure must NOT abort the caller — helper always returns 0; FR-16 no new suppression knob beyond --no-emit-jsonl which inherits M027 opt-out pattern)"
patterns_established:
  - "best-effort-emission-helper-always-returns-0,5-condition-suppression-matrix-verbatim-from-M027,colon-fall-through-emission-at-end-of-file-for-git-arm,defensive-guard-against-update_source=none-protects-against-future-refactors,in-function-pipelines-are-AP-009-permitted-for-version-probe-helpers,stub-source-repo-fixture-pattern-for-source-repo-validation"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P06/tasks/T03-update-run-jsonl-emission-PLAN.md"
duration: "30m"
verification_result: "pass"
completed_at: "2026-05-09T23:42:05Z"
---

T03 ships the update_run JSONL event emission for the three non-rollback dispatch paths (git / npm / homebrew) in scripts/lifecycle/run-update.sh. The rollback path (P05 T02) already emits with op=rollback; T03 mirrors that idiom for non-rollback paths with op=update. Each dispatch attempt emits exactly one event (success OR failure) so the observability stream captures the failure-rate signal too. Events append to .orchestrator/observability/<YYYY-MM-DD>.jsonl per the M027 P00 convention.

Two helpers were added to run-update.sh as inline shell functions (preserving AD-19 single-script-file shape, matching T02s inline-helper pattern): emit_update_run_event encapsulates the suppression-matrix gating + mkdir -p + printf >> append; resolve_target_version is a best-effort post-dispatch version probe (bundle_version reuse for git, npm view for npm, brew info --json=v2 for homebrew) returning the literal string "unknown" on probe failure. The plans Step 3 carves out an explicit AP-009 exception for in-function pipelines — the guard fires on caller-side inline compound shapes, not function-body composition. Caller-side emission invocations stay flat (three-line snippet: _tv= / _rv= / if rc != 0 then _rv=failure / emit_update_run_event ...).

The --no-emit-jsonl flag (default off via NO_EMIT_JSONL=0 at top of file) is the only new operator-facing surface. Per FR-16, M035 introduces no new suppression knob beyond this flag — D013 documents it as inheriting the M027 opt-out pattern rather than a new knob class. The flag is opt-out only; it does NOT abort dispatch. ORCHESTRATOR_AUTO=1 short-circuits emission too, mirroring M027 auto-loop suppression. update_source=none has a defensive guard inside the helper (in practice the none arm exits 0 before the emission code path is reached).

Emission failure must NOT abort the caller — emit_update_run_event always returns 0 even when mkdir -p or printf >> fail. Observability is best-effort; dispatch success/failure stays authoritative. This is enforced via "|| return 0" suffixes on both side-effect calls.

D013 is appended to .orchestrator/DECISIONS.md slotted between D012 (T01) and D014 (T02), in the same ### D### — title heading-shape the cohort settled on. The body records the 5-condition suppression matrix verbatim, the JSONL event schema, the FR-16 discipline, and the best-effort emission contract. Bound to FR-13 / FR-15 / FR-16 / CON-7 / SC-13.

The 12-assertion verifier covers (1-7) structural shape (helpers, flag, env var, defensive guard, update_run literal in >= 3 positions, six-field JSONL template) + (8) D013 anchor + (9-11) three suppression conditions (dry-run, --no-emit-jsonl, ORCHESTRATOR_AUTO=1) + (12) clean dispatch yielding exactly one well-formed event with valid ISO 8601 UTC timestamp. The verifier stages a stub source repo with a stub install-claude-code.sh exiting 0 — this is the fixture pattern that lets the git arm reach its post-dispatch emission point under controlled conditions.

T01 + T02 regressions both green (BATTERY: pass=7 fail=0 and pass=13 fail=0 respectively). Two pre-existing unstaged operator-owned files (templates/phase-plan.md, .orchestrator/direct-mode-execution-log.jsonl) were left untouched per dispatch instructions.

## Patterns established

- Best-effort emission — emit_update_run_event always returns 0; mkdir -p and printf >> failures suffix with "|| return 0" so observability never aborts dispatch. Mirrors the rollback-path idiom but makes the never-abort guarantee explicit.
- 5-condition suppression matrix verbatim from M027 — D013 records the matrix mapping, with M027 (a/b/e) carrying over directly, (c) the new dispatch-suppression case, and (d) explicitly carved out as orthogonal so future authors do not mistakenly bind compression.efficiency_footer.enabled to JSONL emission.
- Colon fall-through emission for git arm — the git arms emission lives at end-of-file (after the existing orchestrator:update OK echo, before exit "$rc") rather than inside the case "$update_source" block, because the git arm uses a colon fall-through to the existing source-repo validation and install dispatch below. Diff stays minimal; existing path is byte-equivalent for git-source consumers.
- In-function pipelines are AP-009-permitted — the resolve_target_version helpers npm view / head / tr pipeline and brew info / grep / sed pipeline live inside function bodies. The AP-009 guard fires on caller-side inline compound shapes, not function-body composition. This is the same carve-out the rollback path uses for git -C "$SOURCE_REPO" log -1 ... pipelines.
- Stub source repo fixture pattern — the verifier stages a minimal source-repo tree with a stub install-claude-code.sh exiting 0 under a fixture-controlled path, then sets ORCHESTRATOR_SOURCE_REPO to that path so the git arms source-repo validation passes. This makes the verifier deterministic regardless of whether $HOME/Sites/orchestrator exists or is in any particular state.

## Verification

- bash tools/verify/m035-p06-update-run-jsonl-emission-shape.sh → BATTERY: pass=12 fail=0
- All 12 PASS lines match the plans Expected Output verbatim.
- T02 regression: bash tools/verify/m035-p06-multi-source-dispatch-shape.sh → BATTERY: pass=13 fail=0 (no regression).
- T01 regression: bash tools/verify/m035-p06-config-schema-shape.sh → BATTERY: pass=7 fail=0 (no regression).

## Caveats

- D013 is slotted numerically between D012 and D014 in DECISIONS.md (not appended at end-of-file) so the M035 P06 cohort stays in numeric order. T02s D014 verifier still finds its anchor via grep -nE "^### D014( |$)" which matches the heading regardless of file position.
- The emit_update_run_event helper does not deduplicate variable names against the rollback paths inline emission (which uses obs_dir/today/jsonl/ts). T03 uses obs_dir (same name; helper-scoped) plus today_emit/jsonl_emit/ts_emit (suffixed to avoid any future global-scope collision). Bash 3.2 has no local in POSIX-sh portable form for all variables, so suffixing is the safe pattern.
- Two unrelated unstaged files (templates/phase-plan.md, .orchestrator/direct-mode-execution-log.jsonl) were left untouched per the dispatch instructions — they are operator-owned WIP.

## Out-of-scope-found

- T04 territory (commands/update.md doc) — D013 cross-references commands/update.md, but the doc itself is T04s responsibility.
- T05 territory (acceptance battery cross-condition coverage) — T03 verifies emission shape against three suppression conditions; T05 will exercise the failure-path emission (dispatch returns non-zero -> result=failure) and the actual npm/brew binaries in CI.
