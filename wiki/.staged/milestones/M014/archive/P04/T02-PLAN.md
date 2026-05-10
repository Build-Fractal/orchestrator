---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M014"
name: "Full FR-5 scripts/knowledge/spec-complexity-probe.sh body replacement (heuristic counts + runtime-gated LLM contradiction pass + verdict logic + observability emission)"
depends_on: ["T01"]
---

## Prerequisites

- T01 shipped: `.orchestrator/config.yml` has pinned threshold values, `tests/fixtures/m014-p04/corpus-labels.tsv` exists, `CALIBRATION-MEMO.md` documents cutoffs.
- P01 stub `scripts/knowledge/spec-complexity-probe.sh` (lines 1-46, body emits unconditional `probe=below-threshold` with all-zero structured fields) — to be fully replaced.
- `scripts/dispatch/dispatch-interface.sh` exists (CC LLM round-trip surface; not invoked in probe's heuristic passes, only in the CC-only contradiction pass).
- `scripts/lifecycle/detect-capabilities.sh` exists (runtime detection).
- `templates/spec-complexity-contradiction-prompt.md` is shipped by T03 — **however, T02's probe logic gracefully degrades if the prompt is missing** (zero contradiction signals, never fails). T02 is structurally independent of T03.

## Description

Replace the P01 stub body of `scripts/knowledge/spec-complexity-probe.sh` with a full FR-5 implementation:

1. **Heuristic counts** (runtime-agnostic, always run): FR count, user-story count, raw-token count, TODO count, TODO density.
2. **Runtime-gated LLM contradiction pass** (CC only, guarded by env var + dispatch-interface availability + prompt presence): invokes `scripts/dispatch/dispatch-interface.sh` against `templates/spec-complexity-contradiction-prompt.md` and parses a single-line `contradictions=<N>` response.
3. **Verdict computation** against pinned thresholds from `.orchestrator/config.yml`, honoring the `hardening_spec_exception` rule.
4. **Observability emission**: appends one `spec_complexity_probe` JSONL record to `.orchestrator/execution-log.jsonl`.

Caller contract (`scripts/specify/specify.sh`) is unchanged: probe still reads `<spec-path>` as `$1`, emits single-line verdict on stdout, structured fields on stderr, exits 0 on success.

## Steps

### Step 1: Full replacement body of `scripts/knowledge/spec-complexity-probe.sh`

Replace the entire file contents. Verbatim body:

```bash
#!/usr/bin/env bash
# scripts/knowledge/spec-complexity-probe.sh — FR-5 complexity probe (full).
#
# P04/T02: full body replaces the P01 stub. Caller contract unchanged:
#   - Reads <spec-path> as positional $1.
#   - Emits exactly one line on stdout:
#       probe=below-threshold
#     OR
#       probe=above-threshold reason=<single-criterion>
#   - Emits structured fields on stderr, one key=value per line:
#       fr_count=<N>
#       user_story_count=<N>
#       todo_count=<N>
#       contradiction_signals=<N>
#   - Exits 0 on success; 1 on missing/unreadable input.
#
# Thresholds are read from .orchestrator/config.yml (specify.complexity_thresholds:).
# The CC-only contradiction-signal LLM pass is gated on:
#   - CLAUDE_CODE_RUNTIME=1 (or detect-capabilities.sh reports runtime=claude-code)
#   - SPEC_COMPLEXITY_PROBE_LLM != 0 (default: on under CC)
#   - scripts/dispatch/dispatch-interface.sh executable
#   - templates/spec-complexity-contradiction-prompt.md present
# Under Codex/Cursor (or any gate failing), contradiction_signals=0.
#
# Bash 3.2 compatible (no declare -A, no mapfile, no process substitution).

set -u

if [ $# -lt 1 ]; then
  echo "usage: spec-complexity-probe.sh <spec-path>" >&2
  exit 1
fi

SPEC_PATH="$1"
if [ ! -f "$SPEC_PATH" ]; then
  echo "spec-complexity-probe.sh: not found: $SPEC_PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG="${PROJECT_ROOT}/.orchestrator/config.yml"

# --- Helpers ---

# Read a YAML scalar under a two-level nested key (grep/sed only; no jq).
# Usage: yaml_nested specify complexity_thresholds fr_count
# Returns "" on miss.
yaml_nested() {
  _outer="$1"; _middle="$2"; _key="$3"
  # Extract the block starting at ^<outer>: up to next top-level key.
  _awk_prog='
    BEGIN { in_outer=0; in_middle=0 }
    /^[^ ]/ { in_outer=0; in_middle=0 }
    $0 ~ "^" outer ":" { in_outer=1; next }
    in_outer && $0 ~ "^  " middle ":" { in_middle=1; next }
    in_outer && /^  [^ ]/ && $0 !~ "^  " middle ":" { in_middle=0 }
    in_middle && $0 ~ "^    " key ":" { sub("^ *" key ": *", "", $0); print; exit }
  '
  awk -v outer="$_outer" -v middle="$_middle" -v key="$_key" "$_awk_prog" "$CONFIG" 2>/dev/null
}

# Read a top-level YAML scalar nested one deep. Usage: yaml_second specify contradiction_signal_criterion
yaml_second() {
  _outer="$1"; _key="$2"
  _awk_prog='
    BEGIN { in_outer=0 }
    /^[^ ]/ { in_outer=0 }
    $0 ~ "^" outer ":" { in_outer=1; next }
    in_outer && $0 ~ "^  " key ":" { sub("^ *" key ": *", "", $0); print; exit }
  '
  awk -v outer="$_outer" -v key="$_key" "$_awk_prog" "$CONFIG" 2>/dev/null
}

# --- Read thresholds ---

T_FR="$(yaml_nested specify complexity_thresholds fr_count)"
T_US="$(yaml_nested specify complexity_thresholds user_story_count)"
T_TOK="$(yaml_nested specify complexity_thresholds raw_token_count)"
T_DEN="$(yaml_nested specify complexity_thresholds todo_density)"
T_CONT="$(yaml_nested specify complexity_thresholds contradiction_signal_count)"
HARDEN="$(yaml_second specify hardening_spec_exception)"

# Fallbacks if config is malformed.
: "${T_FR:=15}"
: "${T_US:=5}"
: "${T_TOK:=8000}"
: "${T_DEN:=0.5}"
: "${T_CONT:=1}"
: "${HARDEN:=true}"

# --- Heuristic counts ---

FR_COUNT="$(grep -cE '^- \*\*FR-[0-9]+|^### FR-[0-9]+|^\*\*FR-[0-9]+' "$SPEC_PATH" 2>/dev/null || echo 0)"
US_COUNT="$(grep -cE '^### User (Story|Scenario)' "$SPEC_PATH" 2>/dev/null || echo 0)"
TOK_COUNT="$(wc -w < "$SPEC_PATH" 2>/dev/null | tr -d ' ')"
TODO_COUNT="$(grep -cE '<TODO' "$SPEC_PATH" 2>/dev/null || echo 0)"
SECTION_COUNT="$(grep -cE '^## ' "$SPEC_PATH" 2>/dev/null || echo 0)"

# Trim leading/trailing whitespace that wc sometimes emits under bash 3.2 macOS.
FR_COUNT="${FR_COUNT// /}"
US_COUNT="${US_COUNT// /}"
TODO_COUNT="${TODO_COUNT// /}"
SECTION_COUNT="${SECTION_COUNT// /}"
: "${TOK_COUNT:=0}"

# --- TODO density: TODO / (TODO + section_count), as a crude 0..1 float expressed in hundredths. ---
# We compare by multiplying by 100 and comparing integers to avoid float shell math.
DEN_NUM=$(( TODO_COUNT * 100 ))
DEN_DEN=$(( TODO_COUNT + SECTION_COUNT ))
if [ "$DEN_DEN" -eq 0 ]; then
  DEN_PCT=0
else
  DEN_PCT=$(( DEN_NUM / DEN_DEN ))
fi
# Compare against T_DEN expressed as 0..1 float. Multiply by 100 using awk.
T_DEN_PCT="$(awk -v t="$T_DEN" 'BEGIN{ printf "%d", t*100 }')"

# --- Contradiction-signal LLM pass (CC only, gated) ---

CONT_COUNT=0
LLM_CALLS=0
LLM_ALLOWED=0

# Detect runtime.
RUNTIME_SIG=""
if [ "${CLAUDE_CODE_RUNTIME:-0}" = "1" ]; then
  RUNTIME_SIG="claude-code"
elif [ -x "${PROJECT_ROOT}/scripts/lifecycle/detect-capabilities.sh" ]; then
  RUNTIME_SIG="$(bash "${PROJECT_ROOT}/scripts/lifecycle/detect-capabilities.sh" --runtime 2>/dev/null || echo "")"
fi

PROMPT="${PROJECT_ROOT}/templates/spec-complexity-contradiction-prompt.md"
DISPATCH="${PROJECT_ROOT}/scripts/dispatch/dispatch-interface.sh"
if [ "${SPEC_COMPLEXITY_PROBE_LLM:-1}" != "0" ] \
   && [ "$RUNTIME_SIG" = "claude-code" ] \
   && [ -x "$DISPATCH" ] \
   && [ -f "$PROMPT" ]; then
  LLM_ALLOWED=1
fi

START_MS="$(date +%s)"
if [ "$LLM_ALLOWED" = "1" ]; then
  # Dispatch the LLM round-trip. The dispatch interface is expected to print
  # the agent's response on stdout; we extract the first `contradictions=<N>`
  # line. On any failure, CONT_COUNT stays at 0 — never fail the probe.
  LLM_OUT="$(bash "$DISPATCH" --prompt-file "$PROMPT" --input-file "$SPEC_PATH" --mode oneshot 2>/dev/null || true)"
  LLM_CALLS=1
  LLM_LINE="$(printf '%s\n' "$LLM_OUT" | grep -E '^contradictions=[0-9]+' | head -n 1)"
  if [ -n "$LLM_LINE" ]; then
    CONT_COUNT="$(printf '%s\n' "$LLM_LINE" | sed -E 's/^contradictions=//')"
  fi
fi
END_MS="$(date +%s)"
ELAPSED_MS=$(( (END_MS - START_MS) * 1000 ))

# --- Verdict ---

VERDICT="below-threshold"
REASON=""

# Hardening-spec exception: fr_count==0 AND hardening_spec_exception=true => below, regardless.
if [ "$HARDEN" = "true" ] && [ "$FR_COUNT" -eq 0 ]; then
  VERDICT="below-threshold"
  REASON="hardening-spec-exception"
else
  if [ "$FR_COUNT" -ge "$T_FR" ]; then
    VERDICT="above-threshold"; REASON="fr_count>=${T_FR}"
  elif [ "$US_COUNT" -ge "$T_US" ]; then
    VERDICT="above-threshold"; REASON="user_story_count>=${T_US}"
  elif [ "$TOK_COUNT" -ge "$T_TOK" ]; then
    VERDICT="above-threshold"; REASON="raw_token_count>=${T_TOK}"
  elif [ "$DEN_PCT" -ge "$T_DEN_PCT" ] && [ "$TODO_COUNT" -gt 0 ]; then
    VERDICT="above-threshold"; REASON="todo_density>=${T_DEN}"
  elif [ "$CONT_COUNT" -ge "$T_CONT" ]; then
    VERDICT="above-threshold"; REASON="contradiction_signals>=${T_CONT}"
  fi
fi

# --- Emit ---

if [ "$VERDICT" = "above-threshold" ]; then
  echo "probe=above-threshold reason=${REASON}"
else
  echo "probe=below-threshold"
fi

{
  echo "fr_count=${FR_COUNT}"
  echo "user_story_count=${US_COUNT}"
  echo "todo_count=${TODO_COUNT}"
  echo "contradiction_signals=${CONT_COUNT}"
} >&2

# --- Observability emission (best-effort) ---

LOG="${PROJECT_ROOT}/.orchestrator/execution-log.jsonl"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REC="{\"type\":\"spec_complexity_probe\",\"ts\":\"${TS}\",\"spec_path\":\"${SPEC_PATH}\",\"verdict\":\"${VERDICT}\",\"reason\":\"${REASON}\",\"fr_count\":${FR_COUNT},\"user_story_count\":${US_COUNT},\"todo_count\":${TODO_COUNT},\"contradiction_signals\":${CONT_COUNT},\"llm_calls\":${LLM_CALLS},\"elapsed_ms\":${ELAPSED_MS},\"source\":\"runtime\"}"
printf '%s\n' "$REC" >> "$LOG" 2>/dev/null || true

exit 0
```

### Step 2: Gate verifier — `scripts/verify/m014-p04-complexity-probe-full.sh`

Single script file. Must exercise:

- Probe runs against `specs/016-autonomous-hardening/spec.md` → emits `probe=below-threshold` (hardening-spec exception; `fr_count=0`).
- Probe runs against `specs/024-spec-management-extended/spec.md` with `CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0` → emits `probe=above-threshold reason=fr_count>=15` (heuristic-only; [M024](../../../../milestones/M024/index.md) has ~20 FRs); structured fields all present on stderr; `contradiction_signals=0`.
- Probe runs against a fixture contradictory prose file with `CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0` → heuristic-only, still above-threshold on `fr_count`/`user_story_count`/`raw_token_count` if the fixture crosses one of those (T07 fixture provides this shape).
- Probe runs against a *trivial* scratch spec (hermetic mktemp) with 1 FR, 1 user story, 50 tokens → emits `probe=below-threshold` with structured fields all zero-or-small.
- Observability record appended: after the above runs, `.orchestrator/execution-log.jsonl` contains at least one new line matching `"type":"spec_complexity_probe"`. (Gate operates on a hermetic scratch log to avoid polluting the live log.)
- Exit 0 from all success paths; exit 1 when no spec path given; exit 1 on missing spec file.

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: T02 — full FR-5 complexity probe body.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROBE="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$PROBE" ] || fail "probe not executable"

