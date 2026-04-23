#!/usr/bin/env bash
# scripts/diagnostics/check-docs.sh — Documentation completeness check
#
# Default mode (--check docs): verifies all 19 required documentation files exist
#   (14 reference docs, 4 user guides, 1 contributor guide). Emits DOCTOR:DOCS.
#
# Drift mode (--check drift): FR-13 runtime-instruction drift detection between
#   CLAUDE.md and AGENTS.md. Compares marker-bounded regions between the two
#   files; detects missing_region, byte_divergence, unmatched_marker. Emits
#   DOCTOR:DRIFT structured output. Advisory (exit 0 even on warn) in v1.
#
# Usage:
#   check-docs.sh [--check docs|drift] [--root <project-root>]
#
# Options:
#   --check  Mode selector: docs (default) or drift
#   --root   Project root directory (default: PROJECT_ROOT env or two levels up)
#
# Bash 3.2 compatible.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CHECK_MODE="docs"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --check) CHECK_MODE="$2"; shift 2 ;;
    *) echo "check-docs.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# ============================================================================
# Mode: docs (M006 documentation completeness — default)
# ============================================================================
if [ "$CHECK_MODE" = "docs" ]; then

  # --- Required documentation files (19 total) ---

  # Reference docs (14)
  DOCS="references/architecture.md
references/engine.md
references/events.md
references/errors.md
references/hooks.md
references/recipes.md
references/routing.md
references/file-formats.md
references/state-machine.md
references/verification-ladder.md
references/tier-definitions.md
references/installation.md
references/provider-convention.md
references/constitution-walkthrough.md
docs/getting-started.md
docs/recipe-authoring.md
docs/hook-development.md
docs/knowledge-management.md
scripts/AGENTS.md"

  # --- Check each file ---
  total=0
  found=0
  missing_list=""

  for doc in $DOCS; do
    total=$((total + 1))
    if [ -f "$PROJECT_ROOT/$doc" ]; then
      found=$((found + 1))
    else
      missing_list="${missing_list}  MISSING: ${doc}
"
    fi
  done

  # --- Report ---
  if [ "$found" -eq "$total" ]; then
    status="ok"
  else
    status="missing"
  fi

  printf 'DOCTOR:DOCS status=%s found=%d total=%d\n' "$status" "$found" "$total"

  if [ "$status" = "missing" ] && [ -n "$missing_list" ]; then
    printf '%s' "$missing_list"
  fi

  if [ "$status" = "missing" ]; then
    exit 1
  fi
  exit 0
fi

# ============================================================================
# Mode: drift (FR-13 runtime-instruction drift between CLAUDE.md and AGENTS.md)
# ============================================================================
if [ "$CHECK_MODE" = "drift" ]; then
  CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
  AGENTS_MD="$PROJECT_ROOT/AGENTS.md"

  # Skip gracefully if either file is absent.
  if [ ! -f "$CLAUDE_MD" ] || [ ! -f "$AGENTS_MD" ]; then
    reason="both-absent"
    if [ ! -f "$CLAUDE_MD" ] && [ -f "$AGENTS_MD" ]; then reason="CLAUDE.md-absent"; fi
    if [ -f "$CLAUDE_MD" ] && [ ! -f "$AGENTS_MD" ]; then reason="AGENTS.md-absent"; fi
    printf 'DOCTOR:DRIFT status=skip reason=%s regions=0 divergences=0\n' "$reason"
    exit 0
  fi

  # Discover every opening marker in either file.
  # Marker literal: `# >>> orchestrator:<region-name> >>>`
  regions_file="$(mktemp)"
  findings_file="$(mktemp)"
  trap 'rm -f "$regions_file" "$findings_file"' EXIT

  grep -hE '^# >>> orchestrator:[a-zA-Z0-9_-]+ >>>$' "$CLAUDE_MD" "$AGENTS_MD" 2>/dev/null \
    | sed -E 's/^# >>> orchestrator:([a-zA-Z0-9_-]+) >>>$/\1/' \
    | sort -u \
    > "$regions_file" || true

  regions_total=0
  if [ -s "$regions_file" ]; then
    regions_total=$(wc -l < "$regions_file" | tr -d ' ')
  fi
  divergences=0

  # Extract region bytes helper.
  extract_region() {
    file="$1"; name="$2"
    awk -v open_mk="# >>> orchestrator:${name} >>>" -v close_mk="# <<< orchestrator:${name} <<<" '
      $0 == open_mk { in_r=1; next }
      $0 == close_mk { in_r=0; next }
      in_r==1 { print }
    ' "$file"
  }

  # Walk each discovered region name.
  while IFS= read -r region; do
    if [ -z "$region" ]; then continue; fi

    c_has_open=0
    c_has_close=0
    a_has_open=0
    a_has_close=0
    if grep -qF "# >>> orchestrator:${region} >>>" "$CLAUDE_MD"; then c_has_open=1; fi
    if grep -qF "# <<< orchestrator:${region} <<<" "$CLAUDE_MD"; then c_has_close=1; fi
    if grep -qF "# >>> orchestrator:${region} >>>" "$AGENTS_MD"; then a_has_open=1; fi
    if grep -qF "# <<< orchestrator:${region} <<<" "$AGENTS_MD"; then a_has_close=1; fi

    # Unmatched markers within a single file.
    if [ "$c_has_open" -ne "$c_has_close" ]; then
      echo "DRIFT: unmatched_marker region=${region} file=CLAUDE.md" >&2
      divergences=$((divergences + 1))
    fi
    if [ "$a_has_open" -ne "$a_has_close" ]; then
      echo "DRIFT: unmatched_marker region=${region} file=AGENTS.md" >&2
      divergences=$((divergences + 1))
    fi

    # Region missing in one file.
    if [ "$c_has_open" -eq 1 ] && [ "$a_has_open" -eq 0 ]; then
      echo "DRIFT: missing_region region=${region} file=AGENTS.md" >&2
      divergences=$((divergences + 1))
      continue
    fi
    if [ "$a_has_open" -eq 1 ] && [ "$c_has_open" -eq 0 ]; then
      echo "DRIFT: missing_region region=${region} file=CLAUDE.md" >&2
      divergences=$((divergences + 1))
      continue
    fi

    # Both present + both matched — compare bytes.
    if [ "$c_has_open" -eq 1 ] && [ "$c_has_close" -eq 1 ] && \
       [ "$a_has_open" -eq 1 ] && [ "$a_has_close" -eq 1 ]; then
      c_bytes="$(extract_region "$CLAUDE_MD" "$region")"
      a_bytes="$(extract_region "$AGENTS_MD" "$region")"
      c_sha="$(printf '%s' "$c_bytes" | shasum -a 256 | awk '{print $1}')"
      a_sha="$(printf '%s' "$a_bytes" | shasum -a 256 | awk '{print $1}')"
      if [ "$c_sha" != "$a_sha" ]; then
        echo "DRIFT: byte_divergence region=${region} file=CLAUDE.md vs AGENTS.md" >&2
        divergences=$((divergences + 1))
      fi
    fi
  done < "$regions_file"

  status="ok"
  if [ "$divergences" -gt 0 ]; then status="warn"; fi

  printf 'DOCTOR:DRIFT status=%s regions=%d divergences=%d\n' \
    "$status" "$regions_total" "$divergences"

  # FR-13 v1: drift is advisory; exit 0 even on warn.
  exit 0
fi

# Unknown mode.
echo "check-docs.sh: unknown --check mode: $CHECK_MODE" >&2
exit 1
