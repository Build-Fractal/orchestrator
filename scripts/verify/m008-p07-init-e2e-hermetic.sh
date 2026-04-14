#!/usr/bin/env bash
# m008-p07-init-e2e-hermetic.sh — full init writes config.yml + CLAUDE.md, delegates to installer.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

echo '{"name":"fixture"}' > "$FIXTURE_PROJ/package.json"

HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code \
  > /tmp/p07-init-e2e.out 2>&1
rc=$?

if [ $rc -ne 0 ]; then
  echo "FAIL: init exited $rc" >&2
  cat /tmp/p07-init-e2e.out >&2
  exit 1
fi

test -f "$FIXTURE_PROJ/CLAUDE.md" || { echo "FAIL: CLAUDE.md not created" >&2; exit 1; }
test -f "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config.yml not created at $FIXTURE_PROJ/.orchestrator/config.yml" >&2; ls -la "$FIXTURE_PROJ" >&2; exit 1; }

grep -q 'schema_version:' "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config missing schema_version" >&2; exit 1; }
grep -q 'runtime:' "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config missing runtime" >&2; exit 1; }
grep -q 'state_root:' "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config missing state_root" >&2; exit 1; }
grep -q 'capabilities:' "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config missing capabilities" >&2; exit 1; }

# Placeholders must have been substituted.
grep -q '{{' "$FIXTURE_PROJ/CLAUDE.md" && { echo "FAIL: CLAUDE.md still contains {{placeholders}}" >&2; exit 1; }
grep -q '^## Project Overview' "$FIXTURE_PROJ/CLAUDE.md" || { echo "FAIL: CLAUDE.md missing Project Overview section" >&2; exit 1; }

# Skills should be under hermetic HOME (delegated by install-claude-code.sh).
test -d "$FIXTURE_HOME/.claude/commands" || { echo "FAIL: skills dir not created under hermetic HOME" >&2; ls -la "$FIXTURE_HOME" >&2; exit 1; }

grep -q '^SUMMARY:' /tmp/p07-init-e2e.out || { echo "FAIL: no SUMMARY line" >&2; cat /tmp/p07-init-e2e.out >&2; exit 1; }

echo "PASS: init-project.sh e2e hermetic (claude-code)"
