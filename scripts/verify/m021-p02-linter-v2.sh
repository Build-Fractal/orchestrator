#!/usr/bin/env bash
# scripts/verify/m021-p02-linter-v2.sh — Gate for anti-pattern-lint.sh v2 coverage.
#
# Asserts:
#   - Class A detectors (AP-004) still fire on the three class-a-*.md fixtures.
#   - Class B detectors (AP-005..AP-009) fire on each corresponding class-b-*.md fixture.
#   - suppressed.md yields zero violations.
#   - clean.md yields zero violations.
#   - ANTIPATTERNS.md contains AP-005..AP-009 each naming a scripts/util/*.sh path.
#
# Exit: 0 on all assertions pass, 1 otherwise.
# Bash 3.2 compatible. Gate internals may use compound bash freely (MEM004,
# AP-004 scope-of-enforcement note) — the enforcement point is inline-tool-call
# invocations, not internal bash of verification scripts.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINTER="${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh"
FIX_DIR="${REPO_ROOT}/tests/fixtures/m021-p02"
AP="${REPO_ROOT}/ANTIPATTERNS.md"

fail_count=0

assert_contains() {
  # $1 = label, $2 = haystack text, $3 = needle
  if printf '%s' "$2" | grep -qF "$3"; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (missing substring: $3)"
    fail_count=$((fail_count + 1))
  fi
}

assert_empty() {
  # $1 = label, $2 = rc from linter, $3 = output
  if [ "$2" = "0" ] && ! printf '%s' "$3" | grep -q 'LINT FAIL'; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (exit=$2, output=$3)"
    fail_count=$((fail_count + 1))
  fi
}

run_lint() {
  # $1 = fixture path; prints linter stdout+stderr; returns linter exit code
  bash "$LINTER" --fixture "$1" 2>&1
}

# --- Class A fixtures ---
out="$(run_lint "$FIX_DIR/class-a-cmd-sub.md" || true)"
assert_contains "Class A: command substitution flagged [AP-004]" "$out" "[AP-004]"

out="$(run_lint "$FIX_DIR/class-a-backtick.md" || true)"
assert_contains "Class A: backtick flagged [AP-004]" "$out" "[AP-004]"

out="$(run_lint "$FIX_DIR/class-a-brace.md" || true)"
assert_contains "Class A: brace expansion flagged [AP-004]" "$out" "[AP-004]"

# --- Class B fixtures ---
out="$(run_lint "$FIX_DIR/class-b-simple-expansion.md" || true)"
assert_contains "Class B: simple-expansion flagged [AP-005]" "$out" "[AP-005]"
assert_contains "Class B: simple-expansion hint names with-env.sh" "$out" "scripts/util/with-env.sh"

out="$(run_lint "$FIX_DIR/class-b-redirect-cmd-sub.md" || true)"
assert_contains "Class B: redirect-cmd-sub flagged [AP-006]" "$out" "[AP-006]"

out="$(run_lint "$FIX_DIR/class-b-quoted-brace.md" || true)"
assert_contains "Class B: quoted-brace flagged [AP-007]" "$out" "[AP-007]"

out="$(run_lint "$FIX_DIR/class-b-heredoc-expansion.md" || true)"
assert_contains "Class B: heredoc-expansion flagged [AP-008]" "$out" "[AP-008]"
assert_contains "Class B: heredoc-expansion hint names run-probe.sh" "$out" "scripts/util/run-probe.sh"

# --- task-plan-compound requires */tasks/*-PAYLOAD.md path shape ---
# Stage the fixture under a tempdir with a literal tasks/ path segment.
_tmpdir="$(mktemp -d)"
mkdir -p "$_tmpdir/tasks"
cp "$FIX_DIR/class-b-task-plan-compound-PAYLOAD.md" "$_tmpdir/tasks/T99-PAYLOAD.md"
out="$(run_lint "$_tmpdir/tasks/T99-PAYLOAD.md" || true)"
assert_contains "Class B: task-plan-compound flagged [AP-009]" "$out" "[AP-009]"
rm -rf "$_tmpdir"

# --- Suppression + clean fixtures: zero violations ---
out="$(bash "$LINTER" --fixture "$FIX_DIR/suppressed.md" 2>&1)"
rc=$?
assert_empty "Suppressed region yields zero violations" "$rc" "$out"

out="$(bash "$LINTER" --fixture "$FIX_DIR/clean.md" 2>&1)"
rc=$?
assert_empty "Clean fixture yields zero violations" "$rc" "$out"

# --- ANTIPATTERNS.md contains AP-005..AP-009 each naming a P01 wrapper ---
for ap in AP-005 AP-006 AP-007 AP-008 AP-009; do
  if grep -q "^## ${ap}:" "$AP"; then
    echo "PASS: ANTIPATTERNS.md contains ${ap} heading"
  else
    echo "FAIL: ANTIPATTERNS.md missing ${ap} heading"
    fail_count=$((fail_count + 1))
  fi
done

# Each AP-00X section should name at least one scripts/util/*.sh path.
# Extract AP-005..AP-009 body blocks and grep each for scripts/util/.
_wrappers_file="$(mktemp)"
awk '
  /^## AP-005:/ {section="AP-005"; capture=1; next}
  /^## AP-006:/ {section="AP-006"; capture=1; next}
  /^## AP-007:/ {section="AP-007"; capture=1; next}
  /^## AP-008:/ {section="AP-008"; capture=1; next}
  /^## AP-009:/ {section="AP-009"; capture=1; next}
  /^## / {capture=0; section=""}
  capture && /scripts\/util\// {print section}
' "$AP" | sort -u > "$_wrappers_file" 2>/dev/null || true

for ap in AP-005 AP-006 AP-007 AP-008 AP-009; do
  if grep -q "^${ap}$" "$_wrappers_file" 2>/dev/null; then
    echo "PASS: ${ap} names a scripts/util/ wrapper"
  else
    echo "FAIL: ${ap} does not name any scripts/util/ wrapper"
    fail_count=$((fail_count + 1))
  fi
done
rm -f "$_wrappers_file"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p02-linter-v2.sh"
  exit 0
fi
echo "FAIL: m021-p02-linter-v2.sh ($fail_count failures)"
exit 1
