#!/usr/bin/env bash
# scripts/dispatch/adapters/backend/stub-record-model.sh -- M030/P04/T01 fixture adapter.
#
# Model-flag-recorder dispatch backend used by the live-routing happy-path
# verifier (T02 deliverable). On every invocation:
#   1. Records the value of the --model flag (or `<no-model-flag>` if absent)
#      to $STUB_RECORD_MODEL_FILE (default /tmp/stub-record-model.txt).
#   2. Always emits a conforming dispatch-result.md on stdout, exits 0.
#
# Used by tools/verify/p04-live-routing-happy-path.sh (T02) to assert that
# dispatch-interface.sh's amended adapter invocation passes the resolved
# --model flag through to the adapter, completing the live-routing
# end-to-end loop.
#
# CON-3 closure: the adapter does NOT introduce hardcoded model IDs.
# The --model value is opaque to the adapter (recorded as-is; not
# interpreted, validated, or normalized).
#
# AD-19 carve-out: dispatch-internal adapter (MEM004 emitter-internal
# pattern). Pipes / awk / $() permitted in its body. Verifiers that
# GATE it follow strict AD-19 (single-script-file shape).
#
# Bash 3.2 compatible.

set -u

MODE="normal"
TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""
MODEL="<no-model-flag>"

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
      MODEL="${2:-<empty-model-value>}"; shift 2 ;;
    *)
      shift ;;
  esac
done

if [ "$MODE" = "probe" ]; then
  echo "available=true"
  echo "backend=stub-record-model"
  echo "reason=m030-p04-t01-model-flag-recorder"
  exit 0
fi

OUT_FILE="${STUB_RECORD_MODEL_FILE:-/tmp/stub-record-model.txt}"
printf '%s\n' "$MODEL" > "$OUT_FILE"

# Standard dispatch-result emission (mirrors stub.sh shape).
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
backend: "stub-record-model"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${ts}"
completed_at: "${ts}"
duration_s: "0"
---

# Stub-record-model Dispatch Result

## Status

success -- recorded model flag value to ${OUT_FILE}.

## Summary

Fixture adapter for M030/P04 live-routing happy-path verifier.
The dispatcher's --model flag value was captured as: ${MODEL}.
EOF

# Reference set-but-unused vars so set -u stays happy in future audits.
: "$PAYLOAD" "$INTENSITY_METADATA"

exit 0
