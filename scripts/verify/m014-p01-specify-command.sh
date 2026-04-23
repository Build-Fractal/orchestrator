#!/usr/bin/env bash
# Gate: verify commands/specify.md shape.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CMD="${PROJECT_ROOT}/commands/specify.md"

if [ ! -f "$CMD" ]; then
  echo "FAIL: commands/specify.md missing" >&2; exit 1
fi

grep -qE '^---$' "$CMD" || { echo "FAIL: YAML frontmatter absent" >&2; exit 1; }
grep -qE '^description:' "$CMD" || { echo "FAIL: description frontmatter field missing" >&2; exit 1; }
grep -qE '^# orchestrator:specify' "$CMD" || { echo "FAIL: title heading missing" >&2; exit 1; }
grep -qE '^## Prerequisites' "$CMD" || { echo "FAIL: Prerequisites section missing" >&2; exit 1; }
grep -qE '^## Usage' "$CMD" || { echo "FAIL: Usage section missing" >&2; exit 1; }
grep -qE '^## Workflow' "$CMD" || { echo "FAIL: Workflow section missing" >&2; exit 1; }
grep -qE '^## Output' "$CMD" || { echo "FAIL: Output section missing" >&2; exit 1; }
grep -qE '^## Idempotency' "$CMD" || { echo "FAIL: Idempotency section missing" >&2; exit 1; }
grep -qE '^## Error Handling' "$CMD" || { echo "FAIL: Error Handling section missing" >&2; exit 1; }
grep -qE '^## Referenced Scripts' "$CMD" || { echo "FAIL: Referenced Scripts section missing" >&2; exit 1; }

# Every required script is referenced.
for ref in "scripts/specify/specify.sh" "templates/spec-template.md" "scripts/util/dual-write-runtime-md.sh" "scripts/verify/spec-shape-lint.sh" "scripts/knowledge/spec-complexity-probe.sh"; do
  grep -qF "$ref" "$CMD" || { echo "FAIL: Referenced Scripts missing $ref" >&2; exit 1; }
done

echo "PASS: commands/specify.md shape verified"
exit 0
