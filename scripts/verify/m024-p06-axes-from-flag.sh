#!/usr/bin/env bash
# scripts/verify/m024-p06-axes-from-flag.sh
# M024/P06/T02 — Verifies proposal-emit.sh accepts --axes-from and applies overrides.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

axes_file="$tmp/axes.txt"
cat > "$axes_file" <<'EOF'
# axes-from override file
scope_tier=C
decomposition=milestone-with-phases
recommended_command=orchestrator:specify
intensity=Full
EOF

emit_out=$(bash "$EMIT" --input "Some short paragraph input." --axes-from "$axes_file" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

grep -q '^scope_tier: "C"' "$proposal" || { echo "FAIL: scope_tier override not applied"; exit 1; }
grep -q '^decomposition: "milestone-with-phases"' "$proposal" || { echo "FAIL: decomposition override not applied"; exit 1; }
grep -q '^recommended_command: "orchestrator:specify"' "$proposal" || { echo "FAIL: recommended_command override not applied"; exit 1; }
grep -q '^intensity: "Full"' "$proposal" || { echo "FAIL: intensity override not applied"; exit 1; }

# REVISE_AXES_DONE rationale skip — overridden axes carry the placeholder rationale
# (revise.sh would post-process to a version-pointer rationale; calling proposal-emit
# directly leaves the placeholder visible).
grep -qE '(Operator revision via revise.sh|operator revision \(revise.sh\))' "$proposal" || {
  echo "FAIL: REVISE_AXES_DONE rationale placeholder not present"
  exit 1
}

# Unknown key exits non-zero.
bad="$tmp/bad.txt"
echo "frobnicate=X" > "$bad"
if bash "$EMIT" --input "x" --axes-from "$bad" --intake-root "$tmp/intake-bad" >/dev/null 2>&1; then
  echo "FAIL: unknown axes-from key should exit non-zero"
  exit 1
fi

# Comments and blank lines are ignored.
ax2="$tmp/axes2.txt"
cat > "$ax2" <<'EOF'

# leading comment
scope_tier=A

# trailing comment
EOF
emit_out=$(bash "$EMIT" --input "y" --axes-from "$ax2" --intake-root "$tmp/intake2")
proposal2=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal2" ] || { echo "FAIL: emitter rejected file with comments + blanks"; exit 1; }
grep -q '^scope_tier: "A"' "$proposal2" || { echo "FAIL: comment-bearing axes file did not apply scope_tier"; exit 1; }

echo "PASS: --axes-from flag applies overrides + REVISE_AXES_DONE rationale skip; unknown keys rejected"
exit 0
