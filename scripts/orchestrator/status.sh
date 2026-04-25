#!/usr/bin/env bash
# scripts/orchestrator/status.sh — Emit structured milestone summary for an
# orchestrator state root. Consumed by tests/integration/test-m003-e2e-migration.sh
# and by developers inspecting migrated or working state.
#
# Usage:
#   status.sh [--root <dir>]
#   ORCHESTRATOR_ROOT=<dir> status.sh
#
# Output (stdout):
#   MILESTONE: <ID>
#   STATE: <state-word>
#   PHASE: P01 <state>
#   PHASE: P02 <state>
#   ...
#
# Exit codes:
#   0 = success (at least one milestone found)
#   1 = no milestones found under resolved root
#   2 = resolver failed
#
# Bash 3.2 compatible. MEM001 (no declare -A, no ${var,,}, no |&).
# AD-19: invokes dependencies as subprocesses, never sources them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- P04: Review-Queue section (FR-4) ---
# Renders the `Review Queue:` section by invoking
# `scripts/knowledge/compute-staleness.sh --review-queue` and parsing its
# structured stdout. Failure-tolerant: any error path emits the
# `Review Queue: unavailable` fallback and a one-line stderr diagnostic.
# Read-only invariant per FR-8 / CON-1: writes nothing to knowledge/** or
# .orchestrator/execution-log.jsonl. Tempdir cleaned via trap RETURN.
_p04_render_review_queue() {
  local repo_root="$REPO_ROOT"
  local helper="$repo_root/scripts/knowledge/compute-staleness.sh"
  if [ ! -x "$helper" ] && [ ! -f "$helper" ]; then
    echo "Review Queue: unavailable"
    echo "P04 review-queue: helper not found at $helper" >&2
    return 0
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  local out_file="$tmpdir/review-queue.out"
  local err_file="$tmpdir/review-queue.err"

  # Wall-clock-bounded invocation. macOS may lack `timeout`; if so, run direct.
  local rc=0
  if command -v timeout >/dev/null 2>&1; then
    timeout 5 bash "$helper" --review-queue >"$out_file" 2>"$err_file" || rc=$?
  else
    bash "$helper" --review-queue >"$out_file" 2>"$err_file" || rc=$?
  fi

  if [ "$rc" -ne 0 ]; then
    echo "Review Queue: unavailable"
    echo "P04 review-queue: helper exited rc=$rc; stderr: $(head -1 "$err_file" 2>/dev/null || true)" >&2
    return 0
  fi

  # Empty-queue path.
  if [ "$(head -1 "$out_file" 2>/dev/null || true)" = "EMPTY" ]; then
    echo "Review Queue: empty"
    return 0
  fi

  if [ ! -s "$out_file" ]; then
    echo "Review Queue: unavailable"
    echo "P04 review-queue: helper emitted empty output" >&2
    return 0
  fi

  # First pass: validate every line is well-formed and tally totals.
  local n_clusters=0 n_entries=0 line cnt
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      cluster_id=*\ topic=*\ count=*\ oldest_age=*\ stale=*) ;;
      *)
        echo "Review Queue: unavailable"
        echo "P04 review-queue: malformed helper line: $line" >&2
        return 0
        ;;
    esac
    cnt="$(printf '%s\n' "$line" | awk '{
      for (i=1;i<=NF;i++) {
        if ($i ~ /^count=/) { sub(/^count=/, "", $i); print $i; exit }
      }
    }')"
    case "$cnt" in
      ''|*[!0-9]*)
        echo "Review Queue: unavailable"
        echo "P04 review-queue: non-integer count on line: $line" >&2
        return 0
        ;;
    esac
    n_clusters=$(( n_clusters + 1 ))
    n_entries=$(( n_entries + cnt ))
  done <"$out_file"

  # Second pass: render header + per-cluster lines.
  printf 'Review Queue: %d clusters, %d entries awaiting review\n' \
    "$n_clusters" "$n_entries"
  local cid topic count age stale stale_marker
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    cid="$(printf '%s\n' "$line"   | awk '{for(i=1;i<=NF;i++)if($i~/^cluster_id=/){sub(/^cluster_id=/,"",$i);print $i;exit}}')"
    topic="$(printf '%s\n' "$line" | awk '{for(i=1;i<=NF;i++)if($i~/^topic=/){sub(/^topic=/,"",$i);print $i;exit}}')"
    count="$(printf '%s\n' "$line" | awk '{for(i=1;i<=NF;i++)if($i~/^count=/){sub(/^count=/,"",$i);print $i;exit}}')"
    age="$(printf '%s\n' "$line"   | awk '{for(i=1;i<=NF;i++)if($i~/^oldest_age=/){sub(/^oldest_age=/,"",$i);print $i;exit}}')"
    stale="$(printf '%s\n' "$line" | awk '{for(i=1;i<=NF;i++)if($i~/^stale=/){sub(/^stale=/,"",$i);print $i;exit}}')"
    stale_marker=""
    if [ "$stale" = "true" ]; then
      stale_marker=" (stale)"
    fi
    printf '  cluster=%s topic=%s count=%s oldest_age=%sd%s\n' \
      "$cid" "$topic" "$count" "$age" "$stale_marker"
  done <"$out_file"
}