# 1. Hardening-spec → below-threshold.
HS_SPEC="${PROJECT_ROOT}/specs/016-autonomous-hardening/spec.md"
if [ -f "$HS_SPEC" ]; then
  OUT="$(CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0 bash "$PROBE" "$HS_SPEC" 2>/dev/null)"
  echo "$OUT" | grep -qE '^probe=below-threshold' || fail "M016 expected below-threshold, got: $OUT"
fi

# 2. Large spec → above-threshold on heuristic.
BIG_SPEC="${PROJECT_ROOT}/specs/024-spec-management-extended/spec.md"
if [ -f "$BIG_SPEC" ]; then
  OUT="$(CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0 bash "$PROBE" "$BIG_SPEC" 2>/dev/null)"
  echo "$OUT" | grep -qE '^probe=above-threshold reason=' || fail "M024 expected above-threshold, got: $OUT"
fi

# 3. Structured fields on stderr.
STDERR_FILE="$(mktemp)"
CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0 bash "$PROBE" "$BIG_SPEC" >/dev/null 2> "$STDERR_FILE"
grep -qE '^fr_count=[0-9]+' "$STDERR_FILE"              || { rm -f "$STDERR_FILE"; fail "stderr missing fr_count"; }
grep -qE '^user_story_count=[0-9]+' "$STDERR_FILE"      || { rm -f "$STDERR_FILE"; fail "stderr missing user_story_count"; }
grep -qE '^todo_count=[0-9]+' "$STDERR_FILE"            || { rm -f "$STDERR_FILE"; fail "stderr missing todo_count"; }
grep -qE '^contradiction_signals=0' "$STDERR_FILE"      || { rm -f "$STDERR_FILE"; fail "stderr contradiction_signals!=0 under non-CC"; }
rm -f "$STDERR_FILE"

