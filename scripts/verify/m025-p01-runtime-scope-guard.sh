#!/usr/bin/env bash
# scripts/verify/m025-p01-runtime-scope-guard.sh -- M025/P01/T03 gate:
# enforces FR-9 / CON-5. The four non-Claude-Code runtime files must remain
# byte-identical to their pre-P01 state, AND must not contain any M025
# scope markers.
#
# Pinned sha256 digests captured at gate-write time (T03 execution) from
# the four protected files. If any of these files is edited during P01,
# the gate fails -- which is the contract.
#
# Protected files:
#   packaging/install/install-codex.sh
#   packaging/install/install-cursor.sh
#   scripts/dispatch/adapters/runtime/codex.sh
#   scripts/dispatch/adapters/runtime/cursor.sh
#
# Negative-grep guard: each file must contain zero matches for the scope
# markers: _orchestrator_managed, settings-merge, M025.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

# Pinned sha256 (captured 2026-04-22 during T03).
PIN_install_codex="caeb0cc05165affd14ad6c84daee0bc32a11fcaae1641d58dbd378f6bda9e269"
PIN_install_cursor="3f7fa447f1142487b320ea989f08888733f0a6c00831529bc5d0e5dcbaa602b5"
PIN_adapter_codex="4b4765101e32ae56071bde41b0605389c7091f3669c78c4166b523697349b495"
PIN_adapter_cursor="c95aa6291434c9315a69f97485e8e818daefd5b6fff5eb352244e709f5d0dfe3"

check_pin() {
  rel="$1"
  expected="$2"
  path="${REPO_ROOT}/${rel}"
  if [ ! -f "$path" ]; then
    fail "protected file missing: ${rel}"
    return
  fi
  actual="$(shasum -a 256 "$path" | awk '{print $1}')"
  if [ "$actual" = "$expected" ]; then
    pass "sha256 pin holds: ${rel}"
  else
    fail "sha256 drift: ${rel} expected=${expected} actual=${actual}"
  fi
}

check_pin "packaging/install/install-codex.sh" "$PIN_install_codex"
check_pin "packaging/install/install-cursor.sh" "$PIN_install_cursor"
check_pin "scripts/dispatch/adapters/runtime/codex.sh" "$PIN_adapter_codex"
check_pin "scripts/dispatch/adapters/runtime/cursor.sh" "$PIN_adapter_cursor"

# Negative-grep guard for each protected file.
PROTECTED="
packaging/install/install-codex.sh
packaging/install/install-cursor.sh
scripts/dispatch/adapters/runtime/codex.sh
scripts/dispatch/adapters/runtime/cursor.sh
"

IFS='
'
for rel in $PROTECTED; do
  IFS=' '
  [ -n "$rel" ] || continue
  path="${REPO_ROOT}/${rel}"
  if [ ! -f "$path" ]; then
    IFS='
'
    continue
  fi
  # Scope markers that must not appear.
  if grep -nE '_orchestrator_managed|settings-merge|M025' "$path" >/dev/null 2>&1; then
    fail "scope leak in ${rel}: contains one of _orchestrator_managed / settings-merge / M025"
  else
    pass "negative-grep clean: ${rel}"
  fi
  IFS='
'
done
IFS=' '

echo "SUMMARY: m025-p01-runtime-scope-guard.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-runtime-scope-guard.sh"
  exit 0
fi
echo "FAIL: m025-p01-runtime-scope-guard.sh" >&2
exit 1
