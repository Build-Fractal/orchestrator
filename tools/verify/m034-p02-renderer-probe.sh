#!/usr/bin/env bash
# tools/verify/m034-p02-renderer-probe.sh — M034 P02 T01 verifier.
#
# Exercises the --probe-renderer seam on dispatch-interface.sh plus the
# CON-4 SSOT enum/validator extension and the REVIEW/SIGNOFF templates.
#
# Asserts:
#   1. dispatch-interface.sh --probe-renderer with ORCH_HEADLESS=1 emits
#      renderer=headless (highest precedence, unconditional).
#   2. dispatch-interface.sh --probe-renderer with SPECKIT_AGENT_TOOL=1 and
#      ORCH_HEADLESS unset emits renderer=interactive-cc (local-agent probe).
#   3. decisions-constants.sh defines DECISIONS_ACTION_VALUES,
#      DECISIONS_POLICY_VALUES, DECISIONS_POLICY_DEFAULT=defer, and the two
#      validators decisions_is_valid_action / decisions_is_valid_policy; the
#      policy enum contains `refuse-entry` and NOT `block` (CON-8).
#   4. templates/review.md contains "action"; templates/signoff.md contains
#      "approved_by".
#
# Prints `PASS: m034-p02 renderer-probe` + exit 0 on success, else
# `FAIL: m034-p02 renderer-probe — <reason>` + exit 1.
#
# Bash 3.2 / POSIX-sh. set -u. Scratch under mktemp.

set -u

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../.." && pwd)"

DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"
CONSTANTS="$REPO_ROOT/scripts/knowledge/lib/decisions-constants.sh"
REVIEW_TPL="$REPO_ROOT/templates/review.md"
SIGNOFF_TPL="$REPO_ROOT/templates/signoff.md"

fail() {
  echo "FAIL: m034-p02 renderer-probe — $1"
  exit 1
}

# --- preflight: required files exist -----------------------------------------
[ -f "$DISPATCH" ] || fail "dispatch-interface.sh missing at $DISPATCH"
[ -f "$CONSTANTS" ] || fail "decisions-constants.sh missing at $CONSTANTS"
[ -f "$REVIEW_TPL" ] || fail "templates/review.md missing"
[ -f "$SIGNOFF_TPL" ] || fail "templates/signoff.md missing"

SCRATCH="$(mktemp -d 2>/dev/null || mktemp -d -t m034p02)"
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || fail "mktemp scratch dir failed"
trap 'rm -rf "$SCRATCH"' EXIT

# --- 1. ORCH_HEADLESS=1 forces renderer=headless -----------------------------
out_headless="$(ORCH_HEADLESS=1 bash "$DISPATCH" --probe-renderer 2>/dev/null)"
if [ "$out_headless" != "renderer=headless" ]; then
  fail "ORCH_HEADLESS=1 expected renderer=headless, got '$out_headless'"
fi

# --- 2. SPECKIT_AGENT_TOOL=1 (ORCH_HEADLESS unset) -> interactive-cc ----------
unset ORCH_HEADLESS
out_cc="$(SPECKIT_AGENT_TOOL=1 bash "$DISPATCH" --probe-renderer 2>/dev/null)"
if [ "$out_cc" != "renderer=interactive-cc" ]; then
  fail "SPECKIT_AGENT_TOOL=1 expected renderer=interactive-cc, got '$out_cc'"
fi

# --- 3. SSOT enums + validators ----------------------------------------------
# Source the SSOT in a clean check; it must have no top-level execution.
# shellcheck disable=SC1090
. "$CONSTANTS" || fail "could not source decisions-constants.sh"

[ -n "${DECISIONS_ACTION_VALUES:-}" ] || fail "DECISIONS_ACTION_VALUES undefined"
[ -n "${DECISIONS_POLICY_VALUES:-}" ] || fail "DECISIONS_POLICY_VALUES undefined"

if [ "${DECISIONS_POLICY_DEFAULT:-}" != "defer" ]; then
  fail "DECISIONS_POLICY_DEFAULT expected 'defer', got '${DECISIONS_POLICY_DEFAULT:-}'"
fi

# policy enum must contain refuse-entry and NOT block (CON-8).
case " $DECISIONS_POLICY_VALUES " in
  *" refuse-entry "*) : ;;
  *) fail "policy enum missing 'refuse-entry' (got '$DECISIONS_POLICY_VALUES')" ;;
esac
case " $DECISIONS_POLICY_VALUES " in
  *" block "*) fail "policy enum must NOT contain 'block' (CON-8) — got '$DECISIONS_POLICY_VALUES'" ;;
  *) : ;;
esac

# validators present and functioning.
type decisions_is_valid_action >/dev/null 2>&1 || fail "decisions_is_valid_action validator missing"
type decisions_is_valid_policy >/dev/null 2>&1 || fail "decisions_is_valid_policy validator missing"

[ "$(decisions_is_valid_action accept)" = "ok" ] || fail "decisions_is_valid_action accept != ok"
[ "$(decisions_is_valid_action bogus)" = "" ] || fail "decisions_is_valid_action bogus should be empty"
[ "$(decisions_is_valid_policy refuse-entry)" = "ok" ] || fail "decisions_is_valid_policy refuse-entry != ok"
[ "$(decisions_is_valid_policy block)" = "" ] || fail "decisions_is_valid_policy block should be empty (CON-8)"

# --- 4. template required tokens ---------------------------------------------
grep -q "action" "$REVIEW_TPL" || fail "templates/review.md missing 'action' token"
grep -q "approved_by" "$SIGNOFF_TPL" || fail "templates/signoff.md missing 'approved_by' token"

echo "PASS: m034-p02 renderer-probe"
exit 0
