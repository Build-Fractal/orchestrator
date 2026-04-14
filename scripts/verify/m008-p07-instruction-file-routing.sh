#!/usr/bin/env bash
# m008-p07-instruction-file-routing.sh — verifies runtime -> instruction-file path mapping via dry-run.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

check_route() {
  # $1 = runtime, $2 = expected relative instruction path
  FIXTURE_HOME="$(mktemp -d)"
  FIXTURE_PROJ="$(mktemp -d)"
  HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
    --project-dir "$FIXTURE_PROJ" --runtime "$1" --dry-run > /tmp/p07-route.out 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"
    echo "FAIL: dry-run failed for runtime $1 (rc=$rc)" >&2
    cat /tmp/p07-route.out >&2
    exit 1
  fi
  if ! grep -qF "$FIXTURE_PROJ/$2" /tmp/p07-route.out; then
    rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"
    echo "FAIL: $1 did not route to $2" >&2
    cat /tmp/p07-route.out >&2
    exit 1
  fi
  rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"
}

check_route "claude-code" "CLAUDE.md"
check_route "codex"       "AGENTS.md"
check_route "cursor"      ".cursor/rules/orchestrator.md"

echo "PASS: instruction-file routing (claude-code/codex/cursor)"
