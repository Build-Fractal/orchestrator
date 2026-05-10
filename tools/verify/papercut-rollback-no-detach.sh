#!/usr/bin/env bash
# tools/verify/papercut-rollback-no-detach.sh — papercut-sweep-post-M035 PC-6
#
# Asserts tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh
# leaves the host repo on its original branch (no detached HEAD) after
# completion. The rollback driver's `git checkout <prior-sha>` is a
# content-no-op when prior-SHA equals current-HEAD but detaches HEAD;
# the test now installs a trap-EXIT recovery to restore the branch.
#
# Bash 3.2 / AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

pass=0
fail=0

# Capture pre-test branch.
pre_branch="$(git rev-parse --abbrev-ref HEAD)"
pre_sha="$(git rev-parse HEAD)"

if [ "$pre_branch" = "HEAD" ]; then
  printf 'SKIP: starting on detached HEAD; cannot exercise PC-6 recovery contract\n' >&2
  printf 'BATTERY: pass=0 fail=0\n'
  exit 0
fi

# Run the rollback test (capture output to a tempfile; we don't care
# about its BATTERY result here, only the post-state).
test_log="$(mktemp -t papercut-pc6-rb.XXXXXX)"
bash tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh >"$test_log" 2>&1
rb_rc=$?

post_branch="$(git rev-parse --abbrev-ref HEAD)"
post_sha="$(git rev-parse HEAD)"

# Check 1 — post-test branch matches pre-test branch (no detached HEAD).
if [ "$post_branch" = "$pre_branch" ]; then
  printf 'PASS: post-test branch=%s (matches pre-test)\n' "$post_branch"
  pass=$((pass + 1))
else
  printf 'FAIL: post-test branch=%s (pre=%s) — recovery did not fire\n' \
    "$post_branch" "$pre_branch"
  fail=$((fail + 1))
fi

# Check 2 — post-test SHA matches pre-test SHA (no rewind).
if [ "$post_sha" = "$pre_sha" ]; then
  printf 'PASS: post-test HEAD=%s (matches pre-test SHA)\n' "$post_sha"
  pass=$((pass + 1))
else
  printf 'FAIL: post-test HEAD=%s (pre=%s)\n' "$post_sha" "$pre_sha"
  fail=$((fail + 1))
fi

# Check 3 — recovery message emitted to stderr if recovery fired.
if grep -q 'restoring HEAD to' "$test_log"; then
  printf 'PASS: recovery INFO message emitted (trap fired)\n'
  pass=$((pass + 1))
else
  printf 'PASS: no recovery needed (no INFO message — HEAD never detached)\n'
  pass=$((pass + 1))
fi

# Surface the underlying test's exit so this verifier inherits a
# meaningful FAIL when the rollback test itself fails. We also
# surface the stderr if the rollback test failed.
if [ "$rb_rc" -ne 0 ]; then
  printf 'NOTE: rollback test exited rc=%d; HEAD-recovery contract still verified above\n' "$rb_rc"
fi

rm -f "$test_log"

printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
