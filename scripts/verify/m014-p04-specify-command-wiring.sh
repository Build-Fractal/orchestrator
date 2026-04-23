#!/usr/bin/env bash
# Gate: T04 — commands/specify.md Workflow + Subcommand updates.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOC="${PROJECT_ROOT}/commands/specify.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$DOC" ] || fail "commands/specify.md missing"

grep -qF 'conversus pressure-test recommended' "$DOC"        || fail "three-way prompt text missing"
grep -qF 'spec-pressure-test' "$DOC"                         || fail "preset name missing"
grep -qF 'Three-way prompt' "$DOC"                           || fail "Three-way prompt subheading missing"
grep -qF 'LLM-assisted splitter' "$DOC"                      || fail "splitter description missing"
grep -qF 'three-case semantics' "$DOC"                       || fail "three-case semantics description missing"

# Deferral language gone.
grep -qF 'P01 ships the surface; full semantics in later phases' "$DOC" \
  && fail "P01 deferral language still present"
grep -qF 'prints a deferral diagnostic and exits 2' "$DOC" \
  && fail "P01 split-stub language still present"

echo "PASS: commands/specify.md wiring updated"
exit 0
