#!/usr/bin/env sh
# m046-p02-injection-reject.sh (SC-10 / FR-15)
# A metacharacter-bearing milestone-dir name is rejected by the driver BEFORE
# reaching any command line, and no injected side effect executes.
set -eu
D="scripts/lifecycle/self-continue-drive.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SENTINEL="$TMP/pwned"

fails=0
check_reject() {
  # $1 = case label, $2 = attack milestone-dir name (passed as ONE quoted arg)
  RC=0
  RES="$(sh "$D" "$2" --min-interval 0 2>/dev/null)" || RC=$?
  if [ "$RC" -eq 0 ]; then
    echo "FAIL: $1 — driver exited 0 (expected non-zero reject)"
    fails=$((fails+1)); return 0
  fi
  case "$RES" in
    *"SELF_CONTINUE:REJECT reason=milestone-dir-charset"*) : ;;
    *)
      echo "FAIL: $1 — missing REJECT line, got: $RES"
      fails=$((fails+1)); return 0 ;;
  esac
  if [ -e "$SENTINEL" ]; then
    echo "FAIL: $1 — injected side effect executed (sentinel exists)"
    rm -f "$SENTINEL"
    fails=$((fails+1)); return 0
  fi
  echo "PASS: $1 rejected, no side effect"
  return 0
}

check_reject "semicolon-injection"  "x; touch $SENTINEL"
check_reject "command-substitution" "x\$(touch $SENTINEL)"
check_reject "backtick-injection"   "x\`touch $SENTINEL\`"
check_reject "embedded-space"       "x y"
check_reject "leading-dash"         "-x"
check_reject "dot-dot-traversal"    "a/../b"

# Positive control: a clean scratch dir name is NOT rejected — drive it with a
# complete-writing stub so it terminates immediately.
MDIR="$TMP/M046ok"; mkdir -p "$MDIR"
STUB="$TMP/stub.sh"
printf '#!/usr/bin/env sh\nprintf "complete" > "%s/.self-continue-outcome"\n' "$MDIR" > "$STUB"
chmod +x "$STUB"
RC=0
RES="$(sh "$D" "$MDIR" --min-interval 0 --auto-cmd "sh $STUB")" || RC=$?
case "$RES" in
  *"SELF_CONTINUE:REJECT"*)
    echo "FAIL: positive control — clean dir name was rejected: $RES"
    fails=$((fails+1)) ;;
  *"SELF_CONTINUE:TERMINAL outcome=complete"*)
    echo "PASS: positive control accepted (terminal on complete)" ;;
  *)
    echo "FAIL: positive control — unexpected output (rc=$RC): $RES"
    fails=$((fails+1)) ;;
esac

[ "$fails" -eq 0 ] || { echo "FAIL: $fails injection-reject case(s) failed"; exit 1; }
echo "PASS: all injection attempts rejected before any command line; positive control accepted"
