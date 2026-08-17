---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P05"
milestone: "M046"
name: "Phase-suite aggregator"
depends_on: [T04, T05]
---

## Prerequisites

- T01–T05 complete: all five P05 verifiers exist on disk:
  `tools/verify/m046-p05-scope-guard-deny.sh`, `tools/verify/m046-p05-install-wiring.sh`,
  `tools/verify/m046-p05-driver-policy.sh`, `tools/verify/m046-p05-sc5-write-tool-scope.sh`,
  `tools/verify/m046-p05-sc15-verification-immutability.sh`.
- `tools/verify/m046-p04-phase-suite.sh` (exists) — the aggregator template to model on.

## Description

Author `tools/verify/m046-p05-phase-suite.sh`, the P05 phase-close gate. It aggregates the five
P05 verifiers, emits one `SUITE:` line per member and a final `SUMMARY:` line, and exits 0 iff
5/5 pass. Straight-line invocation per AD-19 — five literal `bash <path>` calls, no
loop-over-array. Milestone-prefixed name per the P00-clobber lesson.

## Steps

1. Create `tools/verify/m046-p05-phase-suite.sh` modeled verbatim on
   `tools/verify/m046-p04-phase-suite.sh`:
   - `#!/usr/bin/env sh`; `set -u`; `REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$REPO_ROOT"`.
   - `pass=0; fail=0`; an `emit_suite_result()` helper printing `SUITE: <name> PASS|FAIL` and
     incrementing counters.
   - Five straight-line blocks (each: `bash tools/verify/m046-p05-<name>.sh`; `rc=$?`;
     `emit_suite_result "$rc" "m046-p05-<name>.sh"`) for, in order:
     `scope-guard-deny`, `install-wiring`, `driver-policy`, `sc5-write-tool-scope`,
     `sc15-verification-immutability`.
   - `printf 'SUMMARY: pass=%d fail=%d\n' "$pass" "$fail"`; `exit 0` iff `fail -eq 0`, else `exit 1`.

## Must-Haves

- Truth: the suite aggregates all five P05 verifiers and reports 5/5.
- Artifact: `tools/verify/m046-p05-phase-suite.sh` (min 40 lines, contains "SUMMARY:").
- Key Link: `tools/verify/m046-p05-phase-suite.sh` → `m046-p05-scope-guard-deny.sh`.

## Verification

```bash
bash tools/verify/m046-p05-phase-suite.sh
```

## Inputs

### From Previous Tasks
- The five `tools/verify/m046-p05-*.sh` verifiers (T01–T05) — each is a self-contained `bash <path>` invocation exiting 0 on pass. The suite calls them straight-line and aggregates exit codes.

### From Disk (Pre-existing)
- `tools/verify/m046-p04-phase-suite.sh` — the exact aggregator shape (helper + straight-line member calls + SUMMARY + exit).

## Constraints

- AD-19: no loop-over-array; literal `bash <path>` per member.
- Because the members T04/T05 run the real installer into isolated scratch HOMEs, the suite
  inherits that isolation transitively — it does not itself touch `~/.claude`. It MUST NOT set or
  override `HOME` globally (each member manages its own scratch HOME).

## Expected Output

`bash tools/verify/m046-p05-phase-suite.sh` prints five `SUITE: m046-p05-*.sh PASS` lines and
`SUMMARY: pass=5 fail=0`, exit 0.
