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
# T07 testability: STATE_ROOT routes mutation (observability log) to a scratch dir
# without relocating dependency lookups (config, templates, dispatch-interface).
STATE_ROOT="$PROJECT_ROOT"
if [ -n "${ORCHESTRATOR_PROJECT_ROOT:-}" ] && [ -d "${ORCHESTRATOR_PROJECT_ROOT}" ]; then
  STATE_ROOT="$(cd "${ORCHESTRATOR_PROJECT_ROOT}" && pwd)"
fi
CONFIG="${PROJECT_ROOT}/.orchestrator/config.yml"
# Prefer scratch config if present (hermetic gates seed it).
if [ -f "${STATE_ROOT}/.orchestrator/config.yml" ]; then
  CONFIG="${STATE_ROOT}/.orchestrator/config.yml"
fi

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

# Strip trailing YAML inline comments (` # ...`) and surrounding whitespace
# from scalar values read above. Plan-verbatim awk progs did not strip
# comments; P04/T02 deviation for correctness (T01 config uses inline `#`
# annotations on every threshold scalar).
_strip_yaml_scalar() {
  # stdin scalar -> stdout cleaned
  sed -E 's/[[:space:]]*#.*$//' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}
T_FR="$(printf '%s' "$T_FR" | _strip_yaml_scalar)"
T_US="$(printf '%s' "$T_US" | _strip_yaml_scalar)"
T_TOK="$(printf '%s' "$T_TOK" | _strip_yaml_scalar)"
T_DEN="$(printf '%s' "$T_DEN" | _strip_yaml_scalar)"
T_CONT="$(printf '%s' "$T_CONT" | _strip_yaml_scalar)"
HARDEN="$(printf '%s' "$HARDEN" | _strip_yaml_scalar)"

# Fallbacks if config is malformed.
: "${T_FR:=15}"
: "${T_US:=5}"
: "${T_TOK:=8000}"
: "${T_DEN:=0.5}"
: "${T_CONT:=1}"
: "${HARDEN:=true}"

# --- Heuristic counts ---

FR_COUNT="$(grep -cE '^- \*\*FR-[0-9]+|^### FR-[0-9]+|^\*\*FR-[0-9]+' "$SPEC_PATH" 2>/dev/null | head -n 1)"
US_COUNT="$(grep -cE '^### User (Story|Scenario)' "$SPEC_PATH" 2>/dev/null | head -n 1)"
TOK_COUNT="$(wc -w < "$SPEC_PATH" 2>/dev/null | tr -d ' ')"
TODO_COUNT="$(grep -cE '<TODO' "$SPEC_PATH" 2>/dev/null | head -n 1)"
SECTION_COUNT="$(grep -cE '^## ' "$SPEC_PATH" 2>/dev/null | head -n 1)"

# Trim leading/trailing whitespace that wc sometimes emits under bash 3.2 macOS.
FR_COUNT="${FR_COUNT// /}"
US_COUNT="${US_COUNT// /}"
TODO_COUNT="${TODO_COUNT// /}"
SECTION_COUNT="${SECTION_COUNT// /}"
: "${FR_COUNT:=0}"
: "${US_COUNT:=0}"
: "${TODO_COUNT:=0}"
: "${SECTION_COUNT:=0}"
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

LOG="${STATE_ROOT}/.orchestrator/execution-log.jsonl"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REC="{\"type\":\"spec_complexity_probe\",\"ts\":\"${TS}\",\"spec_path\":\"${SPEC_PATH}\",\"verdict\":\"${VERDICT}\",\"reason\":\"${REASON}\",\"fr_count\":${FR_COUNT},\"user_story_count\":${US_COUNT},\"todo_count\":${TODO_COUNT},\"contradiction_signals\":${CONT_COUNT},\"llm_calls\":${LLM_CALLS},\"elapsed_ms\":${ELAPSED_MS},\"source\":\"runtime\"}"
printf '%s\n' "$REC" >> "$LOG" 2>/dev/null || true

exit 0
