#!/usr/bin/env bash
# scripts/verify/m027-p02-t01-shape-precheck.sh
# M027/P02/T01-scoped precheck verifier for the efficiency-footer helper.
#
# Asserts the nine T01 must-haves in a single script per AD-19 (single-script
# Check shape). The phase-level canonical verifier
# m027-p02-efficiency-footer-shape.sh ships in T04 and subsumes this
# precheck; T04 may delete this file once the canonical verifier lands
# (mirrors the M027/P01/T03 + T04 pattern).
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes/$()/grep permitted in the
# verifier body since AD-19 binds Check: invocations, not script internals.

set -u

NAME="m027-p02-t01-shape-precheck.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/diagnostics/efficiency-footer.sh"
READ_CONFIG="$PROJECT_ROOT/scripts/state/read-config.sh"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

# 1. Helper file present.
if [ ! -r "$HELPER" ]; then
  fail "scripts/diagnostics/efficiency-footer.sh missing"
fi

# 2. Helper file >= 80 lines.
lines=$(awk 'END { print NR }' "$HELPER")
if [ "$lines" -lt 80 ]; then
  fail "efficiency-footer.sh too short ($lines lines, need >= 80)"
fi

# 3. Helper file is executable.
if [ ! -x "$HELPER" ]; then
  fail "efficiency-footer.sh not executable (chmod +x missing)"
fi

# 4. Footer title literal present.
if ! grep -qF 'Efficiency (Tier 1 rollup)' "$HELPER"; then
  fail "efficiency-footer.sh missing 'Efficiency (Tier 1 rollup)' title literal"
fi

# 5. efficiency_footer_render function defined.
if ! grep -qE '^efficiency_footer_render\(\)' "$HELPER"; then
  fail "efficiency-footer.sh missing 'efficiency_footer_render()' function definition"
fi

# 6. Sourceable + CLI guard via BASH_SOURCE / $0 comparison.
if ! grep -qE 'BASH_SOURCE\[0\].*=.*\$0|BASH_SOURCE\[0\]:-\$0' "$HELPER"; then
  fail "efficiency-footer.sh missing BASH_SOURCE / \$0 sourceable-CLI guard"
fi

# 7. --quiet arg-parse case present.
if ! grep -qE -- '--quiet\)' "$HELPER"; then
  fail "efficiency-footer.sh missing '--quiet)' arg-parse case"
fi

# 8. efficiency_footer config knob referenced.
if ! grep -qE 'efficiency_footer|ORCH_EFFICIENCY_FOOTER' "$HELPER"; then
  fail "efficiency-footer.sh missing 'efficiency_footer' config knob reference"
fi

# 9. Invokes scripts/diagnostics/metrics-rollup.sh.
if ! grep -qF 'scripts/diagnostics/metrics-rollup.sh' "$HELPER"; then
  fail "efficiency-footer.sh missing scripts/diagnostics/metrics-rollup.sh delegation"
fi

# 10. read-config.sh VALID_KEYS contains efficiency_footer + predictive_cost_surface.
if [ ! -r "$READ_CONFIG" ]; then
  fail "scripts/state/read-config.sh missing"
fi
valid_keys_line="$(grep -E '^VALID_KEYS=' "$READ_CONFIG" | head -n 1)"
if [ -z "$valid_keys_line" ]; then
  fail "scripts/state/read-config.sh missing VALID_KEYS= line"
fi
case "$valid_keys_line" in
  *efficiency_footer*) ;;
  *) fail "VALID_KEYS missing 'efficiency_footer'" ;;
esac
case "$valid_keys_line" in
  *predictive_cost_surface*) ;;
  *) fail "VALID_KEYS missing 'predictive_cost_surface'" ;;
esac

# 11. --quiet path emits zero stdout, exit 0.
quiet_out_file="$(mktemp -t m027-p02-t01-precheck.XXXXXX)"
quiet_err_file="$(mktemp -t m027-p02-t01-precheck.XXXXXX)"
bash "$HELPER" --quiet >"$quiet_out_file" 2>"$quiet_err_file"
quiet_rc=$?
if [ "$quiet_rc" -ne 0 ]; then
  rm -f "$quiet_out_file" "$quiet_err_file"
  fail "--quiet exited non-zero (rc=$quiet_rc)"
fi
quiet_bytes=$(wc -c <"$quiet_out_file" | tr -d ' ')
if [ "$quiet_bytes" != "0" ]; then
  rm -f "$quiet_out_file" "$quiet_err_file"
  fail "--quiet emitted non-zero stdout ($quiet_bytes bytes); CON-3/SC-3 byte-identity broken"
fi
rm -f "$quiet_out_file" "$quiet_err_file"

# 12. ORCH_EFFICIENCY_FOOTER=false env var also suppresses stdout.
env_out_file="$(mktemp -t m027-p02-t01-precheck.XXXXXX)"
ORCH_EFFICIENCY_FOOTER=false bash "$HELPER" --milestone M019 >"$env_out_file" 2>/dev/null
env_rc=$?
if [ "$env_rc" -ne 0 ]; then
  rm -f "$env_out_file"
  fail "ORCH_EFFICIENCY_FOOTER=false exited non-zero (rc=$env_rc)"
fi
env_bytes=$(wc -c <"$env_out_file" | tr -d ' ')
if [ "$env_bytes" != "0" ]; then
  rm -f "$env_out_file"
  fail "ORCH_EFFICIENCY_FOOTER=false emitted $env_bytes bytes; expected 0"
fi
rm -f "$env_out_file"

printf 'PASS: %s all 12 assertions hold\n' "$NAME"
exit 0
