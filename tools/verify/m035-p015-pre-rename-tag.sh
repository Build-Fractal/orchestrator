#!/usr/bin/env bash
# tools/verify/m035-p015-pre-rename-tag.sh
#
# M035/P01.5/T01 verifier — asserts the pre-rename git tag
# `v0.9.*-final-spec-kit-name` exists in local refs and resolves to a real
# commit. Patch number is not pinned because it is captured at T01 execution
# time and may drift between author and execution.
#
# Single-script-file shape per AD-19. No compound chains (CON-3 / AP-009).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

tag_match=$(git tag --list 'v0.9.*-final-spec-kit-name' | head -n 1)
if [ -z "$tag_match" ]; then
  echo "FAIL: pre-rename tag v0.9.*-final-spec-kit-name not found" >&2
  exit 1
fi

if ! git rev-parse --verify "$tag_match" >/dev/null 2>&1; then
  echo "FAIL: tag $tag_match does not resolve to a commit" >&2
  exit 1
fi

echo "PASS: m035-p015-pre-rename-tag found=$tag_match"
exit 0
