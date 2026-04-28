#!/usr/bin/env bash
# End-to-end test: source build-context.sh up through emitter definition,
# then invoke _bc_emit_compression_underperformance directly. Easier path:
# run actual build-context.sh against a fixture milestone with a synthetic
# execution log seeded with 30 underperforming records.
set -eu

REPO="/Users/brettkellgren/Sites/spec-kit-orchestrator"

# Build a synthetic ORCH_ROOT layout under /tmp.
TMP="$(mktemp -d)"
ORCH="$TMP/.orchestrator"
mkdir -p "$ORCH/milestones/MTEST/phases/P01/tasks"
cp "$REPO/.orchestrator/config.yml" "$ORCH/config.yml"

# Roadmap stub
cat > "$ORCH/milestones/MTEST/MTEST-ROADMAP.md" <<EOF
---
schema_version: "1.0"
type: roadmap
tier: B
---
# Roadmap MTEST
## Phases
**P01** — fixture phase
EOF

# Phase plan + task plan stubs
cat > "$ORCH/milestones/MTEST/phases/P01/P01-PLAN.md" <<EOF
---
schema_version: "1.0"
type: phase-plan
---
# Phase Plan P01
EOF

cat > "$ORCH/milestones/MTEST/phases/P01/tasks/T01-PLAN.md" <<EOF
---
schema_version: "1.0"
type: task-plan
task: T01
phase: P01
milestone: MTEST
---
# Task T01
EOF

# Seed the execution log with 30 underperforming records.
LOG="$ORCH/milestones/MTEST/execution-log.jsonl"
i=1
while [ "$i" -le 30 ]; do
  printf '{"record_type":"payload_breakdown","milestone":"MTEST","phase":"P01","task":"T01","payload_chars":1000,"payload_tokens_estimate":100,"filter_dropped_tokens":5,"timestamp":"2026-04-27T00:00:00Z"}\n' >> "$LOG"
  i=$((i + 1))
done

LINES_BEFORE="$(wc -l < "$LOG" | tr -d ' ')"
printf 'records before dispatch: %s\n' "$LINES_BEFORE"

# Run build-context.sh against the synthetic ORCH_ROOT.
# Suppress stdout (just the dispatch payload), capture stderr only.
ORCH_ROOT="$ORCH" bash "$REPO/scripts/dispatch/build-context.sh" "$ORCH" MTEST P01 T01 >/dev/null 2>"$TMP/err.txt" || {
  printf 'build-context.sh failed:\n'
  cat "$TMP/err.txt"
  rm -rf "$TMP"
  exit 1
}

LINES_AFTER="$(wc -l < "$LOG" | tr -d ' ')"
printf 'records after dispatch: %s\n' "$LINES_AFTER"

# Look for the new compression_underperformance record.
UP_COUNT="$(grep -c '"record_type":"compression_underperformance"' "$LOG" 2>/dev/null || true)"
if [ -z "$UP_COUNT" ]; then UP_COUNT=0; fi
printf 'compression_underperformance record count: %s\n' "$UP_COUNT"

# Show the last record (should be our new emission).
printf 'last log record:\n'
tail -1 "$LOG"

if [ "$UP_COUNT" -ge 1 ]; then
  printf '\ne2e test PASS\n'
else
  printf '\ne2e test FAIL\n'
  printf 'stderr:\n'
  cat "$TMP/err.txt"
  rm -rf "$TMP"
  exit 1
fi

rm -rf "$TMP"
