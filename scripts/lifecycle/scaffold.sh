#!/usr/bin/env bash
# scripts/lifecycle/scaffold.sh — Idempotent milestone directory scaffolding
# Creates the orchestrator directory structure for a milestone.
#
# Usage: scaffold.sh <root-dir> <milestone-id>
#        scaffold.sh --root <path> --milestone <id>
#
# Creates:
#   <root>/DECISIONS.md              (global, only if not exists)
#   <root>/KNOWLEDGE.md              (global, only if not exists)
#   <root>/execution-log.jsonl       (global, only if not exists)
#   <root>/milestones/<M###>/phases/
#
# Idempotent: re-running is a no-op. Exits 0 on success, 1 on invalid input.

set -euo pipefail

ROOT_DIR=""
MILESTONE=""
POSITIONAL_ARGS=()

# Parse arguments — collect named flags and positional args separately
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"; shift 2 ;;
    --milestone)
      MILESTONE="$2"; shift 2 ;;
    -*)
      echo "scaffold.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      POSITIONAL_ARGS+=("$1"); shift ;;
  esac
done

# Assign positional args based on what flags were already set
if [[ -n "$ROOT_DIR" && -z "$MILESTONE" ]]; then
  # --root was set, positionals are milestone(s)
  if [[ ${#POSITIONAL_ARGS[@]} -ge 1 ]]; then
    MILESTONE="${POSITIONAL_ARGS[0]}"
  fi
elif [[ -z "$ROOT_DIR" && -n "$MILESTONE" ]]; then
  # --milestone was set, positionals are root dir
  if [[ ${#POSITIONAL_ARGS[@]} -ge 1 ]]; then
    ROOT_DIR="${POSITIONAL_ARGS[0]}"
  fi
else
  # No flags set — positionals are: root dir, milestone ID
  if [[ ${#POSITIONAL_ARGS[@]} -ge 1 ]]; then
    ROOT_DIR="${POSITIONAL_ARGS[0]}"
  fi
  if [[ ${#POSITIONAL_ARGS[@]} -ge 2 ]]; then
    MILESTONE="${POSITIONAL_ARGS[1]}"
  fi
fi

# Validate arguments
if [[ -z "$ROOT_DIR" ]]; then
  echo "scaffold.sh: missing root directory argument" >&2
  echo "Usage: scaffold.sh <root-dir> <milestone-id>" >&2
  exit 1
fi

if [[ -z "$MILESTONE" ]]; then
  echo "scaffold.sh: missing milestone ID argument" >&2
  echo "Usage: scaffold.sh <root-dir> <milestone-id>" >&2
  exit 1
fi

# Validate milestone ID format: M followed by exactly 3 digits
if ! echo "$MILESTONE" | grep -qE '^M[0-9][0-9][0-9]$'; then
  echo "scaffold.sh: invalid milestone ID '$MILESTONE' (expected format: M###, e.g., M001)" >&2
  exit 1
fi

MILESTONE_DIR="$ROOT_DIR/milestones/$MILESTONE"

# Check if milestone already exists
if [[ -d "$MILESTONE_DIR" ]]; then
  echo "Milestone $MILESTONE already scaffolded"
  exit 0
fi

# Create global state files (only if they don't exist)
mkdir -p "$ROOT_DIR"

if [[ ! -f "$ROOT_DIR/DECISIONS.md" ]]; then
  cat > "$ROOT_DIR/DECISIONS.md" << 'EOF'
| # | When | Scope | Decision | Choice | Rationale | Revisable? |
|---|------|-------|----------|--------|-----------|------------|
EOF
fi

if [[ ! -f "$ROOT_DIR/KNOWLEDGE.md" ]]; then
  cat > "$ROOT_DIR/KNOWLEDGE.md" << 'EOF'
# Knowledge Base

EOF
fi

if [[ ! -f "$ROOT_DIR/execution-log.jsonl" ]]; then
  touch "$ROOT_DIR/execution-log.jsonl"
fi

# Create milestone directory structure
mkdir -p "$MILESTONE_DIR/phases"

echo "Scaffolded $MILESTONE at $MILESTONE_DIR"
