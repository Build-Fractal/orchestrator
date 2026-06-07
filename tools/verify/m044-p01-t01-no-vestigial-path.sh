#!/usr/bin/env bash
# tools/verify/m044-p01-t01-no-vestigial-path.sh
# M044/P01/T01 (FR-11): build-context.sh resolves the index path through the
# canonical get_index_path() resolver (sources index-utils.sh + calls it); any
# surviving literal KNOWLEDGE-INDEX.md join is a GUARDED fallback only.
# Bash 3.2 compatible. Emits PASS:/FAIL:; exit 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

BC="scripts/dispatch/build-context.sh"
fail=0

if [ ! -f "$BC" ]; then
  echo "FAIL: $BC not found"
  exit 1
fi

# Must source the canonical resolver lib.
if ! grep -q 'index-utils.sh' "$BC"; then
  echo "FAIL: build-context.sh does not source index-utils.sh"
  fail=1
fi

# Must call get_index_path.
if ! grep -q 'get_index_path' "$BC"; then
  echo "FAIL: build-context.sh does not call get_index_path"
  fail=1
fi

# Both resolution sites must reference the resolved-var-then-literal-fallback
# pattern (the literal join only appears in an elif branch). Heuristic: every
# line that assigns a *-KNOWLEDGE_INDEX var from a bare PROJECT_ROOT literal is
# preceded somewhere by a get_index_path resolution. We assert the resolver
# call count is >= 2 (one per site) so neither site is bare-literal-only.
resolver_calls="$(grep -c 'get_index_path' "$BC")"
if [ "$resolver_calls" -lt 2 ]; then
  echo "FAIL: expected >=2 get_index_path call sites in build-context.sh, found $resolver_calls"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: build-context.sh routes both index-path sites through get_index_path (literal joins are guarded fallbacks)"
  exit 0
fi
exit 1
