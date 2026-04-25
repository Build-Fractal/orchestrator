#!/usr/bin/env bash
# scripts/verify/knowledge-schema-lint.sh — FR-9 schema-authority enforcement
# (SC-8). Scans knowledge/**/MEM*.md (excluding archive/) for:
#
#   1. Unauthorized frontmatter fields (additions outside the M020-authorized
#      set). Source of truth: knowledge/conventions/MEM031.md + the authorized
#      field allowlist embedded below (extend via D-row + MEM031 + this list).
#
#   2. Vocabulary drift on status: (closed enum {candidate, graduated, archived}).
#
#   3. Malformed frontmatter (missing leading or trailing `---`).
#
# Exit 0 + PASS line on a clean tree; exit 1 with FAIL lines on violations.
#
# Usage:
#   knowledge-schema-lint.sh [--root <dir>]
#       --root: directory containing knowledge/. Default: $(pwd).
#
# Read-only. No file mutations. Bash 3.2 compatible. AD-19 single-script-file
# shape. MEM001 prefixed-output conventions.

set -u

ROOT="."
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ $# -lt 2 ] && { echo "FAIL: --root requires a value" >&2; exit 1; }
      ROOT="$2"; shift 2 ;;
    --help|-h)
      cat >&2 <<'EOF'
Usage: knowledge-schema-lint.sh [--root <dir>]
Scans <root>/knowledge/**/MEM*.md (excluding archive/) for unauthorized
frontmatter fields, vocabulary drift on status, and malformed frontmatter.
EOF
      exit 0 ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      exit 1 ;;
  esac
done

KNOWLEDGE_DIR="$ROOT/knowledge"
if [ ! -d "$KNOWLEDGE_DIR" ]; then
  echo "FAIL: knowledge directory not found at $KNOWLEDGE_DIR"
  exit 1
fi

# --- Authorized field set (extend via D-row + MEM031 update + this list) ---
AUTHORIZED_FIELDS="id
scope_tags
category
confidence
created_at
last_verified
hit_count
source_unit
source_type
supersedes
superseded_by
relates_to
content_hash
status
decision_history
archived_into
topic
tags"

# --- Closed-enum vocabulary for status (MEM031) ---
STATUS_ENUM="candidate graduated archived"

violations=0
scanned=0

# Walk every knowledge/**/MEM*.md outside archive/.
while IFS= read -r file; do
  scanned=$(( scanned + 1 ))

  # --- 1. Frontmatter delimiter sanity ---
  first_line="$(head -n 1 "$file")"
  if [ "$first_line" != "---" ]; then
    echo "FAIL: malformed-frontmatter file=$file reason=missing-leading-delimiter"
    violations=$(( violations + 1 ))
    continue
  fi

  # Find the line number of the SECOND `---` (closing fence).
  closing_line="$(awk '/^---$/{n++; if (n==2){print NR; exit}}' "$file")"
  if [ -z "$closing_line" ]; then
    echo "FAIL: malformed-frontmatter file=$file reason=missing-closing-delimiter"
    violations=$(( violations + 1 ))
    continue
  fi

  # --- 2. Extract top-level frontmatter keys (lines like `key:` or `key: value`,
  # ignoring nested keys that begin with whitespace). ---
  keys="$(awk '
    NR == 1 { next }
    /^---$/ { exit }
    /^[A-Za-z_][A-Za-z0-9_]*:/ {
      sub(/:.*$/, "")
      print
    }
  ' "$file")"

  # --- 3. Check each key against the authorized set ---
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    found=0
    while IFS= read -r authorized; do
      [ -z "$authorized" ] && continue
      if [ "$key" = "$authorized" ]; then
        found=1
        break
      fi
    done <<EOF
$AUTHORIZED_FIELDS
EOF
    if [ "$found" -eq 0 ]; then
      echo "FAIL: unauthorized-field file=$file field=$key"
      violations=$(( violations + 1 ))
    fi
  done <<EOF
$keys
EOF

  # --- 4. Check status vocabulary if present ---
  status_val="$(awk '
    /^---$/ { n++; if (n>=2) exit; next }
    n==1 && /^status:[[:space:]]/ {
      sub(/^status:[[:space:]]*/, "")
      sub(/[[:space:]]+$/, "")
      sub(/^"/, ""); sub(/"$/, "")
      print
      exit
    }
  ' "$file")"

  if [ -n "$status_val" ]; then
    found=0
    for allowed in $STATUS_ENUM; do
      if [ "$status_val" = "$allowed" ]; then
        found=1
        break
      fi
    done
    if [ "$found" -eq 0 ]; then
      echo "FAIL: vocabulary-drift file=$file field=status value=$status_val allowed={candidate,graduated,archived}"
      violations=$(( violations + 1 ))
    fi
  fi
done < <(find "$KNOWLEDGE_DIR" -type f -name 'MEM*.md' -not -path '*/archive/*' | sort)

if [ "$violations" -gt 0 ]; then
  echo "FAIL: scanned $scanned entries; $violations violations"
  exit 1
fi

echo "PASS: scanned $scanned entries; 0 violations"
exit 0
