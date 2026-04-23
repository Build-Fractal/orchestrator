#!/usr/bin/env bash
# Gate: verify WRITE-SITES.md is present + shaped + the enumerated set matches
# the actual call-site state on disk.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MANIFEST="${PROJECT_ROOT}/.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md"

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: WRITE-SITES.md missing at $MANIFEST" >&2
  exit 1
fi

# Presence of region names.
grep -q 'project-identity' "$MANIFEST" || { echo "FAIL: project-identity region not named" >&2; exit 1; }
grep -q 'recent-changes'   "$MANIFEST" || { echo "FAIL: recent-changes region not named" >&2; exit 1; }

# Presence of the four enumerated scripts.
grep -q 'scripts/specify/specify.sh'               "$MANIFEST" || { echo "FAIL: P01 specify site not listed" >&2; exit 1; }
grep -q 'scripts/lifecycle/init-project.sh'        "$MANIFEST" || { echo "FAIL: init-project site not listed" >&2; exit 1; }
grep -q 'scripts/lifecycle/reinit-handler.sh'      "$MANIFEST" || { echo "FAIL: reinit-handler site not listed" >&2; exit 1; }
grep -q 'scripts/knowledge/consolidate-artifacts.sh' "$MANIFEST" || { echo "FAIL: consolidate site not listed" >&2; exit 1; }

# Count enumerated sites (exactly 4 rows).
SITE_ROWS=$(grep -cE '^\| [0-9]+ \| `scripts/' "$MANIFEST")
if [ "$SITE_ROWS" -ne 4 ]; then
  echo "FAIL: expected 4 enumerated site rows; found $SITE_ROWS" >&2
  exit 1
fi

# Scan for disallowed write patterns outside the helper.
# Allow list: test-only, verifier-only, the helper itself, and the
# init/reinit render_template path.
DISALLOWED=$(mktemp)
trap 'rm -f "$DISALLOWED"' EXIT

# Find direct redirects to CLAUDE.md / AGENTS.md in scripts/ (excluding verify/, tests/,
# migrate/, the helper, and init/reinit where render_template is the allowed shape).
grep -rnE '>[[:space:]]*"[^"]*CLAUDE\.md"' "$PROJECT_ROOT/scripts/" 2>/dev/null \
  | grep -v 'scripts/verify/' \
  | grep -v 'scripts/migrate/' \
  | grep -v 'scripts/util/dual-write-runtime-md\.sh' \
  | grep -v 'scripts/lifecycle/init-project\.sh' \
  | grep -v 'scripts/lifecycle/reinit-handler\.sh' \
  > "$DISALLOWED" 2>/dev/null || true

grep -rnE '>[[:space:]]*"[^"]*AGENTS\.md"' "$PROJECT_ROOT/scripts/" 2>/dev/null \
  | grep -v 'scripts/verify/' \
  | grep -v 'scripts/migrate/' \
  | grep -v 'scripts/util/dual-write-runtime-md\.sh' \
  | grep -v 'scripts/lifecycle/init-project\.sh' \
  | grep -v 'scripts/lifecycle/reinit-handler\.sh' \
  >> "$DISALLOWED" 2>/dev/null || true

DISALLOWED_COUNT=$(wc -l < "$DISALLOWED" | tr -d ' ')
if [ "$DISALLOWED_COUNT" -ne 0 ]; then
  echo "FAIL: disallowed direct CLAUDE.md/AGENTS.md writes found outside the helper:" >&2
  cat "$DISALLOWED" >&2
  exit 1
fi

echo "PASS: write-site manifest and enumeration invariant verified"
exit 0