# 4. Trivial scratch spec → below-threshold.
SCRATCH="$(mktemp -d)"
TRIV="${SCRATCH}/trivial.md"
cat > "$TRIV" <<'SPEC'
# Feature Specification: Trivial
## Problem Statement
A tiny spec.
## Functional Requirements
- **FR-1 (solo)**: One requirement.
## Success Criteria
- SC-1: Works.
SPEC
OUT="$(CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0 bash "$PROBE" "$TRIV" 2>/dev/null)"
echo "$OUT" | grep -qE '^probe=below-threshold' || { rm -rf "$SCRATCH"; fail "trivial expected below-threshold, got: $OUT"; }
rm -rf "$SCRATCH"

# 5. Missing-arg case.
bash "$PROBE" >/dev/null 2>&1
if [ $? -eq 0 ]; then fail "probe with no args exited 0 (expected non-zero)"; fi

# 6. Missing-path case.
bash "$PROBE" /tmp/does-not-exist-p04.md >/dev/null 2>&1
if [ $? -eq 0 ]; then fail "probe missing path exited 0"; fi

# 7. P01 stub language removed (the exact P01 stub line was "echo \"probe=below-threshold\"" as the unconditional emit; the full body must contain "above-threshold" as a literal string).
grep -qF 'above-threshold' "$PROBE" || fail "probe body missing above-threshold literal — P01 stub not fully replaced"
grep -qF 'contradiction_signals=' "$PROBE" || fail "probe body missing contradiction_signals= emission"

