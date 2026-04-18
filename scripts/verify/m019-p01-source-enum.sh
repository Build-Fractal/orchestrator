#!/usr/bin/env bash
# scripts/verify/m019-p01-source-enum.sh — M019/P01 source-enum gate.
#
# Feeds synthetic single-record JSONL inputs to m019-schema.sh:
#   - source=estimate    -> must PASS
#   - source=runtime     -> must PASS
#   - source=aggregate   -> must PASS (T04 extension)
#   - source=fabricated  -> must FAIL (via bad-records fixture)
#
# Emits a single PASS: or FAIL: summary line on stdout. Exit 0 on all-pass,
# 1 otherwise.
#
# MEM004 carve-out: verification-script-internal; pipes/$()/awk permitted.
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA="$REPO_ROOT/scripts/verify/m019-schema.sh"
FIXTURE_BAD="$REPO_ROOT/tests/fixtures/m019-p01/bad-records/bad-source-enum.jsonl"

if [ ! -x "$SCHEMA" ] && [ ! -r "$SCHEMA" ]; then
  printf 'FAIL: m019-p01-source-enum.sh schema-validator-missing at=%s\n' "$SCHEMA"
  exit 1
fi

TMPDIR_G="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_G"' EXIT INT TERM

gen_record() {
  # $1 = source value
  local src="$1"
  printf '{"record_type":"dispatch_usage","unitId":"M999/P01/T01","milestone":"M999","phase":"P01","task":"T01","backend":"stub","input_tokens_estimate":100,"output_tokens_estimate":0,"estimated_cost_usd":0.001,"pricing_version":"2026-04-17","model":"claude-opus-4-7","source":"%s","timestamp":"2026-04-18T00:00:00Z"}\n' "$src"
}

fail_count=0
check_accept() {
  local src="$1" f
  f="$TMPDIR_G/accept-$src.jsonl"
  gen_record "$src" > "$f"
  if bash "$SCHEMA" "$f" >/dev/null 2>&1; then
    return 0
  fi
  printf 'FAIL: m019-p01-source-enum.sh expected-accept source=%s\n' "$src"
  fail_count=$(( fail_count + 1 ))
  return 1
}

check_reject() {
  local f="$1" label="$2"
  if bash "$SCHEMA" "$f" >/dev/null 2>&1; then
    printf 'FAIL: m019-p01-source-enum.sh expected-reject label=%s\n' "$label"
    fail_count=$(( fail_count + 1 ))
    return 1
  fi
  return 0
}

check_accept "estimate" || true
check_accept "runtime" || true
check_accept "aggregate" || true

if [ ! -r "$FIXTURE_BAD" ]; then
  printf 'FAIL: m019-p01-source-enum.sh bad-fixture-missing at=%s\n' "$FIXTURE_BAD"
  fail_count=$(( fail_count + 1 ))
else
  check_reject "$FIXTURE_BAD" "bad-source-enum-fixture" || true
fi

if [ "$fail_count" -gt 0 ]; then
  printf 'FAIL: m019-p01-source-enum.sh %d gate(s) failed\n' "$fail_count"
  exit 1
fi

printf 'PASS: m019-p01-source-enum.sh 4 source-enum gates green\n'
exit 0
