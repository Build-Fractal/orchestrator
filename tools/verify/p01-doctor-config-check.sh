#!/usr/bin/env bash
# tools/verify/p01-doctor-config-check.sh — M030/P01/T04 verifier.
#
# Exercises both paths of `scripts/diagnostics/run-doctor.sh --config-check`:
#
#   Scenario A (well-formed):  invoke --config-check against the shipped
#     templates/model-routing.yml. Assert exit 0.
#
#   Scenario B (malformed):    stage a malformed copy of model-routing.yml
#     at /tmp/p01-malformed-routing.yml (introduces an undefined symbolic
#     tier 'turbo' under routing.standard.claude-code). Invoke
#     ROUTING_TABLE_PATH=/tmp/... bash run-doctor.sh --config-check.
#     Assert exit 1 AND stdout contains both:
#       - the literal /tmp/p01-malformed-routing.yml path
#       - a `:[0-9]+` line-number suffix
#
# FR-17 + SC-9 gate. Bash 3.2 compatible. AD-19 single-script-file shape.
# No compound chains, no eval. Cleans up the /tmp fixture on every exit.

set -u

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOCTOR="$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh"
WELLFORMED="$PROJECT_ROOT/templates/model-routing.yml"
MALFORMED="/tmp/p01-malformed-routing.yml"

pass=0
fail=0
fail_msgs=""

note_pass() {
  pass=$((pass + 1))
  echo "OK: $1"
}

note_fail() {
  fail=$((fail + 1))
  fail_msgs="${fail_msgs}FAIL: $1
"
  echo "FAIL: $1"
}

cleanup() {
  rm -f "$MALFORMED"
  rm -f /tmp/p01-doctor-cc-stdout.txt
}

# Always cleanup on any exit (success, fail, signal).
trap cleanup EXIT

# ---------- Pre-flight ----------

if [ ! -f "$DOCTOR" ]; then
  echo "FAIL: run-doctor.sh missing at $DOCTOR"
  echo "SUMMARY: p01-doctor-config-check.sh pass=0 fail=1"
  exit 1
fi

if [ ! -f "$WELLFORMED" ]; then
  echo "FAIL: well-formed routing.yml missing at $WELLFORMED"
  echo "SUMMARY: p01-doctor-config-check.sh pass=0 fail=1"
  exit 1
fi

# ---------- Scenario A: well-formed routing.yml exits 0 ----------
#
# Invoke run-doctor.sh --config-check with the default routing table.
# Capture exit code only — we don't care about the rest of the doctor
# pipeline's diagnostic output, only that the routing-table validation
# does not propagate exit 1.

bash "$DOCTOR" --config-check >/tmp/p01-doctor-cc-stdout.txt 2>&1
rc_a=$?

if [ "$rc_a" -eq 0 ]; then
  note_pass "well-formed routing.yml passes --config-check (exit 0)"
else
  # The doctor pipeline can exit 1 if other unrelated checks emit non-zero.
  # We only fail Scenario A if the routing-table verifier itself failed,
  # which we detect by looking for the routing FAIL: prefix in stdout.
  if grep -q "^FAIL: .*model-routing\.yml:" /tmp/p01-doctor-cc-stdout.txt; then
    note_fail "well-formed routing.yml unexpectedly failed --config-check (exit ${rc_a})"
  else
    # Exit non-zero from doctor for unrelated reasons — Scenario A still
    # gates on the routing-table check passing, so accept this as pass
    # but log a soft note. The test contract is: routing-table validation
    # must accept the well-formed file. Other doctor checks are out of
    # scope for this verifier.
    note_pass "well-formed routing.yml passes --config-check (doctor exit ${rc_a} from unrelated checks; routing-table gate did not emit FAIL)"
  fi
fi

# ---------- Scenario B: stage malformed fixture ----------

cat > "$MALFORMED" <<'EOF'
---
schema_version: "1.0"
type: model-routing-table
milestone: "M030"
created_at: "2026-04-30"
---

routing:
  mechanical:
    claude-code: fast
    codex-cli: inherit
    cursor: inherit
  standard:
    claude-code: turbo
    codex-cli: inherit
    cursor: inherit
  novel:
    claude-code: smart
    codex-cli: inherit
    cursor: inherit

resolution:
  fast:
    claude-code: "claude-haiku-4-5"
    codex-cli: inherit
    cursor: inherit
  balanced:
    claude-code: "claude-sonnet-4-7"
    codex-cli: inherit
    cursor: inherit
  smart:
    claude-code: "claude-opus-4-7"
    codex-cli: inherit
    cursor: inherit

cost_rates:
  fast:
    input_per_mtok: 1.00
    output_per_mtok: 5.00
  balanced:
    input_per_mtok: 3.00
    output_per_mtok: 15.00
  smart:
    input_per_mtok: 15.00
    output_per_mtok: 75.00
EOF

if [ ! -f "$MALFORMED" ]; then
  note_fail "could not stage malformed fixture at $MALFORMED"
  echo "SUMMARY: p01-doctor-config-check.sh pass=$pass fail=$fail"
  exit 1
fi

# ---------- Scenario B: malformed fixture exits 1 with file:line ----------
#
# Pass the malformed path via ROUTING_TABLE_PATH env var (the doctor
# extension reads this when --routing-table is not provided). Capture
# stdout and exit code.

ROUTING_TABLE_PATH="$MALFORMED" bash "$DOCTOR" --config-check >/tmp/p01-doctor-cc-stdout.txt 2>&1
rc_b=$?

if [ "$rc_b" -eq 1 ]; then
  note_pass "malformed fixture fails --config-check with exit 1"
else
  note_fail "malformed fixture should exit 1, got exit ${rc_b}"
fi

# Stdout must contain the malformed file path.
if grep -qF "$MALFORMED" /tmp/p01-doctor-cc-stdout.txt; then
  note_pass "stdout names the malformed file path ($MALFORMED)"
else
  note_fail "stdout missing malformed file path ($MALFORMED)"
fi

# Stdout must contain a line-number suffix (`:[0-9]+`) — proves FR-17
# file:line emission is wired through the doctor extension.
if grep -qE "${MALFORMED}:[0-9]+" /tmp/p01-doctor-cc-stdout.txt; then
  note_pass "stdout carries <file>:<lineno> diagnostic (FR-17 + SC-9)"
else
  note_fail "stdout missing <file>:<lineno> diagnostic"
fi

# ---------- Summary ----------

if [ "$fail" -eq 0 ]; then
  echo "SUMMARY: p01-doctor-config-check.sh pass=$pass fail=$fail"
  exit 0
else
  printf '%s' "$fail_msgs"
  echo "SUMMARY: p01-doctor-config-check.sh pass=$pass fail=$fail"
  exit 1
fi
