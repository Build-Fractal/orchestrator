#!/usr/bin/env sh
# m046-p02-driver-continue-class.sh (M046 FR-14 driver half)
# Continue-class markers (rotation|planning|phase_complete|validating) re-spawn
# under the driver; error-class markers (error|unexpected_state|planning_failed)
# terminate with no re-spawn; the synthetic child_abort word surfaces the
# distinct SELF_CONTINUE:CHILD_ABORT terminal line.
# Stub-driven (M045 driver-fixture idiom); SC-9's non-stubbed battery is T03.
set -eu
D="scripts/lifecycle/self-continue-drive.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
MDIR="$TMP/M"; mkdir -p "$MDIR"
STUB="$TMP/stub.sh"
# Stub writes whatever outcome is in $TMP/outcome to the marker, exits 0.
printf '#!/usr/bin/env sh\ncat "%s/outcome" > "%s/.self-continue-outcome"\n' "$TMP" "$MDIR" > "$STUB"
chmod +x "$STUB"

fails=0

# Continue-class leg: each word re-spawns once, then halts at the cap.
for OUT in "planning P01" "phase_complete P01" "validating" "rotation P01"; do
  printf '%s' "$OUT" > "$TMP/outcome"
  RES="$(sh "$D" "$MDIR" --min-interval 0 --max-continuations 1 --auto-cmd "sh $STUB")"
  LAST="$(printf '%s\n' "$RES" | tail -n 1)"
  case "$RES" in
    *"SELF_CONTINUE:SCHEDULED continuation=1"*) : ;;
    *)
      echo "FAIL: continue-class '$OUT' — expected SCHEDULED continuation=1, got: $RES"
      fails=$((fails+1)); continue ;;
  esac
  case "$LAST" in
    "SELF_CONTINUE:CAP_REACHED continuations=1"*)
      echo "PASS: continue-class '$OUT' re-spawns then caps" ;;
    *)
      echo "FAIL: continue-class '$OUT' — expected trailing CAP_REACHED continuations=1, got: $LAST"
      fails=$((fails+1)) ;;
  esac
done

# Terminal leg: error-class words stop with no re-spawn.
for OUT in error unexpected_state planning_failed; do
  printf '%s' "$OUT" > "$TMP/outcome"
  RES="$(sh "$D" "$MDIR" --min-interval 0 --max-continuations 1 --auto-cmd "sh $STUB")"
  case "$RES" in
    *"SELF_CONTINUE:SCHEDULED"*)
      echo "FAIL: terminal '$OUT' — re-spawn happened: $RES"
      fails=$((fails+1)); continue ;;
  esac
  case "$RES" in
    *"SELF_CONTINUE:TERMINAL outcome=$OUT"*"continuations=0"*)
      echo "PASS: terminal '$OUT' stops with no re-spawn" ;;
    *)
      echo "FAIL: terminal '$OUT' — expected TERMINAL outcome=$OUT continuations=0, got: $RES"
      fails=$((fails+1)) ;;
  esac
done

# child_abort synthetic leg: distinct terminal line, no re-spawn.
printf '%s' "child_abort" > "$TMP/outcome"
RES="$(sh "$D" "$MDIR" --min-interval 0 --max-continuations 1 --auto-cmd "sh $STUB")"
case "$RES" in
  *"SELF_CONTINUE:SCHEDULED"*)
    echo "FAIL: child_abort — re-spawn happened: $RES"
    fails=$((fails+1)) ;;
  *"SELF_CONTINUE:CHILD_ABORT"*"continuations=0"*)
    echo "PASS: synthetic child_abort surfaces distinct CHILD_ABORT terminal, no re-spawn" ;;
  *)
    echo "FAIL: child_abort — expected SELF_CONTINUE:CHILD_ABORT continuations=0, got: $RES"
    fails=$((fails+1)) ;;
esac

[ "$fails" -eq 0 ] || { echo "FAIL: $fails continue-class case(s) failed"; exit 1; }
echo "PASS: continue-class re-spawns; error-class and child_abort terminate with no re-spawn"
