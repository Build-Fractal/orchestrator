#!/usr/bin/env bash
# tools/verify/m037-p01-malformed-yaml-fail-closed.sh — M037 P01 T06 Truth #7
# verifier (FR-11).
#
# Stages a fixture target with deliberately-malformed YAML (unclosed quote on
# the first key line), invokes yaml-merge.sh against it, and asserts:
#   1. yaml-merge.sh exits non-zero (FR-11 fail-closed).
#   2. Diagnostic to stderr contains a parseable "YAML_PARSE_ERROR" or
#      "failed YAML parse" marker.
#   3. The target file on disk is byte-identical to the malformed input
#      (no silent overwrite — operator's broken file is preserved as-is so
#      they can fix it).
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

YAML_MERGE="$PROJECT_ROOT/scripts/lib/yaml-merge.sh"
FRAMEWORK="$PROJECT_ROOT/tests/fixtures/m037-config-merge/framework-defaults/orchestrator-config-default.yml"

pass=0
fail=0

ok() {
  printf 'CHECK PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'CHECK FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

if [ ! -f "$YAML_MERGE" ]; then
  bad "scripts/lib/yaml-merge.sh missing at $YAML_MERGE"
  printf 'SUMMARY: m037-p01-malformed-yaml-fail-closed pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
if [ ! -f "$FRAMEWORK" ]; then
  bad "framework-default fixture missing at $FRAMEWORK"
  printf 'SUMMARY: m037-p01-malformed-yaml-fail-closed pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

TMPDIR_LOCAL="$(mktemp -d -t m037-p01-malformed.XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

# Stage a malformed target: unclosed double-quoted string on line 1.
MALFORMED="$TMPDIR_LOCAL/malformed-target.yml"
printf 'default_tier: "unclosed-string\nverification_commands: []\n' > "$MALFORMED"

# Capture pre-invocation hash.
if command -v md5 >/dev/null 2>&1; then
  hash_before="$(md5 -q "$MALFORMED")"
elif command -v md5sum >/dev/null 2>&1; then
  hash_before="$(md5sum "$MALFORMED" | awk '{print $1}')"
else
  hash_before="$(wc -c < "$MALFORMED")"
fi

# Invoke yaml-merge against the malformed target.
LOG="$TMPDIR_LOCAL/merge.log"
set +e
bash "$YAML_MERGE" merge --target "$MALFORMED" --framework-default "$FRAMEWORK" --managed-namespaces "default_tier,verification_commands,wiki" >"$LOG" 2>&1
rc=$?
set -e

# Capture post-invocation hash.
if command -v md5 >/dev/null 2>&1; then
  hash_after="$(md5 -q "$MALFORMED")"
elif command -v md5sum >/dev/null 2>&1; then
  hash_after="$(md5sum "$MALFORMED" | awk '{print $1}')"
else
  hash_after="$(wc -c < "$MALFORMED")"
fi

# 1. Non-zero exit.
if [ "$rc" -ne 0 ]; then
  ok "yaml-merge.sh exited non-zero ($rc) on malformed target (fail-closed)"
else
  bad "yaml-merge.sh exited 0 on malformed target (FR-11 violation)"
fi

# 2. Diagnostic emitted.
if grep -qE 'YAML_PARSE_ERROR|failed YAML parse' "$LOG"; then
  ok "stderr/log contains parseable diagnostic (YAML_PARSE_ERROR or failed YAML parse)"
else
  bad "stderr/log missing parseable diagnostic"
  cat "$LOG" >&2 || true
fi

# 3. Target file on disk byte-identical to malformed input.
if [ "$hash_before" = "$hash_after" ]; then
  ok "target file byte-identical to malformed input (no silent overwrite)"
else
  bad "target file modified despite fail-closed exit (before=$hash_before after=$hash_after)"
fi

printf 'SUMMARY: m037-p01-malformed-yaml-fail-closed pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: m037-p01-malformed-yaml-fail-closed\n'
  exit 0
fi
exit 1
