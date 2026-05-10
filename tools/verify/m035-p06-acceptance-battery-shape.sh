#!/usr/bin/env bash
# tools/verify/m035-p06-acceptance-battery-shape.sh
#
# M035 P06 T05 — Asserts the M035 milestone-grain acceptance battery's
# structural shape (SC-15 self-reference) plus the fixture quartet
# that backs the SC-13 dispatch arm.
#
# 16 assertions:
#   1.  battery script exists and is executable
#   2.  battery contains the BATTERY: rollup line
#   3.  battery references m035-p00-phase-suite.sh
#   4.  battery references m035-p015-phase-suite.sh OR m035-p01.5-phase-suite.sh
#   5.  battery references m035-p02-phase-suite.sh
#   6.  battery references m035-p03-phase-suite.sh
#   7.  battery references m035-p04-phase-suite.sh
#   8.  battery references m035-p05-phase-suite.sh
#   9.  battery references m035-p06-phase-suite.sh
#  10.  battery references m035-p06-acceptance-battery-shape.sh (SC-15 self-reference)
#  11.  battery shebang is #!/usr/bin/env bash
#  12.  battery contains set -u
#  13.  fixture m035-p06-config-update-source-git carries `update_source: git`
#  14.  fixture m035-p06-config-update-source-npm carries `update_source: npm`
#  15.  fixture m035-p06-config-update-source-homebrew carries `update_source: homebrew`
#  16.  fixture m035-p06-config-update-source-none carries `update_source: none`
#
# AD-19 single-script-file shape; Bash 3.2 + POSIX-sh-safe.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BATTERY="$REPO/tests/m035-acceptance/run-acceptance-battery.sh"
FIXTURES="$REPO/tests/m035-acceptance/fixtures"

# shellcheck disable=SC1091
. "$REPO/scripts/lib/errors.sh"

pass=0
fail=0

# --- Assertion 1: battery exists and executable ---
if [ -x "$BATTERY" ]; then
  echo "PASS: run-acceptance-battery.sh exists and is executable"
  pass=$((pass + 1))
else
  echo "FAIL: run-acceptance-battery.sh missing or not executable at $BATTERY"
  fail=$((fail + 1))
fi

# --- Assertion 2: BATTERY: rollup line literal ---
if grep -qF 'BATTERY:' "$BATTERY"; then
  echo "PASS: battery contains BATTERY: rollup line"
  pass=$((pass + 1))
else
  echo "FAIL: battery missing BATTERY: rollup line"
  fail=$((fail + 1))
fi

# --- Assertion 3: P00 phase-suite reference ---
if grep -qF 'm035-p00-phase-suite.sh' "$BATTERY"; then
  echo "PASS: battery references m035-p00-phase-suite.sh"
  pass=$((pass + 1))
else
  echo "FAIL: battery missing m035-p00-phase-suite.sh reference"
  fail=$((fail + 1))
fi

# --- Assertion 4: P01.5 phase-suite reference (either filename form) ---
if grep -qF 'm035-p015-phase-suite.sh' "$BATTERY"; then
  echo "PASS: battery references m035-p015-phase-suite.sh OR m035-p01.5-phase-suite.sh"
  pass=$((pass + 1))
elif grep -qF 'm035-p01.5-phase-suite.sh' "$BATTERY"; then
  echo "PASS: battery references m035-p015-phase-suite.sh OR m035-p01.5-phase-suite.sh"
  pass=$((pass + 1))
else
  echo "FAIL: battery missing P01.5 phase-suite reference (neither m035-p015-phase-suite.sh nor m035-p01.5-phase-suite.sh)"
  fail=$((fail + 1))
fi

# --- Assertion 5: P02 phase-suite reference ---
if grep -qF 'm035-p02-phase-suite.sh' "$BATTERY"; then
  echo "PASS: battery references m035-p02-phase-suite.sh"
  pass=$((pass + 1))
else
  echo "FAIL: battery missing m035-p02-phase-suite.sh reference"
  fail=$((fail + 1))
fi

# --- Assertion 6: P03 phase-suite reference ---
if grep -qF 'm035-p03-phase-suite.sh' "$BATTERY"; then
  echo "PASS: battery references m035-p03-phase-suite.sh"
  pass=$((pass + 1))
else
  echo "FAIL: battery missing m035-p03-phase-suite.sh reference"
  fail=$((fail + 1))
fi

# --- Assertion 7: P04 phase-suite reference ---
if grep -qF 'm035-p04-phase-suite.sh' "$BATTERY"; then
  echo "PASS: battery references m035-p04-phase-suite.sh"
  pass=$((pass + 1))
else
  echo "FAIL: battery missing m035-p04-phase-suite.sh reference"
  fail=$((fail + 1))
fi

# --- Assertion 8: P05 phase-suite reference ---
if grep -qF 'm035-p05-phase-suite.sh' "$BATTERY"; then
  echo "PASS: battery references m035-p05-phase-suite.sh"
  pass=$((pass + 1))
else
  echo "FAIL: battery missing m035-p05-phase-suite.sh reference"
  fail=$((fail + 1))
fi

# --- Assertion 9: P06 phase-suite reference ---
if grep -qF 'm035-p06-phase-suite.sh' "$BATTERY"; then
  echo "PASS: battery references m035-p06-phase-suite.sh"
  pass=$((pass + 1))
else
  echo "FAIL: battery missing m035-p06-phase-suite.sh reference"
  fail=$((fail + 1))
fi

# --- Assertion 10: self-reference (SC-15) ---
if grep -qF 'm035-p06-acceptance-battery-shape.sh' "$BATTERY"; then
  echo "PASS: battery references m035-p06-acceptance-battery-shape.sh (SC-15 self-reference)"
  pass=$((pass + 1))
else
  echo "FAIL: battery missing m035-p06-acceptance-battery-shape.sh self-reference (SC-15)"
  fail=$((fail + 1))
fi

# --- Assertion 11: shebang ---
first_line="$(head -1 "$BATTERY")"
if [ "$first_line" = "#!/usr/bin/env bash" ]; then
  echo "PASS: battery shebang is #!/usr/bin/env bash"
  pass=$((pass + 1))
else
  echo "FAIL: battery shebang is not #!/usr/bin/env bash (got: $first_line)"
  fail=$((fail + 1))
fi

# --- Assertion 12: set -u ---
if grep -qF 'set -u' "$BATTERY"; then
  echo "PASS: battery contains set -u"
  pass=$((pass + 1))
else
  echo "FAIL: battery missing set -u"
  fail=$((fail + 1))
fi

# --- Assertion 13..16: fixture config.yml files carry update_source: <value> ---
for src in git npm homebrew none; do
  fixture="$FIXTURES/m035-p06-config-update-source-$src/.orchestrator/config.yml"
  if [ -r "$fixture" ] && grep -qF "update_source: $src" "$fixture"; then
    echo "PASS: fixture m035-p06-config-update-source-$src/.orchestrator/config.yml exists with update_source: $src"
    pass=$((pass + 1))
  else
    echo "FAIL: fixture m035-p06-config-update-source-$src/.orchestrator/config.yml missing or lacks update_source: $src"
    fail=$((fail + 1))
  fi
done

echo "BATTERY: pass=$pass fail=$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
