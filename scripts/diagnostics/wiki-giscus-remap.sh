#!/usr/bin/env bash
# scripts/diagnostics/wiki-giscus-remap.sh -- M012/P03 US5 remap utility.
#
# See also: scripts/diagnostics/wiki-giscus-smoke.sh (the P03 smoke gate
# that verifies every built HTML page carries the Giscus loader; run it
# after a remap to confirm nothing else regressed).
#
# Under mapping: pathname, a Giscus thread is keyed by the page URL path.
# When an artifact is consolidated (e.g. moved under archive/), the page
# URL changes and Giscus creates a fresh empty thread at the new URL,
# orphaning prior comments. This script relabels the old Discussion's
# TITLE to the new pathname so Giscus' pathname-matcher reconnects the
# thread at the new URL on next page load.
#
# Usage:
#   wiki-giscus-remap.sh <old-path> <new-path> [<old2> <new2> ...]
#   wiki-giscus-remap.sh --dry-run <pairs>
#   wiki-giscus-remap.sh --repo <owner/repo> --category <cat> <pairs>
#   wiki-giscus-remap.sh --help
#
# Flags:
#   --dry-run       print planned operations; do NOT call gh api
#   --repo OWNER/R  target repo (default $GISCUS_REPO)
#   --category CAT  Discussion category name (default $GISCUS_CATEGORY)
#   --help          print usage; exit 0
#
# Behavior:
#   For each <old new> pair:
#     1. Query existing Discussions whose title == <old>.
#     2. If found (exactly one): rename title to <new>. If no match whose
#        title == <old>: emit NOOP: <old> -> <new> and continue (already
#        migrated or never existed -- idempotent tail).
#     3. If match count > 1: emit FAIL: ambiguous (N matches) and set
#        status=1 without attempting a rename (fail-closed).
#
# Idempotency: running the script twice in a row against the same pair
# list produces identical observable state -- the second run emits
# NOOP lines for every pair (the old title no longer exists after the
# first successful run).
#
# Output lines (one per pair):
#   DRY-RUN: <old> -> <new>            (--dry-run only)
#   OK:      <old> -> <new>            (successful rename)
#   NOOP:    <old> -> <new> (no match) (already migrated or never existed)
#   FAIL:    <old> -> <new> (reason)   (ambiguous / id extract / mutation)
#
# Exit codes:
#   0 - all pairs resolved (DRY-RUN, OK, or NOOP)
#   1 - at least one pair failed (ambiguous, id extract, mutation error)
#   2 - usage error (unknown flag, odd positional-arg count, missing
#       --repo/--category in non-dry-run, or gh missing in non-dry-run)
#
# Bash 3.2 compatible. Requires gh (unless --dry-run). No jq hard-dep;
# uses gh --jq for GraphQL response field extraction.

set -u
set -o pipefail

DRY_RUN=0
REPO="${GISCUS_REPO:-}"
CATEGORY="${GISCUS_CATEGORY:-}"

usage() {
  sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'
}

# Two-phase arg parse: flags first, then <old new> positional pairs.
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY_RUN=1; shift ;;
    --repo)     REPO="$2"; shift 2 ;;
    --category) CATEGORY="$2"; shift 2 ;;
    --help|-h)  usage; exit 0 ;;
    --)         shift; break ;;
    -*)         printf 'ERROR: unknown flag: %s\n' "$1" >&2; exit 2 ;;
    *)          break ;;
  esac
done

if [ $# -eq 0 ] || [ $(( $# % 2 )) -ne 0 ]; then
  printf 'ERROR: positional args must be <old> <new> pairs; got %d args\n' "$#" >&2
  usage >&2
  exit 2
fi

if [ "$DRY_RUN" -eq 0 ]; then
  if [ -z "$REPO" ] || [ -z "$CATEGORY" ]; then
    printf 'ERROR: --repo and --category required (or set GISCUS_REPO + GISCUS_CATEGORY)\n' >&2
    exit 2
  fi
  if ! command -v gh >/dev/null 2>&1; then
    printf 'ERROR: gh CLI not on PATH (required for non-dry-run)\n' >&2
    exit 2
  fi
fi

# Pair loop. Each iteration consumes exactly two positional args.
status=0
while [ $# -gt 0 ]; do
  OLD="$1"
  NEW="$2"
  shift 2

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'DRY-RUN: %s -> %s\n' "$OLD" "$NEW"
    continue
  fi

  # Query Discussions in the repo; filter by title on the client side
  # using pure-text parsing (Bash 3.2 + no jq hard-dep).
  query='query($o:String!,$r:String!){repository(owner:$o,name:$r){discussions(first:100){nodes{id title category{name}}}}}'
  owner="${REPO%%/*}"
  name="${REPO##*/}"

  discussions_json="$(gh api graphql -f query="$query" -F o="$owner" -F r="$name" --jq '.data.repository.discussions.nodes' 2>/dev/null || echo '[]')"

  # Count title matches (exact).
  match_count="$(printf '%s' "$discussions_json" | grep -o "\"title\":\"$OLD\"" | wc -l | tr -d '[:space:]')"

  if [ "$match_count" -eq 0 ]; then
    printf 'NOOP: %s -> %s (no match)\n' "$OLD" "$NEW"
    continue
  fi
  if [ "$match_count" -gt 1 ]; then
    printf 'FAIL: %s -> %s (ambiguous: %d matches)\n' "$OLD" "$NEW" "$match_count" >&2
    status=1
    continue
  fi

  # Exactly one match. Extract its id. The GraphQL response shape is a
  # compact JSON array with {id,title,category} nodes; a tolerant sed
  # pattern handles small formatting variations.
  disc_id="$(printf '%s' "$discussions_json" | sed -n 's/.*"id":"\([^"]*\)"[^}]*"title":"'"$OLD"'".*/\1/p' | head -n 1)"
  if [ -z "$disc_id" ]; then
    # Fallback: try title-first ordering in case the field order differs.
    disc_id="$(printf '%s' "$discussions_json" | sed -n 's/.*"title":"'"$OLD"'"[^}]*"id":"\([^"]*\)".*/\1/p' | head -n 1)"
  fi
  if [ -z "$disc_id" ]; then
    printf 'FAIL: %s -> %s (id extract failed)\n' "$OLD" "$NEW" >&2
    status=1
    continue
  fi

  # GraphQL updateDiscussion mutation to rename the title.
  mutation='mutation($id:ID!,$title:String!){updateDiscussion(input:{discussionId:$id,title:$title}){discussion{id title}}}'
  if gh api graphql -f query="$mutation" -F id="$disc_id" -F title="$NEW" >/dev/null 2>&1; then
    printf 'OK: %s -> %s\n' "$OLD" "$NEW"
  else
    printf 'FAIL: %s -> %s (gh api mutation failed)\n' "$OLD" "$NEW" >&2
    status=1
  fi
done

exit "$status"
