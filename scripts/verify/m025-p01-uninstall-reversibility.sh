#!/usr/bin/env bash
# scripts/verify/m025-p01-uninstall-reversibility.sh -- M025/P01/T03 gate:
# round-trip install + uninstall against the canonical GSD fixture. Asserts
# post-uninstall sha256 equals expected-post-uninstall.sha256 (a pinned
# capture from a real round-trip run), AND that the post-uninstall content
# is structurally equivalent to the pre-install baseline (semantic byte
# invariant; canonical re-serialization via the merge helper changes the
# literal bytes but preserves every non-orchestrator key).
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"
FIXTURE_SEED="${REPO_ROOT}/tests/fixtures/m025-p01/gsd-baseline/settings.json"
EXPECTED_SHA_FILE="${REPO_ROOT}/tests/fixtures/m025-p01/expected-post-uninstall.sha256"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

if [ ! -f "$FIXTURE_SEED" ]; then
  fail "fixture missing: $FIXTURE_SEED"
fi
if [ ! -f "$EXPECTED_SHA_FILE" ]; then
  fail "expected sha256 pin missing: $EXPECTED_SHA_FILE"
fi

EXPECTED_SHA="$(cat "$EXPECTED_SHA_FILE" | tr -d '[:space:]')"
if [ -z "$EXPECTED_SHA" ]; then
  fail "expected sha256 pin empty"
fi

TMPHOME="$(mktemp -d -t m025-p01-rev-home.XXXXXX)"
TMPPRJ="$(mktemp -d -t m025-p01-rev-prj.XXXXXX)"
cleanup() { rm -rf "$TMPHOME" "$TMPPRJ"; }
trap cleanup EXIT

mkdir -p "$TMPHOME/.claude"
cp "$FIXTURE_SEED" "$TMPHOME/.claude/settings.json"
RESULT="$TMPHOME/.claude/settings.json"

sha_pre="$(shasum -a 256 "$RESULT" | awk '{print $1}')"
pass "captured pre-install sha256=${sha_pre}"

# Install.
CLAUDECODE=1 HOME="$TMPHOME" bash "$INSTALLER" --project-dir "$TMPPRJ" >/dev/null 2>&1
rc_install=$?
if [ "$rc_install" -eq 0 ]; then
  pass "install step exits 0"
else
  fail "install step exited rc=${rc_install}"
fi

# Uninstall.
CLAUDECODE=1 HOME="$TMPHOME" bash "$INSTALLER" --uninstall --project-dir "$TMPPRJ" >/dev/null 2>&1
rc_uninstall=$?
if [ "$rc_uninstall" -eq 0 ]; then
  pass "uninstall step exits 0"
else
  fail "uninstall step exited rc=${rc_uninstall}"
fi

sha_post="$(shasum -a 256 "$RESULT" | awk '{print $1}')"

# Assertion 1: post-uninstall sha matches the pinned expected sha.
if [ "$sha_post" = "$EXPECTED_SHA" ]; then
  pass "post-uninstall sha256 matches expected-post-uninstall.sha256 (${sha_post})"
else
  fail "post-uninstall sha256=${sha_post} != expected=${EXPECTED_SHA}"
fi

# Assertion 2: post-uninstall content is structurally equivalent to baseline.
python3 - "$RESULT" "$FIXTURE_SEED" <<'PYEOF'
import json, sys
a = json.load(open(sys.argv[1]))
b = json.load(open(sys.argv[2]))
if a != b:
    sys.stderr.write("post-uninstall diverges from baseline:\n")
    sys.stderr.write("post:\n" + json.dumps(a, indent=2, sort_keys=True) + "\n")
    sys.stderr.write("baseline:\n" + json.dumps(b, indent=2, sort_keys=True) + "\n")
    sys.exit(1)
PYEOF
if [ $? -eq 0 ]; then
  pass "post-uninstall content structurally equals pre-install baseline"
else
  fail "post-uninstall content diverges from baseline"
fi

echo "SUMMARY: m025-p01-uninstall-reversibility.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-uninstall-reversibility.sh"
  exit 0
fi
echo "FAIL: m025-p01-uninstall-reversibility.sh" >&2
exit 1
