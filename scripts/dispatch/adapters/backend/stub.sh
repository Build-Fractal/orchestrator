#!/usr/bin/env bash
# scripts/dispatch/adapters/backend/stub.sh — M019/P01/T05 fixture adapter.
#
# Minimal conforming dispatch backend used exclusively by M019/P01 verify
# gates. Emits a dispatch-result.md-shaped document on stdout without
# invoking any real agent runtime. Registered via filename-based routing
# per MEM018 / FR-011 — no changes to dispatch-interface.sh.
#
# Usage:
#   stub.sh --probe
#   stub.sh --task-plan <path> --payload <path> --intensity-metadata <path>
#
# Bash 3.2 compatible.

set -u

MODE="normal"
TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""

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
    *)
      shift ;;
  esac
done

if [ "$MODE" = "probe" ]; then
  echo "available=true"
  echo "backend=stub"
  echo "reason=m019-p01-fixture-adapter"
  exit 0
fi

# Normal mode — emit a conforming dispatch-result.
task_id="T00"
phase_id="P00"
milestone_id="M000"
if [ -n "$TASK_PLAN" ] && [ -f "$TASK_PLAN" ]; then
  t="$(grep -E '^task:' "$TASK_PLAN" | head -n 1 | sed -E 's/^task:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  p="$(grep -E '^phase:' "$TASK_PLAN" | head -n 1 | sed -E 's/^phase:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  m="$(grep -E '^milestone:' "$TASK_PLAN" | head -n 1 | sed -E 's/^milestone:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  [ -n "$t" ] && task_id="$t"
  [ -n "$p" ] && phase_id="$p"
  [ -n "$m" ] && milestone_id="$m"
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat <<EOF
---
schema_version: "1.0"
type: "dispatch-result"
status: "success"
backend: "stub"
task_id: "${task_id}"
phase_id: "${phase_id}"
milestone_id: "${milestone_id}"
dispatched_at: "${ts}"
completed_at: "${ts}"
duration_s: "0"
---

# Stub Dispatch Result

## Status

success -- M019/P01 fixture adapter

## Summary

Hermetic stub; no agent was invoked.

## Artifacts

<!-- none -->

## Notes

Fixture adapter for scripts/verify/m019-p01-*.sh gates.
EOF

exit 0