# --- Parse args ---
arg_root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      if [ $# -lt 2 ]; then
        echo "status.sh: --root requires a directory argument" >&2
        exit 1
      fi
      arg_root="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,24p' "$0"
      exit 0
      ;;
    *)
      echo "status.sh: unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

# --- Resolve root ---
# Precedence: --root flag > ORCHESTRATOR_ROOT env > resolve-root.sh fallback
if [ -n "$arg_root" ]; then
  resolved_root="$arg_root"
elif [ -n "${ORCHESTRATOR_ROOT:-}" ]; then
  resolved_root="$ORCHESTRATOR_ROOT"
else
  resolved_root="$(bash "$REPO_ROOT/scripts/state/resolve-root.sh" --absolute 2>/dev/null || true)"
fi

if [ -z "$resolved_root" ] || [ ! -d "$resolved_root" ]; then
  echo "status.sh: could not resolve orchestrator root (tried --root, ORCHESTRATOR_ROOT, resolve-root.sh)" >&2
  exit 2
fi

# --- Find milestones ---
milestones_dir="$resolved_root/milestones"
if [ ! -d "$milestones_dir" ]; then
  echo "status.sh: no milestones/ directory under $resolved_root" >&2
  exit 1
fi

any_milestone=0
for m_dir in "$milestones_dir"/M*; do
  [ -d "$m_dir" ] || continue
  any_milestone=1
  m_id="$(basename "$m_dir")"
  # Milestone ID is directory name per MEM003 (detected from M###-*.md, but
  # directory basename is authoritative for this wrapper).
  m_state="$(bash "$REPO_ROOT/scripts/state/derive-phase.sh" "$m_dir" 2>/dev/null || echo unknown)"
  echo "MILESTONE: $m_id"
  echo "STATE: $m_state"
  if [ -d "$m_dir/phases" ]; then
    for p_dir in "$m_dir/phases"/P*; do
      [ -d "$p_dir" ] || continue
      p_id="$(basename "$p_dir")"
      if [ -f "$p_dir/$p_id-SUMMARY.md" ]; then
        p_state="complete"
      elif [ -f "$p_dir/$p_id-PLAN.md" ]; then
        p_state="executing"
      else
        p_state="pending"
      fi
      echo "PHASE: $p_id $p_state"
    done
  fi
done

if [ "$any_milestone" -eq 0 ]; then
  echo "status.sh: no milestones found under $milestones_dir" >&2
  exit 1
fi

# --- P04: Review-Queue section (FR-4) ---
_p04_render_review_queue

exit 0
