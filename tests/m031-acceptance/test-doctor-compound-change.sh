#!/usr/bin/env bash
# tests/m031-acceptance/test-doctor-compound-change.sh
# M031/P04/T02 — AD-9 doctor compound-change acceptance test.
#
# Exercises both the absent-knob and present-knob branches of the
# m031_compound_change_check function in scripts/diagnostics/run-doctor.sh.
#
# Detection logic under test: an operator's project is "pre-M031" when the
# active .orchestrator/config.yml lacks the literal substring
# quick_knowledge_token_budget. Doctor emits the M031 compound-change
# message in that case and stays silent otherwise.
#
# The ORCH_DOCTOR_CONFIG_PATH env override (T02 test-only seam) lets this
# test point doctor at fixture configs under a hermetic mktemp scratch
# root. Production callers do NOT set the env var.
#
# Emits RESULT: AD-9 pass (exit 0) or RESULT: AD-9 fail (exit 1).

set -u
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOCTOR="$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

absent_cfg="$work/absent.yml"
present_cfg="$work/present.yml"

# Fixture absent-knob config (pre-M031 shape — lacks quick_knowledge_token_budget)
printf 'auto_proceed: false\n' >"$absent_cfg"

# Fixture present-knob config (post-M031 shape)
printf 'auto_proceed: true\nquick_knowledge_token_budget: 800\n' >"$present_cfg"

pass=0
fail=0

# Absent-knob run: doctor MUST emit the compound-change message.
absent_out=$(ORCH_DOCTOR_CONFIG_PATH="$absent_cfg" bash "$DOCTOR" 2>&1 || true)
if printf '%s\n' "$absent_out" | grep -qF -- "M031"; then
  printf 'PASS: absent-knob fixture emits M031 message\n'
  pass=$((pass + 1))
else
  printf 'FAIL: absent-knob fixture missing M031 message\n'
  fail=$((fail + 1))
fi
if printf '%s\n' "$absent_out" | grep -qF -- "auto_proceed"; then
  printf 'PASS: absent-knob fixture names auto_proceed\n'
  pass=$((pass + 1))
else
  printf 'FAIL: absent-knob fixture missing auto_proceed\n'
  fail=$((fail + 1))
fi
if printf '%s\n' "$absent_out" | grep -qF -- "quick_knowledge_token_budget"; then
  printf 'PASS: absent-knob fixture names quick_knowledge_token_budget\n'
  pass=$((pass + 1))
else
  printf 'FAIL: absent-knob fixture missing quick_knowledge_token_budget\n'
  fail=$((fail + 1))
fi

# Present-knob run: doctor MUST NOT emit the compound-change message header.
present_out=$(ORCH_DOCTOR_CONFIG_PATH="$present_cfg" bash "$DOCTOR" 2>&1 || true)
if printf '%s\n' "$present_out" | grep -qF -- "M031 (right-sized entry) is active"; then
  printf 'FAIL: present-knob fixture unexpectedly emits M031 message\n'
  fail=$((fail + 1))
else
  printf 'PASS: present-knob fixture suppresses M031 message\n'
  pass=$((pass + 1))
fi

printf 'AD-9 totals: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'RESULT: AD-9 pass\n'
  exit 0
fi
printf 'RESULT: AD-9 fail\n'
exit 1
