#!/usr/bin/env bash
# scripts/diagnostics/file-issue.sh — Create or comment on a GitHub Issue
# with a detective triage report body. Supports GH_MOCK_DIR for offline testing.
#
# Usage:
#   file-issue.sh --triage-report path/to/report.md
#   file-issue.sh --triage-report report.md --comment-on 42
#   file-issue.sh --triage-report report.md --title "custom" --labels "bug"
#
# Args: --triage-report <path> (required), --repo <owner/name>,
#       --comment-on <N>, --title <text>, --labels <csv>, --yes, -h/--help
#
# FR-9 confirmation gate: before any GitHub write, the operator confirms.
#   --yes               skip confirmation, proceed.
#   interactive TTY     prompt [y/N] before writing.
#   non-TTY, no --yes   degrade to stdout-only (no write) — prevents deadlock.
#
# Exit: 0 on success (including degradation / decline), 1 on usage error.
# Bash 3.2 compatible (CON-3). No writes to .orchestrator/ (CON-2).
set -uo pipefail

triage_report=""
repo=""
comment_on=""
title=""
labels="detective-triage"
assume_yes=0

while [ $# -gt 0 ]; do
  case "$1" in
    --triage-report) triage_report="$2"; shift 2 ;;
    --repo)          repo="$2"; shift 2 ;;
    --comment-on)    comment_on="$2"; shift 2 ;;
    --title)         title="$2"; shift 2 ;;
    --labels)        labels="$2"; shift 2 ;;
    --yes)           assume_yes=1; shift ;;
    -h|--help)       sed -n '2,20p' "$0"; exit 0 ;;
    *)               echo "ERROR: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

# Resolve repo: explicit --repo flag > config (detective.repo) > default.
if [ -z "$repo" ]; then
  _fi_read_config="$(cd "$(dirname "$0")" && pwd)/../state/read-config.sh"
  repo="$(bash "$_fi_read_config" detective.repo 2>/dev/null || echo "null")"
  [ "$repo" = "null" ] || [ -z "$repo" ] && repo="Build-Fractal/orchestrator"
fi

# --- Validate required args ---
if [ -z "$triage_report" ]; then
  echo "ERROR: --triage-report is required" >&2
  exit 1
fi
if [ ! -f "$triage_report" ]; then
  echo "ERROR: triage report not found: $triage_report" >&2
  exit 1
fi

# --- Auto-generate title from frontmatter symptom field ---
if [ -z "$title" ]; then
  symptom_line="$(grep '^symptom:' "$triage_report" | head -1)"
  if [ -n "$symptom_line" ]; then
    raw="$(echo "$symptom_line" | sed 's/^symptom:[[:space:]]*//' | sed 's/^"//; s/"$//')"
    truncated="$(printf '%.60s' "$raw")"
    title="[detective] $truncated"
  else
    title="[detective] triage report"
  fi
fi

# --- JSON-escape helpers ---
json_escape_body() {
  sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' "$1" | tr -d '\n' | sed 's/\\n$//'
}
json_escape_str() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# --- FR-9 confirmation gate ---
# Runs before any write (mock or live). Proceeds on --yes; prompts on an
# interactive TTY; degrades to stdout-only when non-interactive without --yes
# (prevents deadlock when FR-10 piped input has consumed stdin).
confirm_or_degrade() {
  if [ "$assume_yes" = "1" ]; then
    return 0
  fi
  if [ -t 0 ]; then
    printf 'DETECTIVE: about to %s\n' "$1" >&2
    printf 'Proceed? [y/N] ' >&2
    read -r _reply
    case "$_reply" in
      y|Y|yes|YES) return 0 ;;
      *)
        echo "DETECTIVE: cancelled by operator -- report follows for manual filing" >&2
        cat "$triage_report"
        exit 0 ;;
    esac
  fi
  echo "DETECTIVE: non-interactive without --yes -- report follows for manual filing" >&2
  cat "$triage_report"
  exit 0
}

if [ -z "$comment_on" ]; then
  confirm_or_degrade "create a new issue in ${repo} titled \"${title}\""
else
  confirm_or_degrade "comment on issue #${comment_on} in ${repo}"
fi

# --- Mock path: GH_MOCK_DIR set and non-empty ---
if [ -n "${GH_MOCK_DIR:-}" ]; then
  body_escaped="$(json_escape_body "$triage_report")"

  title_escaped="$(json_escape_str "$title")"
  if [ -z "$comment_on" ]; then
    # Create mode
    printf '{"title":"%s","body":"%s","labels":"%s","repo":"%s","mode":"create"}\n' \
      "$title_escaped" "$body_escaped" "$labels" "$repo" \
      > "$GH_MOCK_DIR/issue-create-request.json"
    echo "DETECTIVE: opened #999 (mock)" >&2
    echo "999"
  else
    # Comment mode
    printf '{"issue_number":%s,"body":"%s","repo":"%s","mode":"comment"}\n' \
      "$comment_on" "$body_escaped" "$repo" \
      > "$GH_MOCK_DIR/issue-comment-request.json"
    echo "DETECTIVE: commented on #${comment_on} (mock)" >&2
    echo "$comment_on"
  fi
  exit 0
fi

# --- Graceful degradation: gh not available ---
if ! command -v gh >/dev/null 2>&1; then
  echo "DETECTIVE: gh unavailable -- report printed to stdout" >&2
  cat "$triage_report"
  exit 0
fi

# --- Live path ---
if [ -z "$comment_on" ]; then
  # Create new issue
  output="$(gh issue create --repo "$repo" --title "$title" --label "$labels" \
    --body-file "$triage_report" 2>&1)" || {
    echo "DETECTIVE: GitHub action failed -- report follows for manual filing" >&2
    cat "$triage_report"
    exit 0
  }
  # Extract issue number from URL (e.g. https://github.com/owner/repo/issues/123)
  issue_num="$(echo "$output" | grep -oE '/issues/[0-9]+' | tail -1 | sed 's|/issues/||')"
  if [ -n "$issue_num" ]; then
    echo "DETECTIVE: opened #${issue_num}" >&2
    echo "$issue_num"
  else
    # Fallback: print the raw gh output
    echo "DETECTIVE: issue created (could not parse number)" >&2
    echo "$output"
  fi
else
  # Comment on existing issue
  gh issue comment "$comment_on" --repo "$repo" --body-file "$triage_report" >/dev/null 2>&1 || {
    echo "DETECTIVE: GitHub action failed -- report follows for manual filing" >&2
    cat "$triage_report"
    exit 0
  }
  echo "DETECTIVE: commented on #${comment_on}" >&2
  echo "$comment_on"
fi
