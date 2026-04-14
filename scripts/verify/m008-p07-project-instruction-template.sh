#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TPL="$REPO_ROOT/templates/project-instruction.md"

test -f "$TPL" || { echo "FAIL: template not found: $TPL" >&2; exit 1; }

# Required sections
for section in "Project Overview" "Detected Capabilities" "Detected Runtime" "Orchestrator Conventions"; do
  grep -q "^## $section" "$TPL" || {
    echo "FAIL: missing section '## $section'" >&2
    exit 1
  }
done

# Required placeholders
for ph in "{{project_type}}" "{{language}}" "{{framework}}" "{{ci_system}}" "{{runtime}}" "{{cap_score}}" "{{state_root}}"; do
  grep -qF "$ph" "$TPL" || {
    echo "FAIL: missing placeholder '$ph'" >&2
    exit 1
  }
done

# Custom-block markers — exact-line match required
grep -q "^<!-- BEGIN CUSTOM -->$" "$TPL" || { echo "FAIL: missing BEGIN CUSTOM marker on its own line" >&2; exit 1; }
grep -q "^<!-- END CUSTOM -->$" "$TPL" || { echo "FAIL: missing END CUSTOM marker on its own line" >&2; exit 1; }

# YAML frontmatter
head -4 "$TPL" | grep -q 'schema_version:' || { echo "FAIL: missing schema_version in frontmatter" >&2; exit 1; }
head -4 "$TPL" | grep -q 'type: project-instruction' || { echo "FAIL: missing type in frontmatter" >&2; exit 1; }

echo "PASS: project-instruction.md template conforms"
