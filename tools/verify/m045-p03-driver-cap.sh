#!/usr/bin/env sh
# m045-p03-driver-cap.sh (SC-3 / FR-5)
# Cap halts the loop; forward-progress distinguishes advance vs thrash.
set -eu
D="scripts/lifecycle/self-continue-drive.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
MDIR="$TMP/M"; mkdir -p "$MDIR"

# Thrash stub: always rotation on the SAME phase P01.
THRASH="$TMP/thrash.sh"
printf '#!/usr/bin/env sh\nprintf "rotation P01" > "%s/.self-continue-outcome"\n' "$MDIR" > "$THRASH"
chmod +x "$THRASH"
RES="$(sh "$D" "$MDIR" --min-interval 0 --max-continuations 3 --auto-cmd "sh $THRASH")"
case "$RES" in
  *"SELF_CONTINUE:CAP_REACHED continuations=3 progress=1"*) : ;;
  *) echo "FAIL: thrash expected CAP_REACHED continuations=3 progress=1, got: $RES"; exit 1 ;;
esac

# Healthy stub: rotation advancing phase each call.
HEALTHY="$TMP/healthy.sh"
printf '#!/usr/bin/env sh\nN=$(cat "%s/n" 2>/dev/null || echo 0); N=$((N+1)); echo "$N" > "%s/n"; printf "rotation P%%s" "$N" > "%s/.self-continue-outcome"\n' "$TMP" "$TMP" "$MDIR" > "$HEALTHY"
chmod +x "$HEALTHY"
RES2="$(sh "$D" "$MDIR" --min-interval 0 --max-continuations 3 --auto-cmd "sh $HEALTHY")"
case "$RES2" in
  *"SELF_CONTINUE:CAP_REACHED continuations=3 progress=3"*) : ;;
  *) echo "FAIL: healthy expected CAP_REACHED continuations=3 progress=3, got: $RES2"; exit 1 ;;
esac
echo "PASS: cap halts; progress=1 on thrash, progress=3 on healthy advance"
