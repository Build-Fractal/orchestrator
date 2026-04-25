#!/usr/bin/env bash
# scripts/knowledge/query.sh — FR-2 dispatch-callable knowledge query surface
#
# Usage: query.sh --topic <X> [--state <S>] [--format ids|json]
#
# FR-2 deterministic semantics:
#   (a) case-insensitive whole-string equality against frontmatter `topic:`
#   (b) topic-keyword index = case-folded set of `tags[]` values, rebuilt
#       lazily on every query (no persistent cache; Principle VI)
#   (c) match: entry's `topic:` equals X (case-insensitive) OR X (case-folded)
#       appears in entry's `tags[]` list
#   (d) state filter: --state <S> returns only that status; default is
#       `graduated` only
#   (e) ranking: topic-field matches > tag-only matches; ties broken by
#       `last_verified` descending
#   (f) output: --format ids (default) emits `entry_id=<ID>` per line in
#       rank order; --format json emits a single
#       `{"matches": [{id,title,status,rank}, ...]}` document. Empty result:
#       --format ids emits `entry_id= no-matches=true`; --format json emits
#       `{"matches": [], "no_matches": true}`.
#
# FR-8 / CON-1: read-only. Never writes to knowledge/**. Sources only
# fm_read_status from frontmatter.sh. Schema-authority constraint per
# knowledge/conventions/MEM031.md — read-only consumer of the closed enum.
#
# Bash 3.2 compatible. AD-19 single-script-file shape (no inline compounds).
# MEM001 structured prefixed output.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/index-utils.sh
. "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/frontmatter.sh
. "$SCRIPT_DIR/lib/frontmatter.sh"
# shellcheck source=lib/preferences.sh
. "$SCRIPT_DIR/lib/preferences.sh"

