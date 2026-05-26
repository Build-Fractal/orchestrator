#!/usr/bin/env bash
# scripts/diagnostics/search-issues.sh — GitHub issue search with match scoring
# Emits JSON array of matching issues sorted by keyword match_score.
#
# Usage:  search-issues.sh --query "template not found" [--repo owner/repo]
#                           [--state open|closed|all] [--limit N] [-h|--help]
#
# Mock: set GH_MOCK_DIR to read $GH_MOCK_DIR/issue-list-response.json offline.
# Exit: 0 on success (including empty results / degradation), 1 on usage error.
# Bash 3.2 compatible (CON-3). No writes to .orchestrator/ (CON-2).
set -uo pipefail

query=""
repo=""
state="open"
limit="20"
threshold=""

while [ $# -gt 0 ]; do
  case "$1" in
    --query)     query="$2"; shift 2 ;;
    --repo)      repo="$2"; shift 2 ;;
    --state)     state="$2"; shift 2 ;;
    --limit)     limit="$2"; shift 2 ;;
    --threshold) threshold="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

if [ -z "$query" ]; then
  echo "Usage: search-issues.sh --query <text>" >&2
  exit 1
fi

# Resolve repo + threshold: explicit flag > config (detective.*) > default.
_si_script_dir="$(cd "$(dirname "$0")" && pwd)"
_si_read_config="$_si_script_dir/../state/read-config.sh"
if [ -z "$repo" ]; then
  repo="$(bash "$_si_read_config" detective.repo 2>/dev/null || echo "null")"
  [ "$repo" = "null" ] || [ -z "$repo" ] && repo="Build-Fractal/orchestrator"
fi
if [ -z "$threshold" ]; then
  threshold="$(bash "$_si_read_config" detective.match_threshold 2>/dev/null || echo "null")"
  [ "$threshold" = "null" ] || [ -z "$threshold" ] && threshold="3"
fi

# --- Fetch issue data (mock or live) ---
raw_json=""
if [ -n "${GH_MOCK_DIR:-}" ]; then
  mock_file="$GH_MOCK_DIR/issue-list-response.json"
  if [ -f "$mock_file" ]; then
    raw_json="$(cat "$mock_file")"
  else
    echo "[]"; exit 0
  fi
else
  if ! command -v gh >/dev/null 2>&1; then
    echo "DETECTIVE: gh unavailable" >&2
    echo "[]"; exit 0
  fi
  raw_json="$(gh issue list --search "$query" --repo "$repo" --state "$state" \
    --limit "$limit" --json number,title,body,labels 2>/dev/null)" || true
  if [ -z "$raw_json" ] || [ "$raw_json" = "null" ]; then
    echo "[]"; exit 0
  fi
fi

# --- Build keyword list (words >= 3 chars) ---
keywords=""
keyword_count=0
set -f; for word in $query; do
  clean="$(echo "$word" | tr -d '[:punct:]')"
  if [ "${#clean}" -ge 3 ]; then
    keywords="${keywords}${keywords:+ }$clean"
    keyword_count=$((keyword_count + 1))
  fi
done
set +f
if [ "$keyword_count" -eq 0 ]; then
  keywords="$query"; keyword_count=1
fi

# --- Score and format with jq if available, else line-based fallback ---
if command -v jq >/dev/null 2>&1 && [ -z "${_SEARCH_ISSUES_NOJQ:-}" ]; then
  echo "$raw_json" | jq --arg kw "$keywords" --argjson th "$threshold" '
    def lc: ascii_downcase;
    ($kw | split(" ")) as $words |
    [ .[] |
      (((.title // "") + " " + (.body // "")) | lc) as $text |
      (reduce ($words[]) as $w (0;
        if ($text | contains($w | lc)) then . + 1 else . end
      )) as $score |
      { number: .number, title: .title, match_score: $score,
        meets_threshold: ($score >= $th),
        labels: [(.labels // [])[] | .name] }
    ] | sort_by(-.match_score)
  '
else
  # Fallback: depth-tracked parsing for gh/mock JSON shape
  issues=""
  cur_num="" cur_title="" cur_body="" cur_labels=""
  depth=0
  while IFS= read -r line; do
    open_count="$(echo "$line" | tr -cd '{' | wc -c | tr -d ' ')"
    close_count="$(echo "$line" | tr -cd '}' | wc -c | tr -d ' ')"
    depth=$((depth + open_count - close_count))
    v="$(echo "$line" | sed -n 's/.*"number"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')"
    [ -n "$v" ] && cur_num="$v"
    v="$(echo "$line" | sed -n 's/.*"title"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    [ -n "$v" ] && cur_title="$v"
    v="$(echo "$line" | sed -n 's/.*"body"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    [ -n "$v" ] && cur_body="$v"
    v="$(echo "$line" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    [ -n "$v" ] && cur_labels="${cur_labels}${cur_labels:+,}\"${v}\""
    # Emit when we return to array depth (depth <= 1) with a populated issue
    if [ "$depth" -le 1 ] && [ -n "$cur_num" ]; then
      searchable="$(printf '%s %s' "$cur_title" "$cur_body" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')"
      score=0
      set -f; for kw in $keywords; do
        kw_lower="$(echo "$kw" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')"
        case "$searchable" in *"$kw_lower"*) score=$((score + 1)) ;; esac
      done; set +f
      safe_title="$(echo "$cur_title" | sed 's/\\/\\\\/g; s/"/\\"/g')"
      if [ "$score" -ge "$threshold" ]; then meets="true"; else meets="false"; fi
      issues="${issues}${issues:+
}${score}|{\"number\":${cur_num},\"title\":\"${safe_title}\",\"match_score\":${score},\"meets_threshold\":${meets},\"labels\":[${cur_labels}]}"
      cur_num="" cur_title="" cur_body="" cur_labels=""
    fi
  done <<EOF_JSON
$raw_json
EOF_JSON
  if [ -z "$issues" ]; then
    echo "[]"
  else
    sorted="$(echo "$issues" | sort -t'|' -k1 -rn | sed 's/^[0-9]*|//')"
    printf '['; first=1
    while IFS= read -r obj; do
      [ "$first" = "1" ] && first=0 || printf ','
      printf '%s' "$obj"
    done <<EOF_SORTED
$sorted
EOF_SORTED
    printf ']\n'
  fi
fi
