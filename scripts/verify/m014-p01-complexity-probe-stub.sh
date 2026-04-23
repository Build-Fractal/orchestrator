#!/usr/bin/env bash
# Gate: verify spec-complexity-probe.sh stub behavior.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROBE="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"

if [ ! -x "$PROBE" ]; then
  echo "FAIL: scripts/knowledge/spec-complexity-probe.sh missing or not executable" >&2
  exit 1
fi

# Run against an existing spec file.
TARGET="${PROJECT_ROOT}/specs/024-spec-management-extended/spec.md"
if [ ! -f "$TARGET" ]; then
  echo "FAIL: target spec missing: $TARGET" >&2; exit 1
fi

STDOUT="$(bash "$PROBE" "$TARGET" 2>/dev/null)"
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: probe exited $RC (expected 0)" >&2; exit 1
fi

echo "$STDOUT" | grep -qF 'probe=below-threshold' || {
  echo "FAIL: probe stdout missing probe=below-threshold" >&2; exit 1;
}

STDERR_FILE="$(mktemp)"
bash "$PROBE" "$TARGET" >/dev/null 2> "$STDERR_FILE"
grep -qF 'fr_count=0' "$STDERR_FILE" || {
  echo "FAIL: probe stderr missing fr_count=0" >&2; rm -f "$STDERR_FILE"; exit 1;
}
grep -qF 'contradiction_signals=0' "$STDERR_FILE" || {
  echo "FAIL: probe stderr missing contradiction_signals=0" >&2; rm -f "$STDERR_FILE"; exit 1;
}
rm -f "$STDERR_FILE"

# Missing-arg case.
bash "$PROBE" >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "FAIL: probe with no args exited 0 (expected non-zero)" >&2; exit 1
fi

# Non-existent path case.
bash "$PROBE" /tmp/does-not-exist-m014-p01.md >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "FAIL: probe against missing path exited 0 (expected non-zero)" >&2; exit 1
fi

echo "PASS: complexity-probe stub verified"
exit 0
