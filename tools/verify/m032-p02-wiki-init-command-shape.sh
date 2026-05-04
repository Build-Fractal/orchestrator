#!/usr/bin/env bash
# tools/verify/m032-p02-wiki-init-command-shape.sh
#
# M032/P02/T01 verifier (Truth 1): asserts commands/wiki-init.md exists,
# carries the MEM012 orchestrator command-file structure (description
# frontmatter + seven required sections), references
# scripts/lifecycle/wiki-init.sh as the canonical implementation, and
# names FR-5 + FR-12 explicitly.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
# No inline compound bash, no command substitution containing pipes.
#
# Output: per-check PASS/FAIL lines + a single final stdout SUMMARY line.
# Exit 0 iff fail=0.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DOC="$PROJECT_ROOT/commands/wiki-init.md"

pass=0
fail=0

check_pass() {
  pass=$((pass + 1))
  echo "PASS: $1"
}

check_fail() {
  fail=$((fail + 1))
  echo "FAIL: $1"
}

# Check 1: commands/wiki-init.md exists.
if [ -f "$DOC" ]; then
  check_pass "$DOC exists"
else
  check_fail "$DOC missing"
  echo "SUMMARY: m032-p02-wiki-init-command-shape.sh pass=$pass fail=$fail"
  exit 1
fi

# Check 2: YAML frontmatter description: field present.
if grep -q '^description:' "$DOC"; then
  check_pass "$DOC has description: in YAML frontmatter"
else
  check_fail "$DOC missing description: in YAML frontmatter"
fi

# Check 3: Title heading "# orchestrator:wiki-init".
if grep -q '^# orchestrator:wiki-init' "$DOC"; then
  check_pass "$DOC has '# orchestrator:wiki-init' title heading"
else
  check_fail "$DOC missing '# orchestrator:wiki-init' title heading"
fi

# Checks 4-9: the six required ## section headings per MEM012.
for section in "Prerequisites" "Core Workflow" "Output" "Idempotency" "Error Handling" "Referenced Scripts"; do
  if grep -q "^## $section" "$DOC"; then
    check_pass "$DOC has '## $section' section"
  else
    check_fail "$DOC missing '## $section' section"
  fi
done

# Check 10: references scripts/lifecycle/wiki-init.sh as canonical implementation.
if grep -q 'scripts/lifecycle/wiki-init.sh' "$DOC"; then
  check_pass "$DOC references scripts/lifecycle/wiki-init.sh"
else
  check_fail "$DOC missing reference to scripts/lifecycle/wiki-init.sh"
fi

# Check 11: FR-5 named.
if grep -q 'FR-5' "$DOC"; then
  check_pass "$DOC references FR-5"
else
  check_fail "$DOC missing FR-5 reference"
fi

# Check 12: FR-12 named.
if grep -q 'FR-12' "$DOC"; then
  check_pass "$DOC references FR-12"
else
  check_fail "$DOC missing FR-12 reference"
fi

# Check 13: --with-giscus + --deploy declared as P03-deferred composable scopes.
if grep -q -- '--with-giscus' "$DOC"; then
  check_pass "$DOC declares --with-giscus scope (P03 deliverable)"
else
  check_fail "$DOC missing --with-giscus declaration"
fi

if grep -q -- '--deploy' "$DOC"; then
  check_pass "$DOC declares --deploy scope (P03 deliverable)"
else
  check_fail "$DOC missing --deploy declaration"
fi

# Check 14: --auto-pip declared (P02 surface, FR-12 / #Q-2).
if grep -q -- '--auto-pip' "$DOC"; then
  check_pass "$DOC declares --auto-pip flag"
else
  check_fail "$DOC missing --auto-pip declaration"
fi

echo "SUMMARY: m032-p02-wiki-init-command-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
