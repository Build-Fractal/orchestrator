#!/usr/bin/env bash
# scripts/verify/m008-p07-detect-project-contract.sh
# Empty-project contract check for detect-project.sh — all required keys must be emitted.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

out="$(bash "$REPO_ROOT/scripts/lifecycle/detect-project.sh" --project-dir "$FIXTURE")"
rc=$?

if [ $rc -ne 0 ]; then
  echo "FAIL: detect-project.sh exited $rc on empty project" >&2
  exit 1
fi

for key in language framework ci_system tools_detected project_type has_git has_tests; do
  if ! echo "$out" | grep -q "^$key="; then
    echo "FAIL: missing key '$key=' in output" >&2
    echo "$out" >&2
    exit 1
  fi
done

echo "PASS: detect-project.sh emits required keys on empty project"
