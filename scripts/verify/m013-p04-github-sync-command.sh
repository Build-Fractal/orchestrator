#!/usr/bin/env bash
# scripts/verify/m013-p04-github-sync-command.sh
# T06 gate: commands/github-sync.md (MEM012 structure) +
# commands/github-status.md --verify-cache addendum.
#
# Single-script-file (AD-19) shape. Bash 3.2 compatible. AP-009 compliant.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="${REPO_ROOT}/commands/github-sync.md"
STATUS_DOC="${REPO_ROOT}/commands/github-status.md"

passed=0
failed=0
fail() {
  echo "FAIL: $1"
  failed=$((failed + 1))
}
pass() {
  echo "PASS: $1"
  passed=$((passed + 1))
}

# Assertion 1: github-sync.md exists.
if [ -f "$DOC" ]; then
  pass "github-sync.md exists"
else
  fail "github-sync.md missing at ${DOC}"
  echo "SUMMARY: m013-p04-github-sync-command.sh pass=${passed} fail=${failed}"
  exit 1
fi

# Assertion 2: YAML description frontmatter present.
if grep -qE '^description: *".+"' "$DOC"; then
  pass "YAML description frontmatter"
else
  fail "description frontmatter missing"
fi

# Assertion 3: Title line.
if grep -qE '^# orchestrator:github-sync' "$DOC"; then
  pass "Title line"
else
  fail "Title line missing"
fi

# Assertion 4-9: MEM012 sections present.
for section in "## Prerequisites" "## Core Workflow" "## Output" "## Idempotency" "## Error Handling" "## Referenced Scripts"; do
  if grep -qE "^${section}" "$DOC"; then
    pass "${section}"
  else
    fail "${section} missing"
  fi
done

# Assertion 10-14: Referenced scripts resolve.
for ref in scripts/integrations/github-sync.sh scripts/integrations/github-conversus-gate.sh scripts/integrations/github-common.sh scripts/dispatch/adapters/tool/conversus.sh scripts/lifecycle/lock-manager.sh; do
  if grep -q "$ref" "$DOC"; then
    if [ -f "${REPO_ROOT}/${ref}" ]; then
      pass "ref ${ref} resolves"
    else
      fail "ref ${ref} does not resolve"
    fi
  else
    fail "ref ${ref} missing from doc"
  fi
done

# Assertion 15: github-status.md addendum for --verify-cache.
if grep -q -- '--verify-cache' "$STATUS_DOC"; then
  pass "github-status.md --verify-cache addendum"
else
  fail "github-status.md --verify-cache addendum missing"
fi

# Assertion 16: description starts with "Use when".
if grep -qE '^description: *"Use when' "$DOC"; then
  pass "description starts with 'Use when'"
else
  fail "description does not start with 'Use when'"
fi

# Assertion 17: Error Handling documents rc codes (rc=3, rc=4, rc=6).
missing_rc=""
for code in "rc=3" "rc=4" "rc=6"; do
  if ! grep -q "$code" "$DOC"; then
    missing_rc="${missing_rc}${missing_rc:+,}${code}"
  fi
done
if [ -z "$missing_rc" ]; then
  pass "Error Handling documents rc=3 / rc=4 / rc=6"
else
  fail "Error Handling missing codes: ${missing_rc}"
fi

# Assertion 18: Core Workflow names sync_mode values.
if grep -q 'on-transition' "$DOC" && grep -q 'manual' "$DOC" && grep -q 'cron' "$DOC"; then
  pass "Core Workflow names all three sync modes"
else
  fail "Core Workflow does not enumerate all three sync modes"
fi

echo "SUMMARY: m013-p04-github-sync-command.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-github-sync-command.sh"
  exit 0
fi
echo "FAIL: m013-p04-github-sync-command.sh" >&2
exit 1
