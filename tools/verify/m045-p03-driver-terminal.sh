#!/usr/bin/env sh
# m045-p03-driver-terminal.sh (SC-2 / FR-4)
# The driver STOPS (no re-spawn) on every terminal outcome.
set -eu
D="scripts/lifecycle/self-continue-drive.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
MDIR="$TMP/M"; mkdir -p "$MDIR"
STUB="$TMP/stub.sh"
# Stub writes whatever outcome is in $TMP/outcome to the marker.
printf '#!/usr/bin/env sh\ncat "%s/outcome" > "%s/.self-continue-outcome"\n' "$TMP" "$MDIR" > "$STUB"
chmod +x "$STUB"
for OUT in complete blocked budget stuck pause; do
  echo "$OUT" > "$TMP/outcome"
  RES="$(sh "$D" "$MDIR" --min-interval 0 --auto-cmd "sh $STUB")"
  case "$RES" in
    *"SELF_CONTINUE:TERMINAL"*"continuations=0"*) : ;;
    *) echo "FAIL: outcome=$OUT expected TERMINAL w/ 0 continuations, got: $RES"; exit 1 ;;
  esac
done
echo "PASS: all 5 terminal outcomes stop with no re-spawn"
