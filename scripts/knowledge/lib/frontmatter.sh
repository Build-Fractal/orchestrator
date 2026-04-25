#!/usr/bin/env bash
# scripts/knowledge/lib/frontmatter.sh — atomic frontmatter read/write
# helpers for M020 schema-evolution fields (status, decision_history,
# archived_into). Bash 3.2 safe.
#
# Source this file. Requires lib/detail-utils.sh sourced first for sed_i.
#
# CON-1 (read-only-during-dispatch): the mutation helpers in this file are
# callable from operator-invoked paths only (e.g. scripts/knowledge/graduate.sh
# in T03). Dispatched task agents MUST NOT call fm_write_status,
# fm_write_archived_into, or fm_append_decision_history directly.
# fm_read_status is read-only and safe from any context.
#
# CON-4 (byte-equivalence): every mutation function follows the
# write-tempfile-then-rename(2) pattern. Same-filesystem `mv` is atomic per
# POSIX, so a crash mid-write leaves the original file unchanged.
# Mutations touch ONLY the named field; all other lines pass through
# byte-for-byte via the awk passthrough rule.
#
# Closed enum (per D024 / MEM031): status: ∈ {candidate, graduated, archived}.
# Pre-M020 entries with no status: line read as "graduated" (FR-10
# incremental-migration default).

# --- Double-source guard ---
[ -n "${_FRONTMATTER_HELPER_SOURCED:-}" ] && return 0
_FRONTMATTER_HELPER_SOURCED=1

# --- Closed-enum assertion ---
# Rejects any value not in {candidate, graduated, archived}.
# Emits FAIL: to stderr and exits 1 on rejection.
fm_assert_closed_enum() {
  local value="$1"
  case "$value" in
    candidate|graduated|archived)
      return 0
      ;;
    *)
      echo "FAIL: status must be one of {candidate, graduated, archived}, got: $value" >&2
      exit 1
      ;;
  esac
}

# --- Read status with FR-10 default ---
# Returns "graduated" for entries with no status: line (pre-M020 default).
# Pure: no file mutation. Reads only the first frontmatter block.
fm_read_status() {
  local file="$1"
  local val
  val="$(awk '
    /^---$/ {
      n++
      if (n >= 2) { exit }
      next
    }
    n == 1 && /^status:[[:space:]]/ {
      sub(/^status:[[:space:]]*/, "")
      sub(/[[:space:]]+$/, "")
      # strip surrounding double-quotes if present
      sub(/^"/, "")
      sub(/"$/, "")
      print
      exit
    }
  ' "$file")"
  if [ -z "$val" ]; then
    echo "graduated"
  else
    echo "$val"
  fi
}

# --- Write status (atomic; insert if absent, replace if present) ---
# Closed-enum guard runs FIRST so an invalid value never produces a tempfile.
fm_write_status() {
  local file="$1"
  local new_status="$2"
  fm_assert_closed_enum "$new_status"
  local tmp="${file}.tmp.$$"
  awk -v ns="$new_status" '
    BEGIN { infm = 0; wrote = 0 }
    /^---$/ {
      if (infm == 0) { infm = 1; print; next }
      if (infm == 1) {
        if (wrote == 0) { print "status: " ns; wrote = 1 }
        infm = 2
        print
        next
      }
      print
      next
    }
    infm == 1 && /^status:[[:space:]]/ {
      print "status: " ns
      wrote = 1
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "WROTE: $file field=status value=$new_status"
}

# --- Write archived_into (atomic; insert if absent, replace if present) ---
# Single-ID back-reference. Used by P03 cluster-aware archive paths.
fm_write_archived_into() {
  local file="$1"
  local canonical_id="$2"
  if [ -z "$canonical_id" ]; then
    echo "FAIL: fm_write_archived_into requires non-empty canonical-id" >&2
    exit 1
  fi
  local tmp="${file}.tmp.$$"
  awk -v cid="$canonical_id" '
    BEGIN { infm = 0; wrote = 0 }
    /^---$/ {
      if (infm == 0) { infm = 1; print; next }
      if (infm == 1) {
        if (wrote == 0) { print "archived_into: " cid; wrote = 1 }
        infm = 2
        print
        next
      }
      print
      next
    }
    infm == 1 && /^archived_into:[[:space:]]/ {
      print "archived_into: " cid
      wrote = 1
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "WROTE: $file field=archived_into value=$canonical_id"
}

# --- Append a decision_history record (atomic; create key if absent) ---
# Record shape (YAML list under decision_history:):
#   decision_history:
#     - rationale: "<rationale>"
#       timestamp: "2026-04-25T17:30:00Z"
#       operator: "<operator>"
#       cluster_id: "<cluster-id-or-empty>"
#
# If decision_history: is absent the key is created immediately before the
# closing `---` of the frontmatter block. Otherwise the new record is
# appended at the end of the existing list (still inside the frontmatter
# block).
fm_append_decision_history() {
  local file="$1"
  local rationale="$2"
  local operator="$3"
  local cluster_id="$4"
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp="${file}.tmp.$$"
  awk -v rat="$rationale" -v ts="$timestamp" -v op="$operator" -v cid="$cluster_id" '
    BEGIN {
      infm = 0
      in_history = 0
      have_history = 0
      appended = 0
    }
    /^---$/ {
      if (infm == 0) { infm = 1; print; next }
      if (infm == 1) {
        # Closing frontmatter delimiter.
        if (in_history == 1 && appended == 0) {
          print "  - rationale: \"" rat "\""
          print "    timestamp: \"" ts "\""
          print "    operator: \"" op "\""
          print "    cluster_id: \"" cid "\""
          appended = 1
        }
        if (have_history == 0 && appended == 0) {
          print "decision_history:"
          print "  - rationale: \"" rat "\""
          print "    timestamp: \"" ts "\""
          print "    operator: \"" op "\""
          print "    cluster_id: \"" cid "\""
          appended = 1
        }
        infm = 2
        in_history = 0
        print
        next
      }
      print
      next
    }
    infm == 1 && /^decision_history:[[:space:]]*$/ {
      have_history = 1
      in_history = 1
      print
      next
    }
    infm == 1 && in_history == 1 && /^[A-Za-z_][A-Za-z0-9_]*:/ {
      # New top-level frontmatter key encountered → end of history list.
      # Emit the new record before this key, then resume passthrough.
      print "  - rationale: \"" rat "\""
      print "    timestamp: \"" ts "\""
      print "    operator: \"" op "\""
      print "    cluster_id: \"" cid "\""
      appended = 1
      in_history = 0
      print
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "WROTE: $file field=decision_history rationale=$rationale"
}
