#!/usr/bin/env bash
# scripts/knowledge/read-decisions.sh — M034 P01 T04 (FR-4 read engine).
#
# The read side of the decision-packet pipeline. Counts active
# (non-superseded) and unreviewed decision entries in a single packet or a
# directory of packets. Consumed by render-status-json.sh (the per-milestone
# unreviewed_decisions field) and check-decisions.sh (the doctor advisory).
#
# An entry is a `## <id>` block (mirrors write-decisions.sh::emit_block).
#   - ACTIVE  iff its block has NO `- **superseded_by**:` bullet (#Q-1 active view).
#   - REVIEWED iff a sibling `*-REVIEW.md` (same basename stem; the
#     `-DECISIONS.md` suffix replaced by `-REVIEW.md`) records its id as
#     adjudicated. P01 ships no REVIEW.md, so every active entry is
#     unreviewed; P02's gate drives the count to zero. The match is kept
#     LIBERAL (forward-compatible with P02's REVIEW.md shape): an id counts
#     as reviewed if the REVIEW file carries `reviewed: <id>` OR
#     `- **id**: <id>`.
#
# Subcommands (each prints a single integer to stdout):
#   active-count <packet-file>          active blocks
#   unreviewed-count <packet-file>      active blocks whose id is not reviewed
#   unreviewed-warn-count <packet-file> unreviewed AND `- **severity**: warn`
#   dir-unreviewed-count <dir>          sum of unreviewed-count over every
#                                       *-DECISIONS.md at depth <= 3 (0 when none)
#
# Bash 3.2 / POSIX-sh single file (CON-1 / AD-19): no declare -A, no ${var,,},
# no process substitution. Pipes/awk/sed/$() in the body are fine.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=scripts/knowledge/lib/decisions-constants.sh
. "$SCRIPT_DIR/lib/decisions-constants.sh"

# --- Emit the ids of active (non-superseded) blocks, one per line. ----------
# A block runs from a `## ` heading to the next `## ` heading (or EOF). The
# block's id is its `- **id**: <id>` bullet. A block is active iff it has no
# `- **superseded_by**:` bullet.
_active_ids() {
  pkt="$1"
  [ -f "$pkt" ] || return 0
  awk '
    function flush() {
      if (cur_id != "" && cur_superseded == 0) {
        print cur_id
      }
    }
    /^## / {
      flush()
      cur_id = ""; cur_superseded = 0
      next
    }
    /^- \*\*id\*\*: / {
      cur_id = $0
      sub(/^- \*\*id\*\*: /, "", cur_id)
      next
    }
    /^- \*\*superseded_by\*\*: / {
      cur_superseded = 1
      next
    }
    END { flush() }
  ' "$pkt"
}

# --- Emit "<id> <severity>" for each active block. --------------------------
_active_id_severity() {
  pkt="$1"
  [ -f "$pkt" ] || return 0
  awk '
    function flush() {
      if (cur_id != "" && cur_superseded == 0) {
        sev = (cur_sev == "") ? "block" : cur_sev
        print cur_id " " sev
      }
    }
    /^## / {
      flush()
      cur_id = ""; cur_superseded = 0; cur_sev = ""
      next
    }
    /^- \*\*id\*\*: / {
      cur_id = $0
      sub(/^- \*\*id\*\*: /, "", cur_id)
      next
    }
    /^- \*\*severity\*\*: / {
      cur_sev = $0
      sub(/^- \*\*severity\*\*: /, "", cur_sev)
      next
    }
    /^- \*\*superseded_by\*\*: / {
      cur_superseded = 1
      next
    }
    END { flush() }
  ' "$pkt"
}

# --- Resolve the sibling REVIEW file for a DECISIONS packet. -----------------
# Replace the `-DECISIONS.md` suffix with `-REVIEW.md`.
_review_file_for() {
  pkt="$1"
  printf '%s\n' "$pkt" | sed -E 's/-DECISIONS\.md$/-REVIEW.md/'
}

# --- Is id $2 marked reviewed in REVIEW file $1? (liberal match). -----------
# Prints "yes" or "" . Matches `reviewed: <id>` or `- **id**: <id>`.
_is_reviewed() {
  rvw="$1"
  rid="$2"
  [ -f "$rvw" ] || { printf ''; return 0; }
  if grep -E "^([[:space:]]*-[[:space:]]+\*\*id\*\*:[[:space:]]*|[[:space:]]*reviewed:[[:space:]]*)${rid}[[:space:]]*\$" "$rvw" >/dev/null 2>&1; then
    printf 'yes'
  else
    printf ''
  fi
}

# --- active-count <packet> ---------------------------------------------------
_active_count() {
  pkt="$1"
  n=$(_active_ids "$pkt" | grep -c . 2>/dev/null || true)
  [ -n "$n" ] || n=0
  printf '%s\n' "$n"
}

# --- unreviewed-count <packet> ----------------------------------------------
_unreviewed_count() {
  pkt="$1"
  rvw=$(_review_file_for "$pkt")
  count=0
  for id in $(_active_ids "$pkt"); do
    [ -n "$id" ] || continue
    if [ "$(_is_reviewed "$rvw" "$id")" != "yes" ]; then
      count=$((count + 1))
    fi
  done
  printf '%s\n' "$count"
}

# --- unreviewed-warn-count <packet> -----------------------------------------
_unreviewed_warn_count() {
  pkt="$1"
  rvw=$(_review_file_for "$pkt")
  count=0
  # Read "<id> <severity>" pairs; count unreviewed entries with severity warn.
  while IFS=' ' read -r id sev; do
    [ -n "$id" ] || continue
    [ "$sev" = "warn" ] || continue
    if [ "$(_is_reviewed "$rvw" "$id")" != "yes" ]; then
      count=$((count + 1))
    fi
  done <<EOF
$(_active_id_severity "$pkt")
EOF
  printf '%s\n' "$count"
}

# --- dir-unreviewed-count <dir> ---------------------------------------------
_dir_unreviewed_count() {
  dir="$1"
  total=0
  [ -d "$dir" ] || { printf '0\n'; return 0; }
  for pkt in $(find "$dir" -maxdepth 3 -type f -name '*-DECISIONS.md' 2>/dev/null); do
    [ -f "$pkt" ] || continue
    sub=$(_unreviewed_count "$pkt")
    [ -n "$sub" ] || sub=0
    total=$((total + sub))
  done
  printf '%s\n' "$total"
}

# --- Dispatch ----------------------------------------------------------------
sub="${1:-}"
arg="${2:-}"
case "$sub" in
  active-count)          _active_count "$arg" ;;
  unreviewed-count)      _unreviewed_count "$arg" ;;
  unreviewed-warn-count) _unreviewed_warn_count "$arg" ;;
  dir-unreviewed-count)  _dir_unreviewed_count "$arg" ;;
  *)
    echo "ERROR: unknown subcommand '$sub'. Use active-count|unreviewed-count|unreviewed-warn-count|dir-unreviewed-count <path>." >&2
    exit 1
    ;;
esac