usage() {
  cat >&2 <<'EOF'
Usage: query.sh --topic <X> [--state <S>] [--format ids|json]

Resolves a knowledge query against knowledge/**/MEM*.md per FR-2.
Default state filter: graduated. Default format: ids.
Read-only — never writes to knowledge/**.
EOF
  exit 1
}

topic=""
state_filter=""
state_filter_seen_on_cli=0
format="ids"

while [ $# -gt 0 ]; do
  case "$1" in
    --topic)
      [ $# -lt 2 ] && usage
      topic="$2"
      shift 2
      ;;
    --state)
      [ $# -lt 2 ] && usage
      state_filter="$2"
      state_filter_seen_on_cli=1
      shift 2
      ;;
    --format)
      [ $# -lt 2 ] && usage
      format="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      usage
      ;;
  esac
done

[ -z "$topic" ] && { echo "FAIL: --topic <X> is required" >&2; usage; }

# FR-6 / P06: deferred state-filter resolution. CLI > project > user > default.
# When --state was not seen on CLI, resolve via pref_resolve. Falls back to
# the closed-enum-safe built-in default if pref_resolve returns empty/non-zero.
# pref_resolve's stderr is preserved (e.g. malformed-value WARN diagnostics).
if [ "$state_filter_seen_on_cli" = "0" ]; then
  resolved_state="$(pref_resolve default_state_filter || true)"
  if [ -n "$resolved_state" ]; then
    state_filter="$resolved_state"
  else
    state_filter="graduated"
  fi
fi

# Validate format flag (T01 only emits ids; --format json is reserved for T02).
case "$format" in
  ids|json) ;;
  *)
    echo "FAIL: --format must be one of {ids, json}, got: $format" >&2
    exit 1
    ;;
esac

# Validate state filter against the closed enum (MEM031).
case "$state_filter" in
  candidate|graduated|archived) ;;
  *)
    echo "FAIL: --state must be one of {candidate, graduated, archived}, got: $state_filter" >&2
    exit 1
    ;;
esac

PROJECT_ROOT_DIR="$(get_project_root)"
KNOWLEDGE_DIR="$PROJECT_ROOT_DIR/knowledge"

if [ ! -d "$KNOWLEDGE_DIR" ]; then
  # Empty domain — no entries at all. Emit empty result (T02 will add
  # the no-matches diagnostic line; T01 just exits 0 with no output).
  exit 0
fi

# Case-fold the query for matching.
topic_lc="$(printf '%s' "$topic" | tr '[:upper:]' '[:lower:]')"

# Working buffers held in tempfile (Bash 3.2: no associative arrays).
# Format per line:  <rank-tier>\t<last_verified>\t<entry_id>\t<title>\t<status>
# rank-tier: 0 = topic-field hit, 1 = tag-only hit. Sort numeric asc on tier,
# then last_verified desc inside tier (ISO 8601 sorts lexicographically).
buf="$(mktemp -t m020-p02-query.XXXXXX)"
trap 'rm -f "$buf"' EXIT

# Walk all knowledge/**/MEM*.md files. find -type f handles arbitrary depth;
# excluding archive/ (which holds historical material; no current entries).
find "$KNOWLEDGE_DIR" -type f -name 'MEM*.md' -not -path '*/archive/*' \
  | sort \
  | while IFS= read -r file; do
      # Read entry status via the FR-10 default-aware helper.
      status="$(fm_read_status "$file")"
      [ "$status" = "$state_filter" ] || continue

      # Extract entry id from filename (matches MEM###.md convention).
      entry_id="$(basename "$file" .md)"

      # Extract topic field (single-line scalar, optional quotes).
      topic_field="$(awk '
        /^---$/ { n++; if (n>=2) exit; next }
        n==1 && /^topic:[[:space:]]/ {
          sub(/^topic:[[:space:]]*/, "")
          sub(/[[:space:]]+$/, "")
          sub(/^"/, ""); sub(/"$/, "")
          print
          exit
        }
      ' "$file")"
      topic_field_lc="$(printf '%s' "$topic_field" | tr '[:upper:]' '[:lower:]')"

      # Extract tags[] — supports flow style `tags: [a, b, c]` or block style
      # `tags:` followed by `  - a` lines. Emit one tag per line, case-folded.
      tags_lc="$(awk '
        BEGIN { infm=0; intags=0 }
        /^---$/ { infm++; if (infm>=2) exit; next }
        infm==1 && /^tags:[[:space:]]*\[/ {
          line = $0
          sub(/^tags:[[:space:]]*\[/, "", line)
          sub(/\][[:space:]]*$/, "", line)
          n = split(line, a, ",")
          for (i = 1; i <= n; i++) {
            t = a[i]
            sub(/^[[:space:]]+/, "", t); sub(/[[:space:]]+$/, "", t)
            sub(/^"/, "", t); sub(/"$/, "", t)
            if (t != "") print tolower(t)
          }
          intags = 0
          next
        }
        infm==1 && /^tags:[[:space:]]*$/ { intags = 1; next }
        infm==1 && intags == 1 && /^[[:space:]]+-[[:space:]]/ {
          t = $0
          sub(/^[[:space:]]+-[[:space:]]+/, "", t)
          sub(/[[:space:]]+$/, "", t)
          sub(/^"/, "", t); sub(/"$/, "", t)
          if (t != "") print tolower(t)
          next
        }
        infm==1 && intags == 1 && /^[A-Za-z_]/ { intags = 0 }
      ' "$file")"

      # Extract title from first H1 line (`# MEMxxx: Title text`).
      title="$(awk '/^# / { sub(/^# /, ""); print; exit }' "$file")"

      # Extract last_verified for ranking tiebreak (ISO 8601 string).
      last_verified="$(awk '
        /^---$/ { n++; if (n>=2) exit; next }
        n==1 && /^last_verified:[[:space:]]/ {
          sub(/^last_verified:[[:space:]]*/, "")
          sub(/[[:space:]]+$/, "")
          sub(/^"/, ""); sub(/"$/, "")
          print
          exit
        }
      ' "$file")"

      # Determine rank tier.
      tier=""
      if [ -n "$topic_field_lc" ] && [ "$topic_field_lc" = "$topic_lc" ]; then
        tier="0"
      elif printf '%s\n' "$tags_lc" | grep -qx -- "$topic_lc"; then
        tier="1"
      fi
      [ -z "$tier" ] && continue

      # Emit a buffer line. last_verified empty ⇒ default to lowest sort key
      # so tagged-but-undated entries land last within their tier.
      printf '%s\t%s\t%s\t%s\t%s\n' "$tier" "${last_verified:-0000-00-00}" "$entry_id" "$title" "$status" >>"$buf"
    done

# Sort: tier ascending (numeric), last_verified descending (reverse string).
# Bash 3.2 + macOS sort: -k1,1n then -k2,2r.
sorted="$(sort -t '	' -k1,1n -k2,2r "$buf")"

# Empty-result diagnostic (US-1 acceptance scenario 3).
if [ -z "$sorted" ]; then
  case "$format" in
    json)
      printf '{"matches": [], "no_matches": true}\n'
      ;;
    ids|*)
      printf 'entry_id= no-matches=true\n'
      ;;
  esac
  exit 0
fi

# Format-aware emission. Rank values are 1-indexed within the sorted output.
case "$format" in
  json)
    # Single-document JSON. Quote-escape title via awk (handles backslash + ").
    printf '{"matches": ['
    rank=0
    first=1
    printf '%s\n' "$sorted" | while IFS=$'\t' read -r _tier _lv id title status; do
      rank=$((rank + 1))
      esc_title="$(printf '%s' "$title" | awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); print}')"
      esc_id="$(printf '%s' "$id" | awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); print}')"
      esc_status="$(printf '%s' "$status" | awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); print}')"
      if [ $first -eq 0 ]; then
        printf ', '
      fi
      printf '{"id": "%s", "title": "%s", "status": "%s", "rank": %d}' \
        "$esc_id" "$esc_title" "$esc_status" "$rank"
      first=0
    done
    printf ']}\n'
    ;;
  ids|*)
    printf '%s\n' "$sorted" | while IFS=$'\t' read -r _tier _lv id _title _status; do
      printf 'entry_id=%s\n' "$id"
    done
    ;;
esac

exit 0
