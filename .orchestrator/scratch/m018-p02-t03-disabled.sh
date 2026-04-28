#!/usr/bin/env bash
# Verify: when compression.underperformance.enabled=false, no
# compression_underperformance record is emitted even with 30 underperforming
# records.
set -eu
REPO="/Users/brettkellgren/Sites/spec-kit-orchestrator"
TMP="$(mktemp -d)"
ORCH="$TMP/.orchestrator"
mkdir -p "$ORCH/milestones/MTEST/phases/P01/tasks"

# Custom config with underperformance disabled.
cat > "$ORCH/config.yml" <<EOF
schema_version: "1.0"
type: orchestrator-config
compression:
  enabled: true
  knowledge_filter:
    enabled: true
    drop_list:
      - superseded
      - experimental
  underperformance:
    enabled: false
    window_size: 30
    floor_pct: 34.7
    min_sample_size: 10
EOF

cat > "$ORCH/milestones/MTEST/MTEST-ROADMAP.md" <<EOF
---
schema_version: "1.0"
type: roadmap
tier: B
---
# Roadmap
**P01** — fixture
EOF
cat > "$ORCH/milestones/MTEST/phases/P01/P01-PLAN.md" <<EOF
---
schema_version: "1.0"
type: phase-plan
---
# P01
EOF
cat > "$ORCH/milestones/MTEST/phases/P01/tasks/T01-PLAN.md" <<EOF
---
schema_version: "1.0"
type: task-plan
task: T01
phase: P01
milestone: MTEST
---
# T01
EOF

LOG="$ORCH/milestones/MTEST/execution-log.jsonl"
i=1
while [ "$i" -le 30 ]; do
  printf '{"record_type":"payload_breakdown","payload_tokens_estimate":100,"filter_dropped_tokens":5,"timestamp":"2026-04-27T00:00:00Z"}\n' >> "$LOG"
  i=$((i + 1))
done

ORCH_ROOT="$ORCH" bash "$REPO/scripts/dispatch/build-context.sh" "$ORCH" MTEST P01 T01 >/dev/null 2>/dev/null || true

UP_COUNT="$(grep -c '"record_type":"compression_underperformance"' "$LOG" 2>/dev/null || true)"
if [ -z "$UP_COUNT" ]; then UP_COUNT=0; fi
printf 'compression_underperformance count (enabled=false): %s\n' "$UP_COUNT"

if [ "$UP_COUNT" -eq 0 ]; then
  printf 'disable-flag-honored: PASS\n'
  rm -rf "$TMP"
else
  printf 'disable-flag-honored: FAIL\n'
  rm -rf "$TMP"
  exit 1
fi
