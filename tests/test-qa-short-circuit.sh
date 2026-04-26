#!/usr/bin/env bash
# tests/test-qa-short-circuit.sh
# M024/P05 phase test — `enough` short-circuit forces low_confidence: true,
# which the P04 fast-path guard refuses to auto-proceed past.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ans="$tmp/answers.txt"
cat > "$ans" <<'EOF'
fix a typo in commands/status.md
single-task
enough
never seen
never seen
EOF

emit_out=$(bash "$EMIT" --qa-answers-from "$ans" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')

[ -f "$proposal" ] || { echo "FAIL: emitter produced no proposal"; exit 1; }

grep -q '^input_shape: "empty_qa"$'  "$proposal" || { echo "FAIL: input_shape not empty_qa"; exit 1; }
grep -q '^qa_short_circuited: true$' "$proposal" || { echo "FAIL: qa_short_circuited not true"; exit 1; }
grep -q '^low_confidence: true$'     "$proposal" || { echo "FAIL: low_confidence should be true on short-circuit"; exit 1; }
grep -q '^auto_proceeded: false$'    "$proposal" || { echo "FAIL: auto_proceeded must be false when low_confidence is true (P04 guard)"; exit 1; }

# Transcript should contain Q1+Q2 only.
grep -q '^### Q1$' "$proposal" || { echo "FAIL: missing ### Q1"; exit 1; }
grep -q '^### Q2$' "$proposal" || { echo "FAIL: missing ### Q2"; exit 1; }
grep -q '^### Q3$' "$proposal" && { echo "FAIL: ### Q3 leaked past short-circuit"; exit 1; }
grep -q 'never seen' "$proposal" && { echo "FAIL: post-enough answer leaked into proposal"; exit 1; }

echo "PASS: test-qa-short-circuit — enough at turn 3 → qa_short_circuited true, low_confidence true, auto_proceeded false"
exit 0
