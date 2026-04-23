#!/usr/bin/env bash
# Gate: verify RUNTIME-ASSUMPTIONS.md shape and entries.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REGISTRY="${PROJECT_ROOT}/RUNTIME-ASSUMPTIONS.md"

if [ ! -f "$REGISTRY" ]; then
  echo "FAIL: RUNTIME-ASSUMPTIONS.md missing at repo root" >&2; exit 1
fi

# Required sections and entries.
grep -qF 'type: runtime-assumptions-registry' "$REGISTRY" || {
  echo "FAIL: frontmatter type missing" >&2; exit 1;
}
grep -qF '# Runtime Assumptions Registry' "$REGISTRY" || {
  echo "FAIL: top-level heading missing" >&2; exit 1;
}
grep -qF '## Entry Schema' "$REGISTRY" || {
  echo "FAIL: ## Entry Schema section missing" >&2; exit 1;
}
grep -qE '^### FR-3: LLM-assisted scaffold-fill depth' "$REGISTRY" || {
  echo "FAIL: FR-3 entry missing" >&2; exit 1;
}
grep -qE '^### FR-5: Complexity probe contradiction-signal count' "$REGISTRY" || {
  echo "FAIL: FR-5 entry missing" >&2; exit 1;
}

# Each entry has the four required subsections.
grep -qF 'Claude Code assumption' "$REGISTRY" || {
  echo "FAIL: 'Claude Code assumption' subsection absent" >&2; exit 1;
}
grep -qF 'Codex/Cursor fallback' "$REGISTRY" || {
  echo "FAIL: 'Codex/Cursor fallback' subsection absent" >&2; exit 1;
}
grep -qF 'M009 obligation' "$REGISTRY" || {
  echo "FAIL: 'M009 obligation' subsection absent" >&2; exit 1;
}
grep -qF 'D016' "$REGISTRY" || {
  echo "FAIL: D016 cross-reference absent" >&2; exit 1;
}

echo "PASS: RUNTIME-ASSUMPTIONS.md shape verified"
exit 0
