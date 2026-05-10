---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M021"
name: "Dogfood attestation gate — scripts/verify/m021-p04-dogfood-attestation.sh (asserts M021's own auto-execution of P01–P04 observed zero user prompts and every phase verified pass)"
depends_on: ["T01"]
---

## Prerequisites

- M021 phases P01, P02, P03 have closed with `P##-SUMMARY.md` files containing `verification_result: pass` in frontmatter.
- `.orchestrator/milestones/M021/auto-loop-result.txt` exists (phase-transition marker file the auto loop writes each cycle).
- `.orchestrator/milestones/M021/execution-log.jsonl` exists (append-only JSONL of every dispatch + verification event during M021's auto run).
- T01 has produced `tests/fixtures/m021-prompt-corpus.txt` (read only indirectly — the gate asserts the corpus exists as a landmark file confirming P04 reached T01 under the hook).

No script source dependencies beyond the P03 hook being live (the hook's liveness is what the dogfood attestation validates).

## Description

Author `scripts/verify/m021-p04-dogfood-attestation.sh` — the AD-8 dogfood-closeout gate. It asserts that M021 itself ran under `orchestrator:auto` through phases P01–P04 without triggering user prompts, providing the empirical ground truth that complements T02's classifier-based SC-1 proof.

The gate performs three checks:

1. **Auto-loop marker exists**: `.orchestrator/milestones/M021/auto-loop-result.txt` is present and is non-empty. This file is written at each auto-loop state transition; its presence is a necessary (not sufficient) condition that the auto loop ran.
2. **No prompt events in execution log**: `.orchestrator/milestones/M021/execution-log.jsonl` contains no records whose JSON `event` field equals `user_prompt`, `safety_prompt`, or `hook_reject_unexpected`. The gate is tolerant of the hook's expected `hook_reject_recovered` events (agent got a REJECT diagnostic and retried with a wrapper) — those are the designed recovery path, not prompts.
3. **All closed phases verified pass**: each `.orchestrator/milestones/M021/phases/P*/P*-SUMMARY.md` that exists contains a `verification_result: pass` YAML-frontmatter line. Missing summaries (uncompleted phases) do not fail the gate — only present-but-failed summaries do.

Any failing check emits a `FAIL:` line with a specific remediation pointer. All-pass exits 0 with `PASS: m021-p04-dogfood-attestation.sh`.

## Steps

### Step 1: Author `scripts/verify/m021-p04-dogfood-attestation.sh`

Target scaffold:

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p04-dogfood-attestation.sh — AD-8 dogfood attestation.
#
# Asserts M021's own orchestrator:auto execution of P01–P04 observed:
#   (a) auto-loop marker present and non-empty
#   (b) execution-log.jsonl has no user_prompt / safety_prompt / hook_reject_unexpected events
#   (c) every present P*-SUMMARY.md records verification_result: pass
#
# Exit 0 on all-pass; 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
M021_DIR="${REPO_ROOT}/.orchestrator/milestones/M021"
AUTO_LOOP="${M021_DIR}/auto-loop-result.txt"
EXEC_LOG="${M021_DIR}/execution-log.jsonl"
PHASES_DIR="${M021_DIR}/phases"
CORPUS="${REPO_ROOT}/tests/fixtures/m021-prompt-corpus.txt"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# --- Landmark: P04 reached T01 (corpus fixture exists) ---
if [ -f "$CORPUS" ]; then
  pass "landmark: tests/fixtures/m021-prompt-corpus.txt present (P04/T01 reached)"
else
  fail "landmark: corpus fixture" "missing at $CORPUS"
fi

# --- Check (a): auto-loop marker ---
if [ -f "$AUTO_LOOP" ] && [ -s "$AUTO_LOOP" ]; then
  pass "check-a: auto-loop marker present and non-empty"
else
  fail "check-a: auto-loop marker" "missing or empty at $AUTO_LOOP"
fi

# --- Check (b): no prompt events in execution log ---
if [ -f "$EXEC_LOG" ]; then
  # Any line containing a prompt-class event field triggers a failure.
  # Use -F (fixed strings) across three independent fixed-string needles
  # so a false-positive on a user-written log comment is minimized.
  for needle in '"event":"user_prompt"' '"event":"safety_prompt"' '"event":"hook_reject_unexpected"'; do
    if grep -qF "$needle" "$EXEC_LOG"; then
      fail "check-b: no prompt events" "found [$needle] in $EXEC_LOG"
    fi
  done
  # Positive assertion: the gate emits a PASS line only when NO needle matched.
  # Use a re-check to avoid conditional-on-fail-count logic that elides the PASS.
  _b_clean=1
  for needle in '"event":"user_prompt"' '"event":"safety_prompt"' '"event":"hook_reject_unexpected"'; do
    if grep -qF "$needle" "$EXEC_LOG"; then
      _b_clean=0
    fi
  done
  if [ "$_b_clean" -eq 1 ]; then
    pass "check-b: no prompt events in execution-log.jsonl"
  fi
else
  fail "check-b: execution log" "missing at $EXEC_LOG"
fi

# --- Check (c): every present P*-SUMMARY.md records verification_result: pass ---
_c_clean=1
for summary in "$PHASES_DIR"/P*/P*-SUMMARY.md; do
  if [ ! -f "$summary" ]; then
    continue  # glob fell through, no summaries yet
  fi
  if grep -qE '^verification_result: *"?pass"?' "$summary"; then
    pass "check-c: $(basename "$(dirname "$summary")") verified pass"
  else
    fail "check-c: $(basename "$(dirname "$summary")") verification_result" "not 'pass' in $summary"
    _c_clean=0
  fi
done
if [ "$_c_clean" -eq 1 ]; then
  pass "check-c: every present phase summary records verification_result: pass"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-dogfood-attestation.sh"
  exit 0
fi
echo "FAIL: m021-p04-dogfood-attestation.sh ($fail_count failures)"
exit 1
```

### Step 2: Make executable

```
chmod +x scripts/verify/m021-p04-dogfood-attestation.sh
```

### Step 3: Run

```
bash scripts/verify/m021-p04-dogfood-attestation.sh
```

Must exit 0 with final line `PASS: m021-p04-dogfood-attestation.sh`. If the gate runs before P04/T03 itself completes (self-referential window), the check (c) sweep will simply report PASS for P01/P02/P03 and skip P04 (no summary yet). That is correct behavior.

### Step 4: Confirm run-suite.sh discovers it

The gate matches `m021-p04-*.sh` — `scripts/verify/run-suite.sh m021 P04` discovers it automatically.

## Must-Haves

- `scripts/verify/m021-p04-dogfood-attestation.sh` exists, is executable.
- Gate emits `PASS:`/`FAIL:` lines per check.
- Gate exits 0 only when: landmark holds, auto-loop marker present + non-empty, no prompt-class events in execution-log.jsonl, and every present `P*-SUMMARY.md` records `verification_result: pass`.
- Tolerant of missing phase summaries (in-flight phases do not fail the gate).
- Tolerant of `hook_reject_recovered` events — those represent the AD-6 designed recovery path (agent got a REJECT, picked a wrapper, retried successfully), not prompts.
- Bash 3.2 compatible — no forbidden constructs.

## Verification

- `bash scripts/verify/m021-p04-dogfood-attestation.sh` exits 0.
- `bash scripts/verify/run-suite.sh m021 P04` includes `PASS: m021-p04-dogfood-attestation.sh` among its reported assertions.
- `bash scripts/verify/m021-p04-bash32-compat.sh` (T05) reports PASS on this file.

## Inputs

### From Previous Tasks

- `tests/fixtures/m021-prompt-corpus.txt` (from T01) — read only as a landmark file confirming P04 reached T01.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M021/auto-loop-result.txt` — auto-loop phase-transition marker. Single text line containing `AUTO:<STATE>` + phase/milestone metadata. Existing file (written during P01–P03 auto execution).
- `.orchestrator/milestones/M021/execution-log.jsonl` — append-only JSONL execution log. Gate greps for three fixed-string `"event":"..."` markers indicating user prompts; presence of any = fail. Absence of all = pass.
- [`.orchestrator/milestones/M021/phases/P01/P01-SUMMARY.md`](../../../../../milestones/M021/phases/P01/P01-SUMMARY.md), `P02/P02-SUMMARY.md`, `P03/P03-SUMMARY.md` — closed-phase summaries. Each must have YAML-frontmatter line matching `^verification_result: *"?pass"?`.
- [`.orchestrator/milestones/M021/phases/P04/P04-SUMMARY.md`](../../../../../milestones/M021/phases/P04/P04-SUMMARY.md) — may or may not exist when this gate runs (self-referential). Missing is acceptable; present-but-not-pass is not.

## Constraints

- **Read-only**: the gate reads state-on-disk landmarks and does not mutate any file.
- **No reliance on absolute paths**: `REPO_ROOT` resolves from `BASH_SOURCE[0]`.
- **Portable grep**: uses `grep -qF` (fixed-string, quiet) and `grep -qE` (extended regex, quiet). Both are POSIX.
- **Glob-safe**: `for summary in ...P*-SUMMARY.md` tolerates no-match via the `[ ! -f "$summary" ]` check (the literal unmatched glob becomes the loop value, which fails the `-f` test). No `shopt -s nullglob` (not universally available under Bash 3.2 invocations).
- **Bash 3.2 compatibility** (constitution IX).
- **Single-script-file invocation** at the agent-facing site (AD-19) — `bash scripts/verify/m021-p04-dogfood-attestation.sh`. Gate internals may use `$()`, pipes, etc. freely (MEM004 + AP-004 scope-of-enforcement carve-out).
- **Tolerates hook_reject_recovered events**: the gate does NOT fail if the execution log contains `"event":"hook_reject_recovered"` entries. Those are expected — AD-6 defines reject + retry as the recovery path, not a prompt.

## Expected Output

- `scripts/verify/m021-p04-dogfood-attestation.sh` exists and is executable.
- `bash scripts/verify/m021-p04-dogfood-attestation.sh` exits 0 under current M021 state (P01/P02/P03 closed, P04 in progress).
- Output contains ≥5 `PASS:` lines (landmark, check-a, check-b, check-c[per phase], check-c summary) and final `PASS: m021-p04-dogfood-attestation.sh`.
- `bash scripts/verify/run-suite.sh m021 P04` includes this gate among its reported PASS entries.
