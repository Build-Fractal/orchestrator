#!/usr/bin/env bash
# m008-p07-init-dry-run-hermetic.sh — --dry-run produces no writes, emits SUMMARY + would_write.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

# Fake a Node project so detect-project has something interesting to report.
echo '{"name":"fixture"}' > "$FIXTURE_PROJ/package.json"

HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code --dry-run \
  > /tmp/p07-init-dry.out 2>&1
rc=$?

if [ $rc -ne 0 ]; then
  echo "FAIL: dry-run exited $rc" >&2
  cat /tmp/p07-init-dry.out >&2
  exit 1
fi

grep -q '^would_write=' /tmp/p07-init-dry.out || { echo "FAIL: no would_write= lines" >&2; cat /tmp/p07-init-dry.out >&2; exit 1; }
grep -q '^SUMMARY:' /tmp/p07-init-dry.out || { echo "FAIL: no SUMMARY: line" >&2; cat /tmp/p07-init-dry.out >&2; exit 1; }
grep -q 'CLAUDE.md' /tmp/p07-init-dry.out || { echo "FAIL: CLAUDE.md path not in dry-run output" >&2; cat /tmp/p07-init-dry.out >&2; exit 1; }

# Assert no writes happened.
test -f "$FIXTURE_PROJ/CLAUDE.md" && { echo "FAIL: dry-run wrote CLAUDE.md" >&2; exit 1; }
test -f "$FIXTURE_PROJ/.orchestrator/config.yml" && { echo "FAIL: dry-run wrote config.yml" >&2; exit 1; }

echo "PASS: init-project.sh --dry-run hermetic"
