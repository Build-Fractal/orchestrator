#!/usr/bin/env bash
# scripts/verify/m027-p01-read-only.sh — M027/P01 Truth #10 (FR-12,
# CON-1, SC-9).
#
# Asserts the predictive script set is read-only against the project
# tree: `git diff --quiet` exit status is unchanged after running
# cost-estimate.sh, intensity-recommend.sh (text + json), and
# metrics-rollup.sh.
#
# If the working tree is already dirty pre-run (developer mid-edit),
# the verifier emits WARN and exits 0 — this avoids false positives in
# interactive use; CI runs against a clean tree.
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out.

set -u

NAME="m027-p01-read-only.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CE="$PROJECT_ROOT/scripts/engine/cost-estimate.sh"
IR="$PROJECT_ROOT/scripts/engine/intensity-recommend.sh"
ROLLUP="$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

[ -f "$CE" ] || fail "cost-estimate.sh missing"
[ -f "$IR" ] || fail "intensity-recommend.sh missing"
[ -f "$ROLLUP" ] || fail "metrics-rollup.sh missing"

cd "$PROJECT_ROOT" || fail "cannot cd to project root"

# Pre-check git working tree.
if ! command -v git >/dev/null 2>&1; then
  printf 'WARN: %s git not available; skipping read-only assertion\n' "$NAME"
  exit 0
fi
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  printf 'WARN: %s not a git repository; skipping read-only assertion\n' "$NAME"
  exit 0
fi

git diff --quiet 2>/dev/null
pre_rc=$?
git diff --cached --quiet 2>/dev/null
pre_cached_rc=$?

if [ "$pre_rc" -ne 0 ] || [ "$pre_cached_rc" -ne 0 ]; then
  printf 'WARN: %s working-tree-dirty pre-run; skipping read-only assertion\n' "$NAME"
  exit 0
fi

# Run the read-only invocations.
bash "$CE" --description "test" >/dev/null 2>&1
bash "$IR" --description "test" >/dev/null 2>&1
bash "$IR" --description "test" --format json >/dev/null 2>&1
bash "$ROLLUP" --granularity milestone --milestone M019 >/dev/null 2>&1

# Re-check.
git diff --quiet 2>/dev/null
post_rc=$?
git diff --cached --quiet 2>/dev/null
post_cached_rc=$?

if [ "$post_rc" -ne 0 ] || [ "$post_cached_rc" -ne 0 ]; then
  printf 'FAIL: %s read-only invariant violated (working tree dirty post-run)\n' "$NAME" >&2
  git diff --stat >&2 || true
  exit 1
fi

printf 'PASS: %s git diff --quiet clean post-invocation\n' "$NAME"
exit 0
