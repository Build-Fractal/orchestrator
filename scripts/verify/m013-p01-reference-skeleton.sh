#!/usr/bin/env bash
# scripts/verify/m013-p01-reference-skeleton.sh
#
# Gate for T06 (M013/P01): asserts references/github-integration.md exists
# with all P01 mandatory section headings, references every P01 shipping
# artifact by literal path, and that references/README.md indexes the new doc.
#
# Single-script-file (AD-19) shape. Bash 3.2 compatible. AP-009 compliant.
# Structured output: PASS:/FAIL: prefixes to stdout. 0/1 exits.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="${REPO_ROOT}/references/github-integration.md"
README="${REPO_ROOT}/references/README.md"

fail_count=0
assert_ok() {
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2"
    fail_count=$((fail_count + 1))
  fi
}

# 1. Doc exists
[ -f "$DOC" ]
assert_ok $? "references/github-integration.md exists"

# 2. Mandatory section headings
grep -q '^## Overview' "$DOC"
assert_ok $? "has Overview section"

grep -q '^## Sidecar Config Schema' "$DOC"
assert_ok $? "has Sidecar Config Schema section"

grep -q 'Pending-Sentinel Semantics' "$DOC"
assert_ok $? "has Pending-Sentinel Semantics section"

grep -q 'sync_mode' "$DOC"
assert_ok $? "has sync_mode Enum section"

grep -q 'orchestrator-id' "$DOC"
assert_ok $? "has orchestrator-id Marker Format section"

grep -q 'UAT Ingestion Contract' "$DOC"
assert_ok $? "has UAT Ingestion Contract section"

grep -q 'Knowledge-Layer Boundary' "$DOC"
assert_ok $? "has Knowledge-Layer Boundary section"

grep -q 'Scope Boundary' "$DOC"
assert_ok $? "has Scope Boundary section"

# 3. Referenced P01 artifact paths (must be present verbatim)
grep -qF ".orchestrator/integrations/github.json" "$DOC"
assert_ok $? "references path: .orchestrator/integrations/github.json"

grep -qF "templates/github-integration-sidecar.json" "$DOC"
assert_ok $? "references path: templates/github-integration-sidecar.json"

grep -qF "scripts/integrations/github-status.sh" "$DOC"
assert_ok $? "references path: scripts/integrations/github-status.sh"

grep -qF "commands/github-status.md" "$DOC"
assert_ok $? "references path: commands/github-status.md"

grep -qF ".github/ISSUE_TEMPLATE/uat-bug.yml" "$DOC"
assert_ok $? "references path: .github/ISSUE_TEMPLATE/uat-bug.yml"

grep -qF "scripts/knowledge/rebuild-index.sh" "$DOC"
assert_ok $? "references path: scripts/knowledge/rebuild-index.sh"

grep -qF "knowledge/spec/defect/README.md" "$DOC"
assert_ok $? "references path: knowledge/spec/defect/README.md"

grep -qF "scripts/integrations/uat-ingest.sh" "$DOC"
assert_ok $? "references path: scripts/integrations/uat-ingest.sh"

# 4. README index entry
[ -f "$README" ]
assert_ok $? "references/README.md exists"

grep -q "github-integration.md" "$README"
assert_ok $? "references/README.md indexes github-integration.md"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-reference-skeleton.sh"
  exit 0
fi
echo "FAIL: m013-p01-reference-skeleton.sh ($fail_count failures)"
exit 1
