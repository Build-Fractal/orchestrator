#!/usr/bin/env bash
# scripts/verify/m025-p01-coexistence.sh -- M025/P01/T03 gate:
# end-to-end coexistence test. Seeds ~/.claude/settings.json from the canonical
# GSD-shaped fixture, runs install-claude-code.sh, and compares the result
# structurally against tests/fixtures/m025-p01/expected-post-install.json.
#
# Structural comparator (python3) ignores key ordering and whitespace; it
# checks semantic JSON equivalence, which is the contract (merge helper
# canonicalizes via json.dumps(sort_keys=True), and hand-authored fixtures
# match that shape because expected-post-install.json was captured from a
# real merge run, not hand-written).
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALLER="${REPO_ROOT}/packaging/install/install-claude-code.sh"
FIXTURE_SEED="${REPO_ROOT}/tests/fixtures/m025-p01/gsd-baseline/settings.json"
EXPECTED="${REPO_ROOT}/tests/fixtures/m025-p01/expected-post-install.json"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

if [ ! -f "$FIXTURE_SEED" ]; then
  fail "fixture missing: $FIXTURE_SEED"
fi
if [ ! -f "$EXPECTED" ]; then
  fail "expected-post-install.json missing: $EXPECTED"
fi

TMPHOME="$(mktemp -d -t m025-p01-coex-home.XXXXXX)"
TMPPRJ="$(mktemp -d -t m025-p01-coex-prj.XXXXXX)"
cleanup() { rm -rf "$TMPHOME" "$TMPPRJ"; }
trap cleanup EXIT

mkdir -p "$TMPHOME/.claude"
cp "$FIXTURE_SEED" "$TMPHOME/.claude/settings.json"

CLAUDECODE=1 HOME="$TMPHOME" bash "$INSTALLER" --project-dir "$TMPPRJ" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "installer exits 0 against fixture-seeded HOME"
else
  fail "installer exited rc=${rc}"
fi

RESULT="$TMPHOME/.claude/settings.json"
if [ ! -f "$RESULT" ]; then
  fail "post-install settings.json missing"
else
  pass "post-install settings.json present"
fi

# Structural comparison via python3: equality of parsed JSON (deep-equal).
python3 - "$RESULT" "$EXPECTED" <<'PYEOF'
import json, sys
a = json.load(open(sys.argv[1]))
b = json.load(open(sys.argv[2]))
if a != b:
    # Provide a minimal diff hint on stderr for debuggability.
    sa = json.dumps(a, indent=2, sort_keys=True)
    sb = json.dumps(b, indent=2, sort_keys=True)
    sys.stderr.write("RESULT:\n" + sa + "\n\nEXPECTED:\n" + sb + "\n")
    sys.exit(1)
PYEOF
if [ $? -eq 0 ]; then
  pass "post-install JSON structurally equals expected-post-install.json"
else
  fail "post-install JSON diverges from expected-post-install.json"
fi

echo "SUMMARY: m025-p01-coexistence.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-coexistence.sh"
  exit 0
fi
echo "FAIL: m025-p01-coexistence.sh" >&2
exit 1
