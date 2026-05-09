#!/usr/bin/env bash
# tools/verify/m035-p05-rollback-driver-shape.sh
#
# M035 P05 T02 — Asserts the --rollback dispatch in run-update.sh covers
# the four refusal/error branches with the documented error shapes:
#
#   A. missing marker            -> exit 1, stderr matches "no prior version recorded"
#   B. symlink-mode refusal      -> exit 1, stderr matches verbatim advisory
#                                          AND echoes the prior_commit_sha in the
#                                          `git checkout <sha>` substitution
#   C. mixed-mode refusal        -> exit 1, stderr matches the same advisory
#   D. missing snapshot          -> exit 1, stderr matches "prior manifest snapshot missing"
#
# T02 verifier does NOT exercise the actual git-checkout / cp loop — that
# is T05's acceptance test (m035-p05-rollback-byte-equivalence.sh) which
# sets up a real source repo and a real install. T02 covers only the
# refusal/error branches that have no source-repo dependency.
#
# AD-19 single-script-file shape. Bash 3.2 + POSIX-sh per CON-2.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
DRIVER="$REPO/scripts/lifecycle/run-update.sh"

FIXTURE_ROOT="/tmp/m035-p05-t02-driver-fixture-$$"
mkdir -p "$FIXTURE_ROOT"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

pass=0
fail=0

# --- Scenario A: missing marker ---
A_DIR="$FIXTURE_ROOT/A-missing-marker"
mkdir -p "$A_DIR/.orchestrator"
# No .previous-version file.

a_out="$(bash "$DRIVER" --rollback --project-dir "$A_DIR" 2>&1 1>/dev/null)"
a_rc=$?
if [ "$a_rc" -ne 0 ] && echo "$a_out" | grep -q 'no prior version recorded'; then
  echo "PASS: missing-marker emits documented error and exits non-zero"
  pass=$((pass + 1))
else
  echo "FAIL: missing-marker scenario (rc=$a_rc)"
  echo "$a_out" | sed 's/^/  /'
  fail=$((fail + 1))
fi

# --- Scenario B: symlink-mode refusal ---
B_DIR="$FIXTURE_ROOT/B-symlink-mode"
mkdir -p "$B_DIR/.orchestrator"
{
  printf 'prior_version=0.9.1\n'
  printf 'prior_commit_sha=abcd1234\n'
  printf 'prior_manifest_path=.orchestrator/.rollback/manifest-0.9.1.txt\n'
  printf 'prior_install_mode=symlink\n'
  printf 'rolled_at=\n'
} > "$B_DIR/.orchestrator/.previous-version"

b_out="$(bash "$DRIVER" --rollback --project-dir "$B_DIR" 2>&1 1>/dev/null)"
b_rc=$?
b_ok=1
if [ "$b_rc" -eq 0 ]; then
  b_ok=0
fi
if ! echo "$b_out" | grep -q 'rollback not available for symlink-mode installs'; then
  b_ok=0
fi
if ! echo "$b_out" | grep -q 'git checkout abcd1234'; then
  b_ok=0
fi
if [ "$b_ok" -eq 1 ]; then
  echo "PASS: symlink-mode refusal emits verbatim advisory"
  pass=$((pass + 1))
else
  echo "FAIL: symlink-mode refusal scenario (rc=$b_rc)"
  echo "$b_out" | sed 's/^/  /'
  fail=$((fail + 1))
fi

# --- Scenario C: mixed-mode refusal ---
C_DIR="$FIXTURE_ROOT/C-mixed-mode"
mkdir -p "$C_DIR/.orchestrator"
{
  printf 'prior_version=0.9.1\n'
  printf 'prior_commit_sha=deadbeef\n'
  printf 'prior_manifest_path=.orchestrator/.rollback/manifest-0.9.1.txt\n'
  printf 'prior_install_mode=mixed\n'
  printf 'rolled_at=\n'
} > "$C_DIR/.orchestrator/.previous-version"

c_out="$(bash "$DRIVER" --rollback --project-dir "$C_DIR" 2>&1 1>/dev/null)"
c_rc=$?
c_ok=1
if [ "$c_rc" -eq 0 ]; then
  c_ok=0
fi
if ! echo "$c_out" | grep -q 'rollback not available for symlink-mode installs'; then
  c_ok=0
fi
if ! echo "$c_out" | grep -q 'git checkout deadbeef'; then
  c_ok=0
fi
if [ "$c_ok" -eq 1 ]; then
  echo "PASS: mixed-mode refusal emits verbatim advisory"
  pass=$((pass + 1))
else
  echo "FAIL: mixed-mode refusal scenario (rc=$c_rc)"
  echo "$c_out" | sed 's/^/  /'
  fail=$((fail + 1))
fi

# --- Scenario D: missing snapshot ---
D_DIR="$FIXTURE_ROOT/D-missing-snapshot"
mkdir -p "$D_DIR/.orchestrator"
{
  printf 'prior_version=0.9.1\n'
  printf 'prior_commit_sha=cafebabe\n'
  printf 'prior_manifest_path=.orchestrator/.rollback/manifest-bogus.txt\n'
  printf 'prior_install_mode=copy\n'
  printf 'rolled_at=\n'
} > "$D_DIR/.orchestrator/.previous-version"
# Intentionally do NOT create the manifest snapshot file.

d_out="$(bash "$DRIVER" --rollback --project-dir "$D_DIR" 2>&1 1>/dev/null)"
d_rc=$?
if [ "$d_rc" -ne 0 ] && echo "$d_out" | grep -q 'prior manifest snapshot missing'; then
  echo "PASS: missing-snapshot emits documented error and exits non-zero"
  pass=$((pass + 1))
else
  echo "FAIL: missing-snapshot scenario (rc=$d_rc)"
  echo "$d_out" | sed 's/^/  /'
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
