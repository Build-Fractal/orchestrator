#!/usr/bin/env bash
# scripts/diagnostics/check-hashes.sh — Knowledge entry content_hash validation
#
# Scans knowledge entry .md files for valid content_hash fields in YAML
# frontmatter. Valid format: sha256:<64 hex chars>.
#
# Usage: check-hashes.sh [--root <project-root>]
#
# Output: DOCTOR:HASHES status=<ok|warn> valid=N missing=N
#
# Bash 3.2 compatible. Advisory only — reports state, does not fix it.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "check-hashes.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Collect knowledge entry .md files ---
FILES=""
for dir in "$PROJECT_ROOT/.orchestrator/knowledge"; do
  if [ -d "$dir" ]; then
    for f in "$dir"/*.md; do
      [ -f "$f" ] || continue
      FILES="${FILES}${f}
"
    done
    # Also check subdirectories one level deep
    for subdir in "$dir"/*/; do
      [ -d "$subdir" ] || continue
      for f in "$subdir"*.md; do
        [ -f "$f" ] || continue
        FILES="${FILES}${f}
"
      done
    done
  fi
done

# --- No knowledge entries: report ok with zero counts ---
if [ -z "$FILES" ]; then
  printf 'DOCTOR:HASHES status=ok valid=0 missing=0\n'
  exit 0
fi

# --- Validate content_hash in each file ---
valid=0
missing=0
missing_files=""

while IFS= read -r file; do
  [ -z "$file" ] && continue

  # Extract YAML frontmatter (between first --- and next ---)
  in_frontmatter=false
  found_valid=false
  found_hash_line=false

  while IFS= read -r line; do
    if [ "$in_frontmatter" = false ]; then
      case "$line" in
        "---"*) in_frontmatter=true ;;
      esac
      continue
    fi

    # End of frontmatter
    case "$line" in
      "---"*)
        break
        ;;
    esac

    # Look for content_hash line
    case "$line" in
      content_hash:*)
        found_hash_line=true
        # Extract value after "content_hash:"
        hash_value="${line#content_hash:}"
        # Trim leading/trailing whitespace and quotes
        hash_value="$(printf '%s' "$hash_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//;s/^'"'"'//;s/'"'"'$//')"
        # Validate format: sha256:<64 hex chars>
        if printf '%s' "$hash_value" | grep -qE '^sha256:[a-f0-9]{64}$'; then
          found_valid=true
        fi
        ;;
    esac
  done < "$file"

  if [ "$found_valid" = true ]; then
    valid=$((valid + 1))
  else
    missing=$((missing + 1))
    rel_path="${file#"$PROJECT_ROOT"/}"
    missing_files="${missing_files}  MISSING: ${rel_path}
"
  fi
done <<FILES_EOF
$FILES
FILES_EOF

# --- Report ---
if [ "$missing" -eq 0 ]; then
  status="ok"
else
  status="warn"
fi

printf 'DOCTOR:HASHES status=%s valid=%d missing=%d\n' "$status" "$valid" "$missing"

if [ "$status" = "warn" ] && [ -n "$missing_files" ]; then
  printf '%s' "$missing_files"
fi

if [ "$status" = "warn" ]; then
  exit 1
fi
exit 0
