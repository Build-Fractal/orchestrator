#!/usr/bin/env bash
# tools/verify/m037-p01-mkdocs-polish-bundle.sh — M037 P01 T05 Truth #5 verifier (FR-9).
#
# Asserts wiki/mkdocs.yml carries all nine polish-bundle additions:
#   1. - navigation.tabs        (under theme.features:)
#   2. - navigation.tabs.sticky (under theme.features:)
#   3. - navigation.prune       (under theme.features:)
#   4. - content.action.edit    (under theme.features:)
#   5. - content.action.view    (under theme.features:)
#   6. toc_depth: 2             (under markdown_extensions: toc:)
#   7. - pymdownx.details       (under markdown_extensions:)
#   8. - pymdownx.tasklist:     (with custom_checkbox: true)
#   9. edit_uri:                (top-level key)
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MKDOCS="$PROJECT_ROOT/wiki/mkdocs.yml"

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

if [ ! -f "$MKDOCS" ]; then
  printf 'FAIL: mkdocs.yml not found at %s\n' "$MKDOCS"
  exit 1
fi

# 1. navigation.tabs
if grep -qE '^[[:space:]]*-[[:space:]]+navigation\.tabs[[:space:]]*$' "$MKDOCS"; then
  ok "theme.features: - navigation.tabs"
else
  bad "theme.features: missing - navigation.tabs"
fi

# 2. navigation.tabs.sticky
if grep -qE '^[[:space:]]*-[[:space:]]+navigation\.tabs\.sticky[[:space:]]*$' "$MKDOCS"; then
  ok "theme.features: - navigation.tabs.sticky"
else
  bad "theme.features: missing - navigation.tabs.sticky"
fi

# 3. navigation.prune
if grep -qE '^[[:space:]]*-[[:space:]]+navigation\.prune[[:space:]]*$' "$MKDOCS"; then
  ok "theme.features: - navigation.prune"
else
  bad "theme.features: missing - navigation.prune"
fi

# 4. content.action.edit
if grep -qE '^[[:space:]]*-[[:space:]]+content\.action\.edit[[:space:]]*$' "$MKDOCS"; then
  ok "theme.features: - content.action.edit"
else
  bad "theme.features: missing - content.action.edit"
fi

# 5. content.action.view
if grep -qE '^[[:space:]]*-[[:space:]]+content\.action\.view[[:space:]]*$' "$MKDOCS"; then
  ok "theme.features: - content.action.view"
else
  bad "theme.features: missing - content.action.view"
fi

# 6. toc_depth: 2 (under toc:)
if grep -qE '^[[:space:]]+toc_depth:[[:space:]]+2[[:space:]]*$' "$MKDOCS"; then
  ok "markdown_extensions: toc_depth: 2"
else
  bad "markdown_extensions: missing toc_depth: 2"
fi

# 7. pymdownx.details
if grep -qE '^[[:space:]]*-[[:space:]]+pymdownx\.details[[:space:]]*$' "$MKDOCS"; then
  ok "markdown_extensions: - pymdownx.details"
else
  bad "markdown_extensions: missing - pymdownx.details"
fi

# 8. pymdownx.tasklist: followed by custom_checkbox: true
# Use awk to assert ordering: find a line matching pymdownx.tasklist:, then
# verify the next non-comment line carries custom_checkbox: true.
if awk '
  /^[[:space:]]*-[[:space:]]+pymdownx\.tasklist:[[:space:]]*$/ { found_tasklist=1; next }
  found_tasklist && /^[[:space:]]*#/ { next }
  found_tasklist && /^[[:space:]]*custom_checkbox:[[:space:]]+true[[:space:]]*$/ { print "ok"; exit 0 }
  found_tasklist && NF { exit 1 }
' "$MKDOCS" | grep -q '^ok$'; then
  ok "markdown_extensions: - pymdownx.tasklist: with custom_checkbox: true"
else
  bad "markdown_extensions: missing - pymdownx.tasklist: with custom_checkbox: true"
fi

# 9. edit_uri: top-level
if grep -qE '^edit_uri:' "$MKDOCS"; then
  ok "top-level edit_uri: key present"
else
  bad "top-level edit_uri: key missing"
fi

printf 'SUMMARY: m037-p01-mkdocs-polish-bundle pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: m037-p01-mkdocs-polish-bundle (%d/%d)\n' "$pass" "$pass"
  exit 0
fi
exit 1
