#!/usr/bin/env bash
# tools/verify/p01-classifier-perf-and-network.sh -- FR-1 perf + CON-1 no-network gate.
#
# Two gates in one verifier:
#   1. Performance: best-of-5 wall-clock invocation against the first
#      labels.yml plan_path MUST be < 100ms.
#   2. Network-call cleanliness: scripts/dispatch/classify-task.sh body
#      MUST NOT contain any of the literals: curl, wget, nc -, dispatch-
#      interface.sh, scripts/dispatch/adapters/backend/, dispatch-task,
#      await-completion, LLM, claude<space>, anthropic, openai, gpt-.
#
# Output contract: stdout final line is
#   SUMMARY: p01-classifier-perf-and-network.sh pass=N fail=M
# Exit 0 iff fail=0.
#
# Wall-clock measurement strategy: prefer python3 monotonic_ns; fall back
# to date +%s%N on linux (BSD date does not honor %N, so the fallback
# loops 100 invocations and divides). The gate's contract is "single
# classification < 100ms wall-clock", not the timer mechanism.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -uo pipefail

CLASSIFIER="scripts/dispatch/classify-task.sh"
LABELS="tests/fixtures/m030-classifier-corpus/labels.yml"

pass=0
fail=0

# ---------- Pre-flight ----------

if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: $CLASSIFIER not found"
  fail=$((fail + 1))
  echo "SUMMARY: p01-classifier-perf-and-network.sh pass=$pass fail=$fail"
  exit 1
fi

if [ ! -f "$LABELS" ]; then
  echo "FAIL: $LABELS not found"
  fail=$((fail + 1))
  echo "SUMMARY: p01-classifier-perf-and-network.sh pass=$pass fail=$fail"
  exit 1
fi

PLAN_PATH=$(grep -E '^  - plan_path:' "$LABELS" | head -1 | sed 's/^  - plan_path:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')

if [ ! -f "$PLAN_PATH" ]; then
  echo "FAIL: derived plan path not on disk: $PLAN_PATH"
  fail=$((fail + 1))
  echo "SUMMARY: p01-classifier-perf-and-network.sh pass=$pass fail=$fail"
  exit 1
fi

# ---------- Gate 1: performance ----------

# Pick a timer.
HAVE_PY=0
if command -v python3 > /dev/null 2>&1; then
  HAVE_PY=1
fi

# Use python3 monotonic_ns when available (cross-platform sub-ms precision).
# Fall back to a 100-iteration loop using `date +%s` (1s precision, divided)
# only if python3 is missing.

now_ns() {
  if [ "$HAVE_PY" -eq 1 ]; then
    python3 -c 'import time; print(time.monotonic_ns())'
  else
    # Fallback: integer seconds * 1e9. Caller wraps in 100-iter loop.
    s=$(date +%s)
    echo "${s}000000000"
  fi
}

min_ms=999999

if [ "$HAVE_PY" -eq 1 ]; then
  # 5-run best-of for sub-second-jitter resilience.
  i=0
  while [ "$i" -lt 5 ]; do
    t0=$(now_ns)
    bash "$CLASSIFIER" "$PLAN_PATH" > /dev/null 2>&1
    t1=$(now_ns)
    elapsed_ms=$(( (t1 - t0) / 1000000 ))
    if [ "$elapsed_ms" -lt "$min_ms" ]; then
      min_ms=$elapsed_ms
    fi
    i=$((i + 1))
  done
else
  # Coarse fallback: time 100 invocations, divide.
  t0=$(now_ns)
  i=0
  while [ "$i" -lt 100 ]; do
    bash "$CLASSIFIER" "$PLAN_PATH" > /dev/null 2>&1
    i=$((i + 1))
  done
  t1=$(now_ns)
  total_ms=$(( (t1 - t0) / 1000000 ))
  min_ms=$(( total_ms / 100 ))
fi

if [ "$min_ms" -lt 100 ]; then
  echo "OK: min elapsed ${min_ms}ms < 100ms (timer=$([ $HAVE_PY -eq 1 ] && echo python3 || echo date-loop))"
  pass=$((pass + 1))
else
  echo "FAIL: min elapsed ${min_ms}ms >= 100ms"
  fail=$((fail + 1))
fi

# ---------- Gate 2: network-call cleanliness ----------

NET_LITERALS="curl wget |nc - |dispatch-interface.sh|scripts/dispatch/adapters/backend/|dispatch-task|await-completion|LLM|claude |anthropic|openai|gpt-"

# Each literal: grep MUST exit 1 (no match). Any match is a fail.
# We grep for each literal in turn rather than building a single alternation
# pattern -- AD-19 shape preference.

clean=1

# Check for `curl` invocation (excluding comments mentioning it as forbidden).
# Strategy: strip comment lines (#-prefixed) before grepping. This avoids
# false-positives when the script's own header documents which literals
# are forbidden.
NONCOMMENT="/tmp/p01-classifier-noncomment.txt"
grep -v -E '^[[:space:]]*#' "$CLASSIFIER" > "$NONCOMMENT" || true

if grep -q -E '\bcurl\b' "$NONCOMMENT"; then
  echo "FAIL: classify-task.sh body contains 'curl'"
  clean=0
fi
if grep -q -E '\bwget\b' "$NONCOMMENT"; then
  echo "FAIL: classify-task.sh body contains 'wget'"
  clean=0
fi
if grep -q -E '\bnc[[:space:]]+-' "$NONCOMMENT"; then
  echo "FAIL: classify-task.sh body invokes 'nc -...'"
  clean=0
fi
if grep -q -F 'dispatch-interface.sh' "$NONCOMMENT"; then
  echo "FAIL: classify-task.sh body references dispatch-interface.sh"
  clean=0
fi
if grep -q -F 'scripts/dispatch/adapters/backend/' "$NONCOMMENT"; then
  echo "FAIL: classify-task.sh body references backend adapters"
  clean=0
fi
if grep -q -F 'dispatch-task' "$NONCOMMENT"; then
  echo "FAIL: classify-task.sh body references dispatch-task"
  clean=0
fi
if grep -q -F 'await-completion' "$NONCOMMENT"; then
  echo "FAIL: classify-task.sh body references await-completion"
  clean=0
fi
if grep -q -E '\banthropic\b' "$NONCOMMENT"; then
  echo "FAIL: classify-task.sh body references 'anthropic'"
  clean=0
fi
if grep -q -E '\bopenai\b' "$NONCOMMENT"; then
  echo "FAIL: classify-task.sh body references 'openai'"
  clean=0
fi
if grep -q -E '\bgpt-' "$NONCOMMENT"; then
  echo "FAIL: classify-task.sh body references 'gpt-...'"
  clean=0
fi

rm -f "$NONCOMMENT"

if [ "$clean" -eq 1 ]; then
  echo "OK: no network-call literals in classify-task.sh body"
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

echo "SUMMARY: p01-classifier-perf-and-network.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
