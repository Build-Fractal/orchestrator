#!/usr/bin/env bash
# scripts/util/dual-write-runtime-md.sh — FR-12 marker-bounded dual-write helper.
# Writes a content fragment between
#   # >>> orchestrator:<region-name> >>>
#   # <<< orchestrator:<region-name> <<<
# in one or more target files. Preserves bytes outside markers byte-identically.
#
# Usage: dual-write-runtime-md.sh --marker <region-name> --content <path-to-fragment>
#                                 [--file CLAUDE.md] [--file AGENTS.md]
#                                 [--root <project-root>] [--dry-run]
#
# Behavior:
#   - If a target file is missing, it is created containing only the marker
#     region with the given content.
#   - If markers are absent in an existing target, they are inserted above
#     the first heading (^#) or at EOF if no heading.
#   - If AGENTS.md is in the target list and .orchestrator/config.yml has
#     `dual_write_agents: false` at top level, AGENTS.md is skipped with a
#     `SKIPPED: AGENTS.md (dual_write_agents=false)` line on stderr.
#   - --dry-run emits one JSONL record per would-be write
#       {"command":"dual-write-runtime-md","action_type":"dual-write-region",
#        "target_path":"...","source_ref":"...","description":"..."}
#     to stdout and makes no disk writes.
#
# Exit: 0 on success; 1 on any error.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MARKER=""
CONTENT=""
DRY_RUN=0
TARGETS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --marker)
      if [ $# -lt 2 ]; then echo "--marker requires a value" >&2; exit 1; fi
      MARKER="$2"; shift 2
      ;;
    --content)
      if [ $# -lt 2 ]; then echo "--content requires a path" >&2; exit 1; fi
      CONTENT="$2"; shift 2
      ;;
    --file)
      if [ $# -lt 2 ]; then echo "--file requires a filename" >&2; exit 1; fi
      TARGETS="${TARGETS}${TARGETS:+ }$2"; shift 2
      ;;
    --root)
      if [ $# -lt 2 ]; then echo "--root requires a path" >&2; exit 1; fi
      PROJECT_ROOT="$2"; shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h)
      sed -n '1,/^$/p' "$0" | sed -e 's/^# //' -e 's/^#$//'
      exit 0
      ;;
    *)
      echo "dual-write-runtime-md.sh: unknown flag: $1" >&2; exit 1
      ;;
  esac
done

if [ -z "$MARKER" ]; then echo "missing --marker" >&2; exit 1; fi
if [ -z "$CONTENT" ] || [ ! -f "$CONTENT" ]; then
  echo "missing or unreadable --content: $CONTENT" >&2; exit 1
fi
if [ -z "$TARGETS" ]; then TARGETS="CLAUDE.md AGENTS.md"; fi

# --- Read dual_write_agents toggle from config ---
CONFIG="${PROJECT_ROOT}/.orchestrator/config.yml"
DUAL_WRITE_AGENTS=1
if [ -f "$CONFIG" ]; then
  if grep -qE '^dual_write_agents:[[:space:]]*false' "$CONFIG"; then
    DUAL_WRITE_AGENTS=0
  fi
fi

emit_dry_run_record() {
  local target="$1"
  printf '{"command":"dual-write-runtime-md","action_type":"dual-write-region","target_path":"%s","source_ref":"%s","description":"write marker-bounded region %s"}\n' \
    "$target" "$CONTENT" "$MARKER"
}

write_region() {
  local target="$1"
  local begin="# >>> orchestrator:${MARKER} >>>"
  local end="# <<< orchestrator:${MARKER} <<<"
  local tmp
  tmp="$(mktemp)"

  if [ ! -f "$target" ]; then
    # Create fresh file with just the marker region.
    {
      printf '%s\n' "$begin"
      cat "$CONTENT"
      printf '%s\n' "$end"
    } > "$tmp"
    mv "$tmp" "$target"
    return 0
  fi

  # Existing file: replace between markers, or insert above first heading/EOF.
  if grep -qF "$begin" "$target" && grep -qF "$end" "$target"; then
    # Replace in place. Use awk to copy-then-substitute the region.
    awk -v begin="$begin" -v end="$end" -v content_file="$CONTENT" '
      BEGIN { in_region=0 }
      $0 == begin {
        print $0
        while ((getline line < content_file) > 0) print line
        close(content_file)
        in_region=1
        next
      }
      $0 == end {
        print $0
        in_region=0
        next
      }
      in_region==0 { print }
    ' "$target" > "$tmp"
    mv "$tmp" "$target"
    return 0
  fi

  # Markers absent: insert above first heading, or at EOF if none.
  local first_heading_line
  first_heading_line="$(grep -nE '^#' "$target" | head -1 | awk -F: '{print $1}')"

  if [ -n "$first_heading_line" ]; then
    awk -v before="$first_heading_line" -v begin="$begin" -v end="$end" -v content_file="$CONTENT" '
      NR == before {
        print begin
        while ((getline line < content_file) > 0) print line
        close(content_file)
        print end
      }
      { print }
    ' "$target" > "$tmp"
    mv "$tmp" "$target"
  else
    {
      cat "$target"
      printf '%s\n' "$begin"
      cat "$CONTENT"
      printf '%s\n' "$end"
    } > "$tmp"
    mv "$tmp" "$target"
  fi
}

# --- Main: iterate targets ---
for t in $TARGETS; do
  abs_target="${PROJECT_ROOT}/${t}"

  # Apply dual_write_agents=false gate for AGENTS.md only.
  if [ "$t" = "AGENTS.md" ] && [ "$DUAL_WRITE_AGENTS" -eq 0 ]; then
    echo "SKIPPED: AGENTS.md (dual_write_agents=false)" >&2
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    emit_dry_run_record "$abs_target"
    continue
  fi

  write_region "$abs_target"
  echo "WROTE: $abs_target (region=${MARKER})"
done

exit 0
