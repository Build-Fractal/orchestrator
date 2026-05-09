#!/usr/bin/env bash
# tools/verify/m035-p06-config-schema-shape.sh
#
# M035 P06 T01 — Asserts the `update_source` config schema is registered:
#   1. scripts/state/read-config.sh is readable AND contains update_source
#   2. VALID_KEYS line includes update_source as a whitespace-separated token
#   3. .orchestrator/DECISIONS.md contains the literal anchor `D012`
#   4. DECISIONS.md D012 row references update_source within proximity
#   5. read-config.sh returns 'npm' for fixture with `update_source: npm`
#   6. read-config.sh returns invalid_value verbatim (no client-side enum check)
#   7. read-config.sh returns null/empty for fixture with update_source absent
#
# AD-19 single-script-file shape; runs against staged fixtures under
# /tmp/m035-p06-t01-config-fixture-$$/. Bash 3.2 + POSIX-sh-safe.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
READ_CONFIG="$REPO/scripts/state/read-config.sh"
DECISIONS="$REPO/.orchestrator/DECISIONS.md"

# Source error lib for parity with sibling verifiers.
# shellcheck disable=SC1091
. "$REPO/scripts/lib/errors.sh"

FIXTURE_ROOT="/tmp/m035-p06-t01-config-fixture-$$"
mkdir -p "$FIXTURE_ROOT"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

pass=0
fail=0

# --- Assertion 1: read-config.sh is readable AND contains update_source ---
reg_ok=0
if [ -r "$READ_CONFIG" ]; then
  if grep -qF 'update_source' "$READ_CONFIG"; then
    reg_ok=1
  fi
fi
if [ "$reg_ok" -eq 1 ]; then
  echo "PASS: read-config.sh registers update_source in VALID_KEYS"
  pass=$((pass + 1))
else
  echo "FAIL: read-config.sh missing or does not register update_source"
  fail=$((fail + 1))
fi

# --- Assertion 3: VALID_KEYS line includes update_source as whitespace-separated token ---
valid_keys_line=""
valid_keys_line="$(grep -E '^VALID_KEYS=' "$READ_CONFIG" | head -1)"
keys_ok=0
if [ -n "$valid_keys_line" ]; then
  if echo "$valid_keys_line" | grep -qE '(^|[[:space:]])update_source([[:space:]]|"$)'; then
    keys_ok=1
  fi
fi
if [ "$keys_ok" -eq 1 ]; then
  echo "PASS: VALID_KEYS line contains update_source as whitespace-separated token"
  pass=$((pass + 1))
else
  echo "FAIL: VALID_KEYS line does not contain update_source as bare token"
  echo "  line: $valid_keys_line"
  fail=$((fail + 1))
fi

# --- Assertion 4: DECISIONS.md contains the D012 decision-row anchor ---
# Match the heading-shape anchor `### D012 ` (table-row shape `| D012 |` also
# accepted). Plain `D012` mentions in body text don't count — older D-rows may
# reference D012 retrospectively in narrative.
d012_anchor_line=0
d012_anchor_line="$(grep -nE '^(### D012( |$)|\| D012 \|)' "$DECISIONS" | head -1 | cut -d: -f1)"
if [ -n "$d012_anchor_line" ] && [ "$d012_anchor_line" -gt 0 ]; then
  echo "PASS: DECISIONS.md contains D012 anchor"
  pass=$((pass + 1))
else
  echo "FAIL: DECISIONS.md missing D012 decision-row anchor"
  fail=$((fail + 1))
fi

# --- Assertion 5: D012 row references update_source within 30 lines ---
prox_ok=0
if [ -n "$d012_anchor_line" ] && [ "$d012_anchor_line" -gt 0 ]; then
  end_line=$((d012_anchor_line + 30))
  block=""
  block="$(sed -n "${d012_anchor_line},${end_line}p" "$DECISIONS")"
  if echo "$block" | grep -qF 'update_source'; then
    prox_ok=1
  fi
fi
if [ "$prox_ok" -eq 1 ]; then
  echo "PASS: DECISIONS.md D012 row references update_source"
  pass=$((pass + 1))
else
  echo "FAIL: DECISIONS.md D012 row does not reference update_source within 30 lines"
  fail=$((fail + 1))
fi

# --- Assertion 6: read-config.sh returns 'npm' for fixture with update_source: npm ---
FX_NPM="$FIXTURE_ROOT/npm-fixture.yml"
printf 'update_source: npm\n' > "$FX_NPM"
npm_out=""
npm_out="$(bash "$READ_CONFIG" --project "$FX_NPM" update_source 2>/dev/null || true)"
if [ "$npm_out" = "npm" ]; then
  echo "PASS: read-config.sh returns 'npm' for fixture with update_source: npm"
  pass=$((pass + 1))
else
  echo "FAIL: expected 'npm', got '$npm_out'"
  fail=$((fail + 1))
fi

# --- Assertion 7: read-config.sh returns invalid_value verbatim ---
FX_BAD="$FIXTURE_ROOT/bad-fixture.yml"
printf 'update_source: invalid_value\n' > "$FX_BAD"
bad_out=""
bad_out="$(bash "$READ_CONFIG" --project "$FX_BAD" update_source 2>/dev/null || true)"
if [ "$bad_out" = "invalid_value" ]; then
  echo "PASS: read-config.sh returns invalid_value verbatim (no client-side enum check)"
  pass=$((pass + 1))
else
  echo "FAIL: expected 'invalid_value', got '$bad_out'"
  fail=$((fail + 1))
fi

# --- Assertion 8: read-config.sh returns null/empty for fixture with update_source absent ---
FX_ABSENT="$FIXTURE_ROOT/absent-fixture.yml"
printf 'default_tier: standard\n' > "$FX_ABSENT"
absent_out=""
absent_out="$(bash "$READ_CONFIG" --project "$FX_ABSENT" update_source 2>/dev/null || true)"
absent_ok=0
if [ -z "$absent_out" ] || [ "$absent_out" = "null" ]; then
  absent_ok=1
fi
if [ "$absent_ok" -eq 1 ]; then
  echo "PASS: read-config.sh returns null/empty for fixture with update_source absent"
  pass=$((pass + 1))
else
  echo "FAIL: expected empty or 'null', got '$absent_out'"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
