#!/usr/bin/env bash
# scripts/verify/graphql-call-shape.sh — FR-5 GraphQL call-shape CI lint.
#
# Scans `scripts/integrations/github-*.sh` for GraphQL mutation invocations,
# extracts the top-level mutation name, and asserts membership in the
# three-shape whitelist: createProjectV2, addProjectV2ItemById,
# updateProjectV2ItemFieldValue.
#
# Output: one `SHAPE: <name>` line per match (stdout), then:
#   PASS: graphql-call-shape.sh <N> mutation shapes, all whitelisted
# on success (exit 0), or
#   FAIL: graphql-call-shape.sh unexpected shape: <name>
# on failure (exit 1 + stderr diagnostic).
#
# Scope: scripts/integrations/github-*.sh only. Unrelated GraphQL elsewhere
# in the repo (e.g., scripts/diagnostics/wiki-giscus-remap.sh) is out of
# scope for M013's FR-5 whitelist.
#
# Bash 3.2 compatible. No assoc-arrays, no array-from-stdin builtins, no
# process substitution.
# Invoked by CI via scripts/verify/m013-p03-phase-suite.sh and directly by
# scripts/verify/m013-p03-graphql-call-shape-selftest.sh with a fixture
# override passed as $1.

set -u

SCAN_ROOT="${1:-}"
if [ -z "$SCAN_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  SCAN_ROOT="${REPO_ROOT}/scripts/integrations"
fi

WHITELIST="createProjectV2 addProjectV2ItemById updateProjectV2ItemFieldValue"

# Collect matching files.
files=""
if [ -d "$SCAN_ROOT" ]; then
  files="$(find "$SCAN_ROOT" -maxdepth 1 -type f -name 'github-*.sh' 2>/dev/null || true)"
fi

# Extract mutation shapes. The regex anchors on `mutation(` and skips
# `query(` forms — only mutation call shapes are whitelisted. Matches both
# the single-line --field query= shape (P02) and any heredoc/assigned-
# variable shape anticipated downstream.
shapes_raw=""
if [ -n "$files" ]; then
  shapes_raw="$(awk '
    /mutation\(/ {
      s = $0
      idx = index(s, "mutation(")
      if (idx == 0) next
      rest = substr(s, idx)
      bc = index(rest, "){")
      if (bc == 0) next
      after = substr(rest, bc + 2)
      name = ""
      for (i = 1; i <= length(after); i++) {
        c = substr(after, i, 1)
        if (c ~ /[A-Za-z0-9_]/) {
          name = name c
        } else {
          break
        }
      }
      if (name != "") print name
    }
  ' $files 2>/dev/null || true)"
fi

# Emit per-match diagnostic lines.
if [ -n "$shapes_raw" ]; then
  printf '%s\n' "$shapes_raw" | while IFS= read -r sh; do
    [ -n "$sh" ] && echo "SHAPE: ${sh}"
  done
fi

# Deduplicate.
shapes_unique="$(printf '%s\n' "$shapes_raw" | sort -u | awk 'NF > 0')"

if [ -z "$shapes_unique" ]; then
  echo "FAIL: graphql-call-shape.sh zero mutation shapes found — expected at least 2 after P02" >&2
  exit 1
fi

# Assert each unique shape is in the whitelist.
fail_count=0
IFS='
'
for sh in $shapes_unique; do
  IFS=' '
  ok=0
  for w in $WHITELIST; do
    if [ "$sh" = "$w" ]; then
      ok=1
      break
    fi
  done
  if [ "$ok" -eq 0 ]; then
    echo "FAIL: graphql-call-shape.sh unexpected shape: ${sh}" >&2
    fail_count=$((fail_count + 1))
  fi
  IFS='
'
done
IFS=' '

count_total="$(printf '%s\n' "$shapes_unique" | awk 'NF > 0 { n++ } END { print n + 0 }')"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

echo "PASS: graphql-call-shape.sh ${count_total} mutation shapes, all whitelisted"
exit 0