echo "PASS: complexity-probe full body verified"
exit 0
```

Make executable.

## Must-Haves

- `scripts/knowledge/spec-complexity-probe.sh` full body replaces P01 stub; min 180 lines; contains `above-threshold`, `contradiction_signals=`, `hardening_spec_exception`
- Probe emits `probe=below-threshold` on [M016](../../../../milestones/M016/index.md) (hardening-spec exception) under non-CC runtime
- Probe emits `probe=above-threshold reason=<criterion>` on M024 under non-CC runtime (heuristic-only)
- Probe emits structured fields on stderr: `fr_count=`, `user_story_count=`, `todo_count=`, `contradiction_signals=`
- Probe exits 1 on missing arg / missing spec path
- Probe emits one `spec_complexity_probe` JSONL record per invocation (best-effort; append failures never fail the probe)
- `scripts/verify/m014-p04-complexity-probe-full.sh` exists, executable, exits 0
- Passes `scripts/verify/anti-pattern-lint.sh` + Bash 3.2 compat

## Verification

```
bash scripts/verify/m014-p04-complexity-probe-full.sh
```

Expected: `PASS: complexity-probe full body verified`, exit 0.

## Inputs

### From Previous Tasks

- `.orchestrator/config.yml` (from T01)
  - Key API: `yaml_nested specify complexity_thresholds <key>` returns pinned scalar value; keys: `fr_count`, `user_story_count`, `raw_token_count`, `todo_density`, `contradiction_signal_count`; `yaml_second specify hardening_spec_exception` returns `true`.
  - Key types: scalar values (integer or float).

### From Disk (Pre-existing)

- `scripts/dispatch/dispatch-interface.sh` — CC LLM round-trip surface. Probe invokes as `bash "$DISPATCH" --prompt-file <path> --input-file <path> --mode oneshot`. On any exit code, probe uses `|| true` to avoid failure; response is parsed for `^contradictions=<N>` line on stdout. If parsing fails, CONT_COUNT stays 0.
- `scripts/lifecycle/detect-capabilities.sh` — runtime detector. Probe invokes as `bash ... --runtime` and expects stdout `claude-code` / `codex` / `cursor`. On any error, RUNTIME_SIG is empty and LLM pass is skipped.
- `specs/016-autonomous-hardening/spec.md`, `specs/024-spec-management-extended/spec.md` — corpus specs for gate end-to-end assertions.

## Constraints

- **Caller contract is unchanged from P01**: same positional arg, same stdout-line shape (`probe=...` prefix), same stderr four-key-value shape. `scripts/specify/specify.sh` (T04) does not need to change its invocation call site because of T02 — it only needs to parse `above-threshold` out of stdout (T04's change).
- **LLM pass is defensive**: any failure in the LLM dispatch path (missing prompt, missing dispatch, exec failure, malformed response) silently yields CONT_COUNT=0 — the probe never fails because of LLM flakiness. This honors CON-2 (Codex/Cursor fallback is fully functional) and CON-8 (idempotency — the LLM is best-effort, not load-bearing).
- **No direct `/conversus` invocations** — T02's LLM pass is via `scripts/dispatch/dispatch-interface.sh` only (D007 reuse discipline; conversus adapter is T04's responsibility).
- **Observability is best-effort**: execution-log append failures warn on stderr at most but never fail the probe.
- Bash 3.2 compatible (no `declare -A`, no `mapfile`, no `<(…)`, no `&>`). Passes `scripts/verify/anti-pattern-lint.sh`.
- Temp files: no `mktemp` usage inside probe body is strictly necessary (no staging files required); if added, use `rm -f` cleanup.
- Avoid `$()` containing pipes per AD-19 — the gate verifier especially must be single-script shape.

## Expected Output

Files committed:

1. `scripts/knowledge/spec-complexity-probe.sh` — full body (~200 lines, executable)
2. `scripts/verify/m014-p04-complexity-probe-full.sh` — gate (~80 lines, executable)

Gate exits 0.
