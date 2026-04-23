#!/usr/bin/env bash
# scripts/knowledge/consolidate-artifacts.sh — Consolidate milestone artifacts
# Implements FR-027 (artifact consolidation) and SC-011 (≥60% footprint reduction).
#
# Usage: consolidate-artifacts.sh <orchestrator-root> <milestone-id>
#
# Behavior:
#   - Verifies all phases are complete (have P##-SUMMARY.md)
#   - Measures total milestone directory size before consolidation
#   - For each phase: moves task plans, task summaries, and phase plans to archive/
#   - Preserves: phase summaries, milestone summary, roadmap, DECISIONS.md, KNOWLEDGE.md
#   - Reports bytes before/after and reduction percentage to stderr
#   - Outputs structured CONSOLIDATE: messages on stdout
#   - Target: ≥60% reduction (task plans + task summaries are the bulk)
#
# Bash 3.2 compatible (no declare -A per K001).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"

usage() {
  cat <<'EOF'
Usage: consolidate-artifacts.sh <orchestrator-root> <milestone-id>

Arguments:
  orchestrator-root  Path to .orchestrator (or equivalent state root)
  milestone-id       Milestone ID (e.g., M001)

Consolidates milestone artifacts by archiving task plans, task summaries, and
phase plans while preserving phase summaries, roadmap, and knowledge files.
Achieves ≥60% footprint reduction per SC-011.
EOF
  exit 1
}

if [ $# -lt 2 ]; then
  echo "ERROR: consolidate-artifacts.sh requires 2 arguments." >&2
  usage
fi

ORCH_ROOT="$1"
MILESTONE_ID="$2"

# Capture start epoch for elapsed_ms computation (Bash 3.2: second-resolution + 000).
START_EPOCH_MS="$(date +%s)000"

# Dual-write project root is the parent of $ORCH_ROOT (where CLAUDE.md / AGENTS.md
# live adjacent to .orchestrator/). This decouples the dual-write target from
# $PROJECT_ROOT (which locates the helper script itself) and makes the script
# hermetically testable against a scratch state directory.
DUAL_WRITE_ROOT="$(cd "$(dirname "$ORCH_ROOT")" && pwd)"

MILESTONE_DIR="$ORCH_ROOT/milestones/$MILESTONE_ID"
ROADMAP_FILE="$MILESTONE_DIR/${MILESTONE_ID}-ROADMAP.md"

# Validate milestone directory exists
if [ ! -d "$MILESTONE_DIR" ]; then
  echo "ERROR: Milestone directory does not exist: $MILESTONE_DIR" >&2
  exit 1
fi

# Validate roadmap exists
if [ ! -f "$ROADMAP_FILE" ]; then
  echo "ERROR: Roadmap not found: $ROADMAP_FILE" >&2
  exit 1
fi

# Get all phases from roadmap
phases_output=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" phases 2>/dev/null) || {
  echo "ERROR: Failed to read roadmap: $ROADMAP_FILE" >&2
  exit 1
}

# Verify all phases are complete
incomplete_phases=""
phase_ids=""
while IFS=' ' read -r pid pstatus prisk pdepends; do
  if [ -z "$pid" ]; then
    continue
  fi
  phase_ids="${phase_ids} $pid"

  phase_dir="$MILESTONE_DIR/phases/$pid"
  summary_file="$phase_dir/${pid}-SUMMARY.md"
  if [ ! -f "$summary_file" ]; then
    incomplete_phases="${incomplete_phases} $pid"
  fi
done <<< "$phases_output"

if [ -n "$incomplete_phases" ]; then
  echo "ERROR: Cannot consolidate — incomplete phases:${incomplete_phases}" >&2
  exit 1
fi

# Measure size before consolidation
# Measure the phases/ directory (active content), not total milestone dir,
# because archive/ is under milestone dir — moving files there doesn't change total.
PHASES_DIR="$MILESTONE_DIR/phases"
if [ ! -d "$PHASES_DIR" ]; then
  echo "ERROR: No phases directory: $PHASES_DIR" >&2
  exit 1
fi
size_before_kb=$(du -sk "$PHASES_DIR" | awk '{print $1}')
size_before_bytes=$((size_before_kb * 1024))

# Archive artifacts for each phase
archived_count=0
for pid in $phase_ids; do
  phase_dir="$MILESTONE_DIR/phases/$pid"
  if [ ! -d "$phase_dir" ]; then
    continue
  fi

  archive_dir="$MILESTONE_DIR/archive/$pid"
  mkdir -p "$archive_dir"

  # Move task plans (T##-PLAN.md)
  for f in "$phase_dir"/tasks/T*-PLAN.md; do
    if [ -f "$f" ]; then
      mv "$f" "$archive_dir/"
    fi
  done

  # Move task summaries (T##-SUMMARY.md)
  for f in "$phase_dir"/tasks/T*-SUMMARY.md; do
    if [ -f "$f" ]; then
      mv "$f" "$archive_dir/"
    fi
  done

  # Move task payloads (T##-PAYLOAD.md)
  for f in "$phase_dir"/tasks/T*-PAYLOAD.md; do
    if [ -f "$f" ]; then
      mv "$f" "$archive_dir/"
    fi
  done

  # Move phase plans (P##-PLAN.md)
  for f in "$phase_dir"/${pid}-PLAN.md; do
    if [ -f "$f" ]; then
      mv "$f" "$archive_dir/"
    fi
  done

  archived_count=$((archived_count + 1))
