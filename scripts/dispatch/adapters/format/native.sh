#!/usr/bin/env bash
# scripts/dispatch/adapters/format/native.sh -- native task-plan format adapter
#
# Format adapters translate between a foreign task representation and the
# orchestrator's native task-plan shape (defined by templates/task-plan.md:
# YAML frontmatter with schema_version, type: task-plan, task, phase,
# milestone, name, depends_on + markdown body).
#
# native.sh is the identity adapter for the native format. It validates
# that input files conform to the native shape and echoes them unchanged
# (read mode), or persists native-format content passed on stdin (write
# mode). Symmetry with foreign-format adapters (e.g. speckit.sh) lets the
# dispatch pipeline treat native and foreign inputs uniformly.
#
# Usage:
#   native.sh --probe
#     Emits: available=true, format=native, reason=...
#     Exit 0 always (native format is always available).
#
#   native.sh --read <path>
#     Validates <path> as a native task-plan and echoes it verbatim on
#     stdout. Exit 0 on success, 2 on file-not-found, 3 on invalid
#     frontmatter.
#
#   native.sh --write <path>
#     Reads task-plan content on stdin, writes atomically to <path>.
#     Exit 0 on success (emits written=<path>), 2 on missing arg,
#     3 if the persisted content is not a valid task-plan.
#
# Bash 3.2 compatible. No jq/python3 dependencies.

set -u

MODE=""
PATH_ARG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --probe)
      MODE="probe"; shift ;;
    --read)
      MODE="read"; PATH_ARG="${2:-}"; shift 2 ;;
    --write)
      MODE="write"; PATH_ARG="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- validate_frontmatter <file> ---
# Returns 0 if the file has a native task-plan frontmatter block
# (requires ^schema_version: and ^type: task-plan or ^type: "task-plan").
validate_frontmatter() {
  local f="$1"
  if ! grep -qE '^schema_version:' "$f"; then
    return 1
  fi
  if ! grep -qE '^type:[[:space:]]*"?task-plan"?[[:space:]]*$' "$f"; then
    return 1
  fi
  return 0
}

# --- Probe mode ---

if [[ "$MODE" = "probe" ]]; then
  echo "available=true"
  echo "format=native"
  echo "reason=native-format-always-available"
  exit 0
fi

# --- Read mode ---

if [[ "$MODE" = "read" ]]; then
  if [[ -z "$PATH_ARG" ]]; then
    echo "FAIL: --read requires a path argument" >&2
    exit 2
  fi
  if [[ ! -f "$PATH_ARG" ]]; then
    echo "FAIL: file not found: $PATH_ARG" >&2
    exit 2
  fi
  if ! validate_frontmatter "$PATH_ARG"; then
    echo "FAIL: invalid task-plan frontmatter: $PATH_ARG" >&2
    exit 3
  fi

  # Extract frontmatter fields (validated; stderr-diagnostic only if missing)
  task_id="$(grep -E '^task:' "$PATH_ARG" | head -n 1 | sed -E 's/^task:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  phase_id="$(grep -E '^phase:' "$PATH_ARG" | head -n 1 | sed -E 's/^phase:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  milestone_id="$(grep -E '^milestone:' "$PATH_ARG" | head -n 1 | sed -E 's/^milestone:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')"
  : "${task_id:=}"
  : "${phase_id:=}"
  : "${milestone_id:=}"

  # Identity: emit file contents verbatim on stdout.
  cat "$PATH_ARG"
  exit 0
fi

# --- Write mode ---

if [[ "$MODE" = "write" ]]; then
  if [[ -z "$PATH_ARG" ]]; then
    echo "FAIL: --write requires a path argument" >&2
    exit 2
  fi

  # Ensure parent directory exists.
  parent_dir="$(dirname "$PATH_ARG")"
  if [[ ! -d "$parent_dir" ]]; then
    echo "FAIL: parent directory does not exist: $parent_dir" >&2
    exit 2
  fi

  # Read stdin into a temp file, then atomically mv into place.
  tmp_file="$(mktemp "${parent_dir}/.native-write.XXXXXX")"
  # Cleanup on unexpected exit
  trap 'rm -f "$tmp_file"' EXIT

  # Drain stdin into tmp_file.
  cat > "$tmp_file"

  # Validate the persisted content before promoting.
  if ! validate_frontmatter "$tmp_file"; then
    rm -f "$tmp_file"
    trap - EXIT
    echo "FAIL: write produced invalid task-plan" >&2
    exit 3
  fi

  # Atomic promotion.
  mv "$tmp_file" "$PATH_ARG"
  trap - EXIT

  echo "written=$PATH_ARG"
  exit 0
fi

echo "FAIL: no mode specified (expected --probe | --read <path> | --write <path>)" >&2
exit 2
