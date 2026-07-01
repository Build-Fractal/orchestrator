#!/usr/bin/env sh
# SC-5: self-continue-branch.sh truth table (M045 P02).
# Hermetic — passes --headless explicitly so it does not depend on the host claude CLI.
set -eu
B="scripts/lifecycle/self-continue-branch.sh"
ROT="CONTEXT:ROTATE weight=9 limit=3"
OK="CONTEXT:OK weight=1 limit=3"
assert() { # <expected-substr> <actual>
  case "$2" in
    *"$1"*) : ;;
    *) echo "FAIL: expected '$1' in '$2'"; exit 1 ;;
  esac
}
assert "AUTO:SELF_CONTINUE"                       "$(bash "$B" --monitor-status "$ROT" --armed true  --headless true)"
assert "AUTO:ROTATE_EXIT reason=not-armed"        "$(bash "$B" --monitor-status "$ROT" --armed false --headless true)"
assert "AUTO:ROTATE_EXIT reason=headless-unavailable" "$(bash "$B" --monitor-status "$ROT" --armed true  --headless false)"
assert "AUTO:ROTATE_EXIT reason=not-armed"        "$(bash "$B" --monitor-status "$ROT" --armed false --headless false)"
assert "AUTO:NO_ROTATION"                         "$(bash "$B" --monitor-status "$OK"  --armed true  --headless true)"
echo "PASS: truth table (5 rows)"