done

# Measure size after consolidation (phases dir only — archive is separate)
size_after_kb=$(du -sk "$PHASES_DIR" | awk '{print $1}')
size_after_bytes=$((size_after_kb * 1024))

# Calculate reduction percentage
if [ "$size_before_bytes" -gt 0 ]; then
  reduction=$(( (size_before_bytes - size_after_bytes) * 100 / size_before_bytes ))
else
  reduction=0
fi

# --- Knowledge lifecycle checks (advisory) ---
KNOWLEDGE_DIR="$PROJECT_ROOT/scripts/knowledge"

# Overlap detection
if [ -f "$KNOWLEDGE_DIR/detect-overlap.sh" ]; then
  echo "" >&2
  echo "CONSOLIDATE: Running overlap detection..." >&2
  overlap_output=$(bash "$KNOWLEDGE_DIR/detect-overlap.sh" 2>&1) || true
  if echo "$overlap_output" | grep -q "^OVERLAP:"; then
    echo "CONSOLIDATE: Overlapping entries detected:" >&2
    echo "$overlap_output" | grep "^OVERLAP:" >&2
  else
    echo "CONSOLIDATE: No overlapping entries found" >&2
  fi
else
  echo "CONSOLIDATE: detect-overlap.sh not found, skipping overlap check" >&2
fi

# Staleness report
if [ -f "$KNOWLEDGE_DIR/compute-staleness.sh" ]; then
  echo "" >&2
  echo "CONSOLIDATE: Running staleness report..." >&2
  staleness_output=$(bash "$KNOWLEDGE_DIR/compute-staleness.sh" 2>&1) || true
  if [ -n "$staleness_output" ]; then
    echo "$staleness_output" >&2
  fi
else
  echo "CONSOLIDATE: compute-staleness.sh not found, skipping staleness check" >&2
fi

# --- Dual-write Recent Changes entry (M014/P02 FR-12) ---
DUAL_WRITE_HELPER="$PROJECT_ROOT/scripts/util/dual-write-runtime-md.sh"
DUAL_WRITES=0
if [ -x "$DUAL_WRITE_HELPER" ]; then
  FRAG_FILE="$(mktemp)"
  EXISTING_REGION="$(mktemp)"
  # Preserve any existing region entries by reading them out of CLAUDE.md
  # first; the helper replaces the region wholesale, so we pre-concatenate
  # existing bytes with the new one-line entry.
  if [ -f "$DUAL_WRITE_ROOT/CLAUDE.md" ]; then
    awk '/^# >>> orchestrator:recent-changes >>>/ { in_r=1; next } /^# <<< orchestrator:recent-changes <<</ { in_r=0; next } in_r==1 { print }' \
      "$DUAL_WRITE_ROOT/CLAUDE.md" > "$EXISTING_REGION"
  fi
  {
    cat "$EXISTING_REGION"
    printf -- '- %s: milestone consolidated (%d%% reduction, %d phases archived)\n' \
      "$MILESTONE_ID" "$reduction" "$archived_count"
  } > "$FRAG_FILE"

  if bash "$DUAL_WRITE_HELPER" \
      --marker recent-changes \
      --content "$FRAG_FILE" \
      --root "$DUAL_WRITE_ROOT" \
      --file CLAUDE.md --file AGENTS.md \
      >/dev/null 2>&1; then
    DUAL_WRITES=2
  else
    if bash "$DUAL_WRITE_HELPER" \
        --marker recent-changes \
        --content "$FRAG_FILE" \
        --root "$DUAL_WRITE_ROOT" \
        --file CLAUDE.md \
        >/dev/null 2>&1; then
      DUAL_WRITES=1
    else
      echo "WARN: consolidate dual-write recent-changes failed; continuing" >&2
    fi
  fi
  rm -f "$FRAG_FILE" "$EXISTING_REGION"
else
  echo "SKIPPED: dual-write-runtime-md.sh not executable (consolidate)" >&2
fi

# --- Emit unit_close JSONL record (M014/P02 FR-16 / M019 Tier 1) ---
END_EPOCH_MS="$(date +%s)000"
ELAPSED_MS=$((END_EPOCH_MS - START_EPOCH_MS))
LOG_FILE="$ORCH_ROOT/execution-log.jsonl"
mkdir -p "$ORCH_ROOT"
if ! printf '{"command":"orchestrator:consolidate","unit_type":"command","milestone":"%s","dual_writes":%d,"reduction_pct":%d,"archived_count":%d,"elapsed_ms":%d,"source":"runtime"}\n' \
    "$MILESTONE_ID" "$DUAL_WRITES" "$reduction" "$archived_count" "$ELAPSED_MS" \
    >> "$LOG_FILE" 2>/dev/null; then
  echo "WARN: failed to append unit_close record to $LOG_FILE" >&2
fi

# Report to stderr
echo "CONSOLIDATE: ${size_before_bytes} → ${size_after_bytes} (${reduction}% reduction)" >&2

# Report to stdout
echo "CONSOLIDATE: $MILESTONE_ID consolidated, $archived_count phases archived"
