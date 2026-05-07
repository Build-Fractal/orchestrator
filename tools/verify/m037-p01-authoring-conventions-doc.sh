#!/usr/bin/env bash
# tools/verify/m037-p01-authoring-conventions-doc.sh — M037 P01 T04 Truth #8 verifier.
#
# Asserts the authoring-conventions reference doc is in place. Five checks:
#   1. references/authoring-conventions.md exists.
#   2. File has >= 100 lines.
#   3. File contains all four required substrings:
#        DR-CODE-NNN, navigation.prune, pymdownx.details, Mermaid.
#   4. File contains a "## Code Conventions" section header.
#   5. File contains a "## Mkdocs-Material Features" section header.
#
# Expected output on full pass: 'PASS: m037-p01-authoring-conventions-doc (5/5)'.
# Single-script-file shape (AD-19). Bash 3.2 + POSIX sh compatible (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DOC="$PROJECT_ROOT/references/authoring-conventions.md"

pass=0
fail=0

ok() {
  printf 'CHECK PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'CHECK FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

# 1. File exists.
if [ -f "$DOC" ]; then
  ok "references/authoring-conventions.md exists"
else
  bad "references/authoring-conventions.md missing"
  printf 'SUMMARY: m037-p01-authoring-conventions-doc pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# 2. Line count >= 100.
line_count=$(wc -l < "$DOC" | tr -d ' ')
if [ "$line_count" -ge 100 ]; then
  ok "line count $line_count >= 100"
else
  bad "line count $line_count < 100"
fi

# 3. All four required substrings (single check — all four must be present).
missing=""
for needle in 'DR-CODE-NNN' 'navigation.prune' 'pymdownx.details' 'Mermaid'; do
  if ! grep -F -q "$needle" "$DOC"; then
    if [ -z "$missing" ]; then
      missing="$needle"
    else
      missing="$missing, $needle"
    fi
  fi
done
if [ -z "$missing" ]; then
  ok "all four required substrings present (DR-CODE-NNN, navigation.prune, pymdownx.details, Mermaid)"
else
  bad "missing required substring(s): $missing"
fi

# 4. "## Code Conventions" section header.
if grep -E -q '^## Code Conventions' "$DOC"; then
  ok "contains '## Code Conventions' section header"
else
  bad "missing '## Code Conventions' section header"
fi

# 5. "## Mkdocs-Material Features" section header.
if grep -E -q '^## Mkdocs-Material Features' "$DOC"; then
  ok "contains '## Mkdocs-Material Features' section header"
else
  bad "missing '## Mkdocs-Material Features' section header"
fi

printf 'SUMMARY: m037-p01-authoring-conventions-doc pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: m037-p01-authoring-conventions-doc (%d/5)\n' "$pass"
  exit 0
fi
exit 1
