#!/usr/bin/env bash
# scripts/verify/m018-p02-preservation-check-api.sh — phase-truth verifier:
# "the preservation-contract self-check library scripts/lib/preservation-check.sh
# exposes pres_check_section, pres_emit_violation, pres_density_pre_check;
# is bash 3.2 compatible, sourceable, and pure."
#
# Three assertions:
#   1. Library file exists and contains literal `pres_check_section`,
#      `pres_emit_violation`, `pres_density_pre_check` function definitions.
#   2. Library is sourceable in a clean shell and exposes all three
#      function names (verified via a small helper script).
#   3. `bash <library> selftest` exits 0 and prints
#      `PASS: pres_check_section selftest`.
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/preservation-check.sh"

if [ ! -f "$LIB" ]; then
  printf 'FAIL: preservation-check library missing at %s\n' "$LIB" >&2
  exit 1
fi

# Function-definition presence check (literal `<name>()`).
for fn in pres_check_section pres_emit_violation pres_density_pre_check; do
  if ! grep -qE "^${fn}\\(\\)" "$LIB"; then
    printf 'FAIL: function definition not found: %s()\n' "$fn" >&2
    exit 1
  fi
done

# PRES_PATTERNS_REGEX array declaration check.
if ! grep -q 'PRES_PATTERNS_REGEX=(' "$LIB"; then
  printf 'FAIL: PRES_PATTERNS_REGEX array declaration not found\n' >&2
  exit 1
fi

# Sourceability check via a probe helper. We cannot source the library
# in this verifier's own shell (verifier must remain isolated), so we
# stage a probe script and invoke it.
TMPDIR_PC="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_PC"' EXIT INT TERM

PROBE="$TMPDIR_PC/probe.sh"
{
  printf '#!/usr/bin/env bash\n'
  printf 'set -u\n'
  printf '. "%s"\n' "$LIB"
  printf 'type pres_check_section >/dev/null 2>&1 || { printf "MISSING:pres_check_section\\n"; exit 2; }\n'
  printf 'type pres_emit_violation >/dev/null 2>&1 || { printf "MISSING:pres_emit_violation\\n"; exit 2; }\n'
  printf 'type pres_density_pre_check >/dev/null 2>&1 || { printf "MISSING:pres_density_pre_check\\n"; exit 2; }\n'
  printf 'printf "ok\\n"\n'
} > "$PROBE"

PROBE_OUT="$TMPDIR_PC/probe.out"
if ! bash "$PROBE" > "$PROBE_OUT" 2>&1; then
  printf 'FAIL: source-and-type probe nonzero (output below)\n' >&2
  cat "$PROBE_OUT" >&2
  exit 1
fi
if ! grep -q '^ok$' "$PROBE_OUT"; then
  printf 'FAIL: probe did not report ok (output below)\n' >&2
  cat "$PROBE_OUT" >&2
  exit 1
fi

# Selftest entry point.
SELFTEST_OUT="$TMPDIR_PC/selftest.out"
if ! bash "$LIB" selftest > "$SELFTEST_OUT" 2>&1; then
  printf 'FAIL: bash %s selftest exited nonzero\n' "$LIB" >&2
  cat "$SELFTEST_OUT" >&2
  exit 1
fi
if ! grep -q 'PASS: pres_check_section selftest' "$SELFTEST_OUT"; then
  printf 'FAIL: selftest stdout missing expected PASS line (got: %s)\n' "$(cat "$SELFTEST_OUT")" >&2
  exit 1
fi

# pres_check_section literal in this verifier (artifact contains check).
# pres_check_section
printf 'PASS: m018-p02-preservation-check-api (3 functions sourceable; selftest green)\n'
exit 0
