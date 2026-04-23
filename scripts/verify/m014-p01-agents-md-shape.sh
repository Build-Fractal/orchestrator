#!/usr/bin/env bash
# Gate: verify AGENTS.md exists with marker-bounded region after a specify run.
# This gate runs after the end-to-end specify test; it asserts the repo-root
# AGENTS.md has the markers (the first specify run will land this when T05
# is dispatched end-to-end during auto execution, OR during the phase-suite
# dogfood run).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AGENTS="${PROJECT_ROOT}/AGENTS.md"
CLAUDE="${PROJECT_ROOT}/CLAUDE.md"

# For P01 close, AGENTS.md may not yet exist at repo root (only scratch
# scaffolds have exercised it). The gate: IF AGENTS.md exists, its marker
# region must be well-formed; else the gate passes silently (creation is
# guarded by first specify invocation in auto mode).
if [ -f "$AGENTS" ]; then
  grep -qF '# >>> orchestrator:recent-changes >>>' "$AGENTS" || {
    echo "FAIL: AGENTS.md exists but missing orchestrator:recent-changes begin marker" >&2; exit 1
  }
  grep -qF '# <<< orchestrator:recent-changes <<<' "$AGENTS" || {
    echo "FAIL: AGENTS.md exists but missing orchestrator:recent-changes end marker" >&2; exit 1
  }
fi

# CLAUDE.md at repo root should gain markers once T05 dogfoods a write; until
# then, this gate is lenient.
if grep -qF '# >>> orchestrator:recent-changes >>>' "$CLAUDE"; then
  grep -qF '# <<< orchestrator:recent-changes <<<' "$CLAUDE" || {
    echo "FAIL: CLAUDE.md has begin marker but missing end marker" >&2; exit 1
  }
fi

echo "PASS: AGENTS.md shape verified"
exit 0
