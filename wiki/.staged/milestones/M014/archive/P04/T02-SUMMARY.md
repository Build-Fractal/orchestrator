---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M014"
provides:
  - "FR-5 complexity probe full body (heuristic FR/user-story/token/TODO counts + CC-gated LLM contradiction pass + verdict logic + spec_complexity_probe JSONL emission); scripts/verify/m014-p04-complexity-probe-full.sh gate verifier"
requires:
  - "from:T01 what:.orchestrator/config.yml specify.complexity_thresholds pinned scalars; from:P01 what:scripts/knowledge/spec-complexity-probe.sh stub to be replaced; from:disk what:scripts/dispatch/dispatch-interface.sh (CC LLM round-trip surface, defensive)"
affects:
  - "T04 specify.sh three-way prompt wiring (consumes probe stdout/stderr/exit-0 unchanged); T07 phase-suite (runs gate verifier); M009 runtime-parity audit"
key_files:
  - "scripts/knowledge/spec-complexity-probe.sh,scripts/verify/m014-p04-complexity-probe-full.sh"
key_decisions:
  - "Deviation: added _strip_yaml_scalar helper to normalize YAML scalars post-read (plan-verbatim awk progs did not strip inline #comments; T01 config uses inline # annotations on every threshold); Deviation: replaced grep -cE ... || echo 0 with grep -cE ... | head -n 1 + : ${VAR:=0} fallback (plan-verbatim form produced multi-line 0\n0 output on grep no-match causing [: integer expression expected errors and breaking FR_COUNT comparisons); both deviations are correctness fixes consistent with P01 T02/T03/T05/T06 deviation precedent"
patterns_established:
  - "YAML-scalar-comment-stripper helper for inline # annotated config values; grep -c | head -n 1 + variable-default fallback for robust count capture under grep no-match conditions; defensive LLM pass pattern (runtime-detect + env-gate + dispatch-executable + prompt-file-exists, all must hold); single-line verdict + four-field stderr shape stable across P01 stub to P04 full-body replacement"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P04/tasks/T02-PAYLOAD.md,.orchestrator/milestones/M014/phases/P04/tasks/T02-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-23T00:41:44Z"
---

T02 replaced the P01 stub body of scripts/knowledge/spec-complexity-probe.sh with the full FR-5 implementation. Caller contract preserved (positional spec-path arg, single-line probe= stdout, four key=value stderr lines, exit 0 on success / 1 on missing arg or file). Corpus verdict table (CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0): [M011](../../../../milestones/M011/index.md) above-threshold reason=fr_count>=15 (fr_count=16); [M013](../../../../milestones/M013/index.md) spec not yet created (deferred to M013 P04); [M016](../../../../milestones/M016/index.md) below-threshold (hardening-spec-exception, fr_count=0); [M021](../../../../milestones/M021/index.md) below-threshold (hardening-spec-exception, fr_count=0); M022 above-threshold reason=user_story_count>=5 (fr_count=10, user_story_count=5); [M024](../../../../milestones/M024/index.md) above-threshold reason=fr_count>=15 (fr_count=20). All six match expected verdicts from T01 calibration corpus. CC-simulation: CLAUDE_CODE_RUNTIME=1 with prompt template absent yields contradiction_signals=0 via defensive fallback chain. Under Codex/Cursor (CLAUDE_CODE_RUNTIME=0), zero LLM calls per CON-2. Observability: spec_complexity_probe JSONL records append to .orchestrator/execution-log.jsonl (best-effort). Gate verifier scripts/verify/m014-p04-complexity-probe-full.sh exits 0 with PASS. Anti-pattern lint PASS on both shipped files. Bash 3.2 compat clean. Two verbatim-body deviations applied as correctness fixes with documented rationale (YAML inline-comment stripping; grep -c no-match handling).
