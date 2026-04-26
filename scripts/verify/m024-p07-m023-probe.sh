#!/usr/bin/env bash
# scripts/verify/m024-p07-m023-probe.sh
# Exercises the M023_SHIPPED_PROBE_OVERRIDE matrix.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/intake/design-gate-degradation.sh"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
emit_out=$(bash "$EMIT" --input "fix typo" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

# stub override -> m023_shipped=false reason=env-override
out=$(M023_SHIPPED_PROBE_OVERRIDE=stub bash "$SCRIPT" --proposal "$proposal" --probe-only)
echo "$out" | grep -qx "m023_shipped=false" || { echo "FAIL: stub override (got: $out)"; exit 1; }
echo "$out" | grep -qx "reason=env-override" || { echo "FAIL: stub reason (got: $out)"; exit 1; }

# live override -> m023_shipped=true reason=env-override
out=$(M023_SHIPPED_PROBE_OVERRIDE=live bash "$SCRIPT" --proposal "$proposal" --probe-only)
echo "$out" | grep -qx "m023_shipped=true" || { echo "FAIL: live override (got: $out)"; exit 1; }
echo "$out" | grep -qx "reason=env-override" || { echo "FAIL: live reason (got: $out)"; exit 1; }

# Unset override -> disk probe. On this checkout (no commands/design.md) -> false+disk-probe-failed.
unset M023_SHIPPED_PROBE_OVERRIDE
out=$(bash "$SCRIPT" --proposal "$proposal" --probe-only)
echo "$out" | grep -qx "m023_shipped=false" || { echo "FAIL: disk probe (got: $out)"; exit 1; }
echo "$out" | grep -qx "reason=disk-probe-failed" || { echo "FAIL: disk reason (got: $out)"; exit 1; }

# Synthesize a commands/design.md in tmp ROOT and re-run with disk probe.
# (We cannot mutate the real ROOT; instead we build a synthetic root tree.)
synth="$tmp/synth"
mkdir -p "$synth/commands" "$synth/scripts/intake"
cp "$SCRIPT" "$synth/scripts/intake/"
chmod +x "$synth/scripts/intake/design-gate-degradation.sh"
echo 'Pass.1' > "$synth/commands/design.md"
# The script computes ROOT relative to its own location; copy a stub proposal too.
cp "$proposal" "$synth/scripts/intake/proposal-stub.md"
out=$(bash "$synth/scripts/intake/design-gate-degradation.sh" --proposal "$synth/scripts/intake/proposal-stub.md" --probe-only)
echo "$out" | grep -qx "m023_shipped=true" || { echo "FAIL: synth disk probe (got: $out)"; exit 1; }
echo "$out" | grep -qx "reason=disk-probe" || { echo "FAIL: synth disk reason (got: $out)"; exit 1; }

echo "PASS: m023-probe — env-override matrix + disk probe (negative + positive synthesized)"
exit 0
