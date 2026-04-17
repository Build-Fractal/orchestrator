#!/usr/bin/env bash
# scripts/verify/m011-p07-bash32-compat.sh
# Scans all new P07 production scripts and verify scripts for
# Bash-3.2 incompatibilities (MEM001):
#   - declare -A (associative arrays)
#   - mapfile / readarray
#   - process substitution <(...) and >(...)
# Also runs `bash -n` on every file to assert parse-clean.
#
# Bash 3.2 compatible.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

files=""
add_file() {
  if [ -f "$REPO/$1" ]; then
    files="${files} $1"
  else
    printf 'FAIL: expected file missing: %s\n' "$1"
    fail=1
  fi
}

fail=0

# --- Production scripts new or edited in P07 ---
add_file "scripts/knowledge/detect-spec-shape.sh"
add_file "scripts/knowledge/normalize-spec.sh"
add_file "scripts/dispatch/adapters/tool/conversus.sh"
add_file "scripts/engine/intensity-gate.sh"

# --- P07 verify scripts (all m011-p07-*.sh under scripts/verify/) ---
for f in "$REPO"/scripts/verify/m011-p07-*.sh; do
  if [ -f "$f" ]; then
    rel="${f#$REPO/}"
    files="${files} ${rel}"
  fi
done

for rel in $files; do
  full="$REPO/$rel"
  # Parse check
  if ! bash -n "$full" 2>/dev/null; then
    printf 'FAIL[parse]: %s does not parse cleanly under bash -n\n' "$rel"
    fail=1
    continue
  fi
  # declare -A / bash-4+ bulk-read builtins check.
  # Exclude comment lines by stripping leading-# lines before the scan,
  # so comments describing these tokens don't trigger the guard.
  body="$(grep -vE '^[[:space:]]*#' "$full" || true)"
  # Build regex from parts so this scanner's own source does not contain
  # any of the forbidden literal tokens.
  tok_a='declare[[:space:]]+-A'
  tok_b='map''file'
  tok_c='read''array'
  regex="\b(${tok_a}|${tok_b}|${tok_c})\b"
  if printf '%s\n' "$body" | grep -Eq "$regex"; then
    tok="$(printf '%s\n' "$body" | grep -Eo "$regex" | head -n 1)"
    printf 'FAIL[bash32]: %s uses prohibited token: %s\n' "$rel" "$tok"
    fail=1
    continue
  fi
  # Process substitution check. Build the regex from parts so this
  # scanner's own source does not contain the literal forbidden bytes.
  ps_regex='<''\(|>''\('
  if printf '%s\n' "$body" | grep -Eq -- "$ps_regex"; then
    printf 'FAIL[bash32]: %s uses process substitution\n' "$rel"
    fail=1
    continue
  fi
  printf 'PASS[bash32]: %s\n' "$rel"
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: Bash 3.2 compatibility scan across all P07 scripts"
exit 0
