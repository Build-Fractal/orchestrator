#!/usr/bin/env bash
# scripts/dispatch/adapters/backend/stub-fail-n.sh -- M030/P04/T01 fixture adapter.
#
# Programmable fail-counter dispatch backend used by P04 SC-4 (escalation
# pass-after-retries), SC-5 (escalation hard-cap-of-2), and CON-5 (cap-is-
# hard) verifiers. Reads a counter file containing a single integer; on
# each invocation, decrements the counter and:
#   - if pre-decrement value > 0: exit 1 (no stdout) -- counted as failure.
#   - if pre-decrement value <= 0: emit a conforming dispatch-result on
#     stdout, exit 0 -- counted as success.
#
# Counter file path: $STUB_FAIL_COUNTER_FILE (default /tmp/stub-fail-n-counter.txt).
# Missing file is treated as 0 (will pass on first invocation).
#
# Optional side-channels (for downstream verifiers):
#   $STUB_FAIL_COUNTER_INVOCATIONS_FILE -- if set, append one line per
#                                          invocation (model + ts) for
#                                          CON-5 invocation-count assertion.
#   $STUB_INVOCATION_SENTINEL_DIR        -- if set + dir exists, drop a
#                                          unique sentinel touch-file per
#                                          invocation (CON-6 mid-escalation
#                                          inspection hook; T03 verifier).
#
# Flag interface mirrors stub.sh + adds --model:
#   --task-plan <path>          (mirrors stub.sh)
#   --payload <path>            (mirrors stub.sh)
#   --intensity-metadata <path> (mirrors stub.sh)
#   --model <id>                (NEW; T02 dispatch-interface starts passing it)
#   --probe                     (capability probe; mirrors stub.sh)
#
# AD-19 carve-out: this is a dispatch-internal adapter (MEM004 emitter-
# internal pattern). Pipes / awk / $() permitted in its body. The
# verifiers that GATE it follow strict AD-19 (single-script-file shape).
#
# CON-3 closure: this adapter does NOT introduce hardcoded model IDs;
# the --model value passed in is opaque to the adapter (recorded as-is
# in the side-channel; not interpreted).
#
# Bash 3.2 compatible.

set -u

MODE="normal"
TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""
MODEL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --probe)
      MODE="probe"; shift ;;
    --task-plan)
      TASK_PLAN="${2:-}"; shift 2 ;;
    --payload)
      PAYLOAD="${2:-}"; shift 2 ;;
    --intensity-metadata)
      INTENSITY_METADATA="${2:-}"; shift 2 ;;
    --model)
      MODEL="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

if [ "$MODE" = "probe" ]; then
  echo "available=true"
  echo "backend=stub-fail-n"
  echo "reason=m030-p04-t01-programmable-fail-counter"
  exit 0
fi

CTR_FILE="${STUB_FAIL_COUNTER_FILE:-/tmp/stub-fail-n-counter.txt}"

# Side-channel: append one line per invocation for CON-5 verifier.
if [ -n "${STUB_FAIL_COUNTER_INVOCATIONS_FILE:-}" ]; then
  ts_inv="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'invocation model=%s ts=%s\n' "$MODEL" "$ts_inv" \
    >> "$STUB_FAIL_COUNTER_INVOCATIONS_FILE"
fi

# Sentinel for CON-6 verifier (drops a file per invocation).
if [ -n "${STUB_INVOCATION_SENTINEL_DIR:-}" ] && [ -d "$STUB_INVOCATION_SENTINEL_DIR" ]; then
  ts_sen="$(date -u +%s)"
  touch "$STUB_INVOCATION_SENTINEL_DIR/inv-${ts_sen}-$$.touch" 2>/dev/null
fi

# Read-decrement the counter.
remaining=0
if [ -f "$CTR_FILE" ]; then
  remaining="$(tr -d '[:space:]' < "$CTR_FILE")"
  if [ -z "$remaining" ]; then
    remaining=0
  fi
fi
new_remaining=$((remaining - 1))
printf '%d\n' "$new_remaining" > "$CTR_FILE"

if [ "$remaining" -gt 0 ]; then
  # This invocation IS a failure (more failures pending including this one).
  exit 1
fi

# Counter reached 0 (or was 0 from start) -- emit conforming dispatch-result.
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
task_id="T00"
phase_id="P00"
milestone_id="M000"
if [ -n "$TASK_PLAN" ] && [ -f "$TASK_PLAN" ]; then
  t="$(grep -E '^task:' "$TASK_PLAN" | head -n 1 | sed -E 's/^task:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  p="$(grep -E '^phase:' "$TASK_PLAN" | head -n 1 | sed -E 's/^phase:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  m="$(grep -E '^milestone:' "$TASK_PLAN" | head -n 1 | sed -E 's/^milestone:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  if [ -n "$t" ]; then task_id="$t"; fi
  if [ -n "$p" ]; then phase_id="$p"; fi
  if [ -n "$m" ]; then milestone_id="$m"; fi
fi

cat <<EOF
---
schema_version: "1.0"
type: "dispatch-result"
status: "success"
backend: "stub-fail-n"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${ts}"
completed_at: "${ts}"
duration_s: "0"
---

# Stub-fail-n Dispatch Result

## Status

success -- counter exhausted, returned pass.

## Summary

Programmable fail-counter fixture adapter for M030/P04 escalation
verifiers. Pre-decrement counter value was <= 0 on this invocation,
so the adapter returned a conforming success result.

## Notes

Adapter recorded model flag value: ${MODEL:-<no-model-flag>}.
EOF

# Reference set-but-unused vars so set -u stays happy in future audits.
: "$PAYLOAD" "$INTENSITY_METADATA"

exit 0
